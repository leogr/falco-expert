# Falco Test Infrastructure — Digest Overview

> **Era:** 0.45 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

## Cloud Layout in 0.45

The pinned repository has separate AWS and OCI configuration. AWS retains the merge-policy configuration and its own job catalog. OCI defines a Prow control plane in namespace `prow`, job pods in `test-pods`, and an explicit Kustomize catalog for chart sync, registry updates, maintainers/manifests automation, and driver builds. The configuration is evidence of the intended deployment; it does not by itself verify live cluster health. **Sources:** [AWS plugins and config-updater](../../../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml#L67-L77), [OCI configuration](../../../refs/falcosecurity/test-infra/config/prow/oci/config.yaml), [OCI catalog](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml).

| Area | AWS | OCI |
|------|-----|-----|
| Cluster | [Terraform](../../../refs/falcosecurity/test-infra/config/clusters/aws/README.md) | [Terraform and bootstrap](../../../refs/falcosecurity/test-infra/config/clusters/oci/README.md) |
| Merge policy / triggers | [AWS plugins](../../../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml) | [Trigger-only plugins](../../../refs/falcosecurity/test-infra/config/prow/oci/plugins.yaml) |
| Job catalog | [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12) | [Kustomize catalog](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml) |
| Retained old jobs | [Backup AWS catalog](../../../refs/falcosecurity/test-infra/config/backup/aws/jobs/) | Replacements in the OCI catalog |

The backup catalog is outside the AWS config-updater glob and the OCI Kustomize list. References to backup jobs in the detailed digests describe retained historical implementations. The upstream repository README's claim that OCI has no catalog is stale against the checked-in [OCI catalog](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml). The AWS architecture and values below apply only to AWS. The detailed digests cover both clouds, current job catalogs, the historical backups, and the separate driver publication path.

## Overview

The [falcosecurity/test-infra](https://github.com/falcosecurity/test-infra) repository manages the core infrastructure for the Falco project's CI/CD, GitHub organization, and prebuilt driver distribution. It is a **Stable, Infra-scope** repository maintained by the test-infra-maintainers team.

### Key Systems

| System | Purpose | Dashboard |
|--------|---------|-----------|
| **Prow** | Kubernetes-based CI/CD for all falcosecurity repos | [prow.falco.org](https://prow.falco.org/) |
| **Drivers Build Grid (DBG)** | Pre-compiles Falco drivers for 23,438 committed kernel/distro/arch configs across two driver lines (best-effort builds) | [download.falco.org/driver/site](https://download.falco.org/driver/site/index.html) |
| **Peribolos / Poiana** | Declarative GitHub org management via the Poiana bot | [prow.falco.org/command-help](https://prow.falco.org/command-help) |
| **AWS EKS** | AWS Prow control plane and retained cluster configuration | `falco-prow-test-infra` cluster, `eu-west-1` |
| **OCI OKE** | Separate Prow control plane, automation and DriverKit pools | [OCI cluster](../../../refs/falcosecurity/test-infra/config/clusters/oci/README.md) |

### AWS Architecture

```
GitHub Webhooks → ALB Ingress → Hook (webhook handler)
                                   ↓
                              Prow Plugins (dco, lgtm, approve, size, ...)
                                   ↓
                         Prow Controller Manager → Job Pods (test-pods namespace)
                                   ↓                        ↓
                              Crier (status reporter)   S3 (falco-prow-logs)
                                   ↓
                         Tide (merge automation) → GitHub (rebase merge)

Horologium → Periodic Jobs (lifecycle bot, branchprotector, ...)
```

### AWS Configuration Values

| Fact | Value |
|------|-------|
| AWS Region | `eu-west-1` |
| EKS Cluster | `falco-prow-test-infra` |
| S3 Bucket (logs) | `s3://falco-prow-logs` |
| ECR Registry | `292999226676.dkr.ecr.eu-west-1.amazonaws.com/test-infra/` |
| Prow Image Version | `v20240805-37a08f946` |
| Merge Method | Rebase (all repos) |
| Bot Account | [poiana](https://github.com/poiana) |
| Max Concurrent Jobs | 100 |
| Default Job Timeout | 24h |

---

## Digest Files

| Digest | Description | Size |
|--------|-------------|------|
| [`prow-infrastructure.md`](prow-infrastructure.md) | Prow components, AWS EKS and OCI OKE/Terraform, networking, ArgoCD apps, container images, tools, proposals | ~45KB |
| [`prow-config.md`](prow-config.md) | config.yaml and plugins.yaml reference, Tide merge rules, branch protection, PR lifecycle, config propagation | ~24KB |
| [`prow-jobs.md`](prow-jobs.md) | Complete job catalog (build-drivers, build-plugins, peribolos, lifecycle-bot, etc.), job patterns, config uploader tool | ~43KB |
| [`github-org-management.md`](github-org-management.md) | org.yaml structure, Peribolos sync, Poiana bot, team management, OWNERS file sync, branch protection | ~27KB |
| [`drivers-build-grid.md`](drivers-build-grid.md) | DBG architecture, driverkit config format, 23,438 configs across 2 driver versions, build process, driver distribution | ~23KB |
| **Total** | | **~162KB** |

---

## Related Digests

| Digest | Relationship |
|--------|-------------|
| [driverkit.md](../driverkit.md) | CLI tool used by DBG to compile kernel modules |
| [dbg-go.md](../dbg-go.md) | Orchestration tool that generates driverkit configs and publishes drivers |
| [kernel-crawler.md](../kernel-crawler.md) | Kernel version discovery tool feeding the DBG pipeline |
| [evolution.md](../evolution.md) | Governance model, maintainers registry, repository lifecycle |
| [charts.md](../charts.md) | Helm charts updated by the update-falco-k8s-manifests job |
| [rules.md](../rules.md) | Detection rules updated by the update-rules-index job |
| [pigeon.md](../pigeon.md) | Secrets/variables management for GitHub Actions infrastructure |

---

## Sources

| Topic | Source File |
|-------|-------------|
| Repository overview | [README.md](../../../refs/falcosecurity/test-infra/README.md) |
| Main Prow config | [config/prow/aws/config.yaml](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml) |
| Plugin config | [config/prow/aws/plugins.yaml](../../../refs/falcosecurity/test-infra/config/prow/aws/plugins.yaml) |
| Org config | [config/org.yaml](../../../refs/falcosecurity/test-infra/config/org.yaml) |
| Prow proposal | [proposals/20200915-prow.md](../../../refs/falcosecurity/test-infra/proposals/20200915-prow.md) |
| Admins proposal | [proposals/20200925-admins.md](../../../refs/falcosecurity/test-infra/proposals/20200925-admins.md) |
| OWNERS | [OWNERS](../../../refs/falcosecurity/test-infra/OWNERS) |
| DBG documentation | [driverkit/README.md](../../../refs/falcosecurity/test-infra/driverkit/README.md) |
| Job creation guide | [AWS job guide:5-12](../../../refs/falcosecurity/test-infra/config/jobs/aws/README.md#L5-L12) |
| Local testing guide | [docs/local-testing.md](../../../refs/falcosecurity/test-infra/docs/local-testing.md) |
| GitHub org management | [docs/github-org-management.md](../../../refs/falcosecurity/test-infra/docs/github-org-management.md) |
| Cluster update guide | [docs/update-cluster.md](../../../refs/falcosecurity/test-infra/docs/update-cluster.md) |

---

*Last updated: 2026-09-22*
