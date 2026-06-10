# Falco Operator - AI Digest

Kubernetes Operator for managing Falco deployments, auxiliary components, and runtime artifacts (rules, plugins, configuration).

**Applicable to**: Falco 0.44 era
**Repository status**: Incubating
**License**: Apache-2.0
**Pinned version**: v0.2.2 (the 0.44.0 release announces operator 0.3.0 + a new `falco-operator` Helm chart 0.2.0; the [`refs/`](../../refs/) submodule is pinned one patch behind at v0.2.2)

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [Instance Operator](#instance-operator)
  - [Artifact Operator](#artifact-operator)
  - [Reference Protection Controllers](#reference-protection-controllers)
- [Custom Resource Definitions](#custom-resource-definitions)
  - [Falco CRD](#falco-crd)
  - [Component CRD](#component-crd)
  - [Rulesfile CRD](#rulesfile-crd)
  - [Plugin CRD](#plugin-crd)
  - [Config CRD](#config-crd)
- [Condition Types](#condition-types)
- [Default Configuration](#default-configuration)
- [Installation](#installation)
- [Build and Development](#build-and-development)
- [Sources](#sources)

---

## Overview

The Falco Operator brings Kubernetes-native lifecycle management to Falco deployments. It consists of two complementary binaries and five CRDs across two API groups ([README.md:19-69](../../refs/falcosecurity/falco-operator/README.md)):

1. **Instance Operator** (`instance-operator` binary) — Manages Falco deployment lifecycle and auxiliary components (e.g., k8s-metacollector) via `instance.falcosecurity.dev/v1alpha1` CRDs
2. **Artifact Operator** (`artifact-operator` binary) — Manages rules, plugins, and configuration fragments via `artifact.falcosecurity.dev/v1alpha1` CRDs; runs as a sidecar in Falco pods

The five CRDs:
- `falcos.instance.falcosecurity.dev` — Falco instances
- `components.instance.falcosecurity.dev` — Auxiliary components (e.g., k8s-metacollector)
- `rulesfiles.artifact.falcosecurity.dev` — Rule distribution
- `plugins.artifact.falcosecurity.dev` — Plugin management
- `configs.artifact.falcosecurity.dev` — Configuration fragments

**Source:** [README.md](../../refs/falcosecurity/falco-operator/README.md)

---

## Architecture

### Instance Operator

The instance operator runs as a Kubernetes Deployment and manages multiple controller types:

#### Falco Controller

The Falco controller ([controllers/instance/falco/controller.go](../../refs/falcosecurity/falco-operator/controllers/instance/falco/controller.go)) reconciles `Falco` CRs through these steps:

1. Fetch the Falco CR
2. Handle deletion (cleanup via finalizers, including cluster-scoped resources)
3. Resolve version and resource type, patch status via deferred call
4. Create RBAC resources (ServiceAccount, Role, RoleBinding, ClusterRole, ClusterRoleBinding)
5. Create a Service for pod discovery
6. Create a ConfigMap with base Falco configuration (mode-specific: DaemonSet or Deployment)
7. Cleanup dual deployments (migration safety when switching between DaemonSet/Deployment)
8. Set finalizer for graceful deletion
9. Generate and apply the DaemonSet or Deployment using Server-Side Apply (SSA) with managed fields diff detection to avoid unnecessary API writes

The controller uses a managed fields comparison ([`controllerhelper.Diff`](../../refs/falcosecurity/falco-operator/internal/pkg/controllerhelper/diff.go)) to skip SSA patches when the desired state matches the existing resource, which avoids spurious `resourceVersion` bumps on Kubernetes < 1.31 ([controller.go:273-274](../../refs/falcosecurity/falco-operator/controllers/instance/falco/controller.go)).

The controller emits Kubernetes events for resource creation, updates, errors, dual deployment cleanup, and availability state changes ([controller.go:309-333](../../refs/falcosecurity/falco-operator/controllers/instance/falco/controller.go)).

#### Component Controller

The Component controller ([controllers/instance/component/controller.go](../../refs/falcosecurity/falco-operator/controllers/instance/component/controller.go)) reconciles `Component` CRs for auxiliary components. It follows the same pattern as the Falco controller but:

- Loads defaults from a type-specific registry ([`resources.GetDefaults`](../../refs/falcosecurity/falco-operator/internal/pkg/resources/registry.go)) — currently supports `metacollector` type
- Always creates a Deployment (not DaemonSet)
- Creates ServiceAccount, ClusterRole, ClusterRoleBinding, and Service
- Does not create a ConfigMap or Role/RoleBinding

#### Reference Protection Controllers

Two controllers protect referenced Kubernetes resources from premature deletion:

**Secret Controller** ([controllers/instance/reference/secret/controller.go](../../refs/falcosecurity/falco-operator/controllers/instance/reference/secret/controller.go)):
- Places a `artifact.falcosecurity.dev/secret-in-use` finalizer on Secrets referenced by Rulesfile or Plugin CRs via `spec.ociArtifact.registry.auth.secretRef`
- Watches Rulesfile and Plugin resources to detect reference changes
- Blocks Secret deletion while still referenced

**ConfigMap Controller** ([controllers/instance/reference/configmap/controller.go](../../refs/falcosecurity/falco-operator/controllers/instance/reference/configmap/controller.go)):
- Places a `artifact.falcosecurity.dev/configmap-in-use` finalizer on ConfigMaps referenced by Rulesfile or Config CRs via `spec.configMapRef`
- Watches Rulesfile and Config resources to detect reference changes
- Blocks ConfigMap deletion while still referenced

**Source:** [common/finalizer.go](../../refs/falcosecurity/falco-operator/internal/pkg/common/finalizer.go)

### Artifact Operator

Runs as a **native sidecar** (Kubernetes 1.29+ feature) in each Falco pod. It manages per-node artifact delivery through three controllers ([controllers/artifact/](../../refs/falcosecurity/falco-operator/controllers/artifact/)):

- **Rulesfile Controller** — Downloads OCI rule artifacts, resolves inline rules (structured JSON), reads ConfigMaps, or combines all three; stores to filesystem with priority ordering
- **Plugin Controller** — Downloads plugin `.so` files from OCI registries; manages plugin configuration
- **Config Controller** — Writes YAML configuration fragments to filesystem with priority ordering; supports both inline config and ConfigMapRef

Artifacts are shared between the sidecar and the Falco container via `emptyDir` volumes at three mount paths ([mounts/consts.go](../../refs/falcosecurity/falco-operator/internal/pkg/mounts/consts.go)):
- `/etc/falco/config.d` — Configuration fragments
- `/etc/falco/rules.d` — Rules files
- `/usr/share/falco/plugins` — Plugins

**Source:** [controllers/artifact/rulesfile/controller.go](../../refs/falcosecurity/falco-operator/controllers/artifact/rulesfile/controller.go), [controllers/artifact/config/controller.go](../../refs/falcosecurity/falco-operator/controllers/artifact/config/controller.go)

---

## Custom Resource Definitions

### Falco CRD

**API**: `instance.falcosecurity.dev/v1alpha1`

Manages a Falco instance in the cluster ([falco_types.go](../../refs/falcosecurity/falco-operator/api/instance/v1alpha1/falco_types.go)).

**Spec fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type` | *string | `DaemonSet` | Deployment mode: `DaemonSet` or `Deployment` |
| `replicas` | *int32 | 1 | Number of replicas (Deployment mode only) |
| `version` | *string | (auto) | Falco version to deploy |
| `podTemplateSpec` | *PodTemplateSpec | (defaults) | Custom pod template for overriding defaults |
| `updateStrategy` | *DaemonSetUpdateStrategy | RollingUpdate | Update strategy (DaemonSet mode only) |
| `strategy` | *DeploymentStrategy | RollingUpdate | Deployment strategy (Deployment mode only) |

**Status fields:**

| Field | Type | Description |
|-------|------|-------------|
| `resourceType` | string | Resolved Kubernetes resource type (Deployment or DaemonSet) |
| `version` | string | Resolved Falco version being deployed |
| `desiredReplicas` | int32 | Desired number of instances |
| `availableReplicas` | int32 | Number of available (ready) pods |
| `unavailableReplicas` | int32 | Number of unavailable pods |
| `conditions` | []Condition | Reconciled and Available conditions |

**Print columns**: Type, Version, Desired, Ready, Reconciled, Available, Age

**Minimal example:**

```yaml
apiVersion: instance.falcosecurity.dev/v1alpha1
kind: Falco
metadata:
  name: falco
spec: {}  # Uses all defaults (DaemonSet mode, modern_ebpf)
```

### Component CRD

**API**: `instance.falcosecurity.dev/v1alpha1`

Manages auxiliary components (e.g., k8s-metacollector) as Deployments ([component_types.go](../../refs/falcosecurity/falco-operator/api/instance/v1alpha1/component_types.go)).

**Spec fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `component.type` | ComponentType | (required) | Component type: currently `metacollector` |
| `component.version` | *string | (bundled) | Component version; defaults to operator-bundled version |
| `replicas` | *int32 | 1 | Number of replicas |
| `podTemplateSpec` | *PodTemplateSpec | (defaults) | Custom pod template |
| `strategy` | *DeploymentStrategy | (default) | Deployment strategy |

**Status fields** mirror `FalcoStatus` (resourceType, version, desiredReplicas, availableReplicas, unavailableReplicas, conditions).

**Print columns**: Type, ResourceType, Version, Desired, Ready, Reconciled, Available, Age

**Example:**

```yaml
apiVersion: instance.falcosecurity.dev/v1alpha1
kind: Component
metadata:
  name: metacollector
spec:
  component:
    type: metacollector
    version: "0.1.2"
  replicas: 1
```

**Source:** [examples/instance_v1alpha1_component.yaml](../../refs/falcosecurity/falco-operator/examples/instance_v1alpha1_component.yaml)

### Rulesfile CRD

**API**: `artifact.falcosecurity.dev/v1alpha1`

Manages Falco rules distribution ([rulesfile_types.go](../../refs/falcosecurity/falco-operator/api/artifact/v1alpha1/rulesfile_types.go)). Supports three source types that can be combined:

| Source | Field | Description |
|--------|-------|-------------|
| OCI artifact | `ociArtifact` | Pull from OCI registry via `image` (repository+tag) with optional `registry` config |
| Inline | `inlineRules` | Structured JSON rules embedded directly in the CR |
| ConfigMap | `configMapRef.name` | Reference a Kubernetes ConfigMap (key: `rules.yaml`) |

**OCI Artifact structure** (restructured API):

```yaml
ociArtifact:
  image:
    repository: falcosecurity/rules/falco-rules  # OCI repository path
    tag: latest                                    # Image tag (default: latest)
  registry:                                        # Optional inline registry config
    name: ghcr.io                                  # Registry hostname
    auth:
      secretRef:
        name: my-secret                            # Secret with username/password keys
    plainHTTP: false                               # Use plain HTTP (mutually exclusive with tls)
    tls:
      insecureSkipVerify: false                    # Skip TLS verification
```

**Priority system**: Values 0-99 (default: 50) for deterministic ordering.
**Node targeting**: Optional `selector` field (label selector) to target specific nodes.

**Status conditions**: `Programmed` (whether the artifact was successfully programmed into Falco)

**Example combining all three sources:**

```yaml
apiVersion: artifact.falcosecurity.dev/v1alpha1
kind: Rulesfile
metadata:
  name: rulesfile-all
spec:
  ociArtifact:
    image:
      repository: falcosecurity/rules/falco-rules
      tag: latest
    registry:
      name: ghcr.io
  configMapRef:
    name: custom-falco-rules
  inlineRules:
    - rule: Terminal shell in container
      desc: A shell was used as the entrypoint/exec point into a container.
      condition: >
        spawned_process and container and shell_procs and proc.tty != 0
      output: >
        A shell was spawned in a container (user=%user.name %container.info)
      priority: NOTICE
      tags: [container, shell, mitre_execution]
  priority: 50
```

**Source:** [examples/artifact_v1alpha1_rulesfile_all.yaml](../../refs/falcosecurity/falco-operator/examples/artifact_v1alpha1_rulesfile_all.yaml)

### Plugin CRD

**API**: `artifact.falcosecurity.dev/v1alpha1`

Manages Falco plugins ([plugin_types.go](../../refs/falcosecurity/falco-operator/api/artifact/v1alpha1/plugin_types.go)).

| Field | Type | Description |
|-------|------|-------------|
| `ociArtifact` | OCIArtifact | Plugin binary from OCI registry (same structure as Rulesfile) |
| `config.name` | string | Plugin name (defaults to CRD name if omitted) |
| `config.libraryPath` | string | Path to `.so` (default: `/usr/share/falco/plugins/<name>.so`) |
| `config.initConfig` | JSON | Initialization parameters (structured JSON, supports nested config) |
| `config.openParams` | string | Open parameters |
| `selector` | LabelSelector | Node targeting |

**Status conditions**: `Programmed`

```yaml
apiVersion: artifact.falcosecurity.dev/v1alpha1
kind: Plugin
metadata:
  name: container
spec:
  ociArtifact:
    image:
      repository: falcosecurity/plugins/plugin/container
      tag: "0.7.1"
    registry:
      name: ghcr.io
  config:
    initConfig:
      label_max_len: "100"
```

### Config CRD

**API**: `artifact.falcosecurity.dev/v1alpha1`

Manages Falco configuration fragments ([config_types.go](../../refs/falcosecurity/falco-operator/api/artifact/v1alpha1/config_types.go)). Supports two source types that can be combined:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `config` | JSON | -- | Structured configuration fragment (JSON object) |
| `configMapRef` | ConfigMapRef | -- | Reference a ConfigMap (key: `config.yaml`) |
| `priority` | int32 | 50 | Application order (0-99) |
| `selector` | LabelSelector | -- | Node targeting |

**Status conditions**: `Programmed`

**Example with both inline and ConfigMapRef:**

```yaml
apiVersion: artifact.falcosecurity.dev/v1alpha1
kind: Config
metadata:
  name: config-both
spec:
  config:
    engine:
      kind: modern_ebpf
      modern_ebpf:
        buf_size_preset: 4
        cpus_for_each_buffer: 2
  configMapRef:
    name: falco-config-base
  priority: 50
```

**Source:** [examples/artifact_v1alpha1_config_both.yaml](../../refs/falcosecurity/falco-operator/examples/artifact_v1alpha1_config_both.yaml)

---

## Condition Types

All condition types are defined in [api/common/v1alpha1/types.go](../../refs/falcosecurity/falco-operator/api/common/v1alpha1/types.go):

### Instance CRDs (Falco, Component)

| Condition | Status Values | Description |
|-----------|--------------|-------------|
| `Reconciled` | True/False/Unknown | Whether reconciliation of the underlying resources succeeded |
| `Available` | True/Degraded/False/Unknown | Service readiness (True=all ready, Degraded=partial, False=none) |

### Artifact CRDs (Rulesfile, Plugin, Config)

| Condition | Status Values | Description |
|-----------|--------------|-------------|
| `Programmed` | True/False/Unknown | Whether the artifact was successfully programmed into Falco |
| `ResolvedRefs` | True/False | Whether all references (ConfigMaps, Secrets) were resolved |

**Common ConfigMap/Secret keys** ([types.go:57-69](../../refs/falcosecurity/falco-operator/api/common/v1alpha1/types.go)):
- `ConfigMapRulesKey` = `rules.yaml`
- `ConfigMapConfigKey` = `config.yaml`
- `SecretUsernameKey` = `username`
- `SecretPasswordKey` = `password`

---

## Default Configuration

The operator applies type-specific defaults via the `InstanceDefaults` registry ([resources/types.go](../../refs/falcosecurity/falco-operator/internal/pkg/resources/types.go), [resources/registry.go](../../refs/falcosecurity/falco-operator/internal/pkg/resources/registry.go)).

### Falco DaemonSet Mode (default)

| Setting | Value |
|---------|-------|
| Engine | `modern_ebpf` (full syscall monitoring) |
| Container engines | CRI + Docker enabled |
| Outputs | stdout + syslog |
| Webserver | Enabled on port 8765 with Prometheus metrics |
| Security context | Privileged mode |
| Host mounts | `/proc`, `/sys`, `/dev`, `/etc`, container runtimes |
| Resources | Requests: 100m CPU, 512Mi memory; Limits: 1000m CPU, 1024Mi memory |
| Probes | Liveness (60s delay), Readiness (30s delay) on `/healthz:8765` |
| Tolerations | master + control-plane NoSchedule |
| Update strategy | RollingUpdate |
| Default Falco image | `docker.io/falcosecurity/falco:0.43.0` (pinned v0.2.2 default; announced operator 0.3.0 bumps this to `0.44.0`) |

**Source:** [resources/falco.go](../../refs/falcosecurity/falco-operator/internal/pkg/resources/falco.go), [`image/const.go:28`](../../refs/falcosecurity/falco-operator/internal/pkg/image/const.go)

### Falco Deployment Mode

| Setting | Value |
|---------|-------|
| Engine | `nodriver` (plugin-only, no kernel instrumentation) |
| Container engines | All disabled |
| Designed for | Targeted analysis via plugins |

### Metacollector (Component)

| Setting | Value |
|---------|-------|
| Resource type | Deployment only |
| Container | `meta-collector` command |
| Default image | `docker.io/falcosecurity/k8s-metacollector:0.1.2` |
| Ports | metrics (8080), health-probe (8081), broker-grpc (45000) |
| Resources | Requests: 100m CPU, 128Mi; Limits: 250m CPU, 256Mi |
| Security context | Non-root (UID 1000), drop ALL capabilities |
| RBAC | ClusterRole with read access to apps, core, and discovery resources |

**Source:** [resources/metacollector.go](../../refs/falcosecurity/falco-operator/internal/pkg/resources/metacollector.go), [image/const.go](../../refs/falcosecurity/falco-operator/internal/pkg/image/const.go)

### Artifact Operator Sidecar

- Image: `docker.io/falcosecurity/artifact-operator:latest` (configurable at build time via ldflags)
- Native sidecar with `restartPolicy: Always`
- Receives `POD_NAMESPACE` and `NODE_NAME` via downward API
- Readiness probe (5s delay) + Liveness probe (15s delay) on `/healthz:8081`
- Shared `emptyDir` volumes for config, rulesfiles, and plugins

**Source:** [version/version.go](../../refs/falcosecurity/falco-operator/internal/pkg/version/version.go), [resources/falco.go:182-235](../../refs/falcosecurity/falco-operator/internal/pkg/resources/falco.go)

---

## Installation

Single-manifest installation from the latest GitHub release ([README.md:97-133](../../refs/falcosecurity/falco-operator/README.md)):

```bash
kubectl apply -f https://github.com/falcosecurity/falco-operator/releases/latest/download/install.yaml
```

This creates: 5 CRDs, the `falco-operator` namespace, ServiceAccount, ClusterRole/Binding, and the operator Deployment.

### Required Permissions

| API Group | Resources | Permissions |
|-----------|-----------|-------------|
| `""` (core) | pods, nodes, configmaps, secrets, serviceaccounts, services, events | get, list, watch, create, update, delete, patch |
| `apps` | daemonsets, deployments, replicasets | get, list, watch, create, update, delete, patch |
| `rbac.authorization.k8s.io` | roles, rolebindings, clusterroles, clusterrolebindings | get, list, watch, create, update, delete, patch |
| `events.k8s.io` | events | create, patch, update |
| `instance.falcosecurity.dev` | falcos, falcos/status, components, components/status | create, delete, get, list, patch, update, watch |
| `artifact.falcosecurity.dev` | configs, plugins, rulesfiles (+ /status) | create, delete, get, list, patch, update, watch |
| `discovery.k8s.io` | endpointslices | get, list, watch |

**Source:** [controllers/instance/falco/controller.go:79-90](../../refs/falcosecurity/falco-operator/controllers/instance/falco/controller.go), [controllers/instance/component/controller.go:75-78](../../refs/falcosecurity/falco-operator/controllers/instance/component/controller.go)

---

## Build and Development

| Aspect | Detail |
|--------|--------|
| Language | Go 1.26.0 |
| Framework | kubebuilder v4, controller-runtime 0.24.0 |
| K8s API | k8s.io/api v0.36.0 |
| OCI client | oras-go/v2 2.6.0 |
| Container base | `cgr.dev/chainguard/static` (non-root user 65532) |
| Architectures | linux/amd64, linux/arm64 |
| Binaries | `instance-operator` (instance controllers), `artifact-operator` (sidecar) |
| Testing | ginkgo/gomega, `make test` (unit), `make test-e2e` (Kind cluster) |
| Linting | golangci-lint |
| Approvers | [@alacuku](https://github.com/alacuku), [@leogr](https://github.com/leogr), [@FedeDP](https://github.com/FedeDP), [@c2ndev](https://github.com/c2ndev) |

### Internal Package Structure

| Package | Purpose |
|---------|---------|
| [`internal/pkg/builders/`](../../refs/falcosecurity/falco-operator/internal/pkg/builders/) | Fluent builders for generating Kubernetes resources (DaemonSet, Deployment, ConfigMap, RBAC, etc.) |
| [`internal/pkg/resources/`](../../refs/falcosecurity/falco-operator/internal/pkg/resources/) | Instance defaults registry (`InstanceDefaults`), resource generators, and overlays |
| [`internal/pkg/instance/`](../../refs/falcosecurity/falco-operator/internal/pkg/instance/) | Shared instance controller logic (availability, conditions, ensure, merge, version resolution) |
| [`internal/pkg/artifact/`](../../refs/falcosecurity/falco-operator/internal/pkg/artifact/) | Shared artifact controller logic (conditions, events, registry client, types) |
| [`internal/pkg/controllerhelper/`](../../refs/falcosecurity/falco-operator/internal/pkg/controllerhelper/) | Controller utilities (SSA status patching, diff comparison, finalizer management, node helpers) |
| [`internal/pkg/managedfields/`](../../refs/falcosecurity/falco-operator/internal/pkg/managedfields/) | Managed fields comparison for SSA (compare, extract, prune, schema) |
| [`internal/pkg/common/`](../../refs/falcosecurity/falco-operator/internal/pkg/common/) | Shared constants, condition constructors, finalizer names, sidecar helpers |
| [`internal/pkg/oci/`](../../refs/falcosecurity/falco-operator/internal/pkg/oci/) | OCI client and puller for artifact downloads |
| [`internal/pkg/index/`](../../refs/falcosecurity/falco-operator/internal/pkg/index/) | Field index definitions for efficient lookups (Secret/ConfigMap references) |

**Source:** [go.mod](../../refs/falcosecurity/falco-operator/go.mod), [Makefile](../../refs/falcosecurity/falco-operator/Makefile), [OWNERS](../../refs/falcosecurity/falco-operator/OWNERS)

---

## Sources

| Topic | Source File |
|-------|-------------|
| Overview and examples | [README.md](../../refs/falcosecurity/falco-operator/README.md) |
| Falco CRD types | [api/instance/v1alpha1/falco_types.go](../../refs/falcosecurity/falco-operator/api/instance/v1alpha1/falco_types.go) |
| Component CRD types | [api/instance/v1alpha1/component_types.go](../../refs/falcosecurity/falco-operator/api/instance/v1alpha1/component_types.go) |
| Artifact CRD types | [api/artifact/v1alpha1/](../../refs/falcosecurity/falco-operator/api/artifact/v1alpha1/) |
| Common types and conditions | [api/common/v1alpha1/types.go](../../refs/falcosecurity/falco-operator/api/common/v1alpha1/types.go) |
| Falco controller | [controllers/instance/falco/controller.go](../../refs/falcosecurity/falco-operator/controllers/instance/falco/controller.go) |
| Component controller | [controllers/instance/component/controller.go](../../refs/falcosecurity/falco-operator/controllers/instance/component/controller.go) |
| Secret protection controller | [controllers/instance/reference/secret/controller.go](../../refs/falcosecurity/falco-operator/controllers/instance/reference/secret/controller.go) |
| ConfigMap protection controller | [controllers/instance/reference/configmap/controller.go](../../refs/falcosecurity/falco-operator/controllers/instance/reference/configmap/controller.go) |
| Artifact controllers | [controllers/artifact/](../../refs/falcosecurity/falco-operator/controllers/artifact/) |
| Instance defaults (Falco) | [internal/pkg/resources/falco.go](../../refs/falcosecurity/falco-operator/internal/pkg/resources/falco.go) |
| Instance defaults (Metacollector) | [internal/pkg/resources/metacollector.go](../../refs/falcosecurity/falco-operator/internal/pkg/resources/metacollector.go) |
| Defaults registry | [internal/pkg/resources/registry.go](../../refs/falcosecurity/falco-operator/internal/pkg/resources/registry.go) |
| Instance defaults type | [internal/pkg/resources/types.go](../../refs/falcosecurity/falco-operator/internal/pkg/resources/types.go) |
| Image constants | [internal/pkg/image/const.go](../../refs/falcosecurity/falco-operator/internal/pkg/image/const.go) |
| Mount paths | [internal/pkg/mounts/consts.go](../../refs/falcosecurity/falco-operator/internal/pkg/mounts/consts.go) |
| Finalizer constants | [internal/pkg/common/finalizer.go](../../refs/falcosecurity/falco-operator/internal/pkg/common/finalizer.go) |
| Version and build info | [internal/pkg/version/version.go](../../refs/falcosecurity/falco-operator/internal/pkg/version/version.go) |
| Build system | [Makefile](../../refs/falcosecurity/falco-operator/Makefile) |
| Dependencies | [go.mod](../../refs/falcosecurity/falco-operator/go.mod) |
| Sample manifests | [examples/](../../refs/falcosecurity/falco-operator/examples/) |

---

*Last updated: 2026-03-12*
