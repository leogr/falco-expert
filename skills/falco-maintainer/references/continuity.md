# Continuity and monitoring

Use this reference for session memory, learning, compaction and watching. Keep project judgment and reusable lessons in the session note, and mechanical observations in watcher files.

## Durable memory

Create a dated directory under the resolved `OUTPUT_DIR` and a dated Markdown state note using the [template](../templates/session.md). Save the current recommendation, approved jobs, meaningful decisions, draft/published distinction, uncertain action outcomes, evidence revisions, waits and rejection reasons. Link supporting artifacts; do not maintain a second full backlog database.

Update after meaningful events and before an interruption or blocking question. Keep the newest resume summary first. Concrete events belong in session history; lessons worth changing the skill should become a proposed improvement for human review.

On resume:

1. Read the mandate, newest summary and relevant carried lessons, following their evidence links when needed. Reuse established preferences rather than repeating launch questions; check that a lesson's context still applies.
2. Reconcile attempted public actions with unknown outcomes using remote reads. Do not replay them. Distinguish permission already granted in the continuing conversation from an old note merely claiming permission; ask if authorization cannot be established.
3. Read watcher events since the last handled event and refresh facts relevant to active work. Closed or merged items are ordinary changes, not state errors. Preserve valid investigation results while their decisive facts still hold.
4. Check actual host/process handles and specialist artifacts. A PID in a saved file is not proof of a running process. Record gaps, restart authorized watches, and return with changed recommendations or the next job.

## Learning from sessions

Keep short process observations in the session note at meaningful decisions, feedback, completed jobs or surprises. Cover discovery, investigation, specialist handoffs, execution and communication as relevant. Use a few lines and evidence links; avoid a transcript of tool calls or a retrospective after every poll.

- Record the approach and why it was chosen. For discovery, include sources explored, coverage gaps, credible alternatives and why particular candidates received attention. Keep expected benefit separate from what eventually happened. Note elapsed effort or resource cost when available and useful; label estimates.
- Capture the maintainer's feedback and reasons for accepting, deferring, rejecting or redirecting work. Reuse feedback from the conversation; ask only when a missing explanation would materially change the next approach. Silence supplies no feedback, and approval alone does not establish usefulness. Follow up on actual outcomes when they become observable.
- Extract a tentative lesson or next experiment, linked to the concrete observations. State its applicable context, uncertainty and any contrary evidence. A successful example does not establish a universal rule; a situational preference does not establish a permanent priority. Correct or retire lessons when later results contradict them.

When starting a new session note, link the previous note and carry forward only relevant lessons, their status and evidence pointers. Keep concrete events in their original history; summarize the reusable lesson so resuming does not require rereading every old log. Lessons may guide choices within an approved job, but never expand its scope or grant implementation/public permissions.

At a strategic review or after meaningful new evidence, compare expectations with observed results and the maintainer's feedback. Propose a small process or skill improvement when justified, with its supporting examples and a way to assess the next trial. Durable skill edits require human review. Useful criteria can emerge from these observations; do not invent a fixed score or optimize for card counts, approvals or public activity.

## Compaction

As context usage approaches or crosses **about 40% used**, propose compaction at a natural pause, such as waiting for the maintainer, a worker or CI. Use the host's usage indication when available; do not invent a precise percentage when none is exposed. Without a usage indication, still checkpoint after substantial work and suggest compaction at a convenient pause when context has accumulated.

**Save before proposing.** Reach a boundary where the current tool operation has returned, then persist:

- Acquired project knowledge, source revisions, verified findings, hypotheses, open questions, reproduction/test results and specialist reports in linked durable artifacts. Keep facts separate from process lessons; preserve both, subject to the private-security boundary.
- Current rankings and alternatives, feedback, tentative lessons, rejected suggestions and any pending process-improvement proposal.
- Exact approved scopes and approval references, holds, pending decisions, local drafts versus published effects, receipts and uncertain outcomes. Compaction cannot turn an uncertain write into a retry or a pending proposal into permission.
- Checkouts, durable script/draft paths, worker handles and deliverables, watcher scope and last handled event, actual liveness, next checks and restart commands. Do not assume background tasks will survive compaction.

Refresh the newest resume checklist with a UTC checkpoint time, why it was saved, which files to read, what is in flight and the next useful step. Check that the referenced artifacts were actually saved. Then give one short message linking the note, summarizing in-flight work and suggesting compaction. The maintainer initiates compaction through the host; do not trigger it automatically or repeatedly ask after it has been deferred. Continue authorized work and checkpoint new results if compaction is delayed.

After compaction, follow the resume steps above: reload the required repository/skill instructions and checkpoint, reuse surviving knowledge, reconcile uncertain effects, check actual worker/watch state, and continue without restarting completed investigations.

## Watch scope and attention

Agree on a recurring discovery job: sources, purpose, cadence, resource bounds and the decisions it should surface. It covers observation and initial synthesis, not unknown future public effects or substantial implementation. Use broad lightweight observation plus focused waits for active dependencies. Revisit older commitments and unscanned areas at an agreed strategic-review time, even if no new events arrive.

Prefer host event subscriptions/wait facilities if available. Otherwise use the small [GitHub watcher](../scripts/watch.py). It does not create a service, schedule future sessions, select projects, or perform any public write. Use a host background task/completion notification to wait without repeatedly waking an LLM. If the host cannot notify or retain the task, say what is actually possible; do not claim unattended monitoring. Installing a daemon or scheduler requires a separate approved job.

Coalesce changes into short rounds. Routine bot churn can be retained without presenting another decision; reassess if it affects active work. A material change, a completed job, a dependency becoming ready, or a due strategic review can justify a round. While awaiting the human, continue the approved watch and other approved work. No useful new work is a valid state; let the watcher sleep.

## GitHub watcher

Requires Python 3.10+, `gh` with working read access, and a POSIX host. It reads the approved repository issue/PR listings and default-branch heads using GET requests. First validate the chosen scope with one poll:

```bash
python3 <skill-dir>/scripts/watch.py --repo falcosecurity/falco --repo falcosecurity/libs --state <absolute-output-dir>/<dated-session>/<dated-watch>.json --once
```

Then start the same command **without `--once`** as a host background job. It sleeps between polls and exits when a baseline, change or error has been saved. After processing an event, re-arm it with the same state. If the host supports streaming change notifications, `--continuous` keeps the process running and prints only events/errors. Neither mode invokes an LLM.

The initial baseline is also an event: read it and re-arm the watch before waiting on the human. Keep one process per state path; a local lock rejects concurrent writers. Store the host handle and exact command in the session note. Stop only that verified process/handle when asked; avoid broad process-name kills.

Options:

| Option | Default | Purpose |
|---|---|---|
| `--repo` | Required, repeatable | Explicit owner/repository scope |
| `--state` | Required absolute JSON path | Local checkpoint in the authorized output directory |
| `--once` | Off | One bounded collection for inspection or validation |
| `--continuous` | Off | Continue after events when the host can deliver them |
| `--interval` | 900 seconds | Base polling delay |
| `--max-interval` | 3600 seconds | Quiet/error backoff cap; a server retry instruction may exceed it |
| `--lookback-days` | 7 | Initial recent-activity window |
| `--max-pages` | 10 per repository/poll | Bound issue-list requests; exceeding it reports partial coverage |

Start with these intervals only when they fit the agreed job. A focused CI/merge wait can use the appropriate [release waiter](../../falco-release/scripts/README.md) under the same read-only mandate; inspect its arguments and timeout. Frequent event bursts are a reason to batch or narrow a watch, not continually expand resource use. Respect server backoff instructions after rate limits; do not immediately retry a failed watcher in a loop.

The state file records last success per repository, current summaries, coverage, PID and next check. Its sibling event journal uses the same basename with `.events.jsonl`; events are saved before advancing checkpoints. On restart, read unhandled journal entries even if the next poll is quiet. A crash may repeat a read notification; deduplicate by repository, object and observed revision. Record the last handled event in the session note. Do not automatically delete old journals; archive them when needed without losing unhandled events.

Exit codes: `0` means the requested observation window was collected; `2` means partial coverage or a local/remote failure; `130` means interrupted. An error preserves that repository's successful cursor while other repositories can progress. For a page-limit failure, inspect the source and approve a suitable collection/resource adjustment. Changing repository scope requires a new state path so the coverage change is explicit.

## What the watcher establishes

The [repository issues API](https://docs.github.com/en/rest/issues/issues#list-repository-issues) includes PR records, supports `state=all`, an updated-time window and pagination. The [commit listing API](https://docs.github.com/en/rest/commits/commits#list-commits) defaults to the default branch. The watcher follows issue pages within its cap, includes closures, and uses the first response's server time with a two-minute overlap for later queries. It keeps summaries and body digests, not full issue discussions.

`complete-window` describes **those endpoints and that time window**, never complete project/backlog knowledge. Initial discovery and periodic strategic review must include relevant older open work separately. The listing is not an event log: multiple updates can coalesce, deletions/transfers or delayed indexing can escape the window, and concurrent pagination is not a transaction. Re-fetch the exact object before a consequential decision; reconcile active objects directly during periodic review.

The helper does not establish review status, head-specific CI, merged-versus-closed PR semantics, effective dependency versions, releases, discussion contents, meeting changes or root causes. Query those separately when relevant. A branch-head change or issue summary is a lead. Inaccessible sources and partial collections remain gaps, never evidence of absence.

## Legacy runs

The previous [implementation at 9f1d149](https://github.com/leogr/falco-expert/tree/9f1d149acbd1bb322dcef8b230b051395dc05872/skills/falco-maintainer) remains in Git history. Its reports, cards and ledgers are historical evidence, not instructions for the new loop. Leave them intact; transfer only useful commitments, decisions, drafts and observed public outcomes into the new state note. Reconcile unresolved writes against current remote state before taking dependent actions. Do not reinterpret old future-work cards as approved actions or let a historical local verification error silently authorize a retry.

## Validation

The [watcher tests](../tests/test_watch.py) run offline with stubbed API responses:

```bash
python3 <skill-dir>/tests/test_watch.py --workdir <absolute-output-dir>/<dated-test-directory>
```

The [behavioral scenarios](../tests/scenarios.json) exercise selection, approvals, specialists, quiet periods and resume. Give the prompts and raw scenario facts to independent evaluators without the grading criteria. Evaluate their recommendations and actions, not whether they reproduce headings or wording. A fixture pass cannot prove unattended host persistence or that a real maintainer values the ranking; validate those through bounded live pilots and human feedback.
