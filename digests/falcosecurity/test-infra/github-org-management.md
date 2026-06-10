# Falco Test Infrastructure — GitHub Organization Management

> **Era:** 0.44 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

This digest documents how the `falcosecurity` GitHub organization is managed declaratively through configuration files and automated Prow jobs in the [test-infra](https://github.com/falcosecurity/test-infra) repository. The central configuration file is [`config/org.yaml`](../../../refs/falcosecurity/test-infra/config/org.yaml), which defines organization settings, membership, teams, and repository configurations. Several Prow jobs synchronize this configuration to GitHub and keep team memberships aligned with per-repository OWNERS files.

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

The organization is named **"Falco"** with the description *"Falco is Container Native Runtime Security"* ([org.yaml:1-4](../../../refs/falcosecurity/test-infra/config/org.yaml)).

| Setting | Value | Description |
|---------|-------|-------------|
| `default_repository_permission` | `read` | External collaborators and non-team members get read-only access by default |
| `has_organization_projects` | `true` | Organization-level project boards are enabled |
| `has_repository_projects` | `true` | Repository-level project boards are enabled |
| `members_can_create_repositories` | `false` | Only admins can create new repositories |

**Source:** [`config/org.yaml:6-9`](../../../refs/falcosecurity/test-infra/config/org.yaml)

### Organization Admins

Organization admins have full administrative access to the GitHub organization. The following users are listed as admins ([org.yaml:11-20](../../../refs/falcosecurity/test-infra/config/org.yaml)):

| GitHub Handle | Notes |
|---------------|-------|
| `caniszczyk` | CNCF representative |
| `ldegio` | Falco co-creator (Loris Degioanni) |
| `leogr` | Core maintainer (Leonardo Grasso) |
| `mstemm` | Core maintainer (Mark Stemm) |
| `poiana` | Automation bot (machine user) |
| `thelinuxfoundation` | Linux Foundation account |
| `jasondellaluce` | Core maintainer (Jason Dellaluce) |
| `LucaGuerra` | Core maintainer (Luca Guerra) |
| `FedeDP` | Core maintainer (Federico Di Pierro) |

### Organization Members

In addition to admins, the organization has 44 members ([org.yaml:22-66](../../../refs/falcosecurity/test-infra/config/org.yaml)). These include active and past contributors across various repositories. Notable members include:

- `admiral0`, `ahmedameenaim`, `alacuku`, `Andreagit97`, `araujof`, `bencer`, `cpanato`, `cappellinsamuele`, `darryk10`, `deepskyblue86`, `dwindsor`, `ekoops`, `ewilderj`, `EXONER4TED`, `fjogeleit`, `geraldcombs`, `gnosek`, `hbrueckner`, `hmadison`, `IgorEulalio`, `incertum`, `irozzo-1A`, `Issif`, `jonahjon`, `Kaizhe`, `krisnova`, `leodido`, `loresuso`, `Lowaiz`, `maxgio92`, `mfdii`, `mmat11`, `mrgian`, `Molter73`, `rabbitstack`, `rohith-raju`, `sboschman`, `scraly`, `sgaist`, `terror96`, `terylt`, `therealbobo`, `vjjmiras`, `zuc`

Members do not have inherent write access to repositories. Repository access is managed through team memberships.

### Team Structure

Teams are defined under the `teams:` section of `org.yaml` ([org.yaml:439-1015](../../../refs/falcosecurity/test-infra/config/org.yaml)). The team structure follows a clear pattern.

#### admins

The `admins` team contains the organization administrators. Its maintainers are: `caniszczyk`, `ldegio`, `leogr`, `thelinuxfoundation`, `mstemm`. This team has admin access to the `advocacy` repository ([org.yaml:440-450](../../../refs/falcosecurity/test-infra/config/org.yaml)).

#### core-maintainers

The `core-maintainers` team represents the **Core maintainers of The Falco Project** ([org.yaml:520-543](../../../refs/falcosecurity/test-infra/config/org.yaml)). This team does not have direct repository access configured in org.yaml but represents the project-wide governance role.

**Maintainers (team role):** `leogr`, `mstemm`

**Members:**
`gnosek`, `cpanato`, `Issif`, `FedeDP`, `maxgio92`, `zuc`, `jasondellaluce`, `Molter73`, `LucaGuerra`, `Andreagit97`, `alacuku`, `loresuso`, `sgaist`, `ekoops`, `deepskyblue86`, `geraldcombs`, `irozzo-1A`

This totals 19 core maintainers. The core-maintainers team is the governance body described in the [evolution governance model](../evolution.md).

#### Per-Repository Maintainer Teams

Each repository has a dedicated `<repo>-maintainers` team following a consistent pattern. Each team:

- Has a description: `"maintainers of falcosecurity/<repo>"`
- Lists `maintainers` (GitHub team role -- can manage team membership) and `members`
- Grants `maintain` permission on the corresponding repository
- Uses `privacy: closed` (visible to organization members)

Examples of this pattern:

| Team | Maintainers (team role) | Members | Repository |
|------|------------------------|---------|------------|
| `falco-maintainers` | `leogr`, `mstemm` | `FedeDP`, `jasondellaluce`, `Andreagit97`, `LucaGuerra`, `sgaist`, `ekoops`, `irozzo-1A` | `falco: maintain` |
| `libs-maintainers` | `leogr`, `mstemm`, `jasondellaluce` | `gnosek`, `FedeDP`, `Molter73`, `LucaGuerra`, `Andreagit97`, `hbrueckner`, `ekoops`, `geraldcombs`, `irozzo-1A`, `deepskyblue86`, `terror96` | `libs: maintain` |
| `rules-maintainers` | `leogr`, `LucaGuerra` | `fededp`, `jasondellaluce`, `andreagit97`, `mstemm`, `darryk10`, `ekoops` | `rules: maintain` |
| `charts-maintainers` | `leogr` | `cpanato`, `Issif`, `alacuku`, `ekoops` | `charts: maintain` |
| `test-infra-maintainers` | `leogr` | `maxgio92`, `zuc`, `jonahjon`, `fededp`, `ekoops` | `test-infra: maintain` |

**Source:** [`config/org.yaml:439-1015`](../../../refs/falcosecurity/test-infra/config/org.yaml)

There are approximately 40+ per-repository maintainer teams defined in org.yaml, one for each active (and some archived) repository.

### Poiana Bot and machine_users

**Poiana** (`poiana`) is the project's automation bot -- a machine user that performs automated tasks across the organization. Poiana is listed as an organization **admin** ([org.yaml:16](../../../refs/falcosecurity/test-infra/config/org.yaml)) and is the sole maintainer of the `machine_users` team ([org.yaml:845-889](../../../refs/falcosecurity/test-infra/config/org.yaml)).

The `machine_users` team has **admin** access to nearly every active repository in the organization. This broad access enables Poiana to:

- Push branches and create pull requests (used by update-maintainers and peribolos-syncer jobs)
- Manage branch protection settings (used by branchprotector)
- Perform organizational sync operations (used by Peribolos)
- Sign commits with its GPG key (`51138685+poiana@users.noreply.github.com`)

Repositories with Poiana admin access include ([org.yaml:851-889](../../../refs/falcosecurity/test-infra/config/org.yaml)):

`.github`, `charts`, `client-go`, `cncf-green-review-testing`, `community`, `contrib`, `dbg-go`, `deploy-kubernetes`, `driverkit`, `elftoolchain`, `event-generator`, `evolution`, `falco`, `falco-actions`, `falco-aws-terraform`, `falco-exporter`, `falco-playground`, `falco-rustlings`, `falco-talon`, `falco-website`, `falcoctl`, `falcosidekick`, `falcosidekick-ui`, `flycheck-falco-rules`, `k8s-metacollector`, `kernel-crawler`, `kernel-testing`, `libs`, `libs-sdk-go`, `peribolos-syncer`, `pigeon`, `plugin-sdk-cpp`, `plugin-sdk-go`, `plugin-sdk-rs`, `plugins`, `rules`, `syscalls-bumper`, `test-infra`, `testing`

That is 38 repositories with admin-level bot access.

### Repository Configurations

The `repos:` section of org.yaml ([org.yaml:68-437](../../../refs/falcosecurity/test-infra/config/org.yaml)) defines settings for every repository in the organization. Common settings across repositories include:

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

Repositories without an explicit `default_branch` setting (defaulting to `master`) include older repos like `falco`, `libs`, `charts`, `driverkit`, `falcoctl`, and others.

---

## Peribolos -- Organization Sync

[Peribolos](https://github.com/kubernetes/test-infra/blob/master/prow/cmd/peribolos/README.md) is a Kubernetes project tool that synchronizes GitHub organization configuration from a YAML file. The Falco project uses Peribolos to apply the declarative configuration in `org.yaml` to the live GitHub organization.

**Source:** [`config/jobs/peribolos/peribolos.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml), [`docs/github-org-management.md`](../../../refs/falcosecurity/test-infra/docs/github-org-management.md)

### What Peribolos Manages

Peribolos synchronizes the following aspects ([docs/github-org-management.md:3-7](../../../refs/falcosecurity/test-infra/docs/github-org-management.md)):

- Organization membership and org-wide rights
- Organization settings
- Teams and team members
- Repos and team repo rights

### Peribolos Flags

The Peribolos job uses these flags to control what it manages ([peribolos.yaml:14-21](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml)):

- `--fix-org` -- sync organization settings
- `--fix-org-members` -- sync organization membership
- `--fix-repos` -- sync repository settings
- `--fix-teams` -- sync team definitions
- `--fix-team-members` -- sync team memberships
- `--fix-team-repos` -- sync team repository permissions
- `--allow-repo-archival` -- allow archiving repositories (pre-submit only)
- `--config-path=config/org.yaml` -- path to the configuration file

### When Peribolos Runs

There are three Prow job types for Peribolos ([peribolos.yaml](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml)):

| Job Type | Name | Trigger | Mode |
|----------|------|---------|------|
| **Pre-submit** | `peribolos-pre-submit` | On PRs to `master` that change `config/org.yaml` or `config/jobs/peribolos/*` | Dry-run (no `--confirm` flag) |
| **Post-submit** | `peribolos-post-submit` | After merge to `master` when `config/org.yaml` or `config/jobs/peribolos/*` change | Live (`--confirm` flag) |
| **Periodic** | `peribolos-periodic` | Every 24 hours | Live (`--confirm` flag) |

The pre-submit job runs without `--confirm`, acting as a validation/dry-run to catch errors before merge. The post-submit and periodic jobs include `--confirm` to actually apply changes to GitHub.

The image used is `gcr.io/k8s-prow/peribolos:v20240805-37a08f946` ([peribolos.yaml:12](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml)).

### How to Add a New Member

Per the documentation ([docs/github-org-management.md:16-37](../../../refs/falcosecurity/test-infra/docs/github-org-management.md)), adding a new organization member requires:

1. Adding the GitHub username to the `members` array in `org.yaml`
2. Adding the username to the `members` array of each relevant per-repository team
3. Submitting a PR to test-infra; Peribolos validates on pre-submit and applies on merge

---

## update-github-teams -- Per-Repo Team Sync (Consolidated)

> Note: Historically the falcosecurity org maintained a fan-out of 33 individual `peribolos-syncer-<repo>.yaml` Prow jobs under `config/jobs/update-github-teams/` (one per repository), each invoking the [`peribolos-syncer`](https://github.com/falcosecurity/peribolos-syncer) tool to sync per-repository maintainer teams in `org.yaml` from each repo's `OWNERS` file. In the current era, those per-repo job files have been consolidated and the single [`config/jobs/peribolos/peribolos.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) job, together with the [`update-maintainers`](#update-maintainers----maintainers-list-sync) job, handles org-wide team synchronization.

**Source:** [`config/jobs/peribolos/peribolos.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml)

### Historical Pattern (per-repo peribolos-syncer jobs)

The previous per-repo jobs all followed the same template. As an example, the historical `peribolos-syncer-falco.yaml` looked like:

```yaml
postsubmits:
  falcosecurity/falco:
  - name: peribolos-syncer-falco-post
    branches:
    - ^master$
    run_if_changed: 'OWNERS$'
    spec:
      containers:
      - image: ghcr.io/falcosecurity/peribolos-syncer:0.2.2
        args:
        - sync
        - github
        - --org=falcosecurity
        - --team=falco-maintainers
        - --peribolos-config-path=config/org.yaml
        - --peribolos-config-repository=test-infra
        - --owners-repository=falco
        - --owners-git-ref=master
        - --approvers-only=true
        - --git-author-name=poiana
```

### How It Worked

1. **Trigger**: Each job ran as a `postsubmit` when an `OWNERS` file changed in the target repository's default branch
2. **Action**: The `peribolos-syncer` tool read the `OWNERS` file from the target repository and extracted the `approvers` list (due to `--approvers-only=true`)
3. **Sync**: It updated the corresponding team (e.g., `falco-maintainers`) in `org.yaml` within test-infra, creating a PR authored by the `poiana` bot
4. **Result**: When the test-infra PR merged, Peribolos picked up the updated `org.yaml` and applied the team membership change to GitHub

This created a **two-step synchronization chain**: OWNERS file change in repo -> peribolos-syncer creates PR to test-infra -> Peribolos applies to GitHub.

### Key Parameters Per Repository

Each historical job file varied only in:
- The target repository and branch (`--owners-repository`, `--owners-git-ref`)
- The target team name (`--team`)
- The postsubmit trigger branch

Some repositories used `^main$` as the branch pattern while others used `^master$`, matching each repository's default branch. All jobs committed as `poiana` with GPG-signed commits using the bot's signing key.

---

## update-maintainers -- Maintainers List Sync

The `update-maintainers` job generates and updates the `maintainers.yaml` file in the [`falcosecurity/evolution`](https://github.com/falcosecurity/evolution) repository by querying GitHub for organization-wide contributor data.

**Source:** [`config/jobs/update-maintainers/update-maintainers.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/update-maintainers/update-maintainers.yaml), [`images/update-maintainers/entrypoint.sh`](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh), [`images/update-maintainers/Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-maintainers/Dockerfile)

### Schedule

The job runs as a Prow **periodic** on a cron schedule: `"0 9 * * *"` (daily at 09:00 UTC) ([update-maintainers.yaml:3](../../../refs/falcosecurity/test-infra/config/jobs/update-maintainers/update-maintainers.yaml)).

### How It Works

The job checks out the `falcosecurity/evolution` repository (branch: `main`) as the working directory ([update-maintainers.yaml:8-11](../../../refs/falcosecurity/test-infra/config/jobs/update-maintainers/update-maintainers.yaml)) and runs the [`entrypoint.sh`](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh) script, which:

1. **Generates maintainers data** using `maintainers-generator` ([entrypoint.sh:40-47](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh)): Queries the GitHub API for the `falcosecurity` organization and produces a `maintainers.yaml` file. It uses `people/affiliations.json` from the evolution repo as a persons database for name/company mapping.

2. **Updates evolution resource files** by running `make` ([entrypoint.sh:51-53](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh)): This regenerates files like `README.md` and `MAINTAINERS.md` in the evolution repository.

3. **Creates a pull request** if changes are detected ([entrypoint.sh:83-114](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh)): Uses the `pr-creator` tool to push a branch (`update-evolution-files`) and open a PR to the evolution repository with the title *"update: maintainers list and evolution resources"*.

### Container Image

The Docker image ([Dockerfile](../../../refs/falcosecurity/test-infra/images/update-maintainers/Dockerfile)) is built in multiple stages:

1. Builds `pr-creator` from the Kubernetes test-infra repository
2. Downloads `maintainers-generator` from [leodido/maintainers-generator](https://github.com/leodido/maintainers-generator) releases
3. Packages both tools with the entrypoint script

### Bot Configuration

All operations are performed as the `poiana` bot with GPG-signed commits ([entrypoint.sh:24-27](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh)):
- **Name:** `poiana`
- **Email:** `51138685+poiana@users.noreply.github.com`
- **GPG Key ID:** `EC9875C7B990D55F3B44D6E45F284448FF941C8F`

---

## Branch Protection

The `branchprotector` Prow job applies GitHub branch protection rules declaratively from the Prow configuration.

**Source:** [`config/jobs/branchprotector/branchprotector.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/branchprotector/branchprotector.yaml), [`config/config.yaml`](../../../refs/falcosecurity/test-infra/config/config.yaml)

### When It Runs

| Job Type | Name | Trigger |
|----------|------|---------|
| **Post-submit** | `branchprotector-post-submit` | After merge to `master` when `config/config.yaml` changes |
| **Periodic** | `branchprotector-hourly` | Every hour (cron: `"55 * * * *"`) |

**Source:** [`branchprotector.yaml:1-64`](../../../refs/falcosecurity/test-infra/config/jobs/branchprotector/branchprotector.yaml)

Both jobs use the `gcr.io/k8s-prow/branchprotector:v20240805-37a08f946` image and read from `config/config.yaml` and `config/jobs/`.

### Branch Protection Configuration

The branch protection rules are defined in the `branch-protection:` section of [`config/config.yaml`](../../../refs/falcosecurity/test-infra/config/config.yaml). Key global defaults ([config.yaml:52-65](../../../refs/falcosecurity/test-infra/config/config.yaml)):

| Setting | Value | Description |
|---------|-------|-------------|
| `enforce_admins` | `true` | Protection rules apply to admins too |
| `restrictions.teams` | `["maintainers", "machine_users"]` | Only these teams can push to protected branches |
| `dismiss_stale_reviews` | `true` | Old reviews are automatically dismissed on new pushes |
| `require_code_owner_reviews` | `true` | At least one code owner must approve |
| `required_approving_review_count` | `1` | Minimum one approving review required |
| `strict` (status checks) | `false` | PRs do not need to be up-to-date with base branch (rebase merge strategy makes this unnecessary) |

At the organization level, all `falcosecurity` repositories require the `dco` status check (Developer Certificate of Origin) ([config.yaml:67-71](../../../refs/falcosecurity/test-infra/config/config.yaml)).

Individual repositories can add additional required status checks. For example, `charts` requires `test`, `readme`, `linkChecker`, and `go-unit-tests` ([config.yaml:82-87](../../../refs/falcosecurity/test-infra/config/config.yaml)).

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
emeritus_approvers:
  - leodido
  - fntlnz
```

The root OWNERS file defines who can approve changes to the entire test-infra repository. The `approvers` list aligns with the `test-infra-maintainers` team in org.yaml plus additional members (`LucaGuerra`, `alacuku`). `emeritus_approvers` lists past approvers who are no longer active.

### config/prow/OWNERS

**Source:** [`config/prow/OWNERS`](../../../refs/falcosecurity/test-infra/config/prow/OWNERS)

```yaml
approvers:
  - jonahjon
  - maxgio92
reviewers:
  - markyjackson-taulia
emeritus_approvers:
  - leodido
  - fntlnz
```

This restricts approval of Prow configuration changes to a smaller set of infrastructure specialists.

### config/jobs/OWNERS

**Source:** [`config/jobs/OWNERS`](../../../refs/falcosecurity/test-infra/config/jobs/OWNERS)

Identical to `config/prow/OWNERS`, restricting job configuration approval to `jonahjon` and `maxgio92`.

### How OWNERS Relates to Prow

OWNERS files integrate with Prow's `approve` and `lgtm` plugins:

- **`/approve`**: Only users listed as `approvers` (in the relevant OWNERS file for changed paths) can issue the `/approve` command
- **`/lgtm`**: Users listed as `reviewers` or `approvers` can issue `/lgtm`
- **Inheritance**: OWNERS files are hierarchical -- a parent directory's OWNERS applies to all subdirectories unless overridden
- **`emeritus_approvers`**: Former approvers who are acknowledged but no longer have active approval rights

### OWNERS and Team Sync

The OWNERS files serve a dual purpose:
1. **Prow access control**: Determining who can approve/review PRs
2. **Team membership source of truth**: The [peribolos-syncer](#update-github-teams----per-repo-team-sync-consolidated) jobs read the `approvers` from each repository's root OWNERS file and sync them to the corresponding `-maintainers` team in org.yaml

This means that **changing an OWNERS file in a repository automatically propagates to the GitHub team membership** through the automated sync chain.

---

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
| Peribolos job | [`config/jobs/peribolos/peribolos.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) |
| Peribolos-syncer (historical) | Previously under `config/jobs/update-github-teams/peribolos-syncer-*.yaml`; consolidated into [`config/jobs/peribolos/peribolos.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/peribolos/peribolos.yaml) |
| Update-maintainers job | [`config/jobs/update-maintainers/update-maintainers.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/update-maintainers/update-maintainers.yaml) |
| Update-maintainers script | [`images/update-maintainers/entrypoint.sh`](../../../refs/falcosecurity/test-infra/images/update-maintainers/entrypoint.sh) |
| Update-maintainers Dockerfile | [`images/update-maintainers/Dockerfile`](../../../refs/falcosecurity/test-infra/images/update-maintainers/Dockerfile) |
| Branch protector job | [`config/jobs/branchprotector/branchprotector.yaml`](../../../refs/falcosecurity/test-infra/config/jobs/branchprotector/branchprotector.yaml) |
| Branch protection config | [`config/config.yaml`](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| Root OWNERS | [`OWNERS`](../../../refs/falcosecurity/test-infra/OWNERS) |
| Prow OWNERS | [`config/prow/OWNERS`](../../../refs/falcosecurity/test-infra/config/prow/OWNERS) |
| Jobs OWNERS | [`config/jobs/OWNERS`](../../../refs/falcosecurity/test-infra/config/jobs/OWNERS) |
| Governance model | [evolution.md](../evolution.md) |
