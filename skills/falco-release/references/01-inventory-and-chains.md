# 01. Component inventory and action chains

The release is a few chains of serialized actions plus many self-contained tasks. Build the inventory first, derive the chains from the pin graph, then keep one table per chain for the whole cycle. Wall clock is dominated by waiting; the work happens in the gaps.

## Component inventory

Enumerate every component the release depends on and the order they must ship in, walking the pin chain upstream to downstream:

```text
plugins (bundled, e.g. container, k8smeta) ──pinned by──▶ libs ──pinned by──▶ falco ──▶ chart ──▶ infra pins, website
falcoctl, rules ──pinned by──▶ falco
k8s-metacollector ──▶ its chart ──▶ k8smeta plugin compatibility
kernel-crawler lists ──▶ driver configs (test-infra) ──▶ prebuilt drivers
```

Cross-check the maintainer's list against the live release document and the actual version pins in the consumer's build files. Watch for **pin overrides**: a downstream repository may override an upstream default (the same plugin pinned in both libs and falco), so the effective version differs from the upstream default and both pins must move.

Per component record in the state file:

| Field | Source |
|---|---|
| Latest tag and default-branch head | `gh api repos/<r>/tags?per_page=5`, `gh api repos/<r>/git/ref/heads/<default>` |
| What merged since the tag (classified: fix, feature, dependency, CI, docs) | `gh api "repos/<r>/compare/<tag>...<head>"` plus the merged PR list of the milestone |
| Open PRs and issues in the milestone | `gh api "search/issues?q=repo:<r>+milestone:<title>+is:open"` (API counts; CLI list limits truncate silently) |
| Due date | The milestone, then the release document |
| Pin used by consumers and its checksum variable | The consumer's build files (see [`04-upstream-components.md`](04-upstream-components.md#pins-with-checksums)) |
| Release mechanics | What a tag publishes (release workflow, OCI push, signing), and which jobs run only for the final release |

Find the **real nearest deadline** by walking the chain backwards from the release date: the earliest upstream tag is the critical item. Plan checkpoints on the maintainers' working calendar, get the hard "no later than" date, and count backwards for reviews, merges, and the verification gate. Ask early how much slack each upstream tag date really has; slack turns a binary go/no-go into a conditional plan with checkpoints and a fallback.

Assign a release manager early; the tracking issue carries the assignment.

## Chains

In a chain every step needs the exact outcome of the previous one (a merge commit, a green run on that commit, a verified artifact, a tag on that commit); it cannot be pre-empted or shortcut. Independent tasks and other chains run in parallel.

### Detection

When a task appears, first say which chain it belongs to (or that it is standalone) and what it blocks. Typical chains, in the shape observed on real releases:

| Chain | Steps (abbreviated) |
|---|---|
| Critical | plugin PR merged → plugin default branch green → plugin tag → artifacts verified → pin PR in libs → cherry-pick to the libs release branch → libs candidate → falco pins PR → falco cherry-picks → falco candidate |
| Libs final | milestone empty → cumulative sync PR → release branch green and tree matches reviewed release PR → final libs and driver tags → release body checked → falco final pins → falco candidate or GA |
| Chart | compatibility check → chart fix PRs on the default branch → chart candidate PR on the release branch → sync PR in the charts repository → publish → infra pin PR; at GA the same with the final version, then the default-branch catch-up |
| Website | snapshot the previous version (minor only) → doc-impact list → content PRs held → version switch (patch: update existing minor entry) → generated pages → blog |
| Release day | preconditions → release-notes hygiene → changelog PR merged → exact release head green → publish (maintainer) → run green → artifacts → tracking ticks → chart, website, catch-ups, announcements |
| Driver configs | crawler lists complete → crawler fix and release if partial → configs generated → hold lifted and merged → builds → published counts compared with configs |
| Late fix | fix PR on the default branch → cherry-pick appended to the cumulative sync PR → two reviews → merge → release tree matches reviewed PR → tracking tick → new candidate decision |

### The chain table

Keep one table per active chain, refreshed at every chain event and shown in recaps and before asking for a go ([`templates/chain-table.md`](../templates/chain-table.md)):

```text
| Step | State | Who | Next |
```

"Waiting" is precise: which commit, which run, whose approval. The state vocabulary is fixed so a reader can scan it: `staged` (local only) → `open / in review` → `CI settling` → `green at <sha>` → `needs N reviews` → `merged` → `branch green at <sha>` → `gate satisfied` → `tagged` → `run green` → `artifacts verified` → `announced`, with overlays `held`, `parked`, `waiting on others (no pings)`, `go aged`, `needs go`.

Below the tables, one line lists the parallel tracks with their state.

### Rules that keep chains honest

- **The go/no-go for a step needs the step's own evidence** (fully green CI on the exact commit, verified artifacts), and the table says who acts: the maintainer tags, tide merges, other maintainers approve.
- **A late event invalidates every step after it.** A security bump arriving right after a tag moves the pin target. Say which prepared steps are void, re-plan from the changed step, and never push prepared work whose target moved.
- **A go ages.** A standing "do X once CI is green" holds only while nothing changes on that chain. When a chain event or any maintainer message lands between the go and the step, re-confirm with the step's own evidence ("green on this commit, proceed or hold?"), most of all for steps irreversible in practice: an approver's approval on a Prow repository merges at once. Never run a public step while a maintainer question is unanswered.
- **Announcing an intent is not a go.** "Draft it now" in a table is not consent. An investigation the maintainer starts on a chain item pauses every step of that chain that was not explicitly re-confirmed, including steps that look independent; ask rather than decide alone.
- **A hold freezes everything public.** "Hold every public action" freezes every public step of every chain, tracking-issue edits included; watchers and local verification continue, and the tables show the frozen steps as `held`.
- **Unrequested local work is not free**: a long local turn delays the reading of chain events and leads to rushed decisions afterwards. Put long work in sub-agents.
- **Never skip a step to save time**: no tag without green CI on the exact commit, no pin without verified artifacts.

### Waiters implement the chain

One background waiter per step (PR merge, checks on a full SHA, tag appearance, release run, status context, URL live) turns waiting into events; see [`scripts/README.md`](../scripts/README.md). Test their exit codes, not their output. They die with the session and with a reboot: record their IDs, scripts, and timeouts in the state file and re-arm them on resume. A notification can arrive minutes after the event, so re-check live before acting on it. The merge automation waits only for its configured contexts, so a PR can merge while optional jobs on its head still run: the gate for the next step is the default-branch CI on the merge commit, not the PR head. Arm the commit-checks waiter on the merge commit as soon as the merge lands.

## Slip or cut

When an upstream deadline slips, decide explicitly between slipping the date and cutting scope; everything downstream inherits the choice. Present the decision as: current state line, the tagged fact chain, the options with what each costs downstream, a recommendation (an inference, flagged as such), and the exact next public action that would follow each option. Nothing public runs until the answer.

Before tagging an upstream component add an explicit verification gate to the tracking issue: default-branch CI green on the final commit, then the downstream consumer pinned to that candidate with its own CI green. Merged PRs are not a candidate until this passes.

A review that offers the author two acceptable paths stalls the PR. Surface such open forks, give the maintainer the trade-off, and once picked post it as a single instruction plus the remaining checklist, then record it in the tracking issue.

## Daily delta

At the start of each session day, after the resume steps of [`00-setup.md`](00-setup.md#resume): run a delta per component against the previous day (merges and tags, new PRs and issues, default-branch CI right after the previous day's merges because publish workflows break too, milestone counts, live tracking body versus the stored copy). Overnight movement is the agenda: a cleared blocker becomes "ready to tag", a red default branch becomes the first task, untouched items need no re-investigation. Patch the tracking issue for the deltas before reporting.

For kernel lists and generated driver configurations, gate on per-item counts against the last known-good state, never on key presence or a green run. Prebuilt-driver publication counts are informational: the build grid is best effort and missing binaries alone do not block a release. See [`04-upstream-components.md`](04-upstream-components.md#drivers-and-the-build-grid).

## Checklist

- [ ] Every component in the train listed with tag, head, merged-since classification, milestone counts, due date, consumer pins (including overrides), release mechanics
- [ ] Nearest real deadline found by walking the chain backwards; checkpoints and slack recorded
- [ ] Release manager assigned and recorded in the tracking issue
- [ ] Each task assigned to a chain or marked standalone; one table per active chain in the state file, with the fixed state vocabulary
- [ ] Parallel tracks listed with their state; long work delegated to sub-agents
- [ ] Waiters armed per chain step with IDs and timeouts recorded; re-armed after every resume
- [ ] Any late event handled by naming the voided steps and re-planning from the changed step
- [ ] Every go re-confirmed with the step's own evidence when anything changed since it was given
- [ ] Daily delta run and the tracking issue patched before the first report of the day
