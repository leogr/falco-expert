# PR body: cumulative cherry-pick sync onto the release branch

One cumulative PR between the last candidate and GA; append cherry-picks with plain pushes as fixes merge and keep this list current. Hold it until the last fix is in. Cherry-picks keep the original author and sign-off, no `-x`. Apply the maintainer's voice skill when available.

```markdown
**What type of PR is this?**

/kind release

**Any specific area of the project related to this PR?**

/area build

<add `/area chart` when chart files are included>

**What this PR does / why we need it**:

This PR cherry-picks onto `<release-branch>` the fixes approved for `<version>`<, plus the agreed dependency pins> 👇

- <pr-url>
- <pr-url>
- <pr-url>

Each cherry-pick was compared with its source patch. The remaining delta from `<default-branch>` is intentional: <release metadata and excluded changes, or none>. After merge, verify that the release head matches this PR's reviewed tree.

N.B. <a fix not included yet and why it follows in the same PR later>.

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

Notes:
- Title pattern: `sync: cherry-pick for <release-branch>` (candidate or fix suffix optional).
- The tracking issue lists this PR once under "Release blocking PRs" as the cumulative sync.
- Remove the hold only when the last agreed fix is picked; a push dismisses earlier approvals, so the final approvals come last. Re-verify the branch tree against the reviewed tree before the tag.
- Chart changelog bullets conflict on cherry-pick: place them under the release branch's own unreleased section and say so in the body.
