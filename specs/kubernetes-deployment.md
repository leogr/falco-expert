# Kubernetes Deployment

> Helm-chart-based Kubernetes deployment: DaemonSet vs Deployment topology, pod architecture, driver configuration, artifact management, volume architecture, RBAC, and ecosystem integration.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/charts/`](../refs/falcosecurity/charts/), [`refs/falcosecurity/deploy-kubernetes/`](../refs/falcosecurity/deploy-kubernetes/)

## Overview

Helm charts are the primary method for deploying Falco and its ecosystem components in Kubernetes. The [falcosecurity/charts](../refs/falcosecurity/charts/) repository provides five production-ready charts that cover the core runtime security engine, alert forwarding, automated response, metadata enrichment, and test event generation.

**Helm Repository:** `https://falcosecurity.github.io/charts`

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
```

**OCI Registry:** `https://github.com/orgs/falcosecurity/packages?repo_name=charts`

### Charts

| Chart | Version | AppVersion | Purpose |
|-------|---------|------------|---------|
| [`falco`](../refs/falcosecurity/charts/charts/falco/) | 8.0.0 | 0.43.0 | Core Falco deployment (DaemonSet or Deployment) |
| [`falcosidekick`](../refs/falcosecurity/charts/charts/falcosidekick/) | 0.12.1 | 2.31.1 | Alert forwarding to 60+ outputs |
| [`falco-talon`](../refs/falcosecurity/charts/charts/falco-talon/) | 0.4.0 | 0.3.0 | Automated response actions |
| [`k8s-metacollector`](../refs/falcosecurity/charts/charts/k8s-metacollector/) | 0.2.0 | 0.1.1 | Kubernetes metadata enrichment via gRPC |
| [`event-generator`](../refs/falcosecurity/charts/charts/event-generator/) | 0.3.4 | 0.10.0 | Test event generation for rule validation |

Pre-rendered Kubernetes manifests (generated from these charts with default values) are also available in [falcosecurity/deploy-kubernetes](../refs/falcosecurity/deploy-kubernetes/) for direct `kubectl apply -k` deployment without Helm.

**Source:** [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md), [`digests/falcosecurity/deploy-kubernetes.md`](../digests/falcosecurity/deploy-kubernetes.md)

## Deployment Topology

The Falco chart supports two controller types based on the event source:

- **DaemonSet** -- required when capturing syscall events, because Falco must run on every node to instrument the kernel
- **Deployment** -- sufficient for plugin-only event sources (e.g., K8s audit logs, CloudTrail), where a single or replicated instance processes events received over the network

### Decision Matrix

| Event Source | `driver.enabled` | `controller.kind` | `collectors.enabled` |
|--------------|-------------------|--------------------|----------------------|
| Syscalls only (default) | `true` | `daemonset` | `true` |
| K8s Audit only | `false` | `deployment` | `false` |
| Syscalls + K8s Audit | `true` | `daemonset` | `true` |
| CloudTrail (plugin) | `false` | `deployment` | `false` |
| gVisor (deprecated) | `true` (kind: gvisor) | `daemonset` | `true` |

When `driver.enabled=true`, a DaemonSet is required so that each node has a Falco instance capturing kernel events. When `driver.enabled=false`, a Deployment is appropriate because events arrive via network endpoints (webhooks, APIs) rather than per-node kernel instrumentation.

**Source:** [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) (Deployment Decision Matrix)

## Pod Architecture

Each Falco pod consists of **2 init containers** (run sequentially before the main containers start) and **2 runtime containers** (run in parallel during steady state):

```
┌──────────────────────────────────────────────────────────────────────┐
│                            Falco Pod                                 │
├──────────────────────────────────────────────────────────────────────┤
│  Init Containers (run sequentially):                                 │
│  ┌──────────────────────────┐  ┌──────────────────────────────────┐ │
│  │  falco-driver-loader     │  │  falcoctl-artifact-install       │ │
│  │  image: falco-driver-    │  │  image: falcoctl:0.12.2          │ │
│  │         loader:0.43.0    │  │                                  │ │
│  │                          │  │  - Downloads rules + plugins     │ │
│  │  - Downloads/builds      │  │  - Writes to emptyDir volumes    │ │
│  │    kernel driver          │  │  - Uses falcoctl index           │ │
│  │  - Writes driver config  │  │                                  │ │
│  │    to emptyDir            │  │  Default refs:                   │ │
│  │                          │  │    falco-rules:5                 │ │
│  │  Skipped when driver     │  │    container plugin:0.6.1        │ │
│  │  is not needed           │  │                                  │ │
│  └──────────────────────────┘  └──────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────────┤
│  Runtime Containers (run in parallel):                               │
│  ┌──────────────────────────┐  ┌──────────────────────────────────┐ │
│  │  falco                   │  │  falcoctl-artifact-follow        │ │
│  │  image: falco:0.43.0     │  │  image: falcoctl:0.12.2          │ │
│  │                          │  │                                  │ │
│  │  - Main Falco process    │  │  - Watches for rule/plugin       │ │
│  │  - Loads driver           │  │    updates from OCI registries   │ │
│  │  - Processes events      │  │  - Downloads new versions        │ │
│  │  - Webserver :8765       │  │  - Check interval: 168h (1 week) │ │
│  │  - /healthz endpoint     │  │  - Triggers Falco hot reload     │ │
│  └──────────────────────────┘  └──────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**Key environment variables** set on the `falco` container:
- `HOST_ROOT=/host` -- host filesystem mount point
- `FALCO_HOSTNAME` -- node name (from `spec.nodeName`)
- `FALCO_K8S_NODE_NAME` -- node name for Kubernetes context

**Resource defaults** for the `falco` container:
- Requests: 100m CPU, 512Mi memory
- Limits: 1000m CPU, 1024Mi memory

**Health probes** (startup, liveness, readiness) all use `/healthz` on port 8765.

**Source:** [`daemonset.yaml`](../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)

## Driver Configuration

The `driver.kind` setting controls how Falco captures system events from the kernel. The driver loader init container handles setup for drivers that require download or compilation.

### Driver Kinds

| Driver | `driver.kind` | Description | Status |
|--------|---------------|-------------|--------|
| Auto | `auto` | Automatically selects the best available driver (prefers modern_ebpf) | **Default** |
| Modern eBPF | `modern_ebpf` | CO-RE eBPF probe embedded in the Falco binary; no loader needed | Stable, recommended |
| Kernel Module | `kmod` | Traditional kernel module; requires compilation or pre-built download | Stable |
| Legacy eBPF | `ebpf` | Legacy eBPF probe; requires loader | **Deprecated in 0.43** |
| gVisor | `gvisor` | gVisor sandbox integration (GKE) | **Deprecated in 0.43** |

```bash
# Explicit Modern eBPF
helm install falco falcosecurity/falco --set driver.kind=modern_ebpf

# Kernel module
helm install falco falcosecurity/falco --set driver.kind=kmod
```

> **Note:** With `modern_ebpf`, the driver loader init container still runs but only generates configuration -- it does not download a separate driver binary, since the probe is embedded in the Falco binary itself.

### Security Contexts per Driver Type

| Driver | Security Context |
|--------|------------------|
| No driver (`driver.enabled=false`) | `{}` (no special privileges) |
| `kmod` | `privileged: true` |
| `modern_ebpf` | `privileged: true` |
| `ebpf` (deprecated) | `privileged: true` (or least-privilege with capabilities) |
| `ebpf` + `leastPrivileged` | `capabilities: [BPF, SYS_RESOURCE, PERFMON, SYS_PTRACE]` |

For modern_ebpf, a least-privilege mode is also available:

```yaml
driver:
  kind: modern_ebpf
  modernEbpf:
    leastPrivileged: true  # Capabilities instead of privileged
```

**Source:** [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) (Security Contexts), [`values.yaml`](../refs/falcosecurity/charts/charts/falco/values.yaml)

## Artifact Management

Falcoctl handles the installation and continuous updating of Falco rules and plugins via OCI-compliant registries.

### Init Container: `falcoctl-artifact-install`

Runs before Falco starts to download required artifacts:

```yaml
args:
  - artifact
  - install
  - --log-format=json
```

**Default artifacts installed:**
- `falco-rules:5` -- stable Falco detection rules
- `ghcr.io/falcosecurity/plugins/plugin/container:0.6.1` -- container metadata plugin

### Sidecar: `falcoctl-artifact-follow`

Runs alongside Falco to watch for updates:

```yaml
args:
  - artifact
  - follow
  - --log-format=json
```

Checks for updates every **168 hours (1 week)** by default. When an update is found, it downloads the new artifact and triggers a Falco hot reload via the `/versions` endpoint compatibility check.

### Install and Follow Refs Pattern

The `install.refs` and `follow.refs` configuration lists control which artifacts are managed:

```yaml
falcoctl:
  config:
    artifact:
      install:
        refs: [falco-rules:5]           # Install at startup
        resolveDeps: true                # Resolve transitive dependencies
        rulesfilesDir: /rulesfiles       # Target directory for rules
        pluginsDir: /plugins             # Target directory for plugins
        stateDir: /artifactstate         # State tracking directory
      follow:
        refs: [falco-rules:5]           # Watch for updates
        every: 168h                      # Check interval
        falcoversions: http://localhost:8765/versions  # Version compat check
        rulesfilesDir: /rulesfiles
        pluginsDir: /plugins
        stateDir: /artifactstate
```

**Customization examples:**

```bash
# Include incubating rules
helm install falco falcosecurity/falco \
  --set "falcoctl.config.artifact.install.refs={falco-rules:5,falco-incubating-rules:5}" \
  --set "falcoctl.config.artifact.follow.refs={falco-rules:5,falco-incubating-rules:5}"

# K8s audit plugin artifacts
helm install falco falcosecurity/falco -f values-k8saudit.yaml
# Sets refs to [k8saudit-rules:0.16, k8saudit:0.16]
```

**Source:** [`digests/falcosecurity/deploy-kubernetes.md`](../digests/falcosecurity/deploy-kubernetes.md) (Init Containers), [`falcoctl-configmap.yaml`](../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml)

## Volume Architecture

The Falco pod mounts three categories of volumes to access host resources, container runtime sockets, and share data between containers.

### Host Path Volumes (8 volumes)

These provide read access to the host filesystem for driver loading, kernel instrumentation, and process inspection:

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

### Container Runtime Socket Volumes (6 volumes)

These allow the container plugin to query container runtime APIs for metadata enrichment:

| Volume | Host Path | Container Runtime |
|--------|-----------|-------------------|
| `container-engine-socket-0` | `/var/run/docker.sock` | Docker |
| `container-engine-socket-1` | `/run/podman/podman.sock` | Podman |
| `container-engine-socket-2` | `/run/host-containerd/containerd.sock` | Containerd (host) |
| `container-engine-socket-3` | `/run/containerd/containerd.sock` | Containerd |
| `container-engine-socket-4` | `/run/crio/crio.sock` | CRI-O |
| `container-engine-socket-5` | `/run/k3s/containerd/containerd.sock` | K3s |

### EmptyDir Volumes (5 volumes)

These enable inter-container communication within the pod:

| Volume | Purpose | Shared Between |
|--------|---------|----------------|
| `rulesfiles-install-dir` | Downloaded rules files | falcoctl-install -> falco, falcoctl-follow |
| `plugins-install-dir` | Downloaded plugins | falcoctl-install -> falco, falcoctl-follow |
| `specialized-falco-configs` | Driver configuration (config.d) | driver-loader -> falco |
| `root-falco-fs` | Falco working directory | driver-loader -> falco |
| `artifact-state-dir` | falcoctl state (artifact digests) | falcoctl-install <-> falcoctl-follow |

The `artifact-state-dir` volume persists artifact digests between the init container and the sidecar, preventing redundant re-downloads of already-installed artifacts across container restarts.

**Source:** [`daemonset.yaml`](../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml), [`digests/falcosecurity/deploy-kubernetes.md`](../digests/falcosecurity/deploy-kubernetes.md) (Volume Architecture)

## Configuration

Falco's Kubernetes configuration is managed through two ConfigMaps and an optional custom rules mechanism.

### ConfigMaps

| ConfigMap | Template | Contents |
|-----------|----------|----------|
| Falco config | [`configmap.yaml`](../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml) | `falco.yaml` -- full Falco configuration |
| Falcoctl config | [`falcoctl-configmap.yaml`](../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml) | `falcoctl.yaml` -- artifact management settings |

The Falco ConfigMap is generated from Helm values and contains all runtime configuration including engine kind, plugin definitions, rule file paths, output channels, and webserver settings.

### Custom Rules via `customRules`

Organizations can inject custom detection rules directly via Helm values, which are rendered into an additional ConfigMap:

```yaml
customRules:
  my-rules.yaml: |-
    - rule: My Custom Rule
      desc: Detect specific behavior
      condition: spawned_process and proc.name = "suspicious"
      output: "Custom alert (user=%user.name command=%proc.cmdline)"
      priority: WARNING
```

Custom rules files are mounted into `/etc/falco/rules.d/` and loaded after the standard rules.

### Key Values Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `driver.kind` | `auto` | Driver selection (auto, modern_ebpf, kmod, ebpf, gvisor) |
| `driver.enabled` | `true` | Enable/disable kernel driver |
| `controller.kind` | `daemonset` | DaemonSet or Deployment |
| `controller.deployment.replicas` | `1` | Replica count (Deployment mode only) |
| `collectors.enabled` | `true` | Container metadata collection |
| `collectors.kubernetes.enabled` | `false` | Full Kubernetes metadata (deploys k8s-metacollector) |
| `falcoctl.artifact.install.enabled` | `true` | Install artifacts at startup |
| `falcoctl.artifact.follow.enabled` | `true` | Auto-update artifacts via sidecar |
| `falcoctl.config.artifact.install.refs` | `[falco-rules:5]` | Artifacts to install |
| `falcoctl.config.artifact.follow.refs` | `[falco-rules:5]` | Artifacts to watch |
| `falcoctl.config.artifact.follow.every` | `168h` | Update check interval |
| `metrics.enabled` | `false` | Prometheus metrics endpoint |
| `metrics.service.port` | `8765` | Metrics service port |
| `serviceMonitor.create` | `false` | Create Prometheus ServiceMonitor |
| `grafana.dashboards.enabled` | `false` | Provision Grafana dashboards |
| `falcosidekick.enabled` | `false` | Deploy falcosidekick sub-chart |
| `responseActions.enabled` | `false` | Deploy falco-talon sub-chart |

**Source:** [`values.yaml`](../refs/falcosecurity/charts/charts/falco/values.yaml)

## RBAC Model

The Falco chart creates a namespace-scoped RBAC model. In the current era (chart 8.0.0), there are no ClusterRole or ClusterRoleBinding resources -- only a namespace-scoped Role is created.

### Resources Created

| Resource | File | Purpose |
|----------|------|---------|
| ServiceAccount | [`serviceaccount.yaml`](../refs/falcosecurity/charts/charts/falco/templates/serviceaccount.yaml) | Pod identity for Falco |
| Role | [`role.yaml`](../refs/falcosecurity/charts/charts/falco/templates/role.yaml) | Namespace-scoped permissions (only when `driver.kind=auto`) |
| RoleBinding | [`roleBinding.yaml`](../refs/falcosecurity/charts/charts/falco/templates/roleBinding.yaml) | Binds Role to ServiceAccount (only when `driver.kind=auto`) |

### Role Permissions

The Role is only created when `driver.kind` is set to `auto` (the default). It grants permissions on `configmaps` in the release namespace:

- **API Group:** `""`
- **Resources:** `configmaps`
- **Verbs:** `get`, `list`, `update`

This allows the driver-loader init container (when using the `auto` driver selection mode) to persist driver configuration into a ConfigMap within the Falco namespace.

> **Note:** The pre-rendered manifests in [`deploy-kubernetes`](../refs/falcosecurity/deploy-kubernetes/) still contain a stale ClusterRole and ClusterRoleBinding from chart 3.8.7 (Falco 0.36.2 era) alongside the current-era Role. These cluster-wide resources are no longer generated by the Helm chart templates in the current era.

**Source:** [`role.yaml`](../refs/falcosecurity/charts/charts/falco/templates/role.yaml), [`roleBinding.yaml`](../refs/falcosecurity/charts/charts/falco/templates/roleBinding.yaml)

## Deployment Scenarios

### Scenario 1: Syscall Monitoring Only (Default)

Runtime threat detection via system call monitoring. This is the default configuration.

```bash
helm install falco falcosecurity/falco --namespace falco --create-namespace
```

```yaml
driver:
  enabled: true
  kind: auto           # Prefers Modern eBPF
controller:
  kind: daemonset
collectors:
  enabled: true        # Container metadata enrichment
```

- DaemonSet ensures Falco runs on every node
- Driver captures syscall events from the kernel
- Container plugin enriches events with container metadata
- falcoctl installs `falco-rules` (stable rules)

### Scenario 2: Kubernetes Audit Only (Plugin Deployment)

Kubernetes API audit log monitoring without syscall capture.

**Source:** [`values-k8saudit.yaml`](../refs/falcosecurity/charts/charts/falco/values-k8saudit.yaml)

```bash
helm install falco falcosecurity/falco -f values-k8saudit.yaml --namespace falco
```

```yaml
driver:
  enabled: false          # No syscall capture
collectors:
  enabled: false          # No container metadata needed
controller:
  kind: deployment        # Single instance sufficient
  deployment:
    replicas: 1
services:
  - name: k8saudit-webhook
    type: NodePort
    ports:
      - port: 9765
        nodePort: 30007
        protocol: TCP
falcoctl:
  config:
    artifact:
      install:
        refs: [k8saudit-rules:0.16, k8saudit:0.16]
      follow:
        refs: [k8saudit-rules:0.16]
falco:
  rules_files:
    - /etc/falco/k8s_audit_rules.yaml
    - /etc/falco/rules.d
  load_plugins: [k8saudit, json]
  plugins:
    - name: k8saudit
      library_path: libk8saudit.so
      open_params: "http://:9765/k8s-audit"
    - name: json
      library_path: libjson.so
```

- Deployment creates a single Falco instance (or replicated for HA)
- k8saudit plugin exposes webhook endpoint on port 9765
- K8s API server sends audit logs to the webhook
- No drivers loaded, no container metadata collection

### Scenario 3: Combined (Syscalls + K8s Audit Logs)

Full coverage with both syscall monitoring and K8s audit logs.

**Source:** [`values-syscall-k8saudit.yaml`](../refs/falcosecurity/charts/charts/falco/values-syscall-k8saudit.yaml)

```bash
helm install falco falcosecurity/falco -f values-syscall-k8saudit.yaml --namespace falco
```

```yaml
driver:
  enabled: true
  kind: module
controller:
  kind: daemonset        # Required for syscall capture
collectors:
  enabled: true
services:
  - name: k8saudit-webhook
    type: NodePort
    ports:
      - port: 9765
        nodePort: 30007
        protocol: TCP
falcoctl:
  config:
    artifact:
      install:
        refs: [falco-rules:5, k8saudit-rules:0.16, k8saudit:0.16]
      follow:
        refs: [falco-rules:5, k8saudit-rules:0.16, k8saudit:0.16]
falco:
  rules_files:
    - /etc/falco/falco_rules.yaml
    - /etc/falco/k8s_audit_rules.yaml
    - /etc/falco/rules.d
  load_plugins: [k8saudit, json]
```

- DaemonSet runs Falco on every node for syscall monitoring
- k8saudit plugin loaded on each instance; webhook service routes to Falco pods
- Both syscall rules and k8saudit rules are loaded

> **Note:** In DaemonSet mode with k8saudit, audit logs are load-balanced to random Falco instances. Check all pods when troubleshooting.

### Scenario 4: Multi-Instance

Run separate Falco instances for different purposes (e.g., different node types or event sources):

```bash
# Regular nodes with Modern eBPF
helm install falco falcosecurity/falco --namespace falco

# Separate plugin-only instance for K8s audit
helm install falco-audit falcosecurity/falco \
  --namespace falco \
  -f values-k8saudit.yaml
```

This pattern is also used when different node pools require different driver configurations or when isolating syscall monitoring from plugin-based event processing.

**Source:** [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) (Deployment Scenarios)

## Ecosystem Integration

The Falco chart includes optional sub-chart dependencies for ecosystem components.

### Falcosidekick (Alert Forwarding)

Forwards Falco alerts to 60+ external outputs (Slack, Kafka, Elasticsearch, cloud services, etc.).

```yaml
falcosidekick:
  enabled: true
```

- Deployed as a **Deployment with 2 replicas** for high availability
- Listens on port **2801** (HTTP endpoint)
- Falco connects via `http_output.url: "http://falcosidekick:2801"`
- Includes ServiceMonitor, PrometheusRules, and Grafana dashboard support

```bash
# Standalone installation
helm install falcosidekick falcosecurity/falcosidekick --namespace falco

# Or as Falco sub-chart dependency
helm install falco falcosecurity/falco --set falcosidekick.enabled=true --namespace falco
```

**Source:** [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) (Falcosidekick Chart)

### K8s-Metacollector (Kubernetes Metadata Enrichment)

Centralized Kubernetes metadata streaming service that provides full K8s metadata to Falco instances via gRPC (port 45000).

```yaml
collectors:
  kubernetes:
    enabled: true        # Deploys k8s-metacollector as dependency
    pluginRef: "ghcr.io/falcosecurity/plugins/plugin/k8smeta:0.4.1"
```

Enables enrichment fields such as `k8s.ns.name`, `k8s.pod.name`, `k8s.deployment.name` beyond what the container plugin provides.

**Source:** [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) (K8s-Metacollector Chart)

### Falco-Talon (Automated Response)

Response engine for automated actions based on Falco alerts.

```yaml
responseActions:
  enabled: true
```

Supported actions include:
- Kubernetes: kill pod, label, cordon node
- AWS: Lambda invocation, SecurityHub integration
- Grafana dashboard for response action visibility

**Source:** [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) (Falco-Talon Chart)

## Monitoring

The Falco chart provides built-in support for Prometheus metrics, Grafana dashboards, and health monitoring.

### Metrics Endpoint

Falco exposes a Prometheus-compatible metrics endpoint on its webserver:

```yaml
metrics:
  enabled: true
  interval: 1h
  service:
    create: true
    port: 8765
```

The metrics endpoint is served on **port 8765** alongside the health and version endpoints.

### Health Endpoint

The `/healthz` endpoint on port 8765 is used for Kubernetes startup, liveness, and readiness probes.

### Prometheus ServiceMonitor

```yaml
serviceMonitor:
  create: true    # Requires Prometheus Operator CRDs
```

Creates a `ServiceMonitor` custom resource for automatic Prometheus scrape target discovery.

### Grafana Dashboards

```yaml
grafana:
  dashboards:
    enabled: true
```

Provisions Grafana dashboards as ConfigMaps (requires the Grafana sidecar dashboard provisioner).

### Full Observability Stack Example

```bash
helm install falco falcosecurity/falco \
  --set falcosidekick.enabled=true \
  --set metrics.enabled=true \
  --set serviceMonitor.create=true \
  --set grafana.dashboards.enabled=true \
  --namespace falco
```

**Source:** [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) (Metrics and Observability)

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`configuration.md`](configuration.md) | Falco configuration system (engine.kind, config_files, webserver settings used in ConfigMap) |
| [`falcoctl.md`](falcoctl.md) | Artifact and driver management CLI (init container and sidecar implementation details) |
| [`plugin-system.md`](plugin-system.md) | Plugin API and capabilities (container, k8saudit, k8smeta, json plugins used in deployment) |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Kernel driver types (modern_ebpf, kmod) configured via driver.kind |
| [`metrics-and-observability.md`](metrics-and-observability.md) | Internal metrics and Prometheus integration (metrics endpoint, ServiceMonitor) |
| [`output-system.md`](output-system.md) | Alert output channels (http_output to falcosidekick, stdout, gRPC) |

## Sources

| Topic | Source File |
|-------|-------------|
| Falco chart | [`charts/falco/`](../refs/falcosecurity/charts/charts/falco/) |
| Falco chart values | [`charts/falco/values.yaml`](../refs/falcosecurity/charts/charts/falco/values.yaml) |
| K8saudit values | [`charts/falco/values-k8saudit.yaml`](../refs/falcosecurity/charts/charts/falco/values-k8saudit.yaml) |
| Syscall + K8saudit values | [`charts/falco/values-syscall-k8saudit.yaml`](../refs/falcosecurity/charts/charts/falco/values-syscall-k8saudit.yaml) |
| Falcosidekick chart | [`charts/falcosidekick/`](../refs/falcosecurity/charts/charts/falcosidekick/) |
| Falco-talon chart | [`charts/falco-talon/`](../refs/falcosecurity/charts/charts/falco-talon/) |
| K8s-metacollector chart | [`charts/k8s-metacollector/`](../refs/falcosecurity/charts/charts/k8s-metacollector/) |
| Event-generator chart | [`charts/event-generator/`](../refs/falcosecurity/charts/charts/event-generator/) |
| Falco DaemonSet manifest | [`kubernetes/falco/templates/daemonset.yaml`](../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml) |
| Falco ConfigMap manifest | [`kubernetes/falco/templates/configmap.yaml`](../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml) |
| Falcoctl ConfigMap manifest | [`kubernetes/falco/templates/falcoctl-configmap.yaml`](../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml) |
| RBAC Role (chart) | [`charts/falco/templates/role.yaml`](../refs/falcosecurity/charts/charts/falco/templates/role.yaml) |
| RBAC RoleBinding (chart) | [`charts/falco/templates/roleBinding.yaml`](../refs/falcosecurity/charts/charts/falco/templates/roleBinding.yaml) |
| RBAC ServiceAccount (chart) | [`charts/falco/templates/serviceaccount.yaml`](../refs/falcosecurity/charts/charts/falco/templates/serviceaccount.yaml) |
| Charts digest | [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) |
| Deploy-kubernetes digest | [`digests/falcosecurity/deploy-kubernetes.md`](../digests/falcosecurity/deploy-kubernetes.md) |
