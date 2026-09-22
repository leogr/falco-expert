# Next-day health check report

Read-only. Run the day after GA with the final-mode scripts and a community sweep; report in one table per area. Every claim tagged; a "regression" needs `[FACT]` plus `[DERIVED]`.

```markdown
# <Component> <version>: next-day health check

**Date:** <YYYY-MM-DD> (UTC)
**Release:** <release-url>

## Release and artifacts

| Check | Result | Evidence |
|---|---|---|
| Release flags: not draft, not pre-release, marked latest | | `gh release view` |
| Packages in the stable buckets | | `artifacts-check.sh --mode final` log |
| Image tags on both registries, multi-arch, `latest` family digests equal to the version digests | | same |
| apt and rpm indexes list the version | | `repo-index-check.py --mode stable` log |
| Release body: component badges, stable links, generated notes, release manager line | | `gh release view --json body` |
| Debug-symbol assets present | | release assets list |

## Chart, website, infra

| Check | Result | Evidence |
|---|---|---|
| Chart index entry with `appVersion: <version>`; release not pre-release; artifact catalog entry | | `chart-check.sh` log |
| Website version banner and versions menu; archived previous version live | | URLs |
| Generated reference pages regenerated from the released image | | PR link |
| Blog post URL returns 200 (production build skips drafts) | | `wait-url-live.py` log |
| Cluster deployment pins on the released chart and image; operator-managed instances; dashboards embedding the chart version | | manifest links |

## Community since the release

| Item | Repository | Class (regression / unrelated / feature request) | Tag | Next action |
|---|---|---|---|---|
| <issue-url> | | | `[FACT]`/`[DERIVED]`/`[INFERENCE]` | |

Sweep: issues and discussions opened organization-wide since the release timestamp, plus older issues with new comments in the same window.

## Follow-ups

- Release-day follow-up PRs waiting for other maintainers' approvals (one grouped item):
  - <pr-url>
  - <pr-url>
- Milestone: <closed / open items left>; next milestone exists: <yes / no>
- Tracking issue: <n> unchecked items left, each with its route
- Parked items re-listed for the maintainer: <pointer>
```
