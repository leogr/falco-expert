#!/usr/bin/env python3
"""Read-only GitHub delta watcher. Uses gh authentication; never performs a write."""

import argparse
import email.utils
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode


def utcnow():
    return datetime.now(timezone.utc)


def stamp(value):
    return value.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_stamp(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timestamp has no timezone")
    return parsed.astimezone(timezone.utc)


class CollectionError(Exception):
    def __init__(self, message, retry_after=0):
        super().__init__(message)
        self.retry_after = retry_after


def api_get(endpoint):
    try:
        result = subprocess.run(
            ["gh", "api", "--hostname", "github.com", "--method", "GET", "--include",
             "-H", "Accept: application/vnd.github+json", endpoint],
            capture_output=True, text=True, timeout=45, check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise CollectionError(str(exc)) from exc
    header_text, separator, body = result.stdout.replace("\r\n", "\n").partition("\n\n")
    headers = {}
    for line in header_text.splitlines()[1:]:
        name, colon, value = line.partition(":")
        if colon:
            headers[name.lower()] = value.strip()
    if result.returncode:
        retry = 0
        try:
            raw_retry = headers.get("retry-after", "0")
            retry = float(raw_retry) if raw_retry.isdigit() else max(
                0, email.utils.parsedate_to_datetime(raw_retry).timestamp() - time.time())
            if headers.get("x-ratelimit-remaining") == "0":
                retry = max(retry, float(headers.get("x-ratelimit-reset", "0")) - time.time())
        except (TypeError, ValueError, OverflowError):
            retry = max(retry, 3600)
        raise CollectionError(f"GET {endpoint}: {result.stderr.strip()[:400]}", max(0, retry))
    if not separator or not header_text.startswith("HTTP/"):
        raise CollectionError("gh returned no HTTP headers")
    try:
        return json.loads(body), headers
    except ValueError as exc:
        raise CollectionError("gh returned invalid JSON") from exc


def summarize(item):
    if (not isinstance(item, dict) or type(item.get("number")) is not int
            or item["number"] <= 0 or item.get("state") not in ("open", "closed")
            or not isinstance(item.get("title"), str) or not isinstance(item.get("html_url"), str)):
        raise ValueError("malformed issue/PR record")
    parse_stamp(item["updated_at"])
    return {
        "number": item["number"], "kind": "pr" if "pull_request" in item else "issue",
        "url": item["html_url"], "title": item["title"], "state": item["state"],
        "updated_at": item["updated_at"], "comments": item.get("comments", 0),
        "author": item.get("user", {}).get("login"),
        "labels": sorted(label["name"] for label in item.get("labels", [])),
        "body_digest": hashlib.sha256((item.get("body") or "").encode()).hexdigest(),
    }


def collect_repo(repo, previous, get, now, lookback_days, max_pages):
    # Repeat an overlap to catch updates near the previous request boundary.
    lower = (parse_stamp(previous["cursor"]) - timedelta(minutes=2) if previous.get("cursor")
             else parse_stamp(previous["since"]) if previous.get("since")
             else now - timedelta(days=lookback_days))
    items, first_date, pages = {}, None, 0
    for page in range(1, max_pages + 1):
        query = urlencode({"state": "all", "sort": "updated", "direction": "asc",
                           "since": stamp(lower), "per_page": 100, "page": page})
        rows, headers = get(f"repos/{repo}/issues?{query}")
        if not isinstance(rows, list):
            raise CollectionError("issue listing was not an array")
        if first_date is None:
            try:
                first_date = email.utils.parsedate_to_datetime(headers["date"])
                if first_date.tzinfo is None:
                    raise ValueError("missing timezone")
            except (KeyError, TypeError, ValueError) as exc:
                raise CollectionError("issue listing has no valid server Date") from exc
        for item in rows:
            summary = summarize(item)
            items[str(summary["number"])] = summary
        pages = page
        if 'rel="next"' not in headers.get("link", ""):
            break
    else:
        raise CollectionError(f"page limit ({max_pages}) reached; cursor preserved")

    commits, _ = get(f"repos/{repo}/commits?per_page=1")
    if (not isinstance(commits, list) or len(commits) != 1
            or not re.fullmatch(r"[0-9a-f]{40}", commits[0].get("sha", ""))):
        raise CollectionError("default-branch head unavailable")
    head = commits[0]["sha"]
    old_items = previous.get("items", {})
    changes = [item for number, item in items.items() if old_items.get(number) != item]
    snapshot = {"cursor": stamp(first_date), "since": stamp(lower), "head": head,
                "items": items, "pages": pages, "checked_at": stamp(now)}
    event = None
    if not previous.get("cursor") or changes or previous.get("head") != head or previous.get("error"):
        event = {"repo": repo, "type": "baseline" if not previous.get("cursor") else "change",
                 "since": stamp(lower), "through": stamp(first_date), "pages": pages,
                 "head": head, "previous_head": previous.get("head"), "items": changes,
                 "recovered": bool(previous.get("error"))}
    return snapshot, event


def poll(state, repos, get=api_get, now=None, lookback_days=7, max_pages=10):
    now = now or utcnow()
    updated = dict(state)
    updated["sources"] = dict(state.get("sources", {}))
    events, retry_after, failed = [], 0, False
    for repo in repos:
        previous = state.get("sources", {}).get(repo, {})
        try:
            snapshot, event = collect_repo(repo, previous, get, now, lookback_days, max_pages)
            updated["sources"][repo] = snapshot
            if event:
                events.append(event)
        except (CollectionError, ValueError, KeyError, TypeError, AttributeError) as exc:
            failed = True
            retry_after = max(retry_after, getattr(exc, "retry_after", 0))
            updated["sources"][repo] = {
                **previous, "since": previous.get("since", stamp(now - timedelta(days=lookback_days))),
                "error": str(exc), "attempted_at": stamp(now),
            }
            events.append({"repo": repo, "type": "error", "error": str(exc),
                           "cursor_preserved": previous.get("cursor"), "retry_after": retry_after})
    updated.update(last_poll=stamp(now), coverage="partial" if failed else "complete-window")
    return updated, events, retry_after


def save(path, state, events):
    # Journal first: a crash can duplicate a read notification, but cannot consume it silently.
    if events:
        journal = path.with_suffix(".events.jsonl")
        with journal.open("a", encoding="utf-8") as stream:
            stream.write(json.dumps({"observed_at": state["last_poll"], "events": events}) + "\n")
            stream.flush()
            os.fsync(stream.fileno())
    with tempfile.NamedTemporaryFile("w", dir=path.parent, prefix=path.name + ".",
                                     encoding="utf-8", delete=False) as stream:
        temp = Path(stream.name)
        try:
            json.dump(state, stream, indent=2)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
            os.replace(temp, path)
        finally:
            temp.unlink(missing_ok=True)


def positive(value):
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return parsed


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, epilog=(
        "Default: sleep between polls until a baseline, change or error is saved, then exit. "
        "Exit 0: complete window; 2: partial/error; 130: interrupted. "
        "State is local; all GitHub requests are GET. Read continuity.md for coverage limits."))
    parser.add_argument("--repo", action="append", required=True, help="owner/repo; repeat for approved scope")
    parser.add_argument("--state", type=Path, required=True, help="absolute JSON path in the resolved output directory")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--once", action="store_true", help="one poll, even if quiet")
    mode.add_argument("--continuous", action="store_true", help="keep collecting; stdout only on changes/errors")
    parser.add_argument("--interval", type=positive, default=900, help="initial delay in seconds (default 900)")
    parser.add_argument("--max-interval", type=positive, default=3600, help="quiet/error backoff cap (default 3600)")
    parser.add_argument("--lookback-days", type=positive, default=7, help="first observation window (default 7 days)")
    parser.add_argument("--max-pages", type=positive, default=10, help="issue pages per repo/poll (default 10)")
    args = parser.parse_args(argv)
    repos = sorted(set(args.repo))
    if (not args.state.is_absolute() or args.state.suffix != ".json" or
            any(not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*", repo) for repo in repos)
            or args.max_interval < args.interval):
        parser.error("use owner/repo, an absolute .json state path, and max-interval >= interval")
    state = {"version": 1, "repos": repos, "sources": {}}
    try:
        args.state.parent.mkdir(parents=True, exist_ok=True)
        with args.state.with_suffix(".lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            if args.state.exists():
                state = json.loads(args.state.read_text())
                if not isinstance(state, dict):
                    raise ValueError("malformed watcher state")
                if state.get("version") != 1 or state.get("repos") != repos:
                    raise ValueError("state version/scope differs; use a new state path")
                if (not isinstance(state.get("sources"), dict)
                        or any(not isinstance(source, dict) for source in state["sources"].values())):
                    raise ValueError("malformed watcher state")
            delay = args.interval
            checkpoint = state.copy()

            def interrupted(_signum, _frame):
                raise KeyboardInterrupt

            signal.signal(signal.SIGTERM, interrupted)
            try:
                while True:
                    state, events, retry = poll(state, repos, lookback_days=args.lookback_days, max_pages=args.max_pages)
                    failed = state["coverage"] == "partial"
                    if events and not failed:
                        delay = args.interval
                    wait_for = max(delay, retry)
                    done = args.once or (bool(events) and not args.continuous)
                    state.update(pid=os.getpid(), status="stopped" if done else "waiting",
                                 next_check=None if done else stamp(utcnow() + timedelta(seconds=wait_for)))
                    save(args.state, state, events)
                    checkpoint = state.copy()
                    if events or args.once:
                        print(json.dumps({"state": str(args.state), "coverage": state["coverage"],
                                          "status": state["status"], "events": events}), flush=True)
                    if done:
                        return 2 if failed else 0
                    time.sleep(wait_for)
                    if failed or not events:
                        delay = min(args.max_interval, delay * 2)
            except KeyboardInterrupt:
                # Do not consume an in-flight observation whose journal may not be saved.
                checkpoint.update(status="stopped", next_check=None)
                save(args.state, checkpoint, [])
                return 130
    except (OSError, ValueError) as exc:
        print(f"watch: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
