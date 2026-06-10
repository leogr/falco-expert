# Falco Blog Digest - Era 0.44

**Context**: This digest covers the Falco blog posts from the falcosecurity/falco-website repository, optimized for Falco era 0.44 (released May 26, 2026).

**Important Notes**:
- Content from previous eras may not fully apply to era 0.44
- Features introduced in earlier versions may have evolved or changed
- Deprecated features are marked accordingly
- Historical posts are preserved for context but should be used with caution

---

## Table of Contents

1. [Falco 0.44.0 Release Details](#falco-0440-release-details)
2. [Falco 0.43.0 Release Details](#falco-0430-release-details)
3. [Falco 0.43.1 Patch Release](#falco-0431-patch-release)
4. [Blog Posts Index](#blog-posts-index)
5. [Release Announcements](#release-announcements)
6. [Feature Introductions](#feature-introductions)
7. [Tutorials and How-Tos](#tutorials-and-how-tos)
8. [Case Studies and Use Cases](#case-studies-and-use-cases)
9. [Community and Ecosystem Updates](#community-and-ecosystem-updates)
10. [Historical Content Notes](#historical-content-notes)

---

## Falco 0.44.0 Release Details

**Release Date**: May 26, 2026
**Authors**: Leonardo Di Giovanna, Leonardo Grasso, Iacopo Rozzo, Alessandro Cannarella
**Libs Version**: 0.25.2
**Drivers Version**: 10.2.0+driver
**Container Plugin Version**: 0.7.1
**falcoctl Version**: 0.13.0
**falco-rules Version**: 5.1.0

**Source:** [Falco 0.44.0 blog post](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-44.0/index.md) | [Release notes on GitHub](https://github.com/falcosecurity/falco/releases/tag/0.44.0)

### Overview

Falco 0.44.0 completes the deprecation cycle started in 0.42.0 and 0.43.0: the **legacy eBPF probe**, the **gVisor engine**, and the **gRPC output (and gRPC server)** are now fully removed across the entire stack. The release also introduces new rule-language capabilities, a long-requested safety knob for the capture feature, JSON output for the `--list` family of commands, performance work on process tree lookups, and a wave of multi-thread safety fixes that lay the groundwork for the upcoming multi-threaded Falco architecture.

> **Driver compatibility warning:** the driver API and schema underwent a **major bump** to `10.2.0+driver`. Kernel modules and modern eBPF probes shipped with Falco 0.43.x are **not** compatible with Falco 0.44.0 userspace — redeploy a matching driver when upgrading.

### Cycle Stats

- 60 PRs on falcosecurity/falco (14 release-note-worthy)
- 160 PRs on falcosecurity/libs (54 release-note-worthy)
- 16 PRs on the Falco drivers (3 release-note-worthy)

### Major Features

| Feature | PR | Summary |
|---------|----|---------|
| **Comparison operator list modifiers** | [#3878](https://github.com/falcosecurity/falco/pull/3878), [libs#2984](https://github.com/falcosecurity/libs/pull/2984) | New `oneof`, `anyof`, `allof` modifiers for comparison operators in rule conditions and single-field exception `comps`. Example: `proc.name startswith anyof (kube-, etcd-)`. Semantics: `oneof` = exactly one matches; `anyof` = at least one; `allof` = all. |
| **Hard cap on capture file size** | [#3824](https://github.com/falcosecurity/falco/pull/3824) | New `capture.max_file_size_mb` config (0–1,048,576 MB; 0 = unlimited). Global, cannot be overridden by rules. Truncation emits an INFO log. |
| **Stricter rule schema validation** | [#3805](https://github.com/falcosecurity/falco/pull/3805) | Unknown top-level keys in `- rule:`/`- macro:`/`- list:` items are now flagged at load time. Same change makes `warn_evttypes`, `skip-if-unknown-filter`, `capture`, `capture_duration`, and `tags` first-class `override` targets. |
| **Backslash escaping in `-o` paths** | [#3835](https://github.com/falcosecurity/falco/pull/3835) | `-o "base.dotted\.key=val"` now targets keys with literal dots, brackets, or backslashes. |
| **JSON output for `--list` commands** | [#3803](https://github.com/falcosecurity/falco/pull/3803), [libs#2837](https://github.com/falcosecurity/libs/pull/2837) | `--list`/`--list-events` gain `--format text|markdown|json`. Legacy `--markdown` is deprecated (still works, emits warning). |
| **Faster process tree lookups** | [libs#2784](https://github.com/falcosecurity/libs/issues/2784), [libs#2879](https://github.com/falcosecurity/libs/issues/2879) | Rewritten user-space `/proc` parsers + new kernel-side lookup path via modern BPF iterators. Lower cold-start time and lower steady-state cost of recovering from dropped events. |
| **Multi-thread safety hardening** | (multiple) | `random()` → thread-local `std::mt19937`; `gmtime`/`localtime` → reentrant `_r`; `strerror` → `strerror_r`; watchdog race fixed with proper memory orderings; portable macOS/musl/WASM/Win32 wrappers added. Foundation for the [Multi-thread Falco design proposal](https://github.com/falcosecurity/falco/blob/0.44.0/proposals/20251205-multi-thread-falco-design.md) ([#3751](https://github.com/falcosecurity/falco/pull/3751)). |
| **http_output, webserver, metrics on macOS & Windows** | [#3827](https://github.com/falcosecurity/falco/pull/3827) | Cross-platform build expansion. Falco userspace can now ship http_output, webserver, and metrics on macOS and Windows. |

### Major Removals (previously deprecated, now removed)

| Removal | PR | Migration |
|---------|----|-----------|
| **Legacy eBPF probe** (`engine.kind=ebpf`, `driver/bpf/`) | [#3796](https://github.com/falcosecurity/falco/pull/3796) | Use `modern_ebpf` (default since 0.38) or `kmod`. The libs `driver/bpf/` directory no longer exists. |
| **gVisor engine** (`engine.kind=gvisor`, `--gvisor-generate-config`) | [#3797](https://github.com/falcosecurity/falco/pull/3797) | No direct replacement — under consideration as a future source plugin. |
| **gRPC output and gRPC server** (`grpc:`, `grpc_output:`, `outputs_grpc.cpp`, `grpc_server.cpp`, `outputs.proto`) | [#3798](https://github.com/falcosecurity/falco/pull/3798) | Use `http_output` or [Falcosidekick](../falcosidekick/). |

### Bundled libs 0.25.2 — Highlights

The libs jump from 0.23.x to 0.25.x is large (54 release-note-worthy PRs). Key categories:
- Multi-thread safety hardening across libsinsp internals
- Modern BPF iterator support for in-kernel `/proc`-like walks (tasks and file descriptors)
- Driver API/schema major bump to 10.x (incompatible with Falco 0.43.x drivers)
- Filter engine support for transformer-aware AST nodes used by the new comparison modifiers

See [Falco 0.44.0 release notes](https://github.com/falcosecurity/falco/releases/tag/0.44.0) and [libs 0.25.2 release](https://github.com/falcosecurity/libs/releases/tag/0.25.2) for the complete change list.

### Bundled container plugin 0.7.1 — Highlights

- Bumped from 0.6.4 (0.43.1 era) to 0.7.0 and then 0.7.1 — see [`plugins/container.md`](../plugins/container.md) for details
- containerd v2.3.0 compatibility fixes

### Plugin security: library path traversal hardening

[#3850](https://github.com/falcosecurity/falco/pull/3850) prevents plugin `library_path` traversal via relative paths. Plugin load now validates that the resolved path stays within the allowed plugin directory.

### Event generator: HTTP output

`event-generator` v0.13.0 replaces its gRPC client (used to retrieve Falco alerts during regression testing) with HTTP-based retrieval. This was a planned cleanup as part of the gRPC removal proposal.

### Kubernetes Operator

The Kubernetes operator received a Helm chart, artifact startup gating, and minor fixes. See [`falco-operator.md`](../falco-operator.md) (v0.2.2).

---

## Falco 0.43.0 Release Details

**Release Date**: January 28, 2026 (blog post published January 26, 2026)
**Authors**: Leonardo Di Giovanna, Leonardo Grasso, Iacopo Rozzo, Alessandro Cannarella
**Libs Version**: 0.23.1
**Drivers Version**: 9.1.0+driver

### Overview

Falco 0.43.0 is a **stabilization release** that consolidates changes introduced in 0.42.0, including the drop-enter initiative and capture recording feature. It introduces several deprecations and fixes.

### Key Changes in 0.43.0

#### Deprecations (May Be Removed Starting 0.44.0)

| Component | Deprecation Details | Migration Path |
|-----------|---------------------|----------------|
| **Legacy eBPF Probe** | `engine.kind=ebpf` deprecated | Use `engine.kind=modern_ebpf` (CO-RE) or `engine.kind=kmod` |
| **gVisor Engine** | `engine.kind=gvisor` deprecated | Low usage, incomplete syscall support |
| **gRPC Output/Server** | `grpc_output.enabled` and `grpc.enabled` deprecated | Use HTTP output or Falcosidekick |

#### Key Fixes

- **`evt.arg.filename` Field Reintroduction**: Fixed regression from drop-enter optimization where filename argument was unavailable for `execve`/`execveat` syscalls
- **Falcoctl Signature Verification**: Fixed for full registry references and authenticated/private registries
- **Container Plugin**: Overflow and NULL pointer dereference fixes (v0.6.1)
- **K8smeta Plugin**: Race condition fix (v0.4.1)

#### Breaking Changes

- **Minimum Kernel Version**: Drivers 9.1.0+ require Linux kernel 3.10 minimum (affects kmod only)
- **Deprecation Warnings**: Using deprecated components generates warnings

#### Notable Improvements

- **Container Plugin**: Exposes `container.id`, `container.image`, `container.name`, `container.type` via table API
- **Falcoctl Follow Interval**: Increased from 6h to 1 week (artifact polling)
- **Cosign v3 Support**: New bundle format for signature verification
- **Dependency Resolution**: Proper deduplication and signature verification for all dependencies
- **GPG Key Rotation**: New key for RPM/DEB package signing (old key expired January 2026)

---

## Falco 0.43.1 Patch Release

**Release Date**: April 9, 2026 (no dedicated blog post)
**Release Manager**: Leonardo Grasso
**Libs Version**: 0.23.2
**Drivers Version**: 9.1.0+driver
**Container Plugin Version**: 0.6.4

0.43.1 is the **last patch release of the 0.43 era**. It bumps two bundled dependencies: `libs` (0.23.1 → 0.23.2) and the `container` plugin (0.6.2 → 0.6.4), via [PR #3851](https://github.com/falcosecurity/falco/pull/3851).

### Bundled libs 0.23.2 — Bug Fixes

| Fix | PR | Impact |
|-----|-----|--------|
| **FTR_STORAGE for unary plugin field checks** | [libs#2935](https://github.com/falcosecurity/libs/pull/2935) | The `unary_check_expr` visitor was missing the `FTR_STORAGE` transformer for plugin fields with unstable pointers (`EPF_NO_PTR_STABILITY`). Combining a unary check (e.g. `exists`) with another check on the same plugin field could return stale data from the shared extract cache. Now mirrors the existing `binary_check_expr` behavior. |
| **modern_bpf: skip syscall -1** | [libs#2938](https://github.com/falcosecurity/libs/pull/2938) | Syscall id `-1` (interrupted/cancelled by ptrace or signal) is now skipped instead of being misinterpreted as `socketcall` on architectures without it. The previous behavior produced spurious `SOCKET_X` events that polluted the fd table (and propagated through clone). |

### Bundled container plugin 0.6.4 — Bug Fixes and Cleanups

The bundled container plugin advanced two patch versions (0.6.2 → 0.6.3 → 0.6.4):

| Fix | Version | Impact |
|-----|---------|--------|
| **Image parsing with registry port** | 0.6.3 | Fixed `registry.example.com:5000/foo/bar:latest` parsing. The previous `strings.Split(image, ":")` couldn't distinguish registry port from tag. Added `parseImageRepoTag()` helper that splits on the last colon after the last slash. |
| **Canonical image ID from ImageInspect** | 0.6.4 | Docker Engine upgrades changed how `ctr.Image` is reported in container inspect responses, causing silent `ImageID` extraction failures when the field contained a full reference (with `/`) instead of a bare `sha256` digest. Now uses `img.ID` from `ImageInspect`. |
| **Sockets/static fields optional when disabled** | 0.6.4 | `init_config` schema now uses `oneOf` so `sockets` is only required for `SocketsContainer` engines when `enabled: true`. Same pattern applied to `StaticContainer` (`container_id`/`container_name`/`container_image` only required when enabled). All 7 engine keys still remain required in the `Engines` definition. |

### Driver Compatibility

No driver change in 0.43.1: still ships with **9.1.0+driver** (same as 0.43.0).

---

## Blog Posts Index

### Release Announcements by Version

| Date | Version | Title | Era Relevance |
|------|---------|-------|---------------|
| 2026-05-26 | **0.44.0** | [Introducing Falco 0.44.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-44.0/index.md) | **Current Era** |
| 2026-01-26 | 0.43.0 | [Introducing Falco 0.43.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-43.0/index.md) | Previous Era |
| 2025-10-22 | 0.42.0 | [Introducing Falco 0.42.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-42.0/index.md) | Historical (0.43 built on this) |
| 2025-05-29 | 0.41.0 | [Introducing Falco 0.41.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-41.0/index.md) | Recent |
| 2025-01-28 | 0.40.0 | [Introducing Falco 0.40.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-40.0/index.md) | Recent |
| 2024-11-21 | 0.39.2 | [Falco 0.39.2](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-39-2/index.md) | Historical |
| 2024-10-09 | 0.39.1 | [Falco 0.39.1](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-39-1/index.md) | Historical |
| 2024-10-01 | 0.39.0 | [Introducing Falco 0.39.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-39-0/index.md) | Historical |
| 2024-08-19 | 0.38.2 | [Introducing Falco 0.38.2](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-38-2/index.md) | Historical |
| 2024-06-19 | 0.38.1 | [Introducing Falco 0.38.1](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-38-1/index.md) | Historical |
| 2024-05-30 | 0.38.0 | [Introducing Falco 0.38.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-38-0/index.md) | Historical |
| 2024-02-13 | 0.37.1 | [Introducing Falco 0.37.1](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-37-1/index.md) | Historical |
| 2024-01-26 | 0.37.0 | [Introducing Falco 0.37.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-37-0/index.md) | Historical |
| 2023-09-26 | 0.36.0 | [Falco 0.36.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-36-0/index.md) | Historical |
| 2023-06-07 | 0.35.0 | [Falco 0.35.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-35-0/index.md) | Historical |
| 2023-02-07 | 0.34.0 | [Falco 0.34.0 "The Honeybee"](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-34-0/index.md) | Historical |
| 2022-10-19 | 0.33.0 | [Falco 0.33.0 "the pumpkin release"](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-33-0.md) | Historical |
| 2022-08-09 | 0.32.2 | [Falco 0.32.2](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-32-2.md) | Historical |
| 2022-07-11 | 0.32.1 | [Falco 0.32.1](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-32-1.md) | Historical |
| 2022-01-31 | 0.31.0 | [Falco 0.31.0 "the Gyrfalcon"](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-31-0.md) | Historical (Plugin System GA) |
| 2021-10-01 | 0.30.0 | [Falco 0.30.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-30-0.md) | Historical |
| < 0.30.0 | Various | Multiple releases | Legacy |

---

## Release Announcements

### Current Era (0.40.0 - 0.44.0)

#### Falco 0.42.0 (October 2025) - Foundation for 0.43

Key features consolidated in 0.43:

- **Capture Recording Feature**: Generate `.scap` files on rule triggers for forensic analysis with Stratoshark
- **Drop-Enter Initiative**: ~50% reduction in events, up to 20% workload performance improvement, 30% CPU reduction
- **Plugin Event Schema Validation**: Backward compatibility checking for plugins
- **Thread Table Auto-Purging**: Configurable `thread_table_size`, `thread_table_auto_purging_interval_s`
- **Static Fields**: `static_fields` configuration for custom fields in rules

**Breaking Changes in 0.42**:
- `evt.dir` field deprecated (use exit events only)
- Old plugins without schema version declaration incompatible

#### Falco 0.41.0 (May 2025)

- **Container Support as Plugin**: New `container` plugin architecture (bundled)
- **Kubernetes Operator**: Technical preview at github.com/falcosecurity/falco-operator
- **New Fields**: `proc.aargs` (ancestor args lookup), indexed `proc.args` access
- **Security Improvements**: modern eBPF no longer stores settings in `.bss` segment

**Breaking Changes**:
- Removed `-S`/`--snaplen`, `-A`, `-b` CLI options (use config instead)
- Container engine config options dropped (use plugin init config)
- Only `.yml`/`.yaml` rule files loaded

#### Falco 0.40.0 (January 2025)

- **Streamlined Docker Images**: Distroless default, reduced size
- **Process Filters**: `proc.pgid`, `proc.pgid.name`, `proc.pgid.exe`, etc.
- **Plugins Suggested Output Fields**: Automatic field addition from plugins
- **Build Improvements**: Zig/Clang toolchain (10% speedup), jemalloc allocator

**Breaking Changes**:
- Removed `--cri`, `--disable-cri-async` CLI options
- Docker images restructured (see release notes)

### Historical Era (0.38.0 - 0.39.x)

#### Falco 0.39.0 (October 2024)

- `basename()` transformer operator
- `regex` operator for pattern matching
- `append_output` feature for rule output customization
- Dynamic driver selection in Helm (`driver.kind=auto`)

#### Falco 0.38.0 (May 2024) - First Post-Graduation Release

- **Driver Loader Magic**: Auto-detect and select best driver
- **Config File Splitting**: `config_files` for modular configuration
- **Runtime Rule Selection**: `rules` config option for enable/disable
- **Field Transformers**: `val()`, `toupper()`, `tolower()`, `b64()`
- **Prometheus Metrics Support**

---

## Feature Introductions

### Features Still Relevant to 0.44

| Feature | Introduced | Status in 0.44 |
|---------|-----------|----------------|
| Modern eBPF Probe (CO-RE) | 0.34.0 | **Sole eBPF driver** — legacy eBPF removed in 0.44 |
| Plugin System | 0.31.0 | Stable |
| Adaptive Syscall Selection | 0.35.0 | Stable |
| Rule Exceptions | 0.28.0 | Stable (gained `oneof`/`anyof`/`allof` modifiers in 0.44) |
| Falcosidekick Integration | 2019 | Stable - Now the only fan-out option (gRPC removed in 0.44) |
| k8smeta Plugin | 2024 | Stable (v0.4.1 in 0.44) |
| Container Plugin | 0.41.0 | Stable (v0.7.1 bundled in 0.44) |
| Capture Recording | 0.42.0 | Sandbox maturity (gained `capture.max_file_size_mb` hard cap in 0.44) |
| Append Output | 0.39.0 | Stable |
| Static Fields | 0.42.0 | Stable |
| Comparison list modifiers (`oneof`/`anyof`/`allof`) | 0.44.0 | **New** — Stable |
| `--format json` for listing CLI | 0.44.0 | **New** — Stable |

### Key Feature Blog Posts

#### Modern eBPF Probe
- **Post**: [Getting started with modern BPF probe in Falco](../../../refs/falcosecurity/falco-website/content/en/blog/falco-modern-bpf/index.md) (2022-11-30)
- **Post**: [Modern eBPF probe is ready to shine](../../../refs/falcosecurity/falco-website/content/en/blog/falco-modern-bpf-0-35-0/index.md) (2023-06-14)
- **Status**: Production-ready since 0.35.0, **the sole eBPF driver in 0.44** (legacy eBPF removed)
- **Requirements**: Linux kernel 5.8+, BTF support

#### Plugin System
- **Post**: [Announcing Plugins and Cloud Security with Falco](../../../refs/falcosecurity/falco-website/content/en/blog/announcing_plugins_and_cloud_security_with_falco.md) (2022-02-09)
- **Post**: "Extend Falco inputs by creating a Plugin" series (2022-2023)
- **Available Plugins**: Cloudtrail, k8saudit, Okta, GitHub, k8smeta, container, etc.

#### Adaptive Syscall Selection
- **Post**: [Adaptive Syscalls Selection in Falco](../../../refs/falcosecurity/falco-website/content/en/blog/adaptive-syscalls-selection/index.md) (2023-07-04)
- **Configuration**: `base_syscalls.custom_set`, `base_syscalls.repair`
- **Benefit**: Reduce CPU load by monitoring only needed syscalls

#### Rule Exceptions
- **Post**: [Falco Rules Now Support Exceptions](../../../refs/falcosecurity/falco-website/content/en/blog/exceptions.md) (2021-01-19)
- **Syntax**: `exceptions` property in rules with fields, comps, values

---

## Tutorials and How-Tos

### Still Relevant Tutorials

| Title | Date | Topic | 0.44 Relevance |
|-------|------|-------|----------------|
| [How to Deploy Falco with k8s-metacollector + k8smeta Plugin](../../../refs/falcosecurity/falco-website/content/en/blog/falco-k8smeta-plugin/index.md) | 2024-10-14 | Kubernetes enrichment | High |
| [Deploy Falco on a Talos cluster](../../../refs/falcosecurity/falco-website/content/en/blog/talos/index.md) | 2024-07-22 | Talos Linux | High |
| [Adding runtime threat detection to GKE with Falco](../../../refs/falcosecurity/falco-website/content/en/blog/falco-on-gke/index.md) | 2023-11-20 | GKE deployment | High |
| [GitOps your Falco Rules](../../../refs/falcosecurity/falco-website/content/en/blog/gitops-your-falco-rules/index.md) | 2023-05-12 | OCI artifacts | High |
| [Crafting Falco Rules With MITRE ATT&CK](../../../refs/falcosecurity/falco-website/content/en/blog/falco-mitre-attack/index.md) | 2023-07-16 | Rule writing | High |
| [Tracing System Calls Using eBPF (Part 1)](../../../refs/falcosecurity/falco-website/content/en/blog/tracing-system-calls-using-ebpf-part-1/index.md) | 2023-09-11 | eBPF fundamentals | Medium |
| [PCI/DSS Controls with Falco](../../../refs/falcosecurity/falco-website/content/en/blog/falco-pci-dss/index.md) | 2023-07-06 | Compliance | High |
| [Validating NIST Requirements with Falco](../../../refs/falcosecurity/falco-website/content/en/blog/nist-controls/index.md) | 2023-07-18 | Compliance | High |
| [Integrate Runtime Security with Falcosidekick](../../../refs/falcosecurity/falco-website/content/en/blog/sidekick-overview/index.md) | 2023-10-24 | Integration | High |
| [Rule basics for the Falco 3.0.0 Helm chart](../../../refs/falcosecurity/falco-website/content/en/blog/rules-helm-chart-3-0-0.md) | 2023-02-09 | Helm rules | Medium (check versions) |

### Outdated/Historical Tutorials

| Title | Date | Notes |
|-------|------|-------|
| [Choosing a Falco driver](../../../refs/falcosecurity/falco-website/content/en/blog/choosing-a-driver.md) | 2020-09-23 | **Outdated**: Modern eBPF not covered, pdig deprecated |
| [Extend Falco outputs with falcosidekick](../../../refs/falcosecurity/falco-website/content/en/blog/extend-falco-outputs-with-falcosidekick.md) | 2020-06-22 | Concepts valid, versions outdated |
| [Getting started with gVisor support](../../../refs/falcosecurity/falco-website/content/en/blog/intro-gvisor-falco/index.md) | 2022-09-15 | **gVisor engine removed in 0.44** (deprecated in 0.43) |
| [Falco on Kind with Prometheus and Grafana](../../../refs/falcosecurity/falco-website/content/en/blog/falco-kind-prometheus-grafana.md) | 2020-03-19 | Commands may be outdated |

---

## Case Studies and Use Cases

### Detection Scenarios

| Title | Date | Topic |
|-------|------|-------|
| [Preventing attacker persistence with Falco on AWS](../../../refs/falcosecurity/falco-website/content/en/blog/aws-detection/index.md) | 2024-03-11 | AWS Lambda/Lex persistence |
| [Detecting Threats in OVHcloud MKS Audit Logs](../../../refs/falcosecurity/falco-website/content/en/blog/detect-threats-falco-ovh-mks-audit-logs-plugin/index.md) | 2025-03-13 | OVHcloud plugin |
| [Falco plugin for collecting AKS audit logs](../../../refs/falcosecurity/falco-website/content/en/blog/falco-aks-audit-logs-plugin/index.md) | 2025-03-09 | Azure AKS |
| [Using Falco to Protect GitHub](../../../refs/falcosecurity/falco-website/content/en/blog/falco-plugin-github/index.md) | 2022-10-25 | GitHub security |
| [Using Falco to Create Custom Identity Detections](../../../refs/falcosecurity/falco-website/content/en/blog/falco-okta-identity/index.md) | 2023-11-28 | Identity security |
| [Detect Malicious Behaviour through Audit Logs](../../../refs/falcosecurity/falco-website/content/en/blog/falco-detect-malicious-behavior-through-audit-logs.md) | 2021-05-22 | K8s audit logs |
| [Package Hunter: Detect supply chain attacks](../../../refs/falcosecurity/falco-website/content/en/blog/package-hunter-falco.md) | 2021-12-09 | GitLab use case |

### Response Engine Series (Concepts Still Valid)

The "Kubernetes Response Engine" blog series demonstrates integration patterns:
- Part 1: Falcosidekick + Kubeless
- Part 2: Falcosidekick + OpenFaaS
- Part 3: Falcosidekick + Knative
- Part 4: Falcosidekick + Tekton
- Part 5: Falcosidekick + Argo
- Part 6-9: Cloud Run, Cloud Functions, Flux v2, Fission

**Note**: For 0.44, consider using **Falco Talon** as a dedicated response engine.

---

## Community and Ecosystem Updates

### Major Milestones

| Date | Event |
|------|-------|
| 2024-02-29 | [**Falco Graduates within the CNCF**](../../../refs/falcosecurity/falco-website/content/en/blog/falco-graduation/index.md) |
| 2022-09-02 | Governance documentation updated |
| 2021-02-23 | [Drivers and libraries contributed to CNCF](../../../refs/falcosecurity/falco-website/content/en/blog/contribution-drivers-kmod-ebpf-libraries.md) |

### Ecosystem Tools

#### Falcosidekick
- **Latest blog-announced release**: [2.31.0](../../../refs/falcosecurity/falco-website/content/en/blog/falcosidekick-2-31-0/index.md) (February 2025); the 0.44-era reference release is 2.34.0 (no dedicated blog post)
- 60+ output integrations
- AWS Security Lake, OTLP Metrics support
- Recommended replacement for the removed gRPC output (removed in 0.44)

#### Falco Talon
- **Latest**: [v0.3.0](../../../refs/falcosecurity/falco-website/content/en/blog/falco-talon-v0-3-0/index.md) (February 2025)
- Response engine for automated remediation
- New `kubernetes:sysdig` actionner for syscall capture
- S3/Minio export support

#### Falcosidekick-UI
- **Latest**: [2.2.0](../../../refs/falcosecurity/falco-website/content/en/blog/falcosidekick-ui-2-2-0/index.md) (September 2023)
- Real-time event visualization
- Authentication support (can be disabled)

---

## Historical Content Notes

### Deprecated/Removed Features (Do Not Use in 0.44)

| Feature | Deprecated In | Removal Status |
|---------|--------------|----------------|
| Legacy eBPF Probe (`engine.kind=ebpf`) | 0.43.0 | **Removed in 0.44.0** |
| gVisor Engine (`engine.kind=gvisor`) | 0.43.0 | **Removed in 0.44.0** |
| gRPC Output/Server | 0.43.0 | **Removed in 0.44.0** |
| `evt.dir` field | 0.42.0 | Future |
| `-p` CLI flag | 0.41.0 | Future |
| `pdig` driver | Historical | Not recommended |

### Configuration Changes Over Time

| Old Option | New Option (0.44) |
|------------|-------------------|
| `--modern_ebpf` | `engine.kind: modern_ebpf` |
| `--nodriver` | `engine.kind: nodriver` |
| `FALCO_BPF_PROBE` env | Removed in 0.44 with the legacy eBPF probe — use `engine.kind: modern_ebpf` |
| `-e <file.scap>` | `engine.kind=replay`, `engine.replay.capture_file` |
| `--cri`, `--disable-cri-async` | Container plugin config |
| `-D`, `-t`, `-T` | `rules[]` config with enable/disable |
| `-S/--snaplen` | `falco_libs.snaplen` |
| `-A` | `base_syscalls.all` |
| `-b` | `buffer_format_base64` |
| `syscall_buf_size_preset` | `engine.<driver>.buf_size_preset` |

### Docker Image Evolution

| Old Image | Current Equivalent (0.44) |
|-----------|---------------------------|
| `falcosecurity/falco-distroless` | `falcosecurity/falco:x.y.z` |
| `falcosecurity/falco-no-driver` | `falcosecurity/falco:x.y.z-debian` |

---

## Quick Reference for 0.44 Users

### Available Driver Kinds

1. **Modern eBPF** (`engine.kind=modern_ebpf`): Default. Requires kernel 5.8+
2. **Kernel Module** (`engine.kind=kmod`): For older kernels (3.10+)
3. **Replay** (`engine.kind=replay`): For replaying capture files
4. **No driver** (`engine.kind=nodriver`): Plugin-only deployments

> Legacy eBPF and gVisor are no longer available — both removed in 0.44.0.

### Essential Configuration for 0.44

```yaml
# Recommended engine configuration
engine:
  kind: modern_ebpf

# Output (gRPC removed in 0.44, use HTTP or Falcosidekick)
http_output:
  enabled: true
  url: "http://falcosidekick:2801"

# Capture feature (sandbox maturity)
capture:
  enabled: false  # Enable for forensics
  path_prefix: /tmp/falco
  mode: rules
  default_duration: 5000      # ms
  # New in 0.44: hard cap on capture file size (0 = unlimited, max 1,048,576 MB)
  max_file_size_mb: 100

# Static fields
static_fields:
  environment: production
```

### GPG Key Update Required

Pre-existing installations must import the new GPG key for package updates:
- Follow documentation at falco.org/docs/setup/packages/

---

## Sources

| Topic | Source File |
|-------|-------------|
| Falco 0.44.0 release | [`blog/falco-0-44.0/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-44.0/index.md) |
| Falco 0.43.0 release | [`blog/falco-0-43.0/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-43.0/index.md) |
| Falco 0.42.0 release | [`blog/falco-0-42.0/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-42.0/index.md) |
| Falco 0.41.0 release | [`blog/falco-0-41.0/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-41.0/index.md) |
| Falco 0.40.0 release | [`blog/falco-0-40.0/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falco-0-40.0/index.md) |
| Modern eBPF probe | [`blog/falco-modern-bpf/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falco-modern-bpf/index.md) |
| Adaptive syscalls | [`blog/adaptive-syscalls-selection/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/adaptive-syscalls-selection/index.md) |
| Falco graduation | [`blog/falco-graduation/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falco-graduation/index.md) |
| Falcosidekick 2.31.0 | [`blog/falcosidekick-2-31-0/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falcosidekick-2-31-0/index.md) |
| Falco Talon v0.3.0 | [`blog/falco-talon-v0-3-0/index.md`](../../../refs/falcosecurity/falco-website/content/en/blog/falco-talon-v0-3-0/index.md) |

*Generated for Falco 0.44 era. Last updated: 2026-06-10*
