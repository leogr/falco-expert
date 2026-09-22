# Falco Test Infrastructure — GitHub Organization Management

> **Era:** 0.45 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

This digest documents how the `falcosecurity` GitHub organization is managed declaratively through configuration files and automated Prow jobs in the [test-infra](https://github.com/falcosecurity/test-infra) repository. The central configuration file is [`config/org.yaml`](../../../refs/falcosecurity/test-infra/config/org.yaml), which defines organization settings, membership, teams, and repository configurations. AWS Peribolos applies this configuration to GitHub. OCI separately refreshes evolution maintainer documentation; the former OWNERS-to-team fan-out is absent from the active job catalogs.

For the broader governance model that informs these organizational structures, see [evolution.md](../evolution.md).

---

## Table of Contents

- [Organization Configuration (org.yaml)](#organization-configuration-orgyaml)
  - [Organization-Level Settings](#organization-level-settings)
  - [Organization Admins](#organization-admins)
  - [Organization Members](#organization-members)
  - [Team Structure](#team-structure)
  - [Poiana Bot and machine_users](#poiana-bot-and-machine_users)
  - [Repository Configurations](#repository-configurations)
- [Peribolos — Organization Sync](#peribolos--organization-sync)
- [update-github-teams — Per-Repo Team Sync](#update-github-teams----per-repo-team-sync-consolidated)
- [update-maintainers — Maintainers List Sync](#update-maintainers--maintainers-list-sync)
- [Branch Protection](#branch-protection)
- [OWNERS Files](#owners-files)
- [Governance Relationship](#governance-relationship)
- [Sources](#sources)

---

## Organization Configuration (org.yaml)

The entire `falcosecurity` GitHub organization is declaratively defined in a single YAML file: [`config/org.yaml`](../../../refs/falcosecurity/test-infra/config/org.yaml). This file is the source of truth for organization settings, membership, teams, and repository configurations.

**Source:** [`config/org.yaml`](../../../refs/falcosecurity/test-infra/config/org.yaml)

### Organization-Level Settings

The organization is named **"Falco"** with the description *"Falco is Container Native Runtime Security"* ([org.yaml:1-4](../../../refs/falcosecurity/test-infra/config/org.yaml#L1-L4)).

| Setting | Value | Description |
|---------|-------|-------------|
| `default_repository_permission` | `read` | External collaborators and non-team members get read-only access by default |
| `has_organization_projects` | `true` | Organization-level project boards are enabled |
| `has_repository_projects` | `true` | Repository-level project boards are enabled |
| `members_can_create_repositories` | `false` | Only admins can create new repositories |

**Source:** [`config/org.yaml:6-9`](../../../refs/falcosecurity/test-infra/config/org.yaml#L6-L9)

### Organization Admins

The pinned organization config lists **10 admins**: `caniszczyk`, `ldegio`, `leogr`, `mstemm`, `poiana`, `thelinuxfoundation`, `jasondellaluce`, `LucaGuerra`, `FedeDP`, `ekoops`.

### Organization Members

It lists **44 members** in addition to admins: `admiral0`, `ahmedameenaim`, `alacuku`, `andreaterzolo`, `araujof`, `bencer`, `c2ndev`, `cpanato`, `cappellinsamuele`, `darryk10`, `deepskyblue86`, `dwindsor`, `ewilderj`, `EXONER4TED`, `fjogeleit`, `geraldcombs`, `gnosek`, `hbrueckner`, `hmadison`, `IgorEulalio`, `incertum`, `irozzo-1A`, `Issif`, `jonahjon`, `Kaizhe`, `krisnova`, `leodido`, `loresuso`, `Lowaiz`, `maxgio92`, `mfdii`, `mmat11`, `mrgian`, `Molter73`, `rabbitstack`, `rohith-raju`, `sboschman`, `scraly`, `sgaist`, `terror96`, `terylt`, `therealbobo`, `vjjmiras`, `zuc`. Default repository permission is read; write access comes from explicit roles/team grants.

**Source:** [config/org.yaml](../../../refs/falcosecurity/test-infra/config/org.yaml#L6).

### Team Structure

Teams are defined under the `teams:` section of `org.yaml` ([org.yaml:457-1055](../../../refs/falcosecurity/test-infra/config/org.yaml#L457-L1055)). The team structure follows a clear pattern.

#### admins

The `admins` team contains the organization administrators. Its maintainers are: `caniszczyk`, `ldegio`, `leogr`, `thelinuxfoundation`, `mstemm`. This team has admin access to the `advocacy` repository ([org.yaml:458-468](../../../refs/falcosecurity/test-infra/config/org.yaml#L458-L468)).

#### core-maintainers

The `core-maintainers` team represents the **Core maintainers of The Falco Project** ([org.yaml:538-560](../../../refs/falcosecurity/test-infra/config/org.yaml#L538-L560)). This team does not have direct repository access configured in org.yaml but represents the project-wide governance role.

**Maintainers (team role):** `leogr`, `mstemm`

**Members:** `gnosek`, `cpanato`, `Issif`, `FedeDP`, `zuc`, `jasondellaluce`, `Molter73`, `LucaGuerra`, `alacuku`, `loresuso`, `sgaist`, `ekoops`, `deepskyblue86`, `geraldcombs`, `irozzo-1A`, `c2ndev`.

This totals 18 configured core-maintainer team participants. The governance model is described in [the evolution digest](../evolution.md).

**Source:** [config/org.yaml](../../../refs/falcosecurity/test-infra/config/org.yaml#L538).

#### Per-Repository Maintainer Teams

Each repository has a dedicated `<repo>-maintainers` team following a consistent pattern. Each team:

- Has a description: `"maintainers of falcosecurity/<repo>"`
- Lists `maintainers` (GitHub team role -- can manage team membership) and `members`
- Grants `maintain` permission on the corresponding repository
- Uses `privacy: closed` (visible to organization members)

Examples of this pattern:

| Team | Maintainers (team role) | Members | Repository |
|------|------------------------|---------|------------|
| `falco-maintainers` | `leogr`, `mstemm` | `FedeDP`, `jasondellaluce`, `LucaGuerra`, `sgaist`, `ekoops`, `irozzo-1A`, `c2ndev` | `falco: maintain` |
| `libs-maintainers` | `leogr`, `mstemm`, `jasondellaluce` | `gnosek`, `FedeDP`, `Molter73`, `LucaGuerra`, `hbrueckner`, `ekoops`, `geraldcombs`, `irozzo-1A`, `deepskyblue86`, `terror96`, `therealbobo` | `libs: maintain` |
| `rules-maintainers` | `leogr`, `LucaGuerra` | `fededp`, `jasondellaluce`, `mstemm`, `darryk10`, `ekoops` | `rules: maintain` |
| `charts-maintainers` | `leogr` | `cpanato`, `Issif`, `alacuku`, `ekoops`, `c2ndev` | `charts: maintain` |
| `test-infra-maintainers` | `leogr` | `maxgio92`, `zuc`, `jonahjon`, `fededp`, `ekoops`, `LucaGuerra`, `alacuku`, `c2ndev` | `test-infra: maintain` |

**Source:** [`config/org.yaml:457-1055`](../../../refs/falcosecurity/test-infra/config/org.yaml#L457-L1055)

There are approximately 40+ per-repository maintainer teams defined in org.yaml, one for each active (and some archived) repository.

### Poiana Bot and machine_users

**Poiana** (`poiana`) is the project's automation bot -- a machine user that performs automated tasks across the organization. Poiana is listed as an organization **admin** ([org.yaml:16](../../../refs/falcosecurity/test-infra/config/org.yaml#L16)) and is the sole maintainer of the `machine_users` team ([org.yaml:873-917](../../../refs/falcosecurity/test-infra/config/org.yaml#L873-L917)).

The `machine_users` team has **admin** access to nearly every active repository in the organization. This broad access enables Poiana to:

- Push branches and create pull requests (used by update-maintainers and peribolos-syncer jobs)
- Manage branch protection settings (used by branchprotector)
- Perform organizational sync operations (used by Peribolos)
- Sign commits with its GPG key (`51138685+poiana@users.noreply.github.com`)

The `machine_users` team has admin access configured for 39 repositories: `.github`, `charts`, `client-go`, `cncf-green-review-testing`, `community`, `contrib`, `dbg-go`, `deploy-kubernetes`, `driverkit`, `elftoolchain`, `event-generator`, `evolution`, `falco`, `falco-actions`, `falco-aws-terraform`, `falco-exporter`, `falco-playground`, `falco-rustlings`, `falco-talon`, `falco-website`, `falcoctl`, `falcosidekick`, `falcosidekick-ui`, `flycheck-falco-rules`, `k8s-metacollector`, `kernel-crawler`, `kernel-testing`, `libs`, `libs-sdk-go`, `peribolos-syncer`, `pigeon`, `plugin-sdk-cpp`, `plugin-sdk-go`, `plugin-sdk-rs`, `plugins`, `rules`, `syscalls-bumper`, `test-infra`, `testing`.

**Source:** [config/org.yaml](../../../refs/falcosecurity/test-infra/config/org.yaml#L873).

### Repository Configurations

The `repos:` section of org.yaml ([org.yaml:69-456](../../../refs/falcosecurity/test-infra/config/org.yaml#L69-L456)) defines settings for every repository in the organization. Common settings across repositories include:

| Setting | Typical Value | Description |
|---------|---------------|-------------|
| `allow_merge_commit` | `false` | Merge commits are disabled across all repos |
| `allow_rebase_merge` | `true` | Rebase merge is the standard merge strategy |
| `allow_squash_merge` | `false` | Squash merge is disabled across all repos |
| `has_projects` | `true` (most) | GitHub Projects enabled |
| `has_wiki` | `false` (most) | GitHub Wiki disabled |
| `default_branch` | `main` or `master` | Varies by repository age |

Several repositories are marked as `archived: true`, including: `advocacy`, `client-py`, `client-rs`, `ebpf-probe`, `falco-exporter`, `kernel-module`, `kilt`, `libscap`, `libsinsp`, `pdig`, `template-repository`.

Repositories with explicit `default_branch: main` include: `.github`, `cncf-green-review-testing`, `community`, `contrib`, `deploy-kubernetes`, `evolution`, `falco-actions`, `falco-aws-terraform`, `falco-operator`, `falco-playground`, `falco-rustlings`, `falco-talon`, `flycheck-falco-rules`, `k8s-metacollector`, `kernel-crawler`, `kernel-testing`, `libs-sdk-go`, `peribolos-syncer`, `pigeon`, `plugin-sdk-go`, `plugin-sdk-rs`, `syscalls-bumper`, `testing`.

Repositories without an explicit `default_branch` setting (not establishing a default branch through this field) include older repos like `falco`, `libs`, `charts`, `driverkit`, `falcoctl`, and others.

---

## Peribolos -- Organization Sync

[Peribolos](https://github.com/kubernetes/test-infra/blob/master/prow/cmd/peribolos/README.md) is a Kubernetes project tool that synchronizes GitHub organization configuration from a YAML file. The Falco project uses Peribolos to apply the declarative configuration in `org.yaml` to the live GitHub organization.

**Source:** [`config/jobs/aws/peribolos/peribolos.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml), [`docs/github-org-management.md`](../../../refs/falcosecurity/test-infra/docs/github-org-management.md)

### What Peribolos Manages

Peribolos synchronizes the following aspects ([docs/github-org-management.md:3-7](../../../refs/falcosecurity/test-infra/docs/github-org-management.md#L3-L7)):

- Organization membership and org-wide rights
- Organization settings
- Teams and team members
- Repos and team repo rights

### Peribolos Flags

The Peribolos job uses these flags to control what it manages ([peribolos.yaml:14-21](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml#L14-L21)):

- `--fix-org` -- sync organization settings
- `--fix-org-members` -- sync organization membership
- `--fix-repos` -- sync repository settings
- `--fix-teams` -- sync team definitions
- `--fix-team-members` -- sync team memberships
- `--fix-team-repos` -- sync team repository permissions
- `--allow-repo-archival` -- allow archiving repositories (pre-submit only)
- `--config-path=config/org.yaml` -- path to the configuration file

### When Peribolos Runs

There are three Prow job types for Peribolos ([peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml)):

| Job Type | Name | Trigger | Mode |
|----------|------|---------|------|
| **Pre-submit** | `peribolos-pre-submit` | On PRs to `master` that change `config/org.yaml` or `config/jobs/aws/peribolos/*` | Dry-run (no `--confirm` flag) |
| **Post-submit** | `peribolos-post-submit` | After merge to `master` when `config/org.yaml` or `config/jobs/aws/peribolos/*` change | Live (`--confirm` flag) |
| **Periodic** | `peribolos-periodic` | Every 24 hours | Live (`--confirm` flag) |

The pre-submit job runs without `--confirm`, acting as a validation/dry-run to catch errors before merge. The post-submit and periodic jobs include `--confirm` to actually apply changes to GitHub.

The image used is `gcr.io/k8s-prow/peribolos:v20240805-37a08f946` ([peribolos.yaml:12](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml#L12)).

### How to Add a New Member

Per the documentation ([docs/github-org-management.md:16-37](../../../refs/falcosecurity/test-infra/docs/github-org-management.md#L16-L37)), adding a new organization member requires:

1. Adding the GitHub username to the `members` array in `org.yaml`
2. Adding the username to the `members` array of each relevant per-repository team
3. Submitting a PR to test-infra; Peribolos validates on pre-submit and applies on merge

---

## update-github-teams -- Per-Repo Team Sync (Consolidated)

The previous fan-out of per-repository `peribolos-syncer` postsubmits is absent from the active AWS and OCI catalogs. It historically read root OWNERS approvers, proposed team edits to the organization YAML, and let Peribolos apply them. The current Peribolos job applies that YAML; it does not regenerate it from OWNERS. The maintainer-list job generates evolution documentation from GitHub data. These are separate directions of synchronization, so an OWNERS edit alone does not establish an automatic team update in this snapshot.

**Sources:** [config/jobs/aws/peribolos/peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml#L1), [config/jobs/oci/kustomization.yaml](../../../refs/falcosecurity/test-infra/config/jobs/oci/kustomization.yaml#L1), [images/update-maintainers/entrypoint.sh](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh#L35). Use the `0.44.x` snapshot for the historical fan-out.

## update-maintainers -- Maintainers List Sync

The `update-maintainers` job generates and updates the `maintainers.yaml` file in the [`falcosecurity/evolution`](https://github.com/falcosecurity/evolution) repository by querying GitHub for organization-wide contributor data.

**Source:** [`config/jobs/oci/automation/maintainers.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml), [`images/update-maintainers/entrypoint.sh`](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh), [`images/update-maintainers/Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-maintainers/Dockerfile)

### Schedule

The job runs as a Prow **periodic** on a cron schedule: `"0 9 * * *"` (daily at 09:00 UTC) ([update-maintainers.yaml:3](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml#L3)).

### How It Works

The job checks out the `falcosecurity/evolution` repository (branch: `main`) as the working directory ([update-maintainers.yaml:8-11](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml#L8-L11)) and runs the [`entrypoint.sh`](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh) script, which:

1. **Generates maintainers data** using `maintainers-generator` ([entrypoint.sh:40-47](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh#L40-L47)): Queries the GitHub API for the `falcosecurity` organization and produces a `maintainers.yaml` file. It uses `people/affiliations.json` from the evolution repo as a persons database for name/company mapping.

2. **Updates evolution resource files** by running `make` ([entrypoint.sh:51-53](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh#L51-L53)): This regenerates files like `README.md` and `MAINTAINERS.md` in the evolution repository.

3. **Creates a pull request** if changes are detected ([entrypoint.sh:83-114](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh#L83-L114)): Uses the `pr-creator` tool to push a branch (`update-evolution-files`) and open a PR to the evolution repository with the title *"update: maintainers list and evolution resources"*.

### Container Image

The Docker image ([Dockerfile](../../../refs/falcosecurity/test-infra/images/update-maintainers/Dockerfile)) is built in multiple stages:

1. Builds `pr-creator` from the Kubernetes test-infra repository
2. Downloads `maintainers-generator` from [leodido/maintainers-generator](https://github.com/leodido/maintainers-generator) releases
3. Packages both tools with the entrypoint script

### Bot Configuration

All operations are performed as the `poiana` bot with GPG-signed commits ([entrypoint.sh:24-27](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh#L24-L27)):
- **Name:** `poiana`
- **Email:** `51138685+poiana@users.noreply.github.com`
- **GPG Key ID:** `EC9875C7B990D55F3B44D6E45F284448FF941C8F`

---

## Branch Protection

The `branchprotector` Prow job applies GitHub branch protection rules declaratively from the Prow configuration.

**Source:** [`config/jobs/aws/branchprotector/branchprotector.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/aws/branchprotector/branchprotector.yaml), [`config/prow/aws/config.yaml`](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml)

### When It Runs

| Job Type | Name | Trigger |
|----------|------|---------|
| **Post-submit** | `branchprotector-post-submit` | After merge to `master` when `config/prow/aws/config.yaml` changes |
| **Periodic** | `branchprotector-hourly` | Every hour (cron: `"55 * * * *"`) |

**Source:** [`branchprotector.yaml:1-64`](../../../refs/falcosecurity/test-infra/config/jobs/aws/branchprotector/branchprotector.yaml#L1-L64)

Both jobs use the `gcr.io/k8s-prow/branchprotector:v20240805-37a08f946` image and read from `config/prow/aws/config.yaml` and the AWS job directory.

### Branch Protection Configuration

The branch protection rules are defined in the `branch-protection:` section of [`config/prow/aws/config.yaml`](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml). Key global defaults ([config.yaml:52-65](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L52-L65)):

| Setting | Value | Description |
|---------|-------|-------------|
| `enforce_admins` | `true` | Protection rules apply to admins too |
| `restrictions.teams` | `["maintainers", "machine_users"]` | Only these teams can push to protected branches |
| `dismiss_stale_reviews` | `true` | Old reviews are automatically dismissed on new pushes |
| `require_code_owner_reviews` | `true` | At least one code owner must approve |
| `required_approving_review_count` | `1` | Minimum one approving review required |
| `strict` (status checks) | `false` | PRs do not need to be up-to-date with base branch (rebase merge strategy makes this unnecessary) |

At the organization level, all `falcosecurity` repositories require the `dco` status check (Developer Certificate of Origin) ([config.yaml:67-71](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L67-L71)).

Individual repositories can add additional required status checks. For example, `charts` requires `test`, `readme`, `linkChecker`, and `go-unit-tests` ([config.yaml:82-87](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml#L82-L87)).

Each repository specifies which branches are protected (typically `main` or `master` with `protect: true`).

---

## OWNERS Files

OWNERS files are a Prow convention that defines who can approve and review pull requests in a directory and its subdirectories. The Falco project uses OWNERS files throughout its repositories.

### Root OWNERS (test-infra)

**Source:** [`OWNERS`](../../../refs/falcosecurity/test-infra/OWNERS)

```yaml
approvers:
  - maxgio92
  - jonahjon
  - leogr
  - zuc
  - fededp
  - LucaGuerra
  - alacuku
  - ekoops
  - c2ndev
emeritus_approvers:
  - leodido
  - fntlnz
```

The root OWNERS file defines who can approve changes to the entire test-infra repository. The approvers match the configured `test-infra-maintainers` team participants at this pin. `emeritus_approvers` lists past approvers who are no longer active.

### Configuration ownership

The former nested OWNERS files for Prow and jobs were removed in the 0.45 source snapshot. Configuration changes inherit the repository's [root OWNERS](../../../refs/falcosecurity/test-infra/OWNERS), which includes `c2ndev`; do not apply the old nested specialist lists as current policy.

### How OWNERS Relates to Prow

OWNERS files integrate with Prow's `approve` and `lgtm` plugins:

- **`/approve`**: Only users listed as `approvers` (in the relevant OWNERS file for changed paths) can issue the `/approve` command
- **`/lgtm`**: Users listed as `reviewers` or `approvers` can issue `/lgtm`
- **Inheritance**: OWNERS files are hierarchical -- a parent directory's OWNERS applies to all subdirectories unless overridden
- **`emeritus_approvers`**: Former approvers who are acknowledged but no longer have active approval rights

### OWNERS and Team Sync

OWNERS governs Prow path approval. GitHub maintainer-team membership is separately configured in the organization YAML and applied by Peribolos. The former OWNERS-to-team jobs are not in the current catalogs; verify both sources when changing maintainer membership.

**Sources:** [OWNERS](../../../refs/falcosecurity/test-infra/OWNERS#L1), [config/org.yaml](../../../refs/falcosecurity/test-infra/config/org.yaml#L1030), [config/jobs/aws/peribolos/peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml#L1).

## Governance Relationship

The organizational structure defined in `org.yaml` implements the governance model described in the [evolution repository](../evolution.md). Key relationships:

- The **core-maintainers** team in org.yaml corresponds to the maintainers listed in [`evolution/maintainers.yaml`](../../../refs/falcosecurity/evolution/maintainers.yaml)
- Per-repository maintainer teams reflect the per-repository OWNERS files, which are themselves governed by the evolution process
- The **update-maintainers** job keeps the evolution repository's `maintainers.yaml` in sync with actual GitHub organization data
- Organization admins include CNCF/LF representatives (`caniszczyk`, `thelinuxfoundation`) reflecting Falco's status as a CNCF graduated project

For the complete governance model, roles, and processes, see [evolution.md](../evolution.md).

---

## Sources

| Topic | Source File |
|-------|-------------|
| Organization config | [`config/org.yaml`](../../../refs/falcosecurity/test-infra/config/org.yaml) |
| GitHub org management docs | [`docs/github-org-management.md`](../../../refs/falcosecurity/test-infra/docs/github-org-management.md) |
| Peribolos job | [`config/jobs/aws/peribolos/peribolos.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/aws/peribolos/peribolos.yaml) |
| Update-maintainers job | [`config/jobs/oci/automation/maintainers.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/oci/automation/maintainers.yaml) |
| Update-maintainers script | [`images/update-maintainers/entrypoint.sh`](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh) |
| Update-maintainers Dockerfile | [`images/update-maintainers/Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-maintainers/Dockerfile) |
| Branch protector job | [`config/jobs/aws/branchprotector/branchprotector.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/aws/branchprotector/branchprotector.yaml) |
| Branch protection config | [`config/prow/aws/config.yaml`](../../../refs/falcosecurity/test-infra/config/prow/aws/config.yaml) |
| Root OWNERS | [`OWNERS`](../../../refs/falcosecurity/test-infra/OWNERS) |
| Governance model | [evolution.md](../evolution.md) |
