---
name: falco-triage
description: Triage GitHub issues and pull requests across falcosecurity repositories. Fetches, categorizes, and analyzes issues/PRs using the falco-expert knowledge base for technical context, checks for duplicates and related work, evaluates PR status, and generates actionable triage reports with ready-to-run gh commands. Supports tiered (quick scan + selective deep dive) and deep-dive-all analysis modes. Read-only — never modifies issues or PRs directly.
metadata:
  falco-version: "0.43"
---

# Falco Triage

Automate maintainer triage duties for the [falcosecurity](https://github.com/falcosecurity) GitHub organization. This skill fetches open issues and PRs, analyzes them using the falco-expert knowledge base, categorizes and groups them, and produces actionable triage reports.

## 1. Overview and Safety

### Purpose

This skill enables AI agents to:
- Fetch and analyze open issues and PRs across falcosecurity repositories
- Use the knowledge base (specs, digests) to understand technical context
- Detect duplicates, related issues, and issues already addressed
- Categorize by kind, priority, and component area
- Generate detailed triage reports with ready-to-run `gh` commands

### Safety Rules

> **MANDATORY: This skill is READ-ONLY.**
>
> - **NEVER** modify issues, PRs, labels, or comments directly
> - **NEVER** execute the suggested `gh` commands. Only generate them in the report
> - **NEVER** close, label, assign, or comment on any issue or PR
> - The output is a report with **suggestions** that maintainers review and execute manually
> - All `gh` commands in the report are prefixed with comments explaining the rationale

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

### Report Quality Rules

> **MANDATORY: Every issue and PR reference in the report MUST be a clickable link.**
>
> - Use the format `[#NUMBER](URL)` for all issue/PR references, e.g. `[#3789](https://github.com/falcosecurity/falco/issues/3789)`
> - This applies everywhere: tables, inline text, suggested commands, analysis sections
> - Cross-repo references must include the repo: `[libs#2817](https://github.com/falcosecurity/libs/pull/2817)`
> - Never leave a bare `#NNN` without a link. The reader must be able to click through
> - PR references use `/pull/`, issue references use `/issues/`

> **MANDATORY: Avoid redundancy in the report.**
>
> - Do not repeat information already shown in another field (e.g. if `Kind` row says `kind/bug`, do not repeat it in `Labels`)
> - Do not repeat the same analysis in both group summaries and individual cards
> - If an issue is fully covered in a group section, do not also give it a standalone section
> - Keep analysis concise. State findings, not the process of finding them

> **MANDATORY: Epistemic tagging applies to all triage analysis.**
>
> Every claim, classification, and recommendation must be grounded using [FACT], [DERIVED], [INFERENCE], or [ASSUMPTION] tags per the [Epistemic Tagging](../../AGENTS.md#epistemic-tagging) rules in AGENTS.md. Tag during analysis; the tags determine what can become an actionable recommendation:
>
> | Claim's grounding | Allowed in report? | Allowed as `gh` command? |
> |---|---|---|
> | [FACT] + [DERIVED] | Yes, stated with confidence | Yes |
> | [FACT] + [INFERENCE] | Yes, with hedging language | Only non-destructive (labels, info requests). Never `/close`. |
> | [INFERENCE] only | Yes, in a "Needs Verification" note | No |
> | Any chain with [ASSUMPTION] | Only in a dedicated "Unverified" note | No |
>
> This rule generalizes the existing `/close requires proof` rule below to all triage actions. Dig Deeper findings arrive pre-tagged; carry those tags forward.

> **MANDATORY: Suggested actions must align with project guidelines.**
>
> - **Do NOT suggest `priority/*` labels.** The project has no public prioritization guidelines. Priority judgments in the report are internal triage assessments, not label recommendations.
> - Any suggestion with public effects (labels, comments, closures) must be consistent with the project's established practices
> - When unsure if a label or action aligns with project norms, omit it

> **MANDATORY: Support questions deserve answers, not just closure.**
>
> - When an issue is a user question or misunderstanding, the suggested comment MUST include a concise, helpful answer, not just "please use community channels"
> - Use the knowledge base to draft an accurate response that resolves the user's question
> - **Epistemic rigor in answers**: Only include information grounded in [FACT]+[DERIVED] from the knowledge base. If the answer involves [INFERENCE] (e.g., interpreting what the user meant), hedge explicitly. Never include [ASSUMPTION]-based content in a suggested comment — an incorrect answer posted under a maintainer's name is worse than no answer.
> - Frame the answer respectfully. Users may not know the issue templates or conventions

> **MANDATORY: `/close` requires proof, not assumptions.**
>
> Never suggest `/close` unless one of these conditions is **verified** (not assumed) — i.e., grounded in [FACT] + [DERIVED]:
> 1. **Provably addressed:** [FACT] A merged PR fixes the issue (cite the PR number) + [DERIVED] the fix covers the reported scenario (confirm by comparing the fix scope to the issue description)
> 2. **Author consent:** [FACT] The issue author explicitly stated the issue is resolved or no longer relevant (cite the comment)
> 3. **Maintainer/community consensus:** [FACT] Maintainers or a clear majority of participants agreed the issue should be closed (cite the comments)
>
> If none of these conditions are met at [FACT]+[DERIVED] level, **do not include `/close` in the suggested command.** Instead:
> - Provide a helpful comment (information, workaround, question for clarification) without `/close`
> - Add a note: "Further investigation required before closure"
> - If the issue looks like it might be resolved but you cannot verify (i.e., the evidence is [INFERENCE] or [ASSUMPTION]), say: "Verify with the author before closing"
>
> **Rationale:** Closing issues prematurely damages trust with reporters. A helpful comment without `/close` is always safe. A premature `/close` is not.
>
> **Before suggesting any action**, use the Dig Deeper workflow to verify your understanding. Generic knowledge base answers are not sufficient. You must check the specific scenario described in the issue (version, environment, exact error) against what the KB says. If you are not confident the suggestion is correct for that specific case, do not suggest it.

### Prerequisites

1. **`gh` CLI authenticated**: Run `gh auth status` to verify
2. **Knowledge base available**: The falco-expert repository must be accessible (at least `digests/` and `specs/`)
3. **Network access**: Required to fetch GitHub data via `gh` CLI

---

## 2. Core Repositories

The default triage scope covers the 9 **core** repositories (essential for building, installing, running, documenting, or using Falco):

| Repository | URL | Typical Issues | Key Specs/Digests |
|------------|-----|----------------|-------------------|
| `falco` | [falcosecurity/falco](https://github.com/falcosecurity/falco) | Engine bugs, config issues, output problems, CLI | [`architecture-overview.md`](../../specs/architecture-overview.md), [`rule-engine.md`](../../specs/rule-engine.md), [`configuration.md`](../../specs/configuration.md), [`output-system.md`](../../specs/output-system.md), [`cli-interface.md`](../../specs/cli-interface.md) |
| `libs` | [falcosecurity/libs](https://github.com/falcosecurity/libs) | Driver issues, syscall gaps, filter bugs, state tracking | [`kernel-instrumentation.md`](../../specs/kernel-instrumentation.md), [`libscap.md`](../../specs/libscap.md), [`libsinsp.md`](../../specs/libsinsp.md), [`filter-engine.md`](../../specs/filter-engine.md) |
| `rules` | [falcosecurity/rules](https://github.com/falcosecurity/rules) | False positives, rule requests, tuning | [`rules-content.md`](../../specs/rules-content.md), [`rule-engine.md`](../../specs/rule-engine.md) |
| `falcoctl` | [falcosecurity/falcoctl](https://github.com/falcosecurity/falcoctl) | Artifact management, driver install issues | [`falcoctl.md`](../../specs/falcoctl.md) |
| `plugins` | [falcosecurity/plugins](https://github.com/falcosecurity/plugins) | Plugin bugs, compatibility, new plugin requests | [`plugin-system.md`](../../specs/plugin-system.md) |
| `plugin-sdk-go` | [falcosecurity/plugin-sdk-go](https://github.com/falcosecurity/plugin-sdk-go) | SDK bugs, API questions | [`plugin-system.md`](../../specs/plugin-system.md) |
| `charts` | [falcosecurity/charts](https://github.com/falcosecurity/charts) | Helm issues, deployment problems, values.yaml | [`kubernetes-deployment.md`](../../specs/kubernetes-deployment.md) |
| `deploy-kubernetes` | [falcosecurity/deploy-kubernetes](https://github.com/falcosecurity/deploy-kubernetes) | Manifest issues, K8s compatibility | [`kubernetes-deployment.md`](../../specs/kubernetes-deployment.md) |
| `falco-website` | [falcosecurity/falco-website](https://github.com/falcosecurity/falco-website) | Doc gaps, corrections, content requests | [`falco-website/docs.md`](../../digests/falcosecurity/falco-website/docs.md) |

### Extended Scope

When the user requests triage beyond core repos, include these groups:

| Group | Repositories |
|-------|-------------|
| **Ecosystem** | `falcosidekick`, `falcosidekick-ui`, `falco-talon`, `k8s-metacollector`, `event-generator`, `falco-lsp`, `falco-operator`, `falco-playground` |
| **Infra** | `test-infra`, `driverkit`, `dbg-go`, `kernel-crawler`, `kernel-testing`, `pigeon`, `syscalls-bumper` |
| **SDKs** | `plugin-sdk-go`, `plugin-sdk-cpp`, `plugin-sdk-rs`, `falco-rustlings` |

Reference: [`digests/falcosecurity/evolution.md`](../../digests/falcosecurity/evolution.md) for the full repository map.

---

## 3. Input Selection

The skill accepts flexible input. Parse the user's request to determine scope.

### Selection Patterns

| User Input | Interpretation |
|------------|---------------|
| *(no specific selection)* | All open issues + PRs from the 9 core repos |
| `falcosecurity/falco` | All open issues + PRs from that single repo |
| `falcosecurity/falco#1234` | Single issue analysis (deep dive) |
| `core` | All 9 core repos |
| `ecosystem` | All ecosystem repos |
| `all` | All repos in the falcosecurity org |
| `falco, libs, rules` | Specific list of repos |
| `kind/bug` | All open issues with that label across core repos |
| `--since 2025-01-01` | Issues created/updated since that date |

### Default Behavior

When the user invokes this skill without specifying criteria:
1. Target: all 9 core repositories
2. State: open issues and open PRs
3. Ask the user to choose analysis depth (tiered or deep-dive-all)

---

## 4. GitHub CLI Reference

### Data Fetching Commands

**Issue listing** (per repo, uses core API — 5000 req/hr):
```bash
gh issue list --repo falcosecurity/REPO --state open --limit 500 \
  --json number,title,body,labels,author,assignees,comments,createdAt,updatedAt,url,milestone,state
```

**PR listing** (per repo, uses core API):
```bash
gh pr list --repo falcosecurity/REPO --state open --limit 200 \
  --json number,title,body,labels,author,assignees,comments,createdAt,updatedAt,url,milestone,state,reviewRequests,isDraft,headRefName,baseRefName
```

**Issue detail** (for deep dive):
```bash
gh issue view NUMBER --repo falcosecurity/REPO --json body,comments,labels,assignees,author,createdAt,updatedAt,url,title,state
```

**PR detail with reviews**:
```bash
gh pr view NUMBER --repo falcosecurity/REPO --json body,comments,labels,assignees,author,createdAt,updatedAt,url,title,state,reviews,reviewRequests,isDraft,headRefName,baseRefName,mergedAt,closedAt
```

**Search for related PRs** (by keywords in a specific repo):
```bash
gh pr list --repo falcosecurity/REPO --state all --limit 20 \
  --search "KEYWORDS" --json number,title,state,url,mergedAt,closedAt
```

**Rate limit check**:
```bash
gh api rate_limit --jq '.resources.core.remaining'
```

**Cross-repo search** (uses search API — 30 req/hr, use sparingly):
```bash
gh search issues --owner falcosecurity --state open --label "LABEL" --limit 100 \
  --json number,title,labels,repository,url,createdAt,updatedAt
```

### jq Filter Pitfall

Do not use the "not equal" operator (exclamation mark followed by equals sign) in jq filters. LLMs tend to render that two-character sequence as a single Unicode "not equal" glyph, which jq cannot parse. Use positive matching (`==`, `or`) or `| not` instead.

### Label System Reference

The falcosecurity organization uses a structured label taxonomy. The `falco` repo has the most complete set; other repos may have subsets.

> **Prow-managed labels:** All standard labels in falcosecurity repos are managed by Prow's `label` plugin. The recognized label prefixes are: `area`, `committee`, `kind`, `language`, `priority`, `sig`, `triage`, `wg`, plus a generic `/label` command for arbitrary labels. To add or remove labels, post a comment with the corresponding Prow command (e.g., `/kind bug`, `/remove-triage duplicate`). Do **not** use `gh issue edit --add-label` or `--remove-label` — it bypasses Prow and may cause inconsistencies.
>
> **Other triage-relevant Prow commands:** `/close [not-planned]`, `/reopen`, `/lifecycle`, `/remove-lifecycle`, `/milestone`, `/assign`, `/unassign`, `/transfer-issue`, `/retitle`, `/cc`, `/uncc`.
>
> **Full reference:** https://prow.falco.org/command-help

#### Kind Labels (issue type)

| Label | Prow command | Remove command |
|-------|-------------|----------------|
| `kind/bug` | `/kind bug` | `/remove-kind bug` |
| `kind/feature` | `/kind feature` | `/remove-kind feature` |
| `kind/cleanup` | `/kind cleanup` | `/remove-kind cleanup` |
| `kind/design` | `/kind design` | `/remove-kind design` |
| `kind/documentation` | `/kind documentation` | `/remove-kind documentation` |
| `kind/rule-create` | `/kind rule-create` | `/remove-kind rule-create` |
| `kind/rule-update` | `/kind rule-update` | `/remove-kind rule-update` |
| `kind/failing-test` | `/kind failing-test` | `/remove-kind failing-test` |
| `kind/release` | `/kind release` | `/remove-kind release` |
| `kind/support` | `/kind support` | `/remove-kind support` |

#### Priority Labels

| Label | Prow command | Remove command |
|-------|-------------|----------------|
| `priority/high` | `/priority high` | `/remove-priority high` |
| `priority/medium` | `/priority medium` | `/remove-priority medium` |
| `priority/low` | `/priority low` | `/remove-priority low` |

#### Area Labels (component)

| Label | Prow command | Remove command |
|-------|-------------|----------------|
| `area/rules` | `/area rules` | `/remove-area rules` |
| `area/engine` | `/area engine` | `/remove-area engine` |
| `area/build` | `/area build` | `/remove-area build` |
| `area/ci` | `/area ci` | `/remove-area ci` |
| `area/tests` | `/area tests` | `/remove-area tests` |
| `area/perf` | `/area perf` | `/remove-area perf` |
| `area/k8s-client` | `/area k8s-client` | `/remove-area k8s-client` |
| `area/proposals` | `/area proposals` | `/remove-area proposals` |

#### Triage Labels

| Label | Prow command | Remove command |
|-------|-------------|----------------|
| `triage/needs-information` | `/triage needs-information` | `/remove-triage needs-information` |
| `triage/not-reproducible` | `/triage not-reproducible` | `/remove-triage not-reproducible` |
| `triage/duplicate` | `/triage duplicate` | `/remove-triage duplicate` |
| `needs-kind` | *(auto-applied by Prow `require-matching-label`)* | *(removed automatically when a `/kind` command is used)* |

#### Lifecycle Labels

| Label | Prow command | Remove command |
|-------|-------------|----------------|
| `lifecycle/stale` | `/lifecycle stale` | `/remove-lifecycle stale` |
| `lifecycle/rotten` | `/lifecycle rotten` | `/remove-lifecycle rotten` |

---

## 5. Analysis Depth Modes

Before starting the triage, ask the user which mode to use.

### Mode Selection Prompt

Present this choice to the user:

> **Analysis depth:**
>
> 1. **Tiered approach** — Quick scan all issues/PRs (metadata-only), then deep dive into selected ones. Best for routine triage of large backlogs.
>
> 2. **Deep-dive all** — Full analysis of every issue/PR with knowledge base lookup. Most thorough but expensive in time and tokens. Best for small scope (single repo, filtered set).

### Tiered Mode

1. **Quick scan**: Analyze all issues/PRs using only metadata (labels, age, assignees, comment count)
2. **Score and rank**: Apply the scoring heuristic (see [Section 7.3](#73-quick-scan-scoring-heuristic))
3. **Present ranked list**: Show the user the top issues needing attention
4. **Selective deep dive**: Deep dive only into user-selected issues (or auto-select top N if user prefers)

### Deep-Dive-All Mode

Perform full analysis on every issue/PR:
- Fetch full body and comments
- Knowledge base lookup via Dig Deeper
- Check for related PRs and recent fixes
- Full categorization

**When to recommend each mode:**
- **Tiered**: > 50 open issues, routine maintenance, no specific focus area
- **Deep-dive-all**: < 50 open issues, single repo, specific label filter, single issue

---

## 6. Triage Workflow

This is the complete step-by-step algorithm. Follow these phases in order.

### Phase 0: Initialization

1. **Parse input scope**: Determine target repos, filters, and specific issues from user input (see [Section 3](#3-input-selection))

2. **Ask analysis depth**: Present the mode selection prompt (see [Section 5](#5-analysis-depth-modes))

3. **Verify prerequisites**:
   ```bash
   # Check authentication
   gh auth status

   # Check rate limit budget
   gh api rate_limit --jq '{core_remaining: .resources.core.remaining, search_remaining: .resources.search.remaining}'
   ```

4. **Load knowledge base index**: Read the repository's `README.md` to load the Table of Contents. This is your index for mapping issues to relevant specs and digests.

5. **Compute budget**: Calculate available API calls:
   - Available = core_remaining - 500 (safety margin)
   - Per-repo cost: 2 calls (issue list + PR list)
   - Per-deep-dive cost: ~3-5 calls (view + comments + PR search)
   - If budget is insufficient, warn the user and suggest reducing scope

### Phase 1: Data Collection

For each target repository:

```bash
# Fetch all open issues
gh issue list --repo falcosecurity/REPO --state open --limit 500 \
  --json number,title,body,labels,author,assignees,comments,createdAt,updatedAt,url,milestone,state

# Fetch all open PRs
gh pr list --repo falcosecurity/REPO --state open --limit 200 \
  --json number,title,body,labels,author,assignees,comments,createdAt,updatedAt,url,milestone,state,reviewRequests,isDraft,headRefName,baseRefName
```

**Rate limit strategy**: Use `gh issue list` / `gh pr list` per repo (core API, 5000/hr). **Never** use `gh search issues` for bulk data collection (search API, 30/hr).

Store the collected data for subsequent phases.

### Phase 2: Quick Scan (Tiered Mode Only)

For each issue and PR, perform a lightweight metadata-only analysis:

1. **Label check**: Does it have `kind/*`? `priority/*`? `area/*`?
2. **Assignment check**: Are there assignees?
3. **Staleness check**: When was it last updated? Does it have `lifecycle/stale` or `lifecycle/rotten`?
4. **Engagement check**: How many comments? Any reactions?
5. **Age check**: When was it created?
6. **Triage label check**: Does it have `needs-kind`, `triage/needs-information`?

Apply the scoring heuristic ([Section 7.3](#73-quick-scan-scoring-heuristic)) and present a ranked list to the user.

For the quick scan, also collect aggregate statistics:
- Total open issues/PRs per repo
- Issues missing kind labels
- Issues missing priority labels
- Stale/rotten issues
- Issues with no assignees and no recent activity

**Skip to Phase 4** for the quick-scanned issues (grouping based on metadata only). Only proceed to Phase 3 for issues selected for deep dive.

### Phase 3: Deep Dive Analysis

For each issue selected for deep dive (all issues in deep-dive-all mode):

#### Step 3a: Fetch Full Context

```bash
# Full issue with all comments
gh issue view NUMBER --repo falcosecurity/REPO \
  --json body,comments,labels,assignees,author,createdAt,updatedAt,url,title

# Search for related PRs (open and recently closed/merged)
gh pr list --repo falcosecurity/REPO --state all --limit 20 \
  --search "KEYWORDS_FROM_ISSUE" --json number,title,state,url,mergedAt
```

Extract keywords from the issue title and key terms from the body for the PR search.

#### Step 3b: Knowledge Base Analysis

Use the Dig Deeper workflow to understand the technical context. Map the issue to relevant specs/digests using the keyword table in [Section 8](#8-dig-deeper-integration).

Dig Deeper findings arrive pre-tagged with [FACT], [DERIVED], [INFERENCE], or [ASSUMPTION]. **Carry these tags forward** — they determine what you can claim about the issue in subsequent steps.

For each issue, determine:
1. **Is this a known architectural limitation or design decision?** Check relevant spec.
2. **Is this a documented feature being misunderstood?** Check digests and website docs.
3. **Does this relate to an existing proposal?** Check [`digests/falcosecurity/falco/proposals.md`](../../digests/falcosecurity/falco/proposals.md) and [`digests/falcosecurity/libs/proposals-and-architecture.md`](../../digests/falcosecurity/libs/proposals-and-architecture.md).
4. **Has the relevant code area changed in the current era?** Check spec source references.
5. **Which era does this issue belong to?** Infer from the Falco version mentioned in the issue body, `falco --support` output, or the creation date mapped to the [release schedule](../../AGENTS.md#release-schedule). If the issue spans multiple eras (e.g., reported in 0.39, still open in 0.43), note all relevant eras clearly.

#### Step 3c: Check If Already Addressed

**Epistemic tagging**: "Already addressed" is a high-stakes claim — it can lead to `/close`. Apply tagging rigorously:
- A PR that **explicitly references** this issue number (`Fixes #NNN`) → [FACT] it is linked
- Confirming the fix **covers the reported scenario** (comparing diff scope to issue description) → [DERIVED]
- A PR found via **keyword search** that seems related → [INFERENCE] at best. Not sufficient for "addressed" status or `/close`. Report as "Possibly related PR" with the [INFERENCE] tag.

1. **Related PRs**: Search for PRs mentioning the issue number or keywords
2. **Cross-repo fixes**: If the issue is in `falco`, check `libs` for related PRs (and vice versa)
3. **Recent merges**: Check if a recently merged PR resolved this

```bash
# Search for PRs referencing the issue number
gh pr list --repo falcosecurity/REPO --state all --limit 10 \
  --search "NUMBER" --json number,title,state,url,mergedAt

# For cross-repo checks (e.g., issue in falco, fix in libs)
gh pr list --repo falcosecurity/OTHER_REPO --state all --limit 10 \
  --search "KEYWORDS" --json number,title,state,url,mergedAt
```

#### Step 3d: Evaluate Acknowledgment and Consensus

> **Issues filed by core maintainers do not need triaging.** If the author has `MEMBER` or `OWNER` association, or is listed as a maintainer in [`digests/falcosecurity/evolution.md`](../../digests/falcosecurity/evolution.md), the issue is already triaged by definition. These issues just need implementation. In the report, mark their status as "Acknowledged (maintainer-filed)" and skip triage recommendations (label suggestions, priority assessments, closure suggestions). Focus the analysis on technical context from the knowledge base that could help whoever picks up the work.

Analyze the issue comments to determine:
1. **Acknowledged by maintainer?** [FACT] A maintainer commented. But "commented" does not equal "acknowledged the problem" — a maintainer asking for clarification is not acknowledgment. Only mark as "acknowledged" if the comment content confirms the maintainer recognizes the issue [DERIVED].
2. **Consensus on approach?** Are there agreed-upon next steps? Requires [FACT] (specific comments agreeing) + [DERIVED] (they constitute consensus).
3. **Blocked?** Is there a dependency on another issue or external factor?
4. **Stale discussion?** Has the conversation stopped without resolution?

#### Step 3e: Classify the Issue

**Epistemic tagging for classification**: An existing label is [FACT]. Classification from reading the full issue body and confirming the content matches a kind is [DERIVED]. Classification from keyword matching alone (e.g., "error message" → `kind/bug`) is [INFERENCE] — the error message might appear in a feature request context. Only [FACT]+[DERIVED] classifications become label suggestions in the report.

**Kind** (use existing label if present, otherwise judge from content):
- `bug`: Error reports, unexpected behavior, crashes, regressions
- `feature`: New capabilities, enhancements, API additions
- `support`: How-to questions, configuration help, usage guidance
- `cleanup`: Tech debt, refactoring, code quality
- `design`: Architecture discussions, proposals, RFCs
- `documentation`: Doc gaps, corrections, content requests
- `rule-create` / `rule-update`: Detection rule requests
- `failing-test`: Test infrastructure issues
- `release`: Release process issues

**Priority** (judge from content and impact):
- `critical`: Security vulnerability, data loss, crash affecting many users, no workaround
- `high`: Significant functionality broken, major user impact, workaround is painful
- `medium`: Moderate impact, reasonable workaround exists
- `low`: Cosmetic, minor inconvenience, nice-to-have improvement

**Status** (determined by analysis):

| Status | Meaning |
|--------|---------|
| `needs-triage` | No labels, no assignee, not yet evaluated |
| `acknowledged` | Maintainer has responded, issue is recognized |
| `in-progress` | Has assignee and/or linked open PR |
| `blocked` | Waiting on dependency, external factor, or upstream |
| `stale` | No activity for > 90 days |
| `misunderstanding` | Reporter misunderstands documented behavior |
| `doc-gap` | Documentation is missing or misleading (not a code bug) |
| `addressed` | Already fixed by a merged PR or in current codebase |
| `duplicate` | Duplicate of another issue |

### Phase 4: Grouping and Deduplication

After all analyses complete (quick scan and/or deep dives):

#### 4a: Duplicate Detection

**Epistemic tagging**: Duplicate claims are high-stakes — they lead to `/triage duplicate` + `/close`. Apply tagging:
- **Explicit references** in the issue body (`Duplicate of #NNN`, confirmed by a maintainer) → [FACT]
- **Identical error messages or stack traces** across issues → [FACT] (the messages match) + [DERIVED] (same root cause, if the error is specific enough)
- **Title similarity or keyword overlap** → [INFERENCE] only. Flag as "Possibly related" in the report, never as "duplicate". Two issues about the same component are not duplicates unless they describe the same problem.

Detection signals (tag each result appropriately):
- **Title similarity**: Normalize titles (lowercase, strip punctuation). Flag pairs with > 70% word overlap. Tag as [INFERENCE].
- **Error message matching**: Extract quoted error messages, stack traces, or log lines from issue bodies. Match across issues. Tag as [FACT] (messages match) + [DERIVED] (same cause) if errors are specific.
- **Code path references**: Extract file paths and function names. Group issues referencing the same code. Tag as [INFERENCE] — same code area does not mean same problem.
- **Explicit references**: Parse bodies for `#NNN`, `Duplicate of #NNN`, `Related to REPO#NNN`. Tag as [FACT].

#### 4b: Related Issue Clustering

> **MANDATORY grouping rule:** Only group issues together if they would realistically be **worked together** by the same person in the same effort. Ask: "Would fixing/addressing one of these directly help or require addressing the others?" If yes, group them. If not, keep them separate.
>
> Do NOT group issues just because they share a label, component area, or kind. For example, two unrelated `kind/feature` requests about different topics must NOT be grouped together.

Group types (all must pass the "worked together" test):

| Group Type | Criteria | Example |
|------------|----------|---------|
| **Same-root-cause** | Issues caused by the same underlying bug | Multiple crash reports from the same code path |
| **Duplicate** | Issues describing the same problem | Identical error messages, confirmed by maintainers |
| **Workflow-chain** | Issues that must be worked in sequence | libs change -> falco change -> rules update -> docs |
| **Overlapping-action** | Issues where a single fix or action resolves multiple | One config change that addresses several user reports |

Issues that do not fit any group are listed individually. Do not force grouping.

#### 4c: Cross-Repo Linking

Detect cross-repo relationships:
- Issue in `falco` that depends on a change in `libs`
- Issue in `rules` that depends on a new engine feature in `falco`
- Issue in `charts` that depends on a new config option in `falco`
- Issue in `falco-website` that documents a feature from another repo
- Issue in `plugins` that depends on a plugin API change in `libs`

### Phase 5: Report Generation

Generate the triage report using the template at [`templates/triage-report.md`](templates/triage-report.md).

1. **Add a Table of Contents** at the top of the report, right after the header. The ToC must list all sections and groups with anchor links so readers can jump to any section. Use standard markdown anchor format: `[Section Name](#anchor)`.
2. **Fill in all template sections** with collected data
3. **Generate actionable `gh` commands** for each recommendation (see [Section 10](#10-actionable-command-generation))
4. **Save the report** to `OUTPUT_DIR/YYYY-MM-DD-falco-triage-SCOPE.md` (see [Output Path Resolution Protocol](../../AGENTS.md#output-path-resolution-protocol)) where:
   - `YYYY-MM-DD` is today's date
   - `SCOPE` describes the triage scope (e.g., `core`, `falco`, `falco-1234`)

### Phase 6: Summary

After saving the report:
1. Print an executive summary to the user (total issues, actionable items, key findings)
2. List the top 5-10 most actionable items
3. Report rate limit usage (calls used vs. budget)
4. Inform the user of the report file location

---

## 7. Categorization and Priority Judgment

### 7.1 Kind Classification Rules

When an issue lacks a `kind/*` label, classify it based on content analysis:

| Signal | Likely Kind |
|--------|-------------|
| Error messages, stack traces, "doesn't work", "broken" | `kind/bug` |
| "Would be nice", "please add", "feature request" | `kind/feature` |
| "How do I", "what is the correct way", "help" | `kind/support` |
| "Refactor", "clean up", "deprecate", "remove" | `kind/cleanup` |
| "Proposal", "RFC", "design", "architecture" | `kind/design` |
| "Documentation", "docs", "typo", "example" | `kind/documentation` |
| "New rule", "detection for" | `kind/rule-create` |
| "False positive", "rule update", "tune" | `kind/rule-update` |
| "Test failure", "CI broken", "flaky test" | `kind/failing-test` |

### 7.2 Priority Judgment Criteria

| Priority | Criteria |
|----------|----------|
| **Critical** | Security vulnerability (CVE, privilege escalation), data loss, crash affecting production, no workaround. Affects many users. |
| **High** | Significant functionality broken, major user workflow blocked, workaround exists but is painful. Regression from previous version. |
| **Medium** | Moderate impact, reasonable workaround exists, affects a subset of users. Enhancement with clear value. |
| **Low** | Cosmetic issues, minor inconvenience, edge cases, nice-to-have improvements. Low user impact. |

**Priority signals from issue metadata:**
- High comment count (> 10) and reactions suggest higher priority
- Issues open for > 1 year without resolution may indicate difficulty rather than low priority
- Issues from maintainers or known contributors may indicate higher awareness of impact
- Issues with linked PRs that were abandoned may need priority re-evaluation

### 7.3 Quick-Scan Scoring Heuristic

For tiered mode, compute a triage-need score per issue:

```
score = 0

# Missing classification (needs triage attention)
if no kind/* label:       score += 3
if no priority/* label:   score += 2
if no area/* label:       score += 1
if no assignees:          score += 2

# Engagement signals
if comments == 0:         score += 3
if comments > 10:         score += 1   (high engagement = needs attention)

# Age and staleness
if age < 14 days:         score += 2   (new, needs prompt triage)
if age > 180 days AND last_update > 90 days: score += 1  (stale, needs decision)

# Explicit triage flags
if has "needs-kind" label:     score += 4
if has "triage/needs-information" and age > 30 days: score += 2  (info never provided)

# Already-triaged indicators (reduce score)
if has lifecycle/stale or lifecycle/rotten:  score -= 5
if has assignees AND has kind/* label:       score -= 3
```

Rank issues by score descending. Present the top items for deep dive selection.

---

## 8. Dig Deeper Integration

### When to Invoke Dig Deeper

Read [`WORKFLOWS.md`](../../WORKFLOWS.md) before executing the Dig Deeper workflow. Use it for deep-dive analysis of individual issues. Not every issue needs a full investigation — use this decision tree:

| Issue Type | Dig Deeper Scope |
|------------|-----------------|
| Support request (how-to question) | Check [`falco-website/docs.md`](../../digests/falcosecurity/falco-website/docs.md) only |
| Bug with stack trace or error message | Check the relevant component spec |
| Feature request | Check [`falco/proposals.md`](../../digests/falcosecurity/falco/proposals.md) and relevant spec for design context |
| Config-related issue | Check [`configuration.md`](../../specs/configuration.md) spec |
| Rule false positive / request | Check [`rules-content.md`](../../specs/rules-content.md) and [`rule-engine.md`](../../specs/rule-engine.md) |
| Unclear or complex issue | Full Dig Deeper with parallel sub-agents |

### Keyword-to-Knowledge-Base Mapping

Use this table to route issues to the correct specs and digests:

| Issue Keywords | Specs | Digests |
|---------------|-------|---------|
| driver, ebpf, kmod, kernel, probe, syscall | [`kernel-instrumentation.md`](../../specs/kernel-instrumentation.md), [`libscap.md`](../../specs/libscap.md) | [`libs/kernel-instrumentation.md`](../../digests/falcosecurity/libs/kernel-instrumentation.md), [`libs/modern-bpf.md`](../../digests/falcosecurity/libs/modern-bpf.md) |
| rule, condition, macro, list, exception, priority, output format | [`rule-engine.md`](../../specs/rule-engine.md), [`filter-engine.md`](../../specs/filter-engine.md) | [`falco/rule-language.md`](../../digests/falcosecurity/falco/rule-language.md), [`rules.md`](../../digests/falcosecurity/rules.md) |
| config, yaml, merge, option, setting | [`configuration.md`](../../specs/configuration.md) | [`falco/configuration.md`](../../digests/falcosecurity/falco/configuration.md) |
| output, alert, http, syslog, json | [`output-system.md`](../../specs/output-system.md) | [`falco/outputs.md`](../../digests/falcosecurity/falco/outputs.md) |
| plugin, container, k8saudit, k8smeta, cloudtrail | [`plugin-system.md`](../../specs/plugin-system.md) | [`libs/plugin-framework.md`](../../digests/falcosecurity/libs/plugin-framework.md), [`plugins.md`](../../digests/falcosecurity/plugins.md) |
| helm, chart, deploy, kubernetes, daemonset, values.yaml | [`kubernetes-deployment.md`](../../specs/kubernetes-deployment.md) | [`charts.md`](../../digests/falcosecurity/charts.md), [`deploy-kubernetes.md`](../../digests/falcosecurity/deploy-kubernetes.md) |
| falcoctl, artifact, install, driver install, follow | [`falcoctl.md`](../../specs/falcoctl.md) | [`falcoctl.md`](../../digests/falcosecurity/falcoctl.md) |
| build, cmake, compile, link, dependency | [`build-system.md`](../../specs/build-system.md) | [`falco/architecture.md`](../../digests/falcosecurity/falco/architecture.md) |
| metric, prometheus, health, stats, /metrics | [`metrics-and-observability.md`](../../specs/metrics-and-observability.md) | [`falco/architecture.md`](../../digests/falcosecurity/falco/architecture.md) |
| sidekick, fan-out, forward, alert routing | [`falcosidekick.md`](../../specs/falcosidekick.md) | [`falcosidekick/README.md`](../../digests/falcosecurity/falcosidekick/README.md) |
| filter, field, operator, transformer, filtercheck | [`filter-engine.md`](../../specs/filter-engine.md) | [`libs/filtering.md`](../../digests/falcosecurity/libs/filtering.md) |
| state, thread, fd, table, sinsp | [`libsinsp.md`](../../specs/libsinsp.md) | [`libs/libsinsp.md`](../../digests/falcosecurity/libs/libsinsp.md), [`libs/state-management.md`](../../digests/falcosecurity/libs/state-management.md) |
| cli, flag, option, -V, --list, introspection | [`cli-interface.md`](../../specs/cli-interface.md) | [`falco/cli-reference.md`](../../digests/falcosecurity/falco/cli-reference.md) |
| lifecycle, signal, reload, hot reload, restart | [`application-lifecycle.md`](../../specs/application-lifecycle.md) | [`falco/architecture.md`](../../digests/falcosecurity/falco/architecture.md) |

### Sub-Agent Context Template

When invoking the Dig Deeper workflow for a specific issue, use this context template for sub-agents:

```
You are a sub-agent performing knowledge base analysis for the falco-triage workflow.

**Your Role:** Determine if GitHub issue [REPO]#[NUMBER] relates to known
architecture, documented features, known limitations, or existing proposals
in the falco-expert knowledge base.

**Issue context:**
- Title: [TITLE]
- Body excerpt: [FIRST 500 CHARS OF BODY]
- Labels: [LABELS]
- Detected component area: [AREA FROM KEYWORD MAPPING]

**Investigation order:** specs/ -> digests/ -> refs/

**Epistemic Tagging (MANDATORY):**
Tag every finding with one of these categories (see AGENTS.md for full definitions):
- **[FACT]** — Directly verified from a citable source. Include the source reference.
- **[DERIVED]** — Logically follows from [FACT]s. Show the reasoning chain.
- **[INFERENCE]** — Probably follows from facts but involves interpretation. Flag the uncertainty.
- **[ASSUMPTION]** — Not verified. Report it transparently but do NOT use it to draw conclusions.

Only [FACT] and [DERIVED] can support definitive answers to the questions below.
If you cannot verify something, tag it [ASSUMPTION] and move on.

**Key questions to answer:**
1. Is this a known architectural limitation or design decision?
2. Is this a documented feature being misunderstood?
3. Does this relate to an existing proposal?
4. Has the relevant code area changed in the current era (0.43)?
5. Is there documentation that would resolve this issue?

**Output requirements:**
- Tag every finding with [FACT], [DERIVED], [INFERENCE], or [ASSUMPTION]
- Every [FACT] must cite a specific file in the knowledge base
- If not found, explicitly state "Not found in knowledge base"
- Group findings by epistemic tag for easy aggregation
- Provide: findings summary, relevant knowledge base context, source citations
```

---

## 9. PR Analysis

### PR Triage Criteria

#### Staleness Thresholds

| Status | Last Update | Action |
|--------|-------------|--------|
| **Active** | < 14 days ago | No action needed |
| **Stale warning** | 14-30 days ago | Consider a reminder comment |
| **Stale** | 30-90 days ago | Ask if still being worked on |
| **Abandoned** | > 90 days ago | Consider closing with note to reopen if needed |

#### Review Status Evaluation

Check these conditions:

| Condition | Flag |
|-----------|------|
| No reviewers assigned | Needs reviewer assignment |
| Reviews requested, no responses > 7 days | Reviewers need nudge |
| Changes requested, not addressed > 14 days | Author needs nudge |
| Approved but not merged > 7 days | May be blocked (check CI, hold labels) |
| Draft PR with no activity > 30 days | May be abandoned |

#### PR Health Check Commands

```bash
# Review status
gh pr view NUMBER --repo falcosecurity/REPO \
  --json reviews,reviewRequests,isDraft,state,labels

# CI/check status
gh pr checks NUMBER --repo falcosecurity/REPO
```

### PR-Issue Linking

Detect PR-issue links by:
1. PR body references: `Fixes #NNN`, `Closes #NNN`, `Resolves #NNN`
2. PR title mentions: `#NNN`
3. Branch name patterns: `fix/NNN-*`, `feature/NNN-*`
4. Cross-repo: PR in `libs` referencing `falco#NNN`

For issues with linked open PRs: mark as `in-progress` and note the PR status.

---

## 10. Actionable Command Generation

Every recommendation in the report includes a ready-to-run `gh` command placed inline with the corresponding issue or PR analysis. **Do NOT create a separate "Actionable Commands" section.** Commands belong next to the issue/PR they act on so maintainers have full context when deciding whether to execute them.

**These are suggestions only.** The report must clearly state that maintainers should review each command before executing.

**Epistemic gate**: Before generating any `gh` command, check the epistemic grounding of the analysis that motivates it (see [Report Quality Rules](#report-quality-rules)). Commands with destructive or hard-to-reverse effects (`/close`, `/triage duplicate`) require [FACT]+[DERIVED]. Non-destructive commands (`/kind`, `/area`, `/triage needs-information`) require at least [FACT]+[INFERENCE]. Commands grounded only in [ASSUMPTION] are never generated.

### Label Suggestions

Labels in falcosecurity repos are managed by Prow via comment commands. Only suggest labels that align with project guidelines:

```bash
# Apply missing kind label (this also removes needs-kind automatically)
gh issue comment NUMBER --repo falcosecurity/REPO --body "/kind bug"

# Apply area label
gh issue comment NUMBER --repo falcosecurity/REPO --body "/area engine"

# Apply triage label
gh issue comment NUMBER --repo falcosecurity/REPO --body "/triage needs-information"

# Remove lifecycle label
gh issue comment NUMBER --repo falcosecurity/REPO --body "/remove-lifecycle stale"

# Close an issue
gh issue comment NUMBER --repo falcosecurity/REPO --body "/close"

# Multiple commands in one comment (one per line)
gh issue comment NUMBER --repo falcosecurity/REPO --body "/kind bug
/area engine"
```

> **Never use `gh issue edit --add-label` or `--remove-label`** — all label changes go through Prow commands posted as comments. See [Label System Reference](#label-system-reference) for the full command list and https://prow.falco.org/command-help for all available Prow commands.

> **Do NOT suggest `priority/*` labels.** The project has no public prioritization policy. Priority is an internal triage assessment only.

### Triage Actions

```bash
# Mark as duplicate and close (ONLY if both issues clearly describe the same problem)
gh issue comment NUMBER --repo falcosecurity/REPO \
  --body "Closing as duplicate of #OTHER. See #OTHER for tracking.

/triage duplicate
/close"

# Provide helpful answer WITHOUT closing (default for support questions)
# Let the author confirm the answer resolves their issue before closing
gh issue comment NUMBER --repo falcosecurity/REPO \
  --body "ANSWER_THAT_ADDRESSES_THE_QUESTION

Let us know if this resolves the issue."

# Close with answer ONLY when closure is verified (author confirmed, PR merged, etc.)
gh issue comment NUMBER --repo falcosecurity/REPO \
  --body "ANSWER_THAT_RESOLVES_THE_QUESTION

/close"

# Request more information
gh issue comment NUMBER --repo falcosecurity/REPO \
  --body "REQUEST_FOR_DETAILS

/triage needs-information"
```

> **Default to answering without closing.** Only include `/close` when you have verified proof of resolution (see [Report Quality Rules](#report-quality-rules)). A helpful response that leaves the issue open for author confirmation is always the safer choice.

### PR Cleanup

```bash
# Nudge stale PR
gh pr comment NUMBER --repo falcosecurity/REPO \
  --body "Hey @AUTHOR, any update on this? Let us know if you need help."

# Close abandoned PR
gh pr close NUMBER --repo falcosecurity/REPO \
  --comment "Closing due to inactivity. Feel free to reopen if you want to pick this up again."
```

### Comment Style

The triage report is ghost-written for a Falco maintainer. The default tone is **direct, concise, friendly, and technically precise**.

**Default style:**
- **Concise and direct**: Keep comments short and to-the-point. Prefer one clear sentence over three vague ones.
- **Friendly but informal**: "Hey", "Can you check...", "LGTM", "Looks like...", "cc @someone"
- **Technical**: Include specific version numbers, config keys, links to docs/code
- **Use collaborative language**: "Could you..." / "Can you check..." instead of "You must..." / "Please ensure..."

**Avoid these patterns in suggested comments** (they tend to read as AI-generated):
- Using em dashes (`--`) as punctuation. Prefer periods, commas, or semicolons.
- "Thank you for reaching out", "I hope this helps", "Please don't hesitate to reach out"
- "Great question", "Excellent report", "We appreciate your detailed report"
- Overly formal or verbose explanations
- Filler phrases like "I noticed that...", "It seems like...", "It would be great if..."
- Bullet-heavy comments where a sentence would do

These anti-AI-pattern rules always apply, even when external style instructions are provided.

**Reference examples** (from actual maintainer comments):

```
Hey @user, can you confirm if the solution described by this comment worked for you?

I suspect this might be related to a configuration issue that we have fixed in chart v6.2.0

Is this still an issue? Let us know, thanks!

/remove-lifecycle stale
```

**Bad examples** (LLM-style, avoid):
```
Thank you for reaching out. We appreciate your detailed report. Could you kindly provide...

I hope this helps! Please don't hesitate to reach out if you have further questions.

We'd like to express our gratitude for your contribution to the project.
```

#### External Style Instructions

This skill ships an **opinionated default style** (above). It is not tied to any specific person's voice; it focuses on triage substance (what to say).

If the orchestrating agent provides external style instructions (e.g., from a dedicated writing-style skill), apply those instructions to all suggested comments and report text. External style instructions take precedence over the default style above, but the anti-AI-pattern rules always apply.

---

## 11. Rate Limit Management

> **MANDATORY: Check and track rate limits throughout the workflow.** Running out of API calls mid-triage wastes all prior work if the report can't be completed.

### Budget Allocation

| Operation | Calls Per Repo | Total (9 repos) | Notes |
|-----------|---------------|------------------|-------|
| Issue list | 1-3 | 9-27 | Paginated at 100/page by `gh` CLI |
| PR list | 1-2 | 9-18 | Paginated at 100/page by `gh` CLI |
| Issue deep dive | 2-3 per issue | Variable | view + PR search |
| PR deep dive | 2-3 per PR | Variable | view + reviews |
| Rate limit check | 1-3 | 1-3 | Init + mid-run checks |
| **Total base** | | **~50** | Before any deep dives |

### Strategy

1. **Check budget at Phase 0**:
   ```bash
   gh api rate_limit --jq '{core: .resources.core.remaining, search: .resources.search.remaining, core_reset: .resources.core.reset}'
   ```
2. **Reserve 500 calls** as safety margin. Never dip below this
3. **Calculate budget before starting**:
   - `listing_cost = repos * 4` (issue list + PR list, with pagination headroom)
   - `deep_dive_cost = estimated_issues * 5` (view + comments + PR search + cross-repo)
   - `total_needed = listing_cost + deep_dive_cost`
   - If `total_needed > (remaining - 500)`: warn user, suggest reducing scope or using tiered mode
4. **Track usage during execution**: After completing Phase 1 (data collection), re-check remaining budget:
   ```bash
   gh api rate_limit --jq '.resources.core.remaining'
   ```
   Recalculate how many deep dives are affordable. Inform the user if the budget constrains the number of deep dives.
5. **Batch API calls efficiently**:
   - Use `gh issue list` with `--json` to fetch body+comments in one call when possible (avoids separate `gh issue view` calls)
   - Use `--limit` to cap results to what's needed (don't fetch 500 issues if the user asked for 20)
   - Prefer `gh issue list --search "KEYWORDS"` over separate `gh search issues` calls (core API vs search API)
6. **Never use search API for bulk operations.** The 30 req/hr limit is too restrictive
7. **If budget runs low mid-run**: Stop deep dives immediately, generate a partial report with whatever data is available, clearly mark which issues got deep dives and which didn't
8. **Log actual API usage** in the report methodology section (calls used, remaining at end)

### Rate Limit Recovery

If a `gh` call fails with HTTP 403 or 429 (rate limited):
```bash
gh api rate_limit --jq '.resources.core | {remaining, reset: (.reset | strftime("%H:%M:%S UTC"))}'
```
- Report the reset time to the user
- Save whatever partial report is possible
- **Do not sleep, poll, or retry.** Stop and let the user decide whether to wait or reduce scope

### Minimizing Waste

- **Phase 1 data is reusable**: The initial `gh issue list` call already fetches `body` and `comments`. For many issues, this is enough for analysis without a separate `gh issue view` call. Only fetch additional data (detailed comments, PR searches) during deep dives.
- **Parallelize where possible**: Multiple `gh` calls to different repos can run concurrently.
- **Cache across runs**: If the user runs triage multiple times in the same session, note that GitHub data changes slowly. Avoid re-fetching data that was fetched within the last few minutes.

---

## 12. Error Handling and Edge Cases

| Scenario | Handling |
|----------|----------|
| `gh auth status` fails | Halt with authentication instructions |
| Rate limit exceeded mid-run | Save partial report, report reset time, stop |
| Empty repo (no open issues/PRs) | Skip, note in report |
| Very large issue body (> 64KB) | Truncate to first 8000 chars for analysis |
| Issue in archived repo | Skip with note |
| Private repo (no access) | Skip with note |
| API timeout | Retry once, then skip with note |
| No issues match selection criteria | Generate empty report with note |
| Paginated results (> 500 issues) | Use pagination, warn about increased API usage |
| Issue body in non-English | Analyze as best as possible, note language |
