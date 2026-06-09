# CI/CD GitHub Actions

> GitHub Actions for CI/CD security and testing: falco-actions for supply chain protection, CI/CD-specific detection rules, and the falcosecurity/testing regression suite.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco-actions/`](../refs/falcosecurity/falco-actions/), [`refs/falcosecurity/testing/`](../refs/falcosecurity/testing/)

## Overview

Two GitHub Actions projects serve distinct roles in the Falco CI/CD ecosystem:

| Component | Repository | Scope | Status | Purpose |
|-----------|-----------|-------|--------|---------|
| **Falco Actions** | [falcosecurity/falco-actions](https://github.com/falcosecurity/falco-actions) | Ecosystem | Sandbox | CI/CD security monitoring and supply chain attack detection |
| **Testing** | [falcosecurity/testing](https://github.com/falcosecurity/testing) | Infra | Incubating | Black-box regression test suite for Falco and ecosystem tools |

**Falco Actions** is experimental. It provides GitHub Actions that run Falco on GitHub runners to detect Software Supply Chain attacks during CI/CD workflow execution. It ships ad-hoc detection rules specific to CI/CD threats and is not necessarily tied to the latest Falco version. It is useful as a real-world Falco use case for CI/CD security, experimentation, and security research.

**Testing** is a Go-based, code-generated test suite that validates Falco, falcoctl, plugins, and drivers through end-to-end black-box tests. It is consumed as a submodule by falcosecurity/falco and provides a composite GitHub Action for CI integration. In era 0.44, the gRPC output has been removed entirely from Falco ([PR #3798](https://github.com/falcosecurity/falco/pull/3798)); testing has been updated accordingly.

**Source:** [`digests/falcosecurity/falco-actions.md`](../digests/falcosecurity/falco-actions.md), [`digests/falcosecurity/testing.md`](../digests/falcosecurity/testing.md)

## Falco Actions

Three GitHub Actions compose the falco-actions suite:

| Action | Purpose |
|--------|---------|
| `start` | Start Falco (live mode) or Sysdig capture (analyze mode) |
| `stop` | Stop monitoring and generate summary (live) or upload capture artifact (analyze) |
| `analyze` | Process captured events offline and generate a detailed report |

Two operational modes are available:

- **Live Mode** -- Falco runs in a Docker container with `modern_ebpf` for real-time monitoring of a single job. Events are captured as they happen and a job summary of triggered rules is produced.
- **Analyze Mode** -- Sysdig captures all system events to a `.scap` file during one job, then a separate analysis job replays the capture through Falco offline, correlates events to workflow steps, and produces a detailed report with optional external enrichment.

**Source:** [`README.md`](../refs/falcosecurity/falco-actions/README.md), [`start/action.yaml`](../refs/falcosecurity/falco-actions/start/action.yaml), [`stop/action.yaml`](../refs/falcosecurity/falco-actions/stop/action.yaml), [`analyze/action.yaml`](../refs/falcosecurity/falco-actions/analyze/action.yaml)

### Action Inputs

#### Start Action

| Input | Description | Default |
|-------|-------------|---------|
| `mode` | Operation mode (`live` or `analyze`) | `live` |
| `falco-version` | Falco version (live mode) | `latest` |
| `sysdig-version` | Sysdig version (analyze mode) | `latest` |
| `config-file` | Syscall filter config (analyze mode) | `src/syscall_ignore.config` |
| `custom-rule-file` | Custom Falco rules file | (empty) |
| `cicd-rules` | Load default CI/CD rules | `true` |
| `verbose` | Enable verbose logs | `false` |

**Source:** [`start/action.yaml`](../refs/falcosecurity/falco-actions/start/action.yaml)

#### Stop Action

| Input | Description | Default |
|-------|-------------|---------|
| `mode` | Operation mode (`live` or `analyze`) | `live` |
| `verbose` | Enable verbose logs | `false` |

**Source:** [`stop/action.yaml`](../refs/falcosecurity/falco-actions/stop/action.yaml)

#### Analyze Action

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

**Source:** [`analyze/action.yaml`](../refs/falcosecurity/falco-actions/analyze/action.yaml)

## Live Mode

Live mode provides real-time protection within a single GitHub Actions job. Falco runs inside a Docker container using the `modern_ebpf` probe and monitors all system activity for the duration of the job.

### Technical Details

- Uses the `falcosecurity/falco-no-driver` Docker image
- Runs with the `--privileged` flag (required for `modern_ebpf`)
- Mounts `/proc`, `/etc`, `/var/run/docker.sock` from the host
- Outputs JSON events to `/tmp/falco_events.json`

**Source:** [`start/action.yaml:73-91`](../refs/falcosecurity/falco-actions/start/action.yaml)

### Workflow Pattern

```
Start Action → User Steps → Stop Action → Job Summary
```

```yaml
jobs:
  protected-job:
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

    # ... user steps monitored by Falco ...

    - name: Stop Falco
      uses: falcosecurity/falco-actions/stop@<commit-sha>
      with:
        mode: live
```

The stop action terminates the Falco container and produces a GitHub job summary listing all triggered Falco rules.

**Source:** [`README.md`](../refs/falcosecurity/falco-actions/README.md)

## Analyze Mode

Analyze mode separates event capture from analysis across two jobs, enabling detailed reporting with external integrations.

### Capture Phase

- Uses the `sysdig/sysdig` Docker image
- Captures to `/tmp/capture.scap` with `--modern-bpf`
- Applies syscall filters from a configuration file to reduce capture size
- The stop action uploads the `.scap` file as a GitHub Actions artifact

**Source:** [`start/action.yaml:107-185`](../refs/falcosecurity/falco-actions/start/action.yaml)

### Analysis Phase

- Downloads the capture artifact from the preceding job
- Runs Falco in replay mode (`engine.kind=replay`) against the `.scap` file
- Extracts data using sysdig filters and chisels (processes, connections, DNS, containers, files, hashes)
- Correlates Falco events to GitHub workflow steps via the GitHub API (requires `actions: read` permission)
- Optionally enriches the report with OpenAI summaries and VirusTotal reputation lookups

**Source:** [`analyze/action.yaml`](../refs/falcosecurity/falco-actions/analyze/action.yaml)

### Two-Job Workflow Pattern

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│        Protected Job            │     │        Analyze Job              │
│                                 │     │                                 │
│  start (analyze) → steps →     │────►│  analyze action:                │
│  stop (analyze, upload .scap)  │     │  - Falco replay                 │
│                                 │     │  - Data extraction              │
│  Sysdig captures to .scap      │     │  - Step correlation             │
└─────────────────────────────────┘     │  - OpenAI summary (optional)    │
                                        │  - VirusTotal lookup (optional) │
                                        └─────────────────────────────────┘
                                                      │
                                                      ▼
                                                Detailed Report
```

```yaml
jobs:
  protected-job:
    runs-on: ubuntu-latest
    steps:
    - name: Start Capture
      uses: falcosecurity/falco-actions/start@<commit-sha>
      with:
        mode: analyze

    # ... user steps captured by Sysdig ...

    - name: Stop Capture
      uses: falcosecurity/falco-actions/stop@<commit-sha>
      with:
        mode: analyze

  analyze-job:
    needs: protected-job
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

**Source:** [`README.md`](../refs/falcosecurity/falco-actions/README.md)

## CI/CD Detection Rules

Seven detection rules ship with falco-actions, all tagged `CI/CD` with `WARNING` priority. They require engine version 0.43.0 (the falco-actions repo has not yet been bumped to the 0.44 engine version 0.62.0; rules remain compatible).

| Rule | Description |
|------|-------------|
| **Source Code Overwrite** | Detects writes to `/home/runner/work/` |
| **Possible Workflow File Overwrite** | Detects writes to `.github/workflows/` |
| **Git Pushing to Repository** | Detects `git push` commands |
| **Process Reading Environment Variables of Others** | Detects reading `/proc/*/environ` |
| **Process Dumping Memory of Others** | Detects reading `/proc/*/mem` |
| **Suspicious Process Reading GitHub Token** | Detects reading `.git/config` by non-git processes |
| **Grep Looking for GitHub Secrets** | Detects grep for token prefixes (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`) |

These rules target the CI/CD threat model: malicious code execution during workflows (dependency confusion, compromised actions, poisoned builds). They are intended for eventual donation to falcosecurity/rules.

**Source:** [`rules/falco_cicd_rules.yaml`](../refs/falcosecurity/falco-actions/rules/falco_cicd_rules.yaml), [`rules/README.md`](../refs/falcosecurity/falco-actions/rules/README.md)

## External Integrations

### OpenAI

The analyze action can generate a human-readable summary of the security report using OpenAI's API.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `openai-model` | Model to use for summarization | `gpt-3.5-turbo` |
| `openai-user-prompt` | Custom prompt appended to the system prompt | (empty) |

Requires the `OPENAI_API_KEY` environment variable.

**Source:** [`README.md`](../refs/falcosecurity/falco-actions/README.md), [`analyze/action.yaml`](../refs/falcosecurity/falco-actions/analyze/action.yaml)

### VirusTotal

The analyze action can look up reputation data for IP addresses contacted during the workflow and SHA256 hashes of executables spawned.

Requires the `VT_API_KEY` environment variable.

**Source:** [`README.md`](../refs/falcosecurity/falco-actions/README.md)

## Report Contents

The analyze mode report includes the following sections:

| Section | Description | Optional |
|---------|-------------|----------|
| **Falco Events** | Triggered rules correlated to specific workflow steps | No |
| **Processes** | Spawned processes with paths and users | No |
| **Contacted IPs** | Outbound connections with originating process info | No |
| **DNS Domains** | DNS queries extracted from UDP traffic | No |
| **Containers** | Docker images spawned during execution | No |
| **Written Files** | Files created or modified during execution | Yes |
| **Executable Hashes** | SHA256 hashes of spawned executables | Yes |
| **OpenAI Summary** | AI-generated human-readable report summary | Yes (requires `OPENAI_API_KEY`) |
| **VirusTotal Reputation** | IP and hash reputation lookup results | Yes (requires `VT_API_KEY`) |

**Source:** [`analyze/action.yaml`](../refs/falcosecurity/falco-actions/analyze/action.yaml)

## Testing Infrastructure

The [falcosecurity/testing](https://github.com/falcosecurity/testing) repository provides a Go-based, black-box testing suite for Falco and ecosystem tools. Tests are defined as Go code, and test binaries are generated via `go generate ./...`.

### Test Binaries

| Binary | Target Component | Description |
|--------|-----------------|-------------|
| `falco.test` | Falco | Main Falco executable regression tests |
| `falcoctl.test` | falcoctl | Falco CLI tool tests |
| `k8saudit.test` | k8saudit plugin | Kubernetes audit plugin tests |
| `dummy.test` | dummy plugin | Dummy plugin tests |
| `falco-driver-loader.test` | drivers | Driver loader tests (requires kernel headers) |

**Source:** [`README.md`](../refs/falcosecurity/testing/README.md), [`action.yml:88-111`](../refs/falcosecurity/testing/action.yml)

### Runner Interface

The `Runner` interface abstracts executable invocation, enabling tests to run against local binaries or Docker containers:

```go
type Runner interface {
    Run(ctx context.Context, options ...RunnerOption) error
    WorkDir() string
}
```

| Implementation | Description |
|---------------|-------------|
| `ExecutableRunner` | Runs local executable binaries directly |
| `DockerRunner` | Runs executables within Docker containers |

Runner options include `WithFiles()`, `WithArgs()`, `WithStdout()`, `WithStderr()`, and `WithEnvVars()`.

**Source:** [`pkg/run/runner.go:39-47`](../refs/falcosecurity/testing/pkg/run/runner.go), [`pkg/run/executable.go`](../refs/falcosecurity/testing/pkg/run/executable.go), [`pkg/run/docker.go`](../refs/falcosecurity/testing/pkg/run/docker.go)

## Test Harness

The `falco.Test()` function is the primary entry point for running Falco under test conditions:

```go
func Test(runner run.Runner, options ...TestOption) *TestOutput
```

Default behaviors: uses `/etc/falco/falco.yaml` as config, enforces debug logging on stderr, enables stdout output, and sets a 5-minute maximum duration.

**Source:** [`pkg/falco/tester.go:69-115`](../refs/falcosecurity/testing/pkg/falco/tester.go)

### TestOptions

| Option | Purpose |
|--------|---------|
| `WithRules(rules ...FileAccessor)` | Load rules files via `-r` |
| `WithConfig(f FileAccessor)` | Use config file via `-c` |
| `WithCaptureFile(f FileAccessor)` | Replay capture file via `engine.kind=replay` |
| `WithOutputJSON()` | Enable JSON output format |
| `WithRulesValidation(rules ...FileAccessor)` | Validate rules via `-V` |
| `WithArgs(args ...string)` | Pass additional CLI arguments |
| `WithEnabledTags(tags ...string)` | Enable rules by tag |
| `WithDisabledTags(tags ...string)` | Disable rules by tag |
| `WithDisabledRules(rules ...string)` | Disable specific rules |
| `WithMinRulePriority(priority string)` | Set minimum rule priority |
| `WithContextDeadline(duration)` | Set maximum run duration |
| `WithStopAfter(duration)` | Stop Falco after duration (`-M`) |
| `WithAllEvents()` | Enable all syscalls via `base_syscalls.all=true` |
| `WithPrometheusMetrics()` | Enable Prometheus metrics endpoint |
| `WithEnvVars(vars map[string]string)` | Set environment variables |

**Source:** [`pkg/falco/tester_options.go`](../refs/falcosecurity/testing/pkg/falco/tester_options.go)

### TestOutput

```go
// Error handling
Err() error                    // Returns error if Falco run failed
ExitCode() int                 // Returns Falco exit code
DurationExceeded() bool        // True if context deadline exceeded

// Output access
Stdout() string                // Raw stdout
Stderr() string                // Raw stderr
StdoutJSON() map[string]interface{}  // Parsed JSON stdout
```

**Source:** [`pkg/falco/tester_output.go`](../refs/falcosecurity/testing/pkg/falco/tester_output.go)

### Detection Assertions

When `WithOutputJSON()` is used, detection assertions are available via the `Detections()` method:

```go
type Alert struct {
    Time         time.Time
    Rule         string
    Output       string
    Priority     string
    Source       string
    Hostname     string
    Tags         []string
    OutputFields map[string]interface{}
}

Detections() Detections                    // Parse alerts from stdout JSON
OfPriority(p string) Detections            // Filter by priority level
OfRule(v interface{}) Detections           // Filter by rule name (string or *regexp.Regexp)
Count() int                                // Number of matching alerts
```

**Source:** [`pkg/falco/tester_output_detection.go`](../refs/falcosecurity/testing/pkg/falco/tester_output_detection.go)

## CI Integration

The testing repository provides a composite GitHub Action (`falcosecurity/testing@main`) for use in CI pipelines. Since no annotated tags are published, reference by branch name or commit hash.

### Action Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `test-falco` | Run Falco tests | `true` |
| `test-falcoctl` | Run falcoctl tests | `false` |
| `test-k8saudit` | Run k8saudit plugin tests | `false` |
| `test-dummy` | Run dummy plugin tests | `false` |
| `test-drivers` | Run driver tests (requires kernel headers) | `false` |
| `static` | Static mode (Falco tests only) | `false` |
| `show-all` | Show all tests in summary | `false` |
| `sudo` | Sudo command to use | `sudo` |

### Action Outputs

| Output | Description |
|--------|-------------|
| `report` | Path to generated JUnit XML report |
| `out_file` | Path to full test output file |

**Source:** [`action.yml`](../refs/falcosecurity/testing/action.yml)

### Usage in Falco CI

The testing suite is consumed as a git submodule in `falcosecurity/falco` at `submodules/falcosecurity-testing`. The synchronization workflow is:

1. When Falco changes break tests, update tests in the testing repository
2. Open PR and merge the test fix
3. Bump the submodule reference in falcosecurity/falco:
   ```bash
   cd submodules/falcosecurity-testing
   git fetch && git merge origin/main
   ```
4. Include the submodule update in the Falco PR

**Era 0.44 note:** Falco 0.44 fully removes the gRPC output and gRPC server from Falco ([PR #3798](https://github.com/falcosecurity/falco/pull/3798)). The testing submodule was previously updated (commit `2f1fba01`, February 5, 2026) to remove all gRPC references, in lockstep with the 0.43 deprecation; in 0.44 the cleanup is permanent.

**Source:** [`README.md`](../refs/falcosecurity/testing/README.md)

## Related Specs

- [`kernel-instrumentation.md`](kernel-instrumentation.md) -- Modern eBPF driver used in live mode and driver loader tests
- [`rule-engine.md`](rule-engine.md) -- Rule language and engine version requirements for CI/CD rules
- [`configuration.md`](configuration.md) -- Falco configuration options (JSON output, file output, replay mode)
- [`cli-interface.md`](cli-interface.md) -- Falco CLI flags used by the test harness
- [`build-system.md`](build-system.md) -- Build system and test integration

## Sources

| Topic | Source File |
|-------|-------------|
| Falco Actions overview | [`README.md`](../refs/falcosecurity/falco-actions/README.md) |
| Start action inputs | [`start/action.yaml`](../refs/falcosecurity/falco-actions/start/action.yaml) |
| Stop action inputs | [`stop/action.yaml`](../refs/falcosecurity/falco-actions/stop/action.yaml) |
| Analyze action inputs | [`analyze/action.yaml`](../refs/falcosecurity/falco-actions/analyze/action.yaml) |
| CI/CD detection rules | [`rules/falco_cicd_rules.yaml`](../refs/falcosecurity/falco-actions/rules/falco_cicd_rules.yaml) |
| CI/CD rules readme | [`rules/README.md`](../refs/falcosecurity/falco-actions/rules/README.md) |
| Testing overview | [`README.md`](../refs/falcosecurity/testing/README.md) |
| Testing GitHub Action | [`action.yml`](../refs/falcosecurity/testing/action.yml) |
| Runner interface | [`pkg/run/runner.go`](../refs/falcosecurity/testing/pkg/run/runner.go) |
| Executable runner | [`pkg/run/executable.go`](../refs/falcosecurity/testing/pkg/run/executable.go) |
| Docker runner | [`pkg/run/docker.go`](../refs/falcosecurity/testing/pkg/run/docker.go) |
| Falco test harness | [`pkg/falco/tester.go`](../refs/falcosecurity/testing/pkg/falco/tester.go) |
| Test options | [`pkg/falco/tester_options.go`](../refs/falcosecurity/testing/pkg/falco/tester_options.go) |
| Test output | [`pkg/falco/tester_output.go`](../refs/falcosecurity/testing/pkg/falco/tester_output.go) |
| Detection assertions | [`pkg/falco/tester_output_detection.go`](../refs/falcosecurity/testing/pkg/falco/tester_output_detection.go) |
| Test entry point, CLI flags | [`tests/tests.go`](../refs/falcosecurity/testing/tests/tests.go) |
| Falco Actions digest | [`digests/falcosecurity/falco-actions.md`](../digests/falcosecurity/falco-actions.md) |
| Testing digest | [`digests/falcosecurity/testing.md`](../digests/falcosecurity/testing.md) |
