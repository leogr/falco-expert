# PR body: workflow pin fix (release tooling)

For a fix to a release workflow (for example the release-notes action pin) that must be on the branch that will be tagged, because the release event runs the workflow file at the tag. Open it on the default branch and cherry-pick onto the release branch (or append to the cumulative sync PR); both must merge before the final tag. Apply the maintainer's voice skill when available.

## Default branch

```markdown
**What type of PR is this?**

/kind bug

**Any specific area of the project related to this PR?**

/area automation

**What this PR does / why we need it**:

Fixes the `<job>` job of the release workflow: <one line on the mechanism, for example the pinned action rejects the current token format and the log hides the error>. This PR <bumps the pin to `<owner/action>@<sha>` / adds the `<permission>` permission / replaces the step>.

Reproduced locally by running the tool at the pinned commit with the same inputs; the fixed build generates the notes for the `<milestone>` milestone.

Part of <tracking-issue-url>

**Which issue(s) this PR fixes**:

Fixes #

**Special notes for your reviewer**:

The job runs only for the final release, so candidates never exercise it: this has to be on `<release-branch>` before the `<version>` tag 👇
- <release-branch-pr-url>

/milestone <version>

**Does this PR introduce a user-facing change?**:

```release-note
NONE
```
```

## Release branch (cherry-pick)

```markdown
/kind bug
/area automation

This PR cherry-picks onto `<release-branch>` the `<job>` fix for the release workflow 👇
- <default-branch-pr-url>

It has to land before the `<version>` tag, since the release workflow runs from the tagged commit and the job runs only for the latest release.

Part of <tracking-issue-url>

```release-note
NONE
```

/milestone <version>
```

Until the fix is merged on the branch to be tagged, build the release body locally with [`../scripts/release-body-build.sh`](../scripts/release-body-build.sh) and let the maintainer apply it with the printed `gh release edit --notes-file` command.
