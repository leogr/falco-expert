# falcosecurity

This folder mirrors the structure of the [falcosecurity](https://github.com/falcosecurity) GitHub organization.

**https://github.com/falcosecurity** is the Falco project's official GitHub organization, hosting all the codebase and serving as the ultimate source of truth for all information.

## Repositories

> **Era 0.44**: This tree is pinned to era 0.44. Do not update [`refs/`](../) until transitioning to a new era (see the [Era Transition](../../WORKFLOWS.md#era-transition) workflow).

Use `git submodule status` from the repo root to see the exact pinned commit and tag for every repository in this directory. This is the canonical source for commit, branch, and date metadata — do not hand-maintain per-repo metadata here.

| Repository | Description |
|------------|-------------|
| [`.github/`](.github/) | Default community health files, contributing guidelines |
| [`charts/`](charts/) | Helm charts for Kubernetes deployment |
| [`client-go/`](client-go/) | Go gRPC client for Falco outputs (DEPRECATED) |
| [`community/`](community/) | Community coordination, meeting notes |
| [`contrib/`](contrib/) | Community experiments (OUTDATED, UNTESTED) |
| [`dbg-go/`](dbg-go/) | Drivers Build Grid orchestration tool (Infra) |
| [`deploy-kubernetes/`](deploy-kubernetes/) | Pre-rendered Kubernetes manifests |
| [`driverkit/`](driverkit/) | CLI tool for building kernel modules and eBPF probes |
| [`event-generator/`](event-generator/) | Testing tool to generate suspect actions detected by Falco |
| [`evolution/`](evolution/) | Governance, repository map, maintainers |
| [`falco/`](falco/) | Main Falco repository (binary, engine, outputs) |
| [`falco-actions/`](falco-actions/) | GitHub Actions for CI/CD security (Sandbox, Experimental) |
| [`falco-lsp/`](falco-lsp/) | Language Server Protocol and VS Code extension for Falco rules (Incubating) |
| [`falco-operator/`](falco-operator/) | Kubernetes Operator for Falco (Incubating) |
| [`falco-playground/`](falco-playground/) | Browser-based rule validation using Falco Wasm (Sandbox, Experimental, Falco 0.37.1) |
| [`falco-rustlings/`](falco-rustlings/) | Interactive Rustlings exercises for Rust SDK learning |
| [`falcosidekick/`](falcosidekick/) | Fan-out daemon for Falco events (70+ outputs) |
| [`falcosidekick-ui/`](falcosidekick-ui/) | Web UI for Falcosidekick events (Incubating) |
| [`falco-talon/`](falco-talon/) | Response Engine for Falco events (Incubating, Experimental) |
| [`falco-website/`](falco-website/) | Source for [falco.org](https://falco.org) |
| [`falcoctl/`](falcoctl/) | Official CLI tool for Falco |
| [`flycheck-falco-rules/`](flycheck-falco-rules/) | Emacs Flycheck for Falco rules (OUTDATED) |
| [`k8s-metacollector/`](k8s-metacollector/) | Centralized Kubernetes metadata collector for Falco |
| [`kernel-crawler/`](kernel-crawler/) | Kernel version discovery for driver building (Infra) |
| [`kernel-testing/`](kernel-testing/) | Driver testing across kernels using Firecracker microVMs (Infra) |
| [`libs/`](libs/) | Core libraries (libscap, libsinsp) and drivers |
| [`pigeon/`](pigeon/) | GitHub Actions secrets/variables management (Infra) |
| [`plugins/`](plugins/) | Plugin registry and official plugins monorepo |
| [`plugin-sdk-cpp/`](plugin-sdk-cpp/) | C++ header-only SDK for building Falco plugins |
| [`plugin-sdk-go/`](plugin-sdk-go/) | Go SDK for building Falco plugins |
| [`plugin-sdk-rs/`](plugin-sdk-rs/) | Rust SDK for building Falco plugins |
| [`prempti/`](prempti/) | Falco-powered policy and visibility layer for AI coding agents (Sandbox, Experimental Preview) |
| [`rules/`](rules/) | Official Falco detection rules |
| [`syscalls-bumper/`](syscalls-bumper/) | Syscall table automation for libs (Infra) |
| [`test-infra/`](test-infra/) | Test infrastructure, Prow CI/CD, Drivers Build Grid (Infra) |
| [`testing/`](testing/) | Regression test suite for Falco and its ecosystem |

## Key Files

The [`evolution/`](evolution/) repository defines the organization structure and is the canonical source for repository mapping:

- [`repositories.yaml`](evolution/repositories.yaml) - Master index of all repos with scope and status
- [`maintainers.yaml`](evolution/maintainers.yaml) - Maintainer registry
- [`GOVERNANCE.md`](evolution/GOVERNANCE.md) - Project governance model
