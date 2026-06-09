# Falco Test Infrastructure -- Prow Components & AWS Infrastructure

> **Era:** 0.44 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

This digest covers the Prow-based CI/CD infrastructure for the falcosecurity organization. The system runs on AWS EKS in `eu-west-1` and provides webhook-driven PR testing, merge automation, job logs via S3, and a web UI at [prow.falco.org](https://prow.falco.org). All Prow components use image version `v20240805-37a08f946`.

---

## Table of Contents

1. [Prow Components](#1-prow-components)
2. [AWS Infrastructure (Terraform)](#2-aws-infrastructure-terraform)
3. [Pod Identity Webhook (IRSA)](#3-pod-identity-webhook-irsa)
4. [ArgoCD Applications](#4-argocd-applications)
5. [Container Images](#5-container-images)
6. [Tools](#6-tools)
7. [Proposals (Historical Context)](#7-proposals-historical-context)
8. [Sources](#sources)

---

## 1. Prow Components

All Prow components are deployed in the `default` namespace on the EKS cluster `falco-prow-test-infra`. Every component uses a `nodeSelector` of `Archtype: "x86"` to pin to x86 nodes. Standard resource requests/limits across most components: `cpu: 100m`, `memory: 256M`.

### 1.1 Hook -- Webhook Handler

**Source:** [`config/prow/hook.yaml`](../../../refs/falcosecurity/test-infra/config/prow/hook.yaml)

- **Purpose:** Receives GitHub webhook events and dispatches them to Prow plugins. The primary entrypoint for all GitHub-driven CI activity.
- **Image:** `gcr.io/k8s-prow/hook:v20240805-37a08f946` ([L71](../../../refs/falcosecurity/test-infra/config/prow/hook.yaml))
- **Replicas:** 2 ([L53](../../../refs/falcosecurity/test-infra/config/prow/hook.yaml))
- **Strategy:** RollingUpdate (maxSurge: 1, maxUnavailable: 1)
- **Ports:** HTTP `8888`, metrics `9090`, healthz `8081` ([L82-L85](../../../refs/falcosecurity/test-infra/config/prow/hook.yaml))
- **Key args:**
  - `--github-endpoint=http://ghproxy` (local cache first)
  - `--github-endpoint=https://api.github.com` (fallback)
  - `--plugin-config=/etc/plugins/plugins.yaml`
  - `--config-path=/etc/config/config.yaml`
  - `--job-config-path=/etc/job-config`
  - `--dry-run=false`
- **Volumes:** `hmac-token` (webhook secret), `oauth-token` (GitHub PAT), `config` ConfigMap, `job-config` ConfigMap, `plugins` ConfigMap
- **RBAC:** Role in `default` namespace granting `create`, `get`, `list`, `update` on `prowjobs` and `create`, `get`, `update` on `configmaps` ([L13-L30](../../../refs/falcosecurity/test-infra/config/prow/hook.yaml))
- **Service:** NodePort type, ports 8888 and 9090 ([L141-L157](../../../refs/falcosecurity/test-infra/config/prow/hook.yaml))

### 1.2 Deck -- Web UI

**Source:** [`config/prow/deck.yaml`](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml)

- **Purpose:** Serves the Prow web dashboard (job status, PR status, Spyglass log viewer). Accessible at `prow.falco.org`.
- **Image:** `gcr.io/k8s-prow/deck:v20240805-37a08f946` ([L116](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml))
- **Replicas:** 3 ([L98](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml))
- **Ports:** HTTP `8080`, metrics `9090` ([L137-L141](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml))
- **Key args:**
  - `--spyglass=true` (enables log viewer)
  - `--tide-url=http://tide/`
  - `--hook-url=http://hook:8888/plugin-help`
  - `--redirect-http-to=prow.falco.org`
  - `--oauth-url=/github-login`
  - `--allow-insecure`
- **S3 Integration:** ServiceAccount annotated with IAM role `falco-prow-test-infra-prow_s3_access` for Spyglass to fetch job logs from S3. Env var `AWS_REGION=eu-west-1` set for bucket lookup ([L8](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml), [L118-L119](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml))
- **Service:** LoadBalancer type with AWS SSL cert annotation for HTTPS termination ([L73-L89](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml))
  - ACM certificate ARN: `arn:aws:acm:eu-west-1:292999226676:certificate/ba966f87-e470-4638-90ba-a2e9a34d5677`
- **RBAC:** Roles in both `default` (prowjobs: get/list/watch/create) and `test-pods` (pods/log: get) namespaces ([L37-L64](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml))
- **Volumes:** `config`, `job-config`, `plugins` ConfigMaps; `github-oauth-config`, `cookie` secrets; `branding` ConfigMap (custom UI)

### 1.3 Tide -- Merge Automation

**Source:** [`config/prow/tide.yaml`](../../../refs/falcosecurity/test-infra/config/prow/tide.yaml)

- **Purpose:** Automatically merges PRs that meet configured criteria (labels, status checks, reviews). Maintains merge pools and a status/history in S3.
- **Image:** `gcr.io/k8s-prow/tide:v20240805-37a08f946` ([L79](../../../refs/falcosecurity/test-infra/config/prow/tide.yaml))
- **Replicas:** 1 (must not scale up -- comment on [L65](../../../refs/falcosecurity/test-infra/config/prow/tide.yaml))
- **Strategy:** Recreate ([L70](../../../refs/falcosecurity/test-infra/config/prow/tide.yaml))
- **Ports:** HTTP `8888`, metrics `9090`
- **Key args:**
  - `--github-graphql-endpoint=http://ghproxy/graphql`
  - `--s3-credentials-file=/etc/s3-credentials/service-account.json`
  - `--status-path=s3://falco-prow-logs/tide-status`
  - `--history-uri=s3://falco-prow-logs/tide-history.json`
- **S3 Integration:** ServiceAccount with IAM role for S3 access ([L26](../../../refs/falcosecurity/test-infra/config/prow/tide.yaml)); also mounts `s3-credentials` secret
- **RBAC:** Role in `default` granting prowjobs: create/list/watch/get ([L29-L42](../../../refs/falcosecurity/test-infra/config/prow/tide.yaml))

### 1.4 Sinker -- Cleanup

**Source:** [`config/prow/sinker.yaml`](../../../refs/falcosecurity/test-infra/config/prow/sinker.yaml)

- **Purpose:** Garbage-collects completed ProwJob resources and their associated pods in the `test-pods` namespace.
- **Image:** `gcr.io/k8s-prow/sinker:v20240805-37a08f946` ([L119](../../../refs/falcosecurity/test-infra/config/prow/sinker.yaml))
- **Replicas:** 1
- **Ports:** metrics `9090`
- **RBAC:** Leader election via `prow-sinker-leaderlock` lease/configmap. Roles in `default` (prowjobs: delete/list/watch/get; leases and configmaps for leader election) and `test-pods` (pods: delete/list/watch/get/patch) ([L8-L70](../../../refs/falcosecurity/test-infra/config/prow/sinker.yaml))

### 1.5 Horologium -- Periodic Job Scheduler

**Source:** [`config/prow/horologium.yaml`](../../../refs/falcosecurity/test-infra/config/prow/horologium.yaml)

- **Purpose:** Triggers periodic ProwJobs on their configured cron schedules (e.g., nightly driver builds).
- **Image:** `gcr.io/k8s-prow/horologium:v20240805-37a08f946` ([L58](../../../refs/falcosecurity/test-infra/config/prow/horologium.yaml))
- **Replicas:** 1 (must not scale up -- [L43](../../../refs/falcosecurity/test-infra/config/prow/horologium.yaml))
- **Strategy:** Recreate
- **Ports:** metrics `9090`
- **RBAC:** Role in `default` granting prowjobs: create/list ([L7-L15](../../../refs/falcosecurity/test-infra/config/prow/horologium.yaml))

### 1.6 Crier -- GitHub Status Reporter

**Source:** [`config/prow/crier.yaml`](../../../refs/falcosecurity/test-infra/config/prow/crier.yaml)

- **Purpose:** Reports ProwJob status back to GitHub (commit statuses, check runs) and uploads job artifacts to blob storage (S3).
- **Image:** `gcr.io/k8s-prow/crier:v20240805-37a08f946` ([L22](../../../refs/falcosecurity/test-infra/config/prow/crier.yaml))
- **Replicas:** 1
- **Ports:** metrics `9090`
- **Key args:**
  - `--github-workers=2`
  - `--kubernetes-blob-storage-workers=2`
  - `--blob-storage-workers=2`
- **Env:** `AWS_REGION=eu-west-1` ([L24-L25](../../../refs/falcosecurity/test-infra/config/prow/crier.yaml))
- **S3 Integration:** ServiceAccount with IAM role `falco-prow-test-infra-prow_s3_access` ([L82](../../../refs/falcosecurity/test-infra/config/prow/crier.yaml))
- **RBAC:** Roles in `default` (prowjobs: get/watch/list/patch) and `test-pods` (pods/events: get/list; pods: patch) ([L84-L147](../../../refs/falcosecurity/test-infra/config/prow/crier.yaml))

### 1.7 Prow Controller Manager -- Job Pod Creation

**Source:** [`config/prow/prow-controller-manager.yaml`](../../../refs/falcosecurity/test-infra/config/prow/prow-controller-manager.yaml)

- **Purpose:** Manages the lifecycle of ProwJob pods in the `test-pods` namespace. Replaces the deprecated Plank controller. Enabled with `--enable-controller=plank` ([L32](../../../refs/falcosecurity/test-infra/config/prow/prow-controller-manager.yaml)).
- **Image:** `gcr.io/k8s-prow/prow-controller-manager:v20240805-37a08f946` ([L24](../../../refs/falcosecurity/test-infra/config/prow/prow-controller-manager.yaml))
- **Replicas:** 1
- **Strategy:** Recreate
- **Ports:** metrics `9090`
- **Env:** `AWS_REGION=eu-west-1`
- **S3 Integration:** ServiceAccount with IAM role `falco-prow-test-infra-prow_s3_access` ([L74](../../../refs/falcosecurity/test-infra/config/prow/prow-controller-manager.yaml))
- **RBAC:** Leader election via `prow-controller-manager-leader-lock`. Roles in `default` (prowjobs: get/update/list/watch/patch; leases and configmaps for leader election) and `test-pods` (pods: delete/list/watch/create/patch/get) ([L76-L168](../../../refs/falcosecurity/test-infra/config/prow/prow-controller-manager.yaml))

### 1.8 GHProxy -- GitHub API Cache

**Source:** [`config/prow/ghproxy.yaml`](../../../refs/falcosecurity/test-infra/config/prow/ghproxy.yaml)

- **Purpose:** Caching reverse proxy for GitHub API requests. Reduces API rate limit consumption. All Prow components point `--github-endpoint=http://ghproxy` as their primary GitHub endpoint.
- **Image:** `gcr.io/k8s-prow/ghproxy:v20240805-37a08f946` ([L64](../../../refs/falcosecurity/test-infra/config/prow/ghproxy.yaml))
- **Replicas:** 1
- **Ports:** main `8888`, metrics `9090`
- **Key args:**
  - `--cache-dir=/cache`
  - `--cache-sizeGB=99`
  - `--serve-metrics=true`
- **Storage:** 100Gi PVC using `ebs-ssd-retain` StorageClass (EBS SSD with Retain reclaim policy) ([L11-L24](../../../refs/falcosecurity/test-infra/config/prow/ghproxy.yaml))
- **Service:** ClusterIP, port 80 mapped to 8888 ([L26-L43](../../../refs/falcosecurity/test-infra/config/prow/ghproxy.yaml))

### 1.9 Status Reconciler

**Source:** [`config/prow/statusreconciler.yaml`](../../../refs/falcosecurity/test-infra/config/prow/statusreconciler.yaml)

- **Purpose:** Reconciles GitHub PR statuses when Prow config changes (e.g., when required jobs are renamed or removed). Stores last known configuration state in S3.
- **Image:** `gcr.io/k8s-prow/status-reconciler:v20240805-37a08f946` ([L22](../../../refs/falcosecurity/test-infra/config/prow/statusreconciler.yaml))
- **Replicas:** 1
- **Key args:**
  - `--continue-on-error=true`
  - `--status-path=s3://falco-prow-logs/status-reconciler-status`
  - `--s3-credentials-file=/etc/s3-credentials/service-account.json`
- **S3 Integration:** ServiceAccount with IAM role `falco-prow-test-infra-prow_s3_access` ([L82](../../../refs/falcosecurity/test-infra/config/prow/statusreconciler.yaml))
- **RBAC:** Role in `default` granting prowjobs: create ([L83-L108](../../../refs/falcosecurity/test-infra/config/prow/statusreconciler.yaml))

### 1.10 Needs-Rebase

**Source:** [`config/prow/needs-rebase.yaml`](../../../refs/falcosecurity/test-infra/config/prow/needs-rebase.yaml)

- **Purpose:** External Prow plugin that adds/removes the `needs-rebase` label on PRs based on merge conflict status.
- **Image:** `gcr.io/k8s-prow/needs-rebase:v20240805-37a08f946` ([L35](../../../refs/falcosecurity/test-infra/config/prow/needs-rebase.yaml))
- **Replicas:** 1
- **Ports:** HTTP `8888`
- **Service:** NodePort, port 80 mapped to 8888 ([L2-L13](../../../refs/falcosecurity/test-infra/config/prow/needs-rebase.yaml))
- **Volumes:** `hmac-token`, `oauth-token`, `plugins` ConfigMap

### 1.11 Check-Config RBAC

**Source:** [`config/prow/check-config.yaml`](../../../refs/falcosecurity/test-infra/config/prow/check-config.yaml)

- **Purpose:** ClusterRole and ClusterRoleBinding that allow `system:nodes` group to read secrets cluster-wide. Used by Prow config validation jobs.
- **RBAC:** ClusterRole `check-prow-config` granting secrets: get/list to `system:nodes` group ([L1-L27](../../../refs/falcosecurity/test-infra/config/prow/check-config.yaml))

### 1.12 ALB Ingress

**Source:** [`config/prow/alb_ingress.yaml`](../../../refs/falcosecurity/test-infra/config/prow/alb_ingress.yaml)

- **Purpose:** AWS Application Load Balancer Ingress routing external traffic to Prow services.
- **Routes:**
  - `/` -> `deck:80` (Prow dashboard)
  - `/hook` -> `hook:8888` (webhook endpoint)
- **Annotations:** `kubernetes.io/ingress.class: alb`, `alb.ingress.kubernetes.io/scheme: internet-facing`
- **Listen ports:** HTTP 80 and HTTP 8888 ([L9](../../../refs/falcosecurity/test-infra/config/prow/alb_ingress.yaml))

### 1.13 Build-Drivers ServiceAccount

**Source:** [`config/prow/build-drivers-serviceaccount.yaml`](../../../refs/falcosecurity/test-infra/config/prow/build-drivers-serviceaccount.yaml)

- **Purpose:** ServiceAccount in `test-pods` namespace for driver build jobs. Annotated with IAM role for S3 access to the `falco-distribution/driver` bucket path.
- **Namespace:** `test-pods`
- **IAM Role:** `falco-prow-test-infra-drivers_s3_access` ([L7](../../../refs/falcosecurity/test-infra/config/prow/build-drivers-serviceaccount.yaml))

### 1.14 AWS Auth Config RBAC

**Source:** [`config/prow/aws-auth-config-rbac.yaml`](../../../refs/falcosecurity/test-infra/config/prow/aws-auth-config-rbac.yaml)

- **Purpose:** Allows the `aws-config-readers` group to read the `aws-auth` ConfigMap in `kube-system`. Used by the test-infra reader GitHub Actions role.
- **RBAC:** Role in `kube-system` granting configmaps `aws-auth`: get ([L1-L25](../../../refs/falcosecurity/test-infra/config/prow/aws-auth-config-rbac.yaml))

### 1.15 Cluster Autoscaler

**Source:** [`config/prow/cluster-autoscaler.yaml`](../../../refs/falcosecurity/test-infra/config/prow/cluster-autoscaler.yaml)

- **Purpose:** Automatically scales EKS node groups based on pending pod demand. Critical for scaling CI job capacity.
- **Image:** `registry.k8s.io/autoscaling/cluster-autoscaler:v1.30.1` ([L150](../../../refs/falcosecurity/test-infra/config/prow/cluster-autoscaler.yaml))
- **Namespace:** `kube-system`
- **Replicas:** 1
- **Key flags:**
  - `--cloud-provider=aws`
  - `--skip-nodes-with-local-storage=false`
  - `--expander=least-waste`
  - `--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/falco-prow-test-infra`
- **IAM Role:** `falco-prow-test-infra-cluster-autoscaler` via IRSA ([L9](../../../refs/falcosecurity/test-infra/config/prow/cluster-autoscaler.yaml))
- **Security:** `priorityClassName: system-cluster-critical`, `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, all capabilities dropped ([L141-L176](../../../refs/falcosecurity/test-infra/config/prow/cluster-autoscaler.yaml))
- **Resources:** requests `cpu: 100m, memory: 600Mi`, limits `memory: 2Gi` ([L152-L157](../../../refs/falcosecurity/test-infra/config/prow/cluster-autoscaler.yaml))
- **RBAC:** Extensive ClusterRole covering nodes, pods, services, replicationcontrollers, PVCs, PVs, replicasets, daemonsets, statefulsets, storageclasses, jobs, leases, and more ([L16-L67](../../../refs/falcosecurity/test-infra/config/prow/cluster-autoscaler.yaml))

---

## 2. AWS Infrastructure (Terraform)

The entire AWS infrastructure is managed via Terraform, with state stored in S3 with DynamoDB locking.

### 2.1 Cluster Naming and Labels

**Source:** [`config/clusters/global.tf`](../../../refs/falcosecurity/test-infra/config/clusters/global.tf)

The cluster name is derived from cloudposse `terraform-terraform-label` module using:
- namespace: `falco`, stage: `prow`, name: `test-infra`
- Result: `falco-prow-test-infra` ([L1-L15](../../../refs/falcosecurity/test-infra/config/clusters/global.tf))

Two Kubernetes namespaces are referenced:
- `default` -- Prow control plane components
- `test-pods` -- ProwJob execution pods

### 2.2 EKS Cluster

**Source:** [`config/clusters/eks.tf`](../../../refs/falcosecurity/test-infra/config/clusters/eks.tf)

- **Module:** `terraform-aws-modules/eks/aws` v17.1.0 ([L2-L3](../../../refs/falcosecurity/test-infra/config/clusters/eks.tf))
- **Kubernetes version:** `1.30` ([`eks_variables.tf:L2`](../../../refs/falcosecurity/test-infra/config/clusters/eks_variables.tf))
- **IRSA:** Enabled (`enable_irsa = true`) ([L11](../../../refs/falcosecurity/test-infra/config/clusters/eks.tf))
- **Audit logging:** Enabled (`cluster_enabled_log_types = ["audit"]`) ([L12](../../../refs/falcosecurity/test-infra/config/clusters/eks.tf))

**Node groups (3 managed node groups):**

| Node Group | Instance Type | AMI Type | Desired/Min/Max | Label `Archtype` | Label `Application` | Taints |
|---|---|---|---|---|---|---|
| `default` (prow-worker-group) | `m5.large` | AL2_x86_64 | 3/1/10 | `x86` | `prow` | None |
| `jobs` (jobs-worker-group) | `m5.large` | AL2_x86_64 | defaults/1/20 | `x86` | `jobs` | `Availability=SingleAZ:NoSchedule` |
| `jobs_arm` (jobs-arm-worker-group) | `m6g.large` | AL2_ARM_64 | defaults/1/20 | `arm` | `jobs` | `Archtype=arm:NoSchedule`, `Availability=SingleAZ:NoSchedule` |

**Source for variable values:** [`config/clusters/prow.auto.tfvars`](../../../refs/falcosecurity/test-infra/config/clusters/prow.auto.tfvars)
- Default worker group desired capacity: 3 ([L10](../../../refs/falcosecurity/test-infra/config/clusters/prow.auto.tfvars))
- Max capacities: default 10, jobs x86 20, jobs ARM 20 ([L13-L15](../../../refs/falcosecurity/test-infra/config/clusters/prow.auto.tfvars))

**Source for variable defaults:** [`config/clusters/eks_variables.tf`](../../../refs/falcosecurity/test-infra/config/clusters/eks_variables.tf)
- Default worker: `m5.large`, desired 4, min 1, max 10 ([L8-L31](../../../refs/falcosecurity/test-infra/config/clusters/eks_variables.tf))
- Jobs x86: `m5.large`, desired 4, min 1, max 10 ([L40-L63](../../../refs/falcosecurity/test-infra/config/clusters/eks_variables.tf))
- Jobs ARM: `m6g.large`, desired 1, min 1, max 3 ([L72-L95](../../../refs/falcosecurity/test-infra/config/clusters/eks_variables.tf))

Key design note: Jobs node groups are pinned to a single Availability Zone to avoid AutoScaling conflicts with cluster-autoscaler during AZ-rebalance events. This guarantees QoS for long-running build jobs ([L59-L64](../../../refs/falcosecurity/test-infra/config/clusters/eks.tf)).

### 2.3 VPC

**Source:** [`config/clusters/vpc.tf`](../../../refs/falcosecurity/test-infra/config/clusters/vpc.tf)

- **Module:** `terraform-aws-modules/vpc/aws` v3.18.1
- **CIDR:** `10.0.0.0/16` ([`prow.auto.tfvars:L7`](../../../refs/falcosecurity/test-infra/config/clusters/prow.auto.tfvars))
- **Private subnets:** `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` ([`prow.auto.tfvars:L5`](../../../refs/falcosecurity/test-infra/config/clusters/prow.auto.tfvars))
- **Public subnets:** `10.0.4.0/24`, `10.0.5.0/24`, `10.0.6.0/24` ([`prow.auto.tfvars:L6`](../../../refs/falcosecurity/test-infra/config/clusters/prow.auto.tfvars))
- **NAT Gateway:** Enabled
- **Subnet tagging:** Public subnets tagged for ELB, private subnets tagged for internal ELB ([L16-L28](../../../refs/falcosecurity/test-infra/config/clusters/vpc.tf))

### 2.4 Terraform Backend

**Source:** [`config/clusters/terraform_backend.tf`](../../../refs/falcosecurity/test-infra/config/clusters/terraform_backend.tf)

- **S3 backend:** bucket `falco-test-infra-state`, key `terraform.tfstate`, region `eu-west-1`
- **DynamoDB lock table:** `falco-test-infra-state-lock`
- **Encryption:** Enabled

**State storage resources** (managed in [`config/clusters/terraform_state.tf`](../../../refs/falcosecurity/test-infra/config/clusters/terraform_state.tf)):
- S3 bucket `falco-test-infra-state` with versioning and KMS encryption ([L1-L34](../../../refs/falcosecurity/test-infra/config/clusters/terraform_state.tf))
- DynamoDB table `falco-test-infra-state-lock` with `LockID` hash key, server-side encryption ([L42-L56](../../../refs/falcosecurity/test-infra/config/clusters/terraform_state.tf))

### 2.5 IAM Roles and OIDC

**Source:** [`config/clusters/iam.tf`](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)

All IAM roles use OIDC-based `iam-assumable-role-with-oidc` module v4.1.0, linking Kubernetes ServiceAccounts to AWS IAM roles (IRSA pattern).

**Prow-internal IAM roles:**

| Role | Purpose | Bound ServiceAccounts |
|---|---|---|
| `falco-prow-test-infra-prow_s3_access` | Full S3 access to `falco-prow-logs` bucket + KMS encrypt/decrypt | tide, deck, crier, statusreconciler, prow-controller-manager ([L207-L213](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falco-prow-test-infra-drivers_s3_access` | S3 access to `falco-distribution/driver/*` | driver-kit (test-pods namespace) ([L260-L262](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falco-prow-test-infra-ebs-csi-controller` | EBS CSI driver permissions | ebs-csi-controller-sa (kube-system) ([L14-L16](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falco-prow-test-infra-cluster-autoscaler` | Autoscaling group management | cluster-autoscaler (kube-system) ([L159-L161](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falco-prow-test-infra-loadbalancer-controller` | ALB/NLB management | aws-load-balancer-controller (kube-system) ([L852-L854](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |

**GitHub Actions OIDC roles** (using `iam-github-oidc-role` module v5.10.0):

| Role | Repository | Trigger | S3 Path / Purpose |
|---|---|---|---|
| `rules_s3_role` | `falcosecurity/rules` | main branch + tags | `falco-distribution/rules/*` ([L295-L330](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `plugins_s3_role` | `falcosecurity/plugins` | main branch + tags | `falco-distribution/plugins/*` ([L334-L370](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `test-infra_cluster_role` | `falcosecurity/test-infra` | master branch | Full AWS access (`*:*`) for Terraform/Prow deploy ([L374-L404](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `test-infra_reader` | `falcosecurity/test-infra` | pull_request | ReadOnlyAccess + DynamoDB state lock ([L406-L438](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `test-infra_s3_role` | `falcosecurity/test-infra` | master branch | `falco-distribution/driver/site/*` for drivers website update ([L440-L475](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falco_dev_s3_role` | `falcosecurity/falco` | master + tags | `falco-distribution/packages/*-dev/*` + CloudFront invalidation ([L479-L525](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falco_s3_role` | `falcosecurity/falco` | tags only | `falco-distribution/packages/*` + CloudFront invalidation ([L529-L574](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falco_ecr_role` | `falcosecurity/falco` | master + tags | ECR push to `falco`, `falco-driver-loader`, `falco-no-driver`, `falco-driver-loader-legacy`, `falco-distroless` repos ([L578-L629](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falcosidekick_ecr_role` | `falcosecurity/falcosidekick` | master + tags | ECR push to `falcosidekick` ([L633-L680](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falcosidekick_ui_ecr_role` | `falcosecurity/falcosidekick-ui` | master + tags | ECR push to `falcosidekick-ui` ([L684-L731](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falcoctl_ecr_role` | `falcosecurity/falcoctl` | main + tags | ECR push to `falcoctl` ([L735-L782](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |
| `falco_playground_s3_role` | `falcosecurity/falco-playground` | tags | `falco-playground/*` + CloudFront invalidation ([L786-L841](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf)) |

### 2.6 S3 Storage

**Source:** [`config/clusters/storage.tf`](../../../refs/falcosecurity/test-infra/config/clusters/storage.tf)

**Prow logs bucket: `falco-prow-logs`**
- Versioning enabled ([L9-L14](../../../refs/falcosecurity/test-infra/config/clusters/storage.tf))
- Lifecycle: 10-day retention for objects under `logs/` prefix ([L16-L45](../../../refs/falcosecurity/test-infra/config/clusters/storage.tf))
- Server-side encryption with KMS (key rotation enabled) ([L47-L72](../../../refs/falcosecurity/test-infra/config/clusters/storage.tf))
- Private ACL ([L58-L61](../../../refs/falcosecurity/test-infra/config/clusters/storage.tf))
- Bucket policy allows full S3 access to the Prow IAM role ([L74-L93](../../../refs/falcosecurity/test-infra/config/clusters/storage.tf))

### 2.7 ECR Repositories

**Source:** [`config/clusters/ecr.tf`](../../../refs/falcosecurity/test-infra/config/clusters/ecr.tf)

Private ECR repositories for CI container images (all KMS encrypted):

| Repository | Purpose |
|---|---|
| `test-infra/update-jobs` | Job config updater image |
| `test-infra/golang` | Go build environment |
| `test-infra/build-drivers` | Driver build image |
| `test-infra/docker-dind` | Docker-in-Docker base image |
| `test-infra/build-plugins` | Plugin build image |
| `test-infra/update-falco-k8s-manifests` | K8s manifest updater |
| `test-infra/update-dbg` | DBG config updater |
| `test-infra/update-rules-index` | Rules index updater |

### 2.8 DNS Certificates

- `prow.falco.org` -- ACM certificate for Deck ([`config/clusters/kubernetes.tf:L1-L8`](../../../refs/falcosecurity/test-infra/config/clusters/kubernetes.tf))
- `monitoring.prow.falco.org` -- ACM certificate for Grafana ([`config/clusters/monitoring.tf:L1-L8`](../../../refs/falcosecurity/test-infra/config/clusters/monitoring.tf))

### 2.9 EKS Users

**Source:** [`config/clusters/eks_variables.tf:L97-L168`](../../../refs/falcosecurity/test-infra/config/clusters/eks_variables.tf)

Nine IAM users are mapped to the `system:masters` group for cluster admin access. Two IAM roles are also mapped in [`prow.auto.tfvars:L17-L28`](../../../refs/falcosecurity/test-infra/config/clusters/prow.auto.tfvars):
- `github_actions-test-infra-cluster` -> `system:masters`
- `github_actions-test-infra-reader` -> `aws-config-readers`

---

## 3. Pod Identity Webhook (IRSA)

**Source:** [`config/prow/pod-identity-webhook/`](../../../refs/falcosecurity/test-infra/config/prow/pod-identity-webhook/deployment-base.yaml)

The Amazon EKS Pod Identity Webhook injects AWS credentials into pods based on ServiceAccount annotations (`eks.amazonaws.com/role-arn`). This is the mechanism that enables IRSA (IAM Roles for Service Accounts).

- **Image:** `amazon/amazon-eks-pod-identity-webhook:v0.5.5` ([`deployment-base.yaml:L21`](../../../refs/falcosecurity/test-infra/config/prow/pod-identity-webhook/deployment-base.yaml))
- **Namespace:** `pod-identity-webhook`
- **Replicas:** 1
- **Key args:**
  - `--in-cluster=false`
  - `--annotation-prefix=eks.amazonaws.com`
  - `--token-audience=sts.amazonaws.com`
- **TLS:** Certificate managed by cert-manager via self-signed ClusterIssuer, 90-day duration, 15-day renewal ([`deployment-base.yaml:L40-L66`](../../../refs/falcosecurity/test-infra/config/prow/pod-identity-webhook/deployment-base.yaml))
- **MutatingWebhookConfiguration:** Intercepts pod CREATE operations, injects AWS credential environment variables and projected token volumes. `failurePolicy: Ignore` ([`mutatingwebhook.yaml:L10`](../../../refs/falcosecurity/test-infra/config/prow/pod-identity-webhook/mutatingwebhook.yaml))
- **RBAC:** ClusterRole granting serviceaccounts: get/watch/list and certificatesigningrequests: create/get/list/watch ([`auth.yaml:L44-L66`](../../../refs/falcosecurity/test-infra/config/prow/pod-identity-webhook/auth.yaml))
- **Service:** port 443 ([`service.yaml`](../../../refs/falcosecurity/test-infra/config/prow/pod-identity-webhook/service.yaml))

---

## 4. ArgoCD Applications

Six applications are deployed via ArgoCD, all with automated sync and `ServerSideApply` enabled.

**Source:** [`config/applications/`](../../../refs/falcosecurity/test-infra/config/applications/falco.yaml)

| Application | Chart | Version | Namespace | Key Config |
|---|---|---|---|---|
| **AWS Load Balancer Controller** | `aws-load-balancer-controller` (eks-charts) | 1.10.0 | `kube-system` | IRSA for ALB management, x86 nodeSelector ([`alb-controller.yaml`](../../../refs/falcosecurity/test-infra/config/applications/alb-controller.yaml)) |
| **cert-manager** | `cert-manager` (jetstack) | 1.16.1 | `cert-manager` | CRDs enabled, Prometheus disabled ([`cert-manager.yaml`](../../../refs/falcosecurity/test-infra/config/applications/cert-manager.yaml)) |
| **AWS EBS CSI Driver** | `aws-ebs-csi-driver` (k8s-sigs) | 2.36.0 | `kube-system` | IRSA for EBS, `ebs-ssd-retain` StorageClass as default ([`ebs-csi-controller.yaml`](../../../refs/falcosecurity/test-infra/config/applications/ebs-csi-controller.yaml)) |
| **Falco** | `falco` (falcosecurity charts) | 7.2.1 | `falco` | Image tag `0.44.0`, modern eBPF driver, container plugin `0.7.1`, k8smeta plugin `0.4.1`, metrics + ServiceMonitor enabled, Grafana dashboards ([`falco.yaml`](../../../refs/falcosecurity/test-infra/config/applications/falco.yaml)) |
| **kube-prometheus-stack** | `kube-prometheus-stack` (prometheus-community) | 66.2.1 | `monitoring` | 180-day retention, 100Gi EBS storage, Grafana with ALB ingress on `monitoring.prow.falco.org`, anonymous viewer access ([`kube-stack-prometheus.yaml`](../../../refs/falcosecurity/test-infra/config/applications/kube-stack-prometheus.yaml)) |
| **prometheus-operator-crds** | `prometheus-operator-crds` (prometheus-community) | 16.0.0 | `prometheus-operator-crds` | CRDs managed separately from kube-prometheus-stack ([`prometheus-operator-crds.yaml`](../../../refs/falcosecurity/test-infra/config/applications/prometheus-operator-crds.yaml)) |

Notable: Falco itself is deployed on the Prow cluster with tolerations for both `SingleAZ` and `arm` nodes, allowing it to monitor all node groups ([`falco.yaml:L19-L27`](../../../refs/falcosecurity/test-infra/config/applications/falco.yaml)).

---

## 5. Container Images

**Source:** [`images/`](../../../refs/falcosecurity/test-infra/images/build-drivers/Dockerfile)

10 image directories, stored in private ECR (`292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/`).

### 5.1 Image Catalog

| Image | Base | Purpose |
|---|---|---|
| **docker-dind** | `debian:buster` | Docker-in-Docker base image with build-essential, curl, git, jq, Docker CE 20.10.1, AWS CLI v2 ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/docker-dind/Dockerfile)) |
| **build-drivers** | `docker-dind` (custom) | Driver build image with `dbg-go` v0.17.0 for orchestrating driverkit builds; multi-arch (`TARGETARCH`) ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/build-drivers/Dockerfile)) |
| **build-plugins** | `golang:1.24-bullseye` | Plugin CI image with `pr-creator` from k8s test-infra; runs `on-registry-changed.sh` ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/build-plugins/Dockerfile)) |
| **golang** | `golang:1.13` | Legacy Go build environment with `dep` v0.5.4 ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/golang/Dockerfile)) |
| **ghissue** | `golang:1.24-alpine` | Creates GitHub issues via `ghissue` CLI tool ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/ghissue/Dockerfile)) |
| **update-dbg** | `golang:1.24-bookworm` | Updates DBG (Drivers Build Grid) configs with `dbg-go` v0.17.0 and `pr-creator` ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-dbg/Dockerfile)) |
| **update-falco-k8s-manifests** | `golang:1.24-bookworm` | Updates Falco Kubernetes manifests using Helm and Kustomize, with `pr-creator` ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-falco-k8s-manifests/Dockerfile)) |
| **update-jobs** | `golang:1.15.7-alpine` | Go binary that updates Prow job configurations ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-jobs/Dockerfile)) |
| **update-maintainers** | `golang:1.21-bookworm` | Generates OWNERS files from maintainers data using `maintainers-generator` and `pr-creator` ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-maintainers/Dockerfile)) |
| **update-rules-index** | `golang:1.24` | Updates rules registry index via `on-registry-changed.sh` and `pr-creator` ([`Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-rules-index/Dockerfile)) |

### 5.2 Build and Publish Scripts

**Source:** [`images/build.sh`](../../../refs/falcosecurity/test-infra/images/build.sh), [`images/publish.sh`](../../../refs/falcosecurity/test-infra/images/publish.sh)

- **`build.sh`**: Starts Docker-in-Docker, then runs `make -C <source_dir> build-image` ([L34-L44](../../../refs/falcosecurity/test-infra/images/build.sh))
- **`publish.sh`**: Starts Docker-in-Docker, authenticates to AWS ECR (`292999226676.dkr.ecr.eu-west-1.amazonaws.com`), then runs `make -C <source_dir> build-push` ([L34-L74](../../../refs/falcosecurity/test-infra/images/publish.sh))

---

## 6. Tools

### 6.1 deploy_prow.sh -- Deployment Script

**Source:** [`tools/deploy_prow.sh`](../../../refs/falcosecurity/test-infra/tools/deploy_prow.sh)

Bash script for deploying/updating the Prow installation on EKS. Execution flow:

1. `updateKubeConfig()` -- Uses `aws eks update-kubeconfig` for cluster `falco-prow-test-infra` in `eu-west-1` ([L33-L35](../../../refs/falcosecurity/test-infra/tools/deploy_prow.sh))
2. `launchConfig()` -- Deploys prerequisites:
   - Metrics Server v0.4.4 ([L46-L48](../../../refs/falcosecurity/test-infra/tools/deploy_prow.sh))
   - Pod Identity Webhook manifests ([L37-L42](../../../refs/falcosecurity/test-infra/tools/deploy_prow.sh))
   - Prow ConfigMaps (plugins, config, job-config, branding) and Secrets (hmac-token, oauth-token, s3-credentials) ([L50-L73](../../../refs/falcosecurity/test-infra/tools/deploy_prow.sh))
3. `launchProw()` -- Applies all manifests in `config/prow/` ([L86-L88](../../../refs/falcosecurity/test-infra/tools/deploy_prow.sh))

Environment variables required: `PROW_HMAC_TOKEN`, `PROW_OAUTH_TOKEN`, `PROW_SERVICE_ACCOUNT_JSON`.

### 6.2 local_prowjob.sh -- Local Testing

**Source:** [`tools/local_prowjob.sh`](../../../refs/falcosecurity/test-infra/tools/local_prowjob.sh)

Bash script for testing Prow jobs locally using `kind` (Kubernetes in Docker). Workflow:

1. Creates a local Docker registry (`kind-registry` on port 5000) ([L175-L188](../../../refs/falcosecurity/test-infra/tools/local_prowjob.sh))
2. Sets up a `kind` cluster named `mkpod` ([L117-L173](../../../refs/falcosecurity/test-infra/tools/local_prowjob.sh))
3. Uses `gcr.io/k8s-prow/mkpj` to generate a ProwJob YAML from config ([L43](../../../refs/falcosecurity/test-infra/tools/local_prowjob.sh))
4. Uses `gcr.io/k8s-prow/mkpod` to convert ProwJob to a Kubernetes Pod spec ([L44](../../../refs/falcosecurity/test-infra/tools/local_prowjob.sh))
5. Applies the pod and watches execution ([L69-L70](../../../refs/falcosecurity/test-infra/tools/local_prowjob.sh))

Default paths: `config/config.yaml`, `config/jobs/driverkit/driverkit-test.local`, `images/golang` ([L25-L27](../../../refs/falcosecurity/test-infra/tools/local_prowjob.sh))

### 6.3 prow-jobs-checker -- Job Validation

**Source:** [`tools/prow-jobs-checker/main.go`](../../../refs/falcosecurity/test-infra/tools/prow-jobs-checker/main.go)

Go tool that validates Prow job configurations. Uses `sigs.k8s.io/prow/pkg/config` to parse and validate presubmit and postsubmit jobs.

**Features:**
- Loads and parses Prow config with `config.LoadStrict()` ([L80](../../../refs/falcosecurity/test-infra/tools/prow-jobs-checker/main.go))
- Validates all presubmit and postsubmit job definitions ([L95-L133](../../../refs/falcosecurity/test-infra/tools/prow-jobs-checker/main.go))
- Optionally checks if jobs would trigger for a given changed file (`--changed-file` flag) ([L105-L109](../../../refs/falcosecurity/test-infra/tools/prow-jobs-checker/main.go))
- Auto-detects default branch via GitHub API when `--base-ref` is not provided ([L69-L76](../../../refs/falcosecurity/test-infra/tools/prow-jobs-checker/main.go))
- Uses `go-github/v61` for GitHub API calls

**CLI flags:**
- `--config-job` (default: `config/jobs/`)
- `--config-prow` (default: `config/config.yaml`)
- `--changed-file` -- file path to test trigger against
- `--base-ref` -- base branch for trigger evaluation
- `--verbose` -- debug logging
- `--token` -- GitHub token for unauthenticated rate limit avoidance

### 6.4 update-drivers-website -- Driver Site Generator

**Source:** [`tools/update-drivers-website/updateDriversWebsite.go`](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go)

Go tool that generates JSON index files for the Falco drivers website by fetching the S3 driver bucket listing.

**How it works:**
1. Fetches XML bucket listing from `https://falco-distribution.s3-eu-west-1.amazonaws.com/?list-type=2&prefix=driver` ([L32](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go))
2. Parses `.ko` (kmod) and `.o` (eBPF) files, extracting lib version, arch, kind, target, and kernel info ([L134-L161](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go))
3. Generates per-lib JSON files and a master `index.json` with all lib versions ([L84-L110](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go))
4. Download URLs point to `https://download.falco.org/` ([L33](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go))
5. Handles pagination via `NextContinuationToken` for large bucket listings ([L184-L186](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go))

---

## 7. Proposals (Historical Context)

### 7.1 Prow on AWS (September 2020)

**Source:** [`proposals/20200915-prow.md`](../../../refs/falcosecurity/test-infra/proposals/20200915-prow.md)

This proposal initiated the Prow deployment on AWS EKS. Prior to this, Prow was only used for label automation via GitHub. The proposal aimed to establish full testing infrastructure with components including Hook, GHProxy, Horologium, Tide, Spyglass, Crier, and Deck. The only prerequisites were an AWS account and an S3 bucket. The proposal explicitly noted it was not intended to replace the existing CI/CD pipeline but to supplement it with centralized test result visibility and PR-based testing workflows.

### 7.2 Infra Admins (September 2020)

**Source:** [`proposals/20200925-admins.md`](../../../refs/falcosecurity/test-infra/proposals/20200925-admins.md)

Defines the role and responsibilities of Falco infrastructure administrators:
- Infra admins are listed in the OWNERS file of `falcosecurity/test-infra`
- Since September 2022, Core Maintainers (per governance) can also administer infra resources ([L24](../../../refs/falcosecurity/test-infra/proposals/20200925-admins.md))
- Responsible for secrets management, system outages, security incidents
- Encouraged to follow "Open Infrastructure" and "GitOps" principles
- All ownership inherited from CNCF/LF

---

## Architecture Summary

```
GitHub Webhooks
      |
      v
  [ALB Ingress] --(/)----> [Deck x3] ----> prow.falco.org
      |            \--(hook)--> [Hook x2] --> Prow Plugins
      |                              |
      |                      [GHProxy (99GB cache)]
      |                              |
      |                       GitHub API
      |
  [Tide x1]           [Horologium x1]     [Crier x1]
  (merge pools)        (cron triggers)     (status reporter)
      |                      |                  |
      +--------+-------------+---------+--------+
               |                       |
  [Prow Controller Manager x1]   [Sinker x1]
  (creates job pods)              (cleans up)
               |
         [test-pods namespace]
         (ProwJob execution)
               |
         [S3: falco-prow-logs]
         (logs, tide status,
          status-reconciler state)
```

**EKS Node Groups:**
```
falco-prow-test-infra (EKS 1.30, eu-west-1)
  |
  +-- default (m5.large, x86, 3-10 nodes) -- Prow control plane
  +-- jobs (m5.large, x86, 1-20 nodes, single AZ) -- x86 CI jobs
  +-- jobs_arm (m6g.large, arm64, 1-20 nodes, single AZ) -- ARM CI jobs
```

---

## Sources

| Topic | Source File |
|-------|-------------|
| Hook deployment | [`config/prow/hook.yaml`](../../../refs/falcosecurity/test-infra/config/prow/hook.yaml) |
| Deck deployment | [`config/prow/deck.yaml`](../../../refs/falcosecurity/test-infra/config/prow/deck.yaml) |
| Tide deployment | [`config/prow/tide.yaml`](../../../refs/falcosecurity/test-infra/config/prow/tide.yaml) |
| Sinker deployment | [`config/prow/sinker.yaml`](../../../refs/falcosecurity/test-infra/config/prow/sinker.yaml) |
| Horologium deployment | [`config/prow/horologium.yaml`](../../../refs/falcosecurity/test-infra/config/prow/horologium.yaml) |
| Crier deployment | [`config/prow/crier.yaml`](../../../refs/falcosecurity/test-infra/config/prow/crier.yaml) |
| Prow Controller Manager | [`config/prow/prow-controller-manager.yaml`](../../../refs/falcosecurity/test-infra/config/prow/prow-controller-manager.yaml) |
| GHProxy deployment | [`config/prow/ghproxy.yaml`](../../../refs/falcosecurity/test-infra/config/prow/ghproxy.yaml) |
| Status Reconciler | [`config/prow/statusreconciler.yaml`](../../../refs/falcosecurity/test-infra/config/prow/statusreconciler.yaml) |
| Needs-Rebase plugin | [`config/prow/needs-rebase.yaml`](../../../refs/falcosecurity/test-infra/config/prow/needs-rebase.yaml) |
| Config check RBAC | [`config/prow/check-config.yaml`](../../../refs/falcosecurity/test-infra/config/prow/check-config.yaml) |
| ALB Ingress | [`config/prow/alb_ingress.yaml`](../../../refs/falcosecurity/test-infra/config/prow/alb_ingress.yaml) |
| Driver build SA | [`config/prow/build-drivers-serviceaccount.yaml`](../../../refs/falcosecurity/test-infra/config/prow/build-drivers-serviceaccount.yaml) |
| AWS auth RBAC | [`config/prow/aws-auth-config-rbac.yaml`](../../../refs/falcosecurity/test-infra/config/prow/aws-auth-config-rbac.yaml) |
| Cluster Autoscaler | [`config/prow/cluster-autoscaler.yaml`](../../../refs/falcosecurity/test-infra/config/prow/cluster-autoscaler.yaml) |
| EKS cluster config | [`config/clusters/eks.tf`](../../../refs/falcosecurity/test-infra/config/clusters/eks.tf) |
| EKS variables | [`config/clusters/eks_variables.tf`](../../../refs/falcosecurity/test-infra/config/clusters/eks_variables.tf) |
| Terraform variables (auto) | [`config/clusters/prow.auto.tfvars`](../../../refs/falcosecurity/test-infra/config/clusters/prow.auto.tfvars) |
| IAM roles and OIDC | [`config/clusters/iam.tf`](../../../refs/falcosecurity/test-infra/config/clusters/iam.tf) |
| Terraform backend | [`config/clusters/terraform_backend.tf`](../../../refs/falcosecurity/test-infra/config/clusters/terraform_backend.tf) |
| Terraform state resources | [`config/clusters/terraform_state.tf`](../../../refs/falcosecurity/test-infra/config/clusters/terraform_state.tf) |
| VPC config | [`config/clusters/vpc.tf`](../../../refs/falcosecurity/test-infra/config/clusters/vpc.tf) |
| S3 storage | [`config/clusters/storage.tf`](../../../refs/falcosecurity/test-infra/config/clusters/storage.tf) |
| ECR repositories | [`config/clusters/ecr.tf`](../../../refs/falcosecurity/test-infra/config/clusters/ecr.tf) |
| Global config | [`config/clusters/global.tf`](../../../refs/falcosecurity/test-infra/config/clusters/global.tf) |
| DNS certificates | [`config/clusters/kubernetes.tf`](../../../refs/falcosecurity/test-infra/config/clusters/kubernetes.tf), [`config/clusters/monitoring.tf`](../../../refs/falcosecurity/test-infra/config/clusters/monitoring.tf) |
| Pod Identity Webhook | [`config/prow/pod-identity-webhook/`](../../../refs/falcosecurity/test-infra/config/prow/pod-identity-webhook/deployment-base.yaml) |
| ArgoCD: ALB Controller | [`config/applications/alb-controller.yaml`](../../../refs/falcosecurity/test-infra/config/applications/alb-controller.yaml) |
| ArgoCD: cert-manager | [`config/applications/cert-manager.yaml`](../../../refs/falcosecurity/test-infra/config/applications/cert-manager.yaml) |
| ArgoCD: EBS CSI | [`config/applications/ebs-csi-controller.yaml`](../../../refs/falcosecurity/test-infra/config/applications/ebs-csi-controller.yaml) |
| ArgoCD: Falco | [`config/applications/falco.yaml`](../../../refs/falcosecurity/test-infra/config/applications/falco.yaml) |
| ArgoCD: Prometheus | [`config/applications/kube-stack-prometheus.yaml`](../../../refs/falcosecurity/test-infra/config/applications/kube-stack-prometheus.yaml) |
| ArgoCD: Prom CRDs | [`config/applications/prometheus-operator-crds.yaml`](../../../refs/falcosecurity/test-infra/config/applications/prometheus-operator-crds.yaml) |
| build-drivers Dockerfile | [`images/build-drivers/Dockerfile`](../../../refs/falcosecurity/test-infra/images/build-drivers/Dockerfile) |
| docker-dind Dockerfile | [`images/docker-dind/Dockerfile`](../../../refs/falcosecurity/test-infra/images/docker-dind/Dockerfile) |
| Image build script | [`images/build.sh`](../../../refs/falcosecurity/test-infra/images/build.sh) |
| Image publish script | [`images/publish.sh`](../../../refs/falcosecurity/test-infra/images/publish.sh) |
| Deploy script | [`tools/deploy_prow.sh`](../../../refs/falcosecurity/test-infra/tools/deploy_prow.sh) |
| Local test script | [`tools/local_prowjob.sh`](../../../refs/falcosecurity/test-infra/tools/local_prowjob.sh) |
| Job checker tool | [`tools/prow-jobs-checker/main.go`](../../../refs/falcosecurity/test-infra/tools/prow-jobs-checker/main.go) |
| Drivers website tool | [`tools/update-drivers-website/updateDriversWebsite.go`](../../../refs/falcosecurity/test-infra/tools/update-drivers-website/updateDriversWebsite.go) |
| Prow proposal | [`proposals/20200915-prow.md`](../../../refs/falcosecurity/test-infra/proposals/20200915-prow.md) |
| Admins proposal | [`proposals/20200925-admins.md`](../../../refs/falcosecurity/test-infra/proposals/20200925-admins.md) |
