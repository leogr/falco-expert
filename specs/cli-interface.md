# CLI Interface

> All CLI flags, introspection commands, validation mode, dry-run mode, exit codes, and support bundle.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco/userspace/falco/app/options.cpp`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

## Overview

The Falco CLI is the primary interface for running Falco, validating rules, and introspecting the system. It uses the [cxxopts](https://github.com/jarro2783/cxxopts) library for argument parsing.

```
falco [options]
```

When invoked without arguments, Falco loads configuration from the default location (`/etc/falco/falco.yaml`) and begins monitoring system events. If no configuration file is found, Falco continues execution for commands that do not require one (e.g., `--help`, `--list`); otherwise, it exits with an error.

**Source:** [`options.cpp:32-85`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`falco.cpp:59-71`](../refs/falcosecurity/falco/userspace/falco/falco.cpp)

## Implementation Details

All CLI options are defined in `options::define()` and parsed via `options::parse()`. Each option maps directly to a member variable in the `falco::app::options` class.

**Source:** [`options.h:34-83`](../refs/falcosecurity/falco/userspace/falco/app/options.h), [`options.cpp:92-131`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-c <path>` | `std::string` | `/etc/falco/falco.yaml` | Configuration file path. In debug builds, also tries the source tree config file. |
| `-o <opt>=<val>`, `--option <opt>=<val>` | `std::vector<std::string>` | *(none)* | Override configuration values. Supports dot notation for nested values (e.g., `base.id=val`, `base.subvalue.subvalue2=val`) and brackets for list indices (e.g., `base.list[1]=val`). Can be passed multiple times. Vector delimiter is disabled, so commas in values are literal. Since 0.44.0, use backslash (`\`) to escape literal dots, brackets, or backslashes in key names (e.g. `-o "base.dotted\.key=val"`, `-o "base.back\\slash=val"`) ([PR #3835](https://github.com/falcosecurity/falco/pull/3835)). |
| `--config-schema` | `bool` | `false` | Print the configuration JSON schema and exit. Useful for programmatic config validation. |
| `--rule-schema` | `bool` | `false` | Print the rules JSON schema and exit. Useful for programmatic rules validation. |

**Source:** [`options.cpp:94-102`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

### Rules Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-r <rules_file>` | `std::vector<std::string>` | *(from config)* | Rules file or directory to load. Can be passed multiple times. Only files with `.yml` or `.yaml` extension are considered. When not specified, Falco defaults to the values in the configuration file. |
| `-V <rules_file>`, `--validate <rules_file>` | `std::vector<std::string>` | *(none)* | Validate the specified rules file(s) and exit. Can be passed multiple times. Returns validation results as JSON when `json_output` is enabled. |
| `-L` | `bool` | `false` | Show name and description of all rules and exit. With `json_output`, prints details about all rules, macros, and lists in JSON format. |
| `-l <rule>` | `std::string` | *(none)* | Show name and description of the specified rule and exit. With `json_output`, prints rule details in JSON format. |

**Source:** [`options.cpp:110-111, 122, 125`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`validate_rules_files.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/validate_rules_files.cpp)

### Output Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-v` | `bool` | `false` | Enable verbose output. |
| `-U`, `--unbuffered` | `bool` | `false` | Turn off output buffering. Every line is flushed immediately. Higher CPU usage but useful when piping to other processes or scripts. |
| `-p <format>`, `--print <format>` | `std::string` | *(none)* | **DEPRECATED:** Use `-o append_output...` instead. Append additional info to rule output. Special values: `-pc`/`-pcontainer` for container details, `-pk`/`-pkubernetes` for container and Kubernetes details. Custom formats are appended to rule output for all events including plugin events. |

> **Note:** The `-A` flag was **removed in Falco 0.39**. Use the `base_syscalls.all` configuration option instead.

**Source:** [`options.cpp:120, 124, 126`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

### Event Source Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--enable-source <source>` | `std::vector<std::string>` | *(all sources)* | Enable a specific event source. When used, only specified sources are enabled. Available sources are `syscall` plus all sources from loaded plugins with event sourcing capability. Can be passed multiple times. |
| `--disable-source <source>` | `std::vector<std::string>` | *(none)* | Disable a specific event source. By default, all loaded sources are enabled. Can be passed multiple times. |

**Behavior constraints:**
- `--enable-source` and `--disable-source` are **mutually exclusive** -- they cannot be mixed.
- Disabling all event sources simultaneously is not permitted.
- Both options have **no effect** when reproducing events from a capture file.

**Source:** [`options.cpp:103, 105`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

### Introspection Commands

#### Field Listing

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--list [source]` | `std::string` (implicit `""`) | *(none)* | List all defined fields and exit. Optionally filter by `<source>` (e.g., `syscall` or any plugin source with event sourcing capability). |
| `-N` | `bool` | `false` | Only print field names (used in conjunction with `--list`). Has no effect with other options. |
| `--format <fmt>` | `std::string` | *(none)* | Print output in the specified format when used with `--list` or `--list-events`. Valid values: `text`, `markdown`, `json`. Added in 0.44.0 ([PR #3803](https://github.com/falcosecurity/falco/pull/3803)). Cannot be used together with `--markdown`. |
| `--markdown` | `bool` | `false` | **DEPRECATED in 0.44.0**, use `--format markdown` instead. Print output in Markdown format (used in conjunction with `--list` or `--list-events`). Has no effect with other options. |

**Source:** [`options.cpp:112, 116-117`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`list_fields.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/list_fields.cpp)

#### Event Listing

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--list-events` | `bool` | `false` | List all defined syscall events, metaevents, tracepoint events, and plugin events, then exit. Output shows for each event: whether enabled by default, direction (`>` enter, `<` exit), name, and parameters with types. Since 0.44.0, supports `--format text\|markdown\|json` ([PR #3803](https://github.com/falcosecurity/falco/pull/3803)). |
| `-i` | `bool` | `false` | Print syscalls ignored by default for performance reasons and exit. |

**Source:** [`options.cpp:109, 113`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`print_syscall_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_syscall_events.cpp), [`print_ignored_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_ignored_events.cpp)

#### Plugin Introspection

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--list-plugins` | `bool` | `false` | Print info on all loaded plugins and exit. Shows plugin count and details for each plugin. |
| `--plugin-info <name>` | `std::string` | *(none)* | Print detailed info for a specific plugin and exit. Shows name, author, init config schema, and suggested open parameters. `<name>` can be the plugin name or its configured `library_path`. |

**Source:** [`options.cpp:114, 119`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`list_plugins.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/list_plugins.cpp), [`print_plugin_info.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_plugin_info.cpp)

#### System Information

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--version` | `bool` | `false` | Print version information and exit. Shows Falco version, Libs version, Plugin API, Engine version, Driver API/Schema versions, and default driver version. With `json_output`, outputs JSON. |
| `--support` | `bool` | `false` | Print support information bundle as JSON and exit. Includes version info, system info, command line, loaded configuration, and rules files content. |
| `--page-size` | `bool` | `false` | Print the system page size and exit. Helps choose the appropriate syscall ring buffer size. |

**Source:** [`options.cpp:123, 127-128`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`print_version.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_version.cpp), [`print_support.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_support.cpp)

### Runtime Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-M <seconds>` | `int` | `0` (run indefinitely) | Stop Falco execution after the specified number of seconds. |
| `-P <pid_file>`, `--pidfile <pid_file>` | `std::string` | `""` (no PID file) | Write PID to the specified file path. By default, no PID file is created. |
| `--dry-run` | `bool` | `false` | Run Falco without processing events. Validates configuration and rules without starting event capture. |

**Source:** [`options.cpp:104, 115, 121`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

### Help

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `-h`, `--help` | `bool` | `false` | Print the help list and exit. |

**Source:** [`options.cpp:95`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`print_help.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_help.cpp)

### Exit Codes

| Code | Constant | Meaning |
|------|----------|---------|
| `0` | `EXIT_SUCCESS` | Successful execution (clean shutdown, validation passed, introspection completed) |
| `1` | `EXIT_FAILURE` | Error occurred (parse error, config error, rule validation failure, runtime error) |

Falco supports automatic restart on `SIGHUP`. The `main()` function calls `falco_run()` in a loop; when the `restart` flag is set (via signal handlers), `falco_run()` is called again.

**Source:** [`falco.cpp:40-71`](../refs/falcosecurity/falco/userspace/falco/falco.cpp)

### Examples

#### Basic Monitoring

```bash
# Run with default config
falco

# Run with custom config
falco -c /path/to/falco.yaml

# Run with custom rules
falco -r /path/to/rules.yaml

# Run for 60 seconds then stop
falco -M 60
```

#### Configuration Overrides

```bash
# Override single config value
falco -o json_output=true

# Override nested config value
falco -o rules_files[0]=/custom/rules.yaml

# Multiple overrides
falco -o json_output=true -o priority=warning
```

#### Rules Validation

```bash
# Validate a single rules file
falco -V /path/to/rules.yaml

# Validate multiple files
falco -V rules1.yaml -V rules2.yaml

# Validate and describe all rules
falco -V rules.yaml -L

# Validate with JSON output
falco -V rules.yaml -o json_output=true
```

#### Introspection

```bash
# List all available fields
falco --list

# List syscall fields only
falco --list syscall

# List fields in markdown format (since 0.44.0)
falco --list --format markdown

# List fields in JSON (since 0.44.0)
falco --list --format json

# List field names only
falco --list -N

# List all event types
falco --list-events

# List events in markdown format (since 0.44.0)
falco --list-events --format markdown

# Show ignored syscalls
falco -i
```

#### Plugin Inspection

```bash
# List all loaded plugins
falco --list-plugins

# Get detailed info for a specific plugin
falco --plugin-info cloudtrail
```

#### System Information

```bash
# Show version info
falco --version

# Generate support bundle (JSON)
falco --support

# Check system page size
falco --page-size
```

#### Dry Run

```bash
# Validate config and rules without processing events
falco --dry-run

# Dry run with custom config
falco --dry-run -c /path/to/falco.yaml
```

## Deprecated Features

| Feature | Status | Replacement |
|---------|--------|-------------|
| `-p <format>` (`--print`) | Deprecated | Use `-o append_output...` instead |
| `-A` (all events) | Removed in 0.39 | Use `base_syscalls.all` configuration option |
| `--gvisor-generate-config`, `--gvisor-*` | **Removed in 0.44.0** ([PR #3797](https://github.com/falcosecurity/falco/pull/3797)) | gVisor engine support has been removed entirely |
| `--markdown` | Deprecated in 0.44.0 ([PR #3803](https://github.com/falcosecurity/falco/pull/3803)) | Use `--format markdown` instead |

**Source:** [`options.cpp`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

## Related Specs

| Spec | Relevance |
|------|-----------|
| [`application-lifecycle.md`](application-lifecycle.md) | App action framework, signal handling, hot reload (SIGHUP restart) |
| [`configuration.md`](configuration.md) | Config system, merging, JSON schema -- used by `-c`, `-o`, `--config-schema` |
| [`rule-engine.md`](rule-engine.md) | Rule compilation and validation -- used by `-r`, `-V`, `-L`, `-l`, `--rule-schema` |
| [`filter-engine.md`](filter-engine.md) | Filter language and field system -- used by `--list`, `-N` |
| [`plugin-system.md`](plugin-system.md) | Plugin API and lifecycle -- used by `--list-plugins`, `--plugin-info` |
| [`output-system.md`](output-system.md) | Alert channels and formatting -- related to `-U`, `-p` |

## Sources

| Topic | Source File |
|-------|-------------|
| CLI options definition | [`options.cpp`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp) |
| Options data structure | [`options.h`](../refs/falcosecurity/falco/userspace/falco/app/options.h) |
| Help output action | [`print_help.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_help.cpp) |
| Version output action | [`print_version.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_version.cpp) |
| Support bundle action | [`print_support.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_support.cpp) |
| Field listing action | [`list_fields.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/list_fields.cpp) |
| Plugin listing action | [`list_plugins.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/list_plugins.cpp) |
| Plugin info action | [`print_plugin_info.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_plugin_info.cpp) |
| Syscall events action | [`print_syscall_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_syscall_events.cpp) |
| Ignored events action | [`print_ignored_events.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/print_ignored_events.cpp) |
| Rules validation action | [`validate_rules_files.cpp`](../refs/falcosecurity/falco/userspace/falco/app/actions/validate_rules_files.cpp) |
| Main entry point | [`falco.cpp`](../refs/falcosecurity/falco/userspace/falco/falco.cpp) |
| Version details | [`versions_info.cpp`](../refs/falcosecurity/falco/userspace/falco/versions_info.cpp) |
| CLI reference digest | [`cli-reference.md`](../digests/falcosecurity/falco/cli-reference.md) |
