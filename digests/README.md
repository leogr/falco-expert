# Digests

AI-optimized summaries of the contents in [`refs/`](../refs/) and other sources.

## Structure

Most digests have a 1-1 relationship with a corresponding reference source in [`refs/`](../refs/).

## Contents

The Era column records the source-review era. Historical and deprecated components retain their explicit applicability notes; the binary report below remains a 0.44 snapshot.

### [`falcosecurity/`](falcosecurity/)

Digests for the [falcosecurity](https://github.com/falcosecurity) GitHub organization repositories.

| Repository | Digests | Total Size | Era |
|------------|---------|------------|-----|
| [`.github`](falcosecurity/.github.md) | 1 file | ~11KB | 0.45 |
| [`charts`](falcosecurity/charts.md) | 1 file | ~18KB | 0.45 |
| [`client-go`](falcosecurity/client-go.md) | 1 file | ~8KB | 0.45 |
| [`community`](falcosecurity/community.md) | 1 file | ~17KB | 0.45 |
| [`contrib`](falcosecurity/contrib.md) | 1 file | ~8KB | 0.45 |
| [`dbg-go`](falcosecurity/dbg-go.md) | 1 file | ~14KB | 0.45 |
| [`deploy-kubernetes`](falcosecurity/deploy-kubernetes.md) | 1 file | ~33KB | 0.45 |
| [`driverkit`](falcosecurity/driverkit.md) | 1 file | ~21KB | 0.45 |
| [`event-generator`](falcosecurity/event-generator.md) | 1 file | ~15KB | 0.45 |
| [`evolution`](falcosecurity/evolution.md) | 1 file | ~24KB | 0.45 |
| [`falco/`](falcosecurity/falco/) | 7 files | ~123KB | 0.45 |
| [`falco-actions`](falcosecurity/falco-actions.md) | 1 file | ~15KB | 0.45 |
| [`falco-lsp`](falcosecurity/falco-lsp.md) | 1 file | ~12KB | 0.45 |
| [`falco-operator`](falcosecurity/falco-operator.md) | 1 file | ~29KB | 0.45 |
| [`falco-playground`](falcosecurity/falco-playground.md) | 1 file | ~10KB | 0.45 |
| [`falco-rustlings`](falcosecurity/falco-rustlings.md) | 1 file | ~10KB | 0.45 |
| [`falco-talon`](falcosecurity/falco-talon.md) | 1 file | ~17KB | 0.45 |
| [`falco-website/`](falcosecurity/falco-website/) | 6 files | ~133KB | 0.45 |
| [`falcoctl`](falcosecurity/falcoctl.md) | 1 file | ~28KB | 0.45 |
| [`falcosidekick/`](falcosecurity/falcosidekick/) | 2 files | ~30KB | 0.45 |
| [`falcosidekick-ui`](falcosecurity/falcosidekick-ui.md) | 1 file | ~9KB | 0.45 |
| [`flycheck-falco-rules`](falcosecurity/flycheck-falco-rules.md) | 1 file | ~5KB | 0.45 |
| [`k8s-metacollector`](falcosecurity/k8s-metacollector.md) | 1 file | ~26KB | 0.45 |
| [`kernel-crawler`](falcosecurity/kernel-crawler.md) | 1 file | ~14KB | 0.45 |
| [`kernel-testing`](falcosecurity/kernel-testing.md) | 1 file | ~12KB | 0.45 |
| [`libs/`](falcosecurity/libs/) | 12 files | ~218KB | 0.45 |
| [`pigeon`](falcosecurity/pigeon.md) | 1 file | ~9KB | 0.45 |
| [`plugin-sdk-cpp`](falcosecurity/plugin-sdk-cpp.md) | 1 file | ~25KB | 0.45 |
| [`plugin-sdk-go`](falcosecurity/plugin-sdk-go.md) | 1 file | ~18KB | 0.45 |
| [`plugin-sdk-rs`](falcosecurity/plugin-sdk-rs.md) | 1 file | ~19KB | 0.45 |
| [`plugins`](falcosecurity/plugins.md) + [`plugins/`](falcosecurity/plugins/) | 6 files | ~117KB | 0.45 |
| [`prempti`](falcosecurity/prempti.md) | 1 file | ~31KB | 0.45 |
| [`rules`](falcosecurity/rules.md) | 1 file | ~9KB | 0.45 |
| [`syscalls-bumper`](falcosecurity/syscalls-bumper.md) | 1 file | ~9KB | 0.45 |
| [`test-infra/`](falcosecurity/test-infra/) | 6 files | ~177KB | 0.45 |
| [`testing`](falcosecurity/testing.md) | 1 file | ~14KB | 0.45 |

### [`cncf/`](cncf/)

| Repository | Digest | Era |
|------------|--------|-----|
| CNCF Foundation | [`foundation.md`](cncf/foundation.md) | 0.45 |

### [`proposals/`](proposals/)

Digests for cross-repository proposals not yet merged into the main codebase.

| Proposal | Digest | Status | Era |
|----------|--------|--------|-----|
| Multi-Thread Falco | [`multi-thread-falco.md`](proposals/multi-thread-falco.md) | Open / WIP (not implemented) | 0.45 baseline; historical proposals |

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
