# Falco Test Infrastructure -- Prow Job Catalog

> **Era:** 0.45 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

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
   - [update-github-teams](#311-update-github-teams-consolidated)
   - [peribolos](#312-peribolos)
   - [branchprotector](#313-branchprotector)
   - [autobump](#314-autobump)
   - [lifecycle-bot](#315-lifecycle-bot)
   - [recurring-ghissues](#316-recurring-ghissues)
4. [Config Uploader Tool](#4-config-uploader-tool)
5. [Job Configuration Patterns](#5-job-configuration-patterns)

---

## 1. Job Types Overview

The 0.45 pin separates two configured Prow installations. AWS retains merge policy, Peribolos, branch protection, lifecycle automation and its own jobs. OCI runs the driver grid, chart synchronization, registry indexes and maintainer/manifest automation. AWS loads only its job directory; OCI loads the explicit Kustomize list. The [backup AWS catalog](../../../refs/falcosecurity/test-infra/config/backup/aws/jobs/) is retained history, outside both active catalogs. These statements describe checked-in deployment configuration, not verified live cluster state.

**Sources:** [config/prow/aws/plugins.yaml](../../../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L67), [config/jobs/oci/kustomization.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1), [config/prow/oci/kustomization.yaml](../../../refs/falcosecurity/test-infra/config/prow/oci/kustomization.yaml#L1).

Prow supports three fundamental job types, each triggered by different events. The following summarizes how each type is used in the Falco infrastructure. **Source:** [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12)

### Presubmit Jobs

Presubmit jobs run **before a PR is merged** (i.e., on pull request events). They are configured per-repository and triggered by the `hook` component when GitHub webhooks arrive. Key properties:

- Triggered when a PR is opened or updated against the specified `branches` (typically `^master$` or `^main$`)
- Can be scoped with `run_if_changed` to only trigger when specific file paths are modified
- Can be set to `always_run: true` to run on every PR regardless of changed files
- Results are reported back to GitHub as commit status checks (unless `skip_report: true`)
- Can be manually re-triggered with `/test <job-name>` comments ([AWS job guide:14-22](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L14-L22))

### Postsubmit Jobs

Postsubmit jobs run **after a PR is merged** (i.e., on push events to the target branch). They are configured per-repository under a `postsubmits:` key with the format `org/repo:`. Key properties:

- Triggered on pushes to matching `branches`
- Can use `run_if_changed` to scope which file changes trigger the job
- Often used for publishing, deploying, or syncing operations that should only happen on the canonical branch
- `max_concurrency` can limit parallel runs ([AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12))

### Periodic Jobs

Periodic jobs run on a **schedule**, independent of any repository event. They are scheduled by the `horologium` component. Key properties:

- Triggered by either a `cron` expression (e.g., `"0 8 * * *"`) or an `interval` (e.g., `1h`, `6h`, `24h`)
- Use `extra_refs` to check out a repository into the workspace before execution
- Not tied to a specific repository push event
- Used for maintenance tasks: org syncing, stale issue management, config checks, manifest updates ([AWS job guide:11-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L11-L12))

### Prow Components Involved

| Component | Role | Source |
|-----------|------|--------|
| `horologium` | Schedules periodic jobs | [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12) |
| `hook` | Schedules presubmit and postsubmit jobs from GitHub webhooks | [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12) |
| `prow-controller-manager` | Schedules the Kubernetes pod for a ProwJob | [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12) |
| `crier` | Reports job status back to GitHub | [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12) |

---

## 2. How to Add Jobs

Choose the cloud catalog first. AWS jobs belong under [the AWS catalog](../../../refs/falcosecurity/test-infra/config/jobs/aws/); `config-updater` reloads matching YAML after merge. OCI jobs belong under [the OCI catalog](../../../refs/falcosecurity/test-infra/config/jobs/oci/) and must also appear in its [Kustomize file list](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1); ArgoCD deploys that generated ConfigMap. Files in backup directories are not loaded.

The former `update-jobs-pr` postsubmit is absent from this snapshot; the retained uploader is manual. Validate the chosen cloud's config and rendered manifests before changing its catalog. The AWS guide links the local testing instructions for verifying new jobs.

**Sources:** [config/prow/aws/plugins.yaml](../../../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L67), [config/applications/oci/prow.yaml](../../../refs/falcosecurity/test-infra/config/applications/oci/prow.yaml#L10), [tools/ci/verify-prow.sh](../../../refs/falcosecurity/test-infra/tools/ci/verify-prow.sh#L12), [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12).

## 3. Complete Job Catalog

### 3.1. build-drivers

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

### 3.2. build-plugins

**Purpose:** Updates plugin registry documentation and the falcoctl distribution index when the registry or plugin release tags change. The script runs `make update-readme`, proposes a README PR, runs `make update-index`, and pushes the index to `falcoctl:gh-pages`; it does not compile plugin binaries.

**Source:** [build-plugins.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `build-plugins-on-registry-changed-postsubmit` | Postsubmit | `falcosecurity/plugins` | `run_if_changed: "^registry.yaml"` on `^main$` |
| `build-plugins-on-plugin-release-postsubmit` | Postsubmit | `falcosecurity/plugins` | Branch pattern: `^plugins/[a-z]+[a-z0-9-_\-]*/v\d+\.\d+\.\d+$` |

**Configuration:**

- **Image:** `ghcr.io/falcosecurity/test-infra/build-plugins` (digest pinned in the job)
- **Command:** `/on-registry-changed.sh /etc/github-token/oauth`
- **Volumes:** `oauth-token` secret (GitHub token), `poiana-gpg-signing-key` secret (GPG signing)
- **Node selector:** `Archtype: "x86"`

---

### 3.3. build-prow-images

**Purpose:** The retained AWS catalog defines eight image-build presubmits and eight ECR-publish postsubmits, including sync-charts. Build-drivers and update-dbg are absent from this AWS image-job catalog; OCI automation images use their GitHub Actions publication workflows.

#### Presubmit Build Jobs

**Source:** [build-images.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/build-prow-images/build-images.yaml)

| Job Name | Trigger (`run_if_changed`) |
|----------|--------------------------|
| `build-images-golang` | `^images/golang/` |
| `build-images-update-jobs` | `^images/update-jobs/` |
| `build-images-update-maintainers` | `^images/update-maintainers/` |
| `build-images-build-plugins` | `^images/build-plugins/` |
| `build-images-update-rules-index` | `^images/update-rules-index/` |
| `build-images-update-falco-k8s-manifests` | `^images/update-falco-k8s-manifests/` |
| `build-images-sync-charts` | `^images/sync-charts/` |
| `build-images-build-docker-dind` | `^images/docker-dind/` |

All presubmit build jobs share:

- **Repository:** `falcosecurity/test-infra`, branch `^master$`
- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/docker-dind`
- **Command:** `/home/prow/go/src/github.com/falcosecurity/test-infra/images/build.sh <image-path>`
- **Resources:** CPU 1.5, Memory 3Gi, Ephemeral-storage 2Gi
- **Security Context:** `privileged: true`
- **Environment:** `AWS_REGION=eu-west-1`

#### Postsubmit Publish Jobs

**Source:** [publish-images.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/build-prow-images/publish-images.yaml)

| Job Name | Trigger (`run_if_changed`) |
|----------|--------------------------|
| `publish-images-build-plugins` | `^images/build-plugins/` |
| `publish-images-update-rules-index` | `^images/update-rules-index/` |
| `publish-images-golang` | `^images/golang/` |
| `publish-images-update-jobs` | `^images/update-jobs/` |
| `publish-images-update-maintainers` | `^images/update-maintainers/` |
| `publish-images-update-falco-k8s-manifests` | `^images/update-falco-k8s-manifests/` |
| `publish-images-sync-charts` | `^images/sync-charts/` |
| `publish-images-build-docker-dind` | `^images/docker-dind/` |

Same configuration as presubmit except the command uses `publish.sh` instead of `build.sh`.

---

### 3.4. build-aws-terraform

**Purpose:** Validates Terraform configurations for the Falco AWS infrastructure.

**Source:** [build-aws-terraform.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/build-aws-terraform/build-aws-terraform.yaml)

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

**Source:** [check-prow-config.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/check-prow-config/check-prow-config.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `check-prow-config` | Presubmit | `always_run: true` on `^master$` |
| `check-prow-config-periodic` | Periodic | `interval: 1h` |

- **Image:** `gcr.io/k8s-prow/checkconfig:v20240805-37a08f946`
- **Command:** `checkconfig --config-path=config/prow/aws/config.yaml --job-config-path=config/jobs/aws --plugin-config=config/prow/aws/plugins.yaml`
- The periodic variant uses `extra_refs` to clone `falcosecurity/test-infra` at `master`

---

### 3.6. update-jobs

The former `update-jobs-pr` postsubmit is absent in the 0.45 snapshot. The retained uploader is a manual utility that replaces selected existing ConfigMaps. AWS job updates are handled by `config-updater`, scoped to the AWS catalog; OCI generates its job ConfigMap through Kustomize.

**Sources:** [manual uploader](../../../refs/falcosecurity/test-infra/prow/update-jobs/README.md), [AWS config-updater mappings](../../../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L67-L77), [OCI job catalog](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml).

---

### 3.7. update-dbg

**Purpose:** Periodically updates the Drivers Build Grid (DBG) configuration in the `test-infra` repository by running driverkit config generation based on kernel-crawler output.

**Source:** [update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `update-dbg` | Periodic | `cron: "0 8 * * *"` (daily at 08:00 UTC) |

- **Image:** `ghcr.io/falcosecurity/test-infra/update-dbg:0.18.0-1`
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/test-infra` at `master` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing for commits)

---

### 3.8. update-maintainers

**Purpose:** Periodically queries GitHub organization data to update the `evolution` repository's `maintainers.yaml`.

**Source:** [update-maintainers.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `update-maintainers` | Periodic | `cron: "0 9 * * *"` (daily at 09:00 UTC) |

- **Image:** `ghcr.io/falcosecurity/test-infra/update-maintainers` (digest pinned in the job)
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/evolution` at `main` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

---

### 3.9. update-rules-index

**Purpose:** Updates the Falco rules index (OCI distribution metadata) when the rules registry changes.

**Source:** [update-rules-index.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml)

| Job Name | Type | Repository | Trigger |
|----------|------|------------|---------|
| `update-rules-index-on-registry-changed-postsubmit` | Postsubmit | `falcosecurity/rules` | `run_if_changed: "^registry.yaml"` on `^main$` |

- **Image:** `ghcr.io/falcosecurity/test-infra/update-rules-index` (digest pinned in the job)
- **Command:** `/on-registry-changed.sh /etc/github-token/oauth`
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

---

### 3.10. update-falco-k8s-manifests

**Purpose:** Periodically renders Helm charts into plain Kubernetes manifests in the `deploy-kubernetes` repository. Each Helm chart has its own scheduled job.

**Source:** [update-falco-k8s-manifests.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/manifests.yaml)

| Job Name | Type | Schedule | `HELM_CHART_NAME` |
|----------|------|----------|-------------------|
| `update-falco-k8s-manifests` | Periodic | `cron: "0 10 * * *"` (daily 10:00 UTC) | `falco` |
| `update-falco-sidekick-k8s-manifests` | Periodic | `cron: "0 12 * * *"` (daily 12:00 UTC) | `falcosidekick` |
| `update-event-generator-k8s-manifests` | Periodic | `cron: "0 13 * * *"` (daily 13:00 UTC) | `event-generator` |

All share:

- **Image:** `ghcr.io/falcosecurity/test-infra/update-falco-k8s-manifests` (digest pinned in the job)
- **Command:** `/entrypoint.sh /etc/github-token/oauth`
- **Extra refs:** Clones `falcosecurity/deploy-kubernetes` at `main` (workdir: true)
- **Volumes:** `oauth-token` (GitHub), `poiana-gpg-signing-key` (GPG signing)

---

### 3.11. update-github-teams (Consolidated)

The historical per-repository `peribolos-syncer` fan-out is absent from both active catalogs at this pin. Do not infer that Peribolos or `update-maintainers` replaces its OWNERS-to-team synchronization: Peribolos applies the existing organization YAML; `update-maintainers` queries GitHub and creates an evolution documentation PR. Neither inspected entry point regenerates the organization YAML from repository OWNERS.

**Sources:** [config/jobs/aws/peribolos/peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml#L1), [images/update-maintainers/entrypoint.sh](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh#L35), [config/jobs/oci/kustomization.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1). For the previous mechanism, consult the `0.44.x` era snapshot selectively.

### 3.12. peribolos

**Purpose:** Manages the `falcosecurity` GitHub organization structure (members, teams, team membership, repos) using Peribolos, a Prow component that applies a declarative org config (`config/org.yaml`).

**Source:** [peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `peribolos-pre-submit` | Presubmit | `run_if_changed: '^config/org.yaml$\|^config/jobs/aws/peribolos/.*'` on `^master$` |
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

**Source:** [branchprotector.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/branchprotector/branchprotector.yaml)

| Job Name | Type | Trigger |
|----------|------|---------|
| `branchprotector-post-submit` | Postsubmit | `run_if_changed: '^config/prow/aws/config.yaml$'` on `^master$` |
| `branchprotector-hourly` | Periodic | `cron: "55 * * * *"` (every hour at :55) |

- **Image:** `gcr.io/k8s-prow/branchprotector:v20240805-37a08f946`
- **Command:** `branchprotector --config-path=config/prow/aws/config.yaml --job-config-path=config/jobs/aws --github-token-path=/etc/github/oauth --confirm`
- **max_concurrency:** 1

---

### 3.14. autobump

**Purpose:** Automatically bumps Prow component versions to the latest release candidate by creating PRs.

**Source:** [autobump.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/autobump/autobump.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `ci-test-infra-autobump-prow` | Periodic | `cron: "05 15 * * 4"` (Thursday at 15:05 UTC) |

- **Image:** `gcr.io/k8s-prow/generic-autobumper:latest`
- **Command:** `generic-autobumper --config=config/prow/aws/autobump-config.yaml --signoff`
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
- [periodic-stale.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-stale.yaml)
- [periodic-rotten.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-rotten.yaml)
- [periodic-close.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-close.yaml)

All share:

- **Image:** `gcr.io/k8s-prow/commenter:v20240731-a5d9345e59`
- **Command:** `commenter` with `--query=org:falcosecurity -label:lifecycle/frozen ...`
- **Ceiling:** `--ceiling=10` (max 10 issues processed per run)
- Query targets the entire `org:falcosecurity` GitHub organization

---

### 3.16. recurring-ghissues

**Purpose:** Periodically creates GitHub issues as reminders for infrastructure maintenance tasks.

**Source:** [prow-eks-upgrade.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/recurring-ghissues/prow-eks-upgrade.yaml)

| Job Name | Type | Schedule |
|----------|------|----------|
| `prow-eks-upgrade-reminder` | Periodic | `cron: "0 7 21 6 *"` (June 21 at 07:00 UTC) |

- **Image:** `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/ghissue:latest`
- **Command:** `/usr/local/bin/entrypoint.sh ghissue create --byline=false issue.txt`
- **Environment:** `GH_REPO=test-infra`, `GH_ISSUE_TITLE="Upgrade EKS cluster to latest stable version"`, `GH_ISSUE_TAGS="maintenance,eks"`
- Creates issues reminding to upgrade: EKS control plane, data plane, AMI, VPC CNI, kubelet, CoreDNS

---

### 3.17. sync-charts

OCI defines four postsubmits: `sync-charts-event-generator`, `sync-charts-falco`, `sync-charts-k8s-metacollector`, and `sync-charts-falco-operator`. They watch the source chart directory, check out the charts repository, and propose a chart synchronization PR when the source chart version differs. The sync preserves target OWNERS and excludes Git metadata. Same-version source changes are intentionally skipped by the script.

**Sources:** [config/jobs/oci/automation/charts.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/charts.yaml#L1), [images/sync-charts/entrypoint.sh](../../../refs/falcosecurity/test-infra/images/sync-charts/entrypoint.sh#L189).

The active OCI manifest jobs cover Falco (10:00 UTC), Falcosidekick (12:00), and event-generator (13:00). The former 11:00 falco-exporter job exists only in the backup catalog. OCI registry jobs share the capacity-one `artifact-index` queue and use a dedicated current-branch registry checkout even when triggered by a plugin release tag.

**Sources:** [config/jobs/oci/automation/manifests.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/manifests.yaml#L1), [config/jobs/oci/automation/registry.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml#L1), [images/build-plugins/on-registry-changed.sh](../../../refs/falcosecurity/test-infra/images/build-plugins/on-registry-changed.sh#L153), [images/update-rules-index/on-registry-changed.sh](../../../refs/falcosecurity/test-infra/images/update-rules-index/on-registry-changed.sh#L119).

## 4. Config Uploader Tool

**Source:** [prow/update-jobs/main.go](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go)

The Config Uploader is a Go program that synchronizes Prow configuration files into Kubernetes ConfigMaps within the Prow cluster. It is a manual recovery utility; it does not run automatically after merge and updates existing ConfigMaps rather than creating missing ones.

### How It Works

1. **Authenticates** to the Kubernetes cluster using either a service account token (in-cluster, default) or a provided kubeconfig file ([main.go:57-67](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go#L57-L67))
2. **Reads configuration files** from the local filesystem
3. **Updates Kubernetes ConfigMaps** in the `default` namespace ([main.go:41-42](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go#L41-L42))

### CLI Flags

| Flag | Description |
|------|-------------|
| `--config-path` | Path to Prow config file. Updates the `config` ConfigMap |
| `--jobs-config-path` | Path to job config directory. Updates the `job-config` ConfigMap |
| `--plugins-config-path` | Path to plugins config file. Updates the `plugins` ConfigMap |
| `--kubeconfig` | Optional path to kubeconfig (defaults to in-cluster SA token) |

### ConfigMap Generation

- **Single-file configs** (`config`, `plugins`): The file content is stored under a key named `<name>.yaml` in the ConfigMap ([main.go:126-144](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go#L126-L144))
- **Directory configs** (`job-config`): All `.yaml` files found recursively in the directory are combined into a single ConfigMap, with each file's basename as the key ([main.go:146-168](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go#L146-L168))

---

## 5. Job Configuration Patterns

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

**Sources:** [config/prow/oci/config.yaml](../../../refs/falcosecurity/test-infra/config/prow/oci/config.yaml#L37), [config/prow/oci/driverkit-policy.yaml](../../../refs/falcosecurity/test-infra/config/prow/oci/driverkit-policy.yaml#L1), [config/jobs/oci/build-drivers/build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L1), [config/jobs/oci/automation/registry.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml#L1), [config/jobs/oci/automation/maintainers.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml#L1), [config/jobs/oci/update-dbg/update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml#L1).

Job `run_if_changed` patterns are repository-relative. A catalog edit is not itself evidence that a job watches that path: use its actual regex. AWS Peribolos watches the organization YAML and its AWS job directory; OCI chart jobs watch each source repository's chart directory. Periodics use `extra_refs` to select their worktree, while OCI registry jobs explicitly check out the current registry branch separately from the triggering release tag.

**Sources:** [config/jobs/aws/peribolos/peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml#L1), [config/jobs/oci/automation/charts.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/charts.yaml#L1), [config/jobs/oci/automation/registry.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml#L1).

## Sources

| Topic | Source File |
|-------|-------------|
| OCI job loading | [Kustomize catalog](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1) |
| OCI chart sync | [charts.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/charts.yaml#L1) |
| OCI registry scripts | [plugin metadata](../../../refs/falcosecurity/test-infra/images/build-plugins/on-registry-changed.sh#L153), [rules index](../../../refs/falcosecurity/test-infra/images/update-rules-index/on-registry-changed.sh#L119) |
| Job configuration guide | [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12) |
| Config Uploader tool | [prow/update-jobs/main.go](../../../refs/falcosecurity/test-infra/prow/update-jobs/main.go) |
| Build drivers (Amazon Linux) | [build-new-amazonlinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-amazonlinux.yaml) |
| Build drivers (Ubuntu Generic) | [build-new-ubuntu-generic.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-generic.yaml) |
| Build drivers (CentOS) | [build-new-centos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-centos.yaml) |
| Build drivers (Debian) | [build-new-debian.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml) |
| Build drivers (AlmaLinux) | [build-new-almalinux.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-almalinux.yaml) |
| Build drivers (Bottlerocket) | [build-new-bottlerocket.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-bottlerocket.yaml) |
| Build drivers (Fedora) | [build-new-fedora.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-fedora.yaml) |
| Build drivers (Minikube) | [build-new-minikube.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-minikube.yaml) |
| Build drivers (Photon OS) | [build-new-photon.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-photon.yaml) |
| Build drivers (Talos) | [build-new-talos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-talos.yaml) |
| Build drivers (Ubuntu AWS) | [build-new-ubuntu-aws.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-aws.yaml) |
| Build drivers (Ubuntu Azure) | [build-new-ubuntu-azure.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-azure.yaml) |
| Build drivers (Ubuntu GCP) | [build-new-ubuntu-gcp.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-gcp.yaml) |
| Build drivers (Ubuntu GKE) | [build-new-ubuntu-gke.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-ubuntu-gke.yaml) |
| Validate DBG configs | [validate-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/validate-dbg.yaml) |
| Build plugins | [build-plugins.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml) |
| Build prow images (presubmit) | [build-images.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/build-prow-images/build-images.yaml) |
| Publish prow images (postsubmit) | [publish-images.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/build-prow-images/publish-images.yaml) |
| Build AWS Terraform | [build-aws-terraform.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/build-aws-terraform/build-aws-terraform.yaml) |
| Check prow config | [check-prow-config.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/check-prow-config/check-prow-config.yaml) |
| Update jobs | [update-jobs.yaml](../../../refs/falcosecurity/test-infra/prow/update-jobs/README.md) |
| Update DBG | [update-dbg.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/update-dbg/update-dbg.yaml) |
| Update maintainers | [update-maintainers.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml) |
| Update rules index | [update-rules-index.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/registry.yaml) |
| Update K8s manifests | [update-falco-k8s-manifests.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/manifests.yaml) |
| Peribolos org management | [peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml) |
| Branch protector | [branchprotector.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/branchprotector/branchprotector.yaml) |
| Autobump | [autobump.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/autobump/autobump.yaml) |
| Lifecycle: stale | [periodic-stale.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-stale.yaml) |
| Lifecycle: rotten | [periodic-rotten.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-rotten.yaml) |
| Lifecycle: close | [periodic-close.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/lifecycle-bot/periodic-close.yaml) |
| EKS upgrade reminder | [prow-eks-upgrade.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/recurring-ghissues/prow-eks-upgrade.yaml) |
