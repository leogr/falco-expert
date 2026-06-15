# libscap (System CAPture Library)

> Low-level capture library: engine vtable abstraction, capture engines, event retrieval, ring buffer management, platform information, and statistics.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/libs/userspace/libscap/`](../refs/falcosecurity/libs/userspace/libscap/)

## Overview

libscap is the low-level system capture library within the Falco stack. It sits between the kernel driver layer and the higher-level libsinsp library, providing a unified C API for reading system events from various sources. Its responsibilities include:

- **Driver communication** through an engine vtable abstraction pattern
- **Event retrieval** via the `scap_next()` API
- **Ring buffer management** for efficient kernel-to-userspace data transfer
- **Capture file** read/write (`.scap` format)
- **Process table scanning** from `/proc` at capture start
- **Platform information** collection (machine info, agent info)
- **Statistics** collection (event counts, drop counters)

In the Falco pipeline, libsinsp calls `scap_next()` to retrieve raw `scap_evt` events, which it then parses, enriches with state, and passes to the rule engine.

**Source:** [`digests/falcosecurity/libs/libscap.md`](../digests/falcosecurity/libs/libscap.md), [`digests/falcosecurity/libs/architecture.md`](../digests/falcosecurity/libs/architecture.md)

## Architecture

### Directory Structure

```
userspace/libscap/
├── scap.c                     # Main implementation
├── scap.h                     # Public API header
├── scap_vtable.h              # Engine vtable definition
├── scap_open.h                # Open arguments structure
├── scap_const.h               # Return codes and constants
├── scap_machine_info.h        # Machine and agent info structs
├── scap_platform_api.h        # Platform information API
├── scap_savefile.c            # Capture file handling
├── scap_savefile_api.h        # Savefile public API
├── scap_event.c               # Event utilities
├── scap_procs.c               # Process scanning
├── scap_procs.h               # Process callback types
├── scap_fds.c                 # File descriptor handling
├── metrics_v2.h               # Extended statistics definitions
├── engine/
│   ├── modern_bpf/            # Modern eBPF engine (DEFAULT)
│   ├── kmod/                  # Kernel module engine
│   ├── savefile/              # Capture file replay engine
│   ├── source_plugin/         # Plugin-provided event engine
│   ├── nodriver/              # No-driver engine (/proc scan only)
│   ├── noop/                  # No-operation engine (testing)
│   └── test_input/            # Test event injection engine
├── linux/                     # Linux-specific code
├── macos/                     # macOS-specific code
└── win32/                     # Windows-specific code
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/`](../refs/falcosecurity/libs/userspace/libscap/)

### Engine Vtable (`scap_vtable`)

libscap uses a vtable pattern to support multiple capture engines. Each engine implements the `scap_vtable` interface, enabling the upper layers (libsinsp, Falco) to work identically regardless of the underlying capture mechanism.

```c
// From scap_vtable.h:118-269
struct scap_vtable {
    // Engine identification
    const char* name;

    // Optional savefile operations (NULL if not supported)
    const struct scap_savefile_vtable* savefile_ops;

    // Lifecycle management
    void* (*alloc_handle)(scap_t* main_handle, char* lasterr_ptr);
    int32_t (*init)(scap_t* main_handle, scap_open_args* open_args);
    void (*free_handle)(struct scap_engine_handle engine);
    int32_t (*close)(struct scap_engine_handle engine);

    // Engine feature flags
    uint64_t (*get_flags)(struct scap_engine_handle engine);

    // Event retrieval (core function)
    int32_t (*next)(struct scap_engine_handle engine,
                    scap_evt** pevent,
                    uint16_t* pdevid,
                    uint32_t* pflags);

    // Capture control
    int32_t (*start_capture)(struct scap_engine_handle engine);
    int32_t (*stop_capture)(struct scap_engine_handle engine);

    // Configuration
    int32_t (*configure)(struct scap_engine_handle engine,
                         enum scap_setting setting,
                         unsigned long arg1,
                         unsigned long arg2);

    // Statistics
    int32_t (*get_stats)(struct scap_engine_handle engine,
                         struct scap_stats* stats);
    const struct metrics_v2* (*get_stats_v2)(struct scap_engine_handle engine,
                                             uint32_t flags,
                                             uint32_t* nstats,
                                             int32_t* rc);

    // Driver information
    int32_t (*get_n_tracepoint_hit)(struct scap_engine_handle engine, long* ret);
    uint32_t (*get_n_devs)(struct scap_engine_handle engine);
    uint64_t (*get_max_buf_used)(struct scap_engine_handle engine);
    uint64_t (*get_api_version)(struct scap_engine_handle engine);
    uint64_t (*get_schema_version)(struct scap_engine_handle engine);
};
```

The `next()` function pointer is the core of the vtable. Its contract specifies that the memory pointed to by `*pevent` is owned by the engine and remains valid until the next call to `next()`.

Engine feature flags are returned by `get_flags()`:

```c
// From scap_vtable.h:116
#define ENGINE_FLAG_BPF_STATS_ENABLED (1 << 0)
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_vtable.h`](../refs/falcosecurity/libs/userspace/libscap/scap_vtable.h)

#### Savefile Sub-Vtable

Engines that support savefile operations provide a `scap_savefile_vtable`:

```c
// From scap_vtable.h:86-114
struct scap_savefile_vtable {
    uint64_t (*ftell_capture)(struct scap_engine_handle engine);
    void (*fseek_capture)(struct scap_engine_handle engine, uint64_t off);
    int32_t (*restart_capture)(struct scap* handle);
    int64_t (*get_readfile_offset)(struct scap_engine_handle engine);
};
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_vtable.h:86-114`](../refs/falcosecurity/libs/userspace/libscap/scap_vtable.h)

### Available Engines

| Engine | Directory | Engine Name Constant | Description | Status |
|--------|-----------|---------------------|-------------|--------|
| Modern eBPF | [`engine/modern_bpf/`](../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/) | `"modern_bpf"` | CO-RE eBPF driver using ring buffers | **Default** |
| Kernel Module | [`engine/kmod/`](../refs/falcosecurity/libs/userspace/libscap/engine/kmod/) | `"kmod"` | Traditional kernel module, per-CPU perf buffers | Supported |
| Savefile | [`engine/savefile/`](../refs/falcosecurity/libs/userspace/libscap/engine/savefile/) | `"savefile"` | Replay events from `.scap` capture files | Supported |
| Source Plugin | [`engine/source_plugin/`](../refs/falcosecurity/libs/userspace/libscap/engine/source_plugin/) | `"source_plugin"` | Events from plugins with `CAP_SOURCING` capability | Supported |
| No-Driver | [`engine/nodriver/`](../refs/falcosecurity/libs/userspace/libscap/engine/nodriver/) | `"nodriver"` | No event capture; `/proc` scan only | Supported |
| No-Op | [`engine/noop/`](../refs/falcosecurity/libs/userspace/libscap/engine/noop/) | `"noop"` | No-operation engine for testing | Supported |
| Test Input | [`engine/test_input/`](../refs/falcosecurity/libs/userspace/libscap/engine/test_input/) | `"test_input"` | Inject test events programmatically | Supported |
| Legacy eBPF | `engine/bpf/` (removed in libs 0.25) | `"bpf"` | Legacy eBPF probe | **Removed (libs 0.25 / Falco 0.44)** |
| gVisor | `engine/gvisor/` (removed in libs 0.25) | `"gvisor"` | gVisor sandbox integration | **Removed (libs 0.25 / Falco 0.44)** |

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap.h:80-88`](../refs/falcosecurity/libs/userspace/libscap/scap.h)

## Functional Requirements

### Event Retrieval

The primary function of libscap is event retrieval via `scap_next()`:

```c
// From scap.h:562
int32_t scap_next(scap_t* handle,
                  scap_evt** pevent,
                  uint16_t* pcpuid,
                  uint32_t* pflags);
```

#### Return Codes

| Code | Value | Meaning |
|------|-------|---------|
| `SCAP_SUCCESS` | `0` | Event returned successfully; `*pevent`, `*pcpuid`, `*pflags` contain valid data |
| `SCAP_TIMEOUT` | `-1` | No events available within the read timeout (not an error) |
| `SCAP_EOF` | `6` | End of offline capture file reached; no more events will arrive |
| `SCAP_FAILURE` | `1` | An error occurred; use `scap_getlasterr()` for details |

The `scap_evt` type is an alias for `struct ppm_evt_hdr`:

```c
// From driver/ppm_events_public.h
struct ppm_evt_hdr {
    uint64_t ts;        // Timestamp in nanoseconds since epoch
    uint64_t tid;       // Thread ID
    uint32_t len;       // Total event length including header
    uint16_t type;      // Event type (ppm_event_type enum)
    uint32_t nparams;   // Number of parameters following header
} __attribute__((packed));

typedef struct ppm_evt_hdr scap_evt;
```

Additional event accessor functions:

```c
uint32_t scap_event_getlen(scap_evt* e);
uint16_t scap_event_get_type(scap_evt* e);
uint64_t scap_event_get_ts(scap_evt* e);
uint64_t scap_event_get_tid(scap_evt* e);
uint32_t scap_event_get_nparams(scap_evt* e);
uint64_t scap_event_get_num(scap_t* handle);
uint32_t scap_event_decode_params(const scap_evt* e, struct scap_sized_buffer* params);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap.h:548-607`](../refs/falcosecurity/libs/userspace/libscap/scap.h)

### Capture Control

#### Opening a Capture

libscap provides two patterns for opening a capture:

1. **Combined** `scap_open()` — allocates and initializes in one call:

```c
// From scap.h:496-499
scap_t* scap_open(scap_open_args* oargs,
                  const struct scap_vtable* vtable,
                  char* error,
                  int32_t* rc);
```

2. **Two-step** `scap_alloc()` + `scap_init()` — useful when the handle address is needed during initialization (e.g., for process callbacks):

```c
// From scap.h:462-475
scap_t* scap_alloc(void);
int32_t scap_init(scap_t* handle,
                  scap_open_args* oargs,
                  const struct scap_vtable* vtable);
```

#### Open Arguments (`scap_open_args`)

```c
// From scap_open.h:42-50
typedef struct scap_open_args {
    bool import_users;                       // Create user list at open time
    interesting_ppm_sc_set ppm_sc_of_interest; // Syscalls to capture
    falcosecurity_log_fn log_fn;             // Logging callback
    uint64_t proc_scan_timeout_ms;           // /proc scan timeout (0 = no timeout)
    uint64_t proc_scan_log_interval_ms;      // /proc scan progress logging interval
    void* engine_params;                     // Pointer to engine-specific params
} scap_open_args;
```

The `engine_params` field points to an engine-specific parameters struct. Each engine defines its own:

| Engine | Params Struct | Key Fields |
|--------|--------------|------------|
| `modern_bpf` | `scap_modern_bpf_engine_params` | `buffer_bytes_dim`, `cpus_for_each_buffer`, `allocate_online_only`, `disable_iterators` |
| `kmod` | `scap_kmod_engine_params` | `buffer_bytes_dim` |
| `savefile` | `scap_savefile_engine_params` | `fname`, `fd`, `start_offset`, `fbuffer_size`, `platform` |
| `source_plugin` | `scap_source_plugin_engine_params` | `input_plugin`, `input_plugin_params` |

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_open.h`](../refs/falcosecurity/libs/userspace/libscap/scap_open.h), [`refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h), [`refs/falcosecurity/libs/userspace/libscap/engine/kmod/kmod_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/kmod/kmod_public.h), [`refs/falcosecurity/libs/userspace/libscap/engine/savefile/savefile_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/savefile/savefile_public.h), [`refs/falcosecurity/libs/userspace/libscap/engine/source_plugin/source_plugin_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/source_plugin/source_plugin_public.h)

#### Modern eBPF Engine Parameters

```c
// From engine/modern_bpf/modern_bpf_public.h:26-42
struct scap_modern_bpf_engine_params {
    uint16_t cpus_for_each_buffer;  // Ring buffer allocation ratio
                                     // 0 = single shared buffer
                                     // 1 = one buffer per CPU (default)
    bool allocate_online_only;       // Only allocate for online CPUs
    unsigned long buffer_bytes_dim;  // Ring buffer size in bytes
                                     // Default: 8 * 1024 * 1024 (8MB)
    bool disable_iterators;          // Since libs 0.25.4 / Falco 0.44.1:
                                     // disable BPF iterators for synchronous
                                     // state fetching, falling back to procfs
};
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h)

#### Start, Stop, and Close

```c
// From scap.h:724-735
int32_t scap_start_capture(scap_t* handle);
int32_t scap_stop_capture(scap_t* handle);

// From scap.h:506-523
void scap_deinit(scap_t* handle);
void scap_free(scap_t* handle);
void scap_close(scap_t* handle);  // Combines deinit + free

// Seek within capture file
void scap_fseek(scap_t* handle, uint64_t off);
uint64_t scap_ftell(scap_t* handle);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap.h`](../refs/falcosecurity/libs/userspace/libscap/scap.h)

### Configuration Settings

Engine behavior is configured at runtime through the `configure()` vtable function, using the `scap_setting` enum:

```c
// From scap_vtable.h:45-84
enum scap_setting {
    SCAP_SAMPLING_RATIO,           // arg1: ratio (power of 2, <= 128)
                                   // arg2: dropping mode enabled (1) / disabled (0)
    SCAP_SNAPLEN,                  // arg1: max capture length (< 65536)
    SCAP_PPM_SC_MASK,              // arg1: scap_ppm_sc_mask_op
                                   // arg2: ppm_sc id
    SCAP_DYNAMIC_SNAPLEN,          // arg1: enabled (bool)
    SCAP_FULLCAPTURE_PORT_RANGE,   // arg1: min port, arg2: max port
    SCAP_STATSD_PORT,              // arg1: statsd port
    SCAP_DROP_FAILED,              // arg1: enable/disable dropping failed syscalls
};

enum scap_ppm_sc_mask_op {
    SCAP_PPM_SC_MASK_SET = 1,     // Enable a syscall
    SCAP_PPM_SC_MASK_UNSET = 2,   // Disable a syscall
};
```

Convenience wrapper functions are also provided:

```c
int32_t scap_set_snaplen(scap_t* handle, uint32_t snaplen);
int32_t scap_set_ppm_sc(scap_t* handle, ppm_sc_code ppm_sc, bool enabled);
int32_t scap_set_dropfailed(scap_t* handle, bool enabled);
int32_t scap_set_fullcapture_port_range(scap_t* handle, uint16_t range_start, uint16_t range_end);
int32_t scap_set_statsd_port(scap_t* handle, uint16_t port);
int32_t scap_start_dropping_mode(scap_t* handle, uint32_t sampling_ratio);
int32_t scap_stop_dropping_mode(scap_t* handle);
int32_t scap_enable_dynamic_snaplen(scap_t* handle);
int32_t scap_disable_dynamic_snaplen(scap_t* handle);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_vtable.h:45-84`](../refs/falcosecurity/libs/userspace/libscap/scap_vtable.h), [`refs/falcosecurity/libs/userspace/libscap/scap.h:786-996`](../refs/falcosecurity/libs/userspace/libscap/scap.h)

## Implementation Details

### Platform Information

#### Machine Info

Collected at capture open time; for live captures it comes from the OS, for offline captures from the `.scap` file header.

```c
// From scap_machine_info.h:40-50
typedef struct _scap_machine_info {
    uint32_t num_cpus;           // Number of processors
    uint64_t memory_size_bytes;  // Physical memory size
    uint64_t max_pid;            // Highest PID number on this machine
    char hostname[128];          // The machine hostname
    uint64_t boot_ts_epoch;      // Host boot timestamp (nanoseconds, epoch)
    uint64_t flags;              // Flags
    uint64_t reserved3;          // Reserved for future use
    uint64_t reserved4;          // Reserved for future use
} scap_machine_info;

const struct _scap_machine_info* scap_get_machine_info(struct scap_platform* platform);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h:40-50`](../refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h)

#### Agent Info

Runtime information about the Falco agent process (live captures only):

```c
// From scap_machine_info.h:57-62
typedef struct _scap_agent_info {
    uint64_t start_ts_epoch;  // Agent start timestamp (nanoseconds, epoch)
    double start_time;        // /proc/self/stat start_time / HZ (seconds since boot)
    char uname_r[128];        // Kernel release (uname -r)
} scap_agent_info;

const scap_agent_info* scap_get_agent_info(struct scap_platform* platform);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h:57-62`](../refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h)

### Process Table Scanning

At capture open time, libscap scans `/proc` to build the initial process state. This allows libsinsp to have a complete view of running processes from the start, not just those that generate events after capture begins.

#### Thread Info Structure

```c
// From scap.h:246-301 (key fields shown)
typedef struct scap_threadinfo {
    uint64_t tid;                                   // Thread/task ID
    uint64_t pid;                                   // Process ID
    uint64_t ptid;                                  // Parent thread ID
    uint64_t sid;                                   // Session ID
    uint64_t vpgid;                                 // Process group (from pid namespace)
    uint64_t pgid;                                  // Process group (from host namespace)
    char comm[SCAP_MAX_PATH_SIZE + 1];              // Command name (e.g., "top")
    char exe[SCAP_MAX_PATH_SIZE + 1];               // argv[0]
    char exepath[SCAP_MAX_PATH_SIZE + 1];           // Full executable path
    bool exe_writable;                              // Executable writable by same user
    bool exe_upper_layer;                           // Executable on overlayfs upper layer
    bool exe_lower_layer;                           // Executable on overlayfs lower layer
    bool exe_from_memfd;                            // Executable from memfd
    char args[SCAP_MAX_ARGS_SIZE + 1];              // Command line arguments
    char env[SCAP_MAX_ENV_SIZE + 1];                // Environment variables
    char cwd[SCAP_MAX_PATH_SIZE + 1];               // Current working directory
    int64_t fdlimit;                                // Max open files
    uint32_t uid;                                   // User ID
    uint32_t gid;                                   // Group ID
    uint64_t cap_permitted;                         // Permitted capabilities
    uint64_t cap_effective;                          // Effective capabilities
    uint64_t cap_inheritable;                       // Inheritable capabilities
    uint64_t exe_ino;                               // Executable inode
    uint64_t exe_ino_ctime;                         // Executable ctime
    uint64_t exe_ino_mtime;                         // Executable mtime
    uint64_t exe_ino_ctime_duration_clone_ts;       // Duration between exe ctime and clone_ts
    uint64_t exe_ino_ctime_duration_pidns_start;    // Duration between pidns start and exe ctime
    uint32_t vmsize_kb;                             // Virtual memory (KB)
    uint32_t vmrss_kb;                              // Resident memory (KB)
    uint32_t vmswap_kb;                             // Swapped memory (KB)
    uint64_t pfmajor;                               // Major page faults
    uint64_t pfminor;                               // Minor page faults
    int64_t vtid;                                   // Virtual thread ID (in pid namespace)
    int64_t vpid;                                   // Virtual process ID (in pid namespace)
    uint64_t pidns_init_start_ts;                   // PID namespace init start time
    struct scap_cgroup_set cgroups;                 // Cgroup set
    char root[SCAP_MAX_PATH_SIZE + 1];              // Root directory
    scap_fdinfo* fdlist;                            // File descriptor table (hash table)
    uint64_t clone_ts;                              // Clone timestamp
    uint32_t tty;                                   // Controlling terminal
    uint32_t loginuid;                              // Login UID (auid)
    UT_hash_handle hh;                              // Hash table handle
} scap_threadinfo;
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap.h:246-301`](../refs/falcosecurity/libs/userspace/libscap/scap.h)

#### Process Scanning Callbacks

libscap uses a callback-based mechanism for process table construction:

```c
// From scap_procs.h:50-55
typedef int32_t (*proc_entry_callback)(void* context,
                                       char* error,
                                       int64_t tid,
                                       scap_threadinfo* tinfo,
                                       scap_fdinfo* fdinfo,
                                       scap_threadinfo** new_tinfo);

typedef void (*proc_table_refresh_start)(void* context);
typedef void (*proc_table_refresh_end)(void* context);

// Full callback set
typedef struct scap_proc_callbacks {
    proc_table_refresh_start m_refresh_start_cb;
    proc_table_refresh_end m_refresh_end_cb;
    proc_entry_callback m_proc_entry_cb;
    void* m_callback_context;
} scap_proc_callbacks;
```

The `proc_entry_callback` is invoked for each thread and file descriptor found during `/proc` scanning. Memory ownership: `tinfo` and `fdinfo` are owned by the caller and must not be freed or stored by the callback.

Scan timeouts are configurable via `scap_open_args`:
- `proc_scan_timeout_ms` — timeout after which a successful scan is cut short (`0` = no timeout, via `SCAP_PROC_SCAN_TIMEOUT_NONE`)
- `proc_scan_log_interval_ms` — interval for progress logging (`0` = no logging, via `SCAP_PROC_SCAN_LOG_NONE`)

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_procs.h`](../refs/falcosecurity/libs/userspace/libscap/scap_procs.h), [`refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h`](../refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h)

#### Platform API for Process Information

```c
// From scap_platform_api.h
int32_t scap_proc_get(struct scap_platform* platform,
                      int64_t tid,
                      struct scap_threadinfo* tinfo,
                      bool scan_sockets);
int32_t scap_refresh_proc_table(struct scap_platform* platform);
bool scap_is_thread_alive(struct scap_platform* platform,
                          int64_t pid, int64_t tid, const char* comm);
int32_t scap_getpid_global(struct scap_platform* platform, int64_t* pid);
struct ppm_proclist_info* scap_get_threadlist(struct scap_platform* platform, char* error);
int32_t scap_get_fdlist(struct scap_platform* platform, struct scap_threadinfo* tinfo, char* error);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h`](../refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h)

### Statistics

#### Basic Statistics (`scap_stats`)

```c
// From scap.h:127-149
typedef struct scap_stats {
    uint64_t n_evts;                                // Total events received by driver
    uint64_t n_drops;                               // Total events dropped
    uint64_t n_drops_buffer;                        // Drops due to full buffer
    uint64_t n_drops_buffer_clone_fork_exit;        // Clone/fork exit drops
    uint64_t n_drops_buffer_execve_exit;            // Execve exit drops
    uint64_t n_drops_buffer_connect_enter;          // Connect enter drops
    uint64_t n_drops_buffer_connect_exit;           // Connect exit drops
    uint64_t n_drops_buffer_open_enter;             // Open enter drops
    uint64_t n_drops_buffer_open_exit;              // Open exit drops
    uint64_t n_drops_buffer_dir_file_exit;          // Dir/file exit drops
    uint64_t n_drops_buffer_other_interest_exit;    // Other interest exit drops
    uint64_t n_drops_buffer_close_exit;             // Close exit drops
    uint64_t n_drops_buffer_proc_exit;              // Process exit drops
    uint64_t n_drops_scratch_map;                   // Drops from full scratch map
    uint64_t n_drops_pf;                            // Drops from invalid memory access
    uint64_t n_drops_bug;                           // Drops from kernel instrumentation bugs
    uint64_t n_preemptions;                         // Preemption events
    uint64_t n_suppressed;                          // Events skipped (suppressed TIDs)
    uint64_t n_tids_suppressed;                     // Number of currently suppressed threads
} scap_stats;

int32_t scap_get_stats(scap_t* handle, scap_stats* stats);
```

The category-specific drop counters (e.g., `n_drops_buffer_clone_fork_exit`, `n_drops_buffer_execve_exit`) provide fine-grained visibility into which event types are being lost when buffers overflow.

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap.h:127-149`](../refs/falcosecurity/libs/userspace/libscap/scap.h)

#### Extended Statistics (v2 API)

The v2 statistics API provides engine-specific metrics including BPF program statistics (similar to `bpftool prog show` output):

```c
// From scap.h:668-671
const struct metrics_v2* scap_get_stats_v2(scap_t* handle,
                                           uint32_t flags,
                                           uint32_t* nstats,
                                           int32_t* rc);
```

The `flags` parameter specifies which categories of statistics to collect. The returned `metrics_v2` array contains `*nstats` entries and remains valid until the next call.

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap.h:658-671`](../refs/falcosecurity/libs/userspace/libscap/scap.h), [`refs/falcosecurity/libs/userspace/libscap/metrics_v2.h`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h)

### Error Handling

#### Return Codes

```c
// From scap_const.h:24-35
#define SCAP_SUCCESS          0   // Operation completed successfully
#define SCAP_FAILURE          1   // General failure (use scap_getlasterr())
#define SCAP_TIMEOUT         -1   // No events available (not an error)
#define SCAP_ILLEGAL_INPUT    3   // Invalid input parameter
#define SCAP_NOTFOUND         4   // Requested item not found
#define SCAP_INPUT_TOO_SMALL  5   // Buffer too small for output
#define SCAP_EOF              6   // End of capture file
#define SCAP_UNEXPECTED_BLOCK 7   // Unexpected block in capture file
#define SCAP_VERSION_MISMATCH 8   // Version incompatibility
#define SCAP_NOT_SUPPORTED    9   // Operation not supported by engine
#define SCAP_FILTERED_EVENT  10   // Event was filtered out

#define SCAP_LASTERR_SIZE   256   // Error message buffer size
```

Error message retrieval:

```c
const char* scap_getlasterr(scap_t* handle);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_const.h`](../refs/falcosecurity/libs/userspace/libscap/scap_const.h)

### Capture Files

#### `.scap` File Format

Capture files contain:
1. **File header** with version and machine information
2. **Process table snapshot** (process list and FD tables)
3. **Event stream** (compressed via gzip)

#### Savefile API

```c
// From scap_savefile_api.h

// Open a trace file for writing
scap_dumper_t* scap_dump_open(struct scap_platform* platform,
                               const char* fname,
                               compression_mode compress,
                               char* lasterr);

// Open using an existing file descriptor
scap_dumper_t* scap_dump_open_fd(struct scap_platform* platform,
                                  int fd,
                                  compression_mode compress,
                                  bool skip_proc_scan,
                                  char* lasterr);

// Write a single event to the trace file
int32_t scap_dump(scap_dumper_t* d,
                  scap_evt* e,
                  uint16_t cpuid,
                  uint32_t flags);

// Close and flush
void scap_dump_close(scap_dumper_t* d);
void scap_dump_flush(scap_dumper_t* d);

// Position queries
int64_t scap_dump_get_offset(scap_dumper_t* d);
int64_t scap_dump_ftell(scap_dumper_t* d);

// Error message for dump operations
const char* scap_dump_getlasterr(scap_dumper_t* handle);
```

Compression modes:

```c
typedef enum compression_mode {
    SCAP_COMPRESSION_NONE = 0,
    SCAP_COMPRESSION_GZIP = 1
} compression_mode;
```

The dumper supports three target types:

```c
typedef enum ppm_dumper_type {
    DT_FILE = 0,          // Write to file via gzFile
    DT_MEM = 1,           // Write to user-provided memory buffer
    DT_MANAGED_BUF = 2,   // Write to auto-managed buffer (3MB initial, 1.25x resize)
} ppm_dumper_type;
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap_savefile_api.h`](../refs/falcosecurity/libs/userspace/libscap/scap_savefile_api.h)

### Event Encoding/Decoding Utilities

libscap provides functions to programmatically create and compare events:

```c
// Create an event from parameters
int32_t scap_event_encode_params(struct scap_sized_buffer event_buf,
                                 size_t* event_size,
                                 char* error,
                                 ppm_event_code event_type,
                                 uint32_t n,
                                 ...);

// Allocate and create an event with timestamp and tid
scap_evt* scap_create_event(char* error,
                            uint64_t ts,
                            uint64_t tid,
                            ppm_event_code event_type,
                            uint32_t n,
                            ...);

// Compare two events for equality
bool scap_compare_events(scap_evt* curr, scap_evt* expected, char* error);

// Syscall code conversions
ppm_sc_code scap_ppm_sc_from_name(const char* name);
ppm_sc_code scap_native_id_to_ppm_sc(int native_id);
int scap_ppm_sc_to_native_id(ppm_sc_code sc_code);
const char* scap_get_ppm_sc_name(ppm_sc_code sc);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap.h:843-952`](../refs/falcosecurity/libs/userspace/libscap/scap.h)

### Driver Version Compatibility

```c
// From scap.h:104-105
#define SCAP_MINIMUM_DRIVER_API_VERSION    PPM_API_VERSION(8, 0, 0)
#define SCAP_MINIMUM_DRIVER_SCHEMA_VERSION PPM_API_VERSION(4, 1, 0)

// Default buffer size (used before variable buffer sizing was introduced)
#define DEFAULT_DRIVER_BUFFER_BYTES_DIM    8 * 1024 * 1024  // 8MB

// Query driver versions at runtime
uint64_t scap_get_driver_api_version(scap_t* handle);
uint64_t scap_get_driver_schema_version(scap_t* handle);

// Check current engine name
bool scap_check_current_engine(scap_t* handle, const char* engine_name);
```

**Source:** [`refs/falcosecurity/libs/userspace/libscap/scap.h:104-110`](../refs/falcosecurity/libs/userspace/libscap/scap.h)

## Non-Functional Requirements

### Performance

- **Zero-copy ring buffer reads** for the modern eBPF engine: events are delivered through memory-mapped `BPF_MAP_TYPE_RINGBUF` buffers, avoiding kernel-to-userspace copies
- **Per-CPU buffering**: The modern eBPF engine supports configurable buffer-to-CPU ratios (1:1 by default, or shared across CPUs)
- **Kernel module** uses perf buffers with `copy_to_user` (higher overhead than modern eBPF ring buffers)
- **Sampling ratio**: Configurable event dropping to reduce load under pressure (power of 2, up to 128:1)
- **Dynamic snaplen**: Adaptive capture length based on event type to reduce buffer usage

### Portability

- **Linux**: Primary platform with full support (modern eBPF, kmod, all engines)
- **macOS**: Limited support via platform-specific code in `macos/`
- **Windows**: Limited support via platform-specific code in `win32/`

### Reliability

- **Category-specific drop counters** enable understanding which critical event types are lost under buffer pressure (clone/fork, execve, connect, open, close, proc_exit)
- **Proc scan timeouts** prevent indefinite hangs when `/proc` is very large (e.g., systems with many processes)

## Usage Example

```c
#include <scap.h>

int main() {
    char error[SCAP_LASTERR_SIZE];
    int32_t rc;

    // Configure modern eBPF engine parameters
    struct scap_modern_bpf_engine_params engine_params = {
        .buffer_bytes_dim = DEFAULT_DRIVER_BUFFER_BYTES_DIM,  // 8MB
        .cpus_for_each_buffer = 1,       // One buffer per CPU
        .allocate_online_only = true,    // Only for online CPUs
    };

    // Configure open arguments
    scap_open_args args = {
        .import_users = true,
        .engine_params = &engine_params,
        .proc_scan_timeout_ms = SCAP_PROC_SCAN_TIMEOUT_NONE,
        .proc_scan_log_interval_ms = SCAP_PROC_SCAN_LOG_NONE,
    };
    // Set syscalls of interest in args.ppm_sc_of_interest...

    // Open capture with modern_bpf vtable
    scap_t* handle = scap_open(&args, &scap_modern_bpf_vtable, error, &rc);
    if (handle == NULL) {
        fprintf(stderr, "Failed to open: %s\n", error);
        return 1;
    }

    // Main event loop
    scap_evt* evt;
    uint16_t cpuid;
    uint32_t flags;

    while (true) {
        rc = scap_next(handle, &evt, &cpuid, &flags);
        if (rc == SCAP_SUCCESS) {
            printf("Event: type=%d tid=%lu ts=%lu\n",
                   evt->type, evt->tid, evt->ts);
        } else if (rc == SCAP_TIMEOUT) {
            continue;
        } else {
            break;  // SCAP_EOF or SCAP_FAILURE
        }
    }

    scap_close(handle);
    return 0;
}
```

**Source:** [`digests/falcosecurity/libs/libscap.md`](../digests/falcosecurity/libs/libscap.md)

## Deprecated Features

| Feature | Status | Notes |
|---------|--------|-------|
| Legacy eBPF engine (previously at `engine/bpf/`) | Removed in libs 0.25 (Falco 0.44) | Deprecated in 0.43; use `modern_bpf` instead |
| gVisor engine (previously at `engine/gvisor/`) | Removed in libs 0.25 (Falco 0.44) | Deprecated in 0.43 |

**Source:** [`digests/falcosecurity/falco/proposals.md`](../digests/falcosecurity/falco/proposals.md)

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`architecture-overview.md`](architecture-overview.md) | System-level context showing libscap in the Falco pipeline |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Kernel driver layer that produces events consumed by libscap |
| [`libsinsp.md`](libsinsp.md) | Higher-level library that calls `scap_next()` for event retrieval |
| [`plugin-system.md`](plugin-system.md) | Plugin framework using the `source_plugin` engine |

## Sources

| Topic | Source File |
|-------|-------------|
| Public API header | [`refs/falcosecurity/libs/userspace/libscap/scap.h`](../refs/falcosecurity/libs/userspace/libscap/scap.h) |
| Engine vtable definition | [`refs/falcosecurity/libs/userspace/libscap/scap_vtable.h`](../refs/falcosecurity/libs/userspace/libscap/scap_vtable.h) |
| Open arguments | [`refs/falcosecurity/libs/userspace/libscap/scap_open.h`](../refs/falcosecurity/libs/userspace/libscap/scap_open.h) |
| Return codes | [`refs/falcosecurity/libs/userspace/libscap/scap_const.h`](../refs/falcosecurity/libs/userspace/libscap/scap_const.h) |
| Machine/agent info | [`refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h`](../refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h) |
| Platform API | [`refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h`](../refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h) |
| Process callbacks | [`refs/falcosecurity/libs/userspace/libscap/scap_procs.h`](../refs/falcosecurity/libs/userspace/libscap/scap_procs.h) |
| Savefile API | [`refs/falcosecurity/libs/userspace/libscap/scap_savefile_api.h`](../refs/falcosecurity/libs/userspace/libscap/scap_savefile_api.h) |
| Modern eBPF params | [`refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h) |
| Kmod params | [`refs/falcosecurity/libs/userspace/libscap/engine/kmod/kmod_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/kmod/kmod_public.h) |
| Savefile params | [`refs/falcosecurity/libs/userspace/libscap/engine/savefile/savefile_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/savefile/savefile_public.h) |
| Source plugin params | [`refs/falcosecurity/libs/userspace/libscap/engine/source_plugin/source_plugin_public.h`](../refs/falcosecurity/libs/userspace/libscap/engine/source_plugin/source_plugin_public.h) |
| Extended metrics | [`refs/falcosecurity/libs/userspace/libscap/metrics_v2.h`](../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| libscap digest | [`digests/falcosecurity/libs/libscap.md`](../digests/falcosecurity/libs/libscap.md) |
| Architecture digest | [`digests/falcosecurity/libs/architecture.md`](../digests/falcosecurity/libs/architecture.md) |
