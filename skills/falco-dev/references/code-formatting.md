# Code Formatting, Commit Conventions, and Licensing

Standards for contributing to falcosecurity repositories.

---

## Pre-commit Hooks (Mandatory for falco and libs)

Both `falco` and `libs` use the [pre-commit](https://pre-commit.com/) framework with three hooks:

| Hook | Version | Purpose |
|------|---------|---------|
| `clang-format` | v18.1.8 | Formats C/C++ source files (`.c`, `.h`, `.cpp`) |
| `cmake-format` | v0.6.13 | Formats CMake files (`.cmake`, `CMakeLists.txt`) |
| DCO sign-off | local script | Appends `Signed-off-by:` line to commit messages |

Formatting is **mandatory in CI** -- PRs will fail if code is not properly formatted.

**Source:** `.pre-commit-config.yaml`, `.clang-format`, `.cmake-format.json` in each repo

### Automatic Installation

`setup-workspace` automatically installs pre-commit hooks when cloning repositories. For repos that already exist (e.g., bind-mounted from host), use the `--install-hooks` option:

```bash
docker exec -u dev $CONTAINER_NAME setup-workspace --install-hooks           # All repos
docker exec -u dev $CONTAINER_NAME setup-workspace --install-hooks falco     # Specific repo
```

Or install manually:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/falco
  pre-commit install --install-hooks --hook-type pre-commit --overwrite
  pre-commit install --install-hooks --hook-type prepare-commit-msg --overwrite
"
```

### Verifying Formatting

**Before committing**, always run the format check:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/falco
  pre-commit run --all-files
"
```

If formatting fails, `pre-commit` automatically fixes the files. Stage the fixes (`git add`) and retry the commit.

---

## Commit Conventions

All falcosecurity repositories require:

- **DCO sign-off**: Every commit must include a `Signed-off-by:` line -- use `git commit -s`. The DCO pre-commit hook automates this if installed.
- **Conventional Commits**: Commit messages must follow [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):
  - `fix:` for bug fixes
  - `feat:` (or `new:`) for new features
  - Other types: `refactor:`, `docs:`, `test:`, `chore:`, etc.
  - `!` or `BREAKING CHANGE:` footer for breaking changes
- **Rebase-only**: Use `git rebase` (not merge) to resolve conflicts; push with `--force-with-lease`

**Source:** [`refs/falcosecurity/.github/CONTRIBUTING.md`](../../../refs/falcosecurity/.github/CONTRIBUTING.md)

---

## Copyright Year in License Headers (Mandatory)

When creating a new file or editing an existing file that has (or should have) a license header, always ensure the copyright year is current.

**Expected format:**

```
// SPDX-License-Identifier: Apache-2.0
/*
Copyright (C) YYYY The Falco Authors.

...
*/
```

Where `YYYY` is the **current year** (verify with `date +%Y`).

| Action | What to Do |
|--------|-----------|
| **Creating a new file** | Add the full license header with the current year |
| **Editing a file with an outdated year** | Update the year to the current year |
| **Editing a file with the current year** | No change needed |
| **Files without license headers** | Follow the conventions of the specific repository |

> **Do NOT blindly update all files** in the repo. Only update the copyright year in files you are creating or meaningfully editing as part of the current task.

**Source:** [GOVERNANCE.md, Section License](../../../refs/falcosecurity/evolution/GOVERNANCE.md), [CNCF Copyright Notices](../../../refs/cncf/foundation/copyright-notices.md)

---

## C++ Coding Style (falco and libs)

Both repositories share identical formatting configuration and naming conventions:

| Convention | Rule |
|-----------|------|
| Naming | `snake_case` for variables and functions |
| Member variables | `m_` prefix (e.g., `m_counter`) |
| Global variables | `g_` prefix (e.g., `g_nplugins`) |
| Indentation | Tabs (width 4) for indentation, spaces for alignment |
| Line width | 100 characters max |
| Braces | Attached / K&R style (opening brace on same line) |
| Include sorting | Disabled (`SortIncludes: Never`) -- preserve existing order |
| Include paths (libs) | Absolute: `<libsinsp/sinsp.h>`, not `"sinsp.h"` |
| Banned C APIs | `strcpy`, `stpcpy`, `strcat`, `wcscpy`, `wcpcpy`, `wcscat`, `sprintf`, `vsprintf` -- use safe alternatives (`strlcpy`, `snprintf`) |
| License header | SPDX identifier required: `// SPDX-License-Identifier: Apache-2.0` |

> **Banned APIs are enforced by Semgrep in CI.** Using `strcpy`, `sprintf`, `strcat`, or similar insecure functions will cause CI to fail. See [`refs/falcosecurity/falco/semgrep/`](../../../refs/falcosecurity/falco/semgrep/) for the exact rules.

**Source:** [`refs/falcosecurity/falco/Contributing.md`](../../../refs/falcosecurity/falco/Contributing.md), [`refs/falcosecurity/falco/.clang-format`](../../../refs/falcosecurity/falco/.clang-format)

---

## Third-Party License Verification (Mandatory)

When adding a new third-party library or dependency, you MUST verify its license is compatible with the Falco project requirements **before** adding it.

### License Requirements

All Falco code is licensed under **Apache-2.0**. Third-party dependencies must be compatible. Per [GOVERNANCE.md](../../../refs/falcosecurity/evolution/GOVERNANCE.md), dependencies must either:

1. Be licensed under **Apache-2.0**, or
2. Be licensed under one of the **CNCF Approved Licenses**, or
3. Have an approved **CNCF Governing Board exception**

### CNCF Approved Licenses (Allowlist)

`0BSD`, `BSD-2-Clause`, `BSD-2-Clause-FreeBSD`, `BSD-3-Clause`, `MIT`, `MIT-0`, `ISC`, `OpenSSL`, `OpenSSL-standalone`, `PSF-2.0`, `Python-2.0`, `Python-2.0.1`, `PostgreSQL`, `SSLeay-standalone`, `UPL-1.0`, `X11`, `Zlib`, [Google patent license for Golang](https://golang.org/PATENTS)

### Licenses That Require Exceptions

| License | Notes |
|---------|-------|
| **LGPL** (any version) | Falco has an exception for `libelf` (dynamic linking only) |
| **GPL** (any version) | Falco's kernel module is dual-licensed `GPL-2.0-only OR MIT` (exception approved) |
| **MPL-2.0** | Some HashiCorp packages had exceptions |
| **curl License** | Falco has an exception for `libcurl` (statically linked) |

### Verification Process

1. **Identify the license**: Check the dependency's `LICENSE` file, `go.mod`, `package.json`, or `CMakeLists.txt`
2. **Check against the allowlist**: Is it Apache-2.0 or on the CNCF approved list?
3. **If approved**: Proceed. Note the license in your commit message or PR description
4. **If NOT approved**: **Stop and inform the user.** Suggest alternatives with compatible licenses.
5. **Never add a dependency with an incompatible license** without explicit user acknowledgment

**Source:** [`digests/cncf/foundation.md`](../../../digests/cncf/foundation.md), [`digests/falcosecurity/evolution.md`](../../../digests/falcosecurity/evolution.md)
