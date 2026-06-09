# Falco Rule Language

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falco/`](../../../refs/falcosecurity/falco/) | **Version:** 0.44.0

## Overview

Falco rules define security detection logic using a YAML-based domain-specific language. Rules are composed of three primitive building blocks: **lists** (collections of values), **macros** (reusable condition fragments), and **rules** (complete detection logic with conditions and outputs). The rule language is processed through a three-phase pipeline: reading (YAML parsing), collection (gathering definitions), and compilation (filter AST generation).

**Engine Version:** 0.58.0 (as defined in [`falco_engine_version.h:22-24`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h))

## Rule File Structure

Rule files are YAML arrays containing rule definitions. Each element is a YAML mapping with one of these top-level keys: `list`, `macro`, `rule`, `required_engine_version`, or `required_plugin_versions`.

```yaml
# Example rule file structure
- required_engine_version: 0.26.0

- required_plugin_versions:
  - name: json
    version: 0.7.0

- list: shell_binaries
  items: [bash, sh, zsh]

- macro: spawned_process
  condition: evt.type = execve

- rule: Shell Spawned
  desc: Detects shell execution
  condition: spawned_process and proc.name in (shell_binaries)
  output: "Shell spawned (user=%user.name command=%proc.cmdline)"
  priority: WARNING
  tags: [shell, process]
```

**Processing Order:** Items are processed sequentially. Later definitions can override earlier ones. Appends require the original definition to exist first.

## Lists

Lists are named collections of values that can be referenced in conditions.

**Source:** [`rule_loader.h:403-416`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```cpp
struct list_info {
    context ctx;
    size_t index;
    size_t visibility;
    std::string name;
    std::vector<std::string> items;
};
```

### Definition Syntax

```yaml
- list: my_binaries
  items: [cat, grep, awk, sed]

# Items can be integers or strings
- list: suspicious_ports
  items: [22, 23, 3389]

# Lists can reference other lists
- list: all_shells
  items: [shell_binaries, powershell]  # References another list
```

### Appending to Lists

```yaml
# Modern syntax (recommended)
- list: shell_binaries
  items: [pwsh, fish]
  override:
    items: append

# Legacy syntax (deprecated)
- list: shell_binaries
  items: [pwsh]
  append: true
```

**Validation:** List names should match the pattern `[^()\"'[:space:]=,]+` (barestring). Invalid names generate a warning.

## Macros

Macros are named condition fragments for reuse across rules.

**Source:** [`rule_loader.h:421-435`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```cpp
struct macro_info {
    context ctx;
    context cond_ctx;
    size_t index;
    size_t visibility;
    std::string name;
    std::string cond;
};
```

### Definition Syntax

```yaml
- macro: open_write
  condition: >
    evt.type in (open, openat, openat2) and
    evt.is_open_write=true

- macro: container
  condition: container.id != host
```

### Appending to Macros

```yaml
# Append additional conditions (joined with space)
- macro: open_write
  condition: or evt.type = creat
  override:
    condition: append
```

**Validation:** Macro names should match `[a-zA-Z]+[a-zA-Z0-9_]*` (identifier pattern). Invalid names generate a warning.

## Rules

Rules define complete detection logic with conditions, outputs, and metadata.

**Source:** [`rule_loader.h:482-509`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

### Complete Rule Syntax (All Fields)

```yaml
- rule: Write Below Etc
  desc: Detect writes to /etc directory                    # Required
  condition: open_write and fd.name startswith /etc/       # Required
  output: "File written to /etc (file=%fd.name user=%user.name)"  # Required
  priority: WARNING                                        # Required
  source: syscall                                          # Optional, default: syscall
  enabled: true                                            # Optional, default: true
  tags: [filesystem, mitre_persistence]                    # Optional
  warn_evttypes: true                                      # Optional, default: true
  skip-if-unknown-filter: false                            # Optional, default: false
  capture: false                                           # Optional, default: false
  capture_duration: 0                                      # Optional, in milliseconds
  exceptions:                                              # Optional
    - name: known_writers
      fields: [proc.name, fd.directory]
      values:
        - [nginx, /etc/nginx]
```

### Rule Fields Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `rule` | string | Yes | - | Rule name (unique identifier) |
| `desc` | string | Yes | - | Human-readable description |
| `condition` | string | Yes | - | Filter expression to match events |
| `output` | string | Yes | - | Alert message format string |
| `priority` | string | Yes | - | Severity level |
| `source` | string | No | `syscall` | Event source |
| `enabled` | boolean | No | `true` | Whether rule is active |
| `tags` | array | No | `[]` | Classification tags |
| `exceptions` | array | No | `[]` | Whitelisting definitions |
| `warn_evttypes` | boolean | No | `true` | Warn if matching too many event types |
| `skip-if-unknown-filter` | boolean | No | `false` | Skip rule if filter field unknown |
| `capture` | boolean | No | `false` | Enable capture when triggered (requires `capture.enabled: true` in falco.yaml) |
| `capture_duration` | integer | No | `0` | Per-rule capture duration in milliseconds (overrides `capture.default_duration`). Verified at [`falco_engine.cpp`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine.cpp): `capture_duration_ns = capture_duration * 1000000LL`. |

### Priority Levels

**Source:** [`falco_common.h:50-59`](../../../refs/falcosecurity/falco/userspace/engine/falco_common.h)

```cpp
enum priority_type {
    PRIORITY_EMERGENCY = 0,    // System unusable
    PRIORITY_ALERT = 1,        // Immediate action needed
    PRIORITY_CRITICAL = 2,     // Critical condition
    PRIORITY_ERROR = 3,        // Error condition
    PRIORITY_WARNING = 4,      // Warning condition
    PRIORITY_NOTICE = 5,       // Normal but significant
    PRIORITY_INFORMATIONAL = 6,// Informational (also: INFO)
    PRIORITY_DEBUG = 7         // Debug-level
};
```

### Rule Matching Strategy

**Source:** [`falco_common.h:66`](../../../refs/falcosecurity/falco/userspace/engine/falco_common.h)

```cpp
enum rule_matching { FIRST = 0, ALL = 1 };
```

- **FIRST**: Stop after first matching rule (default, better performance)
- **ALL**: Continue checking all rules (enables multiple alerts per event)

## Condition Expressions

Conditions use the libsinsp filtering language. See the [Filtering Language Digest](../libs/filtering.md) for complete syntax details.

### Basic Syntax

```yaml
# Field comparisons
condition: proc.name = nginx

# Boolean logic
condition: evt.type = open and fd.name startswith /etc

# Negation
condition: not container.id = host

# Grouping
condition: (evt.type = open or evt.type = openat) and fd.name contains passwd

# Macro references (expanded at compile time)
condition: spawned_process and container
```

### Operators

From the [libs filtering digest](../libs/filtering.md):

| Operator | Description | Example |
|----------|-------------|---------|
| `=`, `!=` | Equality | `proc.name = cat` |
| `<`, `<=`, `>`, `>=` | Numeric comparison | `fd.num <= 2` |
| `contains`, `icontains` | Substring match | `proc.cmdline contains secret` |
| `startswith`, `endswith` | Prefix/suffix | `fd.name startswith /etc` |
| `glob`, `iglob` | Glob pattern | `fd.name glob *.log` |
| `regex` | Regular expression | `proc.name regex ^java.*` |
| `in` | List membership | `proc.name in (cat, ls, grep)` |
| `pmatch` | Prefix list match | `fd.name pmatch (/etc, /var)` |
| `intersects` | List intersection | `proc.args intersects (a, b)` |
| `exists` | Field has value | `container.id exists` |
| `bcontains`, `bstartswith` | Binary comparison | For raw byte fields |

### Comparison Operator List Modifiers (Falco 0.44+)

Comparison operators can be combined with the quantifier modifiers `oneof`, `anyof`, and `allof` to compare a single field value against a list of values with the chosen quantifier semantics. The expression `field <op> <mod> (e0, e1, ... en)` is expanded into the sub-expressions `field <op> e0`, `field <op> e1`, ... `field <op> en`, then combined per `<mod>`:

| Modifier | Semantics |
|----------|-----------|
| `oneof` | Matches when **exactly one** of the sub-expressions matches |
| `anyof` | Matches when **at least one** sub-expression matches (equivalent to ORing them) |
| `allof` | Matches when **all** sub-expressions match (equivalent to ANDing them) |

**Useful combinations** (from the [Falco 0.44.0 release blog](../falco-website/blog.md)):

- `proc.name = anyof (sshd, sudo, su)` — value-in-list (classic), expands to ORed equalities
- `proc.name != allof (sshd, sudo, su)` — value-not-in-list (note: `!= anyof` would NOT do this)
- `proc.cmdline contains allof (curl, bash)` — substring contains all markers
- `proc.name startswith oneof (kube-, etcd-)` — exactly one prefix matches (use when items are mutually exclusive)

**Constraints:**
- The left-hand side must produce a single value at runtime
- The overall expression always fails to match if the right-hand side list is empty
- The modifiers are also accepted in single-field exception `comps`, extending the exception shortcut beyond `in`/`pmatch`/`intersects` to any comparison operator

**Source:** [`rule_loader_cmpop.h:25-49`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_cmpop.h), [`rule_loader_compiler.cpp:66-`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp). Introduced via [#3878](https://github.com/falcosecurity/falco/pull/3878) and [libs#2984](https://github.com/falcosecurity/libs/pull/2984).

### List References in Conditions

```yaml
- list: read_syscalls
  items: [read, readv, pread64]

- rule: Read Sensitive File
  condition: evt.type in (read_syscalls) and fd.name = /etc/shadow
```

Lists are expanded inline during compilation. The above becomes:
```
evt.type in (read, readv, pread64) and fd.name = /etc/shadow
```

## Output Format

Output strings define the alert message using format specifiers.

### Syntax

```yaml
output: "Alert message with field=%field.name and another=%other.field"
```

### Field Interpolation

- `%field.name` - Replaced with field value
- `%container.info` - **Deprecated** (no longer expanded, will be removed in Falco 1.0.0)

### Extra Output Fields

**Source:** [`rule_loader.h:311-325`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

Extra output can be added programmatically:

```cpp
struct extra_output_format_conf {
    std::string m_format;      // Format string to append
    std::string m_source;      // Filter by source (empty = all)
    std::set<std::string> m_tags;  // Filter by tags
    std::string m_rule;        // Filter by rule name
};

struct extra_output_field_conf {
    std::string m_key;         // Field key in output
    std::string m_format;      // Format string
    std::string m_source;
    std::set<std::string> m_tags;
    std::string m_rule;
    bool m_raw;                // Raw value (no formatting)
};
```

## Exceptions

Exceptions provide a structured way to whitelist specific conditions without modifying the rule's main condition.

**Source:** [`rule_loader.h:440-477`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

### Exception Structure

```cpp
struct rule_exception_info {
    struct entry {
        bool is_list;
        std::string item;           // Single value
        std::vector<entry> items;   // List of values
    };

    context ctx;
    std::string name;           // Exception identifier
    entry fields;               // Field(s) to match
    entry comps;                // Comparison operator(s)
    std::vector<entry> values;  // Values to match
};
```

### Exception Types

**Single Field Exception:**

```yaml
exceptions:
  - name: allowed_processes
    fields: proc.name
    comps: in
    values: [nginx, apache, systemd]
```

Compiled to: `and not proc.name in (nginx, apache, systemd)`

**Multi-Field Exception:**

```yaml
exceptions:
  - name: known_writers
    fields: [proc.name, fd.directory]
    comps: [=, startswith]
    values:
      - [nginx, /etc/nginx]
      - [apache, /etc/apache2]
```

Compiled to:
```
and not ((proc.name = nginx and fd.directory startswith /etc/nginx) or
         (proc.name = apache and fd.directory startswith /etc/apache2))
```

### Exception Compilation

**Source:** [`rule_loader_compiler.cpp:93-154`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)

The `build_rule_exception_infos()` function transforms exceptions into condition suffixes:

1. Original condition is wrapped: `(original_condition)`
2. Each exception generates a negated clause
3. Single-field exceptions: `and not (field comp (val1, val2, ...))`
4. Multi-field exceptions: `and not ((f1 c1 v1 and f2 c2 v2) or ...)`

### Appending Exceptions

```yaml
# Original rule with exception structure
- rule: Write Below Etc
  condition: open_write
  exceptions:
    - name: known_writers
      fields: [proc.name, fd.directory]

# Append values to existing exception
- rule: Write Below Etc
  exceptions:
    - name: known_writers
      values:
        - [systemd, /etc/systemd]
  override:
    exceptions: append
```

### Valid Comparison Operators for Exceptions

**Source:** [`rule_loader_collector.cpp:63-101`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_collector.cpp)

- Single field: `in`, `pmatch`, `intersects`, **or** any comparison operator combined with `oneof`/`anyof`/`allof` modifiers (Falco 0.44+, e.g. `comps: startswith anyof`)
- Multi-field: Any supported operator (`=`, `!=`, `contains`, etc.)

## Overrides

The `override` key provides fine-grained control over how rules, macros, and lists are modified.

**Source:** [`rule_loader_reader.cpp:200-262`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp)

### Override Operations

| Operation | Effect |
|-----------|--------|
| `append` | Add to existing value |
| `replace` | Completely replace value |

### Appendable Fields

**Rules:** `condition`, `output`, `desc`, `tags`, `exceptions`

**Macros:** `condition`

**Lists:** `items`

### Replaceable Fields

**Rules:** `condition`, `output`, `desc`, `priority`, `capture`, `capture_duration`, `tags`, `exceptions`, `enabled`, `warn_evttypes`, `skip-if-unknown-filter`

### Override Syntax

```yaml
# Rule override with mixed operations
- rule: existing_rule
  desc: "Additional description"
  condition: and proc.name != systemd
  priority: ERROR
  override:
    desc: append
    condition: append
    priority: replace
```

### Legacy Append Syntax (Deprecated)

```yaml
# Deprecated - generates warning
- rule: existing_rule
  condition: and proc.name != systemd
  append: true
```

**Warning:** Cannot mix `append: true` with `override` key.

## Required Versions

### Required Engine Version

Specifies minimum Falco engine version.

```yaml
# Semver format
- required_engine_version: 0.26.0

# Legacy integer format (interpreted as minor version)
- required_engine_version: 26  # Becomes 0.26.0
```

**Implicit Version Conversion:** [`rule_loader_reader.h:52-56`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.h)

```cpp
static inline sinsp_version get_implicit_engine_version(uint32_t minor) {
    return sinsp_version(MAJOR + "." + std::to_string(minor) + "." + PATCH);
}
```

### Required Plugin Versions

Specifies plugin dependencies with optional alternatives.

**Source:** [`rule_loader.h:370-398`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```yaml
- required_plugin_versions:
  - name: json
    version: 0.7.0
    alternatives:
      - name: json_alt
        version: 0.5.0
```

Alternatives allow multiple plugins to satisfy the requirement.

## Rule Compilation Pipeline

The rule loader processes rules through three distinct phases:

### 1. Reader Phase

**Source:** [`rule_loader_reader.cpp`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp)

- Parses YAML content
- Validates against JSON schema
- Extracts raw definitions
- Handles `append` and `override` syntax
- Delegates to collector

**Key Function:** `reader::read()` (lines 909-968)

**Stricter rule schema validation (Falco 0.44+):** the reader now flags unrecognized top-level keys in `- rule:`, `- macro:`, `- list:`, `required_engine_version`, and `required_plugin_versions` items instead of silently ignoring them. Misspelled or unsupported keys produce a clear validation message at load time. The same change also promotes `warn_evttypes`, `skip-if-unknown-filter`, `capture`, `capture_duration`, and `tags` to first-class targets of the `override` mechanism. Implementation via `warn_unknown_keys()` ([`rule_loader_reader.cpp:407`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp)). Introduced by [#3805](https://github.com/falcosecurity/falco/pull/3805).

### 2. Collector Phase

**Source:** [`rule_loader_collector.cpp`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_collector.cpp)

- Gathers all definitions
- Maintains visibility ordering
- Processes appends and replaces
- Validates exception structures
- Builds indexed collections

**Key Functions:**
- `collector::define()` - Register new definitions
- `collector::append()` - Add to existing definitions
- `collector::selective_replace()` - Replace specific fields

### 3. Compiler Phase

**Source:** [`rule_loader_compiler.cpp`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)

- Expands list references in conditions
- Resolves macro references
- Builds exception condition suffixes
- Parses conditions into AST
- Compiles AST to sinsp_filter
- Validates output format strings

**Key Functions:**
- `compile_list_infos()` - Expand nested lists
- `compile_macros_infos()` - Parse and resolve macros
- `compile_rule_infos()` - Full rule compilation

### Compilation Output

**Source:** [`rule_loader_compile_output.h`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_compile_output.h)

```cpp
struct compile_output {
    indexed_vector<falco_list> lists;
    indexed_vector<falco_macro> macros;
    indexed_vector<falco_rule> rules;
};
```

## Ruleset Management

**Source:** [`filter_ruleset.h`](../../../refs/falcosecurity/falco/userspace/engine/filter_ruleset.h)

### Enabling/Disabling Rules

```cpp
// By name pattern
void enable(const std::string &pattern, match_type match, uint16_t ruleset_id);
void disable(const std::string &pattern, match_type match, uint16_t ruleset_id);

// By tags
void enable_tags(const std::set<std::string> &tags, uint16_t ruleset_id);
void disable_tags(const std::set<std::string> &tags, uint16_t ruleset_id);
```

### Match Types

```cpp
enum class match_type { exact, substring, wildcard };
```

- **exact**: Rule name must match exactly
- **substring**: Pattern appears anywhere in name (empty matches all)
- **wildcard**: Glob-style matching with `*`

### Ruleset IDs

Each ruleset is identified by a numeric ID. The default ruleset is `"default"`. Multiple rulesets allow different rule sets for different contexts.

```cpp
// Engine API
uint16_t find_ruleset_id(const std::string &ruleset);
void enable_rule(const std::string &substring, bool enabled, uint16_t ruleset_id);
```

## Error and Warning Codes

**Source:** [`falco_load_result.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_load_result.h)

### Error Codes

| Code | Description |
|------|-------------|
| `LOAD_ERR_FILE_READ` | Cannot read file |
| `LOAD_ERR_YAML_PARSE` | YAML syntax error |
| `LOAD_ERR_YAML_VALIDATE` | YAML structure invalid |
| `LOAD_ERR_COMPILE_CONDITION` | Condition compilation failed |
| `LOAD_ERR_COMPILE_OUTPUT` | Output format invalid |
| `LOAD_ERR_VALIDATE` | General validation error |

### Warning Codes

| Code | Description |
|------|-------------|
| `LOAD_UNKNOWN_SOURCE` | Unknown event source |
| `LOAD_NO_EVTTYPE` | Rule matches too many event types |
| `LOAD_UNKNOWN_FILTER` | Unknown filter field (with skip enabled) |
| `LOAD_UNUSED_MACRO` | Macro not referenced |
| `LOAD_UNUSED_LIST` | List not referenced |
| `LOAD_DEPRECATED_ITEM` | Deprecated syntax used |
| `LOAD_INVALID_MACRO_NAME` | Macro name doesn't match pattern |
| `LOAD_INVALID_LIST_NAME` | List name doesn't match pattern |

## Sources

| Topic | Source File |
|-------|-------------|
| Rule structures | [`rule_loader.h`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader.h) |
| YAML parsing | [`rule_loader_reader.cpp`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp) |
| Definition collection | [`rule_loader_collector.cpp`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_collector.cpp) |
| Compilation | [`rule_loader_compiler.cpp`](../../../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp) |
| Engine interface | [`falco_engine.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine.h) |
| Rule object | [`falco_rule.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_rule.h) |
| Ruleset management | [`filter_ruleset.h`](../../../refs/falcosecurity/falco/userspace/engine/filter_ruleset.h) |
| JSON schema | [`rule_json_schema.h`](../../../refs/falcosecurity/falco/userspace/engine/rule_json_schema.h) |
| Engine version | [`falco_engine_version.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h) |
| Common types | [`falco_common.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_common.h) |
| Load results | [`falco_load_result.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_load_result.h) |
| Exception proposal | [`proposals/20200828-structured-exception-handling.md`](../../../refs/falcosecurity/falco/proposals/20200828-structured-exception-handling.md) |
| Filtering language | [libs filtering digest](../libs/filtering.md) |
