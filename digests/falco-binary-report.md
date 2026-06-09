# Falco Binary Report Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falco-binary-report.md`](../refs/falco-binary-report.md) | **Generated:** 2026-05-27

Static analysis of the Falco 0.44.0 binary installation including dependencies, plugins, and system requirements. Data sourced from the official `falcosecurity/falco:0.44.0` (Wolfi-based) container image.

## Quick Reference

| Property | Value |
|----------|-------|
| Falco Version | 0.44.0 |
| Libs Version | 0.25.2 |
| Plugin API | 3.12.0 |
| Engine | 0.62.0 |
| Driver API | 10.0.0 (**major bump** from 8.0.0 in 0.43.x) |
| Driver Schema | 4.3.0 |
| Default Driver | 10.2.0+driver |
| Architecture | x86-64 |
| Binary Size | 20 MB |
| Min GLIBC (binary) | 2.17 |
| Min GLIBC (container plugin, Wolfi build) | 2.28 |

> The driver API/schema bump from 0.43.x means kernel modules and modern eBPF probes built for Falco 0.43 are not compatible with 0.44 userspace; redeploy a matching driver when upgrading.

## System Requirements

### GLIBC Compatibility

| GLIBC Version | Falco Binary | Container Plugin (Wolfi) |
|---------------|--------------|--------------------------|
| 2.17 | ✓ | ✗ |
| 2.28+ | ✓ | ✓ |

**Distribution Compatibility (binary + container plugin):**
- CentOS/RHEL 8+
- Debian 10+ (Buster)
- Ubuntu 18.10+
- Fedora 29+

### Required Libraries

**Falco binary:**
- `libc.so.6`, `libm.so.6`, `libpthread.so.0`, `libdl.so.2`, `librt.so.1`

**Container plugin:**
- `libc.so.6` only

### Disk Space (Container Image)

| Component | Size |
|-----------|------|
| Binary | 20 MB |
| Container plugin | 36 MB |
| Config + default rules | ~130 KB |
| **Total** | **~56 MB** |

> **Note:** Sizes are for the official `falcosecurity/falco:0.44.0` image. Additional rule files (`incubating`, `sandbox`, `application_rules`) and plugins (`k8saudit`, `cloudtrail`, `k8smeta`, `json`) are distributed as separate OCI artifacts via `falcoctl` and increase the on-disk footprint when installed.

## Default Configuration

```yaml
engine:
  kind: modern_ebpf
  modern_ebpf:
    cpus_for_each_buffer: 2
    buf_size_preset: 4

load_plugins: [container]

rules_files:
  - /etc/falco/falco_rules.yaml
  - /etc/falco/falco_rules.local.yaml
  - /etc/falco/rules.d

# Capture (Sandbox) — new max_file_size_mb hard cap available in 0.44
capture:
  enabled: false
  path_prefix: /tmp/falco
  mode: rules
  default_duration: 5000   # ms

priority: debug
json_output: false
stdout_output: enabled
syslog_output: enabled
time_format_iso_8601: true
```

Two config drop-ins ship in `/etc/falco/config.d/`:

```yaml
# falco.container_plugin.yaml — enables the container plugin
load_plugins: [container]

# falco.iso8601_timeformat.yaml — ISO 8601 timestamps (Docker convention)
time_format_iso_8601: true
```

## Plugins

### Installed Plugins (Container Image)

The official image ships only the bundled `container` plugin. Additional plugins are distributed as separate OCI artifacts and installed via `falcoctl`.

| Plugin | Size | Min GLIBC | Purpose |
|--------|------|-----------|---------|
| `libcontainer.so` | 36 MB | 2.28 (Wolfi build) | Container metadata enrichment |

### Container Plugin (Default)

**Version:** 0.7.1

**Capabilities:**
- Field Extraction
- Event Parsing
- Async Events

**Supported Container Engines:**
- Docker, Podman, Containerd, CRI (CRI-O, k3s), LXC, libvirt_lxc, BPM, Static

**Plugin API Functions:** 25 exported functions including `plugin_init`, `plugin_extract_fields`, `plugin_parse_event`, `plugin_get_async_events`

**Schema:** all 7 engine keys remain required in the `Engines` definition; `sockets` is only required for `SocketsContainer` types when `enabled: true` (via `oneOf` conditional validation, introduced in 0.6.4 and retained in 0.7.x). Same pattern for `StaticContainer` fields.

## Statistics

| Metric | Value |
|--------|-------|
| Available Fields | 268 |
| Syscall Events | 729 (up from 725 in 0.43.1) |
| Loaded Rules (default `falco_rules.yaml`) | 25 |
| Macros (default rules) | 87 |
| Lists (default rules) | 49 |
| Required Engine Version (default rules) | 0.57.0 |
| System Page Size | 4096 bytes |

## File Locations

| Path | Purpose |
|------|---------|
| `/usr/bin/falco` | Main binary |
| `/etc/falco/falco.yaml` | Main configuration (63 KB) |
| `/etc/falco/config.d/` | Config fragments (`container_plugin`, `iso8601_timeformat`) |
| `/etc/falco/falco_rules.yaml` | Default rules (63 KB, falco-rules-5.1.0) |
| `/etc/falco/falco_rules.local.yaml` | Local overrides (21 B) |
| `/etc/falco/rules.d/` | Drop-in rules directory (empty by default) |
| `/usr/share/falco/plugins/` | Plugin directory |

## Security Features

| Feature | Status |
|---------|--------|
| BIND_NOW | Enabled |
| Full RELRO | Enabled |
| Position Independent | No (EXEC type) |
| Stripped | Yes |
| File Capabilities | None set |
| Build ID | `65f70766bf6dd6c4` (xxHash) |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `FALCO_HOSTNAME` | Override hostname in alerts |
| `FALCO_CGROUP_MEM_PATH` | Custom cgroup memory path |

> `FALCO_GRPC_HOSTNAME` was removed in 0.44.0 along with the gRPC server.

## Driver Modes

| Driver | Description | Kernel Requirement |
|--------|-------------|-------------------|
| `modern_ebpf` | CO-RE eBPF (default) | 5.8+ |
| `kmod` | Kernel module | Any |
| `replay` | Capture replay | N/A |
| `nodriver` | Plugin-only mode | N/A |

> The legacy `ebpf` and `gvisor` engine kinds were removed in 0.44.0 (PRs [#3796](https://github.com/falcosecurity/falco/pull/3796), [#3797](https://github.com/falcosecurity/falco/pull/3797)). Valid kinds are enforced in [`configuration.cpp:236-240`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp).

## Ignored Syscalls

For performance, these high-frequency syscalls are ignored by default:
`read`, `write`, `readv`, `writev`, `pread`, `pwrite`, `preadv`, `pwritev`, `send`, `recv`, `sendfile`

## Changes from 0.43.1 Snapshot

| Property | 0.43.1 (2026-04-09) | 0.44.0 (2026-05-26) |
|----------|---------------------|---------------------|
| Falco | 0.43.1 | 0.44.0 |
| Libs | 0.23.2 | 0.25.2 |
| Engine | 0.58.0 | 0.62.0 |
| Driver API | 8.0.0 | 10.0.0 (major bump) |
| Driver Schema | 4.1.0 | 4.3.0 |
| Default Driver | 9.1.0+driver | 10.2.0+driver |
| Container plugin | 0.6.4 | 0.7.1 |
| Build ID | `bb7161f8fe777655` | `65f70766bf6dd6c4` |
| Container plugin GLIBC min | 2.6 | 2.28 |
| Engine kinds available | `modern_ebpf`, `kmod`, `ebpf`*, `replay`, `gvisor`*, `nodriver` (`*` = deprecated) | `modern_ebpf`, `kmod`, `replay`, `nodriver` (legacy `ebpf` and `gvisor` removed) |
| Env vars | +`FALCO_GRPC_HOSTNAME` | `FALCO_GRPC_HOSTNAME` removed |
| Default rules version | falco-rules-5.0.0 | falco-rules-5.1.0 |
| Syscall events listed | 725 | 729 |

## Sources

| Topic | Source File |
|-------|-------------|
| Binary analysis report | [`falco-binary-report.md`](../refs/falco-binary-report.md) |

## Related Digests

- [`falco-website/docs.md`](falcosecurity/falco-website/docs.md) - Official documentation
- [`charts.md`](falcosecurity/charts.md) - Helm chart deployment
- [`falcoctl.md`](falcosecurity/falcoctl.md) - Driver and artifact management
- [`rules.md`](falcosecurity/rules.md) - Rules reference
