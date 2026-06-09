# Rule Engine

> Rule language, YAML schema, three-phase compilation pipeline, rule indexing, ruleset management, and error handling.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco/userspace/engine/`](../refs/falcosecurity/falco/userspace/engine/)

## Overview

The Falco rule engine compiles YAML-based rule definitions into executable filters (`sinsp_filter`) that match against enriched events (`sinsp_evt`). The engine processes rule files through a three-phase pipeline (reader, collector, compiler) and manages multiple rulesets that can be selectively enabled or disabled at runtime.

**Engine Version:** 0.62.0 (defined in [`falco_engine_version.h:22-24`](../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h))

```cpp
// falco_engine_version.h:22-24
#define FALCO_ENGINE_VERSION_MAJOR 0
#define FALCO_ENGINE_VERSION_MINOR 62
#define FALCO_ENGINE_VERSION_PATCH 0
```

The engine version identifies the set of supported fields, event types, and rule file format. A checksum derived from these is used for CI-based change detection ([`falco_engine_version.h:39`](../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h)).

## Architecture

### Rule File Structure

Rule files are YAML arrays. Each element is a YAML mapping with one of these top-level keys: `list`, `macro`, `rule`, `required_engine_version`, or `required_plugin_versions`.

```yaml
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

**Processing Order:** Items are processed sequentially within each file. Later definitions can override earlier ones. Appends require the original definition to exist first. Multiple rule files are loaded in the order specified by the Falco configuration.

**Stricter schema validation (since 0.44.0):** Unknown top-level keys within `- rule:`, `- macro:`, and `- list:` items are now flagged at load time ([PR #3805](https://github.com/falcosecurity/falco/pull/3805)). Misspelled or unsupported keys raise schema warnings instead of being silently ignored, reducing the risk of latent rule defects.

## Implementation Details

### Lists

Lists are named collections of values that can be referenced in rule and macro conditions. At compilation time, list references in conditions are expanded inline.

**Source:** [`rule_loader.h:403-416`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```cpp
struct list_info {
    context ctx;
    size_t index;        // Definition order index
    size_t visibility;   // Last override position (for ordering)
    std::string name;
    std::vector<std::string> items;
};
```

**Definition Syntax:**

```yaml
- list: my_binaries
  items: [cat, grep, awk, sed]

# Items can be integers or strings
- list: suspicious_ports
  items: [22, 23, 3389]

# Lists can reference other lists (resolved during compilation)
- list: all_shells
  items: [shell_binaries, powershell]
```

**Append Syntax:**

```yaml
# Modern syntax (recommended)
- list: shell_binaries
  items: [pwsh, fish]
  override:
    items: append

# Legacy syntax (deprecated, generates warning)
- list: shell_binaries
  items: [pwsh]
  append: true
```

**Validation:** List names should match the pattern `[^()\"'[:space:]=,]+` (barestring). Invalid names generate a `LOAD_INVALID_LIST_NAME` warning.

### Macros

Macros are named condition fragments for reuse across rules and other macros. A visibility ordering is enforced: macros can only reference other macros defined before them.

**Source:** [`rule_loader.h:421-435`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```cpp
struct macro_info {
    context ctx;
    context cond_ctx;    // Context of the condition expression
    size_t index;        // Definition order index
    size_t visibility;   // Last override position
    std::string name;
    std::string cond;    // Condition expression string
};
```

**Definition Syntax:**

```yaml
- macro: open_write
  condition: >
    evt.type in (open, openat, openat2) and
    evt.is_open_write=true

- macro: container
  condition: container.id != host
```

**Append Syntax:**

```yaml
# Append additional conditions (joined with space)
- macro: open_write
  condition: or evt.type = creat
  override:
    condition: append
```

**Validation:** Macro names should match `[a-zA-Z]+[a-zA-Z0-9_]*` (identifier pattern). Invalid names generate a `LOAD_INVALID_MACRO_NAME` warning.

### Rules

Rules define complete detection logic with conditions, outputs, and metadata.

**Source:** [`rule_loader.h:482-509`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```cpp
struct rule_info {
    context ctx;
    context cond_ctx;
    context output_ctx;
    size_t index;
    size_t visibility;
    bool unknown_source;
    std::string name;
    std::string cond;
    std::string source;
    std::string desc;
    std::string output;
    std::set<std::string> tags;
    std::vector<rule_exception_info> exceptions;
    falco_common::priority_type priority;
    bool capture;
    uint32_t capture_duration;
    bool enabled;
    bool warn_evttypes;
    bool skip_if_unknown_filter;
};
```

#### Rule Fields Reference

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `rule` | string | Yes | - | Rule name (unique identifier) |
| `desc` | string | Yes | - | Human-readable description |
| `condition` | string | Yes | - | Filter expression to match events |
| `output` | string | Yes | - | Alert message format string |
| `priority` | string | Yes | - | Severity level (see [Priority Levels](#priority-levels)) |
| `source` | string | No | `syscall` | Event source (e.g., `syscall`, plugin source) |
| `enabled` | boolean | No | `true` | Whether rule is active |
| `tags` | array | No | `[]` | Classification tags |
| `exceptions` | array | No | `[]` | Whitelisting definitions (see [Exceptions](#exceptions)) |
| `warn_evttypes` | boolean | No | `true` | Warn if rule matches too many event types |
| `skip-if-unknown-filter` | boolean | No | `false` | Skip rule silently if filter field is unknown |
| `capture` | boolean | No | `false` | Enable packet capture when triggered |
| `capture_duration` | integer | No | `0` | Capture duration in seconds |

**Source:** [`rule_loader_reader.cpp:880-898`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp) (field decoding)

#### Priority Levels

**Source:** [`falco_common.h:50-59`](../refs/falcosecurity/falco/userspace/engine/falco_common.h)

```cpp
enum priority_type {
    PRIORITY_EMERGENCY = 0,       // System unusable
    PRIORITY_ALERT = 1,           // Immediate action needed
    PRIORITY_CRITICAL = 2,        // Critical condition
    PRIORITY_ERROR = 3,           // Error condition
    PRIORITY_WARNING = 4,         // Warning condition
    PRIORITY_NOTICE = 5,          // Normal but significant
    PRIORITY_INFORMATIONAL = 6,   // Informational (also accepts: INFO)
    PRIORITY_DEBUG = 7            // Debug-level
};
```

Priority is specified in YAML as a case-insensitive string (e.g., `WARNING`, `Error`, `info`). Lower numeric values represent higher severity. The engine can filter rules by minimum priority via `set_min_priority()` ([`falco_engine.h:141`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)).

#### Rule Matching Strategy

**Source:** [`falco_common.h:66`](../refs/falcosecurity/falco/userspace/engine/falco_common.h)

```cpp
enum rule_matching { FIRST = 0, ALL = 1 };
```

| Strategy | Behavior | Performance |
|----------|----------|-------------|
| `FIRST` | Stop after first matching rule | Better (default) |
| `ALL` | Continue checking all rules | Enables multiple alerts per event |

The strategy is passed to `process_event()` at call time ([`falco_engine.h:259-262`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)).

### Condition Expressions

Conditions use the libsinsp filtering language. See [`filter-engine.md`](filter-engine.md) for the full syntax specification, and the [libs filtering digest](../digests/falcosecurity/libs/filtering.md) for complete operator reference.

**Macro expansion:** Macro references in conditions are replaced with the macro's parsed AST during compilation. Macros are resolved with visibility ordering -- a macro can only reference macros defined before it.

**List expansion:** List references within `in (...)`, `pmatch (...)`, or `intersects (...)` operators are expanded inline by substituting the list name with the comma-separated list items. Lists have no visibility ordering constraint.

**Example:**

```yaml
- list: read_syscalls
  items: [read, readv, pread64]

- rule: Read Sensitive File
  condition: evt.type in (read_syscalls) and fd.name = /etc/shadow
```

After list expansion, the condition becomes:
```
evt.type in (read, readv, pread64) and fd.name = /etc/shadow
```

#### Compound String Comparison Modifiers (since 0.44.0)

Falco 0.44 adds list modifiers `oneof`, `anyof`, and `allof` that can be combined with string comparison operators to compare a field against a list of values with explicit semantics ([PR #3878](https://github.com/falcosecurity/falco/pull/3878)).

**Source:** [`rule_loader_cmpop.h`](../refs/falcosecurity/falco/userspace/engine/rule_loader_cmpop.h)

| Modifier | Semantics |
|----------|-----------|
| `oneof` | Matches when **exactly one** value in the list satisfies the operator |
| `anyof` | Matches when **at least one** value in the list satisfies the operator (logical OR) |
| `allof` | Matches when **all** values in the list satisfy the operator (logical AND) |

**Supported base operators:** `=`, `!=`, `contains`, `icontains`, `bcontains`, `startswith`, `bstartswith`, `endswith`, `glob`, `iglob`, `regex` ([`rule_loader_cmpop.h:26-43`](../refs/falcosecurity/falco/userspace/engine/rule_loader_cmpop.h)).

Only string operators support the modifiers; combinations like `in oneof` or `>= oneof` are rejected at parse time ([`rule_loader_cmpop.h:45-48`](../refs/falcosecurity/falco/userspace/engine/rule_loader_cmpop.h)).

**Examples:**

```yaml
# At least one of the suffixes matches proc.exepath
- macro: shell_like_exe
  condition: proc.exepath endswith anyof ("/bash", "/sh", "/zsh")

# All listed substrings must appear in fd.name
- macro: dual_marker_path
  condition: fd.name contains allof ("tmp", "secret")

# Exactly one of the globs matches
- rule: Single Pattern Match
  condition: proc.cmdline glob oneof ("*.sh *", "python *", "ruby *")
  desc: detects single-pattern command lines
  output: "matched (cmdline=%proc.cmdline)"
  priority: NOTICE
```

### Output Format

Output strings define the alert message using field interpolation.

**Syntax:**

```yaml
output: "Alert message with field=%field.name and another=%other.field"
```

- `%field.name` -- replaced with the field value at alert time
- `%container.info` -- deprecated, no longer expanded (will be removed in Falco 1.0.0). The container plugin now provides `container.id` and `container.name` as suggested output fields automatically.

**Source:** [`rule_loader_compiler.cpp:37-43`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp) (container.info deprecation)

#### Extra Output Configuration

Extra output can be added programmatically via the engine API, enabling additional format strings or fields to be appended to rule outputs based on source, tags, or rule name.

**Source:** [`rule_loader.h:311-325`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```cpp
struct extra_output_format_conf {
    std::string m_format;              // Format string to append
    std::string m_source;              // Filter by source (empty = all)
    std::set<std::string> m_tags;      // Filter by tags
    std::string m_rule;                // Filter by rule name
};

struct extra_output_field_conf {
    std::string m_key;                 // Field key in output
    std::string m_format;              // Format string
    std::string m_source;
    std::set<std::string> m_tags;
    std::string m_rule;
    bool m_raw;                        // Raw value (no formatting)
};
```

The engine provides three methods for adding extra output ([`falco_engine.h:199-218`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)):
- `add_extra_output_format()` -- appends to the text output format string
- `add_extra_output_formatted_field()` -- adds a formatted field to structured output (JSON)
- `add_extra_output_raw_field()` -- adds a raw field to structured output

### Exceptions

Exceptions provide a structured way to whitelist specific conditions without modifying the rule's main condition. They are compiled into negated condition suffixes appended to the original condition.

**Source:** [`rule_loader.h:440-477`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```cpp
struct rule_exception_info {
    struct entry {
        bool is_list;
        std::string item;               // Single value
        std::vector<entry> items;        // List of values

        inline bool is_valid() const {
            return (is_list && !items.empty()) || (!is_list && !item.empty());
        }
    };

    context ctx;
    std::string name;                   // Exception identifier
    entry fields;                       // Field(s) to match
    entry comps;                        // Comparison operator(s)
    std::vector<entry> values;          // Values to match
};
```

#### Single-Field Exceptions

```yaml
exceptions:
  - name: allowed_processes
    fields: proc.name
    comps: in                            # Only: in, pmatch, intersects
    values: [nginx, apache, systemd]
```

Compiled to: `and not (proc.name in (nginx, apache, systemd))`

#### Multi-Field Exceptions

```yaml
exceptions:
  - name: known_writers
    fields: [proc.name, fd.directory]
    comps: [=, startswith]               # Any supported operator
    values:
      - [nginx, /etc/nginx]
      - [apache, /etc/apache2]
```

Compiled to:
```
and not ((proc.name = nginx and fd.directory startswith /etc/nginx) or
         (proc.name = apache and fd.directory startswith /etc/apache2))
```

#### Exception Compilation

**Source:** [`rule_loader_compiler.cpp:93-154`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)

The `build_rule_exception_infos()` function transforms exceptions into condition suffixes:

1. Original condition is wrapped in parentheses: `(original_condition)`
2. Each exception generates a negated clause appended with `and not`
3. **Single-field:** `and not (field comp (val1, val2, ...))`
4. **Multi-field:** `and not ((f1 c1 v1 and f2 c2 v2) or (f1 c1 v3 and f2 c2 v4))`

#### Valid Comparison Operators for Exceptions

**Source:** [`rule_loader_collector.cpp:63-101`](../refs/falcosecurity/falco/userspace/engine/rule_loader_collector.cpp)

| Exception Type | Allowed Operators | Default |
|----------------|-------------------|---------|
| Single field (`fields` is a string) | `in`, `pmatch`, `intersects` only | `in` |
| Multi-field (`fields` is a list) | Any supported operator (`=`, `!=`, `contains`, `startswith`, etc.) | `=` |

When `comps` is not specified, the collector assigns defaults: `in` for single-field, `=` for each field in multi-field.

#### Appending Exceptions

```yaml
# Original rule defines exception structure
- rule: Write Below Etc
  condition: open_write
  exceptions:
    - name: known_writers
      fields: [proc.name, fd.directory]

# Append values to existing exception in a separate file
- rule: Write Below Etc
  exceptions:
    - name: known_writers
      values:
        - [systemd, /etc/systemd]
  override:
    exceptions: append
```

### Overrides

The `override` key provides fine-grained control over how rules, macros, and lists are modified across files.

**Source:** [`rule_loader_reader.cpp:200-262`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp)

#### Override Operations

| Operation | Effect |
|-----------|--------|
| `append` | Add to existing value (concatenation for strings, union for collections) |
| `replace` | Completely replace the existing value |

#### Appendable and Replaceable Fields

| Type | Appendable Fields | Replaceable Fields |
|------|-------------------|--------------------|
| **Rules** | `condition`, `output`, `desc`, `tags`, `exceptions` | `condition`, `output`, `desc`, `priority`, `capture`, `capture_duration`, `tags`, `exceptions`, `enabled`, `warn_evttypes`, `skip-if-unknown-filter` |
| **Macros** | `condition` | *(none beyond append)* |
| **Lists** | `items` | *(none beyond append)* |

#### Override Syntax

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

#### Legacy Append Syntax (Deprecated)

```yaml
# Deprecated - generates LOAD_DEPRECATED_ITEM warning
- rule: existing_rule
  condition: and proc.name != systemd
  append: true
```

`append: true` cannot be mixed with the `override` key.

### Required Versions

#### Required Engine Version

Specifies the minimum Falco engine version needed to load the rule file.

```yaml
# Semver format
- required_engine_version: 0.26.0

# Legacy integer format (interpreted as minor version)
- required_engine_version: 26  # Becomes 0.26.0
```

**Implicit version conversion:** [`rule_loader_reader.h:52-56`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.h)

```cpp
static inline sinsp_version get_implicit_engine_version(uint32_t minor) {
    return sinsp_version(std::to_string(FALCO_ENGINE_VERSION_MAJOR) + "." +
                         std::to_string(minor) + "." +
                         std::to_string(FALCO_ENGINE_VERSION_PATCH));
}
```

#### Required Plugin Versions

Specifies plugin dependencies with optional alternatives.

**Source:** [`rule_loader.h:370-398`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h)

```cpp
struct plugin_version_info {
    struct requirement {
        std::string name;
        std::string version;
    };
    typedef std::vector<requirement> requirement_alternatives;

    context ctx;
    requirement_alternatives alternatives;
};
```

```yaml
- required_plugin_versions:
  - name: json
    version: 0.7.0
    alternatives:
      - name: json_alt
        version: 0.5.0
```

Alternatives allow multiple plugins to satisfy a single requirement. Any one of the listed alternatives (including the primary) is sufficient.

### Three-Phase Compilation Pipeline

The rule loader processes rules through three distinct, sequential phases. The top-level entry point is `compiler::compile()` ([`rule_loader_compiler.cpp:556-584`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)).

#### 1. Reader Phase

**Source:** [`rule_loader_reader.cpp`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp)

**Responsibility:** Parse raw YAML content into structured definition objects.

| Step | Description |
|------|-------------|
| YAML parsing | Parse YAML content via `yaml-cpp`, handling multi-document files |
| JSON schema validation | Validate structure against JSON schema, collect schema warnings |
| Item extraction | Iterate YAML array items, dispatch by top-level key (`list`, `macro`, `rule`, etc.) |
| Override handling | Decode `override` keys, validate append/replace operations against allowed fields |
| Exception reading | Parse exception structures (fields, comps, values) with type-aware decoding |
| Delegation | Pass extracted definitions to the collector via `define()`, `append()`, or `selective_replace()` |

**Key function:** `reader::read()` ([`rule_loader_reader.cpp:909-968`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp))

#### 2. Collector Phase

**Source:** [`rule_loader_collector.cpp`](../refs/falcosecurity/falco/userspace/engine/rule_loader_collector.cpp)

**Responsibility:** Gather all definitions, maintain ordering, and validate exception structures.

| Step | Description |
|------|-------------|
| Definition registration | `define()` -- Register new list/macro/rule definitions, track index and visibility |
| Append processing | `append()` -- Add to existing definitions, update visibility |
| Replace processing | `selective_replace()` -- Replace specific fields in existing definitions |
| Visibility tracking | Each definition/override increments a global counter (`m_cur_index`), establishing processing order |
| Exception validation | Validate exception field/comp counts, operator validity, field existence |
| Indexed collections | Maintain `indexed_vector` collections for lists, macros, and rules |

**Key functions:**
- `collector::define()` -- Register new definitions ([`rule_loader_collector.cpp:40-51`](../refs/falcosecurity/falco/userspace/engine/rule_loader_collector.cpp))
- `validate_exception_info()` -- Validate exception structures ([`rule_loader_collector.cpp:63-101`](../refs/falcosecurity/falco/userspace/engine/rule_loader_collector.cpp))

#### 3. Compiler Phase

**Source:** [`rule_loader_compiler.cpp`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)

**Responsibility:** Transform collected definitions into executable filters.

| Step | Function | Description |
|------|----------|-------------|
| List expansion | `compile_list_infos()` ([line 291](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)) | Resolve nested list references, flatten into final item vectors |
| Macro compilation | `compile_macros_infos()` ([line 320](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)) | Parse macro conditions, expand lists, resolve macro-in-macro references via `filter_macro_resolver` |
| Rule compilation | `compile_rule_infos()` ([line 405](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)) | Build exception suffixes, expand lists/macros, parse into AST, compile to `sinsp_filter`, validate output format |
| Unused detection | `compile()` ([line 556](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)) | After compilation, warn about unused macros and lists |

**Condition parsing depth limit:** 1000 (set via `parser::set_max_depth()` at [`rule_loader_compiler.cpp:278`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)).

#### Compilation Output

**Source:** [`rule_loader_compile_output.h:26-41`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compile_output.h)

```cpp
struct compile_output {
    indexed_vector<falco_list> lists;
    indexed_vector<falco_macro> macros;
    indexed_vector<falco_rule> rules;
};
```

The compiled rule structure ([`falco_rule.h:79-117`](../refs/falcosecurity/falco/userspace/engine/falco_rule.h)):

```cpp
struct falco_rule {
    std::size_t id;
    std::string source;
    std::string name;
    std::string description;
    std::string output;
    extra_output_field_t extra_output_fields;
    std::set<std::string> tags;
    std::set<std::string> exception_fields;
    falco_common::priority_type priority;
    bool capture;
    uint32_t capture_duration;
    std::shared_ptr<libsinsp::filter::ast::expr> condition;  // Parsed AST
    std::shared_ptr<sinsp_filter> filter;                     // Compiled filter
};
```

### Ruleset Management

Rulesets allow different sets of rules to be active simultaneously. Each ruleset is identified by a numeric ID.

**Source:** [`filter_ruleset.h`](../refs/falcosecurity/falco/userspace/engine/filter_ruleset.h)

#### Enabling/Disabling Rules

```cpp
// filter_ruleset.h:165,180 -- By name pattern
virtual void enable(const std::string &pattern, match_type match, uint16_t ruleset_id) = 0;
virtual void disable(const std::string &pattern, match_type match, uint16_t ruleset_id) = 0;

// filter_ruleset.h:193,206 -- By tags
virtual void enable_tags(const std::set<std::string> &tags, uint16_t ruleset_id) = 0;
virtual void disable_tags(const std::set<std::string> &tags, uint16_t ruleset_id) = 0;
```

#### Match Types

**Source:** [`filter_ruleset.h:43`](../refs/falcosecurity/falco/userspace/engine/filter_ruleset.h)

```cpp
enum class match_type { exact, substring, wildcard };
```

| Type | Behavior |
|------|----------|
| `exact` | Rule name must match the pattern exactly |
| `substring` | Pattern appears anywhere in the rule name. An empty pattern matches all rules |
| `wildcard` | Glob-style matching with `*`. A `"*"` pattern matches all rules. Wildcards can appear anywhere (e.g., `"*hello*world*"`) |

#### Ruleset IDs and Engine API

The default ruleset is named `"default"`. Multiple rulesets allow different rule configurations for different contexts (e.g., different tenants or operating modes).

**Source:** [`falco_engine.h:93-149`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)

```cpp
// Look up or create a ruleset ID by name
uint16_t find_ruleset_id(const std::string &ruleset);

// Enable/disable rules by substring match
void enable_rule(const std::string &substring, bool enabled,
                 const std::string &ruleset = s_default_ruleset);

// Enable/disable by exact name
void enable_rule_exact(const std::string &rule_name, bool enabled,
                       const std::string &ruleset = s_default_ruleset);

// Enable/disable by wildcard pattern
void enable_rule_wildcard(const std::string &rule_name, bool enabled,
                          const std::string &ruleset = s_default_ruleset);

// Enable/disable by tags
void enable_rule_by_tag(const std::set<std::string> &tags, bool enabled,
                        const std::string &ruleset = s_default_ruleset);
```

Note: Enabling/disabling applies to the rules, not the tags. If a rule R has tags `(a, b)` and you call `enable_tags({a})` then `disable_tags({b})`, R will be disabled despite having tag `a` ([`filter_ruleset.h:183-206`](../refs/falcosecurity/falco/userspace/engine/filter_ruleset.h)).

#### Event Processing

**Source:** [`falco_engine.h:259-262`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)

```cpp
std::unique_ptr<std::vector<rule_result>> process_event(
    std::size_t source_idx,
    sinsp_evt *ev,
    uint16_t ruleset_id,
    falco_common::rule_matching strategy
);
```

The `rule_result` struct returned on match ([`falco_engine.h:222-233`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)):

```cpp
struct rule_result {
    sinsp_evt *evt;
    std::string rule;
    std::string source;
    falco_common::priority_type priority_num;
    std::string format;
    std::set<std::string> exception_fields;
    std::set<std::string> tags;
    extra_output_field_t extra_output_fields;
    bool capture;
    uint64_t capture_duration_ns;
};
```

### Error and Warning Codes

**Source:** [`falco_load_result.h:29-66`](../refs/falcosecurity/falco/userspace/engine/falco_load_result.h)

#### Error Codes

| Code | Description |
|------|-------------|
| `LOAD_ERR_FILE_READ` | Cannot read the rules file |
| `LOAD_ERR_YAML_PARSE` | YAML syntax error during parsing |
| `LOAD_ERR_YAML_VALIDATE` | YAML structure is invalid (not a sequence of mappings, etc.) |
| `LOAD_ERR_COMPILE_CONDITION` | Condition expression compilation failed (syntax error, undefined macro, etc.) |
| `LOAD_ERR_COMPILE_OUTPUT` | Output format string is invalid (nonexistent field, etc.) |
| `LOAD_ERR_VALIDATE` | General validation error (mismatched fields/comps, invalid priority, etc.) |
| `LOAD_ERR_EXTENSION` | Extension-specific error |

#### Warning Codes

| Code | Description |
|------|-------------|
| `LOAD_UNKNOWN_SOURCE` | Rule references an unknown event source |
| `LOAD_UNSAFE_NA_CHECK` | Unsafe N/A check detected in condition |
| `LOAD_NO_EVTTYPE` | Rule matches too many event types (performance penalty) |
| `LOAD_UNKNOWN_FILTER` | Unknown filter field (rule skipped when `skip-if-unknown-filter` is `true`) |
| `LOAD_UNUSED_MACRO` | Macro is defined but not referenced by any rule or macro |
| `LOAD_UNUSED_LIST` | List is defined but not referenced by any rule or macro |
| `LOAD_UNKNOWN_ITEM` | Unknown top-level item in rules YAML |
| `LOAD_DEPRECATED_ITEM` | Deprecated syntax or field used (e.g., `append: true`, `%container.info`) |
| `LOAD_WARNING_EXTENSION` | Extension-specific warning |
| `LOAD_APPEND_NO_VALUES` | Append operation with no values to append |
| `LOAD_EXCEPTION_NAME_NOT_UNIQUE` | Exception name is duplicated within a rule |
| `LOAD_INVALID_MACRO_NAME` | Macro name does not match identifier pattern `[a-zA-Z]+[a-zA-Z0-9_]*` |
| `LOAD_INVALID_LIST_NAME` | List name does not match barestring pattern `[^()\"'[:space:]=,]+` |
| `LOAD_COMPILE_CONDITION` | Non-fatal condition compilation warning |

#### Deprecated Fields

**Source:** [`falco_load_result.h:78-86`](../refs/falcosecurity/falco/userspace/engine/falco_load_result.h)

| Code | Deprecated Field |
|------|-----------------|
| `DEPRECATED_FIELD_EVT_DIR` | `evt.dir` |
| `DEPRECATED_FIELD_EVT_LATENCY` | `evt.latency` |
| `DEPRECATED_FIELD_EVT_LATENCY_S` | `evt.latency.s` |
| `DEPRECATED_FIELD_EVT_LATENCY_NS` | `evt.latency.ns` |
| `DEPRECATED_FIELD_EVT_LATENCY_HUMAN` | `evt.latency.human` |
| `DEPRECATED_FIELD_EVT_WAIT_LATENCY` | `evt.wait.latency` |

## Non-Functional Requirements

### Performance: Event Type Indexing

For `syscall` source rules, the compiler extracts the set of `ppm_event_code` values that each rule's condition can match against. If a rule matches too many event types (empty set or >100 types), and `warn_evttypes` is `true`, a `LOAD_NO_EVTTYPE` warning is emitted because such rules carry a significant performance penalty -- every event must be evaluated against the rule's full condition.

**Source:** [`rule_loader_compiler.cpp:529-537`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp)

The `filter_ruleset` interface exposes methods for retrieving the enabled event codes and syscall codes for a given ruleset, enabling the engine to configure the kernel driver to only capture relevant event types:

```cpp
// filter_ruleset.h:143,150
virtual libsinsp::events::set<ppm_sc_code> enabled_sc_codes(uint16_t ruleset) = 0;
virtual libsinsp::events::set<ppm_event_code> enabled_event_codes(uint16_t ruleset) = 0;
```

### Extensibility

- **Plugin sources:** The engine supports multiple event sources via plugins. Each source gets its own filter factory, formatter factory, and ruleset. Sources are registered via `add_source()` ([`falco_engine.h:278-289`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)).
- **Custom reader/collector/compiler:** The engine allows replacing the rule reader, collector, and compiler with custom implementations via `set_rule_reader()`, `set_rule_collector()`, `set_rule_compiler()` ([`falco_engine.h:69-76`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)).
- **Custom ruleset factory:** Each source can use a custom `filter_ruleset_factory` for alternative rule indexing strategies ([`falco_engine.h:286-289`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h)).

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`filter-engine.md`](filter-engine.md) | Filter expression syntax, operators, and compilation |
| [`configuration.md`](configuration.md) | Falco configuration including rules file paths and rule matching settings |
| [`output-system.md`](output-system.md) | Alert formatting and delivery of matched rule results |
| [`architecture-overview.md`](architecture-overview.md) | End-to-end system architecture and event pipeline |

## Sources

| Topic | Source File |
|-------|-------------|
| Rule structures | [`rule_loader.h`](../refs/falcosecurity/falco/userspace/engine/rule_loader.h) |
| YAML parsing / Reader | [`rule_loader_reader.cpp`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.cpp) |
| Reader header | [`rule_loader_reader.h`](../refs/falcosecurity/falco/userspace/engine/rule_loader_reader.h) |
| Definition collection | [`rule_loader_collector.cpp`](../refs/falcosecurity/falco/userspace/engine/rule_loader_collector.cpp) |
| Compilation | [`rule_loader_compiler.cpp`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compiler.cpp) |
| Compile output | [`rule_loader_compile_output.h`](../refs/falcosecurity/falco/userspace/engine/rule_loader_compile_output.h) |
| Compiled rule types | [`falco_rule.h`](../refs/falcosecurity/falco/userspace/engine/falco_rule.h) |
| Engine interface | [`falco_engine.h`](../refs/falcosecurity/falco/userspace/engine/falco_engine.h) |
| Ruleset management | [`filter_ruleset.h`](../refs/falcosecurity/falco/userspace/engine/filter_ruleset.h) |
| Engine version | [`falco_engine_version.h`](../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h) |
| Common types | [`falco_common.h`](../refs/falcosecurity/falco/userspace/engine/falco_common.h) |
| Load results / error codes | [`falco_load_result.h`](../refs/falcosecurity/falco/userspace/engine/falco_load_result.h) |
| Rule language digest | [`digests/falcosecurity/falco/rule-language.md`](../digests/falcosecurity/falco/rule-language.md) |
| Filtering language digest | [`digests/falcosecurity/libs/filtering.md`](../digests/falcosecurity/libs/filtering.md) |
