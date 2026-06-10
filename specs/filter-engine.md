# Filter Engine

> Filter expression language, AST, comparison operators, field transformers, filtercheck classes, and compilation pipeline.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/libs/userspace/libsinsp/filter/`](../refs/falcosecurity/libs/userspace/libsinsp/filter/)

## Overview

The filter engine is the core subsystem of libsinsp responsible for evaluating Boolean expressions against system events. It powers:

- **Falco rule conditions** -- every `condition:` field in a Falco rule is a filter expression
- **sysdig capture filters** -- runtime filtering of captured events
- **Plugin field extraction** -- extensible field extraction via the plugin API

The engine implements a complete pipeline: parsing a filter string into an AST, compiling the AST into an executable filter tree, and running the filter against events by extracting field values, applying transformers, and evaluating comparisons.

**Source:** [`filtering.md`](../digests/falcosecurity/libs/filtering.md)

## Architecture

### Filter Compilation Pipeline

```
Filter string
    |
    v
Parser (recursive descent)
    |
    v
AST (abstract syntax tree)
    |
    v
Compiler (AST visitor)
    |
    v
sinsp_filter (executable filter tree)
    |
    v
Run against sinsp_evt → bool
```

**Source:** [`filter.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter.h), [`filter/parser.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter/parser.h)

### Grammar

The filter language uses a context-free grammar parsed by a recursive descent parser. The formal EBNF grammar is defined in the parser header.

**Source:** [`filter/parser.h:28-87`](../refs/falcosecurity/libs/userspace/libsinsp/filter/parser.h)

```
Productions (EBNF Syntax):
    Expr                ::= OrExpr
    OrExpr              ::= AndExpr ('or' OrExprTail)*
    OrExprTail          ::= ' ' AndExpr
                            | '(' Expr ')'
    AndExpr             ::= NotExpr ('and' AndExprTail)*
    AndExprTail         ::= ' ' NotExpr
                            | '(' Expr ')'
    NotExpr             ::= ('not ')* NotExprTail
    NotExprTail         ::= 'not(' Expr ')'
                            | Check
    Check               ::= Field Condition
                            | FieldTransformer Condition
                            | Identifier
                            | '(' Expr ')'
    FieldTransformer       ::= FieldTransformerType FieldTransformerTail
    FieldTransformerTail   ::= FieldTransformerArg ')'
    FieldTransformerArg    ::= FieldTransformer
                            | Field
    FieldTransformerOrVal  ::= FieldTransformer
                            | FieldTransformerVal Field ')'
    Condition           ::= UnaryOperator
                            | NumOperator (NumValue | FieldTransformerOrVal)
                            | StrOperator (StrValue | FieldTransformerOrVal)
                            | ListOperator (ListValue | FieldTransformerOrVal)
    ListValue           ::= '(' (StrValue (',' StrValue)*)* ')'
                            | Identifier
    Field               ::= FieldName('[' FieldArg ']')?
    FieldArg            ::= QuotedStr | FieldArgBareStr
    NumValue            ::= HexNumber | Number
    StrValue            ::= QuotedStr | BareStr

Supported Check Operators (EBNF Syntax):
    UnaryOperator       ::= 'exists'
    NumOperator         ::= '<=' | '<' | '>=' | '>'
    StrOperator         ::= '==' | '=' | '!='
                            | 'bcontains ' | 'bstartswith '
                            | 'contains ' | 'endswith ' | 'glob '
                            | 'icontains ' | 'iglob '
                            | 'startswith ' | 'regex '
    ListOperator        ::= 'in' | 'intersects' | 'pmatch'
    FieldTransformerVal    ::= 'val('
    FieldTransformerType   ::= 'tolower(' | 'toupper(' | 'b64(' | 'basename(' | 'len('

Tokens (Regular Expressions):
    Identifier          ::= [a-zA-Z]+[a-zA-Z0-9_]*
    FieldName           ::= [a-zA-Z]+[a-zA-Z0-9_]*(\.[a-zA-Z]+[a-zA-Z0-9_]*)+
    FieldArgBareStr     ::= [^ \b\t\n\r\[\]"']+
    HexNumber           ::= 0[xX][0-9a-zA-Z]+
    Number              ::= [+\-]?[0-9]+[\.]?[0-9]*([eE][+\-][0-9]+)?
    QuotedStr           ::= "(?:\\"|.)*?"|'(?:\\'|.)*?'
    BareStr             ::= [^ \b\t\n\r\(\),="']+
```

### AST Node Types

The parser produces an Abstract Syntax Tree with these node types, all defined in the `libsinsp::filter::ast` namespace.

**Source:** [`filter/ast.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter/ast.h)

| Node Type | Purpose | Key Members |
|-----------|---------|-------------|
| `and_expr` | Conjunction of expressions | `children: vector<unique_ptr<expr>>` |
| `or_expr` | Disjunction of expressions | `children: vector<unique_ptr<expr>>` |
| `not_expr` | Negation of expression | `child: unique_ptr<expr>` |
| `binary_check_expr` | Field comparison with value | `left: unique_ptr<expr>`, `op: string`, `right: unique_ptr<expr>` |
| `unary_check_expr` | Unary field check (e.g., `exists`) | `left: unique_ptr<expr>`, `op: string` |
| `field_expr` | Field reference | `field: string`, `arg: string` |
| `field_transformer_expr` | Transformed field | `transformer: string`, `value: unique_ptr<expr>` |
| `value_expr` | Literal value | `value: string` |
| `list_expr` | List of values | `values: vector<string>` |
| `identifier_expr` | Named identifier (macro/list reference) | `identifier: string` |

All nodes inherit from the base `expr` class which provides:
- Position tracking via `pos_info` (index, line, column)
- Visitor pattern via `accept(expr_visitor*)` and `accept(const_expr_visitor*)`
- Deep equality via `is_equal(const expr*)`

```cpp
// Key struct definitions from filter/ast.h

struct binary_check_expr : expr {
    std::unique_ptr<expr> left;   // Left side (field or transformer)
    std::string op;                // Comparison operator string
    std::unique_ptr<expr> right;   // Right side (value or list)
};

struct field_expr : expr {
    std::string field;             // Full field name (e.g., "proc.name")
    std::string arg;               // Optional argument (e.g., index or key)
};

struct field_transformer_expr : expr {
    std::string transformer;       // Transformer name (e.g., "tolower")
    std::unique_ptr<expr> value;   // Inner expression (field or nested transformer)
};
```

#### AST Visitors

The AST supports the visitor pattern with three base visitor types:

| Visitor | Purpose |
|---------|---------|
| `expr_visitor` | Mutable AST traversal (pure virtual) |
| `const_expr_visitor` | Immutable AST traversal (pure virtual) |
| `base_expr_visitor` | Default no-op traversal with early-stop support |
| `string_visitor` | Converts AST back to filter string representation |

**Source:** [`filter/ast.h:85-199`](../refs/falcosecurity/libs/userspace/libsinsp/filter/ast.h)

## Implementation Details

### Comparison Operators

**Source:** [`filter_compare.h:31-52`](../refs/falcosecurity/libs/userspace/libsinsp/filter_compare.h)

The `cmpop` enum defines all comparison operators:

| Operator | Enum | Value | Description | Example |
|----------|------|-------|-------------|---------|
| `=` | `CO_EQ` | 1 | Equal | `proc.name = nginx` |
| `!=` | `CO_NE` | 2 | Not equal | `proc.name != sh` |
| `<` | `CO_LT` | 3 | Less than | `evt.rawres < 0` |
| `<=` | `CO_LE` | 4 | Less or equal | `fd.num <= 2` |
| `>` | `CO_GT` | 5 | Greater than | `proc.pid > 1` |
| `>=` | `CO_GE` | 6 | Greater or equal | `proc.cmdnargs >= 3` |
| `contains` | `CO_CONTAINS` | 7 | Substring match | `proc.cmdline contains password` |
| `in` | `CO_IN` | 8 | In list | `proc.name in (cat, grep, ls)` |
| `exists` | `CO_EXISTS` | 9 | Field has value (unary) | `fd.name exists` |
| `icontains` | `CO_ICONTAINS` | 10 | Case-insensitive contains | `fd.name icontains tmp` |
| `startswith` | `CO_STARTSWITH` | 11 | Prefix match | `proc.name startswith java` |
| `glob` | `CO_GLOB` | 12 | Glob pattern match | `fd.name glob /etc/*.conf` |
| `pmatch` | `CO_PMATCH` | 13 | Prefix match in list | `fd.name pmatch (/etc, /usr)` |
| `endswith` | `CO_ENDSWITH` | 14 | Suffix match | `fd.name endswith .log` |
| `intersects` | `CO_INTERSECTS` | 15 | List intersection | `proc.args intersects (a, b)` |
| `bcontains` | `CO_BCONTAINS` | 16 | Binary contains (hex) | `evt.rawarg.data bcontains 4142` |
| `bstartswith` | `CO_BSTARTSWITH` | 17 | Binary prefix (hex) | `evt.rawarg.data bstartswith 7f454c46` |
| `iglob` | `CO_IGLOB` | 18 | Case-insensitive glob | `proc.name iglob Java*` |
| `regex` | `CO_REGEX` | 19 | Regular expression (RE2) | `proc.cmdline regex .*secret.*` |

#### Comparison Function

```cpp
// From filter_compare.h
bool flt_compare(cmpop op,
                 ppm_param_type type,
                 const void* operand1,
                 const void* operand2,
                 uint32_t op1_len = 0,
                 uint32_t op2_len = 0);

// Validate operator/type compatibility
bool flt_is_comparable(cmpop op, ppm_param_type t, bool is_list, std::string& err);

// IP network comparison helpers
bool flt_compare_ipv4net(cmpop op, uint64_t operand1, const ipv4net* operand2);
bool flt_compare_ipv6net(cmpop op, const ipv6addr* operand1, const ipv6net* operand2);
```

**Source:** [`filter_compare.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter_compare.h)

### Field Transformers

Transformers modify field values before comparison. They are applied as a chain between field extraction and comparison.

**Source:** [`sinsp_filter_transformer.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filter_transformers/sinsp_filter_transformer.h)

| Transformer | Enum | Value | Description | Example |
|-------------|------|-------|-------------|---------|
| `toupper(...)` | `FTR_TOUPPER` | 0 | Converts to uppercase | `toupper(proc.name) = NGINX` |
| `tolower(...)` | `FTR_TOLOWER` | 1 | Converts to lowercase | `tolower(proc.name) = nginx` |
| `b64(...)` | `FTR_BASE64` | 2 | Base64 decode | `b64(evt.arg.data) contains secret` |
| `val(...)` | `FTR_STORAGE` | 3 | Value storage (internal only) | Used for RHS field references |
| `basename(...)` | `FTR_BASENAME` | 4 | Extracts path basename | `basename(fd.name) = config.yaml` |
| `len(...)` | `FTR_LEN` | 5 | Returns string length | `len(proc.cmdline) > 1000` |

#### Transformer Chaining

Transformers can be chained by nesting function calls (outermost applied last):

```
basename(tolower(proc.name)) = nginx
toupper(basename(fd.name)) = CONFIG.YAML
```

#### Transformer Base Class

```cpp
// From sinsp_filter_transformer.h
class sinsp_filter_transformer {
public:
    virtual bool transform_type(ppm_param_type& t, uint32_t& flags) const = 0;
    virtual bool transform_values(std::vector<extract_value_t>& vals,
                                  ppm_param_type& t,
                                  uint32_t& flags) = 0;
};
```

**Note:** Fields with the `EPF_NO_TRANSFORMER` flag do not support transformers.

### Filtercheck Classes

Filterchecks are classes that extract and compare field values from events. Each class manages a group of related fields with a common prefix.

#### Default Filtercheck Registration

The default set of filterchecks is registered by `sinsp_filter_check_list`:

**Source:** [`filter_check_list.cpp:89-102`](../refs/falcosecurity/libs/userspace/libsinsp/filter_check_list.cpp)

| # | Class | Field Prefix | Description | Source |
|---|-------|-------------|-------------|--------|
| 1 | `sinsp_filter_check_gen_event` | `evt.*` | Generic event fields (all event types) | [`sinsp_filtercheck_gen_event.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_gen_event.cpp) |
| 2 | `sinsp_filter_check_event` | `evt.*`, `syscall.*` | Syscall-specific event fields | [`sinsp_filtercheck_event.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_event.cpp) |
| 3 | `sinsp_filter_check_thread` | `proc.*`, `thread.*` | Thread/process fields | [`sinsp_filtercheck_thread.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_thread.cpp) |
| 4 | `sinsp_filter_check_user` | `user.*` | User fields | [`sinsp_filtercheck_user.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_user.cpp) |
| 5 | `sinsp_filter_check_group` | `group.*` | Group fields | [`sinsp_filtercheck_group.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_group.cpp) |
| 6 | `sinsp_filter_check_fd` | `fd.*` | File descriptor fields | [`sinsp_filtercheck_fd.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fd.cpp) |
| 7 | `sinsp_filter_check_fspath` | `fs.path.*` | Filesystem path fields | [`sinsp_filtercheck_fspath.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fspath.cpp) |
| 8 | `sinsp_filter_check_utils` | `util.*` | Utility fields | [`sinsp_filtercheck_utils.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_utils.cpp) |
| 9 | `sinsp_filter_check_fdlist` | `fdlist.*` | Poll event FD list fields | [`sinsp_filtercheck_fdlist.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fdlist.cpp) |

> **Note:** Container fields (`container.*`) and Kubernetes fields (`k8s.*`) are **not** built-in libsinsp filterchecks. In Falco 0.44, they are provided by plugins (specifically the `container` and `k8smeta` plugins). See [Plugin Fields](#plugin-fields) below.

#### Generic Event Fields (`evt.*` -- all event types)

**Class:** `sinsp_filter_check_gen_event` | **Source:** [`sinsp_filtercheck_gen_event.cpp:47-161`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_gen_event.cpp)

These fields apply to all event types, including plugin-sourced events.

| Field | Type | Description |
|-------|------|-------------|
| `evt.num` | uint64 | Event number |
| `evt.time` | charbuf | Event timestamp as a time string including nanoseconds |
| `evt.time.s` | charbuf | Event timestamp as a time string with no nanoseconds |
| `evt.time.iso8601` | charbuf | Event timestamp in ISO 8601 format, including nanoseconds and time zone offset (UTC) |
| `evt.datetime` | charbuf | Event timestamp as a time string that includes the date |
| `evt.datetime.s` | charbuf | Event timestamp as a datetime string with no nanoseconds |
| `evt.rawtime` | abstime | Absolute event timestamp (nanoseconds from epoch) |
| `evt.rawtime.s` | abstime | Integer part of the event timestamp (seconds since epoch) |
| `evt.rawtime.ns` | abstime | Fractional part of the absolute event timestamp |
| `evt.reltime` | reltime | Nanoseconds from the beginning of the capture |
| `evt.reltime.s` | reltime | Seconds from the beginning of the capture |
| `evt.reltime.ns` | reltime | Fractional part (ns) of the time from the beginning of the capture |
| `evt.pluginname` | charbuf | Name of the plugin that generated the event (if plugin-sourced) |
| `evt.plugininfo` | charbuf | Summary of the event formatted by the plugin (if plugin-sourced) |
| `evt.source` | charbuf | Name of the source that produced the event |
| `evt.is_async` | bool | `true` for asynchronous events |
| `evt.asynctype` | charbuf | If asynchronous, the type of the event (e.g., `container`) |
| `evt.hostname` | charbuf | Hostname of the underlying host (customizable via `FALCO_HOSTNAME` environment variable) |

#### Syscall Event Fields (`evt.*`, `syscall.*`)

**Class:** `sinsp_filter_check_event` | **Source:** [`sinsp_filtercheck_event.cpp:60-426`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_event.cpp)

These fields apply only to syscall events.

| Field | Type | Flags | Description |
|-------|------|-------|-------------|
| `evt.latency` | reltime | deprecated | Delta between exit and enter event (ns) |
| `evt.latency.s` | reltime | deprecated | Integer part of event latency delta |
| `evt.latency.ns` | reltime | deprecated | Fractional part of event latency delta |
| `evt.latency.quantized` | uint64 | table_only, deprecated | 10-base log of latency delta |
| `evt.latency.human` | charbuf | deprecated | Human-readable latency (e.g., `10.3ms`) |
| `evt.deltatime` | reltime | | Delta between this event and the previous event (ns) |
| `evt.deltatime.s` | reltime | | Integer part of delta from previous event |
| `evt.deltatime.ns` | reltime | | Fractional part of delta from previous event |
| `evt.outputtime` | charbuf | print_only | Output time (depends on `-t` param) |
| `evt.dir` | charbuf | deprecated | Event direction: `>` (enter) or `<` (exit) |
| `evt.type` | charbuf | | Name of the event (e.g., `open`) |
| `evt.type.is` | uint32 | arg_required | Returns 1 if event matches specified type |
| `syscall.type` | charbuf | | Syscall name; unset for non-syscall events |
| `evt.category` | charbuf | | Event category (`file`, `net`, `memory`, etc.) |
| `evt.cpu` | int16 | | CPU number where the event occurred |
| `evt.args` | charbuf | | All event arguments as a single string |
| `evt.arg` | charbuf | arg_required | Specific argument by name or index (e.g., `evt.arg.fd`, `evt.arg[0]`) |
| `evt.rawarg` | dynamic | arg_required, no_rhs, no_transformer | Raw argument data by name (e.g., `evt.rawarg.fd`) |
| `evt.info` | charbuf | | Same as `evt.args` |
| `evt.buffer` | bytebuf | | Binary data buffer for I/O events |
| `evt.buflen` | uint64 | | Length of the binary data buffer |
| `evt.res` | charbuf | | Return value as string (`SUCCESS` or error code like `ENOENT`) |
| `evt.rawres` | int64 | | Raw return value as a number |
| `evt.failed` | bool | | `true` for events that returned an error status |
| `evt.is_io` | bool | | `true` for events that read or write to FDs |
| `evt.is_io_read` | bool | | `true` for events that read from FDs |
| `evt.is_io_write` | bool | | `true` for events that write to FDs |
| `evt.io_dir` | charbuf | | `r` for read, `w` for write |
| `evt.is_wait` | bool | | `true` for wait events (sleep, select, poll) |
| `evt.wait_latency` | reltime | deprecated | Wait latency in nanoseconds |
| `evt.is_syslog` | bool | | `true` for writes to `/dev/log` |
| `evt.count` | uint32 | | Always returns 1 |
| `evt.count.error` | uint32 | | Returns 1 for events that returned with an error |
| `evt.count.error.file` | uint32 | | Returns 1 for file I/O error events |
| `evt.count.error.net` | uint32 | | Returns 1 for network I/O error events |
| `evt.count.error.memory` | uint32 | | Returns 1 for memory allocation error events |
| `evt.count.error.other` | uint32 | | Returns 1 for other error events |
| `evt.count.exit` | uint32 | | Returns 1 for exit events |
| `evt.count.procinfo` | uint32 | table_only | Returns 1 for procinfo events from main threads |
| `evt.count.threadinfo` | uint32 | table_only | Returns 1 for procinfo events |
| `evt.around` | uint64 | filter_only, arg_required, no_rhs, no_transformer | Matches events around a timestamp. Syntax: `evt.around[T]=D` |
| `evt.abspath` | charbuf | arg_required | Absolute path from dirfd and name (use `.src`/`.dst` variants) |
| `evt.buflen.in` | uint64 | table_only | Buffer length for input I/O events |
| `evt.buflen.out` | uint64 | table_only | Buffer length for output I/O events |
| `evt.buflen.file` | uint64 | table_only | Buffer length for file I/O events |
| `evt.buflen.file.in` | uint64 | table_only | Buffer length for input file I/O events |
| `evt.buflen.file.out` | uint64 | table_only | Buffer length for output file I/O events |
| `evt.buflen.net` | uint64 | table_only | Buffer length for network I/O events |
| `evt.buflen.net.in` | uint64 | table_only | Buffer length for input network I/O events |
| `evt.buflen.net.out` | uint64 | table_only | Buffer length for output network I/O events |
| `evt.is_open_read` | bool | | `true` for open events where path was opened for reading |
| `evt.is_open_write` | bool | | `true` for open events where path was opened for writing |
| `evt.is_open_exec` | bool | | `true` for open/creat events where file is created with execute permissions |
| `evt.is_open_create` | bool | | `true` for open events where a file is created |
| `evt.infra.docker.name` | charbuf | table_only | Docker infrastructure event name |
| `evt.infra.docker.container.id` | charbuf | table_only | Docker infrastructure container ID |
| `evt.infra.docker.container.name` | charbuf | table_only | Docker infrastructure container name |
| `evt.infra.docker.container.image` | charbuf | table_only | Docker infrastructure container image |

#### Thread/Process Fields (`proc.*`, `thread.*`)

**Class:** `sinsp_filter_check_thread` | **Source:** [`sinsp_filtercheck_thread.cpp:49-727`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_thread.cpp)

| Field | Type | Flags | Description |
|-------|------|-------|-------------|
| `proc.exe` | charbuf | | First command-line argument (argv[0]), truncated after 4096 bytes |
| `proc.pexe` | charbuf | | Parent process argv[0] |
| `proc.aexe` | charbuf | arg_allowed, no_rhs, no_transformer | Ancestor argv[0]; `proc.aexe[n]` for level n, filterless matches any ancestor |
| `proc.exepath` | charbuf | | Full executable path, resolving symlinks |
| `proc.pexepath` | charbuf | | Parent full executable path |
| `proc.aexepath` | charbuf | arg_allowed, no_rhs, no_transformer | Ancestor executable path; `proc.aexepath[n]` for level n |
| `proc.name` | charbuf | | Process name (truncated after 16 chars, from `task->comm`) |
| `proc.pname` | charbuf | | Parent process name |
| `proc.aname` | charbuf | arg_allowed, no_rhs, no_transformer | Ancestor process name; `proc.aname[n]` for level n |
| `proc.args` | charbuf | arg_allowed | Command-line arguments excluding argv[0]; `proc.args[n]` for specific arg |
| `proc.aargs` | charbuf | arg_allowed | Ancestor command-line arguments; `proc.aargs[n]` for level n |
| `proc.cmdline` | charbuf | | `proc.name + proc.args` (truncated after 4096 bytes) |
| `proc.pcmdline` | charbuf | | Parent full command line |
| `proc.acmdline` | charbuf | arg_allowed, no_rhs, no_transformer | Ancestor full command line; `proc.acmdline[n]` for level n |
| `proc.cmdnargs` | uint64 | | Number of command-line arguments |
| `proc.cmdlenargs` | uint64 | | Total character count of command-line arguments |
| `proc.exeline` | charbuf | | Full command line with exe as first argument (`proc.exe + proc.args`) |
| `proc.env` | charbuf | arg_allowed | Environment variables; `proc.env[NAME]` for specific variable |
| `proc.aenv` | charbuf | arg_allowed, no_rhs, no_transformer | [EXPERIMENTAL] Ancestor environment; `proc.aenv[n]` or `proc.aenv[NAME]` |
| `proc.cwd` | charbuf | | Current working directory |
| `proc.loginshellid` | int64 | | PID of the oldest shell ancestor (for session identification) |
| `proc.tty` | uint32 | | Controlling terminal number (0 if no terminal) |
| `proc.pid` | int64 | | Process ID |
| `proc.ppid` | int64 | | Parent process ID |
| `proc.apid` | int64 | arg_allowed, no_rhs, no_transformer | Ancestor PID; `proc.apid[n]` for level n |
| `proc.vpid` | int64 | | Virtual PID (as seen from container PID namespace) |
| `proc.pvpid` | int64 | | Parent virtual PID |
| `proc.sid` | int64 | | Session ID |
| `proc.sname` | charbuf | | Session leader process name |
| `proc.sid.exe` | charbuf | | Session leader argv[0] |
| `proc.sid.exepath` | charbuf | | Session leader full executable path |
| `proc.vpgid` | int64 | | Virtual process group ID |
| `proc.vpgid.name` | charbuf | | Virtual process group leader name |
| `proc.vpgid.exe` | charbuf | | Virtual process group leader argv[0] |
| `proc.vpgid.exepath` | charbuf | | Virtual process group leader executable path |
| `proc.pgid` | int64 | | Process group ID (host PID namespace) |
| `proc.pgid.name` | charbuf | | Process group leader name |
| `proc.pgid.exe` | charbuf | | Process group leader argv[0] |
| `proc.pgid.exepath` | charbuf | | Process group leader executable path |
| `proc.duration` | reltime | | Nanoseconds since the process started |
| `proc.ppid.duration` | reltime | | Nanoseconds since the parent process started |
| `proc.pid.ts` | reltime | | Process start epoch timestamp in nanoseconds |
| `proc.ppid.ts` | reltime | | Parent process start epoch timestamp in nanoseconds |
| `proc.is_exe_writable` | bool | | `true` if executable is writable by the spawning user |
| `proc.is_exe_upper_layer` | bool | | `true` if executable is in upper layer of overlayfs |
| `proc.is_exe_lower_layer` | bool | | `true` if executable is in lower layer of overlayfs |
| `proc.is_exe_from_memfd` | bool | | `true` if executable is from memfd (in-memory, no disk file) |
| `proc.is_sid_leader` | bool | | `true` if `proc.sid == proc.vpid` |
| `proc.is_vpgid_leader` | bool | | `true` if `proc.vpgid == proc.vpid` |
| `proc.is_pgid_leader` | bool | | `true` if `proc.pgid == proc.pid` |
| `proc.exe_ino` | int64 | | Inode number of executable file on disk |
| `proc.exe_ino.ctime` | abstime | | Last status change time (ctime) of executable file |
| `proc.exe_ino.mtime` | abstime | | Last modification time (mtime) of executable file |
| `proc.exe_ino.ctime_duration_proc_start` | abstime | | Nanoseconds between exe ctime and process clone timestamp |
| `proc.exe_ino.ctime_duration_pidns_start` | abstime | | Nanoseconds between PID namespace start and exe ctime |
| `proc.pidns_init_start_ts` | uint64 | | PID namespace start epoch timestamp in nanoseconds |
| `thread.cap_permitted` | charbuf | | Permitted capabilities set |
| `thread.cap_inheritable` | charbuf | | Inheritable capabilities set |
| `thread.cap_effective` | charbuf | | Effective capabilities set |
| `proc.fdopencount` | uint64 | | Number of open FDs for the process |
| `proc.fdlimit` | int64 | | Maximum number of FDs the process can open |
| `proc.fdusage` | double | | Ratio between open FDs and maximum available FDs |
| `proc.vmsize` | uint64 | | Total virtual memory (kb) |
| `proc.vmrss` | uint64 | | Resident non-swapped memory (kb) |
| `proc.vmswap` | uint64 | | Swapped memory (kb) |
| `thread.pfmajor` | uint64 | | Number of major page faults since thread start |
| `thread.pfminor` | uint64 | | Number of minor page faults since thread start |
| `thread.tid` | int64 | | Thread ID |
| `thread.ismain` | bool | | `true` if the thread is the main one in the process |
| `thread.vtid` | int64 | | Virtual thread ID (container PID namespace) |
| `thread.nametid` | charbuf | table_only | Process name + thread ID as a specific identifier |
| `thread.exectime` | reltime | | CPU time of last scheduled thread (ns), switch events only |
| `thread.totexectime` | reltime | | Total CPU time since capture start (ns), switch events only |
| `thread.cgroups` | charbuf | | All cgroups the thread belongs to |
| `thread.cgroup` | charbuf | arg_required | Cgroup for a specific subsystem (e.g., `thread.cgroup.cpuacct`) |
| `proc.nthreads` | uint64 | | Number of alive threads including leader |
| `proc.nchilds` | uint64 | | Number of alive non-leader threads |
| `thread.cpu` | double | | CPU consumed by the thread in the last second |
| `thread.cpu.user` | double | | User CPU consumed in the last second |
| `thread.cpu.system` | double | | System CPU consumed in the last second |
| `thread.vmsize` | uint64 | | Total virtual memory for main thread (kb), zero for others |
| `thread.vmrss` | uint64 | | Resident memory for main thread (kb), zero for others |
| `thread.vmsize.b` | uint64 | table_only | Total virtual memory for main thread (bytes) |
| `thread.vmrss.b` | uint64 | table_only | Resident memory for main thread (bytes) |
| `proc.stdin.type` | charbuf | | Type of FD 0 (stdin) |
| `proc.stdout.type` | charbuf | | Type of FD 1 (stdout) |
| `proc.stderr.type` | charbuf | | Type of FD 2 (stderr) |
| `proc.stdin.name` | charbuf | | Name of FD 0 (stdin) |
| `proc.stdout.name` | charbuf | | Name of FD 1 (stdout) |
| `proc.stderr.name` | charbuf | | Name of FD 2 (stderr) |

#### File Descriptor Fields (`fd.*`)

**Class:** `sinsp_filter_check_fd` | **Source:** [`sinsp_filtercheck_fd.cpp:53-315`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fd.cpp)

| Field | Type | Flags | Description |
|-------|------|-------|-------------|
| `fd.num` | int64 | | File descriptor number |
| `fd.type` | charbuf | | FD type (`file`, `directory`, `ipv4`, `ipv6`, `unix`, `pipe`, `event`, `signalfd`, `eventpoll`, `inotify`, `memfd`) |
| `fd.typechar` | charbuf | | Single-character FD type (`f`, `4`, `6`, `u`, `p`, `e`, `s`, `l`, `i`, `b`, `r`, `m`, `o`) |
| `fd.name` | charbuf | | Full FD name/path (file path or connection tuple for sockets) |
| `fd.directory` | charbuf | | Directory component (file FDs only) |
| `fd.filename` | charbuf | | Filename component without path (file FDs only) |
| `fd.ip` | ipaddr | filter_only, no_rhs, no_transformer | Matches client or server IP address |
| `fd.cip` | ipaddr | | Client IP address |
| `fd.sip` | ipaddr | | Server IP address |
| `fd.lip` | ipaddr | | Local IP address |
| `fd.rip` | ipaddr | | Remote IP address |
| `fd.port` | port | filter_only, no_rhs, no_transformer | Matches client or server port |
| `fd.cport` | port | | Client port (TCP/UDP) |
| `fd.sport` | port | | Server port (TCP/UDP) |
| `fd.lport` | port | | Local port (TCP/UDP) |
| `fd.rport` | port | | Remote port (TCP/UDP) |
| `fd.l4proto` | charbuf | | IP protocol: `tcp`, `udp`, `icmp`, or `raw` |
| `fd.sockfamily` | charbuf | | Socket family: `ip` or `unix` |
| `fd.is_server` | bool | | `true` if process is server endpoint in connection |
| `fd.uid` | charbuf | | Unique FD identifier (FD number + thread ID) |
| `fd.containername` | charbuf | | Container ID + FD name |
| `fd.containerdirectory` | charbuf | | Container ID + directory name |
| `fd.proto` | port | filter_only, no_rhs, no_transformer | Matches client or server protocol |
| `fd.cproto` | charbuf | | Client protocol (TCP/UDP) |
| `fd.sproto` | charbuf | | Server protocol (TCP/UDP) |
| `fd.lproto` | charbuf | | Local protocol (TCP/UDP) |
| `fd.rproto` | charbuf | | Remote protocol (TCP/UDP) |
| `fd.net` | ipnet | filter_only, no_rhs, no_transformer | Matches client or server IP network |
| `fd.cnet` | ipnet | filter_only, no_rhs, no_transformer | Client IP network |
| `fd.snet` | ipnet | filter_only, no_rhs, no_transformer | Server IP network |
| `fd.lnet` | ipnet | filter_only, no_rhs, no_transformer | Local IP network |
| `fd.rnet` | ipnet | filter_only, no_rhs, no_transformer | Remote IP network |
| `fd.connected` | bool | | `true` if TCP/UDP socket is connected |
| `fd.name_changed` | bool | | `true` when an event changes the FD name |
| `fd.cip.name` | charbuf | no_rhs, no_transformer | Domain name for client IP |
| `fd.sip.name` | charbuf | no_rhs, no_transformer | Domain name for server IP |
| `fd.lip.name` | charbuf | no_rhs, no_transformer | Domain name for local IP |
| `fd.rip.name` | charbuf | no_rhs, no_transformer | Domain name for remote IP |
| `fd.dev` | int32 | | Device number (major/minor) of referenced file |
| `fd.dev.major` | int32 | | Major device number |
| `fd.dev.minor` | int32 | | Minor device number |
| `fd.ino` | int64 | | Inode number of referenced file |
| `fd.nameraw` | charbuf | | Raw FD name without path resolution or sanitization |
| `fd.types` | charbuf | is_list, arg_allowed, no_rhs | List of FD types in use; `fd.types[n]` for specific FD |
| `fd.is_upper_layer` | bool | | `true` if file is in upper layer of overlayfs |
| `fd.is_lower_layer` | bool | | `true` if file is in lower layer of overlayfs |

#### User Fields (`user.*`)

**Class:** `sinsp_filter_check_user` | **Source:** [`sinsp_filtercheck_user.cpp:37-61`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_user.cpp)

| Field | Type | Description |
|-------|------|-------------|
| `user.uid` | uint32 | User ID |
| `user.name` | charbuf | Username |
| `user.homedir` | charbuf | Home directory |
| `user.shell` | charbuf | User's login shell |
| `user.loginuid` | int64 | Audit user ID (auid); returns -1 for invalid UID (UINT32_MAX) |
| `user.loginname` | charbuf | Audit username (auid) |

#### Group Fields (`group.*`)

**Class:** `sinsp_filter_check_group` | **Source:** [`sinsp_filtercheck_group.cpp:37-40`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_group.cpp)

| Field | Type | Description |
|-------|------|-------------|
| `group.gid` | uint32 | Group ID |
| `group.name` | charbuf | Group name |

#### Filesystem Path Fields (`fs.path.*`)

**Class:** `sinsp_filter_check_fspath` | **Source:** [`sinsp_filtercheck_fspath.cpp:34-83`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fspath.cpp)

These fields apply to any syscall that operates on filesystem paths (including syscalls like `unlink`, `rename` that don't use file descriptors).

| Field | Type | Description |
|-------|------|-------------|
| `fs.path.name` | charbuf | Fully resolved path the syscall is operating on (thread cwd prepended if needed) |
| `fs.path.nameraw` | charbuf | Raw path as provided to the syscall (may not be fully resolved) |
| `fs.path.source` | charbuf | Source path for dual-path syscalls (`mv`, `cp`, etc.), fully resolved |
| `fs.path.sourceraw` | charbuf | Raw source path for dual-path syscalls |
| `fs.path.target` | charbuf | Target path for dual-path syscalls, fully resolved |
| `fs.path.targetraw` | charbuf | Raw target path for dual-path syscalls |

#### Poll Event FD List Fields (`fdlist.*`)

**Class:** `sinsp_filter_check_fdlist` | **Source:** [`sinsp_filtercheck_fdlist.cpp:31-74`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fdlist.cpp)

These fields are available for `poll`/`ppoll` events.

| Field | Type | Description |
|-------|------|-------------|
| `fdlist.nums` | charbuf | Comma-separated list of FD numbers in the `fds` argument |
| `fdlist.names` | charbuf | Comma-separated list of FD names in the `fds` argument |
| `fdlist.cips` | charbuf | Comma-separated list of client IP addresses in the `fds` argument |
| `fdlist.sips` | charbuf | Comma-separated list of server IP addresses in the `fds` argument |
| `fdlist.cports` | charbuf | Comma-separated list of client TCP/UDP ports in the `fds` argument |
| `fdlist.sports` | charbuf | Comma-separated list of server TCP/UDP ports in the `fds` argument |

#### Utility Fields (`util.*`)

**Class:** `sinsp_filter_check_utils` | **Source:** [`sinsp_filtercheck_utils.cpp:31-33`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_utils.cpp)

| Field | Type | Description |
|-------|------|-------------|
| `util.cnt` | uint64 | Incremental counter |

### Container Fields (`container.*`) and Kubernetes Fields (`k8s.*`)

In Falco 0.44, container and Kubernetes metadata fields are provided by **plugins** rather than built-in filterchecks:

- **Container fields** (`container.*`): Provided by the `container` plugin. See [`digests/falcosecurity/plugins/container.md`](../digests/falcosecurity/plugins/container.md).
- **Kubernetes fields** (`k8s.*`): Provided by the `k8smeta` plugin. See [`digests/falcosecurity/plugins/k8smeta.md`](../digests/falcosecurity/plugins/k8smeta.md).

These fields are registered dynamically when the corresponding plugin is loaded and are available in Falco rule conditions and output fields just like built-in fields.

### Filter Compilation

**Source:** [`filter.h:179-283`](../refs/falcosecurity/libs/userspace/libsinsp/filter.h)

The `sinsp_filter_compiler` class compiles filter strings or ASTs into executable `sinsp_filter` objects. It implements `const_expr_visitor` to traverse the AST.

```cpp
class sinsp_filter_compiler : private libsinsp::filter::ast::const_expr_visitor {
public:
    // Compile from string (parses internally)
    sinsp_filter_compiler(sinsp* inspector, const std::string& fltstr,
                          const std::shared_ptr<sinsp_filter_cache_factory>& cache_factory = nullptr);

    // Compile from factory + string
    sinsp_filter_compiler(const std::shared_ptr<sinsp_filter_factory>& factory,
                          const std::string& fltstr,
                          const std::shared_ptr<sinsp_filter_cache_factory>& cache_factory = nullptr);

    // Compile from factory + pre-parsed AST
    sinsp_filter_compiler(const std::shared_ptr<sinsp_filter_factory>& factory,
                          const libsinsp::filter::ast::expr* fltast,
                          const std::shared_ptr<sinsp_filter_cache_factory>& cache_factory = nullptr);

    // Build executable filter
    std::unique_ptr<sinsp_filter> compile();

    // Access the AST
    const std::shared_ptr<libsinsp::filter::ast::expr> get_filter_ast() const;

    // Access compiler warnings
    const std::vector<message>& get_warnings() const;
};
```

The compiled `sinsp_filter` class runs the filter against events:

```cpp
class sinsp_filter {
public:
    bool run(sinsp_evt* evt);

    void push_expression(boolop op);
    void pop_expression();
    void add_check(std::unique_ptr<sinsp_filter_check> chk);

    std::unique_ptr<sinsp_filter_expression> m_filter;
};
```

### Filter Execution Flow

```
1. Parse filter string → AST
   libsinsp::filter::parser::parse()
   ├─ Recursive descent parsing
   └─ Max recursion depth: 100 (configurable)

2. Compile AST → sinsp_filter
   sinsp_filter_compiler::compile()
   ├─ Traverse AST using visitor pattern
   ├─ For each field_expr:
   │   └─ Resolve field to sinsp_filter_check via filter_check_list
   ├─ For each binary_check_expr:
   │   ├─ Create filtercheck for LHS field
   │   ├─ Parse operator (str_to_cmpop)
   │   └─ Parse RHS value (constant, list, or field reference)
   ├─ For each field_transformer_expr:
   │   └─ Add transformer to filtercheck chain
   ├─ Build boolean expression tree
   └─ Emit compiler warnings (e.g., regex validity, field references)

3. Run filter against event
   sinsp_filter::run(evt)
   │
   ├─ For each expression node:
   │  │
   │  ├─ Extract field value
   │  │  sinsp_filter_check::extract(evt, values)
   │  │
   │  ├─ Apply transformers (if any)
   │  │  sinsp_filter_check::apply_transformers(values)
   │  │
   │  └─ Compare value against RHS
   │     sinsp_filter_check::compare(evt)
   │     └─ flt_compare(op, type, operand1, operand2)
   │
   └─ Evaluate boolean logic
      sinsp_filter_expression::compare(evt)
      └─ AND/OR/NOT evaluation of child checks
```

### Filtercheck Base Class

**Source:** [`sinsp_filtercheck.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck.h)

```cpp
class sinsp_filter_check {
public:
    // Parse field name from filter string
    virtual int32_t parse_field_name(std::string_view, bool alloc_state, bool needed_for_filtering);

    // Add constant value for comparison
    virtual void add_filter_value(const char* str, uint32_t len, uint32_t i = 0);

    // Add RHS field check for field-to-field comparison
    virtual void add_filter_value(std::unique_ptr<sinsp_filter_check> chk);

    // Add field transformer
    virtual void add_transformer(filter_transformer_type trtype);

    // Extract field values from event (with transformer support)
    bool extract(sinsp_evt*, std::vector<extract_value_t>& values, bool sanitize_strings = true);

    // Compare extracted value against filter value
    virtual bool compare(sinsp_evt*);

    // Get field metadata
    virtual const filtercheck_field_info* get_field_info() const;
    virtual const filtercheck_field_info* get_transformed_field_info() const;

    sinsp* m_inspector;
    boolop m_boolop;      // Boolean operator (AND, OR, NOT)
    cmpop m_cmpop;        // Comparison operator
};
```

### Field Information Structure

**Source:** [`filter_field.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter_field.h)

```cpp
struct filtercheck_field_info {
    ppm_param_type m_type;           // Data type (PT_CHARBUF, PT_INT64, etc.)
    uint32_t m_flags;                // Field flags (EPF_* flags)
    ppm_print_format m_print_format; // Numeric rendering format
    std::string m_name;              // Field name
    std::string m_display;           // Short display name
    std::string m_description;       // Help text
};
```

### Field Flags (EPF_*)

**Source:** [`filter_field.h:31-54`](../refs/falcosecurity/libs/userspace/libsinsp/filter_field.h)

| Flag | Value | Description |
|------|-------|-------------|
| `EPF_NONE` | 0 | No special behavior |
| `EPF_FILTER_ONLY` | 1 << 0 | Can only be used as a filter, not in output |
| `EPF_PRINT_ONLY` | 1 << 1 | Can only be printed, not used in filters |
| `EPF_ARG_REQUIRED` | 1 << 2 | Requires an argument: `field[arg]` |
| `EPF_TABLE_ONLY` | 1 << 3 | Designed for table output, hidden from field listings |
| `EPF_INFO` | 1 << 4 | Contains summary information about the event |
| `EPF_CONVERSATION` | 1 << 5 | Can identify conversations |
| `EPF_IS_LIST` | 1 << 6 | Returns multiple values |
| `EPF_ARG_ALLOWED` | 1 << 7 | Argument is optional |
| `EPF_ARG_INDEX` | 1 << 8 | Accepts numeric index arguments |
| `EPF_ARG_KEY` | 1 << 9 | Accepts string key arguments |
| `EPF_DEPRECATED` | 1 << 10 | Field is deprecated |
| `EPF_NO_TRANSFORMER` | 1 << 11 | Transformers not supported on this field |
| `EPF_NO_RHS` | 1 << 12 | Cannot have a right-hand side field check |
| `EPF_NO_PTR_STABILITY` | 1 << 13 | Extracted data pointers may change across extractions (unsafe for caching) |
| `EPF_FORMAT_SUGGESTED` | 1 << 14 | Suggested for use as output field |

### Filtercheck Registry

**Source:** [`filter_check_list.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter_check_list.h)

```cpp
class filter_check_list {
public:
    // Register a filtercheck factory
    void add_filter_check(std::unique_ptr<sinsp_filter_check> filter_check);

    // Look up filtercheck for a field name
    std::unique_ptr<sinsp_filter_check> new_filter_check_from_fldname(
        std::string_view name, sinsp*, bool do_exact_check) const;

    // Get all registered filterchecks
    void get_all_fields(std::vector<const filter_check_info*>&) const;
};

// Default syscall filterchecks
class sinsp_filter_check_list : public filter_check_list {
public:
    sinsp_filter_check_list();  // Registers all 9 default filterchecks
};
```

### Plugin Fields

Plugins can register custom fields via the extraction capability. Plugin fields are dynamically added to the filter check registry when the plugin is loaded.

```cpp
// Plugin returns field definitions as JSON
const char* get_fields() {
    return R"([
        {"name": "myplugin.field", "type": "string", "desc": "Custom field"}
    ])";
}

// Plugin extracts field values at runtime
ss_plugin_rc extract_fields(ss_plugin_t* s,
                            const ss_plugin_event_input* evt,
                            const ss_plugin_field_extract_input* in);
```

Key plugin-provided field classes in Falco 0.44:
- `container.*` fields -- from the `container` plugin
- `k8s.*` fields -- from the `k8smeta` plugin

See [`digests/falcosecurity/libs/plugin-framework.md`](../digests/falcosecurity/libs/plugin-framework.md) for the complete plugin field extraction API.

## Non-Functional Requirements

### Performance

- **Event type indexing**: The rule engine uses event type indexes to rapidly match events against rules. Only rules whose conditions reference matching event types are evaluated, avoiding full evaluation of all rules for every event.
- **Filter caching**: The `sinsp_filter_cache_factory` provides optional caching of extraction and comparison results, reducing redundant work when multiple rules reference the same fields.
- **Compiler warnings**: The compiler detects common issues (e.g., invalid regex patterns, potential field references in string values) at compile time rather than runtime.

### Extensibility

- **Plugin fields**: The extraction capability API allows plugins to register arbitrary field classes, extending the filter language without modifying libsinsp.
- **Custom filterchecks**: The `filter_check_list` class supports dynamic registration of new filtercheck classes beyond the built-in set.
- **Static filterchecks**: The `sinsp_filter_check_static` class enables user-defined key-value filterchecks at runtime.

## Related Specs

| Spec | Relationship |
|------|-------------|
| [`architecture-overview.md`](architecture-overview.md) | Pipeline context for how filters fit into the event processing flow |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | Kernel drivers that produce the events filtered by this engine |

## Sources

| Topic | Source File |
|-------|-------------|
| Grammar and parser | [`filter/parser.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter/parser.h) |
| AST nodes and visitors | [`filter/ast.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter/ast.h) |
| Comparison operators (`cmpop`) | [`filter_compare.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter_compare.h) |
| Field transformers | [`sinsp_filter_transformer.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filter_transformers/sinsp_filter_transformer.h) |
| Base filtercheck class | [`sinsp_filtercheck.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck.h) |
| Field info and flags | [`filter_field.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter_field.h) |
| Filter compilation and execution | [`filter.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter.h) |
| Filtercheck registry | [`filter_check_list.h`](../refs/falcosecurity/libs/userspace/libsinsp/filter_check_list.h) |
| Default registrations | [`filter_check_list.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/filter_check_list.cpp) |
| Generic event fields | [`sinsp_filtercheck_gen_event.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_gen_event.cpp) |
| Syscall event fields | [`sinsp_filtercheck_event.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_event.cpp) |
| Thread/process fields | [`sinsp_filtercheck_thread.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_thread.cpp) |
| File descriptor fields | [`sinsp_filtercheck_fd.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fd.cpp) |
| User fields | [`sinsp_filtercheck_user.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_user.cpp) |
| Group fields | [`sinsp_filtercheck_group.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_group.cpp) |
| Filesystem path fields | [`sinsp_filtercheck_fspath.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fspath.cpp) |
| FD list fields (poll) | [`sinsp_filtercheck_fdlist.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fdlist.cpp) |
| Utility fields | [`sinsp_filtercheck_utils.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_utils.cpp) |
| Static filterchecks | [`sinsp_filtercheck_static.h`](../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_static.h) |
| Digest | [`filtering.md`](../digests/falcosecurity/libs/filtering.md) |
| Container plugin fields | [`container.md`](../digests/falcosecurity/plugins/container.md) |
| K8s metadata plugin fields | [`k8smeta.md`](../digests/falcosecurity/plugins/k8smeta.md) |
