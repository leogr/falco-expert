# Plugin System

> Plugin API, five capabilities, lifecycle, state table access, thread pool, field definitions, and official plugins.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/libs/userspace/plugin/`](../refs/falcosecurity/libs/userspace/plugin/)

## Overview

The Falco plugin system extends the capabilities of libs beyond syscall events through a well-defined C API. Plugins are dynamically loaded shared libraries that can generate events from external sources, extract new filterable fields, parse events to maintain state, inject asynchronous events, and react to capture lifecycle changes.

- **Plugin API Version:** 3.12.0
- **Event Schema Version:** 4.1.0
- **Maximum Error Length:** 1024 characters (`PLUGIN_MAX_ERRLEN`)

The plugin API is backward compatible within the same major version. Plugins declare their required API version via `get_required_api_version()`, and the framework validates compatibility at load time.

**Source:** [`digests/falcosecurity/libs/plugin-framework.md`](../digests/falcosecurity/libs/plugin-framework.md)

## Architecture

### Capability Model

Plugins implement one or more capabilities by exporting the corresponding function pointers. All plugins must implement the base functions (lifecycle, info, error handling). Capabilities are additive and can be freely combined.

| Capability | Description | Required Functions |
|------------|-------------|-------------------|
| **SOURCING** | Generate events from external sources (cloud APIs, logs, message queues) | `get_id`, `get_event_source`, `open`, `close`, `next_batch` |
| **EXTRACTION** | Extract typed fields from events for use in rule conditions and output | `get_fields`, `extract_fields` |
| **PARSING** | Parse events and maintain state (e.g., update state tables) | `parse_event` |
| **ASYNC** | Inject events asynchronously into the event stream from background threads | `get_async_events`, `set_async_event_handler` |
| **CAPTURE_LISTENING** | React to capture start/stop to perform setup/teardown | `capture_open`, `capture_close` |

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h)

### Plugin API Structure

The full `plugin_api` struct defines all function pointers organized by capability. This is the contract between the plugin framework and loaded plugins.

```c
// From plugin_api.h
typedef struct {
    // Required: API version
    const char* (*get_required_api_version)();

    // Optional: Configuration schema
    const char* (*get_init_schema)(ss_plugin_schema_type* schema_type);

    // Required: Lifecycle
    ss_plugin_t* (*init)(const ss_plugin_init_input* input, ss_plugin_rc* rc);
    void (*destroy)(ss_plugin_t* s);

    // Required: Error handling
    const char* (*get_last_error)(ss_plugin_t* s);

    // Required: Plugin info
    const char* (*get_name)();
    const char* (*get_description)();
    const char* (*get_contact)();
    const char* (*get_version)();

    // Event sourcing capability
    struct {
        uint32_t (*get_id)();
        const char* (*get_event_source)();
        ss_instance_t* (*open)(ss_plugin_t* s, const char* params, ss_plugin_rc* rc);
        void (*close)(ss_plugin_t* s, ss_instance_t* h);
        const char* (*list_open_params)(ss_plugin_t* s, ss_plugin_rc* rc);
        const char* (*get_progress)(ss_plugin_t* s, ss_instance_t* h, uint32_t* progress_pct);
        const char* (*event_to_string)(ss_plugin_t* s, const ss_plugin_event_input* evt);
        ss_plugin_rc (*next_batch)(ss_plugin_t* s, ss_instance_t* h,
                                    uint32_t* nevts, ss_plugin_event*** evts);
    };

    // Field extraction capability
    struct {
        uint16_t* (*get_extract_event_types)(uint32_t* numtypes, ss_plugin_t* s);
        const char* (*get_extract_event_sources)();
        const char* (*get_fields)();
        ss_plugin_rc (*extract_fields)(ss_plugin_t* s,
                                        const ss_plugin_event_input* evt,
                                        const ss_plugin_field_extract_input* in);
    };

    // Event parsing capability
    struct {
        uint16_t* (*get_parse_event_types)(uint32_t* numtypes, ss_plugin_t* s);
        const char* (*get_parse_event_sources)();
        ss_plugin_rc (*parse_event)(ss_plugin_t* s,
                                     const ss_plugin_event_input* evt,
                                     const ss_plugin_event_parse_input* in);
    };

    // Async events capability
    struct {
        const char* (*get_async_event_sources)();
        const char* (*get_async_events)();
        ss_plugin_rc (*set_async_event_handler)(ss_plugin_t* s,
                                                 ss_plugin_owner_t* owner,
                                                 const ss_plugin_async_event_handler_t handler);
        ss_plugin_rc (*dump_state)(ss_plugin_t* s,
                                    ss_plugin_owner_t* owner,
                                    const ss_plugin_async_event_handler_t handler);
    };

    // Configuration update
    ss_plugin_rc (*set_config)(ss_plugin_t* s, const ss_plugin_set_config_input* i);

    // Metrics
    ss_plugin_metric* (*get_metrics)(ss_plugin_t* s, uint32_t* num_metrics);

    // Capture listening capability
    struct {
        ss_plugin_rc (*capture_open)(ss_plugin_t* s, const ss_plugin_capture_listen_input* i);
        ss_plugin_rc (*capture_close)(ss_plugin_t* s, const ss_plugin_capture_listen_input* i);
    };

    // Schema version check
    const char* (*get_required_event_schema_version)(ss_plugin_t* s);
} plugin_api;
```

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h)

## Implementation Details

### Plugin Lifecycle

Plugins follow a deterministic lifecycle managed by the framework:

```
1. Discovery    plugin_loader resolves symbols from shared library
       |
       v
2. Validation   get_required_api_version() checked for compatibility
       |
       v
3. Init         init(config, owner, tables, log_fn) -> plugin state
       |
       v
4. Use          open/close (sourcing), extract/parse (per event)
       |
       v
5. Destroy      destroy(plugin_state)
```

#### Init Input

The `init` function receives a structured input providing everything the plugin needs during its lifetime:

```c
typedef struct ss_plugin_init_input {
    // Configuration string
    const char* config;

    // Plugin owner (for callbacks)
    ss_plugin_owner_t* owner;

    // Error retrieval
    const char* (*get_owner_last_error)(ss_plugin_owner_t* o);

    // State table access
    const ss_plugin_init_tables_input* tables;

    // Logging
    ss_plugin_log_fn_t log_fn;
} ss_plugin_init_input;
```

The `tables` field provides access to discover, get, and register state tables (see [State Table Access](#state-table-access)).

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h), [`plugin_types.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_types.h)

### Event Sourcing

Source plugins generate events from external data sources. Each source plugin has a unique numeric ID and a named event source.

**Required functions:**

| Function | Description |
|----------|-------------|
| `get_id()` | Returns the unique plugin ID (must be registered) |
| `get_event_source()` | Returns the event source name (e.g., `k8s_audit`) |
| `open(params)` | Opens a capture instance and returns instance state |
| `close(instance)` | Closes a capture instance |
| `next_batch(instance, nevts, evts)` | Returns a batch of events |

**Optional functions:**

| Function | Description |
|----------|-------------|
| `list_open_params()` | Lists available open parameters |
| `get_progress(instance, pct)` | Reports capture progress (e.g., for file replay) |
| `event_to_string(evt)` | Converts event payload to human-readable string |

#### Event Input Structure

Events passed to plugins are wrapped in:

```c
typedef struct ss_plugin_event_input {
    // Event number
    uint64_t evtnum;

    // Raw event pointer
    const ss_plugin_event* evt;

    // Event timestamp
    uint64_t evtts;

    // Source plugin (if any)
    ss_plugin_t* evtsrc_plugin;
} ss_plugin_event_input;
```

#### Plugin Platforms

When opening a plugin source via libsinsp, the platform level determines what system information is available alongside plugin events:

```cpp
enum class sinsp_plugin_platform {
    SINSP_PLATFORM_GENERIC,   // No system info
    SINSP_PLATFORM_HOSTINFO,  // Basic host info only
    SINSP_PLATFORM_FULL,      // Full system state (for syscall sources)
};
```

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h), [`digests/falcosecurity/libs/plugin-framework.md`](../digests/falcosecurity/libs/plugin-framework.md)

### Field Extraction

Extraction plugins add new filterable fields that can be used in Falco rule conditions and output formatting. Each plugin declares its fields as a JSON array and implements an extraction function.

**Required functions:**

| Function | Description |
|----------|-------------|
| `get_fields()` | Returns JSON array of field definitions |
| `extract_fields(evt, in)` | Extracts field values for a given event |

**Optional functions:**

| Function | Description |
|----------|-------------|
| `get_extract_event_types(numtypes)` | Limits extraction to specific event types |
| `get_extract_event_sources()` | Limits extraction to specific event sources |

#### Field Definition JSON Format

Plugins return field definitions as a JSON array from `get_fields()`. Each field entry supports the following properties:

```json
[
  {
    "name": "plugin.field_name",
    "type": "string",
    "desc": "Description of the field"
  },
  {
    "name": "plugin.numeric_field",
    "type": "uint64",
    "desc": "A numeric field"
  },
  {
    "name": "plugin.list_field",
    "type": "string",
    "isList": true,
    "desc": "A field that returns multiple values"
  },
  {
    "name": "plugin.indexed_field",
    "type": "string",
    "arg": {
      "isRequired": true,
      "isIndex": true
    },
    "desc": "Field requiring numeric index: plugin.indexed_field[0]"
  },
  {
    "name": "plugin.keyed_field",
    "type": "string",
    "arg": {
      "isRequired": false,
      "isKey": true
    },
    "desc": "Field with optional string key: plugin.keyed_field[keyname]"
  }
]
```

**Field properties:**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | string | required | Unique field name (e.g., `container.id`) |
| `type` | string | required | Field value type (see table below) |
| `desc` | string | required | Human-readable description |
| `isList` | bool | `false` | Field returns a list of values |
| `display` | string | — | Human-readable display name |
| `properties` | string[] | — | Optional properties |
| `arg.isRequired` | bool | `false` | Argument is mandatory |
| `arg.isIndex` | bool | `false` | Argument is a numeric index |
| `arg.isKey` | bool | `false` | Argument is a string key |

#### Supported Field Types

| Type | Description |
|------|-------------|
| `string` | String value |
| `uint64` | Unsigned 64-bit integer |
| `bool` | Boolean |
| `reltime` | Relative time (duration in nanoseconds) |
| `abstime` | Absolute timestamp (nanoseconds since epoch) |
| `ipaddr` | IPv4 or IPv6 address |
| `ipnet` | IPv4 or IPv6 network |

#### Field Extraction Input

```c
typedef struct ss_plugin_field_extract_input {
    ss_plugin_owner_t* owner;
    const char* (*get_owner_last_error)(ss_plugin_owner_t* o);

    uint32_t num_fields;
    ss_plugin_extract_field* fields;

    // Table access
    ss_plugin_table_reader_vtable_ext* table_reader_ext;

    // Optional: value offset tracking
    ss_plugin_extract_value_offsets* value_offsets;
} ss_plugin_field_extract_input;
```

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h), [`plugin_types.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_types.h)

### Event Parsing

Parsing plugins process events and maintain state. They are typically used to update state tables based on observed events. Unlike extraction, parsing happens unconditionally for every matching event before extraction.

**Required function:**

| Function | Description |
|----------|-------------|
| `parse_event(evt, in)` | Processes an event and updates internal state |

**Optional functions:**

| Function | Description |
|----------|-------------|
| `get_parse_event_types(numtypes)` | Limits parsing to specific event types |
| `get_parse_event_sources()` | Limits parsing to specific event sources |

The parse input includes table reader and writer vtables, enabling the plugin to read from and write to state tables during event processing.

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h)

### Async Events

Plugins with async capability can inject events into the event stream from background threads. This is used for events that do not originate from the main capture loop (e.g., container metadata responses, Kubernetes resource updates).

Async events use **event code 402** (`PPME_ASYNCEVENT_E`).

**Required functions:**

| Function | Description |
|----------|-------------|
| `get_async_events()` | Returns JSON array of async event names the plugin can produce |
| `set_async_event_handler(handler)` | Framework provides a handler function the plugin calls to inject events |

**Optional functions:**

| Function | Description |
|----------|-------------|
| `get_async_event_sources()` | Specifies target event sources for async events |
| `dump_state(handler)` | Dumps current plugin state as async events (used for capture snapshots) |

```c
// Handler provided by framework
typedef ss_plugin_rc (*ss_plugin_async_event_handler_t)(
    ss_plugin_owner_t* o,
    const ss_plugin_event* evt,
    char* err);

// Plugin registers to receive handler
ss_plugin_rc (*set_async_event_handler)(
    ss_plugin_t* s,
    ss_plugin_owner_t* owner,
    const ss_plugin_async_event_handler_t handler);
```

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h), [`plugin_types.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_types.h)

### Capture Listening

Capture listening plugins react to the lifecycle of event capture. They receive callbacks when capture starts and stops, providing an opportunity to initialize or tear down resources tied to the capture session.

| Function | Description |
|----------|-------------|
| `capture_open(input)` | Called when capture starts |
| `capture_close(input)` | Called when capture stops |

The capture listen input provides table reader and writer vtables, enabling plugins to set initial state when capture begins (e.g., the container plugin uses this to attach container IDs to pre-existing thread entries).

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h)

### State Table Access

The state table system allows plugins to share state with each other and with the framework. Plugins can read from existing tables (e.g., the `threads` table maintained by libsinsp), add custom fields to existing tables, and register entirely new tables.

#### Table Discovery During Init

During initialization, the `tables` input provides functions to discover and access state tables:

```c
typedef struct {
    ss_plugin_table_info* (*list_tables)(ss_plugin_owner_t* o, uint32_t* ntables);
    ss_plugin_table_t* (*get_table)(ss_plugin_owner_t* o,
                                     const char* name,
                                     ss_plugin_state_type key_type);
    ss_plugin_rc (*add_table)(ss_plugin_owner_t* o, const ss_plugin_table_input* in);
    ss_plugin_table_fields_vtable_ext* fields_ext;
    ss_plugin_table_reader_vtable_ext* reader_ext;
    ss_plugin_table_writer_vtable_ext* writer_ext;
} ss_plugin_init_tables_input;
```

#### Reader Vtable

```c
typedef struct {
    const char* (*get_table_name)(ss_plugin_table_t* t);
    uint64_t (*get_table_size)(ss_plugin_table_t* t);
    ss_plugin_table_entry_t* (*get_table_entry)(ss_plugin_table_t* t,
                                                 const ss_plugin_state_data* key);
    ss_plugin_rc (*read_entry_field)(ss_plugin_table_t* t,
                                      ss_plugin_table_entry_t* e,
                                      const ss_plugin_table_field_t* f,
                                      ss_plugin_state_data* out);
    void (*release_table_entry)(ss_plugin_table_t* t, ss_plugin_table_entry_t* e);
    ss_plugin_bool (*iterate_entries)(ss_plugin_table_t* t,
                                       ss_plugin_table_iterator_func_t it,
                                       ss_plugin_table_iterator_state_t* s);
} ss_plugin_table_reader_vtable_ext;
```

#### Writer Vtable

```c
typedef struct {
    ss_plugin_rc (*clear_table)(ss_plugin_table_t* t);
    ss_plugin_rc (*erase_table_entry)(ss_plugin_table_t* t,
                                       const ss_plugin_state_data* key);
    ss_plugin_table_entry_t* (*create_table_entry)(ss_plugin_table_t* t);
    void (*destroy_table_entry)(ss_plugin_table_t* t, ss_plugin_table_entry_t* e);
    ss_plugin_table_entry_t* (*add_table_entry)(ss_plugin_table_t* t,
                                                 const ss_plugin_state_data* key,
                                                 ss_plugin_table_entry_t* entry);
    ss_plugin_rc (*write_entry_field)(ss_plugin_table_t* t,
                                       ss_plugin_table_entry_t* e,
                                       const ss_plugin_table_field_t* f,
                                       const ss_plugin_state_data* in);
} ss_plugin_table_writer_vtable_ext;
```

#### Plugin-Owned Table Registration

Plugins can register their own state tables during init via the `add_table` function. The table input structure provides all vtable implementations that the framework will use to interact with the plugin-owned table:

```c
typedef struct {
    const char* name;
    ss_plugin_state_type key_type;
    ss_plugin_table_t* table;
    ss_plugin_table_reader_vtable_ext* reader_ext;
    ss_plugin_table_writer_vtable_ext* writer_ext;
    ss_plugin_table_fields_vtable_ext* fields_ext;
} ss_plugin_table_input;

// Register during init
ss_plugin_rc (*add_table)(ss_plugin_owner_t* o, const ss_plugin_table_input* in);
```

#### State Data Types

```c
typedef enum {
    SS_PLUGIN_ST_INT8 = 1,
    SS_PLUGIN_ST_INT16 = 2,
    SS_PLUGIN_ST_INT32 = 3,
    SS_PLUGIN_ST_INT64 = 4,
    SS_PLUGIN_ST_UINT8 = 5,
    SS_PLUGIN_ST_UINT16 = 6,
    SS_PLUGIN_ST_UINT32 = 7,
    SS_PLUGIN_ST_UINT64 = 8,
    SS_PLUGIN_ST_STRING = 9,
    SS_PLUGIN_ST_BOOL = 10,
    SS_PLUGIN_ST_TABLE = 11,  // Nested table (subtable)
} ss_plugin_state_type;
```

The `SS_PLUGIN_ST_TABLE` type enables nested subtables (e.g., the thread table contains a `file_descriptors` subtable keyed by FD number).

**Source:** [`plugin_types.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_types.h), [`digests/falcosecurity/libs/state-management.md`](../digests/falcosecurity/libs/state-management.md)

### Thread Pool (Routines)

Plugins can subscribe recurring routines to the framework's thread pool. This is particularly useful for capture listening plugins that need background work during the capture session.

```c
typedef struct {
    // Subscribe a routine
    ss_plugin_routine_t* (*subscribe)(ss_plugin_owner_t* o,
                                       ss_plugin_routine_fn_t f,
                                       ss_plugin_routine_state_t* i);

    // Unsubscribe a routine
    ss_plugin_rc (*unsubscribe)(ss_plugin_owner_t* o, ss_plugin_routine_t* r);
} ss_plugin_routine_vtable;
```

The routine callback returns a boolean indicating whether it should be rescheduled:

```c
typedef ss_plugin_bool (*ss_plugin_routine_fn_t)(
    ss_plugin_t* s,
    ss_plugin_routine_state_t* i);
```

Returning `true` causes the routine to be rescheduled; returning `false` terminates it.

**Source:** [`plugin_types.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_types.h)

### Configuration Update

Plugins can support dynamic reconfiguration through the `set_config` function:

```c
ss_plugin_rc (*set_config)(ss_plugin_t* s, const ss_plugin_set_config_input* i);
```

This allows the framework to push updated configuration to plugins at runtime without requiring a full restart.

Plugins can also declare a configuration schema via `get_init_schema()`, enabling the framework to validate configuration strings before passing them to `init()`.

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h)

### Metrics

Plugins can expose custom metrics for monitoring and observability:

```c
ss_plugin_metric* (*get_metrics)(ss_plugin_t* s, uint32_t* num_metrics);
```

Metrics include a name, type (monotonic or non-monotonic), and a value. Metric values can be `uint32_t`, `int32_t`, `uint64_t`, `int64_t`, `double`, or `float`.

**Source:** [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h)

### Error Handling

#### Return Codes

```c
typedef enum {
    SS_PLUGIN_SUCCESS = 0,
    SS_PLUGIN_FAILURE = 1,
    SS_PLUGIN_TIMEOUT = 2,
    SS_PLUGIN_EOF = 3,
    SS_PLUGIN_NOT_SUPPORTED = 4,
} ss_plugin_rc;
```

| Code | Value | Meaning |
|------|-------|---------|
| `SS_PLUGIN_SUCCESS` | 0 | Operation succeeded |
| `SS_PLUGIN_FAILURE` | 1 | Operation failed (call `get_last_error()` for details) |
| `SS_PLUGIN_TIMEOUT` | 2 | No data available now, retry later |
| `SS_PLUGIN_EOF` | 3 | End of event stream, no more events |
| `SS_PLUGIN_NOT_SUPPORTED` | 4 | Operation not supported by this plugin |

#### Logging

The framework provides a log function during initialization. Plugins should use this for all diagnostic output.

```c
typedef enum {
    SS_PLUGIN_LOG_SEV_FATAL = 1,
    SS_PLUGIN_LOG_SEV_CRITICAL = 2,
    SS_PLUGIN_LOG_SEV_ERROR = 3,
    SS_PLUGIN_LOG_SEV_WARNING = 4,
    SS_PLUGIN_LOG_SEV_NOTICE = 5,
    SS_PLUGIN_LOG_SEV_INFO = 6,
    SS_PLUGIN_LOG_SEV_DEBUG = 7,
    SS_PLUGIN_LOG_SEV_TRACE = 8,
} ss_plugin_log_severity;

typedef void (*ss_plugin_log_fn_t)(
    ss_plugin_owner_t* o,
    const char* component,  // NULL uses plugin name
    const char* msg,
    ss_plugin_log_severity sev);
```

**Source:** [`plugin_types.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_types.h)

### Plugin SDKs

Three official SDKs are available for developing Falco plugins:

| SDK | Language | Version | Repository | Status |
|-----|----------|---------|------------|--------|
| plugin-sdk-go | Go | v0.8.3 | [`refs/falcosecurity/plugin-sdk-go/`](../refs/falcosecurity/plugin-sdk-go/) | Stable |
| plugin-sdk-cpp | C++ | (header-only) | [`refs/falcosecurity/plugin-sdk-cpp/`](../refs/falcosecurity/plugin-sdk-cpp/) | Incubating |
| plugin-sdk-rs | Rust | v0.5.0 | [`refs/falcosecurity/plugin-sdk-rs/`](../refs/falcosecurity/plugin-sdk-rs/) | Incubating |

**Go SDK** (`plugin-sdk-go`): Three-layer architecture (core interfaces, CGO symbols, high-level plugins). Supports pull and push event production models. Async extraction optimization with worker goroutines.

**C++ SDK** (`plugin-sdk-cpp`): Header-only library using C++11. Mixin-based capability composition via template inheritance. Macro-based symbol registration.

**Rust SDK** (`plugin-sdk-rs`): Trait-based capability system with compile-time checks. Strongly-typed event handling via `falco_event_schema`. Uses the `log` crate redirected to Falco's logger.

**Source:** [`digests/falcosecurity/plugin-sdk-go.md`](../digests/falcosecurity/plugin-sdk-go.md), [`digests/falcosecurity/plugin-sdk-cpp.md`](../digests/falcosecurity/plugin-sdk-cpp.md), [`digests/falcosecurity/plugin-sdk-rs.md`](../digests/falcosecurity/plugin-sdk-rs.md)

### Official Plugins

#### Container Plugin

The `container` plugin is **shipped with Falco** and provides container metadata enrichment for syscall events. It is a hybrid C++/Go plugin.

| Property | Value |
|----------|-------|
| API Version | 3.10.0 |
| Minimum Falco Version | 0.41.0 |
| Language | C++ + Go (static library) |
| Capabilities | extraction, parsing, async, capture listening |

**Architecture:** The C++ shared object handles plugin capabilities and maintains a container cache. The Go static library (worker) retrieves container metadata from container runtime SDKs.

**Supported Container Engines:**

| Engine | Default Socket(s) |
|--------|-------------------|
| Docker | `/var/run/docker.sock` |
| Podman | `/run/podman/podman.sock`, `/run/user/$uid/podman/podman.sock` |
| Containerd | `/run/host-containerd/containerd.sock` |
| CRI | `/run/containerd/containerd.sock`, `/run/crio/crio.sock`, `/run/k3s/containerd/containerd.sock` |
| LXC | Generic info only (ID + type) |
| libvirt_lxc | Generic info only (ID + type) |
| BPM | Generic info only (ID + type) |

**Key Fields:**
- `container.id`, `container.full_id`, `container.name`
- `container.image`, `container.image.repository`, `container.image.tag`, `container.image.digest`
- `container.type`, `container.privileged`, `container.ip`
- `container.mounts`, `container.mount[...]`
- `container.host_pid`, `container.host_network`, `container.host_ipc`
- `container.labels`, `container.label[...]`
- `k8s.pod.name`, `k8s.ns.name`, `k8s.pod.uid`, `k8s.pod.sandbox_id`
- `k8s.pod.label[...]`, `k8s.pod.labels`

> **Note:** Many `k8s.*` fields related to deployments, services, and replica sets are deprecated in the container plugin. Use the `k8smeta` plugin for those fields.

**Source:** [`digests/falcosecurity/plugins/container.md`](../digests/falcosecurity/plugins/container.md), [`plugins/container/README.md`](../refs/falcosecurity/plugins/plugins/container/README.md)

#### K8smeta Plugin

The `k8smeta` plugin provides Kubernetes resource metadata enrichment beyond what the container plugin offers.

| Property | Value |
|----------|-------|
| Plugin Version | 0.4.1 |
| Minimum Falco Version | 0.40.0 |
| Language | C++ |
| Capabilities | extraction, parsing, async, capture listening |

**Architecture:** Implements a client-server model. The plugin runs alongside each Falco instance and receives metadata via gRPC from the centralized [`k8s-metacollector`](https://github.com/falcosecurity/k8s-metacollector) service, which watches the Kubernetes API server. This avoids scalability issues of having every Falco instance connect directly to the API server.

**Key Fields:**
- `k8smeta.pod.name`, `k8smeta.pod.uid`, `k8smeta.pod.label[...]`, `k8smeta.pod.labels`
- `k8smeta.ns.name`, `k8smeta.ns.uid`, `k8smeta.ns.label[...]`
- `k8smeta.deployment.name`, `k8smeta.deployment.uid`, `k8smeta.deployment.label[...]`
- `k8smeta.svc.name` (list), `k8smeta.svc.uid` (list), `k8smeta.svc.label[...]`
- `k8smeta.rs.name`, `k8smeta.rs.uid`, `k8smeta.rs.label[...]`
- `k8smeta.rc.name`, `k8smeta.rc.uid`, `k8smeta.rc.label[...]`

**Source:** [`digests/falcosecurity/plugins/k8smeta.md`](../digests/falcosecurity/plugins/k8smeta.md), [`plugins/k8smeta/README.md`](../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

#### JSON Plugin

The `json` plugin is a general-purpose extraction plugin that extracts values from JSON-encoded event payloads using RFC 6901 JSON Pointer syntax.

| Property | Value |
|----------|-------|
| Plugin Version | 0.7.3 |
| Language | Go |
| Capabilities | extraction |
| Event Source | None (extractor only, works with all sources) |

**Fields:**

| Field | Description |
|-------|-------------|
| `json.value[<json pointer>]` | Extract value using JSON Pointer (RFC 6901) |
| `json.obj` | Full JSON message as text |
| `json.rawtime` | Event time (identical to `evt.rawtime`) |
| `jevt.*` | Aliases for backwards compatibility |

**Example:**
```yaml
condition: json.value[/output_fields/container.id] == "host"
```

**Source:** [`digests/falcosecurity/plugins/json.md`](../digests/falcosecurity/plugins/json.md), [`plugins/json/README.md`](../refs/falcosecurity/plugins/plugins/json/README.md)

#### K8saudit Plugin Family

The `k8saudit` plugins enable Falco to monitor Kubernetes clusters via audit logs. A base plugin and multiple cloud-provider variants share the same `k8s_audit` event source and ruleset.

**Base k8saudit plugin:**

| Property | Value |
|----------|-------|
| Plugin ID | 1 |
| Plugin Version | 0.16.0 |
| Event Source | `k8s_audit` |
| Language | Go |
| Capabilities | sourcing, extraction |

**Input Methods:**
- **Webhook** -- Embedded HTTP/HTTPS server (production use)
- **File** -- JSONL format (testing/development)

**Cloud Provider Variants:**

| Plugin | Source ID | Cloud Provider | Description |
|--------|-----------|----------------|-------------|
| `k8saudit-eks` | 9 | AWS | Read from AWS EKS clusters |
| `k8saudit-gke` | 16 | GCP | Read from GKE clusters |
| `k8saudit-aks` | 21 | Azure | Read from Azure AKS clusters |
| `k8saudit-ovh` | 22 | OVHcloud | Read from OVHcloud MKS clusters |

All variants share the same ruleset from [`plugins/k8saudit/rules/`](../refs/falcosecurity/plugins/plugins/k8saudit/rules/).

**Key Fields:**
- `ka.user.name`, `ka.user.groups`, `ka.verb`, `ka.uri`
- `ka.target.name`, `ka.target.namespace`, `ka.target.resource`
- `ka.req.pod.*` -- Pod request details
- `ka.req.container.*` -- Container request details
- `ka.response.code`, `ka.response.reason`
- `ka.sourceips`, `ka.useragent`

**Source:** [`digests/falcosecurity/plugins/k8saudit.md`](../digests/falcosecurity/plugins/k8saudit.md), [`plugins/k8saudit/README.md`](../refs/falcosecurity/plugins/plugins/k8saudit/README.md)

### Plugin Registry

The plugin registry ([`registry.yaml`](../refs/falcosecurity/plugins/registry.yaml)) is the central catalog of all plugins recognized by The Falco Project. It is hosted in the [`plugins`](../refs/falcosecurity/plugins/) repository.

#### Naming Constraints

- **Plugin `name`:** Must match `^[a-z]+[a-z0-9-_\-]*$` (avoid `_` unless necessary)
- **Event `source`:** Must match `^[a-z]+[a-z0-9_]*$`

#### Reserved Sources

The following data sources are reserved and cannot be used by plugins:
- `syscall` -- Used by Falco's syscall source
- `internal` -- Used internally by Falco
- `plugins` -- Reserved

#### Reserved Plugin IDs

| ID | Purpose |
|----|---------|
| `0` | Reserved for particular purposes (do not use) |
| `999` | Reserved for source plugin development/testing |

#### ID Blocks

| Block | ID Range | Purpose |
|-------|----------|---------|
| Public | 0--1073741823 | Public registry assignments |
| Private | 1073741824--2147483647 | Private/internal plugins |
| Reserved | 2147483648--3221225471 | Future use |
| Internal | 3221225472--4294967295 | Plugin framework internal use |

**Source:** [`registry.yaml`](../refs/falcosecurity/plugins/registry.yaml), [`docs/plugin-ids.md`](../refs/falcosecurity/plugins/docs/plugin-ids.md), [`docs/registering-a-plugin.md`](../refs/falcosecurity/plugins/docs/registering-a-plugin.md)

## Non-Functional Requirements

### Memory Management

Plugins own all memory they allocate. The framework does not free plugin-allocated memory. Plugins must manage their own allocations and release them in `destroy()` (for plugin-level state) and `close()` (for instance-level state).

### Thread Safety

The framework may call `next_batch`, `extract_fields`, and `parse_event` from multiple threads with different parameters. Plugin implementations must be thread-safe with respect to shared mutable state.

### Backward Compatibility

The Plugin API maintains backward compatibility within the same major version. Plugins declaring a required API version of `3.x.y` will work with any framework implementing API version `3.a.b` where `a >= x`.

### Plugin Loading

Plugins are loaded as shared libraries (`.so` on Linux) via `plugin_loader.c`. The loader resolves all function pointers from the shared library symbols, validates the required API version, and initializes the plugin.

```cpp
sinsp inspector;
auto plugin = inspector.register_plugin("/path/to/plugin.so");
plugin->init(R"({"key": "value"})");

// Use for event sourcing
inspector.open_plugin("plugin_name", "open_params", SINSP_PLATFORM_FULL);

// Or just for extraction/parsing on syscall events
inspector.open_modern_bpf(...);
// Plugin will automatically process syscall events
```

**Source:** [`plugin_loader.c`](../refs/falcosecurity/libs/userspace/plugin/plugin_loader.c), [`digests/falcosecurity/libs/plugin-framework.md`](../digests/falcosecurity/libs/plugin-framework.md)

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`architecture-overview.md`](architecture-overview.md) | Overall Falco system architecture and event pipeline |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Kernel driver layer that generates syscall events consumed by plugins |
| [`libscap.md`](libscap.md) | Raw event retrieval and engine abstraction |
| [`libsinsp.md`](libsinsp.md) | Plugin integration in libsinsp, state tables |
| [`filter-engine.md`](filter-engine.md) | Filter system that evaluates plugin-extracted fields |
| [`configuration.md`](configuration.md) | Plugin configuration in Falco config files |

## Sources

| Topic | Source File |
|-------|-------------|
| Plugin API struct | [`plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h) |
| Plugin types and enums | [`plugin_types.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_types.h) |
| Plugin loader | [`plugin_loader.c`](../refs/falcosecurity/libs/userspace/plugin/plugin_loader.c) |
| Plugin registry | [`registry.yaml`](../refs/falcosecurity/plugins/registry.yaml) |
| Plugin registration guide | [`docs/registering-a-plugin.md`](../refs/falcosecurity/plugins/docs/registering-a-plugin.md) |
| Plugin IDs | [`docs/plugin-ids.md`](../refs/falcosecurity/plugins/docs/plugin-ids.md) |
| Container plugin | [`plugins/container/README.md`](../refs/falcosecurity/plugins/plugins/container/README.md) |
| K8smeta plugin | [`plugins/k8smeta/README.md`](../refs/falcosecurity/plugins/plugins/k8smeta/README.md) |
| JSON plugin | [`plugins/json/README.md`](../refs/falcosecurity/plugins/plugins/json/README.md) |
| K8saudit plugin | [`plugins/k8saudit/README.md`](../refs/falcosecurity/plugins/plugins/k8saudit/README.md) |
| K8saudit rules | [`plugins/k8saudit/rules/`](../refs/falcosecurity/plugins/plugins/k8saudit/rules/) |
| Go SDK | [`plugin-sdk-go/`](../refs/falcosecurity/plugin-sdk-go/) |
| C++ SDK | [`plugin-sdk-cpp/`](../refs/falcosecurity/plugin-sdk-cpp/) |
| Rust SDK | [`plugin-sdk-rs/`](../refs/falcosecurity/plugin-sdk-rs/) |
| Plugin framework digest | [`digests/falcosecurity/libs/plugin-framework.md`](../digests/falcosecurity/libs/plugin-framework.md) |
| Plugins repository digest | [`digests/falcosecurity/plugins.md`](../digests/falcosecurity/plugins.md) |
| State management | [`digests/falcosecurity/libs/state-management.md`](../digests/falcosecurity/libs/state-management.md) |
