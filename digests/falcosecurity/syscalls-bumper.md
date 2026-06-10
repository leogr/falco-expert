# syscalls-bumper Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/syscalls-bumper/`](../../refs/falcosecurity/syscalls-bumper/) | **Commit:** `449feef` (`git describe`: `v0.5.1-5-g449feef`, December 17, 2025)

**Repository:** [falcosecurity/syscalls-bumper](https://github.com/falcosecurity/syscalls-bumper)
**Scope:** Infra
**Status:** Incubating

Utility to automatically bump supported syscalls in falcosecurity/libs.

---

## Overview

syscalls-bumper is an infrastructure automation tool that keeps the syscall tables in falcosecurity/libs up-to-date with the latest Linux kernel syscalls across multiple architectures.

**Purpose:**
- Automate updating syscall support in libs
- Ensure all architectures have consistent syscall coverage
- Generate architecture compatibility headers
- Bump schema versions when syscalls are added

**Source:** [`README.md`](../../refs/falcosecurity/syscalls-bumper/README.md)

## How It Works

```
┌──────────────────────────────────────────────────────────────┐
│                      syscalls-bumper                         │
└──────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        ▼                                           ▼
┌───────────────────┐                   ┌───────────────────────┐
│  hrw/syscalls-    │                   │  falcosecurity/libs   │
│  table (GitHub)   │                   │  (local or remote)    │
│                   │                   │                       │
│  x86_64, arm64,   │                   │  driver/syscall_      │
│  s390x, riscv64,  │                   │  table.c              │
│  powerpc64,       │                   │  driver/ppm_events_   │
│  loongarch64      │                   │  public.h             │
└───────────────────┘                   └───────────────────────┘
        │                                           │
        └─────────────────────┬─────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │  Diff & Update  │
                    │  - syscall_table│
                    │  - PPM_SC enum  │
                    │  - compat hdrs  │
                    │  - SCHEMA_VER   │
                    └─────────────────┘
```

**Process:**
1. Download syscall tables from [hrw/syscalls-table](https://github.com/hrw/syscalls-table) for all supported architectures
2. Parse syscalls into `map[syscallName]syscallNR`
3. Create union map of all syscalls across architectures
4. Load libs' current syscall support from `driver/syscall_table.c`
5. Compute diff between system syscalls and libs support
6. For new syscalls, update:
   - `driver/syscall_table.c` - Add syscall entries
   - `driver/ppm_events_public.h` - Add PPM_SC_* enum values
   - `userspace/libscap/linux/scap_ppm_sc.c` - Add to events table
   - `driver/syscall_compat_*.h` - Architecture-specific headers
   - `driver/syscall_ia32_64_map.c` - 32-bit to 64-bit mapping
   - `driver/SCHEMA_VERSION` - Bump patch version
   - `docs/report.md` - Generate syscall support report

**Source:** [`main.go:130-220`](../../refs/falcosecurity/syscalls-bumper/main.go)

## Supported Architectures

| Syscall Table Key | Libs Suffix | Notes |
|-------------------|-------------|-------|
| `x86_64` | `x86_64` | Primary Intel/AMD 64-bit |
| `arm64` | `aarch64` | ARM 64-bit |
| `s390x` | `s390x` | IBM Z series |
| `riscv64` | `riscv64` | RISC-V 64-bit |
| `powerpc64` | `ppc64le` | IBM Power little-endian |
| `loongarch64` | `loongarch64` | Loongson 64-bit |

**Source:** [`main.go:121-128`](../../refs/falcosecurity/syscalls-bumper/main.go)

## CLI Usage

```shell
syscalls-bumper [options]

Options:
  -repo-root string
        falcosecurity/libs repo root (supports http too)
        (default "https://raw.githubusercontent.com/falcosecurity/libs/master")
  -dry-run
        enable dry run mode (don't write files)
  -overwrite
        overwrite existing files in libs repo (local only)
  -verbose
        enable verbose logging
```

**Examples:**

```shell
# Dry run against remote libs (default)
syscalls-bumper -dry-run

# Update local libs clone
syscalls-bumper -repo-root ./libs -overwrite

# Verbose output
syscalls-bumper -repo-root ./libs -overwrite -verbose
```

**Source:** [`README.md`](../../refs/falcosecurity/syscalls-bumper/README.md), [`main.go:99-117`](../../refs/falcosecurity/syscalls-bumper/main.go)

## GitHub Action Usage

The tool is also available as a GitHub composite action for CI automation:

```yaml
- name: Bump syscalls
  uses: falcosecurity/syscalls-bumper@main
  with:
    repo-root: 'libs'  # Path to libs repo (mandatory)
```

**Note:** Use exact tag names, branch names, or commit hashes (not semantic version ranges like `@v0`).

**Source:** [`action.yml`](../../refs/falcosecurity/syscalls-bumper/action.yml), [`README.md`](../../refs/falcosecurity/syscalls-bumper/README.md)

## Files Updated in libs

### driver/syscall_table.c

Adds entries for new syscalls:

```c
#ifdef __NR_new_syscall
    [__NR_new_syscall - SYSCALL_TABLE_ID0] = {.ppm_sc = PPM_SC_NEW_SYSCALL},
#endif
```

**Source:** [`main.go:376-389`](../../refs/falcosecurity/syscalls-bumper/main.go)

### driver/ppm_events_public.h

Adds PPM_SC_* enum entries:

```c
PPM_SC_X(NEW_SYSCALL, <next_value>)
```

**Source:** [`main.go:413-454`](../../refs/falcosecurity/syscalls-bumper/main.go)

### userspace/libscap/linux/scap_ppm_sc.c

Adds syscalls to the PPME_GENERIC events table:

```c
[PPME_GENERIC_E] = {... PPM_SC_NEW_SYSCALL, -1},
```

**Source:** [`main.go:391-411`](../../refs/falcosecurity/syscalls-bumper/main.go)

### driver/syscall_compat_*.h

Generates compatibility headers for each architecture:

```c
#pragma once
#ifndef __NR_syscall_name
#define __NR_syscall_name <syscall_number>
#endif
```

**Source:** [`main.go:514-540`](../../refs/falcosecurity/syscalls-bumper/main.go)

### driver/syscall_ia32_64_map.c

Maps 32-bit x86 syscalls to their 64-bit equivalents:

```c
const int g_ia32_64_map[SYSCALL_TABLE_SIZE] = {
    [32bit_nr] = 64bit_nr,
    // or -1 if ia32 only
};
```

Includes special translations for ia32-only syscalls that have 64-bit equivalents (e.g., `mmap2` → `mmap`, `stat64` → `stat`).

**Source:** [`main.go:555-709`](../../refs/falcosecurity/syscalls-bumper/main.go)

### driver/SCHEMA_VERSION

Bumps patch version (e.g., `1.2.3` → `1.2.4`) when syscalls are added.

**Source:** [`main.go:542-553`](../../refs/falcosecurity/syscalls-bumper/main.go)

### docs/report.md

Generates a Markdown report showing syscall support status:

| Syscall | Supported | Architecture |
|---------|-----------|--------------|
| accept | 🟢 | aarch64,x86_64,... |
| new_sc | 🟡 | x86_64 |

- 🟢 = Fully supported (has event handler)
- 🟡 = Known but not instrumented

**Source:** [`main.go:222-275`](../../refs/falcosecurity/syscalls-bumper/main.go)

## IA32 to x64 Translation Map

Special translations for 32-bit syscalls that don't exist on x86_64 but have compatible equivalents:

| IA32 Syscall | IA32 NR | x64 Equivalent | x64 NR |
|--------------|---------|----------------|--------|
| `mmap2` | 192 | `mmap` | 9 |
| `stat64` | 195 | `stat` | 4 |
| `fstat64` | 197 | `fstat` | 5 |
| `lstat64` | 196 | `lstat` | 6 |
| `sendfile64` | 239 | `sendfile` | 40 |
| `getgid32` | 200 | `getgid` | 104 |
| `fcntl64` | 221 | `fcntl` | 72 |
| `setuid32` | 213 | `setuid` | 105 |
| `_llseek` | 140 | `lseek` | 8 |
| `umount` | 22 | `umount2` | 166 |

**Source:** [`main.go:556-652`](../../refs/falcosecurity/syscalls-bumper/main.go)

## Docker Image

Available on Docker Hub:

```shell
docker pull falcosecurity/syscalls-bumper:latest
```

**Source:** [`README.md`](../../refs/falcosecurity/syscalls-bumper/README.md)

## External Dependencies

- **[hrw/syscalls-table](https://github.com/hrw/syscalls-table)**: Source of truth for Linux syscall numbers across architectures

**Source:** [`main.go:277-286`](../../refs/falcosecurity/syscalls-bumper/main.go)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, usage | [`README.md`](../../refs/falcosecurity/syscalls-bumper/README.md) |
| Main logic | [`main.go`](../../refs/falcosecurity/syscalls-bumper/main.go) |
| GitHub Action | [`action.yml`](../../refs/falcosecurity/syscalls-bumper/action.yml) |
| Build | [`Makefile`](../../refs/falcosecurity/syscalls-bumper/Makefile) |

## Related Documentation

- [`libs/api-reference.md`](libs/api-reference.md) - PPM_SC enum and syscall definitions
- [`libs/kernel-instrumentation.md`](libs/kernel-instrumentation.md) - How syscalls are captured
- [`evolution.md`](evolution.md) - Infra scope repositories
