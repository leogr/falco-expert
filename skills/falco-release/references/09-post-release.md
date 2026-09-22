# 09. After the release

The day after GA is a read-only health check plus a community watch; the following week closes the milestone, the tracking issue, and the loop on lessons. The agent still publishes nothing on its own.

## Next-day health check

Run read-only and report in one table ([`templates/next-day-health-check.md`](../templates/next-day-health-check.md)):

| Area | Check |
|---|---|
| Release flags | The release is not a draft, not a pre-release, and is the repository's latest release |
| Artifacts | [`scripts/artifacts-check.sh --mode final`](../scripts/artifacts-check.sh): packages in the stable buckets, image tags on both registries, `latest` family digests equal to the version digests |
| Repository indexes | [`scripts/repo-index-check.py --mode stable`](../scripts/repo-index-check.py): the apt and rpm indexes list the version, not only the direct files |
| Chart | [`scripts/chart-check.sh`](../scripts/chart-check.sh): index entry with the final `appVersion`, release not flagged pre-release, artifact catalog entry |
| Website | Version switch live, generated reference pages regenerated from the released image, blog post URL returns 200 (the production build skips drafts) |
| Infra pins | Cluster deployment manifests on the released chart and image; operator-managed instances carry their own version field; dashboards embedding the chart version updated |
| Community | Issues and discussions opened organization-wide since the release, older issues with new comments; each classified as regression, unrelated, or feature request |

Classification uses the knowledge base ([Dig Deeper](../../../WORKFLOWS.md#dig-deeper)) and epistemic tags: a "regression" claim needs `[FACT]` plus `[DERIVED]`; a suspicion is `[INFERENCE]` and is reported as such.

## Milestones and leftovers

- The release milestone closes when the last release PR merges. The next milestone exists before leftovers move.
- Leftovers move with a classification, never blanket ([`scripts/milestone-batch.sh`](../scripts/milestone-batch.sh)): unresolved issues to the next milestone with a one-line reason, stale items closed with a pointer, items fixed by the release closed as fixed.
- Follow-up PRs opened on release day (default-branch changelog, chart catch-up, rules testing matrix, meeting notes) need other maintainers' approvals: one grouped actionable item, no separate rows, no pings unless asked.

## Tracking issue closure

The tracking issue closes when every item is ticked or moved. Remaining unchecked items become issues in the owning repositories with a pointer sub-item, then the item is ticked as moved. Announcements (mailing list, chat, blog) are the maintainer's ticks. Announce the thaw of the default branch if the freeze comment promised it.

## Parked items

Items parked during the preparation (infrastructure failures, tooling fixes, driver build gaps, pre-existing test findings) are re-listed after the release with an owner and the fact needed to resume each; the maintainer picks. Pre-existing infrastructure failures found during release preparation get an issue in the owning repository and are postponed; only regressions and untriggered jobs were release work.

## Advisory

The advisory for an embargoed fix is published by the maintainer after the release. The agent still writes nothing that links fix, advisory, and vulnerability, anywhere ([`10-agent-rules.md`](10-agent-rules.md#embargoed-items)). Once the advisory is public the maintainer adds the item to the blog and the notes themselves.

## Close the loop

- Append abstract lessons to [`11-pitfalls.md`](11-pitfalls.md) (no numbers, dates, names, or quotes) and update the checklists in these references when a step was missing.
- Record the concrete events in the release's state file and its reports.
- Refresh the helper scripts in [`scripts/`](../scripts/) when a real run showed a gap; keep any release-specific instance under `OUTPUT_DIR`.
- Delete the release's ephemeral memory notes; the durable knowledge is in this skill and the state file.

## Checklist

- [ ] Next-day health check run read-only and reported in one table; community items classified with tags
- [ ] Release milestone closed; next milestone exists; leftovers moved with a classification
- [ ] Release-day follow-up PRs tracked as one grouped item until merged
- [ ] Tracking issue: unchecked items moved to owning repositories, then closed; thaw announced if promised
- [ ] Parked items re-listed with owners for the maintainer to pick
- [ ] Advisory left to the maintainer; nothing written that links fix, advisory, and vulnerability
- [ ] Lessons appended to the pitfalls (abstract), events to the state file (concrete), scripts refreshed
