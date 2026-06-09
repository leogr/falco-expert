# Build Reference

CMake flags, build targets, and container mode capabilities.

---

## Falco CMake Flags

| Flag | Default | Description |
|------|---------|-------------|
| `USE_BUNDLED_DEPS` | `ON` | Fetch and build all dependencies |
| `BUILD_FALCO_MODERN_BPF` | `ON` | Enable modern eBPF support (Linux only) |
| `MINIMAL_BUILD` | `OFF` | Disable gRPC server and webserver |
| `MUSL_OPTIMIZED_BUILD` | `OFF` | Static linking with musl libc |
| `BUILD_FALCO_UNIT_TESTS` | `OFF` | Build Falco unit tests (`falco_unit_tests` target) |
| `BUILD_WARNINGS_AS_ERRORS` | `OFF` | Treat compiler warnings as errors |
| `FALCOSECURITY_LIBS_SOURCE_DIR` | (unset) | Path to local libs checkout |
| `FALCOSECURITY_LIBS_VERSION` | `0.25.2` | Git ref for libs when fetched remotely |
| `FALCOSECURITY_LIBS_REPO` | `falcosecurity/libs` | GitHub repo for libs (for testing forks) |
| `CMAKE_BUILD_TYPE` | (unset) | `Release`, `Debug`, `RelWithDebInfo` |

**Source:** [`refs/falcosecurity/falco/CMakeLists.txt`](../../../refs/falcosecurity/falco/CMakeLists.txt), [`refs/falcosecurity/falco/cmake/modules/falcosecurity-libs.cmake`](../../../refs/falcosecurity/falco/cmake/modules/falcosecurity-libs.cmake)

---

## Libs CMake Flags

| Flag | Default | Description |
|------|---------|-------------|
| `USE_BUNDLED_DEPS` | `ON` | Fetch and build all dependencies |
| `BUILD_LIBSCAP_MODERN_BPF` | `OFF` | Enable modern eBPF in libscap |
| `BUILD_BPF` | `OFF` | Build legacy eBPF probe (deprecated, defined in `driver/bpf/CMakeLists.txt`) |
| `BUILD_DRIVER` | `ON` | Build kernel module (defined in `driver/CMakeLists.txt`) |
| `CREATE_TEST_TARGETS` | `ON` | Build test binaries (`sinsp-example`, `scap-open`, unit tests) |
| `CMAKE_BUILD_TYPE` | (unset) | `Release`, `Debug`, `RelWithDebInfo` |

**Source:** [`refs/falcosecurity/libs/CMakeLists.txt`](../../../refs/falcosecurity/libs/CMakeLists.txt)

---

## Container Modes

### Docker Flags per Mode

| Flag | Safe | Least-Privilege | Privileged |
|------|------|-----------------|------------|
| `--cap-add SYS_PTRACE` | - | Yes | (included) |
| `--cap-add BPF` | - | Yes | (included) |
| `--cap-add PERFMON` | - | Yes | (included) |
| `--cap-add SYS_RESOURCE` | - | Yes | (included) |
| `--privileged` | - | - | Yes |
| `-v /proc:/host/proc:ro` | - | Yes | Yes |
| `-v /etc:/host/etc:ro` | - | - | Yes |
| `-v /var/run/docker.sock:...` | - | - | Yes |

### What Each Mode Enables

| Capability | Safe | Least-Privilege | Privileged |
|-----------|------|-----------------|------------|
| CMake build (falco, libs) | Yes | Yes | Yes |
| Unit tests (CTest) | Yes | Yes | Yes |
| `falco -V` (rules validation) | Yes | Yes | Yes |
| `falco --dry-run` | Yes | Yes | Yes |
| `falco --list` (field listing) | Yes | Yes | Yes |
| `falco --list-plugins` | Yes | Yes | Yes |
| .scap replay (`sinsp-example -s`) | Yes | Yes | Yes |
| GDB launch mode (`gdb --args ...`) | Yes | Yes | Yes |
| GDB attach mode (`gdb -p <pid>`) | - | Yes | Yes |
| `sinsp-example` modern_ebpf live | - | Yes | Yes |
| `scap-open` modern_ebpf live | - | Yes | Yes |
| `falco` daemon (modern_ebpf) | - | - | Yes |
| Kernel module loading | - | - | Yes |
| Docker socket access | - | - | Yes |
