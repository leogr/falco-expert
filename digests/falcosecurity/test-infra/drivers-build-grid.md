# Falco Test Infrastructure — Drivers Build Grid (DBG)

> **Era:** 0.45 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

## Overview

The Drivers Build Grid (DBG) is the infrastructure system within [test-infra](https://github.com/falcosecurity/test-infra) that pre-compiles Falco kernel modules (`.ko`) for thousands of kernel versions across distributions and architectures. Historical eBPF probes (`.o`) remain in the distribution archive. These pre-built drivers allow Falco users to run with kernel-level instrumentation without compiling drivers themselves.

The DBG relies heavily on the [`dbg-go`](https://github.com/falcosecurity/dbg-go) tool, a Go-based CLI that orchestrates config generation, validation, building, and S3 publishing. The `dbg-go` tool uses [driverkit](https://github.com/falcosecurity/driverkit) as a Go library for the actual driver compilation.

**Source:** [driverkit/README.md](../../../refs/falcosecurity/test-infra/driverkit/README.md)

### Key Capabilities of dbg-go

- Generate configs (single or auto-generation from [kernel-crawler](https://github.com/falcosecurity/kernel-crawler) output)
- Cleanup, validate, and fetch stats about configs
- Build configs using driverkit as a library
- Cleanup, publish, and fetch stats about S3 drivers

**Source:** [driverkit/README.md:10-20](../../../refs/falcosecurity/test-infra/driverkit/README.md#L10-L20)

---

## Config Structure

Driverkit build configurations are stored in a strict directory hierarchy:

```
driverkit/config/<driver_version>/<architecture>/<distro>_<kernel_release>_<build_version>.yaml
```

**Source:** [driverkit/README.md:50](../../../refs/falcosecurity/test-infra/driverkit/README.md#L50)

### Supported Driver Versions

The pinned 0.45 source tree contains two driver lines. These counts measure committed configurations, not successfully published artifacts.

| Driver Version | x86_64 Configs | aarch64 Configs | Total |
|---------------|---------------|----------------|-------|
| `10.2.0+driver` | 6,983 | 4,736 | 11,719 |
| `11.0.0+driver` (Falco 0.45.0) | 6,983 | 4,736 | 11,719 |
| **Total** | **13,966** | **9,472** | **23,438** |

**Source:** counted YAML files under [the pinned configuration tree](../../../refs/falcosecurity/test-infra/driverkit/config/) at commit `73501a21f91f07dbb06f98f167d66b2a0d7d7605`. The 9.0, 9.1, 10.0 and 10.1 lines were removed between the 0.44 and 0.45 pins; this does not imply removal of their published artifacts.

### Supported Architectures

Each currently configured driver version has two architecture directories:

- **x86_64** (mapped to driverkit `amd64`)
- **aarch64** (mapped to driverkit `arm64`)

### Supported Distro Targets

The following unique distro targets exist across the build grid (union of x86_64 and aarch64, counted from the pinned [configuration tree](../../../refs/falcosecurity/test-infra/driverkit/config/)):

| Category | Targets |
|----------|---------|
| Amazon Linux | `amazonlinux2`, `amazonlinux2022`, `amazonlinux2023` |
| AlmaLinux / CentOS | `almalinux`, `centos` |
| Debian | `debian` |
| Fedora | `fedora` |
| Minikube | `minikube` |
| Photon OS | `photon` |
| Ubuntu (generic) | `ubuntu-generic`, `ubuntu-hwe`, `ubuntu-lowlatency`, `ubuntu-lts`, `ubuntu-oem`, `ubuntu-realtime`, `ubuntu-vmware` |
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
| `output.probe` | Historical field in older grid examples; current configs and Driverkit builds use `output.module` |
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

> The following three examples are historical 0.44 snapshots; their driver line has been retired from the 0.45 build configuration tree.

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

**Source:** [amazonlinux2023\_6.1.102-108.177.amzn2023.aarch64\_1.yaml](https://github.com/falcosecurity/test-infra/blob/405120f4ae99e7b90469685acb27319e2b77f5d9/driverkit/config/9.0.0+driver/aarch64/amazonlinux2023_6.1.102-108.177.amzn2023.aarch64_1.yaml)

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

**Source:** [ubuntu-generic\_5.4.0-136-generic\_153.yaml](https://github.com/falcosecurity/test-infra/blob/405120f4ae99e7b90469685acb27319e2b77f5d9/driverkit/config/9.0.0+driver/x86_64/ubuntu-generic_5.4.0-136-generic_153.yaml)

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

**Source:** [photon\_6.1.56-9.ph5\_1.yaml](https://github.com/falcosecurity/test-infra/blob/405120f4ae99e7b90469685acb27319e2b77f5d9/driverkit/config/9.0.0+driver/aarch64/photon_6.1.56-9.ph5_1.yaml)

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

### 2. Config Generation (OCI periodic)

`update-dbg` runs daily at 08:00 UTC in the `driverkit-x86` queue, using `ghcr.io/falcosecurity/test-infra/update-dbg:0.18.0-1`. Its image embeds DBG 0.18.0. The entrypoint cleans up and regenerates configs for amd64 and arm64 from crawler data, then creates a signed `update/dbg` PR if the worktree changed. The upstream grid guide documents that removed configs do not delete already published drivers.

**Sources:** [config/jobs/oci/update-dbg/update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml#L1), [images/update-dbg/Dockerfile](../../../refs/falcosecurity/test-infra/images/update-dbg/Dockerfile#L1), [images/update-dbg/entrypoint.sh](../../../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh#L34), [driverkit/README.md](../../../refs/falcosecurity/test-infra/driverkit/README.md#L57).

### 3. Config Validation and Driver Builds


OCI schedules **71 driver postsubmits across 14 distro files**, plus the `validate-dbg` presubmit. They build kernel modules; older `.o` probes may remain in the distribution archive. Job presence does not imply that a distro currently has configs or that every configured kernel builds successfully.

**Build contract:** changes to matching driver configs on `master` trigger the corresponding distro/architecture job. Each job has `max_concurrency: 1`; the `driverkit-x86` and `driverkit-arm` queues each allow four jobs. Builds use digest-pinned `ghcr.io/falcosecurity/dbg-go:0.18.0`, running `configs build` with `--skip-existing --publish --ignore-errors --redirect-errors=/logs/artifacts/failing.log` and architecture/distro/kernel filters. Build results are best effort: missing prebuilt modules are acceptable, and the failure artifact distinguishes partial coverage from a complete build.

The non-root builder runs as UID/GID 65532. A separate, digest-pinned Docker 29.8.1 native sidecar is privileged and shares only its Unix socket with the builder. Jobs select `Application: driverkit` and the matching CPU architecture, tolerate `dedicated.falco.org/driverkit=true:NoSchedule`, and use `driver-kit` with automatic service-account token mounting disabled. Publication explicitly projects an `sts.amazonaws.com` token and assumes AWS role `falco-prow-driver-publisher` in `eu-west-1`.

**Sources:** [config/jobs/oci/build-drivers/build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L1), [config/prow/oci/config.yaml](../../../refs/falcosecurity/test-infra/config/prow/oci/config.yaml#L37), [config/jobs/oci/kustomization.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1).

| Distro file | Postsubmits | Partitioning |
|-------------|-------------|--------------|
| [build-new-almalinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-almalinux.yaml#L1) | 2 | per-target architecture variants |
| [build-new-amazonlinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-amazonlinux.yaml#L1) | 8 | per-target architecture variants |
| [build-new-bottlerocket.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-bottlerocket.yaml#L1) | 2 | per-target architecture variants |
| [build-new-centos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-centos.yaml#L1) | 9 | x86 kernel majors 2–6; ARM majors 3–6 |
| [build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L1) | 2 | per-target architecture variants |
| [build-new-fedora.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-fedora.yaml#L1) | 2 | per-target architecture variants |
| [build-new-minikube.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-minikube.yaml#L1) | 2 | per-target architecture variants |
| [build-new-photon.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-photon.yaml#L1) | 2 | per-target architecture variants |
| [build-new-talos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-talos.yaml#L1) | 2 | per-target architecture variants |
| [build-new-ubuntu-aws.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-aws.yaml#L1) | 8 | kernel majors 3–6, both architectures |
| [build-new-ubuntu-azure.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-azure.yaml#L1) | 8 | kernel majors 3–6, both architectures |
| [build-new-ubuntu-gcp.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-gcp.yaml#L1) | 8 | kernel majors 3–6, both architectures |
| [build-new-ubuntu-generic.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-generic.yaml#L1) | 8 | kernel majors 3–6, both architectures |
| [build-new-ubuntu-gke.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-gke.yaml#L1) | 8 | kernel majors 3–6, both architectures |

`validate-dbg` runs two unprivileged containers (`configs validate --architecture=amd64` and `arm64`) using the same DBG image. It has no Docker daemon, publication flag or AWS publisher token. Each validator requests 250m CPU/256Mi and limits 1 CPU/2Gi; those are distinct from the build resources.

**Source:** [config/jobs/oci/build-drivers/validate-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/validate-dbg.yaml#L1).


The previous AWS build wrappers and distro jobs are retained under [the backup catalog](../../../refs/falcosecurity/test-infra/config/backup/aws/jobs/build-drivers/); they are not part of either active job-loading path. Current OCI jobs invoke DBG directly instead of the historical `build-drivers.sh` wrapper.

## Driver Distribution

### S3 Bucket

Built drivers are published to an S3 bucket:

- **S3 bucket source URL:** `https://falco-distribution.s3-eu-west-1.amazonaws.com/?list-type=2&prefix=driver`
- **Public download URL:** `https://download.falco.org/`

**Source:** [updateDriversWebsite.go:32-33](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go#L32-L33)

### S3 Path Structure

Drivers in S3 follow the path pattern:
```
driver/<driver_version>/<architecture>/falco_<target>_<kernelrelease>_<kernelversion>.<ext>
```

Current builds publish `.ko` modules; `.o` names describe historical eBPF probes still understood by the archive indexer. Modern eBPF is shipped with Falco rather than built for each grid kernel. See [Driverkit output options](../../../refs/falcosecurity/driverkit/cmd/root_options.go#L31) and [the Driverkit digest](../driverkit.md).

### Drivers Website

A browsable index of all pre-compiled drivers is available at:
**[https://download.falco.org/driver/site/index.html](https://download.falco.org/driver/site/index.html)**

The website is generated by the [update-drivers-website tool](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go), a Go program that:

1. Fetches the S3 bucket XML listing using pagination (`NextContinuationToken` for truncated results) ([updateDriversWebsite.go:112-187](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go#L112-L187))
2. Parses each S3 object key to extract: lib (driver version), arch, kind (ebpf/kmod), target, kernel ([updateDriversWebsite.go:134-161](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go#L134-L161))
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

The current OCI catalog defines `update-dbg` (daily 08:00 UTC), `validate-dbg` (config-change presubmit), and 71 `build-new-drivers-*` postsubmits. See [Config Validation and Driver Builds](#3-config-validation-and-driver-builds) for scheduling, images and permissions. The AWS backup catalog is historical.

**Source:** [config/jobs/oci/kustomization.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1).

## Contributing Custom Drivers

Users can contribute configurations for unsupported kernels:

1. Fork the [test-infra](https://github.com/falcosecurity/test-infra) repository
2. Run `dbg-go configs generate --target-distro=<DISTRO> --target-kernelrelease=<RELEASE> --target-kernelversion=<VERSION>`
3. Validate with `dbg-go configs validate --target-distro=<DISTRO> --target-kernelrelease=<RELEASE> --target-kernelversion=<VERSION>`
4. Submit a PR to the upstream repository

**Source:** [driverkit/README.md:34-55](../../../refs/falcosecurity/test-infra/driverkit/README.md#L34-L55)

### Adding Support for a New Distro

Kernel-crawler, Driverkit and DBG must support the target. Add or update the OCI distro job and its Kustomize catalog entry, release the needed DBG changes, then update the digest-pinned build/validation image and the updater image. The upstream grid guide still describes the older AWS image workflow; use current OCI manifests for deployment details.

**Sources:** [driverkit/README.md](../../../refs/falcosecurity/test-infra/driverkit/README.md#L76), [config/jobs/oci/kustomization.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1), [config/jobs/oci/build-drivers/build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L77), [images/update-dbg/Dockerfile](../../../refs/falcosecurity/test-infra/images/update-dbg/Dockerfile#L1).

## FAQ

**Where can I find the list of all pre-compiled drivers?**
Go to [https://download.falco.org/driver/site/index.html](https://download.falco.org/driver/site/index.html). ([driverkit/README.md:29](../../../refs/falcosecurity/test-infra/driverkit/README.md#L29))

**What if Falco does not find a driver for my OS?**
Generate and contribute configs using `dbg-go configs generate`. ([driverkit/README.md:34-55](../../../refs/falcosecurity/test-infra/driverkit/README.md#L34-L55))

**How do I publish new drivers?**
With proper S3 permissions, run `dbg-go drivers publish`. ([driverkit/README.md:63-66](../../../refs/falcosecurity/test-infra/driverkit/README.md#L63-L66))

**How do I bump the driverkit version?**
Driverkit is a Go dependency of dbg-go; bump it there following [dbg-go's instructions](https://github.com/falcosecurity/dbg-go#bumping-driverkit). ([driverkit/README.md:72](../../../refs/falcosecurity/test-infra/driverkit/README.md#L72))

---

## Related Components

- [driverkit.md](../driverkit.md) -- Driverkit: CLI tool and library for compiling kernel modules
- [dbg-go.md](../dbg-go.md) -- dbg-go: Orchestration tool for config generation, building, and S3 publishing
- [kernel-crawler.md](../kernel-crawler.md) -- kernel-crawler: Kernel version discovery tool that feeds the DBG pipeline
- [prow-config.md](prow-config.md) -- Prow configuration: detailed coverage of all Prow jobs including DBG jobs

---

## Sources

| Topic | Source File |
|-------|-------------|
| DBG overview and FAQ | [driverkit/README.md](../../../refs/falcosecurity/test-infra/driverkit/README.md) |
| Historical AWS build script | [images/build-drivers/build-drivers.sh](../../../refs/falcosecurity/test-infra/images/build-drivers/build-drivers.sh) |
| Historical AWS build image | [images/build-drivers/Dockerfile](../../../refs/falcosecurity/test-infra/images/build-drivers/Dockerfile) |
| Update-dbg entrypoint | [images/update-dbg/entrypoint.sh](../../../refs/falcosecurity/test-infra/images/update-dbg/entrypoint.sh) |
| Update-dbg Dockerfile | [images/update-dbg/Dockerfile](../../../refs/falcosecurity/test-infra/images/update-dbg/Dockerfile) |
| Drivers website tool | [tools/update-drivers-website/updateDriversWebsite.go](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go) |
| Drivers website HTML | [tools/update-drivers-website/index.html](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/index.html) |
| Debian config sample | [driverkit/config/10.2.0+driver/aarch64/debian\_6.1.170-3-rt-arm64\_1.yaml](../../../refs/falcosecurity/test-infra/driverkit/config/10.2.0+driver/aarch64/debian_6.1.170-3-rt-arm64_1.yaml) |
| Amazon Linux config sample | [driverkit/config/9.0.0+driver/aarch64/amazonlinux2023\_6.1.102-108.177.amzn2023.aarch64\_1.yaml](https://github.com/falcosecurity/test-infra/blob/405120f4ae99e7b90469685acb27319e2b77f5d9/driverkit/config/9.0.0+driver/aarch64/amazonlinux2023_6.1.102-108.177.amzn2023.aarch64_1.yaml) |
| Ubuntu config sample | [driverkit/config/9.0.0+driver/x86_64/ubuntu-generic\_5.4.0-136-generic\_153.yaml](https://github.com/falcosecurity/test-infra/blob/405120f4ae99e7b90469685acb27319e2b77f5d9/driverkit/config/9.0.0+driver/x86_64/ubuntu-generic_5.4.0-136-generic_153.yaml) |
| Photon config sample | [driverkit/config/9.0.0+driver/aarch64/photon\_6.1.56-9.ph5\_1.yaml](https://github.com/falcosecurity/test-infra/blob/405120f4ae99e7b90469685acb27319e2b77f5d9/driverkit/config/9.0.0+driver/aarch64/photon_6.1.56-9.ph5_1.yaml) |
| Build jobs (Debian example) | [config/jobs/oci/build-drivers/build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml) |
| Build jobs (Amazon Linux) | [config/jobs/oci/build-drivers/build-new-amazonlinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-amazonlinux.yaml) |
| Validation presubmit job | [config/jobs/oci/build-drivers/validate-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/validate-dbg.yaml) |
| Update-dbg periodic job | [config/jobs/oci/update-dbg/update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml) |
