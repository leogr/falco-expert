# Modern eBPF Driver

## Overview

The modern eBPF driver is the **DEFAULT** driver since Falco 0.35, and the sole eBPF driver as of libs 0.25 / Falco 0.44 (the legacy eBPF probe at `driver/bpf/` was removed). It uses CO-RE (Compile Once, Run Everywhere) technology to provide portable, efficient syscall capture without requiring kernel headers at runtime.

**Location:** `driver/modern_bpf/`
**Requirements:** Linux kernel >= 5.8 with BTF support
**API Version:** 8.0.4 | **Schema Version:** 4.1.0

## Key Features

| Feature | Description |
|---------|-------------|
| **CO-RE** | Compile once, run on any BTF-enabled kernel |
| **Ring Buffers** | Efficient BPF_MAP_TYPE_RINGBUF for event delivery |
| **Tail Calls** | Modular syscall handling via BPF_MAP_TYPE_PROG_ARRAY |
| **Per-CPU Auxiliary Maps** | Temporary event staging before ring buffer push |
| **No Kernel Headers** | BTF provides type information at runtime |

## Architecture

### Directory Structure

```
driver/modern_bpf/
├── definitions/
│   ├── vmlinux.h              # Generated kernel type definitions
│   ├── struct_flavors.h       # Kernel version compatibility structs
│   ├── events_dimensions.h    # Event size constants
│   └── missing_definitions.h  # Missing kernel definitions
├── helpers/
│   ├── base/
│   │   ├── common.h           # Common macros and utilities
│   │   ├── maps_getters.h     # Map access helpers
│   │   ├── push_data.h        # Data pushing utilities
│   │   ├── read_from_task.h   # Task struct readers
│   │   └── stats.h            # Statistics helpers
│   ├── extract/
│   │   └── extract_from_kernel.h  # Kernel data extraction
│   ├── interfaces/
│   │   ├── fixed_size_event.h     # Fixed-size event building
│   │   ├── variable_size_event.h  # Variable-size event building
│   │   ├── syscalls_dispatcher.h  # Syscall dispatch logic
│   │   └── toctou_mitigation.h    # TOCTOU attack prevention
│   └── store/
│       ├── auxmap_store_params.h  # Auxiliary map storage
│       └── ringbuf_store_params.h # Ring buffer storage
├── maps/
│   └── maps.h                 # BPF map definitions
├── programs/
│   ├── attached/              # Programs attached to tracepoints
│   │   ├── dispatchers/       # Syscall dispatchers
│   │   └── events/            # Non-syscall events
│   └── tail_called/           # Tail-called syscall handlers
│       ├── events/            # Event-specific handlers
│       └── syscalls/          # Syscall-specific handlers
└── shared_definitions/
    └── struct_definitions.h   # Shared struct definitions
```

### BPF Maps

The modern eBPF driver uses several BPF maps defined in `maps/maps.h`:

#### Read-Only Global Variables

```c
// Event parameter count lookup
const volatile uint8_t g_event_params_table[PPM_EVENT_MAX];

// Syscall ID to PPM_SC_CODE mapping
const volatile uint16_t g_ppm_sc_table[SYSCALL_TABLE_SIZE];

// API and schema versions
const volatile uint64_t probe_api_ver = PPM_API_CURRENT_VERSION;
const volatile uint64_t probe_schema_var = PPM_SCHEMA_CURRENT_VERSION;

// Sampling/dropping configuration
const volatile uint8_t g_64bit_sampling_syscall_table[SYSCALL_TABLE_SIZE];

// IA32 to x64 syscall mapping (for 32-bit compat)
const volatile uint32_t g_ia32_to_64_table[SYSCALL_TABLE_SIZE];
```

#### Program Arrays (Tail Calls)

```c
// Main syscall exit dispatcher
struct {
    __uint(type, BPF_MAP_TYPE_PROG_ARRAY);
    __uint(max_entries, SYSCALL_TABLE_SIZE);
    __type(key, uint32_t);
    __type(value, uint32_t);
} syscall_exit_tail_table;

// Extra tail table for complex syscalls
struct {
    __uint(type, BPF_MAP_TYPE_PROG_ARRAY);
    __uint(max_entries, SYS_EXIT_EXTRA_CODE_MAX);
    __type(key, uint32_t);
    __type(value, uint32_t);
} syscall_exit_extra_tail_table;
```

#### Data Maps

```c
// Per-CPU auxiliary maps for event staging
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __type(key, uint32_t);
    __type(value, struct auxiliary_map);
} auxiliary_maps;

// Per-CPU event counters
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __type(key, uint32_t);
    __type(value, struct counter_map);
} counter_maps;

// Syscall interest filtering
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, SYSCALL_TABLE_SIZE);
    __type(key, uint32_t);
    __type(value, bool);
} interesting_syscalls_table_64bit;

// Global capture settings
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, uint32_t);
    __type(value, struct capture_settings);
} capture_settings;
```

#### Ring Buffers

```c
// Ring buffer type definition
struct ringbuf_map {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
};

// Array of ring buffers (configurable number)
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY_OF_MAPS);
    __type(key, uint32_t);
    __type(value, uint32_t);
    __array(values, struct ringbuf_map);
} ringbuf_maps;
```

## Event Processing Flow

### Syscall Capture Flow

```
1. SYSCALL ENTRY/EXIT
   └─ Tracepoint triggered (raw_syscalls/sys_enter or sys_exit)

2. DISPATCHER PROGRAM (attached/dispatchers/)
   ├─ Check if syscall is interesting
   ├─ Lookup tail call table
   └─ Tail call to specific handler

3. SYSCALL HANDLER (tail_called/syscalls/)
   ├─ Get auxiliary map for this CPU
   ├─ Build event header
   ├─ Extract parameters from kernel
   └─ Push to ring buffer

4. USERSPACE (libscap)
   └─ Poll ring buffer, retrieve events
```

### Event Building API

#### Fixed-Size Events

For events with known parameter sizes:

```c
// Initialize fixed-size event
ringbuf__store_event_header(&ringbuf_ctx);

// Store parameters
ringbuf__store_u64(&ringbuf_ctx, value);
ringbuf__store_s64(&ringbuf_ctx, signed_value);
// ... more parameters

// Submit event
ringbuf__submit_event(&ringbuf_ctx);
```

#### Variable-Size Events

For events with dynamic-length parameters (strings, buffers):

```c
// Use auxiliary map for staging
auxmap__store_event_header(auxmap);

// Store fixed parameters
auxmap__store_u64_param(auxmap, value);

// Store variable-length data
auxmap__store_charbuf_param(auxmap, ptr, len, USER);
auxmap__store_bytebuf_param(auxmap, ptr, len, USER);

// Submit from auxiliary map to ring buffer
auxmap__finalize_event_header(auxmap);
auxmap__submit_event(auxmap, ctx);
```

## CO-RE and BTF

### How CO-RE Works

1. **Compile Time:** BPF programs are compiled with `vmlinux.h` containing type definitions
2. **Load Time:** libbpf uses BTF to relocate struct field accesses
3. **Runtime:** Programs access correct field offsets for the running kernel

### vmlinux.h Generation

The `vmlinux.h` file is generated from kernel BTF:

```bash
bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h
```

Architecture-specific versions exist in:
- `definitions/x86_64/vmlinux.h`
- `definitions/aarch64/vmlinux.h`
- `definitions/s390x/vmlinux.h`
- `definitions/ppc64le/vmlinux.h`

### struct_flavors.h

Handles kernel version differences:

```c
// Different struct layouts across kernel versions
struct trace_event_raw_sys_enter___v58 { /* 5.8+ layout */ };
struct trace_event_raw_sys_enter___v414 { /* 4.14+ layout */ };
```

## Syscall Coverage

The modern eBPF driver supports ~170 syscall handlers in `programs/tail_called/syscalls/`:

### Process Management
- `clone`, `clone3`, `fork`, `vfork`
- `execve`, `execveat`
- `exit`, `exit_group`
- `setuid`, `setgid`, `setreuid`, `setregid`

### File Operations
- `open`, `openat`, `openat2`, `creat`
- `close`, `close_range`
- `read`, `readv`, `pread64`, `preadv`, `preadv2`
- `write`, `writev`, `pwrite64`, `pwritev`, `pwritev2`
- `lseek`, `llseek`
- `dup`, `dup2`, `dup3`
- `fcntl`

### Networking
- `socket`, `socketpair`
- `bind`, `listen`, `accept`, `accept4`
- `connect`
- `send`, `sendto`, `sendmsg`, `sendmmsg`
- `recv`, `recvfrom`, `recvmsg`, `recvmmsg`
- `shutdown`
- `getsockopt`, `setsockopt`

### Memory Management
- `mmap`, `mmap2`, `munmap`
- `mprotect`
- `brk`
- `mlock`, `mlock2`, `mlockall`, `munlock`, `munlockall`

### IPC
- `pipe`, `pipe2`
- `eventfd`, `eventfd2`
- `signalfd`, `signalfd4`
- `timerfd_create`

### Container/Namespace
- `setns`, `unshare`
- `chroot`
- `mount`, `umount`, `umount2`

## Configuration

### Ring Buffer Configuration

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

## Build Process

### Prerequisites

- clang >= 12
- bpftool with `gen object` and `gen skeleton` support
- BTF-enabled kernel for testing

### Build Steps

```bash
mkdir build && cd build

# Configure with modern eBPF enabled
cmake -DUSE_BUNDLED_DEPS=ON \
      -DBUILD_LIBSCAP_MODERN_BPF=ON \
      ..

# Build the skeleton (compiles BPF programs)
make ProbeSkeleton

# Output: skel_dir/bpf_probe.skel.h

# Build libscap (includes skeleton)
make scap
```

### Build Output

The build process creates:
1. Individual `.o` files for each BPF program
2. Combined skeleton header: `skel_dir/bpf_probe.skel.h`
3. Skeleton is embedded into libscap

## Debugging

### Enable Debug Mode

```bash
cmake -DMODERN_BPF_DEBUG_MODE=ON ..
```

### View BPF Logs

```bash
# Read kernel trace buffer
sudo cat /sys/kernel/debug/tracing/trace_pipe
```

### Verify BPF Programs

```bash
# List loaded BPF programs
sudo bpftool prog list

# Show program details
sudo bpftool prog show id <ID>

# Dump program instructions
sudo bpftool prog dump xlated id <ID>
```

## Performance Considerations

### Ring Buffer Sizing

- Default: 8MB per buffer
- Increase for high-throughput systems
- Monitor drops via `counter_maps`

### CPU Binding

- `cpus_for_each_buffer=1`: One ring buffer per CPU (best performance)
- Higher values: Fewer buffers, shared across CPUs (less memory)

### Syscall Filtering

Filter uninteresting syscalls to reduce overhead:

```cpp
libsinsp::events::set<ppm_sc_code> interesting;
interesting.insert(PPM_SC_EXECVE);
interesting.insert(PPM_SC_OPEN);
// ... add required syscalls

inspector.open_modern_bpf(buffer_size, 1, true, interesting);
```

## Sources

| Topic | Source File |
|-------|-------------|
| BPF maps | [`driver/modern_bpf/maps/maps.h`](../../../refs/falcosecurity/libs/driver/modern_bpf/maps/maps.h) |
| Syscall dispatcher | [`driver/modern_bpf/programs/attached/dispatchers/syscall_exit.bpf.c`](../../../refs/falcosecurity/libs/driver/modern_bpf/programs/attached/dispatchers/syscall_exit.bpf.c) |
| Ring buffer helpers | [`driver/modern_bpf/helpers/store/ringbuf_store_params.h`](../../../refs/falcosecurity/libs/driver/modern_bpf/helpers/store/ringbuf_store_params.h) |
| Event building | [`driver/modern_bpf/helpers/interfaces/variable_size_event.h`](../../../refs/falcosecurity/libs/driver/modern_bpf/helpers/interfaces/variable_size_event.h) |
| Syscall argument extraction | [`driver/modern_bpf/helpers/extract/extract_from_kernel.h`](../../../refs/falcosecurity/libs/driver/modern_bpf/helpers/extract/extract_from_kernel.h) |
| Probe manager (libpman) | [`userspace/libpman/`](../../../refs/falcosecurity/libs/userspace/libpman/) |

## Related Digests

- [architecture.md](architecture.md) - Overall system architecture
- [libscap.md](libscap.md) - libscap interface to modern eBPF
- [api-reference.md](api-reference.md) - Event types and flags
