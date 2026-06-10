# Getting Started

A quick guide for humans who want to use **Falco Expert** — a knowledge base that turns your AI coding agent into a [Falco](https://falco.org) expert.

What you get:

- The [`falco-expert`](agents/falco-expert.md) agent — answers Falco questions with citations into the pinned sources, era-aware (currently Falco 0.44)
- Five [skills](skills/) — rule authoring, CLI verification, development, issue/PR triage, and PR review
- The knowledge base itself — [`digests/`](digests/), [`specs/`](specs/), and [`refs/`](refs/) (the falcosecurity repositories pinned at the versions of the current era)

## 1. Clone and initialize

```bash
git clone https://github.com/leogr/falco-expert.git
cd falco-expert
make init
```

`make init` fetches the [`refs/`](refs/) git submodules — the falcosecurity repositories pinned to the current era. This is a large download, but it is what allows the agent to verify every claim against the actual sources instead of relying on its training data.

## 2. Install the agent and skills

Start your AI agent (e.g., `claude`) in the repository root and ask it:

> Install the falco-expert agent and all the skills locally, as described in the README.

The agent will create symlinks into `~/.claude/agents` and `~/.claude/skills`, and suggest the permissions entry that lets it read the knowledge base without prompting. If you prefer to do it by hand, follow [Installing Skills for Claude Code](README.md#installing-skills-for-claude-code) and [Installing the Agent for Claude Code](README.md#installing-the-agent-for-claude-code).

> **Note:** The installation steps above are Claude Code-specific. Other agents that support the `AGENTS.md` convention (e.g., Codex) pick up the repository guidelines automatically when working from the repository root — no installation needed, but the agent and skills won't be available outside it.

## 3. Update

Because the agent and skills are installed as symlinks, updating is just:

```bash
git pull
make init
```

`git pull` refreshes the knowledge base and everything symlinked from it; `make init` re-syncs the [`refs/`](refs/) submodules when the era changes (e.g., after a new Falco release). No reinstallation is needed.

## Two ways to use it

### From the falco-expert root

```bash
cd falco-expert
claude
```

Working from the repository root gives the agent the full context: the working guidelines ([`AGENTS.md`](AGENTS.md)) are loaded automatically, the knowledge base index ([`README.md`](README.md)) is at hand, and reports are written to [`output/`](output/) without prompting.

**Use this when** the knowledge base is the primary context: asking Falco questions, exploring how something works, authoring and validating rules, triaging issues, or reviewing a PR that you haven't checked out locally.

### From a local clone of a falcosecurity repository

```bash
cd ~/code/falcosecurity/libs   # your working clone, your branch
claude
```

The installed `falco-expert` agent and skills are available globally, so you can invoke them from any directory. The agent reaches the knowledge base through the symlinks, while your repository clone — including uncommitted changes and checked-out branches — is the working context.

**Use this when** the code you are changing is the primary context: developing or debugging in `libs`/`falco`/`rules`, reviewing a PR branch you have checked out, or tuning rules files that live in your own repository.

**Differences to be aware of:**

| | From falco-expert root | From a falcosecurity clone |
|---|---|---|
| Guidelines ([`AGENTS.md`](AGENTS.md)) | Loaded automatically | Loaded by the agent via symlink |
| Working tree | The pinned, read-only era sources | Your branch, including local changes |
| Output reports | [`output/`](output/), no prompt | The agent asks you where to write |
| Best for | Knowledge-driven tasks | Code-change-driven tasks |

## Example prompts

- *"What changed in Falco 0.44? Is there anything I must do before upgrading?"*
- *"Explain how the modern eBPF driver works. Cite the sources."*
- *"Dig deeper into how the rule engine compiles conditions and applies exceptions."*
- *"Write a Falco rule that detects a shell spawned in a container reading /etc/shadow, then validate it."*
- *"Which fields can I use in a rule condition to match the container image? Verify against the actual CLI."*
- *"Triage the most recent open issues in falcosecurity/falco."*
- *"Review PR falcosecurity/libs#2863."* (from the knowledge base root, or from your `libs` clone with the branch checked out)

### What you get back: the report

Phrases like *"dig deeper into..."* trigger the [Dig Deeper](WORKFLOWS.md#dig-deeper) workflow, the knowledge base's investigation procedure. Besides the answer in the conversation, it produces a Markdown report saved as `YYYY-MM-DD-<topic>.md` — in [`output/`](output/) when working from the falco-expert root (the directory is gitignored, so reports never pollute the repository), or in a location you choose when working from another repository.

The report is built to be shared and trusted on its own:

- **Every statement carries a citation** — absolute GitHub URLs pointing at the actual source files, with line numbers for code, so references stay valid outside the repository
- **Findings are graded by how well they are grounded** ([Epistemic Tagging](AGENTS.md#epistemic-tagging)): conclusions rest only on verified facts, interpretations are hedged, and anything unverified is segregated into its own section instead of being mixed with established content
- **Missing information is stated explicitly** — if the knowledge base doesn't cover something, the report says so rather than filling the gap with plausible-sounding guesses

The other skills follow the same pattern: triage and PR review runs also produce report files (and ready-to-run scripts for the actions they suggest), all under the same output directory.

## What to expect

This project deliberately trades speed for accuracy. The agent re-reads the guidelines, consults the knowledge base index before searching, verifies claims against the pinned sources, and tags findings by how well they are grounded (see [Epistemic Tagging](AGENTS.md#epistemic-tagging)). Expect more tool calls, more tokens, and slower turns than a plain chat — and answers you can trust and verify, with citations down to file and line.
