# Rule Language Reference

Complete reference for Falco's rule YAML schema, filter expression language, exception system, and rule engine internals.

**Source:** [`specs/rule-engine.md`](../../../specs/rule-engine.md), [`specs/filter-engine.md`](../../../specs/filter-engine.md)

---

## Rule YAML Schema

Rules are defined in YAML files. Each file is a YAML array where each element is a mapping with one top-level key: `list`, `macro`, `rule`, `required_engine_version`, or `required_plugin_versions`.

```yaml
- rule: My Detection Rule
  desc: Human-readable description of what this rule detects
  condition: evt.type = execve and proc.name = suspicious_binary
  output: "Suspicious binary executed (user=%user.name command=%proc.cmdline container=%container.id)"
  priority: WARNING
  source: syscall           # Optional, default: syscall
  enabled: true             # Optional, default: true
  tags: [process, mitre_execution, T1059]  # Optional
  warn_evttypes: true       # Optional, default: true
  skip-if-unknown-filter: false  # Optional, default: false
```

### Rule Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `rule` | string | Yes | - | Unique rule name |
| `desc` | string | Yes | - | Human-readable description |
| `condition` | string | Yes | - | Filter expression to match events |
| `output` | string | Yes | - | Alert message template with `%field.name` interpolation |
| `priority` | string | Yes | - | Severity level (see below) |
| `source` | string | No | `syscall` | Event source |
| `enabled` | boolean | No | `true` | Whether rule is active |
| `tags` | array | No | `[]` | Classification tags |
| `exceptions` | array | No | `[]` | Structured whitelisting (see [Exception System](#exception-system)) |
| `warn_evttypes` | boolean | No | `true` | Warn if rule matches too many event types |
| `skip-if-unknown-filter` | boolean | No | `false` | Skip rule if filter field is unknown |
| `capture` | boolean | No | `false` | Enable packet capture when triggered |
| `capture_duration` | integer | No | `0` | Capture duration in seconds |

## Lists

Named collections of values referenced in conditions. Expanded inline at compilation time.

```yaml
- list: shell_binaries
  items: [bash, sh, zsh, csh, ksh, dash, fish]

# Lists can reference other lists
- list: scripting_binaries
  items: [shell_binaries, python, ruby, perl]

# Items can be integers
- list: ssh_ports
  items: [22, 2222]
```

**Append syntax (modern):**

```yaml
- list: shell_binaries
  items: [pwsh]
  override:
    items: append
```

## Macros

Named condition fragments for reuse across rules and other macros. Macros can only reference macros defined before them (visibility ordering).

```yaml
- macro: spawned_process
  condition: (evt.type in (execve, execveat))

- macro: container
  condition: container.id != host

- macro: open_write
  condition: >
    evt.type in (open, openat, openat2) and
    evt.is_open_write = true
```

**Append syntax (modern):**

```yaml
- macro: open_write
  condition: or evt.type = creat
  override:
    condition: append
```

## Priority Levels

| Priority | Numeric | Description |
|----------|---------|-------------|
| `EMERGENCY` | 0 | System unusable |
| `ALERT` | 1 | Immediate action needed |
| `CRITICAL` | 2 | Critical condition |
| `ERROR` | 3 | Error condition |
| `WARNING` | 4 | Warning condition |
| `NOTICE` | 5 | Normal but significant |
| `INFORMATIONAL` (or `INFO`) | 6 | Informational |
| `DEBUG` | 7 | Debug-level |

Lower numeric value = higher severity. The `priority` config key sets the minimum priority for alerts.

## Output Format Templates

Output strings use `%field.name` interpolation. At alert time, each `%field.name` is replaced with the field's value extracted from the event.

```yaml
output: >
  Suspicious process spawned
  (user=%user.name command=%proc.cmdline pid=%proc.pid
   parent=%proc.pname container=%container.id
   image=%container.image.repository)
```

## Override and Append Mechanics

The `override` key provides fine-grained control over how rules, macros, and lists are modified across files.

| Operation | Effect |
|-----------|--------|
| `append` | Add to existing value |
| `replace` | Completely replace existing value |

**Example -- disable an existing rule:**

```yaml
- rule: Terminal shell in container
  enabled: false
  override:
    enabled: replace
```

**Example -- append condition and replace priority:**

```yaml
- rule: Write Below Etc
  condition: and not proc.name = systemd-resolve
  priority: ERROR
  override:
    condition: append
    priority: replace
```

**Appendable fields:** `condition`, `output`, `desc`, `tags`, `exceptions`
**Replaceable fields:** All appendable fields plus `priority`, `enabled`, `warn_evttypes`, `skip-if-unknown-filter`, `capture`, `capture_duration`

## Required Versions

```yaml
# Minimum engine version needed to load this rules file
- required_engine_version: 0.26.0

# Plugin dependencies
- required_plugin_versions:
  - name: json
    version: 0.7.0
```

---

## Condition Language Reference

Conditions use the libsinsp filter language. The full grammar is defined in the parser.

**Source:** [`specs/filter-engine.md`](../../../specs/filter-engine.md)

### Filter Grammar

```
Expr        ::= OrExpr
OrExpr      ::= AndExpr ('or' AndExpr)*
AndExpr     ::= NotExpr ('and' NotExpr)*
NotExpr     ::= ('not')* (Check | '(' Expr ')')
Check       ::= Field Condition | FieldTransformer Condition | Identifier | '(' Expr ')'
Condition   ::= UnaryOp | NumOp Value | StrOp Value | ListOp ListValue
```

**Operator precedence:** `not` > `and` > `or`. Use parentheses to override.

```yaml
# Without parens: "A and (B or C)" due to precedence
condition: A and B or C

# With explicit grouping
condition: (A or B) and C
```

### Comparison Operators (19 total)

| Operator | Type | Description | Example |
|----------|------|-------------|---------|
| `=`, `==` | Str/Num | Equal | `proc.name = nginx` |
| `!=` | Str/Num | Not equal | `proc.name != sh` |
| `<` | Num | Less than | `evt.rawres < 0` |
| `<=` | Num | Less or equal | `fd.num <= 2` |
| `>` | Num | Greater than | `proc.pid > 1` |
| `>=` | Num | Greater or equal | `proc.cmdnargs >= 3` |
| `contains` | Str | Substring match | `proc.cmdline contains password` |
| `icontains` | Str | Case-insensitive contains | `fd.name icontains tmp` |
| `startswith` | Str | Prefix match | `proc.name startswith java` |
| `endswith` | Str | Suffix match | `fd.name endswith .log` |
| `glob` | Str | Glob pattern | `fd.name glob /etc/*.conf` |
| `iglob` | Str | Case-insensitive glob | `proc.name iglob Java*` |
| `regex` | Str | RE2 regular expression | `proc.cmdline regex .*secret.*` |
| `in` | List | Value in list | `proc.name in (cat, grep, ls)` |
| `pmatch` | List | Prefix match in list | `fd.name pmatch (/etc, /usr)` |
| `intersects` | List | List intersection | `proc.args intersects (a, b)` |
| `exists` | Unary | Field has value | `fd.name exists` |
| `bcontains` | Binary | Binary substring (hex) | `evt.rawarg.data bcontains 4142` |
| `bstartswith` | Binary | Binary prefix (hex) | `evt.rawarg.data bstartswith 7f454c46` |

### Field Transformers

Transformers modify field values before comparison. Can be chained.

| Transformer | Description | Example |
|-------------|-------------|---------|
| `tolower()` | Convert to lowercase | `proc.name.tolower() = nginx` |
| `toupper()` | Convert to uppercase | `proc.name.toupper() = NGINX` |
| `b64()` | Base64 decode | `evt.arg.data.b64() contains secret` |
| `basename()` | Extract path basename | `fd.name.basename() = config.yaml` |
| `len()` | Return string length | `proc.cmdline.len() > 1000` |

**Chaining:** `fd.name.basename().toupper() = CONFIG.YAML`

### Field Format

- **Simple:** `field.name` (e.g., `proc.name`)
- **With argument:** `field.name[arg]` (e.g., `proc.env[PATH]`, `proc.aname[2]`)
- **With transformer:** `field.name.transformer()` (e.g., `proc.name.tolower()`)

### Key Filtercheck Classes

| Prefix | Description | Typical Fields |
|--------|-------------|----------------|
| `evt.*` | Event metadata | `evt.type`, `evt.time`, `evt.args`, `evt.res`, `evt.rawres`, `evt.is_open_write` |
| `proc.*` | Process/thread | `proc.name`, `proc.pid`, `proc.cmdline`, `proc.exepath`, `proc.pname`, `proc.aname[n]` |
| `fd.*` | File descriptors | `fd.name`, `fd.directory`, `fd.type`, `fd.ip`, `fd.port`, `fd.l4proto` |
| `user.*` | User info | `user.uid`, `user.name`, `user.loginuid`, `user.shell` |
| `group.*` | Group info | `group.gid`, `group.name` |
| `thread.*` | Thread-specific | `thread.tid`, `thread.cap_effective`, `thread.cap_permitted` |
| `container.*` | Container metadata | `container.id`, `container.name`, `container.image.repository` (plugin) |
| `k8s.*` | Kubernetes metadata | `k8s.pod.name`, `k8s.ns.name` (plugin) |
| `fs.path.*` | Filesystem paths | `fs.path.name`, `fs.path.nameraw`, `fs.path.source`, `fs.path.target` |

> **Note:** `container.*` and `k8s.*` fields are provided by plugins (the `container` and `k8smeta` plugins respectively), not built-in filterchecks. They are available in rule conditions when the corresponding plugin is loaded.

### Most-Used Fields Quick Reference

| Field | Type | Description |
|-------|------|-------------|
| `evt.type` | charbuf | Syscall name (e.g., `open`, `execve`, `connect`) |
| `evt.dir` | charbuf | Event direction: `>` (enter) or `<` (exit). **Deprecated since 0.42 -- do not use in new rules.** |
| `evt.is_open_write` | bool | True for open events where path was opened for writing |
| `evt.is_open_read` | bool | True for open events where path was opened for reading |
| `evt.res` | charbuf | Return value as string (`SUCCESS` or error name) |
| `evt.rawres` | int64 | Raw return value as a number |
| `evt.failed` | bool | True for events that returned an error |
| `proc.name` | charbuf | Process name (truncated after 16 chars) |
| `proc.exepath` | charbuf | Full executable path, resolving symlinks |
| `proc.cmdline` | charbuf | Full command line (`proc.name + proc.args`) |
| `proc.pname` | charbuf | Parent process name |
| `proc.aname[n]` | charbuf | Ancestor process name at level n |
| `proc.pid` | int64 | Process ID |
| `proc.ppid` | int64 | Parent process ID |
| `proc.is_exe_writable` | bool | True if executable is writable by the spawning user |
| `proc.is_exe_upper_layer` | bool | True if executable is in upper layer of overlayfs |
| `fd.name` | charbuf | Full FD name/path or connection tuple |
| `fd.directory` | charbuf | Directory component (file FDs only) |
| `fd.type` | charbuf | FD type (`file`, `ipv4`, `ipv6`, `unix`, etc.) |
| `fd.l4proto` | charbuf | IP protocol: `tcp`, `udp`, `icmp`, `raw` |
| `user.uid` | uint32 | User ID |
| `user.name` | charbuf | Username |
| `container.id` | charbuf | Container ID (`host` for host processes) |
| `container.name` | charbuf | Container name |
| `container.image.repository` | charbuf | Container image repository |

---

## Exception System

> **DO NOT USE EXCEPTIONS BY DEFAULT.** The structured `exceptions:` rule field is not widely adopted by Falco users. Most official rules use condition-based tuning instead (macros, lists, negated conditions). Only use exceptions when the user explicitly requests them.

**Default tuning strategy:** Use macros, lists, and negated conditions as described in the False-Positive Reduction Patterns section of the main [SKILL.md](../SKILL.md).

Exceptions provide a structured way to whitelist specific conditions. They are compiled into negated condition suffixes appended to the original condition.

### Single-Field Exceptions

```yaml
exceptions:
  - name: allowed_processes
    fields: proc.name
    comps: in               # Only: in, pmatch, intersects
    values: [nginx, apache, systemd]
```

Compiled to: `and not (proc.name in (nginx, apache, systemd))`

### Multi-Field Exceptions

```yaml
exceptions:
  - name: known_writers
    fields: [proc.name, fd.directory]
    comps: [=, startswith]   # Any supported operator
    values:
      - [nginx, /etc/nginx]
      - [apache, /etc/apache2]
```

Compiled to: `and not ((proc.name = nginx and fd.directory startswith /etc/nginx) or (proc.name = apache and fd.directory startswith /etc/apache2))`

### Appending Exception Values

```yaml
# In a separate file, append values to an existing exception
- rule: Write Below Etc
  exceptions:
    - name: known_writers
      values:
        - [systemd, /etc/systemd]
  override:
    exceptions: append
```

---

## Rule Engine Internals (Optimization Guide)

**Source:** [`specs/rule-engine.md`](../../../specs/rule-engine.md)

### Event Type Indexing

For `syscall` source rules, the compiler extracts the set of event types that each rule's condition can match. This allows the engine to skip rule evaluation for irrelevant event types.

**Why `evt.type` matters for performance:** If a rule does not narrow down to specific event types (empty set or >100 types), every single event must be evaluated against the full condition. This creates a significant performance penalty.

### The `warn_evttypes` Warning

When `warn_evttypes` is `true` (default) and a rule matches too many event types, a `LOAD_NO_EVTTYPE` warning is emitted. This is a strong signal to rewrite the condition.

### How to Write Performant Conditions

1. **Start with `evt.type`**: Always begin conditions with a specific `evt.type` check or a macro that contains one
2. **Use `in` for multiple event types**: `evt.type in (open, openat, openat2)` is more efficient than three `or` clauses
3. **Narrow early**: Place the most selective checks first in the `and` chain
4. **Use macros**: Reusable macros that include `evt.type` checks propagate performance benefits

```yaml
# GOOD: Specific event types, narrow condition
- rule: Write to sensitive file
  condition: >
    evt.type in (open, openat, openat2) and
    evt.is_open_write = true and
    fd.name startswith /etc/passwd

# BAD: No evt.type restriction -- evaluates against every event
- rule: Any write to etc
  condition: fd.name startswith /etc
```

### Compilation Pipeline

1. **Reader phase**: Parses YAML, validates structure, decodes fields
2. **Collector phase**: Registers definitions, tracks ordering, validates exceptions
3. **Compiler phase**: Resolves lists/macros, parses conditions into AST, compiles to executable filters

### Macro Expansion and List Resolution

- **Macros**: References are replaced with the macro's parsed AST (before the current macro's definition)
- **Lists**: References within `in`, `pmatch`, or `intersects` operators are expanded inline by substituting the list name with comma-separated items

```yaml
- list: read_syscalls
  items: [read, readv, pread64]

- rule: Read Sensitive File
  condition: evt.type in (read_syscalls) and fd.name = /etc/shadow
  # After expansion: evt.type in (read, readv, pread64) and fd.name = /etc/shadow
```
