# Kernel Instrumentation
> **Era:** 0.44 | **Version:** libs 0.25.4 | **Source:** [`refs/falcosecurity/libs/`](../../../refs/falcosecurity/libs/)

## Overview

Falco captures system events by instrumenting the Linux kernel at syscall and tracepoint boundaries. Two driver implementations are available:

- **Modern eBPF** (default) - CO-RE enabled, requires kernel 5.8+
- **Kernel Module (kmod)** - Broader compatibility, traditional kernel module

**Location:** [`driver/`](../../../refs/falcosecurity/libs/driver/) (kmod), [`driver/modern_bpf/`](../../../refs/falcosecurity/libs/driver/modern_bpf/) (modern eBPF)

## Hook Points

### Syscall Instrumentation (~280 syscalls)

Both drivers instrument syscalls via raw tracepoints:
- **Entry:** `raw_syscalls/sys_enter` (for TOCTOU mitigation)
- **Exit:** `raw_syscalls/sys_exit` (main event capture)

#### File I/O Syscalls

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| open | PPME_SYSCALL_OPEN_E | PPME_SYSCALL_OPEN_X |
| openat | PPME_SYSCALL_OPENAT_2_E | PPME_SYSCALL_OPENAT_2_X |
| openat2 | PPME_SYSCALL_OPENAT2_E | PPME_SYSCALL_OPENAT2_X |
| creat | PPME_SYSCALL_CREAT_E | PPME_SYSCALL_CREAT_X |
| read | PPME_SYSCALL_READ_E | PPME_SYSCALL_READ_X |
| write | PPME_SYSCALL_WRITE_E | PPME_SYSCALL_WRITE_X |
| pread64 | PPME_SYSCALL_PREAD_E | PPME_SYSCALL_PREAD_X |
| pwrite64 | PPME_SYSCALL_PWRITE_E | PPME_SYSCALL_PWRITE_X |
| readv | PPME_SYSCALL_READV_E | PPME_SYSCALL_READV_X |
| writev | PPME_SYSCALL_WRITEV_E | PPME_SYSCALL_WRITEV_X |
| close | PPME_SYSCALL_CLOSE_E | PPME_SYSCALL_CLOSE_X |
| lseek | PPME_SYSCALL_LSEEK_E | PPME_SYSCALL_LSEEK_X |

#### Process Syscalls

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| execve | PPME_SYSCALL_EXECVE_19_E | PPME_SYSCALL_EXECVE_19_X |
| execveat | PPME_SYSCALL_EXECVEAT_E | PPME_SYSCALL_EXECVEAT_X |
| clone | PPME_SYSCALL_CLONE_20_E | PPME_SYSCALL_CLONE_20_X |
| clone3 | PPME_SYSCALL_CLONE3_E | PPME_SYSCALL_CLONE3_X |
| fork | PPME_SYSCALL_FORK_20_E | PPME_SYSCALL_FORK_20_X |
| vfork | PPME_SYSCALL_VFORK_20_E | PPME_SYSCALL_VFORK_20_X |
| exit | - | PPME_PROCEXIT_1_E |
| exit_group | - | PPME_PROCEXIT_1_E |
| kill | PPME_SYSCALL_KILL_E | PPME_SYSCALL_KILL_X |
| ptrace | PPME_SYSCALL_PTRACE_E | PPME_SYSCALL_PTRACE_X |
| prctl | PPME_SYSCALL_PRCTL_E | PPME_SYSCALL_PRCTL_X |

#### Network Syscalls

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| socket | PPME_SOCKET_SOCKET_E | PPME_SOCKET_SOCKET_X |
| bind | PPME_SOCKET_BIND_E | PPME_SOCKET_BIND_X |
| connect | PPME_SOCKET_CONNECT_E | PPME_SOCKET_CONNECT_X |
| listen | PPME_SOCKET_LISTEN_E | PPME_SOCKET_LISTEN_X |
| accept | PPME_SOCKET_ACCEPT_5_E | PPME_SOCKET_ACCEPT_5_X |
| accept4 | PPME_SOCKET_ACCEPT4_6_E | PPME_SOCKET_ACCEPT4_6_X |
| send | PPME_SOCKET_SEND_E | PPME_SOCKET_SEND_X |
| recv | PPME_SOCKET_RECV_E | PPME_SOCKET_RECV_X |
| sendto | PPME_SOCKET_SENDTO_E | PPME_SOCKET_SENDTO_X |
| recvfrom | PPME_SOCKET_RECVFROM_E | PPME_SOCKET_RECVFROM_X |
| sendmsg | PPME_SOCKET_SENDMSG_E | PPME_SOCKET_SENDMSG_X |
| recvmsg | PPME_SOCKET_RECVMSG_E | PPME_SOCKET_RECVMSG_X |
| shutdown | PPME_SOCKET_SHUTDOWN_E | PPME_SOCKET_SHUTDOWN_X |

#### File Management Syscalls

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| unlink | PPME_SYSCALL_UNLINK_2_E | PPME_SYSCALL_UNLINK_2_X |
| unlinkat | PPME_SYSCALL_UNLINKAT_2_E | PPME_SYSCALL_UNLINKAT_2_X |
| link | PPME_SYSCALL_LINK_2_E | PPME_SYSCALL_LINK_2_X |
| linkat | PPME_SYSCALL_LINKAT_2_E | PPME_SYSCALL_LINKAT_2_X |
| mkdir | PPME_SYSCALL_MKDIR_2_E | PPME_SYSCALL_MKDIR_2_X |
| rmdir | PPME_SYSCALL_RMDIR_2_E | PPME_SYSCALL_RMDIR_2_X |
| rename | PPME_SYSCALL_RENAME_E | PPME_SYSCALL_RENAME_X |
| renameat | PPME_SYSCALL_RENAMEAT_E | PPME_SYSCALL_RENAMEAT_X |
| renameat2 | PPME_SYSCALL_RENAMEAT2_E | PPME_SYSCALL_RENAMEAT2_X |
| chmod | PPME_SYSCALL_CHMOD_E | PPME_SYSCALL_CHMOD_X |
| chown | PPME_SYSCALL_CHOWN_E | PPME_SYSCALL_CHOWN_X |

#### Memory Syscalls

| Syscall | Entry Event | Exit Event |
|---------|-------------|------------|
| mmap | PPME_SYSCALL_MMAP_E | PPME_SYSCALL_MMAP_X |
| mmap2 | PPME_SYSCALL_MMAP2_E | PPME_SYSCALL_MMAP2_X |
| munmap | PPME_SYSCALL_MUNMAP_E | PPME_SYSCALL_MUNMAP_X |
| mprotect | PPME_SYSCALL_MPROTECT_E | PPME_SYSCALL_MPROTECT_X |
| brk | PPME_SYSCALL_BRK_4_E | PPME_SYSCALL_BRK_4_X |
| mlock | PPME_SYSCALL_MLOCK_E | PPME_SYSCALL_MLOCK_X |
| mlockall | PPME_SYSCALL_MLOCKALL_E | PPME_SYSCALL_MLOCKALL_X |

### Non-Syscall Events (Kernel Tracepoints)

| Tracepoint | Event Type | Description |
|------------|------------|-------------|
| `sched_process_fork` | PPME_SYSCALL_CLONE_20_X | Process fork |
| `sched_process_exec` | PPME_SYSCALL_EXECVE_19_X | Process execution |
| `sched_process_exit` | PPME_PROCEXIT_1_E | Process exit |
| `sched_switch` | PPME_SCHEDSWITCH_6_E | Context switch |
| `signal_deliver` | PPME_SIGNALDELIVER_E | Signal delivery |
| `page_fault_kernel` | PPME_PAGE_FAULT_E | Kernel page fault |
| `page_fault_user` | PPME_PAGE_FAULT_E | User page fault |

## Modern eBPF Architecture

### Program Organization

```
driver/modern_bpf/
├── programs/
│   ├── attached/                    # Entry point programs
│   │   └── dispatchers/
│   │       ├── syscall_exit.bpf.c  # Main syscall dispatcher
│   │       └── syscall_enter.bpf.c # TOCTOU mitigation
│   └── tail_called/                 # Per-syscall handlers
│       └── events/
│           └── syscall_dispatched_events/
│               ├── open.bpf.c
│               ├── read.bpf.c
│               ├── write.bpf.c
│               └── ... (280+ handlers)
├── maps/
│   └── maps.h                       # BPF map definitions
└── helpers/
    ├── interfaces/
    │   └── variable_size_event.h   # Event construction
    └── store/
        └── ringbuf_store_params.h  # Ringbuffer helpers
```

### Dispatcher Pattern

The main dispatcher (`syscall_exit.bpf.c`) uses tail calls for efficient dispatch:

```
                   ┌────────────────────────────┐
Syscall Exit  ──→  │  sys_exit dispatcher       │
                   │  SEC("tp_btf/sys_exit")    │
                   └────────────┬───────────────┘
                                │
                   ┌────────────▼───────────────┐
                   │  1. Extract syscall ID     │
                   │  2. Check if interesting   │
                   │  3. Apply sampling         │
                   └────────────┬───────────────┘
                                │
                   ┌────────────▼───────────────┐
                   │  bpf_tail_call(ctx,        │
                   │    syscall_exit_tail_table,│
                   │    syscall_id)             │
                   └────────────┬───────────────┘
                                │
        ┌───────────┬───────────┼───────────┬───────────┐
        ▼           ▼           ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
   │  open   │ │  read   │ │  write  │ │  exec   │ │   ...   │
   │ handler │ │ handler │ │ handler │ │ handler │ │         │
   └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

### BPF Program Types

| Type | Attachment | Purpose |
|------|------------|---------|
| `tp_btf` | Kernel raw tracepoints | Main syscall/event capture with BTF access |
| `kprobe` | Function entry | 32-bit compat syscall TOCTOU mitigation |
| Tail-called | `BPF_MAP_TYPE_PROG_ARRAY` | Per-syscall event handlers |
| `iter/task`, `iter/task_file` | BPF iterators | Synchronous kernel-state fetch to bootstrap/heal the process table (procfs fallback; opt-out via `engine.modern_ebpf.disable_iterators` since 0.44.1). See [modern-bpf.md](modern-bpf.md#bpf-iterators-state-synchronization) |

### Key BPF Maps

```c
// Syscall handler dispatch table
struct {
    __uint(type, BPF_MAP_TYPE_PROG_ARRAY);
    __uint(max_entries, SYSCALL_TABLE_SIZE);
    __type(key, uint32_t);
    __type(value, uint32_t);
} syscall_exit_tail_table;

// Per-CPU ring buffers
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY_OF_MAPS);
    __type(key, uint32_t);
    __array(values, struct ringbuf_map);
} ringbuf_maps;

// Interesting syscalls bitmask
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __type(key, uint32_t);
    __type(value, bool);
    __uint(max_entries, SYSCALL_TABLE_SIZE);
} interesting_syscalls_table_64bit;

// Event counters (drops, totals)
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __type(key, uint32_t);
    __type(value, struct counter_map);
} counter_maps;

// Per-CPU auxiliary buffer for event construction
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __type(key, uint32_t);
    __type(value, struct auxiliary_map);
} auxiliary_maps;
```

### Event Handler Example

```c
// From ptrace.bpf.c
SEC("tp_btf/sys_exit")
int BPF_PROG(ptrace_x, struct pt_regs *regs, long ret) {
    // Get auxiliary map for this CPU
    struct auxiliary_map *auxmap = auxmap__get();
    if (!auxmap)
        return 0;

    // Preload event header
    auxmap__preload_event_header(auxmap, PPME_SYSCALL_PTRACE_X);

    // Extract syscall arguments from registers
    unsigned long request = extract__syscall_argument(regs, 0);
    uint64_t pid = extract__syscall_argument(regs, 1);
    uint64_t addr = extract__syscall_argument(regs, 2);
    uint64_t data = extract__syscall_argument(regs, 3);

    // Store parameters
    auxmap__store_s64_param(auxmap, ret);
    auxmap__store_u16_param(auxmap, ptrace_requests_to_scap(request));
    auxmap__store_s64_param(auxmap, pid);
    // ... more parameters

    // Finalize and submit
    auxmap__finalize_event_header(auxmap);
    auxmap__submit_event(auxmap);
    return 0;
}
```

### CO-RE (Compile Once, Run Everywhere)

Modern eBPF uses CO-RE for kernel version compatibility:

- **vmlinux.h:** Auto-generated from kernel BTF (type definitions)
- **BTF-based tracepoints:** Access raw struct arguments portably
- **BPF CO-RE macros:** Version-independent field access

```c
// CO-RE field access example
struct task_struct *task = (void *)bpf_get_current_task();
pid_t pid = BPF_CORE_READ(task, pid);
```

## Kernel Module (kmod) Architecture

### Filler System

The kernel module uses "filler" functions for each syscall:

```
driver/
├── ppm_fillers.c          # Filler implementations (180+ functions)
├── ppm_fillers.h          # Filler declarations
├── syscall_table.c        # Syscall to filler mapping
└── ppm_events.c           # Event handling and string extraction
```

### Filler Table

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

### Filler Example

```c
// From ppm_fillers.c
int f_sys_open_x(struct event_filler_arguments *args) {
    int res;
    int64_t retval;
    char *name;
    uint32_t flags;
    uint32_t mode;

    // Get return value
    retval = (int64_t)syscall_get_return_value(current, args->regs);
    res = val_to_ring(args, retval, 0, false, 0);
    if (res != PPM_SUCCESS)
        return res;

    // Get filename
    name = (char *)syscall_get_argument(current, args->regs, 0);
    res = val_to_ring(args, (uint64_t)name, 0, true,
                      PPM_STRNCPY_STR);
    if (res != PPM_SUCCESS)
        return res;

    // Get flags
    flags = (uint32_t)syscall_get_argument(current, args->regs, 1);
    res = val_to_ring(args, open_flags_to_scap(flags), 0, false, 0);
    if (res != PPM_SUCCESS)
        return res;

    // Get mode
    mode = (uint32_t)syscall_get_argument(current, args->regs, 2);
    res = val_to_ring(args, mode, 0, false, 0);

    return res;
}
```

## Data Flow: Kernel to Userspace

### Event Structure

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

### Modern eBPF Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                        KERNEL SPACE                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Syscall Exit Tracepoint (tp_btf/sys_exit)                       │
│           │                                                       │
│           ▼                                                       │
│  ┌─────────────────────────────────────┐                         │
│  │       Dispatcher Program             │                         │
│  │  - Extract syscall ID from pt_regs  │                         │
│  │  - Check interesting_syscalls map   │                         │
│  │  - Apply sampling filter            │                         │
│  └──────────────┬──────────────────────┘                         │
│                 │ bpf_tail_call()                                │
│                 ▼                                                 │
│  ┌─────────────────────────────────────┐                         │
│  │       Syscall Handler Program        │                         │
│  │  - Get auxiliary_map for this CPU   │                         │
│  │  - Extract args from pt_regs        │                         │
│  │  - Build event in aux buffer        │                         │
│  └──────────────┬──────────────────────┘                         │
│                 │                                                 │
│                 ▼                                                 │
│  ┌─────────────────────────────────────┐                         │
│  │    Ring Buffer (per-CPU)            │                         │
│  │  - bpf_ringbuf_reserve()            │                         │
│  │  - Copy event from aux buffer       │                         │
│  │  - bpf_ringbuf_submit()             │                         │
│  └──────────────┬──────────────────────┘                         │
│                 │                                                 │
└─────────────────┼────────────────────────────────────────────────┘
                  │
                  │ Memory-mapped ring buffer
                  │
┌─────────────────┼────────────────────────────────────────────────┐
│                 ▼                                                 │
│  ┌─────────────────────────────────────┐       USERSPACE         │
│  │           libscap                    │                         │
│  │  - Poll ring buffers                │                         │
│  │  - Read events                      │                         │
│  │  - Track counters/drops             │                         │
│  └──────────────┬──────────────────────┘                         │
│                 │                                                 │
│                 ▼                                                 │
│  ┌─────────────────────────────────────┐                         │
│  │           libsinsp                   │                         │
│  │  - Parse event parameters           │                         │
│  │  - Update state tables              │                         │
│  │  - Apply filters                    │                         │
│  │  - Enrich events                    │                         │
│  └─────────────────────────────────────┘                         │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Syscall Argument Extraction (x86_64)

```c
// Register mapping for syscall arguments
arg0 = extract__syscall_argument(regs, 0);  // %rdi
arg1 = extract__syscall_argument(regs, 1);  // %rsi
arg2 = extract__syscall_argument(regs, 2);  // %rdx
arg3 = extract__syscall_argument(regs, 3);  // %r10
arg4 = extract__syscall_argument(regs, 4);  // %r8
arg5 = extract__syscall_argument(regs, 5);  // %r9
```

### Ring Buffer Operations

```c
// Reserve space in ring buffer
uint8_t *space = bpf_ringbuf_reserve(rb, event_size, 0);
if (!space)
    return;  // Buffer full, event dropped

// Copy event data
memcpy(space, event_header, sizeof(header));
memcpy(space + header_size, params, params_size);

// Submit to userspace
bpf_ringbuf_submit(space, BPF_RB_NO_WAKEUP);
```

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

### Sampling Configuration

```c
// Syscall sampling flags
UF_NONE        = 0,          // Apply sampling ratio
UF_USED        = (1 << 0),  // Syscall is implemented/used
UF_NEVER_DROP  = (1 << 1),  // Critical, never sample
UF_ALWAYS_DROP = (1 << 2),  // Low-value, always drop
```

## TOCTOU Mitigation

For file I/O syscalls, both entry and exit are captured to prevent race conditions:

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

This ensures the filename captured at entry matches the actual file opened.

## Comparison: Modern eBPF vs kmod

| Aspect | Modern eBPF | Kernel Module |
|--------|-------------|---------------|
| Kernel Version | >= 5.8 | >= 3.10 |
| Headers Required | No (CO-RE) | Yes (for compilation) |
| Buffer Type | Ring buffer | Perf buffer |
| Dispatch | Tail calls | Direct function calls |
| Overhead | Lower | Higher |
| Portability | Excellent (BTF) | Requires recompilation |
| Safety | BPF verifier | Kernel module risks |

## Sources

| Topic | Source File |
|-------|-------------|
| Event types | [`driver/ppm_events_public.h`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h) |
| Syscall table | [`driver/syscall_table64.c`](../../../refs/falcosecurity/libs/driver/syscall_table64.c) |
| Main dispatcher | [`driver/modern_bpf/programs/attached/dispatchers/syscall_exit.bpf.c`](../../../refs/falcosecurity/libs/driver/modern_bpf/programs/attached/dispatchers/syscall_exit.bpf.c) |
| BPF maps | [`driver/modern_bpf/maps/maps.h`](../../../refs/falcosecurity/libs/driver/modern_bpf/maps/maps.h) |
| Ring buffer helpers | [`driver/modern_bpf/helpers/store/ringbuf_store_params.h`](../../../refs/falcosecurity/libs/driver/modern_bpf/helpers/store/ringbuf_store_params.h) |
| Syscall handlers | [`driver/modern_bpf/programs/tail_called/events/syscall_dispatched_events/`](../../../refs/falcosecurity/libs/driver/modern_bpf/programs/tail_called/events/syscall_dispatched_events/) |
| Kmod fillers | [`driver/ppm_fillers.c`](../../../refs/falcosecurity/libs/driver/ppm_fillers.c) |
| Kmod fillers header | [`driver/ppm_fillers.h`](../../../refs/falcosecurity/libs/driver/ppm_fillers.h) |

## Related Digests

- [modern-bpf.md](modern-bpf.md) - Modern eBPF driver details
- [libscap.md](libscap.md) - Userspace capture library
- [api-reference.md](api-reference.md) - Event types and parameter types
- [architecture.md](architecture.md) - Overall system architecture
