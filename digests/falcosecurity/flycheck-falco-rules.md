# flycheck-falco-rules Digest

> **Era Relevance:** 0.44 (OUTDATED) | **Source:** [`refs/falcosecurity/flycheck-falco-rules/`](../../refs/falcosecurity/flycheck-falco-rules/) | **Commit:** `4bdc576` (October 20, 2023)

**Repository:** [falcosecurity/flycheck-falco-rules](https://github.com/falcosecurity/flycheck-falco-rules)
**Scope:** Ecosystem
**Status:** Incubating

---

## WARNING: OUTDATED AND POTENTIALLY BROKEN

**Last updated:** October 2023 (~2.5 years before era 0.43)

**This code may not work with current Falco versions due to:**
- Changes in Falco's JSON validation output format
- Changes in Docker image names or availability
- Changes in Falco CLI argument syntax
- Untested against Falco 0.43.x

**Use for:** Historical context, ideas for similar integrations, or as a starting point that likely requires updates.

**Do not expect this to work out of the box.** If you need Emacs integration for Falco rules, you may need to fork and update this code, or use alternative approaches (e.g., running `falco -V` manually or using LSP-based validation).

---

## Overview

Emacs [Flycheck](https://www.flycheck.org/) extension that provides on-the-fly syntax checking for Falco rules files (YAML). When editing rules in `yaml-mode`, errors and warnings from Falco's validation are displayed inline in the editor.

**Source:** [`README.md`](../../refs/falcosecurity/flycheck-falco-rules/README.md)

## How It Works

1. When a YAML file is saved/modified, Flycheck runs the configured validation command
2. Default command: `docker run --rm -v/tmp:/tmp falcosecurity/falco-no-driver falco -o json_output=True -V <file>`
3. Parses Falco's JSON validation output for errors and warnings
4. Displays errors inline with line/column information

**Source:** [`flycheck-falco-rules.el`](../../refs/falcosecurity/flycheck-falco-rules/flycheck-falco-rules.el)

## Installation (Historical)

### Via MELPA

```elisp
M-x package-install RET flycheck-falco-rules RET
```

Add to `.emacs`:
```elisp
(with-eval-after-load 'flycheck
  (add-hook 'flycheck-mode-hook #'flycheck-falco-rules-setup))
```

### Manual Installation

1. Copy `flycheck-falco-rules.el` to local elisp directory
2. Add to `.emacs`:
```elisp
(load "~/elisp/flycheck-falco-rules.el")
(with-eval-after-load 'flycheck
  (add-hook 'flycheck-mode-hook #'flycheck-falco-rules-setup))
```

**Source:** [`README.md`](../../refs/falcosecurity/flycheck-falco-rules/README.md)

## Configuration (Historical)

### Custom Validation Command

Override the Docker-based default to use a local Falco installation:

```elisp
M-x set-variable RET flycheck-falco-rules-validate-command RET falco -o json_output=True -V RET
```

Or in `.emacs`:
```elisp
(setq flycheck-falco-rules-validate-command "falco -o json_output=True -V")
```

**Source:** [`README.md`](../../refs/falcosecurity/flycheck-falco-rules/README.md)

## Technical Details

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `emacs` | >= 24.3 | GNU Emacs |
| `flycheck` | >= 0.25 | Syntax checking framework |
| `let-alist` | >= 1.0.1 | Alist destructuring |

**Source:** [`flycheck-falco-rules.el:24`](../../refs/falcosecurity/flycheck-falco-rules/flycheck-falco-rules.el)

### Default Validation Command

```
docker run --rm -v/tmp:/tmp falcosecurity/falco-no-driver falco -o json_output=True -V
```

**Potential issues with current era:**
- Image name might be different (check Docker Hub for current tags)
- Volume mount might need adjustment for rules file location
- JSON output format may have changed

**Source:** [`flycheck-falco-rules.el:34-41`](../../refs/falcosecurity/flycheck-falco-rules/flycheck-falco-rules.el)

### JSON Parsing

The extension parses Falco's validation JSON output looking for:
- `.falco_load_results[].errors[]` - Rule errors
- `.falco_load_results[].warnings[]` - Rule warnings
- `.context.locations[]` - Source location information

Each error/warning contains:
- `code` - Error code identifier
- `message` - Human-readable message
- `context.locations[].position.line` - Line number (0-indexed)
- `context.locations[].position.column` - Column number (0-indexed)

**Source:** [`flycheck-falco-rules.el:71-90`](../../refs/falcosecurity/flycheck-falco-rules/flycheck-falco-rules.el)

## Alternative Approaches (Modern)

If this extension doesn't work with current Falco, consider:

1. **Manual validation**: Run `falco -V <rules-file>` from terminal
2. **Compile command**: Configure Emacs `compile` to run Falco validation
3. **Shell script wrapper**: Create a script that wraps Falco validation and outputs in a format Flycheck can parse
4. **LSP integration**: If a Falco Language Server exists in the future

## Files

| File | Purpose |
|------|---------|
| `flycheck-falco-rules.el` | Main Emacs Lisp package |
| `Cask` | Package dependencies for development |
| `Makefile` | Build/test automation |
| `test/flycheck-falco-rules-test.el` | Unit tests |
| `test/example_warnings_error.yaml` | Test fixture |

**Source:** Repository file listing

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, installation | [`README.md`](../../refs/falcosecurity/flycheck-falco-rules/README.md) |
| Implementation | [`flycheck-falco-rules.el`](../../refs/falcosecurity/flycheck-falco-rules/flycheck-falco-rules.el) |

## Related Documentation

- [Flycheck Documentation](https://www.flycheck.org/)
- [MELPA Package](https://melpa.org/#/flycheck-falco-rules)
- [`falco/cli-reference.md`](falco/cli-reference.md) - Falco CLI including `-V` validation option
- [`falco/rule-language.md`](falco/rule-language.md) - Rules syntax reference
