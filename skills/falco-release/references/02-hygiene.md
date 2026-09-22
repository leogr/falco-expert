# 02. Hygiene: dependencies, CI health, milestone, release notes, freeze candidates

Hygiene work is mostly read-only and parallelizable, so it fills the gaps while chains wait. Its findings feed the tracking issue and the freeze decisions; its public actions (approvals, release-note edits, milestone moves) are consent-gated like everything else.

## Dependency alerts and bot PRs

Per repository in the train:

- For each open Dependabot alert read the advisory's real vulnerable range and first patched version (`gh api advisories/<GHSA>`). "No patched version" cannot be fixed by a bump: the honest outcomes are a dismissal with a written reachability rationale, or a tracked migration to the successor module. A downgrade inside the range fixes nothing even if a scanner stops reporting it.
- Verify reachability with the build graph (`go mod why`, the linker's inputs), never by reading the module file, and compare with the upstream advisory's affected package, which is often narrower than GitHub's normalization.
- Auto-generated fix PRs are claims to verify. Cross-repository bumps: fix and tag upstream first, then bump downstream. Reproduce build failures locally to get the real error; distinguish pre-existing failures from regressions by running the same tests on an unmodified baseline.
- Clear the bot PR backlog with [`falco-dependabot`](../../falco-dependabot/SKILL.md): oldest to newest, rebase, wait for checks (excluding `tide`), approve when green, stop on red. Batch only PRs that are green on a fresh head and not expected to conflict. Under Prow with `review_acts_as_lgtm`, approving is merging.
- Bot PRs sharing a manifest get auto-rebased after each sibling merge, which restarts their CI: approve back-to-back once green and re-derive run IDs from the current head after every rebase. Dependabot silently closes a PR as superseded when the bump arrives transitively.
- A bot bump of a shared internal module consumed through a local `replace` cannot pass alone: the consumer side needs a human commit plus whatever version bump the consumer's release policy requires. Recognize the pattern from the file list.
- Alert dismissal comments are length-capped; check before the call, and re-list the alerts for the same package afterwards.

## CI health

Check CI health before working a backlog, accounting for path-gated workflows: look at PR runs for the affected path, not only the default branch.

- **Several unrelated PRs failing identically point at the environment.** Confirm with a last-green/first-red table built from check-run timestamps and diff the environment (runner image, tool versions). A rerun on the same broken environment fails identically: check the environment identifier of each attempt. Mixed pass/fail across architectures of one PR is itself evidence of an environmental cause.
- **Read the full log for the exact error**, then trace it through the tools' source at their pinned versions. Establish the mechanism, not the correlation. In a failed job log find the step that actually failed, not the first `Error:` line: some third-party actions log loud non-fatal errors that also appear in passing jobs. Error lines can be block-buffered and flushed at the end of the log, far from the progress output: grep the whole log for the error pattern before saying a component ran clean. Logs of an in-progress run come from the jobs logs API; strip ANSI codes before grepping.
- **Check upstream trackers** for known regressions and rollbacks before writing a fix. Land a hardening fix even when the environment heals itself, if the latent incompatibility persists against newer tools.
- **Communicate**: an awareness issue listing the affected PRs, stating they are not at fault, asking contributors not to churn branches; then re-trigger CI (bot rebase for bot PRs, rerun of failed jobs for human PRs). Record head SHAs before asking for rebases; fall back to a rerun when the bot answers "already up to date". After the fix lands: rebase bot PRs whose fixed jobs keep failing; rerun failed jobs where passes already exist; ask human authors to rebase when the fix must be in the head.
- **Rerunning only failed jobs** keeps earlier passes, so retries converge under a partial rollout, but it can break artifact consumers: when a retry surfaces a new failure class, read it before retrying. Artifact plumbing means rerun the whole run; a real validation failure belongs to the author. Use [`scripts/gated-rerun.sh`](../scripts/gated-rerun.sh): it re-runs only when the log matches an infrastructure pattern and the external dependency answers again.
- **Image builds that install packages from external archive mirrors** fail on the mirror's timeouts, on the default branch and in the release workflow alike. Read the step log, confirm the mirror answers again, re-run the failed jobs; never re-tag for an infrastructure failure. Build containers based on an end-of-life distribution break when the archive removes binaries or the signed index expires: check EOL dates against the release calendar, fix the source (a frozen snapshot mirror for the whole suite, validity check disabled where the official image does so), apply it to every workflow on the same base image, and add a loud guard so the step fails instead of silently building without the suite.
- **A failure right after a merge is not necessarily caused by it**; compare with the last green run of the same job. Dependency bumps in one repository can break tooling in another: when a publish workflow goes red after bot merges, check whether the release workflow shares the same reusable job before tagging.
- **Check-runs on a commit can come from apps other than the CI** (runner providers, security scanners). The CI gate reads the CI app's check-runs and the workflow-run conclusions; an extra check-run is neither counted nor dismissed unread: find its origin and the outcome of the real job it refers to.
- **A small, well-evidenced fix PR** (mechanism explained, verification recorded, the log kept as evidence, reproduced locally in the same image before opening it) gets merged quickly; write it for a reviewer with no context, as small PRs where the maintainer conventionally pushes.
- **Reviewing a CI guard**: run the new check against the real artifact in the real job environment. A PR that edits a path-filtered workflow file does not exercise itself; suggest including the workflow file in its own paths.
- **Fork runs**: workflows of a PR from a first-time contributor do not start until a maintainer approves them (`conclusion: action_required`), and `gh pr checks` then lists only `dco` and `tide`, which looks like CI never ran. List runs by head SHA and approve the `action_required` ones (consent-gated); repeat after every push, including a maintainer's takeover push.
- **Proving a red check unrelated to a PR**: an attempt-by-job-by-environment table from the run-attempts API showing the outcome is a function of the environment, plus a check of the failing assertion's fields against the PR's diff surface. Approve with the justification in the review body only when merging is the intended outcome.
- **Nightly kernel failures**: attribute by the date of the kernel package bump, not by upstream commits, and check architecture gating before calling it infrastructure.

## Merge gates

Before calling any PR mergeable, read the real gate, not the presence of green checks:

1. **tide's description is authoritative** for the blocker: `gh api repos/<r>/commits/<head>/status --jq '.statuses[] | select(.context=="tide") | .description'`. "Needs approved, lgtm labels" with red CI means the PR is awaiting review, not CI-blocked. "PR can't be rebased" can be stale (tide recomputes only when the PR is in its pool); re-verify with a local rebase.
2. **Labels**: Prow repositories gate on `lgtm` and `approved`. A GitHub approving review reliably yields `lgtm` (`review_acts_as_lgtm`); `approved` sometimes never lands and a follow-up `/approve` can go unanswered. Verify both labels and, when the approver is entitled, propose adding `approved` by hand.
3. **Required reviews**: read `branches/<b>/protection/required_pull_request_reviews`. Core repositories require two approving reviews on the default and release branches; the author never counts, and `dismiss_stale_reviews` drops approvals at every push. A maintainer-authored release PR therefore needs two other maintainers from the start.
4. **Write access**: an approving review counts toward protection only if the reviewer has write access (`gh api repos/<r>/collaborators/<user>/permission`). Access granted later through the org configuration counts retroactively once the sync lands.
5. **Required contexts** differ per repository: read the protection's `required_status_checks`. Informational checks (coverage, performance baselines, linting in some repositories) do not block; treat a red informational check as a fact to explain, not as "CI failing".
6. **Prow may auto-apply `approved`** to approver-authored PRs; that is not merge-readiness, `lgtm` from another maintainer is still needed. Automatic bot holds are prompts, not findings: decide against the rule with the diff in hand and unhold with the reasoning on record.
7. **tide rebase-merges without retesting the combination**: batching approvals lands commits CI never validated together. Simulate locally when several PRs touch the same manifest.

Approvals in the maintainer's voice are one line; the evidence lives in the report. Approve only when merging is the intended outcome, and never on the maintainer's own PRs.

## Milestone hygiene

- **Missing milestones**: search merged PRs and closed issues since the previous tag (search API, paginated), classify before assigning: next milestone for default-branch merges after the branch point, patch milestone for release-branch cherry-picks, none for stale-closed or user-side items. Never blanket-assign. Use [`scripts/milestone-batch.sh`](../scripts/milestone-batch.sh) with a classified items file.
- Before triaging a closing upstream milestone make sure the next one exists; creating it is cheap, moving items is a decision taken after the go/no-go. Rename a rolling milestone (for example the driver's) to the concrete version before the tag, so the release notes have a milestone.
- Distinguish interim "pin to a commit" PRs from the final version-pin PR; the tracking issue points at the latter.
- An upstream `Fixes` reference can close a downstream issue early: check the close event against the upstream merge and reopen so the milestone stays honest.

## Release-note audit

For every merged PR in the milestone ([`scripts/release-notes-check.py`](../scripts/release-notes-check.py)):

| Finding | Fix |
|---|---|
| No `release-note` block | Ask the author or add `NONE` with the Prow command |
| Empty block or template placeholder | `NONE` |
| Free text not in Conventional Commits form (`type(scope)!: description`) | Rewrite into one line |
| Multi-line note | One line |
| Breaking change without the explicit line naming what changed | Add it |
| Behaviour change hidden behind `NONE` | A one-liner |
| `NONE` without the `release-note-none` label | Relabel |

Fix notes on merged PRs with the Prow release-note command or a body edit; it relabels within a minute. Verify, and repeat the audit for PRs merged later. Generate the changelog locally before the final tag and review it as a reader would.

## Freeze candidate sweep

Before the freeze, sweep every open PR in the milestone plus un-milestoned PRs with recent activity: blocker plus one next action each; separate "blocks the release" from "nice to have". Get the maintainer's stance per candidate early (must-fix, skip if late, wait for author, investigate) and record it.

For a candidate bug, trace the cross-reference chain to the fix PR, then assess its release readiness: holds, latest-revision CI, pending matrices, unanswered template questions, empty `Fixes`, missing release note. A fix not mergeable by the tag date is a slip-or-cut input. Judge whether a fix addresses the evident problem by how the consumer actually calls the code, not by how the unit tests do.

Re-check "no release needed" verdicts on pinned component repositories by sweeping their open PRs: an easy merge that changes content adds a tag to the chain. Classify each PR against the repository's own tide requirements and state the version bump implications.

A maintainer cannot approve their own PR, including taken-over ones; those are external waits in the tracking issue. Judge author responsiveness on every channel, including review-thread replies. Taking over an unresponsive contributor's PR is a maintainer decision: confirm the maintainer can modify it, prepare the change in a sub-agent on a fresh clone keeping the author's commits and sign-offs plus the maintainer's sign-off, verify against the reviewer's suggestions, push with `--force-with-lease=<branch>:<observed-head>`, update the PR body, leave a courtesy note, watch the previously red job; expect Prow labels to drop and fork runs to need approval again. When a rebase drops a commit that encoded a decision, prepare both outcomes and let the maintainer choose.

A downstream PR that depends on an upstream PR: verify against the pin (compare API), build and test against that exact pin; red CI from before the pin bump is not evidence; a closed upstream PR may have been superseded by a merged companion.

## Checklist

- [ ] Dependency alerts classified (fixable, dismiss with rationale, migrate); bot PR backlog cleared or scheduled through `falco-dependabot`
- [ ] Default-branch and path-gated CI health confirmed per repository; environmental failures separated from regressions with logs, not correlations
- [ ] Every PR called mergeable has its tide description, labels, required review count, reviewer write access, and required contexts recorded
- [ ] Missing milestones classified and assigned; the next milestone exists; rolling milestones renamed before their tag
- [ ] Release-note audit run on every merged PR in the milestone, repeated after later merges; changelog generated locally and reviewed
- [ ] Freeze candidate sweep done with blocker and next action per PR; the maintainer's stance recorded per candidate
- [ ] Pinned component repositories re-swept for easy merges that would add a tag to the chain
