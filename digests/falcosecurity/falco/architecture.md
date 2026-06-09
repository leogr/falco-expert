# Falco Architecture

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falco/`](../../../refs/falcosecurity/falco/) | **Version:** 0.44.0

## Overview

Falco is a runtime security tool that builds on top of the [falcosecurity/libs](../libs/architecture.md) to provide:

- Rule-based event detection using the **falco_engine**
- Multiple output channels via **falco_outputs**
- Plugin support for extending event sources and field extraction
- Hot reload capability for configuration and rules
- Metrics collection and Prometheus integration

Falco acts as the "policy layer" above the libs' event capture and state tracking infrastructure.

```
+------------------------------------------------------------------+
|                         Falco Application                         |
|  +------------------------------------------------------------+  |
|  |   falco_engine (Rule Engine)                               |  |
|  |   - Rule loading/compilation                               |  |
|  |   - Event matching (process_event)                         |  |
|  |   - Ruleset management                                     |  |
|  +------------------------------------------------------------+  |
|  +------------------------------------------------------------+  |
|  |   falco_outputs (Output Framework)                         |  |
|  |   - Multi-producer queue                                   |  |
|  |   - Worker thread for async output                         |  |
|  |   - Multiple output types (stdout, file, syslog, http...)   |  |
|  +------------------------------------------------------------+  |
+------------------------------------------------------------------+
                              |
                              v
+------------------------------------------------------------------+
|                    falcosecurity/libs                             |
|  +----------------------------+  +-----------------------------+ |
|  |  libsinsp                  |  |  libscap                    | |
|  |  - Event parsing           |  |  - Driver communication     | |
|  |  - State tables            |  |  - Engine abstraction       | |
|  |  - Filter system           |  |  - Buffer management        | |
|  +----------------------------+  +-----------------------------+ |
+------------------------------------------------------------------+
                              |
                              v
+------------------------------------------------------------------+
|                       Kernel Driver                               |
|  (modern_bpf | kmod | plugin | nodriver)                          |
+------------------------------------------------------------------+
```

> **Removed in 0.44:** Legacy eBPF probe (#3796), gVisor engine (#3797), and gRPC output/server (#3798) have all been dropped. Modern eBPF remains the default driver; kmod is available as alternative. Source: [Falco 0.44.0 release notes](https://github.com/falcosecurity/falco/releases/tag/0.44.0).

## Component Diagram

```
+-----------------------------------------------------------------------------------+
|                              Falco Process                                        |
|                                                                                   |
|   main() --> falco_run() --> falco::app::run()                                   |
|                                   |                                               |
|                      +------------+------------+                                  |
|                      |                         |                                  |
|                      v                         v                                  |
|              [run_steps loop]          [teardown_steps]                          |
|                      |                         |                                  |
|   +------------------+------------------+      +------------------+               |
|   |                                     |      | unregister_signal|               |
|   v                                     v      | stop_webserver   |               |
|  [Configuration]              [Event Processing]| cleanup_outputs |               |
|  - load_config                - process_events | close_inspectors |               |
|  - load_plugins               - do_inspect()   +------------------+               |
|  - init_inspectors                   |                                            |
|  - init_falco_engine                 v                                            |
|  - load_rules_files           +------+------+                                     |
|                               |             |                                     |
|   +------------------+        v             v                                     |
|   | Signal Handlers  |   inspector    falco_engine                                |
|   | - SIGINT/SIGTERM |     .next()    .process_event()                            |
|   | - SIGHUP         |        |              |                                    |
|   | - SIGUSR1        |        |              v                                    |
|   +------------------+        |        +-----+-----+                              |
|                               |        | Rule Match|                              |
|   +------------------+        |        +-----+-----+                              |
|   | restart_handler  |        |              |                                    |
|   | - inotify watcher|        |              v                                    |
|   | - config/rules   |        +-----> falco_outputs                               |
|   +------------------+                  .handle_event()                           |
|                                              |                                    |
|                                              v                                    |
|                               +---------------------------+                       |
|                               | Output Worker Thread      |                       |
|                               | - concurrent_queue        |                       |
|                               | - stdout, file, syslog... |                       |
|                               +---------------------------+                       |
|   +------------------+                                                            |
|   | Web Server       |                                                            |
|   | - /healthz       |                                                            |
|   | - /metrics       |                                                            |
|   +------------------+                                                            |
+-----------------------------------------------------------------------------------+
```

## Application Lifecycle

### Entry Point

The application entry point is in [`falco.cpp`](../../../refs/falcosecurity/falco/userspace/falco/falco.cpp):

```cpp
// falco.cpp:59-71
int main(int argc, char **argv) {
    int rc;
    bool restart;
    // falco_run() is called in a loop to support hot restarts
    while((rc = falco_run(argc, argv, restart)) == EXIT_SUCCESS && restart) {
    }
    return rc;
}
```

### Startup Sequence (run_steps)

The startup sequence is defined in [`app.cpp:56-88`](../../../refs/falcosecurity/falco/userspace/falco/app/app.cpp). Each action is executed in order:

| Step | Action | Purpose |
|------|--------|---------|
| 1 | `print_help` | Display help and exit if `-h` |
| 2 | `print_config_schema` | Output config JSON schema if requested |
| 3 | `print_rule_schema` | Output rule JSON schema if requested |
| 4 | `print_ignored_events` | List ignored events if requested |
| 5 | `print_syscall_events` | List syscall events if requested |
| 6 | `load_config` | Parse falco.yaml configuration |
| 7 | `print_kernel_version` | Log kernel version info (when using a kernel driver) |
| 8 | `print_version` | Show Falco version if `--version` |
| 9 | `print_page_size` | Display system page size |
| 11 | `require_config_file` | Validate config file exists |
| 12 | `print_plugin_info` | Show plugin info if requested |
| 13 | `list_plugins` | List available plugins if requested |
| 14 | **`load_plugins`** | Load all configured plugins |
| 15 | **`init_inspectors`** | Create sinsp inspectors per source |
| 16 | **`init_falco_engine`** | Initialize rule engine with sources |
| 17 | `list_fields` | List available fields if requested |
| 18 | `select_event_sources` | Apply `--enable-source`/`--disable-source` |
| 19 | `validate_rules_files` | Validate rules syntax |
| 20 | **`load_rules_files`** | Load and compile rules |
| 21 | `print_support` | Output support info if requested |
| 22 | **`init_outputs`** | Initialize output channels |
| 23 | `create_signal_handlers` | Set up SIGINT, SIGHUP, SIGUSR1 |
| 24 | `create_requested_paths` | Create dirs for outputs/captures |
| 25 | `pidfile` | Write PID file if configured |
| 26 | `configure_interesting_sets` | Compute syscall sets for filtering |
| 27 | `configure_syscall_buffer_size` | Set driver buffer size |
| 28 | `configure_syscall_buffer_num` | Set number of buffers |
| 29 | `start_webserver` | Start health/metrics webserver |
| 30 | **`process_events`** | Main event loop (blocking) |

### Teardown Sequence

Teardown runs regardless of success/failure ([`app.cpp:90-95`](../../../refs/falcosecurity/falco/userspace/falco/app/app.cpp)):

| Step | Action | Purpose |
|------|--------|---------|
| 1 | `unregister_signal_handlers` | Reset signal handlers to default |
| 2 | `stop_webserver` | Stop health webserver |
| 3 | `cleanup_outputs` | Reset outputs (prints stats internally) |
| 4 | `close_inspectors` | Close all sinsp inspectors |

## Application State

The application state is defined in [`state.h`](../../../refs/falcosecurity/falco/userspace/falco/app/state.h):

```cpp
struct state {
    // Command line
    std::string cmdline;
    falco::app::options options;
    std::atomic<bool> restart = false;

    // Core components
    std::shared_ptr<falco_configuration> config;
    std::shared_ptr<falco_outputs> outputs;
    std::shared_ptr<falco_engine> engine;

    // Event sources
    std::vector<std::string> loaded_sources;        // ["syscall", "plugin_source", ...]
    std::unordered_set<std::string> enabled_sources;

    // Inspector management
    std::shared_ptr<sinsp> offline_inspector;       // For plugin loading / capture mode
    indexed_vector<source_info> source_infos;       // Per-source inspector + metadata

    // Plugin configuration
    indexed_vector<falco_configuration::plugin_config> plugin_configs;

    // Syscall configuration
    libsinsp::events::set<ppm_sc_code> selected_sc_set;
    uint64_t syscall_buffer_bytes_size;

    // Hot reload
    std::shared_ptr<restart_handler> restarter;

    // Servers (conditional compilation)
    falco_webserver webserver;
};
```

### source_info Structure

Each event source has associated metadata:

```cpp
struct source_info {
    std::size_t engine_idx;                        // Index in falco_engine
    std::shared_ptr<filter_check_list> filterchecks; // Available filter fields
    std::shared_ptr<sinsp> inspector;              // Assigned inspector
};
```

## Event Processing Flow

### High-Level Flow

```
1. Kernel Event (syscall, tracepoint)
         |
         v
2. Driver captures event -> Ring Buffer
         |
         v
3. libscap: scap_next() retrieves raw event
         |
         v
4. libsinsp: Event parsing + State update + Enrichment
         |
         v
5. Falco Engine: process_event() -> Rule matching
         |
         v
6. If matched: falco_outputs.handle_event()
         |
         v
7. Output Worker: Format and deliver alert
```

### The process_events Action

The main event loop is in [`process_events.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp).

**Capture Mode** (trace file):
```cpp
// process_events.cpp:517-524
if(s.is_capture_mode()) {
    res = open_offline_inspector(s);
    process_inspector_events(s, s.offline_inspector, statsw, "", nullptr, &res);
    s.offline_inspector->close();
}
```

**Live Mode** (multiple sources possible):
```cpp
// process_events.cpp:532-598
for(const auto& source : s.enabled_sources) {
    // Open inspector for this source
    res = open_live_inspector(s, src_info->inspector, source);

    if(s.enabled_sources.size() == 1) {
        // Optimization: single-threaded for one source
        process_inspector_events(...);
    } else {
        // Multi-threaded: one thread per source
        ctx.thread = std::make_unique<std::thread>([...] {
            process_inspector_events(...);
        });
    }
}
```

### The do_inspect Loop

Core event processing ([`process_events.cpp:104-365`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)):

```cpp
while(1) {
    rc = inspector->next(&ev);  // Get event from libsinsp

    // Handle signals (SIGINT, SIGHUP, SIGUSR1)
    if(g_terminate_signal.triggered()) break;
    if(g_restart_signal.triggered()) { s.restart.store(true); break; }

    // Handle return codes
    if(rc == SCAP_TIMEOUT) continue;
    if(rc == SCAP_EOF) break;
    if(rc != SCAP_SUCCESS) return run_result::fatal(...);

    // Check event drops (syscall source only)
    sdropmgr.process_event(inspector, ev);

    // Rule matching via falco_engine
    auto res = s.engine->process_event(source_engine_idx, ev, s.config->m_rule_matching);

    if(res != nullptr) {
        for(auto& rule_res : *res) {
            // Output alert
            s.outputs->handle_event(rule_res.evt, rule_res.rule, ...);

            // Handle capture if enabled
            if(s.config->m_capture_enabled && rule_res.capture) {
                dumper->dump(ev);
            }
        }
    }
}
```

### Rule Matching

The rule matching is performed by `falco_engine::process_event()` ([`falco_engine.h:259-262`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine.h)):

```cpp
std::unique_ptr<std::vector<rule_result>> process_event(
    std::size_t source_idx,   // Event source index
    sinsp_evt *ev,            // Event from libsinsp
    uint16_t ruleset_id,      // Active ruleset
    falco_common::rule_matching strategy  // first/all matching rules
);
```

The engine uses:
1. **filter_ruleset** - Compiled rules organized by event type
2. **sinsp_filter** - Boolean filter expressions
3. **sinsp_evt_formatter** - Output string formatting

## Integration with libs

### libsinsp Integration

Falco creates inspectors per event source ([`init_inspectors.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/init_inspectors.cpp)):

```cpp
// Capture mode: share one inspector
if(is_capture_mode) {
    src_info->inspector = s.offline_inspector;
}
// Live mode: inspector per source
else {
    src_info->inspector = std::make_shared<sinsp>(...);
}
```

**Filter Factory Setup** ([`init_falco_engine.cpp:114-127`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/init_falco_engine.cpp)):

```cpp
void add_source_to_engine(state& s, const std::string& src) {
    auto filter_factory = std::make_shared<sinsp_filter_factory>(
        inspector, filterchecks);
    auto formatter_factory = std::make_shared<sinsp_evt_formatter_factory>(
        inspector, filterchecks);

    src_info->engine_idx = s.engine->add_source(
        src, filter_factory, formatter_factory);
}
```

### libscap Integration

Driver selection is handled in [`helpers_inspector.cpp:43-149`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp):

| Engine Mode | Inspector Call |
|-------------|----------------|
| Capture (trace file) | `inspector->open_savefile(path)` |
| Modern eBPF | `inspector->open_modern_bpf(buffer_size, cpus, ...)` |
| Kernel Module | `inspector->open_kmod(buffer_size, ...)` |
| No Driver | `inspector->open_nodriver()` |
| Plugin Source | `inspector->open_plugin(name, params, ...)` |

## Plugin Integration

### Plugin Loading

Plugins are loaded in [`load_plugins.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/load_plugins.cpp):

```cpp
// Default syscall source always present
s.source_infos.insert(syscall_src_info, falco_common::syscall_source);
s.loaded_sources = {falco_common::syscall_source};

// Load configured plugins
for(auto& p : s.config->m_plugins) {
    auto plugin = s.offline_inspector->register_plugin(p.m_library_path);

    // If plugin provides event sourcing (CAP_SOURCING with non-zero ID)
    if((plugin->caps() & CAP_SOURCING) && plugin->id() != 0) {
        auto src_name = plugin->event_source();
        s.source_infos.insert(src_info, src_name);
        s.loaded_sources.push_back(src_name);
    }
}
```

### Plugin Capabilities

Falco supports plugins with these capabilities:

| Capability | Description | Registration |
|------------|-------------|--------------|
| `CAP_SOURCING` | Generates events | Per-source inspector |
| `CAP_EXTRACTION` | Extracts fields | Added to filtercheck list |
| `CAP_PARSING` | Custom event parsing | Registered with compatible sources |
| `CAP_ASYNC` | Async event injection | Registered with compatible sources |

### Plugin Configuration (falco.yaml)

```yaml
plugins:
  - name: cloudtrail
    library_path: /usr/share/falco/plugins/libcloudtrail.so
    init_config: '{"sqsDelete": false}'
    open_params: 'sqs://my-queue'

load_plugins: [cloudtrail]
```

## Thread Model

Falco uses a multi-threaded architecture:

```
+-------------------+
|   Main Thread     |  <-- Event processing (do_inspect loop)
| - inspector.next()|      Single-threaded, stateful
| - engine.process()|
+-------------------+
         |
         v (queue push)
+-------------------+
|  Output Worker    |  <-- Async output delivery
| - TBB concurrent  |      Consumes from bounded queue
|   queue           |
+-------------------+

+-------------------+
|  Web Server       |  <-- Optional, cpp-httplib threads
| - /healthz        |      Health + Prometheus metrics
| - /metrics        |
+-------------------+

+-------------------+
|  Restart Handler  |  <-- inotify watcher thread
| - Config changes  |      Triggers hot reload
| - Rules changes   |
+-------------------+
```

**Multi-Source Live Mode:**
When multiple event sources are enabled, each gets its own thread:

```cpp
// process_events.cpp:577-588
if(s.enabled_sources.size() > 1) {
    ctx.thread = std::make_unique<std::thread>([...] {
        process_inspector_events(s, src_info->inspector, ...);
    });
}
```

## Hot Reload

### restart_handler

The [`restart_handler`](../../../refs/falcosecurity/falco/userspace/falco/app/restart_handler.h) watches files/directories using inotify:

```cpp
class restart_handler {
    using on_check_t = std::function<bool()>;  // Validation callback
    using watch_list_t = std::vector<std::string>;

    restart_handler(on_check_t on_check,
                    const watch_list_t& watch_files,
                    const watch_list_t& watch_dirs);
};
```

### Signal Handling

Signal handlers trigger atomic flags ([`create_signal_handlers.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp)):

| Signal | Handler | Effect |
|--------|---------|--------|
| `SIGINT`/`SIGTERM` | `g_terminate_signal.trigger()` | Graceful shutdown |
| `SIGHUP` | `restart_handler->trigger()` | Hot restart |
| `SIGUSR1` | `g_reopen_outputs_signal.trigger()` | Reopen output files |

### Hot Restart Process

1. `SIGHUP` received or file change detected
2. Validation: dry-run with new config/rules
3. If valid: `s.restart.store(true)` and break from event loop
4. Main loop restarts: `falco_run()` called again
5. Full re-initialization with updated config/rules

## Build System

### CMake Structure

[`CMakeLists.txt`](../../../refs/falcosecurity/falco/CMakeLists.txt) highlights:

```cmake
# Core options
option(USE_BUNDLED_DEPS "Bundle dependencies" ON)
option(MINIMAL_BUILD "Minimal build (no webserver/metrics/http output)" OFF)
option(BUILD_FALCO_MODERN_BPF "Modern eBPF support" ON)

# Dependencies
include(falcosecurity-libs)  # Fetch/build libs
include(njson)               # JSON library
include(yaml-cpp)            # Config parsing
include(tbb)                 # Concurrent queue

# Subdirectories
add_subdirectory(userspace/engine)  # falco_engine library
add_subdirectory(userspace/falco)   # falco binary
```

### Key Build Targets

| Target | Description |
|--------|-------------|
| `falco` | Main Falco binary |
| `falco_engine` | Rule engine static library |
| `container` | Container plugin (downloaded) |

### Conditional Features

| Flag | Feature |
|------|---------|
| `MINIMAL_BUILD` | Disables webserver, metrics, and http output |
| `BUILD_FALCO_MODERN_BPF` | Modern eBPF (Linux only) |
| `MUSL_OPTIMIZED_BUILD` | Static musl linking |

## Sources

| Topic | Source File |
|-------|-------------|
| Entry point | [`userspace/falco/falco.cpp`](../../../refs/falcosecurity/falco/userspace/falco/falco.cpp) |
| Application flow | [`userspace/falco/app/app.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/app.cpp) |
| Application state | [`userspace/falco/app/state.h`](../../../refs/falcosecurity/falco/userspace/falco/app/state.h) |
| Rule engine | [`userspace/engine/falco_engine.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine.h) |
| Output system | [`userspace/falco/falco_outputs.h`](../../../refs/falcosecurity/falco/userspace/falco/falco_outputs.h) |
| Event processing | [`userspace/falco/app/actions/process_events.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp) |
| Plugin loading | [`userspace/falco/app/actions/load_plugins.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/load_plugins.cpp) |
| Inspector init | [`userspace/falco/app/actions/init_inspectors.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/init_inspectors.cpp) |
| Engine init | [`userspace/falco/app/actions/init_falco_engine.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/init_falco_engine.cpp) |
| Rules loading | [`userspace/falco/app/actions/load_rules_files.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/load_rules_files.cpp) |
| Signal handlers | [`userspace/falco/app/actions/create_signal_handlers.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp) |
| Inspector helpers | [`userspace/falco/app/actions/helpers_inspector.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp) |
| Restart handler | [`userspace/falco/app/restart_handler.h`](../../../refs/falcosecurity/falco/userspace/falco/app/restart_handler.h) |
| Build configuration | [`CMakeLists.txt`](../../../refs/falcosecurity/falco/CMakeLists.txt) |
| Plugin proposal | [`proposals/20210501-plugin-system.md`](../../../refs/falcosecurity/falco/proposals/20210501-plugin-system.md) |

## Related Digests

- [libs Architecture](../libs/architecture.md) - Event capture infrastructure
- [libsinsp](../libs/libsinsp.md) - Event processing and state management
