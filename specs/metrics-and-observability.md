# Metrics and Observability

> Internal metrics framework, statistics collection, event drop detection, webserver endpoints, and health monitoring.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco/userspace/falco/`](../refs/falcosecurity/falco/userspace/falco/)

## Overview

Falco provides an internal metrics framework for monitoring its own health, performance, and system state. Metrics are collected periodically and can be delivered through three output channels:

1. **Prometheus endpoint** (`/metrics`) -- scraped by Prometheus, exposed via the built-in webserver
2. **Falco rule output** -- emitted as internal alert messages ("Falco internal: metrics snapshot") through the standard output pipeline
3. **JSONL file** -- appended to a file on disk for offline analysis

The metrics system is composed of two layers: **Falco-level metrics** (rule counters, config/rules file checksums, jemalloc stats) collected by `falco_metrics`, and **libs-level metrics** (resource utilization, kernel counters, state counters, libbpf stats, plugin metrics) collected by `libs::metrics::libs_metrics_collector` from libsinsp. Both layers feed into the output channels via the `stats_writer` (for rule output and file output) and `falco_metrics::to_text_prometheus()` (for the Prometheus endpoint).

**Source:** [`falco_metrics.h`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.h), [`falco_metrics.cpp`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp), [`stats_writer.h`](../refs/falcosecurity/falco/userspace/falco/stats_writer.h), [`stats_writer.cpp`](../refs/falcosecurity/falco/userspace/falco/stats_writer.cpp), [`metrics_collector.h`](../refs/falcosecurity/libs/userspace/libsinsp/metrics_collector.h)

## Architecture

### Metrics Collection Pipeline

```
                          ┌──────────────────────────┐
                          │     falco_metrics         │
                          │  (Falco-level metrics)    │
                          │  - version, SHA256 files  │
                          │  - rules counters         │
                          │  - jemalloc stats         │
                          │  - outputs_queue_num_drops│
                          └────────────┬─────────────┘
                                       │
     ┌─────────────────────────────────┤
     │                                 │
     ▼                                 ▼
┌─────────────┐        ┌──────────────────────────────┐
│  /metrics   │        │    stats_writer::collector    │
│ (Prometheus │        │  (periodic tick-based)        │
│  endpoint)  │        │                               │
└─────────────┘        │  ┌─────────────────────────┐  │
                       │  │ libs_metrics_collector   │  │
                       │  │ (libs-level metrics)     │  │
                       │  │ - resource utilization   │  │
                       │  │ - kernel counters        │  │
                       │  │ - state counters         │  │
                       │  │ - libbpf stats           │  │
                       │  │ - plugin metrics         │  │
                       │  └─────────────────────────┘  │
                       └──────────┬───────────────────┘
                                  │
                         ┌────────┴────────┐
                         │                 │
                         ▼                 ▼
                  ┌────────────┐   ┌─────────────┐
                  │ Rule Output│   │ JSONL File   │
                  │ (handle_msg)   │ (m_file_output)
                  └────────────┘   └─────────────┘
```

The Prometheus endpoint is serviced on-demand (each HTTP request triggers `falco_metrics::to_text_prometheus()`), while the rule output and file output channels are driven by a periodic timer through the `stats_writer`.

**Source:** [`falco_metrics.cpp:523-547`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp), [`stats_writer.cpp:230-275`](../refs/falcosecurity/falco/userspace/falco/stats_writer.cpp)

### Webserver

The webserver is a [cpp-httplib](https://github.com/yhirose/cpp-httplib) based HTTP(S) server implemented in `falco_webserver`. It runs in a dedicated thread and provides health, version, and metrics endpoints.

**Endpoints:**

| Endpoint | Method | Content Type | Purpose |
|----------|--------|-------------|---------|
| `/healthz` (configurable) | GET | `application/json` | Health check: returns `{"status": "ok"}` |
| `/versions` | GET | `application/json` | Version information JSON (used by falcoctl) |
| `/metrics` | GET | `text/plain; version=0.0.4` | Prometheus exposition format (requires `metrics.enabled` and `webserver.prometheus_metrics_enabled`) |

The healthz endpoint path is configurable via `webserver.k8s_healthz_endpoint` (default: `/healthz`).

**Webserver Configuration:**

```yaml
webserver:
  enabled: true                           # [Stable]
  threadiness: 0                          # 0 = auto (hardware concurrency)
  listen_port: 8765
  listen_address: 0.0.0.0                 # IPv4 or IPv6
  k8s_healthz_endpoint: /healthz
  prometheus_metrics_enabled: false       # [Incubating]
  ssl_enabled: false
  ssl_certificate: /etc/falco/falco.pem
```

The webserver is started during the startup sequence (`start_webserver` action) and runs in a dedicated thread. The Prometheus metrics endpoint is registered lazily, only after inspectors have been opened, via `on_inspectors_opened` callback, because metrics require access to inspector state.

**Source:** [`webserver.h`](../refs/falcosecurity/falco/userspace/falco/webserver.h), [`webserver.cpp`](../refs/falcosecurity/falco/userspace/falco/webserver.cpp), [`start_webserver.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/start_webserver.cpp)

### Version Endpoint

The `/versions` endpoint returns a JSON object with component version information. This is used by falcoctl for version checking and rules artifact compatibility.

```cpp
// versions_info.cpp:65-83
nlohmann::json falco::versions_info::as_json() const {
    nlohmann::json version_info;
    version_info["falco_version"] = falco_version;
    version_info["libs_version"] = libs_version;
    version_info["plugin_api_version"] = plugin_api_version;
    version_info["driver_api_version"] = driver_api_version;
    version_info["driver_schema_version"] = driver_schema_version;
    version_info["default_driver_version"] = default_driver_version;
    version_info["engine_version"] = std::to_string(FALCO_ENGINE_VERSION_MINOR);
    version_info["engine_version_semver"] = engine_version;
    // plugin_versions: map of plugin name -> version string
}
```

**Source:** [`versions_info.h`](../refs/falcosecurity/falco/userspace/falco/versions_info.h), [`versions_info.cpp`](../refs/falcosecurity/falco/userspace/falco/versions_info.cpp)

## Implementation Details

### Metrics Configuration

The full `metrics` configuration block in `falco.yaml`:

```yaml
metrics:
  enabled: false                          # [Stable] Enable metrics collection and export
  interval: 1h                            # Prometheus duration format (ms, s, m, h, d, w, y)
  output_rule: true                       # Emit as Falco internal rule alert
  output_file: ""                         # Append to JSONL file (empty = disabled)
  rules_counters_enabled: true            # Per-rule match counts
  resource_utilization_enabled: true      # CPU, memory, open FDs, container memory
  state_counters_enabled: true            # Thread table, FD table counters
  kernel_event_counters_enabled: true     # Kernel-side event and drop counters
  kernel_event_counters_per_cpu_enabled: false  # Per-CPU event/drop counters
  libbpf_stats_enabled: true             # BPF program run time/count (requires kernel >= 5.1)
  plugins_metrics_enabled: true           # Custom plugin metrics via get_metrics()
  jemalloc_stats_enabled: false           # jemalloc memory stats (requires jemalloc build)
  convert_memory_to_mb: true              # Convert memory metrics to megabytes
  include_empty_values: false             # Include fields with zero/empty values
```

**Source:** [`falco.yaml:1214-1296`](../refs/falcosecurity/falco/falco.yaml), [`configuration.cpp:633-668`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)

**Interval format:** The `interval` field uses Prometheus-style time duration format. Supported units: `ms` (millisecond), `s` (second), `m` (minute), `h` (hour), `d` (day), `w` (week), `y` (year). A minimum interval of 100ms is enforced. Recommended production values: `15m`, `30m`, `1h`, `4h`, `6h`.

**Prometheus endpoint prerequisite:** For the `/metrics` Prometheus endpoint to be active, both `metrics.enabled` and `webserver.prometheus_metrics_enabled` must be `true`.

**Output destinations can be combined:** `output_rule` and `output_file` can be enabled simultaneously, but both operate independently through the `stats_writer`.

### Metrics Flags

Each metric category maps to a bitmask flag used internally to enable/disable collection:

| Config Key | Flag | Defined In |
|-----------|------|-----------|
| `rules_counters_enabled` | `METRICS_V2_RULE_COUNTERS` (1 << 4) | [`metrics_v2.h:56`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| `resource_utilization_enabled` | `METRICS_V2_RESOURCE_UTILIZATION` (1 << 2) | [`metrics_v2.h:54`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| `state_counters_enabled` | `METRICS_V2_STATE_COUNTERS` (1 << 3) | [`metrics_v2.h:55`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| `kernel_event_counters_enabled` | `METRICS_V2_KERNEL_COUNTERS` (1 << 0) | [`metrics_v2.h:52`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| `kernel_event_counters_per_cpu_enabled` | `METRICS_V2_KERNEL_COUNTERS_PER_CPU` (1 << 7) | [`metrics_v2.h:59-60`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| `libbpf_stats_enabled` | `METRICS_V2_LIBBPF_STATS` (1 << 1) | [`metrics_v2.h:53`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| `plugins_metrics_enabled` | `METRICS_V2_PLUGINS` (1 << 6) | [`metrics_v2.h:58`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| `jemalloc_stats_enabled` | `METRICS_V2_JEMALLOC_STATS` (1 << 31) | [`configuration.h:41`](../refs/falcosecurity/falco/userspace/falco/configuration.h) |

Note: `METRICS_V2_JEMALLOC_STATS` is defined in Falco (not in libs) because jemalloc stats collection is Falco-specific. Enabling `kernel_event_counters_per_cpu_enabled` silently enables `METRICS_V2_KERNEL_COUNTERS` as well.

**Source:** [`metrics_v2.h`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h), [`configuration.h:41`](../refs/falcosecurity/falco/userspace/falco/configuration.h), [`configuration.cpp:639-663`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)

### Metric Categories

#### Resource Utilization

Collected by `libs_metrics_collector` from libsinsp when `METRICS_V2_RESOURCE_UTILIZATION` is set. These metrics are agnostic to the event source (inspector is irrelevant). Includes:

- **CPU usage**: Falco process CPU utilization as a percentage of one CPU
- **Memory**: RSS, PSS, VSZ in raw units (kibibytes) or megabytes (if `convert_memory_to_mb` is enabled)
- **Container memory**: Read from `FALCO_CGROUP_MEM_PATH` (default: `/sys/fs/cgroup/memory/memory.usage_in_bytes`)
- **Open file descriptors**: Falco process open FDs
- **Host-level stats**: Overall host CPU usage, memory usage, total processes, total open FDs (from `/proc`)

In Prometheus output, resource utilization metrics use the `falco` subsystem prefix (`falcosecurity_falco_*`).

**Source:** [`falco_metrics.cpp:338-339`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp), [`falco.yaml:1244-1260`](../refs/falcosecurity/falco/falco.yaml)

#### Kernel Event Counters

Collected by `libs_metrics_collector` when `METRICS_V2_KERNEL_COUNTERS` is set. Must be retrieved by the syscall inspector; not available for plugin-only inspectors. Includes:

- `n_evts`: Total kernel-side events
- `n_drops`: Total kernel-side event drops
- `n_drops_buffer_*_exit`: Buffer drops by syscall category (clone_fork, execve, connect, open, dir_file, other_interest, close, proc)
- `n_drops_scratch_map`: Scratch map drops
- `n_drops_pf`: Page fault drops
- `n_drops_bug`: Bug drops (invalid condition in kernel instrumentation)
- `n_preemptions`: Preemption count
- `n_suppressed` / `n_tids_suppressed`: Suppressed event counts

In Prometheus output, kernel counters use the `scap` subsystem prefix (`falcosecurity_scap_*`). Buffer drops are distinguished using labels (`{drop="clone_fork",dir="exit"}`). Deprecated enter-event buffer drop metrics are emitted with value 0 for backward compatibility, with a deprecation notice in the HELP text.

**Source:** [`falco_metrics.cpp:332-443`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp), [`event_drops.cpp:59-89`](../refs/falcosecurity/falco/userspace/falco/event_drops.cpp)

#### Per-CPU Kernel Counters

Collected when `METRICS_V2_KERNEL_COUNTERS_PER_CPU` is set. Provides per-CPU breakdowns of events and drops:

- `n_evts_cpu_<N>`: Events per CPU
- `n_drops_cpu_<N>`: Drops per CPU

In Prometheus output, the CPU number is extracted from the metric name and emitted as a label (`{cpu="7"}`).

**Source:** [`falco_metrics.cpp:347-379`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp)

#### State Counters

Collected by `libs_metrics_collector` when `METRICS_V2_STATE_COUNTERS` is set. Semi-agnostic; must be retrieved by the syscall inspector if applicable. Based on `sinsp_stats_v2` and `sinsp_thread_manager`:

- **Thread table**: `n_threads` (current count), `n_added_threads`, `n_removed_threads`, `n_noncached_thread_lookups`, `n_cached_thread_lookups`, `n_failed_thread_lookups`, `n_drops_full_threadtable`
- **FD table**: `n_fds` (current count across all threads), `n_added_fds`, `n_removed_fds`, `n_noncached_fd_lookups`, `n_cached_fd_lookups`, `n_failed_fd_lookups`
- **Event store**: `n_stored_evts`, `n_store_evts_drops`, `n_retrieved_evts`, `n_retrieve_evts_drops`

**Source:** [`metrics_collector.h:31-56`](../refs/falcosecurity/libs/userspace/libsinsp/metrics_collector.h), [`metrics_collector.h:295-309`](../refs/falcosecurity/libs/userspace/libsinsp/metrics_collector.h)

#### Rules Counters

Collected by Falco (not libs) when `METRICS_V2_RULE_COUNTERS` is set. Obtained from `falco_engine::get_rule_stats_manager()`:

- `rules.matches_total`: Total rule matches across all rules (rule output only)
- Per-rule match count: Indexed by rule ID, emitted only if count > 0 (or `include_empty_values` is true)

In Prometheus output, per-rule counters are emitted as `falcosecurity_falco_rules_matches_total` with labels for `rule_name`, `priority`, `source`, and each tag prefixed with `tag_`:

```
falcosecurity_falco_rules_matches_total{priority="4",rule_name="Read sensitive file untrusted",source="syscall",tag_maturity_stable="true",...} 32
```

In rule output, per-rule counters use sanitized rule names: `falco.rules.<sanitized_rule_name>`.

**Source:** [`falco_metrics.cpp:174-221`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp), [`stats_writer.cpp:422-438`](../refs/falcosecurity/falco/userspace/falco/stats_writer.cpp)

#### Plugin Metrics

Collected by `libs_metrics_collector` when `METRICS_V2_PLUGINS` is set. Must be retrieved for each inspector, because different inspectors may host different plugins. Plugin metrics use the `plugins` subsystem prefix (`falcosecurity_plugins_*`) in Prometheus output.

Plugin authors provide metrics via the `get_metrics()` capability in the plugin API. If a plugin does not implement metrics, no metrics are emitted for that plugin.

**Source:** [`falco_metrics.cpp:320-331`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp), [`falco.yaml:1283-1286`](../refs/falcosecurity/falco/falco.yaml)

#### libbpf Stats

Collected when `METRICS_V2_LIBBPF_STATS` is set. Only available for eBPF-based drivers (`bpf` or `modern_ebpf`). Provides statistics similar to `bpftool prog show`:

- BPF program invocation counts
- Time spent in each BPF program (nanoseconds)

Requires kernel >= 5.1 with `/proc/sys/kernel/bpf_stats_enabled` set. The current libbpf implementation does not support granularity at the BPF tail call level. libbpf stats are automatically disabled for non-eBPF drivers.

**Source:** [`falco.yaml:1274-1282`](../refs/falcosecurity/falco/falco.yaml), [`stats_writer.cpp:623-626`](../refs/falcosecurity/falco/userspace/falco/stats_writer.cpp)

#### jemalloc Stats

Collected when `METRICS_V2_JEMALLOC_STATS` is set (Falco-specific flag, 1 << 31). Requires Falco to be built with jemalloc support (`HAS_JEMALLOC`). Retrieves memory allocator statistics via `malloc_stats_print()` in JSON format, emitting all unsigned integer stats from the `jemalloc.stats` section (e.g., `allocated`, `active`, `mapped`, `resident`).

In Prometheus output: `falcosecurity_falco_jemalloc_*_bytes`
In rule output: `falco.jemalloc.<stat_name>_bytes`

**Source:** [`falco_metrics.cpp:222-253`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp), [`stats_writer.cpp:440-479`](../refs/falcosecurity/falco/userspace/falco/stats_writer.cpp)

### Wrapper (Always-On) Metrics

Certain metrics are always emitted regardless of category flags:

**Prometheus endpoint:**
- `falcosecurity_falco_version_info{version="..."}` -- Falco version
- `falcosecurity_falco_sha256_rules_files_info{file_name="...",sha256="..."}` -- SHA256 of loaded rules files
- `falcosecurity_falco_sha256_config_files_info{file_name="...",sha256="..."}` -- SHA256 of loaded config files
- `falcosecurity_falco_outputs_queue_num_drops_total` -- Output queue drops counter
- `falcosecurity_falco_reload_timestamp_nanoseconds` -- Last reload timestamp
- `falcosecurity_scap_engine_name_info{engine_name="...",evt_source="..."}` -- Active engine per source
- `falcosecurity_falco_kernel_release_info{kernel_release="..."}` -- Kernel release string
- `falcosecurity_falco_start_timestamp_nanoseconds` -- Falco start timestamp
- `falcosecurity_falco_duration_seconds_total` -- Uptime in seconds
- `falcosecurity_evt_hostname_info{hostname="..."}` -- Hostname
- `falcosecurity_falco_host_boot_timestamp_nanoseconds` -- Host boot timestamp
- `falcosecurity_falco_host_num_cpus_total` -- Number of host CPUs

**Rule/file output:**
- `evt.time`, `falco.version`, `falco.start_ts`, `falco.duration_sec`, `falco.kernel_release`
- `evt.hostname`, `falco.host_boot_ts`, `falco.host_num_cpus`
- `falco.outputs_queue_num_drops`, `falco.reload_ts`
- `falco.sha256_rules_file.*`, `falco.sha256_config_file.*`
- `falco.host_netinfo.interfaces.*` (network interface addresses)
- `evt.source`, `scap.engine_name`
- `falco.evts_rate_sec`, `falco.num_evts`, `falco.num_evts_prev`

**Source:** [`falco_metrics.cpp:103-514`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp), [`stats_writer.cpp:331-413`](../refs/falcosecurity/falco/userspace/falco/stats_writer.cpp)

### Multi-Inspector Metrics Collection

Falco utilizes multiple inspectors when plugins with event sources are loaded. The metrics collection loop iterates over all enabled sources, but different metric categories have different collection rules:

| Category | Collection Behavior |
|----------|-------------------|
| Rules counters | Agnostic; collected once from `falco_engine` state |
| Resource utilization | Agnostic; collected once (inspector irrelevant) |
| State counters | Semi-agnostic; must use syscall inspector if available |
| Kernel event counters | Syscall inspector only |
| Per-CPU kernel counters | Syscall inspector only |
| libbpf stats | Syscall inspector only (eBPF drivers only) |
| Plugin metrics | Collected for each inspector |
| jemalloc stats | Agnostic; collected once |
| Agent/machine info | Collected once (from first available inspector) |

The syscall inspector is always at index 0 in the source loop when it exists, ensuring these category constraints are respected.

**Source:** [`falco_metrics.cpp:32-64`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp) (class documentation)

### Stats Writer

The `stats_writer` is responsible for collecting metrics at regular intervals and delivering them via the rule output and/or file output channels. It uses a timer-based ticker mechanism (POSIX `timer_create` with `SIGALRM` on Linux) and a TBB concurrent queue for thread-safe operation.

**Key Components:**

- **Ticker**: An atomic counter incremented by a signal handler (`SIGALRM`) at the configured interval. The `stats_writer::collector` checks the ticker on every event and collects metrics when the tick changes.
- **Collector**: Created per event processing thread. Calls `get_metrics_output_fields_wrapper()` and `get_metrics_output_fields_additional()` to build a JSON object of metric fields, then pushes it to the stats writer's queue.
- **Worker**: A dedicated thread that pops messages from the queue and delivers them via `falco_outputs::handle_msg()` (rule output) and/or appends to the JSONL file.

```cpp
// stats_writer.h:38-43
class stats_writer {
public:
    typedef uint16_t ticker_t;

    class collector {
        // Collects one stats sample per ticker period
        void collect(const std::shared_ptr<sinsp>& inspector,
                     const std::string& src, uint64_t num_evts);
    };
};
```

The rule output delivers metrics as internal alerts with rule name "Falco internal: metrics snapshot" and message "Falco metrics snapshot" at priority `INFORMATIONAL`.

The file output writes one JSON line per sample in the format: `{"sample": N, "output_fields": {...}}`.

**Source:** [`stats_writer.h`](../refs/falcosecurity/falco/userspace/falco/stats_writer.h), [`stats_writer.cpp`](../refs/falcosecurity/falco/userspace/falco/stats_writer.cpp)

### Prometheus Metrics Format

The Prometheus endpoint uses the text-based exposition format (version 0.0.4). All metrics follow the naming convention `<namespace>_<subsystem>_<metric_name>_<unit>`:

| Namespace | Subsystem | Used For |
|-----------|-----------|----------|
| `falcosecurity` | `falco` | Falco application metrics (resource utilization, rules, version, uptime) |
| `falcosecurity` | `scap` | Kernel/driver metrics (event counters, drops, engine info) |
| `falcosecurity` | `plugins` | Plugin-provided metrics |
| `falcosecurity` | `evt` | Event metadata (hostname) |

Supported Prometheus metric types: `counter` (monotonic) and `gauge` (non-monotonic current). The implementation generates text directly rather than using a Prometheus client library, as the metric names are dynamic (e.g., varying tracepoints across architectures).

Unit conventions follow Prometheus best practices: memory is converted to bytes, CPU usage to a ratio, timestamps kept in nanoseconds (to avoid precision loss).

**Source:** [`metrics_collector.h:99-220`](../refs/falcosecurity/libs/userspace/libsinsp/metrics_collector.h), [`falco_metrics.cpp:73`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp)

### Event Drop Detection

The `syscall_evt_drop_mgr` monitors kernel-side event drops during the event processing loop. It is separate from the metrics system but provides complementary drop monitoring.

**Configuration:**

```yaml
syscall_event_drops:
  threshold: .1                           # [Stable] Drop ratio threshold (0-1)
  actions:                                # Actions when drops exceed threshold
    - log                                 # Log at DEBUG level
    - alert                               # Emit as internal rule alert
  rate: .03333                            # Token bucket: messages per second
  max_burst: 1                            # Token bucket: max burst
  simulate_drops: false                   # Testing: force simulated drops
```

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml), [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)

**Detection mechanism:**

1. Every second (based on event timestamps), the drop manager calls `inspector->get_capture_stats()` to retrieve kernel-side counters
2. It computes a delta from the previous check
3. If `delta.n_drops > 0`, it calculates the drop ratio: `n_drops / n_evts`
4. If the ratio exceeds `threshold`, a drop event is detected
5. A token bucket (`rate` / `max_burst`) rate-limits the actions to prevent flooding

**Source:** [`event_drops.cpp:53-127`](../refs/falcosecurity/falco/userspace/falco/event_drops.cpp)

**Actions:**

| Action | Enum Value | Behavior |
|--------|-----------|----------|
| `ignore` | `DISREGARD` | No action |
| `log` | `LOG` | Log message at DEBUG level |
| `alert` | `ALERT` | Emit as internal rule alert "Falco internal: syscall event drop" with detailed drop breakdown fields |
| `exit` | `EXIT` | Log at CRITICAL level and exit |

The alert action includes detailed drop statistics as output fields: `n_evts`, `n_drops`, `n_drops_buffer_total`, per-category buffer drops (`n_drops_buffer_clone_fork_exit`, `n_drops_buffer_execve_exit`, etc.), `n_drops_scratch_map`, `n_drops_page_faults`, `n_drops_bug`, and `ebpf_enabled`.

**Source:** [`event_drops.h:30`](../refs/falcosecurity/falco/userspace/falco/event_drops.h), [`event_drops.cpp:135-219`](../refs/falcosecurity/falco/userspace/falco/event_drops.cpp)

**Key difference from metrics kernel counters:** The `syscall_event_drops` mechanism is threshold-based and operates per-second in real time during the event loop. The `metrics.kernel_event_counters_enabled` option exports monotonic cumulative counters at the configured metrics interval. Both use `scap_stats` from the same underlying driver counters.

### Timeout Monitoring

The event processing loop monitors for sustained periods without events. When `syscall_evt_timeout_max_consecutives` consecutive `SCAP_TIMEOUT` returns occur (default: 1000), an internal alert is emitted:

```yaml
syscall_event_timeouts:
  max_consecutives: 1000                  # [Stable] Alert after N consecutive timeouts
```

The alert rule name is "Falco internal: timeouts notification" and includes a `last_event_time` field.

**Source:** [`process_events.cpp:196-222`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)

### Health Check

The `/healthz` endpoint provides a basic liveness check that returns `{"status": "ok"}` as long as the webserver thread is running. This is primarily used as a Kubernetes liveness probe.

The webserver itself monitors startup success using an atomic `m_failed` flag. If the server fails to bind or start, `stop()` is called and an exception is thrown. Once running, the health endpoint will respond as long as the httplib server thread is alive.

**Source:** [`webserver.cpp:48-52`](../refs/falcosecurity/falco/userspace/falco/webserver.cpp), [`webserver.cpp:67-88`](../refs/falcosecurity/falco/userspace/falco/webserver.cpp)

### Output Watchdog

The output system (not the webserver) uses a `watchdog` template class to detect stuck output delivery. The worker thread sets a deadline before processing each output channel. If delivery exceeds `output_timeout` (default: 2000ms), the watchdog callback fires:

- **Worker watchdog**: Logs a CRITICAL message identifying which output channel is blocked
- **Stop watchdog**: If the worker fails to stop within the timeout, the queue is cleared and a forced stop is issued

```yaml
output_timeout: 2000                      # [Stable] Output delivery timeout in ms
```

**Source:** [`watchdog.h`](../refs/falcosecurity/falco/userspace/falco/watchdog.h), [`falco_outputs.cpp:238-248`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp), [`falco_outputs.cpp:282-286`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.cpp)

## Non-Functional Requirements

- **Low overhead**: The metrics ticker uses a lightweight POSIX timer signal (`SIGALRM`) with an atomic counter. Collection only occurs when the tick changes, avoiding per-event overhead. The Prometheus endpoint generates text on-demand only when scraped.
- **Configurable intervals**: The interval controls the tradeoff between monitoring granularity and overhead. The minimum enforced interval is 100ms. Recommended production intervals are 15m to 6h.
- **Thread safety**: The `stats_writer` uses a TBB `concurrent_bounded_queue` shared between collector threads and the worker thread. The ticker counter uses `std::atomic` with relaxed memory ordering.
- **No external dependencies**: The Prometheus exposition format is generated as plain text strings, avoiding the need for a Prometheus client library. This simplifies the build and reduces dependency footprint.
- **Backward compatibility**: Deprecated enter-event buffer drop metrics are emitted with value 0 to maintain compatibility with existing dashboards, with deprecation notices in the HELP text.

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`architecture-overview.md`](architecture-overview.md) | System context, threading model, event pipeline |
| [`configuration.md`](configuration.md) | Metrics configuration reference, config loading |
| [`output-system.md`](output-system.md) | Metrics output via `handle_msg()`, watchdog, queue |
| [`application-lifecycle.md`](application-lifecycle.md) | Webserver start/stop lifecycle, startup sequence |
| [`libsinsp.md`](libsinsp.md) | `libs_metrics_collector`, state tables, sinsp_stats_v2 |
| [`libscap.md`](libscap.md) | `scap_stats`, `metrics_v2` struct, driver counters |

## Sources

| Topic | Source File |
|-------|-------------|
| Falco metrics class | [`falco_metrics.h`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.h) |
| Falco metrics implementation | [`falco_metrics.cpp`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp) |
| Stats writer | [`stats_writer.h`](../refs/falcosecurity/falco/userspace/falco/stats_writer.h) |
| Stats writer implementation | [`stats_writer.cpp`](../refs/falcosecurity/falco/userspace/falco/stats_writer.cpp) |
| Webserver | [`webserver.h`](../refs/falcosecurity/falco/userspace/falco/webserver.h) |
| Webserver implementation | [`webserver.cpp`](../refs/falcosecurity/falco/userspace/falco/webserver.cpp) |
| Start/stop webserver actions | [`start_webserver.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/start_webserver.cpp) |
| Versions endpoint | [`versions_info.h`](../refs/falcosecurity/falco/userspace/falco/versions_info.h) |
| Versions endpoint implementation | [`versions_info.cpp`](../refs/falcosecurity/falco/userspace/falco/versions_info.cpp) |
| Event drop manager | [`event_drops.h`](../refs/falcosecurity/falco/userspace/falco/event_drops.h) |
| Event drop manager implementation | [`event_drops.cpp`](../refs/falcosecurity/falco/userspace/falco/event_drops.cpp) |
| Watchdog | [`watchdog.h`](../refs/falcosecurity/falco/userspace/falco/watchdog.h) |
| Event processing (drops, timeouts, stats) | [`process_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp) |
| Configuration parsing (metrics) | [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp) |
| Configuration structure | [`configuration.h`](../refs/falcosecurity/falco/userspace/falco/configuration.h) |
| Default configuration | [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml) |
| Libs metrics collector | [`metrics_collector.h`](../refs/falcosecurity/libs/userspace/libsinsp/metrics_collector.h) |
| Metrics v2 schema | [`metrics_v2.h`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
