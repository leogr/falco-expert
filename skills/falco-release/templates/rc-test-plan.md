# Release candidate test plan and unified report

One plan per candidate. Items come from the tracking issue's manual-testing checklist plus the published quickstarts and package guides followed literally with the candidate substituted. One item at a time; ask before advancing when the maintainer wants to steer. Never use a production kubeconfig. Pin the candidate artifacts (image digests, package URLs) in the environment file.

## Plan

```markdown
**<Component> <candidate>: test plan**

Results for [<candidate>](<release-url>), following <tracking-issue-url>. Environment: [`<date>-<component>-<candidate>-test-environment.txt`](<abs path>). Findings: [`<date>-<component>-<candidate>-findings.md`](<abs path>).

| # | Test | Required environment | Status |
|---|---|---|---|
| 1 | CLI options, valid and invalid rules, plugin loading, exit codes and diagnostics | local container, candidate image | |
| 2 | Container guide and quickstart: privileges, alerts, container metadata | local container, BTF host, documented mounts | |
| 3 | Regression check for `<defect found on the previous candidate>` | as the original | |
| 4 | Capture replay against expected alerts, error handling | local container, existing captures and rules | |
| 5 | Event generator, buffer sizes and presets, simultaneous sources, metrics, drops (<duration>) | local container, generator and plugin artifacts | |
| 6 | DEB and RPM install and plugins on the oldest supported glibc | distribution containers | |
| 7 | Helm chart and operator guides, metadata plugin, collector and runtime restarts | disposable VM, small Kubernetes and Helm inside the guest | |
| 8 | Package guide: install, upgrade from `<previous-version>`, restart and reboot, uninstall; kernel module through DKMS, cached reinstall, driver loader | disposable VMs, root, matching kernel headers | |
| 9 | Second architecture: install, capture, alerts (include large page sizes when relevant) | native host or VM for that architecture | |
| 10 | Memory checkers on the debug binaries: validation, replay, error paths | disposable development container, debug symbols | |

Items <1 to 4> need no new host software. Save per item: commands, versions and digests, expected versus actual, logs, a report with a case count. Re-run documentation commands with the version substitution recorded. Recheck the previous candidate's findings.
```

## Evidence layout per item

```text
OUTPUT_DIR/<date>-<component>-<candidate>-test-NN/
├── <date>-report.md            # verdict, case count, what was run, deviations from the guide
├── <date>-environment.txt      # host, kernel, tool versions, image digests, package URLs
├── <date>-commands.sh          # exactly what ran (file, never inline)
├── <date>-expected-vs-actual.md
└── logs/
```

## Unified report

```markdown
**<Component> <candidate>: test summary**

| # | Test performed | Result / report |
|---|---|---|
| 1 | <test> | [PASS: <n>/<n>](<report path>) |
| 2 | <test> | [PASS with <workaround>](<report path>) |
| 3 | <test> | [FAIL: <what>](<report path>) |
| 9 | <test> | Skipped: <reason> |

**Findings and routing** (severity by outcome when hit, not by likelihood)

| Finding | Class | Route |
|---|---|---|
| [<finding>](<report anchor>) | defect, blocking (permanent loss) | issue with the release milestone, fix plus cherry-pick into the cumulative sync PR |
| [<finding>](<report anchor>) | defect, not blocking | issue in the owning repository with the next milestone |
| [<finding>](<report anchor>) | text-only | PR on the default branch plus cherry-pick, listed under release-blocking PRs |
| [<finding>](<report anchor>) | documentation | one-line website PR |
| [<finding>](<report anchor>) | environment | no action, noted |

**Release assessment:** <no finding demonstrated release-blocking impact in this scope / one blocking finding named above>. Coverage limits: <skipped items, short durations, offline-only memory checks>. Previous candidate's findings: <re-checked and fixed / still open>.
```

Every count in the per-item reports is spot-checked by the coordinator before the summary is relayed. Pointers to opened issues and PRs go into the tracking body through the guard flow; ticked items note the candidate.
