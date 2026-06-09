# falco-rustlings Digest

> **Era Relevance:** 0.44 (Compatible) | **Source:** [`refs/falcosecurity/falco-rustlings/`](../../refs/falcosecurity/falco-rustlings/) | **Commit:** `10adcbd` (January 16, 2025)

**Repository:** [falcosecurity/falco-rustlings](https://github.com/falcosecurity/falco-rustlings)
**Scope:** Ecosystem
**Status:** Sandbox

Interactive Rustlings exercises for learning Falco plugin development with the Rust SDK. Uses the [rustlings](https://github.com/rust-lang/rustlings) framework for hands-on, self-paced learning.

## Era Relevance Notes

**Last Updated:** January 16, 2025 (approximately 1 year before era 0.43)

**Compatibility:** The exercises are compatible with the current plugin-sdk-rs (v0.5.0) because:
- Core SDK API patterns (`Plugin`, `SourcePlugin`, `ExtractPlugin`, `ParsePlugin`, `AsyncEventPlugin` traits) remain unchanged
- Uses git dependencies without version pinning, pulling the latest SDK
- The fundamental learning patterns taught remain valid

**Potential Differences:**
- May not cover newest SDK features or helper utilities added after January 2025
- Some ergonomic improvements in the SDK may offer simpler patterns than shown in exercises
- Repository is in Sandbox status (experimental)

**Source:** [`Cargo.toml`](../../refs/falcosecurity/falco-rustlings/Cargo.toml), [`info.toml`](../../refs/falcosecurity/falco-rustlings/info.toml)

## Learning Approach

1. Search for `TODO` and `todo!()` in exercise code
2. Fill in missing implementations
3. Press `h` for hints when stuck
4. Solutions are available in `solutions/` directory
5. Look for `DOCS` pointers to SDK documentation

**Source:** [`README.md`](../../refs/falcosecurity/falco-rustlings/README.md)

## Exercises

| # | Exercise | Capability | Focus |
|---|----------|------------|-------|
| 0 | `building_the_sdk_just_a_moment_please` | Setup | SDK compilation verification |
| 1 | `your_first_plugin` | Base | `Plugin` trait, constants, constructor |
| 2 | `source_plugin` | Event Sourcing | `SourcePlugin`, `SourcePluginInstance` types |
| 3 | `source_plugin_with_events` | Event Sourcing | Emitting events via `next_batch()` |
| 4 | `async_events_plugin` | Async Events | `AsyncEventPlugin`, `AsyncHandler` |
| 5 | `field_extraction` | Field Extraction | `ExtractPlugin`, `field()` macro |
| 6 | `plugin_configuration` | Base | JSON configuration with `Json<T>` |
| 7 | `event_parsing` | Event Parsing | `ParsePlugin`, maintaining state |
| 8 | `event_parsing_using_tables` | Event Parsing + Tables | Exposing state as tables, cross-plugin data |
| 9 | `extract_fields_syscall_events` | Field Extraction | Handling syscall events |

**Source:** [`info.toml`](../../refs/falcosecurity/falco-rustlings/info.toml)

## Key Concepts Taught

### Exercise 1: Base Plugin (`your_first_plugin`)

```rust
impl Plugin for NoOpPlugin {
    const NAME: &'static CStr = c"noop-plugin";
    const PLUGIN_VERSION: &'static CStr = c"0.0.1";
    const DESCRIPTION: &'static CStr = c"The simplest possible plugin";
    const CONTACT: &'static CStr = c"https://github.com/falcosecurity/plugin-sdk-rs";
    type ConfigType = ();

    fn new(_input: Option<&TablesInput>, _config: Self::ConfigType) -> Result<Self, Error> {
        Ok(Self)
    }
}

// #[no_capabilities] for plugins without any capability (won't load in Falco)
static_plugin!(#[no_capabilities] NO_OP_PLUGIN = NoOpPlugin);
```

**Source:** [`exercises/your_first_plugin.rs`](../../refs/falcosecurity/falco-rustlings/exercises/your_first_plugin.rs)

### Exercise 2-3: Source Plugin

```rust
impl SourcePlugin for MySourcePlugin {
    type Instance = MySourceInstance;  // Instance type for event generation
    const EVENT_SOURCE: &'static CStr = c"rustlings";
    const PLUGIN_ID: u32 = 999;  // Must be registered for production plugins

    fn open(&mut self, _params: Option<&str>) -> Result<Self::Instance, Error> { ... }
    fn event_to_string(&mut self, event: &EventInput) -> Result<CString, Error> { ... }
}

impl SourcePluginInstance for MySourceInstance {
    type Plugin = MySourcePlugin;

    fn next_batch(&mut self, _plugin: &mut Self::Plugin, batch: &mut EventBatch)
        -> Result<(), Error> {
        // Return Err with FailureReason::Eof when done
        // Return Err with FailureReason::Timeout when no events yet
        // Add events with batch.add(Self::plugin_event(&data))
    }
}
```

**Source:** [`exercises/source_plugin.rs`](../../refs/falcosecurity/falco-rustlings/exercises/source_plugin.rs)

### Exercise 5: Field Extraction

```rust
impl ExtractPlugin for RandomGenPlugin {
    const EVENT_TYPES: &'static [EventType] = &[];  // All types
    const EVENT_SOURCES: &'static [&'static str] = &["random_generator"];
    type ExtractContext = ();
    const EXTRACT_FIELDS: &'static [ExtractFieldInfo<Self>] =
        &[field("gen.num", &Self::extract_number)];
}

impl RandomGenPlugin {
    fn extract_number(&mut self, req: ExtractRequest<Self>) -> Result<u64, Error> {
        let event = req.event.event()?;
        let event = event.load::<PluginEvent>()?;
        // ... extract and return value
    }
}
```

**Source:** [`solutions/field_extraction.rs`](../../refs/falcosecurity/falco-rustlings/solutions/field_extraction.rs)

### Exercise 6: JSON Configuration

```rust
#[derive(JsonSchema, Deserialize)]
#[schemars(crate = "falco_plugin::schemars")]
#[serde(crate = "falco_plugin::serde")]
struct Config {
    range: u64,
}

impl Plugin for RandomGenPlugin {
    type ConfigType = Json<Config>;

    fn new(_input: Option<&TablesInput>, Json(config): Self::ConfigType) -> Result<Self, Error> {
        Ok(Self { range: config.range, ... })
    }
}
```

**Source:** [`solutions/event_parsing.rs`](../../refs/falcosecurity/falco-rustlings/solutions/event_parsing.rs)

### Exercise 7: Event Parsing

```rust
impl ParsePlugin for RandomGenPlugin {
    const EVENT_TYPES: &'static [EventType] = &[];
    const EVENT_SOURCES: &'static [&'static str] = &["random_generator"];

    fn parse_event(&mut self, event: &EventInput, _parse_input: &ParseInput)
        -> Result<(), Error> {
        // Parse event and update internal state (e.g., histogram)
        let event = event.event()?;
        let event = event.load::<PluginEvent>()?;
        // ... process and store state
        Ok(())
    }
}
```

**Source:** [`solutions/event_parsing.rs`](../../refs/falcosecurity/falco-rustlings/solutions/event_parsing.rs)

### Exercise 4: Async Events

```rust
impl AsyncEventPlugin for AsyncRandomGenPlugin {
    const ASYNC_EVENTS: &'static [&'static str] = &["async"];
    const EVENT_SOURCES: &'static [&'static str] = &[];  // All sources

    fn start_async(&mut self, handler: AsyncHandler) -> Result<(), Error> {
        let event = AsyncEvent {
            plugin_id: None,
            name: Some(c"async"),
            data: Some(b"hello world"),
        };
        handler.emit(Event { metadata: EventMetadata::default(), params: event })?;
        Ok(())
    }

    fn stop_async(&mut self) -> Result<(), Error> { Ok(()) }
}
```

**Source:** [`solutions/async_events_plugin.rs`](../../refs/falcosecurity/falco-rustlings/solutions/async_events_plugin.rs)

## Project Setup

### Requirements

1. Install [Rustlings](https://github.com/rust-lang/rustlings)
2. Clone the repository
3. Run `rustlings` in the repository directory

### Dependencies

```toml
[dependencies]
falco_plugin = { git = "https://github.com/falcosecurity/plugin-sdk-rs" }
falco_plugin_runner = { git = "https://github.com/falcosecurity/plugin-sdk-rs" }
rand = "0.8.5"
```

**Source:** [`Cargo.toml`](../../refs/falcosecurity/falco-rustlings/Cargo.toml)

## Testing Framework

Exercises use `falco_plugin_runner` for testing without a full Falco installation:

```rust
mod tests {
    use exercises::native::NativeTestDriver;
    use exercises::{CapturingTestDriver, TestDriver};

    #[test]
    fn test_plugin() {
        let mut driver = NativeTestDriver::new().unwrap();
        driver.register_plugin(&super::MY_PLUGIN, c"").unwrap();
        let mut driver = driver.start_capture(c"", c"").unwrap();

        let event = driver.next_event().unwrap();
        // Assert on event contents...
    }
}
```

**Source:** [`exercises/source_plugin.rs`](../../refs/falcosecurity/falco-rustlings/exercises/source_plugin.rs)

## Next Steps After Completion

The final message points to a working example plugin that demonstrates:
- Building with a single `cargo` command
- Loading and testing with Docker

**Example:** [madchicken/rand-generator-plugin](https://github.com/madchicken/rand-generator-plugin)

**Source:** [`info.toml`](../../refs/falcosecurity/falco-rustlings/info.toml)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, installation | [`README.md`](../../refs/falcosecurity/falco-rustlings/README.md) |
| Exercise list, hints | [`info.toml`](../../refs/falcosecurity/falco-rustlings/info.toml) |
| Dependencies | [`Cargo.toml`](../../refs/falcosecurity/falco-rustlings/Cargo.toml) |
| Base plugin exercise | [`exercises/your_first_plugin.rs`](../../refs/falcosecurity/falco-rustlings/exercises/your_first_plugin.rs) |
| Source plugin exercise | [`exercises/source_plugin.rs`](../../refs/falcosecurity/falco-rustlings/exercises/source_plugin.rs) |
| Field extraction solution | [`solutions/field_extraction.rs`](../../refs/falcosecurity/falco-rustlings/solutions/field_extraction.rs) |
| Event parsing solution | [`solutions/event_parsing.rs`](../../refs/falcosecurity/falco-rustlings/solutions/event_parsing.rs) |
| Async events solution | [`solutions/async_events_plugin.rs`](../../refs/falcosecurity/falco-rustlings/solutions/async_events_plugin.rs) |

## Related Documentation

- [Falco Plugin Rust SDK Documentation](https://falcosecurity.github.io/plugin-sdk-rs/)
- [Falco Plugin Architecture](https://falco.org/docs/plugins/architecture/)
- [`plugin-sdk-rs.md`](plugin-sdk-rs.md) - Rust SDK reference
- [`plugins.md`](plugins.md) - Plugin registry and overview
