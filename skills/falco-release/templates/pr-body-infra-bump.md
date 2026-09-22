# PR body: infra deployment bump

Points the project's own cluster deployment manifest (the application definition in the infra repository) at a chart version and app version, for a candidate rollout or for the GA pin. Gates before opening: the chart version is in the public Helm index (the cluster pulls it from there) and the images exist on the registry. An infra repository in the middle of a migration is parked: ask before touching it. Apply the maintainer's voice skill when available.

```markdown
**What type of PR is this?**

/kind cleanup

**Any specific area of the project related to this PR?**

/area config

**What this PR does / why we need it**:

Points the <Component> application at chart `<chart-version>` (<Component> `<version or candidate>`) to <test the candidate on our clusters / align the clusters with the release>.

- chart `<chart-version>` 👉 <charts-release-url>
- image `<registry>/<image>:<version>` and `<registry>/<driver-loader-image>:<version>`
- <plugin references bumped in the values, if any>

<For a candidate: we will watch the dashboards for restarts, drops, and event rates, and roll back by reverting this PR if anything looks off.>

Part of <tracking-issue-url>

**Which issue(s) this PR fixes**:

**Special notes for your reviewer**:

Rendered the application values locally; the only changes are the versions above.

**Does this PR introduce a user-facing change?**:

```release-note
NONE
```
```

Commit message pattern: `chore(config/applications): <testing | update> <Component> <version>`, one sign-off line ([`commit-message.md`](commit-message.md)). After the merge, check every cluster's pin (operator-managed instances carry their own version field) and the dashboard links that embed the chart version.
