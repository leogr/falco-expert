# libs Architecture
> **Era:** 0.44 | **Version:** libs 0.25.4 | **Source:** [`refs/falcosecurity/libs/`](../../../refs/falcosecurity/libs/)

## Component Overview

The libs repository is organized into kernel-space (driver) and user-space (libraries) components that work together to capture, process, and analyze system events.

```
libs/
├── driver/                    # Kernel-space drivers
│   ├── modern_bpf/           # Modern eBPF probe (DEFAULT, sole eBPF driver as of libs 0.25 / Falco 0.44)
│   └── *.c, *.h              # Kernel module + shared code (legacy eBPF probe at driver/bpf/ was removed in libs 0.25 / Falco 0.44)
├── userspace/
│   ├── libscap/              # System CAPture library
│   │   └── engine/           # Engine implementations
│   ├── libsinsp/             # System INSPection library
│   └── plugin/               # Plugin API definitions
└── proposals/                # Design proposals
```

## Event Flow

### Capture Pipeline

```
1. SYSCALL EXECUTION
   ├─ Process makes syscall (e.g., open, read, write, execve)
   └─ Kernel invokes syscall handler

2. DRIVER INTERCEPTION
   ├─ Tracepoint/kprobe triggered
   ├─ BPF program (or kmod handler) executes
   ├─ Event data extracted from kernel structures
   └─ Event pushed to ring buffer

3. LIBSCAP CONSUMPTION
   ├─ scap_next() polls ring buffer
   ├─ Raw event retrieved
   └─ Event passed to libsinsp

4. LIBSINSP PROCESSING
   ├─ Parser decodes event parameters
   ├─ State engine updates (thread table, fd table)
   ├─ Event enriched with context (process name, user, container)
   └─ Filter evaluation

5. APPLICATION (e.g., Falco)
   ├─ Rule matching against enriched event
   └─ Alert generation
```

### Event Structure

Events follow a standard binary format defined in `driver/ppm_events_public.h`:

```c
struct ppm_evt_hdr {
    uint64_t ts;        // Timestamp (nanoseconds since epoch)
    uint64_t tid;       // Thread ID
    uint32_t len;       // Total event length
    uint16_t type;      // Event type (ppm_event_type)
    uint32_t nparams;   // Number of parameters
};
// Followed by parameter data
```

## Driver Architecture

### Modern eBPF (DEFAULT since Falco 0.35)

The modern eBPF driver uses CO-RE (Compile Once, Run Everywhere) technology:

**Key Features:**
- No kernel headers required at runtime
- Uses BTF (BPF Type Format) for struct relocation
- Ring buffer for efficient event delivery
- Tail call dispatch for syscall handling

**Structure:**
```
driver/modern_bpf/
├── definitions/
│   ├── vmlinux.h              # BTF-generated kernel types
│   └── struct_flavors.h       # Kernel version compatibility
├── helpers/
│   ├── base/                  # Common helpers
│   ├── extract/               # Data extraction from kernel
│   ├── interfaces/            # Event building APIs
│   └── store/                 # Ring buffer operations
├── maps/
│   └── maps.h                 # BPF map definitions
└── programs/
    ├── attached/              # Tracepoint attachments
    └── tail_called/           # Syscall handlers
```

**BPF Maps:**
- `syscall_exit_tail_table` - Tail call dispatch table
- `auxiliary_maps` - Per-CPU event staging
- `counter_maps` - Per-CPU statistics
- `ringbuf_maps` - Ring buffers for event delivery
- `interesting_syscalls_table_64bit` - Syscall filtering

### Legacy eBPF (REMOVED)

Previously located in `driver/bpf/`. **Removed in libs 0.25 / Falco 0.44** — the path no longer exists. Modern eBPF is now the sole eBPF driver.

### Kernel Module

The kernel module (`driver/*.c`) provides maximum compatibility but requires kernel headers for compilation.

## Userspace Libraries

### libscap (System CAPture)

**Purpose:** Low-level capture interface and driver communication

**Engine Abstraction (`scap_vtable.h`):**
```c
struct scap_vtable {
    const char* name;
    void* (*alloc_handle)(scap_t* main_handle, char* lasterr_ptr);
    int32_t (*init)(scap_t* main_handle, scap_open_args* open_args);
    int32_t (*next)(struct scap_engine_handle engine,
                    scap_evt** pevent, uint16_t* pdevid, uint32_t* pflags);
    int32_t (*start_capture)(struct scap_engine_handle engine);
    int32_t (*stop_capture)(struct scap_engine_handle engine);
    int32_t (*configure)(struct scap_engine_handle engine,
                         enum scap_setting setting,
                         unsigned long arg1, unsigned long arg2);
    // ... statistics, cleanup
};
```

**Available Engines:**
| Engine | Purpose |
|--------|---------|
| `modern_bpf` | Modern eBPF probe |
| `kmod` | Kernel module |
| `savefile` | Capture file replay |
| `source_plugin` | Plugin-provided events |
| `nodriver` | No driver (proc scan only) |
| `test_input` | Testing |

> Note: `bpf` (legacy eBPF) and `gvisor` engines were removed in libs 0.25 / Falco 0.44.

### libsinsp (System INSPection)

**Purpose:** High-level event processing, state management, filtering

**Core Components:**

1. **State Engine**
   - Thread table (`sinsp_threadinfo`) - Process/thread state
   - FD table (`sinsp_fdinfo`) - File descriptor state
   - User/Group manager - Identity tracking

2. **Event Parser (`sinsp_parser`)**
   - Decodes raw events into structured data
   - Updates state tables
   - Handles syscall-specific logic

3. **Filter System**
   - Field extraction from events
   - Boolean expression evaluation
   - Falco rule compilation

**Key Classes:**
```cpp
class sinsp {
    // Main entry point
    void open_modern_bpf(...);  // Open modern eBPF
    void open_kmod(...);        // Open kernel module
    // open_bpf(...) for legacy eBPF was removed in libs 0.25 / Falco 0.44
    int32_t next(sinsp_evt** evt);  // Get next event
};

class sinsp_threadinfo {
    int64_t m_tid;              // Thread ID
    int64_t m_pid;              // Process ID
    std::string m_comm;         // Command name
    std::string m_exe;          // Executable path
    // ... extensive process state
};

class sinsp_fdinfo {
    int64_t m_fd;               // File descriptor number
    scap_fd_type m_type;        // Type (file, socket, pipe, etc.)
    std::string m_name;         // Name/path
    // ... type-specific fields
};
```

## Build System

### CMake Targets

| Target | Description |
|--------|-------------|
| `driver` | Build kernel module |
| `ProbeSkeleton` | Build modern eBPF skeleton |
| `scap` | Build libscap (includes modern eBPF if enabled) |
| `sinsp` | Build libsinsp |
| `scap-open` | Test binary for libscap |
| `sinsp-example` | Test binary for libsinsp |

> Note: The `bpf` target (legacy eBPF probe) was removed in libs 0.25 / Falco 0.44.

### Key CMake Options

| Option | Default | Description |
|--------|---------|-------------|
| `USE_BUNDLED_DEPS` | ON | Fetch and build dependencies |
| `BUILD_LIBSCAP_MODERN_BPF` | OFF | Enable modern eBPF |
| `BUILD_DRIVER` | ON | Build kernel module |
| `CREATE_TEST_TARGETS` | ON | Build test binaries |

> Note: The `BUILD_BPF` option (legacy eBPF probe) was removed in libs 0.25 / Falco 0.44.

### Build Example (Modern eBPF)

```bash
mkdir build && cd build
cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_LIBSCAP_MODERN_BPF=ON ..
make sinsp
```

## Versioning

### Version Numbers

- **Libs Version:** 0.25.4 (SemVer, major=0 indicates unstable API)
- **Driver Version:** Uses `+driver` suffix (e.g., `10.2.0+driver`)
- **API Version:** 10.1.0 (user/kernel boundary)
- **Schema Version:** 4.5.1 (event data format)
- **Plugin API Version:** 3.12.0

### Compatibility Rules

1. **API Version** changes require driver/userspace rebuild
2. **Schema Version** changes may require rule updates
3. **Plugin API** is backward compatible within major version

### Plugin Capabilities

Plugins can implement one or more capabilities (flags are OR-ed together):

| Capability | Flag | Description | Required Functions |
|------------|------|-------------|-------------------|
| **Sourcing** | `CAP_SOURCING` (1 << 0) | Generate events from external sources | `get_id`, `get_event_source`, `open`, `close`, `next_batch` |
| **Extraction** | `CAP_EXTRACTION` (1 << 1) | Extract fields from events | `get_fields`, `extract_fields` |
| **Parsing** | `CAP_PARSING` (1 << 2) | Parse events and maintain state | `parse_event` |
| **Async** | `CAP_ASYNC` (1 << 3) | Send asynchronous events | `get_async_events`, `set_async_event_handler` |
| **Capture Listening** | `CAP_CAPTURE_LISTENING` (1 << 4) | React to capture lifecycle (start/stop) | `capture_open`, `capture_close` |

**Source:** [`plugin_loader.h:40-48`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_loader.h)

See [plugin-framework.md](plugin-framework.md) for full Plugin API details.

## State Tables

### Thread Table Schema

Key fields tracked per thread:

| Field | Type | Description |
|-------|------|-------------|
| `tid` | int64 | Thread ID |
| `pid` | int64 | Process ID |
| `ptid` | int64 | Parent thread ID |
| `comm` | string | Command name |
| `exe` | string | Executable path |
| `exepath` | string | Full executable path |
| `args` | string[] | Command arguments |
| `env` | string[] | Environment variables |
| `cwd` | string | Current working directory |
| `uid/gid` | uint32 | User/Group IDs |
| `cgroups` | map | Cgroup memberships |
| `flags` | uint32 | Thread flags (PPM_CL_*) |

### FD Table Schema

Key fields tracked per file descriptor:

| Field | Type | Description |
|-------|------|-------------|
| `fd` | int64 | File descriptor number |
| `type` | enum | FD type (file, socket, pipe, etc.) |
| `name` | string | Name/path |
| `flags` | uint32 | Open flags |
| `ino` | uint64 | Inode number |

## Sources

| Topic | Source File |
|-------|-------------|
| Repository README | [`README.md`](../../../refs/falcosecurity/libs/README.md) |
| CMake build | [`CMakeLists.txt`](../../../refs/falcosecurity/libs/CMakeLists.txt) |
| API version | [`driver/API_VERSION`](../../../refs/falcosecurity/libs/driver/API_VERSION) |
| Schema version | [`driver/SCHEMA_VERSION`](../../../refs/falcosecurity/libs/driver/SCHEMA_VERSION) |
| Release process | [`release.md`](../../../refs/falcosecurity/libs/release.md) |
| Event types | [`driver/ppm_events_public.h`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h) |

## Related Digests

- [modern-bpf.md](modern-bpf.md) - Modern eBPF driver details
- [libscap.md](libscap.md) - libscap API reference
- [libsinsp.md](libsinsp.md) - libsinsp API reference
- [plugin-framework.md](plugin-framework.md) - Plugin system
- [api-reference.md](api-reference.md) - Event types and flags
