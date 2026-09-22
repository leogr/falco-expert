# Tracking issue body skeleton

Synthetic style: checkbox, short label, `👉` pointer, at most a few words of status with a short date. Details live in the linked PRs, issues, and reports. Never annotate a state GitHub already renders (`(merged)`, `(closed)`). References in sub-lists, one per line. Notes only for decisions recorded nowhere else. Keep the ordering constraints: upstream components before the consumer's pins, pins before the candidate, freeze before the final tag, chart after the images.

Start from the release template in the component repository's release document (the live default branch wins) and keep its headings; fill the sub-items from the inventory.

```markdown
# <Component> <version> Release

Will keep this issue updated with the current status and progress.

## Date

Target release date: <date>

## Release Steps

The process is described in [this document](<release-document-url>).

## External dependencies

- [ ] <plugin>
  - [ ] pending PRs decided
    - <pr-url>
    - <pr-url>
  - [ ] release `<version>` 👉 <release-url>
  - [ ] pin `<version>` in libs 👉 <pr-url>
  - [ ] pin `<version>` in falco 👉 <pr-url>
- [ ] libs
  - [ ] `<version>` 👉 <release-url> (from `<release-branch>`; candidates listed below)
    - <candidate-release-url>
    - <pin-pr-url>
    - <protection-pr-url>
    - <cherry-pick-pr-url>
  - [ ] merged for `<version>`
    - <pr-url>
  - [ ] moved to `<next-version>`
    - <pr-url>
  - [ ] once the last PR is merged: default-branch CI green (kernel matrix and nightly job included), falco pinned to the candidate with CI green, then tag
  - [ ] release descriptions
- [ ] drivers
  - [ ] `<driver-version>` 👉 <release-url>
  - [ ] before generating the `<driver-version>` configs, check both kernel lists are complete per distro; do not merge the config PR while it drops kernels
    - <crawler-issue-url>
    - <configs-pr-url>
- [ ] falcoctl
  - [ ] release `<version>` 👉 <release-url>
  - [ ] bump `<version-variable>` in falco 👉 <pr-url>
- [ ] k8s-metacollector
  - [ ] release `<version>` 👉 <release-url>
  - [ ] chart `<chart-version>` with `appVersion` `<version>` published
- [ ] rules
  - [ ] `<rules-tag>` 👉 <release-url> (<bump kind>; tarball, OCI artifact, and signature verified)
  - [ ] pin `<rules-tag>` in falco 👉 <pr-url>
  - [ ] open rules PRs deferred to after `<version>`
    - <pr-url>

N.B. <one decision recorded nowhere else, one or two lines>.

## Manual Testing Action Items

- [ ] Running Falco on Kubernetes with the official Helm chart
- [ ] Running Falco on Kubernetes with the official operator
- [ ] Running Falco from RPM and DEB artifacts
  - [ ] install, upgrade from `<previous-version>`, restart, reboot, drivers, uninstall
- [ ] Running Falco in a container with the official images
- [ ] Running Falco with multiple event sources active in parallel
- [ ] Running Falco with variable syscall buffer dimension
- [ ] Running Falco in all officially supported architectures
  - [ ] x86_64
  - [ ] ARM64
- [ ] Running Falco with the supported drivers (kernel module, modern eBPF, capture files)
- [ ] Test Falco with the event generator
- [ ] Test that plugins are correctly loaded
- [ ] Test memory and CPU usage (memory checkers included)
- [ ] Test the latest version of the driver loader
- [ ] Test that the metadata plugin works as expected
- [ ] Test that all CLI options work as expected
- [ ] Check that log messages are correct and consistent
- [ ] Test that ruleset loading and validation work as expected
- [ ] <regression check for a defect found on the previous candidate> 👉 <fix-url>

## Action Items

- [ ] **Pre-Release**
  - [ ] Milestone (release-note blocks checked, fixed issues assigned)
  - [ ] Code freeze
  - [ ] Open the release branch and protect it 👉 `<release-branch>` created at `<sha>`; protection <pr-url>
  - [ ] Bump the component pins to the final tags
    - [ ] <plugin> 👉 <pr-url>
    - [ ] falcoctl 👉 <pr-url>
    - [ ] rules 👉 <pr-url>
    - [ ] libs and driver 👉 <pr-url>
  - [ ] cherry-pick the fixes approved for this release onto `<release-branch>` 👉 <sync-pr-url>
  - [ ] Prebuilt drivers published 👉 <counts per distro pointer>
  - [ ] Code thaw
  - [ ] Changelog on the release branch 👉 <pr-url>
  - [ ] Cherry-pick the changelog on the default branch 👉 <pr-url>
- [ ] **Release**
  - [ ] GitHub release
    - [ ] `<candidate-1>` 👉 <release-url> (from `<release-branch>` at `<sha>`; packages in the dev buckets and images tagged)
    - [ ] `<version>` 👉 <release-url> (tag `<sha>` on `<release-branch>`, stable buckets, images and `latest` tags on both registries, release body generated)
- [ ] **Website** 👉 checklist <website-tracking-url>
  - [ ] Create the snapshot for `<previous-version>`
  - [ ] Protect the snapshot branch
  - [ ] Bump the version parameters 👉 <pr-url> (generated pages from the released image pushed)
  - [ ] Merge the release blog post
  - [ ] Merge all necessary documentation PRs
- [ ] **Helm**
  - [ ] Release a new chart version
    - [ ] `<chart-candidate>` for `<candidate>` 👉 <pr-url>
    - [ ] `<chart-version>` for `<version>` 👉 <release-url>
  - [ ] Update the chart documentation
  - [ ] Decide whether to bump the subchart constraints
- [ ] **Operator**
- [ ] **Announcements**
  - [ ] mailing list
  - [ ] blog post
  - [ ] chat channel
- [ ] **Post-Release**
  - [ ] Archive community call meeting notes
  - [ ] Close the resolved issues after the tag and move the unresolved ones under a new milestone
  - [ ] Update the supported fields and syscall documentation
  - [ ] Add the new version to the rules CI matrix

## Breaking changes

- <one line per breaking change, with the commit or PR>
  - <url>

## Miscs

/milestone <version>

/kind documentation

## Release blocking PRs

- <pr-url> 👉 <few words: what it is, short date>

## Candidates to evaluate before the code freeze

- <issue-or-pr-url> 👉 <stance and outcome, short date>
  - <related-url>

## Milestone triage

- moved to `<next-version>`, nothing in flight for `<version>`
  - <issue-url>
- kept, closed once their fix merged
  - <issue-url>
```
