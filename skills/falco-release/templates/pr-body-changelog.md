# PR body: changelog

Two PRs: the changelog on the release branch (held while release contents settle, then merged before publication so the final tag includes it) and its cherry-pick on the default branch afterwards. The content is the release-notes tool output prepended to the changelog file, reviewed locally first ([`../scripts/release-body-build.sh`](../scripts/release-body-build.sh)). Apply the maintainer's voice skill when available.

## Release branch

```markdown
**What type of PR is this?**

/kind release

**Any specific area of the project related to this PR?**

/area build

**What this PR does / why we need it**:

Adds the `<version>` changelog to `CHANGELOG.md`, generated from the `<version>` milestone with the same tool as the release workflow and reviewed by hand.

Held until release contents are settled. Remove the hold once approved and green, then merge before publication; the final tag is cut on this PR's resulting release-branch commit after CI is green there.

Part of <tracking-issue-url>

**Which issue(s) this PR fixes**:

Fixes #

**Special notes for your reviewer**:

/hold

/milestone <version>

**Does this PR introduce a user-facing change?**:

```release-note
NONE
```
```

## Default branch (cherry-pick)

```markdown
**What type of PR is this?**

/kind release

**Any specific area of the project related to this PR?**

/area build

**What this PR does / why we need it**:

Cherry-picks the `<version>` changelog onto `<default-branch>` 👇
- <release-branch-changelog-pr-url>

Part of <tracking-issue-url>

**Which issue(s) this PR fixes**:

Fixes #

**Special notes for your reviewer**:

/milestone <version>

**Does this PR introduce a user-facing change?**:

```release-note
NONE
```
```

Commit message pattern: `docs: add <Component> \`<version>\` changelogs to \`CHANGELOG.md\``, one sign-off line ([`commit-message.md`](commit-message.md)). Dependency download errors from the code-hosting archives during this PR's CI are infrastructure flakes: read the log, re-run the failed jobs, never merge on red.
