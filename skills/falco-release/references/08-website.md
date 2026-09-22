# 08. Website

The website runs in parallel with the code and finishes on release day. Its release document is short and stable ([`falco-website/release.md`](../../../refs/falcosecurity/falco-website/release.md)); the pitfalls are in the mechanics around it: a snapshot that must exist before the switch, a production build that skips drafts, and a deploy preview that is a required check.

## Snapshot of the previous version (minor releases only)

Every new minor archives a snapshot of the whole site, served from a version subdomain; the main site points at the new minor **only after** the snapshot exists ([`release.md:L12-18`](../../../refs/falcosecurity/falco-website/release.md), [`L57`](../../../refs/falcosecurity/falco-website/release.md)). Steps ([`L24-53`](../../../refs/falcosecurity/falco-website/release.md)):

1. Create the branch `v0.<minor>` from the default branch head (check it does not exist first).
2. The hosting provider's branch deploy and branch subdomain are the maintainer's manual steps; ask them to confirm each before continuing.
3. On the branch, edit the versions parameters: `archived_version: true`, `version` set to the last patch of the archived minor, and the first `versions:` block rewritten to the archived entry (`githubbranch` = the patch tag, `docsbranch` = the branch, `url` = the subdomain).
4. Verify the archived site answers and shows the archived banner ([`scripts/wait-url-live.py`](../scripts/wait-url-live.py)).
5. Protect the snapshot branch with a PR in the infra repository's branch-protection configuration (the live path may differ from the pinned [`config.yaml:L297-339`](../../../refs/falcosecurity/test-infra/config/config.yaml); locate it first). An infra repository mid-migration is parked: ask.

## Version switch

One PR on the default branch editing the versions parameters ([`release.md:L61-83`](../../../refs/falcosecurity/falco-website/release.md), pinned example [`params.yaml`](../../../refs/falcosecurity/falco-website/config/_default/versions/params.yaml)): set `version` to the new release and the rules versions to the tags pinned at the final release. For a **minor**, add the new first `versions:` block (default branch, main URL) and rewrite the previous block to its archived form after its snapshot exists. For a **patch of the current minor**, update the existing current-minor entry and its release tag; keep its documentation branch and main URL, leave archived entries alone, and create no snapshot or duplicate minor entry. Hold the PR until the release tag and packages exist, because the "latest" shortcodes build download links from it. Prepare it early; merge it first on release day.

## Content PRs

- Build the **doc-impact list** from the milestone's merged PRs: each PR mapped to "in the tracking checklist", "partial", "missing", or "no doc change"; quote the current text from the default branch before editing, the site may have moved on. Delegate to a website sub-agent with `OUTPUT_DIR`, the consent rules, and a hand-off plan that names the order of operations, the PR per topic, and what stays out of scope.
- Content PRs that describe the new behaviour can be prepared any time; keep them marked work in progress (or held) until the version switch, then un-hold and merge in order.
- Diff the default configuration file between the previous release and the release branch for settings that have no documentation yet, and add the **minimum wording** for last-minute features (what it does, default, how to enable) rather than nothing.
- One branch per PR, PR bodies from the repository template, the maintainer's voice skill applied, `Fixes` lines closing the documentation issues the release resolves.
- A documentation branch that carries a merge commit cannot be rebase-merged: linearize it (a gated rebase asserting tree equality with the old head) before the merge queue can take it.

## Generated pages

Regenerate the version-dependent reference pages from the **released** image, never from a candidate, with the documented commands verbatim ([`release.md:L88-90`](../../../refs/falcosecurity/falco-website/release.md)): the supported events and supported fields pages from the binary's list commands in markdown format; the CLI arguments page by hand from the binary's help when it has no generator. Check the diff: expected deltas must be explainable from the release's changes; anything else is investigated before committing. When a post-processing filter in the documented command misfires on the new output, fix the page by hand and update the command in the release document in the same PR.

## Blog post and drafts

- The blog post is written by the maintainer or a writer from the blog input prompt ([`templates/blog-input-prompt.md`](../templates/blog-input-prompt.md)); the agent does not draft, open, or edit blog content on its own.
- The **production build skips drafts**: a post merged with the draft flag still set is a 404 in production while the deploy preview (built with drafts) shows it. Before merging a blog PR, check the front matter's draft flag; after merging, verify the live URL, not the merge ([`scripts/wait-url-live.py`](../scripts/wait-url-live.py)).
- The blog post merges last, after the version switch and the content PRs, so its links resolve.

## Deploy preview as a required check

The website's default branch requires the DCO check and the hosting provider's deploy-preview status, enforced for administrators too ([`config.yaml:L297-339`](../../../refs/falcosecurity/test-infra/config/config.yaml)). When the provider has an incident the status never arrives; the only way to re-fire it is a new commit SHA on the PR branch (amend, force-with-lease with the observed SHA), on a branch the agent owns, and that re-push stays a manual, consented step ([`scripts/wait-commit-status.sh`](../scripts/wait-commit-status.sh) watches the context).

## Website tracking

The website work has its own tracking issue and milestone; keep its body synthetic and edit it through the same guard flow as the release tracking issue ([`03-tracking-issue.md`](03-tracking-issue.md#edit-guard-flow)). After everything merged: grep the docs for the previous version and candidate strings, and check the live site shows the new version in the banner and the archived version in the versions menu.

## Checklist

- [ ] Minor only: snapshot branch created, archived parameters committed, hosting steps confirmed by the maintainer, archived URL live, protection PR opened at the live configuration path; patch: snapshot steps skipped
- [ ] Version-switch PR prepared with the final rules tags, held until the tag and packages exist, merged first on release day; patch updates the existing minor entry without rotating archives
- [ ] Doc-impact list built from the milestone; content PRs prepared per topic, held until the switch, minimum wording added for undocumented settings
- [ ] Generated pages regenerated from the released image with the documented commands; deltas explained; CLI page updated by hand
- [ ] Blog PR checked for the draft flag before merging; live URL verified after merging
- [ ] Deploy preview handled as a required check; re-fire by new SHA only on a consented manual push
- [ ] Website tracking body kept synthetic and guarded; final sweep for stale version strings done
