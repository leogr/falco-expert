# Falcosidekick

> Fan-out daemon for Falco alerts: HTTP receiver, FalcoPayload data model, 70+ output integrations, priority filtering, deployment patterns, and Falcosidekick-UI.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falcosidekick/`](../refs/falcosecurity/falcosidekick/)

## 1. Overview

Falcosidekick is an ecosystem-scope, stable-status daemon that receives Falco security events via HTTP POST on port 2801 and forwards them to 70+ output integrations simultaneously in a fan-out pattern. It acts as a single integration endpoint for one or more Falco instances, decoupling Falco's alert generation from downstream consumption.

Key capabilities:

- **Single HTTP endpoint** for multiple Falco instances
- **70+ output integrations** spanning chat, alerting, logs, metrics, cloud services, message queues, FaaS, SIEM, and more
- **Fan-out architecture** -- one event is dispatched to all enabled outputs simultaneously
- **Priority-based filtering** -- each output independently filters by minimum priority threshold
- **Event enrichment** -- custom fields, custom tags, and Go-templated fields added to all events
- **Prometheus metrics** -- built-in `/metrics` endpoint for monitoring event flow
- **TLS support** -- mutual TLS for outputs and TLS server mode for the receiver

**Source:** [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md), [`README.md`](../refs/falcosecurity/falcosidekick/README.md)

## 2. Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Falco 1   │     │   Falco 2   │     │   Falco N   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │ HTTP              │ HTTP              │ HTTP
       │ POST              │ POST              │ POST
       └───────────────────┼───────────────────┘
                           ▼
                 ┌─────────────────────┐
                 │   Falcosidekick     │
                 │   (Port 2801)       │
                 └──────────┬──────────┘
                            │ Fan-out
       ┌────────────────────┼────────────────────┐
       ▼                    ▼                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Slack     │     │   Loki      │     │ Alertmanager│
└─────────────┘     └─────────────┘     └─────────────┘
```

Multiple Falco instances send JSON-formatted alerts as HTTP POST requests to Falcosidekick's main handler endpoint (`/`). Falcosidekick deserializes each event into its internal `FalcoPayload` struct, enriches it with custom fields/tags, evaluates per-output priority filters, and dispatches the event to every enabled output in parallel.

**Source:** [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md)

## 3. Falco Integration

### HTTP Output Configuration

The recommended integration method is Falco's native HTTP output. In `falco.yaml`:

```yaml
json_output: true
json_include_output_property: true
http_output:
  enabled: true
  url: "http://falcosidekick:2801/"
```

This causes Falco to POST every alert as a JSON payload to Falcosidekick's main handler. The `json_output: true` setting ensures the payload is machine-parseable; `json_include_output_property: true` includes the formatted output string.

**Source:** [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md), [`configuration.md`](configuration.md)

### Helm Chart Deployment

As a sub-chart of the Falco Helm chart (automatic configuration):

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco --set falcosidekick.enabled=true falcosecurity/falco
```

Or standalone:

```bash
helm install falcosidekick falcosecurity/falcosidekick
```

When deployed as a Falco sub-chart, the HTTP output URL is configured automatically.

**Source:** [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md), [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md)

## 4. FalcoPayload Data Model

The `FalcoPayload` struct is the central data model -- the JSON structure received from Falco and forwarded to all outputs.

```go
type FalcoPayload struct {
    UUID         string                 `json:"uuid,omitempty"`
    Output       string                 `json:"output"`
    Priority     PriorityType           `json:"priority"`
    Rule         string                 `json:"rule"`
    Time         time.Time              `json:"time"`
    OutputFields map[string]interface{} `json:"output_fields"`
    Source       string                 `json:"source"`
    Tags         []string               `json:"tags,omitempty"`
    Hostname     string                 `json:"hostname,omitempty"`
}
```

### Field Reference

| Field | Type | JSON Key | Description |
|-------|------|----------|-------------|
| `UUID` | `string` | `uuid` | Unique identifier for the event (optional) |
| `Output` | `string` | `output` | Formatted output string from the Falco rule |
| `Priority` | `PriorityType` | `priority` | Event priority level (see below) |
| `Rule` | `string` | `rule` | Name of the triggered Falco rule |
| `Time` | `time.Time` | `time` | Event timestamp |
| `OutputFields` | `map[string]interface{}` | `output_fields` | Map of extracted fields from the event (e.g., `proc.name`, `fd.name`, `user.name`) |
| `Source` | `string` | `source` | Event source: `syscall`, `k8s_audit`, or a plugin name |
| `Tags` | `[]string` | `tags` | Tags from the rule definition (optional) |
| `Hostname` | `string` | `hostname` | Source hostname (optional) |

### Priority Levels

Priority is an ordered enumeration from lowest to highest:

```
debug < informational < notice < warning < error < critical < alert < emergency
```

These map directly to Falco's rule priority levels. The ordering is significant for minimum priority filtering (see section 7).

**Source:** [`types/types.go:20-30`](../refs/falcosecurity/falcosidekick/types/types.go)

## 5. Output System

Falcosidekick supports 70+ output integrations organized by category. All outputs follow a consistent configuration pattern:

- **Enable**: Set the primary config key (typically `address`, `webhookurl`, or `hostport`)
- **Filter**: Optional `minimumpriority` to filter by event priority
- **TLS**: Many support `mutualtls` and `checkcert` options
- **Config source**: YAML file or environment variables (env vars override YAML)

### Chat / Messaging (9 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Slack | `slack.webhookurl` | Slack webhook with rich formatting |
| Microsoft Teams | `teams.webhookurl` | Teams incoming webhook |
| Discord | `discord.webhookurl` | Discord webhook with embeds |
| Mattermost | `mattermost.webhookurl` | Self-hosted Mattermost |
| Rocketchat | `rocketchat.webhookurl` | Self-hosted Rocket.Chat |
| Telegram | `telegram.chatid` + `token` | Telegram bot messages |
| Google Chat | `googlechat.webhookurl` | Google Workspace Chat |
| Webex | `webex.webhookurl` | Cisco Webex Teams |
| Zoho Cliq | `cliq.webhookurl` | Zoho Cliq channels |

### Alerting (4 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Alertmanager | `alertmanager.hostport` | Prometheus Alertmanager |
| PagerDuty | `pagerduty.routingkey` | PagerDuty Events API v2 |
| Opsgenie | `opsgenie.apikey` | Atlassian Opsgenie |
| Grafana OnCall | `grafana_oncall.webhookurl` | Grafana OnCall |

### Logs / Log Management (12 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Elasticsearch | `elasticsearch.hostport` | Elasticsearch/OpenSearch |
| Loki | `loki.hostport` | Grafana Loki |
| Splunk | `splunk.hostport` | Splunk HEC |
| Logstash | `logstash.hostport` | Logstash HTTP input |
| Grafana | `grafana.hostport` | Grafana Annotations |
| Syslog | `syslog.host` | RFC 5424 Syslog |
| AWS CloudWatch Logs | `aws.cloudwatchlogs.loggroup` | AWS CloudWatch |
| SumoLogic | `sumologic.receiverurl` | SumoLogic HTTP Source |
| Datadog Logs | `datadoglogs.apikey` | Datadog Log Management |
| OpenObserve | `openobserve.hostport` | OpenObserve |
| Zincsearch | `zincsearch.hostport` | Zincsearch |
| Quickwit | `quickwit.hostport` | Quickwit search engine |

### Metrics / Observability (8 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Prometheus | Built-in `/metrics` | Prometheus metrics endpoint |
| Datadog | `datadog.apikey` | Datadog Events |
| InfluxDB | `influxdb.hostport` | InfluxDB time series |
| Wavefront | `wavefront.endpointhost` | VMware Wavefront |
| Dynatrace | `dynatrace.apitoken` | Dynatrace |
| Spyderbat | `spyderbat.orguid` | Spyderbat platform |
| TimescaleDB | `timescaledb.host` | TimescaleDB |
| OTLP Metrics | `otlp.metrics.endpoint` | OpenTelemetry metrics |

### Object Storage (3 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| AWS S3 | `aws.s3.bucket` | Amazon S3 |
| GCP Storage | `gcp.storage.bucket` | Google Cloud Storage |
| Yandex S3 | `yandex.s3.bucket` | Yandex Object Storage |

### Message Queue / Streaming (13 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Apache Kafka | `kafka.hostport` | Kafka producer |
| Kafka REST Proxy | `kafkarest.address` | Confluent REST Proxy |
| AWS SQS | `aws.sqs.url` | Amazon SQS |
| AWS SNS | `aws.sns.topicarn` | Amazon SNS |
| AWS Kinesis | `aws.kinesis.streamname` | Amazon Kinesis |
| GCP Pub/Sub | `gcp.pubsub.projectid` | Google Pub/Sub |
| Azure Event Hubs | `azure.eventhub.namespace` | Azure Event Hubs |
| NATS | `nats.hostport` | NATS messaging |
| STAN | `stan.hostport` | NATS Streaming (deprecated) |
| RabbitMQ | `rabbitmq.url` | RabbitMQ/AMQP |
| MQTT | `mqtt.broker` | MQTT broker |
| Yandex Data Streams | `yandex.datastreams.streamname` | Yandex Kinesis-compatible |
| Gotify | `gotify.hostport` | Gotify notifications |

### FaaS / Serverless (8 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| AWS Lambda | `aws.lambda.functionname` | Invoke Lambda function |
| GCP Cloud Functions | `gcp.cloudfunctions.name` | Invoke Cloud Function |
| GCP Cloud Run | `gcp.cloudrun.endpoint` | Call Cloud Run service |
| OpenFaaS | `openfaas.gatewayservice` | OpenFaaS functions |
| Kubeless | `kubeless.namespace` | Kubeless functions |
| Fission | `fission.routernamespace` | Fission functions |
| Tekton | `tekton.eventlistener` | Trigger Tekton pipelines |
| KNative/CloudEvents | `cloudevents.address` | CloudEvents spec |

### SIEM (1 output)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| AWS Security Lake | `aws.securitylake.bucket` | OCSF format to Security Lake |

### Web / Webhooks (3 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Webhook | `webhook.address` | Generic HTTP webhook |
| Node-RED | `nodered.address` | Node-RED HTTP endpoint |
| Falcosidekick-UI | `webui.url` | Falcosidekick Web UI |

### Email (1 output)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| SMTP | `smtp.hostport` | Email via SMTP |

### Database (1 output)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Redis | `redis.address` | Redis pub/sub or list |

### Traces / OpenTelemetry (3 outputs)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| OTLP Traces | `otlp.traces.endpoint` | OpenTelemetry traces |
| OTLP Logs | `otlp.logs.endpoint` | OpenTelemetry logs |
| OTLP Metrics | `otlp.metrics.endpoint` | OpenTelemetry metrics |

### Response Engine (1 output)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Falco Talon | `talon.address` | Falco Talon response engine |

### Kubernetes Native (1 output)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| Policy Report | `policyreport.enabled` | Kubernetes PolicyReport CRD |

### Workflow / Automation (1 output)

| Output | Enable Config | Description |
|--------|---------------|-------------|
| n8n | `n8n.address` | n8n workflow automation |

**Source:** [`digests/falcosecurity/falcosidekick/outputs.md`](../digests/falcosecurity/falcosidekick/outputs.md), [`docs/outputs/`](../refs/falcosecurity/falcosidekick/docs/outputs/)

## 6. Configuration

Falcosidekick is configured via a YAML file or environment variables. Environment variables override YAML settings. The env var naming convention converts the YAML key to uppercase and replaces `.` with `_` (e.g., `slack.webhookurl` becomes `SLACK_WEBHOOKURL`).

### General Settings

```yaml
listenaddress: ""          # IP to bind (default: all interfaces)
listenport: 2801           # Listening port (default: 2801)
debug: false               # Log payloads to stdout for debugging
```

### Event Enrichment

```yaml
# Static fields added to every event
customfields:
  environment: "production"
  cluster: "us-west-2"

# Static tags added to every event
customtags:
  - security
  - falco

# Dynamic fields using Go templates evaluated against output_fields
templatedfields:
  namespace: '{{ or (index . "k8s.ns.name") "unknown" }}'
```

### Output Field Format

```yaml
# Customize the output string format
outputFieldFormat: "<timestamp>: <priority> <output>"

# Replace brackets in field names (useful for outputs that cannot handle brackets)
bracketreplacer: "_"
```

### TLS Configuration

```yaml
# Mutual TLS for outgoing connections to outputs
mutualtlsclient:
  certfile: "/etc/certs/client/client.crt"
  keyfile: "/etc/certs/client/client.key"
  cacertfile: "/etc/certs/client/ca.crt"

# TLS server mode for the Falcosidekick receiver itself
tlsserver:
  deploy: false
  certfile: "/etc/certs/server/server.crt"
  keyfile: "/etc/certs/server/server.key"
  mutualtls: false
  cacertfile: "/etc/certs/server/ca.crt"
```

**Source:** [`config_example.yaml`](../refs/falcosecurity/falcosidekick/config_example.yaml), [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md)

## 7. Priority Filtering

Each output can independently filter events by setting a `minimumpriority` threshold. Only events at or above the specified priority level are forwarded to that output. This enables routing high-severity alerts to pagers while sending all events to a log store.

```yaml
slack:
  webhookurl: "https://hooks.slack.com/..."
  minimumpriority: "warning"       # Only warning and above

webhook:
  address: "http://siem:8080/events"
  minimumpriority: ""              # All events (debug and above)
```

Priority order (lowest to highest):

```
debug < informational < notice < warning < error < critical < alert < emergency
```

An empty `minimumpriority` or omitting it entirely means all events pass the filter (equivalent to `debug`).

**Source:** [`docs/outputs/slack.md`](../refs/falcosecurity/falcosidekick/docs/outputs/slack.md), [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md)

## 8. Message Formatting

Many outputs support custom message formatting using Go templates. Templates have access to all `FalcoPayload` fields:

```yaml
slack:
  webhookurl: "https://hooks.slack.com/..."
  messageformat: 'Alert: rule *{{ .Rule }}* triggered by user *{{ index .OutputFields "user.name" }}*'
```

### Available Template Fields

| Template Expression | Description |
|---------------------|-------------|
| `{{ .Output }}` | Formatted output string from Falco |
| `{{ .Priority }}` | Priority level as string |
| `{{ .Rule }}` | Rule name |
| `{{ .Time }}` | Event timestamp |
| `{{ .Source }}` | Event source (syscall, k8s_audit, plugin) |
| `{{ .UUID }}` | Event unique identifier |
| `{{ .Hostname }}` | Source hostname |
| `{{ .Tags }}` | Rule tags (slice) |
| `{{ index .OutputFields "field.name" }}` | Access a specific output field by key |

The `index` function is required for `OutputFields` because the map keys contain dots (e.g., `user.name`, `proc.cmdline`, `k8s.ns.name`).

**Source:** [`docs/outputs/slack.md`](../refs/falcosecurity/falcosidekick/docs/outputs/slack.md)

## 9. Endpoints

Falcosidekick exposes the following HTTP endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | POST | Main handler -- receives FalcoPayload JSON, dispatches to outputs |
| `/healthz` | GET | Health check, returns HTTP 200 |
| `/test` | POST | Sends a synthetic test event to all enabled outputs |
| `/metrics` | GET | Prometheus metrics endpoint |
| `/debug/vars` | GET | Go expvar metrics (JSON format) |

### Prometheus Metrics

The `/metrics` endpoint exposes:

- `falcosidekick_inputs_total{source,priority}` -- total events received, labeled by source and priority
- `falcosidekick_outputs_total{output,status}` -- total events dispatched, labeled by output name and delivery status

These metrics enable monitoring event throughput, identifying delivery failures, and alerting on Falcosidekick health.

**Source:** [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md), [`docs/outputs/prometheus.md`](../refs/falcosecurity/falcosidekick/docs/outputs/prometheus.md)

## 10. Deployment Patterns

### Docker

```bash
docker run -d -p 2801:2801 \
  -e SLACK_WEBHOOKURL=https://hooks.slack.com/services/XXX \
  -e LOKI_HOSTPORT=http://loki:3100 \
  falcosecurity/falcosidekick
```

### Systemd

Download the binary release, place it at `/usr/local/bin/falcosidekick`, create a config at `/etc/falcosidekick/config.yaml`, and run via a systemd unit:

```ini
[Unit]
Description=Falcosidekick
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=/usr/local/bin/falcosidekick -c /etc/falcosidekick/config.yaml

[Install]
WantedBy=default.target
```

### Kubernetes (Helm)

**As Falco sub-chart** (recommended -- automatic HTTP output configuration):

```bash
helm install falco --set falcosidekick.enabled=true falcosecurity/falco
```

**Standalone:**

```bash
helm install falcosidekick falcosecurity/falcosidekick
```

The Helm chart defaults to 2 replicas for high availability. Both replicas receive the same events and forward to the same outputs, providing redundancy.

**Source:** [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md), [`README.md`](../refs/falcosecurity/falcosidekick/README.md)

## 11. Falcosidekick-UI

Falcosidekick-UI is a companion web UI (separate project, [falcosecurity/falcosidekick-ui](https://github.com/falcosecurity/falcosidekick-ui)) for visualizing and exploring Falco events. Status: Ecosystem/Incubating with limited curation.

```
Falco ──▶ Falcosidekick ──▶ Redis (RediSearch) ◀── Falcosidekick-UI (Port 2802)
                 │
                 └──▶ webui output
```

Key characteristics:

- **Vue.js web application** serving on port 2802
- **Requires Redis** with the RediSearch module (v2+) for event storage and querying
- **Features**: dashboard view, event filtering by priority/rule/source/tags, search with pagination, time-based filtering, event counts and statistics
- **Integration**: configure Falcosidekick's `webui.url` output to point to the UI instance
- **Deployment**: available as a Helm sub-chart of the Falcosidekick chart

> Note: Falcosidekick-UI is Incubating status with limited maintenance -- primarily automated dependency bumps. Recommended for development, testing, and demos.

**Source:** [`digests/falcosecurity/falcosidekick-ui.md`](../digests/falcosecurity/falcosidekick-ui.md), [`refs/falcosecurity/falcosidekick-ui/`](../refs/falcosecurity/falcosidekick-ui/)

## 12. Related Specs

| Spec | Relationship |
|------|-------------|
| [`output-system.md`](output-system.md) | Falco's native output system, including the `http_output` channel that sends events to Falcosidekick |
| [`configuration.md`](configuration.md) | Falco's `http_output` and `json_output` config keys used for Falcosidekick integration |
| [`falcoctl.md`](falcoctl.md) | Falcoctl manages Falco artifacts; Falcosidekick is separately distributed |

## 13. Sources

| Topic | Source |
|-------|--------|
| Overview, architecture, installation | [`README.md`](../refs/falcosecurity/falcosidekick/README.md) |
| FalcoPayload data model | [`types/types.go`](../refs/falcosecurity/falcosidekick/types/types.go) |
| Configuration reference | [`config_example.yaml`](../refs/falcosecurity/falcosidekick/config_example.yaml) |
| Output implementations | [`outputs/`](../refs/falcosecurity/falcosidekick/outputs/) |
| Output documentation | [`docs/outputs/`](../refs/falcosecurity/falcosidekick/docs/outputs/) |
| Digest: overview | [`digests/falcosecurity/falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md) |
| Digest: outputs | [`digests/falcosecurity/falcosidekick/outputs.md`](../digests/falcosecurity/falcosidekick/outputs.md) |
| Digest: UI | [`digests/falcosecurity/falcosidekick-ui.md`](../digests/falcosecurity/falcosidekick-ui.md) |
| Helm charts | [`digests/falcosecurity/charts.md`](../digests/falcosecurity/charts.md) |
