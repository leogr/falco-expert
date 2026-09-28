# Discovery and judgment

Use this reference for the opening maintenance pass, subsequent refreshes and project selection. The pass should produce useful small outcomes and a grounded picture of what needs attention. Larger projects emerge from that picture.

## Establish coverage with a shallow first pass

Read the [knowledge-base index](../../../README.md) before searching. Use the [architecture map](../../../specs/architecture-overview.md), [repository/governance digest](../../../digests/falcosecurity/evolution.md), [community digest](../../../digests/falcosecurity/community.md), and component documents relevant to the question. Verify current facts against upstream when they affect a decision; the era snapshot is not a current backlog.

| Area | Sources and checks | Useful result |
|---|---|---|
| Personal obligations | Assigned/authored open issues and PRs, requested reviews, mentions and participation, accessible subscriptions/notifications, prior promises and meeting follow-ups. Read the latest substantive exchange. | What is awaiting this maintainer, already answered, or waiting on someone else? |
| Incoming triage and latest-version reports | New open issues/PRs and items without substantive triage, reported versions, reproduction details, duplicates and existing fixes. Verify current component versions before calling a report a latest-version regression. | A useful answer, routing decision, missing diagnostic, confirmed regression or small fix. Missing labels alone do not prove an item is untriaged. |
| Contributor and review waits | Requested reviews, unresolved discussions, last author changes, reviews and required checks for the current head, approval requirements, holds and active ownership. Inspect other maintainers' work and acceptance questions. | A review or second check that unblocks work, or a concrete author/CI dependency. Green checks alone do not establish readiness for approval. |
| Dependency maintenance | Dependabot and other dependency PRs, affected consumers, compatibility scope, overlapping updates, actual CI failures and relevant security fixes. | A useful bounded update or batch, distinguishing routine maintenance from a migration. The Dependabot execution loop needs its own explicit scope, including merge effects. |
| Unreleased work and delivery gaps | Merged changes since each component's applicable release/tag, intended user benefit, pending follow-ups, consumer pins and packaged artifacts. For plugin monorepos, use the individual plugin's release history. | A fix or feature users are waiting for, its readiness gaps and downstream follow-through. Merged commits alone do not establish release readiness. |
| CI and broken user/developer paths | Default-branch and PR failures, failed-step logs, last successful runs, related failures, installation/artifact/upgrade or documentation breakage suggested by reports and recent changes. | A code defect, shared infrastructure/dependency failure, flaky check or unresolved hypothesis, with the smallest decisive next check. Avoid attributing a failed check to the PR before reading its failure. |
| Community demand and project direction | Independent reports and reproductions, affected use cases, substantive discussion/reactions, active contributor and maintainer investment, accepted proposals and commitments. | Evidence of benefit, momentum or a worthwhile supporting task within a larger initiative. Bot chatter and age contribute little evidence of demand. |

Account for each relevant area on the first general pass, using inexpensive enumeration before selective depth. Adapt coverage to the approved scope and effort; an explicit task or urgent incident may narrow the pass. On subsequent rounds, reuse still-current observations and refresh affected or due sources. Do not deep-review every record before producing useful work.

Enumerate the maintainer's open involvement across the agreed scope, including old unresolved items. Combine and deduplicate assignment, authorship, review-request, mention and participation results; these are different routes to the same obligation. Paginate or partition within the effort bound. If a cap, time limit or inaccessible source prevents full enumeration, record the covered portion and remaining gap. A handful of recently updated records cannot establish the whole personal queue.

Check subscriptions or watched items only through available access or user-provided lists; public participation and a repository watch do not establish a complete item-level subscription list. Treat notification access as optional evidence, and do not mark notifications read or change subscriptions while collecting. Record inaccessible coverage and continue accessible work without asking for extra access by default. Keep private material outside shared reports.

Keep a short source record: area/repository, source or query, time window or revision, checked/partial/unavailable/deferred status, and the material gap or reason. A deliberate deferral should explain its relevance and revisit condition. Watcher `complete-window` only describes its own endpoints and time window. Do not infer inactivity or lack of ownership from missing access or an empty assignee field.

The pinned [governance](../../../refs/falcosecurity/evolution/GOVERNANCE.md) describes broader responsibilities than issue triage, and the [community README](../../../refs/falcosecurity/community/README.md) points to ongoing meeting channels. These are context and source maps; check live documents before relying on current roles or meeting details.

## Choose and complete useful small work

For promising findings, read the relevant body, discussion, code and checks until the next action is concrete. Compare:

- Demonstrated impact, urgency and the cost of leaving it unresolved.
- The maintainer's outstanding obligation, contributor unblock value, and other maintainers' current focus.
- Independent community demand and affected use cases. Prefer substantive interest over raw comment counts. Low interest can support deferral; serious regressions, security, shared infrastructure and explicit commitments can outweigh it.
- Confidence and total effort: investigation, compatibility, implementation, meaningful verification, coordination and downstream delivery. A tiny diff or quick approval command can carry a large review burden.
- Whether the action is a useful standalone outcome or an enabling step in a larger effort.

Select a small active set without a quota or a numeric score. Useful triage, clarifying a documented answer, verifying a second approval, correcting a broken check, or preparing an uncomplicated dependency update can lead the pass. Explain the benefit; labels, activity volume and ease alone do not make work valuable. Defer a weak lead when another check would not change the decision.

Interleave collection with approved small jobs. Prepare or complete the best bounded actions as they become clear, then return to the pass. Use the [job boundaries](collaboration-and-actions.md#jobs-and-approval) to distinguish already authorized local work from public effects or substantial new work. Bundle fully specified public actions when useful; approval waiting on one item need not stop independent collection or approved fixes. Never treat a pass as standing permission for unknown public effects.

Record each retained finding's next action, owner/dependency, evidence and state: completed, ready for approval, needs a bounded check, waiting or deferred. If it grows beyond the pass's effort/risk bounds, preserve the useful evidence and propose a separate job. Do not turn an apparently small fix into an unapproved refactor.

## Follow the impact through components

For every finding retained for action or further work, check relevant upstream dependencies and direct consumers. Establish who benefits, what another component needs, and how the user-visible outcome will be verified. Use known architecture to select these checks; expand further only when an actual dependency warrants it. If applicability or a consumer's effective version is unknown, retain it as an explicit gap.

Where applicable, follow **source change → component release → consumer pin/configuration → packaged or deployed behavior**. Inspect the actual versions and compatibility constraints at each relevant step. A plugin fix may be merged but unreleased; a released fix may still be absent from Falco or a chart. Distinguish the completed local step from the remaining delivery work, and involve existing owners rather than duplicating their implementation. A finding with no relevant downstream action should record why briefly.

Use the release specialist for readiness and release work, including component releases; final publication stays with the human. A version bump or release proposal only becomes a useful recommendation after identifying the changes, benefit and readiness evidence. Follow through until the agreed outcome is verified or its remaining dependency is explicit.

## Synthesize the pass and select larger projects

At the agreed boundary, summarize what was completed or prepared, remaining personal obligations, current health, contributor waits, community needs, delivery gaps and coverage limits. A useful first decision round may contain only small actions and this emerging picture.

Move into larger-project comparison when the relevant sources have been accounted for and the best small opportunities within the effort bound are completed, ready, waiting or explicitly deferred. Explain any material coverage that remains before making a broad ranking. Do not wait for an empty backlog or invent projects when the pass produced no compelling larger need. Urgent harm or an explicit maintainer direction can justify focusing earlier.

Read enough of an issue's body, discussion and relevant code to understand the claimed problem before grouping it. Connect issues and PRs using evidence: affected behavior, component boundaries, dependencies, existing initiatives and proposed remedies. Distinguish:

- **Shared mechanism:** evidence connects the symptoms to one cause or dependency.
- **Shared outcome:** separate problems obstruct the same user/project improvement; they need not share a cause.
- **Research hypothesis:** a plausible connection whose confirmation would change what to do next.

Keep links and uncertainties visible. Split a group if evidence contradicts the proposed connection. Overlapping groups are fine when one component or issue contributes to several outcomes. An existing author or project may already own the work: identify the useful contribution rather than proposing duplicate implementation.

For a candidate, describe the intended improvement, who benefits, linked evidence, current work, major uncertainty and the next bounded job. Give it a meaningful outcome name. Avoid turning every label, repository or handful of similar titles into a project.

Connect each candidate to evidence acquired during the pass or a known strategic commitment. Repeated symptoms are one signal; a single significant report or unanswered design commitment can also justify work. Explain how completed or proposed small tasks contribute to it. Useful larger jobs include reproducing an unresolved failure, mapping remaining dependencies, comparing approaches or defining acceptance cases. Name the decision each job will change.

## Rank with reasons

Explain the tradeoff between candidates in terms the maintainer can challenge:

- Expected benefit to users, contributors or project direction; what evidence supports it?
- Dependencies and commitments it unlocks; consequences of waiting.
- Confidence in the proposed connection and solution; what small investigation reduces consequential uncertainty?
- Effort and resources for the next useful increment, and the maintainer's interests/capacity.

Separate expected benefit from certainty. Do not turn a speculative benefit into a proven fact or require certainty before proposing research. Use meaningful time constraints when present; age alone does not create urgency. Strategic work can be worthwhile without a release date. Reassess the balance as small tasks reveal recurring problems or diminishing returns.

Present a short shortlist grounded in the pass. Show why the leading candidate ranks above the next alternative and what evidence could reverse that ranking. An existing report or familiar issue is reusable evidence, not a reason to prefer it. Keep other promising candidates on disk with a revisit condition. A ranking is a recommendation for the human; it does not authorize implementation or publication.

## Bound investigation by the decision

Within an approved job, use the smallest check that can answer the next question. Before widening a dive, identify what the extra work could change. Verify root causes from definitions/call sites and meaningful reproduction where needed; inspecting more files is not itself progress.

Use [triage](../../falco-triage/SKILL.md) for discovery and [Dig Deeper](../../../WORKFLOWS.md#dig-deeper) for Falco knowledge. Narrow their scope to the approved decision question. Save useful findings once and reuse them while their source revisions and relevant conditions still hold. If new facts invalidate them, record the correction and its impact on related work.

A valid result can be a disproved hypothesis, a reason to leave active contributor work alone, or an explicit choice to wait. Keep such lessons so future rounds do not repeat the same low-value investigation.
