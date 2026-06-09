# Falco Plugins Repository

**Era:** 0.44 | **Status:** Stable | **Scope:** Core

The [`plugins`](../../refs/falcosecurity/plugins/) repository is the central hub for the Falco Plugin ecosystem. It serves dual purposes:

1. **Registry**: A comprehensive catalog of all plugins recognized by The Falco Project (regardless of where their source code is hosted)
2. **Monorepo**: Official plugins hosted and maintained by The Falco Project with robust release and distribution processes

**Source:** [`README.md`](../../refs/falcosecurity/plugins/README.md)

## Table of Contents

- [Plugin Registry](#plugin-registry)
- [Key Plugins](#key-plugins)
  - [Container Plugin](#container-plugin-critical)
  - [K8smeta Plugin](#k8smeta-plugin)
  - [JSON Plugin](#json-plugin)
  - [K8saudit Plugin Family](#k8saudit-plugin-family)
- [Other Notable Plugins](#other-notable-plugins)
- [Build System](#build-system)
- [Release Process](#release-process)
- [CI/CD Workflows](#cicd-workflows)
- [OCI Artifact Distribution](#oci-artifact-distribution)
- [Sources](#sources)

---

## Plugin Registry

The registry ([`registry.yaml`](../../refs/falcosecurity/plugins/registry.yaml)) contains metadata about every plugin known to the falcosecurity organization, whether hosted in this repository or externally.

### Registry Structure

Each plugin entry contains:

| Field | Description |
|-------|-------------|
| `name` | Unique plugin name (must match `^[a-z]+[a-z0-9-_\-]*$`) |
| `description` | Brief plugin description |
| `authors` / `maintainers` | Plugin authors and maintainers |
| `url` | Link to plugin source code |
| `rules_url` | Link to default ruleset (if any) |
| `license` | SPDX license identifier |
| `keywords` | Search keywords |
| `signature` | Cosign signature configuration for OCI artifacts |
| `capabilities` | Plugin capabilities (sourcing, extraction) |

**Source:** [`docs/registering-a-plugin.md`](../../refs/falcosecurity/plugins/docs/registering-a-plugin.md)

### Reserved Sources

The following data sources are reserved and cannot be used by plugins:
- `syscall` - Used by Falco's syscall source
- `internal` - Used internally by Falco
- `plugins` - Reserved

**Source:** [`registry.yaml:29`](../../refs/falcosecurity/plugins/registry.yaml)

### Reserved Plugin IDs

| ID | Purpose |
|----|---------|
| `0` | Reserved for particular purposes (do not use) |
| `999` | Reserved for source plugin development/testing |

**ID Blocks:**

| Block | ID Range | Purpose |
|-------|----------|---------|
| Public | 0–1073741823 | Public registry assignments |
| Private | 1073741824–2147483647 | Private/internal plugins |
| Reserved | 2147483648–3221225471 | Future use |
| Internal | 3221225472–4294967295 | Plugin framework internal use |

**Source:** [`docs/plugin-ids.md`](../../refs/falcosecurity/plugins/docs/plugin-ids.md)

### Naming Constraints

- Plugin `name`: Must match `^[a-z]+[a-z0-9-_\-]*$` (avoid `_` unless necessary)
- Event `source`: Must match `^[a-z]+[a-z0-9_]*$`

---

## Key Plugins

### Container Plugin (Critical)

The `container` plugin is **shipped with Falco** and provides container metadata enrichment for syscall events.

> **Detailed Digest:** See [`plugins/container.md`](plugins/container.md) for architecture, design, and code implementation details.

| Property | Value |
|----------|-------|
| Type | Extraction (syscall source) |
| Language | C++ + Go |
| API Version | 3.10.0 |
| Falco Version | >= 0.41.0 |

**Capabilities:**
- `capture listening` - Attaches container_id to pre-existing threadinfos
- `extraction` - Extracts `container.*` and basic `k8s.*` fields
- `parsing` - Parses async and container events
- `async` - Generates container info events and cache dumps

**Architecture:**
- C++ shared object for plugin capabilities and container cache
- Go static library (worker) for container metadata retrieval using container runtime SDKs

**Supported Container Engines:**
| Engine | Default Socket(s) |
|--------|-------------------|
| Docker | `/var/run/docker.sock` |
| Podman | `/run/podman/podman.sock`, `/run/user/$uid/podman/podman.sock` |
| Containerd | `/run/host-containerd/containerd.sock` |
| CRI | `/run/containerd/containerd.sock`, `/run/crio/crio.sock`, `/run/k3s/containerd/containerd.sock` |
| LXC | Generic info only (ID + type) |
| libvirt_lxc | Generic info only (ID + type) |
| BPM | Generic info only (ID + type) |

**Key Fields Provided:**
- `container.id`, `container.full_id`, `container.name`
- `container.image`, `container.image.repository`, `container.image.tag`, `container.image.digest`
- `container.type`, `container.privileged`, `container.ip`
- `container.mounts`, `container.mount[...]`
- `container.host_pid`, `container.host_network`, `container.host_ipc`
- `container.labels`, `container.label[...]`
- `k8s.pod.name`, `k8s.ns.name`, `k8s.pod.uid`, `k8s.pod.sandbox_id`
- `k8s.pod.label[...]`, `k8s.pod.labels`

> **Note:** Many `k8s.*` fields (deployments, services, replica sets) are deprecated in the container plugin. Use the `k8smeta` plugin instead for those fields.

**Requirements:**
- containerd >= 1.7
- cri-o >= 1.26
- podman >= 4.0.0

**Source:** [`plugins/container/README.md`](../../refs/falcosecurity/plugins/plugins/container/README.md)

---

### K8smeta Plugin

The `k8smeta` plugin provides Kubernetes resource metadata enrichment beyond what the container plugin offers.

| Property | Value |
|----------|-------|
| Type | Extraction (syscall source) |
| Language | C++ |
| Falco Version | >= 0.40.0 |

**Capabilities:** extraction, parsing, async, capture listening

**Architecture:**
- Requires a remote collector: [`k8s-metacollector`](https://github.com/falcosecurity/k8s-metacollector)
- Node-level granularity (one plugin instance per node)
- Cluster-level collector (one collector per cluster)

**Configuration (Required):**
```yaml
plugins:
  - name: k8smeta
    library_path: libk8smeta.so
    init_config:
      collectorPort: 45000        # Required
      collectorHostname: localhost # Required
      nodeName: "${FALCO_K8S_NODE_NAME}" # Required - use Downward API in K8s
```

**Key Fields Provided:**
- `k8smeta.pod.name`, `k8smeta.pod.uid`, `k8smeta.pod.label[...]`, `k8smeta.pod.labels`
- `k8smeta.ns.name`, `k8smeta.ns.uid`, `k8smeta.ns.label[...]`
- `k8smeta.deployment.name`, `k8smeta.deployment.uid`, `k8smeta.deployment.label[...]`
- `k8smeta.svc.name` (list), `k8smeta.svc.uid` (list), `k8smeta.svc.label[...]`
- `k8smeta.rs.name`, `k8smeta.rs.uid`, `k8smeta.rs.label[...]`
- `k8smeta.rc.name`, `k8smeta.rc.uid`, `k8smeta.rc.label[...]`

**Source:** [`plugins/k8smeta/README.md`](../../refs/falcosecurity/plugins/plugins/k8smeta/README.md)

---

### JSON Plugin

The `json` plugin is a utility extraction plugin that can extract values from any JSON payload.

| Property | Value |
|----------|-------|
| Type | Extraction (all sources) |
| Language | Go |
| Falco Version | >= 0.32.0 |

**Use Cases:**
- Extract fields from k8s_audit events
- Extract fields from cloudtrail events
- Extract fields from any plugin that uses JSON payloads

**Fields:**
| Field | Description |
|-------|-------------|
| `json.value[<json pointer>]` | Extract value using JSON pointer (RFC 6901) |
| `json.obj` | Full JSON message as text |
| `json.rawtime` | Event time (identical to `evt.rawtime`) |
| `jevt.*` | Aliases for backwards compatibility |

**Example:**
```yaml
condition: json.value[/output_fields/container.id] == "host"
```

**Source:** [`plugins/json/README.md`](../../refs/falcosecurity/plugins/plugins/json/README.md)

---

### K8saudit Plugin Family

The k8saudit plugins enable Falco to monitor Kubernetes clusters via audit logs.

#### Base k8saudit Plugin

| Property | Value |
|----------|-------|
| Type | Source + Extraction |
| Source ID | 1 |
| Event Source | `k8s_audit` |
| Falco Version | >= 0.32.0 |

**Input Methods:**
- **Webhook**: Embedded HTTP/HTTPS server (production use)
- **File**: JSONL format (testing/development)

**Configuration:**
```yaml
plugins:
  - name: k8saudit
    library_path: libk8saudit.so
    init_config:
      sslCertificate: /etc/falco/falco.pem
    open_params: "http://:9765/k8s-audit"
  - name: json
    library_path: libjson.so

load_plugins: [k8saudit, json]
```

**Key Fields:**
- `ka.user.name`, `ka.user.groups`, `ka.verb`, `ka.uri`
- `ka.target.name`, `ka.target.namespace`, `ka.target.resource`
- `ka.req.pod.*` - Pod request details
- `ka.req.container.*` - Container request details
- `ka.response.code`, `ka.response.reason`
- `ka.sourceips`, `ka.useragent`

**Rules:** [`plugins/k8saudit/rules/k8s_audit_rules.yaml`](../../refs/falcosecurity/plugins/plugins/k8saudit/rules/k8s_audit_rules.yaml)

**Source:** [`plugins/k8saudit/README.md`](../../refs/falcosecurity/plugins/plugins/k8saudit/README.md)

#### Cloud Provider Variants

All variants share the same `k8s_audit` event source and the same rules from the base k8saudit plugin.

| Plugin | Source ID | Cloud Provider | Description |
|--------|-----------|----------------|-------------|
| `k8saudit-eks` | 9 | AWS | Read from AWS EKS clusters |
| `k8saudit-gke` | 16 | GCP | Read from GKE clusters |
| `k8saudit-aks` | 21 | Azure | Read from Azure AKS clusters |
| `k8saudit-ovh` | 22 | OVHcloud | Read from OVHcloud MKS clusters |

> **Note:** All cloud variants use `rules_url` pointing to [`plugins/k8saudit/rules/`](../../refs/falcosecurity/plugins/plugins/k8saudit/rules/) since they share the same ruleset.

---

## Other Notable Plugins

### Source Plugins

| Plugin | ID | Source | Description |
|--------|----|--------|-------------|
| `cloudtrail` | 2 | `aws_cloudtrail` | AWS CloudTrail JSON logs |
| `okta` | 7 | `okta` | Okta log events |
| `github` | 8 | `github` | GitHub webhook events |
| `gcpaudit` | 12 | `gcp_auditlog` | GCP Audit Logs |
| `kafka` | 18 | `kafka` | Events from Kafka topics |
| `collector` | 24 | `collector` | Generic HTTP payload ingestion |

### Extraction Plugins

| Plugin | Sources | Description |
|--------|---------|-------------|
| `krsi` | syscall | KRSI (Kernel Runtime Security Instrumentation) support |
| `anomalydetection` | syscall | Experimental anomaly detection with Count-Min Sketch |

### Reference Implementations

| Plugin | Language | Description |
|--------|----------|-------------|
| `dummy` | Go | Reference plugin documenting the interface |
| `dummy_c` | C++ | C++ reference implementation |
| `dummy_rs` | Rust | Rust reference implementation |

---

### KRSI Plugin

The `krsi` plugin enables Falco to receive data from the Kernel Runtime Security Instrumentation system.

**Key Features:**
- Inspects both syscall and io_uring activity
- Arguments collected directly from kernel (resilient against TOCTOU attacks)
- File path and network connection resolution in kernel

**Events:** `krsi_open`, `krsi_connect`, `krsi_socket`, `krsi_symlinkat`, `krsi_linkat`, `krsi_unlinkat`, `krsi_mkdirat`, `krsi_renameat`

**Source:** [`plugins/krsi/README.md`](../../refs/falcosecurity/plugins/plugins/krsi/README.md)

---

### Collector Plugin

The `collector` plugin is a generic source plugin that listens for HTTP POST requests and ingests raw payloads.

**Use Cases:**
- Ingest alerts from remote Falco instances
- Receive webhooks from external systems
- Use with `json` plugin for structured data extraction

**Configuration:**
```yaml
load_plugins: [collector, json]
plugins:
  - name: collector
    library_path: libcollector.so
  - name: json
    library_path: libjson.so
```

**Source:** [`plugins/collector/README.md`](../../refs/falcosecurity/plugins/plugins/collector/README.md)

---

## Build System

### Root Makefile

The root [`Makefile`](../../refs/falcosecurity/plugins/Makefile) provides targets for building all plugins:

| Target | Description |
|--------|-------------|
| `all` | Build all plugins |
| `<plugin-name>` | Build a specific plugin |
| `clean` | Clean all build artifacts |
| `packages` | Build distribution packages |
| `package/<plugin-name>` | Package a specific plugin |
| `check-registry` | Validate registry.yaml |
| `update-readme` | Update README with registry table |
| `changelogs` | Generate changelogs |

### Build Utilities (`build/`)

| Directory | Purpose |
|-----------|---------|
| `build/changelog/` | Changelog generation tool |
| `build/readme/` | README generation tool |
| `build/registry/` | Registry validation and table generation |
| `build/utils/` | Version extraction utility |

### Per-Plugin Build

Each plugin has its own build system:
- **Go plugins**: `go.mod`, standard Go build
- **C++ plugins**: `CMakeLists.txt` or `Makefile`
- **Rust plugins**: `Cargo.toml`

---

## Release Process

**Versioning:** Per-plugin versioning using git tags: `plugins/<name>/v<version>` (e.g., `plugins/cloudtrail/v1.2.3`)

**Build Types:**

| Type | Trigger | Artifacts |
|------|---------|-----------|
| Dev | Merge to `main` | download.falco.org (dev) |
| Stable | Git tag | download.falco.org (stable) + OCI (ghcr.io) |

**Note:** If a plugin provides a ruleset, the ruleset is released with the same version number.

**Source:** [`release.md`](../../refs/falcosecurity/plugins/release.md)

---

## CI/CD Workflows

| Workflow | Purpose |
|----------|---------|
| [`ci.yaml`](../../refs/falcosecurity/plugins/.github/workflows/ci.yaml) | Main CI pipeline |
| [`release.yml`](../../refs/falcosecurity/plugins/.github/workflows/release.yml) | Release automation |
| [`registry.yaml`](../../refs/falcosecurity/plugins/.github/workflows/registry.yaml) | Registry validation |
| [`main.yaml`](../../refs/falcosecurity/plugins/.github/workflows/main.yaml) | Dev builds on merge |
| [`reusable-publish-oci-artifacts.yaml`](../../refs/falcosecurity/plugins/.github/workflows/reusable-publish-oci-artifacts.yaml) | OCI artifact publishing |
| [`reusable_build_packages.yaml`](../../refs/falcosecurity/plugins/.github/workflows/reusable_build_packages.yaml) | Package building |
| [`reusable_validate_plugins.yaml`](../../refs/falcosecurity/plugins/.github/workflows/reusable_validate_plugins.yaml) | Plugin validation |
| [`container-ci.yaml`](../../refs/falcosecurity/plugins/.github/workflows/container-ci.yaml) | Container plugin CI |
| [`k8smeta-ci.yaml`](../../refs/falcosecurity/plugins/.github/workflows/k8smeta-ci.yaml) | K8smeta plugin CI |
| [`dummy_c-ci.yaml`](../../refs/falcosecurity/plugins/.github/workflows/dummy_c-ci.yaml) | Dummy C++ plugin CI |

---

## OCI Artifact Distribution

Plugins are published as OCI artifacts to `ghcr.io/falcosecurity/plugins/`.

**Installation:**
```bash
falcoctl index update falcosecurity
falcoctl artifact install <plugin-name>
```

**Signature Verification:**
All official plugins are signed with cosign using GitHub OIDC:
```yaml
signature:
  cosign:
    certificate-oidc-issuer: https://token.actions.githubusercontent.com
    certificate-identity-regexp: https://github.com/falcosecurity/plugins/
```

**Helm Chart Integration:**
```yaml
falcoctl:
  config:
    artifact:
      install:
        refs:
          - k8saudit:latest
```

---

## Sources

| Topic | Source File |
|-------|-------------|
| Repository overview | [`README.md`](../../refs/falcosecurity/plugins/README.md) |
| Plugin registry | [`registry.yaml`](../../refs/falcosecurity/plugins/registry.yaml) |
| Registration guide | [`docs/registering-a-plugin.md`](../../refs/falcosecurity/plugins/docs/registering-a-plugin.md) |
| Plugin IDs | [`docs/plugin-ids.md`](../../refs/falcosecurity/plugins/docs/plugin-ids.md) |
| Release process | [`release.md`](../../refs/falcosecurity/plugins/release.md) |
| Build system | [`Makefile`](../../refs/falcosecurity/plugins/Makefile) |
| Container plugin | [`plugins/container/README.md`](../../refs/falcosecurity/plugins/plugins/container/README.md) |
| K8smeta plugin | [`plugins/k8smeta/README.md`](../../refs/falcosecurity/plugins/plugins/k8smeta/README.md) |
| JSON plugin | [`plugins/json/README.md`](../../refs/falcosecurity/plugins/plugins/json/README.md) |
| K8saudit plugin | [`plugins/k8saudit/README.md`](../../refs/falcosecurity/plugins/plugins/k8saudit/README.md) |
| K8saudit rules | [`plugins/k8saudit/rules/`](../../refs/falcosecurity/plugins/plugins/k8saudit/rules/) |
| KRSI plugin | [`plugins/krsi/README.md`](../../refs/falcosecurity/plugins/plugins/krsi/README.md) |
| Collector plugin | [`plugins/collector/README.md`](../../refs/falcosecurity/plugins/plugins/collector/README.md) |
| Anomaly detection | [`plugins/anomalydetection/README.md`](../../refs/falcosecurity/plugins/plugins/anomalydetection/README.md) |
