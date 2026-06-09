# Falco Binary Report Template

> **Instructions:** Replace all `{{PLACEHOLDER}}` values with actual data extracted from the system.

---

# Falco Binary Report

> **Generated:** {{DATE}} | **Falco Version:** {{FALCO_VERSION}} | **Architecture:** {{ARCHITECTURE}}

This report contains static analysis of the Falco binary installation, including version information, dependencies, plugins, configuration, and system requirements.

## Version Information

| Component | Version |
|-----------|---------|
| Falco | {{FALCO_VERSION}} |
| Libs | {{LIBS_VERSION}} |
| Plugin API | {{PLUGIN_API_VERSION}} |
| Engine | {{ENGINE_VERSION}} |
| Driver API | {{DRIVER_API_VERSION}} |
| Driver Schema | {{DRIVER_SCHEMA_VERSION}} |
| Default Driver | {{DEFAULT_DRIVER_VERSION}} |

**Commands:**
```bash
falco --version
```

## Binary Analysis

### File Information

| Property | Value |
|----------|-------|
| Path | {{BINARY_PATH}} |
| Type | {{FILE_TYPE}} |
| Architecture | {{MACHINE_ARCH}} |
| Linking | {{LINKING_TYPE}} |
| Interpreter | {{INTERPRETER}} |
| Target OS | {{TARGET_OS}} |
| Build ID | {{BUILD_ID}} |
| Stripped | {{STRIPPED}} |
| File Size | {{FILE_SIZE}} |

**Commands:**
```bash
which falco
file $(which falco)
readelf -h $(which falco)
ls -lh $(which falco)
```

### Section Sizes

| Section | Size |
|---------|------|
| text | {{TEXT_SIZE}} |
| data | {{DATA_SIZE}} |
| bss | {{BSS_SIZE}} |
| **Total** | **{{TOTAL_SIZE}}** |

**Commands:**
```bash
size $(which falco)
```

### ELF Header

```
Class:                             {{ELF_CLASS}}
Data:                              {{ELF_DATA}}
Type:                              {{ELF_TYPE}}
Machine:                           {{ELF_MACHINE}}
Entry point address:               {{ENTRY_POINT}}
Number of program headers:         {{PROGRAM_HEADERS}}
Number of section headers:         {{SECTION_HEADERS}}
```

**Commands:**
```bash
readelf -h $(which falco)
```

### Build Notes

- **OS:** {{BUILD_OS}}
- **ABI Version:** {{ABI_VERSION}}
- **Build ID:** {{BUILD_ID}}

**Commands:**
```bash
readelf -n $(which falco)
```

### Security Features

| Feature | Status |
|---------|--------|
| BIND_NOW | {{BIND_NOW_STATUS}} |
| Full RELRO | {{RELRO_STATUS}} |
| File Capabilities | {{CAPABILITIES}} |

**Commands:**
```bash
readelf -d $(which falco) | grep -E "(RELRO|BIND_NOW|FLAGS)"
getcap $(which falco)
```

## Dynamic Library Dependencies

### Required Libraries

| Library | Description |
|---------|-------------|
{{#EACH LIBRARY}}
| `{{LIBRARY_NAME}}` | {{LIBRARY_DESCRIPTION}} |
{{/EACH}}

**Commands:**
```bash
ldd $(which falco)
readelf -d $(which falco) | grep NEEDED
```

### GLIBC Version Requirements

| GLIBC Version | Required |
|---------------|----------|
{{#EACH GLIBC_VERSION}}
| {{VERSION}} | Yes |
{{/EACH}}
| **{{MAX_GLIBC_VERSION}}** | **Yes (Minimum Required)** |

**Minimum GLIBC Version: {{MIN_GLIBC_BINARY}}**

**Commands:**
```bash
objdump -p $(which falco) | grep GLIBC | sort -u
```

## Environment Variables

| Variable | Purpose |
|----------|---------|
{{#EACH ENV_VAR}}
| `{{VAR_NAME}}` | {{VAR_PURPOSE}} |
{{/EACH}}

**Commands:**
```bash
strings $(which falco) | grep -E "^FALCO_" | sort -u
```

## Plugins

### Installed Plugins

| Plugin | Size | GLIBC Min | Stripped |
|--------|------|-----------|----------|
{{#EACH PLUGIN}}
| `{{PLUGIN_NAME}}` | {{PLUGIN_SIZE}} | {{PLUGIN_GLIBC}} | {{PLUGIN_STRIPPED}} |
{{/EACH}}

**Commands:**
```bash
ls -lh /usr/share/falco/plugins/*.so
file /usr/share/falco/plugins/*.so
objdump -p /usr/share/falco/plugins/*.so | grep GLIBC
```

### Default Loaded Plugin: {{DEFAULT_PLUGIN_NAME}}

| Property | Value |
|----------|-------|
| Name | {{DEFAULT_PLUGIN_NAME}} |
| Version | {{DEFAULT_PLUGIN_VERSION}} |
| Description | {{DEFAULT_PLUGIN_DESCRIPTION}} |
| Contact | {{DEFAULT_PLUGIN_CONTACT}} |

**Capabilities:**
{{#EACH PLUGIN_CAPABILITY}}
- {{CAPABILITY}}
{{/EACH}}

**Dependencies:**
{{#EACH PLUGIN_DEPENDENCY}}
- `{{DEPENDENCY}}`
{{/EACH}}

**Minimum GLIBC:** {{DEFAULT_PLUGIN_GLIBC}}

**Commands:**
```bash
falco --list-plugins
falco --plugin-info {{DEFAULT_PLUGIN_NAME}}
ldd /usr/share/falco/plugins/lib{{DEFAULT_PLUGIN_NAME}}.so
```

### Plugin Exported Functions

```
{{PLUGIN_EXPORTED_FUNCTIONS}}
```

**Commands:**
```bash
nm -D /usr/share/falco/plugins/lib{{DEFAULT_PLUGIN_NAME}}.so | grep "T plugin_"
```

### Plugin Configuration Schema

{{DEFAULT_PLUGIN_CONFIG_SCHEMA_SUMMARY}}

**Commands:**
```bash
falco --plugin-info {{DEFAULT_PLUGIN_NAME}}
```

## Configuration Files

### File Locations

| File | Size | Purpose |
|------|------|---------|
{{#EACH CONFIG_FILE}}
| `{{FILE_PATH}}` | {{FILE_SIZE}} | {{FILE_PURPOSE}} |
{{/EACH}}

**Commands:**
```bash
ls -la /etc/falco/*.yaml /etc/falco/config.d/*.yaml
```

### Default Configuration Highlights

```yaml
{{DEFAULT_CONFIG_HIGHLIGHTS}}
```

**Commands:**
```bash
cat /etc/falco/falco.yaml
cat /etc/falco/config.d/*.yaml
```

## Rules Statistics

| Metric | Value |
|--------|-------|
| Loaded Rules | {{LOADED_RULES_COUNT}} |
| Rules Files | {{RULES_FILES_COUNT}} |

**Commands:**
```bash
falco -L 2>&1 | grep -E "^[A-Z]" | wc -l
```

## Field and Event Statistics

| Metric | Value |
|--------|-------|
| Available Fields | {{FIELDS_COUNT}} |
| Syscall Events | {{EVENTS_COUNT}} |
| System Page Size | {{PAGE_SIZE}} |

**Commands:**
```bash
falco --list -N 2>&1 | wc -l
falco --list-events 2>&1 | grep -E "^[<>] " | wc -l
falco --page-size
```

### Field Categories

Fields are organized into these classes:
{{#EACH FIELD_CLASS}}
- `{{CLASS}}.*` - {{CLASS_DESCRIPTION}}
{{/EACH}}

### Ignored Syscalls (Performance)

The following syscalls are ignored by default for performance:
{{IGNORED_SYSCALLS}}

**Commands:**
```bash
falco -i
```

## System Requirements Summary

### Minimum Requirements

| Requirement | Value |
|-------------|-------|
| Architecture | {{ARCHITECTURE}} |
| GLIBC (Falco only) | {{MIN_GLIBC_BINARY}} |
| GLIBC (with {{DEFAULT_PLUGIN_NAME}} plugin) | {{MIN_GLIBC_WITH_PLUGIN}} |
| Kernel (for eBPF) | {{MIN_KERNEL}} |
| Page Size | {{PAGE_SIZE}} |

### Required Libraries

For the Falco binary:
{{#EACH BINARY_LIBRARY}}
- {{LIBRARY}}
{{/EACH}}

For the {{DEFAULT_PLUGIN_NAME}} plugin:
{{#EACH PLUGIN_LIBRARY}}
- {{LIBRARY}}
{{/EACH}}

### Disk Space

| Component | Size |
|-----------|------|
| Falco binary | {{BINARY_SIZE}} |
| All plugins | {{PLUGINS_TOTAL_SIZE}} |
| Configuration | {{CONFIG_TOTAL_SIZE}} |
| **Total** | **{{TOTAL_DISK_SPACE}}** |

## Embedded Paths

### Certificate Paths
{{#EACH CERT_PATH}}
- `{{PATH}}`
{{/EACH}}

### System Paths
{{#EACH SYSTEM_PATH}}
- `{{PATH}}`
{{/EACH}}

**Commands:**
```bash
readelf -p .rodata $(which falco) | grep -E "(/etc/|/usr/|falco)"
strings $(which falco) | grep -E "^/etc/|^/usr/"
```

## Driver Information

| Driver | Description |
|--------|-------------|
{{#EACH DRIVER}}
| `{{DRIVER_NAME}}` | {{DRIVER_DESCRIPTION}} |
{{/EACH}}

### Default Driver Configuration

```yaml
{{DEFAULT_DRIVER_CONFIG}}
```

---

## Data Collection Commands Summary

```bash
# Version information
falco --version

# Binary analysis
which falco
file $(which falco)
readelf -h $(which falco)
readelf -n $(which falco)
readelf -d $(which falco)
size $(which falco)
ls -lh $(which falco)
getcap $(which falco)

# Dependencies
ldd $(which falco)
objdump -p $(which falco) | grep GLIBC

# Environment variables and embedded strings
strings $(which falco) | grep -E "^FALCO_"
readelf -p .rodata $(which falco) | grep -E "(/etc/|/usr/|falco)"

# Plugin analysis
ls -lh /usr/share/falco/plugins/*.so
file /usr/share/falco/plugins/*.so
ldd /usr/share/falco/plugins/*.so
objdump -p /usr/share/falco/plugins/*.so | grep GLIBC
nm -D /usr/share/falco/plugins/*.so | grep "T plugin_"
falco --list-plugins
falco --plugin-info <plugin_name>

# Configuration
ls -la /etc/falco/*.yaml /etc/falco/config.d/*.yaml
cat /etc/falco/falco.yaml
cat /etc/falco/config.d/*.yaml

# Introspection
falco -L
falco --list -N
falco --list-events
falco -i
falco --page-size
falco --support
```
