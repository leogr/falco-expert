# PR body: component pin bump

Use the repository's PR template headings (the live default branch wins). One commit per component bumped. Checksums come from two independent downloads of the upstream source archive after the upstream tag exists; say so. References in a sub-list when there are several. Apply the maintainer's voice skill when available; never add an AI attribution line unless the maintainer allows it.

```markdown
**What type of PR is this?**

/kind release

**Any specific area of the project related to this PR?**

/area build

**What this PR does / why we need it**:

This PR bumps the dependencies pinned for `<version or candidate>`:

- <library> to `<version>`, cut from the `<upstream-release-branch>` branch 👉 <release-url> (the archive checksum is the SHA256 of the tag tarball)
- <cli-tool> to `<version>` 👉 <release-url> (hashes verified against the published checksums file)
- the `<plugin>` plugin to `<version>` 👉 <release-url> (hashes are the SHA256 of the stable tarballs on the download bucket)

The driver pin stays at `<driver-version>`, since nothing under `driver/` changed upstream after the previous tag. <or: The driver pin moves to `<driver-version>`.>

<The pins will move to the final tags once cut.>

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

Notes:
- A pin PR opened before the upstream tag exists cannot carry the checksum: prepare the branch, wait for the tag, hash the archive from two independent downloads, amend, then push.
- A downstream repository may override an upstream default pin (the same plugin pinned in both the library and the consumer): both PRs are needed; say so in the body of each.
- Distinguish an interim "pin to a commit" PR from the final version-pin PR; the tracking issue points at the latter.
