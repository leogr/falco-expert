# Rules Content

> Detection rule content and lifecycle: maturity framework, rule files and distribution tiers, rule taxonomy, macro/list architecture, tuning patterns, and release process.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/rules/`](../refs/falcosecurity/rules/)

## Overview

This spec covers Falco detection rules as **content** -- the community-maintained rule definitions, their classification, distribution, and lifecycle. This is distinct from the rule engine mechanics (compilation pipeline, AST, ruleset management) documented in [`rule-engine.md`](rule-engine.md).

Falco rules are organized into four rule files corresponding to maturity tiers and distributed as OCI artifacts via falcoctl. The rules repository is a **Core / Stable** component of the falcosecurity organization, focused on syscall and container event detection. Plugin-specific rules (k8saudit, cloudtrail, etc.) are maintained in their respective plugin repositories.

**Key characteristics:**
- Community-maintained under the falcosecurity organization
- 4 rule files organized by maturity level
- Maturity framework introduced in Falco 0.36 via [proposal 20230605](../refs/falcosecurity/rules/proposals/20230605-rules-adoption-management-maturity-framework.md)
- SemVer-versioned and distributed as signed OCI artifacts
- Engine version 0.62.0 (as defined in [`falco_engine_version.h:22-24`](../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h))

**Source:** [`digests/falcosecurity/rules.md`](../digests/falcosecurity/rules.md), [`digests/falcosecurity/falco/rule-language.md`](../digests/falcosecurity/falco/rule-language.md)

## Maturity Framework

The maturity framework classifies rules into four levels, each with distinct guarantees, target audiences, and distribution methods.

### Maturity Levels

**maturity_stable**
- Thoroughly evaluated by production security experts
- Embody best practices with optimal robustness
- Focus on universal system-level detections (reverse shells, container escapes)
- Difficult for attackers to bypass
- Bundled with the Falco release package (no separate installation required)

**maturity_incubating**
- Address relevant threats with robustness guarantees
- Cater to more specific use cases (e.g., application-specific rules)
- Require explicit installation via falcoctl or Helm configuration

**maturity_sandbox**
- Experimental stage; broader usefulness being assessed
- Meet minimum acceptance criteria
- Serve as inspiration and starting points for custom rules

**maturity_deprecated**
- Re-assessed as less applicable to current threat landscapes
- Retained as examples and historical reference
- No longer actively maintained

### Key Principle

Maturity level does **not** reflect noise potential. Each environment is unique -- a stable rule may generate more alerts than a sandbox rule in a given deployment. Maturity reflects confidence in detection quality, robustness, and universal applicability, not expected alert volume.

**Source:** [`proposals/20230605-rules-adoption-management-maturity-framework.md`](../refs/falcosecurity/rules/proposals/20230605-rules-adoption-management-maturity-framework.md)

## Rule Files and Distribution

### Rule Files

| File | Maturity | Size | Distribution | Description |
|------|----------|------|--------------|-------------|
| [`falco_rules.yaml`](../refs/falcosecurity/rules/rules/falco_rules.yaml) | Stable | ~62KB | Bundled with Falco | Production-ready universal detections |
| [`falco-incubating_rules.yaml`](../refs/falcosecurity/rules/rules/falco-incubating_rules.yaml) | Incubating | ~65KB | Separate install | Specific use cases, application-level rules |
| [`falco-sandbox_rules.yaml`](../refs/falcosecurity/rules/rules/falco-sandbox_rules.yaml) | Sandbox | ~82KB | Separate install | Experimental detections |
| [`falco-deprecated_rules.yaml`](../refs/falcosecurity/rules/archive/falco-deprecated_rules.yaml) | Deprecated | - | Separate install | Legacy examples, no longer maintained (archived) |

### Naming Convention

- Rule files: `<ruleset>_rules.yaml` (alphanumeric, lowercase, separated by `-`)
- Git tags: `<ruleset>-rules-<version>` (e.g., `falco-rules-3.0.0`, `falco-incubating-rules-6.0.0`)

### OCI Artifact Distribution

Rules are distributed as OCI artifacts via falcoctl, hosted on `ghcr.io/falcosecurity/rules`. Each ruleset is a separate OCI artifact with cosign signatures for verification.

**Registry configuration** (from [`registry.yaml`](../refs/falcosecurity/rules/registry.yaml)):

```yaml
rulesfiles:
  - name: falco-rules
    path: rules/falco_rules.yaml
    signature:
      cosign:
        certificate-oidc-issuer: https://token.actions.githubusercontent.com
        certificate-identity-regexp: https://github.com/falcosecurity/rules/
```

### Versioning

Rules follow [SemVer](https://semver.org/). Only the latest rules releases are guaranteed compatible with the latest Falco release.

**Source:** [`CONTRIBUTING.md`](../refs/falcosecurity/rules/CONTRIBUTING.md), [`registry.yaml`](../refs/falcosecurity/rules/registry.yaml)

## Acceptance Criteria

All rules submitted to the repository must meet these criteria. The level of scrutiny increases with maturity tier.

### Correctness

- Valid expression language (syntax and grammar verified by the rule engine)
- Consistent name and description
- All tests must pass
- Manual testing during review

### Robustness

- **Behavioral detections preferred over string matching** -- signature-based detection can be bypassed by trivial renaming or encoding changes
- Choose the most robust syscall for detection (e.g., prefer `execve`/`execveat` for process execution over interpreting command-line strings)
- Broader rules preferred over narrow CVE-specific ones (detect the technique, not the specific exploit)

### Relevance

- Cover attack vectors across industries (not vendor-specific)
- Provide actionable context for incident response
- Effective across diverse workloads
- Include tuning guidance where applicable

### High-Volume Syscall Limitation

Rules requiring high-volume syscalls (those enabled via `base_syscalls.all` in Falco configuration) cannot be accepted beyond sandbox/disabled state due to performance impact on the event pipeline.

> Note: Upstream docs may still reference the deprecated `-A` CLI flag, removed in Falco 0.39 and replaced by `base_syscalls.all` configuration.

**Source:** [`CONTRIBUTING.md`](../refs/falcosecurity/rules/CONTRIBUTING.md)

## Rule Taxonomy

Rules in the repository cover the following detection categories, aligned with common attack frameworks (MITRE ATT&CK tags are used extensively):

### Container Escapes
- Detecting abuse of `release_agent`, `cgroup notify_on_release`, and similar container breakout techniques
- Monitoring writes to sensitive host paths from within containers
- Example: **"Detect release_agent File Container Escapes"** -- monitors open syscalls for writes to `release_agent` files, includes preconditions checking container privileges, targets specific container escape TTPs

### Lateral Movement
- Detecting unauthorized network connections between services
- SSH session monitoring and credential forwarding detection

### File Operations
- Writes to sensitive directories (`/etc`, `/usr/bin`, `/root/.ssh`)
- Modification of system configuration files
- Symlink-based evasion detection

### Credential Access
- Reading sensitive files (`/etc/shadow`, `/etc/passwd`)
- Access to credential stores and key material
- Token and secret file enumeration

### Process Execution
- Unexpected binary execution in containers
- Shell spawning in non-interactive contexts
- Example: **"Drop and execute new binary in container"** -- detects executables not in the original container image, executed from the upper overlayfs layer, leveraging high-value kernel signals

### Network Activity
- Unexpected outbound connections
- Listening on unusual ports
- DNS exfiltration indicators

### Privilege Escalation
- Setuid/setgid bit manipulation
- Capability changes and namespace manipulation
- Exploitation of SUID binaries

**Source:** [`rules/falco_rules.yaml`](../refs/falcosecurity/rules/rules/falco_rules.yaml), [`rules/falco-incubating_rules.yaml`](../refs/falcosecurity/rules/rules/falco-incubating_rules.yaml), [`rules/falco-sandbox_rules.yaml`](../refs/falcosecurity/rules/rules/falco-sandbox_rules.yaml)

## Macro and List Architecture

Rules are built from shared building blocks that promote reuse and consistency across rule files.

### Lists

Lists are named collections of values referenced in rule and macro conditions. At compilation time, list references are expanded inline.

```yaml
- list: shell_binaries
  items: [bash, sh, zsh, ksh, csh, tcsh]

- list: sensitive_file_names
  items: [/etc/shadow, /etc/passwd, /etc/pam.d]
```

Lists can reference other lists (resolved during compilation):

```yaml
- list: all_shells
  items: [shell_binaries, powershell]
```

**Source:** [`rule_loader.h:403-416`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

### Macros

Macros are named condition fragments for reuse across rules. They encapsulate common detection patterns.

```yaml
- macro: open_write
  condition: >
    evt.type in (open, openat, openat2) and
    evt.is_open_write=true

- macro: container
  condition: container.id != host

- macro: spawned_process
  condition: evt.type = execve
```

**Source:** [`rule_loader.h:421-435`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

### Override Patterns

Both lists and macros support `append` and `replace` operations for customization without modifying the original definitions.

**Appending to lists:**

```yaml
- list: shell_binaries
  items: [pwsh, fish]
  override:
    items: append
```

**Appending to macros:**

```yaml
- macro: open_write
  condition: or evt.type = creat
  override:
    condition: append
```

**Replacing rule fields:**

```yaml
- rule: existing_rule
  desc: "Additional description"
  condition: and proc.name != systemd
  priority: ERROR
  override:
    desc: append
    condition: append
    priority: replace
```

The legacy `append: true` syntax is deprecated and generates a warning. It cannot be mixed with the `override` key.

**Source:** [`rule_loader_reader.cpp:200-262`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp)

## Tuning Patterns

### Custom Rules via Helm

Custom rules are injected via the `customRules` Helm value, which creates a ConfigMap mounted into the Falco pod:

```yaml
customRules:
  my-rules.yaml: |-
    - rule: My Custom Rule
      desc: Custom detection
      condition: spawned_process and container
      output: "Custom alert (command=%proc.cmdline)"
      priority: WARNING
```

### Append and Override

The primary tuning mechanism is the override system. Custom rule files loaded after the default rules can:
- **Append** conditions, output fields, tags, and exceptions to existing rules
- **Replace** priority, enabled status, conditions, and other fields
- **Add exception values** to existing exception definitions without modifying the base rule

```yaml
# Disable a noisy rule
- rule: Write Below Etc
  enabled: false
  override:
    enabled: replace

# Add exceptions to an existing rule
- rule: Write Below Etc
  exceptions:
    - name: known_writers
      values:
        - [systemd, /etc/systemd]
  override:
    exceptions: append
```

### Progressive Adoption

The recommended adoption strategy follows a staged approach:

1. **Start with stable rules** -- deploy `falco_rules.yaml` (bundled by default)
2. **Tune for the environment** -- add exceptions and overrides for known-good behavior
3. **Add incubating rules** -- install `falco-incubating_rules.yaml` for additional coverage
4. **Monitor and adjust** -- review alert volumes, add further tuning
5. **Add sandbox rules** -- selectively enable experimental detections as needed

### Environment-Specific Adjustments

- **Profiling:** Allowlist containers, namespaces, and crown jewel applications
- **Behavioral indicators:** Filter by process lineage (shell/Java in parent), manual shell access detection
- **Data lake integration:** Some operationalization requires external correlation systems for alert enrichment and noise reduction

### Installation of Additional Rule Files

```bash
# Helm: install incubating and sandbox rules alongside stable
helm install falco falcosecurity/falco \
  --set "falcoctl.config.artifact.install.refs={falco-rules:2,falco-incubating-rules:2,falco-sandbox-rules:2}" \
  --set "falcoctl.config.artifact.follow.refs={falco-rules:2,falco-incubating-rules:2,falco-sandbox-rules:2}" \
  --set "falco.rules_file={/etc/falco/falco_rules.yaml,/etc/falco/falco-incubating_rules.yaml,/etc/falco/falco-sandbox_rules.yaml,/etc/falco/rules.d}"
```

**Source:** [`digests/falcosecurity/rules.md`](../digests/falcosecurity/rules.md)

## Release Process

### Workflow

1. Update `.github/FALCO_VERSIONS` with compatible stable Falco versions
2. Determine new version per SemVer guidelines
3. Create git tag: `<ruleset>-rules-<version>` (e.g., `falco-incubating-rules-6.0.0`)
4. GitHub Action validates and releases OCI artifact to `ghcr.io/falcosecurity/rules`
5. Registry entry with cosign signature enables verification on pull

### SemVer Guidelines

**Patch (z)** -- backward-compatible changes:
- Decrementing `required_engine_version`
- Adding or removing list items
- Adding tags, increasing priority
- Changing output fields
- Adding or removing exceptions
- Making rules less noisy

**Minor (y)** -- backward-compatible additions:
- Incrementing `required_engine_version`
- Adding new lists, macros, or rules
- New plugin requirements

**Major (x)** -- incompatible changes:
- Renaming or removing lists, macros, or rules
- Changing event source
- Disabling previously enabled rules
- Removing tags, decreasing priority
- Changing logical security scope

### Registry and Signatures

Rules are registered in [`registry.yaml`](../refs/falcosecurity/rules/registry.yaml) with cosign signatures for supply-chain verification. The signature configuration uses GitHub Actions OIDC for identity attestation.

**Source:** [`CONTRIBUTING.md`](../refs/falcosecurity/rules/CONTRIBUTING.md), [`registry.yaml`](../refs/falcosecurity/rules/registry.yaml)

## Related Specs

| Spec | Relationship |
|------|--------------|
| [`rule-engine.md`](rule-engine.md) | Rule compilation pipeline, YAML schema, AST, ruleset management (engine mechanics) |
| [`filter-engine.md`](filter-engine.md) | Filter expression language used in rule conditions |
| [`falcoctl.md`](falcoctl.md) | OCI artifact distribution, rule installation and follow |
| [`plugin-system.md`](plugin-system.md) | Plugin-sourced event rules (k8saudit, cloudtrail) |

## Sources

| Topic | Source File |
|-------|-------------|
| Stable rules | [`rules/falco_rules.yaml`](../refs/falcosecurity/rules/rules/falco_rules.yaml) |
| Incubating rules | [`rules/falco-incubating_rules.yaml`](../refs/falcosecurity/rules/rules/falco-incubating_rules.yaml) |
| Sandbox rules | [`rules/falco-sandbox_rules.yaml`](../refs/falcosecurity/rules/rules/falco-sandbox_rules.yaml) |
| Deprecated rules | [`archive/falco-deprecated_rules.yaml`](../refs/falcosecurity/rules/archive/falco-deprecated_rules.yaml) |
| Registry | [`registry.yaml`](../refs/falcosecurity/rules/registry.yaml) |
| Maturity framework proposal | [`proposals/20230605-rules-adoption-management-maturity-framework.md`](../refs/falcosecurity/rules/proposals/20230605-rules-adoption-management-maturity-framework.md) |
| Contributing guidelines | [`CONTRIBUTING.md`](../refs/falcosecurity/rules/CONTRIBUTING.md) |
| Rules digest | [`digests/falcosecurity/rules.md`](../digests/falcosecurity/rules.md) |
| Rule language digest | [`digests/falcosecurity/falco/rule-language.md`](../digests/falcosecurity/falco/rule-language.md) |
| Rule structures (C++) | [`rule_loader.h`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h) |
| Rule reader | [`rule_loader_reader.cpp`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp) |
| Engine version | [`falco_engine_version.h`](../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h) |
