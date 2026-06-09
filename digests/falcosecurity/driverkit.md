# Driverkit Digest

**Repository:** [falcosecurity/driverkit](https://github.com/falcosecurity/driverkit)
**Version:** v0.22.1
**Status:** Ecosystem / Incubating
**Era:** 0.44

## Overview

Driverkit is a command-line tool for building Falco kernel modules (`.ko`) and eBPF probes (`.o`). It abstracts away the complexity of driver compilation by providing multiple build backends (Docker, Kubernetes, local) and supporting numerous Linux distributions out of the box.

**Source:** [`README.md`](../../refs/falcosecurity/driverkit/README.md)

## Architecture

### Build Process Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  User Input     │────▶│  Build Config    │────▶│  Builder        │
│  (CLI/YAML)     │     │  (RootOptions)   │     │  Factory        │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
                         ┌────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Target Builder                               │
│  (ubuntu, centos, debian, archlinux, amazonlinux, etc.)            │
├─────────────────────────────────────────────────────────────────────┤
│  • URLs(): Returns kernel header download URLs                     │
│  • TemplateKernelUrlsScript(): Kernel download/extract script      │
│  • TemplateScript(): Build script template                         │
│  • KernelTemplateData(): Data for template rendering               │
└─────────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Build Processor                                 │
├──────────────┬──────────────┬──────────────┬───────────────────────┤
│    Docker    │  Kubernetes  │ Kubernetes   │        Local          │
│              │              │  In-Cluster  │                       │
└──────────────┴──────────────┴──────────────┴───────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Builder Image                                    │
│  (falcosecurity/driverkit-builder:<target>-<arch>_<gcc>-<tag>)     │
│  Contains: GCC versions, clang/LLVM, build tools                   │
└─────────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Output                                         │
│  • Kernel Module: /tmp/driver/build/driver/<name>.ko               │
│  • eBPF Probe: /tmp/driver/build/driver/bpf/probe.o                │
└─────────────────────────────────────────────────────────────────────┘
```

**Source:** [`pkg/driverbuilder/builder/builders.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go)

### Core Components

#### 1. Builder Interface

Every target distribution implements the `Builder` interface:

```go
type Builder interface {
    Name() string
    TemplateKernelUrlsScript() string   // Script to download/extract headers
    TemplateScript() string              // Script to build the driver
    URLs(kr kernelrelease.KernelRelease) ([]string, error)  // Kernel header URLs
    KernelTemplateData(kr kernelrelease.KernelRelease, urls []string) interface{}
}
```

**Source:** [`pkg/driverbuilder/builder/builders.go:86-92`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go)

#### 2. Build Configuration

The `Build` struct contains all information needed to build a driver:

| Field | Description |
|-------|-------------|
| `TargetType` | Target distribution (ubuntu, centos, etc.) |
| `KernelRelease` | Kernel release string (from `uname -r`) |
| `KernelVersion` | Kernel version number (from `uname -v`) |
| `DriverVersion` | Git commit hash or tag from falcosecurity/libs |
| `Architecture` | Target architecture (amd64, arm64) |
| `ModuleFilePath` | Output path for kernel module |
| `ProbeFilePath` | Output path for eBPF probe |

**Source:** [`pkg/driverbuilder/builder/build.go:29-55`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/build.go)

#### 3. Build Processors

| Processor | Description | Use Case |
|-----------|-------------|----------|
| `docker` | Builds using local Docker daemon | Local development, CI |
| `kubernetes` | Builds in Kubernetes cluster | Scalable builds, CI/CD |
| `kubernetes-in-cluster` | Builds from within a cluster | In-cluster builds |
| `local` | Builds directly on host system | DKMS-based builds |

**Source:** [`pkg/driverbuilder/docker.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/docker.go), [`pkg/driverbuilder/kubernetes.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/kubernetes.go), [`pkg/driverbuilder/local.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/local.go)

## Supported Targets

| Target | Distribution | Notes |
|--------|--------------|-------|
| `alinux` | Alibaba Cloud Linux 2/3 | |
| `almalinux` | AlmaLinux | |
| `amazonlinux` | Amazon Linux 1 | |
| `amazonlinux2` | Amazon Linux 2 | |
| `amazonlinux2022` | Amazon Linux 2022 | |
| `amazonlinux2023` | Amazon Linux 2023 | |
| `arch` | Arch Linux | Uses [Arch Linux Archive](https://wiki.archlinux.org/title/Arch_Linux_Archive) |
| `bottlerocket` | Bottlerocket OS | |
| `centos` | CentOS 6/7/8 | |
| `debian` | Debian | |
| `fedora` | Fedora | |
| `flatcar` | Flatcar Container Linux | Requires `kernelconfigdata` |
| `minikube` | Minikube | Requires `kernelconfigdata` |
| `ol` | Oracle Linux | |
| `opensuse` | openSUSE | |
| `photon` | VMware Photon OS | |
| `redhat` | Red Hat Enterprise Linux | Requires custom `builderimage` |
| `rocky` | Rocky Linux | |
| `sles` | SUSE Linux Enterprise Server | |
| `talos` | Talos Linux | |
| `ubuntu` | Ubuntu (all flavors) | Also handles `ubuntu-generic`, `ubuntu-aws` |
| `vanilla` | Vanilla kernel | Requires `kernelconfigdata` |

**Source:** [`docs/driverkit.md`](../../refs/falcosecurity/driverkit/docs/driverkit.md), [`Example_configs.md`](../../refs/falcosecurity/driverkit/Example_configs.md)

## CLI Reference

### Global Options

```
--architecture string       Target architecture: amd64, arm64 (default: runtime arch)
--builderimage string       Custom Docker image for building
--builderrepo strings       Docker repos or YAML index files for builder images
--config string             Config file path (default: $HOME/.driverkit.yaml)
--driverversion string      Driver version (git tag/commit) (default: "master")
--gccversion string         Enforce specific GCC version
--kernelconfigdata string   Base64-encoded kernel config (required for vanilla/flatcar/minikube)
--kernelrelease string      Kernel release (from `uname -r`)
--kernelurls strings        Custom kernel header URLs
--kernelversion string      Kernel version (from `uname -v`) (default: "1")
--moduledevicename string   Kernel module device name (default: "falco")
--moduledrivername string   Kernel module driver name (default: "falco")
--output-module string      Output path for kernel module (.ko)
--output-probe string       Output path for eBPF probe (.o)
--proxy string              HTTP/HTTPS proxy URL
--repo-name string          GitHub repo name (default: "libs")
--repo-org string           GitHub organization (default: "falcosecurity")
--target string             Target distribution
--timeout int               Build timeout in seconds (default: 120)
```

**Source:** [`cmd/root_options.go`](../../refs/falcosecurity/driverkit/cmd/root_options.go)

### Commands

#### docker

Build using Docker daemon:

```bash
driverkit docker \
    --output-module /tmp/falco.ko \
    --output-probe /tmp/falco.o \
    --kernelrelease 5.15.0-91-generic \
    --kernelversion 101 \
    --target ubuntu \
    --driverversion 0.20.1
```

**Source:** [`docs/driverkit_docker.md`](../../refs/falcosecurity/driverkit/docs/driverkit_docker.md)

#### kubernetes

Build in Kubernetes cluster:

```bash
driverkit kubernetes \
    --output-module /tmp/falco.ko \
    --kernelrelease 4.15.0-72-generic \
    --kernelversion 81 \
    --target ubuntu-generic \
    --driverversion master
```

Additional options:
- `--namespace`: Kubernetes namespace (default: "default")
- `--run-as-user`: User ID for pod (default: 0)
- `--image-pull-secret`: Secret for pulling builder image

**Source:** [`docs/driverkit_kubernetes.md`](../../refs/falcosecurity/driverkit/docs/driverkit_kubernetes.md)

#### local

Build on local host:

```bash
driverkit local \
    --output-module /tmp/falco.ko \
    --output-probe /tmp/falco.o \
    --kernelrelease $(uname -r) \
    --target ubuntu \
    --driverversion 0.20.1
```

Additional options:
- `--dkms`: Use DKMS for kernel module build (requires root)
- `--download-headers`: Automatically download kernel headers
- `--src-dir`: Use local source directory instead of downloading
- `--env`: Environment variables for the build

**Source:** [`docs/driverkit_local.md`](../../refs/falcosecurity/driverkit/docs/driverkit_local.md)

#### images

List available builder images:

```bash
driverkit images
```

**Source:** [`docs/driverkit_images.md`](../../refs/falcosecurity/driverkit/docs/driverkit_images.md)

## Configuration File

Driverkit supports YAML configuration files:

```yaml
# Example: ubuntu-aws.yaml
kernelrelease: 4.15.0-1057-aws
kernelversion: 59
target: ubuntu
driverversion: 0.20.1
output:
  module: /tmp/falco.ko
  probe: /tmp/falco.o
```

Usage:
```bash
driverkit docker -c ubuntu-aws.yaml
```

**Source:** [`README.md`](../../refs/falcosecurity/driverkit/README.md), [`Example_configs.md`](../../refs/falcosecurity/driverkit/Example_configs.md)

## Builder Images

### Image Naming Convention

```
falcosecurity/driverkit-builder:<target>-<arch>_<gcc-versions>-<tag>
```

Examples:
- `falcosecurity/driverkit-builder:centos-x86_64_gcc5.8.0_gcc6.0.0-latest`
- `falcosecurity/driverkit-builder:any-x86_64_gcc12.0.0-latest`

**Source:** [`docs/builder_images.md`](../../refs/falcosecurity/driverkit/docs/builder_images.md)

### Image Selection Algorithm

1. Load images matching build architecture, tag, and target
2. Load images matching build architecture, tag, and "any" target (fallback)
3. If target-specific image provides required GCC version → use it
4. If "any" fallback image provides required GCC version → use it
5. Otherwise, find image providing nearest GCC version (below target)

**Source:** [`pkg/driverbuilder/builder/builders.go:257-329`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go)

### Default GCC Selection

Based on kernel major version:

| Kernel | GCC Version |
|--------|-------------|
| 6.9+ | 14 |
| 6.5-6.8 | 13 |
| 6.0-6.4 | 12 |
| 5.15+ | 12 |
| 5.x | 11 |
| 4.x | 8 |
| 3.18+ | 5 |
| 3.x | 4.9 |
| 2.x | 4.8 |

**Source:** [`pkg/driverbuilder/builder/builders.go:220-247`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go)

### Custom Builder Images

You can specify custom builder image repositories:

```bash
# Docker repository
driverkit docker --builderrepo myorg/driverkit-builder

# YAML index file
driverkit docker --builderrepo /path/to/index.yaml
```

YAML index format:
```yaml
images:
  - target: ubuntu
    name: myregistry/builder:ubuntu
    arch: x86_64
    tag: latest
    gcc_versions:
      - "12.0.0"
      - "11.0.0"
```

**Source:** [`docs/builder_images.md`](../../refs/falcosecurity/driverkit/docs/builder_images.md), [`pkg/driverbuilder/builder/image.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/image.go)

## Kernel Headers

### Header Resolution

1. If `--kernelurls` provided → use those URLs directly
2. Otherwise → call builder's `URLs()` method to generate URLs
3. Verify URLs with HTTP HEAD requests
4. Filter to only working URLs

**Source:** [`pkg/driverbuilder/builder/builders.go:133-188`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go)

### kernel-crawler Integration

For automated header URL discovery, use [kernel-crawler](https://github.com/falcosecurity/kernel-crawler):

```
https://falcosecurity.github.io/kernel-crawler/
```

The crawler provides JSON files with kernel header URLs for all supported distributions.

**Source:** [`README.md`](../../refs/falcosecurity/driverkit/README.md)

## Build Scripts

### Script Generation

Driverkit uses Go templates to generate bash scripts:

1. **libs_download.sh** - Downloads falcosecurity/libs at specified version
2. **download-headers.sh** - Downloads and extracts kernel headers (per-target)
3. **driverkit.sh** - Builds the actual drivers (per-target)

**Source:** [`pkg/driverbuilder/builder/templates/`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/templates/)

### Build Script Template Data

```go
type commonTemplateData struct {
    DriverBuildDir   string    // /tmp/driver
    ModuleDriverName string    // falco
    ModuleFullPath   string    // /tmp/driver/build/driver/falco.ko
    BuildModule      bool      // Whether to build kernel module
    BuildProbe       bool      // Whether to build eBPF probe
    GCCVersion       string    // GCC version to use
    CmakeCmd         string    // CMake command with all options
}
```

**Source:** [`pkg/driverbuilder/builder/builders.go:75-83`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go)

### CMake Configuration

```bash
cmake -Wno-dev \
  -DUSE_BUNDLED_DEPS=On \
  -DCREATE_TEST_TARGETS=Off \
  -DBUILD_LIBSCAP_GVISOR=Off \
  -DBUILD_LIBSCAP_MODERN_BPF=Off \
  -DENABLE_DRIVERS_TESTS=Off \
  -DDRIVER_NAME=<name> \
  -DPROBE_NAME=<name> \
  -DBUILD_BPF=On \
  -DDRIVER_VERSION=<version> \
  -DPROBE_VERSION=<version> \
  -DGIT_COMMIT=<commit> \
  -DDRIVER_DEVICE_NAME=<device-name> \
  -DPROBE_DEVICE_NAME=<device-name> \
  ..
```

**Source:** [`pkg/driverbuilder/builder/builders.go:36-51`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go)

## Adding New Target Support

To add support for a new distribution:

1. **Create builder file** in `pkg/driverbuilder/builder/<distro>.go`
2. **Define target constant** and register in `byTarget` map
3. **Implement Builder interface**:
   - `Name()` - Return target name
   - `URLs()` - Return kernel header URLs
   - `TemplateKernelUrlsScript()` - Return kernel download script template
   - `TemplateScript()` - Return build script template
   - `KernelTemplateData()` - Return template data
4. **Create script templates** in `pkg/driverbuilder/builder/templates/`
5. **Update kernel-crawler** (separate repo) if automatic header discovery needed
6. **Update dbg-go** to generate configs for new distro
7. **Update test-infra** prow configs for automated builds

**Source:** [`docs/builder.md`](../../refs/falcosecurity/driverkit/docs/builder.md)

## Integration with Falco Ecosystem

### Falco Drivers Build Grid

Driverkit powers the [Falco Drivers Build Grid](https://github.com/falcosecurity/test-infra/tree/master/driverkit), which automatically builds drivers for all supported kernel/distribution combinations.

### falcoctl Integration

The driver artifacts built by driverkit are distributed via:
- OCI registries (via falcoctl)
- download.falco.org

### Relationship to falcosecurity/libs

Driverkit downloads driver source code from [falcosecurity/libs](https://github.com/falcosecurity/libs) at the specified `--driverversion`:

```
https://github.com/falcosecurity/libs/archive/<version>.tar.gz
```

**Source:** [`pkg/driverbuilder/builder/build.go:64-66`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/build.go)

## Cross-Compilation

### Architecture Support

- **Native builds**: amd64, arm64
- **Cross-compilation**: arm64 from x86_64 (using QEMU)

For arm64 cross-builds from x86_64, driverkit automatically pulls and runs `multiarch/qemu-user-static`.

**Source:** [`pkg/driverbuilder/docker.go:68-126`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/docker.go)

## Special Cases

### Red Hat Enterprise Linux

Requires custom builder image with RHEL subscription:

```yaml
target: redhat
builderimage: registry.redhat.io/rhel8:custom_driverkit
```

**Source:** [`Example_configs.md`](../../refs/falcosecurity/driverkit/Example_configs.md)

### Vanilla/Flatcar/Minikube

Require `kernelconfigdata` (base64-encoded kernel config):

```bash
# Get kernel config and encode
zcat /proc/config.gz | base64 -w0
```

**Source:** [`cmd/root_options.go:220-232`](../../refs/falcosecurity/driverkit/cmd/root_options.go)

## Version Note

**v0.23.0** removes legacy eBPF support since it's deprecated in the current era. Use v0.22.1 for this era (0.43) as it maintains compatibility.

## Sources

| Topic | Source File |
|-------|-------------|
| Overview | [`README.md`](../../refs/falcosecurity/driverkit/README.md) |
| CLI Reference | [`docs/driverkit.md`](../../refs/falcosecurity/driverkit/docs/driverkit.md) |
| Builder Interface | [`pkg/driverbuilder/builder/builders.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go) |
| Build Configuration | [`pkg/driverbuilder/builder/build.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/build.go) |
| Docker Processor | [`pkg/driverbuilder/docker.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/docker.go) |
| Kubernetes Processor | [`pkg/driverbuilder/kubernetes.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/kubernetes.go) |
| Local Processor | [`pkg/driverbuilder/local.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/local.go) |
| Builder Images | [`docs/builder_images.md`](../../refs/falcosecurity/driverkit/docs/builder_images.md) |
| Adding Builders | [`docs/builder.md`](../../refs/falcosecurity/driverkit/docs/builder.md) |
| Example Configs | [`Example_configs.md`](../../refs/falcosecurity/driverkit/Example_configs.md) |
| Image Loading | [`pkg/driverbuilder/builder/image.go`](../../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/image.go) |
| CLI Options | [`cmd/root_options.go`](../../refs/falcosecurity/driverkit/cmd/root_options.go) |
