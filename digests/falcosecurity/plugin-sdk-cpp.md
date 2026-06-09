# plugin-sdk-cpp Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/plugin-sdk-cpp/`](../../refs/falcosecurity/plugin-sdk-cpp/) | **Commit:** `d08557d` (January 16, 2026)

**Repository:** [falcosecurity/plugin-sdk-cpp](https://github.com/falcosecurity/plugin-sdk-cpp)
**Scope:** Ecosystem
**Status:** Incubating

C++ header-only library for building [Falco plugins](https://falco.org/docs/plugins/). The SDK provides C++ wrappers around the plugin API, enabling type-safe plugin development with modern C++ features while maintaining compatibility with the C plugin interface.

## Key Characteristics

- **Header-only**: No library compilation required - just include headers
- **C++11 standard**: Compatible with older compilers
- **Mixin-based architecture**: Capabilities are composed via template mixins
- **Type-safe**: Compile-time checks for method signatures
- **Macro-based registration**: Simple macros to export C symbols

**Source:** [`README.md`](../../refs/falcosecurity/plugin-sdk-cpp/README.md)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Plugin Class                                    │
│  Your plugin class implementing required methods                        │
├─────────────────────────────────────────────────────────────────────────┤
│                          Mixin Layer                                     │
│  falcosecurity::_internal::plugin_mixin<Plugin>                         │
│  Composes capability-specific mixins via template inheritance           │
├─────────────────────────────────────────────────────────────────────────┤
│                          Symbols Layer                                   │
│  FALCOSECURITY_PLUGIN_* macros                                          │
│  Generate C symbol exports required by the plugin API                   │
├─────────────────────────────────────────────────────────────────────────┤
│                          C Plugin API                                    │
│  include/falcosecurity/internal/deps/plugin_api.h                       │
│  Standard Falco plugin interface (from libs)                            │
└─────────────────────────────────────────────────────────────────────────┘
```

**Source:** [`include/falcosecurity/internal/plugin_mixin.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/internal/plugin_mixin.h)

## Plugin Capabilities

Plugins can implement one or more capabilities by including appropriate macros:

| Capability | Registration Macro | Description |
|------------|-------------------|-------------|
| **Base** | `FALCOSECURITY_PLUGIN(class)` | Required for all plugins - info, init, destroy |
| **Event Sourcing** | `FALCOSECURITY_PLUGIN_EVENT_SOURCING(plugin, source)` | Generate events from external sources |
| **Field Extraction** | `FALCOSECURITY_PLUGIN_FIELD_EXTRACTION(class)` | Extract typed fields from events |
| **Event Parsing** | `FALCOSECURITY_PLUGIN_EVENT_PARSING(class)` | Parse events and update state tables |
| **Async Events** | `FALCOSECURITY_PLUGIN_ASYNC_EVENTS(class)` | Inject events asynchronously into syscall stream |
| **Capture Listening** | `FALCOSECURITY_PLUGIN_CAPTURE_LISTENING(class)` | React to capture open/close events |

**Source:** [`include/falcosecurity/sdk.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/sdk.h), [`include/falcosecurity/internal/symbols_*.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/internal/)

## Core Types

### Result Codes

```cpp
namespace falcosecurity {
    using result_code = _internal::ss_plugin_rc;
    // SS_PLUGIN_SUCCESS   = 0  - Operation succeeded
    // SS_PLUGIN_FAILURE   = 1  - Operation failed
    // SS_PLUGIN_TIMEOUT   = -1 - Timeout (retry later)
    // SS_PLUGIN_EOF       = 2  - End of event stream
    // SS_PLUGIN_NOT_SUPPORTED = 3  - Operation not supported
}
```

**Source:** [`include/falcosecurity/types.h:32`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/types.h)

### Field Value Types

```cpp
// Available field types for extraction
field_value_type::FTYPE_UINT64   // 64-bit unsigned integer
field_value_type::FTYPE_STRING   // Null-terminated string
field_value_type::FTYPE_RELTIME  // Relative time (nanoseconds)
field_value_type::FTYPE_ABSTIME  // Absolute time (nanoseconds since epoch)
field_value_type::FTYPE_BOOL     // Boolean
field_value_type::FTYPE_IPADDR   // IPv4 or IPv6 address
field_value_type::FTYPE_IPNET    // IPv4 or IPv6 network
```

**Source:** [`include/falcosecurity/types.h:315-337`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/types.h)

### State Value Types

```cpp
// Available types for state table fields
state_value_type::SS_PLUGIN_ST_INT8    state_value_type::SS_PLUGIN_ST_UINT8
state_value_type::SS_PLUGIN_ST_INT16   state_value_type::SS_PLUGIN_ST_UINT16
state_value_type::SS_PLUGIN_ST_INT32   state_value_type::SS_PLUGIN_ST_UINT32
state_value_type::SS_PLUGIN_ST_INT64   state_value_type::SS_PLUGIN_ST_UINT64
state_value_type::SS_PLUGIN_ST_STRING  state_value_type::SS_PLUGIN_ST_BOOL
state_value_type::SS_PLUGIN_ST_TABLE   // Subtable reference
```

**Source:** [`include/falcosecurity/types.h:339-367`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/types.h)

### Logger

```cpp
struct logger {
    void log(const std::string& component, const std::string& msg,
             log_severity sev = log_severity::SS_PLUGIN_LOG_SEV_INFO);
    void log(const std::string& msg,
             log_severity sev = log_severity::SS_PLUGIN_LOG_SEV_INFO);
};
```

**Source:** [`include/falcosecurity/types.h:52-108`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/types.h)

### Field Info

```cpp
struct field_info {
    field_value_type type;        // Field data type
    std::string name;             // Field name (e.g., "example.field")
    bool list = false;            // Field returns list of values
    field_arg arg;                // Argument requirements (key, index, required)
    std::string display;          // Human-readable display name
    std::string description;      // Field description
    std::vector<std::string> properties;  // Optional properties
    bool addOutput = false;       // Include in rule output
};
```

**Source:** [`include/falcosecurity/types.h:152-183`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/types.h)

### Metric

```cpp
struct metric {
    std::string name;
    metric_type type;           // SS_PLUGIN_METRIC_TYPE_MONOTONIC or NON_MONOTONIC
    metric_value value;
    metric_value_type value_type;  // U32, S32, U64, S64, D, F

    void set_value(uint32_t v);
    void set_value(int32_t v);
    void set_value(uint64_t v);
    void set_value(int64_t v);
    void set_value(double v);
    void set_value(float v);
};
```

**Source:** [`include/falcosecurity/types.h:210-279`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/types.h)

## Building Plugins

### Event Source Plugin

```cpp
#include <falcosecurity/sdk.h>

class my_event_source {
public:
    // Optional: void close() {}
    // Optional: double get_progress(std::string& fmt) { return 0.0; }

    falcosecurity::result_code next_event(falcosecurity::event_writer& evt) {
        falcosecurity::events::pluginevent_e_encoder enc;
        enc.set_data((void*)data, len);
        enc.encode(evt);
        return falcosecurity::result_code::SS_PLUGIN_SUCCESS;
    }
};

class my_plugin {
public:
    // Required methods
    std::string get_name() { return "my-source-plugin"; }
    std::string get_version() { return "0.1.0"; }
    std::string get_description() { return "My plugin description"; }
    std::string get_contact() { return "author@example.com"; }
    uint32_t get_id() { return 999; }  // Unique plugin ID
    std::string get_event_source() { return "my-source"; }

    bool init(falcosecurity::init_input& i) {
        logger = i.get_logger();
        return true;
    }

    std::unique_ptr<my_event_source> open(const std::string& params) {
        return std::make_unique<my_event_source>();
    }

    // Optional methods
    // std::vector<falcosecurity::open_param> list_open_params() { return {}; }
    // std::string event_to_string(const falcosecurity::event_reader& evt) {}
    // bool set_config(falcosecurity::set_config_input& i) { return true; }
    // void destroy() {}

private:
    falcosecurity::logger logger;
};

FALCOSECURITY_PLUGIN(my_plugin);
FALCOSECURITY_PLUGIN_EVENT_SOURCING(my_plugin, my_event_source);
```

**Source:** [`examples/plugin_source/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/plugin_source/plugin.cpp)

### Field Extractor Plugin

```cpp
#include <falcosecurity/sdk.h>

class my_plugin {
public:
    std::string get_name() { return "my-extractor-plugin"; }
    std::string get_version() { return "0.1.0"; }
    std::string get_description() { return "My extractor"; }
    std::string get_contact() { return "author@example.com"; }

    // Optional: specify which event sources to extract from
    std::vector<std::string> get_extract_event_sources() { return {"my-source"}; }

    std::vector<falcosecurity::field_info> get_fields() {
        using ft = falcosecurity::field_value_type;
        return {
            {ft::FTYPE_STRING, "my.field", "Display Name", "Field description"},
            {ft::FTYPE_UINT64, "my.count", "Count", "A numeric field"},
        };
    }

    bool init(falcosecurity::init_input& i) { return true; }

    bool extract(const falcosecurity::extract_fields_input& in) {
        auto& req = in.get_extract_request();
        auto& evt = in.get_event_reader();

        switch (req.get_field_id()) {
        case 0:  // my.field
            req.set_value("value", true);  // true = copy the string
            return true;
        case 1:  // my.count
            req.set_value((uint64_t)42);
            return true;
        }
        return false;
    }
};

FALCOSECURITY_PLUGIN(my_plugin);
FALCOSECURITY_PLUGIN_FIELD_EXTRACTION(my_plugin);
```

**Source:** [`examples/plugin_extract/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/plugin_extract/plugin.cpp)

### Event Parsing Plugin (with State Tables)

```cpp
#include <falcosecurity/sdk.h>

class my_plugin {
public:
    std::string get_name() { return "my-parser-plugin"; }
    std::string get_version() { return "0.1.0"; }
    std::string get_description() { return "My parser"; }
    std::string get_contact() { return "author@example.com"; }

    // Specify event types to parse
    std::vector<falcosecurity::event_type> get_parse_event_types() {
        return {(_et)2, (_et)3};  // PPME_SYSCALL_OPEN_E, PPME_SYSCALL_OPEN_X
    }

    // Specify event sources to parse
    std::vector<std::string> get_parse_event_sources() { return {"syscall"}; }

    bool init(falcosecurity::init_input& i) {
        using st = falcosecurity::state_value_type;
        auto& t = i.tables();

        // Access existing state table
        m_threads_table = t.get_table("threads", st::SS_PLUGIN_ST_INT64);

        // Add custom field to existing table
        m_custom_field = m_threads_table.add_field(
            t.fields(), "my_custom_field", st::SS_PLUGIN_ST_UINT64);

        return true;
    }

    bool parse_event(const falcosecurity::parse_event_input& in) {
        auto& evt = in.get_event_reader();
        auto& tr = in.get_table_reader();
        auto& tw = in.get_table_writer();

        // Get thread entry
        auto entry = m_threads_table.get_entry(tr, (int64_t)evt.get_tid());

        // Read/write custom field
        uint64_t value = 0;
        m_custom_field.read_value(tr, entry, value);
        value++;
        m_custom_field.write_value(tw, entry, value);

        return true;
    }

private:
    falcosecurity::table m_threads_table;
    falcosecurity::table_field m_custom_field;
};

FALCOSECURITY_PLUGIN(my_plugin);
FALCOSECURITY_PLUGIN_EVENT_PARSING(my_plugin);
```

**Source:** [`examples/syscall_parse/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_parse/plugin.cpp)

### Async Events Plugin

```cpp
#include <falcosecurity/sdk.h>
#include <thread>
#include <atomic>

class my_plugin {
public:
    std::string get_name() { return "my-async-plugin"; }
    std::string get_version() { return "0.1.0"; }
    std::string get_description() { return "Async events"; }
    std::string get_contact() { return "author@example.com"; }

    // Declare async event names
    std::vector<std::string> get_async_events() {
        return {"my_notification"};
    }

    // Specify target event sources
    std::vector<std::string> get_async_event_sources() { return {"syscall"}; }

    bool init(falcosecurity::init_input& i) { return true; }

    bool start_async_events(
            std::shared_ptr<falcosecurity::async_event_handler_factory> f) {
        m_quit = false;
        m_thread = std::thread(&my_plugin::async_loop, this, f->new_handler());
        return true;
    }

    bool stop_async_events() noexcept {
        m_quit = true;
        if (m_thread.joinable()) {
            m_thread.join();
        }
        return true;
    }

    void async_loop(std::unique_ptr<falcosecurity::async_event_handler> h) {
        falcosecurity::events::asyncevent_e_encoder enc;
        while (!m_quit) {
            std::string msg = "notification data";
            enc.set_tid(1);
            enc.set_name("my_notification");
            enc.set_data((void*)msg.c_str(), msg.size() + 1);
            enc.encode(h->writer());
            h->push();
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
    }

private:
    std::thread m_thread;
    std::atomic<bool> m_quit;
};

FALCOSECURITY_PLUGIN(my_plugin);
FALCOSECURITY_PLUGIN_ASYNC_EVENTS(my_plugin);
```

**Source:** [`examples/syscall_async/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_async/plugin.cpp)

## State Tables API

The SDK provides full access to Falco's state tables for reading and writing enrichment data.

### Table Access

```cpp
// In init()
auto& t = i.tables();

// List available tables
std::vector<table_info> tables = t.list_tables();

// Get a table by name
table m_table = t.get_table("threads", state_value_type::SS_PLUGIN_ST_INT64);

// Get existing field
table_field m_field = m_table.get_field(t.fields(), "comm", state_value_type::SS_PLUGIN_ST_STRING);

// Add custom field
table_field m_custom = m_table.add_field(t.fields(), "my_field", state_value_type::SS_PLUGIN_ST_UINT64);
```

### Table Operations

```cpp
// In parse_event()
auto& tr = in.get_table_reader();
auto& tw = in.get_table_writer();

// Get entry by key
table_entry entry = m_table.get_entry(tr, (int64_t)key);

// Read field value
uint64_t value;
m_field.read_value(tr, entry, value);

// Write field value
m_field.write_value(tw, entry, new_value);

// Get table size
uint64_t size = m_table.get_size(tr);

// Iterate entries
m_table.iterate_entries(tr, [&](const table_entry& e) {
    // Process entry
    return true;  // Continue iteration
});

// Clear table
m_table.clear(tw);

// Erase entry
m_table.erase_entry(tw, key);

// Create and add entry
table_stale_entry new_entry = m_table.create_entry(tw);
m_field.write_value(tw, new_entry, initial_value);
table_entry added = m_table.add_entry(tr, tw, key, std::move(new_entry));
```

**Source:** [`include/falcosecurity/table.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/table.h)

### Subtables

```cpp
// In init()
// Get subtable field accessor
m_fd_field = m_threads_table.get_field(t.fields(), "file_descriptors",
                                       state_value_type::SS_PLUGIN_ST_TABLE);

// Get/add subtable field
m_fd_name = t.get_subtable_field(m_threads_table, m_fd_field, "name",
                                  state_value_type::SS_PLUGIN_ST_STRING);
m_custom = t.add_subtable_field(m_threads_table, m_fd_field, "custom",
                                 state_value_type::SS_PLUGIN_ST_STRING);

// In parse_event()
// Get subtable from entry
table fd_table = m_threads_table.get_subtable(tr, m_fd_field, thread_entry,
                                               state_value_type::SS_PLUGIN_ST_INT64);

// Iterate subtable
fd_table.iterate_entries(tr, [&](const table_entry& e) {
    std::string name;
    m_fd_name.read_value(tr, e, name);
    return true;
});
```

**Source:** [`examples/syscall_subtables/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_subtables/plugin.cpp)

## Event Encoding/Decoding

### Plugin Events

```cpp
// Encoding (in source plugin)
falcosecurity::events::pluginevent_e_encoder enc;
enc.set_ts(timestamp_ns);      // Optional, defaults to -1
enc.set_tid(thread_id);        // Optional, defaults to -1
enc.set_plugin_id(999);        // Optional for SDK, set automatically
enc.set_data((void*)data, len);
enc.encode(event_writer);

// Decoding (in extractor)
falcosecurity::events::pluginevent_e_decoder dec(event_reader);
uint32_t len = 0;
const char* data = (const char*)dec.get_data(len);
```

**Source:** [`include/falcosecurity/events/encoders.h:32-101`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/events/encoders.h), [`include/falcosecurity/events/decoders.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/events/decoders.h)

### Async Events

```cpp
// Encoding
falcosecurity::events::asyncevent_e_encoder enc;
enc.set_tid(1);
enc.set_name("event_name");
enc.set_data((void*)payload, payload_len);
enc.encode(handler->writer());
handler->push();

// Decoding
falcosecurity::events::asyncevent_e_decoder dec(event_reader);
std::string name = dec.get_name();
uint32_t len = 0;
char* data = (char*)dec.get_data(len);
```

**Source:** [`include/falcosecurity/events/encoders.h:103-181`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/events/encoders.h)

## Input Types

### init_input

```cpp
class init_input {
    std::string get_config();           // Plugin configuration string
    table_init_input& tables();         // State tables access
    logger get_logger() const;          // Logger for plugin messages
};
```

**Source:** [`include/falcosecurity/inputs.h:162-194`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/inputs.h)

### parse_event_input

```cpp
class parse_event_input {
    const event_reader& get_event_reader() const;
    const table_reader& get_table_reader() const;
    const table_writer& get_table_writer() const;
};
```

**Source:** [`include/falcosecurity/inputs.h:196-238`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/inputs.h)

### extract_fields_input

```cpp
class extract_fields_input {
    const event_reader& get_event_reader() const;
    const table_reader& get_table_reader() const;
    extract_request& get_extract_request() const;
};
```

**Source:** [`include/falcosecurity/inputs.h:240-287`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/inputs.h)

### capture_listen_input

```cpp
class capture_listen_input {
    const table_reader& get_table_reader() const;
    const table_writer& get_table_writer() const;
};
```

**Source:** [`include/falcosecurity/inputs.h:312-348`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/inputs.h)

## Installation

### CMake FetchContent

```cmake
project(my_plugin VERSION 1.0.0 LANGUAGES CXX)

set(MY_SRCS plugin.cpp)
add_library(${PROJECT_NAME} SHARED ${MY_SRCS})

include(FetchContent)
FetchContent_Declare(
  plugin-sdk-cpp
  GIT_REPOSITORY https://github.com/falcosecurity/plugin-sdk-cpp.git
  GIT_TAG        <release-tag>  # Use specific release for Falco version
)
FetchContent_MakeAvailable(plugin-sdk-cpp)

target_link_libraries(${PROJECT_NAME} plugin-sdk-cpp)
```

### Direct Include

Simply copy the `include/falcosecurity/` directory to your project and add it to your include path.

**Source:** [`README.md`](../../refs/falcosecurity/plugin-sdk-cpp/README.md)

## Build Configuration

```bash
# Build shared library
g++ -std=c++11 -shared -fPIC -o libmyplugin.so plugin.cpp \
    -I/path/to/plugin-sdk-cpp/include

# Using Makefile from examples
make -C examples/plugin_source
```

**Source:** [`examples/plugin_source/Makefile`](../../refs/falcosecurity/plugin-sdk-cpp/examples/plugin_source/Makefile)

## Version Compatibility

The SDK main branch is not guaranteed to be compatible with the latest released Falco. Use the appropriate release tag to target a specific Falco version.

**Source:** [`README.md`](../../refs/falcosecurity/plugin-sdk-cpp/README.md)

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| nlohmann/json | 3.12.0 | JSON parsing (bundled) |

**Source:** [`include/falcosecurity/internal/deps/nlohmann/json.hpp`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/internal/deps/nlohmann/json.hpp), Git commit `d08557d`

## Examples

| Example | Capabilities | Description |
|---------|-------------|-------------|
| [`plugin_source`](../../refs/falcosecurity/plugin-sdk-cpp/examples/plugin_source/) | Event Sourcing | Basic source plugin generating events |
| [`plugin_extract`](../../refs/falcosecurity/plugin-sdk-cpp/examples/plugin_extract/) | Field Extraction | Extract fields from plugin events |
| [`syscall_async`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_async/) | Async Events, Extraction | Inject async events into syscall stream |
| [`syscall_parse`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_parse/) | Event Parsing, Capture Listening | Parse syscall events, access state tables, metrics |
| [`syscall_extract`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_extract/) | Field Extraction | Extract fields from syscall events |
| [`syscall_subtables`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_subtables/) | Event Parsing | Access thread subtables (fds, args, cgroups) |

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, installation | [`README.md`](../../refs/falcosecurity/plugin-sdk-cpp/README.md) |
| Main SDK header | [`include/falcosecurity/sdk.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/sdk.h) |
| Core types | [`include/falcosecurity/types.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/types.h) |
| State tables | [`include/falcosecurity/table.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/table.h) |
| Input types | [`include/falcosecurity/inputs.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/inputs.h) |
| Event encoders | [`include/falcosecurity/events/encoders.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/events/encoders.h) |
| Event decoders | [`include/falcosecurity/events/decoders.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/events/decoders.h) |
| Mixin architecture | [`include/falcosecurity/internal/plugin_mixin.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/internal/plugin_mixin.h) |
| Common mixin | [`include/falcosecurity/internal/plugin_mixin_common.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/internal/plugin_mixin_common.h) |
| C plugin API | [`include/falcosecurity/internal/deps/plugin_api.h`](../../refs/falcosecurity/plugin-sdk-cpp/include/falcosecurity/internal/deps/plugin_api.h) |
| Source plugin example | [`examples/plugin_source/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/plugin_source/plugin.cpp) |
| Extractor plugin example | [`examples/plugin_extract/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/plugin_extract/plugin.cpp) |
| Async plugin example | [`examples/syscall_async/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_async/plugin.cpp) |
| Parser plugin example | [`examples/syscall_parse/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_parse/plugin.cpp) |
| Subtables example | [`examples/syscall_subtables/plugin.cpp`](../../refs/falcosecurity/plugin-sdk-cpp/examples/syscall_subtables/plugin.cpp) |

## Related Documentation

- [Plugin Developer's Guide](https://falco.org/docs/plugins/developers_guide/)
- [Plugin API Reference](https://falco.org/docs/plugins/plugin-api-reference/)
- [falcosecurity/plugins Registry](https://github.com/falcosecurity/plugins)
- [`plugin-sdk-go.md`](plugin-sdk-go.md) - Go SDK for plugins
- [`libs/plugin-framework.md`](libs/plugin-framework.md) - Plugin API in libs
