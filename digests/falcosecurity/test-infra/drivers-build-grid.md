# Falco Test Infrastructure — Drivers Build Grid (DBG)

> **Era:** 0.44 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

## Overview

The Drivers Build Grid (DBG) is the infrastructure system within [test-infra](https://github.com/falcosecurity/test-infra) that pre-compiles Falco kernel modules (`.ko`) and eBPF probes (`.o`) for thousands of Linux kernel versions across multiple distributions and architectures. These pre-built drivers allow Falco users to run with kernel-level instrumentation without compiling drivers themselves.

The DBG relies heavily on the [`dbg-go`](https://github.com/falcosecurity/dbg-go) tool, a Go-based CLI that orchestrates config generation, validation, building, and S3 publishing. The `dbg-go` tool uses [driverkit](https://github.com/falcosecurity/driverkit) as a Go library for the actual driver compilation.

**Source:** [driverkit/README.md](../../../refs/falcosecurity/test-infra/driverkit/README.md)

### Key Capabilities of dbg-go

- Generate configs (single or auto-generation from [kernel-crawler](https://github.com/falcosecurity/kernel-crawler) output)
- Cleanup, validate, and fetch stats about configs
- Build configs using driverkit as a library
- Cleanup, publish, and fetch stats about S3 drivers

**Source:** [driverkit/README.md:10-20](../../../refs/falcosecurity/test-infra/driverkit/README.md)

---

## Config Structure

Driverkit build configurations are stored in a strict directory hierarchy:

```
driverkit/config/<driver_version>/<architecture>/<distro>_<kernel_release>_<build_version>.yaml
```

**Source:** [driverkit/README.md:50](../../../refs/falcosecurity/test-infra/driverkit/README.md)

### Supported Driver Versions

Five driver versions are currently maintained (as of the 0.44 era pin):

| Driver Version | x86_64 Configs | aarch64 Configs | Total |
|---------------|---------------|-----------------|-------|
| `9.0.0+driver` | 7,025 | 4,974 | 11,999 |
| `9.1.0+driver` | 7,025 | 4,974 | 11,999 |
| `10.0.0+driver` | 7,025 | 4,974 | 11,999 |
| `10.1.0+driver` | 7,025 | 4,974 | 11,999 |
| `10.2.0+driver` (bundled with Falco 0.44.0) | 7,025 | 4,974 | 11,999 |
| **Total** | **35,125** | **24,870** | **59,995** |

> The `8.0.0+driver` and `8.1.0+driver` lines were retired before the 0.44 era pin. Counts may vary day-to-day as kernel-crawler discovers new kernels.

### Supported Architectures

Each driver version contains configs for two architectures:

- **x86_64** (mapped to driverkit `amd64`)
- **aarch64** (mapped to driverkit `arm64`)

### Supported Distro Targets

The following unique distro targets exist across the build grid (union of x86_64 and aarch64):

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

Note: Not all targets are present in both architectures. For example, `ubuntu-kvm`, `ubuntu-ibm`, `ubuntu-intel`, and `ubuntu-gkeop` are x86_64-only, while `ubuntu-raspi`, `ubuntu-raspi2`, `ubuntu-snapdragon`, `ubuntu-xilinx`, and `ubuntu-bluefield` are aarch64-only.

---

## Config File Format (YAML)

Each config file is a driverkit configuration YAML with the following fields:

| Field | Description |
|-------|-------------|
| `kernelversion` | The kernel build version (e.g., `"1"`, `"153"`) |
| `kernelrelease` | The kernel release string (e.g., `6.1.140-1~deb11u1-rt-amd64`) |
| `target` | The driverkit target distribution (e.g., `debian`, `ubuntu-generic`, `amazonlinux2023`) |
| `architecture` | The driverkit architecture: `amd64` or `arm64` |
| `output.module` | Output path for the kernel module `.ko` file |
| `output.probe` | Output path for the eBPF probe `.o` file |
| `kernelurls` | List of URLs to download kernel headers/devel packages needed for compilation |

### Sample Config: Debian aarch64 (RT kernel)

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

**Source:** [debian\_6.1.170-3-rt-arm64\_1.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml)

### Sample Config: Amazon Linux 2023 aarch64

```yaml
kernelversion: "1"
kernelrelease: 6.1.102-108.177.amzn2023.aarch64
target: amazonlinux2023
architecture: arm64
output:
    module: output/9.0.0+driver/aarch64/falco_amazonlinux2023_6.1.102-108.177.amzn2023.aarch64_1.ko
    probe: output/9.0.0+driver/aarch64/falco_amazonlinux2023_6.1.102-108.177.amzn2023.aarch64_1.o
kernelurls:
    - https://cdn.amazonlinux.com/.../kernel-devel-6.1.102-108.177.amzn2023.aarch64.rpm
```

**Source:** [amazonlinux2023\_6.1.102-108.177.amzn2023.aarch64\_1.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/9.0.0+driver/aarch64/amazonlinux2023_6.1.102-108.177.amzn2023.aarch64_1.yaml)

### Sample Config: Ubuntu Generic x86_64

```yaml
kernelversion: "153"
kernelrelease: 5.4.0-136-generic
target: ubuntu-generic
architecture: amd64
output:
    module: output/9.0.0+driver/x86_64/falco_ubuntu-generic_5.4.0-136-generic_153.ko
    probe: output/9.0.0+driver/x86_64/falco_ubuntu-generic_5.4.0-136-generic_153.o
kernelurls:
    - http://archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-5.4.0-136-generic_5.4.0-136.153_amd64.deb
    - http://archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-5.4.0-136-lowlatency_5.4.0-136.153_amd64.deb
    - http://archive.ubuntu.com/ubuntu/pool/main/l/linux/linux-headers-5.4.0-136_5.4.0-136.153_all.deb
    # ... plus mirrors from mirrors.edge.kernel.org and security.ubuntu.com
```

**Source:** [ubuntu-generic\_5.4.0-136-generic\_153.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/9.0.0+driver/x86_64/ubuntu-generic_5.4.0-136-generic_153.yaml)

### Sample Config: Photon OS aarch64

```yaml
kernelversion: "1"
kernelrelease: 6.1.56-9.ph5
target: photon
architecture: arm64
output:
    module: output/9.0.0+driver/aarch64/falco_photon_6.1.56-9.ph5_1.ko
    probe: output/9.0.0+driver/aarch64/falco_photon_6.1.56-9.ph5_1.o
kernelurls:
    - https://packages.vmware.com/photon/5.0/photon_5.0_aarch64/aarch64/linux-devel-6.1.56-9.ph5.aarch64.rpm
```

**Source:** [photon\_6.1.56-9.ph5\_1.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/9.0.0+driver/aarch64/photon_6.1.56-9.ph5_1.yaml)

### Key Observations

- **Debian** configs reference `.deb` kernel header packages from `security.debian.org`
- **Amazon Linux** configs reference `.rpm` kernel-devel packages from CDN URLs
- **Ubuntu** configs typically list multiple mirror URLs (archive, mirrors.edge.kernel.org, security) for redundancy
- **Photon** configs reference `.rpm` packages from VMware's Photon package repository
- The `output` paths encode the driver version, architecture, and a standardized filename: `falco_<target>_<kernelrelease>_<kernelversion>.<ext>`

---

## Build Process (End-to-End Flow)

The DBG operates as a continuous pipeline:

### 1. Kernel Discovery (kernel-crawler)

The [kernel-crawler](https://github.com/falcosecurity/kernel-crawler) tool discovers available kernel versions across all supported Linux distributions by scraping distribution package repositories. Its output is the source of truth for which kernels should have pre-built drivers.

### 2. Config Generation (update-dbg periodic job)

A Prow **periodic job** named `update-dbg` runs daily at 08:00 UTC ([update-dbg.yaml:3](../../../refs/falcosecurity/test-infra/config/jobs/update-dbg/update-dbg.yaml)). It:

1. Checks out the `test-infra` repository
2. Runs the [update-dbg image](../../../refs/falcosecurity/test-infra/images/update-dbg/Dockerfile), which contains `dbg-go` v0.17.0 and the `pr-creator` tool
3. Executes the [entrypoint.sh](../../../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh) script, which:
   - Runs `dbg-go configs cleanup -a amd64` then `dbg-go configs generate -a amd64 --auto` ([entrypoint.sh:35-36](../../../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh))
   - Runs `dbg-go configs cleanup -a arm64` then `dbg-go configs generate -a arm64 --auto` ([entrypoint.sh:37-38](../../../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh))
   - The `--auto` flag tells dbg-go to use kernel-crawler output as input
   - Cleanup removes stale configs, generate creates new ones
4. If changes exist, creates a GPG-signed commit and opens a PR to `master` using the `poiana` bot account ([entrypoint.sh:70-99](../../../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh))

**Important behavior:** Configs are kept only for the latest kernel-crawler results. Previously added configs are dropped on DBG updates, but already-published driver artifacts on S3 remain available. ([driverkit/README.md:57-58](../../../refs/falcosecurity/test-infra/driverkit/README.md))

### 3. Config Validation (presubmit job)

When a PR modifies files under `driverkit/config/`, the `validate-dbg` **presubmit job** runs ([validate-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml)). It:

- Triggers on changes matching: `^driverkit/config/[a-z0-9.+-]{5,}/(.+/)?` ([validate-dbg.yaml:9](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml))
- Runs `build-drivers.sh` with `DBG_MAKE_BUILD_TARGET=validate` ([validate-dbg.yaml:16-17](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml))
- Calls `dbg-go configs validate` for both `arm64` and `amd64` ([build-drivers.sh:74-78](../../../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh))

### 4. Driver Building (postsubmit jobs)

After config changes are merged to `master`, per-distro **postsubmit jobs** trigger the actual driver builds. There are 14 distro-specific build job files (each defining x86_64 and aarch64 variants):

| Job File | Distros Covered |
|----------|----------------|
| [build-new-amazonlinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-amazonlinux.yaml) | amazonlinux, amazonlinux2, amazonlinux2022, amazonlinux2023 |
| [build-new-almalinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-almalinux.yaml) | almalinux |
| [build-new-bottlerocket.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-bottlerocket.yaml) | bottlerocket |
| [build-new-centos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-centos.yaml) | centos |
| [build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml) | debian |
| [build-new-fedora.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-fedora.yaml) | fedora |
| [build-new-minikube.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-minikube.yaml) | minikube |
| [build-new-photon.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-photon.yaml) | photon |
| [build-new-talos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-talos.yaml) | talos |
| [build-new-ubuntu-aws.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-aws.yaml) | ubuntu-aws |
| [build-new-ubuntu-azure.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-azure.yaml) | ubuntu-azure |
| [build-new-ubuntu-gcp.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gcp.yaml) | ubuntu-gcp |
| [build-new-ubuntu-generic.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-generic.yaml) | ubuntu-generic and related variants |
| [build-new-ubuntu-gke.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gke.yaml) | ubuntu-gke |

Each postsubmit job:

- Watches for changes matching `^driverkit/config/[a-z0-9.+-]{5,}/<arch>/<distro>_.+` on the `master` branch
- Runs the [build-drivers image](../../../refs/falcosecurity/test-infra/images/build-drivers/Dockerfile) (Docker-in-Docker with `dbg-go` v0.17.0)
- Executes [build-drivers.sh](../../../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh) with:
  - The distro name as the first argument (passed as `--target-distro`)
  - `PUBLISH_S3=true` to publish built drivers directly to S3 ([build-drivers.sh:68](../../../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh))
  - `--ignore-errors --skip-existing --redirect-errors=driverkit/output/failing.log` to handle failures gracefully ([build-drivers.sh:66](../../../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh))
- Uses Docker-in-Docker because driverkit builds drivers inside containers
- Runs on dedicated Kubernetes nodes with architecture-specific node selectors (`Archtype: "x86"` or `Archtype: "arm"`)
- Uses the `driver-kit` service account for S3 access
- Runs in privileged mode for Docker daemon access

**Source:** [build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml), [build-drivers.sh](../../../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh)

---

## Driver Distribution

### S3 Bucket

Built drivers are published to an S3 bucket:

- **S3 bucket source URL:** `https://falco-distribution.s3-eu-west-1.amazonaws.com/?list-type=2&prefix=driver`
- **Public download URL:** `https://download.falco.org/`

**Source:** [updateDriversWebsite.go:32-33](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go)

### S3 Path Structure

Drivers in S3 follow the path pattern:
```
driver/<driver_version>/<architecture>/falco_<target>_<kernelrelease>_<kernelversion>.<ext>
```

Where `<ext>` is `.ko` for kernel modules and `.o` for eBPF probes.

### Drivers Website

A browsable index of all pre-compiled drivers is available at:
**[https://download.falco.org/driver/site/index.html](https://download.falco.org/driver/site/index.html)**

The website is generated by the [update-drivers-website tool](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go), a Go program that:

1. Fetches the S3 bucket XML listing using pagination (`NextContinuationToken` for truncated results) ([updateDriversWebsite.go:112-187](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go))
2. Parses each S3 object key to extract: lib (driver version), arch, kind (ebpf/kmod), target, kernel ([updateDriversWebsite.go:134-161](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go))
3. Generates per-driver-version JSON files (e.g., `9.0.0+driver.json`) containing driver metadata
4. Generates an `index.json` listing all available driver versions
5. The JSON files are consumed by a static HTML page ([index.html](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/index.html)) that provides:
   - A DataTables-powered searchable/filterable table
   - Filter buttons for architecture (x86_64/aarch64), kind (ebpf/kmod), and target (distro)
   - A driver version selector dropdown
   - Direct download links for each driver

**Source:** [updateDriversWebsite.go](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go), [index.html](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/index.html)

---

## Prow Jobs for DBG

The DBG is orchestrated through three categories of Prow jobs:

### Periodic Job: update-dbg

| Field | Value |
|-------|-------|
| Name | `update-dbg` |
| Schedule | Daily at 08:00 UTC (`0 8 * * *`) |
| Image | `test-infra/update-dbg` |
| Purpose | Auto-generate configs from kernel-crawler, open PR |

**Source:** [config/jobs/update-dbg/update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-dbg/update-dbg.yaml)

### Presubmit Job: validate-dbg

| Field | Value |
|-------|-------|
| Name | `validate-dbg` |
| Trigger | PR changes to `driverkit/config/` |
| Image | `test-infra/build-drivers:latest` |
| Purpose | Validate config YAML files before merge |

**Source:** [config/jobs/build-drivers/validate-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml)

### Postsubmit Jobs: build-new-drivers-*

14 job files under [config/jobs/build-drivers/](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/) define per-distro build jobs. Each file typically contains 2+ job definitions (one per architecture, and some files cover multiple distro variants like `build-new-amazonlinux.yaml` which covers amazonlinux, amazonlinux2, amazonlinux2022, and amazonlinux2023).

Common pattern for each postsubmit job:
- **Branch:** `^master$`
- **Trigger:** `run_if_changed` with regex matching the distro prefix under the architecture directory
- **Image:** `test-infra/build-drivers:latest`
- **Command:** `/workspace/build-drivers.sh <distro>`
- **Environment:** `PUBLISH_S3=true`
- **Privileged:** `true` (Docker-in-Docker)
- **Resources:** 1 CPU / 4Gi memory limit, 750m CPU / 2Gi memory request
- **Service Account:** `driver-kit`

---

## Contributing Custom Drivers

Users can contribute configurations for unsupported kernels:

1. Fork the [test-infra](https://github.com/falcosecurity/test-infra) repository
2. Run `dbg-go configs generate --target-distro=<DISTRO> --target-kernelrelease=<RELEASE> --target-kernelversion=<VERSION>`
3. Validate with `dbg-go configs validate --target-distro=<DISTRO> --target-kernelrelease=<RELEASE> --target-kernelversion=<VERSION>`
4. Submit a PR to the upstream repository

**Source:** [driverkit/README.md:34-55](../../../refs/falcosecurity/test-infra/driverkit/README.md)

### Adding Support for a New Distro

Assuming kernel-crawler and driverkit already support the distro:

1. Add the Prow config under `config/jobs/build-drivers/` (copy an existing distro file and update references)
2. Update the `SupportedDistros` map in [dbg-go's distro.go](https://github.com/falcosecurity/dbg-go/blob/main/pkg/root/distro.go)
3. Request a new `dbg-go` release
4. Bump `dbg-go` in both `update-dbg` and `build-drivers` images

**Source:** [driverkit/README.md:76-83](../../../refs/falcosecurity/test-infra/driverkit/README.md)

---

## FAQ

**Where can I find the list of all pre-compiled drivers?**
Go to [https://download.falco.org/driver/site/index.html](https://download.falco.org/driver/site/index.html). ([driverkit/README.md:29](../../../refs/falcosecurity/test-infra/driverkit/README.md))

**What if Falco does not find a driver for my OS?**
Generate and contribute configs using `dbg-go configs generate`. ([driverkit/README.md:34-55](../../../refs/falcosecurity/test-infra/driverkit/README.md))

**How do I publish new drivers?**
With proper S3 permissions, run `dbg-go drivers publish`. ([driverkit/README.md:63-66](../../../refs/falcosecurity/test-infra/driverkit/README.md))

**How do I bump the driverkit version?**
Driverkit is a Go dependency of dbg-go; bump it there following [dbg-go's instructions](https://github.com/falcosecurity/dbg-go#bumping-driverkit). ([driverkit/README.md:72](../../../refs/falcosecurity/test-infra/driverkit/README.md))

---

## Related Components

- [driverkit.md](../driverkit.md) -- Driverkit: CLI tool and library for compiling kernel modules and eBPF probes
- [dbg-go.md](../dbg-go.md) -- dbg-go: Orchestration tool for config generation, building, and S3 publishing
- [kernel-crawler.md](../kernel-crawler.md) -- kernel-crawler: Kernel version discovery tool that feeds the DBG pipeline
- [prow-config.md](prow-config.md) -- Prow configuration: detailed coverage of all Prow jobs including DBG jobs

---

## Sources

| Topic | Source File |
|-------|-------------|
| DBG overview and FAQ | [driverkit/README.md](../../../refs/falcosecurity/test-infra/driverkit/README.md) |
| Build script | [images/build-drivers/build-drivers.sh](../../../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh) |
| Build image Dockerfile | [images/build-drivers/Dockerfile](../../../refs/falcosecurity/test-infra/images/build-drivers/Dockerfile) |
| Update-dbg entrypoint | [images/update-dbg/entrypoint.sh](../../../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh) |
| Update-dbg Dockerfile | [images/update-dbg/Dockerfile](../../../refs/falcosecurity/test-infra/images/update-dbg/Dockerfile) |
| Drivers website tool | [tools/update-drivers-website/updateDriversWebsite.go](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go) |
| Drivers website HTML | [tools/update-drivers-website/index.html](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/index.html) |
| Debian config sample | [driverkit/config/10.2.0+driver/aarch64/debian\_6.1.170-3-rt-arm64\_1.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml) |
| Amazon Linux config sample | [driverkit/config/9.0.0+driver/aarch64/amazonlinux2023\_6.1.102-108.177.amzn2023.aarch64\_1.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/9.0.0+driver/aarch64/amazonlinux2023_6.1.102-108.177.amzn2023.aarch64_1.yaml) |
| Ubuntu config sample | [driverkit/config/9.0.0+driver/x86_64/ubuntu-generic\_5.4.0-136-generic\_153.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/9.0.0+driver/x86_64/ubuntu-generic_5.4.0-136-generic_153.yaml) |
| Photon config sample | [driverkit/config/9.0.0+driver/aarch64/photon\_6.1.56-9.ph5\_1.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/9.0.0+driver/aarch64/photon_6.1.56-9.ph5_1.yaml) |
| Build jobs (Debian example) | [config/jobs/build-drivers/build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml) |
| Build jobs (Amazon Linux) | [config/jobs/build-drivers/build-new-amazonlinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-amazonlinux.yaml) |
| Validation presubmit job | [config/jobs/build-drivers/validate-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml) |
| Update-dbg periodic job | [config/jobs/update-dbg/update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-dbg/update-dbg.yaml) |
