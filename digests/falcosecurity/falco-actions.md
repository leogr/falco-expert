# falco-actions Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falco-actions/`](../../refs/falcosecurity/falco-actions/) | **Commit:** `54d299d` (February 3, 2026)

**Repository:** [falcosecurity/falco-actions](https://github.com/falcosecurity/falco-actions)
**Scope:** Ecosystem
**Status:** Sandbox

GitHub Actions to run Falco in CI/CD workflows for detecting Software Supply Chain attacks.

---

## NOTICE: Experimental Project

**This project is experimental and may not be tied to the latest Falco version.**

- Status is **Sandbox** (early development)
- Useful as a **real-world Falco use case** for CI/CD security
- Rules are work-in-progress (intended for eventual donation to falcosecurity/rules)
- Not necessarily compatible with all Falco versions

**Recommended for:** Understanding Falco CI/CD use cases, experimentation, security research.

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md), Repository badges

---

## Overview

Falco Actions provides GitHub Actions to monitor GitHub runners and detect suspicious behavior during CI/CD workflow execution. It uses Falco with ad-hoc rules specific to CI/CD security threats.

**Key capabilities:**
- Real-time monitoring of GitHub runner activity
- Detection of Software Supply Chain attacks
- CI/CD-specific Falco rules for workflow security
- Detailed security reports with external integrations (OpenAI, VirusTotal)
- Correlation of Falco events to workflow steps

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md)

## Architecture

Three GitHub Actions are provided:

| Action | Purpose |
|--------|---------|
| `start` | Start Falco (live mode) or Sysdig capture (analyze mode) |
| `stop` | Stop monitoring and generate summary (live) or upload capture (analyze) |
| `analyze` | Process captured events and generate detailed report |

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md)

## Modes of Operation

### Live Mode

Real-time protection for a single job. Falco runs in a Docker container using the `modern_ebpf` probe.

```
┌─────────────────────────────────────────┐
│            GitHub Job                   │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │ start   │→ │  your   │→ │  stop   │  │
│  │ action  │  │  steps  │  │ action  │  │
│  └────┬────┘  └─────────┘  └────┬────┘  │
│       │                         │       │
│       ▼                         ▼       │
│  ┌─────────────────────────────────┐    │
│  │  Falco (modern_ebpf, Docker)   │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
              ↓
        Job Summary
   (triggered Falco rules)
```

**Example:**
```yaml
jobs:
  foo:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
    steps:
    - name: Start Falco
      uses: falcosecurity/falco-actions/start@<commit-sha>
      with:
        mode: live
        falco-version: '0.39.0'

    # ... Your steps here ...

    - name: Stop Falco
      uses: falcosecurity/falco-actions/stop@<commit-sha>
      with:
        mode: live
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md), [`start/action.yaml`](../../refs/falcosecurity/falco-actions/start/action.yaml)

### Analyze Mode

Detailed reporting with captured events. Uses Sysdig to capture system events to a `.scap` file, then analyzes offline with Falco.

```
┌─────────────────────────────────────────┐
│          Protected Job                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  │
│  │ start   │→ │  your   │→ │  stop   │  │
│  │ analyze │  │  steps  │  │ analyze │  │
│  └────┬────┘  └─────────┘  └────┬────┘  │
│       │                         │       │
│       ▼                         ▼       │
│  ┌─────────────────────┐  ┌──────────┐  │
│  │ Sysdig (capture)   │  │ artifact │  │
│  └─────────────────────┘  └────┬─────┘  │
└────────────────────────────────│────────┘
                                 ▼
┌─────────────────────────────────────────┐
│          Analyze Job                    │
│  ┌─────────────────────────────────┐    │
│  │  analyze action                 │    │
│  │  - Falco (replay mode)          │    │
│  │  - Extract connections/DNS      │    │
│  │  - Extract processes/files      │    │
│  │  - OpenAI summary (optional)    │    │
│  │  - VirusTotal lookup (optional) │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
              ↓
        Detailed Report
```

**Example:**
```yaml
jobs:
  foo:
    runs-on: ubuntu-latest
    steps:
    - name: Start Falco
      uses: falcosecurity/falco-actions/start@<commit-sha>
      with:
        mode: analyze

    # ... Your steps here ...

    - name: Stop Falco
      uses: falcosecurity/falco-actions/stop@<commit-sha>
      with:
        mode: analyze

  analyze-foo:
    needs: foo
    runs-on: ubuntu-latest
    steps:
    - name: Analyze
      uses: falcosecurity/falco-actions/analyze@<commit-sha>
      with:
        falco-version: '0.39.0'
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}  # optional
        VT_API_KEY: ${{ secrets.VT_API_KEY }}          # optional
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md)

## Action Inputs

### Start Action

| Input | Description | Default |
|-------|-------------|---------|
| `mode` | Operation mode (`live` or `analyze`) | `live` |
| `falco-version` | Falco version (live mode) | `latest` |
| `sysdig-version` | Sysdig version (analyze mode) | `latest` |
| `config-file` | Syscall filter config (analyze mode) | `src/syscall_ignore.config` |
| `custom-rule-file` | Custom Falco rules file | (empty) |
| `cicd-rules` | Load default CI/CD rules | `true` |
| `verbose` | Enable verbose logs | `false` |

**Source:** [`start/action.yaml`](../../refs/falcosecurity/falco-actions/start/action.yaml)

### Stop Action

| Input | Description | Default |
|-------|-------------|---------|
| `mode` | Operation mode (`live` or `analyze`) | `live` |
| `verbose` | Enable verbose logs | `false` |

**Source:** [`stop/action.yaml`](../../refs/falcosecurity/falco-actions/stop/action.yaml)

### Analyze Action

| Input | Description | Default |
|-------|-------------|---------|
| `falco-version` | Falco version to use | `latest` |
| `custom-rule-file` | Custom Falco rules file | (empty) |
| `filters-config` | Filter configuration file | `src/filters.config` |
| `extract-connections` | Extract outbound connections | `true` |
| `extract-processes` | Extract spawned processes | `true` |
| `extract-dns` | Extract DNS queries | `true` |
| `extract-containers` | Extract container images | `true` |
| `extract-written-files` | Extract written files | `false` |
| `extract-chisels` | Extract sysdig chisel data | `false` |
| `extract-hashes` | Extract executable hashes | `false` |
| `openai-model` | OpenAI model for summary | `gpt-3.5-turbo` |
| `openai-user-prompt` | Custom prompt for OpenAI | (empty) |
| `verbose` | Enable verbose logs | `false` |

**Source:** [`analyze/action.yaml`](../../refs/falcosecurity/falco-actions/analyze/action.yaml)

## CI/CD Security Rules

Default rules for detecting CI/CD-specific threats (tagged with `CI/CD`):

| Rule | Description | Priority |
|------|-------------|----------|
| **Source Code Overwrite** | Detects writes to `/home/runner/work/` | WARNING |
| **Possible Workflow File Overwrite** | Detects writes to `.github/workflows/` | WARNING |
| **Git Pushing to Repository** | Detects `git push` commands | WARNING |
| **Process Reading Environment Variables of Others** | Detects reading `/proc/*/environ` | WARNING |
| **Process Dumping Memory of Others** | Detects reading `/proc/*/mem` | WARNING |
| **Suspicious Process Reading GitHub Token** | Detects reading `.git/config` by non-git processes | WARNING |
| **Grep Looking for GitHub Secrets** | Detects grep for `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_` | WARNING |

**Required engine version:** 0.44.0

**Source:** [`rules/falco_cicd_rules.yaml`](../../refs/falcosecurity/falco-actions/rules/falco_cicd_rules.yaml)

## Report Contents

The analyze mode report includes:

| Section | Description | Optional |
|---------|-------------|----------|
| **Falco Events** | Triggered rules correlated to workflow steps | No |
| **Processes** | Spawned processes with paths and users | No |
| **Contacted IPs** | Outbound connections with process info | No |
| **Contacted DNS Domains** | DNS queries extracted from UDP traffic | No |
| **Containers** | Docker images spawned during execution | No |
| **Written Files** | Files created/modified | Yes |
| **Executable Hashes** | SHA256 of spawned executables | Yes |
| **OpenAI Summary** | AI-generated report summary | Yes (requires API key) |
| **VirusTotal Reputation** | IP and hash reputation | Yes (requires API key) |

**Source:** [`analyze/action.yaml`](../../refs/falcosecurity/falco-actions/analyze/action.yaml)

## Filtering and Exceptions

### Syscall Filtering (Capture)

Reduce capture size by filtering noisy syscalls:

```json
{
    "ignore_syscalls": [
        "switch",
        "rt_sigprocmask",
        "clock_gettime",
        "rt_sigaction",
        "waitid",
        "getpid",
        "clock_getres",
        "mprotect",
        "gettimeofday",
        "close",
        "time",
        "getdents64",
        "clock_nanosleep"
    ]
}
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md)

### Report Filtering (Analyze)

Apply Falco conditions to filter report entries:

```json
{
  "outbound_connections": [
    {
      "description": "Filter connections from pythonist",
      "condition": "proc.name in (pythonist, dragent)"
    }
  ],
  "written_files": [
    {
      "description": "Filter GitHub runner writes",
      "condition": "fd.name startswith '/home/runner/runners/'"
    }
  ],
  "processes": [
    {
      "description": "Whitelist noisy processes",
      "condition": "proc.name in (sysdig, systemd-logind, ...)"
    }
  ]
}
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md)

## Technical Implementation

### Live Mode

- Uses `falcosecurity/falco-no-driver` Docker image
- Runs with `--privileged` flag
- Uses `modern_ebpf` engine
- Mounts `/proc`, `/etc`, `/var/run/docker.sock`
- Outputs JSON to `/tmp/falco_events.json`

**Source:** [`start/action.yaml:73-91`](../../refs/falcosecurity/falco-actions/start/action.yaml)

### Analyze Mode

**Capture phase:**
- Uses `sysdig/sysdig` Docker image
- Captures to `/tmp/capture.scap` with `--modern-bpf`
- Applies syscall filters via command-line filter

**Analysis phase:**
- Downloads capture artifact
- Runs Falco in replay mode: `engine.kind=replay`
- Extracts data using sysdig filters and chisels
- Correlates events to GitHub workflow steps via API

**Source:** [`start/action.yaml:107-185`](../../refs/falcosecurity/falco-actions/start/action.yaml), [`analyze/action.yaml`](../../refs/falcosecurity/falco-actions/analyze/action.yaml)

## Required Permissions

```yaml
permissions:
  contents: read   # Read repository content
  actions: read    # Correlate events to workflow steps
```

The `actions: read` permission allows querying the GitHub API to retrieve step timestamps for event correlation.

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md)

## External Integrations

### OpenAI

Generate human-readable report summaries:

```yaml
env:
  OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
with:
  openai-model: "gpt-3.5-turbo"
  openai-user-prompt: "Add remediation steps"
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md)

### VirusTotal

Get reputation for IPs and file hashes:

```yaml
env:
  VT_API_KEY: ${{ secrets.VT_API_KEY }}
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md)

## Use Case: Software Supply Chain Security

This project demonstrates a practical Falco use case for CI/CD security:

1. **Threat Model:** Malicious code execution during CI/CD (dependency confusion, compromised actions, poisoned builds)

2. **Detection Strategy:**
   - Monitor all system activity on GitHub runners
   - Apply CI/CD-specific detection rules
   - Track network connections, file writes, process execution
   - Correlate suspicious activity to workflow steps

3. **Response Options:**
   - Review triggered rules in job summary
   - Investigate detailed reports with OpenAI analysis
   - Check reputation of contacted IPs and file hashes
   - Fail workflows on high-severity detections

**Source:** [`README.md`](../../refs/falcosecurity/falco-actions/README.md), [`rules/README.md`](../../refs/falcosecurity/falco-actions/rules/README.md)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, examples | [`README.md`](../../refs/falcosecurity/falco-actions/README.md) |
| Start action | [`start/action.yaml`](../../refs/falcosecurity/falco-actions/start/action.yaml) |
| Stop action | [`stop/action.yaml`](../../refs/falcosecurity/falco-actions/stop/action.yaml) |
| Analyze action | [`analyze/action.yaml`](../../refs/falcosecurity/falco-actions/analyze/action.yaml) |
| CI/CD rules | [`rules/falco_cicd_rules.yaml`](../../refs/falcosecurity/falco-actions/rules/falco_cicd_rules.yaml) |
| Rules readme | [`rules/README.md`](../../refs/falcosecurity/falco-actions/rules/README.md) |

## Related Documentation

- [`falco/configuration.md`](falco/configuration.md) - Falco configuration (json_output, file_output)
- [`falco/rule-language.md`](falco/rule-language.md) - Writing custom Falco rules
- [`libs/modern-bpf.md`](libs/modern-bpf.md) - Modern eBPF driver used in live mode
- [`libs/scap-file-format.md`](libs/scap-file-format.md) - Capture file format used in analyze mode
