#!/usr/bin/env python3
"""Offline behavior tests for collection, recovery and quiet waiting."""

import argparse
import copy
from datetime import datetime, timedelta, timezone
import email.utils
import fcntl
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit


spec = importlib.util.spec_from_file_location("watch", Path(__file__).parents[1] / "scripts" / "watch.py")
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)
NOW = datetime(2026, 9, 22, 12, 0, tzinfo=timezone.utc)
REPO = "falcosecurity/falco"
HEAD = "a" * 40
ROOT = None


def issue(number=1, state="open", at=None):
    return {"number": number, "title": f"Report {number}", "state": state,
            "updated_at": watch.stamp(at or NOW), "html_url": f"https://github.com/{REPO}/issues/{number}",
            "body": "evidence", "labels": [], "user": {"login": "contributor"}, "comments": 0}


class API:
    def __init__(self, pages=None, head=HEAD, now=NOW):
        self.pages = pages if pages is not None else [[]]
        self.head, self.now, self.calls = head, now, []

    def __call__(self, endpoint):
        self.calls.append(endpoint)
        headers = {"date": email.utils.format_datetime(self.now)}
        if "/commits?" in endpoint:
            return [{"sha": self.head}], headers
        query = parse_qs(urlsplit(endpoint).query)
        assert query["state"] == ["all"]
        page = int(query["page"][0])
        if page < len(self.pages):
            headers["link"] = '<https://api.github.com/next>; rel="next"'
        value = self.pages[page - 1]
        if isinstance(value, Exception):
            raise value
        return copy.deepcopy(value), headers


class WatchTests(unittest.TestCase):
    def fresh(self, api=None):
        return watch.poll({"version": 1, "repos": [REPO], "sources": {}}, [REPO],
                          get=api or API(), now=NOW)

    def test_baseline_empty_is_valid_and_not_full_backlog(self):
        state, events, _ = self.fresh()
        self.assertEqual("complete-window", state["coverage"])
        self.assertEqual("baseline", events[0]["type"])
        self.assertEqual([], events[0]["items"])
        self.assertEqual(watch.stamp(NOW - timedelta(days=7)), events[0]["since"])

    def test_all_pages_and_closed_pr_are_collected(self):
        closed = issue(2, "closed")
        closed["pull_request"] = {"url": "https://api.github.com/repos/example/pulls/2"}
        api = API([[issue()], [closed]])
        state, events, _ = self.fresh(api)
        self.assertEqual(2, state["sources"][REPO]["pages"])
        self.assertEqual("pr", events[0]["items"][1]["kind"])
        self.assertEqual("closed", events[0]["items"][1]["state"])
        self.assertEqual(3, len(api.calls))

    def test_overlap_uses_server_time_and_quiet_poll_has_no_event(self):
        server = NOW - timedelta(seconds=30)
        state, _, _ = self.fresh(API([[issue(at=server)]], now=server))
        api = API([[issue(at=server)]])
        updated, events, _ = watch.poll(state, [REPO], get=api, now=NOW)
        query = parse_qs(urlsplit(api.calls[0]).query)
        self.assertEqual([watch.stamp(server - timedelta(minutes=2))], query["since"])
        self.assertEqual([], events)
        self.assertEqual(watch.stamp(NOW), updated["sources"][REPO]["cursor"])

    def test_closure_and_head_change_are_events_not_disappearing_items(self):
        state, _, _ = self.fresh(API([[issue()]]))
        updated, events, _ = watch.poll(state, [REPO], get=API([[issue(state="closed")]], "b" * 40), now=NOW)
        self.assertEqual("closed", events[0]["items"][0]["state"])
        self.assertEqual(HEAD, events[0]["previous_head"])
        self.assertEqual("b" * 40, updated["sources"][REPO]["head"])

    def test_head_change_alone_is_observable(self):
        state, _, _ = self.fresh()
        _, events, _ = watch.poll(state, [REPO], get=API(head="b" * 40), now=NOW)
        self.assertEqual([], events[0]["items"])
        self.assertEqual(HEAD, events[0]["previous_head"])

    def test_partial_page_failure_does_not_advance_or_emit_partial_items(self):
        state, _, _ = self.fresh(API([[issue()]]))
        before = copy.deepcopy(state["sources"][REPO])
        api = API([[issue(2)], watch.CollectionError("rate limit", 7200)], now=NOW + timedelta(hours=1))
        updated, events, retry = watch.poll(state, [REPO], get=api, now=NOW + timedelta(hours=1))
        self.assertEqual("partial", updated["coverage"])
        self.assertEqual(before["cursor"], updated["sources"][REPO]["cursor"])
        self.assertEqual(before["items"], updated["sources"][REPO]["items"])
        self.assertEqual(["error"], [event["type"] for event in events])
        self.assertEqual(7200, retry)

    def test_page_cap_fails_and_recovery_delivers_unseen_change(self):
        state, _, _ = self.fresh(API([[issue()]]))
        failed, _, _ = watch.poll(state, [REPO], get=API([[issue(2)], [issue(3)]]), now=NOW, max_pages=1)
        self.assertEqual("partial", failed["coverage"])
        recovered, events, _ = watch.poll(failed, [REPO], get=API([[issue(2)], [issue(3)]]), now=NOW)
        self.assertEqual("complete-window", recovered["coverage"])
        self.assertEqual([2, 3], [item["number"] for item in events[0]["items"]])
        self.assertTrue(events[0]["recovered"])

    def test_failed_repository_does_not_block_other_repository(self):
        good = API([[issue()]])

        def get(endpoint):
            if "/libs/" in endpoint:
                raise watch.CollectionError("unavailable")
            return good(endpoint)

        state, events, _ = watch.poll({}, [REPO, "falcosecurity/libs"], get=get, now=NOW)
        self.assertIn("cursor", state["sources"][REPO])
        self.assertNotIn("cursor", state["sources"]["falcosecurity/libs"])
        self.assertEqual({"baseline", "error"}, {event["type"] for event in events})

    def test_malformed_data_and_missing_date_preserve_previous_success(self):
        state, _, _ = self.fresh()
        for bad in ([{"number": 1}], {"message": "oops"}):
            with self.subTest(bad=bad):
                result, _, _ = watch.poll(state, [REPO], get=API([bad]), now=NOW)
                self.assertEqual("partial", result["coverage"])
                self.assertEqual(state["sources"][REPO]["cursor"], result["sources"][REPO]["cursor"])
        result, _, _ = watch.poll(state, [REPO], get=lambda endpoint: ([], {}), now=NOW)
        self.assertEqual("partial", result["coverage"])

    def test_large_numeric_item_ids_are_preserved(self):
        _, events, _ = self.fresh(API([[issue(5280677319)]]))
        self.assertEqual(5280677319, events[0]["items"][0]["number"])

    def test_journal_retains_events_across_quiet_checkpoint(self):
        path = ROOT / "journal" / "watch.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        state, events, _ = self.fresh(API([[issue()]]))
        watch.save(path, state, events)
        original = path.with_suffix(".events.jsonl").read_text()
        quiet, events, _ = watch.poll(state, [REPO], get=API([[issue()]]), now=NOW)
        watch.save(path, quiet, events)
        self.assertEqual(original, path.with_suffix(".events.jsonl").read_text())
        self.assertEqual(quiet, json.loads(path.read_text()))

    def test_cli_is_explicitly_get_and_timeout_is_bounded(self):
        response = subprocess.CompletedProcess([], 0, 'HTTP/2.0 200 OK\nDate: Tue, 22 Sep 2026 12:00:00 GMT\n\n[]', '')
        with patch.object(watch.subprocess, "run", return_value=response) as run:
            rows, headers = watch.api_get("repos/falcosecurity/falco/issues?state=all")
        argv = run.call_args.args[0]
        self.assertEqual("GET", argv[argv.index("--method") + 1])
        self.assertEqual("github.com", argv[argv.index("--hostname") + 1])
        self.assertEqual(45, run.call_args.kwargs["timeout"])
        self.assertFalse(run.call_args.kwargs.get("shell", False))
        self.assertEqual([], rows)
        self.assertIn("date", headers)

    def test_server_retry_instruction_survives_cli_error(self):
        response = subprocess.CompletedProcess([], 1, 'HTTP/2.0 429 Too Many Requests\nRetry-After: 7200\n\n{}', 'rate limited')
        with patch.object(watch.subprocess, "run", return_value=response):
            with self.assertRaises(watch.CollectionError) as caught:
                watch.api_get("repos/falcosecurity/falco/issues")
        self.assertEqual(7200, caught.exception.retry_after)

    def test_changed_scope_does_not_overwrite_checkpoint(self):
        path = ROOT / "scope.json"
        original = json.dumps({"version": 1, "repos": [REPO], "sources": {}})
        path.write_text(original)
        with patch.object(watch, "poll") as poll:
            result = watch.main(["--repo", "falcosecurity/libs", "--state", str(path), "--once"])
        self.assertEqual(2, result)
        poll.assert_not_called()
        self.assertEqual(original, path.read_text())

    def test_quiet_monitor_sleeps_without_repeated_output_and_stops_on_change(self):
        path = ROOT / "quiet.json"
        delays = []
        quiet = {"version": 1, "repos": [REPO], "sources": {}, "last_poll": watch.stamp(NOW), "coverage": "complete-window"}
        responses = [(copy.deepcopy(quiet), [], 0), (copy.deepcopy(quiet), [], 0),
                     (copy.deepcopy(quiet), [{"type": "change", "repo": REPO}], 0)]
        with patch.object(watch, "poll", side_effect=responses), patch.object(watch.time, "sleep", side_effect=delays.append), patch("builtins.print") as emit:
            result = watch.main(["--repo", REPO, "--state", str(path), "--interval", "10", "--max-interval", "40"])
        self.assertEqual(0, result)
        self.assertEqual([10, 20], delays)
        self.assertEqual(1, emit.call_count)
        self.assertEqual("stopped", json.loads(path.read_text())["status"])

    def test_interruption_before_journaling_preserves_last_durable_cursor(self):
        path = ROOT / "interrupted.json"
        original, _, _ = self.fresh()
        path.write_text(json.dumps(original))
        newer, events, retry = watch.poll(original, [REPO], get=API([[issue(2)]], now=NOW + timedelta(hours=1)), now=NOW)
        real_save = watch.save
        attempts = []

        def interrupted_save(target, state, pending):
            attempts.append(pending)
            if len(attempts) == 1:
                raise KeyboardInterrupt
            real_save(target, state, pending)

        with patch.object(watch, "poll", return_value=(newer, events, retry)), patch.object(watch, "save", side_effect=interrupted_save):
            result = watch.main(["--repo", REPO, "--state", str(path), "--once"])
        self.assertEqual(130, result)
        saved = json.loads(path.read_text())
        self.assertEqual(original["sources"], saved["sources"])
        self.assertEqual("stopped", saved["status"])
        self.assertTrue(attempts[0])

    def test_continuous_monitor_respects_server_backoff_above_local_cap(self):
        path = ROOT / "retry.json"
        state = {"version": 1, "repos": [REPO], "sources": {}, "last_poll": watch.stamp(NOW), "coverage": "partial"}
        with patch.object(watch, "poll", return_value=(state, [{"type": "error"}], 7200)), patch.object(watch.time, "sleep", side_effect=KeyboardInterrupt) as sleep, patch("builtins.print"):
            result = watch.main(["--repo", REPO, "--state", str(path), "--continuous", "--interval", "10", "--max-interval", "40"])
        self.assertEqual(130, result)
        sleep.assert_called_once_with(7200)
        self.assertEqual("stopped", json.loads(path.read_text())["status"])

    def test_concurrent_writer_cannot_poll_or_replace_checkpoint(self):
        path = ROOT / "locked.json"
        original = json.dumps({"version": 1, "repos": [REPO], "sources": {}})
        path.write_text(original)
        with path.with_suffix(".lock").open("a") as held, patch.object(watch, "poll") as poll:
            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = watch.main(["--repo", REPO, "--state", str(path), "--once"])
        self.assertEqual(2, result)
        poll.assert_not_called()
        self.assertEqual(original, path.read_text())

    def test_malformed_checkpoint_is_preserved_without_network_requests(self):
        path = ROOT / "malformed.json"
        for value in ([], {"version": 1, "repos": [REPO], "sources": {REPO: None}}):
            with self.subTest(value=value), patch.object(watch, "poll") as poll:
                original = json.dumps(value)
                path.write_text(original)
                result = watch.main(["--repo", REPO, "--state", str(path), "--once"])
                self.assertEqual(2, result)
                poll.assert_not_called()
                self.assertEqual(original, path.read_text())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--workdir", type=Path, required=True)
    args, rest = parser.parse_known_args()
    if not args.workdir.is_absolute():
        parser.error("--workdir must be absolute")
    ROOT = args.workdir
    ROOT.mkdir(parents=True, exist_ok=True)
    unittest.main(argv=[sys.argv[0]] + rest, verbosity=2)
