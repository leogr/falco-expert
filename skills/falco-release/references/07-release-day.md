# 07. Release day

The maintainer publishes the release; the agent prepares the sequence, watches the run, verifies every artifact, and drives the chains that follow. Every step below is gated on the previous one's exact outcome. Line citations point at the era's pinned workflow copies; the live workflow files win when they differ.

## Preconditions

- Release branch head green at the exact commit (every workflow completed, every job success or skipped), plus the PR CI of the identical tree when the branch runs fewer workflows ([`06-freeze-and-sync.md`](06-freeze-and-sync.md#release-branch-versus-default-branch)).
- Every code and dependency blocker merged, the cumulative sync PR included; the candidate test pass complete with findings routed. Remaining changelog and chart metadata PRs follow the sequence below; all other open milestone PRs must be resolved or explicitly deferred.
- Release head matches the reviewed release PR's tree. Inspect the delta from the default branch and explain release-only metadata and intentionally excluded changes; patch releases include only approved backports, even when the default branch has next-minor work ([`scripts/branch-delta.sh`](../scripts/branch-delta.sh), [`04-upstream-components.md`](04-upstream-components.md#patch-releases)).
- The release-notes tooling exercised locally ([`scripts/release-body-build.sh`](../scripts/release-body-build.sh)) and any workflow fix merged on the branch that will be tagged ([`11-pitfalls.md`](11-pitfalls.md#release-notes-tooling-runs-only-at-ga)).
- The pre-tag announcement drafted, the chart final PR drafted, the changelog PR drafted.

## Pre-tag sequence (release branch)

1. **Release-notes hygiene**: assign the milestone to the merged PRs and fixed issues since the previous tag, classifying before assigning ([`RELEASE.md:L84-94`](../../../refs/falcosecurity/falco/RELEASE.md#L84-L94)); audit every release-note block ([`scripts/release-notes-check.py`](../scripts/release-notes-check.py)): free text into Conventional Commits form, an empty block into `NONE`, a multi-line note into one line; a PR without a block must carry the none label.
2. **Changelog**: generate locally with the same tool as the workflow (for a patch, verify the [milestone and PR-base filter](04-upstream-components.md#patch-releases)), review as a reader, and open the changelog PR on the release branch ([`templates/pr-body-changelog.md`](../templates/pr-body-changelog.md)). Once the release contents are settled and reviews and CI are green, lift its hold with consent and merge it **before publication**. Close the milestone and verify CI at the resulting release head. The maintainer cuts the final tag on that commit so it includes the changelog ([`RELEASE.md:L110-124`](../../../refs/falcosecurity/falco/RELEASE.md#L110-L124)).
3. **Chart final PR** on the release branch ([`templates/pr-body-chart-final.md`](../templates/pr-body-chart-final.md)): `version`, `appVersion`, the changelog section folded from the pre-release entries, the README version line, the chart docs check. It merges only after the images are published (see the chart chain).
4. **Announce ahead** with one line on the tracking issue (no date) and stop every other public action on the release branch until the release is out.

## The maintainer's publish step

The maintainer publishes the GitHub release from the "Draft a new release" form: tag `M.m.p` as tag and title, target the release branch, body left empty because the workflow generates it ([`RELEASE.md:L146-159`](../../../refs/falcosecurity/falco/RELEASE.md#L146-L159)). Remind them of the one thing the workflow cannot recover from:

> Publish it as a full release, marked **latest**, targeting the release branch.

This also applies to patches: Falco patches are issued only for the current latest minor, and every final release becomes latest.

Why: the release workflow runs on `release: published` ([`release.yaml:L2-4`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L2-L4)) and computes two settings once, at the publish event ([`L37-54`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L37-L54)): `bucket_suffix` is `-dev` when the tag contains a `-`, else empty; `is_latest` is true only when the tag has no `-` **and** equals the repository's latest stable release at that moment. Only two things depend on `is_latest`: the `release-body` job ([`L156-160`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L156-L160)) and the `latest` image tag family ([`reusable_publish_docker.yaml:L131-142`](../../../refs/falcosecurity/falco/.github/workflows/reusable_publish_docker.yaml#L131-L142)). So a GA published with the pre-release flag, or without "set as latest", still ships the packages to the **stable** buckets (the suffix decides the bucket, not the flag) but skips the generated body, the debug-symbol attachments, and the `latest` tags. Editing the release afterwards does not re-trigger the workflow. Recovery: flip the flag to latest, cancel the running attempt, re-run the **whole** workflow; job outputs are frozen per attempt, so re-running only failed jobs is not enough. A tag with `+` build metadata fails the version check and aborts the run ([`L40-43`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L40-L43)); the workflow's concurrency group cancels an in-flight run when another release is published ([`L10-12`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L10-L12)).

Check the `release-settings` outputs of the run first, before anything else.

## Run watch and artifact verification

1. Watch the release run to the end ([`scripts/wait-run.sh`](../scripts/wait-run.sh)). Image builds that install packages from external mirrors can fail on mirror timeouts: read the step log, confirm the mirror answers, re-run the failed jobs ([`scripts/gated-rerun.sh`](../scripts/gated-rerun.sh)); never re-tag for an infrastructure failure.
2. Verify with one script ([`scripts/artifacts-check.sh --mode final`](../scripts/artifacts-check.sh)): every package in the stable buckets (`rpm`, `deb/stable`, `bin/<arch>`, the static tarball; [`reusable_publish_packages.yaml:L85-100`](../../../refs/falcosecurity/falco/.github/workflows/reusable_publish_packages.yaml#L85-L100), [`L139-141`](../../../refs/falcosecurity/falco/.github/workflows/reusable_publish_packages.yaml#L139-L141)); the image tag families on both registries (`<tag>`, `<tag>-debian`, per-architecture tags, the driver loader's `<tag>` and `<tag>-buster`), multi-arch, with the `latest` family digests equal to the version digests ([`reusable_publish_docker.yaml:L76-129`](../../../refs/falcosecurity/falco/.github/workflows/reusable_publish_docker.yaml#L76-L129)); signing and attestation evidence in the publish job ([`L144-174`](../../../refs/falcosecurity/falco/.github/workflows/reusable_publish_docker.yaml#L144-L174)).
3. Verify the repository indexes, not only the direct files ([`scripts/repo-index-check.py --mode stable`](../scripts/repo-index-check.py)): the apt `Packages` indexes per architecture and the rpm `repodata` must list the version.
4. Verify the release body: component version badges, stable download links, generated notes, the release-manager line, the debug-symbol assets ([`release.yaml:L167-218`](../../../refs/falcosecurity/falco/.github/workflows/release.yaml#L167-L218), [`release_template.md`](../../../refs/falcosecurity/falco/.github/release_template.md)). When the notes job failed, build the body locally and give the maintainer the `gh release edit --notes-file` command.
5. Tick the tracking issue through the guard flow.

## Chart chain

1. The chart final PR merges after the images are published (the chart CI installs the chart).
2. The sync postsubmit runs **only on release branches** and only when the chart path changed ([`OCI charts.yaml:L109-119`](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/charts.yaml)); wait for the sync PR in the charts repository ([`scripts/wait-new-pr.sh`](../scripts/wait-new-pr.sh)). The old AWS definition is retained under the backup catalog and is not the current job source. A chart bump merged on the default branch alone publishes nothing.
3. One charts approver approves the sync PR with one short line; the charts release workflow publishes the chart release when the `version` field changes on the charts default branch ([`charts/release.md:L9-19`](../../../refs/falcosecurity/charts/release.md)); the Helm index and the artifact catalog follow within minutes ([`scripts/chart-check.sh`](../scripts/chart-check.sh): index entry, render, release not flagged pre-release).
4. Catch the default branch up on the chart metadata afterwards with cherry-picks in a separate PR (changelog conflicts resolved with the release-branch version, chart trees compared).

## Default-branch catch-ups and infra pins

- Cherry-pick the changelog PR onto the default branch as its own PR ([`templates/pr-body-changelog.md`](../templates/pr-body-changelog.md)). Dependency download errors from the code-hosting archives are infrastructure flakes: read the log, re-run the failed jobs, never merge on red.
- Bump the infra deployment manifests to the released chart and image tags ([`templates/pr-body-infra-bump.md`](../templates/pr-body-infra-bump.md)); the pinned example is the application manifest in the infra repository ([`applications/falco.yaml:L10-18`](../../../refs/falcosecurity/test-infra/config/applications/aws/falco.yaml)), which may have moved to a per-cluster subdirectory. Check every cluster's pin (operator-managed instances carry their own version field) and the dashboard links that embed the chart version.
- Close the milestone as soon as the changelog PR merges into the release branch ([`RELEASE.md:L122`](../../../refs/falcosecurity/falco/RELEASE.md)); move leftovers with a classification ([`09-post-release.md`](09-post-release.md#milestones-and-leftovers)).

## Website

The version switch goes first, then the content PRs, the generated pages from the released image, and the blog post last ([`08-website.md`](08-website.md)).

## Blog input

Prepare the bullet list of user-facing updates from the milestone as the prompt for a separate writing session ([`templates/blog-input-prompt.md`](../templates/blog-input-prompt.md)): versions table, features, packaging, hardening, drivers, plugins, rules, Kubernetes, breaking changes, counts. Embargoed items stay out; the maintainer adds them after the advisory is public.

## Also on the day

- The meeting-notes archive PR in the community repository ([`RELEASE.md:L161-168`](../../../refs/falcosecurity/falco/RELEASE.md#L161-L168)).
- The new version in the rules repository's testing matrix (`FALCO_VERSIONS`, [`rules/RELEASE.md:L9-11`](../../../refs/falcosecurity/rules/RELEASE.md#L9-L11)).
- Announcements are the maintainer's: mailing list, chat, blog ([`RELEASE.md:L171-178`](../../../refs/falcosecurity/falco/RELEASE.md#L171-L178)).

## Checklist

- [ ] Preconditions verified: branch green at the exact commit, sync PR merged, reviewed release tree matches, intentional default-branch delta recorded, notes tooling exercised, drafts ready
- [ ] Release-notes hygiene done; changelog generated locally, reviewed, unheld with consent and merged before publication; resulting release head green; chart final PR drafted
- [ ] Pre-tag announcement posted (no date); no other public action on the release branch until the release is out
- [ ] Maintainer reminded: full release, marked latest, target the release branch, empty body; the agent never publishes
- [ ] `release-settings` outputs checked first; run watched to the end; infrastructure flakes re-run, never re-tagged
- [ ] Artifacts, repository indexes, image digests including the `latest` family, release body and debug assets verified with the scripts
- [ ] Chart chain: final PR merged after the images, sync PR approved with one line, chart release verified, default-branch catch-up opened
- [ ] Changelog cherry-picked to the default branch; infra pins bumped on every cluster; milestone closed
- [ ] Website chain, blog input, meeting notes, rules matrix done or handed over; tracking issue ticked
