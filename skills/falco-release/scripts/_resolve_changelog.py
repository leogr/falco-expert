#!/usr/bin/env python3
"""_resolve_changelog.py - deterministic resolution of a chart CHANGELOG cherry-pick conflict.

Used by sync-pr.sh when a cherry-pick conflicts only on the changelog path. Rule: the lines the
picked commit added to the changelog go under the release branch's own unreleased section; the
rest of the release branch file is kept as is.

Usage
  _resolve_changelog.py --base <abs> --source <abs> --parent <abs> --out <abs> [--anchor "## Unreleased"]

  --base    the changelog as it is on the release branch (HEAD of the sync branch)
  --source  the changelog as committed by the picked commit
  --parent  the changelog in the picked commit's (first) parent
  --out     where to write the resolved file (usually the conflicted path in the worktree)

The added lines are the non-blank lines present in --source and absent from --parent, in source
order. They are inserted right after the first blank line that follows the anchor line, followed
by one blank line, exactly like the hand-made resolutions this script generalizes.

Exit codes: 0 resolved (prints `resolved: inserted N lines under <anchor>`), 2 usage,
3 the rule does not apply (anchor missing or duplicated, no added lines, lines already present,
self-check failed); nothing is written in that case.

Source pattern: output/2026-09-22-falco-release-helper-templates/resolve-changelog-3990.py
"""
import argparse
import os
import sys

EXIT_USAGE, EXIT_ABORT = 2, 3


def fail(code, msg):
    print(("ABORT: " if code == EXIT_ABORT else "usage error: ") + msg, file=sys.stderr)
    sys.exit(code)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().replace("\r\n", "\n")


def main():
    p = argparse.ArgumentParser(prog="_resolve_changelog.py", description=__doc__.split("\n\n")[0])
    p.add_argument("--base", required=True)
    p.add_argument("--source", required=True)
    p.add_argument("--parent", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--anchor", default="## Unreleased")
    a = p.parse_args()
    for flag, path in (("--base", a.base), ("--source", a.source), ("--parent", a.parent), ("--out", a.out)):
        if not os.path.isabs(path):
            fail(EXIT_USAGE, f"{flag} must be an absolute path: {path}")
    for flag, path in (("--base", a.base), ("--source", a.source), ("--parent", a.parent)):
        if not os.path.isfile(path):
            fail(EXIT_USAGE, f"{flag} file not found: {path}")

    base, source, parent = read(a.base), read(a.source), read(a.parent)
    parent_lines = set(parent.split("\n"))
    added = [l for l in source.split("\n") if l.strip() and l not in parent_lines]
    if not added:
        fail(EXIT_ABORT, "the picked commit adds no line to the changelog; resolve by hand")
    anchor_block = a.anchor + "\n\n"
    if base.count(anchor_block) != 1:
        fail(EXIT_ABORT, f"anchor {anchor_block!r} occurs {base.count(anchor_block)} times on the release branch (need 1)")
    present = [l for l in added if l in base.split("\n")]
    if present:
        fail(EXIT_ABORT, f"{len(present)} added line(s) already present on the release branch: {present[0][:80]!r}")
    inserted = "\n".join(added) + "\n\n"
    out = base.replace(anchor_block, anchor_block + inserted, 1)
    if out.replace(inserted, "", 1) != base:
        fail(EXIT_ABORT, "self-check failed: removing the inserted block does not give back the release branch file")
    with open(a.out, "w", encoding="utf-8") as fh:
        fh.write(out)
    print(f"resolved: inserted {len(added)} lines under {a.anchor!r}")
    for l in added:
        print(f"  + {l[:120]}")


if __name__ == "__main__":
    main()
