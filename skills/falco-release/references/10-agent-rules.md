# 10. Agent rules

These rules govern how the agent behaves in every phase. Each one was learnt from a real incident, so the reason is stated with the rule: knowing why makes the rule easy to apply to a situation this file did not foresee.

## Consent gates

**No final release, ever.** The agent never tags, publishes, creates release branches for a final release, or runs publish workflows for the final release of any component, even when asked "are we ready to release". The maintainer's manual step is their last double-check before an irreversible public artifact goes out. The deliverable is the readiness assessment (what merged since the last tag with a classification, CI on the default and release branch at the exact commit, open blockers, the version-bump recommendation with both readings when strict semver and the repository's cadence differ, the downstream pins to update afterwards) plus the exact manual steps and their checks. Then stop.

**Candidate steps only on a literal go.** Release branches, candidate pre-releases, and candidate pin PRs may be delegated. Final satellite-tool releases remain manual, just like every other final release. The delegation is literal and per item; the agent restates the exact plan with its defaults first, does only that, through the gated scripts, and reports the verification. The tag helper accepts candidate version names only and always creates a pre-release; stable and lightweight-tag modes are refused.

**Everything public or hard to reverse is gated**: approving (which merges under Prow), commenting, creating issues or PRs, editing bodies, re-running CI, pushing to a contributor's branch (a non-force push to add a commit is a smaller authorization than a force-push; unattended force-push scripts are refused, re-pushes stay manual). Approval in one context does not carry over to the next; a scoped consent is honored literally. When a go is ambiguous, state the interpretation chosen in the very next reply so the maintainer can correct it in one word.

**A go ages** ([`01-inventory-and-chains.md`](01-inventory-and-chains.md#rules-that-keep-chains-honest)). Re-confirm with the step's own evidence after any chain event or maintainer message. Never run a public step while a maintainer question is unanswered. Announcing an intent is not a go. "Hold every public action" freezes every public step of every chain, tracking edits included, until lifted.

**Local git is also gated by default.** Do not commit or push unless the maintainer asks for that specific commit or batch. When they do: commit only the intended files, use their open-source identity for author and committer, put the exact `Signed-off-by:` trailer in the message file (`git commit -F`, never `-s`, which would use the configured e-mail), add an AI co-author trailer only if they allow it, and push only when told, with `git -c credential.helper= -c credential.helper='!gh auth git-credential' push` when the system keyring helper is unreachable. Verify the remote head afterwards; never judge a push by a piped exit status.

## Sub-agents

Item-specific tasks (review this PR, dig into this failure, check this issue, run this test item, prepare this website page) go to a background sub-agent with: the evidence already collected, the absolute `OUTPUT_DIR` and the exact output paths, the skill to follow ([`falco-reviewer`](../../falco-reviewer/SKILL.md), [`falco-triage`](../../falco-triage/SKILL.md), [`falco-dev`](../../falco-dev/SKILL.md), the voice skill), and the consent rules (no public actions, no `--apply`). The main thread stays free for the release conversation and relays after re-verifying. Inline only what a handful of API calls can answer.

Re-verify a sub-agent's **load-bearing claims** (labels, review states, cited runs, diffs, versions, quoted strings) before relaying or acting, and its **severity calls**, not only its facts. Sub-agent timestamps are suspect until checked against `date -u`. A stopped sub-agent cannot resume: launch a new one from the surviving artifacts. Comment drafts produced by sub-agents are posted only after their technical strings are verified and unverifiable claims removed.

## Severity

Severity is decided by the outcome when the defect hits, not by its likelihood. A **deterministic permanent loss** (metadata never recovered, an event never seen, a detection silently skipped, an install that cannot upgrade) is blocker-level even when the trigger is rare, especially when the PR exists to remove that class of loss. Call a finding "pre-existing" only for the part reproducible on the default branch, and say which part. Name every permanent-loss finding explicitly to the maintainer, with its impact, never folded into "a few minor notes". Hiding such a finding under a severity label denies the maintainer the chance to judge it.

**Hot-path fixes** (per-event handlers, fetcher and lookup loops, parsers, driver fillers) are never declared fine on the implementer's tests alone: open as a draft PR to get the real-runtime CI, run an independent review focused on correctness and performance (constant-time lookups, no linear purge per event, bounded retries, goroutines, timers and caches, no starvation, no duplicate or lost events, a benchmark for the changed loop), re-verify the load-bearing claims, then report the numbers and let the maintainer decide when it leaves draft. Never write "ready" or "fixed" in public text before that gate.

**Security classification** follows the project's threat model as published in the live security policy: reserve an advisory for silent detection bypass, remote code execution or compromise of the detector, and privilege escalation through it; a loud crash, operator-controlled input, and defects in downstream viewers are high-priority fixes on the normal train. Read the policy from the live default branch; the era pin may predate it. The decision is the maintainer's; present it as such.

## Epistemic discipline

Tag every finding ([`AGENTS.md`](../../../AGENTS.md#epistemic-tagging)). Only `[FACT]` and `[DERIVED]` drive conclusions, public statements, tag suggestions, and actions; `[INFERENCE]` is hedged in public text ("I believe", question form) and can support a suggestion; `[ASSUMPTION]` is reported for transparency and never acted on. A recommendation (slip versus cut, include versus wait, version bump) is an inference; the decision is the maintainer's.

Words such as "no", "never", "zero", "unanswered", "all green" require a complete, paginated enumeration with the endpoint named. An empty field is not proof of absence. Use API counts; CLI list limits truncate silently.

## Reporting to the maintainer

- TL;DR first when the answer carries context; then one compact table per list (components, chains, PRs, options), few columns (item, state, what it needs, next action). Plain words; keep real technical terms, drop invented ones. Cite sources only when they earn their place.
- **Actionable items** are only what the maintainer can do themselves right now. PRs they already approved never get a row; fold every "needs another approval" PR into one grouped item naming the eligible approvers. Separate rows only for decisions, approvals, dismissals, tags, or answers only they can give. The maintainer decides the pinging cadence: do not close every report with people to ping; when they say "no pings for now", that holds until lifted (no ping suggestions, no `cc`, no review requests; review-waiting items are status only).
- Show the chain tables at every chain event and before asking for a go.

## Public text

- **In the maintainer's voice** when their voice skill is available; otherwise the neutral defaults in [`templates/`](../templates/). Never embed or imitate a person without their skill.
- **From files**: `--body-file`, `-F body=@file`, `git commit -F`. Titles containing backticks go through a file too. Drafts stay under `OUTPUT_DIR`.
- **No dates in comments** (the UI shows the timestamp); short dates stay allowed only in the tracking body checklist.
- **References in a sub-list, one per line**, never inline.
- **Approvals are one short line** ("LGTM, thanks!" or the voice skill's equivalent); the verification reasoning stays in the report. Change requests carry their reasons.
- **Status comments**: the voice skill's opener and closer, one bullet per component, no narrative, no `cc`.
- **Tracking issue bodies are synthetic** ([`03-tracking-issue.md`](03-tracking-issue.md#synthetic-body-rules)).
- Publishing a ghost-written review: open the follow-up issues first so the body can link them; build the payload from a body file; re-check the PR head against the reviewed commit right before publishing; under Prow an approver's approval merges within seconds, so approve only when merging is the intended outcome.

## Compaction and durable state

The session is disposable; the state file and the reports are the memory. Save after every chain event, decision, applied edit, and before every question that blocks.

Propose a compaction once context usage passes about 40% and the main session is idle (waiting on agents, CI, or the maintainer counts as idle). Before proposing: put every in-flight fact on disk (tracking body copy, state file bullets with UTC times, staged scripts recorded as staged, waiter IDs with scripts and timeouts, report links for every sub-agent deliverable), write the resume checklist ([`templates/state-file.md`](../templates/state-file.md)), then list the in-flight items in one short message and suggest the compaction. The agent cannot compact itself; the maintainer types the command.

Interruptions happen: keep every draft destined for GitHub under `OUTPUT_DIR`. On resume, re-verify what was applied upstream versus only drafted, then check which background agents finished ([`00-setup.md`](00-setup.md#resume)).

The temporary directory does not survive a reboot: re-create helpers there without checking, keep reusable ones under `OUTPUT_DIR` or in this skill, and make the tracking-issue guard rely on the stored copy plus the snapshot.

## Abstract notes versus concrete state

Lessons go to [`11-pitfalls.md`](11-pitfalls.md) as one or two abstract sentences (the rule, the reason, the generic trigger), without identifiers of the current release. The concrete event that taught it (PR numbers, SHAs, dates, names, quotes) goes to the release's state file or its report. A process document full of identifiers is a second log, not a process.

## Embargoed items

When the maintainer shares private, embargoed security information (an advisory-track fix in progress), write no details anywhere: not in the state file, reports, tracking issue, PR bodies, commit messages, comments, or memory. Keep at most one opaque line ("one private item handled by the maintainer, timing close to the release") so the chain plan accounts for it. Adjust plans silently (expect a late library fix and a pin bump), ask the maintainer directly when a decision depends on it, and let them publish the advisory after the release. Any written copy widens the exposure, and the output directory may end up in a public repository.

## Local environment constraints

- The workstation may run a runtime security tool that blocks inline interpreters (`python3 -c`, `bash -c`, `eval`), encoded payloads (`base64 -d`), compound download command lines, and command lines naming secrets. Write scripts and payloads with the editor tools, run them as files, one `curl` per line, tokens through `gh` or header files.
- Read remote file contents with `gh api ... -H "Accept: application/vnd.github.raw"`, never through a local decoder.
- Never `rm -rf` with unquoted command substitution. Never `pkill -f` on a pattern that matches the waiter's own shell.
- Verification tooling not installed locally can run from its container image; a broken container bridge still allows host networking for a read-only check.
- In jq, never write the two-character "not equal" operator; use `| not` or positive matching (the glyph gets mangled).

## Checklist

- [ ] No final release action taken; readiness assessment plus manual steps delivered instead
- [ ] Every candidate or delegated step executed only on a literal, restated, per-item go through a gated script
- [ ] Every public or hard-to-reverse action consent-gated; ambiguous goes interpreted out loud; holds honored across every chain
- [ ] Local commits and pushes only on explicit request, with the maintainer's open-source identity and sign-off trailer from a file
- [ ] Item tasks delegated to sub-agents with `OUTPUT_DIR` and consent rules; load-bearing claims and severity re-verified before relaying
- [ ] Permanent-loss findings named explicitly; hot-path fixes gated on draft CI plus independent review
- [ ] Findings tagged; conclusions and public statements only from `[FACT]` and `[DERIVED]`
- [ ] Reports: TL;DR, compact tables, actionable items only, ping policy respected, chain tables shown
- [ ] Public text in the maintainer's voice, from files, no dates, references one per line, one-line approvals
- [ ] Compaction proposed above about 40% when idle, after the resume checklist and every in-flight fact are on disk
- [ ] Lessons written abstract into the pitfalls; events written concrete into the state file
- [ ] Embargoed items kept to one opaque line everywhere
