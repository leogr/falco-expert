# Driver Distribution

> Pre-built driver distribution pipeline: kernel-crawler discovery, dbg-go orchestration, driverkit compilation, S3 distribution, and falcoctl installation.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/test-infra/driverkit/`](../refs/falcosecurity/test-infra/driverkit/), [`refs/falcosecurity/driverkit/`](../refs/falcosecurity/driverkit/), [`refs/falcosecurity/dbg-go/`](../refs/falcosecurity/dbg-go/), [`refs/falcosecurity/kernel-crawler/`](../refs/falcosecurity/kernel-crawler/)

## Overview

Pre-built drivers enable Falco users to leverage kernel instrumentation (kernel modules and eBPF probes) without compiling drivers on their target systems. The Falco project maintains an automated pipeline that discovers available Linux kernels across 19 distributions, compiles drivers for each kernel/architecture combination, and publishes the resulting artifacts to a public distribution endpoint.

The pipeline follows a five-stage flow:

1. **kernel-crawler** discovers kernel versions from Linux distribution repositories
2. **dbg-go** generates driverkit build configurations from crawler output
3. **driverkit** compiles kernel modules (`.ko`) and eBPF probes (`.o`) from falcosecurity/libs source
4. **S3** stores the compiled artifacts in the `falco-distribution` bucket
5. **falcoctl** downloads the correct driver for the user's kernel at install time

This system currently maintains ~44,024 build configurations across 4 driver versions and 2 architectures.

**Source:** [`digests/falcosecurity/dbg-go.md`](../digests/falcosecurity/dbg-go.md), [`digests/falcosecurity/test-infra/drivers-build-grid.md`](../digests/falcosecurity/test-infra/drivers-build-grid.md)

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Falco Driver Distribution Pipeline                       │
└─────────────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────┐
 │  Linux Distro Repos │
 │                     │
 │  - Ubuntu mirrors   │
 │  - Debian repos     │
 │  - Amazon Linux CDN │
 │  - CentOS/Fedora    │
 │  - ... (19 distros) │
 └──────────┬──────────┘
            │ crawl (daily GitHub Action)
            ▼
 ┌─────────────────────┐
 │   kernel-crawler     │
 │   (Python)           │
 │                      │
 │ Output: JSON with    │
 │ kernelversion,       │
 │ kernelrelease,       │
 │ target, headers      │
 └──────────┬───────────┘
            │ publish to GitHub Pages
            ▼
 ┌──────────────────────────────────────────┐
 │  GitHub Pages JSON                       │
 │  x86_64/list.json, aarch64/list.json    │
 │  falcosecurity.github.io/kernel-crawler │
 └──────────┬───────────────────────────────┘
            │ fetch (Prow periodic: update-dbg, daily 08:00 UTC)
            ▼
 ┌─────────────────────┐
 │  dbg-go             │
 │  configs generate   │
 │  --auto             │
 └──────────┬──────────┘
            │ write YAML configs
            ▼
 ┌──────────────────────────────────────────────────────────────┐
 │  test-infra repository                                       │
 │  driverkit/config/{version}/{arch}/{distro}_{kr}_{kv}.yaml  │
 └──────────┬───────────────────────────────────────────────────┘
            │ merge to master (Prow postsubmit: build-new-*)
            ▼
 ┌─────────────────────┐
 │  dbg-go             │
 │  configs build      │
 │  (calls driverkit)  │
 └──────────┬──────────┘
            │ compile in Docker containers
            ▼
 ┌──────────────────────────────────────────────────────────────┐
 │  driverkit/output/{version}/{arch}/falco_{target}_{kr}_{kv} │
 │  .ko (kernel module)   .o (eBPF probe)                      │
 └──────────┬───────────────────────────────────────────────────┘
            │ publish (dbg-go drivers publish)
            ▼
 ┌──────────────────────────────────────────────────┐
 │  S3: falco-distribution (eu-west-1)              │
 │  driver/{version}/{arch}/falco_{t}_{kr}_{kv}.ext │
 │  ACL: public-read                                │
 └──────────┬───────────────────────────────────────┘
            │ served via
            ▼
 ┌─────────────────────────────┐
 │  https://download.falco.org │
 └──────────┬──────────────────┘
            │ download
            ▼
 ┌──────────────────────────────┐
 │  falcoctl driver install     │
 │  (or falco-driver-loader     │
 │   init container in K8s)     │
 └──────────────────────────────┘
```

**Source:** [`digests/falcosecurity/dbg-go.md`](../digests/falcosecurity/dbg-go.md), [`digests/falcosecurity/test-infra/drivers-build-grid.md`](../digests/falcosecurity/test-infra/drivers-build-grid.md)

## Kernel Crawler

kernel-crawler is a Python tool that discovers available kernel versions across Linux distribution package repositories. It runs daily via a GitHub Action, crawling package repositories for each supported distribution and architecture, then publishing the results as JSON to GitHub Pages.

**Repository:** [falcosecurity/kernel-crawler](https://github.com/falcosecurity/kernel-crawler) | **Version:** commit `afc8224` (January 8, 2026) | **Scope:** Infra / Incubating

### Supported Distributions

| Distro Key | Distribution | Crawl Method |
|------------|--------------|--------------|
| `alinux` | Alibaba Cloud Linux | RPM |
| `almalinux` | AlmaLinux | RPM |
| `amazonlinux2` | Amazon Linux 2 | RPM |
| `amazonlinux2022` | Amazon Linux 2022 | RPM |
| `amazonlinux2023` | Amazon Linux 2023 | RPM |
| `arch` | Arch Linux | Pacman |
| `bottlerocket` | Bottlerocket (AWS) | Git |
| `centos` | CentOS | RPM |
| `debian` | Debian | DEB |
| `fedora` | Fedora | RPM |
| `flatcar` | Flatcar Container Linux | Git |
| `minikube` | Minikube | Git |
| `ol` | Oracle Linux | RPM |
| `opensuse` | openSUSE | RPM |
| `photon` | VMware Photon OS | RPM |
| `redhat` | Red Hat Enterprise Linux | Container |
| `rocky` | Rocky Linux | RPM |
| `talos` | Talos Linux | Git |
| `ubuntu` | Ubuntu | DEB |

**Supported Architectures:** x86_64, aarch64

**Source:** [`kernel_crawler/crawler.py:43-63`](../refs/falcosecurity/kernel-crawler/kernel_crawler/crawler.py)

### Crawl Methods

| Method | Mechanism | Distributions |
|--------|-----------|---------------|
| **DEB-based** | Parses `Packages.gz` from APT repository indices for `linux-headers-*` packages | Ubuntu, Debian |
| **RPM-based** | Parses `repomd.xml` and `primary.xml` from YUM/DNF repositories for `kernel-devel` packages | Amazon Linux, CentOS, Fedora, AlmaLinux, Rocky, Oracle Linux, openSUSE, Photon, Alibaba Cloud Linux |
| **Git-based** | Queries GitHub/GitLab APIs, downloads kernel configs from manifest files | Flatcar, Bottlerocket, Minikube, Talos |
| **Container-based** | Runs `rpm -qa kernel-devel*` inside a registered RHEL container image | Red Hat |

**Source:** [`kernel_crawler/deb.py`](../refs/falcosecurity/kernel-crawler/kernel_crawler/deb.py), [`kernel_crawler/rpm.py`](../refs/falcosecurity/kernel-crawler/kernel_crawler/rpm.py), [`kernel_crawler/flatcar.py`](../refs/falcosecurity/kernel-crawler/kernel_crawler/flatcar.py), [`kernel_crawler/redhat.py`](../refs/falcosecurity/kernel-crawler/kernel_crawler/redhat.py)

### Output Format

kernel-crawler outputs JSON organized by distribution, with each entry containing the information needed to build a driver:

```json
{
  "ubuntu": [
    {
      "kernelversion": "1",
      "kernelrelease": "5.4.0-150-generic",
      "target": "ubuntu-generic",
      "headers": [
        "http://mirrors.edge.kernel.org/ubuntu/pool/main/l/linux/linux-headers-5.4.0-150_5.4.0-150.167_all.deb",
        "http://mirrors.edge.kernel.org/ubuntu/pool/main/l/linux/linux-headers-5.4.0-150-generic_5.4.0-150.167_amd64.deb"
      ]
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `kernelversion` | Kernel build version (typically `"1"`) |
| `kernelrelease` | Full kernel release string (e.g., `5.4.0-150-generic`) |
| `target` | driverkit target identifier (e.g., `ubuntu-generic`, `amazonlinux2`) |
| `headers` | URLs to kernel header packages needed for compilation |

**Published endpoints (updated daily):**
- **x86_64:** `https://falcosecurity.github.io/kernel-crawler/x86_64/list.json`
- **aarch64:** `https://falcosecurity.github.io/kernel-crawler/aarch64/list.json`

**Source:** [`kernel_crawler/repo.py:27-41`](../refs/falcosecurity/kernel-crawler/kernel_crawler/repo.py), [`.github/workflows/update-kernels.yml`](../refs/falcosecurity/kernel-crawler/.github/workflows/update-kernels.yml)

## DBG-Go

dbg-go (Drivers Build Grid - Go) is the orchestration tool that bridges kernel-crawler output to driverkit builds and manages S3 publishing. It uses driverkit as a Go library dependency.

**Repository:** [falcosecurity/dbg-go](https://github.com/falcosecurity/dbg-go) | **Version:** commit `06c74bc` (February 2, 2026) | **Scope:** Infra / Incubating

### CLI Structure

```
dbg-go
├── configs              # Work with local driverkit configs
│   ├── generate         # Generate configs from kernel-crawler JSON
│   ├── build            # Build drivers using driverkit (Docker-based)
│   ├── validate         # Validate config files
│   ├── cleanup          # Remove stale config files
│   └── stats            # Statistics about configs
└── drivers              # Work with remote S3 drivers
    ├── publish          # Upload built drivers to S3
    ├── cleanup          # Remove drivers from S3
    └── stats            # Statistics about remote drivers
```

**Source:** [`README.md`](../refs/falcosecurity/dbg-go/README.md)

### Config Generation

`dbg-go configs generate --auto` fetches kernel-crawler JSON from GitHub Pages and generates one driverkit YAML config file per kernel/distro/architecture combination.

**Data source URL:** `https://falcosecurity.github.io/kernel-crawler/{arch}/list.json`

**Config path format:**
```
driverkit/config/{driver-version}/{arch}/{distro}_{kernelrelease}_{kernelversion}.yaml
```

**Example:**
```
driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml
```

**Source:** [`pkg/generate/generate.go`](../refs/falcosecurity/dbg-go/pkg/generate/generate.go), [`pkg/root/constants.go`](../refs/falcosecurity/dbg-go/pkg/root/constants.go)

### Driver Building

`dbg-go configs build` reads each YAML config and invokes driverkit (as a library) to compile the driver inside a Docker container. Key flags:

| Flag | Purpose |
|------|---------|
| `--publish` | Publish to S3 immediately after building |
| `--skip-existing` | Skip drivers already present in S3 |
| `--ignore-errors` | Continue batch on individual build failures |
| `--redirect-errors` | Log failures to file for later analysis |

**Output path format:**
```
driverkit/output/{driver-version}/{arch}/falco_{distro}_{kernelrelease}_{kernelversion}.{ko,o}
```

**Source:** [`pkg/build/build.go`](../refs/falcosecurity/dbg-go/pkg/build/build.go)

### S3 Publishing

`dbg-go drivers publish` uploads locally built drivers to S3 with public-read ACL.

**Required environment variables:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

**Source:** [`pkg/utils/s3/s3utils.go`](../refs/falcosecurity/dbg-go/pkg/utils/s3/s3utils.go), [`pkg/publish/publish.go`](../refs/falcosecurity/dbg-go/pkg/publish/publish.go)

## Driverkit

Driverkit is the CLI tool and Go library that compiles Falco kernel modules (`.ko`) and eBPF probes (`.o`) for specific kernel versions and distributions.

**Repository:** [falcosecurity/driverkit](https://github.com/falcosecurity/driverkit) | **Version:** v0.22.1 | **Scope:** Ecosystem / Incubating

### Builder Interface

Every target distribution implements the `Builder` interface:

```go
type Builder interface {
    Name() string
    TemplateKernelUrlsScript() string   // Script to download/extract kernel headers
    TemplateScript() string              // Script to build the driver
    URLs(kr kernelrelease.KernelRelease) ([]string, error)  // Kernel header URLs
    KernelTemplateData(kr kernelrelease.KernelRelease, urls []string) interface{}
}
```

**Source:** [`pkg/driverbuilder/builder/builders.go:86-92`](../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go)

### Supported Targets

22 target distributions are supported:

| Target | Distribution | Notes |
|--------|--------------|-------|
| `alinux` | Alibaba Cloud Linux 2/3 | |
| `almalinux` | AlmaLinux | |
| `amazonlinux` | Amazon Linux 1 | |
| `amazonlinux2` | Amazon Linux 2 | |
| `amazonlinux2022` | Amazon Linux 2022 | |
| `amazonlinux2023` | Amazon Linux 2023 | |
| `arch` | Arch Linux | |
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
| `ubuntu` | Ubuntu (all flavors) | Handles `ubuntu-generic`, `ubuntu-aws`, etc. |
| `vanilla` | Vanilla kernel | Requires `kernelconfigdata` |

**Source:** [`docs/driverkit.md`](../refs/falcosecurity/driverkit/docs/driverkit.md), [`Example_configs.md`](../refs/falcosecurity/driverkit/Example_configs.md)

### Build Processors

| Processor | Description | Use Case |
|-----------|-------------|----------|
| `docker` | Builds using local Docker daemon | Local development, CI (used by dbg-go) |
| `kubernetes` | Builds in Kubernetes cluster | Scalable builds, CI/CD |
| `kubernetes-in-cluster` | Builds from within a cluster | In-cluster builds |
| `local` | Builds directly on host system | DKMS-based builds |

**Source:** [`pkg/driverbuilder/docker.go`](../refs/falcosecurity/driverkit/pkg/driverbuilder/docker.go), [`pkg/driverbuilder/kubernetes.go`](../refs/falcosecurity/driverkit/pkg/driverbuilder/kubernetes.go), [`pkg/driverbuilder/local.go`](../refs/falcosecurity/driverkit/pkg/driverbuilder/local.go)

### Builder Images

Builder images follow the naming convention:
```
falcosecurity/driverkit-builder:<target>-<arch>_<gcc-versions>-<tag>
```

Example: `falcosecurity/driverkit-builder:centos-x86_64_gcc5.8.0_gcc6.0.0-latest`

**GCC version selection** is based on kernel major version:

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

**Source:** [`pkg/driverbuilder/builder/builders.go:220-247`](../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go), [`docs/builder_images.md`](../refs/falcosecurity/driverkit/docs/builder_images.md)

### Compilation

Driverkit downloads driver source code from [falcosecurity/libs](https://github.com/falcosecurity/libs) at the specified driver version and compiles using CMake:

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

**Source code URL:** `https://github.com/falcosecurity/libs/archive/<version>.tar.gz`

**Source:** [`pkg/driverbuilder/builder/builders.go:36-51`](../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go), [`pkg/driverbuilder/builder/build.go:64-66`](../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/build.go)

## Drivers Build Grid

The Drivers Build Grid (DBG) is the infrastructure within [test-infra](https://github.com/falcosecurity/test-infra) that stores and manages the ~44,024 driverkit configuration files used to build pre-compiled drivers.

### Driver Versions

Four driver versions are currently maintained:

| Driver Version | x86_64 Configs | aarch64 Configs | Total |
|---------------|----------------|-----------------|-------|
| `8.0.0+driver` | 6,545 | 4,461 | 11,006 |
| `8.1.0+driver` | 6,545 | 4,461 | 11,006 |
| `9.0.0+driver` | 6,545 | 4,461 | 11,006 |
| `9.1.0+driver` | 6,545 | 4,461 | 11,006 |
| **Total** | **26,180** | **17,844** | **44,024** |

### Architectures

| Directory Name | driverkit Architecture | Platform |
|----------------|----------------------|----------|
| `x86_64` | `amd64` | Intel/AMD 64-bit |
| `aarch64` | `arm64` | ARM 64-bit |

### Distro Targets in the Grid

| Category | Targets |
|----------|---------|
| Amazon Linux | `amazonlinux2`, `amazonlinux2022`, `amazonlinux2023` |
| CentOS | `centos` |
| Debian | `debian` |
| Fedora | `fedora` |
| Minikube | `minikube` |
| Photon OS | `photon` |
| Talos | `talos` |
| Ubuntu (generic) | `ubuntu-generic`, `ubuntu-hwe`, `ubuntu-lowlatency`, `ubuntu-lts`, `ubuntu-oem` |
| Ubuntu (cloud) | `ubuntu-aws`, `ubuntu-azure`, `ubuntu-gcp`, `ubuntu-gke`, `ubuntu-gkeop`, `ubuntu-oracle` |
| Ubuntu (hardware) | `ubuntu-ibm`, `ubuntu-intel`, `ubuntu-kvm`, `ubuntu-nvidia`, `ubuntu-raspi`, `ubuntu-raspi2`, `ubuntu-snapdragon`, `ubuntu-xilinx`, `ubuntu-bluefield` |

Not all targets exist in both architectures. For example, `ubuntu-kvm` and `ubuntu-intel` are x86_64-only, while `ubuntu-raspi` and `ubuntu-bluefield` are aarch64-only.

**Source:** [`digests/falcosecurity/test-infra/drivers-build-grid.md`](../digests/falcosecurity/test-infra/drivers-build-grid.md)

### Config File Format

Each config file is a driverkit YAML specifying a single kernel build:

```yaml
kernelversion: "1"
kernelrelease: 6.1.170-3-rt-arm64
target: debian
architecture: arm64
output:
    module: output/10.2.0+driver/aarch64/falco_debian_6.1.170-3-rt-arm64_1.ko
kernelurls:
    - http://archive.debian.org/debian/pool/main/l/linux/linux-kbuild-6.1_6.1.94-1~bpo11+1_arm64.deb
    - http://security.debian.org/debian-security/pool/updates/main/l/linux/linux-headers-6.1.0-47-common-rt_6.1.170-3_all.deb
    - http://security.debian.org/debian-security/pool/updates/main/l/linux/linux-headers-6.1.0-47-rt-arm64_6.1.170-3_arm64.deb
```

| Field | Description |
|-------|-------------|
| `kernelversion` | Kernel build version (e.g., `"1"`, `"153"`) |
| `kernelrelease` | Kernel release string (e.g., `6.1.140-1~deb11u1-rt-amd64`) |
| `target` | driverkit target distribution (e.g., `debian`, `ubuntu-generic`) |
| `architecture` | driverkit architecture: `amd64` or `arm64` |
| `output.module` | Output path for the kernel module `.ko` file |
| `output.probe` | Output path for the eBPF probe `.o` file |
| `kernelurls` | URLs to kernel header/devel packages needed for compilation |

**Source:** [driverkit/config/10.2.0+driver/aarch64/debian\_6.1.170-3-rt-arm64\_1.yaml](../refs/falcosecurity/test-infra/driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml)

## Distribution

### S3 Bucket

| Setting | Value |
|---------|-------|
| Bucket | `falco-distribution` |
| Region | `eu-west-1` |
| ACL | `public-read` |
| Source URL | `https://falco-distribution.s3-eu-west-1.amazonaws.com/?list-type=2&prefix=driver` |
| Public URL | `https://download.falco.org/` |

**Source:** [`tools/update-drivers-website/updateDriversWebsite.go:32-33`](../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go)

### S3 Path Structure

```
driver/{driver_version}/{architecture}/falco_{target}_{kernelrelease}_{kernelversion}.{ko,o}
```

**Examples:**
- `driver/10.2.0+driver/aarch64/falco_debian_6.1.170-3-rt-arm64_1.ko`
- `driver/10.2.0+driver/aarch64/falco_debian_6.1.170-3-rt-arm64_1.o`
- `driver/10.2.0+driver/x86_64/falco_ubuntu-generic_5.4.0-136-generic_153.ko`

**Source:** [`pkg/utils/s3/s3utils.go`](../refs/falcosecurity/dbg-go/pkg/utils/s3/s3utils.go)

### Drivers Website

A browsable index of all pre-compiled drivers is available at:
**[https://download.falco.org/driver/site/index.html](https://download.falco.org/driver/site/index.html)**

The website is generated by a Go tool ([`updateDriversWebsite.go`](../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go)) that:

1. Fetches the S3 bucket XML listing using pagination
2. Parses each S3 object key to extract: driver version, architecture, kind (ebpf/kmod), target, kernel
3. Generates per-driver-version JSON files (e.g., `9.0.0+driver.json`)
4. Generates an `index.json` listing all available driver versions
5. Serves a DataTables-powered HTML page with searchable/filterable views and download links

**Source:** [`tools/update-drivers-website/updateDriversWebsite.go`](../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go), [`tools/update-drivers-website/index.html`](../refs/falcosecurity/test-infra/tools/update-drivers-website/index.html)

### Important Behavior

Configs are kept only for the latest kernel-crawler results. Previously added configs are dropped on DBG updates, but already-published driver artifacts on S3 remain available for download. This means the S3 bucket accumulates drivers over time even as the config directory reflects only the current crawl state.

**Source:** [`driverkit/README.md:57-58`](../refs/falcosecurity/test-infra/driverkit/README.md)

## Automation

The Drivers Build Grid is orchestrated through three categories of Prow jobs:

### Periodic Job: update-dbg

| Field | Value |
|-------|-------|
| Name | `update-dbg` |
| Schedule | Daily at 08:00 UTC (`0 8 * * *`) |
| Image | `test-infra/update-dbg` (contains `dbg-go` v0.17.0 and `pr-creator`) |
| Purpose | Auto-generate configs from kernel-crawler output, open PR |

The job executes [`entrypoint.sh`](../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh) which:
1. Runs `dbg-go configs cleanup -a amd64` then `dbg-go configs generate -a amd64 --auto`
2. Runs `dbg-go configs cleanup -a arm64` then `dbg-go configs generate -a arm64 --auto`
3. If changes exist, creates a GPG-signed commit and opens a PR to `master` using the `poiana` bot account

**Source:** [`config/jobs/update-dbg/update-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-dbg/update-dbg.yaml), [`images/update-dbg/entrypoint.sh`](../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh)

### Presubmit Job: validate-dbg

| Field | Value |
|-------|-------|
| Name | `validate-dbg` |
| Trigger | PR changes matching `^driverkit/config/[a-z0-9.+-]{5,}/(.+/)?` |
| Image | `test-infra/build-drivers:latest` |
| Purpose | Validate config YAML files before merge |

Calls `dbg-go configs validate` for both `arm64` and `amd64`.

**Source:** [`config/jobs/build-drivers/validate-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml), [`images/build-drivers/build-drivers.sh`](../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh)

### Postsubmit Jobs: build-new-*

14 distro-specific job files define the build jobs that run after config changes are merged to `master`:

| Job File | Distros Covered |
|----------|----------------|
| [`build-new-amazonlinux.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-amazonlinux.yaml) | amazonlinux, amazonlinux2, amazonlinux2022, amazonlinux2023 |
| [`build-new-almalinux.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-almalinux.yaml) | almalinux |
| [`build-new-bottlerocket.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-bottlerocket.yaml) | bottlerocket |
| [`build-new-centos.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-centos.yaml) | centos |
| [`build-new-debian.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml) | debian |
| [`build-new-fedora.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-fedora.yaml) | fedora |
| [`build-new-minikube.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-minikube.yaml) | minikube |
| [`build-new-photon.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-photon.yaml) | photon |
| [`build-new-talos.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-talos.yaml) | talos |
| [`build-new-ubuntu-aws.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-aws.yaml) | ubuntu-aws |
| [`build-new-ubuntu-azure.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-azure.yaml) | ubuntu-azure |
| [`build-new-ubuntu-gcp.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gcp.yaml) | ubuntu-gcp |
| [`build-new-ubuntu-generic.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-generic.yaml) | ubuntu-generic and related variants |
| [`build-new-ubuntu-gke.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gke.yaml) | ubuntu-gke |

Each postsubmit job:
- Watches for changes matching `^driverkit/config/[a-z0-9.+-]{5,}/<arch>/<distro>_.+` on the `master` branch
- Runs the build-drivers Docker image with Docker-in-Docker (privileged mode)
- Executes `build-drivers.sh <distro>` with `PUBLISH_S3=true`, `--ignore-errors`, `--skip-existing`, and `--redirect-errors=driverkit/output/failing.log`
- Uses architecture-specific node selectors (`Archtype: "x86"` or `Archtype: "arm"`)
- Uses the `driver-kit` service account for S3 access
- Resource limits: 1 CPU / 4Gi memory, requests: 750m CPU / 2Gi memory

**Source:** [`config/jobs/build-drivers/build-new-debian.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml), [`images/build-drivers/build-drivers.sh`](../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh)

## Consumer Integration

### falcoctl driver install

`falcoctl driver install` is the primary mechanism for end users to obtain pre-built drivers. It:

1. Detects the running kernel version and release (`uname -r`, `uname -v`)
2. Identifies the target distribution
3. Constructs the download URL using the pattern: `https://download.falco.org/driver/{version}/{arch}/falco_{target}_{kernelrelease}_{kernelversion}.{ko,o}`
4. Downloads the matching kernel module or eBPF probe
5. Falls back to local compilation if no pre-built driver is available

### Kubernetes Integration

In Kubernetes deployments, the Falco Helm chart can configure a `falco-driver-loader` init container that runs `falcoctl driver install` before the main Falco container starts. This ensures the appropriate driver is available when Falco begins event capture.

**Source:** [`digests/falcosecurity/dbg-go.md`](../digests/falcosecurity/dbg-go.md), [`digests/falcosecurity/driverkit.md`](../digests/falcosecurity/driverkit.md)

## Related Specs

- [`kernel-instrumentation.md`](kernel-instrumentation.md) -- Kernel-level event capture architecture (modern eBPF, kmod)
- [`falcoctl.md`](falcoctl.md) -- falcoctl CLI including `driver install` subcommand
- [`build-system.md`](build-system.md) -- CMake build system for Falco and libs
- [`application-lifecycle.md`](application-lifecycle.md) -- Falco application startup including driver loading

## Sources

| Topic | Source File |
|-------|-------------|
| Pipeline overview | [`digests/falcosecurity/dbg-go.md`](../digests/falcosecurity/dbg-go.md) |
| Build grid configs | [`digests/falcosecurity/test-infra/drivers-build-grid.md`](../digests/falcosecurity/test-infra/drivers-build-grid.md) |
| kernel-crawler | [`digests/falcosecurity/kernel-crawler.md`](../digests/falcosecurity/kernel-crawler.md) |
| Driverkit | [`digests/falcosecurity/driverkit.md`](../digests/falcosecurity/driverkit.md) |
| DBG README | [`refs/falcosecurity/test-infra/driverkit/README.md`](../refs/falcosecurity/test-infra/driverkit/README.md) |
| dbg-go README | [`refs/falcosecurity/dbg-go/README.md`](../refs/falcosecurity/dbg-go/README.md) |
| Driverkit builders | [`refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go`](../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go) |
| S3 utilities | [`refs/falcosecurity/dbg-go/pkg/utils/s3/s3utils.go`](../refs/falcosecurity/dbg-go/pkg/utils/s3/s3utils.go) |
| Crawler distros | [`refs/falcosecurity/kernel-crawler/kernel_crawler/crawler.py`](../refs/falcosecurity/kernel-crawler/kernel_crawler/crawler.py) |
| Build jobs (example) | [`refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml) |
| Update-dbg entrypoint | [`refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh`](../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh) |
| Drivers website tool | [`refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go`](../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go) |
| Config sample (Debian) | [`refs/falcosecurity/test-infra/driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml`](../refs/falcosecurity/test-infra/driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml) |
