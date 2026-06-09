# WORKFLOWS.md

This file contains workflow definitions for AI agents working with this repository.

Workflows are shortcuts for common operations. When a user invokes a workflow, follow the steps described below.

---

## Available Workflows

| Workflow | Trigger Phrases | Purpose |
|----------|-----------------|---------|
| [Dig Deeper](#dig-deeper) | "dig deeper", "tell me about", "explain", "what is" | Extract factual information from the knowledge base |
| [Ingest](#ingest) | "ingest this", "ingest `<content>`" | Add new content to the knowledge base |
| [Era Transition](#era-transition) | "bump era", "new era", "update to 0.XX" | Transition the knowledge base to a new Falco release era |

---

## Dig Deeper

**Triggered by:** "dig deeper", "tell me about", "explain", "what is", questions about Falco concepts, requests for factual information

**Also used by:** Other workflows (e.g., Ingest) when they need to:
- Understand a topic or concept
- Judge the relevance of content
- Get contextual information for decision-making
- Verify statements or claims

**Purpose:** Extract accurate, factual, and verifiable information from the knowledge base.

### Core Principles

1. **Read-only**: This workflow MUST NEVER modify repository content (except for the output report)
2. **Factual only**: Provide only information that exists in this repository
3. **No hallucinations**: Never invent or assume information not found in the knowledge base
4. **Verifiable**: Every statement must have a traceable source reference
5. **Wikipedia-style citations**: Annotate all facts with their originating document
6. **Epistemic tagging**: Every finding must be tagged [FACT], [DERIVED], [INFERENCE], or [ASSUMPTION] per the [Epistemic Tagging](AGENTS.md#epistemic-tagging) rules in AGENTS.md. Only [FACT] and [DERIVED] items support conclusions in the final report. [INFERENCE] items are presented with hedging. [ASSUMPTION] items are segregated into a dedicated section — never mixed with verified content.

### Output Requirements

**The output of this workflow MUST be a Markdown report** saved to `OUTPUT_DIR` (see [Output Path Resolution Protocol](AGENTS.md#output-path-resolution-protocol)).

#### Report File Naming

Filenames **must be prefixed with the current date** for chronological ordering and traceability:
- `YYYY-MM-DD-<topic>.md` inside `OUTPUT_DIR` (e.g., `2026-02-23-falco-issue-3789-race-condition.md`)

#### ⚠️ MANDATORY: Reference Links on Every Statement

**THIS IS NON-NEGOTIABLE**: Every factual statement in the report MUST have a reference link.

- **No statement without a citation**: If you cannot cite a source, do not include the statement
- **Use absolute GitHub URLs**: All references must be clickable URLs pointing to the actual source files
- **Include line numbers**: When referencing code, include specific line numbers

**Why absolute URLs?**
- Reports are often shared externally (the `output/` directory inside the repo is gitignored)
- Relative links would break when the file is viewed outside the repository
- Absolute URLs ensure references remain valid and verifiable

#### Reference URL Format

Use the raw GitHub URL format for refs:

```
https://github.com/falcosecurity/<repo>/blob/<branch-or-tag>/<path>#L<line>
```

**Examples:**

For source code in `refs/`:
```markdown
The `get_path_for_dir_fd()` function resolves directory file descriptors[¹].

[¹]: https://github.com/falcosecurity/libs/blob/0.20.1/userspace/libsinsp/threadinfo.cpp#L826-L857
```

For digests (use this repository's URL):
```markdown
The modern eBPF driver is the default since Falco 0.38[²].

[²]: https://github.com/<owner>/falco-expert/blob/main/digests/falcosecurity/libs/modern-bpf.md
```

For external issues/PRs:
```markdown
This bug was reported in issue #3789[³].

[³]: https://github.com/falcosecurity/falco/issues/3789
```

### Sub-Agent Context

When spawning sub-agents for investigation, **always provide the following context** so they can optimize their process:

```
You are a sub-agent working within the "Dig Deeper" workflow of the Falco Expert knowledge base.

**Your Role:** Investigate a specific sub-topic and return findings with source references.

**Workflow Context:**
- You are part of a parallel investigation where multiple sub-agents research different aspects
- Your output will be aggregated into a final report with mandatory citations
- Every factual statement you report MUST include its source file and line numbers
- Follow the investigation order: specs/ → digests/ → refs/

**Epistemic Tagging (MANDATORY):**
Tag every finding with one of these categories (see AGENTS.md for full definitions):
- **[FACT]** — Directly verified from a citable source. Include the source reference.
- **[DERIVED]** — Logically follows from [FACT]s. Show the reasoning chain.
- **[INFERENCE]** — Probably follows from facts but involves interpretation. Flag the uncertainty.
- **[ASSUMPTION]** — Not verified. Report it transparently but do NOT use it to draw conclusions.

Only [FACT] and [DERIVED] can support definitive conclusions. If you cannot verify something, tag it [ASSUMPTION] and move on — do not present it as established.

**Output Requirements:**
- Quote relevant code snippets with file paths and line numbers
- Track every document you analyze
- Use absolute paths within the repository (e.g., <repo-root>/refs/falcosecurity/libs/...)
- Structure your findings clearly for easy aggregation, grouped by epistemic tag
- If information is not found, explicitly state this — do not invent or assume

**Working Directory:** <the repository root directory>
**Output Directory:** <the resolved OUTPUT_DIR absolute path>
All output files must be written to this directory. Do not resolve the output path yourself.
```

This context ensures sub-agents:
- Understand the citation requirements upfront
- Follow the correct investigation order
- Track sources properly for the final report
- Avoid hallucinations by knowing the "missing information" protocol

### Step 0: Create an Investigation Plan

Before investigating, **always create a plan first**:

1. **Analyze the request**: Break down the user's query into distinct topics/sub-topics
2. **Consult indexes**: Use [`README.md`](README.md) and [`AGENTS.md`](AGENTS.md) to identify potentially relevant documents
3. **Design parallel investigation**: Create sub-tasks that can be processed concurrently
4. **Assign sub-agents**: Each sub-topic should be investigated by a dedicated sub-agent
5. **Include workflow context**: When spawning sub-agents, include the [Sub-Agent Context](#sub-agent-context) in their prompt

The plan enables parallel processing of the large knowledge base and ensures comprehensive coverage.

### Step 1: Investigation Process (Per Sub-Agent)

Each sub-agent investigating a topic MUST follow this process:

#### 1.1 Identify Relevant Documents

Use your knowledge and all indexes in this repo ([`README.md`](README.md), [`AGENTS.md`](AGENTS.md), folder READMEs) to identify documents relevant to your assigned topic.

#### 1.2 Follow the Investigation Order

Process documents in this order (most comprehensive to most detailed):

```
specs/ → digests/ → refs/
```

1. **Start with [`specs/`](specs/)**: Check for existing specifications on the topic
   - Follow any references to [`digests/`](digests/) or [`refs/`](refs/)

2. **Then analyze [`digests/`](digests/)**: Read relevant digest files
   - Follow references to source files in [`refs/`](refs/)

3. **Finally, consult [`refs/`](refs/)**: Access original source files if needed
   - Use for verification or when digests lack sufficient detail

4. **Iterate as needed**: Go back and forth between layers
   - If you suspect context loss due to data size, repeat the investigation

#### 1.3 Use the `falco-cli` Skill

At any point, use the [`falco-cli`](skills/falco-cli/SKILL.md) skill to:
- Gather additional information from the actual Falco binary
- Verify statements against CLI output
- Resolve ambiguities in documentation

#### 1.4 Track Sources

**MANDATORY**: Keep detailed notes of:
- Every document analyzed
- Specific sections/line numbers consulted
- Which document provided which piece of information

This tracking is essential for citation in the final output.

#### 1.5 Structure Output for Aggregation

Sub-agents should structure their output to facilitate aggregation into the final report:

1. **Lead with key findings**: Start with the most important discoveries
2. **Quote code with context**: Include file paths, line numbers, and surrounding context
3. **Use consistent formatting**: Headers, code blocks, and tables for easy parsing
4. **Tag every finding**: Use [FACT], [DERIVED], [INFERENCE], or [ASSUMPTION] on each item. Group findings by tag or clearly mark each inline. This is how the aggregation step knows which items can support conclusions and which cannot.
5. **End with a source summary table**: List all documents analyzed with their relevance

**Example sub-agent output structure:**
```markdown
## Key Findings

1. [FACT] <Finding with source reference>
2. [DERIVED] <Conclusion with reasoning chain referencing the facts above>
3. [INFERENCE] <Probable interpretation, flagged as uncertain>

## Detailed Analysis

### <Sub-topic>
<Analysis with code quotes, line numbers, and epistemic tags on each claim>

## Unverified Items

- [ASSUMPTION] <Item that could not be verified — reported for transparency>

## Sources Analyzed

| File | Lines | Key Information |
|------|-------|-----------------|
| `threadinfo.cpp` | 826-857 | dirfd resolution logic |
```

### Step 2: Verify External Information

If any information comes from:
- Your training data (model weights)
- External sources (websites, APIs)

It starts as **[ASSUMPTION]** until verified. You MUST verify it against the knowledge base before using it:
- Find corroborating evidence in [`specs/`](specs/), [`digests/`](digests/), or [`refs/`](refs/)
- If corroborated, **promote to [FACT]** and record the verification source
- If no corroboration exists, it remains [ASSUMPTION] — **do not use it in conclusions**

### Step 3: Handle Missing Information

**MANDATORY**: If information is not found in the knowledge base:

- **Do NOT invent or hallucinate**
- **Do NOT present speculation as fact**
- Report explicitly: "This information is not present in the knowledge base"
- If you have a plausible guess, tag it **[ASSUMPTION]** and segregate it from verified findings — never mix it into conclusions
- Optionally suggest which documents might be missing or need to be ingested

### Step 4: Compile the Report

Once all sub-agents complete their investigation:

1. **Aggregate findings by epistemic tier**: Collect all sub-agent output and group by tag
   - [FACT] and [DERIVED] items form the body of the report
   - [INFERENCE] items are included with hedging language (e.g., "likely", "appears to", question form)
   - [ASSUMPTION] items go into a dedicated "Unverified / Needs Investigation" section — never mixed into the main findings
2. **Verify tag chains**: Before promoting a sub-agent's [DERIVED] item, confirm that its premise [FACT]s are actually present and cited. If a premise is missing or was tagged [ASSUMPTION] by the sub-agent, downgrade the derived item to [INFERENCE] or [ASSUMPTION].
3. **Remove redundancies**: Consolidate duplicate information
4. **Organize logically**: Structure the report by topic with clear sections
5. **Add citations to EVERY statement**: This is MANDATORY — no exceptions

#### Report Structure

```markdown
# <Report Title>

**Topic:** <Brief description>
**Date:** <YYYY-MM-DD>
**Status:** <Investigation status>

---

## Summary

<Brief overview with citations on every claim[¹][²]>

---

## <Section 1>

<Content with mandatory citations[³]>

---

## <Section N>

<Content with mandatory citations[⁴]>

---

## Unverified / Needs Investigation

<[ASSUMPTION] items collected from sub-agents, clearly separated from verified findings.
Each item states what was assumed, why it could not be verified, and optionally what
sources would need to be consulted or ingested to resolve it. Omit this section if
all findings were verified.>

---

## References

[¹]: <absolute-url> - <description>
[²]: <absolute-url> - <description>
[³]: <absolute-url> - <description>
[⁴]: <absolute-url> - <description>
```

#### Citation Checklist

Before finalizing the report, verify:

- [ ] **Every factual statement has a citation** - no exceptions
- [ ] **All URLs are absolute** - no relative paths
- [ ] **Code references include line numbers** - e.g., `#L826-L857`
- [ ] **References section is complete** - all citations are listed
- [ ] **URLs are valid** - test that links work

#### Response Guidelines

- **DO**: Provide factual, concise information with citations on every statement
- **DO**: Use absolute GitHub URLs for all references
- **DO**: Include a complete References section at the end
- **DO NOT**: Include statements without citations
- **DO NOT**: Use relative paths for references
- **DO NOT**: Add opinions or recommendations unless explicitly requested

### Step 5: Save the Report

Save the compiled report to `OUTPUT_DIR` (see [Output Path Resolution Protocol](AGENTS.md#output-path-resolution-protocol)):

1. Choose a descriptive filename (see [Report File Naming](#report-file-naming))
2. Write the report using the Write tool
3. Inform the user of the report location

#### Optional: Save Sub-Agent Outputs

If the user requests it (e.g., "save sub-agent outputs", "include raw findings"), also save individual sub-agent investigation outputs:

**File naming convention** (follows [File Naming Conventions](AGENTS.md#file-naming-conventions)):
```
OUTPUT_DIR/YYYY-MM-DD-<report-name>/
├── YYYY-MM-DD-<report-name>-report.md              # Final compiled report
├── YYYY-MM-DD-<report-name>-subagent-1-<topic>.md  # Sub-agent 1 raw output
├── YYYY-MM-DD-<report-name>-subagent-2-<topic>.md  # Sub-agent 2 raw output
└── ...
```

**Example:**
```
OUTPUT_DIR/2026-02-23-falco-issue-3789-race-condition/
├── 2026-02-23-falco-issue-3789-race-condition-report.md              # Final report
├── 2026-02-23-falco-issue-3789-race-condition-kernel-capture.md      # Kernel capture investigation
├── 2026-02-23-falco-issue-3789-race-condition-dirfd-resolution.md    # dirfd resolution investigation
├── 2026-02-23-falco-issue-3789-race-condition-cloexec-staleness.md   # O_CLOEXEC staleness investigation
└── 2026-02-23-falco-issue-3789-race-condition-event-flow.md          # Event flow architecture investigation
```

**When to use this:**
- User explicitly requests sub-agent outputs
- Investigation is complex and raw findings provide additional value
- User wants to review the investigation process, not just the conclusion
- Debugging or refining the investigation methodology

**Sub-agent output format:**
```markdown
# Sub-Agent Investigation: <Topic>

**Assigned Topic:** <Brief description>
**Date:** <YYYY-MM-DD>
**Status:** Complete

---

## Findings

<Raw findings with source references>

---

## Sources Analyzed

| Document | Relevance | Key Information |
|----------|-----------|-----------------|
| <path> | <high/medium/low> | <what was found> |

---

## Notes

<Any observations, gaps, or suggestions for further investigation>
```

---

## Ingest

**Triggered by:** "ingest this", "ingest `<content>`", "add this to refs", "create a digest for"

**Purpose:** Add new content to the knowledge base and produce its digest.

**Uses:** [Dig Deeper](#dig-deeper) workflow when you need to understand topics, judge relevance, or make decisions during ingestion.

**Steps:**

1. **Add to [`refs/`](refs/)**: Add the provided content following the appropriate guideline
   - For repository URLs: add as git submodule at the correct version for the current era
   - For other content types: follow the corresponding guideline

2. **Produce digest**: Create the digest in [`digests/`](digests/) following all digest guidelines
   - Use [Dig Deeper](#dig-deeper) to understand unfamiliar topics or verify era relevance
   - Apply era relevance verification
   - Include proper source links
   - Update [`README.md`](README.md) and [`digests/README.md`](digests/README.md) as needed

3. **Epistemic verification**: Before finalizing the digest, review every factual claim against the [Epistemic Tagging](AGENTS.md#epistemic-tagging) rules:
   - Every claim in the digest must be at **[FACT]** level — directly verifiable from a source file in [`refs/`](refs/)
   - **Do not carry over claims from previous digests without re-verifying** them against the current source. Previous digests may contain errors or outdated information that no longer matches the refs
   - Pay special attention to **names, versions, paths, and identifiers** — these are the most likely to change between versions and the easiest to get wrong by assuming continuity
   - If a claim cannot be verified (e.g., the source file was not read), either verify it now or remove/flag it
   - Check the **build system** (Makefile, CMakeLists, Dockerfile, CI configs) for authoritative values of binary names, image tags, version strings, and build targets — do not infer these from project names, directory names, or prior digests

4. **Verify and summarize**: Double-check all guidelines were applied correctly and provide a brief summary of the result

> **Note:** If it's unclear how to ingest the given content, or if the content type doesn't match any existing guideline, ask the user how to proceed before performing any operation. You may suggest an approach for the user to consider.

---

## Era Transition

**Triggered by:** "bump era", "new era", "update to 0.XX", "transition to 0.XX"

**Purpose:** Transition the knowledge base from one Falco release era to the next.

**Uses:** [Dig Deeper](#dig-deeper) workflow to verify content relevance during the transition.

### Prerequisites

- The new Falco version must be officially released
- You must know the new version number (e.g., 0.44) and its release date

### Step 1: Update Submodules

Update each git submodule in [`refs/`](refs/) to the correct version for the new era:

1. **Core repos with direct version mapping** (check `falco --version` output for the new release):
   - `falco` — tag matching the new Falco version
   - `libs` — tag shown in `falco --version` output
   - `rules` — latest tag for the era (check OCI artifacts or git tags)
   - `falcoctl` — latest release tag within the development cycle
   - `plugins` — latest tags for each plugin within the development cycle
   - `charts` — latest Helm chart release tag within the development cycle

2. **Repos with indirect version mapping**: Update to the latest commit/tag within the new era's development cycle window

3. **Non-versioned repos** (`evolution`, `community`, `.github`, etc.): Update to latest `main`/`master`

For each submodule:
```bash
cd refs/falcosecurity/<repo>
git fetch --tags
git checkout <new-tag-or-commit>
cd -
```

After all submodules are updated, stage the changes:
```bash
git add refs/
```

### Step 2: Update Era References

Update the era version number in these files:

| File | What to update |
|------|----------------|
| [`README.md`](README.md) | "Current Era" heading and description |
| [`AGENTS.md`](AGENTS.md) | "Current Era" section (version, release date, development cycle dates) |
| [`specs/README.md`](specs/README.md) | Era line at the top |

### Step 3: Update Version Verification Table

In [`AGENTS.md`](AGENTS.md), update the "Version Verification by Repository" table with the new version numbers/tags (the example values in parentheses).

### Step 4: Review Digests for Staleness

For each digest in [`digests/`](digests/):

1. **Check if the corresponding ref changed significantly** — compare the old and new submodule commits
2. **Flag stale content** — if a digest references features, APIs, or behaviors that changed in the new era, mark it for update
3. **Update or re-create digests** as needed, following all digest creation guidelines
4. **Verify era relevance** — apply the era relevance checks from [`AGENTS.md`](AGENTS.md)

Use [Dig Deeper](#dig-deeper) to investigate any changes you're uncertain about.

### Step 5: Review Specs

For each spec in [`specs/`](specs/):

1. **Check source file references** — verify that file paths and line numbers still point to the correct code in the new era
2. **Update changed behavior** — if the implementation changed, update the spec to match
3. **Add new features** — if the new era introduced features relevant to a spec's scope, document them
4. **Remove deprecated content** — if features were removed, update accordingly

### Step 6: Review Skills

For each skill in [`skills/`](skills/):

1. **Update container image tags** — e.g., `falcosecurity/falco:0.43.0-jammy` → new version
2. **Verify CLI flags and options** — ensure documented flags still exist
3. **Update version-specific examples** — any hardcoded version references

### Step 7: Update digests/README.md

Update the `digests/README.md` table:
- Adjust sizes if digests changed significantly
- Update the Era column for modified digests

### Step 8: Verify

1. Run `git submodule status` to confirm all submodules are at the expected versions
2. Review all changes with `git diff`
3. Verify no broken links in modified files

### Step 9: Summarize

Provide a summary to the user including:
- New era version and release date
- Number of submodules updated
- Digests flagged as stale or updated
- Specs updated
- Skills updated
- Any issues or items requiring manual follow-up
