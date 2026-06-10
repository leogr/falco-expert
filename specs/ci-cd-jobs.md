# CI/CD Jobs

> Prow job system and organization automation: job types, complete job catalog, GitHub organization management, OWNERS-based approval workflow, and config uploader.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/test-infra/config/jobs/`](../refs/falcosecurity/test-infra/config/jobs/)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Job Types](#2-job-types)
3. [Job Catalog](#3-job-catalog)
   - [Driver Builds](#31-driver-builds-build-drivers)
   - [Plugin Builds](#32-plugin-builds-build-plugins)
   - [Image Builds](#33-image-builds-build-prow-images)
   - [Config Validation](#34-config-validation-check-prow-config)
   - [Config Upload](#35-config-upload-update-jobs)
   - [DBG Updates](#36-dbg-updates-update-dbg)
   - [Maintainers Sync](#37-maintainers-sync-update-maintainers)
   - [Rules Index](#38-rules-index-update-rules-index)
   - [K8s Manifests](#39-k8s-manifests-update-falco-k8s-manifests)
   - [Branch Protection](#310-branch-protection-branchprotector)
   - [Autobump](#311-autobump)
   - [Lifecycle Bot](#312-lifecycle-bot)
   - [EKS Upgrade Reminder](#313-eks-upgrade-reminder)
4. [GitHub Organization Management](#4-github-organization-management)
5. [OWNERS Files and Approval Workflow](#5-owners-files-and-approval-workflow)
6. [Team Sync (peribolos-syncer)](#6-team-sync-peribolos-syncer----consolidated)
7. [Common Job Patterns](#7-common-job-patterns)
8. [Related Specs](#8-related-specs)
9. [Sources](#9-sources)

---

## 1. Overview

The Falco project uses [Prow](https://docs.prow.k8s.io/docs/), the Kubernetes-native CI/CD system, to automate builds, testing, organization management, and infrastructure maintenance across the entire `falcosecurity` GitHub organization. All job definitions reside under [`config/jobs/`](../refs/falcosecurity/test-infra/config/jobs/) in the `test-infra` repository.

Prow supports three job types -- presubmit, postsubmit, and periodic -- each triggered by different events and scheduled by different components. Jobs are defined as YAML files organized by category in subdirectories. After merge, the config uploader tool propagates job definitions to the Prow cluster as Kubernetes ConfigMaps.

**Source:** [`config/jobs/README.md`](../refs/falcosecurity/test-infra/config/jobs/README.md)

---

## 2. Job Types

### Presubmit

Presubmit jobs run **before a PR is merged**, triggered on pull request events (open, update, synchronize). They are scheduled by the `hook` component when GitHub webhooks arrive.

- Triggered against the specified `branches` (typically `^master$` or `^main$`)
- Scoped with `run_if_changed` to trigger only when specific file paths are modified, or set to `always_run: true` for every PR
- Results reported as GitHub commit status checks (unless `skip_report: true`)
- Manually re-triggerable with `/test <job-name>` comments

**Source:** [`config/jobs/README.md:116-118`](../refs/falcosecurity/test-infra/config/jobs/README.md)

### Postsubmit

Postsubmit jobs run **after a PR is merged**, triggered on push events to the target branch. Scheduled by the `hook` component.

- Triggered on pushes to matching `branches`
- Can use `run_if_changed` to scope which file changes trigger the job
- Used for publishing, deploying, or syncing operations on the canonical branch
- `max_concurrency` can limit parallel runs

**Source:** [`config/jobs/README.md:69-84`](../refs/falcosecurity/test-infra/config/jobs/README.md)

### Periodic

Periodic jobs run on a **schedule**, independent of repository events. Scheduled by the `horologium` component.

- Triggered by either a `cron` expression (e.g., `"0 8 * * *"`) or an `interval` (e.g., `6h`)
- Use `extra_refs` to check out a repository into the workspace before execution
- Not tied to a specific repository push event
- Used for maintenance tasks: org syncing, stale issue management, config checks, manifest updates

**Source:** [`config/jobs/README.md:43-65`](../refs/falcosecurity/test-infra/config/jobs/README.md)

### Prow Components

| Component | Role |
|-----------|------|
| `horologium` | Schedules periodic jobs on cron/interval |
| `hook` | Schedules presubmit and postsubmit jobs from GitHub webhooks |
| `prow-controller-manager` | Schedules the Kubernetes pod for each ProwJob |
| `crier` | Reports job status back to GitHub as commit statuses |

**Source:** [`config/jobs/README.md:6-10`](../refs/falcosecurity/test-infra/config/jobs/README.md)

---

## 3. Job Catalog

### 3.1. Driver Builds (build-drivers)

Builds precompiled Falco kernel drivers (kernel modules and eBPF probes) for specific Linux distributions using Driverkit, then publishes them to S3. Each distro has its own YAML file with postsubmit jobs (one per architecture: x86 and arm). A single presubmit job (`validate-dbg`) validates driverkit configs before merge.

**Common configuration:**
- **Type:** Postsubmit (except `validate-dbg` which is presubmit)
- **Repository:** `falcosecurity/test-infra`, branch `^master$`
- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/build-drivers:latest`
- **Command:** `/workspace/build-drivers.sh <distro> [version-filter]`
- **Service account:** `driver-kit`
- **Security context:** `privileged: true` (Docker-in-Docker)
- **Resources:** CPU limit 1.0 / request 750m; Memory limit 4Gi / request 2Gi
- **Environment:** `PUBLISH_S3=true`
- **Annotations:** `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`, `error_on_eviction: true`

#### Distro Files (14 files)

| File | Distro | Jobs | `run_if_changed` pattern |
|------|--------|------|--------------------------|
| [`build-new-almalinux.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-almalinux.yaml) | AlmaLinux | 2 (x86 + arm) | `almalinux_.+` |
| [`build-new-amazonlinux.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-amazonlinux.yaml) | Amazon Linux (1, 2, 2022, 2023) | 8 (4 variants x 2 arch) | `amazonlinux_.+`, `amazonlinux2_.+`, etc. |
| [`build-new-bottlerocket.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-bottlerocket.yaml) | Bottlerocket | 2 (x86 + arm) | `bottlerocket_.+` |
| [`build-new-centos.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-centos.yaml) | CentOS | 10 (versions 2-6, x86 + arm) | `centos_N.+` (N=2..6) |
| [`build-new-debian.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-debian.yaml) | Debian | 2 (x86 + arm) | `debian_.+` |
| [`build-new-fedora.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-fedora.yaml) | Fedora | 2 (x86 + arm) | `fedora_.+` |
| [`build-new-minikube.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-minikube.yaml) | Minikube | 2 (x86 + arm) | `minikube_.+` |
| [`build-new-photon.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-photon.yaml) | Photon OS | 2 (x86 + arm) | `photon_.+` |
| [`build-new-talos.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-talos.yaml) | Talos | 2 (x86 + arm) | `talos_.+` |
| [`build-new-ubuntu-aws.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-aws.yaml) | Ubuntu AWS | 8 (versions 3-6, x86 + arm) | `ubuntu-aws_N.+` (N=3..6) |
| [`build-new-ubuntu-azure.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-azure.yaml) | Ubuntu Azure | 8 (versions 3-6, x86 + arm) | `ubuntu-azure_N.+` (N=3..6) |
| [`build-new-ubuntu-gcp.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gcp.yaml) | Ubuntu GCP | 8 (versions 3-6, x86 + arm) | `ubuntu-gcp_N.+` (N=3..6) |
| [`build-new-ubuntu-generic.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-generic.yaml) | Ubuntu Generic | 8 (versions 3-6, x86 + arm) | `ubuntu-generic_N.+` (N=3..6) |
| [`build-new-ubuntu-gke.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-ubuntu-gke.yaml) | Ubuntu GKE | 8 (versions 3-6, x86 + arm) | `ubuntu-gke_N.+` (N=3..6) |

All `run_if_changed` patterns follow the form:
- x86: `^driverkit/config/[a-z0-9.+-]{5,}/x86_64/<distro>_.+`
- arm: `^driverkit/config/[a-z0-9.+-]{5,}/aarch64/<distro>_.+`

#### Validation Job

| File | Job Name | Type | Trigger |
|------|----------|------|---------|
| [`validate-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml) | `validate-dbg` | Presubmit | `run_if_changed: ^driverkit/config/[a-z0-9.+-]{5,}/(.+/)?` |

Runs with `DBG_MAKE_BUILD_TARGET=validate` (validation only, no build). Uses the same image, service account, and resources as build jobs.

### 3.2. Plugin Builds (build-plugins)

Builds and distributes Falco plugins as OCI artifacts when the plugin registry or release tags change.

**Source:** [`build-plugins.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-plugins/build-plugins.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `build-plugins-on-registry-changed-postsubmit` | Postsubmit | `falcosecurity/plugins` | `run_if_changed: "^registry.yaml"` on `^main$` |
| `build-plugins-on-plugin-release-postsubmit` | Postsubmit | `falcosecurity/plugins` | Branch: `^plugins/[a-z]+[a-z0-9-_\-]*/v\d+\.\d+\.\d+$` |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/build-plugins:latest`
- **Command:** `/on-registry-changed.sh /etc/github-token/oauth`
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)
- **Node selector:** `Archtype: "x86"`

### 3.3. Image Builds (build-prow-images)

Builds (presubmit) and publishes (postsubmit) Docker container images used by other Prow jobs. Each image directory under `images/` has a corresponding build and publish job pair (9 presubmit + 9 postsubmit = 18 total jobs).

**Source:** [`build-images.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-prow-images/build-images.yaml), [`publish-images.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-prow-images/publish-images.yaml)

| Image | `run_if_changed` |
|-------|-------------------|
| `build-drivers` | `^images/build-drivers/` |
| `golang` | `^images/golang/` |
| `update-jobs` | `^images/update-jobs/` |
| `update-maintainers` | `^images/update-maintainers/` |
| `build-plugins` | `^images/build-plugins/` |
| `update-rules-index` | `^images/update-rules-index/` |
| `update-falco-k8s-manifests` | `^images/update-falco-k8s-manifests/` |
| `docker-dind` | `^images/docker-dind/` |
| `update-dbg` | `^images/update-dbg/` |

All share:
- **Repository:** `falcosecurity/test-infra`, branch `^master$`
- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/docker-dind`
- **Command:** Presubmit uses `build.sh`, postsubmit uses `publish.sh`
- **Resources:** CPU 1.5, Memory 3Gi, Ephemeral-storage 2Gi
- **Security context:** `privileged: true`
- **Environment:** `AWS_REGION=eu-west-1`

### 3.4. Config Validation (check-prow-config)

Validates Prow configuration files (config.yaml, plugins.yaml, job configs) for correctness.

**Source:** [`check-prow-config.yaml`](../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `check-prow-config` | Presubmit | `always_run: true` on `^master$` |
| `check-prow-config-periodic` | Periodic | `interval: 1h` |

- **Image:** `gcr.io/k8s-prow/checkconfig:v20240805-37a08f946`
- **Command:** `checkconfig --config-path=config/config.yaml --job-config-path=config/jobs --plugin-config=config/plugins.yaml`
- The periodic variant uses `extra_refs` to clone `falcosecurity/test-infra` at `master`

### 3.5. Config Upload (update-jobs)

Uploads job configuration YAML files to the Prow cluster as Kubernetes ConfigMaps after changes are merged. This is the mechanism by which job configuration changes take effect.

**Source:** [`update-jobs.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `update-jobs-pr` | Postsubmit | Push to `^master$` of `falcosecurity/test-infra` |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-jobs:latest`
- **Command:** `/go/bin/update-jobs --jobs-config-path /home/prow/go/src/github.com/falcosecurity/test-infra/config/jobs`
- **Service account:** `update-jobs`

The config uploader is a Go program ([`prow/update-jobs/main.go`](../refs/falcosecurity/test-infra/prow/update-jobs/main.go)) that:
1. Authenticates to the Kubernetes cluster (in-cluster SA or kubeconfig)
2. Reads configuration files from the local filesystem
3. Updates ConfigMaps in the `default` namespace

CLI flags: `--config-path` (config ConfigMap), `--jobs-config-path` (job-config ConfigMap), `--plugins-config-path` (plugins ConfigMap), `--kubeconfig` (optional).

For single-file configs, the file is stored under a key named `<name>.yaml`. For directory configs, all `.yaml` files are combined with basenames as keys.

**Source:** [`prow/update-jobs/main.go:41-42, 126-168`](../refs/falcosecurity/test-infra/prow/update-jobs/main.go)

### 3.6. DBG Updates (update-dbg)

Periodically updates the Drivers Build Grid (DBG) configuration by generating driverkit configs from kernel-crawler output.

**Source:** [`update-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-dbg/update-dbg.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `update-dbg` | Periodic | `cron: "0 8 * * *"` (daily 08:00 UTC) |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-dbg`
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/test-infra` at `master` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

### 3.7. Maintainers Sync (update-maintainers)

Periodically synchronizes maintainer information from OWNERS files across all falcosecurity repositories into `evolution/maintainers.yaml`.

**Source:** [`update-maintainers.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-maintainers/update-maintainers.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `update-maintainers` | Periodic | `cron: "0 9 * * *"` (daily 09:00 UTC) |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-maintainers`
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/evolution` at `main` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

The entrypoint script ([`images/update-maintainers/entrypoint.sh`](../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh)):
1. Runs `maintainers-generator` to query the GitHub API and produce `maintainers.yaml`
2. Runs `make` to regenerate `README.md` and `MAINTAINERS.md` in evolution
3. Creates a PR via `pr-creator` if changes are detected (branch: `update-evolution-files`)

### 3.8. Rules Index (update-rules-index)

Updates the Falco rules index (OCI distribution metadata) when the rules registry changes.

**Source:** [`update-rules-index.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-rules-index/update-rules-index.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `update-rules-index-on-registry-changed-postsubmit` | Postsubmit | `falcosecurity/rules` | `run_if_changed: "^registry.yaml"` on `^main$` |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-rules-index:latest`
- **Command:** `/on-registry-changed.sh /etc/github-token/oauth`
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

### 3.9. K8s Manifests (update-falco-k8s-manifests)

Periodically renders Helm charts into plain Kubernetes manifests in the `deploy-kubernetes` repository.

**Source:** [`update-falco-k8s-manifests.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-falco-k8s-manifests/update-falco-k8s-manifests.yaml)

| Job Name | Type | Schedule | `HELM_CHART_NAME` |
|----------|------|----------|--------------------|
| `update-falco-k8s-manifests` | Periodic | daily 10:00 UTC | `falco` |
| `update-falco-exporter-k8s-manifests` | Periodic | daily 11:00 UTC | `falco-exporter` |
| `update-falco-sidekick-k8s-manifests` | Periodic | daily 12:00 UTC | `falcosidekick` |
| `update-event-generator-k8s-manifests` | Periodic | daily 13:00 UTC | `event-generator` |

All share:
- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/update-falco-k8s-manifests`
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/deploy-kubernetes` at `main` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

### 3.10. Branch Protection (branchprotector)

Applies branch protection rules to all repositories in the `falcosecurity` organization based on the Prow config.

**Source:** [`branchprotector.yaml`](../refs/falcosecurity/test-infra/config/jobs/branchprotector/branchprotector.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `branchprotector-post-submit` | Postsubmit | `run_if_changed: '^config/config.yaml$'` on `^master$` |
| `branchprotector-hourly` | Periodic | `cron: "55 * * * *"` (hourly at :55) |

- **Image:** `gcr.io/k8s-prow/branchprotector:v20240805-37a08f946`
- **Command:** `branchprotector --config-path=config/config.yaml --job-config-path=config/jobs --github-token-path=/etc/github/oauth --confirm`
- **max_concurrency:** 1

Branch protection rules are defined in [`config/config.yaml`](../refs/falcosecurity/test-infra/config/config.yaml). Key global defaults:

| Setting | Value |
|---------|-------|
| `enforce_admins` | `true` |
| `restrictions.teams` | `["maintainers", "machine_users"]` |
| `dismiss_stale_reviews` | `true` |
| `require_code_owner_reviews` | `true` |
| `required_approving_review_count` | `1` |
| `strict` (status checks) | `false` (rebase merge makes this unnecessary) |

All repositories require the `dco` status check (Developer Certificate of Origin).

**Source:** [`config/config.yaml:52-71`](../refs/falcosecurity/test-infra/config/config.yaml)

### 3.11. Autobump

Automatically bumps Prow component versions to the latest release candidate by creating PRs.

**Source:** [`autobump.yaml`](../refs/falcosecurity/test-infra/config/jobs/autobump/autobump.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `ci-test-infra-autobump-prow` | Periodic | `cron: "05 15 * * 4"` (Thursday 15:05 UTC) |

- **Image:** `gcr.io/k8s-prow/generic-autobumper:latest`
- **Command:** `generic-autobumper --config=config/autobump-config/prow-autobump-config.yaml --signoff`
- **Extra refs:** Clones `falcosecurity/test-infra` at `master`

### 3.12. Lifecycle Bot

Manages the lifecycle of GitHub issues across the entire `falcosecurity` organization using a stale/rotten/close escalation pattern.

**Escalation pipeline:** Active --> Stale (90 days inactivity) --> Rotten (30 more days) --> Closed (30 more days). Issues labeled `lifecycle/frozen` are exempt.

| Job Name | Type | Schedule | Action |
|----------|------|----------|--------|
| `periodic-stale` | Periodic | `interval: 6h` | Adds `lifecycle/stale` after 90 days (2160h) inactivity |
| `periodic-rotten` | Periodic | `interval: 6h` | Adds `lifecycle/rotten` after 30 more days (720h) |
| `periodic-close` | Periodic | `interval: 6h` | Closes after 30 more days (720h) |

**Sources:** [`periodic-stale.yaml`](../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-stale.yaml), [`periodic-rotten.yaml`](../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-rotten.yaml), [`periodic-close.yaml`](../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-close.yaml)

All share:
- **Image:** `gcr.io/k8s-prow/commenter:v20240731-a5d9345e59`
- **Command:** `commenter` with `--query=org:falcosecurity -label:lifecycle/frozen ...`
- **Ceiling:** `--ceiling=10` (max 10 issues per run)

### 3.13. EKS Upgrade Reminder

Periodically creates GitHub issues as reminders for infrastructure maintenance tasks.

**Source:** [`prow-eks-upgrade.yaml`](../refs/falcosecurity/test-infra/config/jobs/recurring-ghissues/prow-eks-upgrade.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `prow-eks-upgrade-reminder` | Periodic | `cron: "0 7 21 6 *"` (June 21 at 07:00 UTC) |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/ghissue:latest`
- **Command:** `/usr/local/bin/entrypoint.sh ghissue create --byline=false issue.txt`
- **Environment:** `GH_REPO=test-infra`, `GH_ISSUE_TITLE="Upgrade EKS cluster to latest stable version"`, `GH_ISSUE_TAGS="maintenance,eks"`

---

## 4. GitHub Organization Management

The `falcosecurity` GitHub organization is declaratively managed through [`config/org.yaml`](../refs/falcosecurity/test-infra/config/org.yaml), the single source of truth for organization settings, membership, teams, and repository configurations.

**Source:** [`config/org.yaml`](../refs/falcosecurity/test-infra/config/org.yaml), [`docs/github-org-management.md`](../refs/falcosecurity/test-infra/docs/github-org-management.md)

### What org.yaml Defines

- **Organization settings:** `default_repository_permission: read`, `members_can_create_repositories: false`
- **Organization admins:** 9 users including CNCF/LF representatives and core maintainers
- **Organization members:** 44 members (no inherent write access; access is managed through teams)
- **Team structure:** `admins`, `core-maintainers`, and ~40 per-repository `<repo>-maintainers` teams
- **Repository configurations:** merge strategy (`allow_rebase_merge: true`, others disabled), project/wiki settings, default branch, archived status

**Source:** [`config/org.yaml:1-1015`](../refs/falcosecurity/test-infra/config/org.yaml)

### Peribolos

[Peribolos](https://github.com/kubernetes/test-infra/blob/master/prow/cmd/peribolos/README.md) applies the declarative `org.yaml` configuration to the live GitHub organization.

**Source:** [`peribolos.yaml`](../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml)

| Job Name | Type | Trigger | Mode |
|----------|------|---------|------|
| `peribolos-pre-submit` | Presubmit | `run_if_changed: '^config/org.yaml$\|^config/jobs/peribolos/.*'` | **Dry-run** (no `--confirm`) |
| `peribolos-post-submit` | Postsubmit | Same `run_if_changed` | **Live** (`--confirm`) |
| `peribolos-periodic` | Periodic | `interval: 24h` | **Live** (`--confirm`) |

Peribolos manages:
- `--fix-org` -- organization settings
- `--fix-org-members` -- organization membership
- `--fix-repos` -- repository settings
- `--fix-teams` -- team definitions
- `--fix-team-members` -- team memberships
- `--fix-team-repos` -- team repository permissions
- `--allow-repo-archival` -- allow archiving repositories (presubmit only)
- `--config-path=config/org.yaml`

Image: `gcr.io/k8s-prow/peribolos:v20240805-37a08f946`. All jobs have `max_concurrency: 1`.

### Poiana Bot (Machine User)

`poiana` (GitHub ID: 51138685) is the project's automation bot. It is listed as an organization admin and is the sole maintainer of the `machine_users` team, which has **admin** access to 38 repositories.

- **GitHub token:** Mounted from `oauth-token` secret at `/etc/github-token/oauth`
- **GPG signing:** `poiana-gpg-signing-key` and `poiana-gpg-signing-key-pub` secrets
- **GPG key ID:** `EC9875C7B990D55F3B44D6E45F284448FF941C8F`
- **Email:** `51138685+poiana@users.noreply.github.com`
- **GitHub endpoint:** `http://ghproxy.default.svc.cluster.local` (Prow's GitHub proxy) with fallback to `https://api.github.com`

**Source:** [`config/org.yaml:16, 845-889`](../refs/falcosecurity/test-infra/config/org.yaml)

---

## 5. OWNERS Files and Approval Workflow

OWNERS files are a Prow convention defining who can approve and review pull requests. They integrate with Prow's `approve` and `lgtm` plugins.

### Approval Mechanics

- **`/approve`**: Only users listed as `approvers` in the OWNERS file for the changed paths can issue the `/approve` command, which adds the `approved` label
- **`/lgtm`**: Users listed as `reviewers` or `approvers` can issue `/lgtm`, which adds the `lgtm` label
- **Hierarchy**: OWNERS files are hierarchical -- a parent directory's OWNERS applies to all subdirectories unless overridden
- **`emeritus_approvers`**: Former approvers acknowledged but without active approval rights

### Plugin Configuration

| Setting | Value | Effect |
|---------|-------|--------|
| `lgtm_acts_as_approve` | `true` | `/lgtm` from an approver also counts as `/approve` |
| `review_acts_as_lgtm` | `true` | A GitHub approval review is equivalent to `/lgtm` |
| `store_tree_hash` | `true` | LGTM is invalidated if the PR changes after approval |
| `trusted_team_for_sticky_lgtm` | `test-infra-maintainers` | This team's LGTM survives PR updates |
| `require_self_approval` | `false` | PR authors do not need separate approval from themselves |

**Source:** [`config/plugins.yaml:L2-59, L90-139`](../refs/falcosecurity/test-infra/config/plugins.yaml)

### OWNERS as Team Membership Source

OWNERS files serve a dual purpose:
1. **Prow access control**: Determining who can approve/review PRs
2. **Team membership source of truth**: The peribolos-syncer reads the `approvers` list and syncs it to the corresponding `-maintainers` team in org.yaml

Changing an OWNERS file in a repository automatically propagates to GitHub team membership through the automated sync chain.

---

## 6. Team Sync (peribolos-syncer) -- Consolidated

> Note: Historically the peribolos-syncer system used 33 individual postsubmit jobs under `config/jobs/update-github-teams/`, one per falcosecurity repository, to synchronize each `<repo>-maintainers` team in `config/org.yaml` from that repo's `OWNERS` file. In the current era, those per-repo job files have been consolidated; org-wide synchronization is now performed by the single [`config/jobs/peribolos/peribolos.yaml`](../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) job together with the `update-maintainers` job.

**Source:** [`config/jobs/peribolos/peribolos.yaml`](../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml)

### Historical Pattern

Each historical per-repo job followed an identical structure:
- **Type:** Postsubmit on `falcosecurity/<repo>`, branch `^master$` or `^main$`
- **Trigger:** `run_if_changed: 'OWNERS$'`
- **Image:** `ghcr.io/falcosecurity/peribolos-syncer:0.2.2`
- **Command:** `peribolos-syncer sync github` with:
  - `--org=falcosecurity`
  - `--team=<repo>-maintainers`
  - `--peribolos-config-path=config/org.yaml`
  - `--peribolos-config-repository=test-infra`
  - `--owners-repository=<repo>`
  - `--approvers-only=true`
  - `--git-author-name=poiana`
- **max_concurrency:** 1

### Historical Two-Step Sync Chain

1. OWNERS file changes in repository --> peribolos-syncer creates PR to update `org.yaml` in `test-infra`
2. PR merges in test-infra --> Peribolos applies the team membership change to GitHub

### Historical Coverage (33 repositories)

The historical fan-out covered 33 repositories, each with its own `peribolos-syncer-<repo>.yaml` file mapping `<repo>` to the `<repo>-maintainers` team: `charts`, `client-go`, `cncf-green-review-testing`, `community`, `contrib`, `dbg-go`, `deploy-kubernetes`, `driverkit`, `event-generator`, `evolution`, `falco`, `falco-aws-terraform`, `falco-exporter`, `falco-playground`, `falco-website`, `falcoctl`, `falcosidekick`, `falcosidekick-ui`, `flycheck-falco-rules`, `k8s-metacollector`, `kernel-crawler`, `kernel-testing`, `libs`, `libs-sdk-go`, `peribolos-syncer`, `pigeon`, `plugin-sdk-cpp`, `plugin-sdk-go`, `plugins`, `rules`, `syscalls-bumper`, `test-infra`, and `testing`.

---

## 7. Common Job Patterns

### Node Selectors

| Key | Values | Purpose |
|-----|--------|---------|
| `Archtype` | `"x86"`, `"arm"` | Select CPU architecture-specific nodes |
| `Application` | `"jobs"` | Select nodes designated for Prow jobs (build-drivers only) |

All jobs require at least `Archtype: "x86"`. ARM build-drivers jobs use `Archtype: "arm"` instead.

### Tolerations

| Toleration Key | Value | Effect | Used By |
|----------------|-------|--------|---------|
| `Availability` | `SingleAZ` | `NoSchedule` | All build-drivers jobs (cost optimization) |
| `Archtype` | `arm` | `NoSchedule` | ARM build-drivers jobs only |

### Service Accounts

| Service Account | Used By | Purpose |
|-----------------|---------|---------|
| `driver-kit` | build-drivers, validate-dbg | S3 access for publishing driver artifacts |
| `update-jobs` | update-jobs postsubmit | Kubernetes API access for ConfigMap updates |
| *(default)* | Most other jobs | Standard Prow pod service account |

### Resource Patterns

**Build-drivers:** CPU limit 1.0 / request 750m, Memory limit 4Gi / request 2Gi

**Build-prow-images:** CPU 1.5, Memory 3Gi, Ephemeral-storage 2Gi

### Decoration Config

All jobs use `decorate: true`, enabling the Pod Utility decoration system:
- Init containers automatically clone the repository
- `path_alias` controls the clone path (e.g., `github.com/falcosecurity/test-infra` maps to `/home/prow/go/src/github.com/falcosecurity/test-infra`)
- `extra_refs` (periodic jobs) specifies which repos to clone before running

### run_if_changed Patterns

| Pattern | Purpose |
|---------|---------|
| `'^driverkit/config/.../x86_64/<distro>_.+'` | Trigger driver build for distro on x86 |
| `'^driverkit/config/.../aarch64/<distro>_.+'` | Trigger driver build for distro on ARM |
| `'^driverkit/config/[a-z0-9.+-]{5,}/(.+/)?'` | Trigger validation for any driverkit config |
| `'^images/<image-name>/'` | Trigger build/publish for image source changes |
| `'^config/org.yaml$\|^config/jobs/peribolos/.*'` | Trigger peribolos on org config changes |
| `'^config/config.yaml$'` | Trigger branchprotector on Prow config changes |
| `'^config/jobs/'` | Trigger update-jobs on job config changes |
| `'OWNERS$'` | Trigger peribolos-syncer on OWNERS changes |
| `"^registry.yaml"` | Trigger plugin/rules builds on registry changes |

### Container Images

| Image | Used By |
|-------|---------|
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/build-drivers:latest` | build-drivers, validate-dbg |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/build-plugins:latest` | build-plugins |
| `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/docker-dind` | build-prow-images |
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

Custom images are hosted in AWS ECR (`292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/`). Standard Prow components come from `gcr.io/k8s-prow/`.

### Poiana Bot Account

Many automation jobs use the `poiana` bot for creating PRs and signing commits:
- **GitHub token:** `oauth-token` secret at `/etc/github-token/oauth`
- **GPG signing:** `poiana-gpg-signing-key` and `poiana-gpg-signing-key-pub` secrets
- **GitHub endpoint:** `http://ghproxy.default.svc.cluster.local` with fallback to `https://api.github.com`

---

## 8. Related Specs

- [`ci-cd-infrastructure.md`](ci-cd-infrastructure.md) -- Prow cluster, AWS EKS, deployment architecture
- [`ci-cd-github-actions.md`](ci-cd-github-actions.md) -- GitHub Actions workflows across falcosecurity repos
- [`driver-distribution.md`](driver-distribution.md) -- Driver build grid, S3 distribution, falcoctl integration

---

## 9. Sources

| Topic | Source File |
|-------|-------------|
| Job configuration guide | [`config/jobs/README.md`](../refs/falcosecurity/test-infra/config/jobs/README.md) |
| Config uploader tool | [`prow/update-jobs/main.go`](../refs/falcosecurity/test-infra/prow/update-jobs/main.go) |
| Organization config | [`config/org.yaml`](../refs/falcosecurity/test-infra/config/org.yaml) |
| GitHub org management docs | [`docs/github-org-management.md`](../refs/falcosecurity/test-infra/docs/github-org-management.md) |
| Prow plugin config | [`config/plugins.yaml`](../refs/falcosecurity/test-infra/config/plugins.yaml) |
| Branch protection config | [`config/config.yaml`](../refs/falcosecurity/test-infra/config/config.yaml) |
| Peribolos job | [`peribolos.yaml`](../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) |
| Branch protector job | [`branchprotector.yaml`](../refs/falcosecurity/test-infra/config/jobs/branchprotector/branchprotector.yaml) |
| Autobump job | [`autobump.yaml`](../refs/falcosecurity/test-infra/config/jobs/autobump/autobump.yaml) |
| Check prow config job | [`check-prow-config.yaml`](../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml) |
| Update jobs | [`update-jobs.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml) |
| Update DBG job | [`update-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-dbg/update-dbg.yaml) |
| Update maintainers job | [`update-maintainers.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-maintainers/update-maintainers.yaml) |
| Update maintainers script | [`images/update-maintainers/entrypoint.sh`](../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh) |
| Update rules index | [`update-rules-index.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-rules-index/update-rules-index.yaml) |
| Update K8s manifests | [`update-falco-k8s-manifests.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-falco-k8s-manifests/update-falco-k8s-manifests.yaml) |
| Build drivers (example) | [`build-new-amazonlinux.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/build-new-amazonlinux.yaml) |
| Validate DBG configs | [`validate-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-drivers/validate-dbg.yaml) |
| Build plugins | [`build-plugins.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-plugins/build-plugins.yaml) |
| Build prow images | [`build-images.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-prow-images/build-images.yaml) |
| Publish prow images | [`publish-images.yaml`](../refs/falcosecurity/test-infra/config/jobs/build-prow-images/publish-images.yaml) |
| Peribolos-syncer (historical) | Previously under `config/jobs/update-github-teams/peribolos-syncer-*.yaml`; consolidated into [`peribolos.yaml`](../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) |
| Lifecycle: stale | [`periodic-stale.yaml`](../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-stale.yaml) |
| Lifecycle: rotten | [`periodic-rotten.yaml`](../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-rotten.yaml) |
| Lifecycle: close | [`periodic-close.yaml`](../refs/falcosecurity/test-infra/config/jobs/lifecycle-bot/periodic-close.yaml) |
| EKS upgrade reminder | [`prow-eks-upgrade.yaml`](../refs/falcosecurity/test-infra/config/jobs/recurring-ghissues/prow-eks-upgrade.yaml) |
| Prow jobs digest | [`digests/falcosecurity/test-infra/prow-jobs.md`](../digests/falcosecurity/test-infra/prow-jobs.md) |
| GitHub org management digest | [`digests/falcosecurity/test-infra/github-org-management.md`](../digests/falcosecurity/test-infra/github-org-management.md) |
