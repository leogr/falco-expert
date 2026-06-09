# k8smeta Plugin - Kubernetes Metadata Enrichment

**Era:** 0.44 | **Status:** Stable | **Scope:** Core

The `k8smeta` plugin enriches Falco syscall events with Kubernetes metadata by connecting to the [`k8s-metacollector`](../k8s-metacollector.md) service. It provides fields like pod name, namespace, deployment, services, and labels for processes running inside Kubernetes pods.

**Source:** [`plugins/k8smeta/`](../../../refs/falcosecurity/plugins/plugins/k8smeta/)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Plugin Capabilities](#plugin-capabilities)
- [Supported Fields](#supported-fields)
- [Configuration](#configuration)
- [State Tables](#state-tables)
- [gRPC Client](#grpc-client)
- [Pod UID Resolution](#pod-uid-resolution)
- [Event Flow](#event-flow)
- [Usage](#usage)
- [Sources](#sources)

---

## Overview

| Property | Value |
|----------|-------|
| Plugin Name | `k8smeta` |
| Plugin Version | 0.4.1 |
| Minimum Falco Version | 0.40.0 |
| Plugin API Version | 3.9.0 |
| Event Schema Version | 4.0.0 |
| Language | C++ |
| Event Source | `syscall` (extraction/parsing) |

The k8smeta plugin implements a client-server architecture for Kubernetes metadata enrichment:

- **Plugin (k8smeta)**: Runs alongside each Falco instance, receives metadata from collector
- **Collector ([k8s-metacollector](../k8s-metacollector.md))**: Centralized service that watches Kubernetes API server

This architecture avoids the scalability issues of having every Falco instance connect directly to the Kubernetes API server.

**Source:** [`README.md:5-9`](../../../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            k8smeta Plugin                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        Plugin Capabilities                            │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────────┐  │  │
│  │  │    Async    │ │   Parse     │ │  Extract    │ │    Capture     │  │  │
│  │  │ (gRPC recv) │ │ (state upd) │ │ (field get) │ │   Listening    │  │  │
│  │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └───────┬────────┘  │  │
│  │         │               │               │                 │           │  │
│  │         │               │               │                 │           │  │
│  │         ▼               ▼               ▼                 ▼           │  │
│  └─────────┴───────────────┴───────────────┴─────────────────┴───────────┘  │
│                                    │                                        │
│                           ┌────────▼────────┐                               │
│                           │  State Tables   │                               │
│                           │ ┌─────────────┐ │                               │
│                           │ │ m_pod_table │ │                               │
│                           │ │ m_ns_table  │ │                               │
│                           │ │ m_dpl_table │ │                               │
│                           │ │ m_svc_table │ │                               │
│                           │ │ m_rs_table  │ │                               │
│                           │ │ m_rc_table  │ │                               │
│                           │ └─────────────┘ │                               │
│                           └────────┬────────┘                               │
│                                    │                                        │
│                           ┌────────▼────────┐                               │
│                           │   gRPC Client   │                               │
│                           │ (K8sMetaClient) │                               │
│                           └────────┬────────┘                               │
│                                    │                                        │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │ gRPC stream
                            ┌────────▼────────┐
                            │ k8s-metacollector│
                            │    (cluster)    │
                            └─────────────────┘
```

**Source:** [`src/plugin.h:56-292`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.h)

---

## Plugin Capabilities

The k8smeta plugin implements four capabilities:

| Capability | Purpose |
|------------|---------|
| **Async** | Receives metadata events from k8s-metacollector via gRPC |
| **Parse** | Updates internal state tables from async events and process syscalls |
| **Extract** | Provides k8smeta.* fields for rule conditions and outputs |
| **Capture Listening** | Enriches existing thread table entries at capture start |

**Source:** [`README.md:11-19`](../../../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

### Async Capability

Maintains a background thread that:
1. Connects to k8s-metacollector via gRPC
2. Subscribes to metadata for the configured node
3. Receives Create/Update/Delete events for Kubernetes resources
4. Injects events into the syscall event stream

**Async Event Name:** `k8s`

```cpp
#define ASYNC_EVENT_NAME "k8s"
#define ASYNC_EVENT_SOURCES { "syscall" }
```

**Source:** [`src/shared_with_tests_consts.h:25-33`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/shared_with_tests_consts.h)

### Parse Capability

Parses two types of events:

1. **Async events** (`PPME_ASYNCEVENT_E`): Updates state tables with metadata from collector
2. **Process events**: Attaches pod UID to new processes based on cgroup

**Parsed Event Types:**
```cpp
PPME_ASYNCEVENT_E, PPME_SYSCALL_EXECVE_19_X, PPME_SYSCALL_EXECVEAT_X,
PPME_SYSCALL_CLONE_20_X, PPME_SYSCALL_FORK_20_X, PPME_SYSCALL_VFORK_20_X,
PPME_SYSCALL_CLONE3_X
```

**Source:** [`src/shared_with_tests_consts.h:51-56`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/shared_with_tests_consts.h)

### Extract Capability

Provides field extraction for syscall events. The plugin:
1. Gets thread ID from the event
2. Looks up pod UID from thread table
3. Retrieves pod metadata from internal tables
4. Extracts the requested field value

**Source:** [`src/plugin.cpp:995-1142`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.cpp)

### Capture Listening Capability

At capture open time, iterates through all existing thread table entries and enriches them with pod UIDs based on their cgroup paths.

**Source:** [`src/plugin.cpp:324-352`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.cpp)

---

## Supported Fields

The plugin provides 24 fields across 6 Kubernetes resource types:

### Pod Fields

| Field | Type | Description |
|-------|------|-------------|
| `k8smeta.pod.name` | string | Pod name (suggested output) |
| `k8smeta.pod.uid` | string | Pod UID |
| `k8smeta.pod.label[key]` | string | Specific label value |
| `k8smeta.pod.labels` | string list | All labels as `(k1:v1,k2:v2)` |
| `k8smeta.pod.ip` | string | Pod IP address |

### Namespace Fields

| Field | Type | Description |
|-------|------|-------------|
| `k8smeta.ns.name` | string | Namespace name (suggested output) |
| `k8smeta.ns.uid` | string | Namespace UID |
| `k8smeta.ns.label[key]` | string | Specific label value |
| `k8smeta.ns.labels` | string list | All labels |

### Deployment Fields

| Field | Type | Description |
|-------|------|-------------|
| `k8smeta.deployment.name` | string | Deployment name |
| `k8smeta.deployment.uid` | string | Deployment UID |
| `k8smeta.deployment.label[key]` | string | Specific label value |
| `k8smeta.deployment.labels` | string list | All labels |

### Service Fields

| Field | Type | Description |
|-------|------|-------------|
| `k8smeta.svc.name` | string list | Names of all services for pod |
| `k8smeta.svc.uid` | string list | UIDs of all services for pod |
| `k8smeta.svc.label[key]` | string list | Label values from all services |
| `k8smeta.svc.labels` | string list | All labels from all services |

### ReplicaSet Fields

| Field | Type | Description |
|-------|------|-------------|
| `k8smeta.rs.name` | string | ReplicaSet name |
| `k8smeta.rs.uid` | string | ReplicaSet UID |
| `k8smeta.rs.label[key]` | string | Specific label value |
| `k8smeta.rs.labels` | string list | All labels |

### ReplicationController Fields

| Field | Type | Description |
|-------|------|-------------|
| `k8smeta.rc.name` | string | ReplicationController name |
| `k8smeta.rc.uid` | string | ReplicationController UID |
| `k8smeta.rc.label[key]` | string | Specific label value |
| `k8smeta.rc.labels` | string list | All labels |

**Source:** [`README.md:24-54`](../../../refs/falcosecurity/plugins/plugins/k8smeta/README.md), [`src/plugin.cpp:419-542`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.cpp)

---

## Configuration

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `collectorHostname` | string | k8s-metacollector hostname/IP |
| `collectorPort` | integer | k8s-metacollector port (default: 45000) |
| `nodeName` | string | Kubernetes node name for filtering |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `verbosity` | string | `info` | Log level: trace, debug, info, warning, error, critical |
| `caPEMBundle` | string | (none) | Path to CA certificate for TLS |
| `hostProc` | string | `/host` | **DEPRECATED** - No longer used |

**Source:** [`src/plugin.cpp:88-143`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.cpp)

### Example Configuration

```yaml
plugins:
  - name: k8smeta
    library_path: libk8smeta.so
    init_config:
      collectorPort: 45000
      collectorHostname: k8s-metacollector.metacollector.svc
      nodeName: "${FALCO_K8S_NODE_NAME}"  # Set via Downward API
      verbosity: warning
      caPEMBundle: /etc/ssl/certs/ca-certificates.crt

load_plugins: [k8smeta]
```

### Dynamic Node Name (DaemonSet)

When running Falco as a DaemonSet, the `nodeName` must be set dynamically using Kubernetes Downward API:

```yaml
env:
  - name: FALCO_K8S_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
```

**Source:** [`README.md:60-109`](../../../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

---

## State Tables

The plugin maintains internal hash tables for each resource type:

| Table | Key | Content |
|-------|-----|---------|
| `m_pod_table` | Pod UID | Pod metadata, status, references |
| `m_namespace_table` | Namespace UID | Namespace metadata |
| `m_deployment_table` | Deployment UID | Deployment metadata |
| `m_service_table` | Service UID | Service metadata |
| `m_replicaset_table` | ReplicaSet UID | ReplicaSet metadata |
| `m_replication_controller_table` | RC UID | ReplicationController metadata |
| `m_deamonset_table` | DaemonSet UID | DaemonSet metadata |

### Resource Layout

Each cached resource contains:

```cpp
struct resource_layout {
    std::string uid;            // Kubernetes UID
    std::string kind;           // Resource kind (Pod, Namespace, etc.)
    nlohmann::json meta;        // Metadata (name, namespace, labels)
    nlohmann::json spec;        // Spec fields
    nlohmann::json status;      // Status fields (e.g., podIP)
    nlohmann::json refs;        // References to related resources
};
```

**Source:** [`src/plugin.h:28-48`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.h), [`src/plugin.h:272-279`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.h)

### Thread Table Integration

The plugin adds a `pod_uid` field to Falco's thread table, allowing efficient lookup of pod metadata for any thread:

```cpp
#define THREAD_TABLE_NAME "threads"
#define CGROUPS_TABLE_NAME "cgroups"
#define POD_UID_FIELD_NAME "pod_uid"
```

**Source:** [`src/shared_with_tests_consts.h:66-68`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/shared_with_tests_consts.h)

---

## gRPC Client

The `K8sMetaClient` class implements gRPC streaming to receive metadata events:

```cpp
class K8sMetaClient : public grpc::ClientReadReactor<metadata::Event>
```

### Connection Behavior

- **Backoff**: Exponential backoff from 1s to 120s on connection failure
- **TLS**: Optional TLS with custom CA certificate
- **Reconnection**: Automatic reconnection with backoff

**Source:** [`src/grpc_client.h:27-64`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/grpc_client.h)

### Event Processing

When an event is received from the collector:

1. Parse JSON payload from gRPC message
2. Extract `reason` (Create/Update/Delete), `uid`, and `kind`
3. Update corresponding state table

```cpp
#define REASON_CREATE "Create"
#define REASON_UPDATE "Update"
#define REASON_DELETE "Delete"
```

**Source:** [`src/shared_with_tests_consts.h:73-75`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/shared_with_tests_consts.h)

---

## Pod UID Resolution

The plugin resolves pod UID from process cgroup paths using regex:

```cpp
static re2::RE2 pattern(RGX_POD, re2::RE2::POSIX);
```

### Cgroup Patterns

Supports both cgroup v1 and v2:

**Cgroup v2:**
```
0::/kubepods.slice/kubepods-besteffort.slice/kubepods-besteffort-pod93f64796_43b9_468d_b77b_c652c985d5e0.slice
```

**Cgroup v1:**
```
12:perf_event:/kubepods.slice/kubepods-besteffort.slice/kubepods-besteffort-pod93f64796_43b9_468d_b77b_c652c985d5e0.slice
```

### Pod UID Extraction

The extracted UID is normalized:
1. Remove `pod` prefix
2. Convert underscores to hyphens (systemd driver)
3. Result: `93f64796-43b9-468d-b77b-c652c985d5e0`

**Source:** [`src/plugin.cpp:55-82`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.cpp)

---

## Event Flow

```
                    k8s-metacollector
                          │
                          │ gRPC stream (metadata events)
                          ▼
               ┌──────────────────────┐
               │   Async Capability   │
               │ (K8sMetaClient loop) │
               └──────────┬───────────┘
                          │ Inject async event
                          ▼
               ┌──────────────────────┐
               │   Parse Capability   │
               │ (parse_async_event)  │
               └──────────┬───────────┘
                          │ Update state tables
                          ▼
               ┌──────────────────────┐
               │    State Tables      │
               │ (pod, ns, dpl, etc.) │
               └──────────────────────┘
                          │
         ┌────────────────┴────────────────┐
         │                                 │
         ▼                                 ▼
┌─────────────────────┐        ┌─────────────────────┐
│  Syscall Event      │        │  Extract Capability │
│  (execve, clone)    │        │  (field requests)   │
└─────────┬───────────┘        └─────────┬───────────┘
          │                              │
          │ parse_process_events         │ extract()
          ▼                              │
┌─────────────────────┐                  │
│  Attach pod_uid to  │                  │
│  thread table entry │                  │
└─────────────────────┘                  │
                                         │
          ┌──────────────────────────────┘
          │
          ▼
┌─────────────────────┐
│  Look up pod_uid    │
│  from thread entry  │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Get resource from  │
│  state table        │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  Return field value │
└─────────────────────┘
```

**Source:** [`src/plugin.cpp`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.cpp)

---

## Usage

### Minimum Falco Version

| Plugin Version | Falco Version |
|----------------|---------------|
| 0.4.x | >= 0.40.0 |
| 0.2.x | >= 0.37.0, < 0.40.0 |

### Example Rule

```yaml
- rule: K8s Pod Shell Spawned
  desc: Detect shell spawned in a Kubernetes pod
  condition: spawned_process and container and proc.name in (shell_binaries)
  output: >
    Shell spawned in pod (pod=%k8smeta.pod.name ns=%k8smeta.ns.name
    deployment=%k8smeta.deployment.name command=%proc.cmdline)
  priority: WARNING
```

**Source:** [`README.md:119-131`](../../../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

### Suggested Output Fields

The plugin marks two fields as suggested output fields:
- `k8smeta.pod.name`
- `k8smeta.ns.name`

These will be automatically included in alert outputs.

**Source:** [`src/plugin.cpp:424-432`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.cpp)

---

## Comparison: k8smeta vs container plugin

| Aspect | k8smeta | container |
|--------|---------|-----------|
| **Data Source** | k8s-metacollector (gRPC) | Container runtime sockets |
| **Scope** | Kubernetes resources | Container runtime |
| **Field Prefix** | `k8smeta.*` | `container.*` |
| **Pod Metadata** | name, uid, labels, IP | id, image, name |
| **Namespace** | K8s namespace with UID/labels | N/A |
| **Workloads** | Deployment, ReplicaSet, DaemonSet, etc. | N/A |
| **Services** | K8s Services | N/A |
| **Dependency** | k8s-metacollector service | Container runtime |

The plugins are complementary:
- **container plugin**: Container-level details from runtime
- **k8smeta plugin**: Kubernetes object-level details from API server

**Source:** [`README.md:5-9`](../../../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

---

## Version History

| Version | Release | Changes |
|---------|---------|---------|
| v0.4.1 | Current | Dynamic nodeName clarification |
| v0.4.0 | - | Bump to plugin API 3.9.0, event schema 4.0.0 |
| v0.3.1 | - | Drop experimental status |
| v0.3.0 | - | Major update, libs 0.20.0 |
| v0.2.1 | - | Logging adjustments |
| v0.2.0 | - | Proc-scan for initial state recovery |
| v0.1.0 | - | Initial release |

**Source:** [`CHANGELOG.md`](../../../refs/falcosecurity/plugins/plugins/k8smeta/CHANGELOG.md)

---

## Sources

| Topic | Source File |
|-------|-------------|
| README & Fields | [`README.md`](../../../refs/falcosecurity/plugins/plugins/k8smeta/README.md) |
| Plugin Header | [`src/plugin.h`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.h) |
| Plugin Implementation | [`src/plugin.cpp`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/plugin.cpp) |
| gRPC Client | [`src/grpc_client.h`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/grpc_client.h) |
| Constants | [`src/shared_with_tests_consts.h`](../../../refs/falcosecurity/plugins/plugins/k8smeta/src/shared_with_tests_consts.h) |
| Changelog | [`CHANGELOG.md`](../../../refs/falcosecurity/plugins/plugins/k8smeta/CHANGELOG.md) |
| k8s-metacollector | [`k8s-metacollector.md`](../k8s-metacollector.md) |
