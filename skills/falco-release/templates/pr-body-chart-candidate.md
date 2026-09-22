# PR body: chart release candidate

A chart candidate is a chart version with a pre-release suffix and the app candidate as `appVersion`, opened on the **release branch** so the sync job publishes it, flagged as pre-release so default installs keep resolving to the previous stable chart. The app candidate images must be published first (the chart CI installs the chart). Apply the maintainer's voice skill when available.

```markdown
**What type of PR is this?**

/kind chart-release
/kind release

**Any specific area of the project related to this PR?**

/area chart

**What this PR does / why we need it**:

Release candidate of the <Component> chart for <Component> `<candidate>`.

- cherry-picks the chart commits still missing on `<release-branch>`
  - <pr-url>
- <subchart constraint bump, if any, with the published subchart version and its app version>
- bumps the chart to `<chart-candidate>` with `appVersion: <candidate>` and moves the `Unreleased` entries under `## v<chart-candidate>`

Once merged, the chart sync postsubmit opens the sync PR in the charts repository. The published GitHub release is flagged as a pre-release and not as latest, so a default install keeps resolving to `<previous-chart-version>` unless `--version <chart-candidate>` or `--devel` is passed.

The final `<chart-version>` (`appVersion: <version>`) follows the <Component> `<version>` release with a separate chart release PR.

**Which issue(s) this PR fixes**:

Part of <tracking-issue-url>

**Special notes for your reviewer**:

- CI installs the chart with `<registry>/<image>:<candidate>` and `<registry>/<driver-loader-image>:<candidate>`, both already published
- <a separable commit and whether it can be dropped>

/milestone <version>

**Does this PR introduce a user-facing change?**:

```release-note
NONE
```
```

Verify after publication with [`../scripts/chart-check.sh --expect-prerelease`](../scripts/chart-check.sh): index entry, template render showing the candidate image, release flagged pre-release.
