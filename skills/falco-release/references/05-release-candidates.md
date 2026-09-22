# 05. Release candidates

A release candidate is a recoverable public artifact: a pre-release tag whose packages land in the development buckets and whose images carry the candidate tag. Because it is recoverable, the maintainer may delegate cutting it; because it is public, the delegation is literal and per item. Everything after the tag is verification.

## Cutting a candidate

- A candidate is cut from the **release branch**. For a minor, create it from the default branch at the branch point and add branch protection the same day ([`04-upstream-components.md`](04-upstream-components.md#release-branch-protection)); for a patch, reuse the current minor's release branch with only approved backports.
- A candidate tagged from the default branch is acceptable only when the two trees differ in files the artifacts do not ship (chart metadata). The final tag still comes from the release branch. State the target branch explicitly in every tag proposal.
- Empty release bodies are the norm for candidates when the previous ones had them; the release-notes job runs only for the final release, so candidates never exercise it ([`11-pitfalls.md`](11-pitfalls.md#release-notes-tooling-runs-only-at-ga)).
- The agent cuts a candidate only on the maintainer's literal instruction, with the plan restated first (target SHA, gate status, exact command, defaults such as "both the library and the driver candidate tags", "release branch first, protection PR, matrix dispatch"), and only through [`scripts/gated-tag.sh`](../scripts/gated-tag.sh): head unchanged, tag absent, release absent, every workflow run at the target green, every CI check-run green, required upstream runs green. A conditional go ("if green, then tag") is executed by that gated script, dry run shown before the real run. An earlier go has aged after any intermediate merge.
- Delegated candidate pin PRs follow the same rule ([`04-upstream-components.md`](04-upstream-components.md#pins-with-checksums)).

## After every candidate

1. **Wait for the release run to conclude** ([`scripts/wait-run.sh`](../scripts/wait-run.sh)); read any red job's log before anything else.
2. **Verify the artifacts with the same script every time**: [`scripts/artifacts-check.sh --mode candidate`](../scripts/artifacts-check.sh) (packages in the development buckets, multi-arch image tags on both registries). Keep the workdir under `OUTPUT_DIR`.
3. **Announce** with a terse status comment on the tracking issue ([`03-tracking-issue.md`](03-tracking-issue.md#status-comments)): what it ships, what changed, how to try it, whether it is expected to be the last. No dates.
4. **Roll the candidate onto the project's own clusters** through the infra repository's deployment manifests (a PR bumping the chart and image versions; [`templates/pr-body-infra-bump.md`](../templates/pr-body-infra-bump.md)). Read the dashboards for regression signals (restarts, drops, event rates) and capture the logs of any crash-loop before they rotate. An infra repository in the middle of a migration is parked: ask before touching it.
5. **Tick the tracking issue** through the guard flow.

## Test plan

Per candidate, a numbered list of test items with the environment each needs (local container, disposable VM, cluster); [`templates/rc-test-plan.md`](../templates/rc-test-plan.md). Take the items from the tracking issue's manual-testing checklist and from the published quickstarts and package guides, followed literally with the candidate substituted so documentation defects surface with the binary's.

Items that belong in every plan:

| Item | Environment |
|---|---|
| CLI options, valid and invalid rules, plugin loading, exit codes and diagnostics | Local container with the candidate image |
| Container guide and quickstart: privileges, alerts, container metadata | Local container, BTF host |
| Capture replay against expected alerts | Local container, existing captures |
| Event generator, buffer sizes and presets, simultaneous event sources, metrics, drops | Local container |
| DEB and RPM install on the oldest supported glibc; plugin init and rules dry run | Distribution containers |
| Package guide: install, upgrade from the previous release, service restart and reboot, uninstall; kernel module through DKMS, cached reinstall, driver loader | Disposable VMs with root and matching headers |
| Helm chart and operator installs, metadata plugin, collector and runtime restarts | Disposable VM with a small Kubernetes; never a production kubeconfig |
| Every supported architecture | Native host or VM per architecture |
| Memory checkers on the debug binaries: validation, replay, error paths | Disposable development container |
| Any regression check for a defect found on the previous candidate | As the original |

Run one item at a time and save the evidence per item under `OUTPUT_DIR/YYYY-MM-DD-<component>-<candidate>-test-NN/`: commands, versions and digests (which library, driver, and plugin commits were inside), expected versus actual, logs, the report with a case count. Pin the candidate artifacts. Re-check the previous candidate's findings. A skipped item records the reason. Keep one unified report per candidate with a verdict per item ([`templates/rc-test-plan.md`](../templates/rc-test-plan.md) has both shapes). Spot-check every count in the per-item assessments before relying on them.

Delegate items to sub-agents with the evidence layout, `OUTPUT_DIR`, and the no-public-action rule ([`10-agent-rules.md`](10-agent-rules.md#sub-agents)); re-verify the load-bearing claims and the severity calls before relaying.

## Findings routing

Classify each finding as defect, environment, dependency noise, or unverified. Search for an existing issue first. Then:

| Finding | Route |
|---|---|
| Code defect, not blocking | Issue in the owning repository with the next milestone |
| Code defect, blocking (deterministic permanent loss, silent detection gap, install or upgrade broken) | Issue with the release milestone; fix PR on the default branch, cherry-pick into the cumulative sync PR; blocker-level regardless of likelihood |
| Text-only fix wanted in the release (a diagnostic naming a removed flag) | PR on the default branch plus cherry-pick, listed under release-blocking PRs |
| Documentation gap | One-line website PR ([`08-website.md`](08-website.md)) |
| Environment or noise | No action; noted in the report |
| A memory finding reproducible on the previous release | Pre-existing, next milestone, unless it is a permanent loss |

Every opened item gets a pointer sub-item in the tracking body. When a fix lands after a candidate, the item gains `tested on <candidate-N>: defect → <fix>` (ticked) and `re-test on <candidate-N+1>` (open). Read the error message users will see when a compatibility gate fires and check its wording before GA.

## Chart candidate

A chart candidate rides the chart's normal publishing pipeline: a chart version with a pre-release suffix and the app candidate as `appVersion`, on the **release branch** (the sync job publishes only from release branches), published flagged as pre-release so default installs keep resolving to the previous stable chart. The chart CI installs the chart, so the app images must be published first. Verify with [`scripts/chart-check.sh --expect-prerelease`](../scripts/chart-check.sh): the index entry, a template render showing the candidate image, the release flagged as pre-release. Details in [`07-release-day.md`](07-release-day.md#chart-chain) and [`templates/pr-body-chart-candidate.md`](../templates/pr-body-chart-candidate.md).

Before GA, check the chart against the candidate: render the supported configurations, validate them with the binary's dry run, diff the default configuration against the release's, and list the pins to bump (companion CLI image, plugin references, subchart constraints). Chart fix PRs never bump the chart version; the release PR does.

## Checklist

- [ ] Candidate cut from the release branch (or the default-branch exception recorded), on a literal go, through the gated script with the dry run shown
- [ ] Release run green; artifacts verified with the candidate-mode script; workdir kept under `OUTPUT_DIR`
- [ ] Announcement posted in the maintainer's voice, no dates, on their go
- [ ] Candidate rolled onto the project clusters (or the infra repository recorded as parked); dashboards read; crash logs captured
- [ ] Test plan written with environments; items run one at a time; evidence per item under `OUTPUT_DIR`; unified report with a verdict per item; skips with reasons
- [ ] Findings routed (issue with milestone, fix plus cherry-pick, docs PR, no action); pointers added to the tracking body; re-test items created
- [ ] Chart checked against the candidate; chart candidate published from the release branch and verified as pre-release
