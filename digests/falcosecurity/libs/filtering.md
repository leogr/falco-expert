# Filtering Language
> **Era:** 0.44 | **Version:** libs 0.25.4 | **Source:** [`refs/falcosecurity/libs/`](../../../refs/falcosecurity/libs/)

## Overview

The filtering language is the core expression language used in Falco rule `condition:` fields and sysdig capture filters. It evaluates Boolean expressions against system events by extracting field values, optionally transforming them, and comparing against literal values or lists.

**Pipeline:** filter string --> parser (recursive descent) --> AST --> compiler (AST visitor) --> `sinsp_filter` (executable filter tree) --> `run(sinsp_evt*)` --> `bool`

**Location:** [`userspace/libsinsp/filter/`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/) and [`userspace/libsinsp/`](../../../refs/falcosecurity/libs/userspace/libsinsp/)

## Grammar

**Source:** [`filter/parser.h:32-87`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/parser.h)

The filter language is a context-free grammar parsed by a recursive descent parser. The exact EBNF from the source:

```
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
```

**Operators:**

```
UnaryOperator       ::= 'exists'
NumOperator         ::= '<=' | '<' | '>=' | '>'
StrOperator         ::= '==' | '=' | '!='
                        | 'bcontains' | 'bstartswith'
                        | 'contains' | 'endswith' | 'glob'
                        | 'icontains' | 'iglob'
                        | 'startswith' | 'regex'
ListOperator        ::= 'in' | 'intersects' | 'pmatch'
FieldTransformerVal    ::= 'val('
FieldTransformerType   ::= 'tolower(' | 'toupper(' | 'b64(' | 'basename(' | 'len('
```

**Tokens:**

```
Identifier          ::= [a-zA-Z]+[a-zA-Z0-9_]*
FieldName           ::= [a-zA-Z]+[a-zA-Z0-9_]*(\.[a-zA-Z]+[a-zA-Z0-9_]*)+
FieldArgBareStr     ::= [^ \b\t\n\r\[\]"']+
HexNumber           ::= 0[xX][0-9a-zA-Z]+
Number              ::= [+\-]?[0-9]+[\.]?[0-9]*([eE][+\-][0-9]+)?
QuotedStr           ::= "(?:\\"|.)*?"|'(?:\\'|.)*?'
BareStr             ::= [^ \b\t\n\r\(\),="']+
```

Key design details: the parser has configurable max recursion depth (default 100) and supports partial parsing via `set_parse_partial()`. **Source:** [`filter/parser.h:128-139`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/parser.h)

## AST Structure

**Source:** [`filter/ast.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/ast.h)

The parser produces an Abstract Syntax Tree with 10 node types, all inheriting from `expr`:

| Node Type | Purpose | Key Members |
|-----------|---------|-------------|
| `and_expr` | Conjunction (AND) | `children: vector<unique_ptr<expr>>` |
| `or_expr` | Disjunction (OR) | `children: vector<unique_ptr<expr>>` |
| `not_expr` | Negation (NOT) | `child: unique_ptr<expr>` |
| `identifier_expr` | Bare identifier (macro reference) | `identifier: string` |
| `value_expr` | Literal value | `value: string` |
| `list_expr` | List of values | `values: vector<string>` |
| `unary_check_expr` | Unary check (e.g. `exists`) | `left: unique_ptr<expr>`, `op: string` |
| `binary_check_expr` | Binary check (e.g. `field = val`) | `left`, `right: unique_ptr<expr>`, `op: string` |
| `field_expr` | Field reference | `field: string`, `arg: string` |
| `field_transformer_expr` | Transformer wrapping a field | `transformer: string`, `value: unique_ptr<expr>` |

Each node carries `pos_info` (idx, line, col) for error reporting. **Source:** [`filter/ast.h:49-78`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/ast.h)

The AST supports the visitor pattern with four visitor interfaces: `expr_visitor`, `const_expr_visitor`, `base_expr_visitor` (traversal-only default), and `const_base_expr_visitor`. A `string_visitor` converts ASTs back to filter strings. **Source:** [`filter/ast.h:85-199`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/ast.h)

## Comparison Operators

**Source:** [`filter_compare.h:31-52`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_compare.h)

| Operator | Enum | Value | Description | Example |
|----------|------|-------|-------------|---------|
| `=` or `==` | `CO_EQ` | 1 | Equal | `proc.name = nginx` |
| `!=` | `CO_NE` | 2 | Not equal | `proc.name != sh` |
| `<` | `CO_LT` | 3 | Less than | `evt.rawres < 0` |
| `<=` | `CO_LE` | 4 | Less or equal | `fd.num <= 2` |
| `>` | `CO_GT` | 5 | Greater than | `proc.pid > 1` |
| `>=` | `CO_GE` | 6 | Greater or equal | `evt.count >= 100` |
| `contains` | `CO_CONTAINS` | 7 | Substring match | `proc.cmdline contains password` |
| `in` | `CO_IN` | 8 | In list | `proc.name in (cat, grep, ls)` |
| `exists` | `CO_EXISTS` | 9 | Field has value (unary) | `fd.name exists` |
| `icontains` | `CO_ICONTAINS` | 10 | Case-insensitive contains | `fd.name icontains tmp` |
| `startswith` | `CO_STARTSWITH` | 11 | Prefix match | `proc.name startswith java` |
| `glob` | `CO_GLOB` | 12 | Glob pattern | `fd.name glob /etc/*.conf` |
| `pmatch` | `CO_PMATCH` | 13 | Prefix match in list | `fd.name pmatch (/etc, /usr)` |
| `endswith` | `CO_ENDSWITH` | 14 | Suffix match | `fd.name endswith .log` |
| `intersects` | `CO_INTERSECTS` | 15 | List intersection | `proc.args intersects (a, b)` |
| `bcontains` | `CO_BCONTAINS` | 16 | Binary buffer contains (hex) | `evt.buffer bcontains 4142` |
| `bstartswith` | `CO_BSTARTSWITH` | 17 | Binary buffer prefix (hex) | `evt.buffer bstartswith 7f454c46` |
| `iglob` | `CO_IGLOB` | 18 | Case-insensitive glob | `proc.name iglob Java*` |
| `regex` | `CO_REGEX` | 19 | Regular expression (RE2) | `proc.cmdline regex "pass(word)?"` |

The core comparison function is `flt_compare()`. **Source:** [`filter_compare.h:62-67`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_compare.h)

## Field Transformers

**Source:** [`sinsp_filter_transformers/sinsp_filter_transformer.h:25-32`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filter_transformers/sinsp_filter_transformer.h)

Transformers modify field values before comparison. The syntax is **function-call style**, wrapping the field:

| Transformer | Enum | Value | Description | Example |
|-------------|------|-------|-------------|---------|
| `toupper(...)` | `FTR_TOUPPER` | 0 | Converts to uppercase | `toupper(proc.name) = NGINX` |
| `tolower(...)` | `FTR_TOLOWER` | 1 | Converts to lowercase | `tolower(proc.name) = nginx` |
| `b64(...)` | `FTR_BASE64` | 2 | Base64 decode | `b64(evt.arg.data) contains secret` |
| `val(...)` | `FTR_STORAGE` | 3 | Value storage (internal only) | Used for RHS field-to-field comparisons |
| `basename(...)` | `FTR_BASENAME` | 4 | Path basename extraction | `basename(fd.name) = config.yaml` |
| `len(...)` | `FTR_LEN` | 5 | Value length | `len(proc.cmdline) > 1000` |

**Source for descriptions:** [`sinsp_filter_transformers/sinsp_filter_transformer.h:42-48`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filter_transformers/sinsp_filter_transformer.h)

**Transformer chaining:** Transformers nest as function calls:

```
toupper(basename(fd.name)) = CONFIG.YAML
```

**Factory:** [`sinsp_filter_transformers.h:26-52`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filter_transformers.h) -- maps `filter_transformer_type` to concrete implementations.

**RHS field-to-field comparisons:** The `val()` transformer enables comparing two fields at runtime: `fd.name = val(proc.cwd)`. **Source:** [`parser.h:50-51`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/parser.h)

## Filtercheck Architecture

### Base Class

**Source:** [`sinsp_filtercheck.h:59-281`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck.h)

`sinsp_filter_check` is the base class for all field extractors. Key interface:

- `parse_field_name(string_view, alloc_state, needed_for_filtering)` -- resolve field name, return parsed length
- `extract(sinsp_evt*, vector<extract_value_t>&, sanitize_strings)` -- extract values from event
- `compare(sinsp_evt*)` -- compare extracted value against filter RHS
- `add_filter_value(const char*, len, i)` -- set compile-time constant for comparison
- `add_filter_value(unique_ptr<sinsp_filter_check>)` -- set RHS filter check for field-to-field comparison
- `add_transformer(filter_transformer_type)` -- add transformer to extraction pipeline
- `allocate_new()` -- factory method for cloning

### Field Descriptor

**Source:** [`filter_field.h:59-114`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_field.h)

```cpp
struct filtercheck_field_info {
    ppm_param_type m_type;       // Data type (PT_CHARBUF, PT_INT64, etc.)
    uint32_t m_flags;            // EPF_* flags (see below)
    ppm_print_format m_print_format;
    std::string m_name;          // Field name (e.g. "proc.name")
    std::string m_display;       // Short display name
    std::string m_description;   // Help text
};
```

### Field Flags (EPF_*)

**Source:** [`filter_field.h:31-54`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_field.h)

| Flag | Value | Description |
|------|-------|-------------|
| `EPF_NONE` | `0` | No special behavior |
| `EPF_FILTER_ONLY` | `1 << 0` (1) | Can only be used in filters, not output |
| `EPF_PRINT_ONLY` | `1 << 1` (2) | Can only be used in output, not filters |
| `EPF_ARG_REQUIRED` | `1 << 2` (4) | Requires argument: `field[arg]` |
| `EPF_TABLE_ONLY` | `1 << 3` (8) | Hidden from field listings, for table use |
| `EPF_INFO` | `1 << 4` (16) | Contains summary info about the event |
| `EPF_CONVERSATION` | `1 << 5` (32) | Can identify conversations |
| `EPF_IS_LIST` | `1 << 6` (64) | Returns multiple values |
| `EPF_ARG_ALLOWED` | `1 << 7` (128) | Argument optional |
| `EPF_ARG_INDEX` | `1 << 8` (256) | Accepts numeric index argument |
| `EPF_ARG_KEY` | `1 << 9` (512) | Accepts string key argument |
| `EPF_DEPRECATED` | `1 << 10` (1024) | Field is deprecated |
| `EPF_NO_TRANSFORMER` | `1 << 11` (2048) | Transformers not supported |
| `EPF_NO_RHS` | `1 << 12` (4096) | No RHS field-to-field comparison allowed |
| `EPF_NO_PTR_STABILITY` | `1 << 13` (8192) | Extracted data pointers may change across extractions |
| `EPF_FORMAT_SUGGESTED` | `1 << 14` (16384) | Suggested as output field |

### Field Class Info

**Source:** [`filter_field.h:119-134`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_field.h)

```cpp
class filter_check_info {
    enum flags : uint8_t { FL_NONE = 0, FL_HIDDEN = (1 << 0) };
    std::string m_name;       // Class name (e.g. "process", "fd", "evt")
    std::string m_shortdesc;  // Short description
    std::string m_desc;       // Full description
    int32_t m_nfields;        // Number of fields
    const filtercheck_field_info* m_fields;  // Field array
    uint32_t m_flags;         // FL_NONE or FL_HIDDEN
};
```

## Default Filtercheck Registry

**Source:** [`filter_check_list.cpp:89-102`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_check_list.cpp)

The `sinsp_filter_check_list` constructor registers exactly 9 built-in filtercheck classes:

| # | Class | Field Class Name | Field Prefix | Source |
|---|-------|-----------------|--------------|--------|
| 1 | `sinsp_filter_check_gen_event` | `evt` (All event types) | `evt.num`, `evt.time`, `evt.hostname`, etc. | [`sinsp_filtercheck_gen_event.cpp:47-161`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_gen_event.cpp) |
| 2 | `sinsp_filter_check_event` | `evt` (Syscall events only) | `evt.latency`, `evt.type`, `evt.args`, etc. | [`sinsp_filtercheck_event.cpp:60-426`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_event.cpp) |
| 3 | `sinsp_filter_check_thread` | `process` | `proc.*`, `thread.*` | [`sinsp_filtercheck_thread.cpp:49-727`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_thread.cpp) |
| 4 | `sinsp_filter_check_user` | `user` | `user.*` | [`sinsp_filtercheck_user.cpp:37-61`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_user.cpp) |
| 5 | `sinsp_filter_check_group` | `group` | `group.*` | [`sinsp_filtercheck_group.cpp:37-40`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_group.cpp) |
| 6 | `sinsp_filter_check_fd` | `fd` | `fd.*` | [`sinsp_filtercheck_fd.cpp:53-315`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fd.cpp) |
| 7 | `sinsp_filter_check_fspath` | `fs.path` | `fs.path.*` | [`sinsp_filtercheck_fspath.cpp:34-83`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fspath.cpp) |
| 8 | `sinsp_filter_check_utils` | `util` (hidden) | `util.cnt` | [`sinsp_filtercheck_utils.cpp:31-33`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_utils.cpp) |
| 9 | `sinsp_filter_check_fdlist` | `fdlist` | `fdlist.*` | [`sinsp_filtercheck_fdlist.cpp:31-73`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fdlist.cpp) |

> **Important (era 0.44):** Container fields (`container.*`) and Kubernetes fields (`k8s.*`) are **not** built-in filterchecks. They are provided by plugins (specifically the `container` plugin) via the plugin extraction capability. They are **not** registered in `sinsp_filter_check_list`.

## Filtercheck Field Details

### Generic Event Fields (`evt.*` -- all event types)

**Class:** `sinsp_filter_check_gen_event` | **Source:** [`sinsp_filtercheck_gen_event.cpp:47-161`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_gen_event.cpp)

These fields apply to all events, including plugin events:

| Field | Type | Description |
|-------|------|-------------|
| `evt.num` | PT_UINT64 | Event number |
| `evt.time` | PT_CHARBUF | Timestamp with nanoseconds |
| `evt.time.s` | PT_CHARBUF | Timestamp without nanoseconds |
| `evt.time.iso8601` | PT_CHARBUF | ISO 8601 timestamp (UTC) |
| `evt.datetime` | PT_CHARBUF | Timestamp with date |
| `evt.datetime.s` | PT_CHARBUF | Datetime without nanoseconds |
| `evt.rawtime` | PT_ABSTIME | Absolute nanoseconds from epoch |
| `evt.rawtime.s` | PT_ABSTIME | Seconds from epoch |
| `evt.rawtime.ns` | PT_ABSTIME | Fractional nanoseconds |
| `evt.reltime` | PT_RELTIME | Nanoseconds from capture start |
| `evt.reltime.s` | PT_RELTIME | Seconds from capture start |
| `evt.reltime.ns` | PT_RELTIME | Fractional ns from capture start |
| `evt.pluginname` | PT_CHARBUF | Plugin name (if plugin event) |
| `evt.plugininfo` | PT_CHARBUF | Plugin event summary |
| `evt.source` | PT_CHARBUF | Event source name |
| `evt.is_async` | PT_BOOL | True for async events |
| `evt.asynctype` | PT_CHARBUF | Async event type |
| `evt.hostname` | PT_CHARBUF | Host hostname (customizable via env var) |

### Syscall Event Fields (`evt.*` -- syscall events only)

**Class:** `sinsp_filter_check_event` | **Source:** [`sinsp_filtercheck_event.cpp:60-426`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_event.cpp)

Key fields (selected, 58 total):

| Field | Type | Flags | Description |
|-------|------|-------|-------------|
| `evt.latency` | PT_RELTIME | DEPRECATED | Enter-to-exit delta (ns) |
| `evt.deltatime` | PT_RELTIME | -- | Delta from previous event (ns) |
| `evt.outputtime` | PT_CHARBUF | PRINT_ONLY | Output time format |
| `evt.dir` | PT_CHARBUF | DEPRECATED | Direction (`>` enter, `<` exit) |
| `evt.type` | PT_CHARBUF | -- | Event type name |
| `evt.type.is` | PT_UINT32 | ARG_REQUIRED | Check event type |
| `syscall.type` | PT_CHARBUF | -- | Syscall name (unset for non-syscalls) |
| `evt.category` | PT_CHARBUF | -- | Event category (file, net, etc.) |
| `evt.cpu` | PT_INT16 | -- | CPU number |
| `evt.args` | PT_CHARBUF | -- | All arguments as string |
| `evt.arg` | PT_CHARBUF | ARG_REQUIRED, NO_PTR_STABILITY | Specific argument by name/index |
| `evt.rawarg` | PT_DYN | ARG_REQUIRED, NO_RHS, NO_TRANSFORMER | Raw argument by name |
| `evt.info` | PT_CHARBUF | -- | Same as evt.args |
| `evt.buffer` | PT_BYTEBUF | NO_PTR_STABILITY | Binary data buffer |
| `evt.buflen` | PT_UINT64 | -- | Buffer length |
| `evt.res` | PT_CHARBUF | NO_PTR_STABILITY | Return value as string |
| `evt.rawres` | PT_INT64 | -- | Raw return value |
| `evt.failed` | PT_BOOL | -- | True if syscall failed |
| `evt.is_io` | PT_BOOL | -- | True for I/O events |
| `evt.is_io_read` | PT_BOOL | -- | True for read I/O |
| `evt.is_io_write` | PT_BOOL | -- | True for write I/O |
| `evt.is_open_read` | PT_BOOL | -- | Opened for reading |
| `evt.is_open_write` | PT_BOOL | -- | Opened for writing |
| `evt.is_open_exec` | PT_BOOL | -- | Created with exec perms |
| `evt.is_open_create` | PT_BOOL | -- | File created |
| `evt.around` | PT_UINT64 | FILTER_ONLY, ARG_REQUIRED, NO_RHS, NO_TRANSFORMER | Time interval filter |
| `evt.abspath` | PT_CHARBUF | ARG_REQUIRED | Absolute path from dirfd+name |

### Process/Thread Fields (`proc.*`, `thread.*`)

**Class:** `sinsp_filter_check_thread` | **Source:** [`sinsp_filtercheck_thread.cpp:49-727`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_thread.cpp)

Key fields (selected, 90 total):

| Field | Type | Flags | Description |
|-------|------|-------|-------------|
| `proc.exe` | PT_CHARBUF | -- | First argv (argv[0]) |
| `proc.pexe` | PT_CHARBUF | -- | Parent's proc.exe |
| `proc.aexe` | PT_CHARBUF | ARG_ALLOWED, NO_RHS, NO_TRANSFORMER | Ancestor exe (indexed) |
| `proc.exepath` | PT_CHARBUF | -- | Full resolved executable path |
| `proc.pexepath` | PT_CHARBUF | -- | Parent's executable path |
| `proc.aexepath` | PT_CHARBUF | ARG_ALLOWED, NO_RHS, NO_TRANSFORMER | Ancestor exepath (indexed) |
| `proc.name` | PT_CHARBUF | -- | Process name (16 char limit) |
| `proc.pname` | PT_CHARBUF | -- | Parent process name |
| `proc.aname` | PT_CHARBUF | ARG_ALLOWED, NO_RHS, NO_TRANSFORMER | Ancestor name (indexed) |
| `proc.args` | PT_CHARBUF | ARG_ALLOWED | Command arguments (indexed) |
| `proc.cmdline` | PT_CHARBUF | -- | proc.name + proc.args |
| `proc.pcmdline` | PT_CHARBUF | -- | Parent cmdline |
| `proc.acmdline` | PT_CHARBUF | ARG_ALLOWED, NO_RHS, NO_TRANSFORMER | Ancestor cmdline (indexed) |
| `proc.cmdnargs` | PT_UINT64 | -- | Number of args |
| `proc.cmdlenargs` | PT_UINT64 | -- | Total args character count |
| `proc.exeline` | PT_CHARBUF | -- | proc.exe + proc.args |
| `proc.env` | PT_CHARBUF | ARG_ALLOWED | Environment variables |
| `proc.aenv` | PT_CHARBUF | ARG_ALLOWED, NO_RHS, NO_TRANSFORMER | Ancestor env [EXPERIMENTAL] |
| `proc.cwd` | PT_CHARBUF | -- | Current working directory |
| `proc.loginshellid` | PT_INT64 | -- | Login shell PID |
| `proc.tty` | PT_UINT32 | -- | TTY number (0 if none) |
| `proc.pid` | PT_INT64 | -- | Process ID |
| `proc.ppid` | PT_INT64 | -- | Parent PID |
| `proc.apid` | PT_INT64 | ARG_ALLOWED, NO_RHS, NO_TRANSFORMER | Ancestor PID (indexed) |
| `proc.vpid` | PT_INT64 | -- | Virtual PID (in PID namespace) |
| `proc.pvpid` | PT_INT64 | -- | Parent virtual PID |
| `proc.sid` | PT_INT64 | -- | Session ID |
| `proc.sname` | PT_CHARBUF | -- | Session leader name |
| `proc.sid.exe` | PT_CHARBUF | -- | Session leader exe |
| `proc.sid.exepath` | PT_CHARBUF | -- | Session leader exepath |
| `proc.vpgid` | PT_INT64 | -- | Virtual process group ID |
| `proc.pgid` | PT_INT64 | -- | Process group ID (host PID ns) |
| `proc.duration` | PT_RELTIME | -- | Nanoseconds since process start |
| `proc.ppid.duration` | PT_RELTIME | -- | Parent duration |
| `proc.pid.ts` | PT_RELTIME | -- | Process start epoch timestamp (ns) |
| `proc.ppid.ts` | PT_RELTIME | -- | Parent start timestamp (ns) |
| `proc.is_exe_writable` | PT_BOOL | -- | Executable is writable |
| `proc.is_exe_upper_layer` | PT_BOOL | -- | Exe in overlayfs upper layer |
| `proc.is_exe_lower_layer` | PT_BOOL | -- | Exe in overlayfs lower layer |
| `proc.is_exe_from_memfd` | PT_BOOL | -- | Exe from memfd |
| `proc.is_sid_leader` | PT_BOOL | -- | Is session leader |
| `proc.is_vpgid_leader` | PT_BOOL | -- | Is virtual process group leader |
| `proc.is_pgid_leader` | PT_BOOL | -- | Is process group leader |
| `proc.exe_ino` | PT_INT64 | -- | Executable inode number |
| `proc.exe_ino.ctime` | PT_ABSTIME | -- | Exe inode ctime |
| `proc.exe_ino.mtime` | PT_ABSTIME | -- | Exe inode mtime |
| `proc.pidns_init_start_ts` | PT_UINT64 | -- | PID namespace start timestamp |
| `thread.cap_permitted` | PT_CHARBUF | -- | Permitted capabilities |
| `thread.cap_inheritable` | PT_CHARBUF | -- | Inheritable capabilities |
| `thread.cap_effective` | PT_CHARBUF | -- | Effective capabilities |
| `proc.fdopencount` | PT_UINT64 | -- | Open FD count |
| `proc.fdlimit` | PT_INT64 | -- | FD limit |
| `proc.fdusage` | PT_DOUBLE | -- | FD usage ratio |
| `proc.vmsize` | PT_UINT64 | -- | Virtual memory (kb) |
| `proc.vmrss` | PT_UINT64 | -- | Resident memory (kb) |
| `proc.vmswap` | PT_UINT64 | -- | Swapped memory (kb) |
| `thread.tid` | PT_INT64 | -- | Thread ID |
| `thread.ismain` | PT_BOOL | -- | Is main thread |
| `thread.vtid` | PT_INT64 | -- | Virtual thread ID |
| `thread.cgroups` | PT_CHARBUF | -- | All cgroups |
| `thread.cgroup` | PT_CHARBUF | ARG_REQUIRED | Specific cgroup subsystem |
| `proc.nthreads` | PT_UINT64 | -- | Alive thread count |
| `proc.nchilds` | PT_UINT64 | -- | Non-leader thread count |
| `proc.stdin.type` | PT_CHARBUF | -- | FD 0 type |
| `proc.stdout.type` | PT_CHARBUF | -- | FD 1 type |
| `proc.stderr.type` | PT_CHARBUF | -- | FD 2 type |
| `proc.stdin.name` | PT_CHARBUF | -- | FD 0 name |
| `proc.stdout.name` | PT_CHARBUF | -- | FD 1 name |
| `proc.stderr.name` | PT_CHARBUF | -- | FD 2 name |

### File Descriptor Fields (`fd.*`)

**Class:** `sinsp_filter_check_fd` | **Source:** [`sinsp_filtercheck_fd.cpp:53-315`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fd.cpp)

| Field | Type | Flags | Description |
|-------|------|-------|-------------|
| `fd.num` | PT_INT64 | -- | FD number |
| `fd.type` | PT_CHARBUF | -- | FD type (file, ipv4, ipv6, unix, etc.) |
| `fd.typechar` | PT_CHARBUF | -- | Single-char type (f, 4, 6, u, p, etc.) |
| `fd.name` | PT_CHARBUF | -- | Full FD name/path or connection tuple |
| `fd.directory` | PT_CHARBUF | -- | Directory component |
| `fd.filename` | PT_CHARBUF | -- | Filename component |
| `fd.ip` | PT_IPADDR | FILTER_ONLY, NO_RHS, NO_TRANSFORMER | Client or server IP |
| `fd.cip` | PT_IPADDR | -- | Client IP |
| `fd.sip` | PT_IPADDR | -- | Server IP |
| `fd.lip` | PT_IPADDR | -- | Local IP |
| `fd.rip` | PT_IPADDR | -- | Remote IP |
| `fd.port` | PT_PORT | FILTER_ONLY, NO_RHS, NO_TRANSFORMER | Client or server port |
| `fd.cport` | PT_PORT | -- | Client port |
| `fd.sport` | PT_PORT | -- | Server port |
| `fd.lport` | PT_PORT | -- | Local port |
| `fd.rport` | PT_PORT | -- | Remote port |
| `fd.l4proto` | PT_CHARBUF | -- | L4 protocol (tcp, udp, icmp, raw) |
| `fd.sockfamily` | PT_CHARBUF | -- | Socket family (ip, unix) |
| `fd.is_server` | PT_BOOL | -- | Is server endpoint |
| `fd.uid` | PT_CHARBUF | -- | Unique FD identifier (FD+TID) |
| `fd.containername` | PT_CHARBUF | -- | Container ID + FD name |
| `fd.containerdirectory` | PT_CHARBUF | -- | Container ID + directory |
| `fd.proto` | PT_PORT | FILTER_ONLY, NO_RHS, NO_TRANSFORMER | L7 protocol (from port) |
| `fd.cproto` | PT_CHARBUF | -- | Client protocol |
| `fd.sproto` | PT_CHARBUF | -- | Server protocol |
| `fd.lproto` | PT_CHARBUF | -- | Local protocol |
| `fd.rproto` | PT_CHARBUF | -- | Remote protocol |
| `fd.net` | PT_IPNET | FILTER_ONLY, NO_RHS, NO_TRANSFORMER | IP network (client or server) |
| `fd.cnet` | PT_IPNET | FILTER_ONLY, NO_RHS, NO_TRANSFORMER | Client network |
| `fd.snet` | PT_IPNET | FILTER_ONLY, NO_RHS, NO_TRANSFORMER | Server network |
| `fd.lnet` | PT_IPNET | FILTER_ONLY, NO_RHS, NO_TRANSFORMER | Local network |
| `fd.rnet` | PT_IPNET | FILTER_ONLY, NO_RHS, NO_TRANSFORMER | Remote network |
| `fd.connected` | PT_BOOL | -- | Socket is connected |
| `fd.name_changed` | PT_BOOL | -- | FD name changed during event |
| `fd.cip.name` | PT_CHARBUF | NO_RHS, NO_TRANSFORMER | Client IP domain name |
| `fd.sip.name` | PT_CHARBUF | NO_RHS, NO_TRANSFORMER | Server IP domain name |
| `fd.lip.name` | PT_CHARBUF | NO_RHS, NO_TRANSFORMER | Local IP domain name |
| `fd.rip.name` | PT_CHARBUF | NO_RHS, NO_TRANSFORMER | Remote IP domain name |
| `fd.dev` | PT_INT32 | -- | Device number (hex) |
| `fd.dev.major` | PT_INT32 | -- | Device major number |
| `fd.dev.minor` | PT_INT32 | -- | Device minor number |
| `fd.ino` | PT_INT64 | -- | Inode number |
| `fd.nameraw` | PT_CHARBUF | -- | Raw FD name (no resolution) |
| `fd.types` | PT_CHARBUF | IS_LIST, ARG_ALLOWED, NO_RHS | List of FD types in use |
| `fd.is_upper_layer` | PT_BOOL | -- | File in overlayfs upper layer |
| `fd.is_lower_layer` | PT_BOOL | -- | File in overlayfs lower layer |

### User Fields (`user.*`)

**Class:** `sinsp_filter_check_user` | **Source:** [`sinsp_filtercheck_user.cpp:37-61`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_user.cpp)

| Field | Type | Description |
|-------|------|-------------|
| `user.uid` | PT_UINT32 | User ID |
| `user.name` | PT_CHARBUF | Username |
| `user.homedir` | PT_CHARBUF | Home directory |
| `user.shell` | PT_CHARBUF | Login shell |
| `user.loginuid` | PT_INT64 | Audit login UID (auid), -1 if invalid |
| `user.loginname` | PT_CHARBUF | Audit login username |

### Group Fields (`group.*`)

**Class:** `sinsp_filter_check_group` | **Source:** [`sinsp_filtercheck_group.cpp:37-40`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_group.cpp)

| Field | Type | Description |
|-------|------|-------------|
| `group.gid` | PT_UINT32 | Group ID |
| `group.name` | PT_CHARBUF | Group name |

### Filesystem Path Fields (`fs.path.*`)

**Class:** `sinsp_filter_check_fspath` | **Source:** [`sinsp_filtercheck_fspath.cpp:34-83`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fspath.cpp)

| Field | Type | Description |
|-------|------|-------------|
| `fs.path.name` | PT_CHARBUF | Fully resolved path for file syscalls |
| `fs.path.nameraw` | PT_CHARBUF | Raw (unresolved) path |
| `fs.path.source` | PT_CHARBUF | Source path for mv/cp/rename (resolved) |
| `fs.path.sourceraw` | PT_CHARBUF | Source path (raw) |
| `fs.path.target` | PT_CHARBUF | Target path for mv/cp/rename (resolved) |
| `fs.path.targetraw` | PT_CHARBUF | Target path (raw) |

### FD List Fields (`fdlist.*`)

**Class:** `sinsp_filter_check_fdlist` | **Source:** [`sinsp_filtercheck_fdlist.cpp:31-73`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fdlist.cpp)

For poll/select events:

| Field | Type | Description |
|-------|------|-------------|
| `fdlist.nums` | PT_CHARBUF | Comma-separated FD numbers |
| `fdlist.names` | PT_CHARBUF | Comma-separated FD names |
| `fdlist.cips` | PT_CHARBUF | Comma-separated client IPs |
| `fdlist.sips` | PT_CHARBUF | Comma-separated server IPs |
| `fdlist.cports` | PT_CHARBUF | Comma-separated client ports |
| `fdlist.sports` | PT_CHARBUF | Comma-separated server ports |

### Utility Fields (`util.*`)

**Class:** `sinsp_filter_check_utils` (hidden) | **Source:** [`sinsp_filtercheck_utils.cpp:31-33`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_utils.cpp)

| Field | Type | Description |
|-------|------|-------------|
| `util.cnt` | PT_UINT64 | Incremental counter |

## Filter Compilation

**Source:** [`filter.h:179-283`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter.h)

`sinsp_filter_compiler` compiles filter strings or pre-parsed ASTs into executable `sinsp_filter` objects. It implements `const_expr_visitor` to traverse the AST.

**Construction options:**
1. `sinsp_filter_compiler(inspector, fltstr)` -- string input, uses default filter check list
2. `sinsp_filter_compiler(factory, fltstr)` -- string input with custom factory
3. `sinsp_filter_compiler(factory, fltast)` -- pre-parsed AST input

**Compilation flow:**
1. Parse filter string into AST (if string input) via `libsinsp::filter::parser`
2. Visit each AST node, creating `sinsp_filter_check` instances via `sinsp_filter_factory::new_filtercheck()`
3. Build a tree of `sinsp_filter_expression` nodes connected by `boolop` (BO_AND, BO_OR, BO_NOT)
4. Set comparison operators and values on leaf checks
5. Apply transformers to field checks
6. Return `sinsp_filter` with `run(sinsp_evt*)` method

**Runtime execution:** `sinsp_filter::run(evt)` evaluates the expression tree by calling `compare(evt)` on each `sinsp_filter_expression`, which recursively evaluates child checks via `extract()` + `compare()`. **Source:** [`filter.h:76-91`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter.h)

The compiler also emits warnings (e.g., for values that look like field names or transformer names). **Source:** [`filter.h:244`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter.h)

## String Escaping

**Source:** [`filter/escaping.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/escaping.h)

The `libsinsp::filter` namespace provides `escape_str()` and `unescape_str()` for handling special characters in filter strings.

## Plugin Fields

Plugins with extraction capability register custom fields. In era 0.44, container (`container.*`) and Kubernetes (`k8s.*`) fields are provided by the `container` plugin, not by built-in filterchecks. Plugin fields use the same comparison and transformer infrastructure.

See [`plugin-framework.md`](plugin-framework.md) for plugin field extraction details.

## Sources

| Topic | Source File |
|-------|-------------|
| Grammar and parser | [`filter/parser.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/parser.h) |
| AST nodes | [`filter/ast.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/ast.h) |
| Comparison operators | [`filter_compare.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_compare.h) |
| Transformer base class | [`sinsp_filter_transformers/sinsp_filter_transformer.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filter_transformers/sinsp_filter_transformer.h) |
| Transformer factory | [`sinsp_filter_transformers.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filter_transformers.h) |
| Base filtercheck | [`sinsp_filtercheck.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck.h) |
| Field info and EPF flags | [`filter_field.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_field.h) |
| Filtercheck registry | [`filter_check_list.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter_check_list.cpp) |
| Generic event fields | [`sinsp_filtercheck_gen_event.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_gen_event.cpp) |
| Syscall event fields | [`sinsp_filtercheck_event.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_event.cpp) |
| Thread/process fields | [`sinsp_filtercheck_thread.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_thread.cpp) |
| FD fields | [`sinsp_filtercheck_fd.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fd.cpp) |
| User fields | [`sinsp_filtercheck_user.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_user.cpp) |
| Group fields | [`sinsp_filtercheck_group.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_group.cpp) |
| FS path fields | [`sinsp_filtercheck_fspath.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fspath.cpp) |
| FD list fields | [`sinsp_filtercheck_fdlist.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_fdlist.cpp) |
| Utils fields | [`sinsp_filtercheck_utils.cpp`](../../../refs/falcosecurity/libs/userspace/libsinsp/sinsp_filtercheck_utils.cpp) |
| Filter compiler | [`filter.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter.h) |
| String escaping | [`filter/escaping.h`](../../../refs/falcosecurity/libs/userspace/libsinsp/filter/escaping.h) |

## Related Digests

- [`libsinsp.md`](libsinsp.md) -- State engine and event parsing
- [`api-reference.md`](api-reference.md) -- Event types and parameter types
- [`plugin-framework.md`](plugin-framework.md) -- Plugin field extraction
