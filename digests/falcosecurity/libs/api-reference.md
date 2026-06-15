# API Reference
> **Era:** 0.44 | **Version:** libs 0.25.4 | **Source:** [`refs/falcosecurity/libs/`](../../../refs/falcosecurity/libs/)

## Event Types

Events are identified by `ppm_event_type` codes defined in [`ppm_events_public.h`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h). Events come in enter/exit pairs for syscalls.

### Event Type Categories

| Category | Description | Example Events |
|----------|-------------|----------------|
| **Process** | Process lifecycle | `PPME_SYSCALL_CLONE_*`, `PPME_SYSCALL_EXECVE_*`, `PPME_PROCEXIT_*` |
| **File I/O** | File operations | `PPME_SYSCALL_OPEN_*`, `PPME_SYSCALL_READ_*`, `PPME_SYSCALL_WRITE_*` |
| **Network** | Network operations | `PPME_SOCKET_*`, `PPME_SYSCALL_CONNECT_*`, `PPME_SYSCALL_ACCEPT_*` |
| **Memory** | Memory management | `PPME_SYSCALL_MMAP_*`, `PPME_SYSCALL_MUNMAP_*`, `PPME_SYSCALL_BRK_*` |
| **IPC** | Inter-process comm | `PPME_SYSCALL_PIPE_*`, `PPME_SYSCALL_EVENTFD_*` |
| **Signals** | Signal handling | `PPME_SIGNALDELIVER_E`, `PPME_SYSCALL_KILL_*` |
| **System** | System-wide events | `PPME_CPU_HOTPLUG_E`, `PPME_DROP_E/X` |
| **Plugin** | Plugin events | `PPME_PLUGINEVENT_E`, `PPME_ASYNCEVENT_E` |

### Event Direction

- `_E` suffix = **Enter** event (syscall entry)
- `_X` suffix = **Exit** event (syscall return)

## Common Flags

### File Open Flags (PPM_O_*)

**Source:** [`ppm_events_public.h:92-113`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h)

```c
#define PPM_O_NONE 0
#define PPM_O_RDONLY (1 << 0)      // Read only
#define PPM_O_WRONLY (1 << 1)      // Write only
#define PPM_O_RDWR (PPM_O_RDONLY | PPM_O_WRONLY)  // Read/write
#define PPM_O_CREAT (1 << 2)       // Create if not exists
#define PPM_O_APPEND (1 << 3)      // Append mode
#define PPM_O_DSYNC (1 << 4)       // Data sync
#define PPM_O_EXCL (1 << 5)        // Exclusive create
#define PPM_O_NONBLOCK (1 << 6)    // Non-blocking
#define PPM_O_SYNC (1 << 7)        // Synchronous I/O
#define PPM_O_TRUNC (1 << 8)       // Truncate
#define PPM_O_DIRECT (1 << 9)      // Direct I/O
#define PPM_O_DIRECTORY (1 << 10)  // Must be directory
#define PPM_O_LARGEFILE (1 << 11)  // Large file support
#define PPM_O_CLOEXEC (1 << 12)    // Close on exec
#define PPM_O_TMPFILE (1 << 13)    // Temporary file
#define PPM_O_F_CREATED (1 << 14)  // File created (probe flag)
#define PPM_FD_UPPER_LAYER (1 << 15) // OverlayFS upper
#define PPM_FD_LOWER_LAYER (1 << 16) // OverlayFS lower
```

### File Modes (PPM_S_*)

**Source:** [`ppm_events_public.h:131-143`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h)

```c
#define PPM_S_NONE 0
#define PPM_S_IXOTH (1 << 0)   // Execute by others
#define PPM_S_IWOTH (1 << 1)   // Write by others
#define PPM_S_IROTH (1 << 2)   // Read by others
#define PPM_S_IXGRP (1 << 3)   // Execute by group
#define PPM_S_IWGRP (1 << 4)   // Write by group
#define PPM_S_IRGRP (1 << 5)   // Read by group
#define PPM_S_IXUSR (1 << 6)   // Execute by owner
#define PPM_S_IWUSR (1 << 7)   // Write by owner
#define PPM_S_IRUSR (1 << 8)   // Read by owner
#define PPM_S_ISVTX (1 << 9)   // Sticky bit
#define PPM_S_ISGID (1 << 10)  // Set GID
#define PPM_S_ISUID (1 << 11)  // Set UID
```

### Clone Flags (PPM_CL_*)

**Source:** [`ppm_events_public.h:166-204`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h)

```c
#define PPM_CL_NONE 0
#define PPM_CL_CLONE_FILES (1 << 0)      // Share file descriptors
#define PPM_CL_CLONE_FS (1 << 1)         // Share filesystem info
#define PPM_CL_CLONE_IO (1 << 2)         // Share I/O context
#define PPM_CL_CLONE_NEWIPC (1 << 3)     // New IPC namespace
#define PPM_CL_CLONE_NEWNET (1 << 4)     // New network namespace
#define PPM_CL_CLONE_NEWNS (1 << 5)      // New mount namespace
#define PPM_CL_CLONE_NEWPID (1 << 6)     // New PID namespace
#define PPM_CL_CLONE_NEWUTS (1 << 7)     // New UTS namespace
#define PPM_CL_CLONE_PARENT (1 << 8)     // Same parent as caller
#define PPM_CL_CLONE_PARENT_SETTID (1 << 9)
#define PPM_CL_CLONE_PTRACE (1 << 10)    // Continue tracing
#define PPM_CL_CLONE_SIGHAND (1 << 11)   // Share signal handlers
#define PPM_CL_CLONE_SYSVSEM (1 << 12)   // Share SysV semaphores
#define PPM_CL_CLONE_THREAD (1 << 13)    // Same thread group
#define PPM_CL_CLONE_UNTRACED (1 << 14)  // Don't trace
#define PPM_CL_CLONE_VM (1 << 15)        // Share memory
#define PPM_CL_CLONE_INVERTED (1 << 16)  // Child returned first (libsinsp)
#define PPM_CL_NAME_CHANGED (1 << 17)    // Thread name changed (libsinsp)
#define PPM_CL_CLOSED (1 << 18)          // Thread closed
#define PPM_CL_ACTIVE (1 << 19)          // First non-clone event (libsinsp)
#define PPM_CL_CLONE_NEWUSER (1 << 20)   // New user namespace
#define PPM_CL_PIPE_SRC (1 << 21)        // Shell pipe source (libsinsp)
#define PPM_CL_PIPE_DST (1 << 22)        // Shell pipe dest (libsinsp)
#define PPM_CL_CLONE_CHILD_CLEARTID (1 << 23)
#define PPM_CL_CLONE_CHILD_SETTID (1 << 24)
#define PPM_CL_CLONE_SETTLS (1 << 25)
#define PPM_CL_CLONE_STOPPED (1 << 26)
#define PPM_CL_CLONE_VFORK (1 << 27)
#define PPM_CL_CLONE_NEWCGROUP (1 << 28)
#define PPM_CL_CHILD_IN_PIDNS (1 << 29)  // Child in PID namespace
#define PPM_CL_IS_MAIN_THREAD (1 << 30)  // Main thread (libsinsp)
```

### Socket Families (PPM_AF_*)

**Source:** [`ppm_events_public.h:48-88`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h)

```c
#define PPM_AF_UNSPEC 0
#define PPM_AF_UNIX 1       // Unix domain
#define PPM_AF_LOCAL 1      // Same as UNIX
#define PPM_AF_INET 2       // IPv4
#define PPM_AF_INET6 10     // IPv6
#define PPM_AF_NETLINK 16   // Netlink
#define PPM_AF_PACKET 17    // Raw packet
// ... more families
```

### Memory Protection (PPM_PROT_*)

```c
#define PPM_PROT_NONE 0
#define PPM_PROT_READ (1 << 0)       // Readable
#define PPM_PROT_WRITE (1 << 1)      // Writable
#define PPM_PROT_EXEC (1 << 2)       // Executable
#define PPM_PROT_SEM (1 << 3)        // Semaphore
#define PPM_PROT_GROWSDOWN (1 << 4)  // Grows down
#define PPM_PROT_GROWSUP (1 << 5)    // Grows up
```

### mmap Flags (PPM_MAP_*)

```c
#define PPM_MAP_SHARED (1 << 0)      // Share changes
#define PPM_MAP_PRIVATE (1 << 1)     // Private copy
#define PPM_MAP_FIXED (1 << 2)       // Fixed address
#define PPM_MAP_ANONYMOUS (1 << 3)   // Not file-backed
#define PPM_MAP_32BIT (1 << 4)       // Low 2GB
#define PPM_MAP_POPULATE (1 << 7)    // Prefault pages
#define PPM_MAP_NONBLOCK (1 << 8)    // Non-blocking
#define PPM_MAP_LOCKED (1 << 14)     // Lock pages
```

### Mount Flags (PPM_MS_*)

```c
#define PPM_MS_RDONLY (1 << 0)       // Read only
#define PPM_MS_NOSUID (1 << 1)       // Ignore setuid
#define PPM_MS_NODEV (1 << 2)        // No device access
#define PPM_MS_NOEXEC (1 << 3)       // No execution
#define PPM_MS_SYNCHRONOUS (1 << 4)  // Sync writes
#define PPM_MS_REMOUNT (1 << 5)      // Remount
#define PPM_MS_BIND (1 << 12)        // Bind mount
#define PPM_MS_MOVE (1 << 13)        // Move mount
#define PPM_MS_REC (1 << 14)         // Recursive
#define PPM_MS_PRIVATE (1 << 18)     // Private propagation
#define PPM_MS_SLAVE (1 << 19)       // Slave propagation
#define PPM_MS_SHARED (1 << 20)      // Shared propagation
```

### Execve Flags (PPM_EXE_*)

```c
#define PPM_EXE_WRITABLE (1 << 0)     // Executable is writable
#define PPM_EXE_UPPER_LAYER (1 << 1)  // OverlayFS upper layer
#define PPM_EXE_FROM_MEMFD (1 << 2)   // Fileless (memfd)
#define PPM_EXE_LOWER_LAYER (1 << 3)  // OverlayFS lower layer
```

## Syscall Codes (ppm_sc_code)

Syscalls are identified by `ppm_sc_code` values. Common ones:

```c
// Process
PPM_SC_CLONE
PPM_SC_CLONE3
PPM_SC_FORK
PPM_SC_VFORK
PPM_SC_EXECVE
PPM_SC_EXECVEAT
PPM_SC_EXIT
PPM_SC_EXIT_GROUP

// File
PPM_SC_OPEN
PPM_SC_OPENAT
PPM_SC_OPENAT2
PPM_SC_CLOSE
PPM_SC_READ
PPM_SC_WRITE
PPM_SC_PREAD64
PPM_SC_PWRITE64

// Network
PPM_SC_SOCKET
PPM_SC_BIND
PPM_SC_LISTEN
PPM_SC_ACCEPT
PPM_SC_ACCEPT4
PPM_SC_CONNECT
PPM_SC_SEND
PPM_SC_RECV
PPM_SC_SENDTO
PPM_SC_RECVFROM

// Memory
PPM_SC_MMAP
PPM_SC_MMAP2
PPM_SC_MUNMAP
PPM_SC_MPROTECT
PPM_SC_BRK

// IPC
PPM_SC_PIPE
PPM_SC_PIPE2
PPM_SC_EVENTFD
PPM_SC_EVENTFD2
```

## File Descriptor Types

```c
typedef enum scap_fd_type {
    SCAP_FD_UNINITIALIZED = -1,
    SCAP_FD_UNKNOWN = 0,
    SCAP_FD_FILE = 1,           // Regular file
    SCAP_FD_FILE_V2 = 2,        // File with extended info
    SCAP_FD_DIRECTORY = 3,      // Directory
    SCAP_FD_IPV4_SOCK = 4,      // IPv4 socket
    SCAP_FD_IPV6_SOCK = 5,      // IPv6 socket
    SCAP_FD_IPV4_SERVSOCK = 6,  // IPv4 server socket
    SCAP_FD_IPV6_SERVSOCK = 7,  // IPv6 server socket
    SCAP_FD_FIFO = 8,           // Named pipe
    SCAP_FD_UNIX_SOCK = 9,      // Unix socket
    SCAP_FD_EVENT = 10,         // eventfd
    SCAP_FD_UNSUPPORTED = 11,   // Unsupported type
    SCAP_FD_SIGNALFD = 12,      // signalfd
    SCAP_FD_EVENTPOLL = 13,     // epoll
    SCAP_FD_INOTIFY = 14,       // inotify
    SCAP_FD_TIMERFD = 15,       // timerfd
    SCAP_FD_NETLINK = 16,       // netlink
    SCAP_FD_BPF = 17,           // BPF map/program
    SCAP_FD_USERFAULTFD = 18,   // userfaultfd
    SCAP_FD_IOURING = 19,       // io_uring
    SCAP_FD_MEMFD = 20,         // memfd
    SCAP_FD_PIDFD = 21,         // pidfd
} scap_fd_type;
```

## Event Header Structure

**Source:** [`ppm_events_public.h:2182-2191`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h)

```c
struct ppm_evt_hdr {
    uint64_t ts;        // Timestamp (nanoseconds since epoch)
    uint64_t tid;       // Thread ID
    uint32_t len;       // Total event length (header + params)
    uint16_t type;      // Event type (ppm_event_type)
    uint32_t nparams;   // Number of parameters
} __attribute__((packed));

// Total header size: 26 bytes
```

## Parameter Types

Event parameters are typed:

```c
typedef enum {
    PT_NONE = 0,
    PT_INT8 = 1,
    PT_INT16 = 2,
    PT_INT32 = 3,
    PT_INT64 = 4,
    PT_UINT8 = 5,
    PT_UINT16 = 6,
    PT_UINT32 = 7,
    PT_UINT64 = 8,
    PT_CHARBUF = 9,     // NULL-terminated string
    PT_BYTEBUF = 10,    // Binary data
    PT_ERRNO = 11,      // Error number
    PT_SOCKADDR = 12,   // Socket address
    PT_SOCKTUPLE = 13,  // Socket tuple (src+dst)
    PT_FD = 14,         // File descriptor
    PT_PID = 15,        // Process ID
    PT_FDLIST = 16,     // FD list
    PT_FSPATH = 17,     // Filesystem path
    PT_SYSCALLID = 18,  // Syscall number
    PT_SIGTYPE = 19,    // Signal type
    PT_RELTIME = 20,    // Relative time
    PT_ABSTIME = 21,    // Absolute time
    PT_PORT = 22,       // Port number
    PT_L4PROTO = 23,    // L4 protocol
    PT_SOCKFAMILY = 24, // Socket family
    PT_BOOL = 25,       // Boolean
    PT_IPV4ADDR = 26,   // IPv4 address
    PT_DYN = 27,        // Dynamic (varies)
    PT_FLAGS8 = 28,     // 8-bit flags
    PT_FLAGS16 = 29,    // 16-bit flags
    PT_FLAGS32 = 30,    // 32-bit flags
    PT_UID = 31,        // User ID
    PT_GID = 32,        // Group ID
    PT_DOUBLE = 33,     // Double
    PT_SIGSET = 34,     // Signal set
    PT_CHARBUFARRAY = 35, // String array
    PT_CHARBUF_PAIR_ARRAY = 36, // Key=value pairs
    PT_IPV4NET = 37,    // IPv4 network
    PT_IPV6ADDR = 38,   // IPv6 address
    PT_IPV6NET = 39,    // IPv6 network
    PT_IPADDR = 40,     // IP address (v4 or v6)
    PT_IPNET = 41,      // IP network
    PT_MODE = 42,       // File mode
    PT_FSRELPATH = 43,  // FS-relative path
    PT_ENUMFLAGS8 = 44, // 8-bit enum flags
    PT_ENUMFLAGS16 = 45, // 16-bit enum flags
    PT_ENUMFLAGS32 = 46, // 32-bit enum flags
} ppm_param_type;
```

## Version Constants

**Sources:**
- [`driver/API_VERSION`](../../../refs/falcosecurity/libs/driver/API_VERSION) - Driver API version
- [`driver/SCHEMA_VERSION`](../../../refs/falcosecurity/libs/driver/SCHEMA_VERSION) - Event schema version
- [`plugin_api.h:31-33`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_api.h) - Plugin API version

```c
// From driver/API_VERSION
#define PPM_API_CURRENT_VERSION_MAJOR 8
#define PPM_API_CURRENT_VERSION_MINOR 0
#define PPM_API_CURRENT_VERSION_PATCH 4

// From driver/SCHEMA_VERSION
#define PPM_SCHEMA_CURRENT_VERSION_MAJOR 4
#define PPM_SCHEMA_CURRENT_VERSION_MINOR 1
#define PPM_SCHEMA_CURRENT_VERSION_PATCH 0

// From userspace/plugin/plugin_api.h
#define PLUGIN_API_VERSION_MAJOR 3
#define PLUGIN_API_VERSION_MINOR 12
#define PLUGIN_API_VERSION_PATCH 0
```

## Limits

**Source:** [`ppm_events_public.h:42-43`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h)

```c
#define PPM_MAX_EVENT_PARAMS (1 << 5)  // 32 parameters max
#define PPM_MAX_NAME_LEN 32
#define SCAP_MAX_PATH_SIZE 1024
#define SCAP_MAX_ARGS_SIZE 4096
#define SCAP_MAX_ENV_SIZE 4096
#define PLUGIN_MAX_ERRLEN 1024
```

## Sources

| Topic | Source File |
|-------|-------------|
| Event types, flags, parameter types | [`driver/ppm_events_public.h`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h) |
| API version | [`driver/API_VERSION`](../../../refs/falcosecurity/libs/driver/API_VERSION) |
| Schema version | [`driver/SCHEMA_VERSION`](../../../refs/falcosecurity/libs/driver/SCHEMA_VERSION) |
| Plugin API version | [`userspace/plugin/plugin_api.h`](../../../refs/falcosecurity/libs/userspace/plugin/plugin_api.h) |
| FD types | [`userspace/libscap/scap.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap.h) |

## Related Digests

- [architecture.md](architecture.md) - System architecture
- [modern-bpf.md](modern-bpf.md) - Driver implementation
- [libscap.md](libscap.md) - Capture API
- [libsinsp.md](libsinsp.md) - Inspection API
