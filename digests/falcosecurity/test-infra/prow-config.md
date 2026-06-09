# Falco Test Infrastructure -- Prow Configuration Reference

> **Era:** 0.44 | **Scope:** Infra | **Status:** Stable | **Source:** [test-infra](https://github.com/falcosecurity/test-infra)

This document is a comprehensive reference for the Prow CI/CD configuration used across the falcosecurity GitHub organization. Prow manages pull request automation, job execution, merge gating, and branch protection for all falcosecurity repositories.

---

## Table of Contents

- [1. Core Configuration (config.yaml)](#1-core-configuration-configyaml)
  - [1.1 Deck (UI)](#11-deck-ui)
  - [1.2 Plank (Job Controller)](#12-plank-job-controller)
  - [1.3 Sinker (Garbage Collection)](#13-sinker-garbage-collection)
  - [1.4 Namespaces and Log Level](#14-namespaces-and-log-level)
  - [1.5 Branch Protection](#15-branch-protection)
  - [1.6 Tide (Merge Automation)](#16-tide-merge-automation)
- [2. Plugin Configuration (plugins.yaml)](#2-plugin-configuration-pluginsyaml)
  - [2.1 Core Plugins](#21-core-plugins)
  - [2.2 External Plugins](#22-external-plugins)
  - [2.3 Plugin-Specific Configurations](#23-plugin-specific-configurations)
- [3. PR Lifecycle](#3-pr-lifecycle)
- [4. Config Propagation](#4-config-propagation)
- [Sources](#sources)

---

## 1. Core Configuration (config.yaml)

**Source:** [config/config.yaml](../../../refs/falcosecurity/test-infra/config/config.yaml)

### 1.1 Deck (UI)

Deck is the Prow web UI, served at `prow.falco.org`. It provides PR status, job logs, and merge pool visibility.

| Setting | Value | Line Reference |
|---------|-------|----------------|
| Header color | `#00AEC7` (Falco Teal) | [config.yaml:L3](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| Logo / Favicon | `/static/extensions/favicon.png` | [config.yaml:L4-L5](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| Spyglass size limit | 500,000,000 bytes (500 MB) | [config.yaml:L7](../../../refs/falcosecurity/test-infra/config/config.yaml) |

**Spyglass Lenses** (job log viewers) configured at [config.yaml:L8-L22](../../../refs/falcosecurity/test-infra/config/config.yaml):

| Lens | Required Files | Optional Files |
|------|---------------|----------------|
| `metadata` | `started.json` or `finished.json` | `podinfo.json` |
| `buildlog` | `build-log.txt` | -- |
| `podinfo` | `podinfo.json` | -- |

### 1.2 Plank (Job Controller)

Plank is the Prow component that manages ProwJob execution. Settings defined at [config.yaml:L24-L44](../../../refs/falcosecurity/test-infra/config/config.yaml):

| Setting | Value | Notes |
|---------|-------|-------|
| Max concurrency | `100` | Limit of concurrent ProwJobs across the cluster |
| Pod pending timeout | `60m` | Pods pending longer than 60 minutes are aborted |
| Job URL prefix | `http://prow.falco.org/view/` | For all orgs (`*` wildcard) |
| Report template | Links to PR test history at `prow.falco.org/pr-history` | Includes flake guidance |

**Default Decoration Config** (applied to all jobs via `*` wildcard) at [config.yaml:L32-L44](../../../refs/falcosecurity/test-infra/config/config.yaml):

| Setting | Value |
|---------|-------|
| Timeout | `24h` (up to 24 hours, accommodates driverkit builder jobs) |
| Grace period | `10m` |
| S3 bucket | `s3://falco-prow-logs` |
| Path strategy | `explicit` |
| S3 credentials secret | `s3-credentials` (IAM credentials for sidecar pod log upload) |

**Utility Images** (Prow sidecar containers) at [config.yaml:L36-L40](../../../refs/falcosecurity/test-infra/config/config.yaml):

All four utility images use tag `v20240805-37a08f946` from `gcr.io/k8s-prow/`:
- `clonerefs` -- clones source code
- `initupload` -- uploads job start metadata
- `entrypoint` -- wraps job commands
- `sidecar` -- uploads logs and artifacts to S3

### 1.3 Sinker (Garbage Collection)

Sinker cleans up completed ProwJobs and their pods. Settings at [config.yaml:L46-L50](../../../refs/falcosecurity/test-infra/config/config.yaml):

| Setting | Value | Purpose |
|---------|-------|---------|
| Resync period | `1m` | How often sinker checks for stale resources |
| Max ProwJob age | `48h` | ProwJob custom resources older than 48 hours are deleted |
| Max pod age | `24h` | Pods older than 24 hours are deleted |
| Terminated pod TTL | `2h` | Completed/failed pods are deleted after 2 hours |

### 1.4 Namespaces and Log Level

Defined at [config.yaml:L479-L483](../../../refs/falcosecurity/test-infra/config/config.yaml):

| Setting | Value |
|---------|-------|
| Log level | `debug` |
| Pod namespace | `test-pods` (where job pods run) |
| ProwJob namespace | `default` (where ProwJob CRDs are created) |

### 1.5 Branch Protection

Branch protection rules are configured centrally by Prow and enforced via the `branchprotector` periodic job. The full configuration begins at [config.yaml:L52-L477](../../../refs/falcosecurity/test-infra/config/config.yaml).

#### Global Defaults

These defaults apply to all protected branches across the organization unless overridden per-repo ([config.yaml:L52-L65](../../../refs/falcosecurity/test-infra/config/config.yaml)):

| Setting | Value |
|---------|-------|
| Enforce admins | `true` -- rules apply to admins too |
| Push restrictions | Teams: `maintainers`, `machine_users` |
| Dismiss stale reviews | `true` |
| Dismissal restriction teams | `maintainers`, `machine_users` |
| Require code owner reviews | `true` |
| Required approving review count | `1` |
| Strict status checks | `false` -- PRs are not required to be up-to-date (rebase merge strategy + needs-rebase plugin handle this) |

#### Org-Wide Required Status Check

All falcosecurity repositories require the `dco` status check at the org level ([config.yaml:L67-L71](../../../refs/falcosecurity/test-infra/config/config.yaml)).

#### Key Repository-Specific Rules

Selected repositories with notable branch protection overrides:

| Repository | Extra Required Checks | Special Settings | Line Ref |
|------------|----------------------|------------------|----------|
| `falco` | `test-dev-packages / test-packages`, `test-dev-packages-arm64 / test-packages`, `format code` | 2 required approvals | [L158-L200](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| `libs` | 14 checks: build (amd64/arm64, 4 modes each), test-drivers, test-libs-static, test-scap, format code | 2 required approvals | [L352-L406](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| `charts` | `test`, `readme`, `linkChecker`, `go-unit-tests` | -- | [L81-L90](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| `falcoctl` | `test`, 3 `build` (linux/darwin amd64/arm64, windows amd64), `Lint golang files`, `Enforce go.mod tidiness` | `gh-pages` branch: no admin enforcement, no PR reviews (bot push) | [L245-L264](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| `driverkit` | `build-test-dev (amd64) / build-test`, `build-test-dev (arm64) / build-test`, `Enforce go.mod tidiness` | -- | [L129-L137](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| `falcosidekick` | `Run unit tests`, `lint`, `build-image` | -- | [L201-L209](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| `falco-website` | `netlify/falcosecurity/deploy-preview` | Multiple version branches (v0.26-v0.42) protected | [L285-L325](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| `test-infra` | `check-prow-config`, `manifests-validation` | -- | [L466-L473](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| `plugins` | `build-plugins / build-packages-x86_64`, `build-plugins / build-packages-aarch64`, `get-changed-plugins / get-values` | -- | [L427-L435](../../../refs/falcosecurity/test-infra/config/config.yaml) |

> Note: `falco` and `libs` both require **2 approving reviews** (vs. the global default of 1), reflecting their status as core repositories.

### 1.6 Tide (Merge Automation)

Tide is the merge controller that automatically merges PRs meeting all criteria. Configuration at [config.yaml:L485-L1186](../../../refs/falcosecurity/test-infra/config/config.yaml).

#### Global Settings

| Setting | Value | Line Ref |
|---------|-------|----------|
| Target URL | `https://prow.falco.org/tide` | [L486](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| Skip unknown contexts | `true` | [L488](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| From branch protection | `true` (derive required checks from branch protection config) | [L489](../../../refs/falcosecurity/test-infra/config/config.yaml) |

#### Merge Method

All repositories use the **rebase** merge method. The full list of 36+ repos is defined at [config.yaml:L490-L536](../../../refs/falcosecurity/test-infra/config/config.yaml). Every falcosecurity repo without exception uses `rebase`.

#### Tide Merge Criteria (Per-Repo Queries)

Each repository has a Tide query defining merge requirements. The queries follow a consistent pattern starting at [config.yaml:L537-L1186](../../../refs/falcosecurity/test-infra/config/config.yaml).

**Common required labels** (present on virtually all repos):
- `approved`
- `lgtm`
- `dco-signoff: yes`

**Common blocking labels** (`missingLabels` -- PR must NOT have any of these):
- `do-not-merge`
- `do-not-merge/hold`
- `do-not-merge/invalid-owners-file`
- `do-not-merge/work-in-progress`
- `needs-rebase`

**Additional blocking label** for some repos:
- `do-not-merge/release-note-label-needed` -- required on repos using the `release-note` plugin (e.g., `falco`, `libs`, `falcoctl`, `client-go`, `deploy-kubernetes`, `client-py`, `client-rs`, and others)

All Tide queries set `reviewApprovedRequired: true`.

---

## 2. Plugin Configuration (plugins.yaml)

**Source:** [config/plugins.yaml](../../../refs/falcosecurity/test-infra/config/plugins.yaml)

### 2.1 Core Plugins

Every falcosecurity repository has plugins enabled individually (there is no org-wide plugin list). However, a common set of plugins appears across virtually all repos. The full per-repo plugin lists are defined at [plugins.yaml:L502-L1554](../../../refs/falcosecurity/test-infra/config/plugins.yaml).

**Common plugins** (enabled on nearly every repo):

| Plugin | Purpose |
|--------|---------|
| `approve` | Allows OWNERS to `/approve` PRs |
| `assign` | Allows `/assign` and `/cc` commands |
| `blunderbuss` | Auto-assigns reviewers from OWNERS |
| `branchcleaner` | Deletes merged branches |
| `cat` | `/meow` replies with cat pictures |
| `dco` | Checks for DCO sign-off on commits |
| `dog` | `/bark` replies with dog pictures |
| `goose` | `/honk` replies with goose pictures |
| `help` | Supports `/help` and `/good-first-issue` |
| `hold` | Supports `/hold` to delay merge |
| `label` | Manages labels via `/kind`, `/area`, etc. |
| `lifecycle` | Allows `/lifecycle stale`, `/lifecycle rotten`, etc. |
| `lgtm` | Allows `/lgtm` for looks-good-to-me approval |
| `size` | Auto-labels PR size (XS, S, M, L, XL, XXL) |
| `trigger` | Allows `/test` and `/retest` commands |
| `verify-owners` | Validates OWNERS file changes in PRs |
| `welcome` | Welcomes new PR contributors |
| `wip` | Auto-holds PRs with WIP in title |

**Selectively enabled plugins** (on specific repos):

| Plugin | Repos | Purpose |
|--------|-------|---------|
| `golint` | `client-go`, `cncf-green-review-testing`, `dbg-go`, `driverkit`, `elftoolchain`, `event-generator`, `falcosidekick`, `falcosidekick-ui`, `falco-actions`, `falco-exporter`, `falcoctl`, `falco-operator`, `falco-playground`, `falco-rustlings`, `falco-talon`, `k8s-metacollector`, `kernel-testing`, `peribolos-syncer`, `pigeon`, `testing` | Go linting |
| `mergecommitblocker` | `charts`, `falco`, `falcosidekick`, `falcosidekick-ui`, `falco-aws-terraform`, `flycheck-falco-rules`, `kernel-crawler`, `kilt`, `libs`, `pdig`, `plugins`, `plugin-sdk-go`, `plugin-sdk-cpp`, `plugin-sdk-rs` | Blocks merge commits |
| `milestone` | `falco`, `falcoctl`, `falco-website`, `libs`, `pdig`, `plugin-sdk-cpp`, `rules` | Manages milestones |
| `release-note` | `falco`, `client-go`, `client-py`, `client-rs`, `falcoctl`, `libs`, `plugin-sdk-go`, `plugin-sdk-rs` | Requires release notes on PRs |
| `require-matching-label` | Most repos | Enforces `kind/*` labels |
| `retitle` | Most repos (not `.github`, `advocacy`) | Allows retitling PRs/issues |
| `config-updater` | `test-infra` only | Auto-updates ConfigMaps on merge |

### 2.2 External Plugins

The `needs-rebase` external plugin is enabled for every repository in the organization. It listens on `pull_request` events and adds the `needs-rebase` label when a PR has merge conflicts. Defined at [plugins.yaml:L1556-L1741](../../../refs/falcosecurity/test-infra/config/plugins.yaml).

### 2.3 Plugin-Specific Configurations

#### approve

Defined at [plugins.yaml:L1-L59](../../../refs/falcosecurity/test-infra/config/plugins.yaml).

Two groups are configured:

1. **Most repositories** (50+ repos listed at [L2-L50](../../../refs/falcosecurity/test-infra/config/plugins.yaml)):
   - `lgtm_acts_as_approve: true` -- an `/lgtm` from an approver also counts as `/approve`
   - `require_self_approval: false` -- PR authors do not need separate approval from themselves
   - `commandHelpLink: https://prow.falco.org/command-help`

2. **falco and libs** ([L54-L59](../../../refs/falcosecurity/test-infra/config/plugins.yaml)):
   - Same settings: `lgtm_acts_as_approve: true`, `require_self_approval: false`

#### blunderbuss

Defined at [plugins.yaml:L61-L63](../../../refs/falcosecurity/test-infra/config/plugins.yaml):
- `max_request_count: 2` -- assigns at most 2 reviewers
- `use_status_availability: true` -- considers GitHub availability status

#### config_updater

Defined at [plugins.yaml:L65-L73](../../../refs/falcosecurity/test-infra/config/plugins.yaml). Maps files in `test-infra` to Kubernetes ConfigMaps:

| File Pattern | ConfigMap Name | Options |
|-------------|---------------|---------|
| `config/config.yaml` | `config` | -- |
| `config/plugins.yaml` | `plugins` | -- |
| `config/jobs/**/*.yaml` | `job-config` | `gzip: true` |

This is the primary mechanism for config propagation -- see [Section 4](#4-config-propagation).

#### dco

Defined at [plugins.yaml:L75-L78](../../../refs/falcosecurity/test-infra/config/plugins.yaml):
- Applied globally via `"*"` wildcard
- `contributing_branch: main`
- `contributing_repo: falcosecurity/.github` -- points contributors to the central CONTRIBUTING guidelines
- Enforces DCO sign-off for **all** members (no exceptions)

#### goose

Defined at [plugins.yaml:L80-L81](../../../refs/falcosecurity/test-infra/config/plugins.yaml):
- `key_path: /etc/unsplash/honk` -- path to the Unsplash API key for goose images

#### label

Defined at [plugins.yaml:L83-L88](../../../refs/falcosecurity/test-infra/config/plugins.yaml):
- Custom additional labels beyond the standard set:
  - `kind/sandbox`
  - `kind/incubation`
  - `kind/officialsupport`
- These are used primarily on the `evolution` repository for repository lifecycle proposals.

#### lgtm

Defined at [plugins.yaml:L90-L139](../../../refs/falcosecurity/test-infra/config/plugins.yaml):
- Applies to all 36 listed repositories
- `review_acts_as_lgtm: true` -- a GitHub approval review is equivalent to `/lgtm`
- `store_tree_hash: true` -- stores the tree hash at LGTM time; if the PR changes, the LGTM is invalidated
- `trusted_team_for_sticky_lgtm: test-infra-maintainers` -- members of this team have sticky LGTM that survives PR updates

#### repo_milestone

Defined at [plugins.yaml:L141-L160](../../../refs/falcosecurity/test-infra/config/plugins.yaml). Controls who can set milestones on specific repos:

| Repository | Maintainers Team |
|------------|-----------------|
| `falco` | `falco-maintainers` (ID: 3770343) |
| `libs` | `libs-maintainers` (ID: 4535471) |
| `pdig` | `pdig-maintainers` (ID: 3832091) |
| `falcoctl` | `falcoctl-maintainers` |
| `plugin-sdk-cpp` | `plugin-sdk-cpp-maintainers` |

#### require_matching_label

Defined at [plugins.yaml:L162-L484](../../../refs/falcosecurity/test-infra/config/plugins.yaml). Requires a `kind/*` label on PRs or issues across the organization.

Configuration pattern for each repo:
- `missing_label: needs-kind`
- `regexp: ^kind/`
- Applies to either `prs: true` or `issues: true` depending on the repository
- Posts a comment instructing users to add a kind label via `/kind <group>` or manually

Repos where `kind/*` is required on **PRs**: `.github`, `client-go`, `client-py`, `client-rs`, `contrib`, `dbg-go`, `driverkit`, `evolution`, `event-generator`, `falcosidekick`, `falcosidekick-ui`, `plugin-sdk-go`, `plugin-sdk-cpp`, `plugin-sdk-rs`.

Repos where `kind/*` is required on **issues**: `cncf-green-review-testing`, `community`, `deploy-kubernetes`, `falco`, `falco-aws-terraform`, `falco-exporter`, `falcoctl`, `falco-website`, `flycheck-falco-rules`, `k8s-metacollector`, `kilt`, `plugins`, `rules`, `libs`, `libs-sdk-go`, `syscalls-bumper`, `peribolos-syncer`, `pigeon`, `testing`, `kernel-crawler`, `kernel-testing`, `falco-operator`, `falco-playground`, `falco-rustlings`, `falco-talon`, `falco-actions`.

#### retitle

Defined at [plugins.yaml:L486-L487](../../../refs/falcosecurity/test-infra/config/plugins.yaml):
- `allow_closed_issues: true` -- issues can be retitled even after closing

#### size

Defined at [plugins.yaml:L489-L494](../../../refs/falcosecurity/test-infra/config/plugins.yaml). Thresholds for auto-labeling PR size:

| Label | Lines Changed Threshold |
|-------|------------------------|
| `size/S` | 10 |
| `size/M` | 30 |
| `size/L` | 90 |
| `size/XL` | 270 |
| `size/XXL` | 520 |

#### triggers

Defined at [plugins.yaml:L496-L500](../../../refs/falcosecurity/test-infra/config/plugins.yaml):
- Applies to the entire `falcosecurity` org
- `join_org_url: https://github.com/falcosecurity/.github/blob/main/CONTRIBUTING.md`
- `only_org_members: true` -- only organization members can trigger CI jobs via `/test`

---

## 3. PR Lifecycle

The following describes the end-to-end flow of a pull request through the Prow system for any falcosecurity repository.

### 3.1 PR Creation and Presubmit

1. **Developer pushes** commits to a branch and opens a PR against a falcosecurity repo.
2. **GitHub sends a webhook** to Prow's `hook` component.
3. **hook** processes the event and:
   - The `dco` plugin checks all commits for DCO sign-off ([plugins.yaml:L75-L78](../../../refs/falcosecurity/test-infra/config/plugins.yaml)).
   - The `welcome` plugin posts a welcome message for first-time contributors.
   - The `size` plugin auto-labels the PR with a size label.
   - The `blunderbuss` plugin auto-assigns up to 2 reviewers from OWNERS ([plugins.yaml:L61-L63](../../../refs/falcosecurity/test-infra/config/plugins.yaml)).
   - The `require-matching-label` plugin comments if a `kind/*` label is missing.
   - The `needs-rebase` external plugin checks for merge conflicts ([plugins.yaml:L1556-L1741](../../../refs/falcosecurity/test-infra/config/plugins.yaml)).
   - The `wip` plugin auto-holds PRs with "WIP" in the title.
4. **Presubmit jobs** fire based on job configurations in [`config/jobs/`](../../../refs/falcosecurity/test-infra/config/jobs/).
5. **Plank** schedules job pods in the `test-pods` namespace ([config.yaml:L481](../../../refs/falcosecurity/test-infra/config/config.yaml)) with the default 24h timeout ([config.yaml:L34](../../../refs/falcosecurity/test-infra/config/config.yaml)).
6. **Crier** reports job status back to GitHub as commit statuses / checks.
7. Job logs and artifacts are uploaded to `s3://falco-prow-logs` via the `sidecar` utility image ([config.yaml:L42](../../../refs/falcosecurity/test-infra/config/config.yaml)).

### 3.2 Review and Approval

1. **Reviewer** reviews the code and can:
   - Submit a GitHub review approval (acts as `/lgtm` since `review_acts_as_lgtm: true` in [plugins.yaml:L137](../../../refs/falcosecurity/test-infra/config/plugins.yaml))
   - Comment `/lgtm` to add the `lgtm` label
   - Comment `/approve` to add the `approved` label (OWNERS file approvers only)
   - Since `lgtm_acts_as_approve: true` ([plugins.yaml:L51](../../../refs/falcosecurity/test-infra/config/plugins.yaml)), `/lgtm` from an approver also grants `approved`
2. The `lgtm` plugin stores the tree hash (`store_tree_hash: true` at [plugins.yaml:L138](../../../refs/falcosecurity/test-infra/config/plugins.yaml)). If the PR is updated, the LGTM is invalidated unless the reviewer is in `test-infra-maintainers` ([plugins.yaml:L139](../../../refs/falcosecurity/test-infra/config/plugins.yaml)).
3. Any reviewer or author can use `/hold` to block merge temporarily.

### 3.3 Tide Merge

1. **Tide** periodically checks all PRs and evaluates merge readiness.
2. A PR is eligible for merge when it has:
   - Required labels: `approved`, `lgtm`, `dco-signoff: yes`
   - No blocking labels: `do-not-merge`, `do-not-merge/hold`, `do-not-merge/invalid-owners-file`, `do-not-merge/work-in-progress`, `needs-rebase` (and `do-not-merge/release-note-label-needed` where applicable)
   - All required status checks passing (derived from branch protection since `from-branch-protection: true` at [config.yaml:L489](../../../refs/falcosecurity/test-infra/config/config.yaml))
   - `reviewApprovedRequired: true` -- at least one GitHub review approval
3. Tide merges via **rebase** ([config.yaml:L490-L536](../../../refs/falcosecurity/test-infra/config/config.yaml)) -- this is universal across all repos.
4. Unknown contexts are skipped (`skip-unknown-contexts: true` at [config.yaml:L488](../../../refs/falcosecurity/test-infra/config/config.yaml)), so only branch-protection-defined checks gate merges.

### 3.4 Postsubmit

1. After merge, **postsubmit jobs** fire based on configurations in [`config/jobs/`](../../../refs/falcosecurity/test-infra/config/jobs/).
2. For `test-infra` itself, the `update-jobs-pr` postsubmit runs to update the `job-config` ConfigMap ([update-jobs.yaml:L1-L20](../../../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml)).

---

## 4. Config Propagation

Configuration changes in `test-infra` take effect through two mechanisms.

### 4.1 config-updater Plugin (Immediate)

The `config-updater` plugin is enabled **only** on the `test-infra` repository ([plugins.yaml:L1518](../../../refs/falcosecurity/test-infra/config/plugins.yaml)). When a PR merges to `master`, the plugin automatically updates Kubernetes ConfigMaps based on the mapping in [plugins.yaml:L65-L73](../../../refs/falcosecurity/test-infra/config/plugins.yaml):

```
config/config.yaml      -->  ConfigMap "config"
config/plugins.yaml     -->  ConfigMap "plugins"
config/jobs/**/*.yaml   -->  ConfigMap "job-config" (gzip compressed)
```

Prow components watch these ConfigMaps and hot-reload their configuration. This means changes to `config.yaml` and `plugins.yaml` take effect **immediately** upon merge -- no restart needed.

### 4.2 update-jobs Postsubmit

The `update-jobs-pr` postsubmit job ([update-jobs.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml)) runs after every merge to the `master` branch of `test-infra`. It uses a custom `update-jobs` image to process job configuration files from `config/jobs/` and update the `job-config` ConfigMap.

### 4.3 Config Validation

Configuration integrity is ensured by two mechanisms defined in [check-prow-config.yaml](../../../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml):

1. **Presubmit** (`check-prow-config`): Runs on every PR to `test-infra`'s `master` branch. Uses `gcr.io/k8s-prow/checkconfig:v20240805-37a08f946` to validate `config.yaml`, `plugins.yaml`, and all job configs ([check-prow-config.yaml:L1-L18](../../../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml)).

2. **Periodic** (`check-prow-config-periodic`): Runs every 1 hour as a safety net to catch drift between ConfigMaps and the git source ([check-prow-config.yaml:L20-L38](../../../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml)).

Both use the same `checkconfig` tool with identical arguments:
```
checkconfig --config-path=config/config.yaml --job-config-path=config/jobs --plugin-config=config/plugins.yaml
```

---

## Sources

| Topic | Source File |
|-------|-------------|
| Core Prow config (deck, plank, sinker, branch protection, tide) | [config/config.yaml](../../../refs/falcosecurity/test-infra/config/config.yaml) |
| Plugin configuration (approve, lgtm, dco, size, triggers, per-repo plugins) | [config/plugins.yaml](../../../refs/falcosecurity/test-infra/config/plugins.yaml) |
| Config validation (presubmit + periodic) | [config/jobs/check-prow-config/check-prow-config.yaml](../../../refs/falcosecurity/test-infra/config/jobs/check-prow-config/check-prow-config.yaml) |
| Job config update postsubmit | [config/jobs/update-jobs/update-jobs.yaml](../../../refs/falcosecurity/test-infra/config/jobs/update-jobs/update-jobs.yaml) |
