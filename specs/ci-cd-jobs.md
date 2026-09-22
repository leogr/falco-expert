# CI/CD Jobs

> Prow job system and organization automation: job types, complete job catalog, GitHub organization management, OWNERS-based approval workflow, and config uploader.

**Era:** 0.45 | **Source:** [`refs/falcosecurity/test-infra/config/jobs/`](../refs/falcosecurity/test-infra/config/jobs/)

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

The 0.45 pin separates two configured Prow installations. AWS retains merge policy, Peribolos, branch protection, lifecycle automation and its own jobs. OCI runs the driver grid, chart synchronization, registry indexes and maintainer/manifest automation. AWS loads only its job directory; OCI loads the explicit Kustomize list. The [backup AWS catalog](../refs/falcosecurity/test-infra/config/backup/aws/jobs/) is retained history, outside both active catalogs. These statements describe checked-in deployment configuration, not verified live cluster state.

**Sources:** [config/prow/aws/plugins.yaml](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L67), [config/jobs/oci/kustomization.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1), [config/prow/oci/kustomization.yaml](../refs/falcosecurity/test-infra/config/prow/oci/kustomization.yaml#L1).

The Falco project uses [Prow](https://docs.prow.k8s.io/docs/), the Kubernetes-native CI/CD system, to automate builds, testing, organization management, and infrastructure maintenance across the entire `falcosecurity` GitHub organization. All job definitions reside under [`config/jobs/`](../refs/falcosecurity/test-infra/config/jobs/) in the `test-infra` repository.

Prow supports three job types -- presubmit, postsubmit, and periodic -- each triggered by different events and scheduled by different components. Jobs are defined as YAML files organized by category in subdirectories. AWS propagates its catalog through `config-updater`; OCI reconciles its catalog through ArgoCD and Kustomize.

**Source:** [AWS job guide:5-12](../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12)

---

## 2. Job Types

### Presubmit

Presubmit jobs run **before a PR is merged**, triggered on pull request events (open, update, synchronize). They are scheduled by the `hook` component when GitHub webhooks arrive.

- Triggered against the specified `branches` (typically `^master$` or `^main$`)
- Scoped with `run_if_changed` to trigger only when specific file paths are modified, or set to `always_run: true` for every PR
- Results reported as GitHub commit status checks (unless `skip_report: true`)
- Manually re-triggerable with `/test <job-name>` comments

**Source:** [AWS job guide:14-22](../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L14-L22)

### Postsubmit

Postsubmit jobs run **after a PR is merged**, triggered on push events to the target branch. Scheduled by the `hook` component.

- Triggered on pushes to matching `branches`
- Can use `run_if_changed` to scope which file changes trigger the job
- Used for publishing, deploying, or syncing operations on the canonical branch
- `max_concurrency` can limit parallel runs

**Source:** [AWS job guide:5-12](../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12)

### Periodic

Periodic jobs run on a **schedule**, independent of repository events. Scheduled by the `horologium` component.

- Triggered by either a `cron` expression (e.g., `"0 8 * * *"`) or an `interval` (e.g., `6h`)
- Use `extra_refs` to check out a repository into the workspace before execution
- Not tied to a specific repository push event
- Used for maintenance tasks: org syncing, stale issue management, config checks, manifest updates

**Source:** [AWS job guide:11-12](../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L11-L12)

### Prow Components

| Component | Role |
|-----------|------|
| `horologium` | Schedules periodic jobs on cron/interval |
| `hook` | Schedules presubmit and postsubmit jobs from GitHub webhooks |
| `prow-controller-manager` | Schedules the Kubernetes pod for each ProwJob |
| `crier` | Reports job status back to GitHub as commit statuses |

**Source:** [AWS job guide:5-12](../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12)

---

## 3. Job Catalog

### 3.1. Driver Builds (build-drivers)

OCI schedules **71 driver postsubmits across 14 distro files**, plus the `validate-dbg` presubmit. They build kernel modules; older `.o` probes may remain in the distribution archive. Job presence does not imply that a distro currently has configs or that every configured kernel builds successfully.

**Build contract:** changes to matching driver configs on `master` trigger the corresponding distro/architecture job. Each job has `max_concurrency: 1`; the `driverkit-x86` and `driverkit-arm` queues each allow four jobs. Builds use digest-pinned `ghcr.io/falcosecurity/dbg-go:0.18.0`, running `configs build` with `--skip-existing --publish --ignore-errors --redirect-errors=/logs/artifacts/failing.log` and architecture/distro/kernel filters. Build results are best effort: missing prebuilt modules are acceptable, and the failure artifact distinguishes partial coverage from a complete build.

The non-root builder runs as UID/GID 65532. A separate, digest-pinned Docker 29.8.1 native sidecar is privileged and shares only its Unix socket with the builder. Jobs select `Application: driverkit` and the matching CPU architecture, tolerate `dedicated.falco.org/driverkit=true:NoSchedule`, and use `driver-kit` with automatic service-account token mounting disabled. Publication explicitly projects an `sts.amazonaws.com` token and assumes AWS role `falco-prow-driver-publisher` in `eu-west-1`.

**Sources:** [config/jobs/oci/build-drivers/build-new-debian.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L1), [config/prow/oci/config.yaml](../refs/falcosecurity/test-infra/config/prow/oci/config.yaml#L37), [config/jobs/oci/kustomization.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1).

| Distro file | Postsubmits | Partitioning |
|-------------|-------------|--------------|
| [build-new-almalinux.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-almalinux.yaml#L1) | 2 | per-target architecture variants |
| [build-new-amazonlinux.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-amazonlinux.yaml#L1) | 8 | per-target architecture variants |
| [build-new-bottlerocket.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-bottlerocket.yaml#L1) | 2 | per-target architecture variants |
| [build-new-centos.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-centos.yaml#L1) | 9 | x86 kernel majors 2–6; ARM majors 3–6 |
| [build-new-debian.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L1) | 2 | per-target architecture variants |
| [build-new-fedora.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-fedora.yaml#L1) | 2 | per-target architecture variants |
| [build-new-minikube.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-minikube.yaml#L1) | 2 | per-target architecture variants |
| [build-new-photon.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-photon.yaml#L1) | 2 | per-target architecture variants |
| [build-new-talos.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-talos.yaml#L1) | 2 | per-target architecture variants |
| [build-new-ubuntu-aws.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-aws.yaml#L1) | 8 | kernel majors 3–6, both architectures |
| [build-new-ubuntu-azure.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-azure.yaml#L1) | 8 | kernel majors 3–6, both architectures |
| [build-new-ubuntu-gcp.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-gcp.yaml#L1) | 8 | kernel majors 3–6, both architectures |
| [build-new-ubuntu-generic.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-generic.yaml#L1) | 8 | kernel majors 3–6, both architectures |
| [build-new-ubuntu-gke.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-gke.yaml#L1) | 8 | kernel majors 3–6, both architectures |

`validate-dbg` runs two unprivileged containers (`configs validate --architecture=amd64` and `arm64`) using the same DBG image. It has no Docker daemon, publication flag or AWS publisher token. Each validator requests 250m CPU/256Mi and limits 1 CPU/2Gi; those are distinct from the build resources.

**Source:** [config/jobs/oci/build-drivers/validate-dbg.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/validate-dbg.yaml#L1).

### 3.2. Plugin Builds (build-plugins)

Updates plugin registry documentation and the falcoctl distribution index when the plugin registry or release tags change. These Prow jobs do not compile plugin binaries; the script runs `make update-readme`, proposes a README PR, runs `make update-index`, and pushes index changes to `falcoctl:gh-pages`.

**Source:** [`build-plugins.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `build-plugins-on-registry-changed-postsubmit` | Postsubmit | `falcosecurity/plugins` | `run_if_changed: "^registry.yaml"` on `^main$` |
| `build-plugins-on-plugin-release-postsubmit` | Postsubmit | `falcosecurity/plugins` | Branch: `^plugins/[a-z]+[a-z0-9-_\-]*/v\d+\.\d+\.\d+$` |

- **Image:** `ghcr.io/falcosecurity/test-infra/build-plugins` (digest pinned in the job)
- **Command:** `/on-registry-changed.sh /etc/github-token/oauth`
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)
- **Node selector:** `Archtype: "x86"`

### 3.3. Image Builds (build-prow-images)

The retained AWS catalog defines eight image-build presubmits and eight ECR-publish postsubmits. OCI automation images and the DBG updater have dedicated GitHub Actions publication workflows.

**Source:** [`build-images.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/build-prow-images/build-images.yaml), [`publish-images.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/build-prow-images/publish-images.yaml)

| Image | `run_if_changed` |
|-------|-------------------|
| `golang` | `^images/golang/` |
| `update-jobs` | `^images/update-jobs/` |
| `update-maintainers` | `^images/update-maintainers/` |
| `build-plugins` | `^images/build-plugins/` |
| `update-rules-index` | `^images/update-rules-index/` |
| `update-falco-k8s-manifests` | `^images/update-falco-k8s-manifests/` |
| `docker-dind` | `^images/docker-dind/` |
| `sync-charts` | `^images/sync-charts/` |

All share:
- **Repository:** `falcosecurity/test-infra`, branch `^master$`
- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/docker-dind`
- **Command:** Presubmit uses `build.sh`, postsubmit uses `publish.sh`
- **Resources:** CPU 1.5, Memory 3Gi, Ephemeral-storage 2Gi
- **Security context:** `privileged: true`
- **Environment:** `AWS_REGION=eu-west-1`

### 3.4. Config Validation (check-prow-config)

Validates Prow configuration files (config.yaml, plugins.yaml, job configs) for correctness.

**Source:** [`check-prow-config.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/check-prow-config/check-prow-config.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `check-prow-config` | Presubmit | `always_run: true` on `^master$` |
| `check-prow-config-periodic` | Periodic | `interval: 1h` |

- **Image:** `gcr.io/k8s-prow/checkconfig:v20240805-37a08f946`
- **Command:** `checkconfig --config-path=config/prow/aws/config.yaml --job-config-path=config/jobs/aws --plugin-config=config/prow/aws/plugins.yaml`
- The periodic variant uses `extra_refs` to clone `falcosecurity/test-infra` at `master`

### 3.5. Config Upload (update-jobs)

The automatic `update-jobs-pr` postsubmit was removed. AWS uses `config-updater` with the AWS job catalog; OCI builds its job ConfigMap through Kustomize. The uploader remains a manual tool that replaces selected existing ConfigMaps.

**Sources:** [AWS mappings](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L67-L77), [OCI catalog](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml), [manual uploader](../refs/falcosecurity/test-infra/prow/update-jobs/README.md).

The config uploader is a Go program ([`prow/update-jobs/main.go`](../refs/falcosecurity/test-infra/prow/update-jobs/main.go)) that:
1. Authenticates to the Kubernetes cluster (in-cluster SA or kubeconfig)
2. Reads configuration files from the local filesystem
3. Updates ConfigMaps in the `default` namespace

CLI flags: `--config-path` (config ConfigMap), `--jobs-config-path` (job-config ConfigMap), `--plugins-config-path` (plugins ConfigMap), `--kubeconfig` (optional).

For single-file configs, the file is stored under a key named `<name>.yaml`. For directory configs, all `.yaml` files are combined with basenames as keys.

**Source:** [`prow/update-jobs/main.go:41-42, 126-168`](../refs/falcosecurity/test-infra/prow/update-jobs/main.go#L41-L42)

### 3.6. DBG Updates (update-dbg)

Periodically updates the Drivers Build Grid (DBG) configuration by generating driverkit configs from kernel-crawler output.

**Source:** [`update-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `update-dbg` | Periodic | `cron: "0 8 * * *"` (daily 08:00 UTC) |

- **Image:** `ghcr.io/falcosecurity/test-infra/update-dbg:0.18.0-1`
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/test-infra` at `master` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

### 3.7. Maintainers Sync (update-maintainers)

Periodically queries GitHub organization data to update `evolution/maintainers.yaml`.

**Source:** [`update-maintainers.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `update-maintainers` | Periodic | `cron: "0 9 * * *"` (daily 09:00 UTC) |

- **Image:** `ghcr.io/falcosecurity/test-infra/update-maintainers` (digest pinned in the job)
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/evolution` at `main` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

The entrypoint script ([`images/update-maintainers/entrypoint.sh`](../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh)):
1. Runs `maintainers-generator` to query the GitHub API and produce `maintainers.yaml`
2. Runs `make` to regenerate `README.md` and `MAINTAINERS.md` in evolution
3. Creates a PR via `pr-creator` if changes are detected (branch: `update-evolution-files`)

### 3.8. Rules Index (update-rules-index)

Updates the Falco rules index (OCI distribution metadata) when the rules registry changes.

**Source:** [`update-rules-index.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `update-rules-index-on-registry-changed-postsubmit` | Postsubmit | `falcosecurity/rules` | `run_if_changed: "^registry.yaml"` on `^main$` |

- **Image:** `ghcr.io/falcosecurity/test-infra/update-rules-index` (digest pinned in the job)
- **Command:** `/on-registry-changed.sh /etc/github-token/oauth`
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

### 3.9. K8s Manifests (update-falco-k8s-manifests)

Periodically renders Helm charts into plain Kubernetes manifests in the `deploy-kubernetes` repository.

**Source:** [`update-falco-k8s-manifests.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/automation/manifests.yaml)

| Job Name | Type | Schedule | `HELM_CHART_NAME` |
|----------|------|----------|--------------------|
| `update-falco-k8s-manifests` | Periodic | daily 10:00 UTC | `falco` |
| `update-falco-sidekick-k8s-manifests` | Periodic | daily 12:00 UTC | `falcosidekick` |
| `update-event-generator-k8s-manifests` | Periodic | daily 13:00 UTC | `event-generator` |

All share:
- **Image:** `ghcr.io/falcosecurity/test-infra/update-falco-k8s-manifests` (digest pinned in the job)
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/deploy-kubernetes` at `main` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

### 3.10. Branch Protection (branchprotector)

Applies branch protection rules to all repositories in the `falcosecurity` organization based on the Prow config.

**Source:** [`branchprotector.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/branchprotector/branchprotector.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `branchprotector-post-submit` | Postsubmit | `run_if_changed: '^config/prow/aws/config.yaml$'` on `^master$` |
| `branchprotector-hourly` | Periodic | `cron: "55 * * * *"` (hourly at :55) |

- **Image:** `gcr.io/k8s-prow/branchprotector:v20240805-37a08f946`
- **Command:** `branchprotector --config-path=config/prow/aws/config.yaml --job-config-path=config/jobs/aws --github-token-path=/etc/github/oauth --confirm`
- **max_concurrency:** 1

Branch protection rules are defined in [`config/prow/aws/config.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml). Key global defaults:

| Setting | Value |
|---------|-------|
| `enforce_admins` | `true` |
| `restrictions.teams` | `["maintainers", "machine_users"]` |
| `dismiss_stale_reviews` | `true` |
| `require_code_owner_reviews` | `true` |
| `required_approving_review_count` | `1` |
| `strict` (status checks) | `false` (rebase merge makes this unnecessary) |

All repositories require the `dco` status check (Developer Certificate of Origin).

**Source:** [`config/prow/aws/config.yaml:52-71`](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L52-L71)

### 3.11. Autobump

Automatically bumps Prow component versions to the latest release candidate by creating PRs.

**Source:** [`autobump.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/autobump/autobump.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `ci-test-infra-autobump-prow` | Periodic | `cron: "05 15 * * 4"` (Thursday 15:05 UTC) |

- **Image:** `gcr.io/k8s-prow/generic-autobumper:latest`
- **Command:** `generic-autobumper --config=config/prow/aws/autobump-config.yaml --signoff`
- **Extra refs:** Clones `falcosecurity/test-infra` at `master`

### 3.12. Lifecycle Bot

Manages the lifecycle of GitHub issues across the entire `falcosecurity` organization using a stale/rotten/close escalation pattern.

**Escalation pipeline:** Active --> Stale (90 days inactivity) --> Rotten (30 more days) --> Closed (30 more days). Issues labeled `lifecycle/frozen` are exempt.

| Job Name | Type | Schedule | Action |
|----------|------|----------|--------|
| `periodic-stale` | Periodic | `interval: 6h` | Adds `lifecycle/stale` after 90 days (2160h) inactivity |
| `periodic-rotten` | Periodic | `interval: 6h` | Adds `lifecycle/rotten` after 30 more days (720h) |
| `periodic-close` | Periodic | `interval: 6h` | Closes after 30 more days (720h) |

**Sources:** [`periodic-stale.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-stale.yaml), [`periodic-rotten.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-rotten.yaml), [`periodic-close.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-close.yaml)

All share:
- **Image:** `gcr.io/k8s-prow/commenter:v20240731-a5d9345e59`
- **Command:** `commenter` with `--query=org:falcosecurity -label:lifecycle/frozen ...`
- **Ceiling:** `--ceiling=10` (max 10 issues per run)

### 3.13. EKS Upgrade Reminder

Periodically creates GitHub issues as reminders for infrastructure maintenance tasks.

**Source:** [`prow-eks-upgrade.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/recurring-ghissues/prow-eks-upgrade.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `prow-eks-upgrade-reminder` | Periodic | `cron: "0 7 21 6 *"` (June 21 at 07:00 UTC) |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/ghissue:latest`
- **Command:** `/usr/local/bin/entrypoint.sh ghissue create --byline=false issue.txt`
- **Environment:** `GH_REPO=test-infra`, `GH_ISSUE_TITLE="Upgrade EKS cluster to latest stable version"`, `GH_ISSUE_TAGS="maintenance,eks"`

---

### 3.14. Chart Synchronization

OCI defines four postsubmits: `sync-charts-event-generator`, `sync-charts-falco`, `sync-charts-k8s-metacollector`, and `sync-charts-falco-operator`. They watch the source chart directory, check out the charts repository, and propose a chart synchronization PR when the source chart version differs. The sync preserves target OWNERS and excludes Git metadata. Same-version source changes are intentionally skipped by the script.

**Sources:** [config/jobs/oci/automation/charts.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/automation/charts.yaml#L1), [images/sync-charts/entrypoint.sh](../refs/falcosecurity/test-infra/images/sync-charts/entrypoint.sh#L189).

The active OCI manifest jobs cover Falco (10:00 UTC), Falcosidekick (12:00), and event-generator (13:00). The former 11:00 falco-exporter job exists only in the backup catalog. OCI registry jobs share the capacity-one `artifact-index` queue and use a dedicated current-branch registry checkout even when triggered by a plugin release tag.

**Sources:** [config/jobs/oci/automation/manifests.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/automation/manifests.yaml#L1), [config/jobs/oci/automation/registry.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml#L1), [images/build-plugins/on-registry-changed.sh](../refs/falcosecurity/test-infra/images/build-plugins/on-registry-changed.sh#L153), [images/update-rules-index/on-registry-changed.sh](../refs/falcosecurity/test-infra/images/update-rules-index/on-registry-changed.sh#L119).

The retained AWS `build-aws-terraform` presubmit runs against `falcosecurity/falco-aws-terraform`; it is distinct from the test-infra AWS/OCI platform validation workflows. [Source](../refs/falcosecurity/test-infra/config/jobs/aws/build-aws-terraform/build-aws-terraform.yaml#L1).

## 4. GitHub Organization Management

The `falcosecurity` GitHub organization is declaratively managed through [`config/org.yaml`](../refs/falcosecurity/test-infra/config/org.yaml), the single source of truth for organization settings, membership, teams, and repository configurations.

**Source:** [`config/org.yaml`](../refs/falcosecurity/test-infra/config/org.yaml), [`docs/github-org-management.md`](../refs/falcosecurity/test-infra/docs/github-org-management.md)

### What org.yaml Defines

- **Organization settings:** `default_repository_permission: read`, `members_can_create_repositories: false`
- **Organization admins:** 10 users including CNCF/LF representatives and core maintainers
- **Organization members:** 44 members (no inherent write access; access is managed through teams)
- **Team structure:** `admins`, `core-maintainers`, and ~40 per-repository `<repo>-maintainers` teams
- **Repository configurations:** merge strategy (`allow_rebase_merge: true`, others disabled), project/wiki settings, default branch, archived status

**Source:** [`config/org.yaml:1-1055`](../refs/falcosecurity/test-infra/config/org.yaml#L1-L1055)

### Peribolos

[Peribolos](https://github.com/kubernetes/test-infra/blob/master/prow/cmd/peribolos/README.md) applies the declarative `org.yaml` configuration to the live GitHub organization.

**Source:** [`peribolos.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml)

| Job Name | Type | Trigger | Mode |
|----------|------|---------|------|
| `peribolos-pre-submit` | Presubmit | `run_if_changed: '^config/org.yaml$\|^config/jobs/aws/peribolos/.*'` | **Dry-run** (no `--confirm`) |
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

`poiana` (GitHub ID: 51138685) is the project's automation bot. It is listed as an organization admin and is the sole maintainer of the `machine_users` team, which has **admin** access to 39 repositories.

- **GitHub token:** Mounted from `oauth-token` secret at `/etc/github-token/oauth`
- **GPG signing:** `poiana-gpg-signing-key` and `poiana-gpg-signing-key-pub` secrets
- **GPG key ID:** `EC9875C7B990D55F3B44D6E45F284448FF941C8F`
- **Email:** `51138685+poiana@users.noreply.github.com`
- **GitHub endpoint:** `http://ghproxy.default.svc.cluster.local` (Prow's GitHub proxy) with fallback to `https://api.github.com`

**Source:** [`config/org.yaml:16, 845-889`](../refs/falcosecurity/test-infra/config/org.yaml#L16)

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

**Source:** [`config/prow/aws/plugins.yaml:L2-61, L90-139`](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L2-L61)

### OWNERS and Team Membership

OWNERS is the current path-approval source; it was also used by historical team-sync jobs:
1. **Prow access control**: Determining who can approve/review PRs
2. **Historical team membership input**: the former peribolos-syncer jobs read approvers; that fan-out is absent from the active catalogs at this pin

Do not assume an OWNERS edit updates GitHub teams automatically. Verify the organization YAML and the active automation separately.

---

## 6. Team Sync (peribolos-syncer) -- Consolidated

The historical per-repository `peribolos-syncer` fan-out is absent from both active catalogs at this pin. Do not infer that Peribolos or `update-maintainers` replaces its OWNERS-to-team synchronization: Peribolos applies the existing organization YAML; `update-maintainers` queries GitHub and creates an evolution documentation PR. Neither inspected entry point regenerates the organization YAML from repository OWNERS.

**Sources:** [config/jobs/aws/peribolos/peribolos.yaml](../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml#L1), [images/update-maintainers/entrypoint.sh](../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh#L35), [config/jobs/oci/kustomization.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1). For the previous mechanism, consult the `0.44.x` era snapshot selectively.

## 7. Common Job Patterns

| Property | AWS jobs | OCI jobs |
|----------|----------|----------|
| Catalog | AWS directory, loaded by `config-updater` | Explicit Kustomize file list |
| Node selection | `Archtype: x86` in retained jobs | `Application: automation` or `driverkit`, matching `Archtype` and `kubernetes.io/arch` |
| Isolation | Per-job AWS pod settings | Dedicated pool taints; admission policy rejects host namespaces, host paths and host ports |
| Service accounts | Per-job AWS settings | `automation` or `driver-kit`; no automatic token mount |
| Images | Retained ECR job images and older Prow tools | GHCR automation/DBG images; current Prow utility images pinned by digest |
| Default timeout | 24h | 24h; automation jobs override to 1h |

The OCI admission policy permits privilege only for the pinned Docker native sidecar in driver jobs. Driver builders request 1 CPU/2Gi (limits 2 CPU/4Gi); the Docker sidecar separately requests 2 CPU/4Gi/96Gi ephemeral storage (limits 6 CPU/32Gi/120Gi). Ordinary OCI automation requests 500m CPU/1Gi and limits 2 CPU/4Gi. `update-dbg` uses smaller requests. Consult the job definition before estimating pod or cluster capacity.

OCI queues limit `artifact-index` to one concurrent job, `automation` to three, and each driver architecture to four. The shared artifact-index queue serializes plugin and rules writers to the same falcoctl index branch. Each job additionally declares its own concurrency cap.

**Sources:** [config/prow/oci/config.yaml](../refs/falcosecurity/test-infra/config/prow/oci/config.yaml#L37), [config/prow/oci/driverkit-policy.yaml](../refs/falcosecurity/test-infra/config/prow/oci/driverkit-policy.yaml#L1), [config/jobs/oci/build-drivers/build-new-debian.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L1), [config/jobs/oci/automation/registry.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml#L1), [config/jobs/oci/automation/maintainers.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml#L1), [config/jobs/oci/update-dbg/update-dbg.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml#L1).

Job `run_if_changed` patterns are repository-relative. A catalog edit is not itself evidence that a job watches that path: use its actual regex. AWS Peribolos watches the organization YAML and its AWS job directory; OCI chart jobs watch each source repository's chart directory. Periodics use `extra_refs` to select their worktree, while OCI registry jobs explicitly check out the current registry branch separately from the triggering release tag.

**Sources:** [config/jobs/aws/peribolos/peribolos.yaml](../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml#L1), [config/jobs/oci/automation/charts.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/automation/charts.yaml#L1), [config/jobs/oci/automation/registry.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml#L1).

## 8. Related Specs

- [`ci-cd-infrastructure.md`](ci-cd-infrastructure.md) -- Prow cluster, AWS EKS, deployment architecture
- [`ci-cd-github-actions.md`](ci-cd-github-actions.md) -- GitHub Actions workflows across falcosecurity repos
- [`driver-distribution.md`](driver-distribution.md) -- Driver build grid, S3 distribution, falcoctl integration

---

## 9. Sources

| Topic | Source File |
|-------|-------------|
| OCI job loading | [Kustomize catalog](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1) |
| OCI chart sync | [charts.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/automation/charts.yaml#L1) |
| OCI registry scripts | [plugin metadata](../refs/falcosecurity/test-infra/images/build-plugins/on-registry-changed.sh#L153), [rules index](../refs/falcosecurity/test-infra/images/update-rules-index/on-registry-changed.sh#L119) |
| Job configuration guide | [AWS job guide:5-12](../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12) |
| Config uploader tool | [`prow/update-jobs/main.go`](../refs/falcosecurity/test-infra/prow/update-jobs/main.go) |
| Organization config | [`config/org.yaml`](../refs/falcosecurity/test-infra/config/org.yaml) |
| GitHub org management docs | [`docs/github-org-management.md`](../refs/falcosecurity/test-infra/docs/github-org-management.md) |
| Prow plugin config | [`config/prow/aws/plugins.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml) |
| Branch protection config | [`config/prow/aws/config.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml) |
| Peribolos job | [`peribolos.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml) |
| Branch protector job | [`branchprotector.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/branchprotector/branchprotector.yaml) |
| Autobump job | [`autobump.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/autobump/autobump.yaml) |
| Check prow config job | [`check-prow-config.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/check-prow-config/check-prow-config.yaml) |
| Update jobs | [`update-jobs.yaml`](../refs/falcosecurity/test-infra/prow/update-jobs/README.md) |
| Update DBG job | [`update-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml) |
| Update maintainers job | [`update-maintainers.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml) |
| Update maintainers script | [`images/update-maintainers/entrypoint.sh`](../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh) |
| Update rules index | [`update-rules-index.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml) |
| Update K8s manifests | [`update-falco-k8s-manifests.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/automation/manifests.yaml) |
| Build drivers (example) | [`build-new-amazonlinux.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-amazonlinux.yaml) |
| Validate DBG configs | [`validate-dbg.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/validate-dbg.yaml) |
| Build plugins | [`build-plugins.yaml`](../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml) |
| Build prow images | [`build-images.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/build-prow-images/build-images.yaml) |
| Publish prow images | [`publish-images.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/build-prow-images/publish-images.yaml) |
| Lifecycle: stale | [`periodic-stale.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-stale.yaml) |
| Lifecycle: rotten | [`periodic-rotten.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-rotten.yaml) |
| Lifecycle: close | [`periodic-close.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-close.yaml) |
| EKS upgrade reminder | [`prow-eks-upgrade.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/recurring-ghissues/prow-eks-upgrade.yaml) |
| Prow jobs digest | [`digests/falcosecurity/test-infra/prow-jobs.md`](../digests/falcosecurity/test-infra/prow-jobs.md) |
| GitHub org management digest | [`digests/falcosecurity/test-infra/github-org-management.md`](../digests/falcosecurity/test-infra/github-org-management.md) |
