# falcosecurity/libs Digest

**Repository:** [falcosecurity/libs](https://github.com/falcosecurity/libs)
**Version:** 0.25.2 (libs version for Falco 0.44 era; bundled with Falco 0.44.0)
**API Version:** 8.0.4 | **Schema Version:** 4.1.0 | **Plugin API:** 3.12.0

## Overview

The libs repository contains the core runtime components that power Falco's system call monitoring:

- **Drivers** - Kernel-space components that capture syscalls (modern eBPF, kernel module)
- **libscap** - System CAPture library for driver communication and event buffering
- **libsinsp** - System INSPection library for state management, event enrichment, and filtering
- **Plugin Framework** - Extension system for custom event sources and field extraction

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Falco                                   │
├─────────────────────────────────────────────────────────────────┤
│                        libsinsp                                  │
│  ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌──────────────────┐  │
│  │  State   │ │ Parsers  │ │  Filters   │ │ Plugin Manager   │  │
│  │  Engine  │ │          │ │            │ │                  │  │
│  └──────────┘ └──────────┘ └────────────┘ └──────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                         libscap                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Engine Abstraction                     │   │
│  │  ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌───────────────┐  │   │
│  │  │ modern  │ │  kmod   │ │  gvisor  │ │   savefile    │  │   │
│  │  │  bpf    │ │   bpf   │ │          │ │    plugin     │  │   │
│  │  └─────────┘ └─────────┘ └──────────┘ └───────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                         Drivers                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Modern eBPF (DEFAULT)        │ Kernel Module           │    │
│  │  - CO-RE enabled              │                         │    │
│  │  - Ring buffers               │                         │    │
│  │  - Tail calls                 │                         │    │
│  └─────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│                     Linux Kernel                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Syscalls  │  Tracepoints  │  BTF  │  Ring Buffers       │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Digest Files

| File | Description | Size |
|------|-------------|------|
| [`proposals-and-architecture.md`](proposals-and-architecture.md) | Design proposals, versioning, roadmap | ~12KB |
| [`architecture.md`](architecture.md) | Component relationships, event flow, build system | ~8KB |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Syscall hooks, kmod vs eBPF, data flow | ~12KB |
| [`modern-bpf.md`](modern-bpf.md) | Modern eBPF driver (DEFAULT), CO-RE, ring buffers | ~12KB |
| [`libscap.md`](libscap.md) | System capture library, engine abstraction | ~6KB |
| [`libsinsp.md`](libsinsp.md) | System inspection, state engine, filtering | ~10KB |
| [`filtering.md`](filtering.md) | Filter language, operators, filterchecks | ~15KB |
| [`state-management.md`](state-management.md) | State tables, plugin state API, thread/FD tables | ~12KB |
| [`scap-file-format.md`](scap-file-format.md) | .scap capture file format, blocks, events | ~10KB |
| [`plugin-framework.md`](plugin-framework.md) | Plugin API, capabilities, state tables | ~6KB |
| [`api-reference.md`](api-reference.md) | Event types, flags, data structures | ~8KB |

## Quick Reference

### Supported Architectures

> Note: The legacy eBPF probe was removed in libs 0.25 / Falco 0.44.

| Arch | Kernel Module | Modern eBPF | Status |
|------|---------------|-------------|--------|
| x86_64 | >= 3.10 | >= 5.8 | STABLE |
| aarch64 | >= 3.16 | >= 5.8 | STABLE |
| s390x | >= 3.10 | >= 5.8 | EXPERIMENTAL |
| ppc64le | >= 3.10 | >= 5.8 | STABLE |
| riscv64 | >= 5.0 | N/A | EXPERIMENTAL |

### Driver Selection Guide

| Use Case | Recommended Driver |
|----------|-------------------|
| Modern kernels (>= 5.8) | **Modern eBPF** (default) |
| Older kernels (< 5.8) | Kernel module |
| Container environments | Modern eBPF (no kernel headers needed) |
| Maximum compatibility | Kernel module |

### Key Source Files

| File | Purpose |
|------|---------|
| `driver/ppm_events_public.h` | Event types, flags, parameter definitions |
| `userspace/libscap/scap_vtable.h` | Engine abstraction interface |
| `userspace/libsinsp/sinsp.h` | Main library entry point |
| `userspace/libsinsp/threadinfo.h` | Thread/process state |
| `userspace/plugin/plugin_api.h` | Plugin API specification |

## Related Documentation

- [Falco Documentation](https://falco.org/docs/)
- [Driver Loading](https://falco.org/docs/install-operate/running/#driver-loading)
- [Plugin System](https://falco.org/docs/plugins/)
