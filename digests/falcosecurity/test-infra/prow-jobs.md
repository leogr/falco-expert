# Falco Test Infrastructure -- Prow Job Catalog

> **Era:** 0.44 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

This digest catalogs all Prow CI/CD jobs defined in the `falcosecurity/test-infra` repository. The Falco project uses [Prow](https://docs.prow.k8s.io/docs/), the Kubernetes-native CI/CD system, to automate builds, testing, organization management, and infrastructure maintenance across the entire `falcosecurity` GitHub organization.

---

## Table of Contents

1. [Job Types Overview](#1-job-types-overview)
2. [How to Add Jobs](#2-how-to-add-jobs)
3. [Complete Job Catalog](#3-complete-job-catalog)
   - [build-drivers](#31-build-drivers)
   - [build-plugins](#32-build-plugins)
   - [build-prow-images](#33-build-prow-images)
   - [build-aws-terraform](#34-build-aws-terraform)
   - [check-prow-config](#35-check-prow-config)
   - [update-jobs](#36-update-jobs)
   - [update-dbg](#37-update-dbg)
   - [update-maintainers](#38-update-maintainers)
   - [update-rules-index](#39-update-rules-index)
   - [update-falco-k8s-manifests](#310-update-falco-k8s-manifests)
   - [update-github-teams](#311-update-github-teams)
   - [peribolos](#312-peribolos)
   - [branchprotector](#313-branchprotector)
   - [autobump](#314-autobump)
   - [lifecycle-bot](#315-lifecycle-bot)
   - [recurring-ghissues](#316-recurring-ghissues)
4. [Config Uploader Tool](#4-config-uploader-tool)
5. [Job Configuration Patterns](#5-job-configuration-patterns)

---

## 1. Job Types Overview

Prow supports three fundamental job types, each triggered by different events. The following summarizes how each type is used in the Falco infrastructure. **Source:** [config/jobs/README.md](../../../refs/falcosecurity/test-infra/config/jobs/README.md)

### Presubmit Jobs

Presubmit jobs run **before a PR is merged** (i.e., on pull request events). They are configured per-repository and triggered by the `hook` component when GitHub webhooks arrive. Key properties:

- Triggered when a PR is opened or updated against the specified `branches` (typically `^master$` or `^main$`)
- Can be scoped with `run_if_changed` to only trigger when specific file paths are modified
- Can be set to `always_run: true` to run on every PR regardless of changed files
- Results are reported back to GitHub as commit status checks (unless `skip_report: true`)
- Can be manually re-triggered with `/test <job-name>` comments ([README.md:116-118](../../../refs/falcosecurity/test-infra/config/jobs/README.md))

### Postsubmit Jobs

Postsubmit jobs run **after a PR is merged** (i.e., on push events to the target branch). They are configured per-repository under a `postsubmits:` key with the format `org/repo:`. Key properties:

- Triggered on pushes to matching `branches`
- Can use `run_if_changed` to scope which file changes trigger the job
- Often used for publishing, deploying, or syncing operations that should only happen on the canonical branch
- `max_concurrency` can limit parallel runs ([README.md:69-84](../../../refs/falcosecurity/test-infra/config/jobs/README.md))

### Periodic Jobs

Periodic jobs run on a **schedule**, independent of any repository event. They are scheduled by the `horologium` component. Key properties:

- Triggered by either a `cron` expression (e.g., `"0 8 * * *"`) or an `interval` (e.g., `1h`, `6h`, `24h`)
- Use `extra_refs` to check out a repository into the workspace before execution
- Not tied to a specific repository push event
- Used for maintenance tasks: org syncing, stale issue management, config checks, manifest updates ([README.md:43-65](../../../refs/falcosecurity/test-infra/config/jobs/README.md))

### Prow Components Involved

| Component | Role | Source |
|-----------|------|--------|
| `horologium` | Schedules periodic jobs | [README.md:6](../../../refs/falcosecurity/test-infra/config/jobs/README.md) |
| `hook` | Schedules presubmit and postsubmit jobs from GitHub webhooks | [README.md:7](../../../refs/falcosecurity/test-infra/config/jobs/README.md) |
| `prow-controller-manager` | Schedules the Kubernetes pod for a ProwJob | [README.md:9](../../../refs/falcosecurity/test-infra/config/jobs/README.md) |
| `crier` | Reports job status back to GitHub | [README.md:10](../../../refs/falcosecurity/test-infra/config/jobs/README.md) |

---

## 2. How to Add Jobs

**Source:** [config/jobs/README.md](../../../refs/falcosecurity/test-infra/config/jobs/README.md)

To add a new job:

1. **Create a new subdirectory** under `config/jobs/` named after the job category (e.g., `test-driver/`)
2. **Add a YAML job definition** inside that directory (e.g., `test-driver.yaml`)
3. **Open a PR** against the `master` branch. The `update-jobs` presubmit job will automatically run and validate the proposed configuration
4. **After merge**, the `update-jobs-pr` postsubmit job uploads the new configuration to the Prow cluster as a Kubernetes ConfigMap

The directory structure follows this pattern:

```
config/jobs/
|-- OWNERS
|-- README.md
|-- <job-category>/
|   |-- <job-name>.yaml
```

**Tips from the README:**

- Start new jobs with `always_run: false` and `skip_report: true`, manually trigger a few times with `/test <job-name>`, then enable `always_run: true` and `skip_report: false` once stable ([README.md:109-112](../../../refs/falcosecurity/test-infra/config/jobs/README.md))
- The `trigger` regex defaults to `/test <job-name>` if unspecified ([README.md:114-118](../../../refs/falcosecurity/test-infra/config/jobs/README.md))

---

## 3. Complete Job Catalog

### 3.1. build-drivers

**Purpose:** Builds precompiled Falco kernel drivers (kernel modules and eBPF probes) for specific Linux distributions using Driverkit, then publishes them to S3.

**Pattern:** Each distro has its own YAML file containing postsubmit jobs (one per architecture: x86 and arm). Some distros with many kernel versions split jobs by major version number. All jobs watch for changes to driverkit config files under `driverkit/config/` in the `test-infra` repository. A single presubmit job (`validate-dbg`) validates driverkit configs before merge.

**Common configuration across all build-drivers jobs:**

- **Type:** Postsubmit (except `validate-dbg` which is Presubmit)
- **Repository:** `falcosecurity/test-infra`
- **Branch:** `^master$`
- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/build-drivers:latest`
- **Command:** `/workspace/build-drivers.sh <distro> [version-filter]`
- **Service Account:** `driver-kit`
- **Security Context:** `privileged: true`
- **Resources:** CPU limit 1.0 / request 750m; Memory limit 4Gi / request 2Gi
- **Environment:** `PUBLISH_S3=true`
- **Annotations:** `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`, `error_on_eviction: true`

#### Distro-Specific Job Files

| File | Distro | Jobs (x86 + arm pairs) | run_if_changed pattern |
|------|--------|----------------------|----------------------|
| [build-new-almalinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-almalinux.yaml) | AlmaLinux | 2 (x86 + arm) | `almalinux_.+` |
| [build-new-amazonlinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-amazonlinux.yaml) | Amazon Linux (1, 2, 2022, 2023) | 8 (4 variants x 2 arch) | `amazonlinux_.+`, `amazonlinux2_.+`, `amazonlinux2022_.+`, `amazonlinux2023_.+` |
| [build-new-bottlerocket.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-bottlerocket.yaml) | Bottlerocket | 2 (x86 + arm) | `bottlerocket_.+` |
| [build-new-centos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-centos.yaml) | CentOS | 10 (versions 2-6, x86 + arm) | `centos_N.+` (N=2..6) |
| [build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml) | Debian | 2 (x86 + arm) | `debian_.+` |
| [build-new-fedora.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-fedora.yaml) | Fedora | 2 (x86 + arm) | `fedora_.+` |
| [build-new-minikube.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-minikube.yaml) | Minikube | 2 (x86 + arm) | `minikube_.+` |
| [build-new-photon.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-photon.yaml) | Photon OS | 2 (x86 + arm) | `photon_.+` |
| [build-new-talos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-talos.yaml) | Talos | 2 (x86 + arm) | `talos_.+` |
| [build-new-ubuntu-aws.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-aws.yaml) | Ubuntu AWS | 8 (versions 3-6, x86 + arm) | `ubuntu-aws_N.+` (N=3..6) |
| [build-new-ubuntu-azure.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-azure.yaml) | Ubuntu Azure | 8 (versions 3-6, x86 + arm) | `ubuntu-azure_N.+` (N=3..6) |
| [build-new-ubuntu-gcp.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gcp.yaml) | Ubuntu GCP | 8 (versions 3-6, x86 + arm) | `ubuntu-gcp_N.+` (N=3..6) |
| [build-new-ubuntu-generic.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-generic.yaml) | Ubuntu Generic | 8 (versions 3-6, x86 + arm) | `ubuntu-generic_N.+` (N=3..6) |
| [build-new-ubuntu-gke.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gke.yaml) | Ubuntu GKE | 8 (versions 3-6, x86 + arm) | `ubuntu-gke_N.+` (N=3..6) |

All `run_if_changed` patterns follow the form:
- x86: `^driverkit/config/[a-z0-9.+-]{5,}/x86_64/<distro>_.+`
- arm: `^driverkit/config/[a-z0-9.+-]{5,}/aarch64/<distro>_.+`

#### Validation Job

| File | Job Name | Type |
|------|----------|------|
| [validate-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml) | `validate-dbg` | **Presubmit** |

- **run_if_changed:** `^driverkit/config/[a-z0-9.+-]{5,}/(.+/)?` (any driverkit config change)
- **Environment:** `DBG_MAKE_BUILD_TARGET=validate` (runs validation only, no build)
- Same image, service account, and resources as build jobs

---

### 3.2. build-plugins

**Purpose:** Builds and distributes Falco plugins as OCI artifacts when the plugin registry or plugin release tags change.

**Source:** [build-plugins.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-plugins/build-plugins.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `build-plugins-on-registry-changed-postsubmit` | Postsubmit | `falcosecurity/plugins` | `run_if_changed: "^registry.yaml"` on `^main$` |
| `build-plugins-on-plugin-release-postsubmit` | Postsubmit | `falcosecurity/plugins` | Branch pattern: `^plugins/[a-z]+[a-z0-9-_\-]*/v\d+\.\d+\.\d+$` |

**Configuration:**

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/build-plugins:latest`
- **Command:** `/on-registry-changed.sh /etc/github-token/oauth`
- **Volumes:** `oauth-token` secret (GitHub token), `poiana-gpg-signing-key` secret (GPG signing)
- **Node selector:** `Archtype: "x86"`

---

### 3.3. build-prow-images

**Purpose:** Builds (presubmit) and publishes (postsubmit) Docker container images used by other Prow jobs. Each image directory under `images/` has a corresponding build and publish job.

#### Presubmit Build Jobs

**Source:** [build-images.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-prow-images/build-images.yaml)

| Job Name | Trigger (`run_if_changed`) |
|----------|--------------------------|
| `build-images-build-drivers` | `^images/build-drivers/` |
| `build-images-golang` | `^images/golang/` |
| `build-images-update-jobs` | `^images/update-jobs/` |
| `build-images-update-maintainers` | `^images/update-maintainers/` |
| `build-images-build-plugins` | `^images/build-plugins/` |
| `build-images-update-rules-index` | `^images/update-rules-index/` |
| `build-images-update-falco-k8s-manifests` | `^images/update-falco-k8s-manifests/` |
| `build-images-build-docker-dind` | `^images/docker-dind/` |
| `build-images-update-dbg` | `^images/update-dbg/` |

All presubmit build jobs share:

- **Repository:** `falcosecurity/test-infra`, branch `^master$`
- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/docker-dind`
- **Command:** `/home/prow/go/src/github.com/falcosecurity/test-infra/images/build.sh <image-path>`
- **Resources:** CPU 1.5, Memory 3Gi, Ephemeral-storage 2Gi
- **Security Context:** `privileged: true`
- **Environment:** `AWS_REGION=eu-west-1`

#### Postsubmit Publish Jobs

**Source:** [publish-images.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-prow-images/publish-images.yaml)

| Job Name | Trigger (`run_if_changed`) |
|----------|--------------------------|
| `publish-images-build-drivers` | `^images/build-drivers/` |
| `publish-images-build-plugins` | `^images/build-plugins/` |
| `publish-images-update-rules-index` | `^images/update-rules-index/` |
| `publish-images-golang` | `^images/golang/` |
| `publish-images-update-jobs` | `^images/update-jobs/` |
| `publish-images-update-maintainers` | `^images/update-maintainers/` |
| `publish-images-update-falco-k8s-manifests` | `^images/update-falco-k8s-manifests/` |
| `publish-images-build-docker-dind` | `^images/docker-dind/` |
| `publish-images-update-dbg` | `^images/update-dbg/` |

Same configuration as presubmit except the command uses `publish.sh` instead of `build.sh`.

---

### 3.4. build-aws-terraform

**Purpose:** Validates Terraform configurations for the Falco AWS infrastructure.

**Source:** [build-aws-terraform.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-aws-terraform/build-aws-terraform.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `build-aws-terraform` | Presubmit | `falcosecurity/falco-aws-terraform` | `always_run: true` |

- **Image:** `hashicorp/terraform:latest`
- **Command:** `/home/prow/go/src/github.com/falcosecurity/falco-aws-terraform/presubmit.sh`
- **Resources:** CPU 1500m, Memory 3Gi
- **Node selector:** `Archtype: "x86"`

---

### 3.5. check-prow-config

**Purpose:** Validates the Prow configuration files (config.yaml, plugins.yaml, and job configs) for correctness.

**Source:** [check-prow-config.yaml](../../../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `check-prow-config` | Presubmit | `always_run: true` on `^master$` |
| `check-prow-config-periodic` | Periodic | `interval: 1h` |

- **Image:** `gcr.io/k8s-prow/checkconfig:v20240805-37a08f946`
- **Command:** `checkconfig --config-path=config/config.yaml --job-config-path=config/jobs --plugin-config=config/plugins.yaml`
- The periodic variant uses `extra_refs` to clone `falcosecurity/test-infra` at `master`

---

### 3.6. update-jobs

**Purpose:** Uploads job configuration YAML files to the Prow cluster as Kubernetes ConfigMaps after changes are merged.

**Source:** [update-jobs.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `update-jobs-pr` | Postsubmit | Push to `^master$` of `falcosecurity/test-infra` |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-jobs:latest`
- **Command:** `/go/bin/update-jobs --jobs-config-path /home/prow/go/src/github.com/falcosecurity/test-infra/config/jobs`
- **Service Account:** `update-jobs`

---

### 3.7. update-dbg

**Purpose:** Periodically updates the Drivers Build Grid (DBG) configuration in the `test-infra` repository by running driverkit config generation based on kernel-crawler output.

**Source:** [update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-dbg/update-dbg.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `update-dbg` | Periodic | `cron: "0 8 * * *"` (daily at 08:00 UTC) |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-dbg`
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/test-infra` at `master` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing for commits)

---

### 3.8. update-maintainers

**Purpose:** Periodically synchronizes maintainer information from OWNERS files across all falcosecurity repositories into the `evolution` repository's `maintainers.yaml`.

**Source:** [update-maintainers.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-maintainers/update-maintainers.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `update-maintainers` | Periodic | `cron: "0 9 * * *"` (daily at 09:00 UTC) |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-maintainers`
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/evolution` at `main` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

---

### 3.9. update-rules-index

**Purpose:** Updates the Falco rules index (OCI distribution metadata) when the rules registry changes.

**Source:** [update-rules-index.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-rules-index/update-rules-index.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `update-rules-index-on-registry-changed-postsubmit` | Postsubmit | `falcosecurity/rules` | `run_if_changed: "^registry.yaml"` on `^main$` |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-rules-index:latest`
- **Command:** `/on-registry-changed.sh /etc/github-token/oauth`
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

---

### 3.10. update-falco-k8s-manifests

**Purpose:** Periodically renders Helm charts into plain Kubernetes manifests in the `deploy-kubernetes` repository. Each Helm chart has its own scheduled job.

**Source:** [update-falco-k8s-manifests.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-falco-k8s-manifests/update-falco-k8s-manifests.yaml)

| Job Name | Type | Schedule | `HELM_CHART_NAME` |
|----------|------|----------|-------------------|
| `update-falco-k8s-manifests` | Periodic | `cron: "0 10 * * *"` (daily 10:00 UTC) | `falco` |
| `update-falco-exporter-k8s-manifests` | Periodic | `cron: "0 11 * * *"` (daily 11:00 UTC) | `falco-exporter` |
| `update-falco-sidekick-k8s-manifests` | Periodic | `cron: "0 12 * * *"` (daily 12:00 UTC) | `falcosidekick` |
| `update-event-generator-k8s-manifests` | Periodic | `cron: "0 13 * * *"` (daily 13:00 UTC) | `event-generator` |

All share:

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-falco-k8s-manifests`
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/deploy-kubernetes` at `main` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

---

### 3.11. update-github-teams (Consolidated)

> Note: Historically, falcosecurity maintained 31 individual `peribolos-syncer-<repo>.yaml` postsubmit jobs under `config/jobs/update-github-teams/`, one per repository. They used the [`peribolos-syncer`](https://github.com/falcosecurity/peribolos-syncer) tool to keep each `<repo>-maintainers` team in `config/org.yaml` in sync with that repo's `OWNERS` file. In the current era, these per-repo job files have been consolidated; team synchronization is now driven by [`config/jobs/peribolos/peribolos.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) together with the [`update-maintainers`](#310-update-maintainers) job.

**Source:** [config/jobs/peribolos/peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml)

**Historical pattern:** Each per-repo file defined a single postsubmit job for a specific falcosecurity repository, triggered when the `OWNERS` file changed on the default branch.

Representative historical example (`peribolos-syncer-falco.yaml`):

- **Job name:** `peribolos-syncer-falco-post`
- **Type:** Postsubmit on `falcosecurity/falco`, branch `^master$`
- **Trigger:** `run_if_changed: 'OWNERS$'`
- **Image:** `ghcr.io/falcosecurity/peribolos-syncer:0.2.2`
- **Command:** `peribolos-syncer sync github` with args specifying:
  - `--org=falcosecurity`
  - `--team=falco-maintainers` (team name matches `<repo>-maintainers`)
  - `--peribolos-config-path=config/org.yaml` (in `test-infra`)
  - `--owners-repository=falco`
  - `--approvers-only=true`
  - `--git-author-name=poiana` (the Falco bot account)
  - GPG key mounts for signed commits
- **max_concurrency:** 1

**Historical coverage:** 31 repositories had a dedicated `peribolos-syncer-<repo>.yaml` job mapping `<repo>` to the `<repo>-maintainers` team. The full historical list included: `charts`, `client-go`, `cncf-green-review-testing`, `community`, `contrib`, `dbg-go`, `deploy-kubernetes`, `driverkit`, `event-generator`, `evolution`, `falco`, `falco-aws-terraform`, `falco-exporter`, `falco-playground`, `falco-website`, `falcoctl`, `falcosidekick`, `falcosidekick-ui`, `flycheck-falco-rules`, `k8s-metacollector`, `kernel-crawler`, `kernel-testing`, `libs`, `libs-sdk-go`, `peribolos-syncer`, `pigeon`, `plugin-sdk-cpp`, `plugin-sdk-go`, `plugins`, `rules`, `syscalls-bumper`, `test-infra`, and `testing`.

---

### 3.12. peribolos

**Purpose:** Manages the `falcosecurity` GitHub organization structure (members, teams, team membership, repos) using Peribolos, a Prow component that applies a declarative org config (`config/org.yaml`).

**Source:** [peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `peribolos-pre-submit` | Presubmit | `run_if_changed: '^config/org.yaml$\|^config/jobs/peribolos/.*'` on `^master$` |
| `peribolos-post-submit` | Postsubmit | Same `run_if_changed` pattern on `^master$` |
| `peribolos-periodic` | Periodic | `interval: 24h` |

- **Image:** `gcr.io/k8s-prow/peribolos:v20240805-37a08f946`
- **Command:** `peribolos` with flags:
  - `--config-path=config/org.yaml`
  - `--fix-org`, `--fix-org-members`, `--fix-repos`, `--fix-teams`, `--fix-team-members`, `--fix-team-repos`
  - Presubmit runs in **dry-run** mode (no `--confirm`), postsubmit and periodic run with `--confirm`
  - Presubmit also passes `--allow-repo-archival`
- **max_concurrency:** 1

---

### 3.13. branchprotector

**Purpose:** Applies branch protection rules to all repositories in the `falcosecurity` organization based on the Prow config.

**Source:** [branchprotector.yaml](../../../refs/falcosecurity/test-infra/config/jobs/branchprotector/branchprotector.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `branchprotector-post-submit` | Postsubmit | `run_if_changed: '^config/config.yaml$'` on `^master$` |
| `branchprotector-hourly` | Periodic | `cron: "55 * * * *"` (every hour at :55) |

- **Image:** `gcr.io/k8s-prow/branchprotector:v20240805-37a08f946`
- **Command:** `branchprotector --config-path=config/config.yaml --job-config-path=config/jobs --github-token-path=/etc/github/oauth --confirm`
- **max_concurrency:** 1

---

### 3.14. autobump

**Purpose:** Automatically bumps Prow component versions to the latest release candidate by creating PRs.

**Source:** [autobump.yaml](../../../refs/falcosecurity/test-infra/config/jobs/autobump/autobump.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `ci-test-infra-autobump-prow` | Periodic | `cron: "05 15 * * 4"` (Thursday at 15:05 UTC) |

- **Image:** `gcr.io/k8s-prow/generic-autobumper:latest`
- **Command:** `generic-autobumper --config=config/autobump-config/prow-autobump-config.yaml --signoff`
- **Extra refs:** Clones `falcosecurity/test-infra` at `master`
- **Annotation:** "runs autobumper to create/update a PR that bumps prow to the latest RC without label 'skip-review'"

---

### 3.15. lifecycle-bot

**Purpose:** Manages the lifecycle of GitHub issues across the entire `falcosecurity` organization using a stale/rotten/close escalation pattern.

#### Issue Lifecycle Pipeline

Issues progress through: **Active** -> **Stale** (90 days inactivity) -> **Rotten** (30 more days) -> **Closed** (30 more days). Issues labeled `lifecycle/frozen` are exempt.

| Job Name | Type | Schedule | Action |
|----------|------|----------|--------|
| `periodic-stale` | Periodic | `interval: 6h` | Adds `lifecycle/stale` label to issues inactive for 90 days (2160h) |
| `periodic-rotten` | Periodic | `interval: 6h` | Adds `lifecycle/rotten` label to stale issues inactive for 30 more days (720h) |
| `periodic-close` | Periodic | `interval: 6h` | Closes rotten issues inactive for 30 more days (720h) |

**Sources:**
- [periodic-stale.yaml](../../../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-stale.yaml)
- [periodic-rotten.yaml](../../../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-rotten.yaml)
- [periodic-close.yaml](../../../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-close.yaml)

All share:

- **Image:** `gcr.io/k8s-prow/commenter:v20240731-a5d9345e59`
- **Command:** `commenter` with `--query=org:falcosecurity -label:lifecycle/frozen ...`
- **Ceiling:** `--ceiling=10` (max 10 issues processed per run)
- Query targets the entire `org:falcosecurity` GitHub organization

---

### 3.16. recurring-ghissues

**Purpose:** Periodically creates GitHub issues as reminders for infrastructure maintenance tasks.

**Source:** [prow-eks-upgrade.yaml](../../../refs/falcosecurity/test-infra/config/jobs/recurring-ghissues/prow-eks-upgrade.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `prow-eks-upgrade-reminder` | Periodic | `cron: "0 7 21 6 *"` (June 21 at 07:00 UTC) |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/ghissue:latest`
- **Command:** `/usr/local/bin/entrypoint.sh ghissue create --byline=false issue.txt`
- **Environment:** `GH_REPO=test-infra`, `GH_ISSUE_TITLE="Upgrade EKS cluster to latest stable version"`, `GH_ISSUE_TAGS="maintenance,eks"`
- Creates issues reminding to upgrade: EKS control plane, data plane, AMI, VPC CNI, kubelet, CoreDNS

---

## 4. Config Uploader Tool

**Source:** [prow/update-jobs/main.go](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go)

The Config Uploader is a Go program that synchronizes Prow configuration files into Kubernetes ConfigMaps within the Prow cluster. It is the mechanism by which job configuration changes take effect after merging.

### How It Works

1. **Authenticates** to the Kubernetes cluster using either a service account token (in-cluster, default) or a provided kubeconfig file ([main.go:57-67](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go))
2. **Reads configuration files** from the local filesystem
3. **Updates Kubernetes ConfigMaps** in the `default` namespace ([main.go:41-42](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go))

### CLI Flags

| Flag | Description |
|------|-------------|
| `--config-path` | Path to Prow config file. Updates the `config` ConfigMap |
| `--jobs-config-path` | Path to job config directory. Updates the `job-config` ConfigMap |
| `--plugins-config-path` | Path to plugins config file. Updates the `plugins` ConfigMap |
| `--kubeconfig` | Optional path to kubeconfig (defaults to in-cluster SA token) |

### ConfigMap Generation

- **Single-file configs** (`config`, `plugins`): The file content is stored under a key named `<name>.yaml` in the ConfigMap ([main.go:126-144](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go))
- **Directory configs** (`job-config`): All `.yaml` files found recursively in the directory are combined into a single ConfigMap, with each file's basename as the key ([main.go:146-168](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go))

---

## 5. Job Configuration Patterns

This section documents the common patterns and conventions used across all Prow job definitions.

### Node Selectors

Jobs use Kubernetes node selectors to target specific node pools:

| Key | Values | Purpose |
|-----|--------|---------|
| `Archtype` | `"x86"`, `"arm"` | Select CPU architecture-specific nodes |
| `Application` | `"jobs"` | Select nodes designated for Prow jobs (used by build-drivers) |
| `topology.kubernetes.io/zone` | (not observed in current configs) | Reserved for zone-specific scheduling |

- **All jobs** require at least `Archtype: "x86"`
- **ARM build-drivers jobs** use `Archtype: "arm"` instead
- **Build-drivers jobs** additionally require `Application: "jobs"`

### Tolerations

| Toleration Key | Value | Effect | Used By |
|----------------|-------|--------|---------|
| `Availability` | `SingleAZ` | `NoSchedule` | All build-drivers jobs (both x86 and arm) |
| `Archtype` | `arm` | `NoSchedule` | ARM build-drivers jobs only |

- The `SingleAZ` toleration allows scheduling on nodes in a single availability zone (cost optimization)
- The `arm` toleration allows scheduling on ARM-specific tainted nodes

### Service Accounts

| Service Account | Used By | Purpose |
|-----------------|---------|---------|
| `driver-kit` | All build-drivers jobs, validate-dbg | Access to S3 for publishing driver artifacts |
| `update-jobs` | update-jobs postsubmit | Access to Kubernetes API for updating ConfigMaps |
| *(default)* | Most other jobs | Standard Prow pod service account |

### Resource Limits and Requests

**Build-drivers jobs:**
```yaml
resources:
  limits:
    cpu: 1.0
    memory: 4Gi
  requests:
    cpu: 750m    # ~37.5% of m5.large (2 vCPU, 8 GiB RAM)
    memory: 2Gi
```

**Build-prow-images jobs:**
```yaml
resources:
  requests:
    memory: 3Gi
    cpu: 1.5
    ephemeral-storage: "2Gi"
```

**Build-aws-terraform:**
```yaml
resources:
  requests:
    cpu: 1500m   # ~75% of m5.large
    memory: 3Gi
```

### Decoration Config

All jobs use Prow's `decorate: true` setting, which enables the Pod Utility decoration system:

- Automatically adds init containers to clone the repository
- `path_alias` controls the clone path (e.g., `github.com/falcosecurity/test-infra` maps to `/home/prow/go/src/github.com/falcosecurity/test-infra`)
- `extra_refs` (periodic jobs) specifies which repos to clone before running

### run_if_changed Patterns

This mechanism scopes job triggering to specific file paths within a PR or push:

| Pattern | Purpose |
|---------|---------|
| `'^driverkit/config/[a-z0-9.+-]{5,}/x86_64/<distro>_.+'` | Trigger build for specific distro on x86 |
| `'^driverkit/config/[a-z0-9.+-]{5,}/aarch64/<distro>_.+'` | Trigger build for specific distro on ARM |
| `'^driverkit/config/[a-z0-9.+-]{5,}/(.+/)?'` | Trigger validation for any driverkit config change |
| `'^images/<image-name>/'` | Trigger build/publish when image source changes |
| `'^config/org.yaml$\|^config/jobs/peribolos/.*'` | Trigger peribolos on org config changes |
| `'^config/config.yaml$'` | Trigger branchprotector on Prow config changes |
| `'^config/jobs/'` | Trigger update-jobs on any job config change |
| `'OWNERS$'` | Trigger peribolos-syncer on OWNERS file changes |
| `"^registry.yaml"` | Trigger plugin/rules builds on registry changes |

### Bot Account: poiana

Many automation jobs use the `poiana` GitHub bot account (ID: 51138685) for creating PRs and signing commits:

- **GitHub token:** Mounted from `oauth-token` secret at `/etc/github-token/oauth`
- **GPG signing:** `poiana-gpg-signing-key` and `poiana-gpg-signing-key-pub` secrets
- **GitHub endpoint:** Uses `http://ghproxy.default.svc.cluster.local` (Prow's GitHub proxy) with fallback to `https://api.github.com`

### Container Images

| Image | Used By |
|-------|---------|
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/build-drivers:latest` | build-drivers, validate-dbg |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/build-plugins:latest` | build-plugins |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/docker-dind` | build-prow-images (build + publish) |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-jobs:latest` | update-jobs |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-dbg` | update-dbg |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-maintainers` | update-maintainers |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-rules-index:latest` | update-rules-index |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-falco-k8s-manifests` | update-falco-k8s-manifests |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/ghissue:latest` | recurring-ghissues |
| `gcr.io/k8s-prow/peribolos:v20240805-37a08f946` | peribolos |
| `gcr.io/k8s-prow/branchprotector:v20240805-37a08f946` | branchprotector |
| `gcr.io/k8s-prow/checkconfig:v20240805-37a08f946` | check-prow-config |
| `gcr.io/k8s-prow/commenter:v20240731-a5d9345e59` | lifecycle-bot |
| `gcr.io/k8s-prow/generic-autobumper:latest` | autobump |
| `ghcr.io/falcosecurity/peribolos-syncer:0.2.2` | update-github-teams |
| `hashicorp/terraform:latest` | build-aws-terraform |

All custom images are hosted in an AWS ECR registry (`292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/`), while standard Prow components come from `gcr.io/k8s-prow/`.

---

## Sources

| Topic | Source File |
|-------|-------------|
| Job configuration guide | [config/jobs/README.md](../../../refs/falcosecurity/test-infra/config/jobs/README.md) |
| Config Uploader tool | [prow/update-jobs/main.go](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go) |
| Build drivers (Amazon Linux) | [build-new-amazonlinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-amazonlinux.yaml) |
| Build drivers (Ubuntu Generic) | [build-new-ubuntu-generic.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-generic.yaml) |
| Build drivers (CentOS) | [build-new-centos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-centos.yaml) |
| Build drivers (Debian) | [build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml) |
| Build drivers (AlmaLinux) | [build-new-almalinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-almalinux.yaml) |
| Build drivers (Bottlerocket) | [build-new-bottlerocket.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-bottlerocket.yaml) |
| Build drivers (Fedora) | [build-new-fedora.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-fedora.yaml) |
| Build drivers (Minikube) | [build-new-minikube.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-minikube.yaml) |
| Build drivers (Photon OS) | [build-new-photon.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-photon.yaml) |
| Build drivers (Talos) | [build-new-talos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-talos.yaml) |
| Build drivers (Ubuntu AWS) | [build-new-ubuntu-aws.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-aws.yaml) |
| Build drivers (Ubuntu Azure) | [build-new-ubuntu-azure.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-azure.yaml) |
| Build drivers (Ubuntu GCP) | [build-new-ubuntu-gcp.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gcp.yaml) |
| Build drivers (Ubuntu GKE) | [build-new-ubuntu-gke.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gke.yaml) |
| Validate DBG configs | [validate-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml) |
| Build plugins | [build-plugins.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-plugins/build-plugins.yaml) |
| Build prow images (presubmit) | [build-images.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-prow-images/build-images.yaml) |
| Publish prow images (postsubmit) | [publish-images.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-prow-images/publish-images.yaml) |
| Build AWS Terraform | [build-aws-terraform.yaml](../../../refs/falcosecurity/test-infra/config/jobs/build-aws-terraform/build-aws-terraform.yaml) |
| Check prow config | [check-prow-config.yaml](../../../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml) |
| Update jobs | [update-jobs.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml) |
| Update DBG | [update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-dbg/update-dbg.yaml) |
| Update maintainers | [update-maintainers.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-maintainers/update-maintainers.yaml) |
| Update rules index | [update-rules-index.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-rules-index/update-rules-index.yaml) |
| Update K8s manifests | [update-falco-k8s-manifests.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-falco-k8s-manifests/update-falco-k8s-manifests.yaml) |
| Peribolos-syncer (historical) | Previously under `config/jobs/update-github-teams/peribolos-syncer-*.yaml`; consolidated into [peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) |
| Peribolos org management | [peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) |
| Branch protector | [branchprotector.yaml](../../../refs/falcosecurity/test-infra/config/jobs/branchprotector/branchprotector.yaml) |
| Autobump | [autobump.yaml](../../../refs/falcosecurity/test-infra/config/jobs/autobump/autobump.yaml) |
| Lifecycle: stale | [periodic-stale.yaml](../../../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-stale.yaml) |
| Lifecycle: rotten | [periodic-rotten.yaml](../../../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-rotten.yaml) |
| Lifecycle: close | [periodic-close.yaml](../../../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-close.yaml) |
| EKS upgrade reminder | [prow-eks-upgrade.yaml](../../../refs/falcosecurity/test-infra/config/jobs/recurring-ghissues/prow-eks-upgrade.yaml) |
