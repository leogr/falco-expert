# Falco Talon

> Response Engine for Falco: automated threat response via actionners, rule-based event matching, notification channels, artifact storage, and Kubernetes-native remediation.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco-talon/`](../refs/falcosecurity/falco-talon/)

> **Note:** This project is Incubating/Experimental. Recommended for testing, evaluation, or environments where automated response risk is acceptable.

## 1. Overview

Falco Talon is a Response Engine that receives events from Falco (or Falcosidekick) via HTTP webhook and automatically executes configured response actions. It provides a no-code, rule-based approach to threat response in Kubernetes environments.

**Key capabilities:**

- Receive Falco events via HTTP webhook (port 2803)
- Match events against configurable rules
- Execute automated response actions (terminate pods, create network policies, run scripts, capture traffic)
- Notify about action results via multiple channels
- Store action artifacts (logs, tcpdump captures, files)
- Export metrics and traces (Prometheus, OTEL)

**Glossary:**

| Term | Description |
|------|-------------|
| Event | An event detected by Falco and sent to its outputs |
| Rule | Defines criteria for linking events with actions |
| Action | Each rule can sequentially run actions, each refers to an actionner |
| Actionner | Defines what the action will do (the implementation) |
| Notifier | Defines where to send notifications about action results |
| Output | Defines where to store artifacts created by actionners |
| Context | Elements from the Falco event and other sources for dynamic configuration |

**Repository status:** Incubating (Ecosystem, Experimental)
**License:** Apache-2.0
**Latest version:** 0.3.0

**Source:** [`README.md`](../refs/falcosecurity/falco-talon/README.md), [`digests/falcosecurity/falco-talon.md`](../digests/falcosecurity/falco-talon.md)

## 2. Architecture

```
┌─────────────────┐     ┌─────────────────┐
│     Falco       │────>│  Falcosidekick  │
└─────────────────┘     └────────┬────────┘
        │                        │
        │ event                  │ event
        v                        v
┌───────────────────────────────────────────┐
│              Falco Talon (:2803)          │
│  ┌─────────┐  ┌─────────┐  ┌───────────┐│
│  │  Rules  │─>│ Actions │─>│ Notifiers ││
│  │ Engine  │  │         │  │           ││
│  └─────────┘  └────┬────┘  └───────────┘│
│                    │                     │
│                    v                     │
│              ┌───────────┐               │
│              │  Outputs  │               │
│              │ (storage) │               │
│              └───────────┘               │
└───────────────────────────────────────────┘
        │                    │
        v                    v
   Kubernetes            AWS/GCP/Minio
```

Falco Talon receives events directly from Falco's HTTP output or from Falcosidekick's Talon output. Events are matched against rules, which trigger sequential actions via actionners. Results are sent to notifiers, and artifacts are stored in outputs.

**Source:** [`README.md`](../refs/falcosecurity/falco-talon/README.md)

## 3. Actionners

Actionners are the implementations that perform response actions. Format: `<category>:<name>`.

### Kubernetes Actionners

| Actionner | Description | Required Fields |
|-----------|-------------|-----------------|
| `kubernetes:terminate` | Terminate a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:label` | Add labels to a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:annotation` | Add annotations to a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:networkpolicy` | Create a NetworkPolicy | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:exec` | Execute a command in a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:script` | Execute a script in a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:log` | Collect pod logs | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:delete` | Delete a Kubernetes resource | varies by resource |
| `kubernetes:cordon` | Cordon a node | hostname |
| `kubernetes:drain` | Drain a node | hostname |
| `kubernetes:download` | Download a file from a pod | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:tcpdump` | Capture network traffic | `k8s.ns.name`, `k8s.pod.name` |
| `kubernetes:sysdig` | Capture system activity | `k8s.ns.name`, `k8s.pod.name` |

### Network Policy Actionners

| Actionner | Description |
|-----------|-------------|
| `calico:networkpolicy` | Create a Calico NetworkPolicy |
| `cilium:networkpolicy` | Create a Cilium NetworkPolicy |

### Cloud Actionners

| Actionner | Description |
|-----------|-------------|
| `aws:lambda` | Invoke an AWS Lambda function |
| `gcp:function` | Invoke a GCP Cloud Function |

**Source:** [`actionners/actionners.go:74-92`](../refs/falcosecurity/falco-talon/actionners/actionners.go)

## 4. Rule System

### Rule Structure

```yaml
- rule: <rule_name>
  description: <description>
  continue: <true|false>       # continue to next rule after match
  dry_run: <true|false>        # don't execute, just log
  match:
    rules:                     # Falco rule names to match
      - <falco_rule_name>
    output_fields:             # Filter by output field values
      - <field>=<value>
      - <field>!=<value>
    priority: <comparator><priority>  # e.g., >=Warning
    source: <source>           # e.g., syscalls, k8s_audit
    tags:
      - <tag1>, <tag2>        # AND within line, OR between lines
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

**Source:** [`internal/rules/rules.go:18-54`](../refs/falcosecurity/falco-talon/internal/rules/rules.go)

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

**Source:** [`internal/rules/rules.go:536-649`](../refs/falcosecurity/falco-talon/internal/rules/rules.go)

### Action Templates

Actions can be defined as reusable templates that are merged with rule-level actions:

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

**Source:** [`rules.yaml`](../refs/falcosecurity/falco-talon/rules.yaml)

### Terminate Action Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `grace_period_seconds` | int | Pod termination grace period |
| `ignore_daemonsets` | bool | Don't terminate DaemonSet pods |
| `ignore_statefulsets` | bool | Don't terminate StatefulSet pods |
| `ignore_standalone_pods` | bool | Don't terminate standalone pods |
| `min_healthy_replicas` | string | Minimum healthy replicas (absolute or %) |

**Source:** [`actionners/kubernetes/terminate/terminate.go:27-55`](../refs/falcosecurity/falco-talon/actionners/kubernetes/terminate/terminate.go)

## 5. Notifiers

| Notifier | Description |
|----------|-------------|
| `k8sevents` | Create Kubernetes Events |
| `slack` | Send to Slack webhook |
| `smtp` | Send email |
| `webhook` | Send to generic webhook |
| `loki` | Send to Grafana Loki |
| `elasticsearch` | Send to Elasticsearch |

**Source:** [`notifiers/notifiers.go:46-56`](../refs/falcosecurity/falco-talon/notifiers/notifiers.go)

## 6. Outputs

Outputs store artifacts created by actionners (logs, tcpdump captures, downloaded files).

| Output | Description |
|--------|-------------|
| `local:file` | Save to local filesystem |
| `minio:s3` | Upload to Minio S3-compatible storage |
| `aws:s3` | Upload to AWS S3 |
| `gcp:gcs` | Upload to Google Cloud Storage |

**Source:** [`outputs/outputs.go:34-44`](../refs/falcosecurity/falco-talon/outputs/outputs.go)

## 7. Event Structure

Falco Talon expects events in the FalcoPayload JSON format:

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

**Source:** [`internal/events/events.go:13-24`](../refs/falcosecurity/falco-talon/internal/events/events.go)

## 8. Configuration

### Static Configuration (`config.yaml`)

```yaml
listen_address: "0.0.0.0"     # default: "0.0.0.0"
listen_port: "2803"            # default: "2803"
rules_files:
  - "./rules.yaml"
log_format: "color"            # text, color, json (default: color)
watch_rules: true              # reload on file changes (default: true)
print_all_events: false        # print all events, not just matches

deduplication:
  leader_election: true        # enable leader election in k8s
  time_window_seconds: 5       # dedup window (default: 5)

default_notifiers:             # default notifiers for all rules
  - k8sevents

otel:
  traces_enabled: true
  metrics_enabled: true
  collector_endpoint: localhost
  collector_port: 4317
  collector_use_insecure_grpc: true
  timeout: 10

notifiers:
  slack:
    webhook_url: "https://hooks.slack.com/..."
    format: long               # long or short
```

**Source:** [`config_example.yaml`](../refs/falcosecurity/falco-talon/config_example.yaml)

### Metrics and Traces

- **Prometheus metrics:** Exposed at `/metrics` endpoint
- **OTEL:** Configurable traces and metrics export to OTEL collector

## 9. Installation

### Helm

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco-talon falcosecurity/falco-talon -n falco --create-namespace
```

### Integration with Falcosidekick

```bash
helm install falco falcosecurity/falco --namespace falco \
  --create-namespace \
  --set tty=true \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.talon.address=http://falco-talon:2803
```

### Docker

```bash
docker run -d -p 2803:2803 \
  -v ./config.yaml:/config.yaml \
  -v ./rules.yaml:/rules.yaml \
  falcosecurity/falco-talon
```

### CLI Commands

```bash
falco-talon server              # Start the server (default)
falco-talon rules               # Check/print the rules
falco-talon actionners          # List available actionners
falco-talon notifiers           # List available notifiers
falco-talon outputs             # List available outputs
falco-talon version             # Print version
```

**Source:** [`README.md`](../refs/falcosecurity/falco-talon/README.md), [`cmd/`](../refs/falcosecurity/falco-talon/cmd/)

## 10. Related Specs

| Spec | Relationship |
|------|-------------|
| [`falcosidekick.md`](falcosidekick.md) | Event forwarding to Falco Talon (Talon is a Falcosidekick output) |
| [`output-system.md`](output-system.md) | Falco's HTTP output (alternative to Falcosidekick for sending events) |
| [`rules-content.md`](rules-content.md) | Detection rules that trigger Talon response actions |
| [`kubernetes-deployment.md`](kubernetes-deployment.md) | Helm charts (includes falco-talon chart) |

## 11. Sources

| Topic | Source |
|-------|--------|
| Overview, architecture | [`README.md`](../refs/falcosecurity/falco-talon/README.md) |
| Configuration | [`config_example.yaml`](../refs/falcosecurity/falco-talon/config_example.yaml) |
| Rules examples | [`rules.yaml`](../refs/falcosecurity/falco-talon/rules.yaml) |
| Actionners registry | [`actionners/actionners.go`](../refs/falcosecurity/falco-talon/actionners/actionners.go) |
| Notifiers registry | [`notifiers/notifiers.go`](../refs/falcosecurity/falco-talon/notifiers/notifiers.go) |
| Outputs registry | [`outputs/outputs.go`](../refs/falcosecurity/falco-talon/outputs/outputs.go) |
| Rules engine | [`internal/rules/rules.go`](../refs/falcosecurity/falco-talon/internal/rules/rules.go) |
| Event structure | [`internal/events/events.go`](../refs/falcosecurity/falco-talon/internal/events/events.go) |
| Version history | [`CHANGELOG.md`](../refs/falcosecurity/falco-talon/CHANGELOG.md) |
| Digest | [`digests/falcosecurity/falco-talon.md`](../digests/falcosecurity/falco-talon.md) |
