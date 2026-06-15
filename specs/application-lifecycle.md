# Application Lifecycle

> Entry point, modular action framework, startup/teardown sequences, signal handling, hot reload, and multi-source inspector management.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco/userspace/falco/app/`](../refs/falcosecurity/falco/userspace/falco/app/)

## Overview

Falco uses a modular action framework to manage its entire lifecycle. The call chain is:

```
main() --> falco_run() --> falco::app::run()
```

The outermost `main()` function implements a **hot restart loop**: when a restart is requested (via signal or file-change detection), `falco_run()` returns with `restart = true` and is called again, re-initializing the entire application with updated configuration and rules.

Inside `falco::app::run()`, the application executes an ordered list of **run_steps** (startup actions), followed by unconditional **teardown_steps**. Each step is a function that receives a shared `state` struct and returns a `run_result` indicating success/failure and whether to proceed.

## Architecture

### Entry Point

The application entry point is in [`falco.cpp`](../refs/falcosecurity/falco/userspace/falco/falco.cpp).

```cpp
// falco.cpp:59-71
int main(int argc, char **argv) {
    int rc;
    bool restart;

    // Generally falco exits when falco_run returns with the rc
    // returned by falco_run. However, when restart (set by
    // signal handlers, returned in application::run()) is true,
    // falco_run() is called again.
    while((rc = falco_run(argc, argv, restart)) == EXIT_SUCCESS && restart) {
    }

    return rc;
}
```

**Source:** [`falco.cpp:59-71`](../refs/falcosecurity/falco/userspace/falco/falco.cpp)

The `falco_run()` function (lines 40-54) wraps `falco::app::run()` with error handling:

```cpp
// falco.cpp:40-54
int falco_run(int argc, char **argv, bool &restart) {
    restart = false;
    std::string errstr;
    try {
        if(!falco::app::run(argc, argv, restart, errstr)) {
            fprintf(stderr, "Error: %s\n", errstr.c_str());
            return EXIT_FAILURE;
        }
    } catch(std::exception &e) {
        display_fatal_err("Runtime error: " + std::string(e.what()) + ". Exiting.\n");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
```

**Source:** [`falco.cpp:40-54`](../refs/falcosecurity/falco/userspace/falco/falco.cpp)

### Application State

All components share a single `state` struct defined in [`state.h`](../refs/falcosecurity/falco/userspace/falco/app/state.h):

```cpp
// state.h:46-179
struct state {
    // Holds the info mapped for each loaded event source
    struct source_info {
        source_info(): filterchecks(std::make_shared<filter_check_list>()) {}

        // The index of the given event source in the state's falco_engine,
        // as returned by falco_engine::add_source
        std::size_t engine_idx = -1;
        // The filtercheck list containing all fields compatible
        // with the given event source
        std::shared_ptr<filter_check_list> filterchecks;
        // The inspector assigned to this event source. If in capture mode,
        // all event source will share the same inspector. If the event
        // source is a plugin one, the assigned inspector must have that
        // plugin registered in its plugin manager
        std::shared_ptr<sinsp> inspector;
    };

    state():
            config(std::make_shared<falco_configuration>()),
            engine(std::make_shared<falco_engine>()),
            offline_inspector(std::make_shared<sinsp>()) {}

    state(const std::string& cmd, const falco::app::options& opts): state() {
        cmdline = cmd;
        options = opts;
    }

    std::string cmdline;
    falco::app::options options;
    std::atomic<bool> restart = false;

    std::shared_ptr<falco_configuration> config;
    std::shared_ptr<falco_outputs> outputs;
    std::shared_ptr<falco_engine> engine;

    // The set of loaded event sources (by default, the syscall event
    // source plus all event sources coming from the loaded plugins).
    std::vector<std::string> loaded_sources;

    // The set of enabled event sources (can be altered by using
    // the --enable-source and --disable-source options)
    std::unordered_set<std::string> enabled_sources;

    // Used to load all plugins to get their info. In capture mode,
    // this is also used to open the capture file and read its events
    std::shared_ptr<sinsp> offline_inspector;

    // List of all the information mapped to each event source
    // indexed by event source name
    indexed_vector<source_info> source_infos;

    // List of all plugin configurations indexed by plugin name
    indexed_vector<falco_configuration::plugin_config> plugin_configs;

    // Set of syscalls we want the driver to capture
    libsinsp::events::set<ppm_sc_code> selected_sc_set;

    // Dimension of the syscall buffer in bytes.
    uint64_t syscall_buffer_bytes_size = DEFAULT_DRIVER_BUFFER_BYTES_DIM;

    // Helper responsible for watching of handling hot application restarts
    std::shared_ptr<restart_handler> restarter;

#if !defined(_WIN32) && !defined(__EMSCRIPTEN__) && !defined(MINIMAL_BUILD)
    falco_webserver webserver;
#endif

    // Set by start_webserver to start prometheus metrics
    // once all inspectors are opened.
    std::function<void()> on_inspectors_opened = nullptr;

    // Engine mode helpers
    inline bool is_capture_mode() const;
    inline bool is_kmod() const;
    inline bool is_modern_ebpf() const;
    inline bool is_nodriver() const;
    inline bool is_source_enabled(const std::string& src) const;
    inline bool is_driver_drop_failed_exit_enabled() const;
    inline int16_t driver_buf_size_preset() const;
};
```

**Source:** [`state.h:46-179`](../refs/falcosecurity/falco/userspace/falco/app/state.h)

The `source_info` struct maps each event source to its engine index, available filter fields, and assigned inspector. Key design points:

- **`offline_inspector`**: Shared inspector used for plugin loading and as the single inspector in capture mode.
- **`source_infos`**: Indexed vector providing per-source inspector and metadata for live mode.
- **`restart`**: Atomic boolean flag set by signal handlers to trigger the hot restart loop.
- **Conditional compilation**: webserver, metrics, and http_output are excluded in `MINIMAL_BUILD` and `__EMSCRIPTEN__` builds.

## Implementation Details

### Startup Sequence (run_steps)

The startup sequence is an ordered list of 28 actions defined in [`app.cpp:56-85`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp). Each action executes in order; if any returns `proceed = false`, the remaining run_steps are skipped (teardown always runs).

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
| 22 | `create_signal_handlers` | Set up SIGINT, SIGTERM, SIGHUP, SIGUSR1 handlers |
| 23 | `pidfile` | Write PID file if `--pidfile` configured |
| 24 | `configure_interesting_sets` | Compute syscall sets for kernel-level filtering |
| 25 | `configure_syscall_buffer_size` | Set driver ring buffer size |
| 26 | `configure_syscall_buffer_num` | Set number of ring buffers |
| 27 | `start_webserver` | Start health/metrics webserver (if not `MINIMAL_BUILD`) |
| 28 | **`process_events`** | **Main event loop (blocking until termination)** |

**Source:** [`app.cpp:56-88`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp)

The execution loop merges results and stops on `proceed = false`:

```cpp
// app.cpp:97-103
falco::app::run_result res = falco::app::run_result::ok();
for(const auto& func : run_steps) {
    res = falco::app::run_result::merge(res, func(s));
    if(!res.proceed) {
        break;
    }
}
```

**Source:** [`app.cpp:97-103`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp)

### Teardown Sequence

Teardown runs unconditionally after run_steps complete (whether by success, failure, or early exit), as defined in [`app.cpp:87-93`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp):

| Step | Action | Purpose |
|------|--------|---------|
| 1 | `unregister_signal_handlers` | Reset signal handlers to `SIG_DFL`, stop restart_handler |
| 2 | `stop_webserver` | Stop health/metrics webserver |
| 3 | `cleanup_outputs` | Flush and reset outputs (prints stats internally) |
| 4 | `close_inspectors` | Close all sinsp inspectors |

**Source:** [`app.cpp:87-93`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp)

Teardown never skips steps even on failure:

```cpp
// app.cpp:105-108
for(const auto& func : teardown_steps) {
    res = falco::app::run_result::merge(res, func(s));
    // note: we always proceed because we don't want to miss teardown steps
}
```

**Source:** [`app.cpp:105-108`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp)

### Event Processing Loop (do_inspect)

The core event processing loop is the `do_inspect()` function in [`process_events.cpp:104-365`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp). This is the inner loop where Falco spends most of its runtime.

```cpp
// process_events.cpp:161-362 (simplified)
while(1) {
    rc = inspector->next(&ev);  // Get event from libsinsp

    // 1. Handle SIGUSR1 (reopen outputs)
    if(g_reopen_outputs_signal.triggered()) {
        g_reopen_outputs_signal.handle([&s]() {
            s.outputs->reopen_outputs();
            g_reopen_outputs_signal.reset();
        });
    }

    // 2. Handle SIGINT/SIGTERM (terminate)
    if(g_terminate_signal.triggered()) {
        g_terminate_signal.handle([&]() { /* cleanup dumper */ });
        break;
    }

    // 3. Handle SIGHUP (restart)
    if(g_restart_signal.triggered()) {
        g_restart_signal.handle([&]() {
            s.restart.store(true);
        });
        break;
    }

    // 4. Handle return codes
    if(rc == SCAP_TIMEOUT) continue;
    if(rc == SCAP_FILTERED_EVENT) continue;
    if(rc == SCAP_EOF) break;
    if(rc != SCAP_SUCCESS) return run_result::fatal(inspector->getlasterr());

    // 5. Check event drops (syscall source only)
    if(check_drops_and_timeouts && !sdropmgr.process_event(inspector, ev)) {
        return run_result::fatal("Drop manager internal error");
    }

    // 6. Rule matching via falco_engine
    auto res = s.engine->process_event(source_engine_idx, ev, s.config->m_rule_matching);

    if(res != nullptr) {
        for(auto& rule_res : *res) {
            // 7. Output alert
            s.outputs->handle_event(rule_res.evt, rule_res.rule,
                                    rule_res.source, rule_res.priority_num,
                                    rule_res.format, rule_res.tags,
                                    rule_res.extra_output_fields);

            // 8. Handle capture if enabled
            if(s.config->m_capture_enabled && rule_res.capture) {
                // start or extend dump
            }
        }
    }

    // 9. Save events when a dump is in progress
    if(dump_started_ts != 0) {
        dumper->dump(ev);
    }

    num_evts++;
}
```

**Source:** [`process_events.cpp:104-365`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)

Key behaviors in the event loop:

- **Signal priority**: SIGUSR1 (reopen) is checked first (non-breaking), then SIGINT/SIGTERM (terminate), then SIGHUP (restart). Both terminate and restart cause the loop to `break`.
- **Timeout handling**: `SCAP_TIMEOUT` with `nullptr` event increments a consecutive timeout counter. After exceeding `m_syscall_evt_timeout_max_consecutives`, an internal notification is emitted.
- **Drop detection**: The `syscall_evt_drop_mgr` monitors for kernel event buffer drops on the syscall source, with configurable actions (ignore, log, alert, exit).
- **Rule matching**: `s.engine->process_event()` returns `nullptr` for no match, or a vector of `rule_result` for one or more matched rules (controlled by `m_rule_matching` strategy: first match or all matches).
- **Capture dumping**: When `m_capture_enabled` is set, matched events trigger `.scap` file capture with configurable duration deadlines.

### Signal Handling

Falco uses three global `atomic_signal_handler` instances for safe cross-thread signal communication, defined in [`signals.h`](../refs/falcosecurity/falco/userspace/falco/app/signals.h) and [`app.cpp:23-25`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp):

```cpp
// app.cpp:23-25
falco::atomic_signal_handler falco::app::g_terminate_signal;
falco::atomic_signal_handler falco::app::g_restart_signal;
falco::atomic_signal_handler falco::app::g_reopen_outputs_signal;
```

**Source:** [`signals.h`](../refs/falcosecurity/falco/userspace/falco/app/signals.h), [`app.cpp:23-25`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp)

Signal handlers are registered in [`create_signal_handlers.cpp:63-147`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp):

| Signal | Handler Function | Atomic Flag | Effect |
|--------|-----------------|-------------|--------|
| `SIGINT` | `terminate_signal_handler` | `g_terminate_signal.trigger()` | Graceful shutdown: breaks event loop, runs teardown |
| `SIGTERM` | `terminate_signal_handler` | `g_terminate_signal.trigger()` | Graceful shutdown: breaks event loop, runs teardown |
| `SIGHUP` | `restart_signal_handler` | `s_restarter->trigger()` | Hot restart: validates config, sets `s.restart = true` |
| `SIGUSR1` | `reopen_outputs_signal_handler` | `g_reopen_outputs_signal.trigger()` | Reopen output files (for log rotation) |

**Source:** [`create_signal_handlers.cpp:33-45`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp)

#### Atomic Signal Handler Pattern

The `atomic_signal_handler` class ([`atomic_signal_handler.h`](../refs/falcosecurity/falco/userspace/falco/atomic_signal_handler.h)) provides thread-safe signal handling:

- **`trigger()`**: Sets the atomic `m_triggered` flag (safe to call from signal context).
- **`triggered()`**: Returns whether the signal has been triggered (lock-free atomic read).
- **`handle(f)`**: Executes the handler function `f` exactly once among all concurrent callers, using a mutex for serialization. Subsequent calls return `false` until `reset()`.
- **`reset()`**: Returns the handler to its initial non-triggered, non-handled state.
- At startup, a lock-free check is performed; if the atomics are not lock-free, a warning is logged.

**Source:** [`atomic_signal_handler.h`](../refs/falcosecurity/falco/userspace/falco/atomic_signal_handler.h)

### Hot Reload

#### restart_handler

The [`restart_handler`](../refs/falcosecurity/falco/userspace/falco/app/restart_handler.h) class watches configuration and rules files/directories using Linux inotify:

```cpp
// restart_handler.h:32-71
class restart_handler {
public:
    using on_check_t = std::function<bool()>;   // Validation callback
    using watch_list_t = std::vector<std::string>;

    explicit restart_handler(on_check_t on_check,
                             const watch_list_t& watch_files = {},
                             const watch_list_t& watch_dirs = {});

    bool start(std::string& err);  // Start inotify watcher thread
    void stop();                    // Stop watcher thread
    void trigger();                 // Force a restart (used by SIGHUP)

private:
    void watcher_loop() noexcept;

    int m_inotify_fd = -1;
    std::thread m_watcher;
    std::atomic<bool> m_stop;
    std::atomic<bool> m_forced;
    on_check_t m_on_check;
    watch_list_t m_watched_dirs;
    watch_list_t m_watched_files;
};
```

**Source:** [`restart_handler.h`](../refs/falcosecurity/falco/userspace/falco/app/restart_handler.h)

#### Watched Files

When `watch_config_files: true` is set in `falco.yaml`, the restart_handler watches ([`create_signal_handlers.cpp:91-106`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp)):

- **Files**: All loaded config filenames + all loaded rules filenames
- **Directories**: All loaded config folders + all loaded rules folders

#### Validation Before Restart

Before confirming a restart, the `on_check` callback performs a **dry-run validation** ([`create_signal_handlers.cpp:109-134`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp)):

```cpp
// create_signal_handlers.cpp:109-134 (simplified)
s.restarter = std::make_shared<falco::app::restart_handler>(
    [&s] {
        bool tmp = false;
        bool success = false;
        std::string err;
        falco::app::state tmp_state(s.cmdline, s.options);
        tmp_state.options.dry_run = true;
        try {
            success = falco::app::run(tmp_state, tmp, err);
        } catch(std::exception& e) {
            err = e.what();
        }

        if(!success && s.outputs != nullptr) {
            std::string rule = "Falco internal: hot restart failure";
            std::string msg = rule + ": " + err;
            // ... emit PRIORITY_CRITICAL alert
        }

        return success;
    },
    files_to_watch,
    dirs_to_watch);
```

**Source:** [`create_signal_handlers.cpp:108-136`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp)

#### Hot Restart Process

1. **Trigger**: `SIGHUP` signal received or inotify detects file/directory change
2. **Validate**: Dry-run with new config/rules (creates a temporary `state`, runs `falco::app::run()` with `dry_run = true`)
3. **On validation failure**: Emit `PRIORITY_CRITICAL` alert ("Falco internal: hot restart failure") and abort restart
4. **On validation success**: `g_restart_signal.trigger()` is called
5. **Event loop break**: `do_inspect()` detects `g_restart_signal.triggered()`, sets `s.restart.store(true)`, and breaks
6. **Teardown**: All teardown steps execute (unregister signals, stop servers, close inspectors)
7. **Restart loop**: `falco_run()` returns `EXIT_SUCCESS` with `restart = true`, `main()` loop calls `falco_run()` again
8. **Full re-initialization**: Entire startup sequence executes with updated config/rules

### Inspector Management

Inspector creation and assignment is handled in [`init_inspectors.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/init_inspectors.cpp) and [`helpers_inspector.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp).

#### Capture Mode

In capture (replay) mode, all event sources share the single `offline_inspector`:

```cpp
// Capture mode: share one inspector
src_info->inspector = s.offline_inspector;
```

The offline inspector is opened via [`helpers_inspector.cpp:30-41`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp):

```cpp
s.offline_inspector->open_savefile(s.config->m_replay.m_capture_file);
```

#### Live Mode

In live mode, each event source gets its own inspector. The driver selection logic in [`helpers_inspector.cpp:43-149`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp) determines how to open the inspector:

| Engine Mode | Inspector Call | Description |
|-------------|----------------|-------------|
| Plugin source (non-syscall) | `inspector->open_plugin(name, params, ...)` | Opens a plugin event source |
| No driver (with plugin `id=0`) | `inspector->open_plugin(name, params, FULL)` | Plugin providing raw system events |
| No driver (without plugin) | `inspector->open_nodriver()` | No kernel event capture |
| Modern eBPF | `inspector->open_modern_bpf(buffer_size, cpus, true, sc_set, disable_iterators)` | CO-RE eBPF (default driver); the final `disable_iterators` arg (since 0.44.1) forces a procfs fallback instead of BPF iterators |
| Kernel module | `inspector->open_kmod(buffer_size, sc_set)` | Classic kernel module (auto-loads via modprobe on failure) |

**Source:** [`helpers_inspector.cpp:43-149`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp)

### Multi-Source Processing

The `process_events` action in [`process_events.cpp:480-659`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp) handles both single-source and multi-source scenarios:

#### Single Source Optimization

When only one event source is enabled, no additional threads are spawned. The event processing runs directly on the main thread:

```cpp
// process_events.cpp:565-576
if(s.enabled_sources.size() == 1) {
    if(s.on_inspectors_opened != nullptr) {
        s.on_inspectors_opened();
    }

    // optimization: with only one source we don't spawn additional threads
    process_inspector_events(s, src_info->inspector, statsw,
                             source, ctx.sync.get(), &ctx.res);
}
```

**Source:** [`process_events.cpp:565-576`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)

#### Multiple Sources

When multiple event sources are enabled, each source gets its own thread:

```cpp
// process_events.cpp:577-589
else {
    auto res_ptr = &ctx.res;
    auto sync_ptr = ctx.sync.get();
    ctx.thread = std::make_unique<std::thread>(
        [&s, src_info, &statsw, source, sync_ptr, res_ptr]() {
            process_inspector_events(s, src_info->inspector, statsw,
                                     source, sync_ptr, res_ptr);
        });
}
```

**Source:** [`process_events.cpp:577-589`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)

Thread coordination uses a `falco::semaphore` and `source_sync_context` objects. The main thread waits for any source thread to finish; if a thread fails, `g_terminate_signal` is triggered to force all other threads to exit:

```cpp
// process_events.cpp:607-614
if(!res.success && !termination_forced) {
    falco::app::g_terminate_signal.trigger();
    falco::app::g_terminate_signal.handle([&]() {});
    termination_forced = true;
}
```

**Source:** [`process_events.cpp:607-614`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)

**Shared across threads**: The `falco_engine` and `falco_outputs` are shared among all source threads via shared pointers in the `state` struct.

### Pidfile Management

The pidfile action ([`pidfile.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/pidfile.cpp)) writes the current process ID to a file specified by `--pidfile`:

```cpp
// pidfile.cpp:27-52
falco::app::run_result falco::app::actions::pidfile(const falco::app::state& state) {
    if(state.options.dry_run) {
        return run_result::ok();
    }
    if(state.options.pidfilename.empty()) {
        return run_result::ok();
    }

    int64_t self_pid = getpid();
    std::ofstream stream;
    stream.open(state.options.pidfilename);
    if(!stream.good()) {
        falco_logger::log(falco_logger::level::ERR,
                          "Could not write pid to pidfile " + state.options.pidfilename + "...");
        exit(-1);
    }
    stream << self_pid;
    stream.close();
    return run_result::ok();
}
```

**Source:** [`pidfile.cpp:27-52`](../refs/falcosecurity/falco/userspace/falco/app/actions/pidfile.cpp)

Note: Pidfile cleanup on exit is handled implicitly when the process terminates. There is no explicit cleanup action in the teardown sequence.

## Non-Functional Requirements

1. **Graceful shutdown**: On `SIGINT`/`SIGTERM`, the event loop breaks cleanly, active capture dumps are closed, and all teardown steps execute unconditionally to release resources (inspectors, servers, signal handlers).

2. **Validation before hot reload**: Hot restarts always perform a dry-run validation of the new configuration and rules before committing to a restart. If validation fails, a `PRIORITY_CRITICAL` alert is emitted and the running instance continues unaffected.

3. **Atomic signal flags**: All signal communication uses `atomic_signal_handler` with `std::atomic<bool>` and `std::mutex` for handler-once semantics. A lock-free check is performed at startup, with a warning logged if atomics are not lock-free on the platform.

4. **Thread safety**: Multi-source mode uses one thread per source with a semaphore-based synchronization model. The `falco_engine` and `falco_outputs` shared pointers are safely accessed from multiple threads.

5. **Ordered teardown**: Teardown steps always execute in full, regardless of whether run_steps succeeded or failed. The result merging ensures all errors are accumulated.

## Related Specs

- [`architecture-overview.md`](architecture-overview.md) - High-level system architecture
- [`kernel-instrumentation.md`](kernel-instrumentation.md) - Kernel driver details (modern_ebpf, kmod, eBPF)

## Related Digests

- [`digests/falcosecurity/falco/architecture.md`](../digests/falcosecurity/falco/architecture.md) - Full Falco architecture digest
- [`digests/falcosecurity/falco/configuration.md`](../digests/falcosecurity/falco/configuration.md) - Configuration reference
- [`digests/falcosecurity/falco/outputs.md`](../digests/falcosecurity/falco/outputs.md) - Alert output channels
- [`digests/falcosecurity/falco/cli-reference.md`](../digests/falcosecurity/falco/cli-reference.md) - CLI options and introspection

## Sources

| Topic | Source File |
|-------|-------------|
| Entry point | [`userspace/falco/falco.cpp`](../refs/falcosecurity/falco/userspace/falco/falco.cpp) |
| Application flow | [`userspace/falco/app/app.cpp`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp) |
| Application state | [`userspace/falco/app/state.h`](../refs/falcosecurity/falco/userspace/falco/app/state.h) |
| Event processing | [`userspace/falco/app/actions/process_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp) |
| Signal handlers | [`userspace/falco/app/actions/create_signal_handlers.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp) |
| Signal globals | [`userspace/falco/app/signals.h`](../refs/falcosecurity/falco/userspace/falco/app/signals.h) |
| Atomic signal handler | [`userspace/falco/atomic_signal_handler.h`](../refs/falcosecurity/falco/userspace/falco/atomic_signal_handler.h) |
| Restart handler | [`userspace/falco/app/restart_handler.h`](../refs/falcosecurity/falco/userspace/falco/app/restart_handler.h) |
| Inspector helpers | [`userspace/falco/app/actions/helpers_inspector.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp) |
| Pidfile | [`userspace/falco/app/actions/pidfile.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/pidfile.cpp) |
