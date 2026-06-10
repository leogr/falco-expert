# Falco LSP

> Language Server Protocol implementation for Falco rules: CLI validation/formatting tool, LSP server with diagnostics and completion, VS Code extension, and field registry.

**Era:** 0.44 | **Source:** [`refs/falcosecurity/falco-lsp/`](../refs/falcosecurity/falco-lsp/)

## 1. Overview

falco-lsp provides comprehensive language tooling for Falco security rules through three components:

| Component | Language | Purpose |
|-----------|----------|---------|
| `falco-lang` CLI | Go | Command-line validation and formatting |
| Language Server | Go (stdio transport) | LSP implementation for IDE integration |
| VS Code Extension | TypeScript | Full IDE experience with syntax highlighting, snippets, schema validation |

**Three-tier architecture:**

```
┌───────────────────────────────────────────────────┐
│  Consumer Layer                                     │
│  ┌─────────────────────┐  ┌─────────────────────┐  │
│  │   VS Code Extension │  │   falco-lang CLI    │  │
│  └──────────┬──────────┘  └──────────┬──────────┘  │
├─────────────┴────────────────────────┘              │
│  Intelligence Layer                                  │
│  ┌──────────────────────────────────────────────┐   │
│  │           Go Language Server (LSP)            │   │
│  │  stdio JSON-RPC → dispatch → providers/*      │   │
│  └──────────────────────┬───────────────────────┘   │
├─────────────────────────┘                            │
│  Foundation Layer                                    │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────┐│
│  │  YAML    │  │ Condition  │  │   Semantic       ││
│  │  Parser  │  │ Parser/AST │  │   Analyzer       ││
│  └──────────┘  └────────────┘  └──────────────────┘│
└───────────────────────────────────────────────────┘
```

**Supported file patterns:** `*.falco.yaml`, `*.falco.yml`, `*_rules.yaml`, `*_rules.yml`

**Repository status:** Incubating (Ecosystem)
**License:** Apache-2.0
**Current version:** 0.1.0 (the era-pinned commit declares `0.1.0` in [`vscode-extension/package.json`](../refs/falcosecurity/falco-lsp/vscode-extension/package.json); HEAD is a development commit past the `v0.1.0` tag, `git describe = v0.1.0-13-gaa8c175`, so no clean release tag applies for this era)

**Source:** [`README.md`](../refs/falcosecurity/falco-lsp/README.md), [`vscode-extension/package.json`](../refs/falcosecurity/falco-lsp/vscode-extension/package.json), [`digests/falcosecurity/falco-lsp.md`](../digests/falcosecurity/falco-lsp.md)

## 2. CLI Tool (falco-lang)

Entry point: [`cmd/falco-lang/main.go`](../refs/falcosecurity/falco-lsp/falco-lsp/cmd/falco-lang/main.go)

### Commands

**validate** -- Validate Falco rules files:

```bash
falco-lang validate <files...>
falco-lang validate ./rules/              # Recursive directory
falco-lang validate --format json rules   # JSON output
falco-lang validate --strict rules        # Warnings treated as errors
```

Expands file patterns (globs, directories), parses all files together for cross-file analysis, reports errors and warnings.

**format** -- Format Falco rules files:

```bash
falco-lang format --check rules           # Dry-run (exit code indicates changes needed)
falco-lang format --write rules           # In-place formatting
falco-lang format --check --diff rules    # Show diff
falco-lang format --tab-size 4 rules      # Custom indentation (default: 2)
```

**lsp** -- Start the language server:

```bash
falco-lang lsp --stdio                    # stdio mode (default, for IDE integration)
```

**version** -- Print version information.

## 3. Language Server Features

### Data Flow

```
stdio JSON-RPC → server.go (message dispatch) → document.Store (thread-safe) → providers/* → Response
```

### Diagnostics (Real-time)

Published as you type ([`analyzer.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/analyzer/analyzer.go)):

| Category | Examples |
|----------|---------|
| Syntax errors | Invalid YAML, malformed condition expressions |
| Undefined references | Unknown macros or lists |
| Field validation | Unknown fields, fields not available for the rule's source type |
| Best practice hints | Dynamic fields requiring arguments |

Severity levels: Error, Warning, Hint, Info.

### Code Completion (Context-aware)

| Context | Completions Offered |
|---------|---------------------|
| Top-level | `rule`, `macro`, `list`, `required_engine_version`, `required_plugin_versions` |
| Rule properties | condition, output, priority, source, tags, exceptions, enabled, desc, append, override |
| Conditions | Falco fields (syscall, container, Kubernetes), operators, user-defined macros and lists |
| Priority values | EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, INFORMATIONAL, DEBUG |
| Source values | syscall, k8s_audit, aws_cloudtrail, gcp_auditlog, etc. |

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
- Trailing whitespace removal, blank line normalization

### Document Symbols

- Outline view of rules, macros, and lists in the current file

**Source:** [`falco-lsp/internal/lsp/README.md`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/lsp/README.md)

## 4. Parser and Analyzer

### YAML Parser

The parser ([`parser/parser.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/parser/parser.go)) extracts rules, macros, and lists from Falco rules YAML files with position tracking. Manages a coordinate system mismatch: YAML parsing uses 1-based lines / 1-based columns; LSP protocol uses 0-based lines / 0-based columns. The parser stores positions as 1-based lines with 0-based columns, converting at the YAML parsing boundary.

### Condition Parser

Recursive descent parser ([`condition/parser.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/condition/parser.go)) for condition expressions, producing an AST with operator precedence. AST types: `BinaryExpr`, `UnaryExpr`, `FieldExpr`, `Value` with `Position`/`Range` tracking.

### Semantic Analyzer

The analyzer ([`analyzer/analyzer.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/analyzer/analyzer.go)) performs cross-file symbol resolution, field validation, and macro/list reference checking.

### Supported Constructs

**Rule language elements:**

| Element | Properties |
|---------|-----------|
| Rules | name, desc, condition, output, priority, source, tags, enabled, append, override, exceptions, capture, capture_duration, warn_evttypes, skip-if-unknown-filter |
| Macros | name, condition, append |
| Lists | name, items[], append |
| Top-level | `required_engine_version`, `required_plugin_versions` |

**Condition expression operators:**

| Category | Operators |
|----------|----------|
| Logical | `and`, `or`, `not` |
| Comparison | `=`, `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Existence | `exists` |
| Set | `in`, `intersects` |
| String matching | `contains`, `icontains`, `bcontains`, `startswith`, `istartswith`, `bstartswith`, `endswith`, `iendswith`, `bendswith` |
| Pattern matching | `glob`, `iglob`, `regex`, `pmatch` |

## 5. Field Registry

Embedded JSON data for field lookup ([`fields/registry.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/fields/registry.go)):

| Source File | Coverage |
|-------------|----------|
| `syscall.json` | Process, thread, file descriptor, event, container, user fields |
| `k8saudit.json` | Kubernetes audit event fields |
| `plugins.json` | Plugin-provided fields |

Supports dynamic fields with wildcard patterns (e.g., `evt.arg.*`, `thread.cap_*`). Field lookup is source-aware -- a syscall field referenced in a `k8s_audit` rule produces a warning.

## 6. VS Code Extension

**Publisher:** falcosecurity
**Extension ID:** `falcosecurity.falco-rules`
**VS Code minimum:** ^1.85.0
**Package:** [`vscode-extension/`](../refs/falcosecurity/falco-lsp/vscode-extension/)

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

### Extension Commands

| Command | Description |
|---------|-------------|
| `falco.validate` | Validate current file |
| `falco.validateWorkspace` | Validate all Falco files in workspace |
| `falco.formatDocument` | Format current document |
| `falco.showOutput` | Show output channel |
| `falco.restartServer` | Restart language server |

Additional features: TextMate grammar for syntax highlighting, code snippets for rule/macro/list templates, JSON Schema validation synced from the official Falco repository.

**Source:** [`vscode-extension/package.json`](../refs/falcosecurity/falco-lsp/vscode-extension/package.json)

## 7. Implementation Details

| Aspect | Detail |
|--------|--------|
| Language | Go 1.22+, TypeScript (VS Code extension) |
| Dependencies | cobra (CLI), yaml.v3 (parser), fatih/color (output), testify (testing) |
| Binary name | `falco-lang` |
| Platforms | linux/amd64, linux/arm64, darwin/amd64, darwin/arm64, windows/amd64 |
| Test coverage | >85%, 43 test files |
| Linting | golangci-lint v2 |
| Extension build | esbuild, TypeScript 5.3+ |
| Distribution | GitHub Releases (binaries), VS Code Marketplace, Open VSX Registry |

### Core Packages

| Package | Purpose |
|---------|---------|
| [`parser/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/parser/) | YAML parser with position tracking |
| [`condition/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/condition/) | Recursive descent condition parser |
| [`lexer/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/lexer/) | Condition expression tokenizer |
| [`ast/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/ast/) | AST types with Position/Range tracking |
| [`analyzer/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/analyzer/) | Semantic analyzer, cross-file resolution |
| [`formatter/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/formatter/) | Code formatter |
| [`fields/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/fields/) | Embedded field registry |
| [`schema/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/schema/) | Block types and validation schemas |
| [`lsp/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/lsp/) | LSP server, message dispatch, document store |
| [`lsp/providers/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/lsp/providers/) | 9 feature provider sub-packages |

**Source:** [`go.mod`](../refs/falcosecurity/falco-lsp/falco-lsp/go.mod), [`Makefile`](../refs/falcosecurity/falco-lsp/falco-lsp/Makefile)

## 8. Related Specs

| Spec | Relationship |
|------|-------------|
| [`rule-engine.md`](rule-engine.md) | Falco rule YAML schema (falco-lsp validates against this) |
| [`filter-engine.md`](filter-engine.md) | Filter language and operators (falco-lsp parses condition expressions) |
| [`rules-content.md`](rules-content.md) | Detection rules content (what falco-lsp helps author) |
| [`plugin-system.md`](plugin-system.md) | Plugin-provided fields and event sources (included in field registry) |

## 9. Sources

| Topic | Source |
|-------|--------|
| Project overview | [`README.md`](../refs/falcosecurity/falco-lsp/README.md) |
| LSP architecture | [`falco-lsp/internal/lsp/README.md`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/lsp/README.md) |
| CLI entry point | [`falco-lsp/cmd/falco-lang/main.go`](../refs/falcosecurity/falco-lsp/falco-lsp/cmd/falco-lang/main.go) |
| Semantic analyzer | [`falco-lsp/internal/analyzer/analyzer.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/analyzer/analyzer.go) |
| Condition parser | [`falco-lsp/internal/condition/parser.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/condition/parser.go) |
| YAML parser | [`falco-lsp/internal/parser/parser.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/parser/parser.go) |
| Field registry | [`falco-lsp/internal/fields/registry.go`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/fields/registry.go) |
| VS Code extension | [`vscode-extension/package.json`](../refs/falcosecurity/falco-lsp/vscode-extension/package.json) |
| Digest | [`digests/falcosecurity/falco-lsp.md`](../digests/falcosecurity/falco-lsp.md) |
