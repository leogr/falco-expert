# Falco LSP - AI Digest

Language Server Protocol implementation and VS Code extension for Falco rules development, providing real-time diagnostics, code completion, formatting, and cross-file analysis.

**Applicable to**: Falco 0.44 era (current)
**Repository status**: Incubating (Ecosystem)
**License**: Apache-2.0
**Pinned version**: post-v0.1.0 (commit `aa8c175`, `git describe` = `v0.1.0-13-gaa8c175`, dated 2026-05-06). The latest released tag is 0.1.1 (2026-02-06), but the [`refs/`](../../refs/) submodule is pinned to a later commit on a different branch than the 0.1.1 tag, so the era reference is the commit, not a clean tag.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [CLI Tool (falco-lang)](#cli-tool-falco-lang)
- [Language Server Features](#language-server-features)
- [VS Code Extension](#vs-code-extension)
- [Supported Falco Constructs](#supported-falco-constructs)
- [Field Registry](#field-registry)
- [Build and Development](#build-and-development)
- [Sources](#sources)

---

## Overview

falco-lsp provides comprehensive language tooling for Falco security rules through three components ([README.md:32-56](../../refs/falcosecurity/falco-lsp/README.md)):

1. **`falco-lang` CLI** — Command-line tool for validation and formatting (Go binary)
2. **Language Server** — LSP implementation for IDE integration (Go, stdio transport)
3. **VS Code Extension** — Full IDE experience with syntax highlighting, snippets, and schema validation (TypeScript)

**Three-tier architecture:**

| Layer | Components | Purpose |
|-------|-----------|---------|
| Consumer | VS Code Extension, CLI Tool | User interfaces |
| Intelligence | Go Language Server (LSP) | Feature execution |
| Foundation | YAML parser, condition parser, semantic analyzer | Core analysis |

**Supported file patterns:**
- `*.falco.yaml`, `*.falco.yml`
- `*_rules.yaml`, `*_rules.yml` (official Falco naming: `falco_rules.yaml`, `k8s_audit_rules.yaml`)

**Maintainers:** [@c2ndev](https://github.com/c2ndev), [@leogr](https://github.com/leogr)

**Source:** [README.md](../../refs/falcosecurity/falco-lsp/README.md), [OWNERS](../../refs/falcosecurity/falco-lsp/OWNERS)

---

## Architecture

### Core Packages

The Go implementation is organized under `falco-lsp/internal/` ([LSP README](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/lsp/README.md)):

| Package | Purpose |
|---------|---------|
| `parser/` | YAML parser for Falco rules files — extracts rules, macros, lists with position tracking |
| `condition/` | Recursive descent parser for condition expressions — produces AST with operator precedence |
| `lexer/` | Tokenizer for condition expressions |
| `ast/` | AST types (BinaryExpr, UnaryExpr, FieldExpr, Value) with Position/Range tracking |
| `analyzer/` | Semantic analyzer — cross-file symbol resolution, field validation, macro/list reference checking |
| `formatter/` | Code formatter — configurable indentation, property alignment, block handling |
| `fields/` | Field registry — embedded JSON data for syscall, k8s_audit, and plugin fields |
| `schema/` | Block types, properties, and validation schemas for rule language |
| `lsp/` | LSP server implementation — message dispatch, document storage, feature providers |
| `lsp/providers/` | 9 feature provider sub-packages (completion, diagnostics, hover, definition, references, symbols, formatting) |

### Data Flow

```
stdio JSON-RPC → server.go (message dispatch) → document.Store (thread-safe) → providers/* → Response
```

### Coordinate System

The codebase manages a coordinate system mismatch between YAML parsing (1-based lines, 1-based columns) and LSP protocol (0-based lines, 0-based columns). The parser stores positions as 1-based lines with 0-based columns, converting at the YAML parsing boundary ([parser.go](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/parser/parser.go)).

---

## CLI Tool (falco-lang)

Entry point: [`cmd/falco-lang/main.go`](../../refs/falcosecurity/falco-lsp/falco-lsp/cmd/falco-lang/main.go) (550 lines)

### Commands

**validate** — Validate Falco rules files:

```bash
falco-lang validate <files...>
falco-lang validate ./rules/              # Recursive directory
falco-lang validate --format json rules   # JSON output
falco-lang validate --strict rules        # Warnings treated as errors
```

Expands file patterns (globs, directories), parses all files together for cross-file analysis, reports errors and warnings.

**format** — Format Falco rules files:

```bash
falco-lang format --check rules           # Dry-run (exit code indicates changes needed)
falco-lang format --write rules           # In-place formatting
falco-lang format --check --diff rules    # Show diff
falco-lang format --tab-size 4 rules      # Custom indentation (default: 2)
```

**lsp** — Start the language server:

```bash
falco-lang lsp --stdio                    # stdio mode (default, for IDE integration)
```

**version** — Print version information.

---

## Language Server Features

### Diagnostics (Real-time)

Publishes errors, warnings, hints, and info as you type ([analyzer.go](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/analyzer/analyzer.go)):

| Category | Examples |
|----------|---------|
| Syntax errors | Invalid YAML, malformed condition expressions |
| Undefined references | Unknown macros or lists |
| Field validation | Unknown fields, fields not available for the rule's source type |
| Best practice hints | Dynamic fields requiring arguments |

Severity levels: Error, Warning, Hint, Info.

### Code Completion (Context-aware)

- **Top-level items**: `rule`, `macro`, `list`, `required_engine_version`, `required_plugin_versions`
- **Rule properties**: condition, output, priority, source, tags, exceptions, enabled, desc, append, override, etc.
- **Falco fields**: All syscall, container, and Kubernetes fields
- **Operators**: Comparison (`=`, `!=`, `<`, `>`, `<=`, `>=`) and logical (`and`, `or`, `not`)
- **User-defined symbols**: Macros and lists from all open files
- **Priority levels**: EMERGENCY through DEBUG
- **Sources**: syscall, k8s_audit, aws_cloudtrail, gcp_auditlog, etc.

### Hover Information

- Field descriptions and types
- Macro definitions with conditions
- List contents preview

### Go-to-Definition / Find References

- Jump to macro and list definitions
- Cross-file symbol tracking

### Code Formatting

- Configurable indentation (tab size)
- Property alignment in rule/macro/list definitions
- Trailing whitespace removal
- Blank line normalization

### Document Symbols

- Outline view of rules, macros, and lists in the current file

---

## VS Code Extension

**Package:** [`vscode-extension/`](../../refs/falcosecurity/falco-lsp/vscode-extension/)
**Publisher**: falcosecurity
**Extension ID**: `falcosecurity.falco-rules`
**VS Code minimum**: ^1.85.0

### Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| `falco.maxNumberOfProblems` | 100 | Maximum diagnostics per file |
| `falco.enableFormatting` | true | Enable document formatting |
| `falco.tabSize` | 2 | Indentation size |
| `falco.insertSpaces` | true | Use spaces for indentation |
| `falco.validateYamlFiles` | true | Enable YAML validation |
| `falco.enableSemanticHighlighting` | true | Semantic token highlighting |
| `falco.highlightMacrosInConditions` | true | Highlight macros in conditions |
| `falco.schemaValidation` | true | JSON Schema validation |

**Source:** [vscode-extension/package.json](../../refs/falcosecurity/falco-lsp/vscode-extension/package.json)

### Extension Commands

| Command | Description |
|---------|-------------|
| `falco.validate` | Validate current file |
| `falco.validateWorkspace` | Validate all Falco files in workspace |
| `falco.formatDocument` | Format current document |
| `falco.showOutput` | Show output channel |
| `falco.restartServer` | Restart language server |

### Additional Features

- **TextMate grammar** for syntax highlighting ([syntaxes/](../../refs/falcosecurity/falco-lsp/vscode-extension/syntaxes/))
- **Code snippets** for rule, macro, list, exception templates ([snippets/](../../refs/falcosecurity/falco-lsp/vscode-extension/snippets/))
- **JSON Schema** validation synced from the official Falco repository ([schemas/](../../refs/falcosecurity/falco-lsp/vscode-extension/schemas/))

---

## Supported Falco Constructs

### Rule Language Elements

| Element | Properties |
|---------|-----------|
| **Rules** | name, desc, condition, output, priority, source, tags, enabled, append, override, exceptions, capture, capture_duration, warn_evttypes, skip-if-unknown-filter |
| **Macros** | name, condition, append |
| **Lists** | name, items[], append |
| **Top-level** | `required_engine_version`, `required_plugin_versions` |

### Condition Expression Operators

| Category | Operators |
|----------|----------|
| Logical | `and`, `or`, `not` |
| Comparison | `=`, `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Existence | `exists` |
| Set | `in`, `intersects` |
| String matching | `contains`, `icontains`, `bcontains`, `startswith`, `istartswith`, `bstartswith`, `endswith`, `iendswith`, `bendswith` |
| Pattern matching | `glob`, `iglob`, `regex`, `pmatch` |

### Event Sources

syscall, k8s_audit, aws_cloudtrail, gcp_auditlog, azure_platformlogs, github, okta, and other plugin-provided sources.

### Priority Levels

EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFORMATIONAL, DEBUG

---

## Field Registry

The field registry uses embedded JSON data for field lookup ([fields/registry.go](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/fields/registry.go)):

| Source File | Coverage |
|-------------|----------|
| `syscall.json` | Process, thread, file descriptor, event, container, user fields |
| `k8saudit.json` | Kubernetes audit event fields |
| `plugins.json` | Plugin-provided fields |

Supports dynamic fields with wildcard patterns (e.g., `evt.arg.*`, `thread.cap_*`). Field lookup is source-aware — a syscall field referenced in a `k8s_audit` rule produces a warning.

---

## Build and Development

| Aspect | Detail |
|--------|--------|
| Language | Go 1.22+, TypeScript (VS Code extension) |
| Dependencies | cobra (CLI), yaml.v3 (parser), fatih/color (output), testify (testing) |
| Binary name | `falco-lang` |
| Platforms | linux/amd64, linux/arm64, darwin/amd64, darwin/arm64, windows/amd64 |
| Test coverage | >85% |
| Testing | `make test` (with race detection), 43 test files |
| Linting | golangci-lint v2 |
| Extension build | esbuild, TypeScript 5.3+ |
| Distribution | GitHub Releases (binaries), VS Code Marketplace, Open VSX Registry |

**Source:** [go.mod](../../refs/falcosecurity/falco-lsp/falco-lsp/go.mod), [Makefile](../../refs/falcosecurity/falco-lsp/falco-lsp/Makefile)

---

## Sources

| Topic | Source File |
|-------|-------------|
| Project overview | [README.md](../../refs/falcosecurity/falco-lsp/README.md) |
| LSP server details | [falco-lsp/README.md](../../refs/falcosecurity/falco-lsp/falco-lsp/README.md) |
| VS Code extension | [vscode-extension/README.md](../../refs/falcosecurity/falco-lsp/vscode-extension/README.md) |
| LSP architecture | [falco-lsp/internal/lsp/README.md](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/lsp/README.md) |
| CLI entry point | [falco-lsp/cmd/falco-lang/main.go](../../refs/falcosecurity/falco-lsp/falco-lsp/cmd/falco-lang/main.go) |
| Semantic analyzer | [falco-lsp/internal/analyzer/analyzer.go](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/analyzer/analyzer.go) |
| Condition parser | [falco-lsp/internal/condition/parser.go](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/condition/parser.go) |
| YAML parser | [falco-lsp/internal/parser/parser.go](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/parser/parser.go) |
| Field registry | [falco-lsp/internal/fields/registry.go](../../refs/falcosecurity/falco-lsp/falco-lsp/internal/fields/registry.go) |
| Contributing | [CONTRIBUTING.md](../../refs/falcosecurity/falco-lsp/CONTRIBUTING.md) |
| Changelog | [CHANGELOG.md](../../refs/falcosecurity/falco-lsp/CHANGELOG.md) |

---

*Last updated: 2026-02-19*
