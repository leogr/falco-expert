# libsinsp (System INSPection Library)

> High-level event processing library: event parsing, state table management, thread/FD tracking, container metadata, and field extraction.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/libs/userspace/libsinsp/`](../refs/falcosecurity/libs/userspace/libsinsp/)

## Overview

libsinsp is the core system inspection library in the Falco event pipeline. It sits between libscap (raw event provider) and the Falco rule engine (event consumer). Its responsibilities are:

- **Event parsing and enrichment** — transforms raw `scap_evt` events from libscap into enriched `sinsp_evt` objects with resolved metadata
- **State tracking** — maintains live tables of threads/processes, file descriptors, users/groups, and containers, updated incrementally from each event
- **Field extraction** — provides the filtercheck system that extracts typed field values (e.g., `proc.name`, `fd.sip`) from events and state for use by filters and rule output formatting
- **Plugin management** — loads, initializes, and manages plugin lifecycle and state table access

**Source:** [`digests/falcosecurity/libs/libsinsp.md`](../digests/falcosecurity/libs/libsinsp.md), [`digests/falcosecurity/libs/state-management.md`](../digests/falcosecurity/libs/state-management.md)

## Architecture

### Directory Structure

```
userspace/libsinsp/
├── sinsp.h / sinsp.cpp          # Main inspector class
├── parsers.h / parsers.cpp      # Event parsing and state update
├── threadinfo.h / threadinfo.cpp # Thread/process state
├── fdinfo.h / fdtable.h         # File descriptor state
├── filter.h / filter.cpp        # Filter compilation and evaluation
├── filter/
│   ├── ast.h                    # Filter AST nodes
│   ├── parser.h                 # Filter expression parser
│   └── escaping.h               # String escaping utilities
├── plugin.h / plugin.cpp        # Plugin support
├── state/
│   ├── table.h                  # State table base classes
│   ├── table_registry.h         # Table registry for plugin access
│   ├── type_info.h              # Runtime type information
│   ├── static_struct.h          # Compile-time field definitions
│   ├── dynamic_struct.h         # Runtime-extensible fields
│   └── table_adapters.h         # STL/pair/value table adapters
├── events/
│   └── sinsp_events.h           # Event set utilities
└── examples/
    └── test.cpp                 # Example application
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/`](../refs/falcosecurity/libs/userspace/libsinsp/)

### Core Class: `sinsp`

The `sinsp` class is the main entry point for all inspection operations. It owns the event parser, state tables, plugin manager, and filter system.

```cpp
// From sinsp.h
class sinsp : public capture_stats_source {
public:
    sinsp(bool with_metrics = false);
    virtual ~sinsp();

    // === Open capture sources ===

    virtual void open_modern_bpf(
        unsigned long driver_buffer_bytes_dim = DEFAULT_DRIVER_BUFFER_BYTES_DIM,
        uint16_t cpus_for_each_buffer = DEFAULT_CPU_FOR_EACH_BUFFER,
        bool online_only = true,
        const libsinsp::events::set<ppm_sc_code>& ppm_sc_of_interest = {});

    virtual void open_kmod(
        unsigned long driver_buffer_bytes_dim = DEFAULT_DRIVER_BUFFER_BYTES_DIM,
        const libsinsp::events::set<ppm_sc_code>& ppm_sc_of_interest = {});

    virtual void open_bpf(
        const std::string& bpf_path,
        unsigned long driver_buffer_bytes_dim = DEFAULT_DRIVER_BUFFER_BYTES_DIM,
        const libsinsp::events::set<ppm_sc_code>& ppm_sc_of_interest = {});

    virtual void open_savefile(const std::string& filename, int fd = 0);

    virtual void open_plugin(
        const std::string& plugin_name,
        const std::string& plugin_open_params,
        sinsp_plugin_platform platform_type);

    virtual void open_gvisor(
        const std::string& config_path,
        const std::string& root_path,
        bool no_events = false,
        int epoll_timeout = -1);

    virtual void open_nodriver(bool full_proc_scan = false);

    void close();

    // === Event retrieval ===

    virtual int32_t next(sinsp_evt** evt);

    // === Filtering ===

    void set_filter(const std::string& filter);
    void set_filter(std::unique_ptr<sinsp_filter> filter,
                    const std::string& filterstring = "");
    std::string get_filter() const;

    // === Configuration ===

    void set_snaplen(uint32_t snaplen);
    void set_dropfailed(bool dropfailed);
    void set_import_users(bool import_users);

    // === State access ===

    sinsp_threadinfo* get_thread(int64_t tid, bool query_os_if_not_found = true);
    sinsp_threadinfo* get_thread_ref(int64_t tid, bool query_os_if_not_found = true);

    // === Machine info ===

    const scap_machine_info* get_machine_info() const;
    const scap_agent_info* get_agent_info() const;

    // === Statistics ===

    void get_capture_stats(scap_stats* stats) const override;
    uint64_t get_num_events() const;
    uint64_t max_buf_used() const;
};
```

**Key methods:**

| Method | Purpose |
|--------|---------|
| `open_modern_bpf()` | Open capture using the modern eBPF driver (default in 0.43) |
| `open_kmod()` | Open capture using the kernel module driver |
| `open_bpf()` | Open capture using the legacy eBPF driver |
| `open_savefile()` | Replay events from a `.scap` capture file |
| `open_plugin()` | Open a plugin-based event source |
| `open_nodriver()` | Open without any driver (proc scan only) |
| `next()` | Retrieve, parse, and enrich the next event; returns `SCAP_SUCCESS`, `SCAP_TIMEOUT`, or error |
| `set_filter()` | Set a capture-level filter (string or pre-compiled) |
| `get_thread()` | Look up thread state by TID, optionally scanning `/proc` on miss |

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/sinsp.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp.h)

### Event Wrapper: `sinsp_evt`

`sinsp_evt` wraps a raw `scap_evt` with methods for event identification, thread context resolution, parameter access, and FD info lookup.

```cpp
class sinsp_evt {
public:
    // Event identification
    uint64_t get_num() const;         // Monotonically increasing event number
    int16_t get_cpuid() const;        // CPU where event occurred
    uint16_t get_type() const;        // Event type (ppm_event_code)
    ppm_event_flags get_flags() const; // Event flags
    uint64_t get_ts() const;          // Timestamp in nanoseconds

    // Thread/process context
    sinsp_threadinfo* get_thread_info(bool query_os_if_not_found = true);
    int64_t get_tid() const;

    // Event parameters
    uint32_t get_num_params() const;
    const sinsp_evt_param* get_param(uint32_t id) const;
    const char* get_param_as_str(uint32_t id, OUT const char** resolved_str,
                                  param_fmt fmt = PF_NORMAL) const;

    // File descriptor info
    sinsp_fdinfo* get_fd_info() const;
    int64_t get_fd_num() const;

    // Event direction
    event_direction get_direction() const;

    // String representation
    std::string get_name() const;

    // Parameter format options
    enum param_fmt {
        PF_NORMAL,        // Default formatting
        PF_JSON,          // JSON format
        PF_SIMPLE,        // Simplified format
        PF_HEX,           // Hexadecimal
        PF_HEXASCII,      // Hex + ASCII
        PF_EOLS,          // End of lines preserved
        PF_EOLS_COMPACT,  // Compact with EOLs
        PF_BASE64,        // Base64 encoded
        PF_JSONEOLS,      // JSON with EOLs
    };
};
```

Each `sinsp_evt` has a direction: either `ENTER` (syscall entry) or `EXIT` (syscall return). The parser correlates enter/exit pairs to extract complete syscall information (e.g., return value from exit, arguments from enter).

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/event.h`](../refs/falcosecurity/libs/userspace/libsinsp/event.h)

## Implementation Details

### Event Parser (`sinsp_parser`)

The event parser is the central component that transforms raw events into enriched state. It is invoked on every event by `sinsp::next()`.

```cpp
class sinsp_parser {
public:
    // Main processing entry — called for every event
    void process_event(sinsp_evt& evt, sinsp_parser_verdict& verdict);

    // Post-processing cleanup
    void event_cleanup(sinsp_evt& evt);

    // Enter/exit event correlation — retrieves cached enter event for an exit event
    bool retrieve_enter_event(sinsp_evt& enter_evt, sinsp_evt& exit_evt) const;

    // Path resolution with dirfd support
    static std::string parse_dirfd(sinsp_evt& evt, std::string_view name, int64_t dirfd);
};
```

**`process_event()` flow:**

1. Identifies the event type
2. Retrieves the associated thread info (or creates it via `/proc` scan)
3. Dispatches to the appropriate syscall-specific parser
4. Updates state tables (thread table, FD table) based on event parameters
5. Sets the parser verdict (e.g., whether to continue processing)

**Syscall-specific parsers:**

The parser contains 40+ private methods for individual syscall families. The key parsers are:

| Parser Method | Syscalls Handled | State Updated |
|---------------|-----------------|---------------|
| `parse_clone_exit` | `clone`, `fork`, `vfork` | Creates new `sinsp_threadinfo` in thread table |
| `parse_execve_exit` | `execve`, `execveat` | Updates exe, args, env, exepath, capabilities |
| `parse_open_openat_creat_exit` | `open`, `openat`, `creat` | Creates new `sinsp_fdinfo` in FD table |
| `parse_close_exit` | `close` | Removes `sinsp_fdinfo` from FD table |
| `parse_connect_exit` | `connect` | Updates socket info on FD (address, port) |
| `parse_accept_exit` | `accept`, `accept4` | Creates new socket FD from accepted connection |

Additional parsers handle: `read`/`write`/`sendto`/`recvfrom`/`recvmsg`/`sendmsg`, `bind`, `listen`, `socket`, `pipe`, `dup`/`dup2`/`dup3`, `chdir`/`fchdir`, `setuid`/`setgid`, `rename`/`renameat`, `mkdir`/`rmdir`, `mount`/`umount`, `setns`/`unshare`, `mmap`, `ptrace`, `memfd_create`, and others.

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/parsers.h`](../refs/falcosecurity/libs/userspace/libsinsp/parsers.h)

### State Tables

#### Thread Table (`sinsp_thread_manager`)

**Class:** `sinsp_thread_manager : public built_in_table<int64_t>`

**Key Type:** `int64_t` (Thread ID — TID)

The thread table is the primary state table, tracking all processes and threads observed in the system.

```cpp
// Access thread by TID
sinsp_threadinfo* sinsp::get_thread(int64_t tid, bool query_os_if_not_found = true);

// Iterate all threads
void sinsp_thread_manager::iterate_threads(
    std::function<bool(sinsp_threadinfo&)> visitor);
```

**`sinsp_threadinfo` Fields by Category:**

**Identity:**

| Field | Type | Description |
|-------|------|-------------|
| `m_tid` | `int64_t` | Thread ID |
| `m_pid` | `int64_t` | Process ID (same as TID for main thread) |
| `m_ptid` | `int64_t` | Parent thread ID |
| `m_sid` | `int64_t` | Session ID |
| `m_pgid` | `int64_t` | Process group ID |
| `m_vpid` | `int64_t` | Virtual PID (in PID namespace) |
| `m_vtid` | `int64_t` | Virtual TID (in PID namespace) |
| `m_vpgid` | `int64_t` | Virtual PGID (in PID namespace) |
| `m_reaper_tid` | `int64_t` | Reaper (subreaper) process TID |

**Executable:**

| Field | Type | Description |
|-------|------|-------------|
| `m_comm` | `string` | Command name (e.g., `"top"`) |
| `m_exe` | `string` | argv[0] (e.g., `"/bin/top"`) |
| `m_exepath` | `string` | Full resolved executable path |
| `m_args` | `vector<string>` | Command line arguments |
| `m_env` | `vector<string>` | Environment variables |
| `m_cwd` | `string` | Current working directory (via `get_cwd()`/`set_cwd()`) |
| `m_root` | `string` | Root path |

**Executable Metadata:**

| Field | Type | Description |
|-------|------|-------------|
| `m_exe_ino` | `uint64_t` | Executable inode number |
| `m_exe_ino_ctime` | `uint64_t` | Inode change time |
| `m_exe_ino_mtime` | `uint64_t` | Inode modification time |
| `m_exe_writable` | `bool` | Executable file is writable by the process |
| `m_exe_upper_layer` | `bool` | Executable is on OverlayFS upper layer |
| `m_exe_lower_layer` | `bool` | Executable is on OverlayFS lower layer |
| `m_exe_from_memfd` | `bool` | Fileless execution (loaded from memfd) |

**Security:**

| Field | Type | Description |
|-------|------|-------------|
| `m_uid` | `uint32_t` | User ID |
| `m_gid` | `uint32_t` | Group ID |
| `m_loginuid` | `uint32_t` | Login UID (audit UID / auid) |
| `m_cap_permitted` | `uint64_t` | Permitted capabilities bitmask |
| `m_cap_effective` | `uint64_t` | Effective capabilities bitmask |
| `m_cap_inheritable` | `uint64_t` | Inheritable capabilities bitmask |

**Resource:**

| Field | Type | Description |
|-------|------|-------------|
| `m_vmsize_kb` | `uint32_t` | Virtual memory size (KB) |
| `m_vmrss_kb` | `uint32_t` | Resident memory size (KB) |
| `m_vmswap_kb` | `uint32_t` | Swap usage (KB) |
| `m_pfmajor` | `uint64_t` | Major page fault count |
| `m_pfminor` | `uint64_t` | Minor page fault count |
| `m_fdlimit` | `int64_t` | File descriptor limit |

**Container/Namespace:**

| Field | Type | Description |
|-------|------|-------------|
| `m_cgroups` | `vector<pair<string, string>>` | Cgroup subsystem name/path pairs |
| `m_pidns_init_start_ts` | `uint64_t` | PID namespace init process start time |
| `container_id` | `string` | Container ID (dynamic field, set by container plugin) |

**Timestamps:**

| Field | Type | Description |
|-------|------|-------------|
| `m_clone_ts` | `uint64_t` | Timestamp when thread was created (clone) |
| `m_lastexec_ts` | `uint64_t` | Timestamp of last exec |
| `m_lastevent_ts` | `uint64_t` | Timestamp of last event on this thread |
| `m_lastevent_fd` | `int64_t` | FD number of last event |

**Thread Group:**

| Field | Type | Description |
|-------|------|-------------|
| `m_tginfo` | `shared_ptr` | Thread group info (shared across threads in same process) |
| `m_children` | `list` | Child thread/process list |
| `m_flags` | `uint32_t` | Thread flags (`PPM_CL_*` from `ppm_events_public.h`) |

**Key methods on `sinsp_threadinfo`:**

| Method | Purpose |
|--------|---------|
| `is_main_thread()` | Returns true if this is the process main thread (TID == PID) |
| `is_in_pid_namespace()` | Returns true if thread is in a non-root PID namespace |
| `is_dead()` | Returns true if thread has exited |
| `get_main_thread()` | Returns the main thread of the thread group |
| `get_fd(int64_t fd)` | Look up FD info by number |
| `loop_fds(visitor)` | Iterate all FDs in this thread's FD table |
| `get_fd_usage_pct()` | Current FD usage as percentage of FD limit |
| `get_fd_opencount()` | Number of open FDs |
| `get_cgroup(subsys)` | Get cgroup path for a given subsystem |

**Thread Lifecycle:**

```
┌─────────────┐
│ Clone Event │ ──→ Create sinsp_threadinfo, set m_clone_ts
└─────────────┘     Add to thread manager

┌─────────────┐
│ Exec Event  │ ──→ Update exe, args, env, exepath, capabilities
└─────────────┘     Set m_lastexec_ts

┌─────────────┐
│ Any Event   │ ──→ Update m_lastevent_ts, m_lastevent_fd
└─────────────┘

┌─────────────┐
│ Exit Event  │ ──→ set_dead(), set PPM_CL_CLOSED flag
└─────────────┘     Schedule for periodic cleanup
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h`](../refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h), [`refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h`](../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h)

#### File Descriptor Table (`sinsp_fdtable`)

**Class:** `sinsp_fdtable : public built_in_table<int64_t>`

**Key Type:** `int64_t` (File descriptor number)

Each thread has an FD table. Threads that share FDs (created with `PPM_CL_CLONE_FILES`) share a single FD table instance with the main thread.

```cpp
// Per-thread FD table access
sinsp_fdtable* sinsp_threadinfo::get_fd_table();

// Iterate all FDs
bool sinsp_threadinfo::loop_fds(sinsp_fdtable::fdtable_const_visitor_t visitor);
```

**`sinsp_fdinfo` Core Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `m_fd` | `int64_t` | File descriptor number |
| `m_type` | `scap_fd_type` | FD type (see types below) |
| `m_name` | `string` | Human-readable name (path, socket address, etc.) |
| `m_name_raw` | `string` | Raw path with minimal sanitization |
| `m_oldname` | `string` | Previous name (for rename change detection) |

**FD Types (`scap_fd_type`):**

| Enum | Value | Description |
|------|-------|-------------|
| `SCAP_FD_UNINITIALIZED` | -1 | Not yet initialized |
| `SCAP_FD_UNKNOWN` | 0 | Unknown type |
| `SCAP_FD_FILE` | 1 | Regular file |
| `SCAP_FD_FILE_V2` | 2 | Regular file (v2 format) |
| `SCAP_FD_DIRECTORY` | 3 | Directory |
| `SCAP_FD_IPV4_SOCK` | 4 | IPv4 socket |
| `SCAP_FD_IPV6_SOCK` | 5 | IPv6 socket |
| `SCAP_FD_IPV4_SERVSOCK` | 6 | IPv4 server (listening) socket |
| `SCAP_FD_IPV6_SERVSOCK` | 7 | IPv6 server (listening) socket |
| `SCAP_FD_FIFO` | 8 | Named pipe (FIFO) |
| `SCAP_FD_UNIX_SOCK` | 9 | Unix domain socket |
| `SCAP_FD_EVENT` | 10 | eventfd |
| `SCAP_FD_UNSUPPORTED` | 11 | Unsupported type |
| `SCAP_FD_SIGNALFD` | 12 | signalfd |
| `SCAP_FD_EVENTPOLL` | 13 | epoll |
| `SCAP_FD_INOTIFY` | 14 | inotify |
| `SCAP_FD_TIMERFD` | 15 | timerfd |
| `SCAP_FD_NETLINK` | 16 | Netlink socket |
| `SCAP_FD_BPF` | 17 | BPF program/map |
| `SCAP_FD_USERFAULTFD` | 18 | userfaultfd |
| `SCAP_FD_IOURING` | 19 | io_uring |
| `SCAP_FD_MEMFD` | 20 | memfd |
| `SCAP_FD_PIDFD` | 21 | pidfd |

**Socket Information (`sinsp_sockinfo` union):**

| Field | Type | Description |
|-------|------|-------------|
| `m_ipv4info` | `ipv4tuple` | IPv4 connection tuple (src/dst IP + port) |
| `m_ipv6info` | `ipv6tuple` | IPv6 connection tuple |
| `m_ipv4serverinfo` | `ipv4serverinfo` | IPv4 server listen address |
| `m_ipv6serverinfo` | `ipv6serverinfo` | IPv6 server listen address |
| `m_unixinfo` | `unix_tuple` | Unix socket peer info |

**File Information:**

| Field | Type | Description |
|-------|------|-------------|
| `m_openflags` | `uint32_t` | Open flags (`PPM_O_*` constants) |
| `m_ino` | `uint64_t` | Inode number |
| `m_dev` | `uint32_t` | Device number |
| `m_mount_id` | `uint32_t` | Mount ID |
| `m_pid` | `int64_t` | For pidfd: referenced PID |

**FD State Flags:**

| Flag | Description |
|------|-------------|
| `FLAGS_FROM_PROC` | FD was loaded from `/proc` (not from live event) |
| `FLAGS_ROLE_CLIENT` | Socket is acting as client |
| `FLAGS_ROLE_SERVER` | Socket is acting as server |
| `FLAGS_IS_SOCKET_PIPE` | Socket being used as a pipe |
| `FLAGS_SOCKET_CONNECTED` | Socket is in connected state |
| `FLAGS_CONNECTION_PENDING` | Connection is in progress |
| `FLAGS_CONNECTION_FAILED` | Connection attempt failed |
| `FLAGS_IS_CLONED` | FD was cloned (dup/fork) |
| `FLAGS_OVERLAY_UPPER` | File is on OverlayFS upper layer |
| `FLAGS_OVERLAY_LOWER` | File is on OverlayFS lower layer |

**FD Lifecycle:**

```
┌────────────┐
│ Open Event │ ──→ Create sinsp_fdinfo, add to FD table
└────────────┘     Parse name, set type and flags

┌────────────┐
│ I/O Events │ ──→ Lookup FD (cached on sinsp_evt), update socket info
└────────────┘

┌─────────────┐
│ Close Event │ ──→ Erase sinsp_fdinfo from FD table
└─────────────┘
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/fdinfo.h`](../refs/falcosecurity/libs/userspace/libsinsp/fdinfo.h), [`refs/falcosecurity/libs/userspace/libsinsp/fdtable.h`](../refs/falcosecurity/libs/userspace/libsinsp/fdtable.h)

#### User/Group Tables

**Class:** `sinsp_usergroup_manager`

Stores user and group information, organized per container.

**User Info (`scap_userinfo`):**

| Field | Type | Description |
|-------|------|-------------|
| `uid` | `uint32_t` | User ID |
| `gid` | `uint32_t` | Primary group ID |
| `name` | `string` | Username |
| `homedir` | `string` | Home directory path |
| `shell` | `string` | Login shell path |

**Group Info (`scap_groupinfo`):**

| Field | Type | Description |
|-------|------|-------------|
| `gid` | `uint32_t` | Group ID |
| `name` | `string` | Group name |

**Storage pattern:**

```cpp
// Per-container user storage: container_id → (uid → userinfo)
unordered_map<std::string, unordered_map<uint32_t, scap_userinfo>>
// Empty string key ("") = host-level users
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/user.h`](../refs/falcosecurity/libs/userspace/libsinsp/user.h)

### State Infrastructure

#### Type System (`typeinfo`)

Runtime type information system for state values, enabling generic access to typed fields.

```cpp
// From state/type_info.h
class typeinfo {
public:
    template<typename T>
    static const typeinfo& of();          // Get typeinfo for compile-time type T

    static typeinfo from(ss_plugin_state_type t);  // Construct from plugin enum

    const char* name() const;             // Human-readable type name
    ss_plugin_state_type type_id() const; // Plugin API type enum
    size_t size() const;                  // Byte size of the type

    void construct(void* p) const;        // Placement-construct at address
    void destroy(void* p) const;          // Destroy at address
    void copy(void* dst, const void* src) const;
    void move(void* dst, void* src) const;
};
```

**Supported state data types (from `ss_plugin_state_type`):**

| Enum | Value | C Type |
|------|-------|--------|
| `SS_PLUGIN_ST_INT8` | 1 | `int8_t` |
| `SS_PLUGIN_ST_INT16` | 2 | `int16_t` |
| `SS_PLUGIN_ST_INT32` | 3 | `int32_t` |
| `SS_PLUGIN_ST_INT64` | 4 | `int64_t` |
| `SS_PLUGIN_ST_UINT8` | 5 | `uint8_t` |
| `SS_PLUGIN_ST_UINT16` | 6 | `uint16_t` |
| `SS_PLUGIN_ST_UINT32` | 7 | `uint32_t` |
| `SS_PLUGIN_ST_UINT64` | 8 | `uint64_t` |
| `SS_PLUGIN_ST_STRING` | 9 | `const char*` |
| `SS_PLUGIN_ST_BOOL` | 10 | `ss_plugin_bool` |
| `SS_PLUGIN_ST_TABLE` | 11 | `ss_plugin_table_t*` (nested table) |

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/state/type_info.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/type_info.h)

#### Static Fields

Compile-time defined fields with fixed memory layout. Used for built-in fields on `sinsp_threadinfo` and `sinsp_fdinfo`.

```cpp
// From state/static_struct.h
struct static_struct {
    struct field_info {
        bool readonly() const;
        const char* name() const;
        const typeinfo& info() const;
        size_t offset() const;     // Fixed byte offset in the struct
        bool valid() const;
    };

    template<typename T>
    struct field_accessor {
        // Bound to a specific field_info
        // Used with get_static_field/set_static_field for type-safe access
    };

    struct field_infos {
        // Hash map: field name → field_info
        // Immutable after construction
    };

    virtual const field_infos* static_fields() const = 0;
};
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/state/static_struct.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/static_struct.h)

#### Dynamic Fields

Runtime-extensible fields. Used by plugins to add custom fields to existing tables (e.g., a plugin adding `myplugin.custom_data` to the thread table).

```cpp
// From state/dynamic_struct.h
struct dynamic_struct {
    struct field_info {
        uint32_t index() const;     // Position in dynamic fields array
        uint64_t defs_id() const;   // Field definition set ID
        bool readonly() const;
        const char* name() const;
        const typeinfo& info() const;
    };

    template<typename T>
    struct field_accessor {
        // Bound to a specific field_info
    };

    struct field_infos {
        // Shared via shared_ptr across all instances
        // Can add new fields at runtime
        template<typename T>
        field_accessor<T> add_field(const char* name);
    };
};
```

**Key differences from static fields:**
- Can be extended at runtime (plugins add fields during `plugin_init()`)
- Field definitions are shared via `shared_ptr` across all table entries
- Field values are stored in separate memory blocks (not at fixed struct offsets)

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/state/dynamic_struct.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/dynamic_struct.h)

#### Table Entry Base

```cpp
// From state/table.h
struct table_entry : public static_struct, public dynamic_struct {
    // Combines both static and dynamic field systems
    // Unified read/write access to all fields
};
```

Both `sinsp_threadinfo` and `sinsp_fdinfo` extend `table_entry`, making them accessible through the generic state table API used by plugins.

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/state/table.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/table.h)

#### Table Interface

```cpp
// Non-templated base
class base_table {
public:
    const typeinfo& key_info() const;
    virtual const char* name() const = 0;
    virtual uint64_t get_size() = 0;
    virtual std::unique_ptr<table_entry> new_entry() = 0;
    virtual std::shared_ptr<table_entry> get_entry(key) = 0;
    virtual std::shared_ptr<table_entry> add_entry(key, entry) = 0;
    virtual bool erase_entry(key) = 0;
    virtual void clear_entries() = 0;
    virtual bool foreach_entry(predicate) = 0;
};

// Templated interface with typed keys
template<typename KeyType>
class table : public base_table {
public:
    virtual std::shared_ptr<table_entry> get_entry(const KeyType& key) = 0;
    virtual std::shared_ptr<table_entry> add_entry(const KeyType& key, entry) = 0;
    virtual bool erase_entry(const KeyType& key) = 0;
};

// Built-in table implementation
template<typename KeyType>
class built_in_table : public table<KeyType> {
public:
    const char* name() const override;
    virtual const static_struct::field_infos* static_fields() const;
    const std::shared_ptr<dynamic_struct::field_infos>& dynamic_fields();
};
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/state/table.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/table.h)

#### Table Registry

The `table_registry` provides discovery and lookup for all state tables, enabling plugins to find and access tables by name.

```cpp
// From state/table_registry.h
class table_registry {
public:
    template<typename KeyType>
    table<KeyType>* get_table(const std::string& name) const;

    template<typename KeyType>
    table<KeyType>* add_table(table<KeyType>* t);

    const std::unordered_map<std::string, base_table*>& tables() const;
};
```

**Built-in tables registered:**

| Table Name | Key Type | Entry Type | Description |
|------------|----------|------------|-------------|
| `threads` | `int64_t` (TID) | `sinsp_threadinfo` | Thread/process state |
| `file_descriptors` | `int64_t` (FD#) | `sinsp_fdinfo` | Per-thread FD state |
| `containers` | `string` (ID) | `table_entry` | Container metadata (from container plugin) |
| `users` | `uint32_t` (UID) | `scap_userinfo` | User info cache |
| `groups` | `uint32_t` (GID) | `scap_groupinfo` | Group info cache |

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/state/table_registry.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/table_registry.h)

#### Table Adapters

Adapters wrap non-table data structures as state tables for the plugin API.

```cpp
// From state/table_adapters.h

// Wrap std::pair as table entry (fields: "first", "second")
template<typename Tfirst, typename Tsecond>
class pair_table_entry_adapter : public table_entry {};

// Wrap a single value as table entry (field: "value")
template<typename T>
class value_table_entry_adapter : public table_entry {};

// Wrap STL container as an index-based table
template<typename Container, typename EntryAdapter>
class stl_container_table_adapter : public table<uint64_t> {};
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/state/table_adapters.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/table_adapters.h)

#### Plugin State Table API

Plugins access state tables through three vtables provided during `plugin_init()` via `ss_plugin_init_tables_input`:

**Table discovery:**

```cpp
typedef struct {
    // List all available tables
    ss_plugin_table_info* (*list_tables)(ss_plugin_owner_t* o, uint32_t* ntables);

    // Get table by name and key type
    ss_plugin_table_t* (*get_table)(ss_plugin_owner_t* o,
                                     const char* name,
                                     ss_plugin_state_type key_type);

    // Register a plugin-owned table
    ss_plugin_rc (*add_table)(ss_plugin_owner_t* o,
                               const ss_plugin_table_input* in);

    // Vtable pointers
    ss_plugin_table_fields_vtable_ext* fields_ext;
    ss_plugin_table_reader_vtable_ext* reader_ext;
    ss_plugin_table_writer_vtable_ext* writer_ext;
} ss_plugin_init_tables_input;
```

**Reader vtable** (`ss_plugin_table_reader_vtable_ext`):

| Function | Purpose |
|----------|---------|
| `get_table_name` | Get table name string |
| `get_table_size` | Get entry count |
| `get_table_entry` | Look up entry by key (must be paired with `release_table_entry`) |
| `read_entry_field` | Read a field value from an entry |
| `release_table_entry` | Release entry acquired by `get_table_entry` |
| `iterate_entries` | Iterate all entries with a callback |

**Writer vtable** (`ss_plugin_table_writer_vtable_ext`):

| Function | Purpose |
|----------|---------|
| `clear_table` | Remove all entries |
| `erase_table_entry` | Delete entry by key |
| `create_table_entry` | Create a new entry (not yet in table) |
| `destroy_table_entry` | Destroy entry that was not added to table |
| `add_table_entry` | Insert entry into table |
| `write_entry_field` | Write a field value on an entry |

**Fields vtable** (`ss_plugin_table_fields_vtable_ext`):

| Function | Purpose |
|----------|---------|
| `list_table_fields` | List all fields on a table |
| `get_table_field` | Get field accessor by name and type |
| `add_table_field` | Add a new dynamic field to the table |

**Source:** [`refs/falcosecurity/libs/userspace/plugin/plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h)

#### Lazy State Loading

When a thread or FD is not found in the in-memory tables (e.g., the process existed before capture started), libsinsp performs lazy loading from `/proc`:

```cpp
// Thread lookup with lazy loading
sinsp_threadinfo* tinfo = inspector->get_thread(tid, /*query_os_if_not_found=*/true);
// If not found in table and query_os_if_not_found is true:
//   1. Scan /proc/<pid>/status, cmdline, exe, cwd, environ
//   2. Construct sinsp_threadinfo from filesystem data
//   3. Insert into thread table
//   4. Return the new entry
```

For FDs, `sinsp_threadinfo::get_fd()` returns `nullptr` if not found; the caller may scan `/proc/<pid>/fd/<num>` for lazy loading.

#### Cleanup

**Thread cleanup:**
- Periodic scan removes expired dead threads
- Threads marked dead are aged out after a configurable `thread_timeout_ns`
- Scan interval is configurable via `threads_purging_scan_time_ns`
- Controlled by `sinsp::set_auto_threads_purging()`, `set_auto_threads_purging_interval_s()`, `set_thread_timeout_s()`

**FD cleanup:**
- Implicit on `close` events (FD entry is erased from table)
- Max table size enforcement prevents unbounded growth

### Plugin Integration

**Class:** `sinsp_plugin_manager`

```cpp
class sinsp_plugin_manager {
public:
    // Load plugin shared library
    std::shared_ptr<sinsp_plugin> load_plugin(const std::string& path);

    // Get all loaded plugins
    const std::vector<std::shared_ptr<sinsp_plugin>>& plugins() const;

    // Find plugin by name
    std::shared_ptr<sinsp_plugin> plugin_by_name(const std::string& name);
};
```

**Opening a plugin event source:**

```cpp
sinsp inspector;

// Load and register plugin
auto plugin = inspector.register_plugin("/path/to/plugin.so");
plugin->init("config_string");

// Open as event source
inspector.open_plugin("plugin_name", "open_params", SINSP_PLATFORM_FULL);
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/plugin.h`](../refs/falcosecurity/libs/userspace/libsinsp/plugin.h)

### Configuration

**Thread management:**

```cpp
void sinsp::set_auto_threads_purging(bool enabled);          // Enable/disable periodic cleanup
void sinsp::set_auto_threads_purging_interval_s(uint32_t val); // Scan interval (seconds)
void sinsp::set_thread_timeout_s(uint32_t val);               // Dead thread timeout (seconds)
```

**Proc scanning:**

```cpp
void sinsp::set_proc_scan_timeout_ms(uint64_t val);       // Timeout for initial /proc scan
void sinsp::set_proc_scan_log_interval_ms(uint64_t val);  // Log interval during scan
```

**Logging:**

```cpp
void sinsp::set_log_callback(sinsp_logger_callback cb);    // Set log callback function
void sinsp::set_log_file(const std::string& filename);     // Log to file
void sinsp::set_log_stderr();                              // Log to stderr
void sinsp::set_min_log_severity(sinsp_logger::severity sev); // Set minimum severity
```

**Source:** [`refs/falcosecurity/libs/userspace/libsinsp/sinsp.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp.h)

## Non-Functional Requirements

### Thread Safety

- The `sinsp` instance and its state tables are designed for single-threaded access within one event processing loop. Each event source in Falco gets its own `sinsp` inspector instance.
- The output queue (external to libsinsp) handles cross-thread communication via TBB concurrent queues.
- Plugin state table access is safe within the event processing callback but should not be accessed from other threads.

### Memory Management

- Thread entries are reference-counted via `shared_ptr` for thread group sharing.
- FD tables are shared between threads created with `CLONE_FILES` — only the main thread owns the physical table.
- Dead thread cleanup is periodic, not immediate, to allow post-exit rule evaluation.
- Dynamic field definitions are shared via `shared_ptr` across all entries of a table.

### Performance of State Lookups

- Thread lookup by TID is an O(1) hash map operation.
- FD lookup within a thread is O(1) hash map by FD number.
- The `sinsp_evt` caches its thread info pointer after the first `get_thread_info()` call per event.
- Lazy `/proc` scanning is expensive (filesystem I/O) and is used only as a fallback when events are observed for threads not yet in the table.

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`architecture-overview.md`](architecture-overview.md) | System context: where libsinsp fits in the pipeline |
| [`libscap.md`](libscap.md) | Raw event provider consumed by libsinsp |
| [`filter-engine.md`](filter-engine.md) | Filter system that extracts fields from libsinsp state |
| [`plugin-system.md`](plugin-system.md) | Plugin API that accesses libsinsp state tables |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Event types and parameters parsed by libsinsp |

## Sources

| Topic | Source File |
|-------|-------------|
| Main inspector class | [`refs/falcosecurity/libs/userspace/libsinsp/sinsp.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp.h) |
| Event wrapper | [`refs/falcosecurity/libs/userspace/libsinsp/event.h`](../refs/falcosecurity/libs/userspace/libsinsp/event.h) |
| Event parser | [`refs/falcosecurity/libs/userspace/libsinsp/parsers.h`](../refs/falcosecurity/libs/userspace/libsinsp/parsers.h) |
| Thread info | [`refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h`](../refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h) |
| Thread manager | [`refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h`](../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h) |
| FD info | [`refs/falcosecurity/libs/userspace/libsinsp/fdinfo.h`](../refs/falcosecurity/libs/userspace/libsinsp/fdinfo.h) |
| FD table | [`refs/falcosecurity/libs/userspace/libsinsp/fdtable.h`](../refs/falcosecurity/libs/userspace/libsinsp/fdtable.h) |
| User/group manager | [`refs/falcosecurity/libs/userspace/libsinsp/user.h`](../refs/falcosecurity/libs/userspace/libsinsp/user.h) |
| Type info system | [`refs/falcosecurity/libs/userspace/libsinsp/state/type_info.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/type_info.h) |
| Static struct fields | [`refs/falcosecurity/libs/userspace/libsinsp/state/static_struct.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/static_struct.h) |
| Dynamic struct fields | [`refs/falcosecurity/libs/userspace/libsinsp/state/dynamic_struct.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/dynamic_struct.h) |
| Table base classes | [`refs/falcosecurity/libs/userspace/libsinsp/state/table.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/table.h) |
| Table registry | [`refs/falcosecurity/libs/userspace/libsinsp/state/table_registry.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/table_registry.h) |
| Table adapters | [`refs/falcosecurity/libs/userspace/libsinsp/state/table_adapters.h`](../refs/falcosecurity/libs/userspace/libsinsp/state/table_adapters.h) |
| Plugin state API | [`refs/falcosecurity/libs/userspace/plugin/plugin_api.h`](../refs/falcosecurity/libs/userspace/plugin/plugin_api.h) |
| Filter checks | [`refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck.h) |
| Filter system | [`refs/falcosecurity/libs/userspace/libsinsp/filter.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter.h) |
| Plugin manager | [`refs/falcosecurity/libs/userspace/libsinsp/plugin.h`](../refs/falcosecurity/libs/userspace/libsinsp/plugin.h) |
| libsinsp digest | [`digests/falcosecurity/libs/libsinsp.md`](../digests/falcosecurity/libs/libsinsp.md) |
| State management digest | [`digests/falcosecurity/libs/state-management.md`](../digests/falcosecurity/libs/state-management.md) |
