# libscap (System CAPture Library)

## Overview

libscap is the low-level capture library in the Falco libs stack, sitting between the kernel driver layer and libsinsp. It provides a unified C API for live capture control, event retrieval (from drivers, plugins, or capture files), capture file (`.scap`) read/write, `/proc` scanning for initial process state, platform information collection, and statistics.

In the Falco pipeline, libsinsp calls `scap_next()` to retrieve raw `scap_evt` events, then parses and enriches them.

**Source:** [`scap.h:29-43`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h)

## Engine Vtable (`scap_vtable`)

libscap uses a vtable pattern so upper layers work identically regardless of the capture engine. Each engine implements `scap_vtable` ([`scap_vtable.h:118-269`](../../../refs/falcosecurity/libs/userspace/libscap/scap_vtable.h)):

```c
struct scap_vtable {
    const char* name;
    const struct scap_savefile_vtable* savefile_ops;  // NULL if unsupported
    void* (*alloc_handle)(scap_t* main_handle, char* lasterr_ptr);
    int32_t (*init)(scap_t* main_handle, scap_open_args* open_args);
    uint64_t (*get_flags)(struct scap_engine_handle engine);
    void (*free_handle)(struct scap_engine_handle engine);
    int32_t (*close)(struct scap_engine_handle engine);
    int32_t (*next)(struct scap_engine_handle engine, scap_evt** pevent,
                    uint16_t* pdevid, uint32_t* pflags);
    int32_t (*start_capture)(struct scap_engine_handle engine);
    int32_t (*stop_capture)(struct scap_engine_handle engine);
    int32_t (*configure)(struct scap_engine_handle engine, enum scap_setting setting,
                         unsigned long arg1, unsigned long arg2);
    int32_t (*get_stats)(struct scap_engine_handle engine, struct scap_stats* stats);
    const struct metrics_v2* (*get_stats_v2)(struct scap_engine_handle engine,
                                             uint32_t flags, uint32_t* nstats, int32_t* rc);
    int32_t (*get_n_tracepoint_hit)(struct scap_engine_handle engine, long* ret);
    uint32_t (*get_n_devs)(struct scap_engine_handle engine);
    uint64_t (*get_max_buf_used)(struct scap_engine_handle engine);
    uint64_t (*get_api_version)(struct scap_engine_handle engine);
    uint64_t (*get_schema_version)(struct scap_engine_handle engine);
};
```

The `scap_engine_handle` wraps a `void*` pointer ([`engine_handle.h:27-29`](../../../refs/falcosecurity/libs/userspace/libscap/engine_handle.h)). The `next()` contract: `*pevent` memory is engine-owned, valid until the next `next()` call. Engine flag: `ENGINE_FLAG_BPF_STATS_ENABLED (1 << 0)` ([`scap_vtable.h:116`](../../../refs/falcosecurity/libs/userspace/libscap/scap_vtable.h)).

### Savefile Sub-Vtable

```c
// scap_vtable.h:86-114
struct scap_savefile_vtable {
    uint64_t (*ftell_capture)(struct scap_engine_handle engine);
    void (*fseek_capture)(struct scap_engine_handle engine, uint64_t off);
    int32_t (*restart_capture)(struct scap* handle);
    int64_t (*get_readfile_offset)(struct scap_engine_handle engine);
};
```

### Platform Vtable (`scap_platform_vtable`)

Platform-specific operations are in a separate vtable ([`scap_platform_impl.h:43-88`](../../../refs/falcosecurity/libs/userspace/libscap/scap_platform_impl.h)) with methods for `init_platform`, `refresh_addr_list`, `get_device_by_mount_id`, `get_proc`, `refresh_proc_table`, `is_thread_alive`, `get_global_pid`, `get_threadlist`, `get_fdlist`, `get_fdinfo`, `close_platform`, and `free_platform`. The base `scap_platform` struct holds `m_vtable`, `m_addrlist`, `m_userlist`, `m_proclist`, `m_agent_info`, `m_machine_info`, `m_driver_procinfo` ([`scap_platform_impl.h:93-102`](../../../refs/falcosecurity/libs/userspace/libscap/scap_platform_impl.h)).

## Available Engines

| Engine | Name Constant | Params Struct | Status |
|--------|---------------|---------------|--------|
| Modern eBPF ([`engine/modern_bpf/`](../../../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/)) | `"modern_bpf"` | `scap_modern_bpf_engine_params` | **Default** |
| Kernel Module ([`engine/kmod/`](../../../refs/falcosecurity/libs/userspace/libscap/engine/kmod/)) | `"kmod"` | `scap_kmod_engine_params` | Supported |
| Savefile ([`engine/savefile/`](../../../refs/falcosecurity/libs/userspace/libscap/engine/savefile/)) | `"savefile"` | `scap_savefile_engine_params` | Supported |
| Source Plugin ([`engine/source_plugin/`](../../../refs/falcosecurity/libs/userspace/libscap/engine/source_plugin/)) | `"source_plugin"` | `scap_source_plugin_engine_params` | Supported |
| No-Driver ([`engine/nodriver/`](../../../refs/falcosecurity/libs/userspace/libscap/engine/nodriver/)) | `"nodriver"` | (none) | Supported |
| No-Op ([`engine/noop/`](../../../refs/falcosecurity/libs/userspace/libscap/engine/noop/)) | N/A | (none) | Testing |
| Test Input ([`engine/test_input/`](../../../refs/falcosecurity/libs/userspace/libscap/engine/test_input/)) | `"test_input"` | `scap_test_input_engine_params` | Testing |
| Legacy eBPF (`engine/bpf/`) | `"bpf"` | `scap_bpf_engine_params` | **Removed in libs 0.25 / Falco 0.44** |
| gVisor (`engine/gvisor/`) | `"gvisor"` | `scap_gvisor_engine_params` | **Removed in libs 0.25 / Falco 0.44** |

**Source:** Engine public headers included from [`scap.h:81-88`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h)

### Engine-Specific Parameters

**Modern eBPF** ([`modern_bpf_public.h:26-40`](../../../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h)): `uint16_t cpus_for_each_buffer` (0=shared, 1=per-CPU default), `bool allocate_online_only`, `unsigned long buffer_bytes_dim`.

**Kmod** ([`kmod_public.h:26-30`](../../../refs/falcosecurity/libs/userspace/libscap/engine/kmod/kmod_public.h)): `unsigned long buffer_bytes_dim`.

**Savefile** ([`savefile_public.h:27-36`](../../../refs/falcosecurity/libs/userspace/libscap/engine/savefile/savefile_public.h)): `int fd`, `const char* fname`, `uint64_t start_offset`, `uint32_t fbuffer_size`, `struct scap_platform* platform`.

**Source Plugin** ([`source_plugin_public.h:25-30`](../../../refs/falcosecurity/libs/userspace/libscap/engine/source_plugin/source_plugin_public.h)): `scap_source_plugin* input_plugin`, `char* input_plugin_params`.

**Legacy eBPF** (removed in libs 0.25 / Falco 0.44; previously `bpf_public.h`): `unsigned long buffer_bytes_dim`, `const char* bpf_probe`.

**gVisor** (removed in libs 0.25 / Falco 0.44; previously `gvisor_public.h`): `const char* gvisor_root_path`, `const char* gvisor_config_path`, `bool no_events`, `int gvisor_epoll_timeout`, `struct scap_gvisor_platform* gvisor_platform`.

## Core API

### Opening a Capture

```c
// Combined (scap.h:496-499)
scap_t* scap_open(scap_open_args* oargs, const struct scap_vtable* vtable,
                  char* error, int32_t* rc);

// Two-step (scap.h:462, 475) -- useful when handle address needed during init
scap_t* scap_alloc(void);
int32_t scap_init(scap_t* handle, scap_open_args* oargs, const struct scap_vtable* vtable);
```

### Open Arguments

```c
// scap_open.h:42-50
typedef struct scap_open_args {
    bool import_users;
    interesting_ppm_sc_set ppm_sc_of_interest;  // bool ppm_sc[PPM_SC_MAX]
    falcosecurity_log_fn log_fn;
    uint64_t proc_scan_timeout_ms;     // 0 = SCAP_PROC_SCAN_TIMEOUT_NONE
    uint64_t proc_scan_log_interval_ms; // 0 = SCAP_PROC_SCAN_LOG_NONE
    void* engine_params;               // Pointer to engine-specific params
} scap_open_args;
```

**Source:** [`scap_open.h:38-50`](../../../refs/falcosecurity/libs/userspace/libscap/scap_open.h)

### Event Retrieval

```c
// scap.h:562
int32_t scap_next(scap_t* handle, scap_evt** pevent, uint16_t* pcpuid, uint32_t* pflags);
```

Returns `SCAP_SUCCESS`, `SCAP_TIMEOUT`, `SCAP_EOF`, or `SCAP_FAILURE`. The `scap_evt` type aliases `struct ppm_evt_hdr` ([`scap.h:57`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h)):

```c
// driver/ppm_events_public.h:2182-2191 (packed)
struct ppm_evt_hdr {
    uint64_t ts;      // Nanoseconds since epoch
    uint64_t tid;     // Thread ID
    uint32_t len;     // Total event length including header
    uint16_t type;    // Event type (ppm_event_code)
    uint32_t nparams; // Number of parameters
};
```

Event accessors ([`scap.h:571-842`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h)): `scap_event_getlen()`, `scap_event_get_type()`, `scap_event_get_ts()`, `scap_event_get_tid()`, `scap_event_get_nparams()`, `scap_event_get_num()`, `scap_event_getinfo()`, `scap_event_get_dump_flags()`, `scap_event_decode_params()`.

### Capture Control

```c
// scap.h:724-735, 506-523, 535, 984-985
int32_t scap_start_capture(scap_t* handle);
int32_t scap_stop_capture(scap_t* handle);
void scap_close(scap_t* handle);      // deinit + free
void scap_deinit(scap_t* handle);
void scap_free(scap_t* handle);
uint32_t scap_restart_capture(scap_t* handle);
uint64_t scap_ftell(scap_t* handle);
void scap_fseek(scap_t* handle, uint64_t off);
```

### Configuration Settings

```c
// scap_vtable.h:45-84
enum scap_setting {
    SCAP_SAMPLING_RATIO,         // arg1: ratio (power of 2, <=128), arg2: dropping mode 1/0
    SCAP_SNAPLEN,                // arg1: max capture length (<65536)
    SCAP_PPM_SC_MASK,            // arg1: SCAP_PPM_SC_MASK_SET(1)/UNSET(2), arg2: ppm_sc id
    SCAP_DYNAMIC_SNAPLEN,        // arg1: enabled
    SCAP_FULLCAPTURE_PORT_RANGE, // arg1: min port, arg2: max port
    SCAP_STATSD_PORT,            // arg1: port
    SCAP_DROP_FAILED,            // arg1: enable/disable
};
```

Convenience wrappers ([`scap.h:799-996`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h)): `scap_set_snaplen()`, `scap_set_ppm_sc()`, `scap_set_dropfailed()`, `scap_set_fullcapture_port_range()`, `scap_set_statsd_port()`, `scap_start_dropping_mode()`, `scap_stop_dropping_mode()`, `scap_enable_dynamic_snaplen()`, `scap_disable_dynamic_snaplen()`.

## Return Codes

```c
// scap_const.h:24-39
#define SCAP_SUCCESS           0
#define SCAP_FAILURE           1
#define SCAP_TIMEOUT          -1
#define SCAP_ILLEGAL_INPUT     3
#define SCAP_NOTFOUND          4
#define SCAP_INPUT_TOO_SMALL   5
#define SCAP_EOF               6
#define SCAP_UNEXPECTED_BLOCK  7
#define SCAP_VERSION_MISMATCH  8
#define SCAP_NOT_SUPPORTED     9
#define SCAP_FILTERED_EVENT   10
#define SCAP_LASTERR_SIZE    256

const char* scap_getlasterr(scap_t* handle);  // scap.h:540
```

**Source:** [`scap_const.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_const.h)

## Statistics

### Basic (`scap_stats`)

```c
// scap.h:127-149
typedef struct scap_stats {
    uint64_t n_evts;                             // Total events received
    uint64_t n_drops;                            // Total events dropped
    uint64_t n_drops_buffer;                     // Drops: full buffer
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
    uint64_t n_drops_scratch_map;                // Full scratch map
    uint64_t n_drops_pf;                         // Invalid memory access
    uint64_t n_drops_bug;                        // Kernel instrumentation bugs
    uint64_t n_preemptions;
    uint64_t n_suppressed;                       // Skipped (suppressed TIDs)
    uint64_t n_tids_suppressed;                  // Currently suppressed threads
} scap_stats;

int32_t scap_get_stats(scap_t* handle, scap_stats* stats);  // scap.h:656
```

### Extended (`metrics_v2`)

```c
// scap.h:668-671
const struct metrics_v2* scap_get_stats_v2(scap_t* handle, uint32_t flags,
                                           uint32_t* nstats, int32_t* rc);
```

Category flags ([`metrics_v2.h:52-60`](../../../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h)): `METRICS_V2_KERNEL_COUNTERS` (1<<0), `METRICS_V2_LIBBPF_STATS` (1<<1), `METRICS_V2_RESOURCE_UTILIZATION` (1<<2), `METRICS_V2_STATE_COUNTERS` (1<<3), `METRICS_V2_RULE_COUNTERS` (1<<4), `METRICS_V2_MISC` (1<<5), `METRICS_V2_PLUGINS` (1<<6), `METRICS_V2_KERNEL_COUNTERS_PER_CPU` (1<<7).

Each entry: `char name[512]`, `uint32_t flags`, `metrics_v2_metric_type metric_type`, `metrics_v2_value value`, `metrics_v2_value_type type`, `metrics_v2_value_unit unit` ([`metrics_v2.h:107-116`](../../../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h)).

## Platform Information

### Machine Info ([`scap_machine_info.h:40-50`](../../../refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h))

Packed struct: `uint32_t num_cpus`, `uint64_t memory_size_bytes`, `uint64_t max_pid`, `char hostname[128]`, `uint64_t boot_ts_epoch` (ns, epoch), `uint64_t flags`, `uint64_t reserved3`, `uint64_t reserved4`. Retrieved via `scap_get_machine_info(struct scap_platform*)` ([`scap_platform_api.h:95`](../../../refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h)).

### Agent Info ([`scap_machine_info.h:57-62`](../../../refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h))

`uint64_t start_ts_epoch` (ns, epoch), `double start_time` (seconds since boot), `char uname_r[128]`. Retrieved via `scap_get_agent_info(struct scap_platform*)` ([`scap_platform_api.h:104`](../../../refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h)).

## Process Table

### Thread Info (`scap_threadinfo`) ([`scap.h:246-301`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h))

Key fields: `uint64_t tid/pid/ptid/sid/vpgid/pgid`, `char comm/exe/exepath[1025]`, `bool exe_writable/exe_upper_layer/exe_lower_layer/exe_from_memfd`, `char args[4097]` + `uint16_t args_len`, `char env[4097]` + `uint16_t env_len`, `char cwd[1025]`, `int64_t fdlimit`, `uint32_t flags/uid/gid`, `uint64_t cap_permitted/cap_effective/cap_inheritable`, `uint64_t exe_ino/exe_ino_ctime/exe_ino_mtime`, `uint64_t exe_ino_ctime_duration_clone_ts/exe_ino_ctime_duration_pidns_start`, `uint32_t vmsize_kb/vmrss_kb/vmswap_kb`, `uint64_t pfmajor/pfminor`, `int64_t vtid/vpid`, `uint64_t pidns_init_start_ts`, `struct scap_cgroup_set cgroups`, `char root[1025]`, `scap_fdinfo* fdlist`, `uint64_t clone_ts`, `uint32_t tty/loginuid`.

Limits ([`scap_limits.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_limits.h)): `SCAP_MAX_PATH_SIZE=1024`, `SCAP_MAX_ARGS_SIZE=4096`, `SCAP_MAX_ENV_SIZE=4096`.

### Process Callbacks ([`scap_procs.h:50-72`](../../../refs/falcosecurity/libs/userspace/libscap/scap_procs.h))

```c
typedef int32_t (*proc_entry_callback)(void* context, char* error, int64_t tid,
                                       scap_threadinfo* tinfo, scap_fdinfo* fdinfo,
                                       scap_threadinfo** new_tinfo);
typedef struct scap_proc_callbacks {
    proc_table_refresh_start m_refresh_start_cb;
    proc_table_refresh_end m_refresh_end_cb;
    proc_entry_callback m_proc_entry_cb;
    void* m_callback_context;
} scap_proc_callbacks;
```

Platform API for process info ([`scap_platform_api.h:71-127`](../../../refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h)): `scap_proc_get()`, `scap_refresh_proc_table()`, `scap_is_thread_alive()`, `scap_getpid_global()`, `scap_get_threadlist()`, `scap_get_fdlist()`, `scap_get_fdinfo()`.

## Capture Files (`.scap`)

Savefile API ([`scap_savefile_api.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_savefile_api.h)):

```c
scap_dumper_t* scap_dump_open(struct scap_platform* platform, const char* fname,
                               compression_mode compress, char* lasterr);
scap_dumper_t* scap_dump_open_fd(struct scap_platform* platform, int fd,
                                  compression_mode compress, bool skip_proc_scan, char* lasterr);
int32_t scap_dump(scap_dumper_t* d, scap_evt* e, uint16_t cpuid, uint32_t flags);
void scap_dump_close(scap_dumper_t* d);
void scap_dump_flush(scap_dumper_t* d);
int64_t scap_dump_get_offset(scap_dumper_t* d);
int64_t scap_dump_ftell(scap_dumper_t* d);
const char* scap_dump_getlasterr(scap_dumper_t* handle);
```

Compression: `SCAP_COMPRESSION_NONE=0`, `SCAP_COMPRESSION_GZIP=1`. Dumper types: `DT_FILE=0`, `DT_MEM=1`, `DT_MANAGED_BUF=2` (3MB initial, 1.25x resize).

## Event Encoding/Decoding

```c
// scap.h:884-952
int32_t scap_event_encode_params(struct scap_sized_buffer event_buf, size_t* event_size,
                                 char* error, ppm_event_code event_type, uint32_t n, ...);
scap_evt* scap_create_event(char* error, uint64_t ts, uint64_t tid,
                            ppm_event_code event_type, uint32_t n, ...);
bool scap_compare_events(scap_evt* curr, scap_evt* expected, char* error);
void scap_print_event(scap_evt* ev, scap_print_info i);
```

Empty-param variants: `scap_event_encode_params_with_empty_params()`, `scap_create_event_with_empty_params()`. Syscall conversions: `scap_ppm_sc_from_name()`, `scap_native_id_to_ppm_sc()`, `scap_ppm_sc_to_native_id()`, `scap_get_ppm_sc_name()`.

## Driver Version Compatibility

```c
// scap.h:104-110
#define SCAP_MINIMUM_DRIVER_API_VERSION    PPM_API_VERSION(8, 0, 0)
#define SCAP_MINIMUM_DRIVER_SCHEMA_VERSION PPM_API_VERSION(4, 1, 0)
#define DEFAULT_DRIVER_BUFFER_BYTES_DIM    8 * 1024 * 1024  // 8MB
```

Runtime queries: `scap_get_driver_api_version()`, `scap_get_driver_schema_version()`, `scap_check_current_engine()` ([`scap.h:833, 1003-1010`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h)).

## Sources

| Topic | Source File |
|-------|-------------|
| Public API header | [`scap.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h) |
| Engine vtable | [`scap_vtable.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_vtable.h) |
| Open arguments | [`scap_open.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_open.h) |
| Return codes | [`scap_const.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_const.h) |
| Size limits | [`scap_limits.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_limits.h) |
| Machine/agent info | [`scap_machine_info.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_machine_info.h) |
| Platform vtable | [`scap_platform_impl.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_platform_impl.h) |
| Platform API | [`scap_platform_api.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_platform_api.h) |
| Process callbacks | [`scap_procs.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_procs.h) |
| Savefile API | [`scap_savefile_api.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_savefile_api.h) |
| Engine handle | [`engine_handle.h`](../../../refs/falcosecurity/libs/userspace/libscap/engine_handle.h) |
| Extended metrics | [`metrics_v2.h`](../../../refs/falcosecurity/libs/userspace/libscap/metrics_v2.h) |
| Event header | [`ppm_events_public.h`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h) |
| Modern eBPF params | [`modern_bpf_public.h`](../../../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h) |
| Kmod params | [`kmod_public.h`](../../../refs/falcosecurity/libs/userspace/libscap/engine/kmod/kmod_public.h) |
| Savefile params | [`savefile_public.h`](../../../refs/falcosecurity/libs/userspace/libscap/engine/savefile/savefile_public.h) |
| Source plugin params | [`source_plugin_public.h`](../../../refs/falcosecurity/libs/userspace/libscap/engine/source_plugin/source_plugin_public.h) |
| Test input params | [`test_input_public.h`](../../../refs/falcosecurity/libs/userspace/libscap/engine/test_input/test_input_public.h) |

## Related Digests

- [`architecture.md`](architecture.md) -- Overall system architecture
- [`libsinsp.md`](libsinsp.md) -- Higher-level libsinsp API
