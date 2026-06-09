# pigeon Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/pigeon/`](../../refs/falcosecurity/pigeon/) | **Commit:** `43aad93` (May 6, 2024)

**Repository:** [falcosecurity/pigeon](https://github.com/falcosecurity/pigeon)
**Scope:** Infra
**Status:** Incubating

CLI tool for managing GitHub Actions secrets and variables across the falcosecurity organization from a centralized configuration file.

---

## Overview

Pigeon synchronizes GitHub Actions secrets and variables for organizations and repositories from a YAML configuration file. It enables declarative, centralized management of CI/CD configuration across the entire falcosecurity GitHub organization.

**Purpose:**
- Centrally manage GitHub Actions secrets across all falcosecurity repositories
- Declaratively sync variables and secrets from config to GitHub
- Source secrets securely from 1Password
- Ensure consistent CI/CD configuration across the organization

**Source:** [`README.md`](../../refs/falcosecurity/pigeon/README.md)

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           Pigeon Workflow                                     │
└──────────────────────────────────────────────────────────────────────────────┘

 ┌─────────────────────┐          ┌─────────────────────┐
 │   YAML Config       │          │    1Password        │
 │                     │          │    Connect          │
 │ orgs:               │          │                     │
 │   falcosecurity:    │          │ - AWS_ACCESS_KEY    │
 │     secrets:        │──────────│ - DOCKER_TOKEN      │
 │       - AWS_KEY     │  lookup  │ - SIGNING_KEY       │
 │     repos:          │          │ - ...               │
 │       libs:         │          └─────────────────────┘
 │         secrets:    │                    │
 │           - ...     │                    │
 └──────────┬──────────┘                    │
            │                               │
            ▼                               ▼
 ┌─────────────────────────────────────────────────────┐
 │                      Pigeon                          │
 │                                                      │
 │  1. Load config                                      │
 │  2. Fetch secrets from 1Password                     │
 │  3. Encrypt with GitHub public key                   │
 │  4. Sync to GitHub (create/update/delete)            │
 └──────────────────────────────────────────────────────┘
            │
            ▼
 ┌─────────────────────────────────────────────────────┐
 │               GitHub API                             │
 │                                                      │
 │  Org: falcosecurity                                  │
 │  ├── Actions Secrets (org-level)                     │
 │  ├── Actions Variables (org-level)                   │
 │  └── Repos                                           │
 │      ├── libs                                        │
 │      │   ├── Actions Secrets                         │
 │      │   └── Actions Variables                       │
 │      ├── falco                                       │
 │      │   ├── Actions Secrets                         │
 │      │   └── Actions Variables                       │
 │      └── ...                                         │
 └─────────────────────────────────────────────────────┘
```

**Source:** [`main.go`](../../refs/falcosecurity/pigeon/main.go), [`pkg/config/config.go`](../../refs/falcosecurity/pigeon/pkg/config/config.go)

## CLI Usage

```shell
# Basic usage with config file and token
pigeon --conf config.yaml --gh-token /path/to/token

# Dry-run mode (preview changes without applying)
pigeon --conf config.yaml --gh-token /path/to/token --dry-run

# Verbose logging
pigeon --conf config.yaml --gh-token /path/to/token --verbose
```

**CLI Options:**

| Option | Description | Required |
|--------|-------------|----------|
| `--conf` | Path to YAML configuration file | Yes |
| `--gh-token` | Path to file containing GitHub token | Yes* |
| `--dry-run` | Preview changes without applying | No |
| `--verbose` | Enable verbose logging | No |

*Can also be set via `GITHUB_TOKEN_FILE` environment variable.

**Source:** [`README.md`](../../refs/falcosecurity/pigeon/README.md)

## Configuration Format

```yaml
orgs:
  falcosecurity:                    # Organization name
    actions:
      variables:                    # Org-level variables
        REGISTRY: "ghcr.io"
        ORG_NAME: "falcosecurity"
      secrets:                      # Org-level secrets (names only)
        - AWS_ACCESS_KEY_ID
        - AWS_SECRET_ACCESS_KEY
    repos:
      libs:                         # Repository name
        actions:
          variables:                # Repo-level variables
            BUILD_TYPE: "release"
          secrets:                  # Repo-level secrets
            - SIGNING_KEY
      falco:
        actions:
          variables:
            DRIVER_VERSION: "7.0.0"
          secrets:
            - DOCKER_TOKEN
```

**Key points:**
- **Variables**: Defined inline with name and value
- **Secrets**: Only names are listed; values are fetched from 1Password
- Supports both organization-level and repository-level configuration
- Declarative sync: items not in config are deleted from GitHub

**Source:** [`README.md`](../../refs/falcosecurity/pigeon/README.md), [`pkg/config/config.go`](../../refs/falcosecurity/pigeon/pkg/config/config.go)

## 1Password Integration

Pigeon sources secret values from 1Password Connect:

**Required environment variables:**

| Variable | Description |
|----------|-------------|
| `OP_CONNECT_TOKEN` | API token for 1Password Connect |
| `OP_CONNECT_HOST` | Hostname of 1Password Connect instance |
| `OP_VAULT` | UUID of the vault containing secrets |

**How it works:**
1. Secret names are listed in the YAML config
2. Pigeon looks up each secret by name (title) in the 1Password vault
3. Retrieves the `password` field from each item
4. Encrypts with GitHub's public key using libsodium sealed box
5. Uploads encrypted secret to GitHub

**Source:** [`pkg/pigeon/secrets_onepassword.go`](../../refs/falcosecurity/pigeon/pkg/pigeon/secrets_onepassword.go)

## Sync Behavior

Pigeon performs a **declarative sync** - the configuration file is the source of truth:

### Secrets Sync
1. List existing secrets from GitHub
2. Delete secrets that exist on GitHub but not in config
3. Create or update secrets listed in config

### Variables Sync
1. List existing variables from GitHub
2. Delete variables that exist on GitHub but not in config
3. Create or update variables listed in config

**Source:** [`pkg/config/config.go:66-156`](../../refs/falcosecurity/pigeon/pkg/config/config.go)

## Integration with Falco Ecosystem

Pigeon enables centralized CI/CD secret management:

```
1Password (source of truth for secrets)
        │
        ▼
      Pigeon ──▶ GitHub Actions Secrets/Variables
        │
        ▼
  All falcosecurity repositories
  (libs, falco, falcoctl, charts, etc.)
```

**Use cases:**
- Distribute AWS credentials for S3 driver uploads
- Manage Docker Hub/GHCR tokens for image publishing
- Sync signing keys for release artifacts
- Configure organization-wide CI/CD variables

**Source:** [`README.md`](../../refs/falcosecurity/pigeon/README.md)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, CLI | [`README.md`](../../refs/falcosecurity/pigeon/README.md) |
| Entry point | [`main.go`](../../refs/falcosecurity/pigeon/main.go) |
| Config parsing | [`pkg/config/config.go`](../../refs/falcosecurity/pigeon/pkg/config/config.go) |
| Secrets interface | [`pkg/pigeon/secrets.go`](../../refs/falcosecurity/pigeon/pkg/pigeon/secrets.go) |
| 1Password provider | [`pkg/pigeon/secrets_onepassword.go`](../../refs/falcosecurity/pigeon/pkg/pigeon/secrets_onepassword.go) |

## Related Documentation

- [`evolution.md`](evolution.md) - Infra scope repositories
- [`.github.md`](.github.md) - Organization-level GitHub configuration
