---
name: falco-yolo-team
description: Work on Falco as part of a yoloctl agent team (coordinator, architect, dev, DevOps/QA) that shares the falco-expert knowledge base, a managed AIRC chat and a common .falco-team/ workspace. Covers roles, tracking, isolated worktrees of falcosecurity repositories, review, QA in a privileged box and the gated hand-off to upstream. Use when assigned a team role; use the other falco-expert skills for the specialist work itself.
metadata:
  falco-version: "0.45"
---

# Falco yolo team

This skill supplies team roles, workflow and hand-offs. It grants no runtime,
GitHub or chat authority. The falco-expert [AGENTS.md](../../AGENTS.md) and
[README.md](../../README.md) govern knowledge, epistemic tagging, era rules,
output paths and doc checks: load them first, every session and after every
compaction. Resolve this file's links from its physical location
(`<falco-expert>/skills/falco-yolo-team/`), not from a discovery symlink.

## Enter the task

1. Take the role the user or coordinator assigned. If none was assigned, ask
   the coordinator (or the user, when you are the coordinator). Load only that
   role's reference:

   | Role | Responsible for |
   |---|---|
   | [Coordinator](references/coordinator.md) | Boxes, chat, tracking, dispatch, stage progression, the user's decisions |
   | [Architect](references/architect.md) | Plans, challenge, code review, QA strategy |
   | [Dev](references/dev.md) | Implementing an accepted plan in an isolated worktree |
   | [DevOps / QA](references/devops.md) | Builds and tests in the privileged box, integration, upstream hand-off preparation |
   | [Publisher](references/publisher.md) | `gh` only: executing approved public GitHub actions with the user's credential |
   | [Dependabot publisher](references/dependabot.md) | `gh-dependabot` only: clearing Dependabot PR backlogs with `falco-dependabot`, nothing else |

2. Read the ticket and its plan in `.falco-team/tasks/<ticket>/`. Establish
   scope, owner, planning architect, next action and holds. A newer explicit
   user direction supersedes an older dispatch.
3. Install the skills once per account if missing:
   `bash skills/falco-yolo-team/scripts/install-skills.sh --skills-dir DIR`
   (Claude: `~/.claude/skills`; Codex: `~/.codex/skills`). It symlinks this
   skill and every falco-expert skill and never replaces an existing entry.

## Specialist skills by role

Use the existing falco-expert skills for the substance of the work; this skill
only routes it.

| Need | Skill or workflow |
|---|---|
| Facts about Falco behaviour, history, ownership | [Dig Deeper](../../WORKFLOWS.md#dig-deeper) |
| Choosing work, project health | [`falco-maintainer`](../falco-maintainer/SKILL.md) (coordinator) |
| Issue/PR backlog analysis | [`falco-triage`](../falco-triage/SKILL.md) |
| Code review of a candidate or upstream PR | [`falco-reviewer`](../falco-reviewer/SKILL.md) (architect) |
| Building, unit/integration tests, debugging | [`falco-dev`](../falco-dev/SKILL.md) (dev source work; DevOps runs Docker modes) |
| Rules authoring and tuning | [`falco-rules-author`](../falco-rules-author/SKILL.md) |
| CLI validation and introspection | [`falco-cli`](../falco-cli/SKILL.md) |
| Dependabot backlogs, releases | [`falco-dependabot`](../falco-dependabot/SKILL.md), [`falco-release`](../falco-release/SKILL.md): only on explicit user direction |

## Shared workspace

The canonical team directory is `.falco-team/` at the falco-expert root
(Git-ignored, the same path in every box). Do not create a competing one in a
worktree.

```text
.falco-team/
├── PROGRESS.md        # tickets in Plan → Build → Review → QA → Merge (coordinator-owned)
├── BOARD.md           # everything else, importance/urgency quadrants, closed outcomes
├── CHANNELS.md        # chat channels and their purposes
├── DIRECTIVES.md      # standing user directives awaiting consolidation
├── repos/<repo>/      # one clone per falcosecurity repository (main checkout, never edited)
├── worktrees/<ticket>-<box>/   # one git worktree per dev assignment
└── tasks/<ticket>/    # plan, notes, reviews, QA logs and evidence
```

- [`refs/`](../../refs/) submodules are pinned to the era and are read-only.
  Never build in or edit them; clone into `.falco-team/repos/` instead.
- Reports written by specialist skills go to `OUTPUT_DIR` as AGENTS.md
  resolves it (`<falco-expert>/output/`); link them from the ticket folder.
- Ticket IDs are stable `<type>-<topic>` slugs using Conventional Commit types
  (for example `fix-k8saudit-nil-deref`). Commits use
  `<type>(<scope>): <summary>`.
- **Commit identity:** every commit in any repository uses the author identity
  and DCO `Signed-off-by` the user specifies, and carries no agent co-author
  trailer (no `Co-Authored-By` for Claude, Codex or any other agent). Check
  commits and patch files before handing them off; never force-push only to
  fix a trailer after a push without asking.
- Tag significant claims in plans, notes and reviews (`[FACT]` with source,
  `[DERIVED]`, `[INFERENCE]`, `[ASSUMPTION]`), as AGENTS.md defines. An
  assumption never drives implementation, acceptance or a public action.

## Public actions

Everything that leaves the space is the user's to approve, item by item:
pushes, forks, branches, PRs, comments, reviews, labels, Prow commands
(`/approve`, `/lgtm`, `/hold`), tags and releases. falcosecurity Prow treats an
approving review as LGTM, so an approval can merge. The team prepares the exact
artifact (branch, commit, PR text, review body, command) and the coordinator
asks for a literal go. A go covers only the named item.

Only the `gh` box ([publisher](references/publisher.md)) and the
`gh-dependabot` box ([Dependabot publisher](references/dependabot.md)) hold
the user's GitHub write credential and execute public actions; no other box
has, asks for or handles it. Dependabot backlogs go to `gh-dependabot`;
every other public action goes to `gh`. After the go, the coordinator
dispatches the item with the go's message reference and the artifact identity
(commit hash or file sha256). If the artifact changes after the go, the go
lapses: show the user the new version and get a new go. Changes to falco-expert
itself are integrated locally on `main` with `make check-docs`; pushing it is
the user's.

## Chat and hand-offs

Use the installed AIRC skill with its harness recipe, client `space`, channel
`#space` unless assigned another. Every team member, the coordinator
included, joins the chat.

**Listening (user directive):** the coordinator is the only member that
listens to all messages (wake `messages`). Every other role wakes on
`mentions` only (an `@box` address, a reply to its message, a DM, `@all` or
`@here`). Never switch a worker to `messages` or `all`. Keep exactly one
delivery consumer or waiter per member.

- Workers talk to the user through the coordinator. Answer the user directly
  only when the user addresses you by name.
- In chat, reports and notes, write GitHub issue and PR links as
  `[repo#N](url)`, for example
  [falco#4061](https://github.com/falcosecurity/falco/pull/4061). Text posted
  on GitHub follows the [publisher](references/publisher.md) link rules
  instead.
- Address dispatches with `@box`. One dispatch or receipt per step, naming the
  ticket, candidate, result, evidence path, limits and next owner, for example
  `DONE @coordinator fix-k8saudit-nil-deref build cand=ab12cd3 checks=PASS evidence=.falco-team/tasks/fix-k8saudit-nil-deref/build.md next=@fable-architect`.
  No acknowledgement chains, no pasted reports.
- Put every command the user must run in a fenced code block; several host
  steps become one script.
- Whatever you post in chat, do not repeat it in your private session output.
  When everything went to chat, the private output is `←`.
- Before a compaction or session change, save open tickets, holds and the last
  handled message reference in the ticket folder; afterwards reconnect if
  needed and recover bounded chat history.

## Cleanup boundary

No agent runs `rm` with a wildcard, even in its own folders. Each run writes a
new folder (`run-1`, `run-2`, …). Authorized cleanup uses exact paths after
checking ownership, retained evidence and live consumers. Helper/subagent
briefs forbid deletion. Remove a finished worktree with `git worktree remove
<exact path>` from its clone; never `git worktree prune` someone else's.
