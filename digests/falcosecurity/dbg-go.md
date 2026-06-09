# dbg-go Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/dbg-go/`](../../refs/falcosecurity/dbg-go/) | **Commit:** `06c74bc` (February 2, 2026)

**Repository:** [falcosecurity/dbg-go](https://github.com/falcosecurity/dbg-go)
**Scope:** Infra
**Status:** Incubating

Go tool to orchestrate the Falco Drivers Build Grid (DBG) - manages config generation, driver building, and S3 publishing.

---

## Overview

dbg-go is the orchestration layer for Falco's pre-built driver distribution system. It connects [kernel-crawler](kernel-crawler.md) output to [driverkit](driverkit.md) builds and manages the S3 bucket that serves drivers via download.falco.org.

**Name:** DBG = Drivers Build Grid

**Purpose:**
- Generate driverkit YAML configs from kernel-crawler JSON
- Build drivers using driverkit libraries (Docker-based)
- Publish built drivers to S3 for distribution
- Provide statistics and cleanup for both configs and drivers

**Source:** [`README.md`](../../refs/falcosecurity/dbg-go/README.md)

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        Falco Driver Build Pipeline                           │
└──────────────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────┐          ┌─────────────────────┐
 │   kernel-crawler    │          │      dbg-go         │
 │                     │          │                     │
 │ GitHub Pages JSON   │──fetch──▶│ configs generate    │
 │ list.json per arch  │          │   --auto            │
 └─────────────────────┘          └──────────┬──────────┘
                                             │
                                             ▼
                                  ┌─────────────────────┐
                                  │ test-infra repo     │
                                  │                     │
                                  │ driverkit/config/   │
                                  │ {version}/{arch}/   │
                                  │ distro_kr_kv.yaml   │
                                  └──────────┬──────────┘
                                             │
                                             ▼
                                  ┌─────────────────────┐
                                  │      dbg-go         │
                                  │                     │
                                  │ configs build       │
                                  │ (uses driverkit)    │
                                  └──────────┬──────────┘
                                             │
                                             ▼
                                  ┌─────────────────────┐
                                  │ driverkit/output/   │
                                  │ {version}/{arch}/   │
                                  │ falco_*.ko, *.o     │
                                  └──────────┬──────────┘
                                             │
                                             ▼
                                  ┌─────────────────────┐
                                  │      dbg-go         │
                                  │                     │
                                  │ drivers publish     │
                                  │ (or configs build   │
                                  │  --publish)         │
                                  └──────────┬──────────┘
                                             │
                                             ▼
                                  ┌─────────────────────┐
                                  │ S3: falco-distribution │
                                  │ driver/{ver}/{arch}/│
                                  └──────────┬──────────┘
                                             │
                                             ▼
                                  ┌─────────────────────┐
                                  │ download.falco.org  │
                                  │                     │
                                  │ falcoctl driver     │
                                  │ install             │
                                  └─────────────────────┘
```

**Source:** [`README.md`](../../refs/falcosecurity/dbg-go/README.md), [`pkg/generate/generate.go`](../../refs/falcosecurity/dbg-go/pkg/generate/generate.go)

## CLI Structure

```
dbg-go
├── configs              # Work with local driverkit configs
│   ├── generate         # Generate configs from kernel-crawler
│   ├── build            # Build drivers using driverkit
│   ├── validate         # Validate config files
│   ├── cleanup          # Remove config files
│   └── stats            # Statistics about configs
└── drivers              # Work with remote S3 drivers
    ├── publish          # Upload drivers to S3
    ├── cleanup          # Remove drivers from S3
    └── stats            # Statistics about remote drivers
```

**Source:** [`README.md`](../../refs/falcosecurity/dbg-go/README.md)

## Global Options

| Option | Description | Default |
|--------|-------------|---------|
| `--architecture` | Target arch: amd64, arm64 | amd64 |
| `--driver-name` | Driver name | falco |
| `--driver-version` | Driver version(s) to target | (required) |
| `--dry-run` | Preview without executing | false |
| `--repo-root` | Path to test-infra repository | current dir |
| `--target-distro` | Filter by distro (regex) | all |
| `--target-kernelrelease` | Filter by kernel release (regex) | all |
| `--target-kernelversion` | Filter by kernel version (regex) | all |

**Supported distros:** almalinux, amazonlinux, amazonlinux2, amazonlinux2022, amazonlinux2023, bottlerocket, centos, debian, fedora, minikube, talos, ubuntu

**Source:** [`README.md`](../../refs/falcosecurity/dbg-go/README.md)

## Config Generation

Generates driverkit YAML configs from kernel-crawler JSON output.

### Auto-generate from kernel-crawler

```shell
# Generate configs for all distros/kernels
./dbg-go configs generate --repo-root test-infra --auto

# Generate for specific distro
./dbg-go configs generate --repo-root test-infra --auto --target-distro ubuntu

# Generate for specific architecture
./dbg-go configs generate --repo-root test-infra --auto --architecture arm64
```

**Data source:** `https://falcosecurity.github.io/kernel-crawler/{arch}/list.json`

### Manual single config

```shell
./dbg-go configs generate \
    --repo-root test-infra \
    --target-distro centos \
    --target-kernelrelease 5.14.0-325.el9.x86_64 \
    --target-kernelversion 1
```

**Source:** [`pkg/generate/generate.go`](../../refs/falcosecurity/dbg-go/pkg/generate/generate.go), [`pkg/generate/constants.go`](../../refs/falcosecurity/dbg-go/pkg/generate/constants.go)

## Config File Format

Generated configs are driverkit YAML files:

```yaml
kernelversion: "1"
kernelrelease: 5.14.0-325.el9.x86_64
target: centos
architecture: amd64
kernelurls:
  - https://mirror.example.com/kernel-devel-5.14.0-325.el9.x86_64.rpm
output:
  module: output/5.0.1+driver/x86_64/falco_centos_5.14.0-325.el9.x86_64_1.ko
  probe: output/5.0.1+driver/x86_64/falco_centos_5.14.0-325.el9.x86_64_1.o
```

**Path format:** `{repo-root}/driverkit/config/{driver-version}/{arch}/{distro}_{kernelrelease}_{kernelversion}.yaml`

**Source:** [`pkg/root/constants.go`](../../refs/falcosecurity/dbg-go/pkg/root/constants.go)

## Driver Building

Builds drivers using driverkit's Docker-based build system.

```shell
# Build all configs for a driver version
./dbg-go configs build --repo-root test-infra --driver-version 5.0.1+driver

# Build and publish directly to S3
./dbg-go configs build --repo-root test-infra --driver-version 5.0.1+driver --publish

# Skip already-built drivers (checks S3)
./dbg-go configs build --repo-root test-infra --driver-version 5.0.1+driver --skip-existing

# Continue on errors (useful for batch builds)
./dbg-go configs build --repo-root test-infra --driver-version 5.0.1+driver --ignore-errors

# Redirect errors to file for later analysis
./dbg-go configs build --driver-version 5.0.1+driver --redirect-errors errors.log
```

**Output format:** `{repo-root}/driverkit/output/{driver-version}/{arch}/falco_{distro}_{kernelrelease}_{kernelversion}.{ko,o}`

**Source:** [`pkg/build/build.go`](../../refs/falcosecurity/dbg-go/pkg/build/build.go)

## S3 Operations

### Publishing Drivers

```shell
# Publish locally built drivers
./dbg-go drivers publish --repo-root test-infra --driver-version 5.0.1+driver

# Publish for arm64
./dbg-go drivers publish --repo-root test-infra --driver-version 5.0.1+driver --architecture arm64
```

**Required environment variables:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### S3 Structure

| Setting | Value |
|---------|-------|
| Bucket | `falco-distribution` |
| Region | `eu-west-1` |
| Path format | `driver/{version}/{arch}/{driver}_{distro}_{kernelrelease}_{kernelversion}.{ko,o}` |
| ACL | public-read |

**Example S3 path:** `driver/5.0.1+driver/x86_64/falco_ubuntu_5.4.0-150-generic_1.ko`

**Source:** [`pkg/utils/s3/s3utils.go`](../../refs/falcosecurity/dbg-go/pkg/utils/s3/s3utils.go)

### Statistics and Cleanup

```shell
# Local config stats
./dbg-go configs stats --repo-root test-infra

# Remote driver stats
./dbg-go drivers stats --driver-version 5.0.1+driver

# Cleanup local configs (dry-run first)
./dbg-go configs cleanup --repo-root test-infra --dry-run
./dbg-go configs cleanup --repo-root test-infra

# Cleanup remote drivers
./dbg-go drivers cleanup --driver-version 5.0.1+driver --target-distro deprecated-distro
```

**Source:** [`pkg/stats/stats.go`](../../refs/falcosecurity/dbg-go/pkg/stats/stats.go), [`pkg/cleanup/cleanup.go`](../../refs/falcosecurity/dbg-go/pkg/cleanup/cleanup.go)

## Integration with Falco Ecosystem

dbg-go is the central orchestration tool in the driver build pipeline:

```
kernel-crawler ──▶ dbg-go ──▶ driverkit ──▶ S3 ──▶ falcoctl
   (discover)      (orchestrate)  (build)   (store)   (install)
```

**Inputs:**
- kernel-crawler JSON (kernel versions and header URLs)
- test-infra repository (working directory for configs/outputs)
- driverkit (library dependency for building)

**Outputs:**
- Driverkit YAML config files
- Kernel modules (.ko) and eBPF probes (.o)
- S3 uploads to falco-distribution bucket

**Related repositories:**
- **[kernel-crawler](https://github.com/falcosecurity/kernel-crawler)** - Provides kernel list JSON
- **[driverkit](https://github.com/falcosecurity/driverkit)** - Used as library for building
- **[test-infra](https://github.com/falcosecurity/test-infra)** - CI/CD that uses dbg-go
- **[falcoctl](https://github.com/falcosecurity/falcoctl)** - Downloads drivers from S3

**Source:** [`README.md`](../../refs/falcosecurity/dbg-go/README.md)

## Development

### Building

```shell
make build
```

### Testing

```shell
make test
```

### Bumping driverkit

```shell
make bump-driverkit DRIVERKIT_VER=vX.Y.Z
```

**Source:** [`README.md`](../../refs/falcosecurity/dbg-go/README.md)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, CLI | [`README.md`](../../refs/falcosecurity/dbg-go/README.md) |
| Config generation | [`pkg/generate/generate.go`](../../refs/falcosecurity/dbg-go/pkg/generate/generate.go) |
| Driver building | [`pkg/build/build.go`](../../refs/falcosecurity/dbg-go/pkg/build/build.go) |
| S3 operations | [`pkg/utils/s3/s3utils.go`](../../refs/falcosecurity/dbg-go/pkg/utils/s3/s3utils.go) |
| Publishing | [`pkg/publish/publish.go`](../../refs/falcosecurity/dbg-go/pkg/publish/publish.go) |
| Path formats | [`pkg/root/constants.go`](../../refs/falcosecurity/dbg-go/pkg/root/constants.go) |

## Related Documentation

- [`kernel-crawler.md`](kernel-crawler.md) - Kernel version discovery (input source)
- [`driverkit.md`](driverkit.md) - Driver build tool (library dependency)
- [`falcoctl.md`](falcoctl.md) - Driver installation (`falcoctl driver install`)
- [`libs/kernel-instrumentation.md`](libs/kernel-instrumentation.md) - Driver architecture
- [`evolution.md`](evolution.md) - Infra scope repositories
