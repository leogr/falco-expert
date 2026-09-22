# 04. Upstream components

The consumer's release is only as ready as the components it pins. This reference covers, per component, what "ready" means, what a tag publishes, the tag gate, the pins with checksums, and the release-branch protection. Line citations point at the era's pinned copies in [`refs/`](../../../refs/); the live default branch wins when it differs ([`00-setup.md`](00-setup.md#documents-to-read-live)).

## Ship order

The release document fixes the order: libs (with the driver) and plugins first, then the prebuilt drivers, then the Falco binary ([`RELEASE.md:L70-74`](../../../refs/falcosecurity/falco/RELEASE.md#L70-L74)). In practice the chain is: bundled plugin → pin in libs → libs and driver → drivers on the build grid → falco → chart → infra pins and website ([`01-inventory-and-chains.md`](01-inventory-and-chains.md#chains)).

## Readiness of a satellite component

Answer "is X ready?" with evidence, then the manual steps, then stop ([`10-agent-rules.md`](10-agent-rules.md#consent-gates)):

| Evidence | How |
|---|---|
| Default-branch CI on the exact head | every workflow completed, every job success or skipped; a job "that only publishes the dev image" still blocks while it runs |
| Open alerts and bot PRs | [`02-hygiene.md`](02-hygiene.md#dependency-alerts-and-bot-prs) |
| Gating PRs | open PRs in the milestone with their real merge gate |
| Classified commit list since the last tag | fix, feature, dependency, CI, docs; breaking changes named |
| Release mechanics | what a tag publishes (binaries, OCI artifacts, images, signatures), and which jobs run only for the final release |
| Downstream pins to bump afterwards | every consumer and its checksum variables |
| Version bump | both readings when strict semver and the repository's cadence differ, with a recommendation flagged as an inference |

## Tag gates

No tag suggestion, and no exact tag command, before the CI has **finished** and is fully green at the exact commit to be tagged: `gh run list --commit <sha>` shows every workflow completed, `gh run view <id> --json jobs` shows every job success or skipped. If anything is pending, say "not yet", arm [`scripts/wait-commit-checks.sh`](../scripts/wait-commit-checks.sh), and give the steps only when it reports green. Same for a release branch; when the branch runs fewer workflows on push than the default branch, add the PR CI of the identical tree (tree hash equality through [`scripts/branch-delta.sh`](../scripts/branch-delta.sh)) and the default-branch run of the same sources.

Before tagging an upstream component add the verification gate to the tracking issue: default-branch CI green on the final commit, then the consumer pinned to that candidate with its own CI green. Merged PRs are not a candidate until this passes.

Delegated candidate tags go through [`scripts/gated-tag.sh`](../scripts/gated-tag.sh) ([`05-release-candidates.md`](05-release-candidates.md#cutting-a-candidate)). Final tags are the maintainer's.

Select the required workflow run IDs from the live release CI configuration, including workflows that only run on PRs. The tag helper paginates runs, jobs and check-runs and rejects incomplete listings. Every required run must have nonempty green jobs and a head commit equal to the target or with an identical tree. `--allow-no-runs` requires explicit required runs; `--require-pr-tree-of` also requires a green PR run at that PR's current head. A green run from an older, different tree is never evidence for the target.

## Plugins

- Stable builds run when a plugin is tagged `plugins/<name>/v<version>`, where `<name>` matches the plugin folder and `<version>` matches the version string declared by the plugin; dev builds run on merges to the default branch ([`plugins/release.md:L6-7`](../../../refs/falcosecurity/plugins/release.md#L6-L7), [`L16-20`](../../../refs/falcosecurity/plugins/release.md#L16-L20)). The version bump merges first, then a person with repository rights creates the release from the UI; CI publishes the package under the stable prefix of the download bucket and the OCI artifact ([`L27-32`](../../../refs/falcosecurity/plugins/release.md#L27-L32)). A plugin that ships a ruleset releases it with the same version ([`L9`](../../../refs/falcosecurity/plugins/release.md#L9)).
- **Verify a plugin release before bumping pins** ([`scripts/plugin-artifacts-check.sh`](../scripts/plugin-artifacts-check.sh)): release run green end to end including OCI publish and signing; both stable tarballs downloaded twice with SHA256 recorded (these are the pin hashes); contents and ELF machine checked per architecture; the version, minor, and `latest` OCI tags resolve to the same multi-platform digest; signature verification passes with the publish workflow at the tag as subject. Only then open the pin PR with the downloaded hashes.
- **Pin overrides**: the bundled container plugin is pinned in libs with two per-architecture hashes ([`container_plugin.cmake:L24-33`](../../../refs/falcosecurity/libs/cmake/modules/container_plugin.cmake#L24-L33)) and overridden in falco's top-level build file with its own two hashes ([`CMakeLists.txt:L296-303`](../../../refs/falcosecurity/falco/CMakeLists.txt#L296-L303)); both pins must move.
- A defect in a bundled plugin found late is judged by outcome: a deterministic permanent loss of metadata is blocker-level ([`10-agent-rules.md`](10-agent-rules.md#severity)). A security bump arriving right after a plugin tag moves the pin target and voids the prepared downstream steps.

## libs and drivers

- Two independently versioned releases: the **libs** release (a tag plus a GitHub release; no artifacts built) and the **drivers** release (built and published by the build grid to the driver prefix of the download bucket), usually cut together ([`libs/release.md:L5-15`](../../../refs/falcosecurity/libs/release.md#L5-L15)). The libs milestone has a fixed name; the driver milestone is a rolling `next-driver` renamed near the release ([`L19-25`](../../../refs/falcosecurity/libs/release.md#L19-L25)); rename it before the tag so the release notes have a milestone.
- **Release branch** `release/M.m.x` named after the libs version even when drivers are released too; commits land by cherry-pick; the branch hosts the driver tags of the same cycle ([`L66-79`](../../../refs/falcosecurity/libs/release.md#L66-L79)). After branching: protection PR in the infra repository, candidate tag, test with the consumer, exceptional merges cherry-picked and re-tagged, unmerged PRs moved ([`L81-92`](../../../refs/falcosecurity/libs/release.md#L81-L92)).
- **Driver tag decision**: a driver tag is needed only when something under `driver/` changed since the previous driver tag. The version is a running counter: major, minor, or patch moves according to which component of `API_VERSION` or `SCHEMA_VERSION` moved, or patch for any other driver code change ([`versioning-schema-amendment.md:L51-56`](../../../refs/falcosecurity/libs/proposals/20220203-versioning-schema-amendment.md#L51-L56)), suffix `+driver` ([`L136`](../../../refs/falcosecurity/libs/release.md#L136)). It cannot be recomputed from the two files alone; read the previous driver tag and the bump rules ([`README.VERSION.md`](../../../refs/falcosecurity/libs/driver/README.VERSION.md)). An API major bump means the new userspace refuses older drivers and a full grid rebuild follows: say so in the tracking issue and the blog input.
- **Release bodies** are generated by one workflow with two gated jobs: the libs body only when the tag is the newest stable non-driver release, the driver body only when the tag is the newest stable driver release and after the kernel-test matrix completes ([`release-body.yml:L12-70`](../../../refs/falcosecurity/libs/.github/workflows/release-body.yml#L12-L70), [`L126-136`](../../../refs/falcosecurity/libs/.github/workflows/release-body.yml#L126-L136)). Both call the release-notes tool with the tag as milestone name, so the milestones must be literally the tag strings. When the notes step fails, build the body locally ([`scripts/release-body-build.sh`](../scripts/release-body-build.sh)) and let the maintainer set it ([`11-pitfalls.md`](11-pitfalls.md#release-notes-tooling-runs-only-at-ga)).
- The libs tag gate includes the kernel matrix and the nightly newest-kernel job when they exist; a kernel-only build fix does not bump API or schema but does bump the driver version at release.

## Drivers and the build grid

- Prebuilt drivers are built by the build grid from configuration directories per driver version and architecture in the infra repository, generated from the kernel lists published by the crawler ([`digests/falcosecurity/test-infra/drivers-build-grid.md`](../../../digests/falcosecurity/test-infra/drivers-build-grid.md), [`digests/falcosecurity/kernel-crawler.md`](../../../digests/falcosecurity/kernel-crawler.md)).
- **A new driver line is an onboarding project, not a tag**: check the crawler's distribution coverage first, open the configuration PR the same day, keep the daily bot PR flowing, size the runway from measured history.
- **Gate on counts, never on a green run** ([`scripts/crawler-lists-gate.sh`](../scripts/crawler-lists-gate.sh)): the published lists can be silently partial (a whole distribution key missing, whole suites lost behind a mirror, a slow mirror dropping a distribution on timeout) while the run is green; the daily bot then deletes those configurations from every driver version directory and a fresh line inherits the gap. Compare per-distribution counts against the reference configuration directory on the default branch through the git trees API; the PR files API caps its listing. Grep the whole crawler log for distribution-level errors: they are block-buffered and flushed at the end.
- **Bootstrap with the bot's own tool and sequence** (cleanup, then generate per architecture, same tool version as the job images): the tool takes the driver versions from the existing configuration directories, so create the new directory first; verify the new set against the previous line (same kernels, only the output path differs); validate with the tool; compare per-distribution counts with the default branch before pushing.
- **Retention**: keep the configuration directories of the last two driver versions associated with the latest stable releases (a release that keeps the driver version widens the window) and retire the others in the same PR that bootstraps the new line. **Published driver artifacts are never deleted from the bucket**: old lines stay available for users on older releases.
- The daily bot force-pushes its branch from the default branch every run: human commits on that branch survive only if merged before the next run. Keep a backup branch and be ready to re-push or open a separate PR; pausing the job means a configuration PR, not a switch.
- The build tool embeds the driver builder as a library: a new builder release reaches the grid only through a tool release and an image bump; generation does not depend on it. Check the pinned builder version before the builds start.
- **After the first builds**, compare what was published against the configurations per distribution and architecture ([`scripts/drivers-published-count.py`](../scripts/drivers-published-count.py)) and classify every gap: job never triggered (re-run), build failure the previous line also has (pre-existing), build failure new to this line (regression). Reproduce one sample per class locally with the same builder and the previous driver version before calling anything a regression. Pre-existing infrastructure failures get an issue in the owning repository and are postponed; only regressions and untriggered jobs are release work.
- The driver build grid is best effort. Missing prebuilt drivers are acceptable and do not by themselves block a release; publication counts remain informational.

## falcoctl

- Pushing a `v*` tag runs the release workflow, which builds with goreleaser and attaches provenance ([`falcoctl/.github/workflows/release.yaml:L3-6`](../../../refs/falcosecurity/falcoctl/.github/workflows/release.yaml#L3-L6), [`L30-34`](../../../refs/falcosecurity/falcoctl/.github/workflows/release.yaml#L30-L34)); the release document's local-goreleaser step is stale wording ([`falcoctl/release.md:L7-10`](../../../refs/falcosecurity/falcoctl/release.md#L7-L10)). Verify the published checksums file against the tarballs before pinning.
- Falco pins the bare version and two per-architecture hashes and prepends `v` in the download URL ([`falcoctl.cmake:L23-37`](../../../refs/falcosecurity/falco/cmake/modules/falcoctl.cmake#L23-L37)). The dependency-bump helper in the consumer does not cover falcoctl ([`update-deps-version`](../../../refs/falcosecurity/falco/scripts/update-deps-version)); [`scripts/pin-pr.sh`](../scripts/pin-pr.sh) does.
- A packaging fix found in candidate package tests (driver loader behaviour on upgrade) can force a late falcoctl patch and a re-pin; that is a new-candidate decision ([`06-freeze-and-sync.md`](06-freeze-and-sync.md#inclusion-criteria-for-late-fixes)).

## rules

- Each ruleset is released individually with the tag `<name>-rules-<version>`; the action validates the registry and publishes the OCI artifact ([`rules/RELEASE.md:L9-14`](../../../refs/falcosecurity/rules/RELEASE.md#L9-L14)). Before tagging, `FALCO_VERSIONS` must list the tested Falco versions as explicit stable releases; using the development tag near a Falco release is tolerated but must be patched on the ruleset's release branch afterwards ([`L9-11`](../../../refs/falcosecurity/rules/RELEASE.md#L9-L11)). The file's stated ordering is not enforced ([`FALCO_VERSIONS`](../../../refs/falcosecurity/rules/.github/FALCO_VERSIONS)); do not rely on line order.
- Version bump by the ruleset semver rules (patch, minor, major categories, most dominant wins, [`L41-78`](../../../refs/falcosecurity/rules/RELEASE.md#L41-L78)); the CI versioning suggestion is the reference.
- Sweep the open rules PRs before the consumer's freeze: an easy merge that changes content adds a tag to the chain; the rest is deferred with a note in the tracking issue. The consumer pins one ruleset with one checksum ([`rules.cmake:L21-30`](../../../refs/falcosecurity/falco/cmake/modules/rules.cmake#L21-L30)). The new Falco version goes into the rules CI matrix after GA ([`07-release-day.md`](07-release-day.md#also-on-the-day)).

## k8s-metacollector and the metadata plugin

- Readiness as for any satellite component; a tag publishes the image and assets, then the component's chart bumps its `appVersion` and is published through the charts repository. The consumer chart's subchart constraint may need a bump; that is a decision to present with the available versions and their deltas ([`05-release-candidates.md`](05-release-candidates.md#chart-candidate)).
- The metadata plugin ships separately from the plugin monorepo; decide early whether a pending fix forces a release, then bump the chart's plugin reference.

## Pins with checksums

| Pin in falco | File and variables | Checksums |
|---|---|---|
| libs | [`falcosecurity-libs.cmake:L45-48`](../../../refs/falcosecurity/falco/cmake/modules/falcosecurity-libs.cmake#L45-L48): `FALCOSECURITY_LIBS_VERSION`, `FALCOSECURITY_LIBS_CHECKSUM` | one, the source archive of the tag |
| driver | [`driver.cmake:L38-41`](../../../refs/falcosecurity/falco/cmake/modules/driver.cmake#L38-L41): `DRIVER_VERSION`, `DRIVER_CHECKSUM` | one, the source archive of the driver tag |
| falcoctl | [`falcoctl.cmake:L23-33`](../../../refs/falcosecurity/falco/cmake/modules/falcoctl.cmake#L23-L33): `FALCOCTL_VERSION`, `FALCOCTL_HASH` per architecture | two |
| rules | [`rules.cmake:L21-24`](../../../refs/falcosecurity/falco/cmake/modules/rules.cmake#L21-L24): `FALCOSECURITY_RULES_FALCO_VERSION`, `FALCOSECURITY_RULES_FALCO_CHECKSUM` | one |
| container plugin | [`CMakeLists.txt:L297-302`](../../../refs/falcosecurity/falco/CMakeLists.txt#L297-L302): `CONTAINER_VERSION`, `CONTAINER_HASH` per architecture | two (and two more in libs) |

Rules for pin PRs ([`scripts/pin-pr.sh`](../scripts/pin-pr.sh), [`templates/pr-body-pin.md`](../templates/pr-body-pin.md)):

- The checksum of a source archive exists only after the upstream tag: prepare the branch first, wait for the tag, hash the archive from **two independent downloads**, amend, then push.
- One commit per component; open on the default branch, then cherry-pick into the release branch or the cumulative sync PR ([`06-freeze-and-sync.md`](06-freeze-and-sync.md)).
- Reuse the bot's weekly bump PR when it exists on the right base (push on top and retitle) instead of opening a duplicate.
- A candidate pin PR pins the candidate tag; the final pin PR moves to the final tags; the tracking issue points at the final one.
- Verify the consumer's CI on the pin PR before calling the upstream candidate good: that is the consumer half of the verification gate.

## Release-branch protection

The merge automation's branch protection lives in the infra repository's configuration: every protected `release/*` branch is listed per repository with the required review count and contexts, and tide merges by rebase for every repository ([`config.yaml:L156-200`](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml) for falco, [`L366-425`](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml) for libs, [`L522-570`](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml) for merge methods). The live file may have moved during an infrastructure migration (at the time of writing, under a per-cluster `prow/` subdirectory); locate it with the contents API before editing. Open the protection PR the same day the branch is created; until it merges, tide cannot merge into the new branch with the intended rules.

## Patch releases

Falco patches target the current latest minor only; there are no patch releases for previous minors. Every final release, including a patch, is marked latest. Reuse the current minor's release branch and cherry-pick only the fixes approved for the patch ([`RELEASE.md:L103-108`](../../../refs/falcosecurity/falco/RELEASE.md#L103-L108)). The default branch may already contain next-minor work: record that intentional delta instead of trying to make the trees equal. Verify the release head against the reviewed release PR's tree and run CI at the exact commit. Update the existing website version entry without creating a new minor snapshot ([`08-website.md`](08-website.md#version-switch)).

Generate notes from the patch milestone with [`scripts/release-body-build.sh`](../scripts/release-body-build.sh). Its `--branch` filters the PR base: select the branch of the PRs that carry the actual notes, which can be the source PRs on the default branch. Do not automatically filter to the tag's release branch: the [cumulative sync PR](../templates/pr-body-sync.md) carries `NONE`. Check that every approved user-facing fix appears once and that next-minor changes are absent.

Maintainers avoid a patch release when the next minor is close (about a month): a patch release has real release-management cost, and a bundled component's fix reaches package and image users only when its pin moves anyway. Propose instead: component release now, pin bump in the next minor, a configuration workaround or an artifact-install override for users in the interim. Argue for a patch release only when the next minor is far off or the impact is severe, and present it as the maintainer's call. A hotfix out of band is for a bug that is easily exploited and compromises users ([`10-agent-rules.md`](10-agent-rules.md#severity)).

## Checklist

- [ ] Ship order derived from the live release document and the actual pin graph, overrides included
- [ ] Readiness of every satellite component answered with the evidence table, both version readings, and the manual steps; no tag command before CI finished green at the exact commit
- [ ] Plugin releases verified (double downloads, hashes recorded, OCI digests equal, signature) before any pin PR
- [ ] Driver tag decision recorded (changed under `driver/`, bump rule applied); rolling driver milestone renamed before the tag
- [ ] Crawler lists gated on per-distribution counts before generating configurations; retention applied as config-directory retirement only; published drivers never deleted
- [ ] First driver builds compared with configurations; gaps classified; pre-existing failures filed and postponed
- [ ] Every pin PR carries version plus checksum from two independent downloads, one commit per component, default branch then cherry-pick
- [ ] Release-branch protection PR opened the day the branch is created, at the live path of the configuration
- [ ] Patch-release stance applied to any remediation timing proposal
