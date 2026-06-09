# State Management

## Overview

The state management system tracks system state across events and provides a unified API for both built-in and plugin-defined state tables.

**Key Components:**
- **Built-in Tables** - Thread/process, file descriptor, user/group, container state
- **Plugin State API** - Allows plugins to access built-in tables and define custom tables
- **Type System** - Runtime type information for state values
- **Static/Dynamic Fields** - Compile-time and runtime-extensible field definitions

**Location:** `userspace/libsinsp/state/`

## Built-in State Tables

### Thread/Process Table

**Class:** `sinsp_thread_manager : public built_in_table<int64_t>`
**Location:** `userspace/libsinsp/thread_manager.h`, `threadinfo.h`
**Key Type:** `int64_t` (Thread ID)

The thread table tracks all processes and threads in the system.

#### sinsp_threadinfo Fields

**Identity Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `m_tid` | int64_t | Thread ID |
| `m_pid` | int64_t | Process ID (same as TID for main thread) |
| `m_ptid` | int64_t | Parent thread ID |
| `m_sid` | int64_t | Session ID |
| `m_pgid` | int64_t | Process group ID |
| `m_vpid` | int64_t | Virtual PID (in namespace) |
| `m_vtid` | int64_t | Virtual TID (in namespace) |
| `m_reaper_tid` | int64_t | Reaper process TID |

**Executable Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `m_comm` | string | Command name (comm) |
| `m_exe` | string | Executable (argv[0]) |
| `m_exepath` | string | Full executable path |
| `m_args` | vector\<string\> | Command line arguments |
| `m_env` | vector\<string\> | Environment variables |
| `m_cwd` | string | Current working directory |
| `m_root` | string | Root path |

**Security Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `m_uid` | uint32_t | User ID |
| `m_gid` | uint32_t | Group ID |
| `m_loginuid` | uint32_t | Login UID (auid) |
| `m_cap_permitted` | uint64_t | Permitted capabilities |
| `m_cap_effective` | uint64_t | Effective capabilities |
| `m_cap_inheritable` | uint64_t | Inheritable capabilities |

**Resource Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `m_vmsize_kb` | uint32_t | Virtual memory size (KB) |
| `m_vmrss_kb` | uint32_t | Resident memory size (KB) |
| `m_vmswap_kb` | uint32_t | Swap usage (KB) |
| `m_pfmajor` | uint64_t | Major page faults |
| `m_pfminor` | uint64_t | Minor page faults |
| `m_fdlimit` | int64_t | FD limit |

**Executable Tracking:**

| Field | Type | Description |
|-------|------|-------------|
| `m_exe_ino` | uint64_t | Executable inode |
| `m_exe_ino_ctime` | uint64_t | Inode change time |
| `m_exe_ino_mtime` | uint64_t | Inode modify time |
| `m_exe_writable` | bool | Executable is writable |
| `m_exe_upper_layer` | bool | On overlay upper layer |
| `m_exe_lower_layer` | bool | On overlay lower layer |
| `m_exe_from_memfd` | bool | Fileless execution (memfd) |

**Timestamp Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `m_clone_ts` | uint64_t | Clone timestamp |
| `m_lastexec_ts` | uint64_t | Last exec timestamp |
| `m_lastevent_ts` | uint64_t | Last event timestamp |
| `m_lastevent_fd` | int64_t | Last event FD number |

**Container/Namespace:**

| Field | Type | Description |
|-------|------|-------------|
| `m_cgroups` | vector\<pair\> | cgroup subsystem pairs |
| `m_pidns_init_start_ts` | uint64_t | PID namespace init time |
| `container_id` | string | Container ID (dynamic field) |

**Thread Group:**

| Field | Type | Description |
|-------|------|-------------|
| `m_tginfo` | shared_ptr | Thread group info reference |
| `m_children` | list | Child thread list |

### File Descriptor Table

**Class:** `sinsp_fdtable : public built_in_table<int64_t>`
**Location:** `userspace/libsinsp/fdtable.h`, `fdinfo.h`
**Key Type:** `int64_t` (FD number)

Each thread has an FD table (shared with main thread if `PPM_CL_CLONE_FILES`).

#### sinsp_fdinfo Fields

**Core Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `m_fd` | int64_t | File descriptor number |
| `m_type` | scap_fd_type | FD type (see below) |
| `m_name` | string | Human-readable name |
| `m_name_raw` | string | Raw path (minimal sanitization) |
| `m_oldname` | string | Previous name (change detection) |

**FD Types (scap_fd_type):**

| Type | Description |
|------|-------------|
| `SCAP_FD_FILE` | Regular file |
| `SCAP_FD_FILE_V2` | Regular file (v2) |
| `SCAP_FD_DIRECTORY` | Directory |
| `SCAP_FD_IPV4_SOCK` | IPv4 socket |
| `SCAP_FD_IPV6_SOCK` | IPv6 socket |
| `SCAP_FD_IPV4_SERVSOCK` | IPv4 server socket |
| `SCAP_FD_IPV6_SERVSOCK` | IPv6 server socket |
| `SCAP_FD_UNIX_SOCK` | Unix domain socket |
| `SCAP_FD_FIFO` | Named pipe |
| `SCAP_FD_EVENT` | eventfd |
| `SCAP_FD_EVENTPOLL` | epoll |
| `SCAP_FD_INOTIFY` | inotify |
| `SCAP_FD_TIMERFD` | timerfd |
| `SCAP_FD_SIGNALFD` | signalfd |
| `SCAP_FD_NETLINK` | Netlink socket |
| `SCAP_FD_BPF` | BPF program/map |
| `SCAP_FD_MEMFD` | memfd |
| `SCAP_FD_PIDFD` | pidfd |
| `SCAP_FD_USERFAULTFD` | userfaultfd |
| `SCAP_FD_IOURING` | io_uring |

**Socket Information (union sinsp_sockinfo):**

| Field | Type | Description |
|-------|------|-------------|
| `m_ipv4info` | ipv4tuple | IPv4 socket tuple |
| `m_ipv6info` | ipv6tuple | IPv6 socket tuple |
| `m_ipv4serverinfo` | ipv4serverinfo | IPv4 server info |
| `m_ipv6serverinfo` | ipv6serverinfo | IPv6 server info |
| `m_unixinfo` | unix_tuple | Unix socket info |

**File Information:**

| Field | Type | Description |
|-------|------|-------------|
| `m_openflags` | uint32_t | Open flags (PPM_O_*) |
| `m_ino` | uint64_t | Inode number |
| `m_dev` | uint32_t | Device number |
| `m_mount_id` | uint32_t | Mount ID |
| `m_pid` | int64_t | For pidfd: referenced PID |

**FD State Flags:**

| Flag | Description |
|------|-------------|
| `FLAGS_FROM_PROC` | Loaded from /proc |
| `FLAGS_ROLE_CLIENT` | Socket is client |
| `FLAGS_ROLE_SERVER` | Socket is server |
| `FLAGS_IS_SOCKET_PIPE` | Socket used as pipe |
| `FLAGS_SOCKET_CONNECTED` | Socket connected |
| `FLAGS_CONNECTION_PENDING` | Connection in progress |
| `FLAGS_CONNECTION_FAILED` | Connection failed |
| `FLAGS_IS_CLONED` | FD is cloned |
| `FLAGS_OVERLAY_UPPER` | On overlay upper layer |
| `FLAGS_OVERLAY_LOWER` | On overlay lower layer |

### User/Group Tables

**Class:** `sinsp_usergroup_manager`
**Location:** `userspace/libsinsp/user.h`

Stores user and group information per container.

**User Info (scap_userinfo):**

| Field | Type | Description |
|-------|------|-------------|
| `uid` | uint32_t | User ID |
| `gid` | uint32_t | Primary group ID |
| `name` | string | Username |
| `homedir` | string | Home directory |
| `shell` | string | Login shell |

**Group Info (scap_groupinfo):**

| Field | Type | Description |
|-------|------|-------------|
| `gid` | uint32_t | Group ID |
| `name` | string | Group name |

**Storage Pattern:**
```cpp
// Per-container user storage
unordered_map<std::string, unordered_map<uint32_t, scap_userinfo>>
// Empty string key = host users
```

### Container Table

**Location:** `userspace/libsinsp/plugin_tables.h`
**Key Type:** `std::string` (Container ID)

Created by container plugins, accessible via plugin API.

**Common Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `user` | string | Container user |
| `ip` | string | Container IP address |
| (dynamic) | various | Plugin-defined fields |

## Plugin State Table API

### State Data Types

```cpp
// From plugin_types.h
typedef enum {
    SS_PLUGIN_ST_INT8 = 1,
    SS_PLUGIN_ST_INT16 = 2,
    SS_PLUGIN_ST_INT32 = 3,
    SS_PLUGIN_ST_INT64 = 4,
    SS_PLUGIN_ST_UINT8 = 5,
    SS_PLUGIN_ST_UINT16 = 6,
    SS_PLUGIN_ST_UINT32 = 7,
    SS_PLUGIN_ST_UINT64 = 8,
    SS_PLUGIN_ST_STRING = 9,
    SS_PLUGIN_ST_BOOL = 10,
    SS_PLUGIN_ST_TABLE = 11,  // Nested table
} ss_plugin_state_type;
```

### State Data Union

```cpp
typedef union {
    int8_t s8;
    int16_t s16;
    int32_t s32;
    int64_t s64;
    uint8_t u8;
    uint16_t u16;
    uint32_t u32;
    uint64_t u64;
    const char* str;
    ss_plugin_bool b;
    ss_plugin_table_t* table;
} ss_plugin_state_data;
```

### Table Discovery

During `plugin_init()`, plugins receive table access via `ss_plugin_init_tables_input`:

```cpp
typedef struct {
    // List all available tables
    ss_plugin_table_info* (*list_tables)(ss_plugin_owner_t* o,
                                          uint32_t* ntables);

    // Get table by name and key type
    ss_plugin_table_t* (*get_table)(ss_plugin_owner_t* o,
                                     const char* name,
                                     ss_plugin_state_type key_type);

    // Register plugin-owned table
    ss_plugin_rc (*add_table)(ss_plugin_owner_t* o,
                               const ss_plugin_table_input* in);

    // Vtable pointers
    ss_plugin_table_fields_vtable_ext* fields_ext;
    ss_plugin_table_reader_vtable_ext* reader_ext;
    ss_plugin_table_writer_vtable_ext* writer_ext;
} ss_plugin_init_tables_input;
```

### Reader Vtable

```cpp
typedef struct {
    // Get table name
    const char* (*get_table_name)(ss_plugin_table_t* t);

    // Get entry count
    uint64_t (*get_table_size)(ss_plugin_table_t* t);

    // Lookup entry by key
    ss_plugin_table_entry_t* (*get_table_entry)(
        ss_plugin_table_t* t,
        const ss_plugin_state_data* key);

    // Read field from entry
    ss_plugin_rc (*read_entry_field)(
        ss_plugin_table_t* t,
        ss_plugin_table_entry_t* e,
        const ss_plugin_table_field_t* f,
        ss_plugin_state_data* out);

    // Release entry (must pair with get_table_entry)
    void (*release_table_entry)(ss_plugin_table_t* t,
                                 ss_plugin_table_entry_t* e);

    // Iterate all entries
    ss_plugin_bool (*iterate_entries)(
        ss_plugin_table_t* t,
        ss_plugin_table_iterator_func_t it,
        ss_plugin_table_iterator_state_t* s);
} ss_plugin_table_reader_vtable_ext;
```

### Writer Vtable

```cpp
typedef struct {
    // Clear all entries
    ss_plugin_rc (*clear_table)(ss_plugin_table_t* t);

    // Delete entry by key
    ss_plugin_rc (*erase_table_entry)(
        ss_plugin_table_t* t,
        const ss_plugin_state_data* key);

    // Create new entry (not yet in table)
    ss_plugin_table_entry_t* (*create_table_entry)(ss_plugin_table_t* t);

    // Destroy entry (if not added to table)
    void (*destroy_table_entry)(ss_plugin_table_t* t,
                                 ss_plugin_table_entry_t* e);

    // Add entry to table
    ss_plugin_table_entry_t* (*add_table_entry)(
        ss_plugin_table_t* t,
        const ss_plugin_state_data* key,
        ss_plugin_table_entry_t* entry);

    // Write field to entry
    ss_plugin_rc (*write_entry_field)(
        ss_plugin_table_t* t,
        ss_plugin_table_entry_t* e,
        const ss_plugin_table_field_t* f,
        const ss_plugin_state_data* in);
} ss_plugin_table_writer_vtable_ext;
```

### Fields Vtable

```cpp
typedef struct {
    // List all fields
    const ss_plugin_table_fieldinfo* (*list_table_fields)(
        ss_plugin_table_t* t,
        uint32_t* nfields);

    // Get field accessor
    ss_plugin_table_field_t* (*get_table_field)(
        ss_plugin_table_t* t,
        const char* name,
        ss_plugin_state_type data_type);

    // Add new dynamic field
    ss_plugin_table_field_t* (*add_table_field)(
        ss_plugin_table_t* t,
        const char* name,
        ss_plugin_state_type data_type);
} ss_plugin_table_fields_vtable_ext;
```

### Plugin Table Registration

Plugins can register their own tables:

```cpp
typedef struct {
    const char* name;                         // Table name
    ss_plugin_state_type key_type;            // Key type
    ss_plugin_table_t* table;                 // Table pointer
    ss_plugin_table_reader_vtable_ext* reader_ext;
    ss_plugin_table_writer_vtable_ext* writer_ext;
    ss_plugin_table_fields_vtable_ext* fields_ext;
} ss_plugin_table_input;
```

## State Infrastructure

### Type Info System

**Location:** `userspace/libsinsp/state/type_info.h`

Runtime type information for state values:

```cpp
class typeinfo {
public:
    template<typename T>
    static const typeinfo& of();          // Get typeinfo for type T

    static typeinfo from(ss_plugin_state_type t);  // From plugin enum

    const char* name() const;             // Type name string
    ss_plugin_state_type type_id() const; // Plugin type enum
    size_t size() const;                  // Byte size

    void construct(void* p) const;        // Construct in memory
    void destroy(void* p) const;          // Destroy in memory
    void copy(void* dst, const void* src) const;
    void move(void* dst, void* src) const;
};
```

### Static Fields

**Location:** `userspace/libsinsp/state/static_struct.h`

Compile-time defined fields with fixed memory layout:

```cpp
struct static_struct {
    struct field_info {
        bool readonly() const;
        const char* name() const;
        const typeinfo& info() const;
        size_t offset() const;
        bool valid() const;
    };

    template<typename T>
    struct field_accessor {
        // Bound to specific field_info
        // Used with get_static_field/set_static_field
    };

    struct field_infos {
        // Hash map: field name -> field_info
        // Immutable after construction
    };

    virtual const field_infos* static_fields() const = 0;
};
```

### Dynamic Fields

**Location:** `userspace/libsinsp/state/dynamic_struct.h`

Runtime-extensible fields:

```cpp
struct dynamic_struct {
    struct field_info {
        uint32_t index() const;     // Position in array
        uint64_t defs_id() const;   // Field definition set ID
        bool readonly() const;
        const char* name() const;
        const typeinfo& info() const;
    };

    template<typename T>
    struct field_accessor {
        // Bound to specific field_info
    };

    struct field_infos {
        // Shared via shared_ptr
        // Can add fields at runtime
        template<typename T>
        field_accessor<T> add_field(const char* name);
    };
};
```

**Key Differences from Static:**
- Can be extended at runtime
- Shared across all instances via `shared_ptr`
- Fields stored in separate memory blocks
- Used for plugin-defined fields

### Table Entry

```cpp
// From state/table.h
struct table_entry : public static_struct, public dynamic_struct {
    // Combines both field systems
    // Unified access to static and dynamic fields
};
```

### Table Interface

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

// Templated interface
template<typename KeyType>
class table : public base_table {
public:
    virtual std::shared_ptr<table_entry> get_entry(const KeyType& key) = 0;
    virtual std::shared_ptr<table_entry> add_entry(const KeyType& key,
                                                    entry) = 0;
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

### Table Registry

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

### Table Adapters

**Location:** `userspace/libsinsp/state/table_adapters.h`

Wrap non-table data structures as tables:

```cpp
// Wrap std::pair as table entry
template<typename Tfirst, typename Tsecond>
class pair_table_entry_adapter : public table_entry {
    // Fields: "first", "second"
};

// Wrap single value as table entry
template<typename T>
class value_table_entry_adapter : public table_entry {
    // Field: "value"
};

// Wrap STL container as table
template<typename Container, typename EntryAdapter>
class stl_container_table_adapter : public table<uint64_t> {
    // Index-based access to container elements
};
```

## Event-Driven State Updates

### Thread State Lifecycle

```
┌─────────────┐
│ Clone Event │ ──→ Create threadinfo, set m_clone_ts
└─────────────┘     Add to thread manager

┌─────────────┐
│ Exec Event  │ ──→ Update exe, args, env
└─────────────┘     Set m_lastexec_ts

┌─────────────┐
│ Any Event   │ ──→ Update m_lastevent_ts, m_lastevent_fd
└─────────────┘

┌─────────────┐
│ Exit Event  │ ──→ set_dead(), set PPM_CL_CLOSED
└─────────────┘     Schedule for cleanup
```

### FD State Lifecycle

```
┌────────────┐
│ Open Event │ ──→ Create fdinfo, add to FD table
└────────────┘     Parse name, set type and flags

┌────────────┐
│ I/O Events │ ──→ Lookup FD (cached), update socket info
└────────────┘

┌─────────────┐
│ Close Event │ ──→ Erase from FD table
└─────────────┘
```

### Lazy State Loading

When thread/FD not found in table:

```cpp
// Thread lookup
threadinfo* tinfo = inspector->get_thread(tid, lookup_only);
// If not lookup_only and not found:
//   - Scan /proc/<pid> for thread info
//   - Load exe, args, env from filesystem
//   - Create threadinfo entry

// FD lookup
sinsp_fdinfo* fd = tinfo->get_fd(fd_num);
// Returns null if not found
// Caller may scan /proc/<pid>/fd for lazy load
```

### Cleanup

**Thread Cleanup:**
- Periodic scan removes expired threads
- Dead threads aged out after `thread_timeout_ns`
- Configurable via `threads_purging_scan_time_ns`

**FD Cleanup:**
- Implicit on close event
- Max table size enforcement

## Plugin Usage Patterns

### Reading from Built-in Tables

```c
// During plugin_init()
ss_plugin_table_t* threads = get_table(owner, "threads",
                                        SS_PLUGIN_ST_INT64);
ss_plugin_table_field_t* pid_field =
    get_table_field(threads, "pid", SS_PLUGIN_ST_INT64);
ss_plugin_table_field_t* comm_field =
    get_table_field(threads, "comm", SS_PLUGIN_ST_STRING);

// During event processing
ss_plugin_state_data key = { .s64 = tid };
ss_plugin_table_entry_t* entry = get_table_entry(threads, &key);
if (entry) {
    ss_plugin_state_data pid_val;
    read_entry_field(threads, entry, pid_field, &pid_val);
    int64_t pid = pid_val.s64;

    ss_plugin_state_data comm_val;
    read_entry_field(threads, entry, comm_field, &comm_val);
    const char* comm = comm_val.str;

    release_table_entry(threads, entry);
}
```

### Adding Dynamic Fields

```c
// Add custom field to thread table
ss_plugin_table_field_t* my_field =
    add_table_field(threads, "myplugin.custom_data",
                    SS_PLUGIN_ST_STRING);

// Write to field
ss_plugin_state_data value = { .str = "custom value" };
write_entry_field(threads, entry, my_field, &value);
```

### Registering Custom Tables

```c
// Define table structure
ss_plugin_table_input table_input = {
    .name = "my_custom_table",
    .key_type = SS_PLUGIN_ST_STRING,
    .table = my_table_ptr,
    .reader_ext = &my_reader_vtable,
    .writer_ext = &my_writer_vtable,
    .fields_ext = &my_fields_vtable,
};

// Register during init
add_table(owner, &table_input);
```

### Iterating Tables

```c
ss_plugin_bool my_iterator(ss_plugin_table_iterator_state_t* s,
                           ss_plugin_table_entry_t* e) {
    // Process entry
    // Return true to continue, false to stop
    return 1;
}

ss_plugin_table_iterator_state_t state = { .data = user_context };
iterate_entries(threads, my_iterator, &state);
```

## Built-in Tables Summary

| Table Name | Key Type | Entry Type | Description |
|------------|----------|------------|-------------|
| `threads` | int64_t (TID) | sinsp_threadinfo | Thread/process state |
| `file_descriptors` | int64_t (FD#) | sinsp_fdinfo | Per-thread FD state |
| `containers` | string (ID) | table_entry | Container metadata |
| `users` | uint32_t (UID) | scap_userinfo | User info cache |
| `groups` | uint32_t (GID) | scap_groupinfo | Group info cache |

## Sources

| Topic | Source File |
|-------|-------------|
| Thread manager | [`userspace/libsinsp/thread_manager.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h) |
| Thread info | [`userspace/libsinsp/threadinfo.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h) |
| FD table | [`userspace/libsinsp/fdtable.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/fdtable.h) |
| FD info | [`userspace/libsinsp/fdinfo.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/fdinfo.h) |
| User manager | [`userspace/libsinsp/user.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/user.h) |
| State type info | [`userspace/libsinsp/state/type_info.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/state/type_info.h) |
| Static struct | [`userspace/libsinsp/state/static_struct.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/state/static_struct.h) |
| Dynamic struct | [`userspace/libsinsp/state/dynamic_struct.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/state/dynamic_struct.h) |
| Table base | [`userspace/libsinsp/state/table.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/state/table.h) |
| Table registry | [`userspace/libsinsp/state/table_registry.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/state/table_registry.h) |
| Plugin state API | [`userspace/plugin/plugin_api.h`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_api.h) |

## Related Digests

- [libsinsp.md](libsinsp.md) - State engine overview
- [plugin-framework.md](plugin-framework.md) - Plugin API
- [filtering.md](filtering.md) - Field extraction from state
- [api-reference.md](api-reference.md) - Event types that update state
