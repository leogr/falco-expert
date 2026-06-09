# Falco Operator

> Kubernetes Operator for Falco: instance lifecycle management, artifact distribution as native sidecar, 5 CRDs across 2 API groups, and reference protection.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco-operator/`](../refs/falcosecurity/falco-operator/)

## 1. Overview

The Falco Operator brings Kubernetes-native lifecycle management to Falco deployments through two complementary binaries and five Custom Resource Definitions (CRDs) across two API groups.

**Binaries:**

| Binary | Role | Runs As |
|--------|------|---------|
| `instance-operator` | Manages Falco deployment lifecycle and auxiliary components | Kubernetes Deployment |
| `artifact-operator` | Manages rules, plugins, and configuration per-node | Native sidecar in Falco pods |

**API Groups and CRDs:**

| API Group | CRD | Purpose |
|-----------|-----|---------|
| `instance.falcosecurity.dev/v1alpha1` | `Falco` | Falco instance (DaemonSet or Deployment) |
| `instance.falcosecurity.dev/v1alpha1` | `Component` | Auxiliary components (e.g., k8s-metacollector) |
| `artifact.falcosecurity.dev/v1alpha1` | `Rulesfile` | Rule distribution (OCI, inline, ConfigMap) |
| `artifact.falcosecurity.dev/v1alpha1` | `Plugin` | Plugin management (OCI) |
| `artifact.falcosecurity.dev/v1alpha1` | `Config` | Configuration fragments |

**Repository status:** Incubating
**License:** Apache-2.0

**Source:** [`README.md`](../refs/falcosecurity/falco-operator/README.md), [`digests/falcosecurity/falco-operator.md`](../digests/falcosecurity/falco-operator.md)

## 2. Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                    Instance Operator (Deployment)                    │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │ Falco Controller │  │ Component Ctrl   │  │ Reference Prot.  │  │
│  │ (Falco CRs)      │  │ (Component CRs)  │  │ (Secret/CM Ctrl) │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
└────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                     Falco Pod (per node)                             │
│  ┌─────────────────────┐  ┌────────────────────────────────────┐   │
│  │   Falco Container   │  │ Artifact Operator (Native Sidecar) │   │
│  │                     │  │  ┌────────────┐ ┌───────┐ ┌──────┐│   │
│  │  Loads rules,       │◄─│  │ Rulesfile  │ │Plugin │ │Config││   │
│  │  plugins, config    │  │  │ Controller │ │ Ctrl  │ │ Ctrl ││   │
│  │  from shared vols   │  │  └────────────┘ └───────┘ └──────┘│   │
│  └─────────────────────┘  └────────────────────────────────────┘   │
│                                                                     │
│  Shared volumes (emptyDir):                                         │
│    /etc/falco/config.d   /etc/falco/rules.d   /usr/share/falco/plugins│
└────────────────────────────────────────────────────────────────────┘
```

### Instance Operator

The instance operator runs as a standard Kubernetes Deployment and manages three controller types.

**Falco Controller** ([`controllers/instance/falco/controller.go`](../refs/falcosecurity/falco-operator/controllers/instance/falco/controller.go)) reconciles `Falco` CRs through:

1. Fetch Falco CR, handle deletion via finalizers (including cluster-scoped resources)
2. Resolve version and resource type, patch status via deferred call
3. Create RBAC resources (ServiceAccount, Role, RoleBinding, ClusterRole, ClusterRoleBinding)
4. Create a Service for pod discovery
5. Create a ConfigMap with base Falco configuration (mode-specific: DaemonSet or Deployment)
6. Clean up dual deployments (migration safety when switching modes)
7. Generate and apply DaemonSet or Deployment using Server-Side Apply (SSA) with managed fields diff detection

The managed fields comparison ([`controllerhelper.Diff`](../refs/falcosecurity/falco-operator/internal/pkg/controllerhelper/diff.go)) skips SSA patches when desired state matches existing resource, avoiding spurious `resourceVersion` bumps on Kubernetes < 1.31.

**Component Controller** ([`controllers/instance/component/controller.go`](../refs/falcosecurity/falco-operator/controllers/instance/component/controller.go)) follows the same pattern but always creates a Deployment (not DaemonSet), loads defaults from a type-specific registry ([`resources.GetDefaults`](../refs/falcosecurity/falco-operator/internal/pkg/resources/registry.go)), and currently supports the `metacollector` type.

**Reference Protection Controllers** protect referenced Kubernetes resources from premature deletion:

| Controller | Finalizer | Protects | Referenced By |
|------------|-----------|----------|---------------|
| Secret Controller | `artifact.falcosecurity.dev/secret-in-use` | Secrets | Rulesfile, Plugin (`spec.ociArtifact.registry.auth.secretRef`) |
| ConfigMap Controller | `artifact.falcosecurity.dev/configmap-in-use` | ConfigMaps | Rulesfile, Config (`spec.configMapRef`) |

**Source:** [`controllers/instance/reference/`](../refs/falcosecurity/falco-operator/controllers/instance/reference/), [`internal/pkg/common/finalizer.go`](../refs/falcosecurity/falco-operator/internal/pkg/common/finalizer.go)

### Artifact Operator

Runs as a native sidecar (Kubernetes 1.29+) in each Falco pod. Manages per-node artifact delivery through three controllers:

| Controller | Sources | Output Path |
|------------|---------|-------------|
| Rulesfile | OCI artifact, inline rules (JSON), ConfigMap, or combination | `/etc/falco/rules.d` |
| Plugin | OCI artifact (`.so` files) | `/usr/share/falco/plugins` |
| Config | Inline YAML, ConfigMap, or combination | `/etc/falco/config.d` |

All controllers support a priority system (0-99, default 50) for deterministic ordering and an optional `selector` (label selector) for node targeting.

**Source:** [`controllers/artifact/`](../refs/falcosecurity/falco-operator/controllers/artifact/), [`internal/pkg/mounts/consts.go`](../refs/falcosecurity/falco-operator/internal/pkg/mounts/consts.go)

## 3. Custom Resource Definitions

### Falco CRD

**API:** `instance.falcosecurity.dev/v1alpha1`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | *string | `DaemonSet` | Deployment mode: `DaemonSet` or `Deployment` |
| `replicas` | *int32 | 1 | Replica count (Deployment mode only) |
| `version` | *string | (auto) | Falco version to deploy |
| `podTemplateSpec` | *PodTemplateSpec | (defaults) | Custom pod template |
| `updateStrategy` | *DaemonSetUpdateStrategy | RollingUpdate | Update strategy (DaemonSet mode) |
| `strategy` | *DeploymentStrategy | RollingUpdate | Deployment strategy (Deployment mode) |

**Status fields:** `resourceType`, `version`, `desiredReplicas`, `availableReplicas`, `unavailableReplicas`, `conditions`

**Minimal example:**

```yaml
apiVersion: instance.falcosecurity.dev/v1alpha1
kind: Falco
metadata:
  name: falco
spec: {}  # Uses all defaults (DaemonSet mode, modern_ebpf)
```

**Source:** [`api/instance/v1alpha1/falco_types.go`](../refs/falcosecurity/falco-operator/api/instance/v1alpha1/falco_types.go)

### Component CRD

**API:** `instance.falcosecurity.dev/v1alpha1`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `component.type` | ComponentType | (required) | Component type: `metacollector` |
| `component.version` | *string | (bundled) | Component version |
| `replicas` | *int32 | 1 | Replica count |
| `podTemplateSpec` | *PodTemplateSpec | (defaults) | Custom pod template |
| `strategy` | *DeploymentStrategy | (default) | Deployment strategy |

**Source:** [`api/instance/v1alpha1/component_types.go`](../refs/falcosecurity/falco-operator/api/instance/v1alpha1/component_types.go)

### Rulesfile CRD

**API:** `artifact.falcosecurity.dev/v1alpha1`

Supports three source types that can be combined:

| Source | Field | Description |
|--------|-------|-------------|
| OCI artifact | `ociArtifact` | Pull from OCI registry via `image` (repository+tag) with optional `registry` config |
| Inline | `inlineRules` | Structured JSON rules embedded directly in the CR |
| ConfigMap | `configMapRef.name` | Reference a Kubernetes ConfigMap (key: `rules.yaml`) |

OCI artifact structure:

```yaml
ociArtifact:
  image:
    repository: falcosecurity/rules/falco-rules
    tag: latest
  registry:
    name: ghcr.io
    auth:
      secretRef:
        name: my-secret
    plainHTTP: false
    tls:
      insecureSkipVerify: false
```

Additional fields: `priority` (0-99, default 50), `selector` (label selector for node targeting)

**Status conditions:** `Programmed`, `ResolvedRefs`

**Source:** [`api/artifact/v1alpha1/rulesfile_types.go`](../refs/falcosecurity/falco-operator/api/artifact/v1alpha1/rulesfile_types.go), [`examples/artifact_v1alpha1_rulesfile_all.yaml`](../refs/falcosecurity/falco-operator/examples/artifact_v1alpha1_rulesfile_all.yaml)

### Plugin CRD

**API:** `artifact.falcosecurity.dev/v1alpha1`

| Field | Type | Description |
|-------|------|-------------|
| `ociArtifact` | OCIArtifact | Plugin binary from OCI registry |
| `config.name` | string | Plugin name (defaults to CRD name) |
| `config.libraryPath` | string | Path to `.so` (default: `/usr/share/falco/plugins/<name>.so`) |
| `config.initConfig` | JSON | Initialization parameters |
| `config.openParams` | string | Open parameters |
| `selector` | LabelSelector | Node targeting |

**Source:** [`api/artifact/v1alpha1/plugin_types.go`](../refs/falcosecurity/falco-operator/api/artifact/v1alpha1/plugin_types.go)

### Config CRD

**API:** `artifact.falcosecurity.dev/v1alpha1`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `config` | JSON | -- | Structured configuration fragment |
| `configMapRef` | ConfigMapRef | -- | Reference a ConfigMap (key: `config.yaml`) |
| `priority` | int32 | 50 | Application order (0-99) |
| `selector` | LabelSelector | -- | Node targeting |

**Source:** [`api/artifact/v1alpha1/config_types.go`](../refs/falcosecurity/falco-operator/api/artifact/v1alpha1/config_types.go)

## 4. Condition Types

All condition types are defined in [`api/common/v1alpha1/types.go`](../refs/falcosecurity/falco-operator/api/common/v1alpha1/types.go):

| CRD Type | Condition | Status Values | Description |
|----------|-----------|--------------|-------------|
| Instance (Falco, Component) | `Reconciled` | True/False/Unknown | Reconciliation of underlying resources |
| Instance (Falco, Component) | `Available` | True/Degraded/False/Unknown | Service readiness |
| Artifact (Rulesfile, Plugin, Config) | `Programmed` | True/False/Unknown | Artifact programmed into Falco |
| Artifact (Rulesfile, Plugin, Config) | `ResolvedRefs` | True/False | All references resolved |

Common ConfigMap/Secret keys: `rules.yaml`, `config.yaml`, `username`, `password`

## 5. Default Configuration

### DaemonSet Mode (default)

| Setting | Value |
|---------|-------|
| Engine | `modern_ebpf` |
| Container engines | CRI + Docker enabled |
| Outputs | stdout + syslog |
| Webserver | Port 8765 with Prometheus metrics |
| Security context | Privileged mode |
| Host mounts | `/proc`, `/sys`, `/dev`, `/etc`, container runtimes |
| Resources | Requests: 100m CPU, 512Mi; Limits: 1000m CPU, 1024Mi |
| Probes | Liveness (60s delay), Readiness (30s delay) on `/healthz:8765` |
| Tolerations | master + control-plane NoSchedule |
| Default image | `docker.io/falcosecurity/falco:0.41.0` |

**Source:** [`internal/pkg/resources/falco.go`](../refs/falcosecurity/falco-operator/internal/pkg/resources/falco.go)

### Deployment Mode

| Setting | Value |
|---------|-------|
| Engine | `nodriver` (plugin-only, no kernel instrumentation) |
| Container engines | All disabled |
| Designed for | Targeted analysis via plugins |

### Metacollector (Component)

| Setting | Value |
|---------|-------|
| Default image | `docker.io/falcosecurity/k8s-metacollector:0.1.1` |
| Ports | metrics (8080), health-probe (8081), broker-grpc (45000) |
| Resources | Requests: 100m CPU, 128Mi; Limits: 250m CPU, 256Mi |
| Security context | Non-root (UID 1000), drop ALL capabilities |

**Source:** [`internal/pkg/resources/metacollector.go`](../refs/falcosecurity/falco-operator/internal/pkg/resources/metacollector.go)

### Artifact Operator Sidecar

| Setting | Value |
|---------|-------|
| Image | `docker.io/falcosecurity/artifact-operator:latest` |
| Restart policy | `Always` (native sidecar) |
| Environment | `POD_NAMESPACE`, `NODE_NAME` via downward API |
| Probes | Readiness (5s delay), Liveness (15s delay) on `/healthz:8081` |

**Source:** [`internal/pkg/version/version.go`](../refs/falcosecurity/falco-operator/internal/pkg/version/version.go), [`internal/pkg/resources/falco.go:182-235`](../refs/falcosecurity/falco-operator/internal/pkg/resources/falco.go)

## 6. Installation

Single-manifest installation:

```bash
kubectl apply -f https://github.com/falcosecurity/falco-operator/releases/latest/download/install.yaml
```

Creates: 5 CRDs, `falco-operator` namespace, ServiceAccount, ClusterRole/Binding, and operator Deployment.

**Source:** [`README.md:97-133`](../refs/falcosecurity/falco-operator/README.md)

## 7. Implementation Details

| Aspect | Detail |
|--------|--------|
| Language | Go 1.26.0 |
| Framework | kubebuilder v4, controller-runtime 0.23.3 |
| K8s API | k8s.io/api v0.35.2 |
| OCI client | oras-go/v2 2.6.0 |
| Container base | `cgr.dev/chainguard/static` (non-root user 65532) |
| Architectures | linux/amd64, linux/arm64 |
| Testing | ginkgo/gomega, `make test` (unit), `make test-e2e` (Kind cluster) |

### Internal Packages

| Package | Purpose |
|---------|---------|
| [`internal/pkg/builders/`](../refs/falcosecurity/falco-operator/internal/pkg/builders/) | Fluent builders for Kubernetes resources |
| [`internal/pkg/resources/`](../refs/falcosecurity/falco-operator/internal/pkg/resources/) | Instance defaults registry, resource generators |
| [`internal/pkg/instance/`](../refs/falcosecurity/falco-operator/internal/pkg/instance/) | Shared instance controller logic |
| [`internal/pkg/artifact/`](../refs/falcosecurity/falco-operator/internal/pkg/artifact/) | Shared artifact controller logic |
| [`internal/pkg/controllerhelper/`](../refs/falcosecurity/falco-operator/internal/pkg/controllerhelper/) | SSA status patching, diff comparison, finalizers |
| [`internal/pkg/managedfields/`](../refs/falcosecurity/falco-operator/internal/pkg/managedfields/) | Managed fields comparison for SSA |
| [`internal/pkg/oci/`](../refs/falcosecurity/falco-operator/internal/pkg/oci/) | OCI client for artifact downloads |
| [`internal/pkg/index/`](../refs/falcosecurity/falco-operator/internal/pkg/index/) | Field index definitions for efficient lookups |

**Source:** [`go.mod`](../refs/falcosecurity/falco-operator/go.mod), [`Makefile`](../refs/falcosecurity/falco-operator/Makefile)

## 8. Related Specs

| Spec | Relationship |
|------|-------------|
| [`kubernetes-deployment.md`](kubernetes-deployment.md) | Helm-based Falco deployment (alternative to operator-based) |
| [`configuration.md`](configuration.md) | Falco configuration system (Config CRD generates config fragments) |
| [`plugin-system.md`](plugin-system.md) | Plugin API (Plugin CRD distributes plugin binaries) |
| [`rules-content.md`](rules-content.md) | Detection rules (Rulesfile CRD distributes rules) |
| [`falcoctl.md`](falcoctl.md) | Artifact management CLI (operator replaces falcoctl sidecar in operator-managed deployments) |

## 9. Sources

| Topic | Source |
|-------|--------|
| Overview and examples | [`README.md`](../refs/falcosecurity/falco-operator/README.md) |
| Falco CRD types | [`api/instance/v1alpha1/falco_types.go`](../refs/falcosecurity/falco-operator/api/instance/v1alpha1/falco_types.go) |
| Component CRD types | [`api/instance/v1alpha1/component_types.go`](../refs/falcosecurity/falco-operator/api/instance/v1alpha1/component_types.go) |
| Artifact CRD types | [`api/artifact/v1alpha1/`](../refs/falcosecurity/falco-operator/api/artifact/v1alpha1/) |
| Common types and conditions | [`api/common/v1alpha1/types.go`](../refs/falcosecurity/falco-operator/api/common/v1alpha1/types.go) |
| Falco controller | [`controllers/instance/falco/controller.go`](../refs/falcosecurity/falco-operator/controllers/instance/falco/controller.go) |
| Component controller | [`controllers/instance/component/controller.go`](../refs/falcosecurity/falco-operator/controllers/instance/component/controller.go) |
| Artifact controllers | [`controllers/artifact/`](../refs/falcosecurity/falco-operator/controllers/artifact/) |
| Instance defaults | [`internal/pkg/resources/`](../refs/falcosecurity/falco-operator/internal/pkg/resources/) |
| Sample manifests | [`examples/`](../refs/falcosecurity/falco-operator/examples/) |
| Digest | [`digests/falcosecurity/falco-operator.md`](../digests/falcosecurity/falco-operator.md) |
