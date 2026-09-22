#!/usr/bin/env python3
"""tracking-body-edit.py - guarded edit of a GitHub issue body (release tracking issue).

Gated: dry run by default, --apply writes.

Purpose
  Edit the body of a tracking issue without ever clobbering a concurrent edit. Three local
  files back the guard: the stored copy (last body the agent saw), the snapshot (last body
  the agent applied) and the live body fetched through `gh`. Edits are expressed as line
  prefixes so they survive the maintainer ticking lines by hand.

Usage
  tracking-body-edit.py --repo <owner/repo> --issue <n> --stored <abs> --snapshot <abs>
      [--tick "<line prefix>"]...
      [--replace-line "<prefix>" --with-file <abs>]...
      [--insert-after "<prefix>" --from-file <abs>]...
      [--check-live] [--apply]
  tracking-body-edit.py --repo <owner/repo> --issue <n> --stored <abs> --snapshot <abs> --resync

Behaviour
  dry run   read the stored copy, compute the edits, print the unified diff and the
            checked/unchecked counts, print DRY_RUN_OK. With --check-live also compare the
            live body with the stored copy (read-only) and print LIVE_MATCHES_STORED or
            LIVE_DRIFT.
  --apply   fetch the live body; ABORT (exit 3) when it differs from the stored copy; apply
            the edits; write the body to a temp file next to the stored copy; `gh issue edit
            --body-file`; re-fetch; GUARD_FAIL (exit 4) when the re-fetched body differs from
            the edited one; update stored and snapshot; print GUARD_OK with the counts.
  --resync  copy the live body to the stored copy and the snapshot, no edit (local writes only).

Comparison rule: bodies are compared after replacing CRLF with LF and stripping trailing
newlines (the `--jq .body` path appends one newline; without the strip every edit would grow
the body by a blank line and the post-edit comparison would fail on an invisible difference).

Self-check: the diff between the stored copy and the edited body is inspected on changed lines
only (`+`/`-` lines without the file headers); the number of removed and added lines must be
exactly the number implied by the requested edits, otherwise ABORT before any write.

Exit codes
  0  dry run OK, applied and verified, or resynced
  2  usage error (unknown flag, missing argument, relative path, missing file)
  3  ABORT: precondition failed (prefix not unique, live differs from stored, self-check)
  4  GUARD_FAIL: the re-fetched body differs from the edited body
  5  refused by policy (unused here)

Example
  tracking-body-edit.py --repo falcosecurity/falco --issue 3967 \
      --stored /abs/output/tracking-body.md --snapshot /abs/output/tracking-body.snapshot.md \
      --tick "  - [ ] Update helm chart documentation" --check-live

Dry run by default; --apply performs the public action after re-checking every precondition.

Source pattern: output/2026-09-22-falco-release-helper-templates/tracking-edit-sep21-website-done.py
and ws1587-edit-sep21-merged.py (stored/snapshot/live guard, prefix edits, trailing newline rule).
"""
import argparse
import difflib
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

EXIT_OK, EXIT_USAGE, EXIT_ABORT, EXIT_GUARD = 0, 2, 3, 4
UNCHECKED, CHECKED = "- [ ]", "- [x]"


def stamp():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def norm(text):
    return text.replace("\r\n", "\n").rstrip("\n")


def usage_error(parser, msg):
    print(f"usage error: {msg}", file=sys.stderr)
    parser.print_usage(sys.stderr)
    sys.exit(EXIT_USAGE)


def abort(msg):
    print(f"ABORT: {msg}")
    sys.exit(EXIT_ABORT)


def require_abs(parser, flag, path):
    if not os.path.isabs(path):
        usage_error(parser, f"{flag} must be an absolute path: {path}")
    return path


def read_file(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def write_file(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def gh(*args):
    res = subprocess.run(["gh", *args], check=True, capture_output=True, text=True)
    return res.stdout


def fetch_body(repo, issue):
    return norm(gh("issue", "view", str(issue), "-R", repo, "--json", "body", "--jq", ".body"))


def counts(text):
    return text.count(CHECKED), text.count(UNCHECKED)


def unique_line(lines, prefix, what):
    hits = [i for i, line in enumerate(lines) if line.startswith(prefix)]
    if len(hits) != 1:
        abort(f"{what} prefix matches {len(hits)} lines (need exactly 1): {prefix!r}")
    return hits[0]


class HeaderHelpParser(argparse.ArgumentParser):
    """--help prints the module header verbatim (purpose, flags, exit codes, example, gating sentence)."""

    def format_help(self):
        return __doc__ + "\n" + super().format_usage()


def build_parser():
    p = HeaderHelpParser(
        prog="tracking-body-edit.py",
        description="Guarded edit of a GitHub issue body. Dry run by default; --apply performs "
        "the public action after re-checking every precondition.",
        add_help=True,
    )
    p.add_argument("--repo", required=True, help="owner/repo")
    p.add_argument("--issue", required=True, type=int, help="issue number")
    p.add_argument("--stored", required=True, help="absolute path of the stored body copy")
    p.add_argument("--snapshot", required=True, help="absolute path of the last applied body")
    p.add_argument("--tick", action="append", default=[], metavar="PREFIX",
                   help="tick '- [ ]' to '- [x]' on the unique line starting with PREFIX (repeatable)")
    p.add_argument("--replace-line", action="append", default=[], metavar="PREFIX",
                   help="replace the unique line starting with PREFIX (pair with --with-file)")
    p.add_argument("--with-file", action="append", default=[], metavar="ABS",
                   help="file whose content replaces the line (pairs positionally with --replace-line)")
    p.add_argument("--insert-after", action="append", default=[], metavar="PREFIX",
                   help="insert lines after the unique line starting with PREFIX (pair with --from-file)")
    p.add_argument("--from-file", action="append", default=[], metavar="ABS",
                   help="file whose lines are inserted (pairs positionally with --insert-after)")
    p.add_argument("--resync", action="store_true", help="copy live to stored and snapshot, no edit")
    p.add_argument("--check-live", action="store_true",
                   help="dry run only: also compare the live body with the stored copy (read-only)")
    p.add_argument("--apply", action="store_true", help="perform the edit after re-checking preconditions")
    return p


def main():
    parser = build_parser()
    args = parser.parse_args()
    if "/" not in args.repo:
        usage_error(parser, f"--repo must be owner/repo: {args.repo}")
    require_abs(parser, "--stored", args.stored)
    require_abs(parser, "--snapshot", args.snapshot)
    if len(args.replace_line) != len(args.with_file):
        usage_error(parser, "--replace-line and --with-file must be given in pairs")
    if len(args.insert_after) != len(args.from_file):
        usage_error(parser, "--insert-after and --from-file must be given in pairs")
    for path in args.with_file + args.from_file:
        require_abs(parser, "--with-file/--from-file", path)
        if not os.path.isfile(path):
            usage_error(parser, f"file not found: {path}")
    edits_requested = len(args.tick) + len(args.replace_line) + len(args.insert_after)

    print(f"== {stamp()} tracking-body-edit {args.repo}#{args.issue} apply={int(args.apply)} resync={int(args.resync)}")

    if args.resync:
        if edits_requested:
            usage_error(parser, "--resync takes no edits")
        live = fetch_body(args.repo, args.issue)
        write_file(args.stored, live + "\n")
        shutil.copyfile(args.stored, args.snapshot)
        c, u = counts(live)
        print(f"RESYNC_OK: stored and snapshot now hold the live body ({len(live)} chars, checked={c} unchecked={u})")
        sys.exit(EXIT_OK)

    if not edits_requested:
        usage_error(parser, "no edits given (use --tick, --replace-line/--with-file, --insert-after/--from-file, or --resync)")
    if not os.path.isfile(args.stored):
        usage_error(parser, f"stored copy not found: {args.stored} (run --resync first)")

    base = norm(read_file(args.stored))
    lines = base.split("\n")
    expected_removed = expected_added = 0
    already_ticked = []

    # 1. ticks
    for prefix in args.tick:
        i = unique_line(lines, prefix, "--tick")
        if UNCHECKED in lines[i]:
            lines[i] = lines[i].replace(UNCHECKED, CHECKED, 1)
            expected_removed += 1
            expected_added += 1
            print(f"TICK: {lines[i][:100]}")
        elif CHECKED in lines[i]:
            already_ticked.append(prefix)
            print(f"ALREADY_TICKED: {lines[i][:100]}")
        else:
            abort(f"--tick line has no checkbox: {lines[i][:100]!r}")

    # 2. line replacements
    for prefix, path in zip(args.replace_line, args.with_file):
        i = unique_line(lines, prefix, "--replace-line")
        new_lines = norm(read_file(path)).split("\n")
        if new_lines == [lines[i]]:
            abort(f"--replace-line content is identical to the current line: {prefix!r}")
        lines[i:i + 1] = new_lines
        expected_removed += 1
        expected_added += len(new_lines)
        print(f"REPLACE: {prefix[:80]!r} -> {len(new_lines)} line(s) from {path}")

    # 3. insertions
    for prefix, path in zip(args.insert_after, args.from_file):
        i = unique_line(lines, prefix, "--insert-after")
        new_lines = norm(read_file(path)).split("\n")
        lines[i + 1:i + 1] = new_lines
        expected_added += len(new_lines)
        print(f"INSERT: {len(new_lines)} line(s) from {path} after {prefix[:80]!r}")

    body = "\n".join(lines).rstrip("\n")

    # self-check on changed lines only
    diff = list(difflib.unified_diff(base.split("\n"), body.split("\n"), "stored", "edited", lineterm="", n=0))
    removed = [l for l in diff if l.startswith("-") and not l.startswith("---")]
    added = [l for l in diff if l.startswith("+") and not l.startswith("+++")]
    print("\n".join(diff) if diff else "(no textual change)")
    if len(removed) != expected_removed or len(added) != expected_added:
        abort(f"self-check: diff has -{len(removed)}/+{len(added)} changed lines, expected -{expected_removed}/+{expected_added}")
    bc, bu = counts(base)
    ec, eu = counts(body)
    print(f"\nedits={edits_requested} already_ticked={len(already_ticked)} changed_lines=-{len(removed)}/+{len(added)}; "
          f"checked {bc} -> {ec}, unchecked {bu} -> {eu}")

    if not args.apply:
        if args.check_live:
            live = fetch_body(args.repo, args.issue)
            print("LIVE_MATCHES_STORED" if live == base else "LIVE_DRIFT: live body differs from the stored copy (run --resync before --apply)")
        print("DRY_RUN_OK")
        sys.exit(EXIT_OK)

    if body == base:
        abort("nothing to change (every requested line is already in the target state)")

    # --apply: re-check the live body right before writing
    live = fetch_body(args.repo, args.issue)
    if live != base:
        abort("live body differs from the stored copy (concurrent edit). Run --resync, then re-run.")
    fd, tmp = tempfile.mkstemp(prefix=".tracking-body-edit-", suffix=".md", dir=os.path.dirname(args.stored))
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(body + "\n")
    subprocess.run(["gh", "issue", "edit", str(args.issue), "-R", args.repo, "--body-file", tmp],
                   check=True, capture_output=True, text=True)
    after = fetch_body(args.repo, args.issue)
    if after != body:
        print(f"GUARD_FAIL: re-fetched body differs from the edited body (edited copy kept at {tmp})")
        sys.exit(EXIT_GUARD)
    os.unlink(tmp)
    write_file(args.stored, after + "\n")
    shutil.copyfile(args.stored, args.snapshot)
    print(f"GUARD_OK {stamp()}: live == edited; stored and snapshot updated; checked={ec} unchecked={eu}")
    sys.exit(EXIT_OK)


if __name__ == "__main__":
    main()
