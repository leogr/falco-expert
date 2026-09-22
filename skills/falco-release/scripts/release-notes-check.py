#!/usr/bin/env python3
"""release-notes-check.py - audit the release-note blocks of a milestone's merged PRs.

Purpose:
  The release body is generated from the ```release-note``` blocks of the PRs in the milestone
  (falcosecurity/falco .github/workflows/release.yaml, "Generate release notes" step, rn2md).
  This script enumerates the milestone's merged PRs through the GitHub search API and reports:
    - no release-note block
    - empty block (whitespace or HTML comments only)
    - block equal to a placeholder (TODO, TBD, n/a, ...)
    - multi-line note (a trailing "BREAKING CHANGE:" line is allowed by the PR template)
    - note not matching the Conventional Commits pattern  type(scope)!: description
    - note "NONE" on a PR that lacks the release-note-none label (Prow release-note plugin)
  With --issues it also reports closed issues referenced by the PRs' closing keywords
  (Fixes/Closes/Resolves #N) that are not in the milestone.
  For every finding it prints a suggested Prow command line as text (never executed).
  Prints one line per PR:  OK|ISSUE|ERROR #<n> <detail>
  and a final token: RELEASE_NOTES_OK or RELEASE_NOTES_ISSUES (always the last line).

Usage:
  release-notes-check.py --repo <owner/repo> --milestone <title> [--issues] [--placeholder TEXT ...]

Exit codes:
  0  no findings
  1  at least one finding
  2  usage error
  4  the GitHub API could not be queried or search coverage is incomplete

Read-only (gh api GET only).

Expectations come from:
  falcosecurity/falco .github/PULL_REQUEST_TEMPLATE.md   release-note block, "NONE" for no user-facing change,
                                                         commit-convention note line, optional "BREAKING CHANGE:" line
  falcosecurity/falco .github/workflows/release.yaml     rn2md builds the notes from the milestone
  falcosecurity/test-infra config/plugins.yaml           release-note Prow plugin enabled (labels release-note, release-note-none)

Example:
  release-notes-check.py --repo falcosecurity/falco --milestone 0.45.0 --issues
"""
import argparse
import json
import re
import subprocess
import sys
import urllib.parse
from datetime import datetime, timezone

DEFAULT_PLACEHOLDERS = ["todo", "tbd", "n/a", "na", "-", "release note", "release-note", "<release-note>", "your release note here"]
RN_BLOCK = re.compile(r"```release-note[ \t]*\r?\n(.*?)```", re.S | re.I)
HTML_COMMENT = re.compile(r"<!--.*?-->", re.S)
CONVENTIONAL = re.compile(r"^[a-z][a-z0-9-]*(\([^()]+\))?!?: \S.*$")
CLOSING_REF = re.compile(
    r"(?i)\b(?:close|closes|closed|fix|fixes|fixed|resolve|resolves|resolved)\b[:\s]+"
    r"(?:https://github\.com/(?P<owner>[\w.-]+)/(?P<repo>[\w.-]+)/issues/|(?P<slug>[\w.-]+/[\w.-]+)?#)(?P<num>\d+)"
)


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def gh_api(path, paginate=False):
    """Run `gh api` and return the list of JSON documents it printed (gh --paginate concatenates them)."""
    cmd = ["gh", "api"]
    if paginate:
        cmd.append("--paginate")
    cmd.append(path)
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode:
        raise RuntimeError(f"gh api {path} failed: {proc.stderr.strip()[:300]}")
    docs = []
    dec = json.JSONDecoder()
    text = proc.stdout
    pos = 0
    n = len(text)
    while pos < n:
        while pos < n and text[pos].isspace():
            pos += 1
        if pos >= n:
            break
        obj, end = dec.raw_decode(text, pos)
        docs.append(obj)
        pos = end
    return docs


def search_all(query):
    q = urllib.parse.quote_plus(query)
    docs = gh_api(f"search/issues?q={q}&per_page=100", paginate=True)
    if not docs:
        raise RuntimeError("search returned no response; coverage is unknown")
    items = []
    total = 0
    for d in docs:
        if not isinstance(d, dict) or not isinstance(d.get("items"), list) or not isinstance(d.get("total_count"), int):
            raise RuntimeError("search returned an invalid result; coverage is unknown")
        if d.get("incomplete_results") is not False:
            raise RuntimeError("search did not confirm complete results; retry or split the query")
        total = max(total, d["total_count"])
        items.extend(d["items"])
    seen = set()
    uniq = []
    for it in items:
        if it["number"] not in seen:
            seen.add(it["number"])
            uniq.append(it)
    return uniq, total


def classify_note(body, placeholders):
    """Return (kind, note) where kind is one of: none, ok, no-block, empty, placeholder, multi-line, not-conventional."""
    m = RN_BLOCK.search(body or "")
    if not m:
        return "no-block", ""
    raw = HTML_COMMENT.sub("", m.group(1))
    lines = [ln.strip() for ln in raw.replace("\r", "").split("\n") if ln.strip()]
    if not lines:
        return "empty", ""
    note = "\n".join(lines)
    if len(lines) == 1 and lines[0].strip("`").lower() in placeholders:
        return "placeholder", note
    if len(lines) == 1 and lines[0].upper() == "NONE":
        return "none", "NONE"
    main_lines = [ln for ln in lines if not ln.upper().startswith("BREAKING CHANGE:")]
    if len(main_lines) > 1:
        return "multi-line", note
    if not main_lines:
        return "not-conventional", note
    if not CONVENTIONAL.match(main_lines[0]):
        return "not-conventional", note
    return "ok", note


def build_parser():
    p = argparse.ArgumentParser(
        prog="release-notes-check.py",
        description="Audit the release-note blocks of the merged PRs in a milestone.",
        epilog="Exit codes: 0 no findings; 1 findings; 2 usage; 4 API error or incomplete coverage. "
               "Example: release-notes-check.py --repo falcosecurity/falco --milestone 0.45.0 --issues",
    )
    p.add_argument("--repo", required=True, help="owner/repo")
    p.add_argument("--milestone", required=True, help="milestone title (e.g. 0.45.0)")
    p.add_argument("--issues", action="store_true", help="also report closed issues referenced by the PRs that lack the milestone")
    p.add_argument("--placeholder", action="append", default=[], help="repeatable; extra placeholder text treated as an empty note")
    return p


def main():
    args = build_parser().parse_args()
    if "/" not in args.repo or args.repo.count("/") != 1:
        print("error: --repo must be owner/repo", file=sys.stderr)
        return 2
    if not args.milestone.strip():
        print("error: --milestone must not be empty", file=sys.stderr)
        return 2
    placeholders = set(DEFAULT_PLACEHOLDERS) | {p.lower() for p in args.placeholder}
    repo = args.repo
    ms = args.milestone

    print(f"START {now()} release-notes-check repo={repo} milestone={ms} issues={args.issues}")
    try:
        prs, total = search_all(f'repo:{repo} is:pr is:merged milestone:"{ms}"')
    except RuntimeError as e:
        print(f"ERROR search {e}")
        print(f"END {now()} prs=0 findings=0 errors=1")
        print("RELEASE_NOTES_ISSUES")
        return 4
    if total != len(prs):
        print(f"ERROR search returned {len(prs)} of {total} PRs; coverage is incomplete or inconsistent (retry or split the query)")
        print(f"END {now()} prs={len(prs)} findings=0 errors=1")
        print("RELEASE_NOTES_ISSUES")
        return 4
    prs.sort(key=lambda it: it["number"])

    counts = {}
    findings = 0
    suggestions = []

    def finding(num, kind, detail, suggest):
        nonlocal findings
        findings += 1
        counts[kind] = counts.get(kind, 0) + 1
        print(f"ISSUE #{num} {kind} {detail}")
        print(f"  suggest: {suggest}")
        suggestions.append((num, kind, suggest))

    issue_refs = {}
    for pr in prs:
        num = pr["number"]
        title = (pr.get("title") or "").strip()
        labels = {lb["name"] for lb in pr.get("labels", [])}
        kind, note = classify_note(pr.get("body") or "", placeholders)
        first = note.split("\n")[0][:100] if note else ""
        if kind == "ok":
            print(f"OK #{num} note={first!r} labels={'release-note' if 'release-note' in labels else 'no-release-note-label'}")
        elif kind == "none":
            if "release-note-none" in labels:
                print(f"OK #{num} note=NONE labels=release-note-none")
            else:
                finding(num, "none-without-label", f"note is NONE but the release-note-none label is missing ({title[:60]!r})",
                        f"comment on #{num}: /release-note-none")
        elif kind == "no-block":
            finding(num, "no-release-note-block", f"{title[:70]!r}",
                    f"edit the body of #{num} to add a ```release-note``` block, or comment: /release-note-none")
        elif kind == "empty":
            finding(num, "empty-release-note", f"{title[:70]!r}",
                    f"edit the body of #{num} with a one-line note, or comment: /release-note-none")
        elif kind == "placeholder":
            finding(num, "placeholder-release-note", f"note={first!r} ({title[:60]!r})",
                    f"edit the body of #{num} to replace the placeholder, or comment: /release-note-none")
        elif kind == "multi-line":
            finding(num, "multi-line-release-note", f"{len(note.splitlines())} lines, first={first!r}",
                    f"comment on #{num}: /release-note-edit followed by a single ```release-note``` line (BREAKING CHANGE: lines may stay)")
        elif kind == "not-conventional":
            finding(num, "not-conventional-commits", f"note={first!r} (expected type(scope)!: description)",
                    f"comment on #{num}: /release-note-edit with a ```release-note``` block such as 'fix(area): {first[:60]}'")
        if args.issues:
            for m in CLOSING_REF.finditer(pr.get("body") or ""):
                owner, rname, slug = m.group("owner"), m.group("repo"), m.group("slug")
                if owner and f"{owner}/{rname}".lower() != repo.lower():
                    continue
                if slug and slug.lower() != repo.lower():
                    continue
                issue_refs.setdefault(int(m.group("num")), set()).add(num)

    n_err = 0
    if args.issues:
        for inum in sorted(issue_refs):
            if any(p["number"] == inum for p in prs):
                continue
            try:
                doc = gh_api(f"repos/{repo}/issues/{inum}")[0]
            except (RuntimeError, IndexError) as e:
                print(f"ERROR #{inum} cannot read issue: {e}")
                n_err += 1
                continue
            if "pull_request" in doc:
                continue
            if doc.get("state") != "closed":
                print(f"OK #{inum} referenced issue is still open (state={doc.get('state')}); nothing to do for the milestone")
                continue
            ms_title = (doc.get("milestone") or {}).get("title")
            fixed_by = ",".join(f"#{n}" for n in sorted(issue_refs[inum]))
            if ms_title == ms:
                print(f"OK #{inum} closed issue in milestone {ms} (fixed by {fixed_by})")
            else:
                finding(inum, "closed-issue-without-milestone", f"milestone={ms_title!r} fixed by {fixed_by} ({(doc.get('title') or '')[:60]!r})",
                        f"comment on #{inum}: /milestone {ms}")

    print(f"SUMMARY prs={len(prs)} findings={findings} " + " ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    if suggestions:
        print("SUGGESTED_COMMANDS (text only, not executed):")
        for num, kind, sug in suggestions:
            print(f"  #{num} [{kind}] {sug}")
    print(f"END {now()} prs={len(prs)} findings={findings} errors={n_err}")
    if n_err:
        print("RELEASE_NOTES_ISSUES")
        return 4
    if findings:
        print("RELEASE_NOTES_ISSUES")
        return 1
    print("RELEASE_NOTES_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
