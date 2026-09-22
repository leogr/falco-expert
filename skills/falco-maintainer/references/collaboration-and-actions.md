# Collaboration and actions

Use this reference when proposing a job, handing work to a specialist, or preparing a public effect. Approval belongs to the human; the agent makes the decision concrete and follows through.

## Jobs and approval

Every action item or bounded group/chain/job needs approval. A discovery mandate can explicitly cover recurring read-only collection, initial issue investigation, grouping and ranking. Reuse it without asking before each fetch. A proposed deeper investigation or implementation job should state:

- Intended outcome and why this is the next useful move.
- Scope: repositories, questions or changes included, and a clear stopping point.
- Expected artifact or result and meaningful resource needs, such as a large build or privileged test.
- Any public effects proposed, separately identified for explicit approval.

Substantial local implementation requires approval **before** doing it. Make that proposal concrete through the intended behavior and scope; do not implement it first to obtain permission afterward. Once the job is approved, routine investigation, preparation and validation within it need no repeated approval. Reassess with the human when the work expands materially or reaches an unresolved design choice.

Choosing a sub-project does not authorize every possible job inside it. Approval to investigate or implement does not authorize posting, pushing or opening a PR. For example: “investigate these reports and prepare a fix proposal” permits that research and proposal; it does not permit implementing a large solution or publishing a comment.

## Public approval

For each proposed public action, show the exact target, prepared content/diff and meaningful effects, then obtain an explicit go. Keep text in a file so the approved payload is reviewable. Apply the maintainer's available voice skill. The user may approve a coherent group of fully described actions together; do not expand it into a standing permission for unknown later actions.

A chain can describe future dependencies without authorizing them. If its next public content or target depends on results not yet known, return with that concrete step for approval. A tool permission or GitHub write access is not human approval of the action.

Honor explicit holds across the stated scope. A question that calls an approved action into doubt pauses that action while clarified. Recheck decision-relevant state before execution; a material change in target, payload, effect or supporting evidence requires a fresh decision. An unrelated timestamp change alone does not require redoing the entire investigation. Do not ask again for unchanged work already explicitly approved.

Approvals and Prow commands can enable automatic merging or other effects. Check the actual repository configuration, reviews, labels, head and applicable ownership before proposing them. The [review process](../../../refs/falcosecurity/.github/contributing/review-process.md) and [Prow digest](../../../digests/falcosecurity/test-infra/prow-config.md) explain the context; live configuration determines the current behavior. Show merge consequences to the human. Never approve the actor's own PR. Final release publication goes to the human through [falco-release](../../falco-release/SKILL.md).

## Execute and verify proportionately

Use ordinary tools or an inspected operation-specific helper. There is no generic card compiler or closed executor catalog. Prefer the project's documented mechanism when it applies. If an effect is unclear, resolve that uncertainty before asking to execute it.

Immediately before a write, note the specific approved action and intended target/content in the session record. Afterward save its returned link or receipt, then inspect the relevant remote result. Check the thing that proves the intended effect: the stored comment, PR head/body, bot-applied state, or actual workflow run. Command success alone does not prove the outcome.

If a request times out after it may have written, mark the outcome uncertain and reconcile remotely before retrying. A missing verification result or a broken local parser means unverified, not automatically an unsafe remote write. Stop dependent actions until resolved; stop more broadly if the evidence shows a broader authorization or execution problem. Delayed bot effects should be watched without reposting the command.

Scale additional review to the change. A routine factual comment does not require multiple independent audits. A subtle hot-path or concurrency change may warrant reproduction, appropriate tests and independent review. Preserve user checkouts; use fresh worktrees/clones for approved implementation, and never clear an existing directory to reuse it.

Keep outreach deliberate. Pinging, assigning and requesting reviews are public actions requiring explicit approval. Waiting on someone else is a status, not an automatic request to notify them. Keep private security work in the separate private process.

## Specialist handoff

Pass the question/outcome, repositories and relevant revisions, known evidence, workspace, absolute `OUTPUT_DIR`, actor/voice preferences, approved scope and stopping point. Ask for a compact result: findings with sources, uncertainties, artifact, validation, remaining dependency and next useful move. One worker owns each mutable checkout or draft; independent read-only questions can run in parallel.

Read the specialist's contract and use only what the job needs:

- [Triage](../../falco-triage/SKILL.md) and [reviewer](../../falco-reviewer/SKILL.md) return reports and drafts; their public commands/scripts remain unexecuted by that specialist. The maintainer coordinator presents them for approval.
- [Dev](../../falco-dev/SKILL.md) receives the already chosen workspace and approved local task. Existing approval may answer its workspace/commit questions; missing permission still must be obtained. Builds and privileges stay within that skill's constraints.
- [CLI](../../falco-cli/SKILL.md) and [rules-author](../../falco-rules-author/SKILL.md) supply targeted verification or rule work.
- [Dependabot](../../falco-dependabot/SKILL.md) can mutate repositories. A discovery task does not authorize its rebase/approval loop. Give an execution handoff only the explicitly approved steps, including merge effects, and pause it at the next unapproved action.
- [Release](../../falco-release/SKILL.md) owns release-specific gates and the manual final-release boundary. Share the mandate and workstream context; return broader strategy to the existing maintainer coordinator instead of launching it recursively.

Do not restart questionnaires when the needed choices already exist. Do not override a specialist's read-only contract or let a specialist bypass this skill's public approval boundary. If unavailable, use a suitable scoped alternative and disclose a material capability gap.

The main agent synthesizes the results, verifies decisive claims and updates the project recommendation. A specialist being blocked parks that job with a concrete condition; it need not stop other approved work or the watch.
