# Configuration

> Configuration system: sources, merging strategies, JSON schema validation, all configuration keys with types, defaults, and maturity levels.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco/falco.yaml`](../refs/falcosecurity/falco/falco.yaml)

## Overview

Falco uses a YAML-based configuration system that controls all aspects of runtime behavior, from driver selection and rule loading to output channels and performance tuning. The primary configuration file is `falco.yaml`. The system supports environment variable interpolation, multi-file merging with configurable strategies, and JSON schema validation at load time.

Each configuration key carries a maturity level (Stable, Incubating, Sandbox, Deprecated) indicating its stability guarantee.

**Source:** [`digests/falcosecurity/falco/configuration.md`](../digests/falcosecurity/falco/configuration.md)

## Architecture

### Configuration Sources (Precedence Order)

Configuration is loaded from multiple sources with later sources taking precedence:

| Priority | Source | Description |
|----------|--------|-------------|
| 1 (lowest) | Main config file (`falco.yaml`) | Primary configuration file |
| 2 | Config fragments (`config_files` / `config.d/`) | Additional configs merged into main |
| 3 | Environment variables | System environment variables used for interpolation |
| 4 (highest) | CLI arguments (`-o` flag) | Command-line overrides |

**Load Order** (from [`configuration.cpp:129-157`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)):

```
1. Load main falco.yaml
2. Load any -o config_files=foo.yaml cmdline options
3. Merge all config_files (from main config + cmdline)
4. Apply all other -o cmdline options
5. Parse final merged configuration
```

**Command-line override example:**
```bash
falco -o "json_output=true" -o "log_level=debug" -o "engine.kind=kmod"
```

**Source:** [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp), [`load_config.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/load_config.cpp)

### Config File Merge Strategies

When using `config_files` to include additional configuration, three merge strategies are available (from [`yaml_helper.h:88-92`](../refs/falcosecurity/falco/userspace/engine/yaml_helper.h)):

| Strategy | Sequences | Scalars | Non-existing Keys |
|----------|-----------|---------|-------------------|
| `append` (default) | Appended | Overridden | Added |
| `override` | Overridden | Overridden | Added |
| `add-only` | Ignored | Ignored | Added |

**Syntax examples:**
```yaml
config_files:
  - /etc/falco/config.d                    # Directory with append strategy (default)
  - path: /custom/config.yaml
    strategy: override                      # Explicit override strategy
  - path: $HOME/local_config.yaml
    strategy: add-only                      # Only add missing keys
```

Nested includes are not allowed -- included config files cannot themselves include other config files.

**Source:** [`yaml_helper.h`](../refs/falcosecurity/falco/userspace/engine/yaml_helper.h)

### Configuration Maturity Levels

Each configuration key has a maturity level indicating its stability guarantee (from [`proposals/20231220-features-adoption-and-deprecation.md`](../refs/falcosecurity/falco/proposals/20231220-features-adoption-and-deprecation.md)):

| Level | Description | Support Guarantee |
|-------|-------------|-------------------|
| **Stable** | GA features | Long-term support expected |
| **Incubating** | Beta features | Long-term support not guaranteed |
| **Sandbox** | Experimental/alpha features | Can be removed without notice |
| **Deprecated** | Being phased out | Will be removed in a future release |

**Source:** [`20231220-features-adoption-and-deprecation.md`](../refs/falcosecurity/falco/proposals/20231220-features-adoption-and-deprecation.md)

## Implementation Details

### Engine Configuration

#### Engine Kinds

The `engine.kind` setting determines how Falco captures system events (from [`configuration.cpp:236-240`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)):

| Kind | Status | Description |
|------|--------|-------------|
| `modern_ebpf` | **Default** | CO-RE eBPF probe, recommended for modern kernels |
| `kmod` | Stable | Traditional kernel module |
| `replay` | Stable | Replay from capture file |
| `nodriver` | Stable | No kernel driver, useful for plugins-only mode |

> Note: `ebpf` (legacy eBPF probe) and `gvisor` (gVisor engine) were removed in Falco 0.44 ([PR #3796](https://github.com/falcosecurity/falco/pull/3796), [PR #3797](https://github.com/falcosecurity/falco/pull/3797)). Setting `engine.kind` to either now raises `engine.kind '<kind>' is not a valid kind.`.

```yaml
engine:
  kind: modern_ebpf    # [Stable] Required
```

#### Engine-Specific Options

**Modern eBPF (default):**
```yaml
engine:
  kind: modern_ebpf
  modern_ebpf:
    cpus_for_each_buffer: 2   # CPUs per ring buffer (default: 2)
    buf_size_preset: 4        # Buffer index 0-10 (default: 4 = 8MB)
    drop_failed_exit: false   # Drop failed syscall exits
    disable_iterators: false  # Disable BPF iterators; fall back to procfs (default: false)
```

> **`disable_iterators`** (`bool`, default `false`; modern_ebpf only). When `false` (the default), the modern eBPF driver uses BPF iterators to synchronously fetch kernel state — populating the initial process table at startup and healing it after event drops — instead of walking procfs. Setting it to `true` disables the iterators and forces a procfs fallback. The value is loaded from `engine.modern_ebpf.disable_iterators` ([`configuration.cpp:269-271`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)) into `m_modern_ebpf.m_disable_iterators` ([`configuration.h:74`](../refs/falcosecurity/falco/userspace/falco/configuration.h)) and passed as the final argument to `inspector->open_modern_bpf(...)` ([`helpers_inspector.cpp:109-113`](../refs/falcosecurity/falco/userspace/falco/app/actions/helpers_inspector.cpp)); there is no dedicated config accessor. BPF iterators are additionally auto-disabled whenever Falco runs outside the host (root) PID namespace. While iterators are disabled (by this setting or automatically), the kernel iterator event/drop counters (`metrics.kernel_iter_event_counters_enabled`) are not exported ([`falco.yaml`](../refs/falcosecurity/falco/falco.yaml)). Schema: [`config_json_schema.h:409`](../refs/falcosecurity/falco/userspace/falco/config_json_schema.h).

**Kernel Module (kmod):**
```yaml
engine:
  kind: kmod
  kmod:
    buf_size_preset: 4        # Buffer index 0-10 (default: 4 = 8MB)
    drop_failed_exit: false   # Drop failed syscall exits
```

**Replay:**
```yaml
engine:
  kind: replay
  replay:
    capture_file: "/path/to/file.scap"  # Required: path to capture file
```

**No driver:**
```yaml
engine:
  kind: nodriver
```

#### Buffer Size Preset

The `buf_size_preset` maps to actual buffer sizes per CPU:

| Index | Size |
|-------|------|
| 0 | Reserved |
| 1 | 1 MB |
| 2 | 2 MB |
| 3 | 4 MB |
| **4** | **8 MB (default)** |
| 5 | 16 MB |
| 6 | 32 MB |
| 7 | 64 MB |
| 8 | 128 MB |
| 9 | 256 MB |
| 10 | 512 MB |

**Source:** [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp), [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml)

### Rules Configuration

#### rules_files [Stable]

Specifies rule file locations (from [`configuration.cpp:324-354`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)):

```yaml
rules_files:                              # [Stable]
  - /etc/falco/falco_rules.yaml           # Main rules file
  - /etc/falco/falco_rules.local.yaml     # Local customizations
  - /etc/falco/rules.d                    # Directory (alphabetically sorted)
```

Since Falco 0.41, only `.yml` and `.yaml` files are processed.

#### rules [Incubating]

Enable or disable rules by name (with wildcards) or by tag:

```yaml
rules:                                    # [Incubating]
  - disable:
      rule: "*"                           # Disable all rules
  - enable:
      rule: "Netcat Remote Code Execution in Container"
  - disable:
      tag: network                        # Disable by tag
```

**Source:** [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp), [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml)

### Plugin Configuration

#### load_plugins [Stable]

List of plugins to load (from [`configuration.cpp:718-759`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)):

```yaml
load_plugins: []                          # [Stable] Empty = none loaded
# load_plugins: [k8saudit, json]          # Example with plugins
```

#### plugins [Stable]

Plugin definitions with initialization config and open parameters:

```yaml
plugins:                                  # [Stable]
  - name: container
    library_path: libcontainer.so         # Relative paths use FALCO_ENGINE_PLUGINS_DIR
    init_config:
      label_max_len: 100
      with_size: false
  - name: k8saudit
    library_path: libk8saudit.so
    init_config: ""                       # Can be YAML map or string
    open_params: "http://:9765/k8s-audit"
```

#### plugins_hostinfo [Sandbox]

```yaml
plugins_hostinfo: true                    # [Sandbox] Enable host info for plugins
```

**Source:** [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp), [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml)

### Output Configuration

#### Global Output Settings

| Key | Type | Default | Maturity | Description |
|-----|------|---------|----------|-------------|
| `priority` | string | `debug` | Stable | Minimum rule priority to output |
| `json_output` | bool | `false` | Stable | Output alerts in JSON format |
| `json_include_output_property` | bool | `true` | Stable | Include "output" field in JSON |
| `json_include_tags_property` | bool | `true` | Stable | Include "tags" field in JSON |
| `json_include_message_property` | bool | `false` | Incubating | Include formatted message in JSON |
| `json_include_output_fields_property` | bool | `true` | Incubating | Include output fields in JSON |
| `buffered_outputs` | bool | `false` | Stable | Buffer output writes |
| `time_format_iso_8601` | bool | `false` | Stable | Use ISO 8601 timestamps |
| `buffer_format_base64` | bool | `false` | Incubating | Base64 encode binary data in output |
| `rule_matching` | string | `first` | Incubating | Rule matching strategy: `first` or `all` |
| `output_timeout` | int | `2000` | Stable | Output timeout in milliseconds |

#### outputs_queue [Stable]

```yaml
outputs_queue:
  capacity: 0                             # [Stable] 0 = unbounded queue
```

When capacity is exceeded, events are dropped and logged.

#### append_output [Sandbox]

Add fields or text to rule outputs:

```yaml
append_output:                            # [Sandbox]
  - suggested_output: true                # Auto-append suggested fields
  - match:
      source: syscall
    extra_output: "on CPU %evt.cpu"
    extra_fields:
      - home_directory: "${HOME}"
      - evt.hostname
```

#### static_fields [Sandbox]

Add static key-value pairs to all output events:

```yaml
static_fields:                            # [Sandbox]
  foo: bar
  env_value: ${MY_ENV_VAR}
```

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml), [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)

### Output Channels

#### stdout_output [Stable]

```yaml
stdout_output:
  enabled: true                           # [Stable]
```

#### syslog_output [Stable]

```yaml
syslog_output:
  enabled: true                           # [Stable]
```

#### file_output [Stable]

```yaml
file_output:
  enabled: false                          # [Stable]
  keep_alive: false                       # Keep file open between writes
  filename: ./events.txt                  # Output file path
```

#### http_output [Stable]

```yaml
http_output:
  enabled: false                          # [Stable]
  url: ""                                 # Required when enabled
  user_agent: "falcosecurity/falco"
  insecure: false                         # Skip TLS verification
  ca_cert: ""                             # CA certificate path
  ca_bundle: ""                           # CA bundle file
  ca_path: "/etc/ssl/certs"              # CA certificates directory
  mtls: false                             # Enable mutual TLS
  client_cert: "/etc/ssl/certs/client.crt"
  client_key: "/etc/ssl/certs/client.key"
  echo: false                             # Echo server responses to log
  compress_uploads: false                 # Compress payloads (gzip)
  keep_alive: false                       # Persistent HTTP connections
  max_consecutive_timeouts: 5             # Max consecutive timeouts to ignore
```

#### program_output [Stable]

```yaml
program_output:
  enabled: false                          # [Stable]
  keep_alive: false                       # Keep program running between alerts
  program: "jq '{text: .output}' | curl -d @- -X POST https://hooks.slack.com/..."
```

#### grpc_output [Removed in 0.44]

The `grpc_output` block was removed in Falco 0.44 ([PR #3798](https://github.com/falcosecurity/falco/pull/3798)). Setting the key in the configuration is no longer recognized and may be flagged by JSON schema validation. Use `http_output` or Falcosidekick instead.

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml), [`digests/falcosecurity/falco/outputs.md`](../digests/falcosecurity/falco/outputs.md)

### Service Configuration

#### webserver [Stable]

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

**Endpoints:**

| Endpoint | Purpose | Source |
|----------|---------|--------|
| `/healthz` | Health check (configurable path via `k8s_healthz_endpoint`) | [`webserver.cpp:49`](../refs/falcosecurity/falco/userspace/falco/webserver.cpp) |
| `/versions` | Version information (JSON) | [`webserver.cpp:56`](../refs/falcosecurity/falco/userspace/falco/webserver.cpp) |
| `/metrics` | Prometheus metrics (requires `metrics.enabled: true` and `prometheus_metrics_enabled: true`) | [`webserver.cpp:107`](../refs/falcosecurity/falco/userspace/falco/webserver.cpp) |

#### grpc [Removed in 0.44]

The `grpc` server block was removed in Falco 0.44 ([PR #3798](https://github.com/falcosecurity/falco/pull/3798)), per [proposal 20251215](../refs/falcosecurity/falco/proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md). The gRPC server is no longer built or shipped. Use the webserver and Falcosidekick for alert delivery and external integrations.

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml), [`digests/falcosecurity/falco/proposals.md`](../digests/falcosecurity/falco/proposals.md)

### Logging Configuration

#### Falco Logging

| Key | Type | Default | Maturity | Description |
|-----|------|---------|----------|-------------|
| `log_stderr` | bool | `true` | Stable | Log Falco messages to stderr |
| `log_syslog` | bool | `true` | Stable | Log Falco messages to syslog |
| `log_level` | string | `info` | Stable | Log level: `emergency`, `alert`, `critical`, `error`, `warning`, `notice`, `info`, `debug` |

#### libs_logger [Stable]

Controls the logging output from the underlying libs (libscap/libsinsp):

```yaml
libs_logger:
  enabled: true                           # [Stable]
  severity: info                          # fatal, critical, error, warning, notice, info, debug, trace
```

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml)

### Performance Configuration

#### syscall_event_timeouts [Stable]

```yaml
syscall_event_timeouts:
  max_consecutives: 1000                  # [Stable] Alert after N consecutive timeouts
```

#### syscall_event_drops [Stable]

Configures behavior when kernel events are dropped due to ring buffer overflow:

```yaml
syscall_event_drops:
  threshold: .1                           # [Stable] Drop percentage threshold (0-1)
  actions:                                # Actions when threshold exceeded
    - log                                 # Log a message
    - alert                               # Emit an alert
  rate: .03333                            # Messages per second rate limit
  max_burst: 1                            # Burst limit for rate limiter
  simulate_drops: false                   # Testing only: simulate drops
```

Available actions: `ignore`, `log`, `alert`, `exit`.

#### base_syscalls [Stable]

Controls which syscalls Falco monitors:

```yaml
base_syscalls:
  custom_set: []                          # [Stable] Custom syscall list
  repair: false                           # Auto-add required syscalls for state engine
  all: false                              # Monitor all events (significant performance impact)
```

**Syscall list format:**
```yaml
base_syscalls:
  custom_set:
    - clone
    - execve
    - "!mprotect"                         # Exclude with ! prefix
```

#### metrics [Stable]

Internal metrics collection for observability:

```yaml
metrics:
  enabled: false                          # [Stable]
  interval: 1h                            # Prometheus duration format (e.g., 1h, 30m, 15s)
  output_rule: true                       # Emit metrics as Falco rule alerts
  output_file: ""                         # Write metrics to JSONL file (path)
  rules_counters_enabled: true            # Per-rule match counters
  resource_utilization_enabled: true      # CPU, memory, FD usage
  state_counters_enabled: true            # State table entry counts
  kernel_event_counters_enabled: true     # Per-event-type counters
  kernel_event_counters_per_cpu_enabled: false  # Per-CPU event counters
  libbpf_stats_enabled: true             # eBPF program stats
  plugins_metrics_enabled: true           # Plugin-reported metrics
  jemalloc_stats_enabled: false           # Requires jemalloc build
  convert_memory_to_mb: true             # Convert memory values to MB
  include_empty_values: false            # Include zero-value metrics
```

When `webserver.prometheus_metrics_enabled` is `true`, these metrics are also exposed on the web server.

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml), [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp)

### Capture Configuration

#### capture [Sandbox]

```yaml
capture:
  enabled: false                          # [Sandbox]
  path_prefix: /tmp/falco                 # Output path prefix for capture files
  mode: rules                             # Capture trigger mode
  default_duration: 5000                  # Default per-rule duration in milliseconds
  max_file_size_mb: 0                     # Global hard cap in MB (since 0.44.0; 0 = unlimited; max 1,048,576)
```

**Capture modes:**

| Mode | Behavior |
|------|----------|
| `rules` | Capture only when rules with `capture: true` trigger |
| `all_rules` | Capture when any enabled rule triggers |

**Stop conditions (OR semantics):**

| Condition | Scope | Behavior |
|-----------|-------|----------|
| `default_duration` / per-rule `capture_duration` | Per-rule, soft | "At least" semantics; extended when more rules match during the capture |
| `max_file_size_mb` | Global, hard (since 0.44.0) | Cannot be overridden or extended by rules; on truncation Falco emits an INFO internal alert |

The `capture.max_file_size_mb` key was added in Falco 0.44 ([PR #3824](https://github.com/falcosecurity/falco/pull/3824)). Set to `0` (default) for no size cap. The JSON schema enforces a maximum of 1,048,576 MB (1 TiB) ([`config_json_schema.h:332-335`](../refs/falcosecurity/falco/userspace/falco/config_json_schema.h)). The size check uses the dumper's compressed on-disk counter and may overshoot by up to one zlib flush window, so very small values (under a few MB) may be inaccurate.

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml), [`configuration.cpp:606-625`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp), [`config_json_schema.h`](../refs/falcosecurity/falco/userspace/falco/config_json_schema.h)

### Hot Reload

```yaml
watch_config_files: true                  # [Stable]
```

When enabled, Falco monitors configuration and rules files using inotify and automatically reloads on changes. Reload can also be triggered manually via the `SIGHUP` signal.

**Reloadable at runtime:**
- Rules files
- Most configuration options

**Requires restart (not reloadable):**
- Engine kind / driver selection
- Some plugin configurations

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml), [`digests/falcosecurity/falco/architecture.md`](../digests/falcosecurity/falco/architecture.md)

### Environment Variables

#### Recognized Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST_ROOT` | Prefix to host `/proc` filesystem | `/host` |
| `FALCO_HOSTNAME` | Custom hostname for output | System hostname |
| `FALCO_CGROUP_MEM_PATH` | Container memory metric path | `/sys/fs/cgroup/memory/memory.usage_in_bytes` |
| `SKIP_DRIVER_LOADER` | Skip driver loading (fat image) | (unset) |
| `FALCO_FRONTEND` | `noninteractive` for unattended install | (unset) |
| `FALCO_DRIVER_CHOICE` | Driver for deb/rpm install | (unset) |
| `FALCOCTL_ENABLED` | `no` to disable falcoctl | (unset) |

#### Interpolation Syntax

Environment variables can be used in any YAML configuration value:

```yaml
probe: ${HOME}/.falco/falco-bpf.o         # Expands HOME variable
value: $${literal}                         # Escapes to literal ${literal}
```

- `${VAR}` — expands to the value of environment variable `VAR`
- `$${...}` — escapes the dollar sign, producing a literal `${...}` in the value

This is particularly useful for container deployments where configuration values vary by environment.

**Source:** [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml)

### falco_libs Configuration

#### falco_libs [Incubating]

Low-level tuning for the underlying libs (libscap/libsinsp):

```yaml
falco_libs:
  thread_table_size: 262144               # [Incubating] Max thread table entries
  thread_table_auto_purging_interval_s: 300   # Purge interval (seconds)
  thread_table_auto_purging_thread_timeout_s: 300  # Thread timeout (seconds)
  snaplen: 80                             # I/O buffer capture size (bytes)
```

**Default constants:**

| Parameter | Default | Source |
|-----------|---------|--------|
| `thread_table_size` | 262144 | [`falco_common.h:31`](../refs/falcosecurity/falco/userspace/engine/falco_common.h) |
| `thread_table_auto_purging_interval_s` | 300 (5 min) | [`falco_common.h:32`](../refs/falcosecurity/falco/userspace/engine/falco_common.h) |
| `thread_table_auto_purging_thread_timeout_s` | 300 (5 min) | [`falco_common.h:33`](../refs/falcosecurity/falco/userspace/engine/falco_common.h) |
| `snaplen` | 0 (use libs default of 80) | [`configuration.cpp:625`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp) — Falco code default is `0`, meaning "let libs configure it". The libs default is `80` bytes (from [`settings.h:35`](../refs/falcosecurity/libs/userspace/libsinsp/settings.h)). [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml) ships with `80`. |

**Source:** [`falco_common.h`](../refs/falcosecurity/falco/userspace/engine/falco_common.h), [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp), [`settings.h`](../refs/falcosecurity/libs/userspace/libsinsp/settings.h), [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml)

## Non-Functional Requirements

### JSON Schema Validation

Falco validates the merged configuration against a JSON schema at load time (from [`config_json_schema.h`](../refs/falcosecurity/falco/userspace/falco/config_json_schema.h)). This catches type mismatches, unknown keys, and invalid values before the application starts. Validation occurs after all configuration sources (main file, fragments, CLI overrides) have been merged.

### Environment Variable Interpolation

All string values in the configuration support `${VAR}` interpolation. This enables a single configuration file template to be used across environments (development, staging, production) with values injected via environment variables, which is the standard approach for container deployments.

### Config Fragment System

The `config_files` / `config.d/` pattern supports operational workflows where a base configuration is provided by a package or container image and site-specific customizations are layered on top. This avoids modifying the base configuration file directly, making upgrades cleaner.

**Source:** [`config_json_schema.h`](../refs/falcosecurity/falco/userspace/falco/config_json_schema.h), [`yaml_helper.h`](../refs/falcosecurity/falco/userspace/engine/yaml_helper.h)

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`architecture-overview.md`](architecture-overview.md) | Application lifecycle, event pipeline, component boundaries |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Kernel driver details for engine kinds |

## Sources

| Topic | Source File |
|-------|-------------|
| Main configuration reference | [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml) |
| Configuration structures | [`configuration.h`](../refs/falcosecurity/falco/userspace/falco/configuration.h) |
| Configuration loading | [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp) |
| JSON schema | [`config_json_schema.h`](../refs/falcosecurity/falco/userspace/falco/config_json_schema.h) |
| YAML parsing / merge strategies | [`yaml_helper.h`](../refs/falcosecurity/falco/userspace/engine/yaml_helper.h) |
| Config load action | [`load_config.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/load_config.cpp) |
| Default constants | [`falco_common.h`](../refs/falcosecurity/falco/userspace/engine/falco_common.h) |
| Maturity framework | [`20231220-features-adoption-and-deprecation.md`](../refs/falcosecurity/falco/proposals/20231220-features-adoption-and-deprecation.md) |
| Deprecation proposal | [`20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md`](../refs/falcosecurity/falco/proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md) |
| Config fragments | [`config/`](../refs/falcosecurity/falco/config/) |
| Configuration digest | [`digests/falcosecurity/falco/configuration.md`](../digests/falcosecurity/falco/configuration.md) |
| Output channels digest | [`digests/falcosecurity/falco/outputs.md`](../digests/falcosecurity/falco/outputs.md) |
| Proposals digest | [`digests/falcosecurity/falco/proposals.md`](../digests/falcosecurity/falco/proposals.md) |
