# CI/CD Infrastructure

> Organization-wide CI/CD on Prow and AWS EKS: Prow components, cluster architecture, configuration system, Tide merge automation, branch protection, and secrets management.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/test-infra/`](../refs/falcosecurity/test-infra/)

## 1. Overview

The falcosecurity GitHub organization uses [Prow](https://docs.prow.k8s.io/) as its CI/CD platform for all 34+ repositories. Prow provides webhook-driven PR testing, merge automation, job scheduling, and a web UI. The system runs on an AWS EKS cluster in the `eu-west-1` region, with job logs stored in S3 and configuration managed declaratively via YAML files in the [`test-infra`](https://github.com/falcosecurity/test-infra) repository.

- **Web UI:** [prow.falco.org](https://prow.falco.org)
- **Image version:** All Prow components are pinned to `v20240805-37a08f946`
- **Merge strategy:** Rebase (universal across all repos)
- **Job log storage:** S3 (`s3://falco-prow-logs`)
- **Deployment:** ArgoCD manages Prow component manifests on the EKS cluster
- **Secrets management:** [Pigeon](https://github.com/falcosecurity/pigeon) syncs GitHub Actions secrets/variables from 1Password

**Source:** [`digests/falcosecurity/test-infra/prow-infrastructure.md`](../digests/falcosecurity/test-infra/prow-infrastructure.md), [`digests/falcosecurity/test-infra/prow-config.md`](../digests/falcosecurity/test-infra/prow-config.md)

## 2. Prow Components

All Prow components are deployed in the `default` namespace on the EKS cluster. Every component uses a `nodeSelector` of `Archtype: "x86"` to pin to x86 nodes. Standard resource requests/limits: `cpu: 100m`, `memory: 256M`.

| Component | Role | Image | Replicas | Key Configuration |
|-----------|------|-------|----------|-------------------|
| **Hook** | Webhook handler; receives GitHub events and dispatches to plugins | `gcr.io/k8s-prow/hook` | 2 | Ports: 8888 (webhooks), 9090 (metrics). Ingress via ALB at `prow.falco.org/hook` |
| **Deck** | Web UI; displays PR status, job logs via Spyglass | `gcr.io/k8s-prow/deck` | 1 | Ports: 8080 (UI), 9090 (metrics). Spyglass lenses: metadata, buildlog, podinfo. Size limit: 500 MB |
| **Plank** | Job controller; creates and manages ProwJob pods. Runs as a controller within Prow Controller Manager (`--enable-controller=plank`), not as a separate deployment | -- | -- | Max concurrency: 100. Pod pending timeout: 60m. Default job timeout: 24h. S3 logs to `falco-prow-logs` |
| **Sinker** | Garbage collection; cleans up completed ProwJobs and pods | `gcr.io/k8s-prow/sinker` | 1 | Resync: 1m. Max ProwJob age: 48h. Max pod age: 24h. Terminated pod TTL: 2h |
| **Horologium** | Periodic job scheduler; triggers cron-based ProwJobs | `gcr.io/k8s-prow/horologium` | 1 | Must not scale up. Strategy: Recreate |
| **Crier** | Status reporter; reports job results back to GitHub | `gcr.io/k8s-prow/crier` | 1 | GitHub workers: 2. Blob storage workers: 2. S3 integration via IAM role |
| **Tide** | Merge automation; automatically merges PRs meeting all criteria | `gcr.io/k8s-prow/tide` | 1 | Sync period: 1m. Status update period: 1m. See [Section 5](#5-tide-merge-automation) |
| **Prow Controller Manager** | Manages ProwJob pod lifecycle; hosts the Plank controller (`--enable-controller=plank`) | `gcr.io/k8s-prow/prow-controller-manager` | 1 | Manages pod lifecycle in `test-pods` namespace. S3 via IAM role `falco-prow-test-infra-prow_s3_access` |

**Source:** [`config/prow/hook.yaml`](../refs/falcosecurity/test-infra/config/prow/hook.yaml), [`config/prow/deck.yaml`](../refs/falcosecurity/test-infra/config/prow/deck.yaml), [`config/prow/prow-controller-manager.yaml`](../refs/falcosecurity/test-infra/config/prow/prow-controller-manager.yaml), [`config/prow/sinker.yaml`](../refs/falcosecurity/test-infra/config/prow/sinker.yaml), [`config/prow/horologium.yaml`](../refs/falcosecurity/test-infra/config/prow/horologium.yaml), [`config/prow/crier.yaml`](../refs/falcosecurity/test-infra/config/prow/crier.yaml), [`config/prow/tide.yaml`](../refs/falcosecurity/test-infra/config/prow/tide.yaml)

## 3. AWS EKS Cluster

### Cluster Details

| Property | Value |
|----------|-------|
| Cluster name | `falco-prow-test-infra` |
| Region | `eu-west-1` |
| Provisioning | Terraform ([`config/clusters/`](../refs/falcosecurity/test-infra/config/clusters/)) |
| Deployment | ArgoCD applications |

### Namespaces

| Namespace | Purpose |
|-----------|---------|
| `default` | ProwJob CRDs, Prow control plane components |
| `test-pods` | Job execution pods (where CI jobs actually run) |

### Node Architecture

Nodes are labeled with `Archtype` and `Application` selectors:

- **`Archtype: "x86"`** -- Used by all Prow control plane components
- **`Archtype: "arm"`** -- Available for arm64 CI jobs
- **`Application: "jobs"`** -- Used by job pods in `test-pods` namespace

### Pod Identity and S3 Access

Job pods and Prow components access S3 via IAM Roles for Service Accounts (IRSA), managed by the Pod Identity Webhook:
- **S3 bucket:** `s3://falco-prow-logs` (job logs and artifacts)
- **IAM role:** `falco-prow-test-infra-prow_s3_access`
- **Credential delivery:** S3 credentials secret for sidecar log upload; Pod Identity Webhook for component-level access

### ArgoCD Deployment

ArgoCD applications manage Prow component manifests. Each Prow component directory under [`config/prow/`](../refs/falcosecurity/test-infra/config/prow/) maps to an ArgoCD Application resource in [`config/clusters/`](../refs/falcosecurity/test-infra/config/clusters/).

**Source:** [`digests/falcosecurity/test-infra/prow-infrastructure.md`](../digests/falcosecurity/test-infra/prow-infrastructure.md) (Sections 2-4)

## 4. Prow Configuration

Configuration is split across two primary files in [`config/`](../refs/falcosecurity/test-infra/config/):

### 4.1 Core Configuration (config.yaml)

**Source:** [`config/config.yaml`](../refs/falcosecurity/test-infra/config/config.yaml)

#### Deck (UI)

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Header color | `#00AEC7` (Falco Teal) | [config.yaml:L3](../refs/falcosecurity/test-infra/config/config.yaml) |
| Spyglass size limit | 500 MB | [config.yaml:L7](../refs/falcosecurity/test-infra/config/config.yaml) |
| Spyglass lenses | metadata, buildlog, podinfo | [config.yaml:L8-L22](../refs/falcosecurity/test-infra/config/config.yaml) |

#### Plank (Job Controller)

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Max concurrency | `100` | [config.yaml:L24](../refs/falcosecurity/test-infra/config/config.yaml) |
| Pod pending timeout | `60m` | [config.yaml:L24-L44](../refs/falcosecurity/test-infra/config/config.yaml) |
| Default job timeout | `24h` (accommodates driverkit builder jobs) | [config.yaml:L34](../refs/falcosecurity/test-infra/config/config.yaml) |
| Grace period | `10m` | [config.yaml:L32-L44](../refs/falcosecurity/test-infra/config/config.yaml) |
| S3 bucket | `s3://falco-prow-logs` | [config.yaml:L42](../refs/falcosecurity/test-infra/config/config.yaml) |
| Path strategy | `explicit` | [config.yaml:L32-L44](../refs/falcosecurity/test-infra/config/config.yaml) |

**Utility images** (Prow sidecar containers, all `v20240805-37a08f946` from `gcr.io/k8s-prow/`):
- `clonerefs` -- clones source code
- `initupload` -- uploads job start metadata
- `entrypoint` -- wraps job commands
- `sidecar` -- uploads logs and artifacts to S3

**Source:** [config.yaml:L36-L40](../refs/falcosecurity/test-infra/config/config.yaml)

#### Sinker (Garbage Collection)

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Resync period | `1m` | [config.yaml:L46-L50](../refs/falcosecurity/test-infra/config/config.yaml) |
| Max ProwJob age | `48h` | [config.yaml:L46-L50](../refs/falcosecurity/test-infra/config/config.yaml) |
| Max pod age | `24h` | [config.yaml:L46-L50](../refs/falcosecurity/test-infra/config/config.yaml) |
| Terminated pod TTL | `2h` | [config.yaml:L46-L50](../refs/falcosecurity/test-infra/config/config.yaml) |

### 4.2 Plugin Configuration (plugins.yaml)

**Source:** [`config/plugins.yaml`](../refs/falcosecurity/test-infra/config/plugins.yaml)

Plugins are enabled per-repository (no org-wide plugin list). A common set appears across virtually all repos:

**Common plugins** (enabled on nearly every repo):

| Plugin | Purpose |
|--------|---------|
| `approve` | Allows OWNERS to `/approve` PRs. `lgtm_acts_as_approve: true` |
| `assign` | Allows `/assign` and `/cc` commands |
| `blunderbuss` | Auto-assigns up to 2 reviewers from OWNERS. Considers GitHub availability status |
| `branchcleaner` | Deletes merged branches |
| `cat` | `/meow` replies with cat pictures |
| `dco` | Checks DCO sign-off on all commits. Applied globally (`*` wildcard). No exceptions |
| `dog` | `/bark` replies with dog pictures |
| `goose` | `/honk` replies with goose pictures (Unsplash API) |
| `help` | Supports `/help` and `/good-first-issue` |
| `hold` | Supports `/hold` to delay merge |
| `label` | Manages labels via `/kind`, `/area`, etc. |
| `lifecycle` | Allows `/lifecycle stale`, `/lifecycle rotten`, etc. |
| `lgtm` | `/lgtm` for approval. GitHub review approval acts as `/lgtm`. Tree hash invalidation on PR update |
| `size` | Auto-labels PR size (S/M/L/XL/XXL) based on thresholds: 10/30/90/270/520 lines |
| `trigger` | Allows `/test` and `/retest` commands. Only org members can trigger |
| `verify-owners` | Validates OWNERS file changes in PRs |
| `welcome` | Welcomes new PR contributors |
| `wip` | Auto-holds PRs with WIP in title |

**Selectively enabled plugins:**

| Plugin | Scope | Purpose |
|--------|-------|---------|
| `config-updater` | `test-infra` only | Auto-updates ConfigMaps on merge (see [Section 8](#8-config-propagation)) |
| `needs-rebase` | All repos (external plugin) | Adds `needs-rebase` label when PR has merge conflicts |
| `release-note` | `falco`, `libs`, `falcoctl`, `client-go`, `client-py`, `client-rs`, `plugin-sdk-go`, `plugin-sdk-rs` | Requires release notes on PRs |
| `mergecommitblocker` | `charts`, `falco`, `libs`, `plugins`, and others | Blocks merge commits |
| `milestone` | `falco`, `libs`, `falcoctl`, `falco-website`, `pdig`, `plugin-sdk-cpp`, `rules` | Manages milestones per maintainers team |
| `golint` | Go-based repos (20+ repos) | Go linting |
| `require-matching-label` | Most repos | Enforces `kind/*` labels on PRs or issues |

**Source:** [plugins.yaml:L502-L1554](../refs/falcosecurity/test-infra/config/plugins.yaml) (per-repo plugin lists), [plugins.yaml:L1556-L1741](../refs/falcosecurity/test-infra/config/plugins.yaml) (external plugins)

## 5. Tide Merge Automation

Tide is the merge controller that automatically merges PRs meeting all criteria. Configuration at [config.yaml:L485-L1186](../refs/falcosecurity/test-infra/config/config.yaml).

### Global Settings

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Target URL | `https://prow.falco.org/tide` | [config.yaml:L486](../refs/falcosecurity/test-infra/config/config.yaml) |
| `skip-unknown-contexts` | `true` -- only branch-protection-defined checks gate merges | [config.yaml:L488](../refs/falcosecurity/test-infra/config/config.yaml) |
| `from-branch-protection` | `true` -- derive required checks from branch protection config | [config.yaml:L489](../refs/falcosecurity/test-infra/config/config.yaml) |

### Merge Method

All 36+ falcosecurity repositories use the **rebase** merge method without exception.

**Source:** [config.yaml:L490-L536](../refs/falcosecurity/test-infra/config/config.yaml)

### Merge Criteria

A PR is eligible for Tide merge when all of the following are satisfied:

**Required labels:**
- `approved`
- `lgtm`
- `dco-signoff: yes`

**Blocking labels** (PR must NOT have any of these):
- `do-not-merge`
- `do-not-merge/hold`
- `do-not-merge/invalid-owners-file`
- `do-not-merge/work-in-progress`
- `needs-rebase`
- `do-not-merge/release-note-label-needed` (on repos using the `release-note` plugin)

**Additional requirements:**
- `reviewApprovedRequired: true` -- at least one GitHub review approval
- All required status checks passing (derived from branch protection)

**Source:** [config.yaml:L537-L1186](../refs/falcosecurity/test-infra/config/config.yaml)

## 6. Branch Protection

Branch protection rules are configured centrally by Prow and enforced via the `branchprotector` periodic job. Full configuration at [config.yaml:L52-L477](../refs/falcosecurity/test-infra/config/config.yaml).

### Global Defaults

These defaults apply to all protected branches across the organization unless overridden per-repo:

| Setting | Value |
|---------|-------|
| Enforce admins | `true` -- rules apply to admins too |
| Push restrictions | Teams: `maintainers`, `machine_users` |
| Dismiss stale reviews | `true` |
| Dismissal restriction teams | `maintainers`, `machine_users` |
| Require code owner reviews | `true` |
| Required approving review count | `1` |
| Strict status checks | `false` -- PRs are not required to be up-to-date (rebase merge + needs-rebase plugin handle this) |

**Source:** [config.yaml:L52-L65](../refs/falcosecurity/test-infra/config/config.yaml)

### Org-Wide Required Status Check

All falcosecurity repositories require the **`dco`** status check at the org level.

**Source:** [config.yaml:L67-L71](../refs/falcosecurity/test-infra/config/config.yaml)

### Key Repository-Specific Overrides

| Repository | Required Approvals | Extra Required Checks | Line Reference |
|------------|-------------------|----------------------|----------------|
| `falco` | **2** | `test-dev-packages / test-packages`, `test-dev-packages-arm64 / test-packages`, `format code` | [config.yaml:L158-L200](../refs/falcosecurity/test-infra/config/config.yaml) |
| `libs` | **2** | 14 checks: build (amd64/arm64, 4 modes each), test-drivers, test-libs-static, test-scap, format code | [config.yaml:L352-L406](../refs/falcosecurity/test-infra/config/config.yaml) |
| `charts` | 1 (default) | `test`, `readme`, `linkChecker`, `go-unit-tests` | [config.yaml:L81-L90](../refs/falcosecurity/test-infra/config/config.yaml) |
| `falcoctl` | 1 (default) | `test`, 3 `build` (linux/darwin amd64/arm64, windows amd64), `Lint golang files`, `Enforce go.mod tidiness` | [config.yaml:L245-L264](../refs/falcosecurity/test-infra/config/config.yaml) |
| `driverkit` | 1 (default) | `build-test-dev (amd64) / build-test`, `build-test-dev (arm64) / build-test`, `Enforce go.mod tidiness` | [config.yaml:L129-L137](../refs/falcosecurity/test-infra/config/config.yaml) |
| `falcosidekick` | 1 (default) | `Run unit tests`, `lint`, `build-image` | [config.yaml:L201-L209](../refs/falcosecurity/test-infra/config/config.yaml) |
| `falco-website` | 1 (default) | `netlify/falcosecurity/deploy-preview`. Multiple version branches (v0.26-v0.42) protected | [config.yaml:L285-L325](../refs/falcosecurity/test-infra/config/config.yaml) |
| `test-infra` | 1 (default) | `check-prow-config`, `manifests-validation` | [config.yaml:L466-L473](../refs/falcosecurity/test-infra/config/config.yaml) |
| `plugins` | 1 (default) | `build-plugins / build-packages-x86_64`, `build-plugins / build-packages-aarch64`, `get-changed-plugins / get-values` | [config.yaml:L427-L435](../refs/falcosecurity/test-infra/config/config.yaml) |

> **Note:** `falco` and `libs` both require **2 approving reviews** (vs. the global default of 1), reflecting their status as core repositories with the highest quality gates.

## 7. Secrets Management (Pigeon)

[Pigeon](https://github.com/falcosecurity/pigeon) is a CLI tool for managing GitHub Actions secrets and variables across the falcosecurity organization from a centralized configuration file. It bridges 1Password (the secret source of truth) with GitHub's Actions secrets API.

### Architecture

```
┌─────────────────────┐          ┌─────────────────────┐
│   YAML Config       │          │    1Password        │
│                     │          │    Connect          │
│ orgs:               │  lookup  │                     │
│   falcosecurity:    │──────────│ - AWS_ACCESS_KEY    │
│     secrets:        │          │ - DOCKER_TOKEN      │
│     repos:          │          │ - SIGNING_KEY       │
│       libs:         │          └─────────────────────┘
│         secrets:    │                    │
└──────────┬──────────┘                    │
           │                               ▼
           │              ┌─────────────────────────────┐
           └─────────────►│          Pigeon              │
                          │  1. Load config              │
                          │  2. Fetch from 1Password     │
                          │  3. Encrypt with GitHub key  │
                          │  4. Sync to GitHub API       │
                          └──────────────┬──────────────┘
                                         │
                                         ▼
                          ┌─────────────────────────────┐
                          │       GitHub API             │
                          │  Org: falcosecurity          │
                          │  ├── Org-level secrets       │
                          │  ├── Org-level variables     │
                          │  └── Per-repo secrets/vars   │
                          └─────────────────────────────┘
```

### Configuration Format

```yaml
orgs:
  falcosecurity:                    # Organization name
    actions:
      variables:                    # Org-level variables (inline values)
        REGISTRY: "ghcr.io"
      secrets:                      # Org-level secrets (names only, values from 1Password)
        - AWS_ACCESS_KEY_ID
        - AWS_SECRET_ACCESS_KEY
    repos:
      libs:                         # Repository-level
        actions:
          variables:
            BUILD_TYPE: "release"
          secrets:
            - SIGNING_KEY
```

### Sync Behavior

Pigeon performs a **declarative sync** -- the YAML configuration file is the source of truth:

1. **List** existing secrets/variables from GitHub
2. **Delete** items on GitHub not present in config
3. **Create or update** items listed in config

This means removing an entry from the config file will delete the corresponding secret/variable from GitHub on the next sync.

### 1Password Integration

| Environment Variable | Purpose |
|---------------------|---------|
| `OP_CONNECT_TOKEN` | API token for 1Password Connect |
| `OP_CONNECT_HOST` | Hostname of 1Password Connect instance |
| `OP_VAULT` | UUID of the vault containing secrets |

Secret values are looked up by name (title) in the 1Password vault, retrieving the `password` field, encrypting with GitHub's public key using libsodium sealed box, and uploading to GitHub.

**Source:** [`digests/falcosecurity/pigeon.md`](../digests/falcosecurity/pigeon.md), [`refs/falcosecurity/pigeon/pkg/pigeon/secrets_onepassword.go`](../refs/falcosecurity/pigeon/pkg/pigeon/secrets_onepassword.go), [`refs/falcosecurity/pigeon/pkg/config/config.go`](../refs/falcosecurity/pigeon/pkg/config/config.go)

## 8. Config Propagation

Prow configuration changes in `test-infra` propagate to the live cluster through two mechanisms.

### 8.1 config-updater Plugin (Immediate)

The `config-updater` plugin is enabled **only** on the `test-infra` repository. When a PR merges to `master`, the plugin automatically updates Kubernetes ConfigMaps:

| File Pattern | ConfigMap Name | Options |
|-------------|---------------|---------|
| `config/config.yaml` | `config` | -- |
| `config/plugins.yaml` | `plugins` | -- |
| `config/jobs/**/*.yaml` | `job-config` | `gzip: true` |

Prow components watch these ConfigMaps and **hot-reload** their configuration. Changes take effect immediately upon merge without restart.

**Source:** [plugins.yaml:L65-L73](../refs/falcosecurity/test-infra/config/plugins.yaml)

### 8.2 update-jobs Postsubmit (Backup)

The `update-jobs-pr` postsubmit job runs after every merge to `master` in `test-infra`. It uses a custom `update-jobs` image to process job configuration files from `config/jobs/` and update the `job-config` ConfigMap. This serves as a backup mechanism to the `config-updater` plugin.

**Source:** [`config/jobs/update-jobs/update-jobs.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml)

### 8.3 Config Validation

Configuration integrity is ensured by two mechanisms:

1. **Presubmit** (`check-prow-config`): Runs on every PR to `test-infra`'s `master` branch. Uses `gcr.io/k8s-prow/checkconfig:v20240805-37a08f946` to validate `config.yaml`, `plugins.yaml`, and all job configs.

2. **Periodic** (`check-prow-config-periodic`): Runs every 1 hour as a safety net to catch drift between ConfigMaps and the git source.

Both use the same validation command:
```
checkconfig --config-path=config/config.yaml --job-config-path=config/jobs --plugin-config=config/plugins.yaml
```

**Source:** [`config/jobs/check-prow-config/check-prow-config.yaml`](../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml)

## 9. Container Images

### Standard Prow Images

All core Prow components use images from `gcr.io/k8s-prow/*`, pinned to version `v20240805-37a08f946`:
- `hook`, `deck`, `sinker`, `horologium`, `crier`, `tide`, `prow-controller-manager` (includes Plank controller)
- Utility images: `clonerefs`, `initupload`, `entrypoint`, `sidecar`
- Validation: `checkconfig`

### Custom Images

Custom images are hosted in ECR:

```
292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/*
```

These include job-specific images for driver building, config updates, and other CI tasks.

**Source:** [`digests/falcosecurity/test-infra/prow-infrastructure.md`](../digests/falcosecurity/test-infra/prow-infrastructure.md) (Section 5)

## 10. Related Specs

| Spec | Relationship |
|------|-------------|
| [`ci-cd-jobs.md`](ci-cd-jobs.md) | Job catalog: presubmit, postsubmit, periodic jobs for all repos |
| [`ci-cd-github-actions.md`](ci-cd-github-actions.md) | GitHub Actions workflows complementing Prow CI |
| [`driver-distribution.md`](driver-distribution.md) | Drivers Build Grid architecture and driver distribution via S3 |

## 11. Sources

| Topic | Source File |
|-------|-------------|
| Prow components and AWS infrastructure | [`digests/falcosecurity/test-infra/prow-infrastructure.md`](../digests/falcosecurity/test-infra/prow-infrastructure.md) |
| Prow configuration, plugins, Tide, branch protection | [`digests/falcosecurity/test-infra/prow-config.md`](../digests/falcosecurity/test-infra/prow-config.md) |
| Secrets management (Pigeon) | [`digests/falcosecurity/pigeon.md`](../digests/falcosecurity/pigeon.md) |
| Core Prow config (deck, plank, sinker, branch protection, tide) | [`config/config.yaml`](../refs/falcosecurity/test-infra/config/config.yaml) |
| Plugin configuration (approve, lgtm, dco, size, triggers, per-repo plugins) | [`config/plugins.yaml`](../refs/falcosecurity/test-infra/config/plugins.yaml) |
| Config validation (presubmit + periodic) | [`config/jobs/check-prow-config/check-prow-config.yaml`](../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml) |
| Job config update postsubmit | [`config/jobs/update-jobs/update-jobs.yaml`](../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml) |
| Pigeon entry point | [`refs/falcosecurity/pigeon/main.go`](../refs/falcosecurity/pigeon/main.go) |
| Pigeon config parsing | [`refs/falcosecurity/pigeon/pkg/config/config.go`](../refs/falcosecurity/pigeon/pkg/config/config.go) |
| Pigeon 1Password integration | [`refs/falcosecurity/pigeon/pkg/pigeon/secrets_onepassword.go`](../refs/falcosecurity/pigeon/pkg/pigeon/secrets_onepassword.go) |
| Hook deployment manifest | [`config/prow/hook.yaml`](../refs/falcosecurity/test-infra/config/prow/hook.yaml) |
| Deck deployment manifest | [`config/prow/deck.yaml`](../refs/falcosecurity/test-infra/config/prow/deck.yaml) |
| Prow Controller Manager deployment manifest | [`config/prow/prow-controller-manager.yaml`](../refs/falcosecurity/test-infra/config/prow/prow-controller-manager.yaml) |
| Crier deployment manifest | [`config/prow/crier.yaml`](../refs/falcosecurity/test-infra/config/prow/crier.yaml) |
