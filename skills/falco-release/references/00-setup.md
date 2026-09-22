# 00. Setup

Run this at launch and again at every resume. The mandate, the output directory, and the state file are what make a multi-week release survivable across compactions, reboots, and hand-offs.

## Mandate

Identity is an input, never an assumption. Collect and confirm in one short table:

| Item | How to establish it | Why it matters |
|---|---|---|
| Maintainer's GitHub login | `gh api user --jq .login` for the authenticated account; ask if the maintainer is not the operator | Every public action is attributed to this account |
| Repositories where they can approve | Read `OWNERS` (and `OWNERS_ALIASES`) at the live default-branch head of each in-scope repository; `approvers` may approve, `reviewers` may only LGTM | Approving on a Prow repository merges; a reviewer's approval does not satisfy branch protection |
| Where they push branches | Ask: upstream branch prefix (for example `<login>/...`) or a fork | Pin, sync, and chart PR scripts need the push target |
| Open-source commit identity | Name, e-mail, and the exact `Signed-off-by:` trailer they use for open-source work; whether an AI co-author trailer is allowed (default: not) | DCO requires author == sign-off; a corporate e-mail configured in git may not be the one they sign with |
| Voice skill | Ask which style skill, if any, applies to text published under their name | Public text is ghost-written; never imitate a person without their skill |
| Target release | Component, version, planned date, whether it is a minor or a patch | Patch releases have a different scope (see the patch stance in [`04-upstream-components.md`](04-upstream-components.md#patch-releases)) |
| Security intake | Ask whether any embargoed item exists; record only an opaque line | See [`10-agent-rules.md`](10-agent-rules.md#embargoed-items) |
| Standing constraints | Ping policy (default: no pings), hold status, repositories parked (for example an infra repository mid-migration) | These change what the agent may propose |

Authentication does not prove authority: the same account can be an approver in one repository and a plain contributor in another. Re-read ownership before any approval or code-changing action, at the exact head OID.

## Tools

Check once and record the versions in the state file:

```bash
gh auth status
gh --version
jq --version
python3 --version
git --version
helm version 2>/dev/null || echo "helm not installed (chart render checks will be skipped)"
go version 2>/dev/null || echo "go not installed (local release-notes build unavailable)"
date -u +%FT%TZ
```

Every timestamp written to a file comes from `date -u`; local time differs and sub-agent timestamps are suspect until checked.

## Output directory and state file

1. Resolve `OUTPUT_DIR` with the [Output Path Resolution Protocol](../../../AGENTS.md#output-path-resolution-protocol). Inside falco-expert it is `<repo-root>/output/`; outside, the maintainer chooses once.
2. Create `OUTPUT_DIR/YYYY-MM-DD-<component>-<version>-release/` and instantiate [`templates/state-file.md`](../templates/state-file.md) as `YYYY-MM-DD-<component>-<version>-release-state.md`. The state file is the durable memory: concrete events, SHAs, PR numbers, waiter IDs, decisions, and the resume checklists live there. Abstract lessons do not (they go to [`11-pitfalls.md`](11-pitfalls.md)).
3. Keep every draft destined for GitHub, every gated script instance, the stored tracking body and its snapshot, and every report under that directory. The temporary directory is per-boot scratch: re-create helpers there without checking, never rely on them across sessions.
4. Pass `OUTPUT_DIR` as an absolute path in every sub-agent prompt; sub-agents never resolve it themselves.

## Resume

On resume (new session, after compaction, after a reboot):

1. Re-read [`AGENTS.md`](../../../AGENTS.md), [`README.md`](../../../README.md), [`SKILL.md`](../SKILL.md), [`10-agent-rules.md`](10-agent-rules.md), and [`11-pitfalls.md`](11-pitfalls.md).
2. Open the newest state file and read its newest resume checklist first (they are incremental; older ones hold where not superseded).
3. Audit live state before acting: default-branch and release-branch heads and whether their trees are equal, candidate tags, open PRs in the milestone with review counts, tracking body live versus stored, new issues and comments since the last recorded timestamp.
4. Distinguish what was applied upstream from what was only drafted or staged. A staged gated script is not done.
5. Waiters and background agents never survive a session: list the ones recorded as alive, re-arm the waiters from their durable scripts, and check whether each sub-agent deliverable exists and is final before relying on it.
6. Old consent is invalid. Re-collect a go for anything public that was pending.

## Documents to read live

The pinned copies in [`refs/`](../../../refs/) describe the era; the live default branch of each repository is authoritative and may differ. Read the live version with a raw-content request and note in the state file which steps changed:

| Component | Pinned release document | Live check |
|---|---|---|
| falco | [`RELEASE.md`](../../../refs/falcosecurity/falco/RELEASE.md) | `gh api repos/falcosecurity/falco/contents/RELEASE.md -H "Accept: application/vnd.github.raw"` |
| libs and drivers | [`release.md`](../../../refs/falcosecurity/libs/release.md) | same pattern on `falcosecurity/libs` |
| plugins | [`release.md`](../../../refs/falcosecurity/plugins/release.md) | `falcosecurity/plugins` |
| rules | [`RELEASE.md`](../../../refs/falcosecurity/rules/RELEASE.md), [`FALCO_VERSIONS`](../../../refs/falcosecurity/rules/.github/FALCO_VERSIONS) | `falcosecurity/rules` |
| charts | [`release.md`](../../../refs/falcosecurity/charts/release.md) | `falcosecurity/charts` |
| falcoctl | [`release.md`](../../../refs/falcosecurity/falcoctl/release.md) | `falcosecurity/falcoctl` |
| plugin-sdk-go | [`release.md`](../../../refs/falcosecurity/plugin-sdk-go/release.md) | `falcosecurity/plugin-sdk-go` |
| website | [`release.md`](../../../refs/falcosecurity/falco-website/release.md), [`params.yaml`](../../../refs/falcosecurity/falco-website/config/_default/versions/params.yaml) | `falcosecurity/falco-website` |

Never pipe the raw content into a decoder or an inline interpreter; the raw `Accept` header returns plain text.

## Knowledge base to load

Before searching upstream, load the digests for the components in scope so that terminology, pins, and mechanics are already known: [`falco`](../../../digests/falcosecurity/falco/README.md), [`libs`](../../../digests/falcosecurity/libs/README.md), [`plugins`](../../../digests/falcosecurity/plugins.md), [`charts`](../../../digests/falcosecurity/charts.md), [`rules`](../../../digests/falcosecurity/rules.md), [`falcoctl`](../../../digests/falcosecurity/falcoctl.md), [`k8s-metacollector`](../../../digests/falcosecurity/k8s-metacollector.md), [`test-infra`](../../../digests/falcosecurity/test-infra/README.md), [`falco-website`](../../../digests/falcosecurity/falco-website/docs.md), [`evolution`](../../../digests/falcosecurity/evolution.md) (repository scopes and maintainers), [`community`](../../../digests/falcosecurity/community.md) (meeting notes). For any disputed fact, run [Dig Deeper](../../../WORKFLOWS.md#dig-deeper) after re-reading [`WORKFLOWS.md`](../../../WORKFLOWS.md).

## Checklist

- [ ] `OUTPUT_DIR` resolved once and recorded; "Detected falco-expert repository." said when applicable
- [ ] Mandate table confirmed by the maintainer (login, approver repositories, push target, commit identity and sign-off, co-author policy, voice skill, target, security intake, standing constraints)
- [ ] Tool versions and the UTC clock recorded in the state file
- [ ] State directory and state file created from the template, or the newest resume checklist read and the live audit done
- [ ] Live release documents read for every component in scope; differences from the pinned copies noted
- [ ] Digests loaded for the components in scope
- [ ] Waiters re-armed and sub-agent deliverables checked (resume only)
