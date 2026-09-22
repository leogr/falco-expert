# 11. Pitfalls

Non-obvious mechanics learnt on real releases, each as trigger, what goes wrong, and the rule. Abstract on purpose: no numbers, dates, names, or quotes (those live in the release state files). When a new lesson appears, append it here in the same shape and add the step to the phase checklist it belongs to. Line citations point at the era's pinned copies in [`refs/`](../../../refs/); the live files win.

## Release published as pre-release or not latest

The release workflow computes `is_latest` and `bucket_suffix` once at the publish event ([`release.yaml:L37-54`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L37-L54)); the body job and the `latest` image tags depend on `is_latest` ([`L156-160`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L156-L160), [`reusable_publish_docker.yaml:L131-142`](../../../refs/falcosecurity/falco/.github/workflows/reusable_publish_docker.yaml#L131-L142)). A GA published with the pre-release flag ships the packages to the stable buckets anyway but skips the body and the `latest` tags; editing the release does not re-trigger. Rule: remind the maintainer "full release, marked latest, target the release branch"; check the `release-settings` outputs first; recovery is flip the flag, cancel the attempt, re-run the whole workflow.

## Chart publishes only from release branches

The chart sync postsubmit runs only on `release/*` and only when the chart path changed ([`OCI charts.yaml:L109-119`](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/charts.yaml)). A chart bump merged on the default branch alone publishes nothing, and the default branch's in-tree chart lags. Rule: plan the chart bump on the release branch and the default-branch catch-up as two PRs; verify the chart release with the index, a render, and the release flags.

## Production build skips drafts

The website's production build excludes drafts while the deploy preview includes them, so a blog post merged with the draft flag set is a 404 in production and looks fine in the preview. Rule: grep the front matter for the draft flag before merging; verify the live URL, not the merge.

## Deploy preview re-fire

The website's default branch requires the hosting provider's deploy-preview status, enforced for administrators ([`config.yaml:L297-339`](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml)). During a provider incident the status never arrives and cannot be re-requested; only a new commit SHA on the PR branch re-fires it. Rule: amend and force-with-lease with the observed SHA on a branch the agent owns, as a consented manual push.

## Release-notes tooling runs only at GA

The release-body job runs only for the latest release ([`release.yaml:L158`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L158)), so candidates never exercise the release-notes action pinned in the workflow ([`L180-184`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L180-L184); libs: [`release-body.yml:L105-109`](../../../refs/falcosecurity/libs/.github/workflows/release-body.yml#L105-L109), [`L210-214`](../../../refs/falcosecurity/libs/.github/workflows/release-body.yml#L210-L214)). A breakage in that action (for example a token-format assumption, with the action redirecting its output so the job log only shows an exit code) surfaces at GA, on every tag, and a re-run does not help because release events run the workflow file at the tag. Rule: build the notes locally before the final release with the same tool ([`scripts/release-body-build.sh`](../scripts/release-body-build.sh)); when the action is broken, fix the pin on the default branch and on the branch that will be tagged before the tag ([`templates/pr-body-workflow-pin-fix.md`](../templates/pr-body-workflow-pin-fix.md)); meanwhile set the body by hand with `gh release edit --notes-file`. Malformed release-note lines abort the tool too, so the local run also validates the milestone data. The libs bodies additionally require the milestone to be named exactly like the tag and, for the driver body, the kernel-test matrix to finish ([`release-body.yml:L126-136`](../../../refs/falcosecurity/libs/.github/workflows/release-body.yml#L126-L136)).

## Compare API versus tree hashes

A three-dot compare between a release branch and the default branch counts rebased cherry-picks as divergence on both sides even when the trees are identical. Rule: verify branch sync with tree hashes or a two-dot diff ([`scripts/branch-delta.sh`](../scripts/branch-delta.sh)), never with the compare page.

## Path-gated and event-gated workflows

The full build may run only on pull requests, so a release branch push shows a fraction of the workflows; the default branch push runs publish jobs that pull requests do not. Rule: judge a branch head by its own runs plus the PR CI of the identical tree (tree hash) plus the default-branch run of the same sources; check CI health on PR runs for the affected path, not only the default branch. A PR that edits a path-filtered workflow file does not exercise itself.

## Fork runs need approval

Workflows of a PR from a first-time contributor's fork stay on `action_required` until a maintainer approves them; `gh pr checks` then lists only the DCO and tide contexts, which looks like CI never ran. A maintainer's push to the fork branch does not lift it. Rule: list runs by head SHA and approve the `action_required` ones (consented), after every push.

## Mirror and archive flakes

Image builds and package tests that install from external archive mirrors fail on the mirror's timeouts, on the default branch and in the release workflow alike; dependency downloads from code-hosting archives return gateway errors under load; a performance baseline job fails when the artifact it downloads has expired. Rule: read the step log, identify the failed set exactly, confirm the dependency answers again, re-run the failed jobs ([`scripts/gated-rerun.sh`](../scripts/gated-rerun.sh)), and never re-tag for an infrastructure failure. Distinguish required contexts from informational ones before calling a branch red. When downstream jobs consume artifacts of earlier jobs, re-run the whole run.

## End-of-life build images

Build containers on an end-of-life distribution break when the archive removes binaries or the signed index expires, and the removal progresses over hours. Rule: check EOL dates against the release calendar; fix the source (frozen snapshot mirror for the whole suite, validity check disabled where the official image does so) in every workflow on the same base image; add a loud guard so the step fails instead of silently building without the suite.

## Block-buffered logs

A job's error lines can be flushed at the end of the log, far from the progress output they belong to (a crawler printing errors to a block-buffered stdout under CI). Rule: grep the whole log for the error pattern before saying a component ran clean; strip ANSI codes first.

## Partial crawler lists

The kernel lists that drive driver-configuration generation can be silently partial with a green run: a whole distribution key missing, whole suites lost behind a mirror, a slow mirror dropping a distribution on timeout, a repository publishing only one metadata format that the crawler does not parse. The daily bot then deletes those configurations everywhere and a fresh driver line inherits the gap. Rule: gate on per-distribution counts against the default branch's configuration tree ([`scripts/crawler-lists-gate.sh`](../scripts/crawler-lists-gate.sh)), never on key presence or a green run; inspect large bot PRs through the git trees API or a local diff, never the PR files API (it caps the listing).

## Untriggered build jobs

A very large configuration push can leave build jobs untriggered while every visible job is green, so job success does not mean drivers were built. Rule: count the published drivers per distribution and architecture against the configurations after the postsubmits ([`scripts/drivers-published-count.py`](../scripts/drivers-published-count.py)) and classify the gaps (never triggered, pre-existing failure, regression).

## Daily bot force-pushes

The daily configuration bot force-pushes its branch from the default branch every run: human commits on that branch survive only if merged before the next run. Rule: keep a backup branch of the prepared commits; merge before the next run or re-push with a fresh lease; pausing the job is a configuration PR.

## Changelog conflicts on cherry-pick

Chart changelog bullets added under the default branch's unreleased heading conflict when cherry-picked onto a release branch whose unreleased section differs. Rule: place them under the release branch's own unreleased section and let the chart release PR fold them; the sync script's changelog helper does this.

## Merge automation versus the real gate

tide waits only for its configured contexts and merges by rebase without retesting the combination ([`config.yaml:L517-570`](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml)); a PR can merge while optional jobs still run, and two green PRs can land broken together. A GitHub approving review yields the `lgtm` label reliably but not always `approved`; an approval counts toward branch protection only from a reviewer with write access; the default and release branches of the core repositories need two approving reviews and the author never counts; every push dismisses stale approvals. Rule: read tide's description, both labels, the required review count, and the reviewer's permission before calling a PR mergeable ([`02-hygiene.md`](02-hygiene.md#merge-gates)); arm the commit-checks waiter on the merge commit, not the PR head.

## Foreign check-runs

Check-runs on a commit can come from apps other than the CI (runner providers posting neutral results on provisioning errors, security scanners). Rule: gate on the CI app's check-runs and the workflow conclusions; report foreign check-runs and find the outcome of the real job they refer to; neither count nor dismiss them unread.

## A candidate cut from the wrong branch

A candidate tagged from the default branch is content-equivalent only when the trees differ in files the artifacts do not ship (chart metadata); the final tag must come from the release branch. Rule: state the target branch explicitly in every tag proposal and record the exception when it happens.

## Checksums exist only after the tag

A downstream pin carries the checksum of the upstream source archive, which exists only after the upstream tag ([`04-upstream-components.md`](04-upstream-components.md#pins-with-checksums)). Rule: prepare the pin branch, wait for the tag, hash the archive from two independent downloads, amend, push.

## Tracking-body drift and trailing newlines

Reading the tracking body through a JSON query appends a trailing newline; without stripping, every edit grows the body and the post-edit comparison fails on a difference the page does not show. The maintainer also edits the body live between snapshot and apply. Rule: the guard compares after stripping trailing newlines, aborts on drift, and re-syncs stored and snapshot from live before re-deriving the edit ([`03-tracking-issue.md`](03-tracking-issue.md#edit-guard-flow)); diff gates inspect changed lines only.

## Stale documentation in release documents

Release documents drift: a step that says "run the release tool locally" when a tag push already runs it in CI ([`falcoctl/release.md:L7-10`](../../../refs/falcosecurity/falcoctl/release.md#L7-L10) versus [`falcoctl/.github/workflows/release.yaml:L3-6`](../../../refs/falcosecurity/falcoctl/.github/workflows/release.yaml#L3-L6)); a tag regex that excludes the pre-release example the document gives ([`plugin-sdk-go/release.md:L14-17`](../../../refs/falcosecurity/plugin-sdk-go/release.md#L14-L17) versus [`release.yml:L3-6`](../../../refs/falcosecurity/plugin-sdk-go/.github/workflows/release.yml#L3-L6)); workflow file names that no longer exist ([`libs/release.md:L103-104`](../../../refs/falcosecurity/libs/release.md#L103-L104)); a version-list ordering rule the file does not follow ([`rules/RELEASE.md:L45`](../../../refs/falcosecurity/rules/RELEASE.md#L45)); build-file line links that moved. Rule: read the workflow, not only the document, before encoding a step; note the drift in the state file and offer a documentation fix after the release.

## Infrastructure configuration moves

The infra repository's branch-protection configuration, the chart sync job, and the cluster application manifests can move to per-cluster subdirectories during a migration, so the pinned paths return not found. Rule: locate the live files with the contents API before editing; treat a repository mid-migration as parked and ask before touching it.

## A go that aged

A defect surfaces in a merged PR an hour after a go to approve it on green was given; on a Prow repository the approval merges at once. Rule: a go ages; re-confirm with the step's own evidence after any chain event or maintainer message; never run a public step while a maintainer question is unanswered ([`01-inventory-and-chains.md`](01-inventory-and-chains.md#rules-that-keep-chains-honest)).

## Waiters and the temporary directory

Waiters die with the session, a reboot, or a stop; the temporary directory is wiped at boot, taking scripts, clones, and the guard snapshot with it. Rule: record waiter IDs, scripts, and timeouts in the state file; keep durable copies under `OUTPUT_DIR` or in this skill; re-create helpers without checking; never `pkill -f` on a pattern that matches the waiter's own shell.

## Local time labeled as UTC

Sub-agents and hurried notes label local time as UTC. Rule: run `date -u` before writing any timestamp; treat sub-agent times as suspect until checked.

## Rolling milestone not renamed

A driver tag cut while its milestone still carries the rolling name produces an empty release body, because the body job passes the tag as the milestone name. Rule: rename the rolling milestone to the exact tag string before tagging ([`04-upstream-components.md`](04-upstream-components.md#libs-and-drivers)).

## Hot-path fix drafted by the agent

An untested fix drafted by the agent in a per-event path is not a fix. Rule: use the tested patch with a regression test, a draft PR for real-runtime CI, and an independent correctness and performance review ([`10-agent-rules.md`](10-agent-rules.md#severity)).

## Checklist

- [ ] Before the GA publish: latest flag, target branch, empty body reminded; `release-settings` outputs checked first
- [ ] Chart bump planned on the release branch plus a default-branch catch-up
- [ ] Blog front matter checked for the draft flag; live URL verified
- [ ] Release-notes tooling exercised locally before GA; pin fix on the branch to be tagged when broken
- [ ] Branch sync verified with tree hashes; branch heads judged with the PR CI of the identical tree when needed
- [ ] Fork runs approved after every push (consented); red CI read before re-run; re-run instead of re-tag for infrastructure failures
- [ ] Crawler lists gated on counts; published drivers counted against configurations; bot branch backed up
- [ ] Merge readiness read from tide, labels, review count, and write access; foreign check-runs explained
- [ ] Checksums from two downloads after the upstream tag; tracking guard compares after stripping newlines
- [ ] Live paths of moved infra files located before editing; parked repositories left alone
- [ ] Every new lesson appended here abstractly and its step added to the phase checklist
