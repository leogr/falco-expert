# k8s-metacollector - Kubernetes Metadata Collector

**Era:** 0.44 | **Status:** Incubating | **Scope:** Ecosystem

The `k8s-metacollector` is a centralized Kubernetes metadata collection service that gathers metadata from Kubernetes resources and streams it to Falco instances via gRPC. It addresses the scalability limitations of the traditional approach where each Falco instance connects directly to the Kubernetes API server.

**Source:** [`refs/falcosecurity/k8s-metacollector/`](../../refs/falcosecurity/k8s-metacollector/) (v0.1.2)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Collected Resource Types](#collected-resource-types)
- [gRPC Protocol](#grpc-protocol)
- [Collectors](#collectors)
- [Broker](#broker)
- [Deployment](#deployment)
- [CLI Reference](#cli-reference)
- [Prometheus Metrics](#prometheus-metrics)
- [Integration with Falco](#integration-with-falco)
- [Sources](#sources)

---

## Overview

| Property | Value |
|----------|-------|
| Repository Status | Incubating |
| Current Version | v0.1.2 |
| Go Version | 1.26 |
| gRPC Port | 45000 (default) |
| Metrics Port | 8080 |
| Health Probe Port | 8081 |

### Problem Statement

In traditional Falco deployments, every Falco instance (one per node in a DaemonSet) connects to the Kubernetes API server to fetch metadata for container enrichment. This approach has significant scalability issues in large clusters:

- **API Server Load**: N Falco instances × M watch connections = N×M connections to API server
- **Redundant Data Transfer**: Each instance receives full cluster-wide events even though it only needs node-local data
- **Resource Waste**: Each instance processes and caches duplicate metadata

**Source:** [`README.md:11-18`](../../refs/falcosecurity/k8s-metacollector/README.md), [libs issue #987](https://github.com/falcosecurity/libs/issues/987)

### Solution

The k8s-metacollector introduces a centralized architecture:

```
                          ┌───────────────────────┐
                          │  Kubernetes API Server │
                          └───────────┬───────────┘
                                      │ (single client)
                          ┌───────────▼───────────┐
                          │   k8s-metacollector   │
                          │  (centralized broker) │
                          └───────────┬───────────┘
                                      │ gRPC streams
              ┌───────────────────────┼───────────────────────┐
              │                       │                       │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐   ┌─────────▼─────────┐
    │   Falco Node 1    │   │   Falco Node 2    │   │   Falco Node N    │
    │  (filtered data)  │   │  (filtered data)  │   │  (filtered data)  │
    └───────────────────┘   └───────────────────┘   └───────────────────┘
```

**Key Benefits:**

1. **Reduced API Server Load**: Single connection to API server instead of N connections
2. **Node-Filtered Data**: Each Falco instance receives only metadata relevant to its node
3. **Pre-Processed Metadata**: Data is ready for use without further processing by subscribers
4. **Intelligent Filtering**: Only resources running on or related to a specific node are sent

**Source:** [`README.md:20-38`](../../refs/falcosecurity/k8s-metacollector/README.md)

---

## Architecture

The k8s-metacollector uses the Kubernetes controller-runtime framework to watch resources and stream filtered metadata to subscribers.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            k8s-metacollector                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    Controller-Runtime Manager                         │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────────┐ │  │
│  │  │ Pod         │ │ Deployment  │ │ ReplicaSet  │ │ Namespace       │ │  │
│  │  │ Collector   │ │ Collector   │ │ Collector   │ │ Collector       │ │  │
│  │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └────────┬────────┘ │  │
│  │         │               │               │                  │          │  │
│  │  ┌──────┴──────┐ ┌──────┴──────┐ ┌──────┴──────┐ ┌────────┴────────┐ │  │
│  │  │ Service     │ │ DaemonSet   │ │ ReplicaCtrl │ │ EndpointSlice   │ │  │
│  │  │ Collector   │ │ Collector   │ │ Collector   │ │ Dispatcher      │ │  │
│  │  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └────────┬────────┘ │  │
│  │         │               │               │                  │          │  │
│  └─────────┼───────────────┼───────────────┼──────────────────┼──────────┘  │
│            └───────────────┴───────────────┴──────────────────┘             │
│                                    │                                        │
│                           ┌────────▼────────┐                               │
│                           │  Blocking Queue │                               │
│                           │  (Events.Cache) │                               │
│                           └────────┬────────┘                               │
│                                    │                                        │
│                           ┌────────▼────────┐                               │
│                           │     Broker      │                               │
│                           │  (gRPC Server)  │                               │
│                           └────────┬────────┘                               │
│                                    │                                        │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │ gRPC streams
                    ┌────────────────┼────────────────┐
                    │                │                │
              Subscriber 1     Subscriber 2     Subscriber N
              (Falco Node A)   (Falco Node B)   (Falco Node C)
```

**Source:** [`cmd/collector/run/run.go:114-404`](../../refs/falcosecurity/k8s-metacollector/cmd/collector/run/run.go)

### Core Components

| Component | Purpose | Source |
|-----------|---------|--------|
| **Manager** | Controller-runtime manager handling all collectors | [`run.go:125-164`](../../refs/falcosecurity/k8s-metacollector/cmd/collector/run/run.go) |
| **Collectors** | Watch Kubernetes resources and generate events | [`collectors/`](../../refs/falcosecurity/k8s-metacollector/collectors/) |
| **Queue** | Blocking channel for event buffering | [`broker/queue.go`](../../refs/falcosecurity/k8s-metacollector/broker/queue.go) |
| **Broker** | gRPC server that routes events to subscribers | [`broker/broker.go`](../../refs/falcosecurity/k8s-metacollector/broker/broker.go) |
| **Cache** | Per-collector cache tracking resource state | [`pkg/events/cache.go`](../../refs/falcosecurity/k8s-metacollector/pkg/events/cache.go) |

---

## Collected Resource Types

The k8s-metacollector watches and collects metadata for the following Kubernetes resource types:

| Resource Kind | API Group | Purpose |
|---------------|-----------|---------|
| `Pod` | core/v1 | Primary resource - all other resources relate to pods |
| `Namespace` | core/v1 | Namespace metadata for pods |
| `Service` | core/v1 | Services serving traffic to pods |
| `Deployment` | apps/v1 | Deployment owning pods |
| `ReplicaSet` | apps/v1 | ReplicaSet owning pods |
| `DaemonSet` | apps/v1 | DaemonSet owning pods |
| `ReplicationController` | core/v1 | ReplicationController owning pods |
| `EndpointSlice` | discovery.k8s.io/v1 | Pod-to-Service mapping |
| `Endpoints` | core/v1 | Legacy pod-to-service mapping |

**Source:** [`pkg/resource/kind.go:18-37`](../../refs/falcosecurity/k8s-metacollector/pkg/resource/kind.go)

### Node Filtering Logic

A Falco instance on Node X receives metadata only for:

1. **Pods** running on Node X
2. **Namespaces** containing pods running on Node X
3. **Deployments/ReplicaSets/DaemonSets/ReplicationControllers** associated with pods on Node X
4. **Services** serving pods running on Node X

**Source:** [`README.md:29-34`](../../refs/falcosecurity/k8s-metacollector/README.md)

---

## gRPC Protocol

The gRPC protocol is defined in [`metadata/metadata.proto`](../../refs/falcosecurity/k8s-metacollector/metadata/metadata.proto).

### Service Definition

```protobuf
service Metadata {
  // Returns a stream of events for the resources that match the selector
  rpc Watch(Selector) returns (stream Event) {}
}
```

### Messages

**Selector** - Client subscription request:

```protobuf
message Selector {
  string nodeName = 1;                    // Node name for filtering
  map<string, string> resourceKinds = 2;  // Resource types to watch
}
```

**Event** - Metadata update streamed to clients:

```protobuf
message Event {
  string reason = 1;              // "Create", "Update", or "Delete"
  string uid = 2;                 // Kubernetes resource UID
  string kind = 3;                // Resource kind (e.g., "Pod")
  optional string meta = 4;       // JSON-encoded metadata
  optional string spec = 5;       // JSON-encoded spec fields
  optional string status = 6;     // JSON-encoded status fields
  optional References refs = 7;   // References to related resources
}
```

**References** - Links to related resources:

```protobuf
message References {
  map<string, ListOfStrings> resources = 1;  // [resourceKind, UIDs]
}
```

**Source:** [`metadata/metadata.proto:1-52`](../../refs/falcosecurity/k8s-metacollector/metadata/metadata.proto)

### Event Types

| Type | Description |
|------|-------------|
| `Create` | New resource discovered, relevant to subscriber |
| `Update` | Existing resource fields changed |
| `Delete` | Resource no longer relevant (deleted or subscriber unsubscribed) |

**Source:** [`pkg/events/event.go:25-32`](../../refs/falcosecurity/k8s-metacollector/pkg/events/event.go)

---

## Collectors

Collectors are controller-runtime reconcilers that watch Kubernetes resources and generate events.

### Pod Collector

The Pod Collector is the primary collector - all other collectors exist to provide context for pods.

**Key Functions:**

1. **ownerRefsHandler**: Extracts owner references (Deployment → ReplicaSet → Pod chain)
2. **serviceRefsHandler**: Finds services selecting this pod via label selectors
3. **namespaceRefsHandler**: Fetches namespace UID
4. **objFieldsHandler**: Marshals pod metadata/status to JSON

**Source:** [`collectors/pod.go:46-467`](../../refs/falcosecurity/k8s-metacollector/collectors/pod.go)

### Reconciliation Flow

```
Pod Event from API Server
            │
            ▼
    ┌───────────────────┐
    │ Get Pod from Cache │
    └─────────┬─────────┘
              │
              ▼
    ┌───────────────────┐
    │ Find Subscribers  │◄─── Based on pod.Spec.NodeName
    │  for this Node    │
    └─────────┬─────────┘
              │
              ▼
    ┌───────────────────┐
    │ Gather References │
    │ - Namespace       │
    │ - Owner (Dpl/RS)  │
    │ - Services        │
    └─────────┬─────────┘
              │
              ▼
    ┌───────────────────┐
    │ Hash & Compare    │◄─── Detect changes
    └─────────┬─────────┘
              │
              ▼
    ┌───────────────────┐
    │ Generate Events   │◄─── Create/Update/Delete per subscriber
    └─────────┬─────────┘
              │
              ▼
    ┌───────────────────┐
    │  Push to Queue    │
    └───────────────────┘
```

**Source:** [`collectors/pod.go:97-236`](../../refs/falcosecurity/k8s-metacollector/collectors/pod.go)

### Object Meta Collector

Used for Deployment, ReplicaSet, DaemonSet, ReplicationController, and Namespace resources. These collectors respond to external triggers (from Pod Collector) rather than watching for changes directly.

**Source:** [`collectors/partialObjectMetadata.go`](../../refs/falcosecurity/k8s-metacollector/collectors/partialObjectMetadata.go)

---

## Broker

The Broker receives events from collectors and dispatches them to gRPC subscribers.

### Connection Management

When a subscriber connects:

1. Generate unique UID for the connection
2. Store connection in sync.Map
3. Notify all relevant collectors about new subscriber
4. Stream events until context canceled or error

**Source:** [`metadata/server.go:63-119`](../../refs/falcosecurity/k8s-metacollector/metadata/server.go)

### Event Dispatch Loop

```go
for {
    evt := br.queue.Pop(ctx)  // Blocking pop
    if evt == nil {
        break
    }

    for sub := range evt.Subscribers() {
        c, ok := br.subscribers.Load(sub)
        if !ok {
            continue
        }
        con.Stream.Send(evt.GRPCMessage())
    }
}
```

**Source:** [`broker/broker.go:106-131`](../../refs/falcosecurity/k8s-metacollector/broker/broker.go)

### TLS Support

The broker supports TLS for secure gRPC connections:

```bash
--broker-server-cert <path>  # Certificate file
--broker-server-key <path>   # Key file
```

**Source:** [`broker/broker.go:57-68`](../../refs/falcosecurity/k8s-metacollector/broker/broker.go)

---

## Deployment

### Required RBAC Permissions

```yaml
rules:
  - apiGroups: ["apps"]
    resources: [daemonsets, deployments, replicasets]
    verbs: [get, list, watch]
  - apiGroups: [""]
    resources: [endpoints, namespaces, pods, replicationcontrollers, services]
    verbs: [get, list, watch]
  - apiGroups: ["discovery.k8s.io"]
    resources: [endpointslices]
    verbs: [get, list, watch]
```

**Source:** [`manifests/meta-collector.yaml:91-130`](../../refs/falcosecurity/k8s-metacollector/manifests/meta-collector.yaml)

### Kubernetes Manifests

Direct deployment using manifests:

```bash
kubectl apply -f manifests/meta-collector.yaml
```

**Source:** [`manifests/meta-collector.yaml`](../../refs/falcosecurity/k8s-metacollector/manifests/meta-collector.yaml)

### Helm Chart

Install via Helm:

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install k8s-metacollector falcosecurity/k8s-metacollector \
    --namespace metacollector \
    --create-namespace
```

**Source:** [`README.md:74-88`](../../refs/falcosecurity/k8s-metacollector/README.md)

### Resource Requirements

Default resource limits from manifest:

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 10m | 500m |
| Memory | 64Mi | 256Mi |

**Source:** [`manifests/meta-collector.yaml:68-76`](../../refs/falcosecurity/k8s-metacollector/manifests/meta-collector.yaml)

### Container Image

```
docker.io/falcosecurity/k8s-metacollector:latest
```

**Source:** [`manifests/meta-collector.yaml:49`](../../refs/falcosecurity/k8s-metacollector/manifests/meta-collector.yaml)

---

## CLI Reference

```bash
/meta-collector run [flags]
```

### Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--metrics-bind-address` | `:8080` | Prometheus metrics endpoint |
| `--health-probe-bind-address` | `:8081` | Health/readiness probes endpoint |
| `--broker-bind-address` | `:45000` | gRPC broker endpoint |
| `--broker-server-cert` | (none) | TLS certificate file path |
| `--broker-server-key` | (none) | TLS key file path |

**Source:** [`cmd/collector/run/run.go:65-71`](../../refs/falcosecurity/k8s-metacollector/cmd/collector/run/run.go)

### Health Endpoints

| Endpoint | Port | Purpose |
|----------|------|---------|
| `/healthz` | 8081 | Liveness probe |
| `/readyz` | 8081 | Readiness probe |

**Source:** [`cmd/collector/run/run.go:389-396`](../../refs/falcosecurity/k8s-metacollector/cmd/collector/run/run.go)

---

## Prometheus Metrics

All metrics use the namespace `meta_collector`.

### Server Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `meta_collector_server_subscribers` | Gauge | Current number of connected subscribers |

**Source:** [`metadata/metrics.go:29-36`](../../refs/falcosecurity/k8s-metacollector/metadata/metrics.go)

### Broker Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `meta_collector_broker_queue_duration_seconds` | Histogram | `name` | Event queue latency |
| `meta_collector_broker_queue_adds` | Counter | `name`, `type` | Events added to queue |
| `meta_collector_broker_dispatched_events` | Counter | `kind`, `type` | Events sent to subscribers |

**Source:** [`broker/metrics.go:28-64`](../../refs/falcosecurity/k8s-metacollector/broker/metrics.go)

### Collector Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `meta_collector_collector_event_api_server_received` | Counter | `name`, `source`, `type` | Events received from API server |

**Source:** [`collectors/metrics.go:39-52`](../../refs/falcosecurity/k8s-metacollector/collectors/metrics.go)

### Grafana Dashboard

A pre-built Grafana dashboard is available at [`grafana/meta-collector-metrics.json`](../../refs/falcosecurity/k8s-metacollector/grafana/meta-collector-metrics.json).

**Source:** [`README.md:103`](../../refs/falcosecurity/k8s-metacollector/README.md)

---

## Integration with Falco

The k8s-metacollector is designed to work with the **k8smeta plugin** to provide Kubernetes metadata enrichment for Falco. The k8smeta plugin connects to the k8s-metacollector service via gRPC and provides `k8smeta.*` fields for rule conditions and alert outputs.

### k8smeta Plugin Integration

The [k8smeta plugin](plugins/k8smeta.md) is the gRPC client that connects to k8s-metacollector:

| Component | Role | Description |
|-----------|------|-------------|
| **k8s-metacollector** | Server | Centralized service watching Kubernetes API server |
| **k8smeta plugin** | Client | Plugin in each Falco instance receiving metadata |

The plugin configuration specifies the collector hostname and port:

```yaml
plugins:
  - name: k8smeta
    library_path: libk8smeta.so
    init_config:
      collectorHostname: k8s-metacollector.metacollector.svc
      collectorPort: 45000
      nodeName: "${FALCO_K8S_NODE_NAME}"
```

**Source:** [`README.md:12-16`](../../refs/falcosecurity/k8s-metacollector/README.md), [`plugins/k8smeta/README.md`](../../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

### Relationship to Container Plugin

| Plugin | Field Prefix | Responsibility | Data Source |
|--------|--------------|----------------|-------------|
| **k8smeta** | `k8smeta.*` | Kubernetes resource metadata | k8s-metacollector (gRPC) |
| **container** | `container.*` | Container runtime metadata | Container runtime sockets |

The plugins are complementary:
- **k8smeta plugin**: Pod name/uid/labels, namespace, deployment, services, replicasets
- **container plugin**: Container ID, image, name, mount points, network

### Supported k8smeta Fields

Fields provided by k8smeta plugin via k8s-metacollector:

| Resource | Fields |
|----------|--------|
| Pod | `k8smeta.pod.name`, `k8smeta.pod.uid`, `k8smeta.pod.label[key]`, `k8smeta.pod.labels`, `k8smeta.pod.ip` |
| Namespace | `k8smeta.ns.name`, `k8smeta.ns.uid`, `k8smeta.ns.label[key]`, `k8smeta.ns.labels` |
| Deployment | `k8smeta.deployment.name`, `k8smeta.deployment.uid`, `k8smeta.deployment.label[key]`, `k8smeta.deployment.labels` |
| Service | `k8smeta.svc.name`, `k8smeta.svc.uid`, `k8smeta.svc.label[key]`, `k8smeta.svc.labels` |
| ReplicaSet | `k8smeta.rs.name`, `k8smeta.rs.uid`, `k8smeta.rs.label[key]`, `k8smeta.rs.labels` |
| ReplicationController | `k8smeta.rc.name`, `k8smeta.rc.uid`, `k8smeta.rc.label[key]`, `k8smeta.rc.labels` |

**Source:** [`plugins/k8smeta/README.md:24-54`](../../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

---

## Functional Guarantees

The k8s-metacollector provides the following guarantees:

1. **Complete Initial State**: At subscribe time, clients receive all metadata for resources related to their node
2. **Create Events**: Sent when a new resource is discovered
3. **Update Events**: Sent when resource fields change
4. **Delete Events**: Sent when a resource is no longer relevant
5. **Node Filtering**: Only node-relevant metadata is sent to each subscriber

**Source:** [`README.md:42-52`](../../refs/falcosecurity/k8s-metacollector/README.md)

---

## Maintainers

| GitHub Handle | Role |
|---------------|------|
| @alacuku | Approver |
| @leogr | Approver |
| @andreagit97 | Approver |
| @Issif | Approver |

**Source:** [`OWNERS`](../../refs/falcosecurity/k8s-metacollector/OWNERS)

---

## Sources

| Topic | Source File |
|-------|-------------|
| README & Overview | [`README.md`](../../refs/falcosecurity/k8s-metacollector/README.md) |
| gRPC Protocol | [`metadata/metadata.proto`](../../refs/falcosecurity/k8s-metacollector/metadata/metadata.proto) |
| Main Run Logic | [`cmd/collector/run/run.go`](../../refs/falcosecurity/k8s-metacollector/cmd/collector/run/run.go) |
| Broker Implementation | [`broker/broker.go`](../../refs/falcosecurity/k8s-metacollector/broker/broker.go) |
| Pod Collector | [`collectors/pod.go`](../../refs/falcosecurity/k8s-metacollector/collectors/pod.go) |
| gRPC Server | [`metadata/server.go`](../../refs/falcosecurity/k8s-metacollector/metadata/server.go) |
| Event Types | [`pkg/events/event.go`](../../refs/falcosecurity/k8s-metacollector/pkg/events/event.go) |
| Resource Kinds | [`pkg/resource/kind.go`](../../refs/falcosecurity/k8s-metacollector/pkg/resource/kind.go) |
| Deployment Manifest | [`manifests/meta-collector.yaml`](../../refs/falcosecurity/k8s-metacollector/manifests/meta-collector.yaml) |
| Metrics - Broker | [`broker/metrics.go`](../../refs/falcosecurity/k8s-metacollector/broker/metrics.go) |
| Metrics - Collector | [`collectors/metrics.go`](../../refs/falcosecurity/k8s-metacollector/collectors/metrics.go) |
| Metrics - Server | [`metadata/metrics.go`](../../refs/falcosecurity/k8s-metacollector/metadata/metrics.go) |
| Go Dependencies | [`go.mod`](../../refs/falcosecurity/k8s-metacollector/go.mod) |
| k8smeta Plugin (client) | [`plugins/k8smeta.md`](plugins/k8smeta.md) |
