# CI/CD Infrastructure

> Organization-wide CI/CD on separate AWS EKS and OCI OKE Prow installations: Prow components, cluster architecture, configuration system, Tide merge automation, branch protection, and secrets management.

**Era:** 0.45 | **Source:** [`refs/falcosecurity/test-infra/`](../refs/falcosecurity/test-infra/)

## 1. Overview

The 0.45 source pin defines separate AWS and OCI installations. AWS retains organization policy, Tide, Peribolos, branch protection and its own job catalog; OCI defines driver builds and other automation. Sections explicitly describing EKS, AWS manifests, or the older Prow tag apply to AWS only. Deployment files record desired state, not verified live cluster health.

**Sources:** [config/prow/aws/config.yaml](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L525), [config/prow/aws/plugins.yaml](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L67), [config/prow/oci/kustomization.yaml](../refs/falcosecurity/test-infra/config/prow/oci/kustomization.yaml#L1), [config/jobs/oci/kustomization.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1).

The falcosecurity GitHub organization uses [Prow](https://docs.prow.k8s.io/) as its CI/CD platform for all 34+ repositories. Prow provides webhook-driven PR testing, merge automation, job scheduling, and a web UI. The AWS installation runs on an EKS cluster in the `eu-west-1` region, with job logs stored in S3 and configuration managed declaratively via YAML files in the [`test-infra`](https://github.com/falcosecurity/test-infra) repository.

- **Web UI:** [prow.falco.org](https://prow.falco.org)
- **Image version:** AWS Prow components are pinned to `v20240805-37a08f946`
- **Merge strategy:** Rebase (universal across all repos)
- **Job log storage:** S3 (`s3://falco-prow-logs`)
- **Deployment:** the AWS deployment script applies Prow manifests; OCI Prow is an ArgoCD Application
- **Secrets management:** [Pigeon](https://github.com/falcosecurity/pigeon) syncs GitHub Actions secrets/variables from 1Password

**Source:** [`digests/falcosecurity/test-infra/prow-infrastructure.md`](../digests/falcosecurity/test-infra/prow-infrastructure.md), [`digests/falcosecurity/test-infra/prow-config.md`](../digests/falcosecurity/test-infra/prow-config.md)

## 2. Prow Components

AWS Prow components are deployed in the `default` namespace on the EKS cluster. Every component uses a `nodeSelector` of `Archtype: "x86"` to pin to x86 nodes. Standard resource requests/limits: `cpu: 100m`, `memory: 256M`.

| Component | Role | Image | Replicas | Key Configuration |
|-----------|------|-------|----------|-------------------|
| **Hook** | Webhook handler; receives GitHub events and dispatches to plugins | `gcr.io/k8s-prow/hook` | 2 | Ports: 8888 (webhooks), 9090 (metrics). Ingress via ALB at `prow.falco.org/hook` |
| **Deck** | Web UI; displays PR status, job logs via Spyglass | `gcr.io/k8s-prow/deck` | 3 | Ports: 8080 (UI), 9090 (metrics). Spyglass lenses: metadata, buildlog, podinfo. Size limit: 500 MB |
| **Plank** | Job controller; creates and manages ProwJob pods. Runs as a controller within Prow Controller Manager (`--enable-controller=plank`), not as a separate deployment | -- | -- | Max concurrency: 100. Pod pending timeout: 60m. Default job timeout: 24h. S3 logs to `falco-prow-logs` |
| **Sinker** | Garbage collection; cleans up completed ProwJobs and pods | `gcr.io/k8s-prow/sinker` | 1 | Resync: 1m. Max ProwJob age: 48h. Max pod age: 24h. Terminated pod TTL: 2h |
| **Horologium** | Periodic job scheduler; triggers cron-based ProwJobs | `gcr.io/k8s-prow/horologium` | 1 | Must not scale up. Strategy: Recreate |
| **Crier** | Status reporter; reports job results back to GitHub | `gcr.io/k8s-prow/crier` | 1 | GitHub workers: 2. Blob storage workers: 2. S3 integration via IAM role |
| **Tide** | Merge automation; automatically merges PRs meeting all criteria | `gcr.io/k8s-prow/tide` | 1 | Sync period: 1m. Status update period: 1m. See [Section 5](#5-tide-merge-automation) |
| **Prow Controller Manager** | Manages ProwJob pod lifecycle; hosts the Plank controller (`--enable-controller=plank`) | `gcr.io/k8s-prow/prow-controller-manager` | 1 | Manages pod lifecycle in `test-pods` namespace. S3 via IAM role `falco-prow-test-infra-prow_s3_access` |

**Source:** [`config/prow/aws/manifests/hook.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/hook.yaml), [`config/prow/aws/manifests/deck.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/deck.yaml), [`config/prow/aws/manifests/prow-controller-manager.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/prow-controller-manager.yaml), [`config/prow/aws/manifests/sinker.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/sinker.yaml), [`config/prow/aws/manifests/horologium.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/horologium.yaml), [`config/prow/aws/manifests/crier.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/crier.yaml), [`config/prow/aws/manifests/tide.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/tide.yaml)

## 3. AWS EKS Cluster

### Cluster Details

| Property | Value |
|----------|-------|
| Cluster name | `falco-prow-test-infra` |
| Region | `eu-west-1` |
| Provisioning | Terraform ([`config/clusters/`](../refs/falcosecurity/test-infra/config/clusters/)) |
| Deployment | Prow deployment script; ArgoCD add-on applications |

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

### Deployment Responsibilities

The AWS Prow deployment script applies its manifests and bootstraps missing ConfigMaps, preserving maps already managed by `config-updater`. AWS ArgoCD applications manage add-ons and Falco. OCI uses an ArgoCD Application for Prow itself.

**Sources:** [tools/deploy_prow.sh](../refs/falcosecurity/test-infra/tools/deploy_prow.sh#L60), [config/applications/aws/falco.yaml](../refs/falcosecurity/test-infra/config/applications/aws/falco.yaml#L1), [config/applications/oci/prow.yaml](../refs/falcosecurity/test-infra/config/applications/oci/prow.yaml#L1).

## OCI Platform

The OCI stack is separate from AWS: OKE in `eu-frankfurt-1`, cluster `falco-prow-test-infra-oci`, Kubernetes `v1.36.1`, with pinned Oracle Linux 8.10 node images. Terraform declares three fixed platform nodes, an x86 automation pool scaling from 1 to 5, and x86/ARM driver pools scaling from 0 to 4 each. Platform nodes use E5 Flex (2 OCPUs/16Gi); automation uses E6 Flex (2/16); driver x86 uses E6 Flex and ARM uses A1 Flex (8/48), each with 200Gi boot disks. Pool values are configured capacity, not an observation of running nodes.

**Sources:** [config/clusters/oci/terraform.tfvars](../refs/falcosecurity/test-infra/config/clusters/oci/terraform.tfvars#L1), [config/clusters/oci/variables.tf](../refs/falcosecurity/test-infra/config/clusters/oci/variables.tf#L114), [config/clusters/oci/cluster.tf](../refs/falcosecurity/test-infra/config/clusters/oci/cluster.tf#L38).

| Concern | OCI configuration |
|---------|-------------------|
| Namespaces | `prow` for ProwJobs/control plane; `test-pods` for job pods |
| Components | Hook, Deck, GHProxy, Horologium, controller manager, Crier, Sinker; no OCI Tide or needs-rebase deployment |
| Prow version | `v20260811-cafa49460`, images from `us-docker.pkg.dev/k8s-infra-prow/images`, pinned by digest |
| Replicas | Hook 2; Deck 2; other listed deployments 1 |
| Plugin responsibility | Trigger-only config; merge/review/label policy remains in AWS |
| Job queues | `artifact-index: 1`, `automation: 3`, `driverkit-x86: 4`, `driverkit-arm: 4` |
| Logs | S3-compatible OCI Object Storage bucket named `falco-prow-logs`, accessed through the `s3-credentials` secret |
| Public entry | Envoy Gateway/HTTPRoutes with cert-manager; OCI job links use `https://oci-prow.falco.org/view/` |

**Sources:** [config/prow/oci/kustomization.yaml](../refs/falcosecurity/test-infra/config/prow/oci/kustomization.yaml#L1), [config/prow/oci/config.yaml](../refs/falcosecurity/test-infra/config/prow/oci/config.yaml#L1), [config/prow/oci/plugins.yaml](../refs/falcosecurity/test-infra/config/prow/oci/plugins.yaml#L1), [config/prow/oci/hook.yaml](../refs/falcosecurity/test-infra/config/prow/oci/hook.yaml#L73), [config/prow/oci/deck.yaml](../refs/falcosecurity/test-infra/config/prow/oci/deck.yaml#L108), [config/applications/oci/gateway.yaml](../refs/falcosecurity/test-infra/config/applications/oci/gateway.yaml#L1), [config/clusters/oci/storage.tf](../refs/falcosecurity/test-infra/config/clusters/oci/storage.tf#L1).

ArgoCD's OCI Prow Application tracks `master` and renders the OCI Prow Kustomization, which includes the explicit job catalog. ConfigMaps are reconciled through GitOps, with prune/self-heal enabled. The bootstrap script installs ArgoCD chart 10.1.4 using a temporary kubeconfig bound to the intended OKE cluster, then applies the app-of-apps resource. Administrative IAM prerequisites live in a separate bootstrap stack.

**Sources:** [config/applications/oci/prow.yaml](../refs/falcosecurity/test-infra/config/applications/oci/prow.yaml#L10), [config/jobs/oci/kustomization.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1), [tools/deploy_argocd_oci.sh](../refs/falcosecurity/test-infra/tools/deploy_argocd_oci.sh#L20), [config/applications/oci/bootstrap/applications.yaml](../refs/falcosecurity/test-infra/config/applications/oci/bootstrap/applications.yaml#L1), [config/clusters/oci/bootstrap/README.md](../refs/falcosecurity/test-infra/config/clusters/oci/bootstrap/README.md#L1).

OCI log storage is private and versioned: current `logs/` and `pr-logs/` objects expire after 10 days, previous versions after 3 days, and incomplete multipart uploads after 7 days. The log-storage admission policy supplies `AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED` to matching Prow uploader containers. Driver artifacts use a different path: OCI builders assume the AWS `falco-prow-driver-publisher` role to publish under `falco-distribution/driver/*`; the role trusts only the configured OKE issuer and `test-pods:driver-kit` service account and grants read/write/ACL access for that prefix.

**Sources:** [config/clusters/oci/storage.tf](../refs/falcosecurity/test-infra/config/clusters/oci/storage.tf#L15), [config/prow/oci/log-storage-policy.yaml](../refs/falcosecurity/test-infra/config/prow/oci/log-storage-policy.yaml#L1), [config/clusters/aws/bootstrap/driver-publishing/iam.tf](../refs/falcosecurity/test-infra/config/clusters/aws/bootstrap/driver-publishing/iam.tf#L1), [config/clusters/aws/bootstrap/driver-publishing/variables.tf](../refs/falcosecurity/test-infra/config/clusters/aws/bootstrap/driver-publishing/variables.tf#L29).

OCI jobs use dedicated automation or driver pools. Admission policy denies host namespaces, host paths and host ports, and permits privilege only for the pinned Docker native sidecar. Non-root build and automation containers run with automatic Kubernetes token mounting disabled; the driver publisher receives a specifically projected AWS token. This policy is scoped to OCI `test-pods`, not a description of the retained AWS jobs.

**Sources:** [config/prow/oci/driverkit-policy.yaml](../refs/falcosecurity/test-infra/config/prow/oci/driverkit-policy.yaml#L11), [config/jobs/oci/build-drivers/build-new-debian.yaml](../refs/falcosecurity/test-infra/config/jobs/oci/build-drivers/build-new-debian.yaml#L16).

OCI runs Falco through operator chart 0.3.1 and a Falco DaemonSet resource pinned to **0.44.1** at this snapshot. The AWS Falco application separately pins chart 9.2.0 and Falco **0.45.0**, with container plugin 0.7.4 and k8smeta 0.4.2. Do not infer that both clusters track the KB era's Falco version.

**Sources:** [config/applications/oci/falco-operator.yaml](../refs/falcosecurity/test-infra/config/applications/oci/falco-operator.yaml#L10), [config/applications/oci/falco/falco-instance.yaml](../refs/falcosecurity/test-infra/config/applications/oci/falco/falco-instance.yaml#L1), [config/applications/aws/falco.yaml](../refs/falcosecurity/test-infra/config/applications/aws/falco.yaml#L10).

## 4. Prow Configuration

AWS configuration is split across two primary files in [`config/`](../refs/falcosecurity/test-infra/config/):

### 4.1 Core Configuration (config.yaml)

**Source:** [`config/prow/aws/config.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml)

#### Deck (UI)

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Header color | `#00AEC7` (Falco Teal) | [config.yaml:L3](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L3) |
| Spyglass size limit | 500 MB | [config.yaml:L7](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L7) |
| Spyglass lenses | metadata, buildlog, podinfo | [config.yaml:L8-L22](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L8-L22) |

#### Plank (Job Controller)

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Max concurrency | `100` | [config.yaml:L24](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L24) |
| Pod pending timeout | `60m` | [config.yaml:L24-L44](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L24-L44) |
| Default job timeout | `24h` (accommodates driverkit builder jobs) | [config.yaml:L34](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L34) |
| Grace period | `10m` | [config.yaml:L32-L44](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L32-L44) |
| S3 bucket | `s3://falco-prow-logs` | [config.yaml:L42](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L42) |
| Path strategy | `explicit` | [config.yaml:L32-L44](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L32-L44) |

**Utility images** (Prow sidecar containers, all `v20240805-37a08f946` from `gcr.io/k8s-prow/`):
- `clonerefs` -- clones source code
- `initupload` -- uploads job start metadata
- `entrypoint` -- wraps job commands
- `sidecar` -- uploads logs and artifacts to S3

**Source:** [config.yaml:L36-L40](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L36-L40)

#### Sinker (Garbage Collection)

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Resync period | `1m` | [config.yaml:L46-L50](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L46-L50) |
| Max ProwJob age | `48h` | [config.yaml:L46-L50](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L46-L50) |
| Max pod age | `24h` | [config.yaml:L46-L50](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L46-L50) |
| Terminated pod TTL | `2h` | [config.yaml:L46-L50](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L46-L50) |

### 4.2 Plugin Configuration (plugins.yaml)

**Source:** [`config/prow/aws/plugins.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml)

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

**Source:** [plugins.yaml:L524-L1617](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L524-L1617) (per-repo plugin lists), [plugins.yaml:L1618-L1810](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L1618-L1810) (external plugins)

## 5. Tide Merge Automation

For `test-infra`, Tide also lists `Terraform OCI / plan`, `validate-dbg`, and `build-update-dbg-image` as **required if present**. `skip-unknown-contexts` does not make these configured contexts optional once reported. [config/prow/aws/config.yaml](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L525).

Tide is the merge controller that automatically merges PRs meeting all criteria. Configuration at [config.yaml:L525-L1263](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L525-L1263).

### Global Settings

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Target URL | `https://prow.falco.org/tide` | [config.yaml:L526](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L526) |
| `skip-unknown-contexts` | `true` -- branch-protection checks and configured required-if-present contexts gate merges | [config.yaml:L528](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L528) |
| `from-branch-protection` | `true` -- derive required checks from branch protection config | [config.yaml:L529](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L529) |

### Merge Method

All 36+ falcosecurity repositories use the **rebase** merge method without exception.

**Source:** [config.yaml:L538-L586](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L538-L586)

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

**Source:** [config.yaml:L587-L1263](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L587-L1263)

## 6. Branch Protection

Branch protection rules are configured centrally by Prow and enforced via the `branchprotector` periodic job. Full configuration at [config.yaml:L52-L518](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L52-L518).

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

**Source:** [config.yaml:L52-L65](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L52-L65)

### Org-Wide Required Status Check

All falcosecurity repositories require the **`dco`** status check at the org level.

**Source:** [config.yaml:L67-L71](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L67-L71)

### Key Repository-Specific Overrides

| Repository | Required Approvals | Extra Required Checks | Line Reference |
|------------|-------------------|----------------------|----------------|
| `falco` | **2** | `test-dev-packages / test-packages`, `test-dev-packages-arm64 / test-packages`, `format code` | [config.yaml:L156-L202](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L156-L202) |
| `libs` | **2** | 14 checks: build (amd64/arm64, 4 modes each), test-drivers, test-libs-static, test-scap, format code | [config.yaml:L372-L433](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L372-L433) |
| `charts` | 1 (default) | `test`, `readme`, `linkChecker`, `go-unit-tests` | [config.yaml:L81-L88](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L81-L88) |
| `falcoctl` | 1 (default) | `test`, 5 `build` (linux/darwin amd64/arm64, windows amd64), `Lint golang files`, `Enforce go.mod tidiness` | [config.yaml:L261-L280](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L261-L280) |
| `driverkit` | 1 (default) | `build-test-dev (amd64) / build-test`, `build-test-dev (arm64) / build-test`, `Enforce go.mod tidiness` | [config.yaml:L127-L135](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L127-L135) |
| `falcosidekick` | 1 (default) | `Run unit tests`, `lint`, `build-image` | [config.yaml:L203-L211](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L203-L211) |
| `falco-website` | 1 (default) | `netlify/falcosecurity/deploy-preview`. Multiple version branches (v0.26-v0.44) protected | [config.yaml:L301-L345](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L301-L345) |
| `test-infra` | 1 (default) | `check-prow-config`, `manifests-validation` | [config.yaml:L506-L513](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L506-L513) |
| `plugins` | 1 (default) | `build-plugins / build-packages-x86_64`, `build-plugins / build-packages-aarch64`, `get-changed-plugins / get-values` | [config.yaml:L453-L461](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L453-L461) |

> **Note:** `falco` and `libs` both require **2 approving reviews** (vs. the global default of 1), reflecting their status as core repositories with the highest quality gates.

The protected branches include Falco `release/0.45.x`, libs `release/0.26.x`, and website `v0.44`. Falco Operator requires `e2e-chainsaw-summary`, `lint-summary`, `unit-tests`, `helm-chart-check`, and `manifests-check`.

**Source:** [AWS branch protection](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L156-L433).

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

OCI configuration follows the [OCI Platform](#oci-platform) ArgoCD/Kustomize path. The plugin and manual uploader below apply to AWS.

Prow configuration changes in `test-infra` propagate to the live cluster through two mechanisms.

### 8.1 config-updater Plugin (Immediate)

The `config-updater` plugin is enabled **only** on the `test-infra` repository. When a PR merges to `master`, the plugin automatically updates Kubernetes ConfigMaps:

| File Pattern | ConfigMap Name | Options |
|-------------|---------------|---------|
| `config/prow/aws/config.yaml` | `config` | -- |
| `config/prow/aws/plugins.yaml` | `plugins` | -- |
| `config/jobs/aws/**/*.yaml` | `job-config` | `gzip: true` |

Prow components watch these ConfigMaps and **hot-reload** their configuration. Changes take effect immediately upon merge without restart.

**Source:** [plugins.yaml:L67-L77](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L67-L77)

### 8.2 Manual Config Uploader

The former `update-jobs-pr` postsubmit is no longer configured. The retained uploader is a manual tool that replaces selected, existing ConfigMaps. AWS deployment only bootstraps missing maps; it preserves existing configuration owned by `config-updater`. See the [deployment implementation](../refs/falcosecurity/test-infra/tools/deploy_prow.sh#L60-L84).

**Source:** [`prow/update-jobs/README.md`](../refs/falcosecurity/test-infra/prow/update-jobs/README.md)

### 8.3 Config Validation

Configuration integrity is ensured by two mechanisms:

1. **Presubmit** (`check-prow-config`): Runs on every PR to `test-infra`'s `master` branch. Uses `gcr.io/k8s-prow/checkconfig:v20240805-37a08f946` to validate `config.yaml`, `plugins.yaml`, and all job configs.

2. **Periodic** (`check-prow-config-periodic`): Runs every 1 hour to revalidate the checked-out Git configuration.

Both use the same validation command:
```
checkconfig --config-path=config/prow/aws/config.yaml --job-config-path=config/jobs/aws --plugin-config=config/prow/aws/plugins.yaml
```

**Source:** [`config/jobs/aws/check-prow-config/check-prow-config.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/check-prow-config/check-prow-config.yaml)


### Validation and Reconciliation in 0.45

AWS and OCI have separate reusable validation workflows. AWS validates its manifests and job directory. OCI extracts embedded Prow config from its ConfigMaps, validates the OCI job YAML with the pinned current `checkconfig`, renders Kustomize, and validates manifests/CRDs against the configured Kubernetes version. The AWS hourly `check-prow-config-periodic` validates the checked-out Git configuration; it does not read live ConfigMaps to compare cluster drift.

**Sources:** [.github/workflows/ci-aws.yml](../refs/falcosecurity/test-infra/.github/workflows/ci-aws.yml#L1), [.github/workflows/ci-oci.yml](../refs/falcosecurity/test-infra/.github/workflows/ci-oci.yml#L1), [tools/ci/verify-prow.sh](../refs/falcosecurity/test-infra/tools/ci/verify-prow.sh#L12), [tools/ci/verify-manifests.sh](../refs/falcosecurity/test-infra/tools/ci/verify-manifests.sh#L57), [config/jobs/aws/check-prow-config/check-prow-config.yaml](../refs/falcosecurity/test-infra/config/jobs/aws/check-prow-config/check-prow-config.yaml#L20).

## 9. Container Images

### Standard Prow Images

AWS core Prow components use images from `gcr.io/k8s-prow/*`, pinned to version `v20240805-37a08f946`:
- `hook`, `deck`, `sinker`, `horologium`, `crier`, `tide`, `prow-controller-manager` (includes Plank controller)
- Utility images: `clonerefs`, `initupload`, `entrypoint`, `sidecar`
- Validation: `checkconfig`

### Custom Images

Retained AWS custom images are hosted in ECR; OCI jobs use GHCR images, with pins in their job manifests:

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
| Core Prow config (deck, plank, sinker, branch protection, tide) | [`config/prow/aws/config.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/config.yaml) |
| Plugin configuration (approve, lgtm, dco, size, triggers, per-repo plugins) | [`config/prow/aws/plugins.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml) |
| Config validation (presubmit + periodic) | [`config/jobs/aws/check-prow-config/check-prow-config.yaml`](../refs/falcosecurity/test-infra/config/jobs/aws/check-prow-config/check-prow-config.yaml) |
| Manual config uploader | [`prow/update-jobs/README.md`](../refs/falcosecurity/test-infra/prow/update-jobs/README.md) |
| Pigeon entry point | [`refs/falcosecurity/pigeon/main.go`](../refs/falcosecurity/pigeon/main.go) |
| Pigeon config parsing | [`refs/falcosecurity/pigeon/pkg/config/config.go`](../refs/falcosecurity/pigeon/pkg/config/config.go) |
| Pigeon 1Password integration | [`refs/falcosecurity/pigeon/pkg/pigeon/secrets_onepassword.go`](../refs/falcosecurity/pigeon/pkg/pigeon/secrets_onepassword.go) |
| Hook deployment manifest | [`config/prow/aws/manifests/hook.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/hook.yaml) |
| Deck deployment manifest | [`config/prow/aws/manifests/deck.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/deck.yaml) |
| Prow Controller Manager deployment manifest | [`config/prow/aws/manifests/prow-controller-manager.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/prow-controller-manager.yaml) |
| Crier deployment manifest | [`config/prow/aws/manifests/crier.yaml`](../refs/falcosecurity/test-infra/config/prow/aws/manifests/crier.yaml) |
