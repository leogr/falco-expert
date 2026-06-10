# SCAP File Format
> **Era:** 0.44 | **Version:** libs 0.25.2 | **Source:** [`refs/falcosecurity/libs/`](../../../refs/falcosecurity/libs/)

## Overview

The `.scap` file format stores captured system events and state for offline analysis. Based on PCAPng block structure with 4-byte alignment.

**Location:** `userspace/libscap/scap_savefile.c`, `scap_savefile.h`

## File Structure

```
┌──────────────────────────────────┐
│     Section Header Block         │  Magic: 0x0A0D0D0A
├──────────────────────────────────┤
│     Machine Info Block           │  Type: 0x201
├──────────────────────────────────┤
│     Interface List Block (V2)    │  Type: 0x219
├──────────────────────────────────┤
│     User List Block (V2)         │  Type: 0x220
├──────────────────────────────────┤
│     Process List Block (V9)      │  Type: 0x215
├──────────────────────────────────┤
│     FD List Blocks (V2)          │  Type: 0x218 (per thread)
├──────────────────────────────────┤
│     Event Block 1                │  Type: 0x216/0x217
├──────────────────────────────────┤
│     Event Block 2                │
├──────────────────────────────────┤
│           ...                    │
└──────────────────────────────────┘
```

## Block Structure

Every block follows this layout:

```
┌─────────────────────────────────────────────────┐
│  block_type (4 bytes)                           │
├─────────────────────────────────────────────────┤
│  block_total_length (4 bytes)                   │
├─────────────────────────────────────────────────┤
│  payload (variable length)                      │
├─────────────────────────────────────────────────┤
│  padding (0-3 bytes for 4-byte alignment)       │
├─────────────────────────────────────────────────┤
│  block_total_length (4 bytes, validation copy)  │
└─────────────────────────────────────────────────┘
```

Block length alignment: `((len + 3) >> 2) << 2`

## Block Types

### Metadata Blocks

| Block Type | Hex | Description |
|------------|-----|-------------|
| SHB | `0x0A0D0D0A` | Section Header Block |
| MI | `0x201` | Machine Info |
| PL_V9 | `0x215` | Process List (latest) |
| FDL_V2 | `0x218` | File Descriptor List |
| IL_V2 | `0x219` | Interface List |
| UL_V2 | `0x220` | User List |

### Event Blocks

| Block Type | Hex | Description |
|------------|-----|-------------|
| EV_V2 | `0x216` | Event Block |
| EVF_V2 | `0x217` | Event Block with Flags |
| EV_V2_LARGE | `0x221` | Large Event Block (>64KB) |
| EVF_V2_LARGE | `0x222` | Large Event with Flags |

### Legacy Block Types

| Block Type | Hex | Version |
|------------|-----|---------|
| PL_V1 | `0x202` | Process List V1 |
| PL_V2-V8 | `0x207-0x214` | Process List V2-V8 |
| FDL_V1 | `0x203` | File Descriptor List V1 |
| EV_V1 | `0x204` | Event Block V1 |
| IL_V1 | `0x205` | Interface List V1 |
| UL_V1 | `0x206` | User List V1 |

## Section Header Block

```c
struct section_header_block {
    uint32_t byte_order_magic;  // 0x1A2B3C4D (SHB_MAGIC)
    uint16_t major_version;     // Currently 1
    uint16_t minor_version;     // Currently 2
    uint64_t section_length;    // 0xFFFFFFFFFFFFFFFF (unknown)
};
```

**Byte Order Detection:** `byte_order_magic = 0x1A2B3C4D` identifies native endianness.

## Machine Info Block (0x201)

Contains `scap_machine_info` structure:
- CPU count
- OS identification
- System configuration

## Process List Block (0x215, V9)

Stores process/thread state snapshot.

**Entry Format:**

| Field | Type | Description |
|-------|------|-------------|
| `sub_len` | uint32_t | Entry length (for compatibility) |
| `tid` | uint64_t | Thread ID |
| `pid` | uint64_t | Process ID |
| `ptid` | uint64_t | Parent thread ID |
| `sid` | uint64_t | Session ID |
| `vpgid` | uint64_t | Virtual process group ID |
| `pgid` | uint64_t | Process group ID |
| `comm` | string | Command name |
| `exe` | string | Executable (argv[0]) |
| `exepath` | string | Full executable path |
| `args` | string | Arguments (null-separated) |
| `env` | string | Environment (null-separated) |
| `cwd` | string | Current working directory |
| `cgroups` | string | Cgroup info |
| `root` | string | Root path |
| `pidns_init_start_ts` | uint64_t | PID namespace init time |
| `tty` | uint32_t | TTY number |
| `loginuid` | uint32_t | Login UID |
| `exe_writable` | uint8_t | Executable is writable |
| `cap_inheritable` | uint64_t | Inheritable capabilities |
| `cap_permitted` | uint64_t | Permitted capabilities |
| `cap_effective` | uint64_t | Effective capabilities |
| `exe_upper_layer` | uint8_t | On overlay upper layer |
| `exe_ino` | uint64_t | Executable inode |
| `exe_ino_ctime` | uint64_t | Inode change time |
| `exe_ino_mtime` | uint64_t | Inode modify time |
| `exe_from_memfd` | uint8_t | Fileless execution |
| `exe_lower_layer` | uint8_t | On overlay lower layer |

**String Encoding:** Each string prefixed with `uint16_t length`.

## File Descriptor List Block (0x218, V2)

Stores open file descriptors per thread.

**Block Header:**

| Field | Type | Description |
|-------|------|-------------|
| `tid` | uint64_t | Thread these FDs belong to |

**FD Entry Format:**

| Field | Type | Description |
|-------|------|-------------|
| `sub_len` | uint32_t | Entry length |
| `fd` | uint64_t | File descriptor number |
| `ino` | uint64_t | Inode number |
| `type` | uint8_t | FD type |

**Type-Specific Data:**

For IPv4 sockets:
- `sip` (uint32_t) - Source IP
- `dip` (uint32_t) - Destination IP
- `sport` (uint16_t) - Source port
- `dport` (uint16_t) - Destination port
- `l4proto` (uint8_t) - L4 protocol

For IPv6 sockets:
- Same fields with 128-bit addresses

For Unix sockets:
- `source` (uint64_t)
- `destination` (uint64_t)
- `fname` (string)

For regular files:
- `open_flags` (uint32_t)
- `fname` (string)
- `dev` (uint32_t)

## Interface List Block (0x219, V2)

**Entry Format:**

| Field | Type | Description |
|-------|------|-------------|
| `entrylen` | uint32_t | Entry length |
| `type` | uint16_t | Interface type |
| `ifnamelen` | uint16_t | Interface name length |
| `addr` | uint32_t/128-bit | IP address |
| `netmask` | uint32_t/128-bit | Netmask |
| `bcast` | uint32_t/128-bit | Broadcast address |
| `linkspeed` | uint64_t | Link speed |
| `ifname` | string | Interface name |

**Interface Types:**
- `SCAP_II_IPV4` - IPv4 with link speed
- `SCAP_II_IPV4_NOLINKSPEED` - IPv4 without link speed
- `SCAP_II_IPV6` - IPv6 with link speed
- `SCAP_II_IPV6_NOLINKSPEED` - IPv6 without link speed

## User List Block (0x220, V2)

**Entry Format:**

| Field | Type | Description |
|-------|------|-------------|
| `sub_len` | uint32_t | Entry length |
| `type` | uint8_t | User or group |

**For Users (type = USERBLOCK_TYPE_USER):**
- `uid` (uint32_t)
- `gid` (uint32_t)
- `name` (string)
- `homedir` (string)
- `shell` (string)

**For Groups (type = USERBLOCK_TYPE_GROUP):**
- `gid` (uint32_t)
- `name` (string)

## Event Block Format

### Event Header (ppm_evt_hdr)

```c
struct ppm_evt_hdr {
    uint64_t ts;      // Timestamp (nanoseconds from epoch)
    uint64_t tid;     // Thread ID
    uint32_t len;     // Total event length (including header)
    uint16_t type;    // Event type ID
    uint32_t nparams; // Number of parameters (V2+)
};
```

**Header Size** (struct is `__attribute__((packed))` / `#pragma pack(1)`, so no padding):
- V1: 22 bytes (no nparams): ts(8) + tid(8) + len(4) + type(2)
- V2: 26 bytes (with nparams): ts(8) + tid(8) + len(4) + type(2) + nparams(4)

### Event Block Structure (0x216)

```
┌─────────────────────────────────┐
│  block_header (8 bytes)         │
├─────────────────────────────────┤
│  cpuid (uint16_t)               │
├─────────────────────────────────┤
│  ppm_evt_hdr (26 bytes)         │
├─────────────────────────────────┤
│  parameters (variable)          │
├─────────────────────────────────┤
│  padding (0-3 bytes)            │
├─────────────────────────────────┤
│  block_length (4 bytes)         │
└─────────────────────────────────┘
```

### Event Block with Flags (0x217)

```
┌─────────────────────────────────┐
│  block_header (8 bytes)         │
├─────────────────────────────────┤
│  cpuid (uint16_t)               │
├─────────────────────────────────┤
│  flags (uint32_t)               │
├─────────────────────────────────┤
│  ppm_evt_hdr (26 bytes)         │
├─────────────────────────────────┤
│  parameters (variable)          │
├─────────────────────────────────┤
│  padding + block_length         │
└─────────────────────────────────┘
```

### Parameter Encoding

Each parameter:
```
┌────────────────────────────────┐
│  length (uint16_t)             │
├────────────────────────────────┤
│  data (variable)               │
└────────────────────────────────┘
```

## Compression Support

| Format | Mode | Description |
|--------|------|-------------|
| GZIP | `"wb"` | Standard gzip compression |
| None | `"wbT"` | Uncompressed raw file |

Compression is transparent to block structure (handled at I/O layer via zlib).

## Version Compatibility

### Version Strategy

- **Major Version (1):** Breaking changes only
- **Minor Version (2):** New features

### Backwards Compatibility

1. **Block Type Versioning:** Different block types for different versions
2. **Length-Based Versioning (V2+):** `sub_len` field enables field detection
3. **Event Conversion:** V1 events auto-converted to V2 during read

### Reading Unknown Fields

```c
// Skip unknown fields using sub_len
if (bytes_read < sub_len) {
    skip_bytes(sub_len - bytes_read);
}
```

## Reading Implementation

```c
// 1. Initialize and read metadata
scap_read_init(scap_reader_t* r, scap* handle);

// 2. Read events in loop
while (scap_next(handle, &evt) == SCAP_SUCCESS) {
    // Process event
}
```

### Read Flow

1. Read and validate section header
2. Read metadata blocks until first event block
3. For each event block:
   - Read block header
   - Extract cpuid and event data
   - Convert V1 to V2 if needed
   - Return event pointer

## Writing Implementation

```c
// 1. Create dumper
scap_dumper_t* dumper = scap_dump_open(handle, filename,
                                        SCAP_COMPRESSION_GZIP, false);

// 2. Write events
scap_dump(handle, dumper, event, cpuid, flags);

// 3. Close
scap_dump_close(dumper);
```

### Write Flow

1. `scap_dump_open()` - Create file, write section header
2. `scap_setup_dump()` - Write machine info, interfaces, users, processes, FDs
3. `scap_dump()` - Write each event with cpuid and optional flags
4. `scap_dump_close()` - Finalize and close file

## Key Constants

```c
#define SHB_BLOCK_TYPE      0x0A0D0D0A  // Section header magic
#define SHB_MAGIC           0x1A2B3C4D  // Byte order magic

#define READER_BUF_SIZE     65536       // Standard buffer (64KB)

// Block normalization
#define normalize_len(len)  (((len) + 3) >> 2) << 2
```

## Sources

| Topic | Source File |
|-------|-------------|
| Savefile implementation | [`userspace/libscap/scap_savefile.c`](../../../refs/falcosecurity/libs/userspace/libscap/scap_savefile.c) |
| Block types, magic numbers | [`userspace/libscap/scap_savefile.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_savefile.h) |
| Savefile API | [`userspace/libscap/scap_savefile_api.h`](../../../refs/falcosecurity/libs/userspace/libscap/scap_savefile_api.h) |
| Reader interface | [`userspace/libscap/engine/savefile/scap_reader.h`](../../../refs/falcosecurity/libs/userspace/libscap/engine/savefile/scap_reader.h) |
| Event header | [`driver/ppm_events_public.h`](../../../refs/falcosecurity/libs/driver/ppm_events_public.h) |

## Related Digests

- [libscap.md](libscap.md) - Capture library using scap format
- [api-reference.md](api-reference.md) - Event types stored in scap files
- [state-management.md](state-management.md) - State captured in process/FD blocks
