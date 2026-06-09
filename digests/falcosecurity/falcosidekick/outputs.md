# Falcosidekick Outputs Reference

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falcosidekick/docs/outputs/`](../../../refs/falcosecurity/falcosidekick/docs/outputs/)

Complete reference for all 70+ Falcosidekick output integrations, organized by category.

## Output Configuration Pattern

All outputs follow a consistent pattern:
- **Enable**: Set the primary config (usually `address`, `webhookurl`, or `hostport`)
- **Filter**: Optional `minimumpriority` to filter by event priority
- **TLS**: Many support `mutualtls` and `checkcert` options
- **Config**: YAML file or environment variables (env vars override YAML)

## Chat / Messaging

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Slack** | `slack.webhookurl` | Slack webhook with rich formatting |
| **Microsoft Teams** | `teams.webhookurl` | Teams incoming webhook |
| **Discord** | `discord.webhookurl` | Discord webhook with embeds |
| **Mattermost** | `mattermost.webhookurl` | Self-hosted Mattermost |
| **Rocketchat** | `rocketchat.webhookurl` | Self-hosted Rocket.Chat |
| **Telegram** | `telegram.chatid` + `token` | Telegram bot messages |
| **Google Chat** | `googlechat.webhookurl` | Google Workspace Chat |
| **Webex** | `webex.webhookurl` | Cisco Webex Teams |
| **Zoho Cliq** | `cliq.webhookurl` | Zoho Cliq channels |

### Slack Configuration Example

```yaml
slack:
  webhookurl: "https://hooks.slack.com/services/XXX/YYY/ZZZ"
  channel: "#security-alerts"       # Override channel
  username: "Falcosidekick"
  icon: "https://..."
  outputformat: "all"               # all, text, fields
  messageformat: 'Rule *{{ .Rule }}* triggered'  # Go template
  minimumpriority: "warning"
```

**Docs:** [`docs/outputs/slack.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/slack.md)

## Alerting

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Alertmanager** | `alertmanager.hostport` | Prometheus Alertmanager |
| **PagerDuty** | `pagerduty.routingkey` | PagerDuty Events API v2 |
| **Opsgenie** | `opsgenie.apikey` | Atlassian Opsgenie |
| **Grafana OnCall** | `grafana_oncall.webhookurl` | Grafana OnCall |

### Alertmanager Configuration Example

```yaml
alertmanager:
  hostport: "http://alertmanager:9093"
  endpoint: "/api/v2/alerts"        # Default
  expiresafter: 0                   # 0 = no expiration
  extralabels: ""                   # "key1:value1,key2:value2"
  extraannotations: ""
  customseveritymap: ""             # "Critical:critical,Warning:warning"
  dropeventdefaultpriority: "critical"
  dropeventthresholds: ""
  mutualtls: false
  checkcert: true
  minimumpriority: ""
```

**Docs:** [`docs/outputs/alertmanager.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/alertmanager.md)

## Logs / Log Management

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Elasticsearch** | `elasticsearch.hostport` | Elasticsearch/OpenSearch |
| **Loki** | `loki.hostport` | Grafana Loki |
| **Splunk** | `splunk.hostport` | Splunk HEC |
| **Logstash** | `logstash.hostport` | Logstash HTTP input |
| **Grafana** | `grafana.hostport` | Grafana Annotations |
| **Syslog** | `syslog.host` | RFC 5424 Syslog |
| **AWS CloudWatch Logs** | `aws.cloudwatchlogs.loggroup` | AWS CloudWatch |
| **SumoLogic** | `sumologic.receiverurl` | SumoLogic HTTP Source |
| **Datadog Logs** | `datadoglogs.apikey` | Datadog Log Management |
| **OpenObserve** | `openobserve.hostport` | OpenObserve (Zinc successor) |
| **Zincsearch** | `zincsearch.hostport` | Zincsearch |
| **Quickwit** | `quickwit.hostport` | Quickwit search engine |

### Loki Configuration Example

```yaml
loki:
  hostport: "http://loki:3100"
  endpoint: "/loki/api/v1/push"
  tenant: ""                        # X-Scope-OrgID header
  user: ""                          # Basic auth
  apikey: ""                        # Basic auth password
  extralabels: ""                   # "key1:value1,key2:value2"
  customheaders: {}
  mutualtls: false
  checkcert: true
  minimumpriority: ""
```

**Docs:** [`docs/outputs/loki.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/loki.md)

### Elasticsearch Configuration Example

```yaml
elasticsearch:
  hostport: "https://elasticsearch:9200"
  index: "falco"                    # Index name
  type: "_doc"                      # Document type
  suffix: "daily"                   # none, daily, monthly, yearly
  username: ""
  password: ""
  flattenfields: false              # Flatten nested output_fields
  createindextemplate: false        # Auto-create index template
  numberofshards: 3
  numberofreplicas: 3
  mutualtls: false
  checkcert: true
  minimumpriority: ""
```

**Docs:** [`docs/outputs/elasticsearch.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/elasticsearch.md)

## Metrics / Observability

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Prometheus** | Built-in `/metrics` | Prometheus metrics endpoint |
| **Datadog** | `datadog.apikey` | Datadog Events |
| **InfluxDB** | `influxdb.hostport` | InfluxDB time series |
| **Wavefront** | `wavefront.endpointhost` | VMware Wavefront |
| **Dynatrace** | `dynatrace.apitoken` | Dynatrace |
| **Spyderbat** | `spyderbat.orguid` | Spyderbat platform |
| **TimescaleDB** | `timescaledb.host` | TimescaleDB |
| **OTLP Metrics** | `otlp.metrics.endpoint` | OpenTelemetry metrics |

### Prometheus (Built-in)

Endpoint: `/metrics`

```yaml
prometheus:
  extralabels: ""                   # Additional labels for all metrics
```

Key metrics exposed:
- `falcosidekick_inputs_total{source,priority}` - Events received
- `falcosidekick_outputs_total{output,status}` - Events sent

**Docs:** [`docs/outputs/prometheus.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/prometheus.md)

## Object Storage

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **AWS S3** | `aws.s3.bucket` | Amazon S3 |
| **GCP Storage** | `gcp.storage.bucket` | Google Cloud Storage |
| **Yandex S3** | `yandex.s3.bucket` | Yandex Object Storage |

### AWS S3 Configuration Example

```yaml
aws:
  accesskeyid: ""                   # Or use IAM role
  secretaccesskey: ""
  region: "us-east-1"
  rolearn: ""                       # For cross-account
  externalid: ""
  checkidentity: true
  s3:
    bucket: "falco-events"
    prefix: ""                      # Object prefix
    endpoint: ""                    # Custom endpoint (MinIO, etc.)
    minimumpriority: ""
```

**Docs:** [`docs/outputs/aws_s3.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/aws_s3.md)

## Message Queue / Streaming

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Apache Kafka** | `kafka.hostport` | Kafka producer |
| **Kafka REST Proxy** | `kafkarest.address` | Confluent REST Proxy |
| **AWS SQS** | `aws.sqs.url` | Amazon SQS |
| **AWS SNS** | `aws.sns.topicarn` | Amazon SNS |
| **AWS Kinesis** | `aws.kinesis.streamname` | Amazon Kinesis |
| **GCP Pub/Sub** | `gcp.pubsub.projectid` | Google Pub/Sub |
| **Azure Event Hubs** | `azure.eventhub.namespace` | Azure Event Hubs |
| **NATS** | `nats.hostport` | NATS messaging |
| **STAN** | `stan.hostport` | NATS Streaming (deprecated) |
| **RabbitMQ** | `rabbitmq.url` | RabbitMQ/AMQP |
| **MQTT** | `mqtt.broker` | MQTT broker |
| **Yandex Data Streams** | `yandex.datastreams.streamname` | Yandex Kinesis-compatible |
| **Gotify** | `gotify.hostport` | Gotify notifications |

### Kafka Configuration Example

```yaml
kafka:
  hostport: "kafka:9092"
  topic: "falco-events"
  partition: 0                      # -1 for auto
  messagekey: ""                    # Go template for key
  sasl: ""                          # SASL mechanism
  tls: false
  username: ""
  password: ""
  minimumpriority: ""
```

**Docs:** [`docs/outputs/kafka.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/kafka.md)

## FaaS / Serverless

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **AWS Lambda** | `aws.lambda.functionname` | Invoke Lambda function |
| **GCP Cloud Functions** | `gcp.cloudfunctions.name` | Invoke Cloud Function |
| **GCP Cloud Run** | `gcp.cloudrun.endpoint` | Call Cloud Run service |
| **OpenFaaS** | `openfaas.gatewayservice` | OpenFaaS functions |
| **Kubeless** | `kubeless.namespace` | Kubeless functions |
| **Fission** | `fission.routernamespace` | Fission functions |
| **Tekton** | `tekton.eventlistener` | Trigger Tekton pipelines |
| **KNative/CloudEvents** | `cloudevents.address` | CloudEvents spec |

### AWS Lambda Configuration Example

```yaml
aws:
  accesskeyid: ""
  secretaccesskey: ""
  region: "us-east-1"
  lambda:
    functionname: "FalcoEventProcessor"
    invocationtype: "RequestResponse"  # or "Event" for async
    minimumpriority: ""
```

**Docs:** [`docs/outputs/aws_lambda.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/aws_lambda.md)

## SIEM

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **AWS Security Lake** | `aws.securitylake.bucket` | OCSF format to Security Lake |

### AWS Security Lake Configuration

```yaml
aws:
  accesskeyid: ""
  secretaccesskey: ""
  region: "us-east-1"
  securitylake:
    bucket: "aws-security-data-lake-xxx"
    region: "us-east-1"
    prefix: "ext/falco"
    accountid: "123456789012"
    interval: 5                     # Minutes between batches
    batchsize: 1000
    minimumpriority: ""
```

**Docs:** [`docs/outputs/aws_security_lake.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/aws_security_lake.md)

## Web / Webhooks

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Webhook** | `webhook.address` | Generic HTTP webhook |
| **Node-RED** | `nodered.address` | Node-RED HTTP endpoint |
| **Falcosidekick-UI** | `webui.url` | Falcosidekick Web UI |

### Webhook Configuration Example

```yaml
webhook:
  address: "https://my-service/falco-events"
  method: "POST"                    # POST or PUT
  customheaders:
    Authorization: "Bearer xxx"
    X-Custom-Header: "value"
  mutualtls: false
  checkcert: true
  minimumpriority: ""
```

**Docs:** [`docs/outputs/webhook.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/webhook.md)

## Email

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **SMTP** | `smtp.hostport` | Email via SMTP |

### SMTP Configuration Example

```yaml
smtp:
  hostport: "smtp.gmail.com:587"
  tls: true
  authmechanism: "plain"            # plain, login, crammd5, none
  user: "sender@example.com"
  password: "app-password"
  from: "falco@example.com"
  to: "security-team@example.com"
  outputformat: "html"              # html or text
  minimumpriority: "error"
```

**Docs:** [`docs/outputs/smtp.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/smtp.md)

## Database

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Redis** | `redis.address` | Redis pub/sub or list |

### Redis Configuration Example

```yaml
redis:
  address: "redis:6379"
  password: ""
  database: 0
  storagetype: "list"               # list or pub
  key: "falco-events"               # List key or pub/sub channel
  minimumpriority: ""
```

**Docs:** [`docs/outputs/redis.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/redis.md)

## Workflow / Automation

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **n8n** | `n8n.address` | n8n workflow automation |

## Traces / OpenTelemetry

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **OTLP Traces** | `otlp.traces.endpoint` | OpenTelemetry traces |
| **OTLP Logs** | `otlp.logs.endpoint` | OpenTelemetry logs |
| **OTLP Metrics** | `otlp.metrics.endpoint` | OpenTelemetry metrics |

### OTLP Configuration Example

```yaml
otlp:
  traces:
    endpoint: "http://otel-collector:4318/v1/traces"
    protocol: "http"                # http or grpc
    timeout: 10000
    headers: {}
    duration: 1000                  # Trace duration in ms
    extraenvvars: {}
    synced: false
    checkcert: true
    minimumpriority: ""
```

**Docs:** [`docs/outputs/otlp_traces.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/otlp_traces.md)

## Response Engine

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Falco Talon** | `talon.address` | Falco Talon response engine |

### Falco Talon Configuration

```yaml
talon:
  address: "http://falco-talon:2803"
  checkcert: true
  minimumpriority: ""
```

**Docs:** [`docs/outputs/talon.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/talon.md)

## Kubernetes Native

| Output | Enable Config | Description |
|--------|---------------|-------------|
| **Policy Report** | `policyreport.enabled` | Kubernetes PolicyReport CRD |

### Policy Report Configuration

```yaml
policyreport:
  enabled: true
  kubeconfig: ""                    # Uses in-cluster config if empty
  prunebypriority: false
  maxevents: 1000
  minimumpriority: ""
```

Generates Kubernetes `PolicyReport` custom resources compatible with Policy Report tools.

**Docs:** [`docs/outputs/policy_report.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/policy_report.md)

## StatsD / DogStatsD

For monitoring Falcosidekick itself:

```yaml
statsd:
  forwarder: "statsd:8125"
  namespace: "falcosidekick."

dogstatsd:
  forwarder: "datadog-agent:8125"
  namespace: "falcosidekick."
  tags: "env:production,service:falcosidekick"
```

**Docs:** [`docs/outputs/statsd.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/statsd.md), [`docs/outputs/dogstatsd.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/dogstatsd.md)

## Common Configuration Options

Most outputs support these common options:

| Option | Description |
|--------|-------------|
| `minimumpriority` | Filter events by minimum priority |
| `mutualtls` | Enable mutual TLS authentication |
| `checkcert` | Verify server certificate |
| `customheaders` | Add custom HTTP headers |

## Environment Variables

All YAML settings can be set via environment variables:
- Convert to uppercase
- Replace `.` with `_`
- Example: `slack.webhookurl` → `SLACK_WEBHOOKURL`

Environment variables override YAML file settings.

## Sources

| Topic | Source |
|-------|--------|
| Output docs | [`docs/outputs/`](../../../refs/falcosecurity/falcosidekick/docs/outputs/) |
| Configuration types | [`types/types.go`](../../../refs/falcosecurity/falcosidekick/types/types.go) |
| Full config example | [`config_example.yaml`](../../../refs/falcosecurity/falcosidekick/config_example.yaml) |
