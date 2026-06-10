# Proposals and Architectural Decisions
> **Era:** 0.44 | **Version:** libs 0.25.2 | **Source:** [`refs/falcosecurity/libs/`](../../../refs/falcosecurity/libs/)

## Overview

This digest documents the design proposals and architectural decisions that shaped falcosecurity/libs. Understanding these provides context for why the system is designed the way it is.

**Location:** `proposals/`

## Proposal Status Summary

| Proposal | Date | Title | Status |
|----------|------|-------|--------|
| 20210524 | May 2021 | Versioning and Release | Superseded by 20220203 |
| 20210818 | Aug 2021 | Driver SemVer | **Implemented** |
| 20220203 | Feb 2022 | Versioning Schema Amendment | **Implemented** |
| 20220329 | Mar 2022 | Modern BPF Probe | **Implemented** |
| 20230530 | May 2023 | Driver Kernel Testing | **Active** |
| 20240901 | Sep 2024 | Disable Syscall Enter Events | In Progress |
| 20250923 | Sep 2025 | Plugin Schema Versioning | **Implemented** |

## Implemented Proposals

### Driver SemVer (20210818)

**Problem:** Kernel drivers were tightly coupled to specific libscap versions, requiring frequent rebuilds.

**Solution:** API versioning at the user/kernel boundary.

**Key Concepts:**
- `API_VERSION` embedded in both kernel driver and userspace code
- 64-bit version number encoding major.minor.patch
- Compatibility rules:
  - Major mismatch → Hard error (incompatible)
  - Minor mismatch → Warning (new features unavailable)
  - Patch mismatch → OK (bug fixes only)

**Benefits:**
- Drivers reusable across libscap consumers
- Reduced driver builds needed
- Enables distribution packaging
- Backward compatibility maintained

**Current Values (0.44 era):**
- API_VERSION: 10.1.0
- SCHEMA_VERSION: 4.5.1

### Versioning Schema Amendment (20220203)

**Problem:** Single version for all artifacts was too restrictive.

**Solution:** Dual versioning scheme separating libs and drivers.

**Libs Version:**
- Covers userspace libraries (libscap, libsinsp)
- Single SemVer: `0.y.z` (major=0 during stability phase)
- Development format: `<x>.<y>.<z>-<count>+<commit>`

**Driver Version:**
- Covers kernel-space components
- Separate SemVer with `+driver` suffix
- Minimum major version = 1
- Computed from both API_VERSION and SCHEMA_VERSION:
  - Major bump if either API or SCHEMA major changes
  - Minor bump if either minor changes (and no major change)
  - Patch bump otherwise

**Version Computation Example:**
```
API_VERSION = 10.1.0
SCHEMA_VERSION = 4.5.1

Driver version = max(10,4).max(1,5).max(0,1) = 10.5.1+driver
```

**Benefits:**
- Independent release cycles for libs and drivers
- Clearer compatibility guarantees
- Simpler dependency management

### Modern BPF Probe (20220329)

**Problem:** Legacy eBPF probe had limitations:
- Required kernel headers for compilation
- Perf buffers less efficient than ring buffers
- Limited BTF support
- Complex deployment

**Solution:** Modern eBPF probe using CO-RE (Compile Once, Run Everywhere).

**Key Features:**

| Feature | Legacy eBPF | Modern eBPF |
|---------|-------------|-------------|
| Kernel Version | >= 4.14 | >= 5.8 |
| Headers Required | Yes | No (CO-RE) |
| Buffer Type | Perf buffer | Ring buffer |
| BTF Support | Limited | Full |
| ARM64 Support | Partial | Full |
| Compilation | Per-kernel | Universal |

**Architecture:**

```
┌─────────────────────────────────────────────────────┐
│                   Modern eBPF Probe                  │
├─────────────────────────────────────────────────────┤
│  Dispatcher Programs (attached to tracepoints)       │
│  ├── Check capture status                           │
│  ├── Handle 32-bit compatibility                    │
│  ├── Apply event dropping logic                     │
│  └── Tail call to specific handler                  │
├─────────────────────────────────────────────────────┤
│  Event Handler Programs (tail-called)               │
│  ├── Fixed-size: Reserve directly in ring buffer   │
│  └── Variable-size: Use aux map, then copy         │
├─────────────────────────────────────────────────────┤
│  BPF Maps                                           │
│  ├── Ring buffer (per-CPU or shared)               │
│  ├── Auxiliary maps (event construction)           │
│  ├── Tail call tables (dispatcher → handler)       │
│  └── Configuration maps (interesting syscalls)     │
└─────────────────────────────────────────────────────┘
```

**CO-RE Benefits:**
- No kernel headers needed at runtime
- Single binary works across kernel versions
- BTF provides type information
- libbpf handles relocations

**Ring Buffer Benefits:**
- Better performance than perf buffers
- Natural ordering of events
- Reduced memory overhead
- Simpler producer-consumer model

### Driver Kernel Testing Framework (20230530)

**Problem:** Ensuring drivers work across the matrix of:
- Multiple Linux distributions
- Many kernel versions
- Different architectures
- Three driver types (kmod, bpf, modern_bpf)

**Solution:** Comprehensive automated testing framework.

**Test Dimensions:**

| Dimension | Coverage |
|-----------|----------|
| Distributions | 5+ (deb-based, rpm-based) |
| Kernel Versions | 10+ per driver type (focus on LTS) |
| Architectures | x86_64 (P0), aarch64 (P1) |
| Driver Types | kmod, bpf, modern_bpf |
| Compilers | GCC (kmod), Clang (BPF) |

**Test Categories:**

1. **Compilation Tests:**
   - Verify driver compiles for each kernel in test grid
   - Catch build failures early

2. **Functionality Tests:**
   - Driver loads successfully
   - Events are captured correctly
   - scap-open integration tests pass

**Infrastructure:**
- ~30 low-resource VMs
- ~70 test runs per cycle
- Continuous execution
- Results in `docs/matrix.md`

**Example Test Matrix (x86_64):**

| Distribution | Kernel Range |
|--------------|--------------|
| AmazonLinux | 4.14 - 5.10 |
| ArchLinux | 5.15 - 6.3 |
| CentOS | 3.10 - 5.14 |
| Fedora | 5.8 - 6.2 |
| Ubuntu | 4.15 - 6.2 |

### Plugin Schema Versioning (20250923)

**Problem:** Plugin API version check insufficient:
- Plugins may use event fields not available in current schema
- No validation of schema compatibility at load time
- Silent failures or incorrect behavior possible

**Solution:**

New optional plugin API function:
```c
const char* (*get_required_event_schema_version)(ss_plugin_t* s);
```

**Compatibility Rules:**

| Plugin Requires | Available | Result |
|-----------------|-----------|--------|
| 3.0.0 | 4.1.0 | OK (backward compatible) |
| 4.2.0 | 4.1.0 | FAIL (newer than available) |
| 5.0.0 | 4.1.0 | FAIL (major mismatch) |

**Scope:**
- Applies to plugins with PARSING or EXTRACTION capabilities
- Not needed for event sourcing or async-only plugins
- Default: Schema 3.0.0 if function not implemented

**Implementation:**
- API function defined in [`plugin_api.h:1159`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_api.h)
- Symbol resolution in [`plugin_loader.c:131`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_loader.c)
- Validation logic in [`plugin.cpp:617`](../../../refs/falcosecurity/libs/userspace/libsinsp/plugin.cpp) (`check_required_schema_version` method) with default 3.0.0 fallback, major/minor/patch comparison, and error messages
- Dedicated test plugin at [`test/plugins/schema_version_test.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/test/plugins/schema_version_test.cpp)

## Proposal In Progress

### Disable Syscall Enter Events (20240901)

**Status:** In Progress — driver-side enter event generation removed; converter and remaining userspace work ongoing

**Problem:** Syscall enter events consume significant resources:
- Double the events processed in userspace
- ~50% of kernel instrumentation time
- Enter events often duplicate exit event data

**Benchmark Data:**
```
Instrumentation Overhead Analysis (modern eBPF, Redis workload):
- No instrumented syscalls: ~26.5s kernel time
  - sys_enter: ~13.7s
  - sys_exit: ~12.8s

- Small syscall set (2 syscalls): ~54.8s kernel time
  - sys_enter: ~27s
  - sys_exit: ~27.8s

- Large syscall set (15 syscalls): ~146.5s kernel time
  - sys_enter: ~72s
  - sys_exit: ~74.3s
```

**Proposed Solution:**
1. Move all parameters from enter to exit events
2. Adapt libsinsp state machine for exit-only events
3. Provide scap-file conversion tool (merge ENTER→EXIT)
4. TOCTOU mitigation via per-thread-ID BPF hash maps
5. Adapt consumers (Falco, sysdig, plugins) and rules for exit-only semantics

**Implementation Progress (0.44 era):**
- Modern eBPF driver: userspace-facing syscall enter event generation removed ([libs#2588](https://github.com/falcosecurity/libs/issues/2588)); specialized TOCTOU-mitigation enter programs are retained kernel-side only at [`driver/modern_bpf/programs/attached/events/toctou_mitigation/`](../../../refs/falcosecurity/libs/driver/modern_bpf/programs/attached/events/toctou_mitigation/)
- Scap-file converter operational at [`userspace/libscap/engine/savefile/converter/`](../../../refs/falcosecurity/libs/userspace/libscap/engine/savefile/converter/) with `EF_CONVERTER_MANAGED` flag (stabilized from `EF_TMP_CONVERTER_MANAGED` in September 2025); 140 enter-event conversion rules defined in [`converter/table.cpp`](../../../refs/falcosecurity/libs/userspace/libscap/engine/savefile/converter/table.cpp)
- Userspace filtering implemented: TOCTOU-mitigation enter events (open, openat, openat2, creat, connect, execve, execveat) are dropped from the event-processing pipeline in [`parsers.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/parsers.cpp) and retained internally only for legacy scap-file parameter recovery
- Not yet addressed: `event.dir='>'` deprecation — the field remains fully operational ([`sinsp_filtercheck_event.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_event.cpp)) with no deprecation timeline
- Per-enter-event parameter migration ongoing ([libs#2427](https://github.com/falcosecurity/libs/issues/2427)): 101 of 219 enter events carry `EF_CONVERTER_MANAGED` in [`event_table.c`](../../../refs/falcosecurity/libs/driver/event_table.c), with exit-event schemas expanded to absorb enter parameters (e.g., `PPME_SYSCALL_OPEN_X` gained `dev`, `ino`)

**Expected Benefits:**
- ~50% reduction in events
- ~50% reduction in kernel instrumentation time
- Simplified event processing
- Lower CPU overhead

**Migration Path:**
- Incremental, per-driver implementation
- Consumer updates (Falco, sysdig, plugins)
- Rule updates for exit-event-only semantics

## Release Process

**Location:** `release.md`

### Release Phases

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Preparation │───▶│ Code Freeze │───▶│   Release   │
│             │    │             │    │   Branch    │
└─────────────┘    └─────────────┘    └──────┬──────┘
                                             │
┌─────────────┐    ┌─────────────┐           │
│   Release   │◀───│    Thaw     │◀──────────┘
│             │    │             │
└─────────────┘    └─────────────┘
```

### Phase Details

**1. Preparation:**
- Set milestone for target version
- Triage issues and PRs
- Communicate timeline

**2. Code Freeze:**
- No new features merged
- Bug fixes and documentation only
- Release candidate testing

**3. Release Branch:**
- Create `release/M.m.x` branch
- Cherry-pick critical fixes
- Prepare changelog

**4. Thaw:**
- Main branch reopens for development
- Next milestone created

**5. Release:**
- Tag release version
- Build and publish artifacts
- Update documentation

### Independent Release Cycles

Libs and drivers can release independently:

```
Libs:     0.22.0 ──── 0.22.1 ──── 0.23.0 ──── 0.23.1 ──── 0.23.2 ──── 0.24.0 ──── 0.25.0 ──── 0.25.2
            │                       │                                  │                       │
Drivers:  9.0.0+driver ────────── 9.1.0+driver ────────────────── 10.0.0+driver ─ 10.1.0+driver ─ 10.2.0+driver
```

## Architectural Principles

### 1. Separation of Concerns

```
┌─────────────────────────────────────────────────────┐
│                    Consumers                         │
│              (Falco, sysdig, plugins)               │
├─────────────────────────────────────────────────────┤
│                     libsinsp                         │
│         (State management, filtering, enrichment)   │
├─────────────────────────────────────────────────────┤
│                     libscap                          │
│            (Capture abstraction, drivers)           │
├─────────────────────────────────────────────────────┤
│                     Drivers                          │
│           (kmod, bpf, modern_bpf, gvisor)          │
└─────────────────────────────────────────────────────┘
```

### 2. Driver Abstraction

All drivers implement the same vtable interface:
- Capture initialization/shutdown
- Event reading
- Statistics collection

This allows:
- Runtime driver selection
- Easy addition of new capture sources
- Consistent behavior across drivers

### 3. Event Schema Stability

- Schema changes require version bump
- Backward compatibility maintained within major version
- Event format documented in `ppm_events_public.h`

### 4. Plugin Extensibility

- Well-defined plugin API
- Capability-based system (sourcing, extraction, parsing, async)
- State table sharing between plugins and core

## Driver Support Matrix

> Note: Legacy eBPF was deprecated in Falco 0.43 and removed in Falco 0.44 (see [falco proposal 20251215](../../../refs/falcosecurity/falco/proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md)).

| Architecture | Kernel Module | Legacy eBPF (Deprecated) | Modern eBPF (Default) | Status |
|--------------|---------------|--------------------------|----------------------|--------|
| x86_64 | >= 3.10 | >= 4.14 | >= 5.8 | **STABLE** |
| aarch64 | >= 3.16 | >= 4.17 | >= 5.8 | **STABLE** |
| s390x | >= 3.10 | >= 5.5 | >= 5.8 | EXPERIMENTAL |
| ppc64le | >= 3.10 | >= 5.1 | >= 5.8 | **STABLE** |
| riscv64 | >= 5.0 | N/A | N/A | EXPERIMENTAL |

## Future Roadmap

Based on proposals:

1. **Performance Optimization (In Progress):**
   - Disable syscall enter events — driver-side complete, userspace adaptation ongoing
   - Further ring buffer optimizations

2. **Plugin System Hardening (Implemented in 0.43):**
   - Schema version validation — `get_required_event_schema_version` API implemented
   - Stricter compatibility checks at plugin load time

3. **Testing Expansion:**
   - More kernel versions in test matrix
   - Additional architectures
   - Performance regression testing

## Sources

| Topic | Source File |
|-------|-------------|
| Driver SemVer proposal | [`proposals/20210818-driver-semver.md`](../../../refs/falcosecurity/libs/proposals/20210818-driver-semver.md) |
| Versioning amendment | [`proposals/20220203-versioning-schema-amendment.md`](../../../refs/falcosecurity/libs/proposals/20220203-versioning-schema-amendment.md) |
| Modern BPF proposal | [`proposals/20220329-modern-bpf-probe.md`](../../../refs/falcosecurity/libs/proposals/20220329-modern-bpf-probe.md) |
| Testing framework | [`proposals/20230530-driver-kernel-testing-framework.md`](../../../refs/falcosecurity/libs/proposals/20230530-driver-kernel-testing-framework.md) |
| Disable enter events | [`proposals/20240901-disable-support-for-syscall-enter-events.md`](../../../refs/falcosecurity/libs/proposals/20240901-disable-support-for-syscall-enter-events.md) |
| Plugin schema versioning | [`proposals/20250923-plugin-system-event-schema-versioning.md`](../../../refs/falcosecurity/libs/proposals/20250923-plugin-system-event-schema-versioning.md) |
| Release process | [`release.md`](../../../refs/falcosecurity/libs/release.md) |
| API version | [`driver/API_VERSION`](../../../refs/falcosecurity/libs/driver/API_VERSION) |
| Schema version | [`driver/SCHEMA_VERSION`](../../../refs/falcosecurity/libs/driver/SCHEMA_VERSION) |

## Related Digests

- [architecture.md](architecture.md) - Current system architecture
- [kernel-instrumentation.md](kernel-instrumentation.md) - Driver implementation details
- [modern-bpf.md](modern-bpf.md) - Modern eBPF probe details
- [plugin-framework.md](plugin-framework.md) - Plugin API
- [`../../proposals/multi-thread-falco.md`](../../proposals/multi-thread-falco.md) - Multi-thread Falco proposals (post-0.43, thread-safe thread manager)
