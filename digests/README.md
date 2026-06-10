# Digests

AI-optimized summaries of the contents in [`refs/`](../refs/) and other sources.

## Structure

Most digests have a 1-1 relationship with a corresponding reference source in [`refs/`](../refs/).

## Contents

### [`falcosecurity/`](falcosecurity/)

Digests for the [falcosecurity](https://github.com/falcosecurity) GitHub organization repositories.

| Repository | Digests | Total Size | Era |
|------------|---------|------------|-----|
| [`.github`](falcosecurity/.github.md) | 1 file | ~10KB | 0.44 |
| [`charts`](falcosecurity/charts.md) | 1 file | ~15KB | 0.44 |
| [`client-go`](falcosecurity/client-go.md) | 1 file | ~8KB | 0.44 |
| [`community`](falcosecurity/community.md) | 1 file | ~17KB | 0.44 |
| [`contrib`](falcosecurity/contrib.md) | 1 file | ~8KB | 0.44 |
| [`dbg-go`](falcosecurity/dbg-go.md) | 1 file | ~13KB | 0.44 |
| [`deploy-kubernetes`](falcosecurity/deploy-kubernetes.md) | 1 file | ~15KB | 0.44 |
| [`driverkit`](falcosecurity/driverkit.md) | 1 file | ~20KB | 0.44 |
| [`event-generator`](falcosecurity/event-generator.md) | 1 file | ~14KB | 0.44 |
| [`evolution`](falcosecurity/evolution.md) | 1 file | ~24KB | 0.44 |
| [`falco/`](falcosecurity/falco/) | 7 files | ~124KB | 0.44 |
| [`falco-actions`](falcosecurity/falco-actions.md) | 1 file | ~15KB | 0.44 |
| [`falco-lsp`](falcosecurity/falco-lsp.md) | 1 file | ~12KB | 0.44 |
| [`falco-operator`](falcosecurity/falco-operator.md) | 1 file | ~10KB | 0.44 |
| [`falco-playground`](falcosecurity/falco-playground.md) | 1 file | ~10KB | 0.44 |
| [`falco-rustlings`](falcosecurity/falco-rustlings.md) | 1 file | ~10KB | 0.44 |
| [`falco-talon`](falcosecurity/falco-talon.md) | 1 file | ~16KB | 0.44 |
| [`falco-website/`](falcosecurity/falco-website/) | 6 files | ~120KB | 0.44 |
| [`falcoctl`](falcosecurity/falcoctl.md) | 1 file | ~26KB | 0.44 |
| [`falcosidekick/`](falcosecurity/falcosidekick/) | 2 files | ~32KB | 0.44 |
| [`falcosidekick-ui`](falcosecurity/falcosidekick-ui.md) | 1 file | ~8KB | 0.44 |
| [`flycheck-falco-rules`](falcosecurity/flycheck-falco-rules.md) | 1 file | ~6KB | 0.44 |
| [`k8s-metacollector`](falcosecurity/k8s-metacollector.md) | 1 file | ~25KB | 0.44 |
| [`kernel-crawler`](falcosecurity/kernel-crawler.md) | 1 file | ~13KB | 0.44 |
| [`kernel-testing`](falcosecurity/kernel-testing.md) | 1 file | ~12KB | 0.44 |
| [`libs/`](falcosecurity/libs/) | 12 files | ~208KB | 0.44 |
| [`pigeon`](falcosecurity/pigeon.md) | 1 file | ~9KB | 0.44 |
| [`plugin-sdk-cpp`](falcosecurity/plugin-sdk-cpp.md) | 1 file | ~25KB | 0.44 |
| [`plugin-sdk-go`](falcosecurity/plugin-sdk-go.md) | 1 file | ~18KB | 0.44 |
| [`plugin-sdk-rs`](falcosecurity/plugin-sdk-rs.md) | 1 file | ~18KB | 0.44 |
| [`plugins`](falcosecurity/plugins.md) + [`plugins/`](falcosecurity/plugins/) | 5 files | ~108KB | 0.44 |
| [`prempti`](falcosecurity/prempti.md) | 1 file | ~32KB | 0.44 |
| [`rules`](falcosecurity/rules.md) | 1 file | ~8KB | 0.44 |
| [`syscalls-bumper`](falcosecurity/syscalls-bumper.md) | 1 file | ~9KB | 0.44 |
| [`test-infra/`](falcosecurity/test-infra/) | 6 files | ~184KB | 0.44 |
| [`testing`](falcosecurity/testing.md) | 1 file | ~13KB | 0.44 |

### [`proposals/`](proposals/)

Digests for cross-repository proposals not yet merged into the main codebase.

| Proposal | Digest | Status | Era |
|----------|--------|--------|-----|
| Multi-Thread Falco | [`multi-thread-falco.md`](proposals/multi-thread-falco.md) | Open / WIP (not implemented) | Post-0.43 |

### [`falco-binary-report.md`](falco-binary-report.md)

Static analysis of the Falco binary installation.

| Report | Size | Era |
|--------|------|-----|
| [`falco-binary-report.md`](falco-binary-report.md) | ~8KB | 0.44 |

**Contents:** Version info, GLIBC requirements, library dependencies, plugin analysis, configuration defaults, system requirements, security features.

## Guidelines

- Summaries should be comprehensive enough to avoid information loss
- Summaries should fit within LLM context windows
- Can be updated as needed
- Serve as persistent memory for AI agents working with this repository
