---
name: falco-cli
description: Use the Falco CLI for validation, introspection, and information gathering. Supports local binary, downloaded versions from download.falco.org, and container images (Docker/Podman). Validate rules files, list available fields, inspect plugins, get version info, analyze binary dependencies (GLIBC, shared libraries), and verify Falco knowledge. This skill enables CLI-mode operations and binary analysis without requiring elevated privileges or running Falco as a daemon.
metadata:
  falco-version: "0.43"
---

# Falco CLI

Use the `falco` command-line tool for validation and introspection tasks.

## Critical Warning: Daemon Mode

**NEVER run `falco` without one of the CLI-safe options listed below.** Running `falco` alone (or with daemon-related options) will attempt to start Falco as a monitoring daemon, which:
- Requires elevated privileges (`sudo`)
- Runs indefinitely until stopped
- Is NOT the intended use of this skill

## Binary Sources

This skill can work with Falco from multiple sources:

### 1. Local Binary (Default)

By default, use the system-installed Falco binary:

```bash
# Default path
falco --version

# Or specify a custom path
/path/to/custom/falco --version
```

**When user provides a custom binary path**, use that path instead of `falco` for all commands.

### 2. Downloaded Binary

Download a specific Falco version from the official distribution site.

**Download URL pattern:**
```
https://download.falco.org/packages/bin/{arch}/falco-{version}-{arch}.tar.gz
```

**Available architectures:**
- `x86_64`
- `aarch64`

**Package variants:**
- `falco-{version}-{arch}.tar.gz` - Standard binary (dynamically linked)
- `falco-{version}-static-{arch}.tar.gz` - Statically linked binary

**Download and extract workflow:**

```bash
# Set version and architecture
VERSION="0.44.0"
ARCH="x86_64"

# Create temp directory
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# Download
curl -LO "https://download.falco.org/packages/bin/${ARCH}/falco-${VERSION}-${ARCH}.tar.gz"

# Extract
tar -xzf "falco-${VERSION}-${ARCH}.tar.gz"

# Binary is now at:
# $TMPDIR/falco-${VERSION}-${ARCH}/usr/bin/falco

# Use it
"$TMPDIR/falco-${VERSION}-${ARCH}/usr/bin/falco" --version
```

**Static binary** (for systems with older GLIBC):
```bash
curl -LO "https://download.falco.org/packages/bin/${ARCH}/falco-${VERSION}-static-${ARCH}.tar.gz"
tar -xzf "falco-${VERSION}-static-${ARCH}.tar.gz"
```

**List available versions:**
```bash
curl -s "https://falco-distribution.s3-eu-west-1.amazonaws.com/?prefix=packages/bin/x86_64/&delimiter=/" | \
  grep -oP 'falco-[0-9]+\.[0-9]+\.[0-9]+' | sort -V | uniq
```

### 3. Container Image

When a container runtime (Docker/Podman) is available, use official Falco container images.

**Check container runtime:**
```bash
docker --version || podman --version
```

**Base image:** `falcosecurity/falco`

**Image variants:**

| Image | Tag Pattern | Use Case |
|-------|-------------|----------|
| Standard (Wolfi) | `falcosecurity/falco:{version}` | Default, minimal base |
| Debian | `falcosecurity/falco:{version}-debian` | When Debian compatibility needed |
| Architecture-specific | `falcosecurity/falco:{arch}-{version}` | Multi-arch builds |

**Tag examples for version 0.44.0:**
- `falcosecurity/falco:0.44.0` - Standard (Wolfi-based)
- `falcosecurity/falco:0.44.0-debian` - Debian-based
- `falcosecurity/falco:x86_64-0.44.0` - x86_64 specific
- `falcosecurity/falco:aarch64-0.44.0` - ARM64 specific
- `falcosecurity/falco:latest` - Latest release

**Running CLI commands in container:**

```bash
# Version info
docker run --rm falcosecurity/falco:0.44.0 falco --version

# List plugins
docker run --rm falcosecurity/falco:0.44.0 falco --list-plugins

# List fields
docker run --rm falcosecurity/falco:0.44.0 falco --list

# Validate rules (mount rules file)
docker run --rm -v /path/to/rules.yaml:/rules.yaml:ro \
  falcosecurity/falco:0.44.0 falco -V /rules.yaml

# Get support info
docker run --rm falcosecurity/falco:0.44.0 falco --support
```

**Binary analysis in container:**
```bash
# File info
docker run --rm falcosecurity/falco:0.44.0 file /usr/bin/falco

# Library dependencies
docker run --rm falcosecurity/falco:0.44.0 ldd /usr/bin/falco

# List plugins
docker run --rm falcosecurity/falco:0.44.0 ls -la /usr/share/falco/plugins/

# Read config
docker run --rm falcosecurity/falco:0.44.0 cat /etc/falco/falco.yaml
```

**When to use container images:**
- System doesn't have Falco installed
- Need to test a different Falco version
- Need a clean/isolated environment
- Cross-platform consistency

**Other Falco images:**

| Image | Purpose |
|-------|---------|
| `falcosecurity/falco-driver-loader` | Build/load kernel module or eBPF probe |
| `falcosecurity/falco-no-driver` | Falco without driver (legacy, up to 0.39.x) |

## CLI-Safe Options

These options execute a task and exit immediately. They are safe to run without `sudo`.

### Version and Help

| Command | Purpose |
|---------|---------|
| `falco --version` | Show Falco version, libs version, plugin API version, engine version, driver API/schema versions |
| `falco -h, --help` | Show all available options |
| `falco --page-size` | Show system page size (useful for tuning ring buffer) |

### Schema Information

| Command | Purpose |
|---------|---------|
| `falco --config-schema` | Print the configuration file JSON schema |
| `falco --rule-schema` | Print the rules file JSON schema |

### Rules Inspection

| Command | Purpose |
|---------|---------|
| `falco -V, --validate <rules_file>` | **Validate rules file(s)** - exits with success/failure |
| `falco -L` | List all rules with name and description |
| `falco -l "<rule_name>"` | Show details for a specific rule (use quotes if name has spaces) |

**Examples:**
```bash
# Validate default rules
falco -V /etc/falco/falco_rules.yaml

# Validate multiple files
falco -V /etc/falco/falco_rules.yaml -V /etc/falco/falco_rules.local.yaml

# Validate custom rules
falco -V ./my_custom_rules.yaml

# List all loaded rules
falco -L

# Get details about a specific rule
falco -l "Terminal shell in container"
```

### Field Listing

| Command | Purpose |
|---------|---------|
| `falco --list` | List all available fields for rule conditions |
| `falco --list=syscall` | List only syscall fields |
| `falco --list=<source>` | List fields for a specific event source |
| `falco --list --markdown` | Output field list in Markdown format |
| `falco --list -N` | List only field names (no descriptions) |

**Example output structure:**
```
Field Class:                  evt (All event types)
Description:                  These fields can be used for all event types
Event Sources:                syscall

evt.num                       event number
evt.time                      event timestamp as a time string...
```

### Event Listing

| Command | Purpose |
|---------|---------|
| `falco --list-events` | List all syscall events, metaevents, and tracepoint events |
| `falco --list-events --markdown` | Output in Markdown format |

### Plugin Information

| Command | Purpose |
|---------|---------|
| `falco --list-plugins` | List all loaded plugins with capabilities |
| `falco --plugin-info <name>` | Get detailed info about a specific plugin (init schema, capabilities) |

**Examples:**
```bash
# List loaded plugins
falco --list-plugins

# Get details about the container plugin
falco --plugin-info container
```

### Diagnostic Information

| Command | Purpose |
|---------|---------|
| `falco --support` | Print comprehensive support info in JSON (version, config, rules, fields, etc.) |
| `falco -i` | List events ignored by default for performance reasons |

### Configuration Validation

| Command | Purpose |
|---------|---------|
| `falco --dry-run` | Validate configuration and rules without processing events |

**This is useful to verify the entire Falco configuration is valid.**

## Modifying CLI Behavior

These options can be combined with CLI-safe options above:

| Option | Purpose |
|--------|---------|
| `-c <path>` | Use alternative configuration file |
| `-r <rules_file>` | Load specific rules file (can be used multiple times) |
| `-o, --option <opt>=<val>` | Override configuration value (supports dot notation, e.g., `json_output=true`) |
| `-v` | Enable verbose output |

**Examples:**
```bash
# Validate rules with a specific config
falco -c /path/to/falco.yaml -V ./my_rules.yaml

# List rules with JSON output enabled
falco -o json_output=true -L

# Validate with verbose output
falco -v -V ./my_rules.yaml

# Use specific rules file for listing
falco -r ./my_rules.yaml -L
```

## JSON Output

Many CLI commands support JSON output when `json_output` is enabled:

```bash
# List rules in JSON format
falco -o json_output=true -L

# Support info is always JSON
falco --support
```

## Common Use Cases

### 1. Verify Falco Installation
```bash
falco --version
```

### 2. Validate Custom Rules Before Deployment
```bash
falco -V ./my_rules.yaml
```

### 3. Find Available Fields for Rule Writing
```bash
# All fields
falco --list

# Only process-related fields (search output)
falco --list 2>&1 | grep -A5 "proc\."

# Fields for a specific plugin source
falco --list=<plugin_event_source>
```

### 4. Understand a Rule's Purpose
```bash
falco -l "Write below etc"
```

### 5. Check Plugin Capabilities
```bash
falco --list-plugins
falco --plugin-info container
```

### 6. Full System Diagnostic
```bash
falco --support > falco_support.json
```

### 7. Validate Entire Configuration
```bash
falco --dry-run
```

## Options to AVOID (Daemon Mode)

The following will attempt to start Falco as a daemon and should NOT be used with this skill:

| Option | Why to Avoid |
|--------|--------------|
| `falco` (no options) | Starts daemon, requires sudo |
| `-M <seconds>` | Runs daemon for N seconds |
| `--enable-source` / `--disable-source` | Daemon runtime option |
| `-P, --pidfile` | Daemon PID file |
| `-U, --unbuffered` | Daemon output buffering |
| `-p, --print` | Deprecated, daemon output format |

## Default Paths

- Binary: `/usr/bin/falco`
- Configuration: `/etc/falco/falco.yaml`
- Config directory: `/etc/falco/config.d/`
- Default rules: `/etc/falco/falco_rules.yaml`
- Local rules: `/etc/falco/falco_rules.local.yaml`
- Plugins: `/usr/share/falco/plugins/`
- Kernel module (if installed): `/lib/modules/$(uname -r)/updates/falco/` or `/lib/modules/$(uname -r)/extra/falco/`

## Binary and Plugin Analysis

Analyze the `falco` binary and plugin shared objects to understand system requirements, dependencies, and compatibility.

### Binary Location and Type

```bash
# Find falco binary and get basic info
which falco
file $(which falco)

# Example output:
# /usr/bin/falco: ELF 64-bit LSB executable, x86-64, version 1 (SYSV),
# dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, ...
```

### Dynamic Library Dependencies

```bash
# List all shared library dependencies for falco
ldd $(which falco)

# List dependencies for a plugin (e.g., container plugin)
ldd /usr/share/falco/plugins/libcontainer.so

# Using readelf (alternative)
readelf -d $(which falco) | grep NEEDED
```

### GLIBC Version Requirements

```bash
# Find minimum GLIBC version required by falco
objdump -p $(which falco) | grep GLIBC

# Find minimum GLIBC for a plugin
objdump -p /usr/share/falco/plugins/libcontainer.so | grep GLIBC

# The highest version number shown is the minimum required GLIBC
```

### Architecture Information

```bash
# Get ELF header details (architecture, type)
readelf -h $(which falco) | grep -E "(Class|Machine|Type)"

# Example output:
#   Class:   ELF64
#   Type:    EXEC (Executable file)
#   Machine: Advanced Micro Devices X86-64
```

### Binary Size

```bash
# File size
ls -lh $(which falco)

# Section sizes (text, data, bss)
size $(which falco)
```

### Security Features

```bash
# Check for RELRO, BIND_NOW (hardening features)
readelf -d $(which falco) | grep -E "(RELRO|BIND_NOW|FLAGS)"

# Check file capabilities (if any are set)
getcap $(which falco)
```

### Build Information

```bash
# Get build ID and ABI info
readelf -n $(which falco)

# Example output:
#   Build ID: f78d79363fb4c241
#   OS: Linux, ABI: 2.0.0
```

### Embedded Paths and Strings

```bash
# Extract embedded file paths from binary
readelf -p .rodata $(which falco) | grep -E "(/etc/|/usr/|falco)"

# Extract Falco-related strings
strings $(which falco) | grep -E "^(FALCO_|falco_)" | sort -u

# Find environment variables used by Falco
strings $(which falco) | grep -E "^FALCO_"
```

### Plugin Analysis

```bash
# List all installed plugins
ls -la /usr/share/falco/plugins/

# Get file info for all plugins
file /usr/share/falco/plugins/*.so

# Check plugin dependencies
ldd /usr/share/falco/plugins/libcontainer.so

# List exported plugin API functions
nm -D /usr/share/falco/plugins/libcontainer.so | grep "T plugin_"

# Check GLIBC requirements for plugin
objdump -p /usr/share/falco/plugins/libcontainer.so | grep GLIBC
```

### Configuration File Analysis

```bash
# Read default configuration
cat /etc/falco/falco.yaml

# Read plugin-specific configuration
cat /etc/falco/config.d/*.yaml

# List available rules files
ls -la /etc/falco/*.yaml
```

### Common Analysis Tasks

#### 1. Check System Compatibility
```bash
# Get all requirements at once
echo "=== Falco Binary ===" && \
file $(which falco) && \
echo -e "\n=== GLIBC Requirements ===" && \
objdump -p $(which falco) | grep GLIBC | sort -u && \
echo -e "\n=== Library Dependencies ===" && \
ldd $(which falco)
```

#### 2. Full Plugin Inventory
```bash
# List plugins with their dependencies
for plugin in /usr/share/falco/plugins/*.so; do
  echo "=== $(basename $plugin) ==="
  file "$plugin"
  ldd "$plugin" 2>/dev/null | grep -v "linux-vdso"
  echo
done
```

#### 3. Minimum GLIBC Version
```bash
# Find the highest (minimum required) GLIBC version
objdump -p $(which falco) /usr/share/falco/plugins/*.so 2>/dev/null | \
  grep GLIBC | sed 's/.*GLIBC_//' | sort -V | tail -1
```

#### 4. Verify Installation Integrity
```bash
# Check binary exists and is executable
test -x $(which falco) && echo "Falco binary OK" || echo "Falco binary missing/not executable"

# Check default config exists
test -f /etc/falco/falco.yaml && echo "Config OK" || echo "Config missing"

# Check default rules exist
test -f /etc/falco/falco_rules.yaml && echo "Rules OK" || echo "Rules missing"

# Check plugins directory
test -d /usr/share/falco/plugins && echo "Plugins dir OK" || echo "Plugins dir missing"
```

## Falco Binary Report

Generate a comprehensive static analysis report of the Falco installation. This report extracts all available information from the binary, plugins, configuration, and CLI introspection.

**Output location:** `refs/falco-binary-report.md`

**After generation:** The report should be ingested to create a digest at `digests/falco-binary-report.md`

### Report Contents

The report includes:

1. **Version Information**
   - Falco version, libs version, plugin API, engine version
   - Driver API/schema versions

2. **Binary Analysis**
   - File type, architecture, build ID
   - Dynamic library dependencies
   - GLIBC version requirements
   - Security features (RELRO, BIND_NOW)
   - Binary size and section breakdown

3. **Plugin Analysis** (for each installed plugin)
   - File type and size
   - Dependencies and GLIBC requirements
   - Exported plugin API functions
   - Plugin capabilities (from `--list-plugins`)

4. **Configuration**
   - Default configuration file contents
   - Config directory contents
   - Loaded plugins configuration

5. **Rules**
   - List of available rules files
   - Rules file sizes and locations

6. **Introspection Data**
   - Available fields (`--list`)
   - Available events (`--list-events`)
   - Ignored events (`-i`)
   - System page size

7. **Schemas**
   - Configuration JSON schema
   - Rules JSON schema

8. **Support Information**
   - Full `--support` JSON output

9. **Environment**
   - Known environment variables (FALCO_HOSTNAME, etc.)
   - Embedded paths in binary

### Generation Commands

```bash
# The report is generated by running multiple falco CLI commands
# and system analysis tools, then combining the output into a
# structured markdown document.

# Key commands used:
falco --version
falco --support
falco --list
falco --list-events
falco --list-plugins
falco --plugin-info <plugin>
falco -i
falco --page-size
falco --config-schema
falco --rule-schema
file $(which falco)
ldd $(which falco)
objdump -p $(which falco) | grep GLIBC
readelf -h $(which falco)
readelf -n $(which falco)
readelf -d $(which falco)
size $(which falco)
# ... and equivalent commands for each plugin
```

### Report Template

Use the template at [`templates/binary-report.md`](templates/binary-report.md) to ensure consistent report structure.

The template includes:
- All section headers and tables
- Placeholder syntax (`{{PLACEHOLDER}}`) for values
- Commands to extract each piece of data
- Complete data collection command summary at the end

### Workflow

1. Run data collection commands from the template
2. Replace all `{{PLACEHOLDER}}` values with extracted data
3. Save report to `refs/falco-binary-report.md`
4. Create digest at `digests/falco-binary-report.md`
5. Update `README.md` and `digests/README.md` with references

## Error Handling

- Exit code `0`: Success
- Exit code non-zero: Error (check stderr for details)
- Validation errors will show the file, line, and error message

## Notes

- Log messages go to stderr, actual output (lists, schemas) goes to stdout
- Use `2>&1` to capture both if needed
- The `[libs]: Cannot read host init process proc root: 13` warning is normal without elevated privileges and can be ignored for CLI operations
