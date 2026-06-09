# falcosecurity/rules Digest

**Repository:** https://github.com/falcosecurity/rules
**Era:** 0.44
**Status:** Core / Stable

The official repository for Falco detection rules - predefined detections for security threats, abnormal behaviors, and compliance monitoring.

## Overview

Rules tell Falco what to do. This repository contains community-maintained rules for syscall and container event detection. Plugin rules (k8saudit, cloudtrail, etc.) are stored in their respective plugin repositories.

**Key Links:**
- [Rules Documentation](https://falco.org/docs/rules)
- [Rules Overview](https://falcosecurity.github.io/rules/)
- [Style Guide](https://falco.org/docs/rules/style-guide/)
- [Supported Fields](https://falco.org/docs/reference/rules/supported-fields/)

## Rule Files

| File | Maturity | Default | Description |
|------|----------|---------|-------------|
| `falco_rules.yaml` | Stable | Bundled | ~62KB - Production-ready rules |
| `falco-incubating_rules.yaml` | Incubating | Separate | ~65KB - Specific use cases |
| `falco-sandbox_rules.yaml` | Sandbox | Separate | ~82KB - Experimental rules |
| `falco-deprecated_rules.yaml` | Deprecated | Separate | Legacy examples |

### Naming Convention

- Rule files: `<ruleset>_rules.yaml` (alphanumeric, lowercase, separated by `-`)
- Git tags: `<ruleset>-rules-<version>` (e.g., `falco-rules-3.0.0`)
- Versioning follows [SemVer](https://semver.org/)

## Rules Maturity Framework

Established via [proposal 20230605](../../refs/falcosecurity/rules/proposals/20230605-rules-adoption-management-maturity-framework.md), implemented in Falco 0.36.

### Maturity Levels

**maturity_stable**
- Thoroughly evaluated by production experts
- Embody best practices, optimal robustness
- Focus on universal system-level detections (reverse shells, container escapes)
- Difficult for attackers to bypass
- Included in Falco release package

**maturity_incubating**
- Address relevant threats with robustness guarantees
- Cater to more specific use cases
- May include application-specific rules
- Require explicit installation

**maturity_sandbox**
- Experimental stage
- Broader usefulness being assessed
- Meet minimum acceptance criteria
- Serve as inspiration

**maturity_deprecated**
- Re-assessed as less applicable
- Kept as examples
- No longer actively maintained

### Key Principle

Maturity level does NOT reflect noise potential - each environment is unique. Start with stable rules, tune, then progressively add incubating/sandbox as needed.

## Rules Acceptance Criteria

### Correctness
- Valid expression language (syntax and grammar)
- Consistent name/description
- Tests must pass
- Manual testing during review

### Robustness
- Prefer behavioral detections over string matching
- Signature-based detection can be bypassed
- Choose most robust syscall for detection
- Broader rules preferred over narrow CVE-specific ones

### Relevance
- Cover attack vectors across industries
- Provide actionable context for incident response
- Effective across diverse workloads
- Include tuning guidance

### High-Volume Syscalls
Rules requiring high-volume syscalls (configured via `base_syscalls.all` since 0.39) cannot be accepted beyond sandbox/disabled state due to performance impact.

> Note: Upstream docs may still reference the deprecated `-A` CLI flag, removed in Falco 0.39.

## Installation Methods

### Helm Chart

```bash
helm install falco falcosecurity/falco \
  --set "falcoctl.config.artifact.install.refs={falco-rules:2,falco-incubating-rules:2,falco-sandbox-rules:2}" \
  --set "falcoctl.config.artifact.follow.refs={falco-rules:2,falco-incubating-rules:2,falco-sandbox-rules:2}" \
  --set "falco.rules_file={/etc/falco/k8s_audit_rules.yaml,/etc/falco/rules.d,/etc/falco/falco_rules.yaml,/etc/falco/falco-incubating_rules.yaml,/etc/falco/falco-sandbox_rules.yaml}"
```

Options:
- `falcoctl.config.artifact.install.refs` - Rules downloaded at startup
- `falcoctl.config.artifact.follow.refs` - Rules automatically updated
- `falco.rules_file` - Rules loaded by engine

### Host Installation

1. Configure `rules_file` in `falco.yaml`
2. Download rules from [download.falco.org](https://download.falco.org/?prefix=rules/)
3. Place in rules directory or `rules.d`

## Release Process

1. Update `.github/FALCO_VERSIONS` with compatible stable Falco versions
2. Determine new version per SemVer guidelines
3. Create git tag: `<name>-rules-<version>`
4. GitHub Action validates and releases OCI artifact

### Versioning Guidelines

**Patch (z)** - Backward-compatible changes:
- Decrementing `required_engine_version`
- Adding/removing list items
- Adding tags, increasing priority
- Changing output fields
- Adding/removing exceptions
- Making rules less noisy

**Minor (y)** - Backward-compatible additions:
- Incrementing `required_engine_version`
- Adding new lists, macros, rules
- New plugin requirements

**Major (x)** - Incompatible changes:
- Renaming/removing lists, macros, rules
- Changing event source
- Disabling previously enabled rules
- Removing tags, decreasing priority
- Changing logical security scope

## Registry

Rules are registered in `registry.yaml` with cosign signatures for verification:

```yaml
rulesfiles:
  - name: falco-rules
    path: rules/falco_rules.yaml
    signature:
      cosign:
        certificate-oidc-issuer: https://token.actions.githubusercontent.com
        certificate-identity-regexp: https://github.com/falcosecurity/rules/
```

## Maintainers

**Approvers:**
- mstemm, leogr, jasondellaluce, fededp, andreagit97, lucaguerra, ekoops

**Reviewers:**
- leodido, kaizhe, darryk10, loresuso

**Emeritus:**
- kaizhe, incertum

## Important Notes

1. **Compatibility:** Only latest rules releases are guaranteed compatible with latest Falco release
2. **Main Branch:** Contains latest development - check compatibility before using
3. **Rule Matching:** Use `rule_matching` config to resolve overlapping rules (vs "first match wins")
4. **Selective Overrides:** Use [selective overrides](https://falco.org/docs/rules/overriding/) for customization
5. **Base Syscalls:** Precise syscall control via `base_syscalls` config (adaptive selection available)

## Primary Use Cases

1. **Threat Detection:** Rule violations as indicators of compromise
2. **Compliance:** Detecting unauthorized changes (PCI/DSS file monitoring)

## Example Robust Rules

**Detect release_agent File Container Escapes**
- Based on open syscall monitoring file writes
- Includes preconditions checking container privileges
- Targets specific container escape TTP

**Drop and execute new binary in container**
- Detects executables not in original container image
- Executed from upper overlayfs layer
- Leverages high-value kernel signals

## Tuning Best Practices

1. **Profiling:** Allowlist containers/namespaces, define crown jewel applications
2. **Behavioral Indicators:** Filter by process lineage (shell/Java in parent), manual shell access detection
3. **Progressive Adoption:** Start stable → tune → add incubating → monitor → add sandbox
4. **Consider Data Lakes:** Some operationalization requires external correlation systems

## Scope Considerations (for rule writing)

- Operates at syscall level; deep kernel internals not fully visible
- Network monitoring via syscalls (connect, accept, etc.), not deep packet inspection
- Application-level monitoring requires plugins (k8saudit, cloudtrail, etc.)
- Rule-based detection; no built-in ML anomaly detection

## Sources

| Topic | Source File |
|-------|-------------|
| Stable rules | [`rules/falco_rules.yaml`](../../refs/falcosecurity/rules/rules/falco_rules.yaml) |
| Incubating rules | [`rules/falco-incubating_rules.yaml`](../../refs/falcosecurity/rules/rules/falco-incubating_rules.yaml) |
| Sandbox rules | [`rules/falco-sandbox_rules.yaml`](../../refs/falcosecurity/rules/rules/falco-sandbox_rules.yaml) |
| Deprecated rules | [`archive/falco-deprecated_rules.yaml`](../../refs/falcosecurity/rules/archive/falco-deprecated_rules.yaml) |
| Registry | [`registry.yaml`](../../refs/falcosecurity/rules/registry.yaml) |
| Maturity framework proposal | [`proposals/20230605-rules-adoption-management-maturity-framework.md`](../../refs/falcosecurity/rules/proposals/20230605-rules-adoption-management-maturity-framework.md) |
| Contributing guidelines | [`CONTRIBUTING.md`](../../refs/falcosecurity/rules/CONTRIBUTING.md) |
| Repository ownership | [`OWNERS`](../../refs/falcosecurity/rules/OWNERS) |
