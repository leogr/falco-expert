# falcosidekick Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falcosidekick/`](../../../refs/falcosecurity/falcosidekick/) | **Commit:** `1f8b740` (February 2, 2026)

**Repository:** [falcosecurity/falcosidekick](https://github.com/falcosecurity/falcosidekick)
**Scope:** Ecosystem
**Status:** Stable

A daemon that receives Falco events via HTTP and forwards them to multiple outputs in a fan-out pattern. Essential for integrating Falco with external systems, SIEMs, alerting platforms, and observability stacks.

## Key Value

- **Single endpoint** for multiple Falco instances
- **70+ output integrations** across chat, alerting, logs, cloud services, message queues
- **Fan-out architecture** - one event can go to many destinations simultaneously
- **Filtering by priority** - each output can have minimum priority threshold
- **Custom fields/tags** - enrich events with additional metadata
- **Metrics** - Prometheus, StatsD, OTLP for monitoring

**Source:** [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md)

## Digest Contents

| File | Description |
|------|-------------|
| [README.md](README.md) | Overview, architecture, Falco integration (this file) |
| [outputs.md](outputs.md) | Complete output reference organized by category |

## Architecture

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

**Source:** [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md)

## Falco Integration

### HTTP Output Configuration (Recommended)

In `falco.yaml`:

```yaml
json_output: true
json_include_output_property: true
http_output:
  enabled: true
  url: "http://falcosidekick:2801/"
```

### Helm Chart (Falco + Falcosidekick)

Deploy as dependency of Falco chart (automatic configuration):

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco --set falcosidekick.enabled=true falcosecurity/falco
```

Or standalone:

```bash
helm install falcosidekick falcosecurity/falcosidekick
```

See [`charts.md`](../charts.md) for detailed Helm configuration.

**Source:** [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md)

## FalcoPayload Structure

The JSON payload received from Falco and forwarded to outputs:

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

| Field | Description |
|-------|-------------|
| `uuid` | Unique identifier for the event |
| `output` | Formatted output string from Falco |
| `priority` | Event priority (Emergency, Alert, Critical, Error, Warning, Notice, Informational, Debug) |
| `rule` | Name of the triggered rule |
| `time` | Event timestamp |
| `output_fields` | Map of extracted fields from the event |
| `source` | Event source (syscall, k8s_audit, plugin name, etc.) |
| `tags` | Rule tags |
| `hostname` | Source hostname |

**Source:** [`types/types.go:20-30`](../../../refs/falcosecurity/falcosidekick/types/types.go)

## Installation

### Docker

```bash
docker run -d -p 2801:2801 \
  -e SLACK_WEBHOOKURL=https://hooks.slack.com/services/XXX \
  -e LOKI_HOSTPORT=http://loki:3100 \
  falcosecurity/falcosidekick
```

### Systemd

```bash
# Download
VER=$(curl -sI https://github.com/falcosecurity/falcosidekick/releases/latest | awk -F '/' '/^location/ {print substr($NF, 1, length($NF)-1)}')
wget -c https://github.com/falcosecurity/falcosidekick/releases/download/${VER}/falcosidekick_${VER}_linux_amd64.tar.gz -O - | tar -xz
sudo mv falcosidekick /usr/local/bin/

# Create config
sudo mkdir -p /etc/falcosidekick
# Edit /etc/falcosidekick/config.yaml

# Systemd unit
sudo tee /etc/systemd/system/falcosidekick.service << 'EOF'
[Unit]
Description=Falcosidekick
After=network.target

[Service]
Type=simple
Restart=always
ExecStart=/usr/local/bin/falcosidekick -c /etc/falcosidekick/config.yaml

[Install]
WantedBy=default.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now falcosidekick
```

**Source:** [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md)

## Configuration

Configuration via YAML file or environment variables. Environment variables override YAML settings.

### General Settings

```yaml
listenaddress: ""          # IP to bind (default: all)
listenport: 2801           # Port (default: 2801)
debug: false               # Log payloads to stdout

# Custom fields added to all events
customfields:
  environment: "production"
  cluster: "us-west-2"

# Custom tags added to all events
customtags:
  - security
  - falco

# Templated fields using Go templates + output_fields
templatedfields:
  namespace: '{{ or (index . "k8s.ns.name") "unknown" }}'

# Output field format customization
outputFieldFormat: "<timestamp>: <priority> <output>"

# Bracket replacer for field names (useful for some outputs)
bracketreplacer: "_"
```

### TLS Configuration

```yaml
# Mutual TLS for outputs
mutualtlsclient:
  certfile: "/etc/certs/client/client.crt"
  keyfile: "/etc/certs/client/client.key"
  cacertfile: "/etc/certs/client/ca.crt"

# TLS server mode
tlsserver:
  deploy: false
  certfile: "/etc/certs/server/server.crt"
  keyfile: "/etc/certs/server/server.key"
  mutualtls: false
  cacertfile: "/etc/certs/server/ca.crt"
```

**Source:** [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md), [`config_example.yaml`](../../../refs/falcosecurity/falcosidekick/config_example.yaml)

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Main handler - receives Falco events |
| `/healthz` | Health check (HTTP 200) |
| `/ping` | Returns "pong" (deprecated, removed in 3.0.0) |
| `/test` | Send test event to all enabled outputs |
| `/debug/vars` | Go expvar metrics (JSON) |
| `/metrics` | Prometheus metrics endpoint |

**Source:** [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md)

## Metrics

### Prometheus

Endpoint: `/metrics`

Key metrics:
- `falcosidekick_inputs_total` - Total events received by source/priority
- `falcosidekick_outputs_total` - Total events sent by output/status

### StatsD / DogStatsD

Push metrics to external StatsD server. See [outputs.md](outputs.md#statsd--dogstatsd).

### OTLP Metrics

Export metrics via OpenTelemetry Protocol. See [outputs.md](outputs.md#metrics--observability).

**Source:** [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md)

## Priority Filtering

Each output can filter events by minimum priority:

```yaml
slack:
  webhookurl: "https://hooks.slack.com/..."
  minimumpriority: "warning"  # Only warning and above

webhook:
  address: "http://siem:8080/events"
  minimumpriority: ""  # All events (debug and above)
```

Priority order (lowest to highest):
`debug` < `informational` < `notice` < `warning` < `error` < `critical` < `alert` < `emergency`

**Source:** [`docs/outputs/slack.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/slack.md)

## Message Formatting (Go Templates)

Many outputs support Go templates for custom message formatting:

```yaml
slack:
  webhookurl: "https://hooks.slack.com/..."
  messageformat: 'Alert: rule *{{ .Rule }}* triggered by user *{{ index .OutputFields "user.name" }}*'
```

Available template fields:
- `{{ .Output }}` - Formatted output string
- `{{ .Priority }}` - Priority as string
- `{{ .Rule }}` - Rule name
- `{{ .Time }}` - Timestamp
- `{{ index .OutputFields "field.name" }}` - Specific output field

**Source:** [`docs/outputs/slack.md`](../../../refs/falcosecurity/falcosidekick/docs/outputs/slack.md)

## Testing

### Send Test Event

```bash
curl -X POST http://localhost:2801/test
```

### Manual Event

```bash
curl -X POST "http://localhost:2801/" \
  -H "Content-Type: application/json" \
  -d '{
    "output": "File below a known binary directory opened for writing",
    "priority": "Error",
    "rule": "Write below binary dir",
    "time": "2024-01-15T10:30:00.000000000Z",
    "output_fields": {
      "fd.name": "/bin/hack",
      "proc.cmdline": "touch /bin/hack",
      "user.name": "root"
    },
    "source": "syscall",
    "hostname": "node-1"
  }'
```

**Source:** [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, installation | [`README.md`](../../../refs/falcosecurity/falcosidekick/README.md) |
| Configuration example | [`config_example.yaml`](../../../refs/falcosecurity/falcosidekick/config_example.yaml) |
| FalcoPayload type | [`types/types.go`](../../../refs/falcosecurity/falcosidekick/types/types.go) |
| Output implementations | [`outputs/`](../../../refs/falcosecurity/falcosidekick/outputs/) |
| Output documentation | [`docs/outputs/`](../../../refs/falcosecurity/falcosidekick/docs/outputs/) |

## Related Documentation

- [outputs.md](outputs.md) - Complete output reference
- [`charts.md`](../charts.md) - Helm chart for falcosidekick
- [`falco/outputs.md`](../falco/outputs.md) - Falco native outputs (http_output)
- [`falco/configuration.md`](../falco/configuration.md) - Falco configuration for HTTP output
