# Architecture Overview

> End-to-end system architecture of Falco: event pipeline, component boundaries, threading model, and multi-source event handling.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco/`](../refs/falcosecurity/falco/), [`refs/falcosecurity/libs/`](../refs/falcosecurity/libs/)

## Overview

Falco is a runtime security tool that detects threats by matching kernel-level system events against a set of rules. It is built as a layered architecture where each layer has a well-defined responsibility:

1. **Kernel Driver** — captures syscalls and kernel events
2. **libscap** — abstracts driver communication and delivers raw events
3. **libsinsp** — parses events, maintains state tables, provides field extraction
4. **falco_engine** — compiles and evaluates rules against enriched events
5. **falco_outputs** — formats and delivers alerts through configured channels
6. **Falco Application** — orchestrates all components through a modular action framework

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
|  |   - Multi-producer async queue                             |  |
|  |   - Worker thread for output delivery                      |  |
|  |   - Channels: stdout, file, syslog, HTTP, program          |  |
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
|           (modern_bpf | kmod | plugin | nodriver)                 |
+------------------------------------------------------------------+
```

**Source:** [`digests/falcosecurity/falco/architecture.md`](../digests/falcosecurity/falco/architecture.md), [`digests/falcosecurity/libs/architecture.md`](../digests/falcosecurity/libs/architecture.md)

## Event Pipeline

The event pipeline is the core data flow through Falco. Every security-relevant system event traverses this pipeline from kernel capture to alert delivery.

### End-to-End Flow

```
1. Kernel Event (syscall, tracepoint)
         |
         v
2. Driver captures event → Ring Buffer
         |
         v
3. libscap: scap_next() retrieves raw event
         |
         v
4. libsinsp: Event parsing + State update + Enrichment
         |
         v
5. Falco Engine: process_event() → Rule matching
         |
         v
6. If matched: falco_outputs.handle_event()
         |
         v
7. Output Worker: Format and deliver alert
```

### Pipeline Stages

| Stage | Component | Input | Output | Spec |
|-------|-----------|-------|--------|------|
| Capture | Kernel Driver | Syscall/tracepoint | Raw event in ring buffer | [`kernel-instrumentation.md`](kernel-instrumentation.md) |
| Retrieval | libscap | Ring buffer poll | `scap_evt` (raw event) | [`libscap.md`](libscap.md) |
| Parsing | libsinsp (`sinsp_parser`) | `scap_evt` | `sinsp_evt` (enriched event) | [`libsinsp.md`](libsinsp.md) |
| State Update | libsinsp (state tables) | `sinsp_evt` | Updated thread/FD tables | [`libsinsp.md`](libsinsp.md) |
| Field Extraction | libsinsp (filterchecks) | `sinsp_evt` + state | Field values for filters | [`filter-engine.md`](filter-engine.md) |
| Rule Matching | falco_engine | `sinsp_evt` + ruleset | Match result(s) | [`rule-engine.md`](rule-engine.md) |
| Alert Delivery | falco_outputs | Match result | Formatted alert on channel(s) | [`output-system.md`](output-system.md) |

**Source:** [`digests/falcosecurity/libs/architecture.md`](../digests/falcosecurity/libs/architecture.md), [`digests/falcosecurity/falco/architecture.md`](../digests/falcosecurity/falco/architecture.md)

## Component Boundaries and Interfaces

### libscap → libsinsp

libscap provides raw events to libsinsp through the `scap_next()` API. The engine vtable abstraction (`scap_vtable`) allows different capture backends (modern eBPF, kmod, savefile, plugin) to present a uniform interface.

```
libsinsp::sinsp::next(sinsp_evt** evt)
    └─→ scap_next(m_h, &scap_evt, &cpuid, &flags)
            └─→ vtable->next(engine_handle, &pevent, &pdevid, &pflags)
```

**Key interface:** `scap_vtable.next()` returns a `scap_evt*` pointer to the raw event data.

**Source:** [`digests/falcosecurity/libs/libscap.md`](../digests/falcosecurity/libs/libscap.md)

### libsinsp → falco_engine

The Falco engine receives enriched `sinsp_evt` pointers from libsinsp. The engine does not own the event data — it processes each event synchronously during the `process_event()` call.

```cpp
// falco_engine.h:259-262
std::unique_ptr<std::vector<rule_result>> process_event(
    std::size_t source_idx,
    sinsp_evt *ev,
    uint16_t ruleset_id,
    falco_common::rule_matching strategy
);
```

The engine uses `sinsp_filter_factory` and `sinsp_evt_formatter_factory` to create filters and formatters that operate on `sinsp_evt` objects.

**Source:** [`refs/falcosecurity/falco/userspace/engine/falco_engine.h`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)

### falco_engine → falco_outputs

When a rule matches, the engine returns a vector of `rule_result` structs. The application passes these to `falco_outputs::handle_event()`, which enqueues the alert for async delivery.

```cpp
// From process_events.cpp do_inspect loop
auto res = s.engine->process_event(source_engine_idx, ev, s.config->m_rule_matching);
if(res != nullptr) {
    for(auto& rule_res : *res) {
        s.outputs->handle_event(rule_res.evt, rule_res.rule, ...);
    }
}
```

**Source:** [`refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)

## Threading Model

Falco uses a multi-threaded architecture with a clear separation of concerns between threads.

```
+-------------------+
|   Main Thread     |  ← Event processing (do_inspect loop)
| - inspector.next()|    Single-threaded, stateful
| - engine.process()|
+-------------------+
         |
         v (queue push)
+-------------------+
|  Output Worker    |  ← Async output delivery
| - TBB concurrent  |    Consumes from bounded queue
|   queue           |
+-------------------+

+-------------------+
|  Web Server       |  ← cpp-httplib threads
| - /healthz        |    Health + Prometheus metrics
| - /metrics        |
+-------------------+

+-------------------+
|  Restart Handler  |  ← inotify watcher thread
| - Config changes  |    Triggers hot reload
| - Rules changes   |
+-------------------+
```

### Thread Responsibilities

| Thread | Purpose | Concurrency Model |
|--------|---------|-------------------|
| Main thread | Event capture, parsing, rule matching | Single-threaded per source (see below) |
| Output worker | Alert formatting and delivery | Consumer on TBB concurrent queue |
| Web server | Health checks, metrics endpoint | cpp-httplib internal threads |
| Restart handler | Watch config/rules files for changes | inotify-based watcher |

### Multi-Source Threading

When multiple event sources are enabled (e.g., syscall + k8saudit plugin), each source gets its own processing thread:

```cpp
// process_events.cpp:532-598
if(s.enabled_sources.size() == 1) {
    // Optimization: single-threaded for one source
    process_inspector_events(...);
} else {
    // Multi-threaded: one thread per source
    for(const auto& source : s.enabled_sources) {
        ctx.thread = std::make_unique<std::thread>([...] {
            process_inspector_events(s, src_info->inspector, ...);
        });
    }
}
```

Each thread has its own `sinsp` inspector instance and processes events independently. The `falco_engine` and `falco_outputs` are shared across threads.

**Source:** [`refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)

## Multi-Source Event Handling

Falco supports multiple event sources simultaneously through the inspector-per-source model.

### Event Sources

| Source | Provider | Inspector Type |
|--------|----------|---------------|
| `syscall` | Kernel driver (modern_bpf, kmod) | Direct driver inspector |
| Plugin sources | Plugins with `CAP_SOURCING` (e.g., k8saudit, cloudtrail) | Plugin-backed inspector |

### Source Registration

During startup, sources are registered in a specific order:

1. The `syscall` source is always registered first as the default source
2. Plugin sources are registered for each plugin with `CAP_SOURCING` capability and a non-zero event source ID

```cpp
// load_plugins.cpp
s.source_infos.insert(syscall_src_info, falco_common::syscall_source);
s.loaded_sources = {falco_common::syscall_source};

for(auto& p : s.config->m_plugins) {
    auto plugin = s.offline_inspector->register_plugin(p.m_library_path);
    if((plugin->caps() & CAP_SOURCING) && plugin->id() != 0) {
        s.source_infos.insert(src_info, plugin->event_source());
        s.loaded_sources.push_back(plugin->event_source());
    }
}
```

### Per-Source State

Each source maintains its own metadata through the `source_info` structure:

```cpp
struct source_info {
    std::size_t engine_idx;                        // Index in falco_engine
    std::shared_ptr<filter_check_list> filterchecks; // Available filter fields
    std::shared_ptr<sinsp> inspector;              // Assigned inspector
};
```

**Source:** [`refs/falcosecurity/falco/userspace/falco/app/state.h`](../refs/falcosecurity/falco/userspace/falco/app/state.h), [`refs/falcosecurity/falco/userspace/falco/app/actions/load_plugins.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/load_plugins.cpp)

## Application State

The entire Falco application state is contained in a single `falco::app::state` struct, passed to all action functions:

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
    std::vector<std::string> loaded_sources;
    std::unordered_set<std::string> enabled_sources;

    // Inspector management
    std::shared_ptr<sinsp> offline_inspector;
    indexed_vector<source_info> source_infos;

    // Plugin configuration
    indexed_vector<falco_configuration::plugin_config> plugin_configs;

    // Syscall configuration
    libsinsp::events::set<ppm_sc_code> selected_sc_set;
    uint64_t syscall_buffer_bytes_size;

    // Hot reload
    std::shared_ptr<restart_handler> restarter;

    // Servers
    falco_webserver webserver;
};
```

**Source:** [`refs/falcosecurity/falco/userspace/falco/app/state.h`](../refs/falcosecurity/falco/userspace/falco/app/state.h)

## Version Compatibility

### Component Versions (Era 0.44)

| Component | Version | Compatibility Scope |
|-----------|---------|-------------------|
| Falco | 0.44.1 | Application release |
| Libs | 0.25.4 | Library API |
| Driver API | 10.0.0 (minimum required by the Falco 0.44.x binary, measured on 0.44.0); libs 0.25.4 source publishes 10.1.0 | Kernel/userspace boundary |
| Schema | 4.3.0 (minimum required by the Falco 0.44.x binary, measured on 0.44.0); libs 0.25.4 source publishes 4.5.1 | Event data format |
| Plugin API | 3.12.0 | Plugin/host interface |

> `falco --version` for the bundled 0.44.0 binary reports Driver API `10.0.0` and Schema `4.3.0` — these are the **minimum versions Falco requires** of the drivers it talks to (the binary analyzed in the knowledge base is 0.44.0; the era pin now bundles libs 0.25.4 via Falco 0.44.1). The libs 0.25.4 source files [`driver/API_VERSION`](../refs/falcosecurity/libs/driver/API_VERSION) and [`driver/SCHEMA_VERSION`](../refs/falcosecurity/libs/driver/SCHEMA_VERSION) advertise newer numbers (`10.1.0`/`4.5.1`) because libs picked up backward-compatible additions; these source values are unchanged between libs 0.25.2 and 0.25.4.

### Compatibility Rules

- **Driver API** version changes require driver and userspace to be rebuilt together
- **Schema** version changes may require rule updates to handle new event parameters
- **Plugin API** is backward compatible within the same major version

**Source:** [`digests/falcosecurity/libs/architecture.md`](../digests/falcosecurity/libs/architecture.md)

## Removed Features (0.44)

The following features were deprecated in 0.43 and **removed in 0.44**; they are not covered by these specifications:

| Feature | Status | Replacement |
|---------|--------|-------------|
| Legacy eBPF driver (`driver/bpf/`) | **Removed in 0.44** ([PR #3796](https://github.com/falcosecurity/falco/pull/3796)) | Modern eBPF driver |
| gVisor engine | **Removed in 0.44** ([PR #3797](https://github.com/falcosecurity/falco/pull/3797)) | — |
| gRPC output channel | **Removed in 0.44** ([PR #3798](https://github.com/falcosecurity/falco/pull/3798)) | HTTP output, falcosidekick |

**Source:** [`digests/falcosecurity/falco/proposals.md`](../digests/falcosecurity/falco/proposals.md)

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Kernel driver capture layer |
| [`libscap.md`](libscap.md) | Raw event retrieval and engine abstraction |
| [`libsinsp.md`](libsinsp.md) | Event parsing, state management, field extraction |
| [`filter-engine.md`](filter-engine.md) | Filter expression compilation and evaluation |
| [`rule-engine.md`](rule-engine.md) | Rule compilation and event matching |
| [`configuration.md`](configuration.md) | Configuration system and option reference |
| [`output-system.md`](output-system.md) | Alert formatting and delivery channels |
| [`plugin-system.md`](plugin-system.md) | Plugin API and capability model |
| [`metrics-and-observability.md`](metrics-and-observability.md) | Internal metrics and health monitoring |
| [`application-lifecycle.md`](application-lifecycle.md) | Startup, shutdown, hot reload, signal handling |
| [`cli-interface.md`](cli-interface.md) | CLI flags and introspection commands |
| [`falcoctl.md`](falcoctl.md) | Artifact and driver management tool |
| [`build-system.md`](build-system.md) | CMake build, dependencies, feature flags |

## Sources

| Topic | Source File |
|-------|-------------|
| Falco architecture | [`digests/falcosecurity/falco/architecture.md`](../digests/falcosecurity/falco/architecture.md) |
| Libs architecture | [`digests/falcosecurity/libs/architecture.md`](../digests/falcosecurity/libs/architecture.md) |
| Entry point | [`refs/falcosecurity/falco/userspace/falco/falco.cpp`](../refs/falcosecurity/falco/userspace/falco/falco.cpp) |
| Application flow | [`refs/falcosecurity/falco/userspace/falco/app/app.cpp`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp) |
| Application state | [`refs/falcosecurity/falco/userspace/falco/app/state.h`](../refs/falcosecurity/falco/userspace/falco/app/state.h) |
| Event processing | [`refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp) |
| Plugin loading | [`refs/falcosecurity/falco/userspace/falco/app/actions/load_plugins.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/load_plugins.cpp) |
| Engine init | [`refs/falcosecurity/falco/userspace/falco/app/actions/init_falco_engine.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/init_falco_engine.cpp) |
| falco_engine header | [`refs/falcosecurity/falco/userspace/engine/falco_engine.h`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h) |
