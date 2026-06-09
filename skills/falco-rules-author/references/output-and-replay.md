# Falco Output and Replay Testing Reference

Understanding Falco alert output formats and testing with .scap replay files.

---

## Understanding Falco Output

**Source:** [`specs/output-system.md`](../../../specs/output-system.md)

### Text Alert Format

Default format (when `json_output: false`):

```
<timestamp>: <Priority> <output_message>
```

Example:
```
17:48:41.725822389: Warning Suspicious process spawned (user=root command=bash pid=12345 parent=sshd container=host)
```

### JSON Alert Structure

When `json_output: true`:

```json
{
  "time": "2026-01-28T17:48:41.725822389+0000",
  "rule": "Terminal shell in container",
  "priority": "Notice",
  "source": "syscall",
  "hostname": "node-1",
  "output": "A shell was spawned in a container (evt_type=execve user=root ...)",
  "tags": ["container", "shell", "mitre_execution"],
  "output_fields": {
    "evt.type": "execve",
    "user.name": "root",
    "proc.name": "bash",
    "proc.cmdline": "bash",
    "proc.pname": "docker-runc",
    "container.id": "abc123def456",
    "container.name": "my-app"
  }
}
```

| JSON Field | Description |
|------------|-------------|
| `time` | Event timestamp (ISO 8601 when `time_format_iso_8601: true`) |
| `rule` | Name of the matched rule |
| `priority` | Priority level string |
| `source` | Event source (`syscall`, plugin name, or `internal`) |
| `hostname` | Hostname of the machine where Falco is running |
| `output` | Formatted output string (from rule's `output:` field) |
| `tags` | Array of tags from the rule |
| `output_fields` | Key-value map of interpolated field values (when `json_include_output_fields_property: true`) |

### Priority Filtering

Set minimum priority to reduce noise during testing:

```bash
# Only show WARNING and above
falco -o priority=warning
```

---

## Testing with .scap Files (Replay Engine)

### What .scap Files Contain

`.scap` files store captured system events and process state. They include:

- **Metadata blocks**: Machine info, process list (with full thread state, cgroups, capabilities), file descriptor lists, interface/user lists
- **Event blocks**: Timestamped syscall events with thread ID, event type, and parameters

This means replay can reconstruct process ancestry, container context, and file descriptor state -- enabling realistic rule evaluation.

**Source:** [`digests/falcosecurity/libs/scap-file-format.md`](../../../digests/falcosecurity/libs/scap-file-format.md)

### Configuring the Replay Engine

Create a configuration override or use `-o` flags:

```yaml
engine:
  kind: replay
  replay:
    capture_file: "/path/to/capture.scap"
```

### Running Replay via CLI

```bash
# Replay a .scap file with custom rules
falco -c /etc/falco/falco.yaml \
  -o "engine.kind=replay" \
  -o "engine.replay.capture_file=/path/to/capture.scap" \
  -r /path/to/my_rules.yaml \
  -o json_output=true
```

### Running Replay in Docker

```bash
docker run --rm \
  -v /path/to/capture.scap:/capture.scap:ro \
  -v /path/to/my_rules.yaml:/my_rules.yaml:ro \
  falcosecurity/falco:0.44.0 \
  falco \
    -o "engine.kind=replay" \
    -o "engine.replay.capture_file=/capture.scap" \
    -r /etc/falco/falco_rules.yaml \
    -r /my_rules.yaml \
    -o json_output=true \
    -o json_include_output_fields_property=true
```

### Where to Find .scap Test Files

The Falco testing infrastructure provides capture files:

- **Testing repository:** The [`testing`](../../../digests/falcosecurity/testing.md) repository contains `.scap` files in `tests/data/captures/`
- **Download URL pattern:** `https://download.falco.org/fixtures/trace-files/`

### Capturing .scap Files with Falco

Falco supports event capture during live monitoring. Configure the `capture` section:

```yaml
capture:
  enabled: true
  path_prefix: /tmp/falco
  mode: all_rules        # Capture when any rule triggers
  default_duration: 5000 # Duration in milliseconds
```

| Capture Mode | Behavior |
|-------------|----------|
| `rules` | Capture only when rules with `capture: true` trigger |
| `all_rules` | Capture when any enabled rule triggers |

---

## JSON Output Configuration

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
