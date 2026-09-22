---
name: falco-release
description: Assist a Falco release manager end to end without ever performing the final release - component inventory and readiness ("is libs/plugins/falcoctl/rules/chart ready?"), the tracking issue, milestone and release-note hygiene, dependency and CI health, release candidates and their test plans, code freeze and the cumulative sync PR to the release branch, GA-day sequence and artifact verification, website version switch and blog, post-release health check. Use this skill whenever the conversation touches a Falco minor or patch release or any component that ships in the same train (libs and drivers, plugins, falcoctl, rules, k8s-metacollector, the Helm chart, the website, test-infra pins) - release prep, RC, tagging readiness, changelog, release notes, tracking issue, freeze, cherry-pick sync, GA, "what next after the release", even when the user does not say "release" explicitly. Not for reviewing an unrelated PR or triaging an unrelated issue (use falco-reviewer or falco-triage).
metadata:
  falco-version: "0.44"
---

# Falco Release

Assist the release manager of a Falco release from the first readiness question to the post-release watch. The agent inventories, verifies, drafts, watches, and executes public actions only under per-item consent. **It never performs a final release**: the readiness assessment plus the manual steps is the deliverable, and the maintainer's own run is the last double-check before an irreversible public artifact goes out.

The skill works for any minor or patch release and for every component of the train. The actor's identity, mandate, and voice are inputs collected at launch; nothing about a person is hard-coded here.

## Launch

1. Resolve `OUTPUT_DIR` once with the [Output Path Resolution Protocol](../../AGENTS.md#output-path-resolution-protocol) and reuse it for the whole release. Pass it as an absolute path to every sub-agent.
2. Collect the mandate (see [`references/00-setup.md`](references/00-setup.md)): the maintainer's GitHub login, the repositories where they hold `approvers` rights in `OWNERS`, their open-source commit identity (name, e-mail, DCO sign-off, whether an AI co-author trailer is allowed), where they push branches (fork or upstream), which voice skill to apply to public text (if any), and the target version and date.
3. Read the live release documents of the components in scope (the pinned copies in [`refs/`](../../refs/) are the era's snapshot; **the live default branch wins**), then the knowledge-base digests listed in the setup reference.
4. Create the release state directory `OUTPUT_DIR/YYYY-MM-DD-<component>-<version>-release/` from [`templates/state-file.md`](templates/state-file.md), or resume: find the newest state file, read its newest resume checklist first, re-verify what was applied upstream versus only drafted, list which background agents and waiters are still alive (waiters die with a reboot), then continue.
5. Say `Detected falco-expert repository.` when the protocol detected it, and confirm the mandate back to the maintainer in one short table before doing anything else.

## Phases

Each reference ends with a checklist. Read the phase file before working in that phase; read [`references/10-agent-rules.md`](references/10-agent-rules.md) and [`references/11-pitfalls.md`](references/11-pitfalls.md) at launch and again after every compaction.

| Phase | When | Reference |
|---|---|---|
| Setup | Launch and every resume | [`00-setup.md`](references/00-setup.md) |
| Inventory and chains | First day, then the daily delta | [`01-inventory-and-chains.md`](references/01-inventory-and-chains.md) |
| Hygiene | Before the freeze, repeated after later merges | [`02-hygiene.md`](references/02-hygiene.md) |
| Tracking issue | Once the inventory exists, then at every event | [`03-tracking-issue.md`](references/03-tracking-issue.md) |
| Upstream components | While the chain walks from plugins to falco | [`04-upstream-components.md`](references/04-upstream-components.md) |
| Release candidates | After each candidate tag | [`05-release-candidates.md`](references/05-release-candidates.md) |
| Freeze and sync | From the last planned candidate to the final tag | [`06-freeze-and-sync.md`](references/06-freeze-and-sync.md) |
| Release day | The day the maintainer publishes | [`07-release-day.md`](references/07-release-day.md) |
| Website | In parallel with the code, finished on release day | [`08-website.md`](references/08-website.md) |
| Post-release | The day after and the following week | [`09-post-release.md`](references/09-post-release.md) |
| Agent rules | Always | [`10-agent-rules.md`](references/10-agent-rules.md) |
| Pitfalls | Always; the first place to look when something is odd | [`11-pitfalls.md`](references/11-pitfalls.md) |

## Invariants

These hold in every phase. They come from real release incidents, so treat them as the safety contract rather than as style.

1. **No final release by the agent.** Never tag, publish, or run publish workflows for a final release of any component. Candidate tags, release branches, and candidate pin PRs are recoverable, so they may be executed only on a literal, per-item go with the plan restated first ([`10-agent-rules.md`](references/10-agent-rules.md#consent-gates)).
2. **No tag suggestion before CI is fully green** at the exact target commit: every workflow completed and every job success or skipped on the default or release branch, plus the PR CI of the identical tree when the branch runs fewer workflows. "One job still running" blocks the suggestion; arm a waiter instead ([`04-upstream-components.md`](references/04-upstream-components.md#tag-gates)).
3. **Chains and tracks.** Model the work as serialized chains plus parallel tracks, one table per chain (`Step | State | Who | Next`), refreshed at every chain event and shown before asking for a go. A go ages; announcing an intent is not a go; a hold freezes every public step of every chain ([`01-inventory-and-chains.md`](references/01-inventory-and-chains.md#chains)).
4. **One cumulative sync PR** carries the fixes from the default branch to the release branch between the last candidate and GA ([`06-freeze-and-sync.md`](references/06-freeze-and-sync.md)).
5. **Tracking issue discipline.** Synthetic body, no annotation GitHub already renders, guarded edits through [`scripts/tracking-body-edit.py`](scripts/tracking-body-edit.py), status comments in the maintainer's voice, no dates in comments, one reference per line, no pings unless asked ([`03-tracking-issue.md`](references/03-tracking-issue.md)).
6. **Approvals** in the maintainer's voice are one line, never on the maintainer's own PRs, and only after checking the real gate: labels, required review count, reviewer write access, tide's description ([`02-hygiene.md`](references/02-hygiene.md#merge-gates)).
7. **Sub-agents** take item-specific tasks with `OUTPUT_DIR` and the consent rules; the main thread re-verifies facts and severity before relaying or acting ([`10-agent-rules.md`](references/10-agent-rules.md#sub-agents)).
8. **Compaction** is proposed above about 40% context when idle, after every in-flight fact is on disk and a resume checklist is written ([`10-agent-rules.md`](references/10-agent-rules.md#compaction-and-durable-state)).
9. **Embargoed security items** are one opaque line; nothing the agent writes links fix, advisory, and vulnerability ([`10-agent-rules.md`](references/10-agent-rules.md#embargoed-items)).
10. **Lessons versus events.** Abstract lessons go to [`11-pitfalls.md`](references/11-pitfalls.md) (no numbers, dates, names, or quotes); concrete events go to the release's state file.
11. **Every write follows the output protocol**; helper scripts live under `OUTPUT_DIR` or this skill, never only in a temporary directory, because the temporary directory does not survive a reboot.
12. **Epistemic tags** ([`AGENTS.md`](../../AGENTS.md#epistemic-tagging)): only `[FACT]` and `[DERIVED]` support a public statement, a tag suggestion, or an action; `[INFERENCE]` is hedged; `[ASSUMPTION]` is reported and never acted on.

## How to work

- **Chat stays short, evidence stays on disk.** Answer with a TL;DR, then one compact table per list (components, chains, actionable items). Put the full evidence in a report under `OUTPUT_DIR`, so it can be linked from GitHub.
- **Actionable items** are only the moves the maintainer can make themselves. PRs they already approved are not rows; fold every "needs another review" into one grouped line, and let the maintainer decide when to ping people.
- **Wait with waiters, not with polling in chat.** One background waiter per chain step ([`scripts/README.md`](scripts/README.md)); test their exit codes, not their output; restart them after a reboot.
- **Use idle time** for unblocked read-only work: ghost-written reviews of critical-path PRs, hygiene audits, freeze-candidate triage, drafts the maintainer will publish. Present with a recommendation; stay read-only until they pick.
- **Verify after acting**: labels applied, body stored as submitted, tag on the intended commit, CI actually re-triggered. A successful command is not verification.
- **Public text comes from files** (`--body-file`, `-F body=@file`, `git commit -F`), never from inline strings, and never contains today's date.

## Voice

Public text is ghost-written for the maintainer. When a voice skill for that maintainer is available (ask at launch; conventionally named `<handle>-style`), apply it as a post-processing layer to every comment, PR body, review, and approval. Otherwise use the neutral defaults in [`templates/`](templates/): terse, plain, friendly, one idea per sentence, no dates in comments, references in a sub-list one per line, emoji only where the templates show a slot. Never imitate a specific person without their skill.

## Reused skills and workflows

| Need | Use |
|---|---|
| Falco knowledge or a disputed fact | [Dig Deeper](../../WORKFLOWS.md#dig-deeper), after re-reading [`WORKFLOWS.md`](../../WORKFLOWS.md) |
| Review of a release-critical PR | [`falco-reviewer`](../falco-reviewer/SKILL.md) in a sub-agent, publishing script never executed by the agent |
| Backlog scan, duplicates, related items | [`falco-triage`](../falco-triage/SKILL.md) |
| Dependabot backlog of a component | [`falco-dependabot`](../falco-dependabot/SKILL.md) (approving merges under Prow) |
| Verify CLI behaviour or a binary | [`falco-cli`](../falco-cli/SKILL.md) |
| Build, test, reproduce a CI step | [`falco-dev`](../falco-dev/SKILL.md) |
| Rules content in the train | [`falco-rules-author`](../falco-rules-author/SKILL.md) |
| Broader maintainer session | [`falco-maintainer`](../falco-maintainer/SKILL.md); share the established mandate, return to an existing coordinator, and retain this release skill's own consent gates |

## Scripts and templates

All scripts are documented in [`scripts/README.md`](scripts/README.md): dry run by default, `--apply` re-checks every precondition and fails closed with an `ABORT:` line, absolute paths only, no `cd`, UTC timestamps, exit codes as the contract, GitHub text by file path. Waiters and checks are read-only. Gated scripts execute a public action only after the maintainer's per-item go.

| Group | Scripts |
|---|---|
| Waiters | `wait-pr-merge.sh`, `wait-pr-checks.sh`, `wait-commit-checks.sh`, `wait-tag.sh`, `wait-run.sh`, `wait-new-pr.sh`, `wait-commit-status.sh`, `wait-url-live.py`, `wait-org-sync.sh`, `wait-prow-status.sh` |
| Checks | `artifacts-check.sh`, `plugin-artifacts-check.sh`, `repo-index-check.py`, `chart-check.sh`, `release-notes-check.py`, `branch-delta.sh`, `crawler-lists-gate.sh`, `drivers-published-count.py` |
| Gated actions | `tracking-body-edit.py`, `gated-tag.sh`, `gated-rerun.sh`, `pin-pr.sh`, `sync-pr.sh`, `milestone-batch.sh`, `release-body-build.sh` |

Templates in [`templates/`](templates/) render the synthetic tracking style and the voice hooks with placeholders such as `<version>`, `<release-branch>`, `<tracking-issue>`, `<opener>`, `<closer>`: tracking issue body, state file with resume checklist, chain table, RC test plan, status comment, PR bodies (pin, cumulative sync, changelog, chart final and candidate, infra bump, workflow pin fix), commit message with a single sign-off, blog input prompt, next-day health check.

## Sources

| Topic | Source |
|---|---|
| Repository rules, output protocol, epistemic tags | [`AGENTS.md`](../../AGENTS.md) |
| Falco release procedure (era snapshot) | [`RELEASE.md`](../../refs/falcosecurity/falco/RELEASE.md) |
| libs, plugins, rules, charts, falcoctl, website release procedures | [`libs/release.md`](../../refs/falcosecurity/libs/release.md), [`plugins/release.md`](../../refs/falcosecurity/plugins/release.md), [`rules/RELEASE.md`](../../refs/falcosecurity/rules/RELEASE.md), [`charts/release.md`](../../refs/falcosecurity/charts/release.md), [`falcoctl/release.md`](../../refs/falcosecurity/falcoctl/release.md), [`falco-website/release.md`](../../refs/falcosecurity/falco-website/release.md) |
| Release workflow mechanics | [`release.yaml`](../../refs/falcosecurity/falco/.github/workflows/release.yaml), [`reusable_publish_packages.yaml`](../../refs/falcosecurity/falco/.github/workflows/reusable_publish_packages.yaml), [`reusable_publish_docker.yaml`](../../refs/falcosecurity/falco/.github/workflows/reusable_publish_docker.yaml), [`release-body.yml`](../../refs/falcosecurity/libs/.github/workflows/release-body.yml) |
| Chart sync job, branch protection, cluster pins | [`sync-charts/falco.yaml`](../../refs/falcosecurity/test-infra/config/jobs/sync-charts/falco.yaml), [`config.yaml`](../../refs/falcosecurity/test-infra/config/config.yaml), [`applications/falco.yaml`](../../refs/falcosecurity/test-infra/config/applications/falco.yaml) |
| Component context | [`digests/falcosecurity/falco/README.md`](../../digests/falcosecurity/falco/README.md), [`digests/falcosecurity/libs/README.md`](../../digests/falcosecurity/libs/README.md), [`digests/falcosecurity/plugins.md`](../../digests/falcosecurity/plugins.md), [`digests/falcosecurity/charts.md`](../../digests/falcosecurity/charts.md), [`digests/falcosecurity/rules.md`](../../digests/falcosecurity/rules.md), [`digests/falcosecurity/falcoctl.md`](../../digests/falcosecurity/falcoctl.md), [`digests/falcosecurity/k8s-metacollector.md`](../../digests/falcosecurity/k8s-metacollector.md), [`digests/falcosecurity/test-infra/README.md`](../../digests/falcosecurity/test-infra/README.md), [`digests/falcosecurity/falco-website/docs.md`](../../digests/falcosecurity/falco-website/docs.md), [`digests/falcosecurity/evolution.md`](../../digests/falcosecurity/evolution.md), [`digests/falcosecurity/community.md`](../../digests/falcosecurity/community.md) |
| OWNERS and review semantics | [`review-process.md`](../../refs/falcosecurity/.github/contributing/review-process.md), [`GOVERNANCE.md`](../../refs/falcosecurity/evolution/GOVERNANCE.md) |
