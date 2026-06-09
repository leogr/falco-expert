# Docker-Based Testing Reference

Complete reference for running Falco in Docker containers for rule testing.

---

## Container Images

| Variant | Image Tag | Base | Use Case |
|---------|-----------|------|----------|
| Default | `falcosecurity/falco:0.44.0` | Wolfi distroless | Production, CI, minimal footprint |
| Debian | `falcosecurity/falco:0.44.0-debian` | Debian | **Recommended for testing** -- has shell, package manager, debugging tools |

Use the **Debian variant** for iterative rule testing. It includes a full shell and `apt-get`, which makes in-container diagnostics (BPF debugging, field inspection, plugin troubleshooting) possible. The distroless default is not designed for interactive use.

## Safety Warnings

- Running Falco in Docker for live testing creates a **privileged container** that monitors all host activity
- Only do this on **dedicated test machines** or **development environments**
- The container can see all processes, files, and network activity on the host
- Always **stop the container** when testing is complete
- Use a **predictable container name** (`falco-rule-test`) for easy management

## Modern eBPF Setup (Privileged Mode -- Recommended for Testing)

Use `--privileged` for live testing. While individual capabilities (`SYS_ADMIN`, `SYS_RESOURCE`, `SYS_PTRACE`) can work, `--privileged` avoids intermittent BPF attachment failures observed on newer kernels (6.x+) when capabilities are granted individually.

```bash
docker run -d \
  --name falco-rule-test \
  --privileged \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v /proc:/host/proc:ro \
  -v /etc:/host/etc:ro \
  -v /path/to/my_rules.yaml:/etc/falco/my_rules.yaml:ro \
  falcosecurity/falco:0.44.0 \
  falco \
    -r /etc/falco/falco_rules.yaml \
    -r /etc/falco/my_rules.yaml \
    -o json_output=true \
    -o json_include_output_fields_property=true
```

> **Note:** This is for **testing only** on development machines. Never use `--privileged` in production. For production, use individual capabilities: `--cap-drop all --cap-add sys_ptrace --cap-add sys_resource --cap-add bpf --cap-add perfmon` (or `--cap-add sys_admin` instead of `bpf`+`perfmon` if your Docker version doesn't support them).

## Mounting Custom Rules and Config

```bash
# Mount a custom rules file
-v /path/to/my_rules.yaml:/etc/falco/my_rules.yaml:ro

# Mount a custom config directory
-v /path/to/config.d/:/etc/falco/config.d/:ro

# Mount a custom config file
-v /path/to/falco.yaml:/etc/falco/falco.yaml:ro
```

## Reading Output

**IMPORTANT:** The Falco Docker image does not guarantee clean stdout/stderr separation. JSON alerts and log messages can end up on either stream. Always use `2>&1 | grep '^{'` to reliably extract JSON alerts:

```bash
# Follow logs in real-time (all streams)
docker logs -f falco-rule-test 2>&1

# Save only JSON alerts to file (reliable method)
docker logs falco-rule-test 2>&1 | grep '^{' > /tmp/falco-alerts.json
```

Parse with `jq`:

```bash
# Extract rule names and counts
jq -r '.rule' /tmp/falco-alerts.json | sort | uniq -c | sort -rn

# Filter for a specific rule
jq 'select(.rule == "My Custom Rule")' /tmp/falco-alerts.json

# Extract output fields
jq '.output_fields' /tmp/falco-alerts.json
```

## Running for a Fixed Duration

Use the `-M` flag to run Falco for a specific number of seconds:

```bash
docker run --rm \
  --name falco-rule-test \
  --privileged \
  -v /proc:/host/proc:ro \
  -v /etc:/host/etc:ro \
  -v /path/to/my_rules.yaml:/etc/falco/my_rules.yaml:ro \
  falcosecurity/falco:0.44.0 \
  falco \
    -r /etc/falco/falco_rules.yaml \
    -r /etc/falco/my_rules.yaml \
    -o json_output=true \
    -o json_include_output_fields_property=true \
    -M 60
```

### `-M` Summary Output

When `-M` is used, Falco prints a text summary to stderr after the monitoring window ends:

```
Events detected: 16
Rule counts by severity:
   Severity: Notice, 13
   Severity: Warning, 3
Triggered rules by rule name:
   AI Agent Spawned Process: 13
   AI Agent Read Credential File: 3
```

This is useful as a **quick pass/fail signal** before diving into JSON analysis. Check `Events detected: N` first -- if it's 0, troubleshoot before parsing JSON.

## Starting, Stopping, and Restarting

```bash
docker start falco-rule-test       # Start
docker stop falco-rule-test        # Stop
docker rm falco-rule-test          # Remove
docker rm -f falco-rule-test       # Force remove (stop + remove)
# Then re-run the docker run command with updated rules
```

## Nodriver Mode in Containers (Plugin-Only)

For testing plugin-only rules without kernel access:

```bash
docker run --rm \
  --name falco-rule-test \
  -v /path/to/my_rules.yaml:/etc/falco/my_rules.yaml:ro \
  falcosecurity/falco:0.44.0 \
  falco \
    -o "engine.kind=nodriver" \
    -r /etc/falco/my_rules.yaml \
    -o json_output=true
```

## Replay Mode in Containers

For testing with `.scap` files inside Docker -- no privileges needed:

```bash
docker run --rm \
  --name falco-rule-test \
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
```

## Smoke Test: Verify BPF Probe Attachment

After starting a live container, **always verify** that the BPF probe attached successfully before proceeding:

```bash
sleep 10 && docker logs falco-rule-test 2>&1 | grep "Opening 'syscall' source with modern BPF probe"
```

If this produces no output, the BPF probe did not attach. See [Troubleshooting](#troubleshooting) before proceeding.

> **Do NOT use alert count as a smoke test.** Zero alerts after 10 seconds is normal -- it just means no rules matched yet, not that BPF failed. Always check for the BPF attachment log message instead.
>
> **Note:** This smoke test only applies when using the modern_ebpf engine for `syscall` source rules. No other engine (replay, nodriver) or event source (plugins) uses BPF probes.

## AI Agent Timing Guidance

Each Bash tool call is a separate, sequential invocation with unpredictable gaps between calls. To ensure test commands run within the `-M` monitoring window, **chain everything in a single shell command**:

```bash
docker rm -f falco-rule-test 2>/dev/null; \
docker run -d --name falco-rule-test \
  --privileged \
  -v /proc:/host/proc:ro -v /etc:/host/etc:ro \
  -v /path/to/my_rules.yaml:/etc/falco/my_rules.yaml:ro \
  falcosecurity/falco:0.44.0 \
  falco -r /etc/falco/my_rules.yaml \
    -o json_output=true \
    -o json_include_output_fields_property=true \
    -M 120 && \
sleep 10 && \
docker logs falco-rule-test 2>&1 | grep -q "Opening 'syscall' source with modern BPF probe" && \
echo "=== BPF probe attached, running test commands ===" && \
echo "=== test commands here ===" && \
sleep 120 && \
docker logs falco-rule-test 2>&1 | grep '^{' > /tmp/alerts.json; \
docker logs falco-rule-test 2>&1 | grep "Events detected"
```

Key points:
- Use `-M 120` (2 minutes) or longer to allow enough room for BPF init (~5-10s) and test commands
- `sleep 10` after `docker run` gives the BPF probe time to attach
- The smoke test (`grep -q "Opening 'syscall' source"`) verifies BPF attached before proceeding
- The final `sleep` must be **longer** than the `-M` value to ensure Falco finishes before collection
- Use `;` (not `&&`) before collection commands -- `grep '^{'` returns exit code 1 when there are 0 alerts, which would break a `&&` chain
- Alternatively, omit `-M` (run indefinitely), use separate tool calls for test commands, then `docker stop` + collect

**WARNING: `grep` exit codes in chains.** `grep` returns exit code 1 when no lines match. In `&&` chains, this silently aborts all subsequent commands. Use `(grep ... || true)` or `;` instead of `&&` after any `grep` whose match count might be zero (smoke tests, alert collection, event counting).

## Troubleshooting

| Symptom | Likely Cause | Diagnostic Steps |
|---------|-------------|------------------|
| 0 events despite no errors | BPF probe failed to attach silently | Check `docker logs falco-rule-test 2>&1 \| grep -i bpf` for attachment messages. Restart the container with `--privileged`. On newer kernels (6.x+), individual capabilities may not suffice. |
| 0 events, stderr shows BPF errors | Kernel/driver incompatibility | Try `--privileged` instead of individual capabilities. Check kernel version with `uname -r`. Consider using replay mode with a `.scap` file instead. |
| Events detected but alerts.json is empty | Incorrect log collection method | Use `docker logs 2>&1 \| grep '^{'` instead of `docker logs 2>/dev/null`. Falco does not guarantee clean stdout/stderr separation. |
| Test commands not captured | Commands ran outside the `-M` window | Chain docker run + sleep + test commands + sleep + collection in a single shell command. Use `-M 120` or longer. See AI Agent Timing Guidance above. |
| `-M` summary shows events but JSON has fewer | Some events are non-JSON summary lines | The `-M` summary counts all events; JSON output only includes rule-matched alerts. This is expected behavior. |
| Chained command stops midway silently | `grep` exit code 1 when no matches | `grep` and `grep -c` return exit code 1 when no lines match. In `&&` chains, this aborts all subsequent commands. Use `(grep ... \|\| true)` or `;` instead of `&&` after any `grep` that might match zero lines. |
