# Falco Binary Report

> **Generated:** 2026-05-27 | **Falco Version:** 0.44.0 | **Architecture:** x86_64 | **Source:** `falcosecurity/falco:0.44.0` container image

This report contains static analysis of the Falco binary installation, including version information, dependencies, plugins, configuration, and system requirements. Data was extracted from the official `falcosecurity/falco:0.44.0` (Wolfi-based) image, which represents the standard distribution.

## Version Information

| Component | Version |
|-----------|---------|
| Falco | 0.44.0 |
| Libs | 0.25.2 |
| Plugin API | 3.12.0 |
| Engine | 0.62.0 |
| Driver API | 10.0.0 |
| Driver Schema | 4.3.0 |
| Default Driver | 10.2.0+driver |

> The driver API and schema received a **major bump** in 0.44.0. Kernel modules and modern eBPF probes built for Falco 0.43.x are not compatible with the 0.44.0 userspace — redeploy a matching driver when upgrading.

## Binary Analysis

### File Information

| Property | Value |
|----------|-------|
| Path | `/usr/bin/falco` |
| Type | ELF 64-bit LSB executable |
| Architecture | x86-64 (AMD64) |
| Linking | Dynamically linked |
| Interpreter | `/lib64/ld-linux-x86-64.so.2` |
| Target OS | GNU/Linux 2.0.0 |
| Build ID | `65f70766bf6dd6c4` (xxHash) |
| Stripped | Yes |
| File Size | 20 MB |

### Section Sizes

| Section | Size |
|---------|------|
| text | 18,786,959 bytes (~17.9 MB) |
| data | 1,507,272 bytes (~1.4 MB) |
| bss | 2,413,624 bytes (~2.3 MB) |
| **Total** | **22,707,855 bytes (~21.7 MB)** |

### ELF Header

```
Class:                             ELF64
Data:                              2's complement, little endian
Type:                              EXEC (Executable file)
Machine:                           Advanced Micro Devices X86-64
Entry point address:               0x1a25000
```

### Build Notes

- **OS:** Linux
- **ABI Version:** 2.0.0
- **Build ID:** 65f70766bf6dd6c4

### Security Features

| Feature | Status |
|---------|--------|
| BIND_NOW | Enabled |
| Full RELRO | Enabled (FLAGS: NOW) |
| File Capabilities | None set |

## Dynamic Library Dependencies

### Required Libraries

| Library | Description |
|---------|-------------|
| `libm.so.6` | Math library |
| `libpthread.so.0` | POSIX threads |
| `libc.so.6` | GNU C Library |
| `libdl.so.2` | Dynamic linking |
| `librt.so.1` | Real-time extensions |
| `ld-linux-x86-64.so.2` | Dynamic linker |

### GLIBC Version Requirements

The Falco binary requires symbols from multiple GLIBC versions. Minimum required:

| GLIBC Version | Required |
|---------------|----------|
| GLIBC_2.2.5 | Yes |
| GLIBC_2.3 | Yes |
| GLIBC_2.3.2 | Yes |
| GLIBC_2.3.3 | Yes |
| GLIBC_2.3.4 | Yes |
| GLIBC_2.4 | Yes |
| GLIBC_2.10 | Yes |
| GLIBC_2.12 | Yes |
| **GLIBC_2.17** | **Yes (Minimum Required)** |

**Minimum GLIBC Version: 2.17** (released 2012-12-25)

This corresponds to:
- CentOS/RHEL 7+
- Debian 8+ (Jessie)
- Ubuntu 14.04+ (Trusty)

## Environment Variables

Falco recognizes the following environment variables:

| Variable | Purpose |
|----------|---------|
| `FALCO_HOSTNAME` | Override hostname in alerts |
| `FALCO_CGROUP_MEM_PATH` | Custom cgroup memory path |

> The `FALCO_GRPC_HOSTNAME` environment variable was removed in 0.44.0 along with the gRPC server and output (PR [#3798](https://github.com/falcosecurity/falco/pull/3798)).

## Plugins

### Installed Plugins (Container Image)

The official `falcosecurity/falco:0.44.0` container image ships only the bundled `container` plugin. Additional plugins (e.g., `k8saudit`, `cloudtrail`, `json`, `k8smeta`) are distributed as separate OCI artifacts and must be installed via `falcoctl` or system packages.

| Plugin | Size | GLIBC Min | Stripped |
|--------|------|-----------|----------|
| `libcontainer.so` | 36 MB | 2.28 | Yes |

### Default Loaded Plugin: container

| Property | Value |
|----------|-------|
| Name | container |
| Version | 0.7.1 |
| Description | Falco container metadata enrichment Plugin |
| Contact | github.com/falcosecurity/plugins |

**Capabilities:**
- Field Extraction
- Event Parsing
- Async Events

**Dependencies:**
- `libc.so.6`
- `ld-linux-x86-64.so.2`

**Minimum GLIBC:** 2.28 (Wolfi-built artifact in 0.44.0; up from 2.6 in 0.43.x — reflecting the Go runtime bump in the container plugin v0.7.x line).

### Container Plugin Exported Functions

```
plugin_capture_close
plugin_capture_open
plugin_destroy
plugin_dump_state
plugin_extract_fields
plugin_get_async_events
plugin_get_async_event_sources
plugin_get_contact
plugin_get_description
plugin_get_extract_event_sources
plugin_get_extract_event_types
plugin_get_fields
plugin_get_init_schema
plugin_get_last_error
plugin_get_metrics
plugin_get_name
plugin_get_parse_event_sources
plugin_get_parse_event_types
plugin_get_required_api_version
plugin_get_required_event_schema_version
plugin_get_version
plugin_init
plugin_parse_event
plugin_set_async_event_handler
plugin_set_config
```

### Container Plugin Configuration Schema

The container plugin supports configuration for multiple container engines:

**Supported Engines:**
- Docker
- Podman
- Containerd
- CRI (CRI-O, k3s)
- LXC
- libvirt_lxc
- BPM
- Static (manual container definition)

**Configuration Options:**
- `label_max_len` (integer): Maximum label length to report
- `with_size` (boolean): Inspect container sizes
- `hooks` (array): Lifecycle hooks to attach (`create`, `start`)
- `log_level` (string): `trace`, `debug`, `info`, `warn`, `error`
- `engines` (object): Per-engine enable/disable and socket configuration. All 7 engine keys (`bpm`, `containerd`, `cri`, `docker`, `libvirt_lxc`, `lxc`, `podman`) remain required; `sockets` is only required when `enabled: true` (relaxed in plugin v0.6.4 via `oneOf` conditional validation, still applies in 0.7.x).

## Configuration Files

### File Locations

| File | Size | Purpose |
|------|------|---------|
| `/etc/falco/falco.yaml` | 63 KB | Main configuration |
| `/etc/falco/config.d/falco.container_plugin.yaml` | 84 B | Container plugin loader |
| `/etc/falco/config.d/falco.iso8601_timeformat.yaml` | 66 B | ISO 8601 time format enabler |
| `/etc/falco/falco_rules.yaml` | 63 KB | Default rules (stable, falco-rules-5.1.0) |
| `/etc/falco/falco_rules.local.yaml` | 21 B | Local rule overrides |
| `/etc/falco/rules.d/` | - | Drop-in rules directory (empty by default) |

### Default Configuration Highlights

```yaml
# Engine (default)
engine:
  kind: modern_ebpf
  modern_ebpf:
    cpus_for_each_buffer: 2
    buf_size_preset: 4
    drop_failed_exit: false

# Rules files
rules_files:
  - /etc/falco/falco_rules.yaml
  - /etc/falco/falco_rules.local.yaml
  - /etc/falco/rules.d

# Plugins
load_plugins: [container]

# Capture (Sandbox)
capture:
  enabled: false
  path_prefix: /tmp/falco
  mode: rules
  default_duration: 5000

# Outputs
priority: debug
json_output: false
buffered_outputs: false
rule_matching: first
stdout_output: enabled
syslog_output: enabled
time_format_iso_8601: true
```

### Container Plugin Configuration

```yaml
# /etc/falco/config.d/falco.container_plugin.yaml
# Enable container plugin for linux non musl installation.
load_plugins: [container]
```

### ISO 8601 Time Format Configuration

```yaml
# /etc/falco/config.d/falco.iso8601_timeformat.yaml
# Enable iso 8601 time format on docker
time_format_iso_8601: true
```

## Rules Statistics

| Metric | Value |
|--------|-------|
| Loaded Rules (default `falco_rules.yaml`) | 25 |
| Macros in default rules file | 87 |
| Lists in default rules file | 49 |
| Required Engine Version (default rules) | 0.57.0 |
| Rules Files (container image) | 2 (default + local; `rules.d/` empty) |

> **Note:** The container image ships only the stable `falco_rules.yaml` (matching `falco-rules-5.1.0` artifact, released alongside Falco 0.44.0). Additional rulesets (`falco-incubating-rules`, `falco-sandbox-rules`, `application_rules`) are distributed separately via OCI artifacts and can be installed with `falcoctl`.

## Field and Event Statistics

| Metric | Value |
|--------|-------|
| Available Fields | 268 |
| Syscall Events | 729 |
| System Page Size | 4096 bytes |

> Event count increased from 725 (0.43.1) to 729 in 0.44.0, reflecting the new syscall added in libs 0.25 ([release notes](https://github.com/falcosecurity/falco/releases/tag/0.44.0)).

### Field Categories

Fields are organized into these classes:
- `evt.*` - Event fields (all types)
- `syscall.*` - Syscall-specific fields
- `proc.*` - Process fields
- `thread.*` - Thread fields
- `user.*` - User fields
- `group.*` - Group fields
- `fd.*` - File descriptor fields
- `fs.*` - Filesystem fields
- `container.*` - Container fields (from plugin)

### Ignored Syscalls (Performance)

The following syscalls are ignored by default for performance:

- `read`, `write`
- `readv`, `preadv`
- `pread`, `writev`
- `pwrite`, `pwritev`
- `send`, `recv`
- `sendfile`

## System Requirements Summary

### Minimum Requirements

| Requirement | Value |
|-------------|-------|
| Architecture | x86-64 |
| GLIBC (Falco binary, Wolfi build) | 2.17 |
| GLIBC (container plugin, Wolfi build) | 2.28 |
| Kernel (for modern eBPF) | 5.8+ recommended |
| Page Size | 4096 bytes |

### Required Libraries

For the Falco binary:
- libm.so.6
- libpthread.so.0
- libc.so.6
- libdl.so.2
- librt.so.1

For the container plugin (Wolfi build):
- libc.so.6

### Disk Space (Container Image)

| Component | Size |
|-----------|------|
| Falco binary | 20 MB |
| Container plugin | 36 MB |
| Configuration (incl. default rules) | ~130 KB |
| **Total** | **~56 MB** |

## Embedded Paths

The following paths are embedded in the Falco binary:

### Configuration Paths
- `/etc/falco/falco.yaml`
- `/etc/falco/falco.pem`

### Certificate Paths
- `/etc/ssl/certs/client.crt`
- `/etc/ssl/certs/client.key`

### System Paths
- `/usr/lib/debug/lib/modules/%s/vmlinux`
- `/usr/lib/modules/%s/kernel/vmlinux`
- `/sys/module/falco/parameters/max_consumers`

### SSL Certificate Search Paths
- `/etc/ssl/certs`

## Driver Information

Falco supports the following driver modes in 0.44.0:

| Driver | Description |
|--------|-------------|
| `modern_ebpf` | Modern eBPF (CO-RE, default) |
| `kmod` | Kernel module |
| `replay` | Capture file replay |
| `nodriver` | Plugin-only mode (no kernel instrumentation) |

> **Removed in 0.44.0:** The legacy eBPF probe (`ebpf`) was removed via PR [#3796](https://github.com/falcosecurity/falco/pull/3796); the gVisor engine (`gvisor`) was removed via PR [#3797](https://github.com/falcosecurity/falco/pull/3797). Valid engine kinds are now enforced by `engine_mode_lut` in [`configuration.cpp:236-240`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp).

### Default Driver Configuration

```yaml
engine:
  kind: modern_ebpf
  modern_ebpf:
    cpus_for_each_buffer: 2
    buf_size_preset: 4
    drop_failed_exit: false
```

## Changes from 0.43.1

This report supersedes the previous 0.43.1 snapshot (generated 2026-05-27 against the `falcosecurity/falco:0.43.1` image). Key changes in 0.44.0:

| Property | 0.43.1 (2026-04-09) | 0.44.0 (2026-05-26) |
|----------|---------------------|---------------------|
| Falco | 0.43.1 | 0.44.0 |
| Libs | 0.23.2 | 0.25.2 |
| Engine | 0.58.0 | 0.62.0 |
| Driver API | 8.0.0 | 10.0.0 (major bump) |
| Driver Schema | 4.1.0 | 4.3.0 |
| Default Driver | 9.1.0+driver | 10.2.0+driver |
| Container plugin | 0.6.4 | 0.7.1 |
| Falco binary Build ID | `bb7161f8fe777655` | `65f70766bf6dd6c4` |
| Falco text section | 18,899,154 bytes | 18,786,959 bytes |
| Falco data section | 1,604,688 bytes | 1,507,272 bytes |
| Falco bss section | 4,269,672 bytes | 2,413,624 bytes |
| Container plugin GLIBC min | 2.6 | 2.28 |
| Engine kinds available | `modern_ebpf`, `kmod`, `ebpf` (deprecated), `replay`, `gvisor` (deprecated), `nodriver` | `modern_ebpf`, `kmod`, `replay`, `nodriver` (legacy `ebpf` and `gvisor` removed) |
| Env vars | `FALCO_HOSTNAME`, `FALCO_GRPC_HOSTNAME`, `FALCO_CGROUP_MEM_PATH` | `FALCO_HOSTNAME`, `FALCO_CGROUP_MEM_PATH` (`FALCO_GRPC_HOSTNAME` removed) |
| Default rules | `falco-rules-5.0.0` (25 rules) | `falco-rules-5.1.0` (25 rules; content updated, count coincidentally identical) |
| Syscall events listed | 725 | 729 (new syscall in libs 0.25) |
