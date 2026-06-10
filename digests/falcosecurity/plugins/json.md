# JSON Plugin - Design and Architecture

**Era:** 0.44 | **Status:** Stable | **Scope:** Core

The `json` plugin is a general-purpose extractor plugin that extracts arbitrary values from JSON-encoded event payloads. It is commonly used alongside source plugins like `k8saudit`, `cloudtrail`, and `okta` that represent their events as JSON.

**Source:** [`plugins/json/`](../../../refs/falcosecurity/plugins/plugins/json/)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Plugin Capabilities](#plugin-capabilities)
- [Supported Fields](#supported-fields)
- [JSON Pointer Syntax](#json-pointer-syntax)
- [Configuration](#configuration)
- [Event Flow](#event-flow)
- [Usage Examples](#usage-examples)
- [Integration with Source Plugins](#integration-with-source-plugins)
- [Sources](#sources)

---

## Overview

| Property | Value |
|----------|-------|
| Plugin Name | `json` |
| Plugin Version | 0.7.4 |
| Language | Go |
| Event Source | None (extractor only) |
| Capabilities | Extraction |
| SDK Version | plugin-sdk-go v0.8.3 |

The json plugin is an **extractor-only plugin**, meaning it does not generate events but rather extracts fields from events produced by other source plugins. It parses JSON payloads using the high-performance [fastjson](https://github.com/valyala/fastjson) library and supports the RFC 6901 JSON Pointer syntax for navigating nested structures.

**Source:** [`plugins/json/README.md`](../../../refs/falcosecurity/plugins/plugins/json/README.md), [`pkg/json/json.go:39-44`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json.go)

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                       Falco Event Pipeline                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────────────────┐         ┌────────────────────────────┐   │
│   │   Source Plugin     │         │      JSON Plugin           │   │
│   │  (k8saudit, etc.)   │         │   (Extractor Plugin)       │   │
│   │                     │         │                            │   │
│   │  Generates events   │────────▶│  Extracts fields from      │   │
│   │  with JSON payload  │         │  JSON event payload        │   │
│   │                     │         │                            │   │
│   └─────────────────────┘         │  ┌──────────────────────┐  │   │
│                                   │  │    fastjson Parser   │  │   │
│                                   │  │   (high performance) │  │   │
│                                   │  └──────────────────────┘  │   │
│                                   │                            │   │
│                                   │  ┌──────────────────────┐  │   │
│                                   │  │  JSON Pointer (6901) │  │   │
│                                   │  │   Path Navigation    │  │   │
│                                   │  └──────────────────────┘  │   │
│                                   │                            │   │
│                                   └────────────────────────────┘   │
│                                              │                      │
│                                              ▼                      │
│                                   ┌──────────────────────┐          │
│                                   │    Falco Rules       │          │
│                                   │                      │          │
│                                   │  Condition uses      │          │
│                                   │  json.value[/path]   │          │
│                                   │  in filter           │          │
│                                   └──────────────────────┘          │
└────────────────────────────────────────────────────────────────────┘
```

### Plugin Structure

```go
type Plugin struct {
    plugins.BasePlugin
    jparser     fastjson.Parser      // High-performance JSON parser
    jdata       *fastjson.Value      // Parsed JSON data
    jdataEvtnum uint64               // Event number for cache validation
    Config      PluginConfig         // Plugin configuration
}
```

The plugin caches the parsed JSON for each event (identified by `jdataEvtnum`) to avoid re-parsing when multiple fields are extracted from the same event.

**Source:** [`pkg/json/json.go:46-52`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json.go)

---

## Plugin Capabilities

The json plugin implements a single capability:

| Capability | Purpose | Implementation |
|------------|---------|----------------|
| `extraction` | Extract `json.*` and `jevt.*` fields from JSON payloads | [`pkg/json/json.go:125-225`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json.go) |

### Extraction Logic

1. **Quick sanity check**: Verify the payload starts with `{` or `[`
2. **Lazy parsing**: Parse JSON only once per event (cached by event number)
3. **Field extraction**: Navigate JSON using pointer syntax or return full object
4. **Type handling**: String values are returned as-is; other types are serialized

```go
// Extraction flow from pkg/json/json.go:125-158
func (m *Plugin) Extract(req sdk.ExtractRequest, evt sdk.EventReader) error {
    // Quick check for valid JSON
    if !(data[0] == '{' || data[0] == '[') {
        return fmt.Errorf("invalid json format")
    }

    // Parse only if not cached for this event
    if evt.EventNum() != m.jdataEvtnum {
        m.jdata, err = m.jparser.ParseBytes(data)
        m.jdataEvtnum = evt.EventNum()
    }
    // ... field extraction logic
}
```

**Source:** [`pkg/json/json.go:125-225`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json.go)

---

## Supported Fields

| Field | Type | Argument | Description |
|-------|------|----------|-------------|
| `json.value` | string | Key (Required) | Extract a value using JSON Pointer syntax (RFC 6901) |
| `json.obj` | string | None | The full JSON message as a pretty-printed text string |
| `json.rawtime` | string | None | The event timestamp, identical to `evt.rawtime` |
| `jevt.value` | string | Key (Required) | Alias for `json.value` (backwards compatibility) |
| `jevt.obj` | string | None | Alias for `json.obj` (backwards compatibility) |
| `jevt.rawtime` | string | None | Alias for `json.rawtime` (backwards compatibility) |

### Field IDs

| ID | Field |
|----|-------|
| 0 | `json.value` |
| 1 | `json.obj` |
| 2 | `json.rawtime` |
| 3 | `jevt.value` |
| 4 | `jevt.obj` |
| 5 | `jevt.rawtime` |

**Source:** [`pkg/json/json.go:88-123`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json.go), [`README.md`](../../../refs/falcosecurity/plugins/plugins/json/README.md)

---

## JSON Pointer Syntax

The `json.value` field uses [RFC 6901 JSON Pointer](https://datatracker.ietf.org/doc/html/rfc6901) syntax for path navigation.

### Syntax Rules

| Pattern | Description |
|---------|-------------|
| `/key` | Access object property named "key" |
| `/nested/path` | Navigate nested objects |
| `/array/0` | Access array element by index |
| `/~0` | Escaped `~` character |
| `/~1` | Escaped `/` character |

### Escape Sequences

The plugin implements proper JSON Pointer escaping:

```go
// From pkg/json/json.go:177-178
key = strings.Replace(key, "~1", "/", -1)  // ~1 -> /
key = strings.Replace(key, "~0", "~", -1)  // ~0 -> ~
```

### Examples

Given this JSON payload:
```json
{
  "user": {
    "name": "alice",
    "roles": ["admin", "user"]
  },
  "path/with/slashes": "value",
  "~tilde": "test"
}
```

| Pointer | Result |
|---------|--------|
| `/user/name` | `"alice"` |
| `/user/roles/0` | `"admin"` |
| `/path~1with~1slashes` | `"value"` |
| `/~0tilde` | `"test"` |
| (empty) | Full JSON object |

**Source:** [`pkg/json/json.go:163-183`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json.go), [`pkg/json/json_test.go:96-198`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json_test.go)

---

## Configuration

### Plugin Configuration Schema

```go
type PluginConfig struct {
    UseAsync bool `json:"useAsync" jsonschema:"...default=true"`
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `useAsync` | bool | `true` | Enable async extraction optimization |

The `useAsync` option controls whether the plugin uses asynchronous extraction, which can improve performance when multiple fields are extracted from the same event.

**Source:** [`pkg/json/config.go:20-27`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/config.go)

### Example falco.yaml Configuration

```yaml
plugins:
  - name: json
    library_path: libjson.so
    init_config: ""
    open_params: ""

# Optional: If not specified, the first entry in plugins is used
load_plugins: [json]
```

### Configuration with useAsync

```yaml
plugins:
  - name: json
    library_path: libjson.so
    init_config: '{"useAsync": true}'
```

**Source:** [`README.md`](../../../refs/falcosecurity/plugins/plugins/json/README.md)

---

## Event Flow

### Extraction Process

```
┌────────────────────┐
│  Event with JSON   │
│  payload arrives   │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│  Check first byte  │
│  ('{' or '[')      │
└─────────┬──────────┘
          │
    ┌─────┴─────┐
    │  Valid?   │
    └─────┬─────┘
          │
    Yes   │   No
    │     └──────▶ Return error
    ▼
┌────────────────────┐
│  Check event cache │
│  (jdataEvtnum)     │
└─────────┬──────────┘
          │
    ┌─────┴─────┐
    │  Cached?  │
    └─────┬─────┘
          │
    No    │   Yes
    │     └──────▶ Use cached jdata
    ▼
┌────────────────────┐
│  Parse with        │
│  fastjson.Parser   │
└─────────┬──────────┘
          │
          ▼
┌────────────────────┐
│  Process field     │
│  based on FieldID  │
└─────────┬──────────┘
          │
    ┌─────┴─────────────┬──────────────────┐
    │                   │                   │
    ▼                   ▼                   ▼
┌─────────┐      ┌───────────┐      ┌────────────┐
│ json.   │      │  json.obj │      │ json.      │
│ value   │      │           │      │ rawtime    │
└────┬────┘      └─────┬─────┘      └──────┬─────┘
     │                 │                    │
     ▼                 ▼                    ▼
┌─────────┐      ┌───────────┐      ┌────────────┐
│ Navigate│      │  Indent   │      │  Return    │
│ pointer │      │  & return │      │  timestamp │
│ path    │      │  full obj │      │            │
└─────────┘      └───────────┘      └────────────┘
```

**Source:** [`pkg/json/json.go:125-225`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json.go)

---

## Usage Examples

### Rule Using json.value

```yaml
- rule: Suspicious K8s API Call
  desc: Detect suspicious Kubernetes API calls
  condition: >
    ka.verb in (create, update, patch) and
    json.value[/objectRef/resource] = "secrets"
  output: >
    Suspicious K8s API call detected
    (user=%json.value[/user/username]%
     resource=%json.value[/objectRef/resource]%)
  priority: WARNING
  source: k8s_audit
```

### Using jevt.* Aliases (Backwards Compatibility)

```yaml
- rule: CloudTrail Event
  desc: Detect specific CloudTrail events
  condition: >
    jevt.value[/eventName] = "DeleteBucket"
  output: >
    S3 bucket deleted (bucket=%jevt.value[/requestParameters/bucketName]%)
  priority: CRITICAL
  source: aws_cloudtrail
```

### Extracting Nested Values

```yaml
# For JSON: {"metadata": {"labels": {"app": "nginx"}}}
condition: json.value[/metadata/labels/app] = "nginx"
```

### Extracting Array Elements

```yaml
# For JSON: {"items": [{"name": "first"}, {"name": "second"}]}
condition: json.value[/items/0/name] = "first"
```

---

## Integration with Source Plugins

The json plugin is designed to work with any source plugin that produces JSON-formatted event payloads.

### Common Combinations

| Source Plugin | Event Source | Typical Use Case |
|---------------|--------------|------------------|
| `k8saudit` | `k8s_audit` | Kubernetes audit log monitoring |
| `k8saudit-eks` | `k8s_audit` | AWS EKS audit logs |
| `k8saudit-gke` | `k8s_audit` | GCP GKE audit logs |
| `k8saudit-aks` | `k8s_audit` | Azure AKS audit logs |
| `cloudtrail` | `aws_cloudtrail` | AWS CloudTrail events |
| `okta` | `okta` | Okta security events |
| `github` | `github` | GitHub webhook events |
| `gcpaudit` | `gcp_auditlog` | GCP audit logs |

### Example Multi-Plugin Configuration

```yaml
plugins:
  - name: k8saudit
    library_path: libk8saudit.so
    init_config: ""
    open_params: "http://:9765/k8s-audit"
  - name: json
    library_path: libjson.so

load_plugins: [k8saudit, json]
```

**Source:** [`registry.yaml:103-122`](../../../refs/falcosecurity/plugins/registry.yaml)

---

## Sources

| Topic | Source File |
|-------|-------------|
| Plugin overview | [`README.md`](../../../refs/falcosecurity/plugins/plugins/json/README.md) |
| Main plugin implementation | [`pkg/json/json.go`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json.go) |
| Plugin configuration | [`pkg/json/config.go`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/config.go) |
| Plugin entry point | [`plugin/json.go`](../../../refs/falcosecurity/plugins/plugins/json/plugin/json.go) |
| Unit tests | [`pkg/json/json_test.go`](../../../refs/falcosecurity/plugins/plugins/json/pkg/json/json_test.go) |
| Build configuration | [`Makefile`](../../../refs/falcosecurity/plugins/plugins/json/Makefile) |
| Go module | [`go.mod`](../../../refs/falcosecurity/plugins/plugins/json/go.mod) |
| Changelog | [`CHANGELOG.md`](../../../refs/falcosecurity/plugins/plugins/json/CHANGELOG.md) |
| Plugin registry entry | [`registry.yaml`](../../../refs/falcosecurity/plugins/registry.yaml) |
