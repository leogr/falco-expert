# Falco Configuration

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falco/`](../../../refs/falcosecurity/falco/) | **Version:** 0.44.1

## Overview

Falco's configuration system controls all aspects of runtime behavior, from driver selection to output channels and performance tuning. The primary configuration file is `falco.yaml`, which uses YAML format with support for environment variable interpolation, config file merging, and JSON schema validation.

Configuration can be provided through multiple sources with defined precedence, and includes a maturity framework to indicate stability of each option.

## Configuration Sources

Falco configuration is loaded from multiple sources in a specific order, with later sources taking precedence:

1. **Main config file** (`falco.yaml`) - Primary configuration source
2. **Config fragments** (`config_files` / `config.d/`) - Additional configs merged into main
3. **Environment variables** - System environment variables for interpolation
4. **Command-line arguments** (`-o` flag) - Highest precedence overrides

**Load Order** (from [`configuration.cpp:129-157`](../../../refs/falcosecurity/falco/userspace/falco/configuration.cpp)):
```
1. Load main falco.yaml
2. Load any -o config_files=foo.yaml cmdline options
3. Merge all config_files (from main config + cmdline)
4. Apply all other -o cmdline options
5. Parse final merged configuration
```

**Command-line Override Example:**
```bash
falco -o "json_output=true" -o "log_level=debug" -o "engine.kind=kmod"
```

## Config File Merge Strategies

When using `config_files` to include additional configuration, three merge strategies are available (from [`yaml_helper.h:88-92`](../../../refs/falcosecurity/falco/userspace/engine/yaml_helper.h)):

| Strategy | Sequences | Scalars | Non-existing Keys |
|----------|-----------|---------|-------------------|
| `append` (default) | Appended | Overridden | Added |
| `override` | Overridden | Overridden | Added |
| `add-only` | Ignored | Ignored | Added |

**Configuration Example:**
```yaml
config_files:
  - /etc/falco/config.d                    # Directory with append strategy
  - path: /custom/config.yaml
    strategy: override                      # Explicit override strategy
  - path: $HOME/local_config.yaml
    strategy: add-only                      # Only add missing keys
```

**Important:** Nested includes are not allowed - included config files cannot include other config files.

## Configuration Maturity Levels

Each configuration key has a maturity level indicating stability (from [`proposals/20231220-features-adoption-and-deprecation.md`](../../../refs/falcosecurity/falco/proposals/20231220-features-adoption-and-deprecation.md)):

| Level | Description | Support Guarantee |
|-------|-------------|-------------------|
| **Stable** | GA features | Long-term support expected |
| **Incubating** | Beta features | Long-term support not guaranteed |
| **Sandbox** | Experimental/alpha | Can be removed without notice |
| **Deprecated** | Being phased out | Will be removed in future release |

## Engine Configuration

### Engine Kinds

The `engine.kind` setting determines how Falco captures system events (from [`configuration.cpp:236-247`](../../../refs/falcosecurity/falco/userspace/falco/configuration.cpp)):

| Kind | Status | Description |
|------|--------|-------------|
| `modern_ebpf` | **Default** | CO-RE eBPF probe, recommended for modern kernels |
| `kmod` | Stable | Traditional kernel module |
| `replay` | Stable | Replay from capture file |
| `nodriver` | Stable | No kernel driver, useful for plugins |

> The legacy `ebpf` and `gvisor` engine kinds were removed in Falco 0.44.0 (PRs [#3796](https://github.com/falcosecurity/falco/pull/3796) and [#3797](https://github.com/falcosecurity/falco/pull/3797)). The valid set above is enforced in [`configuration.cpp:236-240`](../../../refs/falcosecurity/falco/userspace/falco/configuration.cpp).

**Configuration:**
```yaml
engine:
  kind: modern_ebpf    # [Stable] Required
```

### Engine-Specific Options

**Kernel Module (kmod):**
```yaml
engine:
  kind: kmod
  kmod:
    buf_size_preset: 4        # Buffer index 0-10 (default: 4 = 8MB)
    drop_failed_exit: false   # Drop failed syscall exits
```

**Modern eBPF:**
```yaml
engine:
  kind: modern_ebpf
  modern_ebpf:
    cpus_for_each_buffer: 2   # CPUs per ring buffer (default: 2)
    buf_size_preset: 4        # Buffer index 0-10 (default: 4 = 8MB)
    drop_failed_exit: false
    disable_iterators: false  # Disable BPF iterators; fall back to procfs (default: false)
```

> **`disable_iterators`** (modern_ebpf only, since 0.44.1): by default the modern eBPF driver uses BPF iterators to synchronously fetch kernel state — populating the initial process table at startup and healing it after event drops — which is faster and more reliable than walking procfs. Set to `true` to disable the iterators and force a procfs fallback. BPF iterators are also automatically disabled whenever Falco runs outside the host (root) PID namespace, regardless of this setting. Source: [`falco.yaml:429-453`](../../../refs/falcosecurity/falco/falco.yaml), [`configuration.cpp:269-271`](../../../refs/falcosecurity/falco/userspace/falco/configuration.cpp), [`config_json_schema.h:409`](../../../refs/falcosecurity/falco/userspace/falco/config_json_schema.h).

**Replay:**
```yaml
engine:
  kind: replay
  replay:
    capture_file: "/path/to/file.scap"  # Required
```

### Buffer Size Preset

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

## Rules Configuration

### rules_files [Stable]

Specifies rule file locations (from [`configuration.cpp:324-354`](../../../refs/falcosecurity/falco/userspace/falco/configuration.cpp)):

```yaml
rules_files:                              # [Stable]
  - /etc/falco/falco_rules.yaml           # Main rules file
  - /etc/falco/falco_rules.local.yaml     # Local customizations
  - /etc/falco/rules.d                    # Directory (alphabetically sorted)
```

**Note:** Since Falco 0.41, only `.yml` and `.yaml` files are processed.

### rules [Incubating]

Enable/disable rules by name (with wildcards) or tag:

```yaml
rules:                                    # [Incubating]
  - disable:
      rule: "*"                           # Disable all rules
  - enable:
      rule: "Netcat Remote Code Execution in Container"
  - disable:
      tag: network                        # Disable by tag
```

## Plugin Configuration

### load_plugins [Stable]

List of plugins to load (from [`configuration.cpp:718-759`](../../../refs/falcosecurity/falco/userspace/falco/configuration.cpp)):

```yaml
load_plugins: []                          # [Stable] Empty = none loaded
# load_plugins: [k8saudit, json]          # Example with plugins
```

### plugins [Stable]

Plugin definitions with initialization config:

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

### plugins_hostinfo [Sandbox]

```yaml
plugins_hostinfo: true                    # [Sandbox] Enable host info for plugins
```

## Output Configuration

### Global Output Settings

| Key | Type | Default | Maturity | Description |
|-----|------|---------|----------|-------------|
| `priority` | string | `debug` | Stable | Minimum rule priority to output |
| `json_output` | bool | `false` | Stable | Output alerts in JSON format |
| `json_include_output_property` | bool | `true` | Stable | Include "output" in JSON |
| `json_include_tags_property` | bool | `true` | Stable | Include "tags" in JSON |
| `json_include_message_property` | bool | `false` | Incubating | Include formatted message |
| `json_include_output_fields_property` | bool | `true` | Incubating | Include output fields |
| `buffered_outputs` | bool | `false` | Stable | Buffer output writes |
| `time_format_iso_8601` | bool | `false` | Stable | Use ISO 8601 timestamps |
| `buffer_format_base64` | bool | `false` | Incubating | Base64 encode binary data |
| `rule_matching` | string | `first` | Incubating | `first` or `all` matching |
| `output_timeout` | int | `2000` | Stable | Output timeout in ms |

### outputs_queue [Stable]

```yaml
outputs_queue:
  capacity: 0                             # [Stable] 0 = unbounded queue
```

### append_output [Sandbox]

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

### static_fields [Sandbox]

```yaml
static_fields:                            # [Sandbox]
  foo: bar
  env_value: ${MY_ENV_VAR}
```

## Output Channels

### stdout_output [Stable]

```yaml
stdout_output:
  enabled: true                           # [Stable]
```

### syslog_output [Stable]

```yaml
syslog_output:
  enabled: true                           # [Stable]
```

### file_output [Stable]

```yaml
file_output:
  enabled: false                          # [Stable]
  keep_alive: false                       # Keep file open
  filename: ./events.txt                  # Output path
```

### http_output [Stable]

```yaml
http_output:
  enabled: false                          # [Stable]
  url: ""                                 # Required when enabled
  user_agent: "falcosecurity/falco"
  insecure: false                         # Skip TLS verification
  ca_cert: ""                             # CA certificate path
  ca_bundle: ""                           # CA bundle file
  ca_path: "/etc/ssl/certs"               # CA certificates directory
  mtls: false                             # Enable mTLS
  client_cert: "/etc/ssl/certs/client.crt"
  client_key: "/etc/ssl/certs/client.key"
  echo: false                             # Echo server responses
  compress_uploads: false                 # Compress payloads
  keep_alive: false                       # Persistent connections
  max_consecutive_timeouts: 5             # Max timeouts to ignore
```

### program_output [Stable]

```yaml
program_output:
  enabled: false                          # [Stable]
  keep_alive: false                       # Keep program running
  program: "jq '{text: .output}' | curl -d @- -X POST https://hooks.slack.com/..."
```

### grpc_output (Removed in 0.44)

Removed in Falco 0.44.0 along with the gRPC server. The `grpc_output:` key no longer exists. Use [`http_output`](#http_output-stable) or [Falcosidekick](../falcosidekick/).

## Service Configuration

### webserver [Stable]

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
- `/healthz` - Health check
- `/versions` - Version information (JSON)

### grpc (Removed in 0.44)

Removed in Falco 0.44.0. The `grpc:` section no longer exists in `falco.yaml`.

## Logging Configuration

### Falco Logging

| Key | Type | Default | Maturity | Description |
|-----|------|---------|----------|-------------|
| `log_stderr` | bool | `true` | Stable | Log to stderr |
| `log_syslog` | bool | `true` | Stable | Log to syslog |
| `log_level` | string | `info` | Stable | Log level (emergency through debug) |

### libs_logger [Stable]

```yaml
libs_logger:
  enabled: true                           # [Stable]
  severity: info                          # fatal, critical, error, warning, notice, info, debug, trace
```

## Performance Configuration

### syscall_event_timeouts [Stable]

```yaml
syscall_event_timeouts:
  max_consecutives: 1000                  # [Stable] Alert after N timeouts
```

### syscall_event_drops [Stable]

```yaml
syscall_event_drops:
  threshold: .1                           # [Stable] Drop percentage (0-1)
  actions:                                # ignore, log, alert, exit
    - log
    - alert
  rate: .03333                            # Messages per second
  max_burst: 1                            # Burst limit
  simulate_drops: false                   # Testing only
```

### base_syscalls [Stable]

```yaml
base_syscalls:
  custom_set: []                          # [Stable] Custom syscall list
  repair: false                           # Auto-add required syscalls
  all: false                              # Monitor all events (impacts performance)
```

**Syscall List Format:**
```yaml
base_syscalls:
  custom_set:
    - clone
    - execve
    - "!mprotect"                         # Exclude with ! prefix
```

### metrics [Stable]

```yaml
metrics:
  enabled: false                          # [Stable]
  interval: 1h                            # Prometheus duration format
  output_rule: true                       # Emit as Falco rule
  output_file: ""                         # Write to JSONL file
  rules_counters_enabled: true
  resource_utilization_enabled: true
  state_counters_enabled: true
  kernel_event_counters_enabled: true
  kernel_event_counters_per_cpu_enabled: false
  libbpf_stats_enabled: true
  plugins_metrics_enabled: true
  jemalloc_stats_enabled: false           # Requires jemalloc build
  convert_memory_to_mb: true
  include_empty_values: false
```

## Capture Configuration [Sandbox]

```yaml
capture:
  enabled: false                          # [Sandbox]
  path_prefix: /tmp/falco                 # Output path prefix
  mode: rules                             # rules or all_rules
  default_duration: 5000                  # Duration in ms
```

**Modes:**
- `rules`: Capture only when rules with `capture: true` trigger
- `all_rules`: Capture when any enabled rule triggers

## Hot Reload

```yaml
watch_config_files: true                  # [Stable]
```

When enabled, Falco monitors configuration and rules files for changes and automatically reloads. Reload can also be triggered via `SIGHUP` signal.

**Reloadable:**
- Rules files
- Most configuration options

**Not Reloadable (requires restart):**
- Engine kind/driver selection
- Some plugin configurations

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOST_ROOT` | Prefix to host `/proc` filesystem | `/host` |
| `FALCO_HOSTNAME` | Custom hostname for output | System hostname |
| `FALCO_CGROUP_MEM_PATH` | Container memory metric path | `/sys/fs/cgroup/memory/memory.usage_in_bytes` |
| `SKIP_DRIVER_LOADER` | Skip driver loading (fat image) | - |
| `FALCO_FRONTEND` | `noninteractive` for unattended install | - |
| `FALCO_DRIVER_CHOICE` | Driver for deb/rpm install | - |
| `FALCOCTL_ENABLED` | `no` to disable falcoctl | - |

**Environment Variable Interpolation:**
```yaml
probe: ${HOME}/.falco/falco-bpf.o         # Expands HOME
value: $${literal}                        # Escapes to ${literal}
```

## falco_libs Configuration [Incubating]

```yaml
falco_libs:
  thread_table_size: 262144               # [Incubating] Max thread table entries
  thread_table_auto_purging_interval_s: 300   # Purge interval (seconds)
  thread_table_auto_purging_thread_timeout_s: 300  # Thread timeout (seconds)
  snaplen: 80                             # I/O buffer capture size (bytes)
```

**Default Constants** (from [`falco_common.h:31-33`](../../../refs/falcosecurity/falco/userspace/engine/falco_common.h)):
- `thread_table_size`: 262144
- `thread_table_auto_purging_interval_s`: 300 (5 minutes)
- `thread_table_auto_purging_thread_timeout_s`: 300 (5 minutes)

## Sources

| Topic | Source File |
|-------|-------------|
| Main Configuration Reference | [`falco.yaml`](../../../refs/falcosecurity/falco/falco.yaml) |
| Configuration Structures | [`configuration.h`](../../../refs/falcosecurity/falco/userspace/falco/configuration.h) |
| Configuration Loading | [`configuration.cpp`](../../../refs/falcosecurity/falco/userspace/falco/configuration.cpp) |
| JSON Schema | [`config_json_schema.h`](../../../refs/falcosecurity/falco/userspace/falco/config_json_schema.h) |
| YAML Parsing | [`yaml_helper.h`](../../../refs/falcosecurity/falco/userspace/engine/yaml_helper.h) |
| Config Load Action | [`load_config.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/load_config.cpp) |
| Default Constants | [`falco_common.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_common.h) |
| Maturity Framework | [`20231220-features-adoption-and-deprecation.md`](../../../refs/falcosecurity/falco/proposals/20231220-features-adoption-and-deprecation.md) |
| Config Fragments | [`config/`](../../../refs/falcosecurity/falco/config/) |
