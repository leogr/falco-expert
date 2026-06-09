---
name: falco-reviewer
description: Review pull requests across falcosecurity repositories as a ghost writer for Falco maintainers. Performs code review, security review, and breaking change analysis using the falco-expert knowledge base. Generates a review report and a ready-to-run shell script that publishes a pending (draft) GitHub review with inline comments. Use this skill whenever the user asks to review a PR in any falcosecurity repository, or when terms like "review PR", "PR review", "code review" appear in the context of falcosecurity.
metadata:
  falco-version: "0.43"
---

# Falco Reviewer

Review pull requests across [falcosecurity](https://github.com/falcosecurity) repositories as a ghost writer for Falco maintainers. This skill produces a detailed review report and a shell script the maintainer can inspect, edit, and run to publish a draft review on GitHub.

## 1. Overview and Safety

### Purpose

This skill enables AI agents to:
- Fetch and analyze PRs across falcosecurity repositories using the `gh` CLI
- Perform **code review** (correctness, patterns, testing, documentation)
- Perform **security review** (injection, data validation, secrets, OWASP patterns)
- Check for **breaking changes** (API, config, CLI, behavior)
- Use the falco-expert knowledge base via the **Dig Deeper** workflow for technical context
- Generate a review report stored in `OUTPUT_DIR` (see [Output Path Resolution Protocol](../../AGENTS.md#output-path-resolution-protocol))
- Generate a `review-pr-<NUMBER>.sh` script the maintainer can inspect, edit, and run

### Safety Rules

> **MANDATORY: This skill NEVER takes public actions.**
>
> - **NEVER** submit, approve, or request changes on a PR
> - **NEVER** comment on issues or PRs
> - **NEVER** push code, create branches, or modify the target repository
> - **NEVER** execute the generated review script. Only generate it
> - **NEVER** run `gh pr review` or any command that modifies GitHub state
> - The outputs are a **report** and a **script** that the maintainer reviews and runs manually
> - If anything is unclear, **ask the user** before proceeding

### Output Directory

Before generating any output files, resolve `OUTPUT_DIR` — the absolute path where all reports will be saved. Resolve it **once**, then reuse for the session.

1. Check if the git remote URL contains `falco-expert`:
   ```bash
   git remote get-url origin 2>/dev/null | grep -q "falco-expert"
   ```
   If the check matches, inform the user (e.g., "Detected falco-expert repository.").
2. **If inside the falco-expert repository**: `OUTPUT_DIR` = `<repo-root>/output/`
3. **If outside** (or the check fails): You **MUST** prompt the user to choose (do NOT skip this prompt):
   - `<current-project>/output/`
   - A unique temporary directory (`mktemp -d /tmp/falco-expert-output-XXXXXXXX`)
   - A custom path

Store the resolved absolute path as `OUTPUT_DIR`. All subsequent `OUTPUT_DIR` references in this skill use that path.

> **Note:** This is a summary of the [Output Path Resolution Protocol](../../AGENTS.md#output-path-resolution-protocol) in `AGENTS.md`. If you have `AGENTS.md` in context, follow the canonical version there.

### Prerequisites

1. **`gh` CLI authenticated**: Run `gh auth status` to verify
2. **Knowledge base available**: The falco-expert repository must be accessible (at least `digests/` and `specs/`)
3. **Network access**: Required to fetch PR data via `gh` CLI

---

## 2. Workflow

### Step 0: Identify the PR and Ensure Local Codebase

Parse the user's request to extract:
- **Repository**: e.g., `falcosecurity/falco`, `falcosecurity/libs`
- **PR number**: e.g., `#1288`

If either is missing or ambiguous, ask the user.

#### Ensure local codebase access

The review requires access to the full repository codebase (not just the diff) so you can scan surrounding code, trace call chains, check for patterns elsewhere, and verify claims against the actual implementation.

1. **Check the current working directory.** Determine if it is already a clone of the PR's repository:
   ```bash
   git remote get-url origin 2>/dev/null
   ```
   Compare the output against the PR's repository URL (e.g., `falcosecurity/libs`).

2. **If it matches**, use the current directory. Fetch the PR branch so you can read the changed files at their new state:
   ```bash
   gh pr checkout <NUMBER> --detach
   ```
   (Use `--detach` to avoid creating a local branch. Remember to restore the previous branch when done.)

3. **If it does not match**, ask the user:
   > "The current directory is not the `<OWNER/REPO>` repository. Would you like me to clone it into a temporary directory so I can scan the full codebase during the review?"

   If the user agrees:
   ```bash
   REVIEW_TMPDIR=$(mktemp -d)
   gh repo clone <OWNER/REPO> "$REVIEW_TMPDIR"
   cd "$REVIEW_TMPDIR"
   gh pr checkout <NUMBER> --detach
   ```
   Use `$REVIEW_TMPDIR` as the working tree for the rest of the review. Inform the user of the path.

   If the user declines or provides an alternative path, follow their instructions.

#### Fetch PR metadata

```bash
gh pr view <NUMBER> --repo <OWNER/REPO> --json number,title,body,author,baseRefName,headRefName,headRefOid,files,reviews,labels,state,isDraft,mergeable,commits,url
```

Also fetch the full diff:

```bash
gh pr diff <NUMBER> --repo <OWNER/REPO>
```

### Step 1: Understand Context with Dig Deeper

Before reviewing code, use the **Dig Deeper** workflow (see [`WORKFLOWS.md`](../../WORKFLOWS.md)) to understand:
- What component(s) does this PR touch?
- What are the relevant specs, digests, and architectural patterns?
- Are there known issues, proposals, or prior art related to this change?

This step is critical. The review quality depends on understanding the codebase context, not just reading the diff in isolation.

Read [`WORKFLOWS.md`](../../WORKFLOWS.md) before executing the Dig Deeper workflow.

**Epistemic tagging**: Dig Deeper findings come pre-tagged with [FACT], [DERIVED], [INFERENCE], or [ASSUMPTION] (see [Epistemic Tagging](../../AGENTS.md#epistemic-tagging)). Carry these tags forward into subsequent review steps. The tags determine what can become a review comment and what cannot.

**Save the Dig Deeper findings** as a separate file so the user can inspect the technical context independently. This file goes inside the review subdirectory (see Step 6).

**Filename:** `YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-context.md` (inside the `YYYY-MM-DD-review-<REPO>-pr-<NUMBER>/` subdirectory in `OUTPUT_DIR`)

This file contains the full knowledge base research (specs, digests, refs consulted, architectural context) that informed the review.

### Step 1b: Evaluate Existing Reviews

Before writing your own review, check if other reviewers have already left feedback.

```bash
gh api --paginate "repos/<OWNER/REPO>/pulls/<NUMBER>/reviews" --jq '[.[] | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "COMMENTED" or .state == "PENDING") | {user: .user.login, state: .state, body: .body, id: .id}]'
```

Also fetch their inline comments:

```bash
gh api --paginate "repos/<OWNER/REPO>/pulls/<NUMBER>/comments" --jq '[.[] | {user: .user.login, path: .path, line: .line, body: .body}]'
```

**Important:** Do not use the "not equal" operator (exclamation mark followed by equals sign) in jq filters. LLMs tend to render that two-character sequence as a single Unicode "not equal" glyph, which jq cannot parse. Use positive matching (`==`, `or`) or `| not` instead.

For each existing review:

1. **Read every comment carefully.** Understand what the reviewer is asking for and why.

2. **Evaluate each point** using the knowledge base context from Step 1. Is the reviewer's concern valid? Is their suggestion correct?

3. **If you agree** with a point:
   - Do not repeat the same feedback in your own review. That adds noise.
   - Judge whether it is worth adding a short comment to second the reviewer (e.g., "+1 on this" or a brief reinforcement). This is valuable when: the point is important and might be overlooked, the PR author pushed back, or a second opinion from a maintainer would help move things forward. Otherwise, skip it.
   - If you include a seconding comment, keep it brief and reference the original reviewer.

4. **If you disagree** with a point:
   - Do not silently contradict the other reviewer in your own comments.
   - **Ask the user** before proceeding. Present the disagreement clearly: what the other reviewer said, what you think based on the knowledge base, and why they conflict. Let the user decide how to handle it.

5. **Include an "Existing Reviews" section** in the review report summarizing:
   - Who reviewed and their overall stance (approved, requested changes, commented)
   - Which of their points you agree with (and whether you seconded them)
   - Any disagreements flagged to the user

### Step 1c: Check CI Status

Fetch the CI check results for the PR's HEAD commit:

```bash
gh pr checks <NUMBER> --repo <OWNER/REPO>
```

If all checks pass, proceed to Step 2.

If any checks are failing:

1. **Identify which checks failed.** Fetch details:
   ```bash
   gh api "repos/<OWNER/REPO>/commits/<headRefOid>/check-runs" --jq '.check_runs[] | select(.conclusion == "failure") | {name: .name, status: .status, conclusion: .conclusion, details_url: .details_url}'
   ```

2. **Determine if they are required.** Required checks block merge and typically must be addressed. Use a `falco-expert` sub-agent to investigate each failing check:
   - What does this CI job do? (Use the knowledge base, particularly [`ci-cd-jobs.md`](../../specs/ci-cd-jobs.md) and [`ci-cd-infrastructure.md`](../../specs/ci-cd-infrastructure.md))
   - Is the failure related to the PR's changes or is it a known flaky test / infrastructure issue?
   - If the failure is PR-related, what needs to change?

3. **For required checks that fail due to PR changes**: include this as a **blocking** finding in the code review. The PR cannot merge until these are green.

4. **For checks failing for reasons unrelated to the PR** (e.g., flaky tests, infrastructure outages, pre-existing failures on the base branch, external service timeouts): do not blame the PR author. **Ask the user** how to handle it before proceeding. Present what you found: the failing check, why you believe it is unrelated, and whether the same check fails on the base branch. The user may want to note it in the review, ignore it, or investigate further.

5. **For optional or informational checks**: use your judgment. If the failure is clearly caused by the PR's changes, mention it as a non-blocking observation. If it looks unrelated, note it briefly but don't hold up the review.

6. **Include a "CI Status" section** in the review report summarizing: which checks passed, which failed, whether failures are PR-related or pre-existing, and any action items.

### Step 2: Code Review

**Epistemic tagging**: Tag every finding during analysis. A finding about a bug must be grounded in [FACT]s (what the code does at specific lines) and [DERIVED] reasoning (why that behavior is incorrect). Findings that rely on [ASSUMPTION]s about intended behavior, undocumented contracts, or LLM prior knowledge must be tagged accordingly and will be filtered in Step 5.

Analyze the PR diff for:

**Correctness**
- Logic errors, off-by-one, nil/null dereference, resource leaks
- Edge cases the author may have missed
- Whether error handling follows the patterns used in the rest of the codebase

**Consistency**
- Naming conventions, code style, patterns used elsewhere in the repo
- Whether the approach aligns with existing architectural patterns (use knowledge base context)

**Testing**
- Are new code paths tested?
- Are edge cases covered?
- Do existing tests need updating?
- Is the test actually exercising the code it claims to? (Watch for tests that set up infrastructure but never call the function under test)

**Documentation**
- Are user-facing changes reflected in docs, comments, or changelogs?
- Do new config options have descriptions and defaults?

### Step 3: Security Review

**Epistemic tagging**: Security findings demand the highest rigor. A security concern must be backed by [FACT]+[DERIVED] to be reported as a finding. [INFERENCE]-level security concerns (e.g., "this pattern is often vulnerable to X") can be raised as questions but not as definitive findings. [ASSUMPTION]-level security concerns are never reported in review comments.

Analyze every changed file for security concerns:

**Input Validation**
- Are user/external inputs validated before use?
- String interpolation into URLs, SQL, commands, or file paths without sanitization
- Deserialization of untrusted data

**Authentication and Authorization**
- Changes to auth flows, token handling, credential storage
- Privilege escalation vectors

**Data Exposure**
- Secrets, tokens, or credentials in code or config
- Logging of sensitive data
- Error messages that leak internal details

**Dependency and Supply Chain**
- New dependencies: license compatibility, known CVEs, maintenance status
- Pinned versions vs floating

**Falco-Specific Security**
- Changes to kernel drivers, eBPF probes, or syscall handling
- Changes to the plugin API trust boundary
- Changes to rule parsing that could allow rule injection

### Step 4: Breaking Change Analysis

**Epistemic tagging**: Breaking change claims must be [FACT]-grounded (specific API/config/CLI changes observable in the diff) with [DERIVED] impact analysis. Do not flag something as a breaking change based on [ASSUMPTION] about how downstream consumers use an API.

Check whether the PR introduces breaking changes:

**API/ABI Breaks**
- Changed function signatures, removed public APIs
- Modified protobuf/gRPC definitions
- Plugin API version changes

**Configuration Breaks**
- Renamed, removed, or changed default config keys
- Changed behavior of existing config options

**CLI Breaks**
- Removed or renamed flags
- Changed exit codes or output format

**Behavioral Breaks**
- Changed semantics of existing rules, fields, or operators
- Different default behavior for existing features

If breaking changes are found, note whether they follow the project's convention: conventional commit with `!` suffix or `BREAKING CHANGE:` footer, and whether the PR description mentions the break.

### Step 5: Compose the Review

#### Epistemic Filter Rule

Before writing any review text, apply this filter to every finding from Steps 2-4:

| Finding's epistemic grounding | Action |
|-------------------------------|--------|
| [FACT] + [DERIVED] chain | Becomes a review comment. State with confidence. |
| [FACT] + [INFERENCE] chain | Becomes a review comment **with hedging**. Use question form ("Could this lead to...?") or explicit uncertainty ("If I'm reading this correctly..."). |
| [INFERENCE] only (no supporting [FACT]) | Goes to the report only (Discarded Suggestions section). Not in the review script. |
| Any chain involving [ASSUMPTION] as a premise | Goes to the report only (Discarded Suggestions section). Not in the review script. The reason for discarding must state which premise was [ASSUMPTION] and why it could not be verified. |

This filter is the primary mechanism for preventing assumption-based suggestions from reaching the PR. Apply it strictly.

#### Writing Style

The review is ghost-written for a Falco maintainer. The default tone is **direct, concise, friendly, and constructive**.

**Default style:**
- **Be direct.** State the point upfront. No preamble, no hedging.
- **Be concise.** Prefer one clear sentence over three vague ones. Say what needs to change and why, then stop.
- **Be constructive.** Every comment should help the author move forward. Point out the problem, explain why it matters, suggest a path.
- **Be friendly.** Keep a warm, collegial tone. Not over-the-top, just enough to make the contributor feel welcome. A casual question mark, a thinking emoji, or a brief "thanks" goes a long way.
- **Use collaborative language.** "Could we..." / "May we..." / "What about..." instead of "You must..." / "Please fix..."
- **Acknowledge good work.** If the approach is solid, say so briefly.

**Avoid these patterns in the review text** (they tend to read as AI-generated):
- Starting comments with labels like "Bug:", "Issue:", "Nit:" (just state the point directly)
- Using em dashes (`--`). Prefer periods to split sentences, or commas.
- "Same issue here:" (say "Same here." or just state the point)
- "Consider doing X" (say "Could we do X?" or "What about X?")
- Overly formal or verbose explanations
- Bullet-heavy comments where a sentence would do
- Filler phrases like "I noticed that...", "It seems like...", "It would be great if..."

**Reference examples** (from actual falcosecurity maintainer reviews):

A short, friendly question that opens discussion:
```
Is there any particular reason to use `__linux` instead of `__linux__`?
```

Suggestion block first, then the rationale:
````
```suggestion
	{Type: "string", Name: "ct.request.documentname", ...},
```

For consistency with the current convention, since all other fields are lowercase.
````

Raising a concern with a question, inviting others:
```
Since there's no `filewatch` package, why is this file here?
```

Flagging a real bug, constructively, with evidence:
```
With this change, now we pass full references to `SignatureForIndexRef()`,
which by design returns `nil` for full refs. As a result, the signature
verification is effectively skipped every time, even when it exists in the index.
```

A minor observation, framed as non-blocking:
```
Nit. Very minor recommendation here.

`os.WriteFile` is not atomic (it truncates and writes using a buffer), so if
multiple `falcoctl` processes read and write simultaneously to the same state
file, a reader could see the state file in a corrupted state.

However, the read function (above) handles corrupted JSON gracefully, and since
the "best-effort" nature of this "cache" mechanism, I don't see this as a
blocker for this PR. We may improve it later.
```

Tagging others and inviting discussion:
```
I tend to agree with this.

cc @falcosecurity/plugins-maintainers any thoughts in this regard?
```

Acknowledging the PR, then pointing to inline comments:
```
Thanks for adding Chronicle support! The overall approach looks good and
follows the existing GCP output patterns nicely.

I found a few issues, see inline comments.
```

Notice the patterns: short sentences, questions with thinking emoji when genuinely curious, evidence before conclusions, non-blocking caveats stated explicitly, tagging relevant people when a second opinion helps.

#### External Style Instructions

This skill ships an **opinionated default style** (above). It is not tied to any specific person's voice; it focuses on review substance (what to say).

If the orchestrating agent provides external style instructions (e.g., from a dedicated writing-style skill), apply those instructions to all review text (body + inline comments). External style instructions take precedence over the default style above, but the anti-AI-pattern rules always apply.

#### Review Body

The review body (the top-level comment) should:
1. Thank the contributor (briefly, naturally)
2. Summarize the overall impression in 1-2 sentences
3. If there are blocking issues, mention them at a high level
4. Point to inline comments for details

Keep it short. The inline comments carry the substance.

#### Inline Comments

Each inline comment should:
- Target a specific file and line (or line range)
- State the issue or suggestion clearly
- Use GitHub suggestion blocks (` ```suggestion `) when proposing concrete code changes. Never use language-specific code blocks (e.g., ` ```go `, ` ```cpp `) for proposed changes — only ` ```suggestion ` gives the author a one-click "Apply" button.
- **Place `suggestion` blocks at the beginning of the comment by default.** The code change comes first, then the explanation follows. Only put the suggestion later in the comment if there is a specific reason (e.g., the explanation is needed to understand why the suggestion makes sense). The intent is to lead with the fix, then explain.
- **When a suggestion replaces multiple lines**, the comment MUST target the full line range using both `start_line`/`start_side` and `line`/`side` in the API call. GitHub can only apply a suggestion to lines covered by the comment's range. If you target only the last line, the suggestion will fail or replace only that single line.

### Step 5b: Verify Suggestions

Before finalizing, verify that the suggestions you are about to propose are sound. This step has two passes: first challenge each suggestion's premises individually, then verify the surviving set against architecture and conventions.

#### Pass 1: Assumption Audit (with Epistemic Tags)

For each suggestion that proposes changing an existing pattern (type choice, naming, API shape, error handling approach, data structure), challenge the assumption that the existing code is correct and the PR deviates from it. **Never assume the existing code is the right baseline.** Sometimes the PR is intentionally correcting a historical mistake.

**Tag every premise** in the suggestion's reasoning chain as [FACT], [DERIVED], [INFERENCE], or [ASSUMPTION]. Then answer these three questions:

1. **Why does the existing code look this way?** Investigate before suggesting alignment with an existing pattern.
   - Search the codebase for the pattern. Is it used consistently, or is it already being migrated away from?
   - Check the knowledge base (specs, digests, proposals) for documented rationale or known technical debt.
   - Look at commit history, comments, or related issues that explain the reasoning.
   - If you cannot find a reason, tag the premise as [ASSUMPTION] — do not assume the existing pattern is correct.

2. **Do the domain constraints support your concern?** If the suggestion is based on a general programming principle (e.g., "type widths should be consistent", "error codes should always be checked", "this could overflow"), verify that the concern is real in context, not just theoretical.
   - Are there platform, kernel, or protocol guarantees that make the concern moot? (e.g., PIDs cannot exceed `2^32 - 1` on Linux, so `uint64_t` for PIDs is unnecessary.)
   - Does the "problem" manifest in practice, or is it purely hypothetical?
   - If the concern is only theoretical, tag it [INFERENCE] at best, [ASSUMPTION] if it rests on unverified claims about how the code is used.

3. **What if the direction is reversed?** Ask: "What if the existing code is wrong and the PR's approach is the correction?" If your suggestion is to align new code with old code, check whether the old code itself is a known issue or technical debt being cleaned up.

**Decision rule:** After tagging, apply the [Epistemic Filter Rule](#epistemic-filter-rule) from Step 5. If the suggestion's reasoning chain includes an [ASSUMPTION] as a premise, **discard the suggestion entirely**. Do not weaken it to a question or soften it to a "nit." A wrong suggestion framed as a question still wastes the author's time and damages the maintainer's credibility. Record all discarded suggestions, their tag chains, and the reason for discarding them (see Step 6, "Discarded Suggestions").

#### Pass 2: Architecture and Convention Check

After the assumption audit, take the surviving suggestions and:

1. **Produce a unified diff** of all suggestion blocks against the original code. This is not a file on disk; mentally (or explicitly) reconstruct what the code would look like if the author applied every suggestion.

2. **Run the Dig Deeper workflow** on the resulting changes to check:
   - Do the suggested changes follow falcosecurity coding conventions, patterns, and style?
   - Are the suggestions sound with the project's architectural design? Check against the knowledge base specs (e.g., [`architecture-overview.md`](../../specs/architecture-overview.md), [`plugin-system.md`](../../specs/plugin-system.md), [`kernel-instrumentation.md`](../../specs/kernel-instrumentation.md)) to verify that suggestions respect component boundaries, event pipeline design, threading model, plugin API contracts, and other deliberate architectural choices the project has made.
   - Do they introduce any new issues (e.g., breaking an API contract, violating naming conventions, missing a required license header)?
   - Are the suggestions aligned with the contributing guidelines (commit conventions, DCO, etc.)?

3. **If issues are found**, revise the affected suggestions and repeat both passes. Keep iterating until all suggestions pass.

4. **If no issues are found**, proceed to generate the outputs.

This step prevents the review itself from introducing bad advice. A suggestion that contradicts project design or rests on a wrong assumption undermines the maintainer's credibility.

### Step 6: Generate the Review Report

Save all review artifacts into a subdirectory of `OUTPUT_DIR` (see [Output Path Resolution Protocol](../../AGENTS.md#output-path-resolution-protocol)):

**Subdirectory:** `OUTPUT_DIR/YYYY-MM-DD-review-<REPO>-pr-<NUMBER>/`

**Report filename:** `YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-report.md`

**Report structure:**

```markdown
# Review: <REPO>#<NUMBER> - <PR Title>

**PR:** <URL>
**Author:** @<author>
**Branch:** <head> -> <base>
**Commit:** <headRefOid>
**Date:** YYYY-MM-DD

---

## Summary

<1-3 sentence overall assessment>

## Code Review Findings

### <Finding 1 title>
- **File:** `<path>`  **Lines:** <range>
- **Severity:** blocking | non-blocking | nit
- **Grounding:** [FACT]+[DERIVED] | [FACT]+[INFERENCE] (describe the tag chain briefly)
- <Description>

...

## Security Review Findings

### <Finding 1 title>
- **File:** `<path>`  **Lines:** <range>
- **Severity:** critical | high | medium | low | informational
- **Grounding:** [FACT]+[DERIVED] | [FACT]+[INFERENCE] (describe the tag chain briefly)
- <Description>

...

## Breaking Change Analysis

<Assessment of breaking changes, or "No breaking changes detected.">

## CI Status

<Summary of check results: passed, failed, whether failures are PR-related or pre-existing, action items. Or "All checks passing." if green.>

## Existing Reviews

<Summary of other reviewers' feedback, agreement/disagreement, and any seconding comments included in the review script. Or "No prior reviews." if none.>

## Review Body

The top-level comment for the GitHub review. This text is included in the submit commands printed by the review script. If submitting via the web UI instead, copy-paste this into the review comment box.

> <review body text>

## Discarded Suggestions

Suggestions that were drafted during review but dropped after the assumption audit (Step 5b, Pass 1). Included for transparency so the maintainer can see what was considered and why it was rejected.

### <Discarded suggestion 1 title>
- **File:** `<path>`  **Lines:** <range>
- **Original suggestion:** <What was going to be suggested>
- **Tag chain:** <The epistemic tags of each premise, e.g., "[FACT] X calls Y → [ASSUMPTION] Y is expected to return Z → [INFERENCE] bug">
- **Reason discarded:** <Which premise was [ASSUMPTION], which assumption audit question failed, and what the investigation revealed>

...

*(If no suggestions were discarded, replace this section with "No suggestions were discarded.")*

## Context

The Dig Deeper knowledge base research has been saved to:
`YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-context.md` (in the same directory as this report)

## Review Script

The review script has been saved to:
`YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-review.sh` (in the same directory as this report)

To publish the review:
1. Inspect and edit the script as needed
2. Run: `bash OUTPUT_DIR/YYYY-MM-DD-review-<REPO>-pr-<NUMBER>/YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-review.sh`
3. The script creates a **pending (draft) review** that is NOT visible to others
4. To submit, run the command printed by the script

## References

[1]: <url> - <description>
...
```

### Step 7: Generate the Review Script

Save an executable shell script in the same subdirectory as the report.

**Filename:** `YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-review.sh`

The script uses the GitHub REST API via `gh api` to create a **pending** review (draft, not visible until submitted). The key is omitting the `event` field from the API call, which defaults to `PENDING`.

#### Tooling Constraints

> **MANDATORY: The review script must use only `bash` and `gh` (with standard POSIX utilities like `jq`, `echo`, `cat` that are already invoked in the template).**
>
> - **Do NOT** use Python, Node.js, Ruby, Perl, or any other language runtime
> - **Do NOT** introduce dependencies beyond what `gh` already requires
> - **Do NOT** call out to other tools to build the JSON payload, escape strings, or post the review
> - All JSON payloads must be constructed as heredocs or via `jq` invocations inside the script
> - The rationale: maintainers must be able to inspect and run the script without installing extra runtimes, and the surface area for review must stay minimal

#### Mandatory Correctness Validation

Before writing the script file to `OUTPUT_DIR`, you **MUST** validate its correctness. Do not skip this step. A malformed script that fails when the maintainer runs it damages trust in the skill.

Validation checklist (all must pass before saving):

1. **Bash syntax check.** Run `bash -n <script-path>` on the generated content (use a temporary path, e.g., `mktemp`). The script must parse cleanly.
2. **JSON payload validity.** For every heredoc JSON payload in the script, pipe it through `jq empty` to confirm it is valid JSON. Watch for unescaped newlines, quotes, backticks (common in `suggestion` blocks), and backslashes inside comment bodies.
3. **Required fields present.** Each comment object in the `comments` array must include `path`, `body`, and either `line` (single-line) or both `start_line`+`line` (multi-line). Multi-line comments must also include `start_side` and `side`.
4. **Commit ID matches HEAD.** Confirm the `commit_id` in the payload equals the `headRefOid` fetched in Step 0. If the PR was updated during review, re-fetch.
5. **No forbidden tooling.** Grep the script for `python`, `python3`, `node`, `ruby`, `perl`, `awk -f`, or any other runtime invocation. The only executables that may appear are `bash`, `gh`, `jq`, and shell builtins.
6. **No placeholders left in.** Search for `<...>` placeholder syntax. Every `<NUMBER>`, `<OWNER/REPO>`, `<headRefOid>`, `<file path>`, `<line number>`, `<comment text...>`, `<review body text>` must have been replaced with the actual value.

If any check fails, fix the script and re-run all checks. Only save the file once every check passes. If a check cannot be satisfied (e.g., a comment body legitimately needs a character that breaks JSON encoding), resolve the encoding issue properly — do not bypass the validation.

**Script template:**

```bash
#!/usr/bin/env bash
set -euo pipefail

PR=<NUMBER>
REPO="<OWNER/REPO>"
COMMIT="<headRefOid>"

# Review body (top-level comment). Edit this before submitting.
REVIEW_BODY='<review body text>'

echo "Creating pending review for PR #${PR}..."

RESPONSE=$(gh api "repos/${REPO}/pulls/${PR}/reviews" \
  --method POST \
  --input - <<'EOF'
{
  "commit_id": "<headRefOid>",
  "comments": [
    {
      "path": "<file path>",
      "line": <line number>,
      "side": "RIGHT",
      "body": "<comment text with escaped newlines and quotes>"
    }
  ]
}
EOF
)

REVIEW_ID=$(echo "$RESPONSE" | jq -r '.id')

if [ "$REVIEW_ID" = "null" ] || [ -z "$REVIEW_ID" ]; then
  echo "ERROR: Failed to create review."
  echo "$RESPONSE" | jq .
  exit 1
fi

echo "Pending review created (ID: ${REVIEW_ID})."
echo ""
echo "IMPORTANT: The review body (top-level comment) is set at submit time, not"
echo "at creation time. The submit commands below include it. You can also edit"
echo "the REVIEW_BODY variable at the top of this script before running them."
echo "The review body is also in the review report under 'Review Body'."
echo ""
echo "To submit as 'Request Changes', run:"
echo "  gh api repos/${REPO}/pulls/${PR}/reviews/${REVIEW_ID}/events --method POST --field event='REQUEST_CHANGES' --field body='${REVIEW_BODY}'"
echo ""
echo "To submit as 'Approve', run:"
echo "  gh api repos/${REPO}/pulls/${PR}/reviews/${REVIEW_ID}/events --method POST --field event='APPROVE' --field body='${REVIEW_BODY}'"
echo ""
echo "To submit as 'Comment' (neutral), run:"
echo "  gh api repos/${REPO}/pulls/${PR}/reviews/${REVIEW_ID}/events --method POST --field event='COMMENT' --field body='${REVIEW_BODY}'"
echo ""
echo "To discard the draft review, run:"
echo "  gh api repos/${REPO}/pulls/${PR}/reviews/${REVIEW_ID} --method DELETE"
```

**When generating the script**, the agent MUST replace `<review body text>` in the `REVIEW_BODY=` assignment with the actual review body text from Step 5. The `REVIEW_BODY` variable is defined once at the top and referenced by all submit commands, so the user can edit it in one place.

After writing the script file, make it executable:
```bash
chmod +x <script-path>
```

**Important API details:**
- Omit the `event` field entirely to create a pending (draft) review. Do NOT use `"event": "PENDING"` as that is not a valid REST API value.
- Omit the `body` field from the creation call. The GitHub web UI does not display the body of a pending review, so setting it at creation time is effectively lost. Instead, pass the body in the submit command (`--field body='...'`), where it is reliably applied.
- Use `"side": "RIGHT"` for comments on the new version of the file.
- For multi-line comments, use both `"start_line"` / `"start_side"` and `"line"` / `"side"`.
- Use GitHub suggestion blocks in comment bodies for code changes (suggestion first, explanation after):
  ````
  ```suggestion\n<replacement code>\n```\n\nExplanation of why this change is needed.
  ````
- JSON strings must have properly escaped newlines (`\n`), quotes (`\"`), and backslashes (`\\`).
- The `commit_id` must match the HEAD commit of the PR at review time.

### Step 8: Present to User

Tell the user where all three output files were saved. All files are in `OUTPUT_DIR/YYYY-MM-DD-review-<REPO>-pr-<NUMBER>/`:
1. **Review report:** `YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-report.md`
2. **Context (Dig Deeper findings):** `YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-context.md`
3. **Review script:** `YYYY-MM-DD-review-<REPO>-pr-<NUMBER>-review.sh`

Remind them to **inspect and edit** the report and script before running. The script creates a **draft review** (not visible to others) and prints commands to submit or discard it.

#### Restore the working tree

If Step 0 checked out the PR with `gh pr checkout --detach`, restore the previous branch:

```bash
git checkout -
```

If Step 0 cloned into a temporary directory, inform the user of the path so they can clean it up when done.

---

## 3. Falco Project Conventions

When reviewing PRs, apply these project-specific conventions:

### Commit Messages
- Must follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- Prefixes: `fix:`, `feat:` / `new:`, `!` suffix for breaking changes
- All commits must be signed off (DCO)

### Prow / Poiana Bot
- Labels like `kind/*`, `area/*` are managed via Prow commands (`/kind bug`, `/area rules`)
- Merge requires `lgtm` + `approved` labels, no `do-not-merge/*` labels, passing checks
- Core repos (`falco`, `libs`) often require two or more maintainer approvals

### Code Review Culture
- Assume competence and positive intentions
- Explain reasoning behind change requests
- Avoid excessive personal style preferences
- Help with testing significant patches

### Licensing
- Apache License 2.0 is the default
- Source files should include SPDX license identifiers
- New dependencies must have compatible licenses (check against [CNCF allowed licenses](../../digests/cncf/foundation.md))

For full contributing guidelines, see [`digests/falcosecurity/.github.md`](../../digests/falcosecurity/.github.md).

---

## 4. Edge Cases and Troubleshooting

### Large PRs
For PRs with many changed files, prioritize:
1. Files with security implications (auth, crypto, input parsing, kernel/eBPF code)
2. Files with behavioral changes (handlers, config, CLI)
3. New files (may introduce new patterns or dependencies)
4. Test files (verify they actually test what they claim)

### Draft PRs
Review draft PRs the same way, but soften the tone. The author knows it's not ready. Focus on directional feedback rather than nitpicks.

### Bot / Automated PRs
For dependency bumps or automated PRs, focus on:
- Whether the dependency change introduces known vulnerabilities
- Whether the version bump is compatible
- License changes in updated dependencies

### API Error: 422 Unprocessable Entity
If the review script fails with HTTP 422:
- Check that `commit_id` matches the current HEAD of the PR (it may have been updated)
- Verify that line numbers in comments still correspond to the current diff
- Ensure JSON is properly escaped (common issue with suggestion blocks containing backticks)
