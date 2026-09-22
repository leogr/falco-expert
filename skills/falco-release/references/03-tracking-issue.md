# 03. Tracking issue

The tracking issue is the single public place where the release's downstream work is recorded: component releases, driver decisions, release manager, blockers, tests, announcements. Its body is a checklist that many people read at a glance; its comments are the log. The agent edits the body only through the guarded flow and posts comments only in the maintainer's voice and on their go.

## Drafting

1. Start from the release template in the component repository's release document and from [`templates/tracking-issue-body.md`](../templates/tracking-issue-body.md). Fill what is done and what is missing from the inventory ([`01-inventory-and-chains.md`](01-inventory-and-chains.md)).
2. Keep the **hard ordering constraints** in the body (which component ships before which); required component releases are givens, not options; no placeholders left in.
3. Post with the milestone and the kind label (through Prow commands in the body or a comment, as the template shows), then verify the stored body matches the reviewed draft by fetching it back.
4. Immediately store the fetched body as the **stored copy** and the **snapshot** in the release state directory: the edit guard depends on them.

## Synthetic body rules

Each item is a checkbox, a short label, a pointer, and at most a few words of status with a short date:

```markdown
- [x] release `<version>` 👉 <release-url> (<short date>)
- [ ] pin `<version>` in <consumer> 👉 <pr-url>
```

- **Cut what a reader gets by clicking**: no root causes, verification steps, hashes, or decision rationale in the body. Details live in the linked PRs, issues, and reports under `OUTPUT_DIR`.
- **Never annotate a state GitHub already renders**: no `(merged)`, `(closed)`, `(done)` next to a ticked item that links a PR or issue. An annotation must add information the link does not carry: a consequence, a blocker, a decision, a date that matters, a follow-up pointer. If the only thing to say is the item's state, tick the box and say nothing.
- **Short dates are allowed in the body** (they mark when a step happened and the UI shows nothing per line), never in comments.
- **References go in sub-lists, one per line**, never inline in a sentence: GitHub expands each reference into icon plus title, and an inline list becomes a wall of text.
- **Notes** only for decisions recorded nowhere else, one or two lines each. Cut a line that grows past two lines.
- A new blocker goes in the body under its component; the comments are the log.
- Follow-ups the release depends on become issues in the owning repositories and checkboxes here.
- An embargoed item is one opaque line ([`10-agent-rules.md`](10-agent-rules.md#embargoed-items)).

## Edit guard flow

Every body edit goes through [`scripts/tracking-body-edit.py`](../scripts/tracking-body-edit.py), which keeps three copies honest: the **stored** copy (what the agent last knew), the **snapshot** (the last body it applied), and the **live** body.

1. Express edits as **line prefixes** (tick the unique line starting with this prefix, replace it, insert after it). Prefix edits tolerate lines the maintainer already ticked, and the guard aborts before any write when a prefix matches zero or several lines.
2. **Dry run** first (default): the script prints the unified diff and the checked/unchecked counts. Show that to the maintainer; a body edit is a public action and needs its go, unless the maintainer has delegated routine ticks for the day.
3. `--apply` re-fetches the live body, strips trailing newlines on both sides (reading through a JSON query appends one, and without the strip every edit grows the body by a blank line), aborts on drift with `ABORT:`, applies, re-fetches, compares, then updates the stored copy and the snapshot.
4. On `ABORT:` (the maintainer edited live): run `--resync` to copy live into stored and snapshot, re-derive the edit from the new body, dry run, apply.
5. Absolute paths only; the guard never changes directory. When the snapshot is gone (temporary directory wiped), the stored copy under `OUTPUT_DIR` plus a live fetch are enough.
6. Gate scripts that inspect a diff look only at changed lines (`^[+-]`, minus the file headers); a pattern matched on a context line is a false positive that blocks a correct edit.

Derive the next edit from the previous one by changing only the prefixes; the guard logic stays identical.

## Periodic re-check

Re-check the live body against the stored copy at the start of every day and before every edit. The maintainer ticks items directly; that is normal, and the guard handles it through `--resync`. Patch surgically after re-fetching; never rewrite the whole body from memory.

After every candidate test pass, tick fully passed items with the candidate noted; a partially covered item gets a ticked sub-item plus an open sub-item naming what is left; the parent stays open until every sub-item closes. Skipped items stay untouched, with the reason recorded in the report and the state file.

## Status comments

Comments are the log and the community's window on progress. Post them on the maintainer's go, in their voice ([`templates/status-comment.md`](../templates/status-comment.md)):

| Moment | Content |
|---|---|
| Recap (end of an active day or week) | Opener, one bullet per component (merged, in review, moved, declined), a sub-list of references one per line, the next steps in order, a short closer |
| Candidate announcement | Candidate name and link, the component versions it ships (verified at the tag), what changed since the previous candidate, whether it is expected to be the last, how to try it (image tag, package bucket links) |
| Freeze | Milestone state, freeze reached, only agreed fixes onto the release branch from now, the planned remaining changes (usually pins) |
| Delay notice | The candidate out, the abstract reason for the delay, thanks |
| Pre-tag announcement | One line saying the release is being cut; no date |

Rules that hold for every comment:

- **No dates**: the UI shows the timestamp. Grep the draft for month names and dates before posting.
- **No narrative, no `cc`**, no pings unless the maintainer lifted the rule for that comment.
- **Technical strings from sub-agents** (macro names, log messages, metric names, versions) are verified against the sources before posting; claims that cannot be verified are removed.
- **From a file**: `gh issue comment <n> -R <repo> --body-file <abs path>`. The draft stays under `OUTPUT_DIR`.
- **Verify after posting** by fetching the comment; a slip (a date, a wrong number) is fixed by editing the comment at once.
- The maintainer reviews the draft before posting, always.

## Checklist

- [ ] Draft built from the template with the hard ordering constraints, no placeholders, milestone and kind label
- [ ] Posted body fetched back, compared with the draft, stored as stored copy and snapshot under `OUTPUT_DIR`
- [ ] Every item is checkbox, label, pointer, a few status words; no redundant state annotations; references in sub-lists
- [ ] Every edit goes through the guard: dry run shown, go received (or delegation recorded), `--apply`, `GUARD_OK`, stored and snapshot updated
- [ ] Live body re-checked daily and before each edit; `--resync` used on drift
- [ ] Test results ticked per item with candidate noted; partial items split into sub-items
- [ ] Status comments drafted from the template, in the maintainer's voice, without dates, from a file, verified after posting
