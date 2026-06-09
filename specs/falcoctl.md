# falcoctl

> Artifact and driver management CLI tool: OCI artifact distribution, driver installation, registry operations, index system, and Kubernetes integration.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falcoctl/`](../refs/falcosecurity/falcoctl/)

## Overview

Falcoctl is a Go-based CLI tool for managing Falco artifacts and drivers. It serves as the primary interface for:

1. **Artifact management** -- Search, install, and continuously follow rules, plugins, and assets from OCI-compliant registries
2. **Driver management** -- Install, configure, and clean up kernel drivers (kmod, ebpf, modern_ebpf)
3. **Registry operations** -- Push, pull, and authenticate with OCI registries using multiple auth methods
4. **Index management** -- Configure artifact indexes that map simple names to OCI registry locations

Falcoctl is built with [Cobra](https://github.com/spf13/cobra) for command structure and uses standard OCI distribution protocols for artifact management.

**Source:** [`cmd/root.go`](../refs/falcosecurity/falcoctl/cmd/root.go), [`digests/falcosecurity/falcoctl.md`](../digests/falcosecurity/falcoctl.md)

## Architecture

### Command Groups

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          falcoctl CLI                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │   artifact  │  │    index    │  │   registry  │  │   driver    │    │
│  │   commands  │  │   commands  │  │   commands  │  │   commands  │    │
│  ├─────────────┤  ├─────────────┤  ├─────────────┤  ├─────────────┤    │
│  │ • install   │  │ • add       │  │ • auth      │  │ • install   │    │
│  │ • follow    │  │ • remove    │  │   (basic/   │  │ • config    │    │
│  │ • search    │  │ • list      │  │    oauth/   │  │ • cleanup   │    │
│  │ • info      │  │ • update    │  │    gcp)     │  │ • printenv  │    │
│  │ • list      │  │             │  │ • push      │  │             │    │
│  │ • manifest  │  │             │  │ • pull      │  │             │    │
│  │ • config    │  │             │  │             │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                                          │
│  ┌─────────────┐  ┌─────────────┐                                       │
│  │     tls     │  │   version   │                                       │
│  ├─────────────┤  └─────────────┘                                       │
│  │ • install   │                                                         │
│  └─────────────┘                                                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Source:** [`cmd/root.go:67-72`](../refs/falcosecurity/falcoctl/cmd/root.go)

### Package Structure

| Package | Purpose |
|---------|---------|
| [`cmd/`](../refs/falcosecurity/falcoctl/cmd/) | CLI command implementations (Cobra commands) |
| [`pkg/oci/`](../refs/falcosecurity/falcoctl/pkg/oci/) | OCI registry operations, media types, artifact config |
| [`pkg/index/`](../refs/falcosecurity/falcoctl/pkg/index/) | Index management and lookup |
| [`pkg/driver/`](../refs/falcosecurity/falcoctl/pkg/driver/) | Driver type handling and operations |
| [`pkg/artifact/`](../refs/falcosecurity/falcoctl/pkg/artifact/) | Artifact reference parsing |
| [`internal/follower/`](../refs/falcosecurity/falcoctl/internal/follower/) | Follow daemon logic |
| [`internal/config/`](../refs/falcosecurity/falcoctl/internal/config/) | Configuration handling |
| [`internal/signature/`](../refs/falcosecurity/falcoctl/internal/signature/) | Signature verification (Sigstore/Cosign) |

## Implementation Details

### OCI Artifact Distribution

Falcoctl uses OCI-compliant registries (GHCR, Docker Hub, Google Artifact Registry, etc.) to distribute Falco artifacts. This provides versioning, multi-architecture support, and compatibility with standard container tooling.

**Source:** [`proposals/20220916-rules-and-plugin-distribution.md`](../refs/falcosecurity/falcoctl/proposals/20220916-rules-and-plugin-distribution.md)

#### Artifact Types

| Type | Layer Media Type | Config Media Type | Description |
|------|-----------------|-------------------|-------------|
| `rulesfile` | `application/vnd.cncf.falco.rulesfile.layer.v1+tar.gz` | `application/vnd.cncf.falco.rulesfile.config.v1+json` | Falco detection rules (YAML) |
| `plugin` | `application/vnd.cncf.falco.plugin.layer.v1+tar.gz` | `application/vnd.cncf.falco.plugin.config.v1+json` | Falco plugins (shared libraries) |
| `asset` | `application/vnd.cncf.falco.asset.layer.v1+tar.gz` | `application/vnd.cncf.falco.asset.config.v1+json` | Assets consumed by plugins |

**Source:** [`pkg/oci/constants.go:18-40`](../refs/falcosecurity/falcoctl/pkg/oci/constants.go), [`pkg/oci/types.go:28-38`](../refs/falcosecurity/falcoctl/pkg/oci/types.go)

#### ArtifactConfig Structure

Each OCI artifact has a config layer containing metadata used for dependency resolution and version compatibility:

```go
// pkg/oci/types.go:143-149
type ArtifactConfig struct {
    Name         string                `json:"name,omitempty"`        // Unique name in index
    Version      string                `json:"version,omitempty"`     // Semver version
    Dependencies []ArtifactDependency  `json:"dependencies,omitempty"` // Required artifacts
    Requirements []ArtifactRequirement `json:"requirements,omitempty"` // Falco version requirements
}
```

`ArtifactDependency` supports alternative dependencies (parsed from `"name:version|alt1:version1|..."` format):

```go
// pkg/oci/types.go:203-207
type ArtifactDependency struct {
    Name         string       `json:"name"`
    Version      string       `json:"version"`
    Alternatives []Dependency `json:"alternatives,omitempty"`
}
```

**Source:** [`pkg/oci/types.go:143-272`](../refs/falcosecurity/falcoctl/pkg/oci/types.go)

#### Reference Formats

Artifacts can be referenced in multiple ways:

| Format | Example | Description |
|--------|---------|-------------|
| Simple name | `cloudtrail` | Resolved via index, defaults to `latest` tag |
| Name with tag | `cloudtrail:0.6.0` | Resolved via index, specific version |
| Full OCI reference | `ghcr.io/falcosecurity/plugins/plugin/cloudtrail:latest` | Direct registry access |
| With digest | `ghcr.io/.../cloudtrail@sha256:abc...` | Immutable reference |

When no tag is provided, the default tag is `latest`.

**Source:** [`README.md:261-272`](../refs/falcosecurity/falcoctl/README.md), [`pkg/oci/constants.go:39`](../refs/falcosecurity/falcoctl/pkg/oci/constants.go)

### Index System

An index is a YAML file that maps artifact names to their OCI registry locations, allowing users to reference artifacts by simple names instead of full OCI references.

#### Index File Structure

```yaml
- name: k8saudit
  type: plugin
  registry: ghcr.io
  repository: falcosecurity/plugins/plugin/k8saudit
  description: Kubernetes Audit Events
  home: https://github.com/falcosecurity/plugins/tree/master/plugins/k8saudit
  keywords:
    - audit
    - kubernetes
  license: Apache-2.0
  maintainers:
    - name: The Falco Authors
      email: cncf-falco-dev@lists.cncf.io
```

**Source:** [`README.md:176-212`](../refs/falcosecurity/falcoctl/README.md)

#### Storage Backends

| Backend | URI Scheme | Description |
|---------|------------|-------------|
| HTTP/HTTPS | `https://` | Default backend, simple HTTP GET |
| GCS | `gs://` | Google Cloud Storage |
| S3 | `s3://` | AWS S3 |
| File | `file://` | Local filesystem |

**Source:** [`README.md:216-224`](../refs/falcosecurity/falcoctl/README.md)

#### Default Index

The official falcosecurity index URL:
```
https://falcosecurity.github.io/falcoctl/index.yaml
```

Add it with:
```bash
falcoctl index add falcosecurity https://falcosecurity.github.io/falcoctl/index.yaml
```

### Artifact Commands

#### `artifact install`

Downloads and installs artifacts to local directories.

**Source:** [`cmd/artifact/install/install.go`](../refs/falcosecurity/falcoctl/cmd/artifact/install/install.go)

**Default directories:**

| Artifact Type | Default Directory |
|---------------|-------------------|
| Plugins | `/usr/share/falco/plugins` |
| Rules files | `/etc/falco` |
| Assets | `/etc/falco/assets` |

**Key flags:**

| Flag | Description |
|------|-------------|
| `--plugins-dir` | Directory for plugins |
| `--rulesfiles-dir` | Directory for rules |
| `--assets-dir` | Directory for assets |
| `--state-dir` | Directory for artifact state |
| `--platform` | OS/Arch (default: current system) |
| `--resolve-deps` | Resolve dependencies (default: `true`) |
| `--no-verify` | Skip signature verification |

**Dependency resolution:** When multiple versions of the same artifact are specified, falcoctl keeps only the highest version. Dependencies declared in the artifact config layer are automatically resolved and installed.

#### `artifact follow`

Runs as a daemon that periodically checks for artifact updates and installs new versions.

**Source:** [`cmd/artifact/follow/follow.go`](../refs/falcosecurity/falcoctl/cmd/artifact/follow/follow.go), [`internal/follower/follower.go`](../refs/falcosecurity/falcoctl/internal/follower/follower.go)

**Key flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `--every` | `6h` (standalone), `168h` (Kubernetes) | Check interval |
| `--cron` | - | Cron expression for check interval |
| `--startup-behavior` | `jitter` | Behavior at startup |
| `--falco-versions` | `http://localhost:8765/versions` | URL to Falco versions endpoint |

**Startup behaviors:**

| Behavior | Description |
|----------|-------------|
| `skip` | First check happens on first scheduled interval |
| `jitter` | Random delay (0 to interval) before first check |
| `immediate` | Check immediately at startup |

**Integration with Falco:** The follower queries Falco's `/versions` endpoint to check artifact requirements (engine version, rules file version) against the running Falco version before installing. This prevents installing incompatible artifacts.

#### `artifact search`

Search for artifacts in configured indexes by name or keywords.

```bash
$ falcoctl artifact search kubernetes
INDEX           ARTIFACT        TYPE            REGISTRY        REPOSITORY
falcosecurity   k8saudit        plugin          ghcr.io         falcosecurity/plugins/plugin/k8saudit
falcosecurity   k8saudit-rules  rulesfile       ghcr.io         falcosecurity/plugins/ruleset/k8saudit
```

#### `artifact info`

Display available tags for an artifact.

```bash
$ falcoctl artifact info k8saudit
REF                                             TAGS
ghcr.io/falcosecurity/plugins/plugin/k8saudit   0.1.0 0.2.0 0.3.0 0.4.0 latest
```

#### `artifact list`

List installed artifacts.

#### `artifact manifest`

Display the OCI manifest for an artifact.

#### `artifact config`

Display the artifact config layer.

### Driver Commands

Driver commands manage the kernel driver used by Falco to capture system events. They replace the legacy `falco-driver-loader` shell script.

**Source:** [`cmd/driver/`](../refs/falcosecurity/falcoctl/cmd/driver/)

#### Driver Types

| Type | Constant | Extension | HasArtifacts | Description |
|------|----------|-----------|--------------|-------------|
| `kmod` | `TypeKmod` | `.ko` | Yes | Kernel module, broadest compatibility (>= 3.10) |
| `ebpf` | `TypeBpf` | `.o` | Yes | Classic eBPF probe (deprecated in favor of modern_ebpf) |
| `modern_ebpf` | `TypeModernBpf` | - | No | CO-RE eBPF, embedded in Falco binary (>= 5.8 with BTF) |

The `DriverType` interface defines the contract for all driver types:

```go
// pkg/driver/type/type.go:34-42
type DriverType interface {
    fmt.Stringer
    Cleanup(printer *output.Printer, driverName string) error
    Load(printer *output.Printer, src, driverName string, fallback bool) error
    Extension() string
    HasArtifacts() bool
    ToOutput(destPath string) cmd.OutputOptions
    Supported(kr kernelrelease.KernelRelease) bool
}
```

**Source:** [`pkg/driver/type/type.go`](../refs/falcosecurity/falcoctl/pkg/driver/type/type.go), [`pkg/driver/type/consts.go`](../refs/falcosecurity/falcoctl/pkg/driver/type/consts.go)

#### `driver config`

Configures the driver type for Falco.

**Source:** [`cmd/driver/config/config.go`](../refs/falcosecurity/falcoctl/cmd/driver/config/config.go)

```bash
falcoctl driver config --type modern_ebpf
```

**Behavior:**
1. Checks if Falco is configured to use a driver (`engine.kind` in `falco.yaml`)
2. If yes, writes driver type to `/etc/falco/config.d/engine-kind-falcoctl.yaml`
3. Stores configuration in the falcoctl config file

**Kubernetes ConfigMap support:** When running in a cluster, can update ConfigMaps directly:
```bash
falcoctl driver config --namespace falco --configmap falco
```

#### `driver install`

Downloads or builds the kernel driver.

**Source:** [`cmd/driver/install/install.go`](../refs/falcosecurity/falcoctl/cmd/driver/install/install.go)

```bash
falcoctl driver install [--download] [--compile]
```

**Process (sequential):**
1. **Clean** -- Remove existing driver artifacts
2. **Download** -- Try to download prebuilt driver from configured repositories
3. **Compile** -- If download fails and `--compile` is enabled, build locally using kernel headers
4. **Load** -- Load the driver (`insmod` for kmod; no-op for modern_ebpf since it is embedded in Falco)

#### `driver cleanup`

Removes existing driver artifacts.

**For kmod:**
1. Tries `rmmod` to unload the kernel module
2. Uses `dkms` to remove DKMS-installed versions

#### `driver printenv`

Prints driver configuration as environment variables, useful for debugging and scripting.

### Registry Commands

#### Authentication

Falcoctl supports multiple authentication methods for OCI registries:

**Source:** [`cmd/registry/auth/`](../refs/falcosecurity/falcoctl/cmd/registry/auth/)

| Method | Command | Description |
|--------|---------|-------------|
| Basic | `falcoctl registry auth basic <registry>` | Username/password authentication |
| OAuth2 | `falcoctl registry auth oauth <registry>` | Client credentials flow |
| GCP | `falcoctl registry auth gcp <registry>` | Application Default Credentials |

```bash
# Basic authentication
falcoctl registry auth basic <registry> --username <user> --password <pass>

# OAuth2 client credentials
falcoctl registry auth oauth <registry> --client-id <id> --client-secret <secret> --token-url <url>

# GCP Application Default Credentials
falcoctl registry auth gcp <registry>
```

#### `registry push`

Push artifacts to an OCI registry.

```bash
falcoctl registry push \
  --type rulesfile \
  --version "1.0.0" \
  --depends-on "k8saudit:0.6" \
  ghcr.io/myorg/myrules:1.0.0 \
  myrules.tar.gz
```

**Key flags:**

| Flag | Description |
|------|-------------|
| `--type` | Artifact type (`rulesfile`, `plugin`, `asset`) |
| `--version` | Semver version (required) |
| `--depends-on` | Dependencies (can be repeated, format: `name:version`) |
| `--platform` | Platform for plugins (e.g., `linux/amd64`) |
| `--add-floating-tags` | Create major/minor floating tags (e.g., `1.0.0` also creates `1.0` and `1`) |

#### `registry pull`

Pull artifacts from an OCI registry.

```bash
falcoctl registry pull ghcr.io/falcosecurity/plugins/plugin/cloudtrail:latest
```

### Configuration

#### Configuration File

Default location: `/etc/falcoctl/falcoctl.yaml`

**Source:** [`README.md:111-156`](../refs/falcosecurity/falcoctl/README.md)

```yaml
artifact:
  install:
    refs:
      - falco-rules:5
      - ghcr.io/falcosecurity/plugins/plugin/container:0.7.1
    rulesfilesdir: /etc/falco
    pluginsdir: /usr/share/falco/plugins
    resolveDeps: true
  follow:
    every: 168h
    falcoVersions: http://localhost:8765/versions
    refs:
      - falco-rules:5
    rulesfilesDir: /rulesfiles
    pluginsDir: /plugins
    stateDir: /artifactstate

indexes:
  - name: falcosecurity
    url: https://falcosecurity.github.io/falcoctl/index.yaml

registry:
  auth:
    basic:
      - registry: myregistry.example.com
        user: user
        password: password
    gcp:
      - registry: europe-docker.pkg.dev
```

#### Environment Variables

All configuration can be set via environment variables:

| Variable | Description |
|----------|-------------|
| `FALCOCTL_INDEXES` | Index configuration |
| `FALCOCTL_ARTIFACT_INSTALL_REFS` | Artifacts to install |
| `FALCOCTL_ARTIFACT_FOLLOW_REFS` | Artifacts to follow |
| `FALCOCTL_ARTIFACT_FOLLOW_EVERY` | Follow interval |
| `FALCOCTL_REGISTRY_AUTH_BASIC` | Basic auth credentials |
| `FALCOCTL_REGISTRY_AUTH_OAUTH` | OAuth2 credentials |
| `FALCOCTL_REGISTRY_AUTH_GCP` | GCP registries |

**Source:** [`README.md:462-491`](../refs/falcosecurity/falcoctl/README.md)

#### Configuration Priority

Configuration values are resolved in this order (highest priority first):

1. **CLI flags** -- Explicitly passed on the command line
2. **Environment variables** -- `FALCOCTL_*` prefixed variables
3. **Config file** -- Values from `/etc/falcoctl/falcoctl.yaml`

### Kubernetes Integration

Falcoctl is integral to Falco's Kubernetes deployment via the Helm chart. It runs as both init containers and sidecars, sharing artifacts with the Falco container through emptyDir volumes.

**Sources:**
- [`charts/falco/values.yaml:550-638`](../refs/falcosecurity/charts/charts/falco/values.yaml) - falcoctl configuration
- [`charts/falco/templates/_helpers.tpl:255-315`](../refs/falcosecurity/charts/charts/falco/templates/_helpers.tpl) - container templates
- [`charts/falco/templates/falcoctl-configmap.yaml`](../refs/falcosecurity/charts/charts/falco/templates/falcoctl-configmap.yaml) - ConfigMap template

#### Container Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Falco Pod                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  INIT CONTAINERS (sequential):                                               │
│  ┌─────────────────────────┐    ┌──────────────────────────────────────────┐│
│  │ falco-driver-loader     │    │ falcoctl-artifact-install                ││
│  │ (if driver.enabled)     │ →  │ (if falcoctl.artifact.install.enabled)  ││
│  │                         │    │                                          ││
│  │ - Downloads/builds      │    │ - Runs: artifact install                 ││
│  │   kernel driver         │    │ - Downloads rules & plugins from OCI     ││
│  │ - Writes to config.d    │    │ - Writes to emptyDir volumes             ││
│  └─────────────────────────┘    └──────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────────────────┤
│  RUNTIME CONTAINERS (parallel):                                              │
│  ┌─────────────────────────┐    ┌──────────────────────────────────────────┐│
│  │ falco                   │    │ falcoctl-artifact-follow                 ││
│  │                         │    │ (if falcoctl.artifact.follow.enabled)    ││
│  │ - Main Falco process    │    │                                          ││
│  │ - Loads rules & plugins │    │ - Runs: artifact follow                  ││
│  │   from shared volumes   │    │ - Periodically checks for updates        ││
│  │ - Exposes /versions     │ <- │ - Queries Falco /versions for compat     ││
│  │   endpoint on :8765     │    │ - Downloads new versions to shared vols  ││
│  └─────────────────────────┘    └──────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

The `falco-driver-loader` init container is separate from `falcoctl-artifact-install` because it requires different privileges (privileged mode) and access to host kernel files (`/boot`, `/lib/modules`, `/usr`). For `modern_ebpf`, it only writes config since the driver is embedded in Falco.

#### Shared Volumes (emptyDir)

| Volume | Purpose | Mounted In |
|--------|---------|------------|
| `rulesfiles-install-dir` | Downloaded rules files | falcoctl-install, falco, falcoctl-follow |
| `plugins-install-dir` | Downloaded plugins | falcoctl-install, falco, falcoctl-follow |
| `artifact-state-dir` | Artifact state (digests) | falcoctl-install, falcoctl-follow |

The state directory (`/artifactstate`) persists artifact digests between the init container and sidecar, preventing re-downloads of already-installed artifacts.

#### Version Compatibility Check

The `falcoctl-artifact-follow` sidecar queries Falco's `/versions` endpoint before installing updates:

```yaml
follow:
  falcoversions: http://localhost:8765/versions
```

Falco exposes version info at `http://localhost:8765/versions`:
```json
{
  "falco_version": "0.44.0",
  "libs_version": "0.25.2",
  "plugin_api_version": "3.6.0",
  "driver_api_version": "9.1.0",
  "driver_schema_version": "2.0.0",
  "default_driver_version": "10.2.0+driver",
  "engine_version": "62",
  "engine_version_semver": "0.62.0",
  "plugin_versions": {}
}
```

The `engine_version` field contains only the MINOR component as a string (kept for backward compatibility with existing tooling, including falcoctl's matching of old rules artifacts configs). The `engine_version_semver` field contains the full semver representation. Plugin versions are populated when plugins are loaded.

**Source:** [`versions_info.cpp:65-83`](../refs/falcosecurity/falco/userspace/falco/versions_info.cpp), [`versions_info.h:33-57`](../refs/falcosecurity/falco/userspace/falco/versions_info.h), [`falco_engine_version.h`](../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h)

Falcoctl checks artifact requirements against these versions to ensure compatibility before installing or updating artifacts.

#### Helm Values Structure

```yaml
falcoctl:
  image:
    repository: falcosecurity/falcoctl
    tag: "0.13.0"
  artifact:
    install:
      enabled: true              # Run as init container
      args: ["--log-format=json"]
    follow:
      enabled: true              # Run as sidecar
      args: ["--log-format=json"]
  config:
    indexes:
      - name: falcosecurity
        url: https://falcosecurity.github.io/falcoctl/index.yaml
    artifact:
      allowedTypes: [rulesfile, plugin]
      install:
        refs: [falco-rules:5]    # Artifacts to install at startup
        resolveDeps: true
        rulesfilesDir: /rulesfiles
        pluginsDir: /plugins
        stateDir: /artifactstate
      follow:
        refs: [falco-rules:5]    # Artifacts to watch for updates
        every: 168h              # Check interval (1 week)
        falcoversions: http://localhost:8765/versions
        rulesfilesDir: /rulesfiles
        pluginsDir: /plugins
        stateDir: /artifactstate
```

**Customization examples:**

Install different rules (e.g., with incubating rules):
```bash
helm install falco falcosecurity/falco \
  --set "falcoctl.config.artifact.install.refs={falco-rules:5,falco-incubating-rules:5}" \
  --set "falcoctl.config.artifact.follow.refs={falco-rules:5,falco-incubating-rules:5}"
```

Install plugins for K8s audit:
```bash
helm install falco falcosecurity/falco \
  -f values-k8saudit.yaml  # Sets refs to [k8saudit-rules:0.16, k8saudit:0.16]
```

Disable automatic updates (install only, no follow sidecar):
```bash
helm install falco falcosecurity/falco \
  --set falcoctl.artifact.follow.enabled=false
```

### Signature Verification

Falcoctl supports artifact signature verification using Sigstore/Cosign.

**Index signature configuration:**
```yaml
signature:
  cosign:
    certificate-oidc-issuer: https://token.actions.githubusercontent.com
    certificate-identity-regexp: https://github.com/falcosecurity/
```

**Skip verification:**
```bash
falcoctl artifact install --no-verify <artifact>
```

**Image verification (falcoctl container images are also signed):**
```bash
cosign verify docker.io/falcosecurity/falcoctl:0.13.0 \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp=https://github.com/falcosecurity/falcoctl/
```

**Source:** [`internal/signature/`](../refs/falcosecurity/falcoctl/internal/signature/)

### TLS Commands (Removed)

The `tls install` command (previously under `cmd/tls/`) generated and installed TLS certificates for securing Falco's gRPC server and other TLS-enabled endpoints. It was removed in a recent falcoctl release; certificate provisioning now falls outside falcoctl's scope.

**Source:** Historical only; the `cmd/tls/` package no longer exists in falcoctl.

## Non-Functional Requirements

- **OCI Compliance**: All artifact distribution uses standard OCI distribution protocols, enabling compatibility with any OCI-compliant registry (GHCR, Docker Hub, Google Artifact Registry, Amazon ECR, Azure ACR, Harbor, etc.)
- **Container Registry Compatibility**: Uses standard OCI media types (`application/vnd.cncf.falco.*`) allowing registries to store Falco artifacts alongside container images
- **Platform Support**: Multi-architecture artifact support via OCI platform manifests (e.g., `linux/amd64`, `linux/arm64`)
- **Dependency Resolution**: Automatic transitive dependency resolution with highest-version-wins conflict strategy
- **Signature Verification**: Sigstore/Cosign-based supply chain security for artifact integrity
- **Idempotent State**: State directory tracking prevents redundant downloads across init container and sidecar restarts

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`configuration.md`](configuration.md) | Falco configuration system (engine.kind, config.d directory used by driver config) |
| [`plugin-system.md`](plugin-system.md) | Plugin API and capabilities (plugins distributed via falcoctl OCI artifacts) |
| [`build-system.md`](build-system.md) | Build system for Falco and libs (driver compilation path) |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Kernel driver types managed by falcoctl driver commands |
| [`architecture-overview.md`](architecture-overview.md) | Falco application architecture (versions endpoint, event sources) |

## Sources

| Topic | Source File |
|-------|-------------|
| Repository README | [`README.md`](../refs/falcosecurity/falcoctl/README.md) |
| Command structure | [`cmd/root.go`](../refs/falcosecurity/falcoctl/cmd/root.go) |
| Artifact install command | [`cmd/artifact/install/install.go`](../refs/falcosecurity/falcoctl/cmd/artifact/install/install.go) |
| Artifact follow command | [`cmd/artifact/follow/follow.go`](../refs/falcosecurity/falcoctl/cmd/artifact/follow/follow.go) |
| Follower logic | [`internal/follower/follower.go`](../refs/falcosecurity/falcoctl/internal/follower/follower.go) |
| Driver commands | [`cmd/driver/`](../refs/falcosecurity/falcoctl/cmd/driver/) |
| Driver config command | [`cmd/driver/config/config.go`](../refs/falcosecurity/falcoctl/cmd/driver/config/config.go) |
| Driver install command | [`cmd/driver/install/install.go`](../refs/falcosecurity/falcoctl/cmd/driver/install/install.go) |
| Driver type interface | [`pkg/driver/type/type.go`](../refs/falcosecurity/falcoctl/pkg/driver/type/type.go) |
| Driver type constants | [`pkg/driver/type/consts.go`](../refs/falcosecurity/falcoctl/pkg/driver/type/consts.go) |
| OCI constants | [`pkg/oci/constants.go`](../refs/falcosecurity/falcoctl/pkg/oci/constants.go) |
| OCI types | [`pkg/oci/types.go`](../refs/falcosecurity/falcoctl/pkg/oci/types.go) |
| Registry auth commands | [`cmd/registry/auth/`](../refs/falcosecurity/falcoctl/cmd/registry/auth/) |
| Signature verification | [`internal/signature/`](../refs/falcosecurity/falcoctl/internal/signature/) |
| OCI distribution proposal | [`proposals/20220916-rules-and-plugin-distribution.md`](../refs/falcosecurity/falcoctl/proposals/20220916-rules-and-plugin-distribution.md) |
| Helm chart values | [`charts/falco/values.yaml`](../refs/falcosecurity/charts/charts/falco/values.yaml) |
| Helm chart helpers | [`charts/falco/templates/_helpers.tpl`](../refs/falcosecurity/charts/charts/falco/templates/_helpers.tpl) |
| Falcoctl ConfigMap template | [`charts/falco/templates/falcoctl-configmap.yaml`](../refs/falcosecurity/charts/charts/falco/templates/falcoctl-configmap.yaml) |
| Digest | [`digests/falcosecurity/falcoctl.md`](../digests/falcosecurity/falcoctl.md) |
