# Plugin Framework
> **Era:** 0.44 | **Version:** libs 0.25.2 | **Source:** [`refs/falcosecurity/libs/`](../../../refs/falcosecurity/libs/)

## Overview

The Falco plugin framework extends libs capabilities beyond syscall events. Plugins can:

- **Source Events** - Generate events from external sources (cloud APIs, logs, etc.)
- **Extract Fields** - Add new filterable fields to events
- **Parse Events** - Maintain state based on event streams
- **Send Async Events** - Inject events asynchronously
- **Listen to Capture** - React to capture start/stop

**Location:** `userspace/plugin/`
**Plugin API Version:** 3.12.0

## Plugin Capabilities

| Capability | Description | Required Functions |
|------------|-------------|-------------------|
| **SOURCING** | Generate events from external sources | `get_id`, `get_event_source`, `open`, `close`, `next_batch` |
| **EXTRACTION** | Extract fields from events | `get_fields`, `extract_fields` |
| **PARSING** | Parse events and maintain state | `parse_event` |
| **ASYNC** | Send asynchronous events | `get_async_events`, `set_async_event_handler` |
| **CAPTURE_LISTENING** | React to capture lifecycle | `capture_open`, `capture_close` |

## Plugin API

### Core Plugin Structure

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

## State Tables

Plugins can access and define state tables for cross-plugin state sharing.

### Table Types

```c
// State data types
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
    SS_PLUGIN_ST_TABLE = 11,  // Nested table
} ss_plugin_state_type;
```

### Accessing Tables (Reader Vtable)

```c
typedef struct {
    // Get table name
    const char* (*get_table_name)(ss_plugin_table_t* t);

    // Get entry count
    uint64_t (*get_table_size)(ss_plugin_table_t* t);

    // Get entry by key
    ss_plugin_table_entry_t* (*get_table_entry)(ss_plugin_table_t* t,
                                                 const ss_plugin_state_data* key);

    // Read field from entry
    ss_plugin_rc (*read_entry_field)(ss_plugin_table_t* t,
                                      ss_plugin_table_entry_t* e,
                                      const ss_plugin_table_field_t* f,
                                      ss_plugin_state_data* out);

    // Release entry
    void (*release_table_entry)(ss_plugin_table_t* t, ss_plugin_table_entry_t* e);

    // Iterate entries
    ss_plugin_bool (*iterate_entries)(ss_plugin_table_t* t,
                                       ss_plugin_table_iterator_func_t it,
                                       ss_plugin_table_iterator_state_t* s);
} ss_plugin_table_reader_vtable_ext;
```

### Modifying Tables (Writer Vtable)

```c
typedef struct {
    // Clear all entries
    ss_plugin_rc (*clear_table)(ss_plugin_table_t* t);

    // Erase entry by key
    ss_plugin_rc (*erase_table_entry)(ss_plugin_table_t* t,
                                       const ss_plugin_state_data* key);

    // Create new entry
    ss_plugin_table_entry_t* (*create_table_entry)(ss_plugin_table_t* t);

    // Destroy entry
    void (*destroy_table_entry)(ss_plugin_table_t* t, ss_plugin_table_entry_t* e);

    // Add entry to table
    ss_plugin_table_entry_t* (*add_table_entry)(ss_plugin_table_t* t,
                                                 const ss_plugin_state_data* key,
                                                 ss_plugin_table_entry_t* entry);

    // Write field to entry
    ss_plugin_rc (*write_entry_field)(ss_plugin_table_t* t,
                                       ss_plugin_table_entry_t* e,
                                       const ss_plugin_table_field_t* f,
                                       const ss_plugin_state_data* in);
} ss_plugin_table_writer_vtable_ext;
```

### Defining Tables (Plugin-Owned)

```c
typedef struct {
    // Table name
    const char* name;

    // Key type
    ss_plugin_state_type key_type;

    // Table pointer
    ss_plugin_table_t* table;

    // Read operations
    ss_plugin_table_reader_vtable_ext* reader_ext;

    // Write operations
    ss_plugin_table_writer_vtable_ext* writer_ext;

    // Field operations
    ss_plugin_table_fields_vtable_ext* fields_ext;
} ss_plugin_table_input;

// Register during init
ss_plugin_rc (*add_table)(ss_plugin_owner_t* o, const ss_plugin_table_input* in);
```

## Init Input

Information passed to plugins during initialization:

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

// Tables input
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

## Event Input

Information passed when processing events:

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

## Field Extraction Input

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

## Async Events

Plugins can send events asynchronously (e.g., from background threads):

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

## Thread Pool (Routines)

Plugins can subscribe recurring routines to the framework's thread pool:

```c
typedef struct {
    // Subscribe a routine
    ss_plugin_routine_t* (*subscribe)(ss_plugin_owner_t* o,
                                       ss_plugin_routine_fn_t f,
                                       ss_plugin_routine_state_t* i);

    // Unsubscribe a routine
    ss_plugin_rc (*unsubscribe)(ss_plugin_owner_t* o, ss_plugin_routine_t* r);
} ss_plugin_routine_vtable;

// Routine callback
typedef ss_plugin_bool (*ss_plugin_routine_fn_t)(
    ss_plugin_t* s,
    ss_plugin_routine_state_t* i);
```

## Field Definition Format

Plugins return field definitions as JSON:

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

### Supported Field Types

| Type | Description |
|------|-------------|
| `string` | String value |
| `uint64` | Unsigned 64-bit integer |
| `bool` | Boolean |
| `reltime` | Relative time (duration) |
| `abstime` | Absolute timestamp |
| `ipaddr` | IP address |
| `ipnet` | IP network |

## Plugin Loading

### From C++

```cpp
sinsp inspector;

// Load plugin
auto plugin = inspector.register_plugin("/path/to/plugin.so");

// Initialize with config
plugin->init(R"({"key": "value"})");

// Use for event sourcing
inspector.open_plugin("plugin_name", "open_params", SINSP_PLATFORM_FULL);

// Or just for extraction/parsing
inspector.open_modern_bpf(...);
// Plugin will automatically process syscall events
```

### Plugin Platforms

```cpp
enum class sinsp_plugin_platform {
    SINSP_PLATFORM_GENERIC,   // No system info
    SINSP_PLATFORM_HOSTINFO,  // Basic host info only
    SINSP_PLATFORM_FULL,      // Full system state (for syscall sources)
};
```

## Error Handling

```c
// Return codes
typedef enum {
    SS_PLUGIN_SUCCESS = 0,
    SS_PLUGIN_FAILURE = 1,
    SS_PLUGIN_TIMEOUT = 2,
    SS_PLUGIN_EOF = 3,
    SS_PLUGIN_NOT_SUPPORTED = 4,
} ss_plugin_rc;

// Max error message length
#define PLUGIN_MAX_ERRLEN 1024
```

## Logging

```c
// Log severity
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

// Log function
typedef void (*ss_plugin_log_fn_t)(
    ss_plugin_owner_t* o,
    const char* component,  // NULL uses plugin name
    const char* msg,
    ss_plugin_log_severity sev);
```

## Plugin Development Notes

1. **Memory Management:** Plugins own all allocated memory. Framework does not free plugin memory.

2. **Thread Safety:** `next_batch`, `extract_fields`, `parse_event` may be called from multiple threads with different parameters.

3. **Plugin IDs:** Source plugins with specific event sources must register for an official ID from the Falco organization.

4. **Backward Compatibility:** Plugin API maintains backward compatibility within major versions.

5. **Event Format:** Async events use event code 402 (async event type).

## Sources

| Topic | Source File |
|-------|-------------|
| Plugin API | [`userspace/plugin/plugin_api.h`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_api.h) |
| Plugin types | [`userspace/plugin/plugin_types.h`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_types.h) |
| Plugin loader | [`userspace/plugin/plugin_loader.c`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_loader.c) |

## Related Digests

- [architecture.md](architecture.md) - Overall system architecture
- [libsinsp.md](libsinsp.md) - Plugin integration in libsinsp
- [api-reference.md](api-reference.md) - Event types
- [../plugin-sdk-go.md](../plugin-sdk-go.md) - Go SDK for plugins
