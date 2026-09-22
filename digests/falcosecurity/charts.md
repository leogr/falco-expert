# falcosecurity/charts Digest

**Repository:** https://github.com/falcosecurity/charts
**Era:** 0.45
**Status:** Core / Stable

Official Helm charts for deploying Falco and its ecosystem components in Kubernetes. This monorepo contains charts that demonstrate best practices for configuring and running Falco components.

## Overview

The repository provides production-ready Helm charts for:
- Deploying Falco as a DaemonSet or Deployment
- Integrating with container runtimes and Kubernetes
- Forwarding alerts to external systems
- Automated response actions
- Kubernetes metadata enrichment

**Helm Repository:** https://falcosecurity.github.io/charts
**OCI Registry:** https://github.com/orgs/falcosecurity/packages?repo_name=charts

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
```

> **Chart source and release:** Falco chart development lives in the [Falco repository](../../refs/falcosecurity/falco/chart/falco/); this charts monorepo is its published Helm/OCI distribution point. The current pin is `falco-9.2.0`, with appVersion `0.45.0` ([Chart.yaml](../../refs/falcosecurity/charts/charts/falco/Chart.yaml)).

## Charts Summary

| Chart | Version | AppVersion | Purpose |
|-------|---------|------------|---------|
| [falco](../../refs/falcosecurity/charts/charts/falco/) | 9.2.0 | 0.45.0 | Core Falco deployment |
| [falco-operator](../../refs/falcosecurity/charts/charts/falco-operator/) | 0.4.0-rc3 | 0.5.0-rc3 | Kubernetes Operator for managing Falco instances |
| [falcosidekick](../../refs/falcosecurity/charts/charts/falcosidekick/) | 0.14.0 | 2.31.1 | Alert forwarding to 60+ outputs |
| [falco-talon](../../refs/falcosecurity/charts/charts/falco-talon/) | 0.4.2 | 0.3.0 | Automated response actions |
| [k8s-metacollector](../../refs/falcosecurity/charts/charts/k8s-metacollector/) | 0.3.2 | 0.1.4 | Kubernetes metadata enrichment |
| [event-generator](../../refs/falcosecurity/charts/charts/event-generator/) | 0.4.0 | 0.13.0 | Test event generation |

> **Chart `appVersion` vs. bundled component versions:** Each chart's `appVersion` is the application version that chart release ships by default; it is not always the latest upstream release of that component (e.g., the bundled `falcosidekick` chart appVersion is `2.31.1`, while the standalone falcosidekick app is at `2.35.0`).

## Falco Chart (Main)

The primary chart for deploying Falco in Kubernetes. Can optionally include falcosidekick, k8s-metacollector, and falco-talon as dependencies.

### Basic Installation

```bash
helm install falco falcosecurity/falco \
    --create-namespace \
    --namespace falco
```

### Deployment Scenarios

The chart supports multiple deployment scenarios based on event sources. The key relationship:

- **Syscall events (drivers)** → **DaemonSet** (must run on every node to capture host syscalls)
- **Plugin events only** → **Deployment** (single/replicated instance, no node-level access needed)

#### Scenario 1: Syscall Monitoring Only (Default)

**Use case:** Runtime threat detection via system call monitoring.

```yaml
# values.yaml (default)
driver:
  enabled: true
  kind: auto  # Prefers Modern eBPF
controller:
  kind: daemonset
collectors:
  enabled: true  # Container metadata enrichment
```

```bash
helm install falco falcosecurity/falco --namespace falco
```

**What happens:**
- DaemonSet ensures Falco runs on every node
- Driver captures syscall events from the kernel
- Container plugin enriches events with container metadata
- falcoctl installs `falco-rules` (stable rules)

#### Scenario 2: Plugin-Only (K8s Audit Logs)

**Use case:** Kubernetes API audit log monitoring without syscall capture.

**Source:** [`values-k8saudit.yaml`](../../refs/falcosecurity/charts/charts/falco/values-k8saudit.yaml)

```yaml
driver:
  enabled: false  # No syscall capture
collectors:
  enabled: false  # No container metadata needed
controller:
  kind: deployment  # Single instance sufficient
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

```bash
helm install falco falcosecurity/falco -f values-k8saudit.yaml
```

**What happens:**
- Deployment creates a single Falco instance (or replicated for HA)
- k8saudit plugin exposes webhook endpoint on port 9765
- K8s API server sends audit logs to the webhook
- No drivers loaded, no container metadata collection

#### Scenario 3: Combined (Syscalls + K8s Audit Logs)

**Use case:** Full coverage with both syscall monitoring and K8s audit logs.

**Source:** [`values-syscall-k8saudit.yaml`](../../refs/falcosecurity/charts/charts/falco/values-syscall-k8saudit.yaml)

```yaml
driver:
  enabled: true
  kind: kmod  # Or auto/modern_ebpf
controller:
  kind: daemonset  # Required for syscall capture
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
falco:
  rules_files:
    - /etc/falco/falco_rules.yaml
    - /etc/falco/k8s_audit_rules.yaml
    - /etc/falco/rules.d
  load_plugins: [k8saudit, json]
```

**What happens:**
- DaemonSet runs Falco on every node for syscall monitoring
- k8saudit plugin also loaded on each instance
- Webhook service routes to Falco pods (audit logs go to random instance)
- Both syscall rules and k8saudit rules are loaded

> **Note:** In DaemonSet mode with k8saudit, audit logs are load-balanced to random Falco instances. Check all pods when testing.

#### Scenario 4: gVisor on GKE (Removed in 0.44)

**Use case:** Monitor gVisor-sandboxed pods on GKE.

**Source:** Previously available via the now-removed `values-gvisor-gke.yaml` (dropped in chart 8.x for the Falco 0.44 era when gVisor support was removed).

```yaml
driver:
  enabled: true
  kind: gvisor
  gvisor:
    runsc:
      path: /home/containerd/usr/local/sbin
      root: /run/containerd/runsc
      config: /run/containerd/runsc/config.toml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: sandbox.gke.io/runtime
          operator: In
          values: [gvisor]
tolerations:
  - effect: NoSchedule
    key: sandbox.gke.io/runtime
    operator: Equal
    value: gvisor
collectors:
  enabled: true
  containerd:
    enabled: true
```

**What happens:**
- DaemonSet with node affinity targets only gVisor-enabled nodes
- Falco uses gVisor's runsc to intercept sandboxed syscalls
- Separate Falco instance (with ebpf/kmod) needed for non-gVisor nodes

> **Removal:** gVisor engine was deprecated in Falco 0.43 and removed in Falco 0.44.

### Deployment Decision Matrix

| Event Source | `driver.enabled` | `controller.kind` | `collectors.enabled` |
|--------------|------------------|-------------------|----------------------|
| Syscalls only | `true` | `daemonset` | `true` |
| K8s Audit only | `false` | `deployment` | `false` |
| Syscalls + K8s Audit | `true` | `daemonset` | `true` |
| CloudTrail (plugin) | `false` | `deployment` | `false` |

### Driver Configuration

The `driver.kind` setting controls how Falco captures system events:

| Driver | Setting | Description |
|--------|---------|-------------|
| Auto (default) | `auto` | Automatically selects best driver |
| Modern eBPF | `modern_ebpf` | Recommended; shipped in Falco binary |
| Kernel Module | `kmod` | Traditional kernel module |
| Legacy eBPF | `ebpf` | **Removed in 0.44** (deprecated in 0.43) |
| gVisor | `gvisor.enabled: true` | **Removed in 0.44** (deprecated in 0.43) |

```bash
# Explicit Modern eBPF
helm install falco falcosecurity/falco --set driver.kind=modern_ebpf

# Kernel module
helm install falco falcosecurity/falco --set driver.kind=kmod
```

**Driver Loader:** The `falco-driver-loader` init container handles setup for `auto`/`kmod` when enabled. Explicit `modern_ebpf` uses the embedded probe and disables the loader by default.

### Container Metadata Collection

Container enrichment is enabled by default via the container plugin:

```yaml
collectors:
  enabled: true
  containerEngine:
    enabled: true
    pluginRef: "ghcr.io/falcosecurity/plugins/plugin/container:0.7.4"
    engines:
      docker: { enabled: true, sockets: ["/var/run/docker.sock"] }
      containerd: { enabled: true, sockets: ["/run/host-containerd/containerd.sock"] }
      cri: { enabled: true, sockets: [...] }
      podman: { enabled: true }
```

### Kubernetes Metadata (k8smeta plugin)

For full Kubernetes metadata (beyond container annotations):

```yaml
collectors:
  kubernetes:
    enabled: true  # Deploys k8s-metacollector as dependency
    pluginRef: "ghcr.io/falcosecurity/plugins/plugin/k8smeta:0.4.2"
```

This enables fields like `k8smeta.ns.name`, `k8smeta.pod.name`, `k8smeta.deployment.name`.

### Rules Management (falcoctl)

The chart uses falcoctl for artifact management:

```yaml
falcoctl:
  artifact:
    install:
      enabled: true
    follow:
      enabled: true
  config:
    artifact:
      install:
        refs: [falco-rules:5]
      follow:
        refs: [falco-rules:5]
        every: 168h
```

To include incubating/sandbox rules:
```bash
helm install falco falcosecurity/falco \
  --set "falcoctl.config.artifact.install.refs={falco-rules:5,falco-incubating-rules:6}" \
  --set "falcoctl.config.artifact.follow.refs={falco-rules:5,falco-incubating-rules:6}"
```

### Metrics and Observability

```yaml
metrics:
  enabled: true
  interval: 1h
  service:
    create: true
    port: 8765

serviceMonitor:
  create: true  # For Prometheus Operator

grafana:
  dashboards:
    enabled: true
```

### Output Configuration

Key Falco output settings:

```yaml
falco:
  json_output: true
  stdout_output:
    enabled: true
  http_output:
    enabled: true
    url: "http://falcosidekick:2801"
```

### Integrations

**Falcosidekick** (alert forwarding):
```yaml
falcosidekick:
  enabled: true
```

**Falco Talon** (response actions):
```yaml
responseActions:
  enabled: true
```

### Security Contexts

Driver-dependent security contexts are auto-configured:

| Driver | Security Context |
|--------|-----------------|
| No driver | `{}` |
| kmod, modern_ebpf | `privileged: true` |
| modern_ebpf + leastPrivileged | `capabilities: [BPF, SYS_RESOURCE, PERFMON, SYS_PTRACE]` |

### Key Values Reference

| Setting | Default | Description |
|---------|---------|-------------|
| `driver.kind` | `auto` | Driver selection |
| `driver.modernEbpf.disableIterators` | `false` | Disable BPF iterators; fall back to procfs (modern_ebpf only, since chart 9.1.0 / Falco 0.44.1) |
| `controller.kind` | `daemonset` | DaemonSet or Deployment |
| `collectors.enabled` | `true` | Container metadata |
| `collectors.kubernetes.enabled` | `false` | Full K8s metadata |
| `falcoctl.artifact.install.enabled` | `true` | Install artifacts at startup |
| `falcoctl.artifact.follow.enabled` | `true` | Auto-update artifacts |
| `metrics.enabled` | `false` | Prometheus metrics |
| `falcosidekick.enabled` | `false` | Deploy falcosidekick |
| `responseActions.enabled` | `false` | Deploy falco-talon |

## Falco-Operator Chart

Deploys the [Falco Operator](falco-operator.md) (Kubernetes Operator, Incubating) that manages Falco instances and their artifacts via Custom Resources. The chart at this monorepo pin is prerelease `0.4.0-rc3`, appVersion `0.5.0-rc3`; the standalone operator digest describes stable v0.4.1. Do not conflate these snapshots.

```bash
helm install falco-operator falcosecurity/falco-operator --namespace falco
```

## Falcosidekick Chart

Forwards Falco alerts to 60+ outputs including Slack, Kafka, Elasticsearch, and cloud services.

```bash
helm install falcosidekick falcosecurity/falcosidekick --namespace falco
```

Or as Falco dependency:
```bash
helm install falco falcosecurity/falco --set falcosidekick.enabled=true
```

Key features:
- 2 replicas by default for HA
- ServiceMonitor for Prometheus
- PrometheusRules for alerting
- Grafana dashboard

## K8s-Metacollector Chart

Fetches and distributes Kubernetes metadata to Falco instances via gRPC (port 45000).

Typically deployed as a Falco chart dependency when `collectors.kubernetes.enabled=true`.

## Falco-Talon Chart

Response engine for automated actions based on Falco alerts.

```yaml
# As Falco dependency
responseActions:
  enabled: true
```

Features:
- Kubernetes actions (kill pod, label, cordon node)
- AWS actions (Lambda, SecurityHub)
- Grafana dashboard

## Event-Generator Chart

Generates events to trigger Falco rules for testing.

```bash
helm install event-generator falcosecurity/event-generator --namespace falco
```

Deployment modes:
- Job (one-time generation)
- Deployment (continuous generation)

## Maintainers

**Approvers:** leogr, Issif, cpanato, alacuku, ekoops

**Reviewers:** bencer

**Source:** [`OWNERS`](../../refs/falcosecurity/charts/OWNERS)

## Additional Configuration Patterns

### Pattern: Minimal Resource Usage

Reduce CPU/memory footprint with least-privilege and minimal syscall set:

```yaml
driver:
  kind: modern_ebpf
  modernEbpf:
    leastPrivileged: true  # Capabilities instead of privileged
falco:
  base_syscalls:
    repair: true  # Only syscalls needed for rules + state engine
```

### Pattern: Full Observability Stack

Complete monitoring with metrics, dashboards, and alert forwarding:

```bash
helm install falco falcosecurity/falco \
  --set falcosidekick.enabled=true \
  --set metrics.enabled=true \
  --set serviceMonitor.create=true \
  --set grafana.dashboards.enabled=true
```

### Pattern: Custom Rules via ConfigMap

Add organization-specific rules:

```yaml
customRules:
  my-rules.yaml: |-
    - rule: My Custom Rule
      desc: Detect specific behavior
      condition: spawned_process and proc.name = "suspicious"
      output: "Custom alert (user=%user.name command=%proc.cmdline)"
      priority: WARNING
```

### Pattern: Multiple Falco Instances

Run separate instances for different purposes (e.g., gVisor + regular nodes):

```bash
# Regular nodes with Modern eBPF
helm install falco falcosecurity/falco --namespace falco

# gVisor nodes (removed in 0.44; example retained for historical context)
helm install falco-gvisor falcosecurity/falco \
  --namespace falco-gvisor \
  -f values-gvisor-gke.yaml
```

## Era-Specific Notes

- **Removal:** Legacy eBPF probe (`driver.kind=ebpf`) removed in 0.44 (deprecated in 0.43)
- **Removal:** gVisor engine removed in 0.44 (deprecated in 0.43)
- **Removal:** gRPC output and server support dropped in chart 9.0.0 (Falco 0.44)
- **Default driver:** `auto` mode prefers Modern eBPF
- **Container plugin:** Unified container metadata collection (since 0.40)
- **Chart 9.1.0 (Falco 0.44.1):** Bumped `appVersion` to `0.44.1`; added `driver.modernEbpf.disableIterators` (default `false`) to opt out of BPF iterators and fall back to procfs, and exposed the missing `metrics.kernelIterEventCountersEnabled` (default `true`) for kernel-side iterator event/drop counters. See the Falco [`configuration`](falco/configuration.md) digest for the underlying `engine.modern_ebpf.disable_iterators` option.

### Chart 9.2.0 Behavior

Container-runtime hostPath volumes mount each socket's **parent directory** under `/host`, deduplicated by directory, so replacement sockets after a runtime restart remain visible. Plugin configuration still specifies socket file paths on the host. The Falco container always mounts the `specialized-falco-configs` emptyDir at `/etc/falco/config.d`, including when the driver loader and both falcoctl containers are disabled, to shadow image-provided snippets. The falcoctl ConfigMap volume is only rendered when an artifact container uses it.

Both controllers support `revisionHistoryLimit`, including an explicit zero; unset values leave the Kubernetes default. `serviceAccount.labels` adds custom ServiceAccount labels. The Falco chart depends on falcosidekick `0.14.*`, metacollector `0.3.*`, and Talon `0.4.*`.

**Source:** [`_helpers.tpl:447-514`](../../refs/falcosecurity/charts/charts/falco/templates/_helpers.tpl), [`pod-template.tpl:147-161,224-284`](../../refs/falcosecurity/charts/charts/falco/templates/pod-template.tpl), [`daemonset.yaml:20-22`](../../refs/falcosecurity/charts/charts/falco/templates/daemonset.yaml), [`deployment.yaml:18-20`](../../refs/falcosecurity/charts/charts/falco/templates/deployment.yaml), [`serviceaccount.yaml:11-17`](../../refs/falcosecurity/charts/charts/falco/templates/serviceaccount.yaml), [`Chart.yaml:20-32`](../../refs/falcosecurity/charts/charts/falco/Chart.yaml).

The chart's HTTP output mTLS settings configure **outgoing alerts**. They do not enable client-certificate authentication on the k8saudit webhook; that listener uses its own HTTPS server certificate configuration.

**Source:** [`README.md:274-284`](../../refs/falcosecurity/charts/charts/falco/README.md).

## Sources

| Topic | Source File |
|-------|-------------|
| Falco chart | [`charts/falco/`](../../refs/falcosecurity/charts/charts/falco/) |
| Falco chart values | [`charts/falco/values.yaml`](../../refs/falcosecurity/charts/charts/falco/values.yaml) |
| K8saudit values | [`charts/falco/values-k8saudit.yaml`](../../refs/falcosecurity/charts/charts/falco/values-k8saudit.yaml) |
| Syscall + K8saudit values | [`charts/falco/values-syscall-k8saudit.yaml`](../../refs/falcosecurity/charts/charts/falco/values-syscall-k8saudit.yaml) |
| Falco-operator chart | [`charts/falco-operator/`](../../refs/falcosecurity/charts/charts/falco-operator/) |
| Falco chart CHANGELOG | [`charts/falco/CHANGELOG.md`](../../refs/falcosecurity/charts/charts/falco/CHANGELOG.md) |
| Falcosidekick chart | [`charts/falcosidekick/`](../../refs/falcosecurity/charts/charts/falcosidekick/) |
| Falco-talon chart | [`charts/falco-talon/`](../../refs/falcosecurity/charts/charts/falco-talon/) |
| K8s-metacollector chart | [`charts/k8s-metacollector/`](../../refs/falcosecurity/charts/charts/k8s-metacollector/) |
| Event-generator chart | [`charts/event-generator/`](../../refs/falcosecurity/charts/charts/event-generator/) |
| Repository ownership | [`OWNERS`](../../refs/falcosecurity/charts/OWNERS) |
