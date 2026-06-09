# Kernel Instrumentation

> Kernel-level event capture: modern eBPF driver, kernel module, syscall table, event model, and architecture support.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/libs/driver/`](../refs/falcosecurity/libs/driver/)

## Overview

Falco captures system events by instrumenting the Linux kernel at syscall and tracepoint boundaries. The kernel instrumentation layer is responsible for:

- Intercepting ~280 syscalls and kernel tracepoints
- Extracting event parameters from kernel structures
- Encoding events into a binary format
- Delivering events to userspace through ring buffers

Two driver implementations are actively maintained:

| Driver | Status | Kernel Requirement | Description |
|--------|--------|--------------------|-------------|
| **Modern eBPF** | **Default** | >= 5.8 with BTF | CO-RE enabled, ring buffers, tail call dispatch |
| **Kernel Module (kmod)** | Supported | >= 3.10 | Traditional kernel module, broader compatibility |

**Source:** [`digests/falcosecurity/libs/kernel-instrumentation.md`](../digests/falcosecurity/libs/kernel-instrumentation.md), [`digests/falcosecurity/libs/modern-bpf.md`](../digests/falcosecurity/libs/modern-bpf.md)

## Architecture

### Driver Location

```
libs/driver/
├── modern_bpf/              # Modern eBPF driver (DEFAULT)
│   ├── definitions/         # vmlinux.h, struct flavors, event dimensions
│   ├── helpers/             # BPF helper functions
│   │   ├── base/            # Common macros, map getters, stats
│   │   ├── extract/         # Kernel data extraction
│   │   ├── interfaces/      # Event building APIs
│   │   └── store/           # Ring buffer and auxmap storage
│   ├── maps/                # BPF map definitions
│   └── programs/            # BPF programs
│       ├── attached/        # Tracepoint-attached dispatchers
│       └── tail_called/     # Per-syscall handlers
├── ppm_fillers.c            # Kmod filler implementations
├── ppm_fillers.h            # Kmod filler declarations
├── ppm_events_public.h      # Event type definitions (shared)
├── syscall_table64.c        # Syscall-to-event mapping
└── ppm_events.c             # Event handling and string extraction
```

**Source:** [`refs/falcosecurity/libs/driver/`](../refs/falcosecurity/libs/driver/)

### Shared Components

Both drivers share core definitions from the `driver/` root:

- **`ppm_events_public.h`** — Event type enum (`PPME_*`), event parameter types, flags
- **`syscall_table64.c`** — Mapping of syscall numbers to `ppm_sc_code` and event types
- **`ppm_events.c`** — Event parameter encoding/decoding utilities

## Event Model

### Event Header

Every event captured by the driver has a standard binary header:

```c
// driver/ppm_events_public.h
struct ppm_evt_hdr {
    uint64_t ts;        // Timestamp (nanoseconds since epoch)
    uint64_t tid;       // Thread ID
    uint32_t len;       // Total event length (header + params)
    uint16_t type;      // Event type (ppm_event_type enum)
    uint32_t nparams;   // Number of parameters
};
```

**Source:** [`refs/falcosecurity/libs/driver/ppm_events_public.h`](../refs/falcosecurity/libs/driver/ppm_events_public.h)

### Event Binary Layout

```
┌─────────────────────────────────────────────────────┐
│                    Event Header                      │
├─────────────────────────────────────────────────────┤
│  ts (uint64_t)           │ Nanoseconds from epoch   │
│  tid (uint64_t)          │ Thread ID                │
│  len (uint32_t)          │ Total event length       │
│  type (uint16_t)         │ Event type (PPME_*)      │
│  nparams (uint32_t)      │ Parameter count          │
├─────────────────────────────────────────────────────┤
│                   Lengths Array                      │
│  param_len[0] (uint16_t) │ Length of param 0        │
│  param_len[1] (uint16_t) │ Length of param 1        │
│  ...                     │ ...                      │
├─────────────────────────────────────────────────────┤
│                     Payload                          │
│  param_data[0]           │ Parameter 0 data         │
│  param_data[1]           │ Parameter 1 data         │
│  ...                     │ ...                      │
└─────────────────────────────────────────────────────┘
```

### Event Types

Events are identified by `ppm_event_type` enum values with `PPME_` prefix. Each syscall typically generates two events:

- **Entry event** (`_E` suffix): Captured at syscall entry, contains input parameters
- **Exit event** (`_X` suffix): Captured at syscall exit, contains return value and resolved parameters

### Event Drop Flags

```c
UF_NONE        = 0,          // Apply sampling ratio
UF_USED        = (1 << 0),  // Syscall is implemented/used
UF_NEVER_DROP  = (1 << 1),  // Critical event, never sample/drop
UF_ALWAYS_DROP = (1 << 2),  // Low-value event, always drop under pressure
```

**Source:** [`digests/falcosecurity/libs/kernel-instrumentation.md`](../digests/falcosecurity/libs/kernel-instrumentation.md)

## Hook Points

### Syscall Instrumentation

Both drivers instrument syscalls via raw tracepoints:

- **Entry:** `raw_syscalls/sys_enter` — captures input parameters for TOCTOU mitigation
- **Exit:** `raw_syscalls/sys_exit` — captures return values and resolved parameters

### Monitored Syscalls (~280)

#### File I/O

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| `open` | `PPME_SYSCALL_OPEN_E` | `PPME_SYSCALL_OPEN_X` |
| `openat` | `PPME_SYSCALL_OPENAT_2_E` | `PPME_SYSCALL_OPENAT_2_X` |
| `openat2` | `PPME_SYSCALL_OPENAT2_E` | `PPME_SYSCALL_OPENAT2_X` |
| `creat` | `PPME_SYSCALL_CREAT_E` | `PPME_SYSCALL_CREAT_X` |
| `read` | `PPME_SYSCALL_READ_E` | `PPME_SYSCALL_READ_X` |
| `write` | `PPME_SYSCALL_WRITE_E` | `PPME_SYSCALL_WRITE_X` |
| `close` | `PPME_SYSCALL_CLOSE_E` | `PPME_SYSCALL_CLOSE_X` |

#### Process Management

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| `execve` | `PPME_SYSCALL_EXECVE_19_E` | `PPME_SYSCALL_EXECVE_19_X` |
| `execveat` | `PPME_SYSCALL_EXECVEAT_E` | `PPME_SYSCALL_EXECVEAT_X` |
| `clone` | `PPME_SYSCALL_CLONE_20_E` | `PPME_SYSCALL_CLONE_20_X` |
| `clone3` | `PPME_SYSCALL_CLONE3_E` | `PPME_SYSCALL_CLONE3_X` |
| `fork` | `PPME_SYSCALL_FORK_20_E` | `PPME_SYSCALL_FORK_20_X` |
| `vfork` | `PPME_SYSCALL_VFORK_20_E` | `PPME_SYSCALL_VFORK_20_X` |
| `exit`/`exit_group` | — | `PPME_PROCEXIT_1_E` |
| `kill` | `PPME_SYSCALL_KILL_E` | `PPME_SYSCALL_KILL_X` |
| `ptrace` | `PPME_SYSCALL_PTRACE_E` | `PPME_SYSCALL_PTRACE_X` |

#### Networking

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| `socket` | `PPME_SOCKET_SOCKET_E` | `PPME_SOCKET_SOCKET_X` |
| `bind` | `PPME_SOCKET_BIND_E` | `PPME_SOCKET_BIND_X` |
| `connect` | `PPME_SOCKET_CONNECT_E` | `PPME_SOCKET_CONNECT_X` |
| `listen` | `PPME_SOCKET_LISTEN_E` | `PPME_SOCKET_LISTEN_X` |
| `accept` | `PPME_SOCKET_ACCEPT_5_E` | `PPME_SOCKET_ACCEPT_5_X` |
| `accept4` | `PPME_SOCKET_ACCEPT4_6_E` | `PPME_SOCKET_ACCEPT4_6_X` |
| `sendto` | `PPME_SOCKET_SENDTO_E` | `PPME_SOCKET_SENDTO_X` |
| `recvfrom` | `PPME_SOCKET_RECVFROM_E` | `PPME_SOCKET_RECVFROM_X` |

#### File Management

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| `unlink` | `PPME_SYSCALL_UNLINK_2_E` | `PPME_SYSCALL_UNLINK_2_X` |
| `unlinkat` | `PPME_SYSCALL_UNLINKAT_2_E` | `PPME_SYSCALL_UNLINKAT_2_X` |
| `link` | `PPME_SYSCALL_LINK_2_E` | `PPME_SYSCALL_LINK_2_X` |
| `linkat` | `PPME_SYSCALL_LINKAT_2_E` | `PPME_SYSCALL_LINKAT_2_X` |
| `mkdir` | `PPME_SYSCALL_MKDIR_2_E` | `PPME_SYSCALL_MKDIR_2_X` |
| `rename` | `PPME_SYSCALL_RENAME_E` | `PPME_SYSCALL_RENAME_X` |
| `renameat` | `PPME_SYSCALL_RENAMEAT_E` | `PPME_SYSCALL_RENAMEAT_X` |
| `chmod` | `PPME_SYSCALL_CHMOD_E` | `PPME_SYSCALL_CHMOD_X` |

#### Memory Management

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| `mmap` | `PPME_SYSCALL_MMAP_E` | `PPME_SYSCALL_MMAP_X` |
| `mprotect` | `PPME_SYSCALL_MPROTECT_E` | `PPME_SYSCALL_MPROTECT_X` |
| `brk` | `PPME_SYSCALL_BRK_4_E` | `PPME_SYSCALL_BRK_4_X` |

#### Container/Namespace

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| `setns` | `PPME_SYSCALL_SETNS_E` | `PPME_SYSCALL_SETNS_X` |
| `unshare` | `PPME_SYSCALL_UNSHARE_E` | `PPME_SYSCALL_UNSHARE_X` |
| `chroot` | `PPME_SYSCALL_CHROOT_E` | `PPME_SYSCALL_CHROOT_X` |
| `mount` | `PPME_SYSCALL_MOUNT_E` | `PPME_SYSCALL_MOUNT_X` |

### Non-Syscall Events (Kernel Tracepoints)

| Tracepoint | Event Type | Description |
|------------|------------|-------------|
| `sched_process_fork` | `PPME_SYSCALL_CLONE_20_X` | Process fork |
| `sched_process_exec` | `PPME_SYSCALL_EXECVE_19_X` | Process execution |
| `sched_process_exit` | `PPME_PROCEXIT_1_E` | Process exit |
| `sched_switch` | `PPME_SCHEDSWITCH_6_E` | Context switch |
| `signal_deliver` | `PPME_SIGNALDELIVER_E` | Signal delivery |
| `page_fault_kernel` | `PPME_PAGE_FAULT_E` | Kernel page fault |
| `page_fault_user` | `PPME_PAGE_FAULT_E` | User page fault |

**Source:** [`refs/falcosecurity/libs/driver/ppm_events_public.h`](../refs/falcosecurity/libs/driver/ppm_events_public.h), [`refs/falcosecurity/libs/driver/syscall_table64.c`](../refs/falcosecurity/libs/driver/syscall_table64.c)

## Modern eBPF Driver (Default)

The modern eBPF driver is the default since Falco 0.35. It uses CO-RE (Compile Once, Run Everywhere) technology for portable, efficient syscall capture without requiring kernel headers at runtime.

**Requirements:** Linux kernel >= 5.8 with BTF support

### CO-RE (Compile Once, Run Everywhere)

CO-RE enables a single compiled BPF binary to run on different kernel versions:

1. **Compile Time:** BPF programs are compiled with `vmlinux.h` containing type definitions
2. **Load Time:** libbpf uses BTF to relocate struct field accesses for the running kernel
3. **Runtime:** Programs access correct field offsets automatically

```c
// CO-RE field access — libbpf relocates at load time
struct task_struct *task = (void *)bpf_get_current_task();
pid_t pid = BPF_CORE_READ(task, pid);
```

Architecture-specific `vmlinux.h` files are provided for: `x86_64`, `aarch64`, `s390x`, `ppc64le`.

**Source:** [`refs/falcosecurity/libs/driver/modern_bpf/definitions/`](../refs/falcosecurity/libs/driver/modern_bpf/definitions/)

### BPF Program Types

| Type | Attachment | Purpose |
|------|------------|---------|
| `tp_btf` | Kernel raw tracepoints | Main syscall/event capture with BTF access |
| `kprobe` | Function entry | 32-bit compat syscall TOCTOU mitigation |
| Tail-called | `BPF_MAP_TYPE_PROG_ARRAY` | Per-syscall event handlers |

### Dispatcher Pattern

The main dispatcher uses tail calls for efficient per-syscall dispatch:

```
                   ┌────────────────────────────────┐
Syscall Exit  ───→ │  sys_exit dispatcher           │
                   │  SEC("tp_btf/sys_exit")        │
                   └────────────┬───────────────────┘
                                │
                   ┌────────────▼───────────────────┐
                   │  1. Extract syscall ID          │
                   │  2. Check interesting_syscalls  │
                   │  3. Apply sampling              │
                   └────────────┬───────────────────┘
                                │ bpf_tail_call()
                                │
        ┌───────────┬───────────┼───────────┬───────────┐
        ▼           ▼           ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
   │  open   │ │  read   │ │  write  │ │  exec   │ │   ...   │
   │ handler │ │ handler │ │ handler │ │ handler │ │         │
   └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

**Source:** [`refs/falcosecurity/libs/driver/modern_bpf/programs/attached/dispatchers/syscall_exit.bpf.c`](../refs/falcosecurity/libs/driver/modern_bpf/programs/attached/dispatchers/syscall_exit.bpf.c)

### BPF Maps

```c
// maps/maps.h

// Syscall handler dispatch table
struct { __uint(type, BPF_MAP_TYPE_PROG_ARRAY); } syscall_exit_tail_table;

// Extra tail table for complex syscalls needing multiple programs
struct { __uint(type, BPF_MAP_TYPE_PROG_ARRAY); } syscall_exit_extra_tail_table;

// Per-CPU ring buffers for event delivery
struct { __uint(type, BPF_MAP_TYPE_ARRAY_OF_MAPS); } ringbuf_maps;

// Per-CPU auxiliary maps for event staging
struct { __uint(type, BPF_MAP_TYPE_ARRAY); } auxiliary_maps;

// Per-CPU event counters (totals, drops by category)
struct { __uint(type, BPF_MAP_TYPE_ARRAY); } counter_maps;

// Syscall interest filtering bitmask
struct { __uint(type, BPF_MAP_TYPE_ARRAY); } interesting_syscalls_table_64bit;

// Global capture settings (snaplen, sampling, etc.)
struct { __uint(type, BPF_MAP_TYPE_ARRAY); } capture_settings;
```

**Source:** [`refs/falcosecurity/libs/driver/modern_bpf/maps/maps.h`](../refs/falcosecurity/libs/driver/modern_bpf/maps/maps.h)

### Event Building

#### Variable-Size Events (most common)

Events with dynamic-length parameters (strings, buffers) use the auxiliary map for staging:

```c
// Get auxiliary map for this CPU
struct auxiliary_map *auxmap = auxmap__get();

// Write event header
auxmap__preload_event_header(auxmap, PPME_SYSCALL_PTRACE_X);

// Store parameters
auxmap__store_s64_param(auxmap, ret);
auxmap__store_u16_param(auxmap, request_type);
auxmap__store_charbuf_param(auxmap, filename_ptr, len, USER);

// Finalize and submit to ring buffer
auxmap__finalize_event_header(auxmap);
auxmap__submit_event(auxmap);
```

#### Fixed-Size Events

Events with known parameter sizes write directly to the ring buffer:

```c
ringbuf__store_event_header(&ringbuf_ctx);
ringbuf__store_u64(&ringbuf_ctx, value);
ringbuf__store_s64(&ringbuf_ctx, signed_value);
ringbuf__submit_event(&ringbuf_ctx);
```

**Source:** [`refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/variable_size_event.h`](../refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/variable_size_event.h), [`refs/falcosecurity/libs/driver/modern_bpf/helpers/store/ringbuf_store_params.h`](../refs/falcosecurity/libs/driver/modern_bpf/helpers/store/ringbuf_store_params.h)

### Ring Buffer Operations

```c
// Reserve space in ring buffer
uint8_t *space = bpf_ringbuf_reserve(rb, event_size, 0);
if (!space) return;  // Buffer full → event dropped

// Copy event data
memcpy(space, event_header, sizeof(header));
memcpy(space + header_size, params, params_size);

// Submit to userspace
bpf_ringbuf_submit(space, BPF_RB_NO_WAKEUP);
```

### Syscall Argument Extraction (x86_64)

```c
// Register mapping for syscall arguments on x86_64
arg0 = extract__syscall_argument(regs, 0);  // %rdi
arg1 = extract__syscall_argument(regs, 1);  // %rsi
arg2 = extract__syscall_argument(regs, 2);  // %rdx
arg3 = extract__syscall_argument(regs, 3);  // %r10
arg4 = extract__syscall_argument(regs, 4);  // %r8
arg5 = extract__syscall_argument(regs, 5);  // %r9
```

**Source:** [`refs/falcosecurity/libs/driver/modern_bpf/helpers/extract/extract_from_kernel.h`](../refs/falcosecurity/libs/driver/modern_bpf/helpers/extract/extract_from_kernel.h)

### Capture Settings

```c
struct capture_settings {
    uint64_t boot_time;           // System boot time
    uint32_t snaplen;             // Max capture length per event
    bool dropping_mode;           // Dropping/sampling mode active
    uint32_t sampling_ratio;      // Sampling configuration
    bool drop_failed;             // Drop failed syscalls (exit events)
    bool do_dynamic_snaplen;      // Enable dynamic snaplen
    uint16_t fullcapture_port_range_start;
    uint16_t fullcapture_port_range_end;
    uint16_t statsd_port;
    int32_t scap_tid;             // TID of the scap process
};
```

### Opening Modern eBPF from libsinsp

```cpp
sinsp inspector;
inspector.open_modern_bpf(
    8 * 1024 * 1024,    // driver_buffer_bytes_dim (8MB per buffer)
    1,                   // cpus_for_each_buffer (1 = one buffer per CPU)
    true,                // online_only (only allocate for online CPUs)
    interesting_syscalls // set of syscalls to capture
);
```

**Source:** [`digests/falcosecurity/libs/modern-bpf.md`](../digests/falcosecurity/libs/modern-bpf.md)

## Kernel Module (kmod)

The kernel module provides maximum compatibility but requires kernel headers for compilation.

### Filler System

The kernel module uses "filler" functions — one per event type — to extract parameters:

```c
// Maps event type to filler function
const struct ppm_event_entry g_ppm_events[PPM_EVENT_MAX] = {
    [PPME_SYSCALL_OPEN_E] = {
        .filler_callback = f_sys_open_e,
        .flags = 0,
    },
    [PPME_SYSCALL_OPEN_X] = {
        .filler_callback = f_sys_open_x,
        .flags = UF_NEVER_DROP,
    },
    // ... 280+ entries
};
```

### Filler Implementation Example

```c
// From ppm_fillers.c
int f_sys_open_x(struct event_filler_arguments *args) {
    int64_t retval = (int64_t)syscall_get_return_value(current, args->regs);
    res = val_to_ring(args, retval, 0, false, 0);

    char *name = (char *)syscall_get_argument(current, args->regs, 0);
    res = val_to_ring(args, (uint64_t)name, 0, true, PPM_STRNCPY_STR);

    uint32_t flags = (uint32_t)syscall_get_argument(current, args->regs, 1);
    res = val_to_ring(args, open_flags_to_scap(flags), 0, false, 0);

    uint32_t mode = (uint32_t)syscall_get_argument(current, args->regs, 2);
    res = val_to_ring(args, mode, 0, false, 0);
    return res;
}
```

**Source:** [`refs/falcosecurity/libs/driver/ppm_fillers.c`](../refs/falcosecurity/libs/driver/ppm_fillers.c), [`refs/falcosecurity/libs/driver/ppm_fillers.h`](../refs/falcosecurity/libs/driver/ppm_fillers.h)

### kmod vs Modern eBPF Buffer Types

| Aspect | kmod | Modern eBPF |
|--------|------|-------------|
| Buffer type | Perf buffer (per-CPU) | Ring buffer (`BPF_MAP_TYPE_RINGBUF`) |
| Event delivery | `copy_to_user` | Memory-mapped, zero-copy |
| Buffer sizing | Fixed at open time | Fixed at open time |
| Drop detection | Counter in shared page | Counter in `counter_maps` |

## TOCTOU Mitigation

For file I/O syscalls, both entry and exit tracepoints are captured to prevent Time-of-Check-Time-of-Use race conditions:

```
┌──────────────────┐       ┌──────────────────┐
│   sys_enter      │       │   sys_exit       │
│   (openat)       │──────▶│   (openat)       │
│                  │       │                  │
│ Capture:         │       │ Capture:         │
│ - filename       │       │ - return value   │
│ - flags          │       │ - resolved fd    │
│ - mode           │       │                  │
└──────────────────┘       └──────────────────┘
```

This ensures the filename captured at entry matches the actual file opened, preventing attackers from swapping the file between check and use.

**Source:** [`refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/toctou_mitigation.h`](../refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/toctou_mitigation.h)

## Event Loss Handling

### Drop Counters

```c
struct counter_map {
    uint64_t n_evts;                          // Total events seen
    uint64_t n_drops_buffer;                  // Drops due to full ringbuf
    // Category-specific buffer drops (not all syscalls are categorized)
    uint64_t n_drops_buffer_clone_fork_exit;
    uint64_t n_drops_buffer_execve_exit;
    uint64_t n_drops_buffer_connect_enter;
    uint64_t n_drops_buffer_connect_exit;
    uint64_t n_drops_buffer_open_enter;
    uint64_t n_drops_buffer_open_exit;
    uint64_t n_drops_buffer_dir_file_exit;
    uint64_t n_drops_buffer_other_interest_exit;
    uint64_t n_drops_buffer_close_exit;
    uint64_t n_drops_buffer_proc_exit;
    uint64_t n_drops_max_event_size;          // Drops due to excessive event size (>64KB)
};
```

Drop counters are per-CPU and aggregated by libscap when reading statistics.

**Source:** [`digests/falcosecurity/libs/kernel-instrumentation.md`](../digests/falcosecurity/libs/kernel-instrumentation.md)

## Architecture Support

| Architecture | Modern eBPF | Kernel Module |
|--------------|-------------|---------------|
| x86_64 | Yes | Yes |
| aarch64 (ARM64) | Yes | Yes |
| s390x | Yes | Yes |
| ppc64le | Yes | Yes |

**Source:** [`digests/falcosecurity/libs/modern-bpf.md`](../digests/falcosecurity/libs/modern-bpf.md)

## Driver Comparison

| Aspect | Modern eBPF | Kernel Module |
|--------|-------------|---------------|
| Kernel version | >= 5.8 | >= 3.10 |
| Headers required | No (CO-RE) | Yes (for compilation) |
| Buffer type | Ring buffer | Perf buffer |
| Dispatch | Tail calls | Direct function calls |
| Overhead | Lower | Higher |
| Portability | Excellent (BTF) | Requires recompilation |
| Safety | BPF verifier | Kernel module risks |
| Default | Yes (since 0.35) | No |

## Build Process

### Modern eBPF Build

```bash
cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_LIBSCAP_MODERN_BPF=ON ..
make ProbeSkeleton  # Compiles BPF programs into skeleton header
make scap           # Builds libscap with embedded skeleton
```

**Output:** `skel_dir/bpf_probe.skel.h` — skeleton header embedded into libscap.

### Kernel Module Build

Requires kernel headers for the target kernel version. The module is built separately and loaded at runtime.

**Source:** [`digests/falcosecurity/libs/modern-bpf.md`](../digests/falcosecurity/libs/modern-bpf.md)

## Removed Features

| Feature | Status | Notes |
|---------|--------|-------|
| Legacy eBPF (`driver/bpf/`, `BUILD_BPF`) | **Removed in libs 0.25 / Falco 0.44** ([PR #3796](https://github.com/falcosecurity/falco/pull/3796)) | The `driver/bpf/` directory and the `BUILD_BPF` CMake option were deleted. Only the modern eBPF probe (`driver/modern_bpf/`) remains. Use modern eBPF instead. |

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`architecture-overview.md`](architecture-overview.md) | System-level context for the driver layer |
| [`libscap.md`](libscap.md) | Userspace consumer of driver events |
| [`build-system.md`](build-system.md) | Driver build configuration |

## Sources

| Topic | Source File |
|-------|-------------|
| Event types | [`refs/falcosecurity/libs/driver/ppm_events_public.h`](../refs/falcosecurity/libs/driver/ppm_events_public.h) |
| Syscall table | [`refs/falcosecurity/libs/driver/syscall_table64.c`](../refs/falcosecurity/libs/driver/syscall_table64.c) |
| Main dispatcher | [`refs/falcosecurity/libs/driver/modern_bpf/programs/attached/dispatchers/syscall_exit.bpf.c`](../refs/falcosecurity/libs/driver/modern_bpf/programs/attached/dispatchers/syscall_exit.bpf.c) |
| BPF maps | [`refs/falcosecurity/libs/driver/modern_bpf/maps/maps.h`](../refs/falcosecurity/libs/driver/modern_bpf/maps/maps.h) |
| Ring buffer helpers | [`refs/falcosecurity/libs/driver/modern_bpf/helpers/store/ringbuf_store_params.h`](../refs/falcosecurity/libs/driver/modern_bpf/helpers/store/ringbuf_store_params.h) |
| Event building | [`refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/variable_size_event.h`](../refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/variable_size_event.h) |
| Kernel extraction | [`refs/falcosecurity/libs/driver/modern_bpf/helpers/extract/extract_from_kernel.h`](../refs/falcosecurity/libs/driver/modern_bpf/helpers/extract/extract_from_kernel.h) |
| Kmod fillers | [`refs/falcosecurity/libs/driver/ppm_fillers.c`](../refs/falcosecurity/libs/driver/ppm_fillers.c) |
| Kmod fillers header | [`refs/falcosecurity/libs/driver/ppm_fillers.h`](../refs/falcosecurity/libs/driver/ppm_fillers.h) |
| TOCTOU mitigation | [`refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/toctou_mitigation.h`](../refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/toctou_mitigation.h) |
| Kernel instrumentation digest | [`digests/falcosecurity/libs/kernel-instrumentation.md`](../digests/falcosecurity/libs/kernel-instrumentation.md) |
| Modern eBPF digest | [`digests/falcosecurity/libs/modern-bpf.md`](../digests/falcosecurity/libs/modern-bpf.md) |
