# libsinsp (System INSPection Library)

## Overview

libsinsp is the high-level system inspection library that provides:

- Event parsing and enrichment
- Process and file descriptor state tracking
- Container and user/group information
- Filter compilation and evaluation
- Plugin management

**Location:** `userspace/libsinsp/`

## Core Classes

### sinsp - Main Entry Point

```cpp
// From sinsp.h
class sinsp : public capture_stats_source {
public:
    sinsp(bool with_metrics = false);
    virtual ~sinsp();

    // Open capture sources
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

    // Close capture
    void close();

    // Get next event
    virtual int32_t next(sinsp_evt** evt);

    // Filtering
    void set_filter(const std::string& filter);
    void set_filter(std::unique_ptr<sinsp_filter> filter,
                    const std::string& filterstring = "");
    std::string get_filter() const;

    // Configuration
    void set_snaplen(uint32_t snaplen);
    void set_dropfailed(bool dropfailed);
    void set_import_users(bool import_users);

    // State access
    sinsp_threadinfo* get_thread(int64_t tid, bool query_os_if_not_found = true);
    sinsp_threadinfo* get_thread_ref(int64_t tid, bool query_os_if_not_found = true);

    // Machine info
    const scap_machine_info* get_machine_info() const;
    const scap_agent_info* get_agent_info() const;

    // Statistics
    void get_capture_stats(scap_stats* stats) const override;
    uint64_t get_num_events() const;
    uint64_t max_buf_used() const;
};
```

### sinsp_evt - Event Wrapper

```cpp
class sinsp_evt {
public:
    // Event identification
    uint64_t get_num() const;
    int16_t get_cpuid() const;
    uint16_t get_type() const;
    ppm_event_flags get_flags() const;
    uint64_t get_ts() const;

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

### sinsp_threadinfo - Thread/Process State

```cpp
// From threadinfo.h
class sinsp_threadinfo : public libsinsp::state::table_entry {
public:
    // Core identification
    int64_t m_tid;      // Thread ID
    int64_t m_pid;      // Process ID
    int64_t m_ptid;     // Parent thread ID
    int64_t m_sid;      // Session ID

    // Names and paths
    std::string m_comm;     // Command name (e.g., "top")
    std::string m_exe;      // argv[0] (e.g., "/bin/top")
    std::string m_exepath;  // Full executable path

    // Arguments and environment
    std::vector<std::string> m_args;  // Command line arguments
    std::vector<std::string> m_env;   // Environment variables

    // Working directory
    std::string get_cwd();
    void set_cwd(const std::string& v);

    // Credentials
    uint32_t m_uid;
    uint32_t m_gid;
    uint32_t m_loginuid;
    uint64_t m_cap_permitted;
    uint64_t m_cap_effective;
    uint64_t m_cap_inheritable;

    // Resource limits
    int64_t m_fdlimit;

    // Flags (PPM_CL_* from ppm_events_public.h)
    uint32_t m_flags;

    // Memory stats
    uint32_t m_vmsize_kb;
    uint32_t m_vmrss_kb;
    uint32_t m_vmswap_kb;
    uint64_t m_pfmajor;
    uint64_t m_pfminor;

    // Namespace info
    int64_t m_vtid;   // Virtual TID (in namespace)
    int64_t m_vpid;   // Virtual PID (in namespace)
    int64_t m_vpgid;  // Virtual PGID
    int64_t m_pgid;   // Process group ID

    // Executable metadata
    uint64_t m_exe_ino;
    uint64_t m_exe_ino_ctime;
    uint64_t m_exe_ino_mtime;
    bool m_exe_writable;
    bool m_exe_upper_layer;  // OverlayFS upper
    bool m_exe_lower_layer;  // OverlayFS lower
    bool m_exe_from_memfd;   // Fileless execution

    // Cgroups
    using cgroups_t = std::vector<std::pair<std::string, std::string>>;
    cgroups_t m_cgroups;

    // Methods
    std::string get_comm() const;
    std::string get_exe() const;
    std::string get_exepath() const;
    const std::vector<std::string>& get_env();
    std::string get_env(const std::string& name);

    bool is_main_thread() const;
    bool is_in_pid_namespace() const;
    bool is_invalid() const;
    bool is_dead() const;

    sinsp_threadinfo* get_main_thread();
    uint64_t get_num_threads() const;

    // File descriptors
    sinsp_fdinfo* get_fd(int64_t fd);
    bool loop_fds(sinsp_fdtable::fdtable_const_visitor_t visitor);
    uint64_t get_fd_usage_pct();
    uint64_t get_fd_opencount() const;
    uint64_t get_fd_limit();

    // Cgroup access
    const std::string& get_cgroup(const std::string& subsys) const;
};
```

### sinsp_fdinfo - File Descriptor State

```cpp
class sinsp_fdinfo {
public:
    int64_t m_fd;           // File descriptor number
    scap_fd_type m_type;    // Type (file, socket, pipe, etc.)
    std::string m_name;     // Name/path
    std::string m_oldname;  // Previous name (for tracking changes)
    uint32_t m_flags;       // Open flags

    // Type-specific fields
    union {
        struct {
            uint64_t m_ino;      // Inode
            uint64_t m_dev;      // Device
            uint32_t m_mount_id; // Mount ID
        } file;

        struct {
            uint8_t m_l4proto;   // L4 protocol (TCP, UDP)
            bool m_is_server;   // Server socket?
            // Address info
            ipv4tuple m_info_v4;
            ipv6tuple m_info_v6;
        } socket;

        struct {
            uint64_t m_ino;
        } pipe;
    };
};

// File descriptor types
enum scap_fd_type {
    SCAP_FD_UNINITIALIZED = -1,
    SCAP_FD_UNKNOWN = 0,
    SCAP_FD_FILE = 1,
    SCAP_FD_FILE_V2 = 2,
    SCAP_FD_DIRECTORY = 3,
    SCAP_FD_IPV4_SOCK = 4,
    SCAP_FD_IPV6_SOCK = 5,
    SCAP_FD_IPV4_SERVSOCK = 6,
    SCAP_FD_IPV6_SERVSOCK = 7,
    SCAP_FD_FIFO = 8,
    SCAP_FD_UNIX_SOCK = 9,
    SCAP_FD_EVENT = 10,
    SCAP_FD_UNSUPPORTED = 11,
    SCAP_FD_SIGNALFD = 12,
    SCAP_FD_EVENTPOLL = 13,
    SCAP_FD_INOTIFY = 14,
    SCAP_FD_TIMERFD = 15,
    SCAP_FD_NETLINK = 16,
    SCAP_FD_BPF = 17,
    SCAP_FD_USERFAULTFD = 18,
    SCAP_FD_IOURING = 19,
    SCAP_FD_MEMFD = 20,
    SCAP_FD_PIDFD = 21,
};
```

## Event Parser

The parser (`parsers.h`) processes raw events and updates state:

```cpp
class sinsp_parser {
public:
    // Main processing entry
    void process_event(sinsp_evt& evt, sinsp_parser_verdict& verdict);
    void event_cleanup(sinsp_evt& evt);

    // Enter/exit event correlation
    bool retrieve_enter_event(sinsp_evt& enter_evt, sinsp_evt& exit_evt) const;

    // Path resolution
    static std::string parse_dirfd(sinsp_evt& evt, std::string_view name, int64_t dirfd);

private:
    // Syscall-specific parsers
    void parse_clone_exit(sinsp_evt& evt, sinsp_parser_verdict& verdict) const;
    void parse_execve_exit(sinsp_evt& evt, sinsp_parser_verdict& verdict) const;
    void parse_open_openat_creat_exit(sinsp_evt& evt) const;
    void parse_close_exit(sinsp_evt& evt, sinsp_parser_verdict& verdict) const;
    void parse_connect_exit(sinsp_evt& evt, sinsp_parser_verdict& verdict) const;
    void parse_accept_exit(sinsp_evt& evt, sinsp_parser_verdict& verdict) const;
    // ... 40+ more syscall parsers
};
```

## Filter System

### Filter Syntax

libsinsp supports a rich filter syntax:

```
# Field comparisons
proc.name = "nginx"
fd.type = "ipv4"
evt.type in (open, openat)
proc.cmdline contains "curl"

# Logical operators
proc.name = "sshd" and fd.type = "ipv4"
proc.name = "bash" or proc.name = "sh"
not proc.name = "systemd"

# Field arguments
fd.sip[0] = "10.0.0.1"
proc.env[HOME] = "/root"
```

### Filter API

```cpp
// Compile filter from string
void sinsp::set_filter(const std::string& filter);

// Use pre-compiled filter
void sinsp::set_filter(std::unique_ptr<sinsp_filter> filter,
                       const std::string& filterstring = "");

// Check if event matches
bool sinsp::run_filters_on_evt(sinsp_evt* evt) const;

// Access filter AST
const std::shared_ptr<libsinsp::filter::ast::expr>& sinsp::get_filter_ast();
```

### Filter Checks (Field Extractors)

```cpp
// Base class for filter field extractors
class sinsp_filter_check {
public:
    // Get field value from event
    virtual uint8_t* extract(sinsp_evt* evt, OUT uint32_t* len,
                             bool sanitize_strings = true) = 0;

    // Compare field value
    virtual bool compare(sinsp_evt* evt);

    // Field metadata
    virtual const filtercheck_field_info* get_fields() const = 0;
};

// Example: process fields
class sinsp_filter_check_proc : public sinsp_filter_check {
    // Extracts: proc.pid, proc.name, proc.cmdline, proc.exe, etc.
};

// Example: fd fields
class sinsp_filter_check_fd : public sinsp_filter_check {
    // Extracts: fd.name, fd.type, fd.sip, fd.sport, etc.
};
```

## State Tables

libsinsp maintains several state tables exposed via the plugin API:

### Thread Table

```cpp
// Access thread by ID
sinsp_threadinfo* sinsp::get_thread(int64_t tid, bool query_os_if_not_found = true);

// Iterate all threads
void sinsp_thread_manager::iterate_threads(
    std::function<bool(sinsp_threadinfo&)> visitor);
```

### FD Table

```cpp
// Per-thread FD table
sinsp_fdtable* sinsp_threadinfo::get_fd_table();

// Iterate FDs
bool sinsp_threadinfo::loop_fds(sinsp_fdtable::fdtable_const_visitor_t visitor);
```

### Table Registry (Plugin Access)

```cpp
// From state/table_registry.h
class table_registry {
public:
    // Register a table
    void add_table(std::shared_ptr<table> t);

    // Get table by name
    table* get_table(const std::string& name);

    // List all tables
    std::vector<table_info> list_tables();
};
```

## Plugin Integration

### Plugin Manager

```cpp
class sinsp_plugin_manager {
public:
    // Load plugin
    std::shared_ptr<sinsp_plugin> load_plugin(const std::string& path);

    // Get loaded plugins
    const std::vector<std::shared_ptr<sinsp_plugin>>& plugins() const;

    // Plugin by name
    std::shared_ptr<sinsp_plugin> plugin_by_name(const std::string& name);
};
```

### Opening Plugin Source

```cpp
sinsp inspector;

// Load plugin
auto plugin = inspector.register_plugin("/path/to/plugin.so");
plugin->init("config_string");

// Open as event source
inspector.open_plugin("plugin_name", "open_params", SINSP_PLATFORM_FULL);
```

## Configuration

### Thread Management

```cpp
// Enable/disable automatic thread purging
void sinsp::set_auto_threads_purging(bool enabled);

// Set purging interval (seconds)
void sinsp::set_auto_threads_purging_interval_s(uint32_t val);

// Set thread timeout (seconds)
void sinsp::set_thread_timeout_s(uint32_t val);
```

### Proc Scanning

```cpp
// Set timeout for /proc scan
void sinsp::set_proc_scan_timeout_ms(uint64_t val);

// Set logging interval during scan
void sinsp::set_proc_scan_log_interval_ms(uint64_t val);
```

### Logging

```cpp
// Set log callback
void sinsp::set_log_callback(sinsp_logger_callback cb);

// Log to file
void sinsp::set_log_file(const std::string& filename);

// Log to stderr
void sinsp::set_log_stderr();

// Set minimum severity
void sinsp::set_min_log_severity(sinsp_logger::severity sev);
```

## Usage Example

```cpp
#include <libsinsp/sinsp.h>

int main() {
    sinsp inspector;

    // Open modern eBPF capture
    inspector.open_modern_bpf(
        8 * 1024 * 1024,  // 8MB buffer
        1,                 // 1 CPU per buffer
        true,              // online CPUs only
        {}                 // all syscalls
    );

    // Set filter
    inspector.set_filter("proc.name = nginx and evt.type = open");

    // Process events
    sinsp_evt* evt;
    while (true) {
        int32_t rc = inspector.next(&evt);
        if (rc == SCAP_SUCCESS) {
            // Get thread info
            sinsp_threadinfo* tinfo = evt->get_thread_info();
            if (tinfo) {
                std::cout << "Event: " << evt->get_name()
                          << " pid=" << tinfo->m_pid
                          << " comm=" << tinfo->m_comm
                          << std::endl;
            }
        } else if (rc == SCAP_TIMEOUT) {
            continue;
        } else {
            break;
        }
    }

    inspector.close();
    return 0;
}
```

## Directory Structure

```
userspace/libsinsp/
├── sinsp.h / sinsp.cpp          # Main class
├── parsers.h / parsers.cpp      # Event parsing
├── threadinfo.h / threadinfo.cpp # Thread state
├── fdinfo.h / fdtable.h         # FD state
├── filter.h / filter.cpp        # Filter system
├── filter/
│   ├── ast.h                    # Filter AST
│   ├── parser.h                 # Filter parser
│   └── escaping.h               # String escaping
├── plugin.h / plugin.cpp        # Plugin support
├── state/
│   ├── table.h                  # State table base
│   └── table_registry.h         # Table registry
├── events/
│   └── sinsp_events.h           # Event sets
└── examples/
    └── test.cpp                 # Example application
```

## Sources

| Topic | Source File |
|-------|-------------|
| Main inspector | [`userspace/libsinsp/sinsp.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp.h) |
| Event class | [`userspace/libsinsp/event.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/event.h) |
| Thread manager | [`userspace/libsinsp/thread_manager.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h) |
| Thread info | [`userspace/libsinsp/threadinfo.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h) |
| FD info | [`userspace/libsinsp/fdinfo.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/fdinfo.h) |
| Event parser | [`userspace/libsinsp/parsers.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/parsers.h) |
| Filter system | [`userspace/libsinsp/filter.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter.h) |
| Filterchecks | [`userspace/libsinsp/sinsp_filtercheck.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck.h) |

## Related Digests

- [architecture.md](architecture.md) - Overall system architecture
- [libscap.md](libscap.md) - Lower-level libscap API
- [plugin-framework.md](plugin-framework.md) - Plugin system details
- [api-reference.md](api-reference.md) - Event types and flags
