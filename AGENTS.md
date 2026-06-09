# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

---

## ⚠️ MANDATORY: Read This First

> **Note:** [`CLAUDE.md`](CLAUDE.md) is a symlink to this file. Claude Code users get these guidelines auto-loaded into the system prompt. Other AI agents must read this file explicitly.

**CRITICAL REQUIREMENT**: You MUST have [`AGENTS.md`](AGENTS.md) and [`README.md`](README.md) loaded in your context **every time** you:
- Start a new conversation or session
- Begin any new operation or task
- Resume after context compaction
- Return to this repository after working elsewhere

**Why this matters**: This knowledge base has specific conventions, era-based versioning, and strict guidelines that govern all operations. Working without these guidelines loaded in your context will lead to errors, inconsistencies, and wasted effort.

**How to comply**:
1. Ensure [`AGENTS.md`](AGENTS.md) is in your context (this file) — contains all working guidelines
2. Read [`README.md`](README.md) — contains the Table of Contents and current era info
3. Only then proceed with your task

**Do not skip this step.** Even if you think you remember the guidelines, re-read them. The guidelines may have been updated, and context compaction may have removed critical details.

---

## Project Overview

**Falco Expert** is a knowledge base for AI Agents focused on [Falco](https://falco.org), the Cloud Native Runtime Security tool (part of CNCF).

### Purpose

This repository serves as a centralized source of Falco knowledge for AI agents, enabling:
- Creation of Falco-focused AI agent skills
- Building dedicated Falco expert AI agents
- Assisting with Falco evolutive maintenance
- Providing an index for AI agents to retrieve Falco-related information
- Supporting evolution, refactoring, and development of the Falco codebase

## Primary Data Source

**https://github.com/falcosecurity** is the Falco project's official GitHub organization, hosting all the codebase and serving as the **ultimate source of truth** for all information.

### Organization Structure

The [`evolution`](refs/falcosecurity/evolution/) repository is the canonical source for understanding the falcosecurity organization:
- [`repositories.yaml`](refs/falcosecurity/evolution/repositories.yaml) - Master index of all 34+ repositories with scope and status
- [`maintainers.yaml`](refs/falcosecurity/evolution/maintainers.yaml) - Registry of all maintainers
- [`GOVERNANCE.md`](refs/falcosecurity/evolution/GOVERNANCE.md) - Project governance model

**Repository Scopes**:
- **Core**: Essential for building, installing, running, documenting, or using Falco (e.g., `falco`, `libs`, `rules`, `falcoctl`)
- **Ecosystem**: Optional extensions and integrations (e.g., `falcosidekick`, `driverkit`, `falco-talon`)
- **Infra**: Infrastructure support and testing (e.g., `test-infra`, `kernel-crawler`)
- **Special**: Unique purposes (e.g., `evolution`, `community`, `.github`)

**Repository Statuses**: Stable, Incubating, Sandbox, Deprecated

See [`digests/falcosecurity/evolution.md`](digests/falcosecurity/evolution.md) for the complete repository map.

## Era/Versioning System

Information in this repo is organized by Falco version "eras". The Falco version indicates the era of the collected information.

### Current Era: 0.44

- **Released**: May 26, 2026
- **Development cycle**: January 28, 2026 → May 26, 2026
- Patch versions (e.g., 0.44.x) belong to the same era

### Release Schedule

Falco typically releases 3 times per year:
- Last Monday of January
- Last Monday of May
- Last Monday of September

(Plus patch/hotfix releases in between. Actual dates may vary due to contingencies.)

### Component Version Mapping

- **Direct mapping**: Components shown in `falco --version` have 1-1 relationship with Falco version
- **Indirect mapping**: Ecosystem components without direct version mapping use development cycle time window
- Some component versions may span multiple Falco eras
- Some components may be specific to patch versions (still belong to corresponding era)

### Version Verification by Repository

**Universal method**: Run `git submodule status` from the repo root to see the pinned commit and tag for every submodule.

How to verify the era/version for each repository in [`refs/`](refs/):

| Repository | Verification method |
|------------|---------------------|
| `falco` | Git tag (e.g., `0.44.0`). Also: [`cmake/modules/falco-version.cmake`](refs/falcosecurity/falco/cmake/modules/falco-version.cmake) |
| `libs` | Git tag (e.g., `0.25.2`). Also: [`cmake/modules/versions.cmake`](refs/falcosecurity/libs/cmake/modules/versions.cmake) |
| `rules` | Git tag (e.g., `falco-incubating-rules-6.0.1`). Also: [`registry.yaml`](refs/falcosecurity/rules/registry.yaml) |
| `charts` | Git tag (e.g., `falco-9.0.0`). Also: [`charts/falco/Chart.yaml`](refs/falcosecurity/charts/charts/falco/Chart.yaml) → `version` and `appVersion` |
| `falcoctl` | Git tag (e.g., `v0.13.0`) |
| `plugins` | Git tag per plugin (e.g., `plugins/container/v0.7.1`). Also: individual plugin `CMakeLists.txt` or `go.mod` |
| `falco-website` | Check [`config/_default/versions/params.yaml`](refs/falcosecurity/falco-website/config/_default/versions/params.yaml) → `version` field |
| `evolution` | Not version-specific; governance applies to current era |
| Other repos | Git tag or branch shown by `git submodule status`; use development cycle time window for indirect mapping |

### Mixed-Era Content

Some repositories (e.g., `falco-website`) contain content from multiple eras:
- **Current era content**: Directly applicable to the current era (0.44)
- **Previous era content**: May be useful for historical context but does not necessarily apply to the current era

When creating digests and specs, judge each piece of content:
- Clearly mark content that is era-specific
- For documentation, assume it applies to the current era unless stated otherwise
- For blog posts, note the Falco version they reference
- Historical content may describe features/behaviors that have changed

## Repository Structure

### [`refs/`](refs/)
Data sources used as input to construct knowledge.
- Contains git submodules pointing to correct versions for the current era
- **Once initialized, do not modify until era changes**
- Primary source for collecting information; contents are referenced elsewhere
- **`git submodule status`** (from the repo root) is the canonical source for commit, branch, and date metadata — do not hand-maintain per-repo metadata in READMEs

### [`digests/`](digests/)
AI-optimized summaries of contents in [`refs/`](refs/).
- 1-1 relationship with corresponding ref
- Should be comprehensive enough to avoid information loss
- Should fit within LLM context windows
- Can be updated as needed (these are like persistent memories)
- **Must include detailed source references** (like Wikipedia citations)
- Code references must link to file and relevant line numbers
- Multi-file digests go in subdirectories with `README.md` as navigation hub

### [`specs/`](specs/)
Technical specifications derived from analyzing [`refs/`](refs/) and [`digests/`](digests/).
- Formal technical specifications and/or PRDs (Product Requirements Documents)
- Includes functional and non-functional requirements
- **Must include detailed source references** (like Wikipedia citations)
- Code references must link to file and relevant line numbers
- Designed to be indexable, avoid redundancies, and support future code changes
- Prefer Open Source style for technical specifications

### [`skills/`](skills/)
Documents following the [agentskills.io](https://agentskills.io/) specification.
- **Do not create new skills without explicit user request**
- Existing skills can be updated when underlying information changes

#### Available Skills

| Skill | Purpose |
|-------|---------|
| [`falco-cli`](skills/falco-cli/SKILL.md) | Use the Falco CLI for validation, introspection, binary analysis, and knowledge verification |
| [`falco-dev`](skills/falco-dev/SKILL.md) | Develop, build, test, and debug Falco core components using a devcontainer |
| [`falco-rules-author`](skills/falco-rules-author/SKILL.md) | Author, validate, test, and iteratively tune Falco detection rules with Docker-based feedback loops |
| [`falco-triage`](skills/falco-triage/SKILL.md) | Triage GitHub issues and PRs across falcosecurity repositories with knowledge-base-backed analysis |
| [`falco-reviewer`](skills/falco-reviewer/SKILL.md) | Review PRs as a ghost writer for Falco maintainers, with security review and breaking change analysis |

**Using `falco-cli`**: Agents working with this repository can use the `falco-cli` skill to:
- Validate Falco rules files (`falco -V`)
- List available fields for rule conditions (`falco --list`)
- Inspect plugins and their capabilities (`falco --list-plugins`, `falco --plugin-info`)
- Analyze binary dependencies (GLIBC, shared libraries)
- Generate binary reports for documentation
- Verify Falco knowledge claims against the actual CLI output
- Work with different Falco versions via downloaded binaries or container images

To use, read [`skills/falco-cli/SKILL.md`](skills/falco-cli/SKILL.md) for complete instructions.

**Using `falco-dev`**: Agents working with Falco source code can use the `falco-dev` skill to:
- Build Falco and libs from source in a reproducible devcontainer
- Run unit tests, integration tests, and the `falcosecurity/testing` suite
- Debug with gdb, valgrind, and `sinsp-example`
- Manage multi-repo workspaces (`falco`, `libs`, `rules`, `testing`)
- Use graduated privilege modes (safe, least-privilege, privileged) depending on task requirements

To use, read [`skills/falco-dev/SKILL.md`](skills/falco-dev/SKILL.md) for complete instructions.

**Using `falco-triage`**: Agents can use the `falco-triage` skill to:
- Fetch and analyze open issues and PRs across falcosecurity repositories
- Use the knowledge base to understand technical context and detect misunderstandings
- Categorize issues by kind, priority, and component area
- Detect duplicates, related issues, and issues already addressed by merged PRs
- Generate triage reports with ready-to-run `gh` commands for maintainer review
- Support tiered (quick scan + selective deep dive) and deep-dive-all analysis modes

To use, read [`skills/falco-triage/SKILL.md`](skills/falco-triage/SKILL.md) for complete instructions.

**Using `falco-reviewer`**: Agents can use the `falco-reviewer` skill to:
- Review PRs across falcosecurity repositories as a ghost writer for Falco maintainers
- Perform code review, security review, and breaking change analysis
- Use the Dig Deeper workflow for knowledge-base-backed technical context
- Generate review reports stored in `OUTPUT_DIR`
- Generate ready-to-run shell scripts that publish pending (draft) GitHub reviews

To use, read [`skills/falco-reviewer/SKILL.md`](skills/falco-reviewer/SKILL.md) for complete instructions.

### [`output/`](output/)

Generated reports, analysis results, and other output artifacts.

#### Output Path Resolution Protocol

Every workflow, skill, and agent that writes output files MUST resolve the output directory using this protocol. Resolve it **once per session**, store it as `OUTPUT_DIR` (an absolute path), and reuse it for all subsequent writes in the same session.

**Step 1: Detect whether the current working directory is inside the falco-expert repository.**

Check if the git remote URL contains `falco-expert`:
```bash
git remote get-url origin 2>/dev/null | grep -q "falco-expert"
```

If the check matches, inform the user that you detected the falco-expert repository (e.g., "Detected falco-expert repository.").

**Step 2: Resolve the output path.**

- **If inside the falco-expert repository**: Use `<repo-root>/output/`. No user prompt needed.
- **If outside the falco-expert repository**: You **MUST** prompt the user **once** with these options (do NOT skip this prompt):
  1. `<current-project>/output/` — write output alongside the user's project
  2. A unique temporary directory — create with `mktemp -d /tmp/falco-expert-output-XXXXXXXX`
  3. A custom path provided by the user

Store the resolved absolute path as `OUTPUT_DIR`. Inform the user of the chosen path.

**Step 3: Reuse for the session.**

All subsequent output writes in the same session use `OUTPUT_DIR` without re-prompting.

#### Sub-Agent Output Path Propagation

When spawning sub-agents, **always pass `OUTPUT_DIR` as an explicit absolute path** in the sub-agent prompt. Sub-agents MUST NOT resolve the output path themselves. Example:

```
**Output Directory:** /absolute/path/to/output
All output files must be written to this directory. Do not resolve the output path yourself.
```

#### File Naming Conventions

- **Single-file tasks**: `OUTPUT_DIR/YYYY-MM-DD-<descriptive-name>.md`
- **Multi-file tasks**: Create a subdirectory with the same date prefix, and prefix each file inside using the same convention:
  ```
  OUTPUT_DIR/YYYY-MM-DD-<descriptive-name>/
  ├── YYYY-MM-DD-<descriptive-name>-report.md
  ├── YYYY-MM-DD-<descriptive-name>-context.md
  └── YYYY-MM-DD-<descriptive-name>-script.sh
  ```

- `YYYY-MM-DD` is always today's date
- This ensures chronological ordering and traceability, and each file remains self-identifying when moved or shared outside the subdirectory
- Example single file: `2026-02-23-scap-event-decode-params-security-report-verification.md`
- Example subdirectory: `2026-03-09-review-libs-pr-2863/`

#### File Write Safety Rule

**Never write to any path unless the user has explicitly authorized it.** The Output Path Resolution Protocol obtains that authorization:
- **Inside the falco-expert repository**: `output/` is the established default — using it constitutes implicit authorization.
- **Outside the falco-expert repository**: The user explicitly chooses the path during the prompt.

Once `OUTPUT_DIR` is resolved, writes are permitted **to that path only**. All other paths remain off-limits unless the user grants separate authorization.

### [`README.md`](README.md)
Repository description with Table of Contents.
- **Must be kept in sync** with repository contents
- Helps both humans and AIs find information quickly

## Working Guidelines

### ⚠️ MANDATORY: Verify Every Conclusion Against Actual Code
Never claim something is a bug, dead code, incorrect, or behaves a certain way based on assumptions or general knowledge. Always read the actual definitions, implementations, and call sites in the codebase first. Re-verify conclusions before presenting them — if you can't point to the specific code that supports your claim, don't make the claim. When delegating to subagents, explicitly instruct them to read all relevant definitions (macros, types, wrappers, headers) and trace through actual call chains rather than assuming behavior.

### Epistemic Tagging

Every claim, finding, or conclusion produced during reasoning, investigation, or review **must** be tagged with one of the following epistemic categories. Tags are UPPERCASE in square brackets for visibility.

#### Categories

| Tag | Definition | Can drive conclusions? |
|-----|-----------|----------------------|
| **[FACT]** | Directly verified from a citable source (code at file:line, documentation, knowledge base). The agent can point to exactly where it read this. | Yes |
| **[DERIVED]** | Logically and necessarily follows from [FACT]s. If the facts are true, this must be true. The full reasoning chain is explicit and every step is verifiable. | Yes |
| **[INFERENCE]** | Probably follows from facts but involves interpretation, pattern recognition, or incomplete information. Grounded in evidence but uncertain. | Suggestions only, flagged as uncertain |
| **[ASSUMPTION]** | Not grounded in verified sources. Includes LLM prior knowledge that has not been verified against current sources in this repository. | Never |

#### Core Rules

1. **Only [FACT] and [DERIVED] can support definitive conclusions.** If a reasoning chain includes an [ASSUMPTION] as a premise, the conclusion is at best an [INFERENCE] and cannot be stated as certain.
2. **[INFERENCE] can support suggestions**, but they must be explicitly flagged as uncertain (e.g., hedging language, question form, or an explicit [INFERENCE] marker in the output).
3. **[ASSUMPTION] is for transparency only.** It is reported so humans can judge, but it never drives conclusions, suggestions, or actions. An [ASSUMPTION] presented as a conclusion is a defect.
4. **Tag during reasoning, respect in output.** Tags are used during internal analysis. Final outputs (reports, review comments, etc.) may strip the tag syntax for readability, but the epistemic grounding they enforce must be reflected in how claims are presented — definitive language for [FACT]/[DERIVED], hedged language for [INFERENCE], and explicit "unverified" markers for [ASSUMPTION].
5. **Promote, don't blur.** When an [ASSUMPTION] or [INFERENCE] is later verified against a source, promote it to [FACT] and record the source. Never leave a verified claim at a lower tier.

#### Example

```
[FACT] Function foo() calls bar() at libs/engine/foo.cpp:142
[FACT] bar() takes a non-const reference to state (libs/engine/bar.h:30)
[DERIVED] Therefore foo() can mutate state through bar()
[INFERENCE] Given the naming convention, this mutation is probably intentional
[ASSUMPTION] The caller likely expects state to be unchanged (not verified)
```

In this chain, the first three items can support a conclusion. The [INFERENCE] can support a suggestion ("this looks intentional, but worth confirming"). The [ASSUMPTION] cannot support any claim — it can only be reported as an open question.

#### Workflow and Skill Integration

Each workflow and skill defines **where and how** epistemic tags are used in its specific context:
- **[Dig Deeper](WORKFLOWS.md#dig-deeper)**: Sub-agents tag every finding; the report separates verified from unverified content
- **[Falco Reviewer](skills/falco-reviewer/SKILL.md)**: Only [FACT]+[DERIVED] backed findings become review comments; [INFERENCE] is hedged; [ASSUMPTION] is discarded or reported transparently
- **[Falco Triage](skills/falco-triage/SKILL.md)**: Destructive actions (`/close`, `/triage duplicate`) require [FACT]+[DERIVED]; non-destructive labels require [FACT]+[INFERENCE]; suggested comment answers must be KB-grounded
- Other workflows and skills should apply the core rules above to their outputs

### Markdown Links
Always convert paths referenced in `.md` files to clickable links. The project must be easily navigable for humans.
- Use a clickable link like [`refs/`](refs/) instead of plain code formatting
- For cross-folder references, use a relative path from the current file. From a nested file, that usually means linking to `../refs/`
- **This applies everywhere**: inline text, tables, "Source:" references, lists
- Never leave paths as backticked code only - always make them clickable links
- In tables, path cells should contain links, not plain code-formatted text
- **Link direction is one-way**: digests must **not** link to [`specs/`](specs/). Specs are derived from digests, so [`specs/`](specs/) link to [`digests/`](digests/) and [`refs/`](refs/), never the reverse — linking a digest to a spec would invert that dependency. Digests may link to sibling digests and to [`refs/`](refs/).

### Digest Creation

When creating or updating digests, follow these principles:

1. **Understand architecture and design**: Before summarizing, deeply analyze the component's architecture, design patterns, and intended use cases
   - Read configuration files, templates, and examples to understand how components work together
   - Use pre-existing knowledge to contextualize what the component does and why
   - Identify the key decisions users must make (e.g., deployment modes, configuration options)
   - Document the relationships between components and their dependencies

2. **Include detailed source references (like Wikipedia citations)**: Every factual claim must be verifiable
   - Every significant statement should be traceable to a source file in [`refs/`](refs/)
   - Link to specific files with line numbers when referencing code or configuration
   - Reference example files (e.g., `values-*.yaml`) when documenting use cases
   - Use formats like:
     ```text
     **Source:** [filename](relative/path/to/file.ext)
     [source](path)
     **Source:** [file.h:42-50](path/to/file.h)
     ```
   - This enables verification, prevents hallucinations, and helps readers dive deeper

3. **Add a Sources section** at the end of each digest listing key reference files:
   ```markdown
   ## Sources

   | Topic | Source File |
   |-------|-------------|
   | Event types | [`ppm_events_public.h`](../../../refs/.../ppm_events_public.h) |
   | Plugin API | [`plugin_api.h`](../../../refs/.../plugin_api.h) |
   ```

4. **Link back to source files** for important content readers may want to access in full:
   - Blog posts, release announcements, documentation pages
   - Use relative paths from the digest file location
   - **Link to specific files**, not directories (e.g., link to `_index.md` not just the folder)
   - Example from the repo root: [Falco 0.43.0](refs/falcosecurity/falco-website/content/en/blog/falco-0-43.0/index.md)
   - For "Source:" references, follow the same syntax pattern above with a relative path from the current file

### Date Discrepancies
When source materials contain conflicting dates (e.g., blog post date vs. official release date):
- Note both dates explicitly in the digest
- Clarify what each date represents (e.g., "Blog published: Jan 26, Official release: Jan 28")
- This prevents confusion and demonstrates careful source verification

### Adding References
When adding code references in specs:
1. Include the data structure or code snippet
2. Always add a link to the original source file with line numbers
3. This enables verification and traceability

### Updating Content
- [`refs/`](refs/): Do not modify within same era
- [`digests/`](digests/): Update freely as needed
- [`specs/`](specs/): Update and refine, maintain references
- [`skills/`](skills/): Update existing only; ask before creating new
- [`README.md`](README.md): Keep ToC in sync with all changes
- **After modifying any markdown files**, run `make check-docs` to validate links, refs paths, and index consistency. Fix any reported issues before considering the change complete. Individual checks are also available: `make check-md-links`, `make check-refs-paths`, `make check-index-drift`.

### Era Relevance Verification

When creating or updating digests, **always verify content is relevant for the current era**:

1. **Check for deprecated features**: Upstream sources may reference deprecated CLI flags, config options, or APIs that no longer exist in the current era
   - Example: `-A` flag was removed in 0.39, replaced by `base_syscalls.all` config

2. **Update terminology**: Use current-era equivalents for deprecated features
   - Don't just copy outdated references from upstream docs

3. **Add notes for stale upstream content**: When upstream documentation references deprecated features, add a note:
   ```markdown
   > Note: Upstream docs may still reference the deprecated `--old-flag`, removed in Falco X.YZ.
   ```

4. **Version annotations are acceptable**: Noting when features were introduced provides useful historical context
   - ✅ "Configuration merging (since 0.38)" - factual context
   - ✅ "Modern eBPF (default since 0.38)" - shows feature maturity
   - ❌ "You can now use X since 0.36" - implies newness for established features
   - Avoid "newness" language (now, new, starting from) for features that have been standard for multiple releases

5. **Verify against current documentation**: Cross-reference with [`digests/falcosecurity/falco-website/`](digests/falcosecurity/falco-website/) to confirm current-era behavior

6. **Scope vs limitations**: Frame architectural boundaries as "scope considerations" rather than "limitations" from old proposals

### Source Verification
All information in specs must be traceable to sources in [`refs/`](refs/). This prevents hallucinations and ensures accuracy.

### ⚠️ MANDATORY: Re-read README.md Before Any Search or Lookup

**CRITICAL**: You MUST re-read [`README.md`](README.md) before performing any search or lookup operation in this knowledge base. [`README.md`](README.md) contains the **Table of Contents** of all files in this repository and serves as the primary index.

**This applies every time you need to**:
- Find which file covers a given topic
- Investigate a question (e.g., during a Dig Deeper workflow)
- Locate digests, specs, or refs for a specific component
- Determine where information might be stored

**Why this matters**: Without the ToC in context, you will miss relevant files, search blindly, or rely on stale memory of the repository structure. The ToC is the authoritative map — always consult it first.

**Do NOT rely on memory of the repository structure. Always re-read [`README.md`](README.md) before searching.**

## Workflows

Workflows are predefined procedures for common operations. Full workflow definitions are in [`WORKFLOWS.md`](WORKFLOWS.md).

### ⚠️ MANDATORY: Re-read WORKFLOWS.md Before Every Workflow Execution

**CRITICAL**: You MUST re-read [`WORKFLOWS.md`](WORKFLOWS.md) **every time** before executing a workflow — even if you believe you remember the steps. This is non-negotiable because:
- Workflow definitions may have been updated since your last read
- Context compaction may have removed workflow details from your context
- Partial recall leads to skipped steps (e.g., missing era relevance checks)

**Do NOT rely on memory or summaries of workflow steps. Always read the source.**

### Available Workflows

| Workflow | Trigger Phrases | Purpose |
|----------|-----------------|---------|
| [Dig Deeper](WORKFLOWS.md#dig-deeper) | "dig deeper", "tell me about", "explain", "what is" | Extract factual information from the knowledge base |
| [Ingest](WORKFLOWS.md#ingest) | "ingest this", "ingest `<content>`" | Add new content to the knowledge base |
| [Era Transition](WORKFLOWS.md#era-transition) | "bump era", "new era", "update to 0.XX" | Transition the knowledge base to a new Falco release era |

### Detecting Workflow Requests

**When to trigger a workflow**: Look for these patterns in user messages:

1. **Explicit workflow name**: User mentions the workflow by name (e.g., "run the ingest workflow", "dig deeper")
2. **Trigger phrases**: User's request matches a workflow's trigger phrases (see table above)
3. **Intent match**: User describes an action that clearly maps to a workflow's purpose
   - Example: "add this repo to the knowledge base" → Ingest workflow
   - Example: "what is the modern eBPF driver?" → Dig Deeper workflow

**When a workflow is detected**:
1. **Re-read [`WORKFLOWS.md`](WORKFLOWS.md)** to load the full, current workflow steps (MANDATORY — see above)
2. Follow the workflow steps **exactly** as documented — do not skip any step
3. If unclear whether a workflow applies, ask the user before proceeding

### Internal Workflow Usage

Workflows can invoke other workflows. When performing any operation that requires:
- Understanding Falco concepts or topics
- Judging the relevance of content
- Making decisions based on Falco knowledge
- Verifying statements or claims

**Use the [Dig Deeper](WORKFLOWS.md#dig-deeper) workflow** to gather accurate, factual information from the knowledge base before proceeding.

**The same re-read requirement applies**: re-read [`WORKFLOWS.md`](WORKFLOWS.md) before executing any internally-invoked workflow.
