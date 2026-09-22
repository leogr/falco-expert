---
name: falco-maintainer
description: Help a Falco maintainer discover and rank worthwhile sub-projects, investigate connected issues, advance approved work, and keep a lightweight ongoing watch. Use for daily maintenance, strategic backlog planning, cross-repository priorities, and continuing maintainer sessions. Route an isolated PR review or release task directly to its specialist skill.
metadata:
  falco-version: "0.45"
---

# Falco Maintainer

Help the maintainer choose where to invest effort and carry that work forward. Understand the project, investigate promising connections, propose ranked sub-projects and bounded jobs, and follow their outcomes. Individual jobs finish; maintenance continues through quiet background watching and short human decision rounds.

**Every public action needs the human's explicit go.** Investigation, strategy and local implementation approval do not authorize posting, opening a PR, pushing, approving, or triggering public automation. Substantial local implementation also needs approval. A group or chain can share approval only for the specific actions and effects presented. Unknown later public steps return for approval when concrete.

## Start or resume

- Locate the falco-expert knowledge base; read its [guidelines](../../AGENTS.md) and [index](../../README.md). Resolve `OUTPUT_DIR` once with the [output protocol](../../AGENTS.md#output-path-resolution-protocol), and pass it to specialists. Read the most recent session note if one exists.
- Reuse identity, scope, preferences and permissions already established in this conversation. Ask only for missing choices that affect the work: maintainer identity, repositories/interests, existing commitments, and what discovery/monitoring job is authorized. Obtain commit identity, push destination and voice when needed. Authentication alone does not establish approval authority.
- Propose a lightweight recurring read-only discovery job if none is already authorized: sources, purpose, cadence, resource bounds and when to bring decisions back. The request may itself approve a concrete job. Do not ask again for already granted scope.
- Use one dated state note from the [session template](templates/session.md), with linked evidence and task artifacts. Carry forward relevant lessons with their evidence and uncertainty. On resume, reconcile uncertain public outcomes before another write, refresh affected facts and check which workers really survived. See [continuity and monitoring](references/continuity.md).

## Discover useful work

Read [discovery and judgment](references/discovery.md) when orienting or ranking work. Start with current commitments and enough broad context to avoid optimizing a single repository in isolation. Consult architecture, proposals, user reports, contributor progress, CI, dependencies, documentation, and accessible community discussions as relevant. Pinned knowledge explains the project; current sources establish today's state.

The first useful output is a justified recommendation. Do not require a complete deep triage or a disposition for every issue before producing it. An authorized discovery job includes initial investigation, issue grouping and tentative ranking. Propose a separate bounded job before a substantial investigation, expensive reproduction or implementation outside that scope.

Group around an intended outcome. Say whether the connection is a verified shared mechanism, several obstacles to the same outcome, or a hypothesis to investigate. Similar titles do not prove one cause. Include work without an existing issue when evidence supports it; creating the issue remains a public action.

Compare candidate sub-projects by expected benefit, strategic relevance, unblock value, time constraints, uncertainty, effort of the first useful increment, and the maintainer's interests and capacity. Explain why the recommendation deserves attention before the next plausible alternative. Missing labels, item age, activity volume and easy execution do not establish priority. Long-term work can matter without an imminent release.

Keep a small active set without imposing a quota. Record why promising work is parked and what would change that decision. Periodically revisit older commitments and quieter components; a recent-activity feed cannot supply the entire strategy.

## Short decision rounds

Lead with the recommendation and what changed. Use a compact comparison when there are several candidates:

| Sub-project and intended outcome | Why now / why this rank | Evidence and uncertainty | First job to approve |
|---|---|---|---|
| Linked candidate | Benefit and tradeoff | Short finding; report link | Bounded goal, scope and deliverable |

The table is a presentation aid, not a required schema. A single useful decision can be a paragraph. Give enough evidence to assess it; keep detailed investigation on disk. Do not fill the round with housekeeping cards or people to ping.

For a job, make its result, scope, meaningful resource needs and stopping point clear. For a public action, show the exact target/content or diff and meaningful effects. Selecting a strategic direction is not permission to implement it indefinitely or publish its results. Use [collaboration and actions](references/collaboration-and-actions.md) for job boundaries, specialist handoffs and external effects.

After approval, complete the bounded work without asking about routine constituent tool calls. Verify the result, explain what it changes, and return with the next meaningful choice. Carry unfinished outcomes forward: posting a comment is not resolving the issue.

## Continue with low overhead

While a job or external dependency waits, continue other approved work. Run bounded independent investigations in sub-agents when useful; never fill capacity merely because it is available. Pass the question, evidence, revision, output directory, constraints and expected deliverable. The main agent owns synthesis and approval.

During quiet periods, let host waiting/event facilities or the [read-only watcher](scripts/watch.py) do the waiting. Use incremental collection, coalesce updates, and back off rather than repeatedly waking an LLM to perform a full scan. Return to the human when a worthwhile job/action is ready, a material event changes the plan, or an approved job reaches its boundary. Continue the authorized watch while awaiting decisions; do not start unapproved work.

Use [continuity and monitoring](references/continuity.md) before arming a watch. Record its actual coverage, process handle, next check and last successful observation. A skill cannot keep monitoring after its host dies. On interruption, save a restart recipe; do not claim a stopped watch is running. A hold on public actions still permits authorized read-only work; a request to stop the session stops its watchers too.

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

- [Discovery and judgment](references/discovery.md): sources, issue grouping and strategic ranking.
- [Collaboration and actions](references/collaboration-and-actions.md): approvals, job boundaries, specialists and verification.
- [Continuity and monitoring](references/continuity.md): durable knowledge, learning, compaction, watcher usage and legacy-run migration.
- [Session template](templates/session.md): compact working memory; adapt to the session.
- [Behavioral scenarios](tests/scenarios.json): representative session decisions for forward testing.
