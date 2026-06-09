# falcosecurity/deploy-kubernetes Digest

**Repository:** https://github.com/falcosecurity/deploy-kubernetes
**Era:** 0.44
**Status:** Core / Stable

Pre-rendered Kubernetes manifests auto-generated from the [Helm charts](charts.md). These serve as deployment templates and provide insight into how Falco components are structured in Kubernetes.

## Overview

This repository provides ready-to-use Kubernetes manifests that can be deployed directly with `kubectl` or `kustomize`, without requiring Helm. The manifests are generated from the [falcosecurity/charts](../../refs/falcosecurity/charts/) repository and reflect the default chart configurations.

**Important:** These are **templates** meant as starting points. For production deployments, either:
- Customize these manifests for your environment
- Use the Helm charts directly for more flexibility

**Deployment method:** [Kustomize](https://kustomize.io/)
```bash
kubectl apply -k kubernetes/falco
```

## Repository Structure

| Directory | Contents | Controller Type |
|-----------|----------|-----------------|
| [`kubernetes/falco/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/) | Falco syscall monitoring | DaemonSet |
| [`kubernetes/falcosidekick/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/) | Alert forwarding | Deployment (2 replicas) |
| [`kubernetes/falco-exporter/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/) | Prometheus metrics exporter | DaemonSet |
| [`kubernetes/event-generator/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/) | Test event generation | Deployment |
| [`archive/`](../../refs/falcosecurity/deploy-kubernetes/archive/) | Deprecated K8s audit configurations | - |

## Falco Deployment Analysis

**Source:** [`kubernetes/falco/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/)

The Falco manifests demonstrate how Falco operates as a DaemonSet with multiple containers and init containers working together.

### Kubernetes Resources

| Resource | File | Purpose |
|----------|------|---------|
| DaemonSet | [`daemonset.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml) | Main Falco deployment |
| ConfigMap | [`configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml) | `falco.yaml` configuration |
| ConfigMap | [`falcoctl-configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml) | `falcoctl.yaml` for artifact management |
| ServiceAccount | [`serviceaccount.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/serviceaccount.yaml) | Pod identity |
| ClusterRole | [`clusterrole.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/clusterrole.yaml) | Cluster-wide permissions |
| ClusterRoleBinding | [`clusterrolebinding.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/clusterrolebinding.yaml) | Binds ClusterRole |
| Role | [`role.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/role.yaml) | Namespace-scoped permissions |
| RoleBinding | [`roleBinding.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/roleBinding.yaml) | Binds Role |

### Pod Structure

The Falco pod consists of **2 init containers** and **2 runtime containers**:

```
┌─────────────────────────────────────────────────────────────────┐
│                         Falco Pod                                │
├─────────────────────────────────────────────────────────────────┤
│  Init Containers (run sequentially before main containers):      │
│  ┌───────────────────────┐  ┌─────────────────────────────────┐ │
│  │ falco-driver-loader   │  │ falcoctl-artifact-install       │ │
│  │ - Downloads/builds    │  │ - Downloads rules + plugins     │ │
│  │   kernel driver       │  │ - Writes to emptyDir volumes    │ │
│  │ - Writes config to    │  │ - Uses falcoctl index           │ │
│  │   specialized-falco-  │  │                                 │ │
│  │   configs emptyDir    │  │                                 │ │
│  └───────────────────────┘  └─────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Runtime Containers (run in parallel):                           │
│  ┌───────────────────────┐  ┌─────────────────────────────────┐ │
│  │ falco                 │  │ falcoctl-artifact-follow        │ │
│  │ - Main Falco process  │  │ - Watches for rule updates      │ │
│  │ - Loads driver        │  │ - Downloads new versions        │ │
│  │ - Processes events    │  │ - Runs every 168h (1 week)      │ │
│  │ - Webserver :8765     │  │                                 │ │
│  └───────────────────────┘  └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Init Containers

#### 1. `falco-driver-loader`

**Image:** `falcosecurity/falco-driver-loader:0.44.0`
**Purpose:** Download or build the kernel driver before Falco starts

```yaml
args:
  - auto  # Automatically selects best driver (modern_ebpf preferred)
securityContext:
  privileged: true  # Required for driver loading
```

**Volume mounts:**
- `/host/boot` - Access kernel files
- `/host/lib/modules` - Kernel modules
- `/host/usr` - System binaries
- `/host/etc` - System configuration
- `/host/proc` - Process information
- `/etc/falco/config.d` - Writes driver configuration

> **Note:** With `modern_ebpf`, the driver loader generates config but doesn't download a driver (it's embedded in Falco binary).

#### 2. `falcoctl-artifact-install`

**Image:** `falcosecurity/falcoctl:0.13.0`
**Purpose:** Download rules and plugins before Falco starts

```yaml
args:
  - artifact
  - install
  - --log-format=json
```

**Default artifacts installed:**
- `falco-rules:5` - Stable Falco rules
- `ghcr.io/falcosecurity/plugins/plugin/container:0.7.1` - Container metadata plugin

### Runtime Containers

#### 1. `falco`

**Image:** `falcosecurity/falco:0.44.0`
**Purpose:** Main Falco process for threat detection

```yaml
securityContext:
  privileged: true  # Required for syscall capture
resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1024Mi
ports:
  - containerPort: 8765  # Webserver (healthz, metrics, versions)
```

**Key environment variables:**
- `HOST_ROOT=/host` - Host filesystem mount point
- `FALCO_HOSTNAME` - Node name (from `spec.nodeName`)
- `FALCO_K8S_NODE_NAME` - Node name for Kubernetes context

**Health probes:** All use `/healthz` endpoint on port 8765

#### 2. `falcoctl-artifact-follow`

**Image:** `falcosecurity/falcoctl:0.13.0`
**Purpose:** Watch for and download rule updates

```yaml
args:
  - artifact
  - follow
  - --log-format=json
```

Checks for updates every 168 hours (1 week) by default.

### Volume Architecture

The DaemonSet uses a combination of **hostPath** volumes (for system access) and **emptyDir** volumes (for inter-container communication):

#### Host Path Volumes (System Access)

| Volume | Host Path | Purpose |
|--------|-----------|---------|
| `proc-fs` | `/proc` | Process information |
| `dev-fs` | `/dev` | Device access |
| `etc-fs` | `/etc` | System configuration |
| `boot-fs` | `/boot` | Kernel files (driver loader) |
| `lib-modules` | `/lib/modules` | Kernel modules |
| `usr-fs` | `/usr` | System binaries |
| `sys-module-fs` | `/sys/module` | Kernel module info |
| `sys-fs` | `/sys/kernel` | Kernel tracing (tracefs/debugfs) |

#### Container Socket Volumes

| Volume | Host Path | Container Runtime |
|--------|-----------|-------------------|
| `container-engine-socket-0` | `/var/run/docker.sock` | Docker |
| `container-engine-socket-1` | `/run/podman/podman.sock` | Podman |
| `container-engine-socket-2` | `/run/host-containerd/containerd.sock` | Containerd (host) |
| `container-engine-socket-3` | `/run/containerd/containerd.sock` | Containerd |
| `container-engine-socket-4` | `/run/crio/crio.sock` | CRI-O |
| `container-engine-socket-5` | `/run/k3s/containerd/containerd.sock` | K3s |

#### EmptyDir Volumes (Inter-Container Communication)

| Volume | Purpose | Shared Between |
|--------|---------|----------------|
| `rulesfiles-install-dir` | Downloaded rules | falcoctl → falco |
| `plugins-install-dir` | Downloaded plugins | falcoctl → falco |
| `specialized-falco-configs` | Driver config | driver-loader → falco |
| `root-falco-fs` | Falco working directory | driver-loader → falco |
| `artifact-state-dir` | falcoctl state | install ↔ follow |

### Falco Configuration (`falco.yaml`)

**Source:** [`configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml)

Key configuration in the default deployment:

```yaml
engine:
  kind: modern_ebpf  # Default driver
  modern_ebpf:
    buf_size_preset: 4
    cpus_for_each_buffer: 2

load_plugins:
  - container  # Container metadata enrichment

plugins:
  - name: container
    library_path: libcontainer.so
    init_config:
      engines:
        docker: { enabled: true, sockets: ["/var/run/docker.sock"] }
        containerd: { enabled: true, sockets: ["/run/host-containerd/containerd.sock"] }
        cri: { enabled: true, sockets: [...] }
        podman: { enabled: true, sockets: ["/run/podman/podman.sock"] }

rules_files:
  - /etc/falco/falco_rules.yaml
  - /etc/falco/falco_rules.local.yaml
  - /etc/falco/rules.d

webserver:
  enabled: true
  listen_port: 8765
  k8s_healthz_endpoint: /healthz
```

### RBAC Permissions

**ClusterRole permissions** (cluster-wide read access):
- `nodes`, `namespaces`, `pods`, `services`, `events`, `configmaps`
- `daemonsets`, `deployments`, `replicasets`, `statefulsets`
- `/healthz` endpoints

These permissions allow Falco and the container plugin to enrich events with Kubernetes metadata.

## Falcosidekick Deployment

**Source:** [`kubernetes/falcosidekick/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/)

Deployment (not DaemonSet) with 2 replicas for high availability:

```yaml
spec:
  replicas: 2
  containers:
    - name: falcosidekick
      image: falcosecurity/falcosidekick:2.32.0
      ports:
        - containerPort: 2801  # HTTP endpoint
      securityContext:
        runAsUser: 1234
        fsGroup: 1234
```

**To connect Falco to Falcosidekick**, configure `http_output` in Falco:
```yaml
http_output:
  enabled: true
  url: "http://falcosidekick:2801"
```

## Falco-Exporter Deployment

**Source:** [`kubernetes/falco-exporter/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/)

DaemonSet that connects to Falco's gRPC socket and exposes Prometheus metrics:

```yaml
containers:
  - name: falco-exporter
    image: falcosecurity/falco-exporter:0.8.3
    args:
      - --client-socket=unix:///run/falco/falco.sock
      - --listen-address=0.0.0.0:9376
    ports:
      - containerPort: 9376  # Prometheus metrics
    securityContext:
      privileged: false
      readOnlyRootFilesystem: true
```

> **Note:** Requires `grpc.enabled: true` in Falco configuration. The gRPC output was removed in Falco 0.44 (deprecated in 0.43); use the built-in Prometheus metrics endpoint instead.

## Deployment Commands

```bash
# Deploy Falco
kubectl apply -k kubernetes/falco

# Deploy Falcosidekick (optional)
kubectl apply -k kubernetes/falcosidekick

# Deploy Falco-Exporter (optional, deprecated approach)
kubectl apply -k kubernetes/falco-exporter

# Deploy Event Generator (for testing)
kubectl apply -k kubernetes/event-generator

# Tear down
kubectl delete -k kubernetes/falco
```

## Verification

```bash
# Check pods
kubectl get pods -l app.kubernetes.io/name=falco

# View logs
kubectl logs -l app.kubernetes.io/name=falco -c falco

# Test - spawn a shell (should trigger "Terminal shell in container" rule)
kubectl exec -it <falco-pod> -c falco -- bash
```

## Archive (Deprecated)

The [`archive/`](../../refs/falcosecurity/deploy-kubernetes/archive/) directory contains deprecated configurations:

- `falco-k8s-audit-sink/` - K8s AuditSink resource (deprecated API)
- `kind/` - Kind cluster audit configuration
- `kubeadm/` - Kubeadm audit configuration

For K8s audit logs, use the [k8saudit plugin](https://github.com/falcosecurity/plugins/tree/main/plugins/k8saudit) instead.

## Relationship to Helm Charts

These manifests are generated from [falcosecurity/charts](charts.md) with default values:

| Manifest | Helm Chart | Chart Version |
|----------|------------|---------------|
| `kubernetes/falco/` | `falco` | 9.0.0 |
| `kubernetes/falcosidekick/` | `falcosidekick` | 0.12.1 |
| `kubernetes/falco-exporter/` | `falco-exporter` | 0.12.2 |
| `kubernetes/event-generator/` | `event-generator` | (various) |

For customization beyond these defaults, use the Helm charts directly.

## Sources

| Topic | Source File |
|-------|-------------|
| Falco manifests | [`kubernetes/falco/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/) |
| Falco DaemonSet | [`kubernetes/falco/templates/daemonset.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml) |
| Falco ConfigMap | [`kubernetes/falco/templates/configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml) |
| Falcoctl ConfigMap | [`kubernetes/falco/templates/falcoctl-configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml) |
| Falcosidekick manifests | [`kubernetes/falcosidekick/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/) |
| Falco-exporter manifests | [`kubernetes/falco-exporter/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/) |
| Event-generator manifests | [`kubernetes/event-generator/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/) |
| Archive (deprecated) | [`archive/`](../../refs/falcosecurity/deploy-kubernetes/archive/) |
