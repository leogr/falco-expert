# Driver Distribution

> Pre-built driver distribution pipeline: kernel-crawler discovery, dbg-go orchestration, driverkit compilation, S3 distribution, and falcoctl installation.

**Era:** 0.45 | **Source:** [`refs/falcosecurity/test-infra/driverkit/`](../refs/falcosecurity/test-infra/driverkit/), [`refs/falcosecurity/driverkit/`](../refs/falcosecurity/driverkit/), [`refs/falcosecurity/dbg-go/`](../refs/falcosecurity/dbg-go/), [`refs/falcosecurity/kernel-crawler/`](../refs/falcosecurity/kernel-crawler/)

## Overview

Pre-built drivers enable Falco users to leverage kernel modules without compiling drivers on their target systems. The Falco project maintains an automated pipeline that discovers available Linux kernels across 19 distributions, compiles drivers for each kernel/architecture combination, and publishes the resulting artifacts to a public distribution endpoint.

The pipeline follows a five-stage flow:

1. **kernel-crawler** discovers kernel versions from Linux distribution repositories
2. **dbg-go** generates driverkit build configurations from crawler output
3. **driverkit** compiles kernel modules (`.ko`) from falcosecurity/libs source
4. **S3** stores the compiled artifacts in the `falco-distribution` bucket
5. **falcoctl** downloads the correct driver for the user's kernel at install time

The pinned grid contains 23,438 build configurations across two driver versions and two architectures. Config counts describe intended coverage, not successful published artifacts. Falco embeds its default modern eBPF driver; this pipeline builds kernel modules. [Driver contract](../refs/falcosecurity/driverkit/cmd/root_options.go#L34-L41), [modern eBPF](../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/_index.md#L35-L39).

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
 │  .ko (kernel module)                                          │
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

**Repository:** [falcosecurity/kernel-crawler](https://github.com/falcosecurity/kernel-crawler) | **Version:** pinned release-cycle snapshot (`git submodule status`) | **Scope:** Infra / Incubating

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

**Source:** [`kernel_crawler/crawler.py:43-63`](../refs/falcosecurity/kernel-crawler/kernel_crawler/crawler.py#L43-L63)

### Crawl Methods

| Method | Mechanism | Distributions |
|--------|-----------|---------------|
| **DEB-based** | Parses `Packages.gz` from APT repository indices for `linux-headers-*` packages | Ubuntu, Debian |
| **RPM-based** | Prefers SQLite `primary_db`; falls back to `primary` XML only when SQLite metadata is absent; XML does not resolve transitive dependencies | Amazon Linux, CentOS, Fedora, AlmaLinux, Rocky, Oracle Linux, openSUSE, Photon, Alibaba Cloud Linux |
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

**Source:** [`kernel_crawler/repo.py:27-41`](../refs/falcosecurity/kernel-crawler/kernel_crawler/repo.py#L27-L41), [`.github/workflows/update-kernels.yml`](../refs/falcosecurity/kernel-crawler/.github/workflows/update-kernels.yml)

## DBG-Go

dbg-go (Drivers Build Grid - Go) is the orchestration tool that bridges kernel-crawler output to driverkit builds and manages S3 publishing. It uses driverkit as a Go library dependency.

**Repository:** [falcosecurity/dbg-go](https://github.com/falcosecurity/dbg-go) | **Version:** v0.18.0 | **Scope:** Infra / Incubating

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
driverkit/output/{driver-version}/{arch}/falco_{distro}_{kernelrelease}_{kernelversion}.ko
```

**Source:** [`pkg/build/build.go`](../refs/falcosecurity/dbg-go/pkg/build/build.go)

### S3 Publishing

`dbg-go drivers publish` uploads locally built drivers to S3 with public-read ACL.

**OCI job authentication:** the driver-kit service account supplies a projected web-identity token; the job sets `AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE` and region `eu-west-1`. Static access-key variables are not required by this deployed job configuration. [Source](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L89-L99).

**Source:** [`pkg/utils/s3/s3utils.go`](../refs/falcosecurity/dbg-go/pkg/utils/s3/s3utils.go), [`pkg/publish/publish.go`](../refs/falcosecurity/dbg-go/pkg/publish/publish.go)

## Driverkit

Driverkit is the CLI tool and Go library that compiles Falco kernel modules (`.ko`) for specific kernel versions and distributions.

**Repository:** [falcosecurity/driverkit](https://github.com/falcosecurity/driverkit) | **Version:** v0.23.2 | **Scope:** Ecosystem / Incubating

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

**Source:** [`pkg/driverbuilder/builder/builders.go:86-92`](../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go#L86-L92)

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

**Source:** [`pkg/driverbuilder/builder/builders.go:220-247`](../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go#L220-L247), [`docs/builder_images.md`](../refs/falcosecurity/driverkit/docs/builder_images.md)

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
  -DDRIVER_VERSION=<version> \
  -DPROBE_VERSION=<version> \
  -DGIT_COMMIT=<commit> \
  -DDRIVER_DEVICE_NAME=<device-name> \
  -DPROBE_DEVICE_NAME=<device-name> \
  .. && \
  sed -i s/'DRIVER_COMMIT ""'/'DRIVER_COMMIT "<commit>"'/g driver/src/driver_config.h
```

**Source code URL:** `https://github.com/falcosecurity/libs/archive/<version>.tar.gz`

**Source:** [`pkg/driverbuilder/builder/builders.go:37-52`](../refs/falcosecurity/driverkit/pkg/driverbuilder/builder/builders.go#L37-L52) (`cmakeCmdFmt`)

## Drivers Build Grid

The Drivers Build Grid (DBG) is the infrastructure within [test-infra](https://github.com/falcosecurity/test-infra) that stores and manages the 23,438 driverkit configuration files used to build pre-compiled drivers.

### Driver Versions

Two driver versions are present in the pinned grid:

| Driver Version | x86_64 Configs | aarch64 Configs | Total |
|---------------|----------------|-----------------|-------|
| `10.2.0+driver` | 6,983 | 4,736 | 11,719 |
| `11.0.0+driver` | 6,983 | 4,736 | 11,719 |
| **Total** | **13,966** | **9,472** | **23,438** |

Counts are the YAML files under each version/architecture directory in [driverkit/config](../refs/falcosecurity/test-infra/driverkit/config/). They do not measure build success or download availability.

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

**Source:** [`tools/update-drivers-website/updateDriversWebsite.go:32-33`](../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go#L32-L33)

### S3 Path Structure

The listing code recognizes historical `.o` artifacts as well as `.ko`; current driverkit output is `.ko`. Existing object listings do not imply a matching current build configuration.

```
driver/{driver_version}/{architecture}/falco_{target}_{kernelrelease}_{kernelversion}.{ko,o}
```

**Examples:**
- `driver/10.2.0+driver/aarch64/falco_debian_6.1.170-3-rt-arm64_1.ko`
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

**Source:** [`driverkit/README.md:57-58`](../refs/falcosecurity/test-infra/driverkit/README.md#L57-L58)

## Automation

The current source catalog loads grid jobs in OCI. The AWS backup catalog is historical and is not loaded by this OCI Kustomization. These are configured jobs, not a claim about live cluster health. [Catalog](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1-L26).

### Periodic Job: update-dbg

`update-dbg` runs daily at 08:00 UTC, with one concurrent job in the x86 driver queue. It uses `ghcr.io/falcosecurity/test-infra/update-dbg:0.18.0-1`. Its entrypoint cleans and regenerates configs for amd64 and arm64, then commits and opens a PR when changes exist. [Job](../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml#L1-L33), [entrypoint](../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh#L35-L105).

### Presubmit Job: validate-dbg

Changes to driver configs on `master` run `validate-dbg`. Separate amd64 and arm64 containers execute `dbg-go configs validate` using the digest-pinned v0.18.0 image. [Job](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/validate-dbg.yaml#L1-L59).

### Postsubmit Jobs: build-new-*

Fourteen distro job files are loaded by the catalog. Their jobs select changed architecture/distro/kernel config paths on `master`; each runs `dbg-go configs build` with `--skip-existing`, `--publish`, `--ignore-errors` and a failure log under Prow artifacts. The builder runs as a non-root user and talks over a shared Unix socket to a privileged Docker sidecar. The `driver-kit` service account provides the projected AWS token used for publication. [Catalog](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L11-L26), [Debian job and arm variant](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L1-L163).

Driver builds are best effort: individual failures are logged while the batch proceeds. A successful batch job does not prove that every requested kernel has a published driver. Missing pre-built drivers are acceptable; evaluate the fallback available for the specific deployment. [Build options](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L77-L88), [build error handling](../refs/falcosecurity/dbg-go/pkg/build/build.go).

## Consumer Integration

### falcoctl driver install

For kernel-module deployments, `falcoctl driver install` obtains or builds the kernel-specific module. It:

1. Detects the running kernel version and release (`uname -r`, `uname -v`)
2. Identifies the target distribution
3. Constructs the download URL using the pattern: `https://download.falco.org/driver/{version}/{arch}/falco_{target}_{kernelrelease}_{kernelversion}.ko`
4. Downloads the matching kernel module
5. Falls back to local compilation if no pre-built driver is available

### Kubernetes Integration

In Kubernetes deployments, the Falco Helm chart can configure a `falco-driver-loader` init container that runs `falcoctl driver install` before the main Falco container starts. Modern eBPF deployments use the driver embedded in Falco; the chart does not need this kernel-module installation path for that engine.

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
| Build jobs (example) | [`refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml) |
| Update-dbg entrypoint | [`refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh`](../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh) |
| Drivers website tool | [`refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go`](../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go) |
| Config sample (Debian) | [`refs/falcosecurity/test-infra/driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml`](../refs/falcosecurity/test-infra/driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml) |
