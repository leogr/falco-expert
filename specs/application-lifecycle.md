# Application Lifecycle

> Entry point, modular action framework, startup/teardown sequences, signal handling, hot reload, and multi-source inspector management.

**Era:** 0.45 | **Source:** [`refs/falcosecurity/falco/userspace/falco/app/`](../refs/falcosecurity/falco/userspace/falco/app/)

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

**Source:** [`falco.cpp:59-71`](../refs/falcosecurity/falco/userspace/falco/falco.cpp#L59-L71)

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

**Source:** [`falco.cpp:40-54`](../refs/falcosecurity/falco/userspace/falco/falco.cpp#L40-L54)

### Application State

All components share a single `state` struct defined in [`state.h`](../refs/falcosecurity/falco/userspace/falco/app/state.h):

```cpp
// state.h:48-168
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
#ifdef __linux__
    falco_reload_control reload_control;
#endif
#endif

    // Set by start_webserver to start prometheus metrics
    // once all inspectors are opened.
    std::function<void()> on_inspectors_opened = nullptr;

    // Engine mode helpers
    inline bool is_replaying() const;
    inline bool is_kmod() const;
    inline bool is_modern_ebpf() const;
    inline bool is_nodriver() const;
    inline bool is_source_enabled(const std::string& src) const;
    inline bool is_driver_drop_failed_exit_enabled() const;
    inline int16_t driver_buf_size_preset() const;
};
```

**Source:** [`state.h:48-168`](../refs/falcosecurity/falco/userspace/falco/app/state.h#L48-L168)

The `source_info` struct maps each event source to its engine index, available filter fields, and assigned inspector. Key design points:

- **`offline_inspector`**: Shared inspector used for plugin loading and as the single inspector in capture mode.
- **`source_infos`**: Indexed vector providing per-source inspector and metadata for live mode.
- **`restart`**: Atomic boolean flag set by event processing after a validated restart request, then returned to the outer hot restart loop.
- **Conditional compilation**: webserver, metrics, and http_output are excluded in `MINIMAL_BUILD` and `__EMSCRIPTEN__` builds.

## Implementation Details

### Startup Sequence (run_steps)

The startup sequence is an ordered list of 28 actions defined in [`app.cpp:63-92`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L63-L92). Each action executes in order; if any returns `proceed = false`, the remaining run_steps are skipped (teardown always runs).

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

**Source:** [`app.cpp:63-95`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L63-L95)

The execution loop merges results and stops on `proceed = false`:

```cpp
// app.cpp:104-113
falco::app::run_result res = falco::app::run_result::ok();
for(const auto& func : run_steps) {
    res = falco::app::run_result::merge(res, func(s));
    if(!res.proceed) {
        break;
    }
}
```

**Source:** [`app.cpp:104-113`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L104-L113)

### Teardown Sequence

Teardown runs unconditionally after run_steps complete (whether by success, failure, or early exit), as defined in [`app.cpp:94-100`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L94-L100):

| Step | Action | Purpose |
|------|--------|---------|
| 1 | `unregister_signal_handlers` | Stop restart worker; reset SIGINT/SIGTERM/SIGUSR1; retain SIGHUP handler/eventfd |
| 2 | `stop_webserver` | Stop Unix reload listener and health/metrics webserver |
| 3 | `cleanup_outputs` | Flush and reset outputs (prints stats internally) |
| 4 | `close_inspectors` | Close all sinsp inspectors |

**Source:** [`app.cpp:94-100`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L94-L100)

Teardown never skips steps even on failure:

```cpp
// app.cpp:115-118
for(const auto& func : teardown_steps) {
    res = falco::app::run_result::merge(res, func(s));
    // note: we always proceed because we don't want to miss teardown steps
}
```

**Source:** [`app.cpp:115-118`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L115-L118)

### Event Processing Loop (do_inspect)

The core event processing loop is the `do_inspect()` function in [`process_events.cpp:105-369`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp#L105-L369). This is the inner loop where Falco spends most of its runtime.

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

**Source:** [`process_events.cpp:105-369`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp#L105-L369)

Key behaviors in the event loop:

- **Signal priority**: SIGUSR1 (reopen) is checked first (non-breaking), then SIGINT/SIGTERM (terminate), then SIGHUP (restart). Both terminate and restart cause the loop to `break`.
- **Timeout handling**: `SCAP_TIMEOUT` with `nullptr` event increments a consecutive timeout counter. After exceeding `m_syscall_evt_timeout_max_consecutives`, an internal notification is emitted.
- **Drop detection**: The `syscall_evt_drop_mgr` monitors for kernel event buffer drops on the syscall source, with configurable actions (ignore, log, alert, exit).
- **Rule matching**: `s.engine->process_event()` returns `nullptr` for no match, or a vector of `rule_result` for one or more matched rules (controlled by `m_rule_matching` strategy: first match or all matches).
- **Capture dumping**: When `m_capture_enabled` is set, matched events trigger `.scap` file capture with configurable duration deadlines.

### Signal Handling

| Signal | Handler | Effect |
|--------|---------|--------|
| `SIGINT` / `SIGTERM` | `g_terminate_signal.trigger()` | Event loops exit and teardown runs |
| `SIGUSR1` | `g_reopen_outputs_signal.trigger()` | Event loop requests output reopen for rotation |
| `SIGHUP` | `request_reload()` | Increment a lock-free request counter and wake the restart worker through a nonblocking eventfd |

The terminate/restart/reopen `atomic_signal_handler` objects provide atomic flags and a mutex-protected `handle()` method for once-only handling outside signal context. SIGHUP uses a separate process-lifetime `reload_state` and eventfd. Initialization requires its request atomics to be lock-free; its handler and descriptor remain installed through hot-restart teardown, avoiding access to destroyed per-run objects. SIGINT/SIGTERM/SIGUSR1 are reset to `SIG_DFL` during teardown.

**Source:** [`create_signal_handlers.cpp:35-117`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp#L35-L117), [`create_signal_handlers.cpp:211-230`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp#L211-L230), [`atomic_signal_handler.h`](../refs/falcosecurity/falco/userspace/falco/atomic_signal_handler.h), [`reload_state.h`](../refs/falcosecurity/falco/userspace/falco/app/reload_state.h).

### Hot Reload

The Linux `restart_handler` worker runs even when `watch_config_files` is false. It creates inotify only when there are configured paths to watch. Watched files are the loaded configuration/rules files; watched directories are their configured folders. `select()` waits on inotify, a worker eventfd, and the process-lifetime reload eventfd. Shutdown wakes the worker instead of waiting for an idle poll timeout.

**Source:** [`create_signal_handlers.cpp:151-201`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp#L151-L201), [`restart_handler.cpp:71-175`](../refs/falcosecurity/falco/userspace/falco/app/restart_handler.cpp#L71-L175).

The restart sequence is:

1. Receive a file change, SIGHUP, or Unix `POST /reload` request.
2. Debounce changes, then run the application against a temporary `state` with `dry_run=true` and the original command-line options.
3. If validation fails, record the rejected generation and emit `Falco internal: hot restart failure` at critical priority; the active run continues.
4. If validation succeeds and no newer request/change intervenes, trigger `g_restart_signal`; a newer change causes another validation pass.
5. Event processing sets `s.restart=true` and exits. Readiness becomes false and all teardown steps run.
6. The outer `main()` loop calls `falco_run()` again. Configuration, rules, plugins and inspectors are reconstructed within the same process.
7. Once every enabled live source has successfully started capture, record the applied generation and set `ready=true`.

Validation is a preflight, not an atomic transaction or rollback guarantee. Resources and filesystem state can change before actual restart, and opening capture/socket resources can still fail.

**Source:** [`create_signal_handlers.cpp:168-197`](../refs/falcosecurity/falco/userspace/falco/app/actions/create_signal_handlers.cpp#L168-L197), [`restart_handler.cpp:172-282`](../refs/falcosecurity/falco/userspace/falco/app/restart_handler.cpp#L172-L282), [`app.cpp:55-121`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L55-L121), [`process_events.cpp:157-195`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp#L157-L195), [`reload_state.cpp:37-76`](../refs/falcosecurity/falco/userspace/falco/app/reload_state.cpp#L37-L76), [`falco.cpp:59-71`](../refs/falcosecurity/falco/userspace/falco/falco.cpp#L59-L71).

#### Administrative Reload API (0.45)

The optional Linux, non-minimal `reload_control` listener serves HTTP over a filesystem Unix socket independently of the TCP health/metrics webserver. `start_webserver` validates its directory during dry-run, starts it during live startup, and stops it during teardown; replay does not start listeners. `state.reload_control` owns the per-run listener while global reload progress survives its recreation.

`POST /reload` rejects body, multipart, or query input with 400. Acceptance returns 202, a `Location: /reload` header, and `instance_id` plus `started_generation` as the baseline; an unavailable notification returns 503. `GET /reload` returns all generation fields and readiness with `Cache-Control: no-store`. GET is also available over TCP; POST is only registered on the Unix listener.

Clients finish writing files before POST, then wait for the **same** instance with `ready=true` and `applied_generation > max(baseline, rejected_generation)`. A newer rejection indicates invalid input. Connection loss/timeout is an unknown outcome; retry status reads through listener outages, and submit a new request if process identity changed. Socket access is controlled by directory ownership/modes and group access; see [configuration](configuration.md#hot-reload) for provisioning requirements.

**Source:** [`start_webserver.cpp:27-87`](../refs/falcosecurity/falco/userspace/falco/app/actions/start_webserver.cpp#L27-L87), [`reload_control.cpp:210-334`](../refs/falcosecurity/falco/userspace/falco/reload_control.cpp#L210-L334), [`webserver.cpp:50-60`](../refs/falcosecurity/falco/userspace/falco/webserver.cpp#L50-L60), [`falco.yaml:967-994`](../refs/falcosecurity/falco/falco.yaml#L967-L994).

### Inspector Management

Inspector creation and assignment is handled in [`init_inspectors.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/init_inspectors.cpp) and [`helpers_inspector.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp).

#### Capture Mode

In capture (replay) mode, all event sources share the single `offline_inspector`:

```cpp
// Capture mode: share one inspector
src_info->inspector = s.offline_inspector;
```

The offline inspector is opened via [`helpers_inspector.cpp:117-128`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp#L117-L128):

```cpp
s.offline_inspector->open_savefile(s.config->m_replay.m_capture_file);
```

#### Live Mode

In live mode, each event source gets its own inspector. The driver selection logic in [`helpers_inspector.cpp:130-226`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp#L130-L226) determines how to open the inspector:

| Engine Mode | Inspector Call | Description |
|-------------|----------------|-------------|
| Plugin source (non-syscall) | `inspector->open_plugin(name, params, ...)` | Opens a plugin event source |
| No driver (with plugin `id=0`) | `inspector->open_plugin(name, params, FULL)` | Plugin providing raw system events |
| No driver (without plugin) | `inspector->open_nodriver()` | No kernel event capture |
| Modern eBPF | `inspector->open_modern_bpf(buffer_size, cpus, true, sc_set, disable_iterators)` | CO-RE eBPF (default driver); the final `disable_iterators` arg (since 0.44.1) forces a procfs fallback instead of BPF iterators |
| Kernel module | `inspector->open_kmod(buffer_size, sc_set)` | Classic kernel module (auto-loads via modprobe on failure) |

**Source:** [`helpers_inspector.cpp:130-226`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp#L130-L226)

### Multi-Source Processing

The `process_events` action in [`process_events.cpp:486-668`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp#L486-L668) handles both single-source and multi-source scenarios:

#### Single Source Optimization

When only one event source is enabled, no additional threads are spawned. The event processing runs directly on the main thread:

```cpp
// process_events.cpp:571-583
if(s.enabled_sources.size() == 1) {
    if(s.on_inspectors_opened != nullptr) {
        s.on_inspectors_opened();
    }

    // optimization: with only one source we don't spawn additional threads
    process_inspector_events(s, src_info->inspector, statsw,
                             source, ctx.sync.get(), &ctx.res);
}
```

**Source:** [`process_events.cpp:571-583`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp#L571-L583)

#### Multiple Sources

When multiple event sources are enabled, each source gets its own thread:

```cpp
// process_events.cpp:584-597
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

**Source:** [`process_events.cpp:584-597`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp#L584-L597)

Thread coordination uses a `falco::semaphore` and `source_sync_context` objects. The main thread waits for any source thread to finish; if a thread fails, `g_terminate_signal` is triggered to force all other threads to exit:

```cpp
// process_events.cpp:615-622
if(!res.success && !termination_forced) {
    falco::app::g_terminate_signal.trigger();
    falco::app::g_terminate_signal.handle([&]() {});
    termination_forced = true;
}
```

**Source:** [`process_events.cpp:615-622`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp#L615-L622)

**Shared across threads**: The `falco_engine` and `falco_outputs` are shared among all source threads via shared pointers in the `state` struct.

### Pidfile Management

The `--pidfile` action skips writes in dry-run or when no path is supplied. On POSIX it opens with `O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC` and mode 0644, writes PID plus newline, and closes the descriptor. The final path cannot be a symlink. Failure calls `exit(-1)` (normally observed as status 255 on POSIX), rather than returning an action error. On Windows the implementation checks for reparse points before `CreateFileA`; the source explicitly notes that check is not race-free.

There is no unlink action for the PID file in teardown: process exit closes descriptors but does not remove the file.

**Source:** [`pidfile.cpp:68-150`](../refs/falcosecurity/falco/userspace/falco/app/actions/pidfile.cpp#L68-L150), [`app.cpp:94-100`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp#L94-L100).

## Non-Functional Requirements

1. **Graceful shutdown**: On `SIGINT`/`SIGTERM`, the event loop breaks cleanly, active capture dumps are closed, and all teardown steps execute unconditionally to release resources (inspectors, servers, signal handlers).

2. **Validation before hot reload**: Hot restarts always perform a dry-run validation of the new configuration and rules before committing to a restart. If validation fails, a `PRIORITY_CRITICAL` alert is emitted and the running instance continues unaffected.

3. **Signal safety**: SIGINT/SIGTERM/SIGUSR1 use atomic flags with mutex-protected once-only handling outside signal context. SIGHUP uses a lock-free request counter and a process-lifetime eventfd; startup fails if its atomics are not lock-free.

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
