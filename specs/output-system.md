# Output System

> Alert delivery architecture: output channels, async message queue, formatting, control messages, and timeout handling.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco/userspace/falco/`](../refs/falcosecurity/falco/userspace/falco/)

## Overview

The Falco output system delivers security alerts to configured destinations when rules are triggered. It implements a **multi-producer, single-consumer architecture** using Intel TBB's `concurrent_bounded_queue` for thread-safe asynchronous message passing. When the rule engine matches an event, the alert is formatted into a message and pushed to a concurrent queue, where a dedicated worker thread dispatches it to all configured output channels.

The system is orchestrated by the `falco_outputs` class, which owns the message queue, the worker thread, and all output channel instances. Formatting is delegated to the `falco_formats` class, which uses `sinsp_evt_formatter` from libsinsp to interpolate field values into output templates.

**Source:** [`falco_outputs.h:32-40`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.h), [`falco_outputs.cpp`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp), [`digests/falcosecurity/falco/outputs.md`](../digests/falcosecurity/falco/outputs.md)

## Architecture

### Message Queue

The output system uses Intel TBB's `concurrent_bounded_queue<ctrl_msg>` for thread-safe message passing between producers (the main event processing thread, signal handlers, etc.) and the single consumer (the worker thread).

```cpp
// falco_outputs.h:122-123
typedef tbb::concurrent_bounded_queue<ctrl_msg> falco_outputs_cbq;
falco_outputs_cbq m_queue;
```

Queue capacity is set during construction via the `outputs_queue_capacity` parameter, which maps to the `outputs_queue.capacity` configuration option. The default is unbounded (`std::ptrdiff_t(~size_t(0) / 2)`), defined in [`falco_common.h:29`](../refs/falcosecurity/falco/userspace/engine/falco_common.h).

```cpp
// falco_outputs.cpp:70
m_queue.set_capacity(outputs_queue_capacity);
```

When the queue is at capacity, `try_push()` fails and the event is dropped. A drop counter tracks lost messages, and the first drop is logged as an error:

```cpp
// falco_outputs.cpp:262-270
inline void falco_outputs::push(const ctrl_msg &cmsg) {
    if(!m_queue.try_push(cmsg)) {
        if(m_outputs_queue_num_drops.load() == 0) {
            falco_logger::log(falco_logger::level::ERR,
                              "Outputs queue out of memory. Drop event and continue on ...");
        }
        m_outputs_queue_num_drops++;
    }
}
```

The drop count is exposed via `get_outputs_queue_num_drops()` ([`falco_outputs.cpp:328-330`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)) for metrics collection.

**Source:** [`falco_outputs.h:121-126`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.h), [`falco_outputs.cpp:262-276`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)

### Worker Thread

A dedicated worker thread is spawned in the constructor and runs the `worker()` method. It blocks on `m_queue.pop()` until a message is available, then dispatches it to every configured output channel via `process_msg()`. A watchdog monitors each output's processing time:

```cpp
// falco_outputs.cpp:281-308
void falco_outputs::worker() noexcept {
    watchdog<std::string> wd;
    wd.start([&](const std::string &payload) -> void {
        falco_logger::log(falco_logger::level::CRIT,
                          "\"" + payload + "\" output timeout, all output channels are blocked\n");
    });

    auto timeout = m_timeout;

    falco_outputs::ctrl_msg cmsg;
    do {
        m_queue.pop(cmsg);  // Blocks until message available

        for(const auto &o : m_outputs) {
            wd.set_timeout(timeout, o->get_name());
            try {
                process_msg(o.get(), cmsg);
            } catch(const std::exception &e) {
                falco_logger::log(falco_logger::level::ERR,
                                  o->get_name() + ": " + std::string(e.what()) + "\n");
            }
        }
        wd.cancel_timeout();
    } while(cmsg.type != ctrl_msg_type::CTRL_MSG_STOP);
}
```

The `process_msg()` method dispatches based on control message type ([`falco_outputs.cpp:310-326`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)):

```cpp
// falco_outputs.cpp:310-326
inline void falco_outputs::process_msg(falco::outputs::abstract_output *o,
                                        const ctrl_msg &cmsg) {
    switch(cmsg.type) {
    case ctrl_msg_type::CTRL_MSG_OUTPUT:
        o->output(&cmsg);
        break;
    case ctrl_msg_type::CTRL_MSG_CLEANUP:
    case ctrl_msg_type::CTRL_MSG_STOP:
        o->cleanup();
        break;
    case ctrl_msg_type::CTRL_MSG_REOPEN:
        o->reopen();
        break;
    }
}
```

The worker thread is marked `noexcept`; an uncaught exception terminates the program. The `stop_worker()` method sends a `CTRL_MSG_STOP` message and joins the worker thread, using its own watchdog to handle the case where outputs are blocked ([`falco_outputs.cpp:237-254`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)).

**Source:** [`falco_outputs.cpp:281-326`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)

### Control Messages

The queue carries `ctrl_msg` values, which extend the `falco::outputs::message` struct with a type discriminator. The control message types are defined in [`falco_outputs.h:110-115`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.h):

| Message Type | Value | Purpose | Worker Action |
|-------------|-------|---------|---------------|
| `CTRL_MSG_STOP` | 0 | Terminates worker thread | Calls `cleanup()` on each output, then exits loop |
| `CTRL_MSG_OUTPUT` | 1 | Delivers an alert to all outputs | Calls `output()` on each output |
| `CTRL_MSG_CLEANUP` | 2 | Flushes output buffers | Calls `cleanup()` on each output |
| `CTRL_MSG_REOPEN` | 3 | Closes and reopens outputs (log rotation) | Calls `reopen()` on each output |

```cpp
// falco_outputs.h:110-119
enum ctrl_msg_type {
    CTRL_MSG_STOP = 0,
    CTRL_MSG_OUTPUT = 1,
    CTRL_MSG_CLEANUP = 2,
    CTRL_MSG_REOPEN = 3,
};

struct ctrl_msg : falco::outputs::message {
    ctrl_msg_type type;
};
```

Control messages (non-OUTPUT) are sent via the helper `push_ctrl()` ([`falco_outputs.cpp:256-260`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)), which creates an empty message with only the type field set.

**Source:** [`falco_outputs.h:110-119`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.h)

### Message Structure

Each output message is defined in [`outputs.h:43-51`](../refs/falcosecurity/falco/userspace/falco/outputs.h):

```cpp
// outputs.h:43-51
struct message {
    uint64_t ts;
    falco_common::priority_type priority;
    std::string msg;
    std::string rule;
    std::string source;
    nlohmann::json fields;
    std::set<std::string> tags;
};
```

| Field | Type | Description |
|-------|------|-------------|
| `ts` | `uint64_t` | Event timestamp in nanoseconds since epoch |
| `priority` | `falco_common::priority_type` | Alert severity level (0-7) |
| `msg` | `std::string` | Fully formatted output string (text or JSON) |
| `rule` | `std::string` | Name of the matched rule |
| `source` | `std::string` | Event source (e.g., `"syscall"`, `"k8s_audit"`, or `"internal"`) |
| `fields` | `nlohmann::json` | Key-value map of output field values |
| `tags` | `std::set<std::string>` | Set of tags from the matched rule |

Messages are populated by two entry points:
- **`handle_event()`** ([`falco_outputs.cpp:120-164`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)) -- formats a rule-matched event via `falco_formats::format_event()` and extracts field values
- **`handle_msg()`** ([`falco_outputs.cpp:166-227`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)) -- formats a generic (internal) message, e.g., drop alerts; uses source `"internal"`

**Source:** [`outputs.h:43-51`](../refs/falcosecurity/falco/userspace/falco/outputs.h), [`falco_outputs.cpp:120-227`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)

## Implementation Details

### Output Channels

All output channels inherit from `falco::outputs::abstract_output` ([`outputs.h:58-93`](../refs/falcosecurity/falco/userspace/falco/outputs.h)), which defines the interface:

```cpp
// outputs.h:58-93
class abstract_output {
public:
    virtual bool init(const config& oc, bool buffered,
                      const std::string& hostname, bool json_output,
                      std::string& err);
    const std::string& get_name() const;
    virtual void output(const message* msg) = 0;  // Pure virtual
    virtual void reopen() {}                       // No-op default
    virtual void cleanup() {}                      // No-op default
protected:
    config m_oc;       // Output configuration (name + options map)
    bool m_buffered;
    std::string m_hostname;
    bool m_json_output;
};
```

Output channels are instantiated at construction time by `add_output()` ([`falco_outputs.cpp:82-118`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)), which maps the config name to a concrete class. Platform availability varies:

| Channel | Class | Platforms |
|---------|-------|-----------|
| `stdout` | `output_stdout` | All |
| `file` | `output_file` | All |
| `syslog` | `output_syslog` | Linux/Unix (not Windows) |
| `program` | `output_program` | Linux/Unix (not Windows) |
| `http` | `output_http` | All platforms (not Emscripten, not MINIMAL_BUILD). Since 0.44, also built on macOS and Windows ([PR #3827](https://github.com/falcosecurity/falco/pull/3827)) |

**Source:** [`falco_outputs.cpp:82-118`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)

#### stdout_output

Writes alerts to standard output. Uses `std::unitbuf` for unbuffered mode (set on every write since other stdout writes may disable it). Flushes on `cleanup()`.

```cpp
// outputs_stdout.cpp:21-32
void falco::outputs::output_stdout::output(const message *msg) {
    if(!m_buffered) {
        std::cout << std::unitbuf;
    }
    std::cout << msg->msg + "\n";
}
```

Configuration:
```yaml
stdout_output:
  enabled: true
```

**Source:** [`outputs_stdout.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_stdout.cpp)

#### syslog_output

Sends alerts to the system syslog via the POSIX `syslog()` function. The message `priority` field maps directly to syslog priority levels (the enum values in [`falco_common.h:50-59`](../refs/falcosecurity/falco/userspace/engine/falco_common.h) are numerically equivalent to `LOG_EMERG` through `LOG_DEBUG`). No trailing newline is appended.

```cpp
// outputs_syslog.cpp:21-24
void falco::outputs::output_syslog::output(const message *msg) {
    ::syslog(msg->priority, "%s", msg->msg.c_str());
}
```

Configuration:
```yaml
syslog_output:
  enabled: true
```

**Source:** [`outputs_syslog.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_syslog.cpp)

#### file_output

Writes alerts to a file in append mode using `std::fstream`. Supports `keep_alive` to keep the file open between writes (default: close after each write). Supports `reopen()` for log rotation (close then reopen). When unbuffered, the stream buffer size is set to 0 via `pubsetbuf(0, 0)`.

```cpp
// outputs_file.cpp:22-32
void falco::outputs::output_file::open_file() {
    if(!m_buffered) {
        m_outfile.rdbuf()->pubsetbuf(0, 0);
    }
    if(!m_outfile.is_open()) {
        m_outfile.open(m_oc.options["filename"], std::fstream::app);
    }
}

// outputs_file.cpp:34-41
void falco::outputs::output_file::output(const message *msg) {
    open_file();
    m_outfile << msg->msg + "\n";
    if(m_oc.options["keep_alive"] != "true") {
        cleanup();
    }
}
```

Configuration:
```yaml
file_output:
  enabled: true
  filename: /var/log/falco/events.log
  keep_alive: true
```

**Source:** [`outputs_file.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_file.cpp)

#### http_output

Posts alerts as HTTP webhooks using libcurl. Sets `Content-Type` based on the `json_output` configuration: `application/json` when JSON output is enabled, `text/plain` otherwise. Supports TLS verification, mutual TLS (mTLS), CA certificates, transfer encoding compression, and TCP keep-alive.

On each alert, the message string is set as the POST body via `CURLOPT_POSTFIELDS` and `curl_easy_perform()` is called. If the request times out (`CURLE_OPERATION_TIMEDOUT`), it retries up to `max_consecutive_timeouts` times (default: 5).

```cpp
// outputs_http.cpp:109-126
void falco::outputs::output_http::output(const message *msg) {
    CURLcode res = curl_easy_setopt(m_curl, CURLOPT_POSTFIELDS, msg->msg.c_str());
    uint8_t curl_easy_platform_calls = 0;
    if(res == CURLE_OK) {
        do {
            res = curl_easy_perform(m_curl);
            curl_easy_platform_calls++;
        } while(res == CURLE_OPERATION_TIMEDOUT &&
                curl_easy_platform_calls <= m_max_consecutive_timeouts);
    }
}
```

The `init()` method ([`outputs_http.cpp:31-107`](../refs/falcosecurity/falco/userspace/falco/outputs_http.cpp)) configures all curl options from the config map. URL quoting is automatically stripped. When `echo` is `false` (default), a no-op write callback suppresses response output to stdout.

Configuration:
```yaml
http_output:
  enabled: true
  url: http://webhook.endpoint/path
  user_agent: "falcosecurity/falco"
  insecure: false
  echo: false
  ca_cert: ""
  ca_bundle: ""
  ca_path: "/etc/ssl/certs"
  mtls: false
  client_cert: "/etc/ssl/certs/client.crt"
  client_key: "/etc/ssl/certs/client.key"
  compress_uploads: false
  keep_alive: false
  max_consecutive_timeouts: 5
```

| Option | curl Equivalent | Description |
|--------|----------------|-------------|
| `url` | `CURLOPT_URL` | Target webhook URL |
| `user_agent` | `CURLOPT_USERAGENT` | HTTP User-Agent header |
| `insecure` | `CURLOPT_SSL_VERIFYPEER=0` | Skip TLS certificate verification |
| `mtls` | `CURLOPT_SSLCERT` + `CURLOPT_SSLKEY` | Mutual TLS with client certificate/key |
| `ca_cert` | `CURLOPT_CAINFO` | CA certificate file for verification |
| `ca_bundle` | `CURLOPT_CAINFO` | CA bundle file (fallback for `ca_cert`) |
| `ca_path` | `CURLOPT_CAPATH` | CA certificates directory (fallback) |
| `echo` | `CURLOPT_WRITEFUNCTION` | Echo HTTP response to stdout when `true` |
| `compress_uploads` | `CURLOPT_TRANSFER_ENCODING` | Enable transfer encoding compression |
| `keep_alive` | `CURLOPT_TCP_KEEPALIVE` | Enable TCP keep-alive |
| `max_consecutive_timeouts` | N/A | Max retry count on `CURLE_OPERATION_TIMEDOUT` |

**Source:** [`outputs_http.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_http.cpp)

#### program_output

Pipes alerts to an external program's stdin using `popen()` in write mode. When unbuffered, `setvbuf()` is set to `_IONBF` (no buffering). Supports `keep_alive` to keep the pipe open between writes. The `reopen()` method closes and reopens the pipe, which can be used if the child process terminates.

```cpp
// outputs_program.cpp:41-51
void falco::outputs::output_program::output(const message *msg) {
    open_pfile();
    if(m_pfile != nullptr) {
        fprintf(m_pfile, "%s\n", msg->msg.c_str());
    }
    if(m_oc.options["keep_alive"] != "true") {
        cleanup();
    }
}
```

Configuration:
```yaml
program_output:
  enabled: true
  program: "jq . >> /var/log/falco.json"
  keep_alive: true
```

**Source:** [`outputs_program.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_program.cpp)

### Message Format

#### Text Format

The default text format is: `<timestamp>: <Priority> <formatted_rule_output>`

The prefix is constructed by `falco_formats::format_event()` ([`formats.cpp:38-73`](../refs/falcosecurity/falco/userspace/engine/formats.cpp)):

```cpp
// formats.cpp:49-54
if(m_time_format_iso_8601) {
    prefix_format = "*%evt.time.iso8601: ";
} else {
    prefix_format = "*%evt.time: ";
}
prefix_format += level;
```

The `*` prefix on format strings tells `sinsp_evt_formatter` to resolve the format even if some fields are not present. The complete output is `prefix + " " + message`, where `message` is the rule's `output` string with field placeholders resolved.

Example:
```
13:53:31.726060287: Critical Sensitive file opened (file=/etc/shadow proc_exe=cat)
```

With `time_format_iso_8601: true`:
```
2024-01-15T13:53:31.726060287+0000: Critical Sensitive file opened (file=/etc/shadow proc_exe=cat)
```

**Source:** [`formats.cpp:38-73`](../refs/falcosecurity/falco/userspace/engine/formats.cpp)

#### JSON Format

When `json_output: true`, `format_event()` produces a complete JSON object ([`formats.cpp:77-158`](../refs/falcosecurity/falco/userspace/engine/formats.cpp)). The timestamp is always in ISO 8601 format with nanosecond precision:

```json
{
  "time": "2024-01-15T13:53:31.726060287Z",
  "rule": "Read sensitive file",
  "priority": "Critical",
  "source": "syscall",
  "hostname": "node-1",
  "output": "13:53:31.726060287: Critical Sensitive file opened...",
  "tags": ["filesystem", "mitre_credential_access"],
  "message": "Sensitive file opened...",
  "output_fields": {
    "fd.name": "/etc/shadow",
    "proc.name": "cat"
  }
}
```

The inclusion of individual JSON properties is controlled by configuration flags:

| Config Option | Default | JSON Property | Description |
|--------------|---------|---------------|-------------|
| `json_output` | `false` | N/A | Enables JSON format for all outputs |
| `json_include_output_property` | `true` | `output` | Include the full text output string |
| `json_include_tags_property` | `true` | `tags` | Include the rule tags array |
| `json_include_message_property` | `false` | `message` | Include the message without timestamp/priority prefix |
| `json_include_output_fields_property` | `true` | `output_fields` | Include the structured field values |

The `time`, `rule`, `priority`, `source`, and `hostname` properties are always included when JSON output is enabled.

**Source:** [`formats.cpp:77-158`](../refs/falcosecurity/falco/userspace/engine/formats.cpp), [`formats.h`](../refs/falcosecurity/falco/userspace/engine/formats.h)

### Output Formatting

#### Template System

Rule output strings use a template system where `%field.name` placeholders are interpolated with actual event values. Formatting is handled by `sinsp_evt_formatter` from libsinsp, accessed through `falco_engine::create_formatter()`.

The `falco_formats` class ([`formats.h`](../refs/falcosecurity/falco/userspace/engine/formats.h)) provides three formatting methods:

| Method | Purpose |
|--------|---------|
| `format_event()` | Produces the complete output for a rule-matched event (text or JSON) |
| `format_string()` | Resolves a format string against an event (always text mode) |
| `get_field_values()` | Extracts a map of field name to string value for a format |

Example rule output template:
```
Sensitive file opened (file=%fd.name proc_exe=%proc.exepath proc_name=%proc.name)
```

Resolves to:
```
Sensitive file opened (file=/etc/shadow proc_exe=/usr/bin/cat proc_name=cat)
```

**Source:** [`formats.h`](../refs/falcosecurity/falco/userspace/engine/formats.h), [`formats.cpp`](../refs/falcosecurity/falco/userspace/engine/formats.cpp)

#### Extra Output Fields

Additional fields can be injected into rule outputs programmatically via the `falco_engine` API. Each extra field is specified as a pair of `(format_string, is_raw)` keyed by field name.

The type is defined in [`falco_common.h:71`](../refs/falcosecurity/falco/userspace/engine/falco_common.h):

```cpp
typedef std::unordered_map<std::string, std::pair<std::string, bool>> extra_output_field_t;
```

| API Method | Description |
|-----------|-------------|
| `add_extra_output_format()` | Appends a format string to rule output text |
| `add_extra_output_formatted_field()` | Adds a formatted field to `output_fields` (`is_raw=false`) |
| `add_extra_output_raw_field()` | Adds a raw field that preserves its original type in JSON (`is_raw=true`) |

Each method accepts optional filters for source, tags, and rule name. In `handle_event()`, extra fields are resolved and merged into the `fields` map of the control message ([`falco_outputs.cpp:142-156`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)). In JSON mode, raw fields are formatted with `OF_JSON` to preserve type information, while formatted fields are always strings ([`formats.cpp:133-155`](../refs/falcosecurity/falco/userspace/engine/formats.cpp)).

**Source:** [`falco_common.h:71`](../refs/falcosecurity/falco/userspace/engine/falco_common.h), [`falco_outputs.cpp:142-156`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp), [`formats.cpp:133-155`](../refs/falcosecurity/falco/userspace/engine/formats.cpp)

### Priority Levels

Priority levels are defined in [`falco_common.h:50-59`](../refs/falcosecurity/falco/userspace/engine/falco_common.h). The numeric values are intentionally aligned with syslog priority levels:

```cpp
// falco_common.h:50-59
enum priority_type {
    PRIORITY_EMERGENCY = 0,
    PRIORITY_ALERT = 1,
    PRIORITY_CRITICAL = 2,
    PRIORITY_ERROR = 3,
    PRIORITY_WARNING = 4,
    PRIORITY_NOTICE = 5,
    PRIORITY_INFORMATIONAL = 6,
    PRIORITY_DEBUG = 7
};
```

| Priority | Value | Syslog Equivalent | Use Case |
|----------|-------|-------------------|----------|
| EMERGENCY | 0 | `LOG_EMERG` | System unusable |
| ALERT | 1 | `LOG_ALERT` | Immediate action required |
| CRITICAL | 2 | `LOG_CRIT` | Critical conditions (e.g., sensitive file access) |
| ERROR | 3 | `LOG_ERR` | Error conditions |
| WARNING | 4 | `LOG_WARNING` | Warning conditions |
| NOTICE | 5 | `LOG_NOTICE` | Normal but significant |
| INFORMATIONAL | 6 | `LOG_INFO` | Informational messages |
| DEBUG | 7 | `LOG_DEBUG` | Debug-level messages |

The `format_priority()` and `parse_priority()` helper functions convert between enum values and string representations ([`falco_common.h:61-64`](../refs/falcosecurity/falco/userspace/engine/falco_common.h)).

**Source:** [`falco_common.h:50-64`](../refs/falcosecurity/falco/userspace/engine/falco_common.h)

### Timeout and Buffering

#### Output Timeout

The `output_timeout` configuration option (default: 2000ms) controls the watchdog timeout for each output channel. The watchdog is implemented as a template class ([`watchdog.h`](../refs/falcosecurity/falco/userspace/falco/watchdog.h)) that runs a separate monitoring thread. When any output's `process_msg()` call exceeds the timeout, a CRITICAL log is emitted identifying the blocked output, but processing continues (the alert is not retried or skipped):

```cpp
// falco_outputs.cpp:283-286
wd.start([&](const std::string &payload) -> void {
    falco_logger::log(falco_logger::level::CRIT,
                      "\"" + payload + "\" output timeout, all output channels are blocked\n");
});
```

The watchdog uses a polling resolution of 100ms ([`watchdog.h:31`](../refs/falcosecurity/falco/userspace/falco/watchdog.h)).

During shutdown, a separate watchdog monitors the stop operation. If the worker thread does not stop within the timeout period, the queue is cleared and a new stop message is pushed ([`falco_outputs.cpp:237-254`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)).

#### Buffered Outputs

The `buffered_outputs` configuration option (default: `false`) controls whether output channels buffer their writes:

- **`false` (unbuffered)**: Each alert is flushed immediately after being written. This is the default to minimize alert delivery latency.
- **`true` (buffered)**: Output relies on system or library buffering mechanisms.

The CLI flag `falco -U` forces unbuffered mode regardless of the configuration.

Per-channel buffering behavior:
- **stdout**: Sets `std::unitbuf` manipulator on each write ([`outputs_stdout.cpp:28-29`](../refs/falcosecurity/falco/userspace/falco/outputs_stdout.cpp))
- **file**: Sets stream buffer size to 0 via `pubsetbuf(0, 0)` ([`outputs_file.cpp:23-24`](../refs/falcosecurity/falco/userspace/falco/outputs_file.cpp))
- **program**: Sets `setvbuf()` to `_IONBF` ([`outputs_program.cpp:36`](../refs/falcosecurity/falco/userspace/falco/outputs_program.cpp))
- **syslog**: Syslog handles its own buffering; the option has no effect
- **http**: HTTP sends each message as a separate POST; the option has no effect

**Source:** [`watchdog.h`](../refs/falcosecurity/falco/userspace/falco/watchdog.h), [`falco_outputs.cpp:237-254`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp), [`falco_outputs.cpp:281-308`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)

## Removed Features

| Feature | Status | Notes |
|---------|--------|-------|
| gRPC output (`grpc_output`) | **Removed in 0.44** ([PR #3798](https://github.com/falcosecurity/falco/pull/3798)) | The `output_grpc` channel, `outputs.proto`, and supporting protobuf/gRPC code paths were deleted entirely. The `grpc_output` configuration block is no longer recognized. Use `http_output` (now also available on macOS/Windows) or [Falcosidekick](https://github.com/falcosecurity/falcosidekick) as a replacement. |
| gRPC server (`grpc.enabled`) | **Removed in 0.44** ([PR #3798](https://github.com/falcosecurity/falco/pull/3798)) | The embedded gRPC server that previously hosted `grpc_output` is no longer built or shipped. See [proposal 20251215](../refs/falcosecurity/falco/proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md). |

## Related Specs

- [`architecture-overview.md`](architecture-overview.md) -- System architecture and event pipeline; shows where `falco_outputs` fits in the overall flow
- [`rule-engine.md`](rule-engine.md) -- Rule compilation and matching; produces the events and format strings consumed by the output system
- [`configuration.md`](configuration.md) -- Configuration system; output options and JSON settings
- [`application-lifecycle.md`](application-lifecycle.md) -- Application orchestration; controls output initialization, SIGHUP reopen, and shutdown

## Sources

| Topic | Source File |
|-------|-------------|
| Output interface | [`falco_outputs.h`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.h) |
| Output implementation | [`falco_outputs.cpp`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp) |
| Abstract output base | [`outputs.h`](../refs/falcosecurity/falco/userspace/falco/outputs.h) |
| stdout output | [`outputs_stdout.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_stdout.cpp) |
| syslog output | [`outputs_syslog.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_syslog.cpp) |
| file output | [`outputs_file.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_file.cpp) |
| HTTP webhook | [`outputs_http.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_http.cpp) |
| program pipe | [`outputs_program.cpp`](../refs/falcosecurity/falco/userspace/falco/outputs_program.cpp) |
| Formatting engine | [`formats.h`](../refs/falcosecurity/falco/userspace/engine/formats.h) |
| Formatting implementation | [`formats.cpp`](../refs/falcosecurity/falco/userspace/engine/formats.cpp) |
| Priority definitions | [`falco_common.h`](../refs/falcosecurity/falco/userspace/engine/falco_common.h) |
| Watchdog timer | [`watchdog.h`](../refs/falcosecurity/falco/userspace/falco/watchdog.h) |
| Configuration | [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp) |
| Digest | [`digests/falcosecurity/falco/outputs.md`](../digests/falcosecurity/falco/outputs.md) |
