# Falco CLI Reference

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falco/`](../../../refs/falcosecurity/falco/) | **Version:** 0.44.0

## Overview

Falco is the Cloud Native Runtime Security tool. The CLI is the primary interface for running Falco, validating rules, and introspecting the system. This reference documents all command-line options available in Falco 0.43.

## Basic Usage

```
falco [options]
```

When invoked without arguments, Falco attempts to load configuration from the default location (`/etc/falco/falco.yaml`) and begins monitoring system events.

## Configuration Options

| Option | Description |
|--------|-------------|
| `-c <path>` | Configuration file path. Defaults to `/etc/falco/falco.yaml` if not specified. |
| `-o <opt>=<val>`, `--option <opt>=<val>` | Override configuration values. Supports dot notation for nested values and brackets for list indices (e.g., `base.list[1]=val`). Use backslash (`\`) to escape literal dots, brackets, or backslashes in key names (e.g., `base.dotted\.key=val`). Can be passed multiple times. |
| `--config-schema` | Print the configuration JSON schema and exit. Useful for config validation. |
| `--rule-schema` | Print the rules JSON schema and exit. Useful for rules validation. |

**Source:** [`options.cpp:94-102`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

## Rules Options

| Option | Description |
|--------|-------------|
| `-r <rules_file>` | Rules file or directory to load. Can be passed multiple times. Files must have `.yml` or `.yaml` extension. |
| `-V <rules_file>`, `--validate <rules_file>` | Validate the specified rules file(s) and exit. Can be passed multiple times. Returns validation results as JSON when `json_output` is enabled. |
| `-L` | Show name and description of all rules and exit. With `json_output`, prints details about all rules, macros, and lists in JSON format. |
| `-l <rule>` | Show name and description of the specified rule and exit. With `json_output`, prints rule details in JSON format. |

**Source:** [`options.cpp:110-111, 122, 125`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

## Output Options

| Option | Description |
|--------|-------------|
| `-v` | Enable verbose output. |
| `-U`, `--unbuffered` | Turn off output buffering. Every line is flushed immediately. Higher CPU usage but useful when piping to other processes. |
| `-p <format>`, `--print <format>` | **DEPRECATED:** Use `-o append_output...` instead. Append additional info to rule output. Special values: `-pc`/`-pcontainer` for container details, `-pk`/`-pkubernetes` for container and Kubernetes details. |

> **Note:** The `-A` flag was **removed in Falco 0.39**. Use the `base_syscalls.all` configuration option instead.

**Source:** [`options.cpp:120, 124, 126`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

## Event Sources

| Option | Description |
|--------|-------------|
| `--enable-source <source>` | Enable a specific event source. When used, only specified sources are enabled. Cannot be mixed with `--disable-source`. Available sources: `syscall` plus any plugin-provided sources. |
| `--disable-source <source>` | Disable a specific event source. By default, all loaded sources are enabled. Cannot be mixed with `--enable-source`. Disabling all sources is not permitted. |

Both options have no effect when reproducing events from a capture file.

**Source:** [`options.cpp:103, 105`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

## Introspection Commands

### Field Listing

| Option | Description |
|--------|-------------|
| `--list [source]` | List all defined fields and exit. Optionally filter by source (e.g., `syscall` or plugin source names). |
| `-N` | Only print field names (use with `--list`). |
| `--markdown` | Print output in Markdown format (use with `--list` or `--list-events`). |

**Source:** [`options.cpp:112, 116-117`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`list_fields.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/list_fields.cpp)

### Event Listing

| Option | Description |
|--------|-------------|
| `--list-events` | List all defined syscall events, metaevents, tracepoint events, and plugin events. Categories: Syscall events, Tracepoint events, Plugin events, Metaevents. |
| `-i` | Print syscalls ignored by default for performance reasons and exit. |

The `--list-events` output shows for each event: whether it is enabled by default, direction (`>` enter, `<` exit), name, and parameters with types.

**Source:** [`options.cpp:109, 113`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`print_syscall_events.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_syscall_events.cpp)

### Plugin Introspection

| Option | Description |
|--------|-------------|
| `--list-plugins` | Print info on all loaded plugins and exit. Shows plugin count and details for each. |
| `--plugin-info <name>` | Print detailed info for a specific plugin and exit. Shows name, author, init config schema, and suggested open parameters. `<name>` can be the plugin name or its `library_path`. |

**Source:** [`options.cpp:114, 119`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`list_plugins.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/list_plugins.cpp), [`print_plugin_info.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_plugin_info.cpp)

### System Information

| Option | Description |
|--------|-------------|
| `--version` | Print version information and exit. Shows Falco version, Libs version, Plugin API, Engine version, Driver API/Schema versions, and default driver version. With `json_output`, outputs JSON. |
| `--support` | Print support information bundle as JSON and exit. Includes version info, system info, command line, loaded configuration, and rules files content. |
| `--page-size` | Print the system page size and exit. Helps choose appropriate syscall ring buffer size. |

**Source:** [`options.cpp:123, 127-128`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp), [`print_version.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_version.cpp), [`print_support.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_support.cpp)

## Runtime Options

| Option | Description |
|--------|-------------|
| `-M <seconds>` | Stop Falco execution after the specified number of seconds. Default: 0 (run indefinitely). |
| `-P <pid_file>`, `--pidfile <pid_file>` | Write PID to the specified file path. By default, no PID file is created. |
| `--dry-run` | Run Falco without processing events. Validates configuration and rules without starting event capture. |

**Source:** [`options.cpp:104, 115, 121`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

## Help

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Print the help list and exit. |

**Source:** [`options.cpp:95`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 (`EXIT_SUCCESS`) | Successful execution |
| 1 (`EXIT_FAILURE`) | Error occurred (parse error, rule validation failure, runtime error, etc.) |

Falco supports automatic restart on SIGHUP. The main loop re-executes `falco_run()` when the restart flag is set.

**Source:** [`falco.cpp:40-71`](../../../refs/falcosecurity/falco/userspace/falco/falco.cpp)

## Examples

### Basic Monitoring

```bash
# Run with default config
falco

# Run with custom config
falco -c /path/to/falco.yaml

# Run with custom rules
falco -r /path/to/rules.yaml
```

### Configuration Overrides

```bash
# Override single config value
falco -o json_output=true

# Override nested config value
falco -o rules_files[0]=/custom/rules.yaml

# Multiple overrides
falco -o json_output=true -o priority=warning
```

### Rules Validation

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

### Introspection

```bash
# List all available fields
falco --list

# List syscall fields only
falco --list syscall

# List fields in markdown format
falco --list --markdown

# List field names only
falco --list -N

# List all event types
falco --list-events

# List events in markdown format
falco --list-events --markdown

# Show ignored syscalls
falco -i
```

### Plugin Inspection

```bash
# List all loaded plugins
falco --list-plugins

# Get detailed info for a specific plugin
falco --plugin-info cloudtrail
```

### System Information

```bash
# Show version info
falco --version

# Generate support bundle (JSON)
falco --support

# Check system page size
falco --page-size
```

### Dry Run

```bash
# Validate config and rules without processing events
falco --dry-run
```

## Sources

| Topic | Source File |
|-------|-------------|
| CLI options parsing | [`options.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/options.cpp) |
| Options header | [`options.h`](../../../refs/falcosecurity/falco/userspace/falco/app/options.h) |
| Help output | [`print_help.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_help.cpp) |
| Version output | [`print_version.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_version.cpp) |
| Support bundle | [`print_support.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_support.cpp) |
| Field listing | [`list_fields.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/list_fields.cpp) |
| Plugin listing | [`list_plugins.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/list_plugins.cpp) |
| Plugin info | [`print_plugin_info.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_plugin_info.cpp) |
| Syscall events | [`print_syscall_events.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_syscall_events.cpp) |
| Rules validation | [`validate_rules_files.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/validate_rules_files.cpp) |
| Ignored events | [`print_ignored_events.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/print_ignored_events.cpp) |
| Version details | [`versions_info.cpp`](../../../refs/falcosecurity/falco/userspace/falco/versions_info.cpp) |
| Main entry point | [`falco.cpp`](../../../refs/falcosecurity/falco/userspace/falco/falco.cpp) |
| Run result types | [`run_result.h`](../../../refs/falcosecurity/falco/userspace/falco/app/run_result.h) |
