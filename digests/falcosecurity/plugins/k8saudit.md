# k8saudit Plugin - Design and Architecture

**Era:** 0.44 | **Status:** Stable | **Scope:** Core

The `k8saudit` plugin extends Falco to support [Kubernetes Audit Events](https://kubernetes.io/docs/tasks/debug-application-cluster/audit/#audit-backends) as a data source. Audit events are logged by the API server when cluster management tasks are performed, providing high visibility into cluster activity for detecting malicious behavior.

**Source:** [`plugins/k8saudit/`](../../../refs/falcosecurity/plugins/plugins/k8saudit/)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Plugin Capabilities](#plugin-capabilities)
- [Event Sources](#event-sources)
- [Configuration](#configuration)
- [Supported Fields](#supported-fields)
- [Event Flow](#event-flow)
- [Kubernetes Setup](#kubernetes-setup)
- [Rules](#rules)
- [Usage Examples](#usage-examples)
- [Sources](#sources)

---

## Overview

| Property | Value |
|----------|-------|
| Plugin Name | `k8saudit` |
| Plugin ID | 1 |
| Plugin Version | 0.17.0 |
| Event Source | `k8s_audit` |
| Language | Go |
| Minimum Falco Version | 0.32.0 |

The plugin consumes Kubernetes Audit Events from:
- **Webhook backend** - Embeds a web server that listens on a configurable port for POST requests containing audit events
- **File** - Reads events from local filesystem in JSONL format (for testing/development or Stratoshark)

**Source:** [`README.md`](../../../refs/falcosecurity/plugins/plugins/k8saudit/README.md)

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                          k8saudit Plugin                                │
├────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    Plugin Structure                               │  │
│  │                                                                   │  │
│  │  ┌─────────────────┐        ┌─────────────────────────────────┐  │  │
│  │  │   Source Cap    │        │      Extraction Cap             │  │  │
│  │  │                 │        │                                 │  │  │
│  │  │ ┌─────────────┐ │        │  ┌─────────────────────────┐    │  │  │
│  │  │ │ Web Server  │ │        │  │   Field Extractors      │    │  │  │
│  │  │ │ (HTTP/HTTPS)│ │        │  │   (ka.* fields)         │    │  │  │
│  │  │ └─────────────┘ │        │  └─────────────────────────┘    │  │  │
│  │  │ ┌─────────────┐ │        │                                 │  │  │
│  │  │ │ File Reader │ │        │  ┌─────────────────────────┐    │  │  │
│  │  │ │  (JSONL)    │ │        │  │   JSON Parser (fastjson)│    │  │  │
│  │  │ └─────────────┘ │        │  └─────────────────────────┘    │  │  │
│  │  └─────────────────┘        └─────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    K8s API Server (Webhook Backend)                     │
│                                                                         │
│  ┌────────────────┐    ┌────────────────────────────────────────────┐  │
│  │ Audit Policy   │───>│           POST /k8s-audit                   │  │
│  │ (audit-policy  │    │           JSON payload                      │  │
│  │  .yaml)        │    │           (EventList or Event)              │  │
│  └────────────────┘    └────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

### Plugin Structure

The plugin is implemented in Go and consists of two main packages:

1. **Core Package** ([`pkg/k8saudit/`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/))
   - `k8saudit.go` - Plugin definition and initialization
   - `source.go` - Event sourcing (web server and file reader)
   - `extract.go` - Field extraction logic
   - `fields.go` - Field definitions
   - `config.go` - Configuration schema

2. **Plugin Entry Point** ([`plugin/k8saudit.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/plugin/k8saudit.go))
   - Registers the plugin with source and extractor capabilities

**Source:** [`pkg/k8saudit/k8saudit.go:42-49`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/k8saudit.go)

---

## Plugin Capabilities

The plugin implements two Falco plugin capabilities:

| Capability | Purpose | Implementation |
|------------|---------|----------------|
| `source` | Generates events from webhooks or files | [`source.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/source.go) |
| `extraction` | Extracts `ka.*` fields from audit events | [`extract.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/extract.go) |

### Plugin Info

```go
func (k *Plugin) Info() *plugins.Info {
    return &plugins.Info{
        ID:          1,
        Name:        "k8saudit",
        Description: "Read Kubernetes Audit Events and monitor Kubernetes Clusters",
        Contact:     "github.com/falcosecurity/plugins",
        Version:     "0.17.0",
        EventSource: "k8s_audit",
    }
}
```

**Source:** [`pkg/k8saudit/k8saudit.go:51-60`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/k8saudit.go)

---

## Event Sources

### Webhook Mode (Primary)

The plugin embeds an HTTP/HTTPS web server that receives audit events from the Kubernetes API Server's webhook backend.

```go
func (k *Plugin) OpenWebServer(address, endpoint string, ssl bool) (source.Instance, error) {
    // Creates HTTP server listening on address
    // Handles POST requests to endpoint
    // Expects Content-Type: application/json
    // Parses EventList or single Event JSON
}
```

**Key characteristics:**
- Listens on configurable address and endpoint
- Supports HTTP and HTTPS (with SSL certificate)
- Limits request body size via `webhookMaxBatchSize`
- Uses push-mode event channel
- Graceful 5-second shutdown timeout

**Source:** [`pkg/k8saudit/source.go:128-220`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/source.go)

### File Mode (Testing/Development)

Reads audit events from local filesystem in JSONL format.

```go
func (k *Plugin) OpenReader(r io.ReadCloser) (source.Instance, error) {
    // Reads line by line (JSONL format)
    // Each line is a JSON audit event
}
```

**Supports:**
- Single file reading
- Directory reading (files sorted by modification time)
- JSONL format (one JSON object per line)

**Source:** [`pkg/k8saudit/source.go:99-126`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/source.go)

### Open Parameters

| Format | Mode | Description |
|--------|------|-------------|
| `http://<host>:<port>/<endpoint>` | Webhook | HTTP web server |
| `https://<host>:<port>/<endpoint>` | Webhook | HTTPS web server |
| `<filepath>` | File | Local file or directory path |

**Source:** [`pkg/k8saudit/source.go:43-97`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/source.go)

---

## Configuration

### Plugin Configuration Schema

```go
type PluginConfig struct {
    SSLCertificate      string `json:"sslCertificate"`       // Default: /etc/falco/falco.pem
    UseAsync            bool   `json:"useAsync"`             // Default: true
    MaxEventSize        uint64 `json:"maxEventSize"`         // Default: 262144 (256KB)
    WebhookMaxBatchSize uint64 `json:"webhookMaxBatchSize"`  // Default: 12582912 (~12MB)
}
```

**Source:** [`pkg/k8saudit/config.go:22-27`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/config.go)

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `sslCertificate` | string | `/etc/falco/falco.pem` | SSL certificate for HTTPS webhook endpoint |
| `useAsync` | bool | `true` | Enable async extraction optimization |
| `maxEventSize` | uint64 | 262144 | Maximum size of single audit event (bytes) |
| `webhookMaxBatchSize` | uint64 | 12582912 | Maximum size of incoming webhook POST request bodies |

The `webhookMaxBatchSize` default is ~20% higher than the Kubernetes API server default of 10485760 bytes.

**Source:** [`pkg/k8saudit/config.go:29-41`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/config.go)

### Example Falco Configuration

```yaml
plugins:
  - name: k8saudit
    library_path: libk8saudit.so
    init_config:
      sslCertificate: /etc/falco/falco.pem
    open_params: "http://:9765/k8s-audit"
  - name: json
    library_path: libjson.so
    init_config: ""

load_plugins: [k8saudit, json]
```

**Source:** [`README.md`](../../../refs/falcosecurity/plugins/plugins/k8saudit/README.md)

---

## Supported Fields

The plugin extracts fields with the `ka.` prefix from Kubernetes Audit Events.

### Core Fields

| Field | Type | Description |
|-------|------|-------------|
| `ka.auditid` | string | Unique ID of the audit event |
| `ka.stage` | string | Stage of request (RequestReceived, ResponseComplete, etc.) |
| `ka.verb` | string | Action being performed (create, update, delete, get, etc.) |
| `ka.uri` | string | Request URI as sent from client to server |
| `ka.uri.param[key]` | string | Value of a query parameter in the URI |

### User Fields

| Field | Type | Description |
|-------|------|-------------|
| `ka.user.name` | string | User name performing the request |
| `ka.user.groups` | list | Groups to which the user belongs |
| `ka.impuser.name` | string | Impersonated user name |

### Authorization Fields

| Field | Type | Description |
|-------|------|-------------|
| `ka.auth.decision` | string | Authorization decision |
| `ka.auth.reason` | string | Authorization reason |
| `ka.auth.openshift.decision` | string | OpenShift authentication decision |
| `ka.auth.openshift.username` | string | OpenShift authentication username |
| `ka.validations.admission.policy.failure` | string | Validation failure reason from Validation Admission Policy |
| `ka.security.pod.violations` | string | Violation reason for pod security policy |

### Target Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `ka.target.name` | string | Target object name |
| `ka.target.namespace` | string | Target object namespace |
| `ka.target.resource` | string | Target object resource |
| `ka.target.subresource` | string | Target object subresource |
| `ka.target.pod.name` | string | Target pod name |

### Role Binding Fields

| Field | Type | Description |
|-------|------|-------------|
| `ka.req.binding.subjects` | list | Subjects linked by role binding |
| `ka.req.binding.subjects.user_names` | list | User names linked by binding |
| `ka.req.binding.subjects.serviceaccount_names` | list | Service account names linked by binding |
| `ka.req.binding.subjects.serviceaccount_ns_names` | list | Namespaced service account names (namespace:name) |
| `ka.req.binding.subjects.group_names` | list | Group names linked by binding |
| `ka.req.binding.role` | string | Role being linked by binding |

### Pod Container Fields

| Field | Type | Arg | Description |
|-------|------|-----|-------------|
| `ka.req.pod.containers.name` | list | Index | Container names |
| `ka.req.pod.containers.image` | list | Index | Container images |
| `ka.req.pod.containers.image.repository` | list | Index | Image repository (e.g., falcosecurity/falco) |
| `ka.req.pod.containers.command` | list | Index | Container commands |
| `ka.req.pod.containers.args` | list | Index | Container args |
| `ka.req.pod.containers.privileged` | list | Index | Privileged flag for containers |
| `ka.req.pod.containers.allow_privilege_escalation` | list | Index | allowPrivilegeEscalation flag |
| `ka.req.pod.containers.read_only_fs` | list | Index | readOnlyRootFilesystem flag |
| `ka.req.pod.containers.run_as_user` | list | Index | runAsUser uid for containers |
| `ka.req.pod.containers.run_as_group` | list | Index | runAsGroup gid for containers |
| `ka.req.pod.containers.eff_run_as_user` | list | Index | Effective runAsUser (pod + container) |
| `ka.req.pod.containers.eff_run_as_group` | list | Index | Effective runAsGroup (pod + container) |
| `ka.req.pod.containers.proc_mount` | list | Index | procMount types |
| `ka.req.pod.containers.host_port` | list | Index | hostPort values |
| `ka.req.pod.containers.add_capabilities` | list | Index | Capabilities to add |

### Pod Security Fields

| Field | Type | Description |
|-------|------|-------------|
| `ka.req.pod.host_ipc` | string | hostIPC flag value |
| `ka.req.pod.host_network` | string | hostNetwork flag value |
| `ka.req.pod.host_pid` | string | hostPID flag value |
| `ka.req.pod.run_as_user` | string | Pod-level runAsUser |
| `ka.req.pod.run_as_group` | string | Pod-level runAsGroup |
| `ka.req.pod.fs_group` | string | fsGroup gid |
| `ka.req.pod.supplemental_groups` | list | supplementalGroup gids |

### Volume Fields

| Field | Type | Arg | Description |
|-------|------|-----|-------------|
| `ka.req.pod.volumes.hostpath` | list | Index | hostPath paths for all volumes |
| `ka.req.pod.volumes.flexvolume_driver` | list | Index | flexVolume drivers |
| `ka.req.pod.volumes.volume_type` | list | Index | Volume types |
| `ka.req.volume.hostpath[path]` | string | Key | Check if host path prefix is used (deprecated) |

### Role/ClusterRole Fields

| Field | Type | Arg | Description |
|-------|------|-----|-------------|
| `ka.req.role.rules` | list | None | Rules associated with role |
| `ka.req.role.rules.apiGroups` | list | Index | API groups in rules |
| `ka.req.role.rules.nonResourceURLs` | list | Index | Non-resource URLs in rules |
| `ka.req.role.rules.verbs` | list | Index | Verbs in rules |
| `ka.req.role.rules.resources` | list | Index | Resources in rules |

### Service Fields

| Field | Type | Arg | Description |
|-------|------|-----|-------------|
| `ka.req.service.type` | string | None | Service type |
| `ka.req.service.ports` | list | Index | Service ports |

### ConfigMap Fields

| Field | Type | Description |
|-------|------|-------------|
| `ka.req.configmap.name` | string | ConfigMap name |
| `ka.req.configmap.obj` | string | Entire configmap object |

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `ka.resp.name` | string | Response object name |
| `ka.response.code` | string | Response code |
| `ka.response.reason` | string | Response reason (usually for failures) |

### Client Fields

| Field | Type | Arg | Description |
|-------|------|-----|-------------|
| `ka.useragent` | string | None | User agent of the client |
| `ka.sourceips` | list | Index | Client IP addresses |
| `ka.cluster.name` | string | None | Kubernetes cluster name |

### Deprecated Fields

| Field | Replacement |
|-------|-------------|
| `ka.req.container.image` | `ka.req.pod.containers.image` |
| `ka.req.container.image.repository` | `ka.req.pod.containers.image.repository` |
| `ka.req.container.host_network` | `ka.req.pod.host_network` |
| `ka.req.container.privileged` | `ka.req.pod.containers.privileged` |
| `ka.req.volume.hostpath[key]` | `ka.req.pod.volumes.hostpath` |
| `ka.req.binding.subject.has_name[key]` | Always returns "N/A" |

**Source:** [`pkg/k8saudit/fields.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/fields.go)

---

## Event Flow

### Webhook Event Processing

```
K8s API Server
      │
      │ POST /k8s-audit (JSON)
      ▼
┌─────────────────────┐
│   HTTP Handler      │
│   - Validate method │
│   - Check content   │
│   - Read body       │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────────┐
│  Event Parser           │
│  - Parse JSON payload   │
│  - Handle EventList     │
│  - Handle single Event  │
│  - Extract stageTimestamp│
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│  Event Channel          │
│  (Push Mode)            │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│  Falco Rule Engine      │
│  - Extract ka.* fields  │
│  - Evaluate conditions  │
└─────────────────────────┘
```

### JSON Parsing

The plugin uses the `fastjson` library for high-performance JSON parsing. Events can be:

1. **EventList** - Contains multiple events in `items` array
2. **Single Event** - A single audit event object

```go
func (k *Plugin) ParseAuditEventsJSON(value *fastjson.Value) ([]*source.PushEvent, error) {
    if value.Type() == fastjson.TypeArray {
        // Handle array of events
    } else if value.Get("kind") != nil {
        switch string(value.Get("kind").GetStringBytes()) {
        case "EventList":
            // Parse items array
        case "Event":
            // Parse single event
        }
    }
}
```

**Source:** [`pkg/k8saudit/source.go:288-318`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/source.go)

---

## Kubernetes Setup

### Audit Policy

The plugin requires Kubernetes audit logging to be enabled with an appropriate audit policy. A recommended policy is provided:

**Key policy settings:**
- Omit `RequestReceived` stage (only process completed requests)
- Log pods and deployments at `RequestResponse` level
- Log RBAC resources (clusterroles, clusterrolebindings) at `RequestResponse` level
- Log secrets at `Metadata` level
- Log configmaps at `Request`/`RequestResponse` level

**Source:** [`configs/audit-policy.yaml`](../../../refs/falcosecurity/plugins/plugins/k8saudit/configs/audit-policy.yaml)

### Webhook Configuration

Template for configuring the API server webhook backend:

```yaml
apiVersion: v1
kind: Config
clusters:
- name: falco
  cluster:
    server: http://$FALCO_SERVICE_CLUSTERIP:8765/k8s-audit
contexts:
- context:
    cluster: falco
    user: ""
  name: default-context
current-context: default-context
```

**Source:** [`configs/webhook-config.yaml.in`](../../../refs/falcosecurity/plugins/plugins/k8saudit/configs/webhook-config.yaml.in)

---

## Rules

The plugin ships with a comprehensive ruleset for detecting security-relevant Kubernetes operations.

### Rule Dependencies

```yaml
- required_engine_version: 15
- required_plugin_versions:
    - name: k8saudit
      version: 0.7.0
      alternatives:
        - name: k8saudit-aks
        - name: k8saudit-eks
        - name: k8saudit-gke
        - name: k8saudit-ovh
    - name: json
      version: 0.7.0
```

### Key Macros

| Macro | Description |
|-------|-------------|
| `kevt` | Select events at ResponseComplete stage |
| `kcreate` | verb=create |
| `kmodify` | verb in (create, update, patch) |
| `kdelete` | verb=delete |
| `pod` | target.resource=pods (no subresource) |
| `deployment` | target.resource=deployments |
| `service` | target.resource=services |
| `secret` | target.resource=secrets |
| `clusterrole` | target.resource=clusterroles |
| `clusterrolebinding` | target.resource=clusterrolebindings |
| `response_successful` | response.code startswith 2 |

### Security Rules (WARNING/ERROR Priority)

| Rule | Description |
|------|-------------|
| Create Privileged Pod | Pod with privileged container |
| Create Sensitive Mount Pod | Pod mounting sensitive host paths (/proc, docker.sock, etc.) |
| Create HostNetwork Pod | Pod using host network |
| Create HostPid Pod | Pod using host PID namespace |
| Create HostIPC Pod | Pod using host IPC namespace |
| Anonymous Request Allowed | Request by anonymous user was allowed |
| Attach to cluster-admin Role | ClusterRoleBinding to cluster-admin |
| ClusterRole With Wildcard Created | Role with wildcard resources or verbs |
| ClusterRole With Pod Exec Created | Role with pods/exec privileges |
| K8s Secret Get Successfully | Successful secret retrieval |

### Activity Rules (INFO Priority)

Rules for monitoring general Kubernetes activity:
- K8s Deployment Created/Deleted
- K8s Service Created/Deleted
- K8s ConfigMap Created/Deleted
- K8s Namespace Created/Deleted
- K8s Serviceaccount Created/Deleted
- K8s Role/ClusterRole Created/Deleted
- K8s RoleBinding/ClusterRoleBinding Created/Deleted
- K8s Secret Created/Deleted

**Source:** [`rules/k8s_audit_rules.yaml`](../../../refs/falcosecurity/plugins/plugins/k8saudit/rules/k8s_audit_rules.yaml)

---

## Usage Examples

### Running with Webhook

```shell
falco -c falco.yaml -r k8s_audit_rules.yaml
```

**Example output:**
```
14:09:12.581541000: Warning Pod started with privileged container (user=system:serviceaccount:kube-system:replicaset-controller pod=nginx-deployment-5cdcc99dbf-rgw6z ns=default image=nginx)
```

---

## Cloud Provider Variants

The k8saudit plugin has cloud-specific variants for managed Kubernetes services. All variants share the same `ka.*` field extraction logic and work with the same `k8s_audit_rules.yaml` ruleset, differing only in how they consume audit logs from each cloud provider.

| Variant | Cloud Provider | Data Source | Plugin ID |
|---------|---------------|-------------|-----------|
| `k8saudit-eks` | AWS EKS | CloudWatch Logs | 9 |
| `k8saudit-gke` | Google GKE | Pub/Sub | 16 |
| `k8saudit-aks` | Azure AKS | Event Hub | 21 |
| `k8saudit-ovh` | OVHcloud MKS | LDP WebSocket | 22 |

### k8saudit-eks (Amazon EKS)

Consumes Kubernetes audit logs from Amazon CloudWatch Logs for EKS clusters.

**Architecture:**
```
EKS Cluster → CloudWatch Logs → k8saudit-eks Plugin → Falco
```

**Configuration:**
```yaml
plugins:
  - name: k8saudit-eks
    library_path: libk8saudit-eks.so
    init_config:
      shift: 10           # Delay in seconds before reading logs
      polling_interval: 5 # Polling interval in seconds
      use_async: false
      buffer_size: 500
    open_params: "my-cluster"  # EKS cluster name
```

**Required IAM Policy:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadAccessToCloudWatchLogs",
            "Effect": "Allow",
            "Action": [
                "logs:Describe*",
                "logs:FilterLogEvents",
                "logs:Get*",
                "logs:List*"
            ],
            "Resource": [
                "arn:aws:logs:*:*:log-group:/aws/eks/*/cluster:*"
            ]
        }
    ]
}
```

**Prerequisites:**
- Enable control plane logging (Audit) on EKS cluster
- IAM role with CloudWatch Logs read permissions
- AWS credentials configured (environment variables, IAM role, or config file)

**Source:** [`plugins/k8saudit-eks/`](../../../refs/falcosecurity/plugins/plugins/k8saudit-eks/)

### k8saudit-gke (Google GKE)

Consumes Kubernetes audit logs from Google Cloud Pub/Sub for GKE clusters. The plugin reconstructs standard Kubernetes audit events from Google LogEntry format.

**Architecture:**
```
GKE Cluster → Cloud Logging → Log Router → Pub/Sub → k8saudit-gke Plugin → Falco
```

**Configuration:**
```yaml
plugins:
  - name: k8saudit-gke
    library_path: libk8saudit-gke.so
    init_config:
      project_id: "my-gcp-project"
      subscription_id: "my-subscription"
      # credentials_file: "/path/to/credentials.json"  # Optional
      # max_outstanding_messages: 1000
      # max_outstanding_bytes: 1000000000
      # num_goroutines: 10
```

**Required Setup:**
1. Create Pub/Sub topic for audit logs
2. Create Log Router sink filtering GKE audit logs:
   ```
   resource.type="k8s_cluster" AND
   log_id("cloudaudit.googleapis.com/activity") AND
   resource.labels.cluster_name="my-cluster"
   ```
3. Grant Pub/Sub Subscriber role to Falco's service account

**LogEntry Reconstruction:** The plugin converts Google's LogEntry format back to standard Kubernetes audit event format, enabling use of the same `ka.*` fields and rules.

**Source:** [`plugins/k8saudit-gke/`](../../../refs/falcosecurity/plugins/plugins/k8saudit-gke/)

### k8saudit-aks (Azure AKS)

Consumes Kubernetes audit logs from Azure Event Hub for AKS clusters.

**Architecture:**
```
AKS Cluster → Diagnostic Settings → Event Hub → k8saudit-aks Plugin → Falco
```

**Configuration:**
```yaml
plugins:
  - name: k8saudit-aks
    library_path: libk8saudit-aks.so
    init_config:
      event_hub_name: "my-aks-audit-hub"
      event_hub_namespace: "my-namespace"
      blob_storage_url: "https://mystorageaccount.blob.core.windows.net/checkpoints"
      # max_wait_seconds: 60
```

**Required Setup:**
1. Create Event Hub namespace and hub
2. Configure AKS Diagnostic Settings to export `kube-audit` logs to Event Hub
3. Create Azure Blob Storage container for checkpointing
4. Configure authentication (Managed Identity, Service Principal, or connection string)

**Checkpoint Storage:** Uses Azure Blob Storage to track consumption offset, ensuring no duplicate or missed events across restarts.

**Source:** [`plugins/k8saudit-aks/`](../../../refs/falcosecurity/plugins/plugins/k8saudit-aks/)

### k8saudit-ovh (OVHcloud MKS)

Consumes Kubernetes audit logs from OVHcloud Logs Data Platform (LDP) via WebSocket for Managed Kubernetes Service (MKS).

**Architecture:**
```
MKS Cluster → LDP (Graylog) → WebSocket → k8saudit-ovh Plugin → Falco
```

**Configuration:**
```yaml
plugins:
  - name: k8saudit-ovh
    library_path: libk8saudit-ovh.so
    init_config:
      ldp_alias: "my-ldp-alias"
      ldp_service_name: "ldp-xx-xxxxx"
      # ovh_endpoint: "ovh-eu"  # Default: ovh-eu
```

**Required Setup:**
1. Enable audit logs in OVHcloud MKS control plane settings
2. Subscribe MKS cluster to LDP stream
3. Configure OVH API credentials (environment variables or config file)

**OVH API Authentication:**
```shell
export OVH_ENDPOINT=ovh-eu
export OVH_APPLICATION_KEY=xxx
export OVH_APPLICATION_SECRET=xxx
export OVH_CONSUMER_KEY=xxx
```

**Source:** [`plugins/k8saudit-ovh/`](../../../refs/falcosecurity/plugins/plugins/k8saudit-ovh/)

### Variant Rule Compatibility

All cloud variants are declared as alternatives in the rule dependencies, allowing the same ruleset to work with any variant:

```yaml
- required_plugin_versions:
    - name: k8saudit
      version: 0.7.0
      alternatives:
        - name: k8saudit-aks
        - name: k8saudit-eks
        - name: k8saudit-gke
        - name: k8saudit-ovh
```

**Source:** [`rules/k8s_audit_rules.yaml`](../../../refs/falcosecurity/plugins/plugins/k8saudit/rules/k8s_audit_rules.yaml)

---

## Sources

| Topic | Source File |
|-------|-------------|
| Plugin overview | [`README.md`](../../../refs/falcosecurity/plugins/plugins/k8saudit/README.md) |
| Main plugin class | [`pkg/k8saudit/k8saudit.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/k8saudit.go) |
| Configuration | [`pkg/k8saudit/config.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/config.go) |
| Event sourcing | [`pkg/k8saudit/source.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/source.go) |
| Field extraction | [`pkg/k8saudit/extract.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/extract.go) |
| Field definitions | [`pkg/k8saudit/fields.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/pkg/k8saudit/fields.go) |
| Plugin entry point | [`plugin/k8saudit.go`](../../../refs/falcosecurity/plugins/plugins/k8saudit/plugin/k8saudit.go) |
| Audit policy | [`configs/audit-policy.yaml`](../../../refs/falcosecurity/plugins/plugins/k8saudit/configs/audit-policy.yaml) |
| Webhook config | [`configs/webhook-config.yaml.in`](../../../refs/falcosecurity/plugins/plugins/k8saudit/configs/webhook-config.yaml.in) |
| Detection rules | [`rules/k8s_audit_rules.yaml`](../../../refs/falcosecurity/plugins/plugins/k8saudit/rules/k8s_audit_rules.yaml) |
