# kernel-crawler Digest

> **Era Relevance:** 0.45 | **Source:** [`refs/falcosecurity/kernel-crawler/`](../../refs/falcosecurity/kernel-crawler/). Use `git submodule status` for the pinned revision.

**Repository:** [falcosecurity/kernel-crawler](https://github.com/falcosecurity/kernel-crawler)
**Scope:** Infra
**Status:** Incubating

Tool to crawl Linux distribution repositories and discover available kernel versions for Falco driver building.

---

## Overview

kernel-crawler is a critical infrastructure component that enables Falco's pre-built driver distribution system. It crawls package repositories of supported Linux distributions to discover all available kernel versions and their header packages, then generates [driverkit](https://github.com/falcosecurity/driverkit)-compatible configuration files.

**Purpose:**
- Discover all kernel versions available across major Linux distributions
- Generate driverkit configuration JSON for automated driver building
- Enable the Falco project to pre-build kernel modules for many kernels

**Source:** [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md)

## Why This Exists

This pipeline supplies kernel-specific modules. Falco also embeds the modern eBPF driver, which does not require this download/build pipeline. [Source](../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/_index.md#L16-L39). For kernel modules, users have three options:

1. **Pre-built drivers** - Download from Falco's driver repository
2. **Dynamic build** - Build on the host at runtime (requires kernel headers)
3. **Custom build** - Use driverkit to build manually

For option 1 to work at scale, the Falco project must know which kernels exist across all major distributions. kernel-crawler solves this by:

1. Crawling distribution package repositories
2. Extracting kernel package information and header URLs
3. Generating driverkit configs for each kernel
4. Enabling automated driver builds via CI/CD

**Source:** [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md)

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Falco Driver Build Pipeline                   │
└──────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────┐          ┌─────────────────────┐
 │  Linux Distro Repos │          │   kernel-crawler    │
 │                     │          │                     │
 │  - Ubuntu mirrors   │──crawl──▶│  - Discover kernels │
 │  - Debian repos     │          │  - Extract headers  │
 │  - Amazon Linux     │          │  - Generate JSON    │
 │  - CentOS/RHEL      │          └──────────┬──────────┘
 │  - Fedora           │                     │
 │  - ... (19 distros) │                     ▼
 └─────────────────────┘          ┌─────────────────────┐
                                  │  GitHub Pages       │
                                  │  (kernel list.json) │
                                  └──────────┬──────────┘
                                             │
                                             ▼
                                  ┌─────────────────────┐
                                  │  test-infra (Prow)  │
                                  │                     │
                                  │  - Generate configs │
                                  │  - Build drivers    │
                                  └──────────┬──────────┘
                                             │
                                             ▼
                                  ┌─────────────────────┐
                                  │   driverkit        │
                                  │                     │
                                  │  - Build .ko       │
                                  │  - Publish to S3   │
                                  └─────────────────────┘
```

**Automation Flow:**
1. Daily GitHub Action runs kernel-crawler for x86_64 and aarch64
2. Output JSON published to GitHub Pages
3. Prow job in test-infra detects updates
4. Creates PR with new driverkit configs
5. driverkit builds drivers for new kernels
6. Pre-built drivers uploaded to download.falco.org

**Source:** [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md), [`.github/workflows/update-kernels.yml`](../../refs/falcosecurity/kernel-crawler/.github/workflows/update-kernels.yml)

## Supported Distributions

| Distro Key | Distribution | Package Format |
|------------|--------------|----------------|
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

**Source:** [`kernel_crawler/crawler.py:43-63`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/crawler.py#L43-L63)

## Output Format

kernel-crawler generates JSON compatible with driverkit:

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
  ],
  "amazonlinux2": [
    {
      "kernelversion": "1",
      "kernelrelease": "4.14.320-243.544.amzn2.x86_64",
      "target": "amazonlinux2",
      "headers": [
        "https://cdn.amazonlinux.com/2/core/2.0/x86_64/.../kernel-devel-4.14.320-243.544.amzn2.x86_64.rpm"
      ]
    }
  ]
}
```

**DriverKitConfig Fields:**
- `kernelversion` - Kernel version string (usually "1")
- `kernelrelease` - Full kernel release string (e.g., `5.4.0-150-generic`)
- `target` - driverkit target identifier (e.g., `ubuntu-generic`, `amazonlinux2`)
- `headers` - URLs to kernel header packages

**Source:** [`kernel_crawler/repo.py:27-41`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/repo.py#L27-L41)

## CLI Usage

```shell
# Install
pip3 install .

# Crawl all distros for x86_64 (default)
kernel-crawler crawl --distro=*

# Crawl specific distro
kernel-crawler crawl --distro=ubuntu

# Crawl for aarch64
kernel-crawler crawl --distro=amazonlinux2 --arch=aarch64

# Crawl Red Hat (requires container image)
kernel-crawler crawl --distro=redhat --image=redhat/ubi8:registered

# Output to file
kernel-crawler crawl --distro=debian --output=debian-kernels.json

# Debug mode
kernel-crawler --debug crawl --distro=fedora
```

**Source:** [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md), [`kernel_crawler/main.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/main.py)

## GitHub Action Usage

```yaml
- name: Crawl kernels
  uses: falcosecurity/kernel-crawler@main
  with:
    arch: 'x86_64'      # or 'aarch64'
    distro: 'ubuntu'    # or '*' for all
```

**Note:** Use exact tag/branch/commit references (not semantic versions like `@v0`).

**Source:** [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md)

## Published Kernel Lists

The daily crawl results are published to GitHub Pages:

- **x86_64:** https://falcosecurity.github.io/kernel-crawler/x86_64/list.json
- **aarch64:** https://falcosecurity.github.io/kernel-crawler/aarch64/list.json

These URLs are consumed by:
- test-infra Prow jobs for driver building
- driverkit for kernel header resolution
- Users wanting to check kernel support

**Source:** [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md)

## Docker Image

```shell
# Pull from Docker Hub
docker pull falcosecurity/kernel-crawler:latest

# Build locally
docker build -t falcosecurity/kernel-crawler -f docker/Dockerfile .
```

**Source:** [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md)

## How Distribution Crawlers Work

### DEB-based (Ubuntu, Debian)

Crawls mirror URLs for `linux-headers-*` packages:
- Parses `Packages.gz` from repository indices
- Extracts header package URLs
- Groups by kernel version and flavor (generic, aws, oracle, etc.)

**Example mirrors:**
- `http://mirrors.edge.kernel.org/ubuntu/`
- `http://security.ubuntu.com/ubuntu/`
- `http://deb.debian.org/debian/`

**Source:** [`kernel_crawler/ubuntu.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/ubuntu.py), [`kernel_crawler/deb.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/deb.py)

The package-index parser decodes invalid UTF-8 with replacement, allowing historical indexes with non-UTF-8 metadata to be processed. Debian catches failures while loading each repository's package database, logs the error and continues collecting other repositories before dependency resolution. This does not guarantee that the resulting list covers every repository. [Parser](../../refs/falcosecurity/kernel-crawler/kernel_crawler/deb.py#L50-L62), [decoder](../../refs/falcosecurity/kernel-crawler/kernel_crawler/utils/py23.py#L8-L12), [Debian collection](../../refs/falcosecurity/kernel-crawler/kernel_crawler/debian.py#L46-L65).

### RPM-based (Amazon Linux, CentOS, Fedora, etc.)

Crawls YUM/DNF repositories for kernel packages. The base RPM repository implementation reads `repomd.xml` and prefers `primary_db` SQLite metadata, which resolves transitive package dependencies. If the repository does not advertise `primary_db`, it falls back to `primary` XML. An advertised SQLite database that cannot be fetched does not trigger this fallback. [Selection and collection](../../refs/falcosecurity/kernel-crawler/kernel_crawler/rpm.py#L141-L174), [SQLite dependency query](../../refs/falcosecurity/kernel-crawler/kernel_crawler/rpm.py#L74-L91).

The XML path returns only matching kernel packages, without transitive dependencies. Its version filter accepts either a version or a version-release pair, and it clears processed XML elements as it scans. Subclasses with different package selection must implement `kernel_package_match()` as well as their SQL predicate; Oracle and Photon provide these overrides. [XML parser](../../refs/falcosecurity/kernel-crawler/kernel_crawler/rpm.py#L94-L121), [selection contract](../../refs/falcosecurity/kernel-crawler/kernel_crawler/rpm.py#L51-L62), [Oracle](../../refs/falcosecurity/kernel-crawler/kernel_crawler/oracle.py#L19-L28), [Photon](../../refs/falcosecurity/kernel-crawler/kernel_crawler/photon.py#L18-L32).

**Source:** [`kernel_crawler/rpm.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/rpm.py), [`kernel_crawler/amazonlinux.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/amazonlinux.py)

### Git-based (Flatcar, Bottlerocket, Minikube, Talos)

Fetches kernel configs from Git repositories:
- Queries GitHub/GitLab APIs
- Downloads kernel configurations
- Extracts version information from manifest files

**Source:** [`kernel_crawler/flatcar.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/flatcar.py), [`kernel_crawler/bottlerocket.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/bottlerocket.py)

### Container-based (Red Hat)

For RHEL, kernel information is extracted from container images:
- Requires a registered RHEL container image
- Runs `rpm -qa kernel-devel*` inside container
- Extracts kernel versions from installed packages

**Source:** [`kernel_crawler/redhat.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/redhat.py)

## Integration with Falco Ecosystem

```
kernel-crawler ──▶ test-infra ──▶ driverkit ──▶ download.falco.org
                       │
                       ▼
                  driver configs
                  (falcosecurity/test-infra/driverkit/)
```

**Related repositories:**
- **[driverkit](https://github.com/falcosecurity/driverkit)** - Builds drivers using crawler output
- **[test-infra](https://github.com/falcosecurity/test-infra)** - CI/CD pipeline for driver builds
- **[libs](https://github.com/falcosecurity/libs)** - Driver source code (kernel module, eBPF)

**Source:** [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, usage | [`README.md`](../../refs/falcosecurity/kernel-crawler/README.md) |
| CLI entry point | [`kernel_crawler/main.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/main.py) |
| Crawler logic | [`kernel_crawler/crawler.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/crawler.py) |
| Base classes | [`kernel_crawler/repo.py`](../../refs/falcosecurity/kernel-crawler/kernel_crawler/repo.py) |
| Update workflow | [`.github/workflows/update-kernels.yml`](../../refs/falcosecurity/kernel-crawler/.github/workflows/update-kernels.yml) |

## Related Documentation

- [`driverkit.md`](driverkit.md) - Driver build tool (consumes crawler output)
- [`libs/kernel-instrumentation.md`](libs/kernel-instrumentation.md) - Driver architecture
- [`evolution.md`](evolution.md) - Infra scope repositories
- [`falcoctl.md`](falcoctl.md) - Driver installation (`falcoctl driver install`)
