# Falco Outputs

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falco/`](../../../refs/falcosecurity/falco/) | **Version:** 0.44.0

## Overview

Falco's output system delivers security alerts to various destinations when rules are triggered. The system uses a **multi-producer, single-consumer architecture** with an asynchronous message queue. When an event matches a rule, the alert is formatted and pushed to a concurrent queue, where a dedicated worker thread dispatches it to all configured output channels.

## Output Architecture

### Message Queue

The output system uses Intel TBB's `concurrent_bounded_queue` for thread-safe message passing (`falco_outputs.h:122`). Queue capacity is configured via `outputs_queue.capacity` (default: unbounded). When capacity is exceeded, events are dropped and logged.

```cpp
// falco_outputs.cpp:262-270
inline void falco_outputs::push(const ctrl_msg &cmsg) {
    if(!m_queue.try_push(cmsg)) {
        m_outputs_queue_num_drops++;
    }
}
```

### Worker Thread

A dedicated worker thread consumes messages and dispatches to all outputs with a watchdog timeout (`falco_outputs.cpp:281-308`):

```cpp
void falco_outputs::worker() noexcept {
    watchdog<std::string> wd;
    do {
        m_queue.pop(cmsg);  // Blocks until message available
        for(const auto &o : m_outputs) {
            wd.set_timeout(timeout, o->get_name());
            process_msg(o.get(), cmsg);
        }
    } while(cmsg.type != ctrl_msg_type::CTRL_MSG_STOP);
}
```

### Control Messages

Defined in `falco_outputs.h:110-115`:

| Message Type | Purpose |
|-------------|---------|
| `CTRL_MSG_STOP` | Terminates worker thread |
| `CTRL_MSG_OUTPUT` | Delivers alert to outputs |
| `CTRL_MSG_CLEANUP` | Flushes output buffers |
| `CTRL_MSG_REOPEN` | Closes and reopens outputs (log rotation) |

### Message Structure

Each output message contains (`outputs.h:43-51`):

| Field | Type | Description |
|-------|------|-------------|
| `ts` | uint64_t | Timestamp in nanoseconds |
| `priority` | priority_type | Alert severity |
| `msg` | string | Formatted output string |
| `rule` | string | Rule name that triggered |
| `source` | string | Event source |
| `fields` | json | Output field values |
| `tags` | set<string> | Rule tags |

## Output Channels

### stdout_output

Writes alerts to standard output (`outputs_stdout.cpp:21-32`). Uses `std::unitbuf` for unbuffered mode.

```yaml
stdout_output:
  enabled: true
```

### syslog_output

Sends alerts to system syslog (`outputs_syslog.cpp:21-24`). Priority maps directly to syslog priority. Linux/Unix only.

```yaml
syslog_output:
  enabled: true
```

### file_output

Writes alerts to a file (`outputs_file.cpp`). Opens in append mode. Supports `reopen()` for log rotation.

```yaml
file_output:
  enabled: true
  filename: /var/log/falco/events.log
  keep_alive: true  # Keep file open between writes
```

### http_output

Posts alerts as HTTP webhooks using libcurl (`outputs_http.cpp`). Sets `Content-Type` based on `json_output` setting.

```yaml
http_output:
  enabled: true
  url: http://webhook.endpoint/path
  user_agent: "falcosecurity/falco"
  insecure: false           # Skip TLS verification
  echo: false               # Echo response to stdout
  ca_cert: ""               # CA certificate file
  ca_path: "/etc/ssl/certs" # CA certificates directory
  mtls: false               # Enable mutual TLS
  client_cert: "/etc/ssl/certs/client.crt"
  client_key: "/etc/ssl/certs/client.key"
  compress_uploads: false   # Transfer encoding compression
  keep_alive: false         # TCP keep-alive
  max_consecutive_timeouts: 5
```

### program_output

Pipes alerts to an external program's stdin using `popen()` (`outputs_program.cpp`). Linux/Unix only.

```yaml
program_output:
  enabled: true
  program: "jq . >> /var/log/falco.json"
  keep_alive: true  # Keep pipe open between writes
```

### grpc_output (Removed in 0.44)

The `grpc_output` channel and the embedded gRPC server were removed in Falco 0.44.0 via [#3798](https://github.com/falcosecurity/falco/pull/3798). The `grpc:` and `grpc_output:` configuration sections no longer exist; `outputs_grpc.cpp`, `grpc_server.cpp`, and `outputs.proto` are no longer in `userspace/falco/`. Use the [`http_output`](#http_output) channel or [Falcosidekick](../falcosidekick/) instead.

## Message Format

### Text Format

Default format: `<timestamp>: <Priority> <formatted_rule_output>`

Example:
```
13:53:31.726060287: Critical Sensitive file opened (file=/etc/shadow proc_exe=cat)
```

Timestamp format controlled by `time_format_iso_8601` (default: `false`).

### JSON Format

Enabled via `json_output: true`. Structure (`formats.cpp:93-158`):

```json
{
  "time": "2024-01-15T13:53:31.726060287Z",
  "rule": "Read sensitive file",
  "priority": "Critical",
  "source": "syscall",
  "hostname": "node-1",
  "output": "13:53:31.726060287: Critical Sensitive file opened...",
  "tags": ["filesystem", "mitre_credential_access"],
  "output_fields": {
    "fd.name": "/etc/shadow",
    "proc.name": "cat"
  }
}
```

### JSON Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `json_output` | `false` | Enable JSON output format |
| `json_include_output_property` | `true` | Include `output` string |
| `json_include_tags_property` | `true` | Include `tags` array |
| `json_include_message_property` | `false` | Include `message` (without timestamp/priority) |
| `json_include_output_fields_property` | `true` | Include `output_fields` object |

### Priority Levels

Defined in `falco_common.h:50-59`:

| Priority | Value | Syslog Equivalent |
|----------|-------|-------------------|
| EMERGENCY | 0 | LOG_EMERG |
| ALERT | 1 | LOG_ALERT |
| CRITICAL | 2 | LOG_CRIT |
| ERROR | 3 | LOG_ERR |
| WARNING | 4 | LOG_WARNING |
| NOTICE | 5 | LOG_NOTICE |
| INFORMATIONAL | 6 | LOG_INFO |
| DEBUG | 7 | LOG_DEBUG |

## Extra Output Fields

Additional fields can be injected into rule outputs programmatically via `falco_engine`:

- **`add_extra_output_format()`** - Appends format string to rule output
- **`add_extra_output_formatted_field()`** - Adds a formatted field to `output_fields`
- **`add_extra_output_raw_field()`** - Adds a raw field value (preserves original type)

Each accepts parameters for filtering by source, tags, and rule name.

## Timeout and Buffering

**`output_timeout`** (default: 2000ms) - Watchdog timeout for slow outputs. When exceeded, a CRITICAL log is emitted but the output continues.

**`buffered_outputs`** (default: `false`) - Controls output buffering:
- `false`: Unbuffered - each alert flushed immediately
- `true`: Buffered - relies on system/library buffering
- Override via CLI: `falco -U` (unbuffered)

## Sources

| Topic | Source File |
|-------|-------------|
| Output interface | [`userspace/falco/falco_outputs.h`](../../../refs/falcosecurity/falco/userspace/falco/falco_outputs.h) |
| Output implementation | [`userspace/falco/falco_outputs.cpp`](../../../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp) |
| Abstract output base | [`userspace/falco/outputs.h`](../../../refs/falcosecurity/falco/userspace/falco/outputs.h) |
| stdout output | [`userspace/falco/outputs_stdout.cpp`](../../../refs/falcosecurity/falco/userspace/falco/outputs_stdout.cpp) |
| syslog output | [`userspace/falco/outputs_syslog.cpp`](../../../refs/falcosecurity/falco/userspace/falco/outputs_syslog.cpp) |
| file output | [`userspace/falco/outputs_file.cpp`](../../../refs/falcosecurity/falco/userspace/falco/outputs_file.cpp) |
| HTTP webhook | [`userspace/falco/outputs_http.cpp`](../../../refs/falcosecurity/falco/userspace/falco/outputs_http.cpp) |
| program pipe | [`userspace/falco/outputs_program.cpp`](../../../refs/falcosecurity/falco/userspace/falco/outputs_program.cpp) |
| Output formatting | [`userspace/engine/formats.cpp`](../../../refs/falcosecurity/falco/userspace/engine/formats.cpp) |
| Configuration | [`userspace/falco/configuration.cpp`](../../../refs/falcosecurity/falco/userspace/falco/configuration.cpp) |
