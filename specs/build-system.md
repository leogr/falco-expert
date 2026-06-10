# Build System

> CMake structure, dependencies, feature flags, driver build options, and container image build.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco/CMakeLists.txt`](../refs/falcosecurity/falco/CMakeLists.txt), [`refs/falcosecurity/libs/CMakeLists.txt`](../refs/falcosecurity/libs/CMakeLists.txt)

## Overview

Falco uses CMake as its build system. The build has two primary layers:

1. **Falco** (`falcosecurity/falco`) — the application binary and rule engine library
2. **Libs** (`falcosecurity/libs`) — core capture and inspection libraries, fetched as a dependency

Both layers support bundled dependencies (default) for reproducible builds or system-provided dependencies for distribution packaging.

## Architecture

### Repository Build Structure

```
falco/
├── CMakeLists.txt              # Root build configuration
├── cmake/
│   └── modules/                # CMake modules for dependency fetching
│       ├── falcosecurity-libs.cmake  # Fetches and builds libs
│       ├── njson.cmake               # nlohmann/json
│       ├── yaml-cpp.cmake            # YAML parser
│       ├── cxxopts.cmake             # CLI option parsing
│       └── cpp-httplib.cmake         # HTTP server
├── userspace/
│   ├── engine/
│   │   └── CMakeLists.txt      # falco_engine static library
│   └── falco/
│       └── CMakeLists.txt      # falco binary
└── docker/                     # Container image build files

libs/
├── CMakeLists.txt              # Root build configuration
├── cmake/
│   └── modules/                # Dependency modules (incl. tbb.cmake, re2.cmake, etc.)
├── userspace/
│   ├── libscap/
│   │   └── CMakeLists.txt      # libscap library
│   ├── libsinsp/
│   │   └── CMakeLists.txt      # libsinsp library
│   └── libpman/
│       └── CMakeLists.txt      # Modern eBPF probe manager
└── driver/
    ├── CMakeLists.txt          # Kernel module build
    └── modern_bpf/
        └── CMakeLists.txt      # Modern eBPF skeleton build
```

**Source:** [`refs/falcosecurity/falco/CMakeLists.txt`](../refs/falcosecurity/falco/CMakeLists.txt), [`refs/falcosecurity/libs/CMakeLists.txt`](../refs/falcosecurity/libs/CMakeLists.txt)

### Dependency Hierarchy

```
falco (binary)
├── falco_engine (static lib)
│   ├── yaml-cpp
│   └── nlohmann_json
├── libsinsp (from libs)
│   ├── libscap (from libs)
│   │   ├── libpman (modern eBPF probe manager)
│   │   └── zlib
│   ├── curl
│   ├── jsoncpp
│   ├── re2
│   └── tbb
├── cxxopts (CLI parsing)
└── cpp-httplib (webserver)
```

## Implementation Details

### Falco Build Targets

| Target | Type | Description |
|--------|------|-------------|
| `falco` | Executable | Main Falco binary |
| `falco_engine` | Static library | Rule engine (compilation, matching, formatting) |
| `container` | Downloaded | Container plugin (downloaded during build) |

**Source:** [`refs/falcosecurity/falco/CMakeLists.txt`](../refs/falcosecurity/falco/CMakeLists.txt)

### Libs Build Targets

| Target | Type | Description |
|--------|------|-------------|
| `scap` | Library | libscap (system capture) |
| `sinsp` | Library | libsinsp (system inspection) |
| `driver` | Kernel module | Kernel module (kmod) |
| `ProbeSkeleton` | BPF skeleton | Modern eBPF skeleton header |
| `scap-open` | Executable | Test binary for libscap |
| `sinsp-example` | Executable | Test binary for libsinsp |

**Source:** [`refs/falcosecurity/libs/CMakeLists.txt`](../refs/falcosecurity/libs/CMakeLists.txt)

### Feature Flags (Falco)

| Flag | Default | Description |
|------|---------|-------------|
| `USE_BUNDLED_DEPS` | `ON` | Fetch and build all dependencies |
| `MINIMAL_BUILD` | `OFF` | Build minimal Falco: disables webserver, metrics, http output, memory allocators, OpenSSL/curl, container plugin, coverage |
| `BUILD_FALCO_MODERN_BPF` | `ON` | Enable modern eBPF support (Linux only) |
| `MUSL_OPTIMIZED_BUILD` | `OFF` | Static linking with musl libc |
| `BUILD_WARNINGS_AS_ERRORS` | `OFF` | Treat compiler warnings as errors |

**Source:** [`refs/falcosecurity/falco/CMakeLists.txt`](../refs/falcosecurity/falco/CMakeLists.txt)

### Feature Flags (Libs)

| Flag | Default | Description |
|------|---------|-------------|
| `USE_BUNDLED_DEPS` | `ON` | Fetch and build all dependencies |
| `BUILD_LIBSCAP_MODERN_BPF` | `OFF` | Enable modern eBPF in libscap |
| `BUILD_DRIVER` | `ON` | Build kernel module |
| `CREATE_TEST_TARGETS` | `ON` | Build test binaries |

**Source:** [`refs/falcosecurity/libs/CMakeLists.txt`](../refs/falcosecurity/libs/CMakeLists.txt)

### External Dependencies

| Dependency | Purpose | Fetching Module |
|-----------|---------|-----------------|
| falcosecurity/libs | Core capture and inspection libraries | `falcosecurity-libs.cmake` |
| nlohmann/json | JSON parsing and serialization | `njson.cmake` |
| yaml-cpp | YAML configuration parsing | `yaml-cpp.cmake` |
| Intel TBB | Concurrent bounded queue for outputs | `tbb.cmake` (from libs) |
| cxxopts | Command-line option parsing | `cxxopts.cmake` |
| cpp-httplib | HTTP server for health/metrics endpoints | `cpp-httplib.cmake` |
| curl | HTTP output channel | (via libs) |
| re2 | Regular expression matching | (via libs) |
| zlib | Compression for capture files | (via libs) |

### Driver Build Options

#### Modern eBPF

```bash
cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_FALCO_MODERN_BPF=ON ..
make falco
```

The modern eBPF skeleton (`bpf_probe.skel.h`) is built as part of the `ProbeSkeleton` target and embedded into libscap. **Prerequisites:** clang >= 12, bpftool.

#### Kernel Module

The kernel module is built separately and requires kernel headers:

```bash
cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_DRIVER=ON ..
make driver
```

**Output:** `driver/falco.ko`

> Note: The legacy eBPF probe (`BUILD_BPF`/`driver/bpf/`) was removed in libs 0.25 / Falco 0.44 ([PR #3796](https://github.com/falcosecurity/falco/pull/3796)). Only the modern eBPF probe (`driver/modern_bpf/`) remains.

### Build Examples

#### Standard Build (Modern eBPF)

```bash
mkdir build && cd build
cmake -DUSE_BUNDLED_DEPS=ON \
      -DBUILD_FALCO_MODERN_BPF=ON \
      ..
make -j$(nproc) falco
```

#### Minimal Build (No Webserver/Metrics/HTTP Output)

```bash
cmake -DUSE_BUNDLED_DEPS=ON \
      -DMINIMAL_BUILD=ON \
      ..
make -j$(nproc) falco
```

#### Static Build (musl)

```bash
cmake -DUSE_BUNDLED_DEPS=ON \
      -DMUSL_OPTIMIZED_BUILD=ON \
      -DBUILD_FALCO_MODERN_BPF=ON \
      ..
make -j$(nproc) falco
```

### Container Image Build

Falco provides container images for deployment. The build process produces multiple image variants:

| Image | Description |
|-------|-------------|
| `falcosecurity/falco` | Full Falco image with driver loader |
| `falcosecurity/falco-no-driver` | Falco without driver artifacts (for modern_ebpf or plugin-only) |
| `falcosecurity/falco-driver-loader` | Driver loader init container |

**Source:** [`refs/falcosecurity/falco/docker/`](../refs/falcosecurity/falco/docker/)

### Versioning in Build

Version information is embedded during CMake configuration:

| Variable | Source | Example |
|----------|--------|---------|
| Falco version | `CMakeLists.txt` / git tag | `0.44.0` |
| Libs version | Fetched from libs repo | `0.25.2` |
| Driver API version | `driver/API_VERSION` | `10.1.0` |
| Schema version | `driver/SCHEMA_VERSION` | `4.5.1` |
| Plugin API version | `userspace/plugin/plugin_api.h` | `3.12.0` |
| Engine version | `falco_engine_version.h` | `0.62.0` |

**Source:** [`refs/falcosecurity/libs/driver/API_VERSION`](../refs/falcosecurity/libs/driver/API_VERSION), [`refs/falcosecurity/libs/driver/SCHEMA_VERSION`](../refs/falcosecurity/libs/driver/SCHEMA_VERSION)

## Non-Functional Requirements

- **Reproducible builds:** Bundled dependencies ensure consistent builds across environments
- **Cross-compilation:** Supported via CMake toolchain files
- **Architecture support:** x86_64 (primary), aarch64, s390x, ppc64le (for modern eBPF)
- **Compiler requirements:** C++17, GCC >= 8 or Clang >= 12

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`architecture-overview.md`](architecture-overview.md) | Component structure being built |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Driver build targets |
| [`libscap.md`](libscap.md) | libscap build target |
| [`libsinsp.md`](libsinsp.md) | libsinsp build target |
| [`plugin-system.md`](plugin-system.md) | Plugin build and distribution |

## Sources

| Topic | Source File |
|-------|-------------|
| Falco root CMake | [`refs/falcosecurity/falco/CMakeLists.txt`](../refs/falcosecurity/falco/CMakeLists.txt) |
| Falco engine CMake | [`refs/falcosecurity/falco/userspace/engine/CMakeLists.txt`](../refs/falcosecurity/falco/userspace/engine/CMakeLists.txt) |
| Falco binary CMake | [`refs/falcosecurity/falco/userspace/falco/CMakeLists.txt`](../refs/falcosecurity/falco/userspace/falco/CMakeLists.txt) |
| CMake modules | [`refs/falcosecurity/falco/cmake/modules/`](../refs/falcosecurity/falco/cmake/modules/) |
| Libs root CMake | [`refs/falcosecurity/libs/CMakeLists.txt`](../refs/falcosecurity/libs/CMakeLists.txt) |
| Driver API version | [`refs/falcosecurity/libs/driver/API_VERSION`](../refs/falcosecurity/libs/driver/API_VERSION) |
| Schema version | [`refs/falcosecurity/libs/driver/SCHEMA_VERSION`](../refs/falcosecurity/libs/driver/SCHEMA_VERSION) |
| Docker files | [`refs/falcosecurity/falco/docker/`](../refs/falcosecurity/falco/docker/) |
| Falco architecture digest | [`digests/falcosecurity/falco/architecture.md`](../digests/falcosecurity/falco/architecture.md) |
| Libs architecture digest | [`digests/falcosecurity/libs/architecture.md`](../digests/falcosecurity/libs/architecture.md) |
