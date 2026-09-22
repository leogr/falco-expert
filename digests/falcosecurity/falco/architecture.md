# Falco Architecture

> **Era Relevance:** 0.45 | **Source:** [`refs/falcosecurity/falco/`](../../../refs/falcosecurity/falco/) | **Version:** 0.45.0

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

The ordered actions are defined in [`app.cpp:63-92`](../../../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L63-L92):

| Step | Action | Purpose |
|------|--------|---------|
| 1 | `print_help` | Display help text and exit if `-h` flag |
| 2 | `print_config_schema` | Output configuration JSON schema if requested |
| 3 | `print_rule_schema` | Output rule JSON schema if requested |
| 4 | `print_ignored_events` | List ignored events if requested |
| 5 | `print_syscall_events` | List syscall events if requested |
| 6 | **`load_config`** | **Parse `falco.yaml` configuration file** |
| 7 | `print_kernel_version` | Show kernel version if requested |
| 8 | `print_version` | Show Falco version if requested |
| 9 | `print_page_size` | Display system page size |
| 10 | `require_config_file` | Validate that config file exists |
| 11 | `print_plugin_info` | Show plugin info if `--plugin-info` requested |
| 12 | `list_plugins` | List available plugins if `--list-plugins` requested |
| 13 | **`load_plugins`** | **Load all configured plugins into offline_inspector** |
| 14 | **`init_inspectors`** | **Create sinsp inspectors per event source** |
| 15 | **`init_falco_engine`** | **Initialize rule engine with sources, filter/formatter factories** |
| 16 | `list_fields` | List available fields if `--list` requested |
| 17 | `select_event_sources` | Apply `--enable-source` / `--disable-source` filters |
| 18 | `validate_rules_files` | Validate rules syntax (dry-run validation) |
| 19 | **`load_rules_files`** | **Load and compile detection rules** |
| 20 | `print_support` | Output support info if requested |
| 21 | **`init_outputs`** | **Initialize output channels (stdout, file, syslog, http, etc.)** |
| 22 | `create_signal_handlers` | Initialize persistent SIGHUP handling, install other signal handlers, start restart worker |
| 23 | `pidfile` | Write PID file if `--pidfile` configured |
| 24 | `configure_interesting_sets` | Compute syscall sets for kernel-level filtering |
| 25 | `configure_syscall_buffer_size` | Set driver ring buffer size |
| 26 | `configure_syscall_buffer_num` | Set number of ring buffers |
| 27 | `start_webserver` | Start optional Unix reload listener and health/metrics webserver (non-minimal live mode) |
| 28 | **`process_events`** | **Main event loop (blocking until termination)** |

### Teardown Sequence

Teardown runs regardless of success/failure ([`app.cpp:97-102`](../../../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L97-L102)):

| Step | Action | Purpose |
|------|--------|---------|
| 1 | `unregister_signal_handlers` | Stop restart worker; reset SIGINT/SIGTERM/SIGUSR1; preserve SIGHUP |
| 2 | `stop_webserver` | Stop Unix reload listener and health/metrics webserver |
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
#ifdef __linux__
    falco_reload_control reload_control;
#endif
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
if(s.is_replaying()) {
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

Core event processing ([`process_events.cpp:105-369`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp#L105-L369)):

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

The rule matching is performed by `falco_engine::process_event()` ([`falco_engine.h:259-262`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine.h#L259-L262)):

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

**Filter Factory Setup** ([`init_falco_engine.cpp:114-127`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/init_falco_engine.cpp#L114-L127)):

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

Driver selection is handled in [`helpers_inspector.cpp:130-226`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp#L130-L226):

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

Falco reloads by validating a temporary dry-run state, tearing down the active run, and executing the full startup sequence again within the same process. File watching (`watch_config_files`), SIGHUP and the optional Unix HTTP control listener all use this path. Validation failure emits an internal critical alert and leaves the running state active; success does not guarantee later resource acquisition will succeed.

| Signal | Effect |
|--------|--------|
| `SIGINT` / `SIGTERM` | Trigger an atomic termination flag |
| `SIGUSR1` | Trigger an atomic output-reopen flag |
| `SIGHUP` | Increment a lock-free request counter and wake a process-lifetime eventfd |

The SIGHUP handler and descriptor survive run teardown. The restart worker handles request counters and inotify events outside signal context, validates after debounce, and repeats validation for intervening requests/changes. It is started even with file watching disabled; inotify is allocated only when paths are watched.

**Source:** [`create_signal_handlers.cpp:35-117,151-230`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp#L35-L230), [`restart_handler.cpp:71-282`](../../../refs/falcosecurity/falco/userspace/falco/app/restart_handler.cpp#L71-L282), [`app.cpp:55-121`](../../../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L55-L121).

### Reload Status and Control (0.45)

`GET /reload` exposes `instance_id`, `started_generation`, `applied_generation`, `rejected_generation`, and `ready` on the TCP webserver and optional Unix listener. Readiness means every enabled live source has started capture; stopping/failing sources or teardown clear it. A failed validation can leave the prior run ready while advancing `rejected_generation`.

`reload_control.enabled` starts a separate Linux, non-minimal Unix listener, independent of `webserver.enabled`. Only this listener accepts `POST /reload`. A bodyless, queryless request returns 202 with a generation baseline. Clients finish writes first and observe the same instance until `ready=true` and `applied_generation > max(baseline, rejected_generation)`; they retry GET through reload outages and request again after an instance change. HTTP 200 from GET alone does not establish reload success. See [reload configuration](configuration.md#hot-reload) for permissions and failure semantics.

**Source:** [`reload_control.cpp:210-334`](../../../refs/falcosecurity/falco/userspace/falco/reload_control.cpp#L210-L334), [`reload_state.cpp:37-76`](../../../refs/falcosecurity/falco/userspace/falco/app/reload_state.cpp#L37-L76), [`webserver.cpp:50-60`](../../../refs/falcosecurity/falco/userspace/falco/webserver.cpp#L50-L60), [`falco.yaml:967-994`](../../../refs/falcosecurity/falco/falco.yaml#L967-L994).

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
