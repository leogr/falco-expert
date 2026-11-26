# Team setup

The coordinator's recipe for shaping, enrolling and onboarding boxes. Check
each command's `--help` on the running build; the installed
`yolo-box-operator` and AIRC skills are authoritative for their commands.

## Default roster

Use this lean roster unless the user overrides it. Names follow `model-role`;
the user can rename. It sets roles and intended model/effort, not authority.

| Role | Box | Agent | Model | Effort | Extra grants |
|---|---|---|---|---|---|
| Coordinator | (current box) | claude | claude-opus-5-5 | medium/high | `--operator` |
| Architect (design challenge) | `fable-architect` | claude | claude-fable-5-2 | xhigh | — |
| Architect (analyses, reviews) | `astra-architect` | codex | gpt-6.2-astra | xhigh (set with `/model`) | — |
| Dev | `opus-dev-1`, `opus-dev-2` | claude | claude-opus-5-5 | xhigh | — |
| DevOps / QA | `opus-devops` | claude | claude-opus-5-5 | high | `--operator` (drives `privileged-dev`) |
| Privileged QA executor | `privileged-dev` | none | — | — | `--privileged`, no account, no chat |
| Publisher | `gh` | codex-gh | gpt-6.2-astra | xhigh (`/model`, session scope) | separate `<publisher-account>` holding the only GitHub write token; confined network (`github` feature) |
| Dependabot publisher | `gh-dependabot` | codex-gh | gpt-6.2-sol | medium (`/model`, session scope) | copy of `gh`: same account and token; only `falco-dependabot` |

The publisher's token reaches its environment only through an agent profile
that declares it: built-in profiles inject no GitHub secret. The host copies
the agent (`./bin/yoloctl agent copy codex codex-gh`) and adds
`{secret: GH_TOKEN, env: GH_TOKEN}` to its `secret_injection` list; the box
uses that agent with account `<publisher-account>`. Secrets are delivered at container
creation, so a changed token needs `box recreate gh`. A custom agent has its
own account-state leaf (`<account>/codex-gh`), so its agent login is separate
from the built-in agent's. The token's scopes follow the user's push model:
pushing PR branches to falcosecurity directly needs Contents read and write
there; pushing through a fork needs write access to the fork instead.
Under confined
networking the `github` feature lets only `/usr/bin/git` and `/usr/bin/gh`
reach GitHub; verify `gh` is installed before the first check. That policy
does not reach GitHub Actions log storage, so job logs cannot be downloaded
from the publisher box: rely on check annotations, or ask the user for a log.

`gh-dependabot` is a `box copy` of `gh` (same agent `codex-gh`, account
`<publisher-account>`, token and Codex login), with `-m gpt-6.2-sol` and medium effort.
Both share one Codex config: set effort with `/model` choosing **s**
(session) rather than Enter (account default), so one box's choice does not
change the other's.

"Another Opus dev" means another box like `opus-dev-N`, not a new role.

## Shape each box

All chat boxes: the falco-expert workdir, `--unconfined-network`, the
`github` feature (for `gh`), `yolo.chat.skill` (implied by `--operator`), and
`--capability fs.pty.allocate` for architects and devs. Declare everything
before the first launch: image, feature, mount, account, network and operator
changes recreate the container later.

```sh
WD=<host-path-of-falco-expert>   # host path of the workdir
# Claude worker (architect example)
yoloctl box create fable-architect --agent claude --account <account> --workdir "$WD" \
  --features github,yolo.chat.skill --unconfined-network \
  --capability fs.pty.allocate \
  --agent-extra-args --model,claude-fable-5-2,--effort,xhigh \
  --manifest-only --no-attach
yoloctl chat enroll fable-architect --connect --client space --recreate --json

# Privileged executor (declaration only; the host starts it)
yoloctl box create privileged-dev --agent none --account none --privileged \
  --workdir "$WD" --manifest-only --no-attach
```

Host start of the privileged box:

```sh
yoloctl box start privileged-dev --space <space> --no-attach
```

Host commands for the user use the `yoloctl` binary the user names (for
example a local build instead of the one on PATH); record it in
`.falco-team/`. Write prompts that work in the user's host shell (in zsh, wrap
`read -p` in `bash -c '…'`). Secrets go in host-only `account secret set`,
read from stdin, never through chat.

Only the coordinator listens to all messages ([listening
directive](../SKILL.md#chat-and-hand-offs)); workers keep the default
`mentions`. For the coordinator, `messages` wake is selected at launch, never
via box env:

```sh
--agent-extra-args '--settings,"{""env"":{""AIRC_DELIVERY_WAKE"":""messages""}}"'
```

`--agent-extra-args` is CSV and `box set` replaces the whole list.

## Existing box joining chat

An existing box missing `yolo.chat.skill`, open networking or PTY needs
`yoloctl box set` with all changes at once, then
`yoloctl chat enroll BOX --connect --client space --recreate`. Save its
hand-off first; recreation keeps account state and the workdir but drops the
container's private home. The coordinator never recreates itself: self-enroll
without `--recreate`, last, and let a peer or the host recreate it.

## Disk

Space builds and box starts need free VM disk. Devs build in overlayfs scratch
copies, keep caches small and clean them after final checks (`go clean -cache
-modcache`, package caches); finished worktrees are removed by exact path at
ticket close.

## Skills

Claude boxes on one account share `~/.claude`; Codex boxes share `~/.codex`.
Install once per account from any box on it:

```sh
bash skills/falco-yolo-team/scripts/install-skills.sh --skills-dir ~/.claude/skills
bash skills/falco-yolo-team/scripts/install-skills.sh --skills-dir ~/.codex/skills
```

The links point into the shared workdir, so every box mounting it at the same
path resolves them. A newly installed skill is visible to a session started
after the install. A private skill (such as the user's voice skill) comes from
a read-only mount on only the boxes that need it; a link to it in a shared
skills directory stays dangling, and unusable, on the boxes without the mount.

## Onboarding instruction

After enrollment, inspect `yoloctl box use BOX screen`; at an idle prompt send
**one** instruction (`box use BOX batch --stdin` with a text request followed
by `key enter`). It contains: box and role; "load AGENTS.md, README.md and the
falco-yolo-team skill, then your role reference"; scope and holds; paths
(`.falco-team/`, the workdir); intended model/effort; client `space`, channel
`#space`; and the harness paragraph:

- **Claude:** the packaged `airc-delivery` monitor is your consumer. Run
  `airc status space`; never add a waiter or start the plugin yourself. If the
  client stays connected with no consumer, report it.
- **Codex:** inspect `airc status space`, read the installed Codex recipe,
  verify `CODEX_THREAD_ID`, and keep **one**
  `airc subscribe space --wake mentions -- airc-codex --thread "$CODEX_THREAD_ID"`
  job.

It ends with: send one confirmed READY in `#space` addressed to the
coordinator, then wait. READY names box and role, observed model/effort, the
installed skills seen, the connection and its delivery owner. Input `sent` is
not READY; onboarding completes only on READY from the expected account.
