# <component> <version> release: state

Concrete, durable memory of one release preparation. Everything identifier-bearing goes here (PR numbers, SHAs, waiter IDs, decisions with their rationale, UTC times). Abstract lessons go to the skill's pitfalls reference instead. Newest resume checklist first; daily bullets below, appended in order, every timestamp from `date -u`.

## Mandate

| Item | Value |
|---|---|
| Maintainer login | `<login>` |
| Approver in | `<repo>`, `<repo>` (from `OWNERS` at `<sha>`) |
| Push target | `<upstream branch prefix or fork>` |
| Commit identity | `<Name> <<e-mail>>`, trailer `Signed-off-by: <Name> <<e-mail>>`, AI co-author: `<allowed / not allowed>` |
| Voice skill | `<skill name or none>` |
| Target | `<component> <version>`, planned `<date>`, `<minor / patch>` |
| Standing constraints | pings: `<policy>`; holds: `<none / scope>`; parked repositories: `<list>` |
| Security intake | `<none / one private item handled by the maintainer>` |
| Tools | gh `<v>`, jq `<v>`, python3 `<v>`, git `<v>`, helm `<v / absent>`, go `<v / absent>` |
| `OUTPUT_DIR` | `<absolute path>` |

## Components

| Component | Latest tag | Default head | Merged since tag (fix / feat / deps / ci / docs) | Milestone open | Due | Pinned by | Notes |
|---|---|---|---|---|---|---|---|
| `<plugin>` | | | | | | libs, falco | pin override in falco |
| libs | | | | | | falco | driver tag: `<needed / not needed>` |
| falcoctl | | | | | | falco | |
| rules | | | | | | falco | |
| k8s-metacollector | | | | | | its chart, k8smeta | |
| falco | | | | | | chart, website, infra | |
| chart | | | | | | infra | |

## Chains

<!-- one table per active chain; refresh at every chain event; fixed state vocabulary:
staged -> open / in review -> CI settling -> green at <sha> -> needs N reviews -> merged -> branch green at <sha>
-> gate satisfied -> tagged -> run green -> artifacts verified -> announced; overlays: held, parked,
waiting on others (no pings), go aged, needs go -->

### Chain: <name>

| Step | State | Who | Next |
|---|---|---|---|
| | | | |

Parallel tracks: `<track>: <state>`; `<track>: <state>`.

## Waiters

| ID | Script and args | Armed (UTC) | Timeout | Fired / alive |
|---|---|---|---|---|
| | | | | |

## Decisions

| When (UTC) | Decision | Options shown | Chosen | Rationale pointer |
|---|---|---|---|---|
| | | | | |

## Tracking issue

- Issue: `<url>`; stored copy: `<abs path>`; snapshot: `<abs path>`
- Last edit: `<UTC>` `<script>` `GUARD_OK` `<checked>/<unchecked>`; stored == snapshot == live: `<yes / no>`
- Staged, waiting for a go: `<script> (<n> edits)` or `none`

## Reports

| Topic | Path |
|---|---|
| | |

## Resume checklist <N> (written <UTC>, <trigger: before compaction / end of session / after <event>>)

Read `AGENTS.md`, `README.md`, `SKILL.md`, `10-agent-rules.md`, `11-pitfalls.md` first, then the daily bullets above for details. Checklist <N-1> still holds where not superseded here.

1. Where we are: default branch `<sha>`, release branch `<sha>` (intentional differences from default: `<none / reviewed list>`; tree matches reviewed release PR: `<yes / differences>`); latest candidate `<candidate>` at `<sha>`; milestone open: `<n>`; target: `<date or "slipped to">`.
2. Tracking issue: last edit, counts, stored == snapshot == live; staged edits waiting for a go.
3. Chains now: one sub-bullet per chain, current step -> next step (who) -> terminal; gate evidence; held or parked items with the reason.
4. Decisions pending (maintainer): options, inputs shown, recommendation.
5. Waiting on others (no pings): PRs needing reviews; bot PRs; upstream fixes.
6. Parked: items with the fact needed to resume each.
7. Before the next tag or the GA sequence: ordered to-do with owners (the maintainer tags, never the agent).
8. Waiters alive at write time (ID, script, args, timeout) or "none" and why; restart recipe with durable script paths.
9. Local checkouts and scripts (durable dir versus temporary dir): worktrees, gated scripts (dry-run done / staged / applied), bodies, commit messages; reports written.
10. Standing rules reaffirmed (compact list).
11. Security constraint: private item stays opaque everywhere.

UPDATE (<UTC>): <delta since writing, appended instead of rewriting>.

## Daily log

- `<UTC>` <event, exact objects, outcome, next action>
