# event-generator

Testing and demonstration tool for generating synthetic security events detected by Falco rules.

**Repository:** [falcosecurity/event-generator](https://github.com/falcosecurity/event-generator)
**Version:** v0.13.0
**Era:** 0.44
**Scope:** Ecosystem
**Status:** Incubating
**Compatibility:** Requires Falco 0.37.0 or newer

## Overview

Event-generator is a CLI tool that performs a variety of suspect actions designed to trigger Falco detection rules. It serves multiple purposes:

- **Rule Validation**: Verify that Falco detection rules work as intended
- **Security Testing**: Safely simulate malicious activities in controlled environments
- **Performance Benchmarking**: Generate high-volume event traffic to measure Falco's throughput
- **Training/Demonstration**: Show Falco's detection capabilities to stakeholders

**Source:** [`README.md`](../../refs/falcosecurity/event-generator/README.md)

## Architecture

### Action Registry

Actions are registered in a central registry and organized by collection (package):

| Collection | Purpose | Source |
|------------|---------|--------|
| `syscall` | System call activity matching [default Falco ruleset](https://github.com/falcosecurity/rules) | [`events/syscall/`](../../refs/falcosecurity/event-generator/events/syscall/) |
| `k8saudit` | Kubernetes audit events matching [k8s audit rules](https://github.com/falcosecurity/plugins/blob/master/plugins/k8saudit/rules/k8s_audit_rules.yaml) | [`events/k8saudit/`](../../refs/falcosecurity/event-generator/events/k8saudit/) |
| `helper` | Basic network and execution patterns for testing | [`events/helper/`](../../refs/falcosecurity/event-generator/events/helper/) |

**Source:** [`events/registry.go`](../../refs/falcosecurity/event-generator/events/registry.go)

### Action Interface

Every action implements the `Action` type:

```go
// An Action triggers an event.
type Action func(Helper) error
```

The `Helper` interface provides utilities for actions:
- Logging (`Log()`)
- Sleeping (`Sleep()`)
- Cleanup registration (`Cleanup()`)
- Spawning child processes with different names (`SpawnAs()`, `SpawnAsWithSymlink()`)
- Kubernetes resource building (`ResourceBuilder()`)
- Container detection (`InContainer()`)

**Source:** [`events/interfaces.go:34-74`](../../refs/falcosecurity/event-generator/events/interfaces.go)

### Action Options

Actions can be registered with options:
- `WithDisabled()`: Marks an action as disabled by default (requires `--all` flag to run)

**Source:** [`events/options.go`](../../refs/falcosecurity/event-generator/events/options.go)

## CLI Commands

| Command | Purpose | Documentation |
|---------|---------|---------------|
| `list` | List available actions | [`docs/event-generator_list.md`](../../refs/falcosecurity/event-generator/docs/event-generator_list.md) |
| `run` | Execute actions | [`docs/event-generator_run.md`](../../refs/falcosecurity/event-generator/docs/event-generator_run.md) |
| `test` | Run and test actions against Falco | [`docs/event-generator_test.md`](../../refs/falcosecurity/event-generator/docs/event-generator_test.md) |
| `bench` | Benchmark Falco performance | [`docs/event-generator_bench.md`](../../refs/falcosecurity/event-generator/docs/event-generator_bench.md) |
| `suite` | Manage declaratively-specified (YAML) test suites grouped by rule (since v0.13.0); sub-commands `run`, `test`, `explain`, `yaml` | [`docs/event-generator_suite.md`](../../refs/falcosecurity/event-generator/docs/event-generator_suite.md) |

### Global Options

```
-c, --config string      Config file path (default $HOME/.falco-event-generator.yaml)
    --logformat string   Output format: "text" or "json" (default "text")
-l, --loglevel string    Log level (default "info")
```

**Source:** [`docs/event-generator.md`](../../refs/falcosecurity/event-generator/docs/event-generator.md)

## Syscall Actions

Syscall actions generate system call activity that triggers Falco's default ruleset. Each action is implemented as a Go function registered in the `syscall` package.

### Available Actions (v0.13.0)

| Action | Rule Triggered | Enabled by Default |
|--------|----------------|-------------------|
| `ReadSensitiveFileUntrusted` | Read sensitive file untrusted | Yes |
| `CreateSymlinkOverSensitiveFiles` | Create Symlink Over Sensitive Files | Yes |
| `DirectoryTraversalMonitoredFileRead` | Directory traversal monitored file read | Yes |
| `ReadSensitiveFileTrustedAfterStartup` | Read sensitive file trusted after startup | Yes |
| `WriteBelowEtc` | Write below etc | Yes |
| `WriteBelowBinaryDir` | Write below binary dir | Yes |
| `WriteBelowRpmDatabase` | Write below rpm database | Yes |
| `CreateFilesBelowDev` | Create files below dev | Yes |
| `MkdirBinaryDirs` | Mkdir binary dirs | Yes |
| `ModifyBinaryDirs` | Modify binary dirs | Yes |
| `NonSudoSetuid` | Non sudo setuid | Yes |
| `DbProgramSpawnedProcess` | DB program spawned process | Yes |
| `SystemProcsNetworkActivity` | System procs network activity | Yes |
| `SystemUserInteractive` | System user interactive | Yes |
| `UserMgmtBinaries` | User mgmt binaries | Yes |
| `SearchPrivateKeysOrPasswords` | Search Private Keys or Passwords | Yes |
| `ScheduleCronJobs` | Schedule Cron Jobs | Yes |
| `RunShellUntrusted` | Run shell untrusted | Yes |
| `ChangeThreadNamespace` | Change thread namespace | No (disabled) |
| `ChangeNamespacePrivilegesViaUnshare` | Change namespace privileges via unshare | No |
| `ContainerDriftDetected*` | Container drift detection | No |
| `DropAndExecuteNewBinaryInContainer` | Drop and execute new binary in container | No |
| `FilelessExecutionViaMemfdCreate` | Fileless execution via memfd_create | No |
| `DetectCryptoMinersUsingStratumProtocol` | Detect crypto miners using stratum protocol | No |
| ... and many more | | |

**Source:** [`events/syscall/`](../../refs/falcosecurity/event-generator/events/syscall/)

### Example Action Implementation

```go
// ReadSensitiveFileUntrusted opens /etc/shadow to trigger the rule
func ReadSensitiveFileUntrusted(h events.Helper) error {
    file, err := os.Open("/etc/shadow")
    if err != nil {
        return err
    }
    defer file.Close()
    return nil
}
```

**Source:** [`events/syscall/read_sensitive_file_untrusted.go`](../../refs/falcosecurity/event-generator/events/syscall/read_sensitive_file_untrusted.go)

### Disabled Actions

Some actions are disabled by default because:
- The corresponding rule is not in `falco_rules.yaml` (stable rules)
- They require special permissions (e.g., `CAP_SYS_ADMIN`)
- They are container-specific or require privileged containers

Use `--all` flag to include disabled actions.

**Source:** [`events/syscall/change_thread_namespace.go:29-32`](../../refs/falcosecurity/event-generator/events/syscall/change_thread_namespace.go)

## Kubernetes Audit Actions

K8saudit actions create Kubernetes resources that trigger audit log rules. Actions are auto-generated from YAML files in [`events/k8saudit/yaml/`](../../refs/falcosecurity/event-generator/events/k8saudit/yaml/).

### Available K8saudit Actions

| Action | Kubernetes Resource | Rule Triggered |
|--------|---------------------|----------------|
| `ClusterRoleWithPodExecCreated` | ClusterRole | ClusterRole With Pod Exec Created |
| `ClusterRoleWithWildcardCreated` | ClusterRole | ClusterRole With Wildcard Created |
| `ClusterRoleWithWritePrivilegesCreated` | ClusterRole | ClusterRole With Write Privileges Created |
| `CreateDisallowedPod` | Pod | Create Disallowed Pod |
| `CreateHostNetworkPod` | Pod | Create HostNetwork Pod |
| `CreateModifyConfigmapWithPrivateCredentials` | ConfigMap | Create/Modify Configmap With Private Credentials |
| `CreateNodePortService` | Service | Create NodePort Service |
| `CreatePrivilegedPod` | Deployment | Create Privileged Pod |
| `CreateSensitiveMountPod` | Pod | Create Sensitive Mount Pod |
| `K8SConfigMapCreated` | ConfigMap | K8s ConfigMap Created |
| `K8SDeploymentCreated` | Deployment | K8s Deployment Created |
| `K8SServiceCreated` | Service | K8s Service Created |
| `K8SServiceaccountCreated` | ServiceAccount | K8s ServiceAccount Created |

**Note:** All k8saudit actions are disabled by default and require `--all` flag.

**Source:** [`events/k8saudit/yaml_loader.go`](../../refs/falcosecurity/event-generator/events/k8saudit/yaml_loader.go)

### K8saudit YAML Format

K8saudit actions are defined as standard Kubernetes YAML manifests with special labels:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: privileged-deployment
  labels:
    app.kubernetes.io/part-of: falco-event-generator
    falco.org/rule: Create-Privileged-Pod
spec:
  # ... resource spec
```

**Source:** [`events/k8saudit/yaml/create-privileged-pod.yaml`](../../refs/falcosecurity/event-generator/events/k8saudit/yaml/create-privileged-pod.yaml)

### K8saudit Prerequisites

- Kubernetes cluster with [audit logging enabled](https://falco.org/docs/event-sources/kubernetes-audit/)
- Falco configured with [k8saudit plugin](https://github.com/falcosecurity/plugins/tree/master/plugins/k8saudit)
- Namespace must already exist

## Helper Actions

Helper actions provide basic network and execution patterns:

| Action | Purpose |
|--------|---------|
| `ExecLs` | Execute `ls` command |
| `NetworkActivity` | Basic network connection |
| `RunShell` | Run a shell |
| `InboundConnection` | Accept inbound connection |
| `OutboundConnection` | Make outbound connection |
| `CombinedServerClient` | Combined server/client test |

**Source:** [`events/helper/`](../../refs/falcosecurity/event-generator/events/helper/)

## Running Actions

### Basic Usage

```bash
# List all enabled actions
event-generator list

# List all actions including disabled
event-generator list --all

# Run all enabled actions
event-generator run

# Run specific actions by regex
event-generator run 'syscall.*Files.*'

# Run in a loop
event-generator run --loop --sleep 100ms
```

### Docker Usage (Recommended)

Running in Docker is recommended because some actions modify system directories (`/bin`, `/etc`, `/dev`):

```bash
# Run all syscall actions in a loop
docker run -it --rm falcosecurity/event-generator run syscall --loop

# Run specific actions
docker run -it --rm falcosecurity/event-generator run 'ReadSensitiveFile.*'
```

**Source:** [`README.md`](../../refs/falcosecurity/event-generator/README.md)

### Kubernetes Deployment

Deploy using the official Helm chart:

```bash
# Add Falco Helm repository
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Run as Kubernetes Job (one-time)
helm install event-generator falcosecurity/event-generator \
  --namespace event-generator \
  --create-namespace \
  --set config.loop=false \
  --set config.actions=""

# Run as Deployment (continuous loop)
helm install event-generator falcosecurity/event-generator \
  --namespace event-generator \
  --create-namespace \
  --set config.actions=""
```

**Source:** [`README.md`](../../refs/falcosecurity/event-generator/README.md)

## Testing Rules

The `test` command runs actions and verifies they trigger the expected Falco alerts. As of v0.13.0 it retrieves alerts over Falco's **HTTP Output** (the gRPC-based path was removed, mirroring the gRPC output removal in Falco 0.44). The command starts a local HTTP server that Falco posts alerts to:

```bash
# Test syscall actions locally (requires Falco with the HTTP Output enabled)
sudo event-generator test syscall

# Bind the alert-retriever HTTP server to a custom address
sudo event-generator test syscall --http-server-address localhost:8080

# Use TLS/mTLS for the Falco -> event-generator alert channel
sudo event-generator test syscall --http-server-security-mode mtls

# Test in Kubernetes
helm install event-generator falcosecurity/event-generator \
  --set config.command=test \
  --set config.loop=false
```

**Requirements:**
- A running Falco instance with the [HTTP Output](https://falco.org/docs/outputs/channels/#http-output) enabled, configured to send alerts to the event-generator's HTTP server (`--http-server-address`, default `localhost:8080`)
- Optional TLS/mTLS via `--http-server-security-mode` (`insecure`, `tls`, or `mtls`)

> Note: Upstream README sections may still reference the gRPC Output for `test`; the gRPC path was removed and Falco 0.44 dropped the gRPC output entirely.

**Source:** [`docs/event-generator_test.md`](../../refs/falcosecurity/event-generator/docs/event-generator_test.md)

## Benchmarking

The `bench` command generates high EPS (Events Per Second) to measure Falco throughput:

```bash
# Benchmark with specific fast actions
sudo event-generator bench "ChangeThreadNamespace|ReadSensitiveFileUntrusted" \
  --all --loop --sleep 10ms --pid $(pidof -s falco)
```

**Key options:**
- `--sleep`: Controls EPS (lower = higher EPS)
- `--loop`: Halves sleep duration each round for progressive stress testing
- `--pid`: Monitor the Falco process during benchmark
- `--round-duration`: Duration of each benchmark round (default 5s)

**Not all actions are suitable for benchmarking** - some take too long (k8saudit) or have built-in delays.

**Source:** [`docs/event-generator_bench.md`](../../refs/falcosecurity/event-generator/docs/event-generator_bench.md)

## Using as a Library

The tool provides importable packages:

| Package | Purpose |
|---------|---------|
| `/cmd` | CLI implementation |
| `/events` | Events registry |
| `/pkg/runner` | Action runner implementations |

**Source:** [`README.md`](../../refs/falcosecurity/event-generator/README.md)

## Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `k8s.io/client-go` | Kubernetes API client for k8saudit actions |
| `k8s.io/cli-runtime` | Kubernetes resource building |
| `spf13/cobra` | CLI framework |
| `golang.org/x/sys` | System calls (for syscall actions) |

> Note: `falcosecurity/client-go` (the Falco gRPC client) is no longer a dependency as of v0.13.0; the `test`/`suite` commands retrieve alerts over Falco's HTTP Output instead.

**Source:** [`go.mod`](../../refs/falcosecurity/event-generator/go.mod)

## Distribution

| Method | Image/Chart |
|--------|-------------|
| Docker | `falcosecurity/event-generator` |
| Helm | `falcosecurity/event-generator` (from `https://falcosecurity.github.io/charts`) |
| Binary | GitHub Releases |

**Architectures:** x86_64, aarch64

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, usage | [`README.md`](../../refs/falcosecurity/event-generator/README.md) |
| CLI documentation | [`docs/`](../../refs/falcosecurity/event-generator/docs/) |
| Action registry | [`events/registry.go`](../../refs/falcosecurity/event-generator/events/registry.go) |
| Action interface | [`events/interfaces.go`](../../refs/falcosecurity/event-generator/events/interfaces.go) |
| Syscall actions | [`events/syscall/`](../../refs/falcosecurity/event-generator/events/syscall/) |
| K8saudit actions | [`events/k8saudit/`](../../refs/falcosecurity/event-generator/events/k8saudit/) |
| Helper actions | [`events/helper/`](../../refs/falcosecurity/event-generator/events/helper/) |
| Dependencies | [`go.mod`](../../refs/falcosecurity/event-generator/go.mod) |
