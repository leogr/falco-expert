# plugin-sdk-rs Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/plugin-sdk-rs/`](../../refs/falcosecurity/plugin-sdk-rs/) | **Commit:** `f872262` (January 7, 2026)

**Repository:** [falcosecurity/plugin-sdk-rs](https://github.com/falcosecurity/plugin-sdk-rs)
**Scope:** Ecosystem
**Status:** Incubating
**Documentation:** [falcosecurity.github.io/plugin-sdk-rs](https://falcosecurity.github.io/plugin-sdk-rs/)

Rust SDK for building [Falco plugins](https://falco.org/docs/plugins/). The SDK provides high-level, type-safe Rust bindings for the plugin API with strong compile-time guarantees and idiomatic Rust patterns.

## Key Characteristics

- **Type-safe**: Compile-time checks for trait implementations and capability exports
- **Idiomatic Rust**: Uses traits, Result types, and pattern matching
- **Strongly-typed events**: Integrates with `falco_event_schema` for typed event handling
- **Static and dynamic linking**: Supports both `cdylib` and `staticlib` builds
- **Macro-based registration**: Simple macros to export C symbols and validate capabilities
- **Integrated logging**: Uses the `log` crate, redirected to Falco's logger

**Source:** [`falco_plugin/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/README.md)

## Workspace Structure

The SDK is organized as a Rust workspace with multiple crates:

| Crate | Purpose |
|-------|---------|
| `falco_plugin` | Main SDK crate with high-level plugin traits and macros |
| `falco_plugin_api` | Low-level C API bindings (`ss_plugin_*` types) |
| `falco_plugin_derive` | Procedural macros for plugin code generation |
| `falco_event` | Event handling (raw events, serialization/deserialization) |
| `falco_event_schema` | Strongly-typed event definitions from Falco libs |
| `falco_event_derive` | Derive macros for custom event types |
| `falco_event_serde` | Serde integration for events |
| `falco_schema_derive` | Schema generation macros |
| `falco_plugin_runner` | Test harness for running plugins |
| `falco_plugin_tests` | SDK test suite |

**Source:** [`Cargo.toml`](../../refs/falcosecurity/plugin-sdk-rs/Cargo.toml)

## Plugin Capabilities

| Capability | Trait | Export Macro | Description |
|------------|-------|--------------|-------------|
| **Base** | `Plugin` | `plugin!` | Required for all plugins - info, init, config |
| **Event Sourcing** | `SourcePlugin` + `SourcePluginInstance` | `source_plugin!` | Generate events from external sources |
| **Field Extraction** | `ExtractPlugin` | `extract_plugin!` | Extract typed fields from events |
| **Event Parsing** | `ParsePlugin` | `parse_plugin!` | Parse events and update state tables |
| **Async Events** | `AsyncEventPlugin` | `async_event_plugin!` | Inject events asynchronously |
| **Capture Listening** | `CaptureListenPlugin` | `capture_listen_plugin!` | React to capture open/close |

**Source:** [`falco_plugin/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/README.md), [`falco_plugin/src/lib.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/lib.rs)

## Building Plugins

### Cargo.toml Configuration

```toml
[package]
name = "my-plugin"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]  # For dynamic linking

[dependencies]
falco_plugin = "0.5.0"
```

**Source:** [`falco_plugin/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/README.md)

### Basic Plugin Structure

```rust
use std::ffi::CStr;
use falco_plugin::base::Plugin;
use falco_plugin::tables::TablesInput;
use falco_plugin::plugin;

struct MyPlugin;

impl Plugin for MyPlugin {
    const NAME: &'static CStr = c"my-plugin";
    const PLUGIN_VERSION: &'static CStr = c"0.1.0";
    const DESCRIPTION: &'static CStr = c"My plugin description";
    const CONTACT: &'static CStr = c"author@example.com";
    type ConfigType = ();  // or String, or Json<T>

    fn new(input: Option<&TablesInput>, config: Self::ConfigType)
        -> Result<Self, anyhow::Error> {
        Ok(MyPlugin)
    }
}

// Register the plugin
plugin!(MyPlugin);
```

**Source:** [`falco_plugin/src/base/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/base/mod.rs)

## Base Plugin Trait

### Required Constants

```rust
const NAME: &'static CStr;           // Must match Falco config
const PLUGIN_VERSION: &'static CStr; // Semantic version
const DESCRIPTION: &'static CStr;    // Human-readable description
const CONTACT: &'static CStr;        // Author/maintainer contact
const SCHEMA_VERSION: &'static CStr; // Optional, defaults to current
```

### Configuration Types

```rust
// No configuration
type ConfigType = ();

// String configuration
type ConfigType = String;

// JSON configuration (requires serde + schemars)
use falco_plugin::base::Json;
use falco_plugin::schemars::JsonSchema;
use falco_plugin::serde::Deserialize;

#[derive(JsonSchema, Deserialize)]
#[schemars(crate = "falco_plugin::schemars")]
#[serde(crate = "falco_plugin::serde")]
struct MyConfig {
    debug: bool,
    endpoint: String,
}

type ConfigType = Json<MyConfig>;
```

### Metrics

```rust
use falco_plugin::base::{Metric, MetricLabel, MetricType, MetricValue};

impl Plugin for MyPlugin {
    fn get_metrics(&mut self) -> impl IntoIterator<Item = Metric> {
        [
            Metric::new(
                MetricLabel::new(c"events_processed", MetricType::Monotonic),
                MetricValue::U64(self.event_count),
            )
        ]
    }
}
```

**Source:** [`falco_plugin/src/base/mod.rs:19-288`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/base/mod.rs)

## Event Sourcing Plugin

```rust
use std::ffi::{CStr, CString};
use falco_event::events::RawEvent;
use falco_plugin::source::{
    EventBatch, EventInput, PluginEvent, SourcePlugin, SourcePluginInstance
};
use falco_plugin::{plugin, source_plugin, FailureReason};

struct MyPlugin;

impl SourcePlugin for MyPlugin {
    type Instance = MyInstance;
    const EVENT_SOURCE: &'static CStr = c"my-source";
    const PLUGIN_ID: u32 = 999;  // Must be registered with falcosecurity
    type Event<'a> = falco_event::events::Event<PluginEvent<&'a [u8]>>;

    fn open(&mut self, params: Option<&str>) -> Result<Self::Instance, anyhow::Error> {
        Ok(MyInstance::new())
    }

    fn event_to_string(&mut self, event: &EventInput<Self::Event<'_>>)
        -> Result<CString, anyhow::Error> {
        let plugin_event = event.event()?;
        Ok(CString::new(plugin_event.params.event_data)?)
    }
}

struct MyInstance { count: u64 }

impl SourcePluginInstance for MyInstance {
    type Plugin = MyPlugin;

    fn next_batch(&mut self, _plugin: &mut Self::Plugin, batch: &mut EventBatch)
        -> Result<(), anyhow::Error> {
        // Return events
        let event = Self::plugin_event(b"hello, world");
        batch.add(event)?;
        Ok(())

        // Or timeout (no events now, retry later)
        // Err(anyhow::anyhow!("no events").context(FailureReason::Timeout))

        // Or EOF (no more events)
        // Err(anyhow::anyhow!("done").context(FailureReason::Eof))
    }
}

plugin!(MyPlugin);
source_plugin!(MyPlugin);
```

**Source:** [`falco_plugin/src/source/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/source/mod.rs)

## Field Extraction Plugin

```rust
use std::ffi::CString;
use falco_event::events::RawEvent;
use falco_plugin::extract::{field, ExtractFieldInfo, ExtractPlugin, ExtractRequest};
use falco_plugin::{plugin, extract_plugin};

struct MyExtractor;

impl ExtractPlugin for MyExtractor {
    type Event<'a> = RawEvent<'a>;
    type ExtractContext = ();  // Shared context between extractions

    const EXTRACT_FIELDS: &'static [ExtractFieldInfo<Self>] = &[
        field("my.string_field", &Self::extract_string),
        field("my.numeric_field", &Self::extract_number),
        field("my.indexed_field", &Self::extract_with_index),
        field("my.keyed_field", &Self::extract_with_key),
    ];
}

impl MyExtractor {
    fn extract_string(&mut self, req: ExtractRequest<Self>)
        -> Result<CString, anyhow::Error> {
        Ok(c"value".to_owned())
    }

    fn extract_number(&mut self, req: ExtractRequest<Self>)
        -> Result<u64, anyhow::Error> {
        Ok(42)
    }

    // With numeric index: field[5]
    fn extract_with_index(&mut self, req: ExtractRequest<Self>, arg: u64)
        -> Result<CString, anyhow::Error> {
        Ok(CString::new(format!("item_{}", arg))?)
    }

    // With string key: field[key]
    fn extract_with_key(&mut self, req: ExtractRequest<Self>, arg: &CStr)
        -> Result<CString, anyhow::Error> {
        Ok(CString::new(format!("value_for_{}", arg.to_str()?))?)
    }
}

plugin!(MyExtractor);
extract_plugin!(MyExtractor);
```

### Supported Return Types

- `u64`, `bool`, `CString`
- `std::time::SystemTime`, `std::time::Duration`
- `std::net::IpAddr`, `falco_event::types::IpNet`
- `Vec<T>` of any above type (for list fields)

**Source:** [`falco_plugin/src/extract/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/extract/mod.rs)

## Event Parsing Plugin

```rust
use falco_event::events::RawEvent;
use falco_plugin::parse::{EventInput, ParseInput, ParsePlugin};
use falco_plugin::{plugin, parse_plugin};

struct MyParser;

impl ParsePlugin for MyParser {
    type Event<'a> = RawEvent<'a>;

    fn parse_event(&mut self, event: &EventInput<RawEvent>, parse_input: &ParseInput)
        -> Result<(), anyhow::Error> {
        let raw_event = event.event()?;

        // Access tables for reading/writing
        // parse_input.reader - for reading table entries
        // parse_input.writer - for writing table entries

        Ok(())
    }
}

plugin!(MyParser);
parse_plugin!(MyParser);
```

**Source:** [`falco_plugin/src/parse/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/parse/mod.rs)

## Async Events Plugin

```rust
use std::sync::Arc;
use std::thread::JoinHandle;
use falco_plugin::async_event::{AsyncEventPlugin, AsyncHandler, BackgroundTask};
use falco_plugin::{plugin, async_event_plugin};

struct MyAsyncPlugin {
    task: Arc<BackgroundTask>,
    thread: Option<JoinHandle<Result<(), anyhow::Error>>>,
}

impl AsyncEventPlugin for MyAsyncPlugin {
    const ASYNC_EVENTS: &'static [&'static str] = &["my_notification"];
    const EVENT_SOURCES: &'static [&'static str] = &["syscall"];

    fn start_async(&mut self, handler: AsyncHandler) -> Result<(), anyhow::Error> {
        self.thread = Some(self.task.spawn(
            std::time::Duration::from_millis(100),
            move || {
                handler.emit(Self::async_event(c"my_notification", b"data"))?;
                Ok(())
            }
        )?);
        Ok(())
    }

    fn stop_async(&mut self) -> Result<(), anyhow::Error> {
        self.task.request_stop_and_notify()?;
        if let Some(handle) = self.thread.take() {
            handle.join().map_err(|e| std::panic::resume_unwind(e))?
        }
        Ok(())
    }
}

plugin!(MyAsyncPlugin);
async_event_plugin!(MyAsyncPlugin);
```

**Source:** [`falco_plugin/src/async_event/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/async_event/mod.rs)

## Capture Listening Plugin

```rust
use std::ops::ControlFlow;
use falco_plugin::listen::{CaptureListenInput, CaptureListenPlugin, Routine};
use falco_plugin::{plugin, capture_listen_plugin};

struct MyListener {
    routines: Vec<Routine>,
}

impl CaptureListenPlugin for MyListener {
    fn capture_open(&mut self, input: &CaptureListenInput) -> Result<(), anyhow::Error> {
        // Start background tasks
        self.routines.push(input.thread_pool.subscribe(|| {
            // Do work in background
            std::thread::sleep(std::time::Duration::from_millis(500));
            ControlFlow::Continue(())  // Reschedule
            // or ControlFlow::Break(()) to stop
        })?);
        Ok(())
    }

    fn capture_close(&mut self, input: &CaptureListenInput) -> Result<(), anyhow::Error> {
        // Stop background tasks
        for routine in self.routines.drain(..) {
            input.thread_pool.unsubscribe(&routine)?;
        }
        Ok(())
    }
}

plugin!(MyListener);
capture_listen_plugin!(MyListener);
```

**Source:** [`falco_plugin/src/listen/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/listen/mod.rs)

## Event Types

### Working with Events

```rust
use falco_event::events::{Event, RawEvent};
use falco_plugin::event::PluginEvent;

// Raw event (no parsing)
type Event<'a> = RawEvent<'a>;

// Plugin events (source plugins)
type Event<'a> = Event<PluginEvent<&'a [u8]>>;

// Specific syscall event type
use falco_event_schema::events::PPME_SYSCALL_OPENAT2_X;
type Event<'a> = Event<PPME_SYSCALL_OPENAT2_X<'a>>;

// Any event (large enum of all types)
use falco_event_schema::events::AnyEvent;
type Event<'a> = Event<AnyEvent<'a>>;
```

**Source:** [`falco_plugin/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/README.md), [`falco_event/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_event/README.md)

## Static Linking

For embedding plugins in custom applications using libsinsp:

```rust
// In Cargo.toml: crate-type = ["staticlib"]

use falco_plugin::static_plugin;

static_plugin!(MY_PLUGIN_API = MyPlugin);

// On C++ side: sinsp::register_plugin(&MY_PLUGIN_API)
```

### Building Both Variants

```rust
#[cfg(linkage = "static")]
static_plugin!(MY_PLUGIN = MyPlugin);

#[cfg(not(linkage = "static"))]
plugin!(MyPlugin);
#[cfg(not(linkage = "static"))]
source_plugin!(MyPlugin);
```

```bash
# Dynamic library (default)
cargo build --release

# Static library
RUSTFLAGS='--cfg linkage="static"' cargo rustc --crate-type=staticlib --release
```

**Source:** [`falco_plugin/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/README.md)

## Error Handling

### FailureReason

```rust
use falco_plugin::FailureReason;

// Timeout - no events now, but may have later
Err(anyhow::anyhow!("no events").context(FailureReason::Timeout))

// EOF - no more events, end capture
Err(anyhow::anyhow!("done").context(FailureReason::Eof))

// Other failures - logged as errors
Err(anyhow::anyhow!("something went wrong"))
```

**Source:** [`falco_plugin/src/error/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/error/mod.rs)

## Logging

```rust
// Uses the `log` crate, redirected to Falco's logger
log::info!("Plugin initialized");
log::error!("Something went wrong: {}", error);

// Set log level in init
fn new(input: Option<&TablesInput>, config: Self::ConfigType)
    -> Result<Self, anyhow::Error> {
    log::set_max_level(log::LevelFilter::Debug);
    Ok(Self)
}
```

**Source:** [`falco_plugin/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/README.md)

## Features

| Feature | Description |
|---------|-------------|
| `thread-safe-tables` | Use `parking_lot` for thread-safe table access |

**Source:** [`falco_plugin/Cargo.toml`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/Cargo.toml)

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| `anyhow` | 1.0.81 | Error handling |
| `thiserror` | 2.0.12 | Error type derivation |
| `serde` | 1.0.197 | JSON configuration |
| `schemars` | 1.0.1 | JSON schema generation |
| `log` | 0.4.21 | Logging |
| `bumpalo` | 3.16.0 | Bump allocator for events |

**Source:** [`falco_plugin/Cargo.toml`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/Cargo.toml)

## Version Compatibility

The SDK version is `0.5.0`. While in the 0.x version range, the Minimum Supported Rust Version (MSRV) is defined as "latest stable".

**Source:** [`falco_plugin/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/README.md), [`falco_plugin/Cargo.toml`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/Cargo.toml)

## Examples

| Example | Description |
|---------|-------------|
| [`dummy_source`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/examples/dummy_source.rs) | Basic source plugin with static/dynamic linking support |

**Source:** [`falco_plugin/examples/`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/examples/)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, building plugins | [`falco_plugin/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/README.md) |
| Main SDK exports | [`falco_plugin/src/lib.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/lib.rs) |
| Base plugin trait | [`falco_plugin/src/base/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/base/mod.rs) |
| Source plugin trait | [`falco_plugin/src/source/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/source/mod.rs) |
| Extract plugin trait | [`falco_plugin/src/extract/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/extract/mod.rs) |
| Parse plugin trait | [`falco_plugin/src/parse/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/parse/mod.rs) |
| Async event plugin trait | [`falco_plugin/src/async_event/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/async_event/mod.rs) |
| Capture listening trait | [`falco_plugin/src/listen/mod.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/src/listen/mod.rs) |
| Event handling | [`falco_event/README.md`](../../refs/falcosecurity/plugin-sdk-rs/falco_event/README.md) |
| Workspace config | [`Cargo.toml`](../../refs/falcosecurity/plugin-sdk-rs/Cargo.toml) |
| Dummy source example | [`falco_plugin/examples/dummy_source.rs`](../../refs/falcosecurity/plugin-sdk-rs/falco_plugin/examples/dummy_source.rs) |

## Related Documentation

- [Plugin Developer's Guide](https://falco.org/docs/plugins/developers_guide/)
- [Plugin API Reference](https://falco.org/docs/plugins/plugin-api-reference/)
- [falcosecurity/plugins Registry](https://github.com/falcosecurity/plugins)
- [Rust SDK Documentation](https://falcosecurity.github.io/plugin-sdk-rs/)
- [`plugin-sdk-cpp.md`](plugin-sdk-cpp.md) - C++ SDK for plugins
- [`plugin-sdk-go.md`](plugin-sdk-go.md) - Go SDK for plugins
- [`libs/plugin-framework.md`](libs/plugin-framework.md) - Plugin API in libs
