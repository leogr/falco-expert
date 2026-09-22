# falco-talon Digest

> **Era Relevance:** 0.45 | **Source:** [`refs/falcosecurity/falco-talon/`](../../refs/falcosecurity/falco-talon/) | **Snapshot:** `d273e35` (post-v0.3.0 development)

**Repository:** [falcosecurity/falco-talon](https://github.com/falcosecurity/falco-talon)
**Scope:** Ecosystem
**Status:** Incubating
**Documentation:** [https://docs.falco-talon.org/](https://docs.falco-talon.org/)

Response Engine for managing threats in Kubernetes by reacting to Falco events with automated actions.

---

## NOTICE: Experimental Project

**This project is Incubating; the pinned development snapshot includes changes after the latest v0.3.0 release.**

- Status is **Incubating** (not yet stable)
- First GA release (0.1.0) was September 5, 2024
- Latest version 0.3.0 released February 5, 2025
- May have incomplete features or undocumented behaviors
- Use with appropriate expectations for an experimental response engine

**Recommended for:** Testing, evaluation, non-production environments, or environments where automated response risk is acceptable.

**Source:** [`CHANGELOG.md`](../../refs/falcosecurity/falco-talon/CHANGELOG.md), Repository badges

---

## Overview

Falco Talon is a Response Engine that receives events from Falco (or Falcosidekick) and automatically executes configured response actions. It provides a no-code, rule-based approach to threat response in Kubernetes environments.

**Key capabilities:**
- Receive Falco events via HTTP webhook
- Match events against configurable rules
- Execute automated response actions (terminate pods, create network policies, etc.)
- Notify about action results via multiple channels
- Store action artifacts (logs, tcpdump captures, files)
- Export metrics and traces (Prometheus, OTEL)

**Source:** [`README.md`](../../refs/falcosecurity/falco-talon/README.md)

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│     Falco       │────▶│  Falcosidekick  │
└─────────────────┘     └────────┬────────┘
        │                        │
        │ event                  │ event
        ▼                        ▼
┌───────────────────────────────────────────┐
│              Falco Talon                  │
│  ┌─────────┐  ┌─────────┐  ┌───────────┐  │
│  │  Rules  │─▶│ Actions │─▶│ Notifiers │  │
│  │ Engine  │  │         │  │           │  │
│  └─────────┘  └────┬────┘  └───────────┘  │
│                    │                      │
│                    ▼                      │
│              ┌───────────┐                │
│              │  Outputs  │                │
│              │ (storage) │                │
│              └───────────┘                │
└───────────────────────────────────────────┘
        │                    │
        ▼                    ▼
   Kubernetes            AWS/GCP/Minio
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-talon/README.md)

## Glossary

| Term | Description |
|------|-------------|
| **Event** | An event detected by Falco and sent to its outputs |
| **Rule** | Defines criteria for linking events with actions to apply |
| **Action** | Each rule can sequentially run actions, each refers to an actionner |
| **Actionner** | Defines what the action will do (the implementation) |
| **Notifier** | Defines where to send notifications about action results |
| **Output** | Defines where to store artifacts created by actionners |
| **Context** | Elements from the Falco event and other sources for dynamic configuration |

**Source:** [`README.md`](../../refs/falcosecurity/falco-talon/README.md)

## Actionners

Actionners are the implementations that perform response actions. Format: `<category>:<name>`

### Kubernetes Actionners

| Actionner | Description | Required Fields |
|-----------|-------------|-----------------|
| `kubernetes:terminate` | Terminate a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:label` | Add labels to a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:annotation` | Add annotations to a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:networkpolicy` | Create a NetworkPolicy to restrict pod network | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:exec` | Execute a command in a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:script` | Execute a script in a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:log` | Collect pod logs | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:delete` | Delete a Kubernetes resource | varies by resource |
| `kubernetes:cordon` | Cordon a node | hostname |
| `kubernetes:drain` | Drain a node | hostname |
| `kubernetes:download` | Download a file from a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:tcpdump` | Capture network traffic | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:sysdig` | Capture system activity with sysdig | `k8s.ns.name`, `k8s.pod.name` |

**Source:** [`actionners/actionners.go:76-94`](../../refs/falcosecurity/falco-talon/actionners/actionners.go#L76-L94)

### Network Policy Actionners

| Actionner | Description |
|-----------|-------------|
| `calico:networkpolicy` | Create a Calico NetworkPolicy |
| `cilium:networkpolicy` | Create a Cilium NetworkPolicy |

**Source:** [`actionners/actionners.go:92-93`](../../refs/falcosecurity/falco-talon/actionners/actionners.go#L92-L93)

### Cloud Actionners

| Actionner | Description |
|-----------|-------------|
| `aws:lambda` | Invoke an AWS Lambda function |
| `gcp:function` | Invoke a GCP Cloud Function |

**Source:** [`actionners/actionners.go:90-91`](../../refs/falcosecurity/falco-talon/actionners/actionners.go#L90-L91)

## Notifiers

Notifiers send notifications about action results.

| Notifier | Description |
|----------|-------------|
| `k8sevents` | Create Kubernetes Events |
| `slack` | Send to Slack webhook |
| `smtp` | Send email |
| `webhook` | Send to generic webhook |
| `loki` | Send to Grafana Loki |
| `elasticsearch` | Send to Elasticsearch |

**Source:** [`notifiers/notifiers.go:46-56`](../../refs/falcosecurity/falco-talon/notifiers/notifiers.go#L46-L56)

## Outputs

Outputs store artifacts created by actionners (logs, tcpdump captures, downloaded files).

| Output | Description |
|--------|-------------|
| `local:file` | Save to local filesystem |
| `minio:s3` | Upload to Minio S3-compatible storage |
| `aws:s3` | Upload to AWS S3 |
| `gcp:gcs` | Upload to Google Cloud Storage |

**Source:** [`outputs/outputs.go:34-44`](../../refs/falcosecurity/falco-talon/outputs/outputs.go#L34-L44)

## Configuration

### Static Configuration (`config.yaml`)

```yaml
listen_address: "0.0.0.0"  # default: "0.0.0.0"
listen_port: "2803"         # default: "2803"
rules_files:
  - "./rules.yaml"          # default: "./rules.yaml"
# kubeConfig: "~/.kube/config"  # only outside Kubernetes
log_format: "color"         # text, color, json (default: color)
watch_rules: true           # reload on file changes (default: true)
print_all_events: false     # print all events, not just matches

# Deduplication (for cluster mode)
deduplication:
  leader_election: true     # enable leader election in k8s
  time_window_seconds: 5    # dedup window (default: 5)

# Default notifiers for all rules
default_notifiers:
  - k8sevents

# OTEL configuration
otel:
  traces_enabled: true
  metrics_enabled: true
  collector_endpoint: localhost
  collector_port: 4317
  collector_use_insecure_grpc: true
  timeout: 10

# Notifiers configuration
notifiers:
  slack:
    webhook_url: "https://hooks.slack.com/..."
    format: long  # long or short
  # webhook:
  #   url: ""
  # smtp:
  #   host_port: ""
  #   from: ""
  #   to: ""
```

**Source:** [`config_example.yaml`](../../refs/falcosecurity/falco-talon/config_example.yaml)

## Rules

Rules define which Falco events trigger which actions.

### Rule Structure

```yaml
- rule: <rule_name>
  description: <description>
  continue: <true|false>    # continue to next rule after match
  dry_run: <true|false>     # don't execute, just log
  match:
    rules:                  # Falco rule names to match
      - <falco_rule_name>
    output_fields:          # Filter by output field values
      - <field>=<value>
      - <field>!=<value>
    priority: <comparator><priority>  # e.g., >=Warning
    source: <source>        # e.g., syscalls, k8s_audit
    tags:
      - <tag1>, <tag2>      # AND within line, OR between lines
  actions:
    - action: <action_name>
      actionner: <category:name>
      parameters:
        <key>: <value>
      continue: <true|false>
      ignore_errors: <true|false>
      additional_contexts:
        - <context_name>
      output:
        target: <output_target>
        parameters:
          <key>: <value>
  notifiers:
    - <notifier_name>
```

**Source:** [`internal/rules/rules.go:18-54`](../../refs/falcosecurity/falco-talon/internal/rules/rules.go#L18-L54)

### Actions and Action Templates

Actions can be defined inline or as reusable templates. Template actions are merged with rule-level actions.

```yaml
# Reusable action template
- action: Terminate Pod
  actionner: kubernetes:terminate
  parameters:
    grace_period_seconds: 5
    ignore_standalone_pods: true

# Rule using the template
- rule: Terminal shell in container
  match:
    rules:
      - Terminal shell in container
    output_fields:
      - k8s.ns.name!=kube-system
  actions:
    - action: Terminate Pod  # References template above
```

**Source:** [`rules.yaml`](../../refs/falcosecurity/falco-talon/rules.yaml)

### Match Criteria

| Field | Description | Example |
|-------|-------------|---------|
| `rules` | List of Falco rule names | `- Terminal shell in container` |
| `output_fields` | Filter by Falco output fields | `- k8s.ns.name!=kube-system` |
| `priority` | Filter by priority with comparator | `>=Warning`, `=Error` |
| `source` | Filter by event source | `syscalls`, `k8s_audit` |
| `tags` | Filter by Falco rule tags | `- network, container` |

**Priority comparators:** `=`, `>`, `>=`, `<`, `<=`
**Output field comparators:** `=`, `!=`

**Source:** [`internal/rules/rules.go:546-672`](../../refs/falcosecurity/falco-talon/internal/rules/rules.go#L546-L672)

## Event Structure

Falco Talon expects Falco events in JSON format (FalcoPayload):

```go
type Event struct {
    TraceID      string         `json:"trace_id"`
    Output       string         `json:"output"`
    Priority     string         `json:"priority"`
    Rule         string         `json:"rule"`
    Hostname     string         `json:"hostname"`
    Time         time.Time      `json:"time"`
    Source       string         `json:"source"`
    OutputFields map[string]any `json:"output_fields"`
    Context      map[string]any `json:"context"`
    Tags         []any          `json:"tags"`
}
```

**Source:** [`internal/events/events.go:14-25`](../../refs/falcosecurity/falco-talon/internal/events/events.go#L14-L25)

## Example: Terminate Pod Action

```yaml
- action: Terminate the pod
  actionner: kubernetes:terminate
  parameters:
    grace_period_seconds: 5       # Pod termination grace period
    ignore_daemonsets: true       # Don't terminate DaemonSet pods
    ignore_statefulsets: true     # Don't terminate StatefulSet pods
    ignore_standalone_pods: true  # Don't terminate standalone pods
    min_healthy_replicas: 33%     # Minimum healthy replicas (absolut or %)
```

**Required RBAC permissions:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: falco-talon
rules:
- apiGroups: [""]
  resources: [pods]
  verbs: [get, delete, list]
- apiGroups: [apps]
  resources: [replicasets]
  verbs: [get]
```

**Source:** [`actionners/kubernetes/terminate/terminate.go:27-55`](../../refs/falcosecurity/falco-talon/actionners/kubernetes/terminate/terminate.go#L27-L55)

## Installation

### Helm

```shell
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco-talon falcosecurity/falco-talon -n falco --create-namespace
```

### Configure Falcosidekick

Connect Falcosidekick to send events to Falco Talon:

```shell
helm install falco falcosecurity/falco --namespace falco \
  --create-namespace \
  --set tty=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.talon.address=http://falco-talon:2803
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-talon/README.md)

### Docker

```shell
docker run -d -p 2803:2803 \
  -v ./config.yaml:/config.yaml \
  -v ./rules.yaml:/rules.yaml \
  falcosecurity/falco-talon
```

**Source:** [`README.md`](../../refs/falcosecurity/falco-talon/README.md)

## Metrics and Traces

### Prometheus Metrics

Exposed at `/metrics` endpoint.

### OTEL Metrics and Traces

Configure in `config.yaml`:

```yaml
otel:
  traces_enabled: true
  metrics_enabled: true
  collector_endpoint: localhost
  collector_port: 4317
```

**Source:** [`config_example.yaml`](../../refs/falcosecurity/falco-talon/config_example.yaml)

## CLI Commands

```shell
falco-talon server              # Start the server (default)
falco-talon rules               # Check/print the rules
falco-talon actionners          # List available actionners
falco-talon notifiers           # List available notifiers
falco-talon outputs             # List available outputs
falco-talon version             # Print version
```

**Source:** [`cmd/`](../../refs/falcosecurity/falco-talon/cmd/) directory

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 0.3.0 | 2025-02-05 | Added `kubernetes:sysdig` actionner |
| 0.2.0 | 2024-11-26 | Added `gcp:function`, `gcp:gcs`, Helm chart migration |
| 0.1.0 | 2024-09-05 | First GA release (13 actionners, 6 notifiers, 3 outputs) |

**Source:** [`CHANGELOG.md`](../../refs/falcosecurity/falco-talon/CHANGELOG.md)

## Era 0.45 Development Snapshot

The pin includes post-v0.3.0 changes; these features must not be attributed to the v0.3.0 release image without checking its source. Rule checking, startup and rule-file reload share validation of actionners, action parameters, required outputs and output parameters. Action templates can inherit an output target and allocate its parameter map when needed. YAML errors identify the file that failed.

The event consumer recovers panics raised synchronously while processing an individual event and logs the failure. Event accessors accept strings and numeric JSON values and ignore unsupported types; remote protocol lookup falls back to `fd.sproto`. This is a bounded recovery mechanism, not a guarantee that arbitrary failures in other goroutines are contained.

Output storage implementations share timestamped object-key construction with deterministic fallback ordering. Other fixes include resolving `daemonsets` through the DaemonSet client, using `allow_namespaces` to decide whether to construct Cilium namespace egress rules, honoring configured `otel.timeout`, and populating text SMTP bodies.

**Source:** [`rule_validation.go:10-95`](../../refs/falcosecurity/falco-talon/cmd/rule_validation.go), [`server.go:35-49,100-121`](../../refs/falcosecurity/falco-talon/cmd/server.go), [`rules.go:244-312`](../../refs/falcosecurity/falco-talon/internal/rules/rules.go), [`actionners.go:471-505`](../../refs/falcosecurity/falco-talon/actionners/actionners.go), [`events.go:58-153`](../../refs/falcosecurity/falco-talon/internal/events/events.go), [`helpers.go:17-47`](../../refs/falcosecurity/falco-talon/outputs/helpers/helpers.go), [`client.go:293-325`](../../refs/falcosecurity/falco-talon/internal/kubernetes/client/client.go), [`networkpolicy.go:376-399`](../../refs/falcosecurity/falco-talon/actionners/cilium/networkpolicy/networkpolicy.go), [`configuration.go:95-106`](../../refs/falcosecurity/falco-talon/configuration/configuration.go), [`smtp.go:164-178`](../../refs/falcosecurity/falco-talon/notifiers/smtp/smtp.go).

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, architecture | [`README.md`](../../refs/falcosecurity/falco-talon/README.md) |
| Configuration | [`config_example.yaml`](../../refs/falcosecurity/falco-talon/config_example.yaml) |
| Rules examples | [`rules.yaml`](../../refs/falcosecurity/falco-talon/rules.yaml) |
| Actionners registry | [`actionners/actionners.go`](../../refs/falcosecurity/falco-talon/actionners/actionners.go) |
| Notifiers registry | [`notifiers/notifiers.go`](../../refs/falcosecurity/falco-talon/notifiers/notifiers.go) |
| Outputs registry | [`outputs/outputs.go`](../../refs/falcosecurity/falco-talon/outputs/outputs.go) |
| Rules engine | [`internal/rules/rules.go`](../../refs/falcosecurity/falco-talon/internal/rules/rules.go) |
| Event structure | [`internal/events/events.go`](../../refs/falcosecurity/falco-talon/internal/events/events.go) |
| Version history | [`CHANGELOG.md`](../../refs/falcosecurity/falco-talon/CHANGELOG.md) |

## Related Documentation

- [`falcosidekick/README.md`](falcosidekick/README.md) - Event forwarding to Falco Talon
- [`falcosidekick/outputs.md`](falcosidekick/outputs.md) - Talon output configuration in Falcosidekick
- [`charts.md`](charts.md) - Helm charts (includes falco-talon chart)
- [`falco/outputs.md`](falco/outputs.md) - Falco HTTP output (alternative to Falcosidekick)
