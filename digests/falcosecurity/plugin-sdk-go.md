# plugin-sdk-go Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/plugin-sdk-go/`](../../refs/falcosecurity/plugin-sdk-go/) | **Version:** v0.8.3

Go SDK for building [Falco plugins](https://falco.org/docs/plugins/). This SDK facilitates writing plugins that extend Falco's capabilities by providing new event sources or field extraction logic.

## Architecture Overview

The SDK is designed with **three layers of abstraction**:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Developer Layer                                 │
│  pkg/sdk/plugins/{source,extractor}                                     │
│  High-level constructs for building plugins in a Go-friendly way        │
├─────────────────────────────────────────────────────────────────────────┤
│                          Symbols Layer                                   │
│  pkg/sdk/symbols/{info,initialize,open,nextbatch,extract,fields,...}   │
│  Prebuilt C symbol implementations (CGO exports)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                          Core Layer                                      │
│  pkg/sdk                                                                 │
│  Basic interfaces, types, and definitions                               │
└─────────────────────────────────────────────────────────────────────────┘
```

## Plugin Capabilities

Falco plugins can have one or both of these capabilities:

| Capability | Description | Key Interface |
|------------|-------------|---------------|
| **Event Sourcing** | Generate events from external sources (cloud APIs, logs, etc.) | `source.Plugin` |
| **Field Extraction** | Extract typed fields from events for rule conditions | `extractor.Plugin` |

## Core Interfaces

### Plugin State and Lifecycle

```go
// PluginState represents the state returned by plugin_init()
type PluginState interface{}

// InstanceState represents the state of a plugin instance from plugin_open()
type InstanceState interface{}

// Destroyer is called in plugin_destroy() to release resources
type Destroyer interface {
    Destroy()
}

// Closer is called in plugin_close() to release instance resources
type Closer interface {
    Close()
}
```

### Plugin Information

```go
// plugins.Info contains general plugin information
type Info struct {
    ID                  uint32   // Unique plugin ID (for event sourcing)
    Name                string   // Plugin name (e.g., "cloudtrail")
    Description         string   // Human-readable description
    EventSource         string   // Event source name (for sourcing capability)
    Contact             string   // Author/maintainer contact
    Version             string   // Semantic version (e.g., "0.1.0")
    RequiredAPIVersion  string   // Minimum plugin API version
    ExtractEventSources []string // Event sources this plugin can extract from
}
```

### Event Handling

```go
// EventWriter - for creating events (event sourcing)
type EventWriter interface {
    Writer() io.Writer      // Get writer for event data
    SetTimestamp(uint64)    // Set event timestamp (nanoseconds)
}

// EventWriters - batch of events for plugin_next_batch()
type EventWriters interface {
    Get(eventIndex int) EventWriter
    Len() int
    ArrayPtr() unsafe.Pointer  // For passing to C framework
    Free()
}

// EventReader - for reading events (field extraction)
type EventReader interface {
    EventNum() uint64           // Event number assigned by framework
    Timestamp() uint64          // Event timestamp
    Reader() io.ReadSeeker      // Reader for event data
}
```

### Field Extraction

```go
// FieldEntry describes an extractable field
type FieldEntry struct {
    Name       string        `json:"name"`       // e.g., "ct.user"
    Type       string        `json:"type"`       // uint64, string, bool, etc.
    IsList     bool          `json:"isList"`     // Field returns list of values
    Arg        FieldEntryArg `json:"arg"`        // Argument requirements
    Display    string        `json:"display"`    // Human-readable display name
    Desc       string        `json:"desc"`       // Description
    Properties []string      `json:"properties"` // Optional properties
}

// ExtractRequest wraps a field extraction request
type ExtractRequest interface {
    FieldID() uint64        // Field index in Fields() list
    FieldType() uint32      // Field type constant
    Field() string          // Field name
    ArgKey() string         // String argument (if isKey)
    ArgIndex() uint64       // Index argument (if isIndex)
    ArgPresent() bool       // Whether argument is present
    IsList() bool           // Extracting list values
    SetValue(v interface{}) // Set extracted value
}

// Extractor implements field extraction
type Extractor interface {
    Extract(req ExtractRequest, evt EventReader) error
}
```

### Field Types

```go
const (
    FieldTypeUint64  uint32 = 8   // 64-bit unsigned integer
    FieldTypeCharBuf uint32 = 9   // Null-terminated string
    FieldTypeRelTime uint32 = 20  // Relative time (nanoseconds)
    FieldTypeAbsTime uint32 = 21  // Absolute time (nanoseconds since epoch)
    FieldTypeBool    uint32 = 25  // Boolean (4 bytes)
    FieldTypeIPAddr  uint32 = 40  // IPv4 or IPv6 address
    FieldTypeIPNet   uint32 = 41  // IPv4 or IPv6 network
)
```

## Building Plugins

### Event Source Plugin

```go
package main

import (
    "github.com/falcosecurity/plugin-sdk-go/pkg/sdk"
    "github.com/falcosecurity/plugin-sdk-go/pkg/sdk/plugins"
    "github.com/falcosecurity/plugin-sdk-go/pkg/sdk/plugins/source"
)

type MyPlugin struct {
    plugins.BasePlugin  // Provides boilerplate implementation
}

func init() {
    plugins.SetFactory(func() plugins.Plugin {
        p := &MyPlugin{}
        source.Register(p)  // Enable event sourcing capability
        return p
    })
}

func (m *MyPlugin) Info() *plugins.Info {
    return &plugins.Info{
        ID:          999,           // Unique ID (register with falcosecurity/plugins)
        Name:        "my-plugin",
        Description: "My custom event source",
        Version:     "0.1.0",
        EventSource: "my-source",   // Events tagged with this source name
    }
}

func (m *MyPlugin) Init(config string) error {
    // Parse config, initialize resources
    return nil
}

func (m *MyPlugin) Open(params string) (source.Instance, error) {
    // Create event source instance
    return source.NewPullInstance(func(ctx context.Context, evt sdk.EventWriter) error {
        // Write event data
        evt.Writer().Write([]byte("event data"))
        evt.SetTimestamp(uint64(time.Now().UnixNano()))
        return nil
    })
}

func main() {} // Required but empty
```

### Field Extractor Plugin

```go
type MyExtractor struct {
    plugins.BasePlugin
}

func init() {
    plugins.SetFactory(func() plugins.Plugin {
        p := &MyExtractor{}
        extractor.Register(p)  // Enable extraction capability
        return p
    })
}

func (m *MyExtractor) Info() *plugins.Info {
    return &plugins.Info{
        ID:                  999,
        Name:                "my-extractor",
        ExtractEventSources: []string{"syscall", "my-source"},  // Sources to extract from
    }
}

func (m *MyExtractor) Fields() []sdk.FieldEntry {
    return []sdk.FieldEntry{
        {Type: "uint64", Name: "my.field", Desc: "A numeric field"},
        {Type: "string", Name: "my.name", Desc: "A string field"},
    }
}

func (m *MyExtractor) Extract(req sdk.ExtractRequest, evt sdk.EventReader) error {
    switch req.FieldID() {
    case 0:  // my.field
        req.SetValue(uint64(42))
    case 1:  // my.name
        req.SetValue("hello")
    }
    return nil
}
```

### Combined Source + Extractor

```go
func init() {
    plugins.SetFactory(func() plugins.Plugin {
        p := &MyFullPlugin{}
        source.Register(p)     // Enable sourcing
        extractor.Register(p)  // Enable extraction
        return p
    })
}
```

## Event Production Models

### Pull Model (Synchronous)

```go
// Plugin pulls events synchronously
func (m *MyPlugin) Open(params string) (source.Instance, error) {
    return source.NewPullInstance(
        func(ctx context.Context, evt sdk.EventWriter) error {
            // Called repeatedly to get next event
            data := fetchNextEvent()
            evt.Writer().Write(data)
            return nil  // or sdk.ErrEOF when done
        },
        source.WithInstanceTimeout(30*time.Millisecond),
        source.WithInstanceBatchSize(128),
        source.WithInstanceEventSize(256*1024),
    )
}
```

### Push Model (Asynchronous)

```go
// Plugin receives events through a channel
func (m *MyPlugin) Open(params string) (source.Instance, error) {
    evtC := make(chan source.PushEvent)

    go func() {
        for data := range externalSource {
            evtC <- source.PushEvent{
                Data:      data,
                Timestamp: time.Now(),
            }
        }
        close(evtC)  // Signals EOF
    }()

    return source.NewPushInstance(evtC)
}
```

### Custom Instance

```go
type MyInstance struct {
    source.BaseInstance
    counter uint64
}

func (m *MyPlugin) Open(params string) (source.Instance, error) {
    batch, _ := sdk.NewEventWriters(10, 64)
    inst := &MyInstance{counter: 0}
    inst.SetEvents(batch)
    return inst, nil
}

func (m *MyInstance) NextBatch(pState sdk.PluginState, evts sdk.EventWriters) (int, error) {
    n := 0
    for n < evts.Len() {
        m.counter++
        evts.Get(n).Writer().Write(encodeCounter(m.counter))
        evts.Get(n).SetTimestamp(uint64(time.Now().UnixNano()))
        n++
    }
    return n, nil
}
```

## Symbols Package (CGO Bridge)

The `pkg/sdk/symbols/` package provides prebuilt C symbol implementations:

| Subpackage | Exported C Symbols |
|------------|-------------------|
| `info` | `plugin_get_id`, `plugin_get_name`, `plugin_get_description`, `plugin_get_contact`, `plugin_get_version`, `plugin_get_required_api_version`, `plugin_get_event_source`, `plugin_get_extract_event_sources` |
| `initialize` | `plugin_init`, `plugin_destroy` |
| `open` | `plugin_open`, `plugin_close` |
| `nextbatch` | `plugin_next_batch` |
| `extract` | `plugin_extract_fields` |
| `fields` | `plugin_get_fields` |
| `lasterr` | `plugin_get_last_error` |
| `evtstr` | `plugin_event_to_string` |
| `progress` | `plugin_get_progress` |
| `initschema` | `plugin_get_init_schema` |
| `listopen` | `plugin_list_open_params` |

Importing a subpackage automatically exports its symbols. The high-level `plugins/source` and `plugins/extractor` packages import the required symbols automatically.

## Async Extraction Optimization

For high-throughput scenarios, the SDK provides an async extraction optimization that uses worker goroutines with shared spinlocks to reduce C->Go call overhead:

```go
// Enable async extraction (default: enabled)
extract.SetAsync(true)

// Automatically managed by extractor.Register()
// - StartAsync() called after plugin_init
// - StopAsync() called before plugin_destroy
```

**Design:**
- N concurrent C consumers, N shared locks, M Go workers
- Workers busy-wait with spinlocks for minimal latency
- Sleep after 1ms of idle to reduce CPU usage
- Requires multi-core (GOMAXPROCS > 1)

## Config Schema Validation

Plugins can define a JSON Schema for configuration validation:

```go
func (m *MyPlugin) InitSchema() *sdk.SchemaInfo {
    return &sdk.SchemaInfo{
        Schema: `{
            "type": "object",
            "properties": {
                "endpoint": {"type": "string"},
                "timeout": {"type": "integer", "minimum": 0}
            },
            "required": ["endpoint"]
        }`,
    }
}
```

The framework validates config before calling `Init()`, ensuring well-formed input.

## Plugin Loader (pkg/loader)

The loader package allows loading compiled plugins from shared libraries:

```go
import "github.com/falcosecurity/plugin-sdk-go/pkg/loader"

// Load and validate plugin
plugin, err := loader.NewValidPlugin("/path/to/plugin.so")

// Get plugin info
info := plugin.Info()

// Check capabilities
if plugin.HasCapSourcing() { /* ... */ }
if plugin.HasCapExtraction() { /* ... */ }

// Initialize
err = plugin.Init(`{"key": "value"}`)

// Get fields (if extraction capable)
fields := plugin.Fields()

// Cleanup
plugin.Unload()
```

## CGO Handle Management

The SDK uses a custom `cgo.Handle` implementation optimized for plugin use cases:

- Maximum 256 concurrent handles (sufficient for plugin states)
- Lock-free design for performance
- Used to pass Go pointers through C safely

```go
// Internal usage - developers don't interact directly
handle := cgo.NewHandle(pluginState)  // Create handle
value := handle.Value()                // Retrieve value
handle.Delete()                        // Release handle
```

## Return Codes

```go
const (
    SSPluginSuccess      int32 = 0   // Operation succeeded
    SSPluginFailure      int32 = 1   // Operation failed
    SSPluginTimeout      int32 = -1  // Timeout (retry later)
    SSPluginEOF          int32 = 2   // End of event stream
    SSPluginNotSupported int32 = 3   // Operation not supported
)

// Standard errors for NextBatch
var ErrEOF = errors.New("eof")       // No more events
var ErrTimeout = errors.New("timeout") // No events now, try again
```

## Event Structure

Plugin events use the `ss_plugin_event` C structure:

```
┌─────────────────────────────────────────────────────────────────┐
│ Event Header (26 bytes)                                         │
│ - type (2 bytes): PPME_PLUGINEVENT_E = 322                     │
│ - len (4 bytes): Total event length                            │
│ - ts (8 bytes): Timestamp (nanoseconds)                        │
│ - tid (8 bytes): Thread ID (UINT64_MAX for plugins)            │
│ - nparams (4 bytes): Always 2 for plugin events                │
├─────────────────────────────────────────────────────────────────┤
│ Param lengths (8 bytes)                                         │
│ - Plugin ID size (4 bytes): Always 4                           │
│ - Data payload size (4 bytes): Variable                        │
├─────────────────────────────────────────────────────────────────┤
│ Plugin ID (4 bytes)                                             │
├─────────────────────────────────────────────────────────────────┤
│ Data Payload (variable)                                         │
│ - Plugin-defined event data                                     │
└─────────────────────────────────────────────────────────────────┘

PluginEventPayloadOffset = 26 + 4 + 4 + 4 = 38 bytes
```

## Best Practices

1. **Compose with Base Types**: Use `plugins.BasePlugin`, `source.BaseInstance` for boilerplate
2. **Unique Plugin IDs**: Register your plugin ID at [falcosecurity/plugins](https://github.com/falcosecurity/plugins)
3. **Semantic Versioning**: Follow semver for plugin versions
4. **Config Schemas**: Define `InitSchema()` for automatic validation
5. **Resource Cleanup**: Implement `Destroy()` and `Close()` to release resources
6. **Error Handling**: Use `SetLastError()` for detailed error messages
7. **Batch Events**: Fill entire batches when possible for better throughput
8. **Build Command**: `go build -buildmode=c-shared -o plugin.so`

## Sources

| Topic | Source File |
|-------|-------------|
| SDK core interfaces | [`pkg/sdk/sdk.go`](../../refs/falcosecurity/plugin-sdk-go/pkg/sdk/sdk.go) |
| Plugin info types | [`pkg/sdk/plugins/plugins.go`](../../refs/falcosecurity/plugin-sdk-go/pkg/sdk/plugins/plugins.go) |
| Source plugin interface | [`pkg/sdk/plugins/source/`](../../refs/falcosecurity/plugin-sdk-go/pkg/sdk/plugins/source/) |
| Extractor plugin interface | [`pkg/sdk/plugins/extractor/`](../../refs/falcosecurity/plugin-sdk-go/pkg/sdk/plugins/extractor/) |
| Field entry definitions | [`pkg/sdk/extract.go`](../../refs/falcosecurity/plugin-sdk-go/pkg/sdk/extract.go) |
| Event writers | [`pkg/sdk/event.go`](../../refs/falcosecurity/plugin-sdk-go/pkg/sdk/event.go) |
| Symbols package (CGO) | [`pkg/sdk/symbols/`](../../refs/falcosecurity/plugin-sdk-go/pkg/sdk/symbols/) |
| Plugin loader | [`pkg/loader/`](../../refs/falcosecurity/plugin-sdk-go/pkg/loader/) |
| Async extraction | [`pkg/sdk/symbols/extract/async.go`](../../refs/falcosecurity/plugin-sdk-go/pkg/sdk/symbols/extract/async.go) |
| CGO handle management | [`pkg/cgo/handle.go`](../../refs/falcosecurity/plugin-sdk-go/pkg/cgo/handle.go) |

## Related Documentation

- [Plugin Developer's Guide](https://falco.org/docs/plugins/developers_guide/)
- [Plugin API Reference](https://falco.org/docs/plugins/plugin-api-reference/)
- [falcosecurity/plugins Registry](https://github.com/falcosecurity/plugins)
- [`charts.md`](charts.md) - Helm chart integration with plugins
- [`falcoctl.md`](falcoctl.md) - Plugin distribution via OCI artifacts
