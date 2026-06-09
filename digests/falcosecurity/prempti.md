# falcosecurity/prempti Digest

> **KB Era:** 0.44 — **prempti v0.2.1 targets Falco 0.43.0** (no prempti release for the 0.44 era yet; Makefile pins `FALCO_VERSION := 0.43.0`) | **Source:** [`refs/falcosecurity/prempti/`](../../refs/falcosecurity/prempti/) | **Version:** v0.2.1 (released 2026-05-12)

**Repository:** [falcosecurity/prempti](https://github.com/falcosecurity/prempti)
**Status:** Ecosystem / **Sandbox** (per README badge)
**Stability:** Experimental Preview — interfaces and behavior may change between releases
**License:** Apache 2.0 ([`LICENSE`](../../refs/falcosecurity/prempti/LICENSE))
**Platforms:** Linux (x86_64, aarch64), macOS (Apple Silicon, Intel), Windows (x64, ARM64)

## Overview

**Prempti** is a policy and visibility layer for AI coding agents. It intercepts tool calls (shell commands, file writes/reads, web requests, MCP calls) *before* execution, evaluates them against Falco rules in `nodriver` mode, and returns allow/deny/ask verdicts in real time. It runs entirely in userspace, with no kernel instrumentation and no elevated privileges.

**It is not** a sandbox or OS-level security boundary — at the hook level the plugin only sees what the agent *declares*, not the runtime side effects of resulting commands. It is a **cooperative** policy layer that complements containment techniques (sandboxing, system hardening, least-privilege), not a replacement.

**Source:** [`README.md`](../../refs/falcosecurity/prempti/README.md), [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md)

### Falco Era

| Item | Value |
|------|-------|
| Falco version targeted | **0.43.0** (hardcoded in [`Makefile:5`](../../refs/falcosecurity/prempti/Makefile)) |
| Engine mode | `nodriver` (no kernel driver — plugin-only event source) |
| Falco source plugin SDK | `falco_plugin` Rust crate **v0.5** ([`plugins/coding-agents-plugin/Cargo.toml`](../../refs/falcosecurity/prempti/plugins/coding-agents-plugin/Cargo.toml)) |
| Falco binary acquisition | Linux: pre-built download from `download.falco.org`. macOS/Windows: built from source with an `http_output` patch ([`installers/macos/falco-macos-http-output.patch`](../../refs/falcosecurity/prempti/installers/macos/falco-macos-http-output.patch), [`installers/windows/falco-windows-http-output.patch`](../../refs/falcosecurity/prempti/installers/windows/falco-windows-http-output.patch)) |

## Architecture

```
┌──────────────┐      ┌──────────────┐      ┌────────────────────────────┐
│ Coding Agent │─────>│ Interceptor  │─────>│     Falco (nodriver)       │
│              │      │   (hook)     │      │  ┌───────────────────────┐ │
│              │<─────│              │<─────│  │  Plugin (src + extract│ │
│              │      │              │      │  │  + embedded broker)   │ │
└──────────────┘      └──────────────┘      │  └───────────────────────┘ │
                                            │  Rule Engine + Rules       │
                                            └────────────────────────────┘
```

**Source:** [`README.md`](../../refs/falcosecurity/prempti/README.md), [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) Architecture section

### Pipeline Flow

1. **Interception** — the coding agent's pre-tool-use hook fires; the interceptor captures structured event data and pauses execution while awaiting a verdict.
2. **Event delivery** — interceptor sends the event to the plugin's embedded broker via a Unix domain socket (`broker.sock`).
3. **Rule evaluation** — the plugin feeds the event to Falco's rule engine via the source plugin API (`next_batch`); Falco evaluates all loaded rules.
4. **Alert feedback** — matching rules generate alerts; Falco delivers them back to the plugin's embedded HTTP server via `http_output` on `localhost:2802`.
5. **Verdict resolution** — the broker derives the verdict from rule tags (`coding_agent_deny`, `coding_agent_ask`, or allow-by-default) and responds to the interceptor.
6. **Verdict delivery** — interceptor returns the verdict to the coding agent using the agent's standard hook response format.

### Components

| Component | Location | Language | Role |
|-----------|----------|----------|------|
| **Interceptor** | [`hooks/claude-code/`](../../refs/falcosecurity/prempti/hooks/claude-code/) | Rust | Thin passthrough: reads hook JSON from stdin, wraps in envelope, sends to broker, maps verdict to stdout. No content interpretation. |
| **Plugin** | [`plugins/coding-agents-plugin/`](../../refs/falcosecurity/prempti/plugins/coding-agents-plugin/) | Rust (falco_plugin SDK v0.5) | Falco **source + extraction** plugin with embedded broker. Parses events, extracts fields, feeds Falco, receives alerts, resolves verdicts. Built as a C dynamic library (`cdylib`, `libcoding_agent.so` / `.dylib` / `.dll`). |
| **Supervisor / CLI** | [`tools/premptictl/`](../../refs/falcosecurity/prempti/tools/premptictl/) | Rust | `premptictl` CLI plus the `daemon` subcommand that spawns Falco, rotates its logs, owns the agent hook lifecycle, and exposes a control socket. |
| **Rules** | [`rules/`](../../refs/falcosecurity/prempti/rules/) | YAML (Falco rule language) | Default ruleset (overwritten on upgrade), user overrides directory, mandatory catch-all `seen.yaml`. |
| **Installer** | [`installers/{linux,macos,windows}/`](../../refs/falcosecurity/prempti/installers/) | Shell, PowerShell, WiX (MSI) | Platform-specific packaging, install, hook registration, mode switching, uninstall. |
| **Skill** | [`skills/prempti-falco-rules/`](../../refs/falcosecurity/prempti/skills/prempti-falco-rules/) | Claude Code skill | Interactive rule-authoring skill distributed via the Claude Code plugin marketplace ([`.claude-plugin/marketplace.json`](../../refs/falcosecurity/prempti/.claude-plugin/marketplace.json)). |
| **Tests** | [`tests/`](../../refs/falcosecurity/prempti/tests/) | Rust | Cross-platform interceptor unit tests and end-to-end integration tests. |

**Source:** [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) Components table, [`Cargo.toml`](../../refs/falcosecurity/prempti/Cargo.toml) workspace members

## Key Design Decisions

### Single data source: `coding_agent`

The plugin registers one Falco data source named **`coding_agent`** (the plugin name itself). Rules MUST set `source: coding_agent`. It implements two capabilities: **sourcing** (event generation) and **extraction** (field extraction for rules).

### Generic, agent-agnostic event schema

All event data is exposed through two field namespaces. Path fields come in raw/real pairs — *raw* is what the agent reported, *real* is `canonicalize`'d (symlinks resolved, absolute); use *real* for policy matching.

| Field | Type | Description |
|-------|------|-------------|
| `correlation.id` | u64 | Broker-assigned monotonic ID, always > 0; declared with `add_output()` so Falco auto-includes it in `output_fields` |
| `agent.name` | string | Coding agent identifier (e.g. `claude_code`) |
| `agent.os` | string | Host OS — `linux`, `macos`, `windows`, or `unknown` (static per build, from `cfg!(target_os)`) |
| `agent.hook_event_name` | string | Lifecycle hook type (e.g. `PreToolUse`) |
| `agent.session_id` | string | Session identifier |
| `agent.cwd` | string | Working directory, raw |
| `agent.real_cwd` | string | Working directory, resolved canonical path |
| `agent.permission_mode` | string | Session permission mode (`default`, `acceptEdits`, `plan`, `bypassPermissions`; Codex also `dontAsk`) |
| `agent.transcript_path` | string | Session transcript file path; empty when agent reports `null` |
| `tool.use_id` | string | Tool call identifier (raw, may be empty) |
| `tool.name` | string | Tool name (`Bash`, `Write`, `Edit`, `Read`, `Glob`, `Grep`, `Agent`, …) |
| `tool.input` | string | Full tool input JSON |
| `tool.input_command` | string | Shell command, Bash tool only |
| `tool.file_path` | string | Target file path, raw (Write/Edit/Read only) |
| `tool.real_file_path` | string | Target file path, canonicalized (Write/Edit/Read only) |

**Source:** [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) Field schema, [`rules/README.md`](../../refs/falcosecurity/prempti/rules/README.md) Available Fields

**Rule authoring notes:**
- Use the `val()` transformer when comparing one field to another: `tool.real_file_path startswith val(agent.real_cwd)`. Without `val()` the RHS is a literal.
- Use `basename()` to extract the file name from a path: `basename(tool.file_path) = ".env"`.

### Tags drive verdicts (not output text)

Verdicts are encoded in the rule's `tags:` array, not in the `output:` string. Tag names are **configurable** in the plugin `init_config` and support multiple tags per verdict. Defaults:

| Tag | Verdict |
|-----|---------|
| `coding_agent_deny` | Block the tool call |
| `coding_agent_ask` | Require user confirmation |
| `coding_agent_seen` | Used only by the catch-all `seen.yaml` rule (audit + batch-completion signal) |
| (none) | Allow — absence of a deny/ask tag IS the allow verdict |

When multiple rules match: **deny > ask > allow**.

### Catch-all "seen" rule + HTTP verdict resolution

All verdict signals flow through Falco's `http_output` to the plugin's embedded HTTP server on `127.0.0.1:2802`. Deny/ask alerts resolve the pending request immediately. A **catch-all seen rule** (tagged `coding_agent_seen`) fires for every event; when the broker receives the seen alert, rule evaluation is complete — if no deny/ask alert arrived for that `correlation.id`, the request resolves as allow. This is the synchronization mechanism — no timeouts involved.

**Critical config requirements** ([`configs/falco.yaml`](../../refs/falcosecurity/prempti/configs/falco.yaml), [`configs/falco.coding_agents_plugin.yaml`](../../refs/falcosecurity/prempti/configs/falco.coding_agents_plugin.yaml)):

| Setting | Why |
|---------|-----|
| `rule_matching: all` | Default `first` only fires one rule per event — would prevent deny + seen from both firing |
| `priority: debug` | Seen rule has `priority: DEBUG`; raising the floor breaks verdict resolution |
| `json_output: true` + `json_include_message_property: true` + `json_include_tags_property: true` + `json_include_output_fields_property: true` | Broker parses tags and `output_fields.correlation.id` from JSON alerts |
| `json_include_output_property: false` | Avoids redundant timestamp prefix in verdict reason |
| Seen rule loaded **last** | Ensures deny/ask alerts are enqueued before the batch-completion signal |
| `engine.kind: nodriver` + `--disable-source syscall` CLI flag | nodriver leaves syscall source idle but still allocates resources; CLI flag removes it entirely |

### Embedded broker (no separate process)

The broker lives **inside** the Falco plugin, not as a separate process. The plugin spawns threads for the Unix socket server (accepting interceptor connections) and the HTTP server (receiving Falco alerts). The only processes the user runs are the supervisor + Falco, plus the stateless interceptor invoked per tool call. **Source:** [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) "Broker embedded in plugin"

### Operational modes

Two plugin modes, switchable without reinstall via `premptictl mode <guardrails|monitor>`:

- **Guardrails** (default) — verdicts enforced (deny/ask/allow).
- **Monitor** — rules evaluated and logged, but all verdicts resolve to allow.

Mode changes are applied with an explicit service restart driven by `ctl mode`: the CLI rewrites the plugin config fragment, stops the service, re-registers the interceptor hook (so the restart window stays fail-closed), and starts the service again. Falco's `watch_config_files` is deliberately **disabled** because it is Linux-only upstream — so config edits to `falco.yaml` or any included file only take effect on the next service restart.

**Source:** [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) Operational modes, [`configs/falco.yaml`](../../refs/falcosecurity/prempti/configs/falco.yaml) `watch_config_files: false` with rationale comment

### Fail-closed semantics

When the hook is registered but Falco / the plugin is unreachable, tool calls are **denied**. This is by design: no policy gap. During a `ctl mode` or `ctl restart`, the hook is re-registered between stop and start so the restart window itself stays fail-closed. Use `premptictl hook remove` to deliberately bypass interception (e.g. when the service is intentionally down). **Source:** [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) Fail-safety

### Supervisor (`premptictl daemon`)

The init system (systemd user unit on Linux, launchd user agent on macOS, `HKCU\…\Run` key on Windows) spawns **not Falco directly** but a Rust supervisor process running `premptictl daemon --prefix <prefix>`, which in turn spawns Falco. The supervisor:

1. **Owns Falco's lifecycle**: spawns it with `-U -c falco.yaml --disable-source syscall`, waits on it, escalates SIGTERM → SIGKILL on shutdown timeout (Unix), or `TerminateProcess` (Windows).
2. **Owns the log files**: drains Falco's stdout into `log/falco.log` and stderr into `log/falco.err`, line by line. The `-U` (unbuffered) flag ensures Falco flushes after every alert so JSON lines arrive synchronously.
3. **Owns rotation**: parameters in [`configs/supervisor.yaml`](../../refs/falcosecurity/prempti/configs/supervisor.yaml) (cap 10 MiB default, 3 archives kept, 20 s stop timeout). Identical implementation on every platform.
4. **Owns the hook lifecycle**: runs `hook::add` on start, `hook::remove` on stop. Replaces systemd's `ExecStartPost`/`ExecStopPost`, the launchd `trap`, and the Windows `try/finally`.
5. **Exposes a control channel**: `run/supervisor.sock` (separate from `run/broker.sock`) accepts `STOP\n` (graceful shutdown) and `STATUS\n` (returns pid, falco_pid, start time, rotation count). This is how `ctl stop` on Windows requests a graceful shutdown of a console-less process.

Restart-on-failure is the init system's job; the supervisor is intentionally dumb. Only one supervisor at a time per prefix because `supervisor.sock` is a singleton.

**Source:** [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) Supervisor section

## Installation Layout

All components install under `~/.prempti/` (Linux/macOS) or `%LOCALAPPDATA%\prempti\` (Windows):

```
~/.prempti/
├── bin/                    # Executables: falco, claude-interceptor, premptictl
├── config/
│   ├── falco.yaml                       # Base Falco config (engine, output, isolation)
│   ├── falco.coding_agents_plugin.yaml  # Plugin config (plugin def, rules, http_output)
│   └── supervisor.yaml                  # Supervisor config; preserved on upgrade
├── log/                    # Falco logs (rotated): falco.log[.1..N], falco.err[.1..N]
├── run/                    # Runtime sockets: broker.sock, supervisor.sock
├── share/                  # Plugin library: libcoding_agent.{so,dylib,dll}
└── rules/
    ├── default/coding_agents_rules.yaml  # Default ruleset (overwritten on upgrade)
    ├── user/                             # User custom rules (preserved on upgrade)
    └── seen.yaml                         # Catch-all seen rule (loaded last)
```

**Source:** [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) Installation directory structure

### Falco configuration isolation

Falco runs with a fully isolated configuration — no defaults from `/etc/falco/`. The base config ([`configs/falco.yaml`](../../refs/falcosecurity/prempti/configs/falco.yaml)) sets `engine.kind: nodriver`, disables `syslog_output`/`file_output`/`program_output`/`webserver`, includes the plugin fragment via `config_files`, and disables `watch_config_files` to keep behavior identical across platforms (the Falco implementation is Linux/inotify-only). The plugin fragment ([`configs/falco.coding_agents_plugin.yaml`](../../refs/falcosecurity/prempti/configs/falco.coding_agents_plugin.yaml)) declares the plugin, `load_plugins`, `rules_files` order, `rule_matching: all`, `http_output`, and `append_output` for AI-agent attribution. All paths use `${HOME}` expansion (Falco 0.43 supports `${VAR}` in all YAML scalars).

## Default Ruleset

The default ruleset ([`rules/default/coding_agents_rules.yaml`](../../refs/falcosecurity/prempti/rules/default/coding_agents_rules.yaml)) ships **59 rules** plus reusable lists and macros, organized into seven sections (per [`README.md`](../../refs/falcosecurity/prempti/README.md) Default Rules table and [`rules/README.md`](../../refs/falcosecurity/prempti/rules/README.md)):

| Section | Coverage |
|---------|----------|
| Working-directory boundary | Monitor and ask on file access outside the session's project directory |
| Sensitive paths | Deny reads and writes to `/etc/`, `~/.ssh/`, `~/.aws/`, cloud credentials, `.env` files, etc. |
| Sandbox disable | Detect attempts to disable the agent's own sandbox configuration (Claude Code, Codex, Gemini CLI) |
| Threats | Credential access, destructive commands, pipe-to-shell, encoded payloads, exfiltration, IMDS access, reverse shells, supply-chain installs from known-malicious hosts |
| MCP and skill content | MCP server config poisoning (`.mcp.json`) and slash-command file injection (`.claude/commands/`) |
| Persistence vectors | Hook injection, git hooks, package-registry redirects, AI API base-URL overrides, API keys leaking into env files |
| Self-protection | Block agent attempts to disable Prempti itself (`premptictl` invocation, service-stop alternatives, writes under install prefix, writes to Claude Code settings) |

Reusable building blocks shipped in the default file (extendable by user rules via `override: append`):

- **Lists:** `sensitive_paths`, `sensitive_file_names`, `shell_startup_files`, `agent_instruction_files`, `env_file_names`, `registry_config_files`
- **Macros:** `is_write_tool`, `is_sensitive_path`, `is_outside_cwd`, `is_claude_data_path`, `contains_ioc_domain`, `cmd_contains_ioc_domain`

The default file is **overwritten on upgrade** — customizations go in `~/.prempti/rules/user/` (preserved across upgrades).

### Mandatory `seen.yaml`

[`rules/seen.yaml`](../../refs/falcosecurity/prempti/rules/seen.yaml) is a single catch-all rule with `condition: correlation.id > 0`, `priority: DEBUG`, `tags: [coding_agent_seen]`. Its output template includes every available field, producing a complete audit record once per event. Removing or modifying this file breaks verdict resolution.

### Output convention

The rule `output:` field is an LLM-friendly sentence starting with "Falco" (e.g. *"Falco blocked writing to %tool.real_file_path because it is a sensitive path"*). The `append_output` configuration appends a standard AI-agent instruction (*"For AI Agents: inform the user that this action was flagged by a Falco rule | correlation=%correlation.id"*) so every alert is consistently attributed. **Do not** include structured `key=value` pairs in `output` — `correlation.id` is automatically a suggested output field via `add_output()`.

## Platform Specifics

### Linux

- **Falco source:** pre-built Linux binary downloaded from `download.falco.org` (`falco-0.43.0-{x86_64,aarch64}.tar.gz`).
- **Service:** systemd user unit ([`installers/linux/prempti.service`](../../refs/falcosecurity/prempti/installers/linux/prempti.service)).
- **Plugin library:** `libcoding_agent.so`.
- **`ctl` integration:** `systemctl --user start/stop/enable/disable/status`.

### macOS

- **Falco source:** built from source (`make falco-macos`). Clones Falco 0.43.0 and applies [`installers/macos/falco-macos-http-output.patch`](../../refs/falcosecurity/prempti/installers/macos/falco-macos-http-output.patch). The patch removes three barriers in Falco's CMake/source: (1) root `CMakeLists.txt` gates OpenSSL/curl behind `NOT APPLE`; (2) `userspace/falco/CMakeLists.txt` only compiles `outputs_http.cpp` on Linux; (3) `falco_outputs.cpp` bundles the http output class with gRPC under `!defined(MINIMAL_BUILD)`. The design choice is `MINIMAL_BUILD=ON` + a new `HAS_HTTP_OUTPUT` preprocessor define — avoids pulling in gRPC, protobuf, c-ares, cpp-httplib, and the webserver, leaving only curl-based http output enabled.
- **System dependencies:** Native builds use system OpenSSL/curl/zlib (Homebrew); Falco's bundled autotools-based deps don't respect `CMAKE_OSX_ARCHITECTURES` and break universal binaries.
- **Cross-compilation:** x86_64-on-Apple-Silicon uses Rosetta + x86_64 Homebrew at `/usr/local`; `make macos-universal` produces a fat binary via `lipo -create`.
- **Service:** launchd user agent ([`installers/macos/dev.falcosecurity.prempti.plist`](../../refs/falcosecurity/prempti/installers/macos/dev.falcosecurity.prempti.plist)), label `dev.falcosecurity.prempti`. `ProgramArguments` invokes the supervisor directly.
- **Plugin library:** `libcoding_agent.dylib`. Quarantine bit may need clearing on first run (`xattr -dr com.apple.quarantine ~/.prempti`).
- **`ctl` integration:** `launchctl load/unload/list` (compile-time branched via `#[cfg(target_os)]`).

### Windows

- **Falco source:** built from source (`make falco-windows`). Clones Falco 0.43.0 and applies [`installers/windows/falco-windows-http-output.patch`](../../refs/falcosecurity/prempti/installers/windows/falco-windows-http-output.patch) (same `HAS_HTTP_OUTPUT` pattern plus a `_WIN32` block tolerating `CURLE_NOT_BUILT_IN` for `CURLOPT_NOPROXY`/`CURLOPT_CAINFO`/`CURLOPT_CAPATH` because the SChannel backend omits those options) and [`installers/windows/falco-windows-cmake-generator.patch`](../../refs/falcosecurity/prempti/installers/windows/falco-windows-cmake-generator.patch) (forwards `-G`/`-A` to the nested libscap/libsinsp configure, avoids ARM64 link-time platform mismatches). The plugin `library_path` POSIX check is also patched to use `std::filesystem::path::has_root_path()` so absolute Windows paths are recognized.
- **TLS:** static curl from vcpkg with the **SChannel** backend (`curl:x64-windows-static` / `curl:arm64-windows-static`). No OpenSSL on Windows.
- **Service:** no Windows Service (a per-user install can't register a service without admin). Auto-start via `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\Prempti`, value invokes [`installers/windows/prempti-launcher.ps1`](../../refs/falcosecurity/prempti/installers/windows/prempti-launcher.ps1) with `WindowStyle Hidden` to avoid a console flash at login. The launcher just invokes `premptictl daemon`.
- **Graceful shutdown:** `ctl stop` connects to `run/supervisor.sock` and sends `STOP\n` (real Unix-domain socket — Windows 10+ supports `AF_UNIX` natively via the `uds_windows` crate). Falls back to `taskkill /F /PID <sup-pid>` only if the supervisor doesn't exit within 30 s.
- **Plugin library:** `coding_agent.dll`. Paths normalized to forward slashes at config-generation time (and at runtime — the `\\?\` long-path prefix that `std::fs::canonicalize` sometimes adds is stripped for rule matching).
- **Packaging:** WiX MSI ([`installers/windows/Package.wxs`](../../refs/falcosecurity/prempti/installers/windows/Package.wxs)) with a deferred `REMOVE=ALL` custom action that calls `uninstall.ps1` before `RemoveFiles`, so Apps & Features and `msiexec /x` both stop the service, remove the hook, drop the Run-key entry, and clean `bin\` from the user `PATH`.

## `premptictl` Command Surface

| Command | Purpose |
|---------|---------|
| `daemon --prefix <path>` | Run the supervisor (spawns Falco, owns logs/rotation/hook) |
| `start` / `stop` / `restart` | Service lifecycle (per-platform implementation, same UX) |
| `enable` / `disable` | Auto-start at login |
| `status` | Show service state |
| `mode <guardrails\|monitor>` | Switch operational mode (rewrites plugin config, restarts service, re-registers hook) |
| `health` | Synthetic event through the full pipeline; expects `OK: pipeline healthy (synthetic event → allow)` |
| `hook add` / `hook remove` / `hook status` | Register / unregister / inspect the agent hook (writes `~/.claude/settings.json` for Claude Code) |
| `logs` | Tail Falco logs; defaults to last 100 lines, `-f` to follow, `--tail=N` to override (uses `tail` on Unix, `Get-Content -Tail` on Windows) |
| `uninstall` | Linux/macOS uninstall (Windows uninstalls via MSI) |

**Source:** [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) Service-management tables (per-OS)

## Build & Release

- **Workspace version** is declared once in [`Cargo.toml`](../../refs/falcosecurity/prempti/Cargo.toml) (`[workspace.package].version`), inherited by every crate via `version.workspace = true`. The plugin's reported version is derived from `CARGO_PKG_VERSION` at compile time; `Makefile` and `installers/windows/package.ps1` read the same field. The Claude Code marketplace manifest ([`.claude-plugin/marketplace.json`](../../refs/falcosecurity/prempti/.claude-plugin/marketplace.json)) carries an independent version that must be kept in lockstep — release cuts are a two-file edit.
- **Release profile:** workspace-wide `lto = true`, `strip = true`. Size-optimized (`opt-level = "z"`, `codegen-units = 1`) for `claude-interceptor` and `premptictl`; speed-optimized (`opt-level = 2`) for the plugin (Falco hot path).
- **MSRV:** latest stable Rust (the `falco_plugin` SDK tracks latest stable).

### Make targets

| Target | Description |
|--------|-------------|
| `make build` / `build-{interceptor,plugin,ctl}` | Build all / individual Rust components for the native arch |
| `make test` / `test-{plugin-unit,interceptor,e2e}` | Unit and E2E tests; E2E discovers the project's Falco build |
| `make download-falco-linux` / `falco-macos` / `falco-windows[-x64,-arm64]` | Acquire Falco for each platform |
| `make linux` / `linux-{x86_64,aarch64}` | Linux `.tar.gz` packages |
| `make macos` / `macos-{aarch64,x86_64,universal}` | macOS `.pkg` (and tarball) installers |
| `make windows` / `windows-{x64,arm64}` | Windows `.msi` packages |

**Source:** [`Makefile`](../../refs/falcosecurity/prempti/Makefile)

## Tags, Releases, and Status

| Tag | Date | Notes |
|-----|------|-------|
| v0.1.0 | initial preview | First public release |
| v0.2.0-rc1, v0.2.0 | March–April 2026 | Pre-0.2.x baseline |
| v0.2.1-rc1, **v0.2.1** | 2026-05-12 | Latest release (current pin) |

**Stability:** Marked "Experimental Preview" by the README; "Sandbox" status per the falcosecurity ecosystem badge. The project is not (yet) listed in [`refs/falcosecurity/evolution/repositories.yaml`](../../refs/falcosecurity/evolution/repositories.yaml) at the current `evolution` submodule revision.

**OWNERS** ([`OWNERS`](../../refs/falcosecurity/prempti/OWNERS)): `leogr`, `ldegio`, `c2ndev`, `irozzo-1A`, `ekoops`.

**Roadmap signals (from [`README.md`](../../refs/falcosecurity/prempti/README.md)):** Codex (OpenAI) integration is "Planned"; Linux/macOS/Windows for Claude Code is the supported matrix today.

## Known Limitations

Documented in [`README.md`](../../refs/falcosecurity/prempti/README.md) "Known Limitations":

- **Hook-level interception only**: Prempti sees what the agent *declares*, not the runtime side effects. A compile-then-run pattern (`gcc main.c -o main && ./main`) is visible as `gcc` and `./main` invocations, but the syscalls of `./main` itself are not observed.
- **Asymmetric coverage**: Strongest for first-class tools (`Write`, `Edit`, `Read`); weaker for generic `Bash` (where rules evaluate the declared command, not the fully-resolved shell behavior); input-side only for MCP (the requested call is inspectable, but not the MCP server's subsequent side effects).
- **Not a sandbox**: Guardrails mode blocks many unsafe or out-of-policy tool calls but is not OS-level containment. Falco's kernel instrumentation (eBPF/kmod) remains the right tool for syscall-level visibility on Linux.

## Related Components in the Knowledge Base

- [`digests/falcosecurity/falco/configuration.md`](falco/configuration.md) — full Falco YAML configuration reference (rule_matching, http_output, json_*, append_output, watch_config_files)
- [`digests/falcosecurity/falco/rule-language.md`](falco/rule-language.md) — Falco rule language (lists, macros, rules, override, tags, priority, source)
- [`digests/falcosecurity/falco/outputs.md`](falco/outputs.md) — output channels including `http_output` and `append_output`
- [`digests/falcosecurity/libs/plugin-framework.md`](libs/plugin-framework.md) — Plugin API (sourcing + extraction capabilities, `next_batch`, `add_output()`)
- [`digests/falcosecurity/plugin-sdk-rs.md`](plugin-sdk-rs.md) — Rust plugin SDK (`falco_plugin` crate) used by the Prempti plugin
- [`digests/falcosecurity/falco-actions.md`](falco-actions.md) — adjacent ecosystem entry for CI/CD-side coding-agent security

## Sources

| Topic | Source File |
|-------|-------------|
| Project overview, status, user docs | [`README.md`](../../refs/falcosecurity/prempti/README.md) |
| Architecture, design decisions, platform internals | [`CLAUDE.md`](../../refs/falcosecurity/prempti/CLAUDE.md) |
| Workspace layout, profiles, version | [`Cargo.toml`](../../refs/falcosecurity/prempti/Cargo.toml) |
| Build targets, Falco version pin | [`Makefile`](../../refs/falcosecurity/prempti/Makefile) (`FALCO_VERSION := 0.43.0`) |
| Base Falco config (with isolation rationale) | [`configs/falco.yaml`](../../refs/falcosecurity/prempti/configs/falco.yaml) |
| Plugin config (mode, http_output, rules order) | [`configs/falco.coding_agents_plugin.yaml`](../../refs/falcosecurity/prempti/configs/falco.coding_agents_plugin.yaml) |
| Supervisor config | [`configs/supervisor.yaml`](../../refs/falcosecurity/prempti/configs/supervisor.yaml) |
| Default ruleset | [`rules/default/coding_agents_rules.yaml`](../../refs/falcosecurity/prempti/rules/default/coding_agents_rules.yaml) |
| Mandatory catch-all rule | [`rules/seen.yaml`](../../refs/falcosecurity/prempti/rules/seen.yaml) |
| Rule schema, fields, conventions | [`rules/README.md`](../../refs/falcosecurity/prempti/rules/README.md) |
| Plugin Rust deps (falco_plugin v0.5) | [`plugins/coding-agents-plugin/Cargo.toml`](../../refs/falcosecurity/prempti/plugins/coding-agents-plugin/Cargo.toml) |
| Hook (interceptor) implementation | [`hooks/claude-code/src/main.rs`](../../refs/falcosecurity/prempti/hooks/claude-code/src/main.rs) |
| Plugin SPEC | [`docs/plugins/coding-agents-plugin/SPEC.md`](../../refs/falcosecurity/prempti/docs/plugins/coding-agents-plugin/SPEC.md) |
| Hook SPEC | [`docs/hooks/claude-code/SPEC.md`](../../refs/falcosecurity/prempti/docs/hooks/claude-code/SPEC.md) |
| Linux installer/systemd unit | [`installers/linux/`](../../refs/falcosecurity/prempti/installers/linux/) |
| macOS installer + http_output patch | [`installers/macos/`](../../refs/falcosecurity/prempti/installers/macos/) |
| Windows installer + WiX MSI + patches | [`installers/windows/`](../../refs/falcosecurity/prempti/installers/windows/) |
| Rule-authoring skill (Claude Code) | [`skills/prempti-falco-rules/SKILL.md`](../../refs/falcosecurity/prempti/skills/prempti-falco-rules/SKILL.md) |
| Claude Code marketplace manifest | [`.claude-plugin/marketplace.json`](../../refs/falcosecurity/prempti/.claude-plugin/marketplace.json) |
| Maintainers (OWNERS) | [`OWNERS`](../../refs/falcosecurity/prempti/OWNERS) |
