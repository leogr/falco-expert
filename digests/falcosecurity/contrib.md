# contrib Digest

> **Era Relevance:** 0.44 (OUTDATED) | **Source:** [`refs/falcosecurity/contrib/`](../../refs/falcosecurity/contrib/) | **Commit:** `eb584b5` (December 5, 2025)

**Repository:** [falcosecurity/contrib](https://github.com/falcosecurity/contrib)
**Scope:** Ecosystem
**Status:** Sandbox

---

## CRITICAL WARNING: EXPERIMENTAL AND UNTESTED CONTENT

**DO NOT USE THIS CODE IN PRODUCTION.**

This repository contains community experiments that have:
- **Never been formally tested** for correctness or security
- **Never been maintained** beyond sporadic dependency bumps
- **Code dating back to 2018-2019** referencing deprecated Kubernetes versions (1.11, 1.13)
- **References to deprecated/removed Falco features** (gRPC output was removed in Falco 0.44.0, deprecated in 0.43.0)
- **Kubernetes features that no longer exist** (DynamicAuditing was removed in K8s 1.19)

**This content is preserved ONLY for historical context.** If you need:
- Kubernetes deployment: Use [`falcosecurity/deploy-kubernetes`](https://github.com/falcosecurity/deploy-kubernetes) or [`falcosecurity/charts`](https://github.com/falcosecurity/charts)
- K8s audit integration: Use the [k8saudit plugin](https://github.com/falcosecurity/plugins/tree/main/plugins/k8saudit) with modern webhook configuration
- Log forwarding: Use [falcosidekick](https://github.com/falcosecurity/falcosidekick)

**Source:** [`README.md`](../../refs/falcosecurity/contrib/README.md)

---

## Repository Purpose (Historical)

A place for the community to "test-drive" experimental ideas, projects, and code. All contributions have Sandbox status - meaning experimental, no stability guarantees, and potentially abandoned.

**Source:** [`README.md`](../../refs/falcosecurity/contrib/README.md)

## Directory Structure

| Directory | Status | Description |
|-----------|--------|-------------|
| [`/deploy`](../../refs/falcosecurity/contrib/deploy/) | **MOVED** | Kubernetes manifests (now at `falcosecurity/deploy-kubernetes`) |
| [`/examples`](../../refs/falcosecurity/contrib/examples/) | **OUTDATED** | Demo scenarios and attack simulations |
| [`/integrations`](../../refs/falcosecurity/contrib/integrations/) | **OUTDATED/BROKEN** | Third-party tool integrations |
| [`/usage-metrics`](../../refs/falcosecurity/contrib/usage-metrics/) | **INTERNAL** | Falco download statistics tools (requires S3 access) |

## Examples (Historical, OUTDATED)

### bad-mount-cryptomining

Docker-compose demo showing how Falco detects cryptomining exploits via sensitive mount detection.

**Architecture:**
- `host-machine`: Docker-in-docker simulating a vulnerable host with exposed Docker API
- `attacker-server`: Nginx serving malicious scripts
- `falco`: Falco instance detecting the attack

**Attack flow:**
1. Attacker creates container with `/etc` mounted
2. Container modifies cron to download/run cryptominer
3. Falco detects "Container with sensitive mount started"

**WARNING:** This demo uses Docker Engine >= 1.13.0 patterns and may not work with modern Docker/containerd.

**Source:** [`examples/bad-mount-cryptomining/README.md`](../../refs/falcosecurity/contrib/examples/bad-mount-cryptomining/README.md)

### k8s_audit_config

Scripts and configurations for Kubernetes audit log integration with Falco.

**CRITICAL: SEVERELY OUTDATED**
- References Kubernetes 1.11 and 1.13 (EOL since 2019-2020)
- Uses `DynamicAuditing` feature gate (removed in Kubernetes 1.19)
- Uses `AuditSink` API (removed in Kubernetes 1.19)
- Manual API server patching approach is obsolete

**Modern alternative:** Use the [k8saudit plugin](https://github.com/falcosecurity/plugins/tree/main/plugins/k8saudit) which supports:
- Webhook mode (receives audit events via HTTP)
- Log file mode (reads from audit log file)

**Source:** [`examples/k8s_audit_config/README.md`](../../refs/falcosecurity/contrib/examples/k8s_audit_config/README.md)

### Other Examples

| Example | Description | Status |
|---------|-------------|--------|
| `mitm-sh-installer` | Demo of man-in-the-middle attacks on curl\|bash installers | **OUTDATED** |
| `nodejs-bad-rest-api` | Vulnerable Node.js API for Falco demo | **OUTDATED** |

## Integrations (Historical, BROKEN/OUTDATED)

### anchore-falco

Python tool that generates Falco rules from Anchore policy evaluation results.

**Purpose:** Block containers that fail Anchore security scanning.

**WARNINGS:**
- Requires Python 3.6 and pipenv (outdated)
- Anchore-engine API may have changed
- Generated rule format may be incompatible with current Falco

**Source:** [`integrations/anchore-falco/README.md`](../../refs/falcosecurity/contrib/integrations/anchore-falco/README.md)

### falco-phoenix-sidecar

Kubernetes sidecar that annotates Pods when Falco detects events affecting them.

**WARNINGS:**
- **Uses gRPC output, which was removed in Falco 0.44.0** (deprecated in 0.43.0)
- Phoenix operator may no longer exist
- Kustomize post-renderer approach may need updating

**Source:** [`integrations/falco-phoenix-sidecar/README.md`](../../refs/falcosecurity/contrib/integrations/falco-phoenix-sidecar/README.md)

### logdna

Integration for sending Falco alerts to LogDNA.

**WARNINGS:**
- **Uses gRPC output, which was removed in Falco 0.44.0** (deprecated in 0.43.0)
- LogDNA has been rebranded to Mezmo
- Use [falcosidekick](https://github.com/falcosecurity/falcosidekick) for modern log forwarding

**Source:** [`integrations/logdna/`](../../refs/falcosecurity/contrib/integrations/logdna/)

### puppet-module

Example Puppet module for Falco deployment.

**WARNING:** Minimal documentation, likely outdated package references.

**Source:** [`integrations/puppet-module/README.md`](../../refs/falcosecurity/contrib/integrations/puppet-module/README.md)

### logrotate

Logrotate configuration for Falco logs.

**Status:** May still be useful for file-based logging, but verify paths and syntax.

**Source:** [`integrations/logrotate/`](../../refs/falcosecurity/contrib/integrations/logrotate/)

## Usage Metrics (Internal)

Tools for Falco maintainers to analyze CloudFront distribution logs for driver download statistics.

**Requires:** AWS CLI access to `logging-falco-distribution` S3 bucket.

**Not useful for general users.**

**Source:** [`usage-metrics/distribution-logs/README.md`](../../refs/falcosecurity/contrib/usage-metrics/distribution-logs/README.md)

## Commit History Analysis

Recent commits are almost entirely automated dependency bumps:
- `protobuf`, `requests`, `certifi`, `grpcio` updates
- No significant content updates since 2021

This confirms the repository content is essentially unmaintained.

## Modern Alternatives

| Old Approach (contrib) | Modern Alternative |
|------------------------|-------------------|
| `/deploy` K8s manifests | [`deploy-kubernetes`](https://github.com/falcosecurity/deploy-kubernetes), [`charts`](https://github.com/falcosecurity/charts) |
| `k8s_audit_config` scripts | [k8saudit plugin](https://github.com/falcosecurity/plugins/tree/main/plugins/k8saudit) |
| gRPC-based integrations | HTTP webhook output, [falcosidekick](https://github.com/falcosecurity/falcosidekick) |
| LogDNA integration | falcosidekick with Mezmo/LogDNA output |
| Puppet module | Community Puppet modules or Helm charts |

## Sources

| Topic | Source File |
|-------|-------------|
| Overview | [`README.md`](../../refs/falcosecurity/contrib/README.md) |
| Cryptomining demo | [`examples/bad-mount-cryptomining/README.md`](../../refs/falcosecurity/contrib/examples/bad-mount-cryptomining/README.md) |
| K8s audit (obsolete) | [`examples/k8s_audit_config/README.md`](../../refs/falcosecurity/contrib/examples/k8s_audit_config/README.md) |
| Anchore integration | [`integrations/anchore-falco/README.md`](../../refs/falcosecurity/contrib/integrations/anchore-falco/README.md) |
| Phoenix sidecar | [`integrations/falco-phoenix-sidecar/README.md`](../../refs/falcosecurity/contrib/integrations/falco-phoenix-sidecar/README.md) |

## Related Documentation

- [`deploy-kubernetes.md`](deploy-kubernetes.md) - Modern Kubernetes deployment manifests
- [`charts.md`](charts.md) - Official Helm charts
- [`plugins/k8saudit.md`](plugins/k8saudit.md) - Modern K8s audit plugin
- [`client-go.md`](client-go.md) - Deprecated gRPC client (for context on gRPC deprecation)
