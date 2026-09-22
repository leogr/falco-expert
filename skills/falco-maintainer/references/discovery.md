# Discovery and judgment

Use this reference when starting a discovery job, revisiting project priorities, or evaluating a new cluster of issues. The outcome is a defensible recommendation about where to work together.

## Build context selectively

Read the [knowledge-base index](../../../README.md) before searching. Use the [architecture map](../../../specs/architecture-overview.md), [repository/governance digest](../../../digests/falcosecurity/evolution.md), [community digest](../../../digests/falcosecurity/community.md), and component documents relevant to the question. Verify current facts against upstream when they affect a decision; the era snapshot is not a current backlog.

| Lens | Useful sources | Decision it can inform |
|---|---|---|
| Commitments and direction | Maintainer notes, proposals, roadmap discussions, meeting follow-ups | Which promised outcome or unresolved design deserves attention? |
| User experience | Reports, support discussions, installation/upgrade paths, detection behavior, documentation | Which difficulties form a worthwhile improvement? |
| Contributor progress | Full relevant discussion, reviews, changed code, CI and maintainer promises | What can the maintainer do to unlock useful work? |
| Project health | Default-branch failures, repeated CI symptoms, test gaps, dependencies | Is a shared problem consuming effort or hiding regressions? |
| Component relationships | Effective consumer pins, APIs, compatibility and downstream tests | Has an improvement actually reached its consumers? |
| Community and responsibility | Accessible agendas, contribution paths, ownership, onboarding | Is a coordination or contributor-support job needed? |

Choose sources for the authorized scope; do not audit every lens in every round. Mention an inaccessible source when it limits a relevant conclusion. Do not infer inactivity or lack of ownership from missing access or an empty API field.

The pinned [governance](../../../refs/falcosecurity/evolution/GOVERNANCE.md) describes broader responsibilities than issue triage, and the [community README](../../../refs/falcosecurity/community/README.md) points to ongoing meeting channels. These are context and source maps; check live documents before relying on current roles or meeting details.

## Form candidate sub-projects

Read enough of an issue's body, discussion and relevant code to understand the claimed problem before grouping it. Connect issues and PRs using evidence: affected behavior, component boundaries, dependencies, existing initiatives and proposed remedies. Distinguish:

- **Shared mechanism:** evidence connects the symptoms to one cause or dependency.
- **Shared outcome:** separate problems obstruct the same user/project improvement; they need not share a cause.
- **Research hypothesis:** a plausible connection whose confirmation would change what to do next.

Keep links and uncertainties visible. Split a group if evidence contradicts the proposed connection. Overlapping groups are fine when one component or issue contributes to several outcomes. An existing author or project may already own the work: identify the useful contribution rather than proposing duplicate implementation.

For a candidate, describe the intended improvement, who benefits, linked evidence, current work, major uncertainty and the next bounded job. Give it a meaningful outcome name. Avoid turning every label, repository or handful of similar titles into a project.

Examples of useful first jobs include reproducing a common failure, comparing competing approaches, mapping an initiative's remaining dependencies, defining acceptance cases, reviewing an enabling PR, or implementing a scoped fix after approval. “Triage these issues” is too vague when the actual decision is which improvement to pursue.

## Rank with reasons

Explain the tradeoff between candidates in terms the maintainer can challenge:

- Expected benefit to users, contributors or project direction; what evidence supports it?
- Dependencies and commitments it unlocks; consequences of waiting.
- Confidence in the proposed connection and solution; what small investigation reduces consequential uncertainty?
- Effort and resources for the next useful increment, and the maintainer's interests/capacity.

Separate expected benefit from certainty. Do not turn a speculative benefit into a proven fact or require certainty before proposing research. Use meaningful time constraints when present; age alone does not create urgency. Strategic work can be worthwhile without a release date. Metadata chores and easy comments should not crowd it out.

Present a short shortlist as soon as there is enough evidence to recommend a next job. Show why the leading candidate ranks above the next alternative and what evidence could reverse that ranking. Keep other promising candidates on disk with a revisit condition. A ranking is a recommendation for the human; it does not authorize implementation or publication.

## Bound investigation by the decision

Within an approved job, use the smallest check that can answer the next question. Before widening a dive, identify what the extra work could change. Verify root causes from definitions/call sites and meaningful reproduction where needed; inspecting more files is not itself progress.

Use [triage](../../falco-triage/SKILL.md) for discovery and [Dig Deeper](../../../WORKFLOWS.md#dig-deeper) for Falco knowledge. Narrow their scope to the approved decision question. Save useful findings once and reuse them while their source revisions and relevant conditions still hold. If new facts invalidate them, record the correction and its impact on related work.

A valid result can be a disproved hypothesis, a reason to leave active contributor work alone, or an explicit choice to wait. Keep such lessons so future rounds do not repeat the same low-value investigation.
