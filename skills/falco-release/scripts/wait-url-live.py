#!/usr/bin/env python3
"""wait-url-live.py - wait until a URL answers HTTP 200 and its body contains a needle.

Purpose:    Poll a public URL (for example a published documentation page, a
            release announcement, or a package index) until it answers 200 and,
            when --needle is given, the decoded body contains that string.
Usage:      wait-url-live.py --url <http(s)://...> [--needle <text>] [--max-minutes <n>] [--interval-seconds <n>] [--request-timeout-seconds <n>]
Exit codes: 0 URL_LIVE | 1 URL_CLIENT_ERROR (every answer until the deadline was a 4xx)
            | 2 usage error | 3 TIMEOUT
Read-only. Performs plain HTTP GET requests only; stdlib only.
"""

import argparse
import sys
import time
import urllib.error
import urllib.request

USER_AGENT = "wait-url-live/1 (read-only poller)"


def ts() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def log(message: str) -> None:
    print(f"{ts()} {message}", flush=True)


def positive_int(value: str) -> int:
    try:
        number = int(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"{value!r} is not an integer") from exc
    if number <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return number


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="wait-url-live.py",
        description=(
            "Wait until a URL answers HTTP 200 and (optionally) its body contains a "
            "needle string. Read-only: plain GET requests only."
        ),
        epilog=(
            "Exit codes: 0 URL_LIVE | 1 URL_CLIENT_ERROR (only 4xx answers observed "
            "until the deadline) | 2 usage error | 3 TIMEOUT.\n"
            "Example: wait-url-live.py --url https://example.org/releases/1.2.3/ "
            "--needle 'Version 1.2.3' --max-minutes 60"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--url", required=True, help="URL to poll (http:// or https://)")
    parser.add_argument("--needle", default=None, help="string the body must contain (optional)")
    parser.add_argument("--max-minutes", type=positive_int, default=180, help="give up after n minutes (default 180)")
    parser.add_argument("--interval-seconds", type=positive_int, default=60, help="seconds between polls (default 60)")
    parser.add_argument(
        "--request-timeout-seconds", type=positive_int, default=30, help="per-request socket timeout (default 30)"
    )
    return parser


def fetch(url: str, timeout: int) -> tuple:
    """Return (status_code, body) for one GET; raises urllib errors."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode("utf-8", "replace")
        return response.status, body


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if not (args.url.startswith("http://") or args.url.startswith("https://")):
        parser.error("--url must start with http:// or https://")

    deadline = time.monotonic() + args.max_minutes * 60
    last_state = None
    polls = 0
    client_errors = 0

    while True:
        polls += 1
        try:
            status, body = fetch(args.url, args.request_timeout_seconds)
            if status == 200 and (args.needle is None or args.needle in body):
                needle_note = f" body contains {args.needle!r}" if args.needle is not None else ""
                log(f"URL_LIVE {args.url} HTTP {status}{needle_note} after {polls} poll(s)")
                return 0
            state = f"HTTP {status} but needle {args.needle!r} not in body ({len(body)} bytes)"
        except urllib.error.HTTPError as exc:
            if 400 <= exc.code < 500:
                client_errors += 1
            state = f"HTTP {exc.code} {exc.reason}"
        except urllib.error.URLError as exc:
            state = f"connection error: {exc.reason}"
        except (TimeoutError, OSError) as exc:
            state = f"request error: {exc.__class__.__name__}: {exc}"

        if state != last_state:
            log(f"{args.url}: {state}")
            last_state = state

        now = time.monotonic()
        if now >= deadline:
            if client_errors == polls:
                log(
                    f"URL_CLIENT_ERROR {args.url}: every answer was a 4xx client error "
                    f"({polls} poll(s), last: {state}) after {args.max_minutes}m"
                )
                return 1
            log(f"TIMEOUT after {args.max_minutes}m: {args.url} not live (last: {state})")
            return 3
        time.sleep(min(args.interval_seconds, max(0, int(deadline - now))))


if __name__ == "__main__":
    sys.exit(main())
