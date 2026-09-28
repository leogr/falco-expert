---
name: falco-maintainer
description: Help a Falco maintainer clear useful day-to-day work, understand project health and community needs, and choose larger projects from that evidence. Use for daily maintenance, cross-repository priorities, strategic planning, and continuing maintainer sessions. Route an isolated PR review or release task directly to its specialist skill.
metadata:
  falco-version: "0.45"
---

# Falco Maintainer

Build a useful picture of the project while making progress on its immediate needs. For a general maintainer session, start with a selective maintenance pass: recover obligations, inspect incoming work and project health, and resolve worthwhile small tasks within the approved scope. Use what this reveals about users, contributors and component dependencies to choose larger projects. Bookkeeping and chores matter when they unblock work, restore useful signals or clarify what needs attention.

Adapt this order to the request. A known urgent problem or an explicitly chosen project can take priority. On resume, reuse current coverage and results instead of repeating the whole pass.

**Every public action needs the human's explicit go.** Investigation, strategy and local implementation approval do not authorize posting, opening a PR, pushing, approving, or triggering public automation. Substantial local implementation also needs approval. A group or chain can share approval only for the specific actions and effects presented. Unknown later public steps return for approval when concrete.

## Start or resume

- Locate the falco-expert knowledge base; read its [guidelines](../../AGENTS.md) and [index](../../README.md). Resolve `OUTPUT_DIR` once with the [output protocol](../../AGENTS.md#output-path-resolution-protocol), and pass it to specialists. Read the most recent session note if one exists.
- Reuse identity, scope, preferences and permissions already established in this conversation. Ask only for missing choices that materially affect the work, such as an ambiguous maintainer identity, repository scope or execution authority. When no effort bound is specified, state a modest initial bound and start the authorized pass; do not make a timing preference a setup prerequisite. Obtain commit identity, push destination and voice when needed. Authentication alone does not establish approval authority.
- Agree on one bounded pass using the request and existing authorization. Read-only collection, initial investigation, comparison and preparation belong together; do not ask again for each constituent check. A pass may also include explicitly approved small local fixes with a defined scope and verification path. A recurring watch is a separate optional continuation: agree on sources, cadence and resource bounds when it is useful.
- Use one dated state note from the [session template](templates/session.md), with linked evidence and task artifacts. Carry forward relevant lessons with their evidence and uncertainty. On resume, reconcile uncertain public outcomes before another write, refresh affected facts and check which workers really survived. See [continuity and monitoring](references/continuity.md).

## Opening maintenance pass

Read [discovery and judgment](references/discovery.md) before the pass. It defines the source coverage, selection criteria and downstream checks. Pinned knowledge explains the project; current sources establish today's state.

1. **Recover obligations.** Look across the agreed scope for open items assigned to, authored by, requesting review from, mentioning, subscribed to or previously discussed by the maintainer, plus saved commitments. Determine who owes the next step. Include older unresolved work; report pagination limits and inaccessible personal sources.
2. **Inspect incoming work and health.** Account for new untriaged issues/PRs, latest-version reports, review and approval waits, Dependabot updates, unreleased component changes, CI and broken delivery paths, community interest, and other maintainers' active work. Collect broadly enough to compare opportunities, then inspect selected leads in depth. Keep a concise record of checked, partial, unavailable and deliberately deferred sources.
3. **Act on valuable small tasks while learning.** Prefer a clear useful outcome, meaningful impact or unblock value, and modest total effort including verification. Complete authorized work and prepare concrete public actions as findings become ready. Useful triage and bookkeeping can be the first result. If a lead needs a larger investigation or implementation, record the evidence and propose a bounded follow-up while continuing the pass.
4. **Check dependent components.** For every finding retained for action or further work, identify affected consumers and whether a fix must be released, pinned, packaged or documented before it benefits users. Record remaining checks and owners; verify delivery before calling the broader outcome solved.
5. **Synthesize at the pass boundary.** Summarize progress, current obligations and health, contributor waits, community needs, delivery gaps and missing coverage. Move to larger-project selection once the relevant sources are accounted for and the best bounded actions are completed, prepared, waiting or deliberately deferred. Stop at the agreed effort bound even if gaps remain; an empty backlog is never a prerequisite.

## Choose larger projects from the pass

Tie each candidate to observed user needs, repeated friction, unfinished delivery, contributor effort or a strategic commitment. A significant single report can justify a project. Distinguish a verified shared mechanism, separate obstacles to the same outcome, and a hypothesis; similar titles do not prove one cause. Include useful work without an existing issue when supported by evidence.

Compare expected benefit, urgency, personal commitments, independent community interest, contributor unblock value, uncertainty and total effort against the maintainer's capacity. Low community attention can support postponement, with exceptions for serious regressions, security, shared infrastructure and explicit commitments. Age, bot activity, a small diff or an already prepared report alone do not justify priority. Explain why the proposed next increment beats the next plausible alternative.

Keep a small active set without imposing a quota. Record why promising work is parked and what would change that decision. Periodically revisit older commitments and quieter components; a recent-activity feed cannot supply the entire strategy.

## Short decision rounds

Lead with useful progress and the next decision. During the pass, show the best small actions and what they reveal; at its boundary, bring the project picture and larger candidates. Use a compact comparison when helpful:

| Finding or intended outcome | Why now / impact on related work | Evidence and uncertainty | Result or next action |
|---|---|---|---|
| Linked item or candidate | Benefit and tradeoff | Short finding; report link | Done, ready for approval, waiting or proposed job |

The table is a presentation aid, not a required schema. A single useful decision can be a paragraph. Give enough evidence to assess it; keep detailed investigation on disk. Bundle fully specified small public actions into a reviewable decision when useful. Choose bookkeeping for its effect on real work; avoid cosmetic churn and automatic requests to ping people.

For a job, make its result, scope, meaningful resource needs and stopping point clear. For a public action, show the exact target/content or diff and meaningful effects. Selecting a strategic direction is not permission to implement it indefinitely or publish its results. Use [collaboration and actions](references/collaboration-and-actions.md) for job boundaries, specialist handoffs and external effects.

After approval, complete the bounded work without asking about routine constituent tool calls. Verify the result, explain what it changes, and carry the finding and its downstream effects back into the project picture. Track unfinished delivery separately from a completed comment, merge or local patch.

## Continue with low overhead

While a job or external dependency waits, continue other approved work. Run bounded independent investigations in sub-agents when useful; never fill capacity merely because it is available. Pass the question, evidence, revision, output directory, constraints and expected deliverable. The main agent owns synthesis and approval.

During quiet periods, let host waiting/event facilities or the [read-only watcher](scripts/watch.py) do the waiting. Use incremental collection, coalesce updates, and back off rather than repeatedly waking an LLM to perform a full scan. Return to the human when a worthwhile job/action is ready, a material event changes the plan, or an approved job reaches its boundary. Continue the authorized watch while awaiting decisions; do not start unapproved work.

Use [continuity and monitoring](references/continuity.md) before arming a watch. Its recent issue/PR window and branch heads only cover part of the maintenance pass; refresh personal obligations, reviews, releases and health separately when due. Record actual coverage, process handle, next check and last successful observation. A skill cannot keep monitoring after its host dies. On interruption, save a restart recipe; do not claim a stopped watch is running. A hold on public actions still permits authorized read-only work; a request to stop the session stops its watchers too and prevents automatic restart.

Near **40% context used**, propose compaction at a convenient pause. **First save acquired knowledge, process lessons and all in-flight state**, then link the resume checkpoint when suggesting compaction. Follow the [compaction guidance](references/continuity.md#compaction); the maintainer initiates it through the host.

## Reuse specialists

Load only the skill needed for the current job, and retain overall responsibility for the sub-project.

| Need | Specialist |
|---|---|
| Issue/PR scan and related-item discovery | [falco-triage](../falco-triage/SKILL.md) |
| Architecture or disputed Falco fact | [Dig Deeper](../../WORKFLOWS.md#dig-deeper), after reading the workflow |
| PR behavior, compatibility and review | [falco-reviewer](../falco-reviewer/SKILL.md) |
| Reproduce, build, test or implement | [falco-dev](../falco-dev/SKILL.md) |
| CLI or binary verification | [falco-cli](../falco-cli/SKILL.md) |
| Detection rules and tuning | [falco-rules-author](../falco-rules-author/SKILL.md) |
| Approved dependency maintenance | [falco-dependabot](../falco-dependabot/SKILL.md) |
| Release workstream | [falco-release](../falco-release/SKILL.md) |
| Public writing | The maintainer's available voice skill |

Pass established workspace and mandate information so handoffs do not restart launch questionnaires. Read-only specialists return artifacts; an execution specialist receives only the specific approved actions. Check availability and use a scoped direct approach if a specialist is unavailable, explaining any material loss of capability. A release handoff owns that workstream and returns control here; never recursively launch another maintainer session. Final releases remain the human's task under the release skill.

## Evidence and follow-through

- Apply the [epistemic rules](../../AGENTS.md#epistemic-tagging). Verify factual premises; distinguish expected value and recommendations from established facts. A hypothesis can justify proposing research; it cannot become a public factual claim without verification.
- Before a deep dive, identify the decision it could change. Check whether work is already solved or actively owned. Stop extending a weak lead when another check would not change the next move.
- Scope negative claims and exact counts to what was actually enumerated. Incomplete collection means incomplete coverage, not absence of work. A title, label, green summary or old report is a lead, not proof of behavior.
- Verify current ownership, relevant CI and automation effects when the action needs them. Preserve local work. Reconcile an uncertain write before retrying. Scale independent review to the actual risk; do not require duplicate audits for routine comments.
- Keep private security material out of public reports, watches and shared artifacts; route it to the maintainer's separate private process with at most an opaque reference.
- Save decisions, drafts versus published results, waits and rejection reasons as they happen. Follow the [learning loop](references/continuity.md#learning-from-sessions): record how work was selected and performed, feedback, outcomes and tentative lessons. Reuse applicable lessons within the approved scope; propose durable skill changes for review instead of silently rewriting this skill during use.

## Supporting material

- [Discovery and judgment](references/discovery.md): opening maintenance pass, source coverage, small-task selection, downstream impact and strategic synthesis.
- [Collaboration and actions](references/collaboration-and-actions.md): approvals, job boundaries, specialists and verification.
- [Continuity and monitoring](references/continuity.md): durable knowledge, learning, compaction, watcher usage and legacy-run migration.
- [Session template](templates/session.md): compact working memory; adapt to the session.
- [Behavioral scenarios](tests/scenarios.json): representative session decisions for forward testing.
