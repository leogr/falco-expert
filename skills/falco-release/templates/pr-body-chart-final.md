# PR body: chart final release

Opened on the **release branch** (the chart sync job publishes only from release branches). It merges after the app images are published (the chart CI installs the chart). It folds the pre-release changelog entries into the final section, bumps `version` and `appVersion`, refreshes the README version line, and passes the chart docs check. Chart fix PRs never bump the chart version; only this PR does. A separate catch-up PR brings the same metadata to the default branch afterwards. Apply the maintainer's voice skill when available.

```markdown
**What type of PR is this?**

/kind chart-release
/kind release

**Any specific area of the project related to this PR?**

/area chart

**What this PR does / why we need it**:

Release of the <Component> chart `<chart-version>` for <Component> `<version>`.

- bumps the chart to `<chart-version>` with `appVersion: <version>`
- folds the `<chart-candidate>` entries and the `Unreleased` entries under `## v<chart-version>`
- <subchart constraint changes, if any, one per line>
- README version line regenerated with the docs tool

Once merged, the chart sync postsubmit opens the sync PR in the charts repository; the charts release workflow publishes `<chart>-<chart-version>` as the latest chart release, then the Helm index and the artifact catalog follow.

The `<default-branch>` catch-up (same metadata, changelog conflicts resolved with the release-branch version) follows in a separate PR.

**Which issue(s) this PR fixes**:

Part of <tracking-issue-url>

**Special notes for your reviewer**:

- CI installs the chart with `<registry>/<image>:<version>` and `<registry>/<driver-loader-image>:<version>`, both already published
- rendered the supported configurations against the released binary's dry run before opening this PR

/milestone <version>

**Does this PR introduce a user-facing change?**:

```release-note
NONE
```
```

Commit message pattern: `chore(chart): release <chart-version> for <Component> <version>`, one sign-off line ([`commit-message.md`](commit-message.md)). The approval of the bot-opened sync PR in the charts repository is one short line by one charts approver ([`../references/07-release-day.md`](../references/07-release-day.md#chart-chain)).
