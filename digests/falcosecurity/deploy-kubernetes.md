# falcosecurity/deploy-kubernetes Digest

**Repository:** https://github.com/falcosecurity/deploy-kubernetes
**Era:** 0.44
**Status:** Core / Stable
**Pinned commit:** `ecd78de` (2026-05-27, day after the Falco 0.44.0 release)

Pre-rendered Kubernetes manifests auto-generated from the [Helm charts](charts.md). These serve as deployment templates and provide insight into how Falco components are structured in Kubernetes. The manifests in this submodule were generated from the `falco-9.0.0` chart (appVersion `0.44.0`).

## Overview

This repository provides ready-to-use Kubernetes manifests that can be deployed directly with `kubectl` or `kustomize`, without requiring Helm. The manifests are generated from the [falcosecurity/charts](../../refs/falcosecurity/charts/) repository and reflect the default chart configurations.

**Source:** [`README.md`](../../refs/falcosecurity/deploy-kubernetes/README.md)

**Important:** These are **templates** meant as starting points, not final resources. The repository README explicitly states they are "strongly recommended" to be considered templates ([`README.md:8`](../../refs/falcosecurity/deploy-kubernetes/README.md)). For production deployments, either:
- Customize these manifests for your environment
- Use the Helm charts directly for more flexibility

**Deployment method:** [Kustomize](https://kustomize.io/) — each component directory has a [`kustomization.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/kustomization.yaml).
```bash
kubectl apply -k kubernetes/falco
```

> **Note (stale upstream content):** The [`kubernetes/README.md:11`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/README.md) still claims "The default configuration in Falco utilizes the kernel module driver (`kmod`)." This is outdated — the rendered [`configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml) sets `engine.kind: modern_ebpf` as the default. The same README correctly notes that `modern_ebpf` needs no driver download/build and no `falco-driver-loader` init container ([`kubernetes/README.md:15`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/README.md)).

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

The Falco manifests demonstrate how Falco operates as a DaemonSet with multiple containers and init containers working together. The DaemonSet uses a `RollingUpdate` update strategy and tolerates `node-role.kubernetes.io/master` and `node-role.kubernetes.io/control-plane` NoSchedule taints, so it runs on control-plane nodes too ([`daemonset.yaml:29-33,261-262`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)).

### Kubernetes Resources

The [`kustomization.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/kustomization.yaml) bundles 8 resources:

| Resource | File | Purpose |
|----------|------|---------|
| DaemonSet | [`daemonset.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml) | Main Falco deployment |
| ConfigMap (`falco`) | [`configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml) | `falco.yaml` configuration |
| ConfigMap (`falco-falcoctl`) | [`falcoctl-configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml) | `falcoctl.yaml` for artifact management |
| ServiceAccount | [`serviceaccount.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/serviceaccount.yaml) | Pod identity (`falco`) |
| ClusterRole | [`clusterrole.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/clusterrole.yaml) | Cluster-wide read access |
| ClusterRoleBinding | [`clusterrolebinding.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/clusterrolebinding.yaml) | Binds ClusterRole |
| Role | [`role.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/role.yaml) | Namespace-scoped configmap access |
| RoleBinding | [`roleBinding.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/roleBinding.yaml) | Binds Role |

> Both **ClusterRole + ClusterRoleBinding** AND **Role + RoleBinding** exist for Falco. The ClusterRole grants cluster-wide read access; the namespace Role grants `configmaps` write access used by the driver-loader to persist its detected config (see [RBAC Permissions](#rbac-permissions)).

All resources are created in the `default` namespace ([`daemonset.yaml:5`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)).

### Pod Structure

The Falco pod consists of **2 init containers** and **2 runtime containers** ([`daemonset.yaml:34-195`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)):

```
┌─────────────────────────────────────────────────────────────────┐
│                          Falco Pod                                │
├─────────────────────────────────────────────────────────────────┤
│  Init Containers (run sequentially before main containers):       │
│  ┌───────────────────────┐  ┌─────────────────────────────────┐  │
│  │ falco-driver-loader   │  │ falcoctl-artifact-install       │  │
│  │ - args: [auto]        │  │ - args: [artifact, install,     │  │
│  │ - privileged: true    │  │   --log-format=json]            │  │
│  │ - builds/loads driver │  │ - downloads rules + plugins     │  │
│  │ - writes config to    │  │   into emptyDir volumes         │  │
│  │   specialized-falco-  │  │ - writes detected driver config │  │
│  │   configs emptyDir    │  │   to the falco ConfigMap        │  │
│  └───────────────────────┘  └─────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│  Runtime Containers (run in parallel):                            │
│  ┌───────────────────────┐  ┌─────────────────────────────────┐  │
│  │ falco                 │  │ falcoctl-artifact-follow        │  │
│  │ - args: [/usr/bin/    │  │ - args: [artifact, follow,      │  │
│  │   falco]              │  │   --log-format=json]            │  │
│  │ - privileged: true    │  │ - watches for rule updates      │  │
│  │ - processes events    │  │ - empty securityContext         │  │
│  │ - web server :8765    │  │ - re-checks every 168h (1 week) │  │
│  └───────────────────────┘  └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Init Containers

#### 1. `falco-driver-loader`

**Image:** `docker.io/falcosecurity/falco-driver-loader:0.44.0` ([`daemonset.yaml:145`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml))
**Purpose:** Download or build the kernel driver before Falco starts

```yaml
args:
  - auto              # Automatically selects best driver (modern_ebpf preferred)
securityContext:
  privileged: true    # Required for driver loading
env:
  - HOST_ROOT=/host
  - FALCOCTL_DRIVER_CONFIG_NAMESPACE  # from metadata.namespace
  - FALCOCTL_DRIVER_CONFIG_CONFIGMAP=falco
```

**Volume mounts** ([`daemonset.yaml:151-169`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)): `/root/.falco`, `/host/proc` (ro), `/host/boot` (ro), `/host/lib/modules`, `/host/usr` (ro), `/host/etc` (ro), and `/etc/falco/config.d` (writes the detected driver config to the `specialized-falco-configs` emptyDir).

> **Note:** With `modern_ebpf` (the default), no driver is downloaded or built — it is bundled in the Falco binary via CO-RE eBPF and works on kernels >= 5.8 ([`kubernetes/README.md:15`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/README.md)). The driver-loader still runs and persists driver config into the `falco` ConfigMap via `FALCOCTL_DRIVER_CONFIG_CONFIGMAP=falco` ([`daemonset.yaml:177-178`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)).

#### 2. `falcoctl-artifact-install`

**Image:** `docker.io/falcosecurity/falcoctl:0.13.0` ([`daemonset.yaml:180`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml))
**Purpose:** Download rules and plugins before Falco starts

```yaml
args:
  - artifact
  - install
  - --log-format=json
securityContext:        # empty (no privilege escalation)
```

**Volume mounts** ([`daemonset.yaml:187-195`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)): `/plugins`, `/rulesfiles`, `/etc/falcoctl` (config), `/artifactstate`.

**Default artifacts installed** (from the falcoctl config, [`falcoctl-configmap.yaml:26-33`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml)):
- `falco-rules:5` — Stable Falco rules (major version 5)
- `ghcr.io/falcosecurity/plugins/plugin/container:0.7.1` — Container metadata plugin
- `resolveDeps: true` — dependency resolution enabled

### Runtime Containers

#### 1. `falco`

**Image:** `docker.io/falcosecurity/falco:0.44.0` ([`daemonset.yaml:36`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml))
**Purpose:** Main Falco process for threat detection

```yaml
args:
  - /usr/bin/falco
securityContext:
  privileged: true     # Required for syscall capture
resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1024Mi
ports:
  - containerPort: 8765  # name: web — web server (healthz, versions, metrics)
```

**Key environment variables** ([`daemonset.yaml:49-59`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)):
- `HOST_ROOT=/host` — Host filesystem mount point
- `FALCO_HOSTNAME` — Node name (from `spec.nodeName`)
- `FALCO_K8S_NODE_NAME` — Node name (from `spec.nodeName`)

**Health probes** ([`daemonset.yaml:65-88`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)): `startupProbe`, `livenessProbe`, and `readinessProbe` all HTTP-GET `/healthz` on port 8765. The startup probe allows up to 20 failures (≈100s) before liveness takes over.

> Unlike the init `falco-driver-loader`, the main `falco` container does **not** mount `/host/boot`, `/host/lib/modules`, or `/host/usr` — it only mounts `/host/proc`, `/host/etc` (ro), `/host/dev` (ro), `/sys/module`, and `/sys/kernel` (ro), plus the container sockets and emptyDir volumes ([`daemonset.yaml:89-125`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)).

#### 2. `falcoctl-artifact-follow`

**Image:** `docker.io/falcosecurity/falcoctl:0.13.0` ([`daemonset.yaml:127`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml))
**Purpose:** Watch for and download rule updates while Falco runs

```yaml
args:
  - artifact
  - follow
  - --log-format=json
securityContext:        # empty
```

Re-checks for updates every `168h` (1 week) and queries the running Falco web server for compatible versions via `http://localhost:8765/versions` ([`falcoctl-configmap.yaml:18-21`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml)). It follows only `falco-rules:5` ([`falcoctl-configmap.yaml:22-23`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml)).

### Volume Architecture

The DaemonSet combines **hostPath** volumes (system access), **emptyDir** volumes (inter-container communication), and **configMap** volumes (config files) ([`daemonset.yaml:196-260`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)).

#### Host Path Volumes (System Access)

| Volume | Host Path | Purpose | Mounted on |
|--------|-----------|---------|------------|
| `proc-fs` | `/proc` | Process information | falco + driver-loader |
| `dev-fs` | `/dev` | Device access | falco (ro) |
| `etc-fs` | `/etc` | System configuration | falco (ro) + driver-loader (ro) |
| `boot-fs` | `/boot` | Kernel files | driver-loader (ro) |
| `lib-modules` | `/lib/modules` | Kernel modules | driver-loader |
| `usr-fs` | `/usr` | System binaries | driver-loader (ro) |
| `sys-module-fs` | `/sys/module` | Kernel module info | falco |
| `sys-fs` | `/sys/kernel` | Kernel tracing (tracefs/debugfs) | falco (ro) |

#### Container Socket Volumes

All six are mounted into the `falco` container under `/host/...` (matching the container plugin socket config) ([`daemonset.yaml:90-101,197-214`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml)):

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
| `rulesfiles-install-dir` | Downloaded rules (`/etc/falco` in falco; `/rulesfiles` in falcoctl) | falcoctl → falco |
| `plugins-install-dir` | Downloaded plugins (`/usr/share/falco/plugins` in falco; `/plugins` in falcoctl) | falcoctl → falco |
| `specialized-falco-configs` | Driver config at `/etc/falco/config.d` | driver-loader → falco |
| `root-falco-fs` | Falco working dir `/root/.falco` | driver-loader → falco |
| `artifact-state-dir` | falcoctl state `/artifactstate` | install ↔ follow |

#### ConfigMap Volumes (Config Files)

| Volume | ConfigMap | Mount | Notes |
|--------|-----------|-------|-------|
| `falco-yaml` | `falco` (key `falco.yaml`) | `/etc/falco/falco.yaml` (subPath) | Main Falco config, mounted on `falco` container |
| `falcoctl-config-volume` | `falco-falcoctl` (key `falcoctl.yaml`) | `/etc/falcoctl` | Mounted on both falcoctl containers |

### Falco Configuration (`falco.yaml`)

**Source:** [`configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml) (ConfigMap `falco`)

Notable settings in the default deployment:

```yaml
config_files:
  - /etc/falco/config.d        # driver-loader writes detected config here
engine:
  kind: modern_ebpf            # Default driver
  kmod:
    buf_size_preset: 4
    drop_failed_exit: false
  modern_ebpf:
    buf_size_preset: 4
    cpus_for_each_buffer: 2
    drop_failed_exit: false
falco_libs:
  snaplen: 80
  thread_table_size: 262144
  thread_table_auto_purging_interval_s: 300
load_plugins:
  - container                  # Container metadata enrichment
plugins:
  - name: container
    library_path: libcontainer.so
    init_config:
      engines:
        bpm:         { enabled: true }
        containerd:  { enabled: true, sockets: ["/run/host-containerd/containerd.sock"] }
        cri:         { enabled: true, sockets: ["/run/containerd/containerd.sock", "/run/crio/crio.sock", "/run/k3s/containerd/containerd.sock", "/run/host-containerd/containerd.sock"] }
        docker:      { enabled: true, sockets: ["/var/run/docker.sock"] }
        libvirt_lxc: { enabled: true }
        lxc:         { enabled: true }
        podman:      { enabled: true, sockets: ["/run/podman/podman.sock"] }
      hooks: [create]
plugins_hostinfo: true
priority: debug                # Minimum rule severity emitted
rule_matching: first           # Stop at first matching rule
rules_files:
  - /etc/falco/falco_rules.yaml
  - /etc/falco/falco_rules.local.yaml
  - /etc/falco/rules.d
stdout_output:   { enabled: true }
syslog_output:   { enabled: true }
json_output: false
watch_config_files: true
webserver:
  enabled: true
  listen_address: 0.0.0.0
  listen_port: 8765
  k8s_healthz_endpoint: /healthz
  prometheus_metrics_enabled: false
  ssl_enabled: false
```

Other defaults present in the ConfigMap: `append_output` with `suggested_output: true`; `http_output.enabled: false` (TLS cert paths under `/etc/falco/certs/`); `program_output.enabled: false`; `syscall_event_drops` with `log`+`alert` actions; `libs_logger.enabled: true`; `buffered_outputs: false`; `time_format_iso_8601: false` ([`configmap.yaml:14-147`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml)).

### RBAC Permissions

**ClusterRole** ([`clusterrole.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/clusterrole.yaml)) — cluster-wide read (`get`/`list`/`watch`):
- Core/extensions group: `nodes`, `namespaces`, `pods`, `replicationcontrollers`, `replicasets`, `services`, `daemonsets`, `deployments`, `events`, `configmaps`
- `apps` group: `daemonsets`, `deployments`, `replicasets`, `statefulsets`
- Non-resource URLs: `/healthz`, `/healthz/*` (`get`)

> **Stale labels (verified in source):** [`clusterrole.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/clusterrole.yaml) and [`clusterrolebinding.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/clusterrolebinding.yaml) carry old chart labels `helm.sh/chart: falco-3.8.7` and `app.kubernetes.io/version: "0.36.2"`, unlike the other Falco resources which use `falco-9.0.0` / `0.44.0`. The RBAC rules themselves are unchanged and remain valid; only the metadata labels are outdated in the generated output.

**Role** (namespace-scoped, [`role.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/role.yaml)) — `configmaps`: `get`, `list`, `update`. This lets the `falco-driver-loader` init container write the detected driver configuration back into the `falco` ConfigMap.

These permissions let Falco and the container plugin enrich events with Kubernetes metadata and let the driver loader persist its config.

## Falcosidekick Deployment

**Source:** [`kubernetes/falcosidekick/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/) — chart `falcosidekick-0.13.1`

The [`kustomization.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/kustomization.yaml) bundles 8 resources: Deployment, a Grafana Loki dashboard ConfigMap, UI RBAC, core RBAC, UI secret, core secret, Service, and a test-connection Pod.

A `Deployment` (not DaemonSet) with **2 replicas** for high availability ([`deployment.yaml:16`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/deployment.yaml)):

```yaml
spec:
  replicas: 2
  securityContext:
    fsGroup: 1234
    runAsUser: 1234
  containers:
    - name: falcosidekick
      image: docker.io/falcosecurity/falcosidekick:2.32.0
      ports:
        - name: http
          containerPort: 2801
      livenessProbe/readinessProbe:
        httpGet: { path: /ping, port: http }
      envFrom:
        - secretRef: { name: falcosidekick }   # all output config via the secret
```

> **Version inconsistency (verified in source):** the container `image` tag is `2.32.0` ([`deployment.yaml:41`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/deployment.yaml)), but the resource labels report `app.kubernetes.io/version: "2.31.1"` and `helm.sh/chart: falcosidekick-0.13.1` ([`deployment.yaml:7-10`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/deployment.yaml)). The `falcosidekick-0.13.1` chart's appVersion is `2.31.1` ([`charts/falcosidekick/Chart.yaml`](../../refs/falcosecurity/charts/charts/falcosidekick/Chart.yaml)); the rendered manifest pins the newer `2.32.0` image. Report the image tag as `2.32.0` faithfully.

**Service** ([`service.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/service.yaml)): `ClusterIP` exposing port `2801` (`http`) and `2810` (`http-notls`); annotated `prometheus.io/scrape: "true"`.

**RBAC** ([`rbac.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/rbac.yaml)): ServiceAccount + namespace Role granting `get` on `endpoints`, plus a RoleBinding.

**Outputs config** ([`secrets.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/secrets.yaml)): a single `falcosidekick` Secret carrying the (empty/default) environment variables for all 70+ supported outputs (Slack, Loki, Elasticsearch, Kafka, AWS, GCP, OTLP, etc.). Outputs are enabled by populating these keys.

**UI scaffolding (no UI deployment):** the directory ships `falcosidekick-ui` RBAC ([`rbac-ui.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/rbac-ui.yaml), empty rules) and a `falcosidekick-ui-redis` Secret ([`secrets-ui.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/secrets-ui.yaml)), but **no UI Deployment or Service** is rendered (the UI is disabled by default).

**Extras:** a Grafana Loki dashboard ConfigMap ([`falcosidekick-loki-dashboard-grafana.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/falcosidekick-loki-dashboard-grafana.yaml), labeled `grafana_dashboard: "1"`) and a Helm `test-success` Pod that POSTs to `falcosidekick:2801/ping` ([`tests/test-connection.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/tests/test-connection.yaml)).

**To connect Falco to Falcosidekick**, enable `http_output` in Falco:
```yaml
http_output:
  enabled: true
  url: "http://falcosidekick:2801"
```
(In this rendered config `http_output.enabled` is `false` by default — [`configmap.yaml:47-61`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml).)

## Falco-Exporter Deployment

**Source:** [`kubernetes/falco-exporter/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/) — chart `falco-exporter-0.12.2`

> **Important:** `falco-exporter` is shipped **only** by deploy-kubernetes. Its Helm chart was removed from the [falcosecurity/charts](charts.md) repository in the 0.44 era (no `falco-exporter` chart exists at `charts/charts/` for `falco-9.0.0`). There is **no current falco-exporter Helm chart** to install. The manifests here remain as a generated artifact from an older chart version.

A `DaemonSet` ([`daemonset.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/templates/daemonset.yaml)) that reads Falco's gRPC socket and exposes Prometheus metrics:

```yaml
containers:
  - name: falco-exporter
    image: docker.io/falcosecurity/falco-exporter:0.8.3
    args:
      - /usr/bin/falco-exporter
      - --client-socket=unix:///run/falco/falco.sock
      - --timeout=2m
      - --listen-address=0.0.0.0:9376
    ports:
      - name: metrics
        containerPort: 9376        # Prometheus metrics
    securityContext:
      privileged: false
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities: { drop: [ALL] }
      seccompProfile: { type: RuntimeDefault }
    livenessProbe:  { httpGet: { path: /liveness,  port: 19376 } }
    readinessProbe: { httpGet: { path: /readiness, port: 19376 } }
    volumeMounts:
      - mountPath: /run/falco        # hostPath /run/falco (ro)
        name: falco-socket-dir
```

The `falco-exporter` resource labels report `app.kubernetes.io/version: "0.8.7"` while the image tag is `0.8.3` ([`daemonset.yaml:8,39`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/templates/daemonset.yaml)) — another label/image mismatch in the generated output; the deployed image is `0.8.3`. The **Service** is headless (`clusterIP: None`) and annotated for Prometheus scraping on port 9376 ([`service.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/templates/service.yaml)). It also ships a ServiceAccount ([`serviceaccount.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/templates/serviceaccount.yaml)) and a `busybox` `wget` test Pod ([`tests/test-connection.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/templates/tests/test-connection.yaml)).

> **Requires the gRPC Unix socket** at `/run/falco/falco.sock`. The rendered Falco `falco.yaml` in this submodule does **not** enable gRPC, and the gRPC output server was removed from Falco in 0.44 (deprecated in 0.43). For metrics on a current 0.44 deployment, use Falco's native Prometheus endpoint instead (`webserver.prometheus_metrics_enabled`, currently `false` — [`configmap.yaml:144`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml)). This DaemonSet is therefore effectively legacy.

## Event-Generator Deployment

**Source:** [`kubernetes/event-generator/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/) — chart `event-generator-0.4.0` (appVersion `0.13.0`)

A `Deployment` (1 replica) that continuously generates suspect actions to exercise Falco rules ([`deployment.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/templates/deployment.yaml)):

```yaml
containers:
  - name: event-generator
    image: falcosecurity/event-generator:latest
    command:
      - /bin/event-generator
      - run
      - --all
      - ^syscall      # run all syscall-category actions
      - --loop        # repeat continuously
    env:
      - FALCO_EVENT_GENERATOR_NAMESPACE   # from metadata.namespace
```

> The image tag is the floating `latest` (not a pinned version), and the deployment `app.kubernetes.io/version` label is `0.13.0` ([`deployment.yaml:10,33`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/templates/deployment.yaml)). The `--loop` flag generates a continuous stream of events — intended for test environments only.

**RBAC** ([`rbac.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/templates/rbac.yaml)): a ServiceAccount, a **ClusterRole** (broad create/delete on configmaps, services, serviceaccounts, pods, deployments, roles/rolebindings; `get` on `pods/exec` and all resources), and a **RoleBinding** that binds the ClusterRole to the ServiceAccount in `default`. (Note: a RoleBinding referencing a ClusterRole grants those permissions only within the binding's namespace.)

## Deployment Commands

```bash
# Deploy Falco
kubectl apply -k kubernetes/falco

# Deploy Falcosidekick (optional)
kubectl apply -k kubernetes/falcosidekick

# Deploy Falco-Exporter (optional, legacy — requires Falco gRPC, removed in 0.44)
kubectl apply -k kubernetes/falco-exporter

# Deploy Event Generator (for testing only — generates many events continuously)
kubectl apply -k kubernetes/event-generator

# Tear down
kubectl delete -k kubernetes/falco
```

## Verification

Per [`kubernetes/README.md:46-71`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/README.md):

```bash
# Check pods
kubectl -n default get pods -l app.kubernetes.io/name=falco

# View logs
kubectl -n default logs <falco-pod> -c falco

# Test - spawn a shell (should trigger "Terminal shell in container" rule)
kubectl -n default exec -it <falco-pod> -c falco -- bash
```

Alternatively, deploy the [event-generator](https://github.com/falcosecurity/event-generator) to automatically generate test events.

## Archive (Deprecated)

The [`archive/`](../../refs/falcosecurity/deploy-kubernetes/archive/) directory contains deprecated configurations:

- [`falco-k8s-audit-sink/`](../../refs/falcosecurity/deploy-kubernetes/archive/falco-k8s-audit-sink/) — K8s AuditSink resource (deprecated API)
- [`kind/`](../../refs/falcosecurity/deploy-kubernetes/archive/kind/) — Kind cluster audit configuration
- [`kubeadm/`](../../refs/falcosecurity/deploy-kubernetes/archive/kubeadm/) — Kubeadm audit configuration

For K8s audit logs, use the [k8saudit plugin](https://github.com/falcosecurity/plugins/tree/main/plugins/k8saudit) instead (see [`plugins/k8saudit.md`](plugins/k8saudit.md)).

## Relationship to Helm Charts

These manifests are generated from [falcosecurity/charts](charts.md) with default values. Chart versions verified against the [charts submodule](../../refs/falcosecurity/charts/) at tag `falco-9.0.0`:

| Manifest | Helm Chart | Chart Version (per rendered labels) | In charts repo at `falco-9.0.0`? |
|----------|------------|-------------------------------------|----------------------------------|
| [`kubernetes/falco/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/) | `falco` | `9.0.0` (appVersion `0.44.0`) | Yes ([`Chart.yaml`](../../refs/falcosecurity/charts/charts/falco/Chart.yaml): `9.0.0` / `0.44.0`) |
| [`kubernetes/falcosidekick/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/) | `falcosidekick` | `0.13.1` (appVersion `2.31.1`) | Yes ([`Chart.yaml`](../../refs/falcosecurity/charts/charts/falcosidekick/Chart.yaml): `0.13.1` / `2.31.1`) |
| [`kubernetes/falco-exporter/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/) | `falco-exporter` | `0.12.2` (appVersion `0.8.7`) | **No — chart removed in the 0.44 era** |
| [`kubernetes/event-generator/`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/) | `event-generator` | `0.4.0` (appVersion `0.13.0`) | Yes ([`Chart.yaml`](../../refs/falcosecurity/charts/charts/event-generator/Chart.yaml): `0.4.0` / `0.13.0`) |

> The chart versions above are taken from the `helm.sh/chart` labels embedded in the rendered manifests. For the `falco`, `falcosidekick`, and `event-generator` charts these match the current charts submodule. The `falco-exporter` chart is **no longer present** in the charts repo — its manifests here are a leftover generated artifact, so do not treat `falco-exporter-0.12.2` as a currently-installable chart.

For customization beyond these defaults, use the Helm charts directly.

## Sources

| Topic | Source File |
|-------|-------------|
| Repo overview | [`README.md`](../../refs/falcosecurity/deploy-kubernetes/README.md) |
| Manifest usage guide | [`kubernetes/README.md`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/README.md) |
| Falco kustomization | [`kubernetes/falco/kustomization.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/kustomization.yaml) |
| Falco DaemonSet | [`kubernetes/falco/templates/daemonset.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/daemonset.yaml) |
| Falco ConfigMap | [`kubernetes/falco/templates/configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/configmap.yaml) |
| Falcoctl ConfigMap | [`kubernetes/falco/templates/falcoctl-configmap.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/falcoctl-configmap.yaml) |
| Falco ClusterRole | [`kubernetes/falco/templates/clusterrole.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/clusterrole.yaml) |
| Falco Role | [`kubernetes/falco/templates/role.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco/templates/role.yaml) |
| Falcosidekick Deployment | [`kubernetes/falcosidekick/templates/deployment.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/deployment.yaml) |
| Falcosidekick Secret (outputs) | [`kubernetes/falcosidekick/templates/secrets.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falcosidekick/templates/secrets.yaml) |
| Falco-exporter DaemonSet | [`kubernetes/falco-exporter/templates/daemonset.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/falco-exporter/templates/daemonset.yaml) |
| Event-generator Deployment | [`kubernetes/event-generator/templates/deployment.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/templates/deployment.yaml) |
| Event-generator RBAC | [`kubernetes/event-generator/templates/rbac.yaml`](../../refs/falcosecurity/deploy-kubernetes/kubernetes/event-generator/templates/rbac.yaml) |
| Archive (deprecated) | [`archive/`](../../refs/falcosecurity/deploy-kubernetes/archive/) |
| Charts cross-reference | [`charts/falco/Chart.yaml`](../../refs/falcosecurity/charts/charts/falco/Chart.yaml) |
