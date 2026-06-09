---
name: falco-rules-author
description: Author, validate, and iteratively tune Falco detection rules. Covers the complete rule language (conditions, macros, lists, priorities, output templates, overrides), the filter expression language (19 operators, 5 transformers, all field classes), rule engine optimization (event type indexing), and practical Docker-based testing workflows with structured feedback loops for false-positive reduction. Supports modern_ebpf (live), replay (.scap), nodriver (plugins-only), and plugin event sources.
metadata:
  falco-version: "0.43"
---

# Falco Rules Author

Author, validate, test, and iteratively tune Falco detection rules.

## 1. Overview and Safety Warnings

This skill enables AI agents to:

- **Author** Falco rules from scratch (conditions, outputs, macros, lists)
- **Validate** rules files using the Falco CLI (`falco -V`)
- **Test** rules against live syscalls (Docker + modern_ebpf) or captured events (.scap replay)
- **Analyze** alert output (text and JSON) to identify true and false positives
- **Tune** rules iteratively using condition-based patterns (macros, lists, negated conditions)
- **Deliver** production-ready rules with minimal false-positive rates

### MANDATORY: Never Perform Dangerous Actions to Test Rules

**You MUST NOT execute dangerous, destructive, or suspicious commands on the system to trigger rule detections.** This is a non-negotiable safety requirement.

Specifically, you MUST NEVER:
- Run exploit code, reverse shells, or privilege escalation attempts
- Execute malware samples or attack tools
- Read, modify, or delete sensitive system files (e.g., `/etc/shadow`, `/etc/passwd`) to generate alerts
- Create suspicious processes, inject code, or spawn shells in containers for testing purposes
- Perform network attacks, port scans, or unauthorized connections
- Modify system configurations, user accounts, or security settings
- Run any command whose primary purpose is to simulate malicious activity

**How to test rules instead:**
- **Replay mode** (preferred): Use pre-existing `.scap` capture files that already contain the events you want to detect
- **Passive observation**: Deploy Falco with live monitoring and observe naturally occurring system activity -- do NOT manufacture activity
- **Validation only**: Use `falco -V` to validate rule syntax and `falco --dry-run` to verify configuration without processing any events
- **User-directed testing**: If the user explicitly asks you to run a specific benign command to generate events (e.g., `ls /etc`), that is acceptable -- but only when the user explicitly directs it and the command itself is harmless

The purpose of this skill is to write and tune rules, not to simulate attacks. If a rule needs to be tested against specific attack patterns, inform the user and let them perform the testing manually or provide `.scap` files containing the relevant events.

### CRITICAL: Daemon Mode Safety

Running Falco as a daemon (live monitoring) requires **elevated privileges** because it instruments the Linux kernel. When running Falco in Docker for testing:

- The container needs Linux capabilities (`CAP_BPF`, `CAP_PERFMON`, `CAP_SYS_RESOURCE`, `CAP_SYS_PTRACE`) or `--privileged`. If Docker doesn't support `CAP_BPF`/`CAP_PERFMON`, use `CAP_SYS_ADMIN` as a fallback.
- It will monitor **all** system activity on the host, including other containers and host processes
- Always use a **dedicated test environment** when possible
- Never run privileged Falco containers on production systems for rule testing
- Use the `replay` engine with `.scap` files when you can -- it requires **no privileges**

### Supported Engines

| Engine | Privileges | Use Case |
|--------|-----------|----------|
| `modern_ebpf` | Yes (capabilities) | Live syscall monitoring for real-world testing |
| `replay` | No | Replay captured `.scap` files -- safest for testing |
| `nodriver` | No | Plugin-only mode (no syscall events) |
| Plugins | Varies | Additional event sources (k8s_audit, etc.) |

Engines NOT covered: `kmod` (kernel module). Legacy `ebpf` and `gvisor` engines were removed in Falco 0.44.0.

---

## 2. Rule Language Quick Reference

For the complete specification (all fields, 19 operators, 5 transformers, field classes, exception system, engine internals), read [`references/rule-language.md`](references/rule-language.md). This section covers the essential conventions.

### Rule Structure

```yaml
- rule: My Detection Rule
  desc: Human-readable description of what this rule detects
  condition: evt.type = execve and proc.name = suspicious_binary
  output: "Suspicious binary executed (user=%user.name command=%proc.cmdline container=%container.id)"
  priority: WARNING
  source: syscall           # Optional, default: syscall
  enabled: true             # Optional, default: true
  tags: [process, mitre_execution, T1059]  # Optional
```

Required fields: `rule`, `desc`, `condition`, `output`, `priority`.

### Lists and Macros

```yaml
- list: shell_binaries
  items: [bash, sh, zsh, csh, ksh, dash, fish]

- macro: spawned_process
  condition: (evt.type in (execve, execveat))

- macro: container
  condition: container.id != host

- macro: open_write
  condition: >
    evt.type in (open, openat, openat2) and
    evt.is_open_write = true
```

### Override and Append

The `override` key modifies rules, macros, and lists across files:

```yaml
# Disable an existing rule
- rule: Terminal shell in container
  enabled: false
  override:
    enabled: replace

# Append to a condition and replace priority
- rule: Write Below Etc
  condition: and not proc.name = systemd-resolve
  priority: ERROR
  override:
    condition: append
    priority: replace

# Append items to a list
- list: shell_binaries
  items: [pwsh]
  override:
    items: append
```

Appendable fields: `condition`, `output`, `desc`, `tags`, `exceptions`. Replaceable: all appendable fields plus `priority`, `enabled`, `warn_evttypes`, `skip-if-unknown-filter`.

### Performance: Start with `evt.type`

Always begin syscall rule conditions with a specific `evt.type` check. Without it, the rule evaluates against every single event (performance penalty, `LOAD_NO_EVTTYPE` warning).

```yaml
# GOOD: Specific event types
condition: evt.type in (open, openat, openat2) and evt.is_open_write = true and fd.name startswith /etc/

# BAD: No evt.type restriction
condition: fd.name startswith /etc
```

### Key Output Fields

Output templates use `%field.name` interpolation. Most-used fields:

| Field | Description |
|-------|-------------|
| `%user.name` | Username |
| `%proc.name` | Process name (truncated at 16 chars) |
| `%proc.cmdline` | Full command line |
| `%proc.pname` | Parent process name |
| `%proc.pid` | Process ID |
| `%proc.exepath` | Full executable path |
| `%fd.name` | File descriptor path or connection tuple |
| `%container.id` | Container ID (`host` for host processes) |
| `%container.name` | Container name |
| `%container.image.repository` | Container image |

### CLI Reference

For validation (`falco -V`), field listing (`falco --list`), rule inspection (`falco -L`), and other CLI operations, use the **falco-cli** skill.

---

## 3. Data Sources

### Syscall Source (Default)

The default event source. Requires kernel instrumentation (modern_ebpf driver) and elevated privileges.

- Source name: `syscall`
- All built-in fields (`evt.*`, `proc.*`, `fd.*`, `user.*`, etc.) are available
- Plugin-provided fields (`container.*`, `k8s.*`) are also available when plugins are loaded
- Rules without an explicit `source:` field default to `syscall`

### Plugin Event Sources

Plugins can provide additional event sources (e.g., `k8s_audit` from the k8saudit plugin). Plugin event source rules:
- Must specify `source: <plugin_source_name>`
- Can only use fields provided by that plugin (plus generic `evt.*` fields)
- May not be testable locally without the plugin and its data source configured

### Nodriver Mode

When `engine.kind: nodriver`, Falco runs without kernel instrumentation:
- No syscall events are captured
- Only plugin event sources are available
- No elevated privileges required
- Useful for testing plugin-only rules

---

## 4. Falco Configuration for Rule Testing

**Source:** [`specs/configuration.md`](../../specs/configuration.md)

### Engine Kinds for Testing

```yaml
# Modern eBPF -- live monitoring (requires privileges)
engine:
  kind: modern_ebpf

# Replay -- replay .scap file (no privileges needed)
engine:
  kind: replay
  replay:
    capture_file: "/path/to/file.scap"

# No driver -- plugin-only mode (no privileges needed)
engine:
  kind: nodriver
```

### Rules Files Configuration

```yaml
rules_files:
  - /etc/falco/falco_rules.yaml         # Default rules
  - /etc/falco/falco_rules.local.yaml   # Local customizations
  - /etc/falco/rules.d                  # Directory (alphabetically sorted)
```

Only `.yml` and `.yaml` files are processed.

### JSON Output Configuration (for Programmatic Analysis)

Enable JSON output for machine-parseable alerts:

```yaml
json_output: true
json_include_output_property: true
json_include_tags_property: true
json_include_output_fields_property: true
```

Or via CLI override:

```bash
falco -o json_output=true -o json_include_output_fields_property=true
```

### Config Override via CLI

The `-o` flag overrides any configuration value. Supports dot notation:

```bash
falco -o "json_output=true" -o "engine.kind=replay" -o "engine.replay.capture_file=/tmp/test.scap"
```

### Hot Reload

Falco supports configuration and rules reload without restart:
- `watch_config_files: true` -- automatically reload when files change
- Send `SIGHUP` to the Falco process to trigger manual reload

---

## 5. False-Positive Reduction Patterns

**DEFAULT STRATEGY:** Use condition-based tuning: macros, lists, and negated conditions. This is the approach used by the official `falcosecurity/rules` and the one most Falco adopters understand.

**Source:** [`refs/falcosecurity/rules/rules/falco_rules.yaml`](../../refs/falcosecurity/rules/rules/falco_rules.yaml), [`digests/falcosecurity/rules.md`](../../digests/falcosecurity/rules.md)

### Pattern 1: Template Macros (`user_known_*` with `never_true`)

The official rules define placeholder macros that default to `never_true` (a macro that always evaluates to `false` via `evt.num=0`). Users override these macros with real conditions to tune rules.

```yaml
# In official rules -- placeholder that does nothing
- macro: never_true
  condition: (evt.num=0)

- macro: user_known_read_sensitive_files_activities
  condition: (never_true)

# In the rule
- rule: Read sensitive file
  condition: >
    open_read and sensitive_files
    and not user_known_read_sensitive_files_activities
```

**To tune:** Override the macro in a local rules file:

```yaml
- macro: user_known_read_sensitive_files_activities
  condition: (proc.name in (backup-agent, config-reader))
  override:
    condition: replace
```

### Pattern 2: Process Lineage Checking (Ancestor Fields)

Use `proc.aname[n]` and related ancestor fields to check the process tree:

```yaml
condition: >
  spawned_process and
  proc.name in (shell_binaries) and
  container and
  not proc.pname in (cron, crond, anacron, ansible, puppet, chef-client)
```

### Pattern 3: Container Image Allowlisting

Use lists of known-good container images:

```yaml
- list: trusted_images
  items: [my-company/app-server, my-company/worker]

- macro: trusted_container
  condition: (container.image.repository in (trusted_images))

# In the rule condition
condition: >
  ... and container and not trusted_container
```

### Pattern 4: List-Based Allowlists with Negated `in` Checks

```yaml
- list: allowed_inbound_ports
  items: [80, 443, 8080, 8443]

- rule: Unexpected Inbound Connection
  condition: >
    evt.type in (accept, accept4) and
    container and
    not fd.sport in (allowed_inbound_ports)
```

### Other Patterns

- **Capability-based preconditions**: `thread.cap_effective contains CAP_NET_ADMIN`
- **Temporal checks (startup windows)**: `container.duration > 30000000000` (ignore first 30s of container life)
- **Network behavior filtering (RFC 1918)**: `not fd.snet in (rfc_1918_addresses)`

### Common Antipatterns to Avoid

| Antipattern | Why It's Bad | Better Approach |
|-------------|-------------|-----------------|
| Overly broad `evt.type` | Performance penalty from evaluating every event | Narrow to specific syscalls |
| String matching on paths without anchoring | `contains /etc` matches `/home/etc/` | Use `startswith /etc/` or `pmatch` |
| Hard-coding process names | Breaks when processes are renamed | Use `proc.exepath` or `proc.aname` for lineage |
| Not using macros for tuning | Users can't customize without editing the rule | Provide `user_known_*` macros |

### Alert Volume Assessment

When analyzing alerts to determine if tuning is needed:

- **>100 alerts/minute** from a single rule: Likely needs significant condition narrowing
- **10-100 alerts/minute**: Review for patterns; may need targeted allowlists
- **1-10 alerts/minute**: Evaluate each alert for true/false positive
- **<1 alert/minute**: Likely well-tuned; verify true positives are being caught

---

## 6. Feedback Loop Workflow

This is the core iterative workflow for authoring production-ready rules.

For detailed Docker setup, container images, troubleshooting, and timing guidance, read [`references/docker-testing.md`](references/docker-testing.md). For output formats, JSON fields, and .scap replay details, read [`references/output-and-replay.md`](references/output-and-replay.md).

### Step 1: Write Initial Rule(s)

Based on the detection requirement, write the initial rule with:
- Specific `evt.type` checks (for performance)
- Descriptive `output` with useful fields
- Appropriate `priority`
- Tags for categorization
- `user_known_*` template macros for future tuning

### Step 2: Validate with `falco -V`

```bash
# Validate syntax and semantics
falco -V /path/to/my_rules.yaml

# Or in Docker
docker run --rm \
  -v /path/to/my_rules.yaml:/my_rules.yaml:ro \
  falcosecurity/falco:0.44.0 \
  falco -V /my_rules.yaml
```

Fix any errors before proceeding. Common errors:
- `LOAD_ERR_COMPILE_CONDITION`: Syntax error in condition (undefined macro, invalid field)
- `LOAD_ERR_COMPILE_OUTPUT`: Invalid field in output template
- `LOAD_ERR_YAML_VALIDATE`: YAML structure error

Warnings to address:
- `LOAD_NO_EVTTYPE`: Rule matches too many event types -- add `evt.type` check
- `LOAD_UNSAFE_NA_CHECK`: Unsafe N/A check in condition
- `LOAD_UNKNOWN_FILTER`: Unknown field (check plugin availability)

### Step 3: Deploy to Docker Container

Choose the appropriate engine:

- **Replay** (safest, no privileges): Use a `.scap` file that contains relevant events
- **Modern eBPF** (realistic, requires privileges): Monitor live system activity

```bash
# Replay mode (safe)
docker run --rm --name falco-rule-test \
  -v /path/to/capture.scap:/capture.scap:ro \
  -v /path/to/my_rules.yaml:/etc/falco/my_rules.yaml:ro \
  falcosecurity/falco:0.44.0 \
  falco \
    -o "engine.kind=replay" \
    -o "engine.replay.capture_file=/capture.scap" \
    -r /etc/falco/falco_rules.yaml \
    -r /etc/falco/my_rules.yaml \
    -o json_output=true \
    -o json_include_output_fields_property=true

# Live mode (requires privileges -- use --privileged for reliability)
docker run -d --name falco-rule-test \
  --privileged \
  -v /proc:/host/proc:ro -v /etc:/host/etc:ro \
  -v /path/to/my_rules.yaml:/etc/falco/my_rules.yaml:ro \
  falcosecurity/falco:0.44.0 \
  falco \
    -r /etc/falco/falco_rules.yaml \
    -r /etc/falco/my_rules.yaml \
    -o json_output=true \
    -o json_include_output_fields_property=true
```

### Step 3b: Smoke Test (Verify BPF Probe Attached)

After starting the live container, **always verify** that the BPF probe attached successfully before proceeding:

```bash
sleep 10 && docker logs falco-rule-test 2>&1 | grep "Opening 'syscall' source with modern BPF probe"
```

If this produces no output, the BPF probe did not attach. See troubleshooting in [`references/docker-testing.md`](references/docker-testing.md).

> **Do NOT use alert count as a smoke test.** Zero alerts after 10 seconds is normal -- it just means no rules matched yet, not that BPF failed. Always check for the BPF attachment log message instead.
>
> **Note:** This smoke test only applies when using the modern_ebpf engine for `syscall` source rules. No other engine (replay, nodriver) or event source (plugins) uses BPF probes.

### Step 4: Collect Alerts

For replay mode, alerts are output immediately when the capture ends.

For live mode, let Falco run for an observation period (use `-M <seconds>` or monitor with `docker logs`):

```bash
# Collect JSON alerts (always use 2>&1 | grep '^{' for reliable extraction)
docker logs falco-rule-test 2>&1 | grep '^{' > /tmp/alerts.json

# Quick check: how many events were detected?
docker logs falco-rule-test 2>&1 | grep "Events detected"
```

> **AI Agent Timing:** Each Bash tool call is a separate, sequential invocation with unpredictable gaps between calls. To ensure test commands run within a `-M` monitoring window, chain everything in a single shell command. See [`references/docker-testing.md`](references/docker-testing.md) for the full chained command pattern.
>
> **WARNING: `grep` exit codes in chains.** `grep` returns exit code 1 when no lines match. In `&&` chains, this silently aborts all subsequent commands. Use `(grep ... || true)` or `;` instead of `&&` after any `grep` whose match count might be zero (smoke tests, alert collection, event counting).

### Step 5: Analyze Alerts

```bash
# Count alerts per rule
jq -r '.rule' /tmp/alerts.json | sort | uniq -c | sort -rn

# Show unique values for a field in alerts from your rule
jq 'select(.rule == "My Rule") | .output_fields["proc.name"]' /tmp/alerts.json | sort -u

# Show full alert details
jq 'select(.rule == "My Rule")' /tmp/alerts.json

# Identify false positive patterns
jq 'select(.rule == "My Rule") | {proc: .output_fields["proc.cmdline"], parent: .output_fields["proc.pname"], container: .output_fields["container.name"]}' /tmp/alerts.json
```

Classify each alert pattern as:
- **True positive**: The rule correctly detected the intended behavior
- **False positive**: The rule triggered on benign activity that should be excluded

### Step 6: Tune Rules

Based on the analysis, apply condition-based tuning:

```yaml
# Add a user_known macro for tuning
- macro: user_known_my_rule_activities
  condition: (never_true)

# In your rule condition, add:
#   and not user_known_my_rule_activities

# Then override the macro with real exclusions:
- macro: user_known_my_rule_activities
  condition: (proc.name in (known-good-process, another-process))
  override:
    condition: replace
```

Or add specific conditions directly:

```yaml
- rule: My Rule
  condition: and not proc.name in (known-good-process)
  override:
    condition: append
```

### Step 7: Re-validate and Re-deploy

```bash
# Validate updated rules
falco -V /path/to/my_rules.yaml

# Restart container with updated rules
docker rm -f falco-rule-test
# Re-run the docker run command from Step 3 with updated rules
```

### Step 8: Repeat Until Requirements Met

Continue the loop until:
- All true positives are caught
- False positive rate is acceptable for the use case
- Alert volume is manageable

**Convergence criteria:** Zero new false positive patterns in the last observation period, alert volume within operational limits, coverage verified.

### Container Cleanup

```bash
docker stop falco-rule-test        # Stop
docker rm falco-rule-test          # Remove
docker rm -f falco-rule-test       # Force remove (stop + remove)
```

---

## 7. Complete Workflow Example

This example applies the feedback loop from Section 6 to detect shell execution in containers.

**The rule:**

```yaml
# File: shell_in_container.yaml

- list: shell_binaries
  items: [bash, sh, zsh, csh, ksh, dash, fish]

- macro: spawned_process
  condition: (evt.type in (execve, execveat))

- macro: container
  condition: container.id != host

- macro: never_true
  condition: (evt.num=0)

- macro: user_known_shell_in_container
  condition: (never_true)

- rule: Shell in Container
  desc: Detects shell execution inside a container
  condition: >
    spawned_process and
    container and
    proc.name in (shell_binaries) and
    not user_known_shell_in_container
  output: >
    Shell spawned in container
    (user=%user.name command=%proc.cmdline pid=%proc.pid
     parent=%proc.pname container=%container.id
     image=%container.image.repository)
  priority: NOTICE
  tags: [container, shell, mitre_execution]
```

**Validate, deploy, collect, and analyze** following Steps 2-5 from Section 6. If analysis reveals that `health-checker` containers legitimately run `sh`, **tune:**

```yaml
- macro: user_known_shell_in_container
  condition: (container.image.repository = "my-company/health-checker")
  override:
    condition: replace
```

Re-validate and re-deploy (Steps 7-8) until false positives are eliminated.

---

## Sources

| Topic | Source in Knowledge Base |
|-------|------------------------|
| Rule YAML schema | [`specs/rule-engine.md`](../../specs/rule-engine.md) |
| Filter language and operators | [`specs/filter-engine.md`](../../specs/filter-engine.md) |
| Configuration | [`specs/configuration.md`](../../specs/configuration.md) |
| Output system | [`specs/output-system.md`](../../specs/output-system.md) |
| CLI interface | [`specs/cli-interface.md`](../../specs/cli-interface.md) |
| .scap format | [`digests/falcosecurity/libs/scap-file-format.md`](../../digests/falcosecurity/libs/scap-file-format.md) |
| Official rules | [`refs/falcosecurity/rules/rules/falco_rules.yaml`](../../refs/falcosecurity/rules/rules/falco_rules.yaml) |
| Rules maturity | [`digests/falcosecurity/rules.md`](../../digests/falcosecurity/rules.md) |
| Plugin system | [`specs/plugin-system.md`](../../specs/plugin-system.md) |
| Docker patterns | [`digests/falcosecurity/falco-website/docs.md`](../../digests/falcosecurity/falco-website/docs.md) |
| Testing harness | [`digests/falcosecurity/testing.md`](../../digests/falcosecurity/testing.md) |
