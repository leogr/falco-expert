# 06. Code freeze and the cumulative sync PR

The freeze separates "what goes in" from "what waits". After it, agreed fixes reach the release branch through a single cumulative sync PR so that reviewers see one place. The changelog follows once the contents are settled; the final tag is gated on green CI at that resulting commit.

## Announcing the freeze

- Announce the freeze on the tracking issue once the last planned candidate is out and the milestone has no open code changes left except pins ([`templates/status-comment.md`](../templates/status-comment.md), freeze variant): milestone state, freeze reached, release branch open, only fixes cherry-picked from now, the planned remaining changes named.
- Tick the freeze item in the tracking body through the guard.
- The thaw is announced after the final release.

## Inclusion criteria for late fixes

Include when the fix addresses a problem users hit in an evident way; let it wait when a mitigation exists or it is an edge case. Evaluate with evidence: who is affected, how visible, workaround, blast radius, and judge by how the consumer actually calls the code, not by how the unit tests do.

Present the decision as options with costs ([`01-inventory-and-chains.md`](01-inventory-and-chains.md#slip-or-cut)):

| Option | Typical cost |
|---|---|
| Tag as is, fix in the next patch | Users hit the defect; patch release cost later |
| Land the fix, then tag | Reviews, CI, possibly a new candidate and a shorter soak |

A late, tiny, low-risk fix may enter the release branch after the last candidate when the maintainer decides so: record the decision and its rationale in the state file, cherry-pick after the merge, and keep the final tag gated on green CI at its commit.

Every fix accepted after a candidate decides whether a **new candidate is needed**: a driver change also moves the driver tag; a packaging change needs the upgrade test again; a feature accepted late moves the plan (a new candidate follows its merge, the cumulative sync PR merges before that candidate, and the soak before GA shrinks). State the calendar consequence when the maintainer decides.

Hot-path fixes (per-event handlers, fetcher loops, parsers) are never declared fine on the implementer's word: a draft PR for real-runtime CI plus an independent correctness and performance review first ([`10-agent-rules.md`](10-agent-rules.md#severity)).

## One cumulative sync PR

Between the last candidate and GA, fixes reach the release branch through **one** cumulative sync PR ([`scripts/sync-pr.sh`](../scripts/sync-pr.sh), [`templates/pr-body-sync.md`](../templates/pr-body-sync.md)):

1. Open it with the first cherry-pick: `/kind release`, `/area build` (and `/area chart` when chart files are included), `release-note NONE`, "Part of" the tracking issue, a sub-list of the cherry-picked source PRs one per line.
2. Append each new cherry-pick as its fix merges, with plain pushes (never force), and keep the body list current with `--existing-pr`.
3. Hold it (`/hold`) so an early approval cannot merge it before the last fix is in.
4. Cherry-picks keep the original author and sign-off, set only the committer identity, no `-x`. Before pushing, compare every picked commit with its source range using `git patch-id`; abort on a mismatch.
5. List it once under "Release blocking PRs" in the tracking issue as the cumulative sync.
6. Merge it after the last agreed code and pin changes, before finalizing the changelog PR: a push dismisses earlier approvals, so the final approvals come at the end. Re-verify the release branch head against the reviewed tree (tree hash equality, [`scripts/branch-delta.sh`](../scripts/branch-delta.sh)); a three-dot compare counts rebased cherry-picks as divergence and must not be used for this. Then follow the [pre-tag sequence](07-release-day.md#pre-tag-sequence-release-branch), including the changelog merge and CI at the resulting commit.

Component pin PRs follow the same path: open on the default branch, then cherry-pick into the release branch or into the cumulative sync PR. Chart changelog bullets conflict on cherry-pick: they go under the release branch's own unreleased section (the sync script's changelog helper does this); the chart release PR folds them later.

## Ordering of conflicting PRs

Two open PRs touching the same symbol must merge in a known order: the second one rebases, and tide does not re-run pull-request workflows, so a PR whose checks passed before the first merge can land broken. Hold the follower until the leader is in; cherry-pick both in order with patch-id checks.

## Release branch versus default branch

- Keep the release branch a subset of the default branch (plus release-only metadata such as the chart version). Inspect the two-dot diff and record intentional exclusions. For patches, the approved backport list defines scope; next-minor work stays on the default branch. Require tree equality between the reviewed release PR and the resulting release head, not between the release and default branches.
- The release branch can run fewer workflows on push than the default branch (the full build may be pull-request-only). The tag gate then combines the branch's own runs at the exact commit with the pull-request CI on an identical tree, verified by tree hash, plus the default-branch run of the same sources when it exists.
- Prefer fixes that keep a shared test suite untouched when another repository floats on this repository's default branch; a cross-repository change needs a transitional accept-both step.

## Checklist

- [ ] Freeze announced on the tracking issue and ticked; the remaining planned changes named
- [ ] Every late fix evaluated with evidence and decided by the maintainer; decision and rationale in the state file
- [ ] New-candidate decision taken and its calendar consequence stated for every accepted post-candidate change
- [ ] Exactly one cumulative sync PR open against the release branch, held, body listing every source PR one per line, listed once in the tracking issue
- [ ] Every cherry-pick patch-id-compared with its source before pushing; author and sign-off preserved
- [ ] Conflicting PRs merged in a known order; followers held until leaders land
- [ ] Sync PR merged after the last agreed code and pin changes, final approvals after the last push, release branch tree verified against the reviewed tree; changelog merge and final CI follow before the tag
