# falcosecurity/falcoctl Digest

**Repository:** https://github.com/falcosecurity/falcoctl
**Era:** 0.44
**Status:** Core / Stable

The official CLI tool for working with Falco and its ecosystem components. Manages artifacts (rules, plugins, assets) via OCI registries and handles driver installation/configuration.

## Overview

Falcoctl is a Go-based CLI tool that provides:
1. **Artifact management** - Search, install, and follow rules and plugins from OCI registries
2. **Driver management** - Install and configure kernel drivers (kmod, ebpf, modern_ebpf)
3. **Registry operations** - Push, pull, and authenticate with OCI registries
4. **Index management** - Configure artifact indexes for discovery

## Architecture

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

**Source:** [`cmd/root.go`](../../refs/falcosecurity/falcoctl/cmd/root.go)

## OCI Artifact Distribution

Falcoctl uses OCI-compliant registries (like GHCR, Docker Hub, Artifact Registry) to distribute Falco artifacts. This enables versioning, multi-architecture support, and standard container tooling.

**Source:** [`proposals/20220916-rules-and-plugin-distribution.md`](../../refs/falcosecurity/falcoctl/proposals/20220916-rules-and-plugin-distribution.md)

### Artifact Types

| Type | Media Type | Description |
|------|------------|-------------|
| `rulesfile` | `application/vnd.cncf.falco.rulesfile.layer.v1+tar.gz` | Falco detection rules (YAML) |
| `plugin` | `application/vnd.cncf.falco.plugin.layer.v1+tar.gz` | Falco plugins (shared libraries) |
| `asset` | `application/vnd.cncf.falco.asset.layer.v1+tar.gz` | Assets consumed by plugins |

**Source:** [`pkg/oci/constants.go`](../../refs/falcosecurity/falcoctl/pkg/oci/constants.go), [`pkg/oci/types.go`](../../refs/falcosecurity/falcoctl/pkg/oci/types.go)

### Artifact Config Layer

Each artifact has a config layer with metadata:

```go
type ArtifactConfig struct {
    Name         string                `json:"name,omitempty"`        // Unique name in index
    Version      string                `json:"version,omitempty"`     // Semver version
    Dependencies []ArtifactDependency  `json:"dependencies,omitempty"` // Required artifacts
    Requirements []ArtifactRequirement `json:"requirements,omitempty"` // Falco version requirements
}
```

**Source:** [`pkg/oci/types.go:143-149`](../../refs/falcosecurity/falcoctl/pkg/oci/types.go)

### Reference Formats

| Format | Example | Description |
|--------|---------|-------------|
| Simple name | `cloudtrail` | Uses index for lookup, defaults to `latest` tag |
| Name with tag | `cloudtrail:0.6.0` | Uses index, specific version |
| Full OCI reference | `ghcr.io/falcosecurity/plugins/plugin/cloudtrail:latest` | Direct registry access |
| With digest | `ghcr.io/.../cloudtrail@sha256:abc...` | Immutable reference |

**Source:** [`README.md:261-272`](../../refs/falcosecurity/falcoctl/README.md)

## Index System

An index is a YAML file that maps artifact names to their OCI registry locations. This allows users to reference artifacts by simple names instead of full OCI references.

### Index File Structure

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

**Source:** [`README.md:176-212`](../../refs/falcosecurity/falcoctl/README.md)

### Index Storage Backends

| Backend | URI Scheme | Description |
|---------|------------|-------------|
| HTTP/HTTPS | `https://` | Default, simple HTTP GET |
| GCS | `gs://` | Google Cloud Storage |
| S3 | `s3://` | AWS S3 |
| File | `file://` | Local filesystem |

**Source:** [`README.md:216-224`](../../refs/falcosecurity/falcoctl/README.md)

### Default Index

The official falcosecurity index:
```bash
falcoctl index add falcosecurity https://falcosecurity.github.io/falcoctl/index.yaml
```

## Artifact Commands

### `artifact install`

Downloads and installs artifacts to local directories.

**Source:** [`cmd/artifact/install/install.go`](../../refs/falcosecurity/falcoctl/cmd/artifact/install/install.go)

**Default directories:**
- Plugins: `/usr/share/falco/plugins`
- Rules files: `/etc/falco`
- Assets: `/etc/falco/assets`

**Key flags:**
```
--plugins-dir        Directory for plugins
--rulesfiles-dir     Directory for rules
--assets-dir         Directory for assets
--state-dir          Directory for artifact state
--platform           OS/Arch (default: current system)
--resolve-deps       Resolve dependencies (default: true)
--no-verify          Skip signature verification
```

**Dependency resolution:** When multiple versions of the same artifact are specified, falcoctl keeps only the highest version. Dependencies are automatically resolved and installed.

### `artifact follow`

Runs as a daemon that periodically checks for artifact updates and installs new versions.

**Source:** [`cmd/artifact/follow/follow.go`](../../refs/falcosecurity/falcoctl/cmd/artifact/follow/follow.go), [`internal/follower/follower.go`](../../refs/falcosecurity/falcoctl/internal/follower/follower.go)

**Key flags:**
```
--every              Check interval (default: 6h, or 168h in Kubernetes deployment)
--cron               Cron expression for check interval
--startup-behavior   Behavior at startup: skip|jitter|immediate (default: jitter)
--falco-versions     URL to Falco versions endpoint (default: http://localhost:8765/versions)
```

**Startup behaviors:**
| Behavior | Description |
|----------|-------------|
| `skip` | First check happens on first scheduled interval |
| `jitter` | Random delay (0 to interval) before first check |
| `immediate` | Check immediately at startup |

**Integration with Falco:** The follower queries Falco's `/versions` endpoint to check artifact requirements against the running Falco version before installing.

### `artifact search`

Search for artifacts in configured indexes by name or keywords.

```bash
$ falcoctl artifact search kubernetes
INDEX           ARTIFACT        TYPE            REGISTRY        REPOSITORY
falcosecurity   k8saudit        plugin          ghcr.io         falcosecurity/plugins/plugin/k8saudit
falcosecurity   k8saudit-rules  rulesfile       ghcr.io         falcosecurity/plugins/ruleset/k8saudit
```

### `artifact info`

Display available tags for an artifact.

```bash
$ falcoctl artifact info k8saudit
REF                                             TAGS
ghcr.io/falcosecurity/plugins/plugin/k8saudit   0.1.0 0.2.0 0.3.0 0.4.0 latest
```

## Driver Commands

Falcoctl includes driver management commands that replace the legacy `falco-driver-loader` shell script.

**Source:** [`cmd/driver/`](../../refs/falcosecurity/falcoctl/cmd/driver/)

### Driver Types

| Type | Extension | HasArtifacts | Description |
|------|-----------|--------------|-------------|
| `kmod` | `.ko` | Yes | Kernel module |
| `ebpf` | `.o` | Yes | eBPF probe (classic, deprecated) |
| `modern_ebpf` | - | No | CO-RE eBPF (embedded in Falco) |

**Source:** [`pkg/driver/type/`](../../refs/falcosecurity/falcoctl/pkg/driver/type/)

### `driver config`

Configures the driver type for Falco.

**Source:** [`cmd/driver/config/config.go`](../../refs/falcosecurity/falcoctl/cmd/driver/config/config.go)

```bash
falcoctl driver config --type modern_ebpf
```

**Behavior:**
1. Checks if Falco is configured to use a driver (`engine.kind` in `falco.yaml`)
2. If yes, writes driver type to `/etc/falco/config.d/engine-kind-falcoctl.yaml`
3. Stores configuration in falcoctl config file

**Kubernetes support:** Can update ConfigMaps directly when running in a cluster:
```bash
falcoctl driver config --namespace falco --configmap falco
```

### `driver install`

Downloads or builds the kernel driver.

**Source:** [`cmd/driver/install/install.go`](../../refs/falcosecurity/falcoctl/cmd/driver/install/install.go)

```bash
falcoctl driver install [--download] [--compile]
```

**Process:**
1. Clean up existing drivers
2. Try to download prebuilt driver from configured repos
3. If download fails and `--compile` enabled, build locally
4. Load the driver (`insmod` for kmod, no-op for modern_ebpf)

### `driver cleanup`

Removes existing driver artifacts.

**For kmod:**
1. Tries `rmmod` to unload the module
2. Uses `dkms` to remove DKMS-installed versions

### `driver printenv`

Prints driver configuration as environment variables (useful for debugging/scripts).

## Registry Commands

### Authentication

Falcoctl supports multiple authentication methods:

```bash
# Basic authentication
falcoctl registry auth basic <registry> --username <user> --password <pass>

# OAuth2 client credentials
falcoctl registry auth oauth <registry> --client-id <id> --client-secret <secret> --token-url <url>

# GCP Application Default Credentials
falcoctl registry auth gcp <registry>
```

**Source:** [`cmd/registry/auth/`](../../refs/falcosecurity/falcoctl/cmd/registry/auth/)

### Push Artifacts

```bash
falcoctl registry push \
  --type rulesfile \
  --version "1.0.0" \
  --depends-on "k8saudit:0.6" \
  ghcr.io/myorg/myrules:1.0.0 \
  myrules.tar.gz
```

**Key flags:**
```
--type              Artifact type (rulesfile|plugin|asset)
--version           Semver version (required)
--depends-on        Dependencies (can repeat)
--platform          Platform for plugins (e.g., linux/amd64)
--add-floating-tags Create major/minor tags (1.0.0 -> 1.0, 1)
```

### Pull Artifacts

```bash
falcoctl registry pull ghcr.io/falcosecurity/plugins/plugin/cloudtrail:latest
```

## Configuration

### Configuration File

Default location: `/etc/falcoctl/falcoctl.yaml`

**Source:** [`README.md:111-156`](../../refs/falcosecurity/falcoctl/README.md)

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

### Environment Variables

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

**Source:** [`README.md:462-491`](../../refs/falcosecurity/falcoctl/README.md)

**Priority order:** CLI flags > Environment variables > Config file

## Kubernetes / Helm Chart Integration

Falcoctl is integral to Falco's Kubernetes deployment via the [Helm chart](charts.md). It runs as both init containers and sidecars, sharing artifacts with Falco via emptyDir volumes.

**Sources:**
- [`charts/falco/values.yaml:550-638`](../../refs/falcosecurity/charts/charts/falco/values.yaml) - falcoctl configuration
- [`charts/falco/templates/_helpers.tpl:255-315`](../../refs/falcosecurity/charts/charts/falco/templates/_helpers.tpl) - container templates
- [`charts/falco/templates/falcoctl-configmap.yaml`](../../refs/falcosecurity/charts/charts/falco/templates/falcoctl-configmap.yaml) - ConfigMap

### Helm Values Structure

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

### Container Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Falco Pod                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  INIT CONTAINERS (sequential):                                               │
│  ┌─────────────────────────┐    ┌──────────────────────────────────────────┐│
│  │ falco-driver-loader     │    │ falcoctl-artifact-install                ││
│  │ (if driver.enabled)     │ → │ (if falcoctl.artifact.install.enabled)  ││
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
│  │ - Exposes /versions     │ ← │ - Queries Falco /versions for compat     ││
│  │   endpoint on :8765     │    │ - Downloads new versions to shared vols  ││
│  └─────────────────────────┘    └──────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### Shared Volumes (emptyDir)

| Volume | Purpose | Mounted In |
|--------|---------|------------|
| `rulesfiles-install-dir` | Downloaded rules files | falcoctl-install → falco, falcoctl-follow |
| `plugins-install-dir` | Downloaded plugins | falcoctl-install → falco, falcoctl-follow |
| `artifact-state-dir` | Artifact state (digests) | falcoctl-install ↔ falcoctl-follow |

The state directory (`/artifactstate`) persists artifact digests between the init container and sidecar, preventing re-downloads of already-installed artifacts.

### Version Compatibility Check

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

The `engine_version` field contains only the MINOR component as a string (kept for backward compatibility). The `engine_version_semver` field contains the full semver. Plugin versions are populated when plugins are loaded.

**Source:** [`versions_info.cpp:65-83`](../../refs/falcosecurity/falco/userspace/falco/versions_info.cpp), [`falco_engine_version.h`](../../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h)

Falcoctl checks artifact requirements against these versions to ensure compatibility.

### ConfigMap Generation

The Helm chart generates a ConfigMap from `falcoctl.config`:

**Template:** [`templates/falcoctl-configmap.yaml`](../../refs/falcosecurity/charts/charts/falco/templates/falcoctl-configmap.yaml)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: falco-falcoctl
data:
  falcoctl.yaml: |-
    artifact:
      allowedTypes: [rulesfile, plugin]
      install:
        refs: [falco-rules:5]
        # ... (from values)
      follow:
        refs: [falco-rules:5]
        every: 168h
        # ... (from values)
    indexes:
      - name: falcosecurity
        url: https://falcosecurity.github.io/falcoctl/index.yaml
```

### Customizing Artifacts

**Install different rules (e.g., with incubating rules):**
```bash
helm install falco falcosecurity/falco \
  --set "falcoctl.config.artifact.install.refs={falco-rules:5,falco-incubating-rules:5}" \
  --set "falcoctl.config.artifact.follow.refs={falco-rules:5,falco-incubating-rules:5}"
```

**Install plugins for K8s audit:**
```bash
helm install falco falcosecurity/falco \
  -f values-k8saudit.yaml  # Sets refs to [k8saudit-rules:0.16, k8saudit:0.16]
```

**Disable automatic updates (install only, no follow):**
```bash
helm install falco falcosecurity/falco \
  --set falcoctl.artifact.follow.enabled=false
```

### Driver Loader vs Falcoctl

The Helm chart has two separate init containers that use falcoctl images:

| Container | Image | Purpose |
|-----------|-------|---------|
| `falco-driver-loader` | `falcosecurity/falco-driver-loader` | Downloads/builds kernel driver |
| `falcoctl-artifact-install` | `falcosecurity/falcoctl` | Downloads rules & plugins |

The driver loader is separate because:
- It requires different privileges (privileged: true)
- It needs access to host kernel files (/boot, /lib/modules, /usr)
- For `modern_ebpf`, it only writes config (driver is embedded in Falco)

### Related Digests

- [charts.md](charts.md) - Full Helm chart documentation
- [deploy-kubernetes.md](deploy-kubernetes.md) - Pre-rendered manifests showing the actual YAML

## Signature Verification

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

## Version Information

```bash
falcoctl version
```

Falcoctl images are signed with cosign:
```bash
cosign verify docker.io/falcosecurity/falcoctl:0.13.0 \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp=https://github.com/falcosecurity/falcoctl/
```

## Package Structure

| Package | Purpose |
|---------|---------|
| [`cmd/`](../../refs/falcosecurity/falcoctl/cmd/) | CLI command implementations |
| [`pkg/oci/`](../../refs/falcosecurity/falcoctl/pkg/oci/) | OCI registry operations |
| [`pkg/index/`](../../refs/falcosecurity/falcoctl/pkg/index/) | Index management |
| [`pkg/driver/`](../../refs/falcosecurity/falcoctl/pkg/driver/) | Driver type handling |
| [`pkg/artifact/`](../../refs/falcosecurity/falcoctl/pkg/artifact/) | Artifact reference parsing |
| [`internal/follower/`](../../refs/falcosecurity/falcoctl/internal/follower/) | Follow daemon logic |
| [`internal/config/`](../../refs/falcosecurity/falcoctl/internal/config/) | Configuration handling |
| [`internal/signature/`](../../refs/falcosecurity/falcoctl/internal/signature/) | Signature verification |

## Common Use Cases

### Install Rules and Plugins

```bash
# Add the official index
falcoctl index add falcosecurity https://falcosecurity.github.io/falcoctl/index.yaml

# Install cloudtrail plugin and rules
falcoctl artifact install cloudtrail cloudtrail-rules
```

### Configure Modern eBPF Driver

```bash
# Configure the driver type
falcoctl driver config --type modern_ebpf

# For modern_ebpf, no artifacts are needed (embedded in Falco)
```

### Push Custom Rules to Private Registry

```bash
# Authenticate
falcoctl registry auth basic ghcr.io --username $USER --password $TOKEN

# Push rules
falcoctl registry push \
  --type rulesfile \
  --version "1.0.0" \
  ghcr.io/myorg/custom-rules:1.0.0 \
  custom-rules.tar.gz
```

### Run Follower for Auto-Updates

```bash
# Follow rules with weekly checks
falcoctl artifact follow \
  --every 168h \
  --rulesfiles-dir /etc/falco/rules.d \
  falco-rules:5
```

## Sources

| Topic | Source File |
|-------|-------------|
| Repository README | [`README.md`](../../refs/falcosecurity/falcoctl/README.md) |
| Command structure | [`cmd/root.go`](../../refs/falcosecurity/falcoctl/cmd/root.go) |
| Artifact install command | [`cmd/artifact/install/install.go`](../../refs/falcosecurity/falcoctl/cmd/artifact/install/install.go) |
| Artifact follow command | [`cmd/artifact/follow/follow.go`](../../refs/falcosecurity/falcoctl/cmd/artifact/follow/follow.go) |
| Follower logic | [`internal/follower/follower.go`](../../refs/falcosecurity/falcoctl/internal/follower/follower.go) |
| Driver commands | [`cmd/driver/`](../../refs/falcosecurity/falcoctl/cmd/driver/) |
| Driver config command | [`cmd/driver/config/config.go`](../../refs/falcosecurity/falcoctl/cmd/driver/config/config.go) |
| Driver install command | [`cmd/driver/install/install.go`](../../refs/falcosecurity/falcoctl/cmd/driver/install/install.go) |
| OCI constants | [`pkg/oci/constants.go`](../../refs/falcosecurity/falcoctl/pkg/oci/constants.go) |
| OCI types | [`pkg/oci/types.go`](../../refs/falcosecurity/falcoctl/pkg/oci/types.go) |
| Driver types | [`pkg/driver/type/`](../../refs/falcosecurity/falcoctl/pkg/driver/type/) |
| Registry auth commands | [`cmd/registry/auth/`](../../refs/falcosecurity/falcoctl/cmd/registry/auth/) |
| OCI distribution proposal | [`proposals/20220916-rules-and-plugin-distribution.md`](../../refs/falcosecurity/falcoctl/proposals/20220916-rules-and-plugin-distribution.md) |
