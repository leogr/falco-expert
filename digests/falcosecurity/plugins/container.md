# Container Plugin - Design and Architecture

**Era:** 0.44 | **Status:** Stable | **Scope:** Core | **Version:** 0.7.1 (bundled with Falco 0.44.0)

The `container` plugin is a critical component shipped with Falco that provides container metadata enrichment for syscall events. It is a hybrid C++/Go plugin that retrieves container information from various container runtimes.

**Source:** [`plugins/container/`](../../../refs/falcosecurity/plugins/plugins/container/)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Plugin Capabilities](#plugin-capabilities)
- [C++ Component](#c-component)
- [Go Worker Component](#go-worker-component)
- [Container ID Resolution](#container-id-resolution)
- [Cgroup Matchers](#cgroup-matchers)
- [State Table](#state-table)
- [Event Flow](#event-flow)
- [Configuration](#configuration)
- [Extracted Fields](#extracted-fields)
- [Sources](#sources)

---

## Overview

| Property | Value |
|----------|-------|
| Plugin Name | `container` |
| Plugin API Version | 3.10.0 |
| Minimum Falco Version | 0.41.0 |
| Languages | C++ + Go (static library) |
| Event Source | `syscall` (extraction) |

The plugin reimplements all container-related logic previously present in libs, now exposed as a plugin that can be attached to any source. Key improvements include faster container metadata retrieval to avoid missing event metadata.

**Source:** [`plugins/container/README.md`](../../../refs/falcosecurity/plugins/plugins/container/README.md)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Container Plugin                              │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    C++ Shared Object                         │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │   │
│  │  │   Async     │  │   Parse     │  │     Extract         │  │   │
│  │  │ Capability  │  │ Capability  │  │    Capability       │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │   │
│  │         │                │                     │             │   │
│  │         ▼                ▼                     ▼             │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │        Container Cache (m_containers)                │    │   │
│  │  │     map<string, shared_ptr<container_info>>          │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  │                          │                                   │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │            Cgroup Matchers (matcher_manager)         │    │   │
│  │  │  docker | podman | cri | containerd | lxc | bpm      │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────┬──────────────────────────────┘   │
│                                 │ CGO                               │
│  ┌──────────────────────────────▼──────────────────────────────┐   │
│  │                   Go Worker (Static Library)                 │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │               Container Engines                      │    │   │
│  │  │   Docker | Podman | CRI | Containerd                 │    │   │
│  │  └───────────────────────┬─────────────────────────────┘    │   │
│  │                          │                                   │   │
│  │                          ▼                                   │   │
│  │              Container Runtime Sockets                       │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

The plugin consists of two tightly integrated modules:

1. **C++ Shared Object** ([`src/`](../../../refs/falcosecurity/plugins/plugins/container/src/))
   - Implements all 4 plugin capabilities
   - Maintains the container metadata cache
   - Handles cgroup matching for container ID resolution
   - Communicates with Go worker via CGO

2. **Go Static Library** ([`go-worker/`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/))
   - Implements container runtime SDK integrations
   - Listens for container create/delete events
   - Fetches container metadata on demand
   - Linked statically into the C++ shared object

**Source:** [`plugins/container/README.md`](../../../refs/falcosecurity/plugins/plugins/container/README.md), [`plugins/container/architecture.svg`](../../../refs/falcosecurity/plugins/plugins/container/architecture.svg)

---

## Plugin Capabilities

The plugin implements four capabilities:

| Capability | Purpose | Implementation |
|------------|---------|----------------|
| `capture listening` | Attach container_id to pre-existing threads at startup | [`caps/listening/listening.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/listening/listening.cpp) |
| `extraction` | Extract `container.*` and `k8s.*` fields | [`caps/extract/extract.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/extract/extract.cpp) |
| `parsing` | Parse async and container events, process clone/fork/execve | [`caps/parse/parse.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/parse/parse.cpp) |
| `async` | Generate container added/removed events, dump cache state | [`caps/async/async.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/async/async.cpp) |

**Source:** [`src/plugin.h:55-102`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin.h)

---

## C++ Component

### Main Plugin Class

The `my_plugin` class in [`src/plugin.h`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin.h) implements the Falco plugin API:

```cpp
class my_plugin
{
    private:
    // Container metadata cache: container_id -> container_info
    std::unordered_map<std::string, std::shared_ptr<const container_info>> m_containers;

    // Last container enriched (for extraction during async events)
    std::pair<uint64_t, std::shared_ptr<const container_info>> m_last_container;

    // Cache of container IDs already requested from Go worker
    std::unordered_set<std::string> m_asked_containers;

    // Cgroup matcher manager
    std::unique_ptr<matcher_manager> m_mgr;

    // Thread table accessors
    falcosecurity::table m_threads_table;
    falcosecurity::table_field m_container_id_field;  // Foreign key added to thread table
    // ... additional table field accessors
};
```

**Source:** [`src/plugin.h:121-169`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin.h)

### Container Info Structure

The [`container_info`](../../../refs/falcosecurity/plugins/plugins/container/src/container_info.h) class holds all metadata:

```cpp
class container_info {
    std::string m_id;           // Truncated ID (12 chars)
    std::string m_full_id;      // Full container ID
    container_type m_type;      // CT_DOCKER, CT_CRI, etc.
    std::string m_name;
    std::string m_image;
    std::string m_imageid;
    std::string m_imagerepo;
    std::string m_imagetag;
    std::string m_imagedigest;
    std::string m_container_ip;
    bool m_privileged;
    bool m_host_pid;
    bool m_host_network;
    bool m_host_ipc;
    std::vector<container_mount_info> m_mounts;
    std::vector<container_port_mapping> m_port_mappings;
    std::map<std::string, std::string> m_labels;
    std::list<container_health_probe> m_health_probes;
    // K8s-specific fields
    std::string m_pod_sandbox_id;
    std::map<std::string, std::string> m_pod_sandbox_labels;
    std::string m_pod_sandbox_cniresult;
    bool m_is_pod_sandbox;
    // ...
};
```

**Source:** [`src/container_info.h:90-167`](../../../refs/falcosecurity/plugins/plugins/container/src/container_info.h)

### Container Types

Defined in [`src/container_type.h`](../../../refs/falcosecurity/plugins/plugins/container/src/container_type.h):

| Type | Value | Description |
|------|-------|-------------|
| `CT_DOCKER` | 0 | Docker containers |
| `CT_LXC` | 1 | LXC containers |
| `CT_LIBVIRT_LXC` | 2 | libvirt-lxc containers |
| `CT_CUSTOM` | 5 | Custom containers |
| `CT_CRI` | 6 | CRI-compatible (generic) |
| `CT_CONTAINERD` | 7 | containerd |
| `CT_CRIO` | 8 | CRI-O |
| `CT_BPM` | 9 | BPM containers |
| `CT_STATIC` | 10 | Static container (configured) |
| `CT_PODMAN` | 11 | Podman containers |
| `CT_HOST` | 0xfffe | Host (not a container) |
| `CT_UNKNOWN` | 0xffff | Unknown type |

**Source:** [`src/container_type.h:5-23`](../../../refs/falcosecurity/plugins/plugins/container/src/container_type.h)

### Thread Category Classification

The plugin classifies threads into categories for health probe detection:

```cpp
enum command_category {
    CAT_NONE = 0,
    CAT_CONTAINER,           // vpid == 1 (init process)
    CAT_HEALTHCHECK,         // Docker healthcheck
    CAT_LIVENESS_PROBE,      // K8s liveness probe
    CAT_READINESS_PROBE      // K8s readiness probe
};
```

**Source:** [`src/plugin.h:24-31`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin.h)

---

## Go Worker Component

### Worker API

The Go worker exposes three CGO functions to C++:

| Function | Purpose |
|----------|---------|
| `StartWorker(cb, initCfg, enabledSocks)` | Start the worker, list existing containers, begin listening |
| `StopWorker(pCtx)` | Stop all goroutines and cleanup |
| `AskForContainerInfo(pCtx, containerId)` | Request metadata for a specific container |

**Source:** [`go-worker/worker_api.go`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/worker_api.go)

### Engine Interface

Each container runtime implements the `Engine` interface:

```go
type Engine interface {
    Name() string
    Sock() string
    List(ctx context.Context) ([]event.Event, error)
    Listen(ctx context.Context, wg *sync.WaitGroup) (<-chan event.Event, error)
}
```

Additionally, engines implement:
- `getter` - Fetch single container by ID
- `copier` - Create engine copy for the fetcher

**Source:** [`go-worker/pkg/container/engine.go:97-104`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/pkg/container/engine.go)

### Supported Engines

| Engine | Type | Socket Pattern |
|--------|------|----------------|
| Docker | `docker` | `/var/run/docker.sock` |
| Podman | `podman` | `/run/podman/podman.sock` |
| CRI | `cri` | `/run/containerd/containerd.sock`, `/run/crio/crio.sock` |
| Containerd | `containerd` | `/run/host-containerd/containerd.sock` |

**Source:** [`go-worker/pkg/container/engine.go:28-33`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/pkg/container/engine.go)

### Fetcher Engine

The fetcher is a special "engine" that handles on-demand container lookups:

```go
type fetcher struct {
    getters     []getter       // All enabled engines
    ctx         context.Context
    fetcherChan chan string    // Channel for container ID requests
}
```

When a container ID is requested via `AskForContainerInfo()`:
1. The ID is sent to `fetcherChan`
2. Fetcher loops through all engines trying to `get()` the container
3. If not found, retries every 30ms for up to 150ms
4. On success, publishes event to output channel

**Source:** [`go-worker/pkg/container/fetcher.go`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/pkg/container/fetcher.go)

### Worker Lifecycle

1. **Startup** (`StartWorker`):
   - Parse init config
   - Generate engines for enabled sockets
   - List all existing containers from each engine
   - Call `goCb` for each pre-existing container (with `initialState=true`)
   - Create fetcher engine
   - Start worker goroutine loop

2. **Runtime** (`workerLoop`):
   - Listen on all engine channels
   - Call `goCb` for container add/remove events
   - Handle fetcher requests

3. **Shutdown** (`StopWorker`):
   - Cancel context
   - Wait for goroutines
   - Close fetcher channel

**Source:** [`go-worker/worker_api.go:32-138`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/worker_api.go)

---

## Container ID Resolution

### Resolution Flow

When a new process event (clone/fork/execve) is parsed:

1. **Get thread cgroups** from the thread table
2. **Match cgroup path** against enabled matchers
3. **Extract container ID** from matching cgroup pattern
4. **Write container_id** to thread table entry as foreign key
5. **Request metadata** from Go worker if not in cache

```cpp
std::string my_plugin::compute_container_id_for_thread(
        const falcosecurity::table_entry& thread_entry,
        const falcosecurity::table_reader& tr,
        container_info::ptr_t& info)
{
    // Get cgroups table of the thread
    auto cgroups_table = m_threads_table.get_subtable(
            tr, m_threads_field_cgroups, thread_entry, ...);

    cgroups_table.iterate_entries(tr, [&](const falcosecurity::table_entry& e) {
        std::string cgroup;
        m_cgroups_field_second.read_value(tr, e, cgroup);
        if(!cgroup.empty()) {
            m_mgr->match_cgroup(cgroup, container_id, info);
            if(!container_id.empty()) return false; // break
        }
        return true;
    });
    return container_id;
}
```

**Source:** [`src/plugin.cpp:179-216`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin.cpp)

---

## Cgroup Matchers

### Matcher Interface

Each container type has a cgroup matcher:

```cpp
class cgroup_matcher {
    virtual bool resolve(const std::string& cgroup, std::string& container_id) = 0;

    // For engines without listener SDK (lxc, bpm, libvirt_lxc)
    // Returns container_info immediately without waiting for Go worker
    virtual container_info::ptr_t to_container(const std::string& container_id) {
        return nullptr;
    }
};
```

**Source:** [`src/matchers/matcher.h`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/matcher.h)

### Matcher Manager

The manager maintains an ordered list of matchers and an LRU cache:

```cpp
class matcher_manager {
    std::vector<std::shared_ptr<cgroup_matcher>> m_cgroup_matchers;
    LRU<std::string, std::pair<std::string, std::shared_ptr<cgroup_matcher>>>
            m_cgroup_cinfo_cache;

    bool match_cgroup(const std::string& cgroup,
                      std::string& container_id,
                      container_info::ptr_t& ctr);
};
```

Matchers are added based on configuration:
1. podman (if enabled)
2. docker (if enabled)
3. cri (if enabled)
4. containerd (if enabled)
5. lxc (if enabled)
6. libvirt_lxc (if enabled)
7. bpm (if enabled)

**Source:** [`src/matchers/matcher.cpp:11-57`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/matcher.cpp)

### Available Matchers

| Matcher | File | Pattern Example |
|---------|------|-----------------|
| Docker | [`docker.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/docker.cpp) | `/docker/<container_id>` |
| Podman | [`podman.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/podman.cpp) | `/libpod-<container_id>` |
| CRI | [`cri.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/cri.cpp) | `cri-containerd-<container_id>` |
| Containerd | [`containerd.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/containerd.cpp) | `/containerd/<container_id>` |
| LXC | [`lxc.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/lxc.cpp) | `/lxc/<container_name>` |
| libvirt_lxc | [`libvirt_lxc.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/libvirt_lxc.cpp) | `/machine-lxc...` |
| BPM | [`bpm.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/bpm.cpp) | `/bpm-...` |

---

## State Table

The plugin exposes the container cache as a libsinsp-compatible state table named `containers`:

### Exposed Fields

| Field | Type | Description |
|-------|------|-------------|
| `ip` | string | Container IP address |
| `user` | string | Container user |
| `id` | string | Container ID |
| `image` | string | Container image |
| `name` | string | Container name |
| `type` | uint32 | Container type enum |

### Table Operations

```cpp
// Table is keyed by container ID (string)
input.key_type = st::SS_PLUGIN_ST_STRING;
input.table = (void*)&m_containers;
```

Supported operations:
- `get_table_entry` - Lookup by container ID
- `read_entry_field` - Read container field
- `iterate_entries` - Iterate all containers
- `erase_table_entry` - Remove container
- `clear_table` - Clear all containers

**Source:** [`src/table.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/table.cpp)

---

## Event Flow

### Parsed Events

The plugin parses these event types:

| Event Type | Handler | Purpose |
|------------|---------|---------|
| `PPME_ASYNCEVENT_E` | `parse_async_event` | Container added/removed from Go worker |
| `PPME_CONTAINER_E` | `parse_container_event` | Legacy container event (backward compat) |
| `PPME_CONTAINER_JSON_E` | `parse_container_json_event` | JSON container event (backward compat) |
| `PPME_CONTAINER_JSON_2_E` | `parse_container_json_2_event` | Large payload JSON event |
| `PPME_SYSCALL_CLONE*_X` | `parse_new_process_event` | New process - attach container_id |
| `PPME_SYSCALL_FORK*_X` | `parse_new_process_event` | New process - attach container_id |
| `PPME_SYSCALL_EXECVE*_X` | `parse_new_process_event` | New process - attach container_id |
| `PPME_SYSCALL_EXECVEAT_X` | `parse_new_process_event` | New process - attach container_id |
| `PPME_SYSCALL_CHROOT_X` | `parse_new_process_event` | chroot - re-evaluate container_id |
| `PPME_PROCEXIT_1_E` | `parse_exit_process_event` | Process exit - cleanup if vpid==1 |

**Source:** [`src/consts.h:24-38`](../../../refs/falcosecurity/plugins/plugins/container/src/consts.h), [`src/caps/parse/parse.cpp:297-331`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/parse/parse.cpp)

### Async Event Generation

When Go worker finds a new container or container exits:

1. Go worker calls `goCb` with JSON container info
2. `goCb` calls C callback via `makeCallback()`
3. C++ `generate_async_event()` creates `PPME_ASYNCEVENT_E`
4. Event name: `container_added` or `container_removed`
5. Event is injected into syscall event stream
6. Parse capability processes the async event
7. Container cache is updated

**Source:** [`src/caps/async/async.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/async/async.cpp)

---

## Configuration

### Plugin Configuration Schema

```cpp
struct PluginConfig {
    int label_max_len;    // Default: 100
    bool with_size;       // Default: false (slow operation)
    uint8_t hooks;        // HOOK_CREATE (1) or HOOK_START (2)
    std::string host_root; // From HOST_ROOT env var
    std::string log_level; // Default: "info"
    Engines engines;
};
```

**Source:** [`src/plugin_config.h:59-78`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin_config.h)

### Engine Configuration

```cpp
struct Engines {
    SimpleEngine bpm;        // enabled: true
    SimpleEngine lxc;        // enabled: true
    SimpleEngine libvirt_lxc; // enabled: true
    SocketsEngine docker;    // enabled: true, sockets: [...]
    SocketsEngine podman;    // enabled: true, sockets: [...]
    SocketsEngine cri;       // enabled: true, sockets: [...]
    SocketsEngine containerd; // enabled: true, sockets: [...]
    StaticEngine static_ctr; // enabled: false
};
```

**Source:** [`src/plugin_config.h:47-57`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin_config.h)

### Default Socket Paths

| Engine | Default Sockets |
|--------|-----------------|
| Docker | `/var/run/docker.sock` |
| Podman | `/run/podman/podman.sock`, `/run/user/$uid/podman/podman.sock` |
| Containerd | `/run/host-containerd/containerd.sock` |
| CRI | `/run/containerd/containerd.sock`, `/run/crio/crio.sock`, `/run/k3s/containerd/containerd.sock` |

### Example Configuration

```yaml
plugins:
  - name: container
    library_path: libcontainer.so
    init_config:
      label_max_len: 100
      with_size: false
      hooks: ['create', 'start']
      engines:
        docker:
          enabled: true
          sockets: ['/var/run/docker.sock']
        podman:
          enabled: true
          sockets: ['/run/podman/podman.sock']
        cri:
          enabled: true
          sockets: ['/run/crio/crio.sock']
        containerd:
          enabled: true
          sockets: ['/run/containerd/containerd.sock']
        lxc:
          enabled: false
        libvirt_lxc:
          enabled: false
        bpm:
          enabled: false
```

---

## Extracted Fields

### Container Fields

| Field | Type | Description |
|-------|------|-------------|
| `container.id` | string | Truncated ID (12 chars), "host" for non-container |
| `container.full_id` | string | Full container ID |
| `container.name` | string | Container name |
| `container.image` | string | Image name (e.g., `falcosecurity/falco:latest`) |
| `container.image.id` | string | Image ID |
| `container.image.repository` | string | Image repository |
| `container.image.tag` | string | Image tag |
| `container.image.digest` | string | Image digest |
| `container.type` | string | Container type (docker, cri-o, etc.) |
| `container.privileged` | bool | Running as privileged |
| `container.mounts` | string | Space-separated mount info |
| `container.mount[idx/src]` | string | Single mount info |
| `container.mount.source[...]` | string | Mount source |
| `container.mount.dest[...]` | string | Mount destination |
| `container.ip` | string | Container IP (IPv4 only) |
| `container.cni.json` | string | CNI result JSON |
| `container.host_pid` | bool | Using host PID namespace |
| `container.host_network` | bool | Using host network namespace |
| `container.host_ipc` | bool | Using host IPC namespace |
| `container.label[key]` | string | Container label by key |
| `container.labels` | string | All labels comma-separated |
| `container.healthcheck` | string | Docker healthcheck command |
| `container.liveness_probe` | string | K8s liveness probe |
| `container.readiness_probe` | string | K8s readiness probe |
| `container.start_ts` | abstime | Container start timestamp |
| `container.duration` | reltime | Time since start |

### Kubernetes Fields (from container runtime)

| Field | Type | Description |
|-------|------|-------------|
| `k8s.pod.name` | string | Pod name |
| `k8s.ns.name` | string | Namespace name |
| `k8s.pod.uid` | string | Pod UID |
| `k8s.pod.sandbox_id` | string | Pod sandbox ID (12 chars) |
| `k8s.pod.full_sandbox_id` | string | Full sandbox ID |
| `k8s.pod.label[key]` | string | Pod label |
| `k8s.pod.labels` | string | All pod labels |
| `k8s.pod.ip` | string | Pod IP |
| `k8s.pod.cni.json` | string | Pod CNI result JSON |

### Process Health Check Fields

| Field | Type | Description |
|-------|------|-------------|
| `proc.is_container_healthcheck` | bool | Part of container healthcheck |
| `proc.is_container_liveness_probe` | bool | Part of liveness probe |
| `proc.is_container_readiness_probe` | bool | Part of readiness probe |

### Deprecated Fields

These fields are deprecated; use `k8smeta` plugin instead:
- `k8s.rc.*` - Replication controller
- `k8s.svc.*` - Service
- `k8s.ns.id`, `k8s.ns.label[...]`, `k8s.ns.labels`
- `k8s.rs.*` - ReplicaSet
- `k8s.deployment.*` - Deployment

**Source:** [`src/caps/extract/extract.cpp:9-74`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/extract/extract.cpp)

---

## Sources

| Topic | Source File |
|-------|-------------|
| Plugin overview | [`README.md`](../../../refs/falcosecurity/plugins/plugins/container/README.md) |
| Architecture diagram | [`architecture.svg`](../../../refs/falcosecurity/plugins/plugins/container/architecture.svg) |
| Main plugin class | [`src/plugin.h`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin.h) |
| Plugin initialization | [`src/plugin.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin.cpp) |
| Container info structure | [`src/container_info.h`](../../../refs/falcosecurity/plugins/plugins/container/src/container_info.h) |
| Container types | [`src/container_type.h`](../../../refs/falcosecurity/plugins/plugins/container/src/container_type.h) |
| Configuration | [`src/plugin_config.h`](../../../refs/falcosecurity/plugins/plugins/container/src/plugin_config.h) |
| Cgroup matchers | [`src/matchers/matcher.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/matchers/matcher.cpp) |
| State table | [`src/table.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/table.cpp) |
| Async capability | [`src/caps/async/async.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/async/async.cpp) |
| Parse capability | [`src/caps/parse/parse.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/parse/parse.cpp) |
| Extract capability | [`src/caps/extract/extract.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/extract/extract.cpp) |
| Listening capability | [`src/caps/listening/listening.cpp`](../../../refs/falcosecurity/plugins/plugins/container/src/caps/listening/listening.cpp) |
| Go worker API | [`go-worker/worker_api.go`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/worker_api.go) |
| Engine interface | [`go-worker/pkg/container/engine.go`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/pkg/container/engine.go) |
| Fetcher engine | [`go-worker/pkg/container/fetcher.go`](../../../refs/falcosecurity/plugins/plugins/container/go-worker/pkg/container/fetcher.go) |
| Event constants | [`src/consts.h`](../../../refs/falcosecurity/plugins/plugins/container/src/consts.h) |
