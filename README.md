# Falco Expert

Falco Knowledge Base for AI Agents.

[Falco](https://falco.org) is the Cloud Native Runtime Security tool, part of the [CNCF](https://www.cncf.io/).

## Current Era: 0.44

Information in this repository corresponds to Falco version 0.44.x (released May 26, 2026).

## For Humans

Read the [Getting Started guide](GETTING-STARTED.md) for setup instructions and usage examples.

[![Falco Expert demo](https://asciinema.org/a/jAXq49rAEpVaUxZV.png)](https://asciinema.org/a/jAXq49rAEpVaUxZV)

> NOTE: This project is cumbersome and opinionated on purpose: it is optimized for accuracy, not for speed or resource consumption. Agents working with it re-read guidelines, consult the index before searching, and verify claims against the pinned sources — expect more tool calls and tokens in exchange for answers you can trust and verify. It has been mainly tested with Claude, but works nicely with Codex as well.

## For AI Agents

See [`AGENTS.md`](AGENTS.md) for detailed guidance on working with this repository.

## Setup

After cloning, initialize the git submodules to populate the [`refs/`](refs/) data sources:

```bash
make init
```

This is only needed if you want to access the original source repositories (e.g., to verify sources, create new digests, or run the Ingest workflow). The knowledge base content ([`digests/`](digests/), [`specs/`](specs/), [`skills/`](skills/), [`agents/`](agents/)) works without submodules.

## Table of Contents

### References ([`refs/`](refs/))

Data sources for the current era.

- [`falcosecurity/`](refs/falcosecurity/) - Official Falco GitHub organization (git submodules)
  - [`.github/`](refs/falcosecurity/.github/) - Default community health files, contributing guidelines
  - [`charts/`](refs/falcosecurity/charts/) - Helm charts for Kubernetes deployment
  - [`client-go/`](refs/falcosecurity/client-go/) - Go gRPC client for Falco outputs (DEPRECATED)
  - [`community/`](refs/falcosecurity/community/) - Community coordination, meeting notes
  - [`contrib/`](refs/falcosecurity/contrib/) - Community experiments (OUTDATED, UNTESTED)
  - [`dbg-go/`](refs/falcosecurity/dbg-go/) - Drivers Build Grid orchestration tool (Infra)
  - [`deploy-kubernetes/`](refs/falcosecurity/deploy-kubernetes/) - Pre-rendered Kubernetes manifests
  - [`driverkit/`](refs/falcosecurity/driverkit/) - CLI tool for building kernel modules and eBPF probes
  - [`event-generator/`](refs/falcosecurity/event-generator/) - Testing tool to generate suspect actions detected by Falco
  - [`evolution/`](refs/falcosecurity/evolution/) - Governance, repository map, maintainers
  - [`falco/`](refs/falcosecurity/falco/) - Main Falco repository (binary, engine, outputs)
  - [`falco-actions/`](refs/falcosecurity/falco-actions/) - GitHub Actions for CI/CD security (Sandbox, Experimental)
  - [`falco-lsp/`](refs/falcosecurity/falco-lsp/) - Language Server Protocol and VS Code extension for Falco rules (Incubating)
  - [`falco-operator/`](refs/falcosecurity/falco-operator/) - Kubernetes Operator for Falco (Incubating)
  - [`falco-playground/`](refs/falcosecurity/falco-playground/) - Browser-based rule validation using Falco Wasm (Sandbox, Experimental, Falco 0.37.1)
  - [`falco-website/`](refs/falcosecurity/falco-website/) - Source for [falco.org](https://falco.org)
  - [`falcoctl/`](refs/falcosecurity/falcoctl/) - Official CLI tool for Falco
  - [`falcosidekick/`](refs/falcosecurity/falcosidekick/) - Fan-out daemon for Falco events (70+ outputs)
  - [`falcosidekick-ui/`](refs/falcosecurity/falcosidekick-ui/) - Web UI for Falcosidekick events (Incubating)
  - [`falco-talon/`](refs/falcosecurity/falco-talon/) - Response Engine for Falco events (Incubating, Experimental)
  - [`flycheck-falco-rules/`](refs/falcosecurity/flycheck-falco-rules/) - Emacs Flycheck for Falco rules (OUTDATED)
  - [`k8s-metacollector/`](refs/falcosecurity/k8s-metacollector/) - Centralized Kubernetes metadata collector for Falco
  - [`kernel-crawler/`](refs/falcosecurity/kernel-crawler/) - Kernel version discovery for driver building (Infra)
  - [`kernel-testing/`](refs/falcosecurity/kernel-testing/) - Driver testing across kernels using Firecracker microVMs (Infra)
  - [`libs/`](refs/falcosecurity/libs/) - Core libraries (libscap, libsinsp) and drivers
  - [`plugin-sdk-cpp/`](refs/falcosecurity/plugin-sdk-cpp/) - C++ header-only SDK for building Falco plugins
  - [`plugin-sdk-go/`](refs/falcosecurity/plugin-sdk-go/) - Go SDK for building Falco plugins
  - [`plugin-sdk-rs/`](refs/falcosecurity/plugin-sdk-rs/) - Rust SDK for building Falco plugins
  - [`falco-rustlings/`](refs/falcosecurity/falco-rustlings/) - Interactive Rustlings exercises for Rust SDK learning
  - [`pigeon/`](refs/falcosecurity/pigeon/) - GitHub Actions secrets/variables management (Infra)
  - [`plugins/`](refs/falcosecurity/plugins/) - Plugin registry and official plugins monorepo
  - [`prempti/`](refs/falcosecurity/prempti/) - Falco-powered policy and visibility layer for AI coding agents (Sandbox, Experimental)
  - [`rules/`](refs/falcosecurity/rules/) - Official Falco detection rules
  - [`testing/`](refs/falcosecurity/testing/) - Regression test suite for Falco and its ecosystem
  - [`syscalls-bumper/`](refs/falcosecurity/syscalls-bumper/) - Syscall table automation for libs (Infra)
  - [`test-infra/`](refs/falcosecurity/test-infra/) - Test infrastructure, Prow CI/CD, Drivers Build Grid (Infra)
- [`cncf/`](refs/cncf/) - CNCF Foundation references
  - [`foundation/`](refs/cncf/foundation/) - CNCF Foundation policies, charter, and governance
- [`falco-binary-report.md`](refs/falco-binary-report.md) - Static analysis of local Falco binary installation
- [`proposals/`](refs/proposals/) - Cross-repository proposals (unmerged PRs, WIP)
  - [`multi-thread-falco/`](refs/proposals/multi-thread-falco/) - Multi-thread Falco initiative (3 proposals, post-0.43, not implemented)

### Digests ([`digests/`](digests/))

AI-optimized summaries of reference materials.

- [`falcosecurity/`](digests/falcosecurity/) - Digests for falcosecurity repositories
  - [`.github.md`](digests/falcosecurity/.github.md) - Contributing guidelines, security policy, code review
  - [`charts.md`](digests/falcosecurity/charts.md) - Helm charts, deployment patterns, configuration
  - [`client-go.md`](digests/falcosecurity/client-go.md) - Go gRPC client (DEPRECATED as of 0.43)
  - [`community.md`](digests/falcosecurity/community.md) - Community calls, blog guidelines, appreciation program
  - [`contrib.md`](digests/falcosecurity/contrib.md) - Community experiments (OUTDATED, UNTESTED, historical only)
  - [`dbg-go.md`](digests/falcosecurity/dbg-go.md) - Drivers Build Grid orchestration, config generation, S3 publishing (Infra)
  - [`deploy-kubernetes.md`](digests/falcosecurity/deploy-kubernetes.md) - Rendered manifests, pod structure, volumes
  - [`driverkit.md`](digests/falcosecurity/driverkit.md) - Driver build tool, targets, builder images
  - [`event-generator.md`](digests/falcosecurity/event-generator.md) - Testing tool, rule validation, benchmarking
  - [`evolution.md`](digests/falcosecurity/evolution.md) - Repository map, governance, maintainers, licensing
  - [`falco-actions.md`](digests/falcosecurity/falco-actions.md) - GitHub Actions for CI/CD security (Sandbox, real use case example)
  - [`falco-lsp.md`](digests/falcosecurity/falco-lsp.md) - LSP, CLI tool (falco-lang), VS Code extension for Falco rules (Incubating)
  - [`falco-operator.md`](digests/falcosecurity/falco-operator.md) - Kubernetes Operator, 5 CRDs (Falco, Component, Rulesfile, Plugin, Config), artifact management, reference protection (Incubating)
  - [`falco-playground.md`](digests/falcosecurity/falco-playground.md) - Browser-based rule validation, Falco Wasm proof-of-concept (Sandbox, Falco 0.37.1)
  - [`falco/`](digests/falcosecurity/falco/) - 6 digests (~115KB total)
    - [`README.md`](digests/falcosecurity/falco/README.md) - Overview and navigation
    - [`architecture.md`](digests/falcosecurity/falco/architecture.md) - Application lifecycle, event flow, libs integration
    - [`rule-language.md`](digests/falcosecurity/falco/rule-language.md) - Complete rule language specification
    - [`configuration.md`](digests/falcosecurity/falco/configuration.md) - Full configuration reference
    - [`outputs.md`](digests/falcosecurity/falco/outputs.md) - Alert output channels and formatting
    - [`cli-reference.md`](digests/falcosecurity/falco/cli-reference.md) - CLI options and introspection
    - [`proposals.md`](digests/falcosecurity/falco/proposals.md) - Design proposals, adoption/deprecation, roadmap
  - [`falco-website/`](digests/falcosecurity/falco-website/) - 5 digests (~120KB total)
    - [`docs.md`](digests/falcosecurity/falco-website/docs.md) - Core documentation
    - [`blog.md`](digests/falcosecurity/falco-website/blog.md) - Blog posts (with era markers)
    - [`about.md`](digests/falcosecurity/falco-website/about.md) - Use cases, FAQ, ecosystem
    - [`data.md`](digests/falcosecurity/falco-website/data.md) - Adopters, features, config reference
    - [`community.md`](digests/falcosecurity/falco-website/community.md) - Community info
  - [`falcoctl.md`](digests/falcosecurity/falcoctl.md) - CLI tool, OCI artifacts, driver management
  - [`falcosidekick/`](digests/falcosecurity/falcosidekick/) - 1 digest
    - [`README.md`](digests/falcosecurity/falcosidekick/README.md) - Overview, architecture, Falco integration
    - [`outputs.md`](digests/falcosecurity/falcosidekick/outputs.md) - Complete output reference (70+ integrations)
  - [`falcosidekick-ui.md`](digests/falcosecurity/falcosidekick-ui.md) - Web UI for event visualization (Incubating, limited curation)
  - [`falco-talon.md`](digests/falcosecurity/falco-talon.md) - Response Engine for automated threat response (Incubating, Experimental)
  - [`flycheck-falco-rules.md`](digests/falcosecurity/flycheck-falco-rules.md) - Emacs Flycheck plugin (OUTDATED, Oct 2023)
  - [`k8s-metacollector.md`](digests/falcosecurity/k8s-metacollector.md) - Centralized K8s metadata streaming service
  - [`kernel-crawler.md`](digests/falcosecurity/kernel-crawler.md) - Kernel version discovery for driver building (Infra)
  - [`kernel-testing.md`](digests/falcosecurity/kernel-testing.md) - Driver testing across kernels with Firecracker microVMs (Infra)
  - [`libs/`](digests/falcosecurity/libs/) - 11 digests (~206KB total)
    - [`README.md`](digests/falcosecurity/libs/README.md) - Overview and navigation
    - [`proposals-and-architecture.md`](digests/falcosecurity/libs/proposals-and-architecture.md) - Design proposals, versioning, roadmap
    - [`architecture.md`](digests/falcosecurity/libs/architecture.md) - Component relationships, event flow
    - [`kernel-instrumentation.md`](digests/falcosecurity/libs/kernel-instrumentation.md) - Syscall hooks, kmod vs eBPF, data flow
    - [`modern-bpf.md`](digests/falcosecurity/libs/modern-bpf.md) - Modern eBPF driver (DEFAULT), CO-RE
    - [`libscap.md`](digests/falcosecurity/libs/libscap.md) - System capture library
    - [`libsinsp.md`](digests/falcosecurity/libs/libsinsp.md) - System inspection library
    - [`filtering.md`](digests/falcosecurity/libs/filtering.md) - Filter language, operators, filterchecks
    - [`state-management.md`](digests/falcosecurity/libs/state-management.md) - State tables, plugin state API
    - [`scap-file-format.md`](digests/falcosecurity/libs/scap-file-format.md) - .scap capture file format
    - [`plugin-framework.md`](digests/falcosecurity/libs/plugin-framework.md) - Plugin API
    - [`api-reference.md`](digests/falcosecurity/libs/api-reference.md) - Event types, flags
  - [`plugin-sdk-cpp.md`](digests/falcosecurity/plugin-sdk-cpp.md) - C++ header-only plugin SDK, mixin architecture, state tables
  - [`plugin-sdk-go.md`](digests/falcosecurity/plugin-sdk-go.md) - Plugin SDK, interfaces, event handling
  - [`plugin-sdk-rs.md`](digests/falcosecurity/plugin-sdk-rs.md) - Rust plugin SDK, traits, strongly-typed events
  - [`falco-rustlings.md`](digests/falcosecurity/falco-rustlings.md) - Interactive Rustlings exercises, Sandbox status (January 2025)
  - [`prempti.md`](digests/falcosecurity/prempti.md) - Falco-powered policy and visibility layer for AI coding agents (Sandbox, Experimental Preview, Falco 0.43.0)
  - [`plugins/`](digests/falcosecurity/plugins/) - 5 digests (~115KB total)
    - [`../plugins.md`](digests/falcosecurity/plugins.md) - Plugin registry, key plugins overview, OCI distribution
    - [`container.md`](digests/falcosecurity/plugins/container.md) - Container plugin architecture and implementation
    - [`json.md`](digests/falcosecurity/plugins/json.md) - JSON extractor plugin for parsing JSON event payloads
    - [`k8saudit.md`](digests/falcosecurity/plugins/k8saudit.md) - K8s Audit plugin for Kubernetes audit event monitoring
    - [`k8smeta.md`](digests/falcosecurity/plugins/k8smeta.md) - K8s metadata enrichment plugin (gRPC client for k8s-metacollector)
  - [`pigeon.md`](digests/falcosecurity/pigeon.md) - GitHub Actions secrets/variables management from 1Password (Infra)
  - [`rules.md`](digests/falcosecurity/rules.md) - Detection rules, maturity framework, versioning
  - [`testing.md`](digests/falcosecurity/testing.md) - Regression test suite, test harness, CI integration
  - [`syscalls-bumper.md`](digests/falcosecurity/syscalls-bumper.md) - Syscall table automation for libs (Infra)
  - [`test-infra/`](digests/falcosecurity/test-infra/) - 5 digests (~165KB total)
    - [`README.md`](digests/falcosecurity/test-infra/README.md) - Overview and navigation
    - [`prow-infrastructure.md`](digests/falcosecurity/test-infra/prow-infrastructure.md) - Prow components, AWS EKS, deployment, images, tools
    - [`prow-config.md`](digests/falcosecurity/test-infra/prow-config.md) - Configuration reference, plugins, Tide, branch protection
    - [`prow-jobs.md`](digests/falcosecurity/test-infra/prow-jobs.md) - Job catalog and build system
    - [`github-org-management.md`](digests/falcosecurity/test-infra/github-org-management.md) - org.yaml, Peribolos, Poiana bot, teams
    - [`drivers-build-grid.md`](digests/falcosecurity/test-infra/drivers-build-grid.md) - DBG architecture, driver distribution
- [`cncf/`](digests/cncf/) - Digests for CNCF Foundation references
  - [`foundation.md`](digests/cncf/foundation.md) - CNCF IP policy, allowed licenses, container image guidance, copyright notices
- [`falco-binary-report.md`](digests/falco-binary-report.md) - Static analysis of Falco binary (versions, dependencies, GLIBC, plugins)
- [`proposals/`](digests/proposals/) - Cross-repository proposal digests
  - [`multi-thread-falco.md`](digests/proposals/multi-thread-falco.md) - Multi-thread Falco initiative (post-0.43, not implemented, 3 proposals)

### Specifications ([`specs/`](specs/))

Implementation-focused technical specifications (24 specs).

- [`README.md`](specs/README.md) - Navigation hub, component map, reading order, dependency graph
- [`architecture-overview.md`](specs/architecture-overview.md) - System architecture, event pipeline, threading model
- [`kernel-instrumentation.md`](specs/kernel-instrumentation.md) - Modern eBPF, kmod, syscall capture, event model
- [`libscap.md`](specs/libscap.md) - System capture library, engine vtable, ring buffers, statistics
- [`libsinsp.md`](specs/libsinsp.md) - Event parsing, state tables, thread/FD tracking, plugin integration
- [`filter-engine.md`](specs/filter-engine.md) - Filter language, AST, operators, transformers, complete field reference
- [`rule-engine.md`](specs/rule-engine.md) - Rule YAML schema, compilation pipeline, exceptions, ruleset management
- [`configuration.md`](specs/configuration.md) - Config system, merging, all keys with types/defaults/maturity
- [`output-system.md`](specs/output-system.md) - Alert channels, async queue, formatting, timeout handling
- [`plugin-system.md`](specs/plugin-system.md) - Plugin API, five capabilities, lifecycle, state tables, official plugins
- [`metrics-and-observability.md`](specs/metrics-and-observability.md) - Internal metrics, stats, Prometheus, health monitoring
- [`application-lifecycle.md`](specs/application-lifecycle.md) - App actions, startup/teardown, signal handling, hot reload
- [`cli-interface.md`](specs/cli-interface.md) - CLI flags, introspection commands, exit codes
- [`falcoctl.md`](specs/falcoctl.md) - Artifact/driver management, OCI distribution, Kubernetes integration
- [`build-system.md`](specs/build-system.md) - CMake structure, dependencies, feature flags
- [`kubernetes-deployment.md`](specs/kubernetes-deployment.md) - Helm charts, DaemonSet/Deployment, pod architecture, RBAC
- [`rules-content.md`](specs/rules-content.md) - Detection rules, maturity framework, tuning patterns, release process
- [`falcosidekick.md`](specs/falcosidekick.md) - Fan-out daemon, FalcoPayload data model, 70+ output integrations
- [`falco-operator.md`](specs/falco-operator.md) - Kubernetes Operator, 5 CRDs, instance lifecycle and artifact management
- [`falco-lsp.md`](specs/falco-lsp.md) - Language Server, CLI tool (falco-lang), VS Code extension for Falco rules
- [`falco-talon.md`](specs/falco-talon.md) - Response Engine, actionners, automated threat response in Kubernetes
- [`driver-distribution.md`](specs/driver-distribution.md) - Pre-built driver pipeline, kernel-crawler, driverkit, S3 distribution
- [`ci-cd-infrastructure.md`](specs/ci-cd-infrastructure.md) - Prow components, AWS EKS, Tide merge automation, Pigeon secrets
- [`ci-cd-jobs.md`](specs/ci-cd-jobs.md) - Prow job catalog, GitHub org management, OWNERS workflow
- [`ci-cd-github-actions.md`](specs/ci-cd-github-actions.md) - Falco Actions for CI/CD security, testing regression suite

### Skills ([`skills/`](skills/))

AI agent skills following [agentskills.io](https://agentskills.io/) specification.

- [`falco-cli/`](skills/falco-cli/) - Use Falco CLI for validation, introspection, and binary analysis without daemon mode
- [`falco-dev/`](skills/falco-dev/) - Develop, build, test, and debug Falco core components using a devcontainer
- [`falco-rules-author/`](skills/falco-rules-author/) - Author, validate, test, and iteratively tune Falco detection rules with Docker-based feedback loops
- [`falco-triage/`](skills/falco-triage/) - Triage GitHub issues and PRs across falcosecurity repositories with knowledge-base-backed analysis
- [`falco-reviewer/`](skills/falco-reviewer/) - Review PRs across falcosecurity repositories as a ghost writer for Falco maintainers, with security review and breaking change analysis

#### Installing Skills for Claude Code

Clone this repository (skip if already cloned):

```bash
git clone https://github.com/leogr/falco-expert.git
```

Install individual skills by symlinking each skill directory:

```bash
mkdir -p ~/.claude/skills
ln -s "$(cd falco-expert && pwd)/skills/falco-cli" ~/.claude/skills/falco-cli
ln -s "$(cd falco-expert && pwd)/skills/falco-dev" ~/.claude/skills/falco-dev
ln -s "$(cd falco-expert && pwd)/skills/falco-rules-author" ~/.claude/skills/falco-rules-author
ln -s "$(cd falco-expert && pwd)/skills/falco-triage" ~/.claude/skills/falco-triage
ln -s "$(cd falco-expert && pwd)/skills/falco-reviewer" ~/.claude/skills/falco-reviewer
```

### Agents ([`agents/`](agents/))

Pre-built AI agents powered by this knowledge base.

- [`falco-expert.md`](agents/falco-expert.md) - Comprehensive Falco expert agent for [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

#### Installing the Agent for Claude Code

Clone this repository (skip if already cloned):

```bash
git clone https://github.com/leogr/falco-expert.git
```

Install the [`falco-expert`](agents/falco-expert.md) agent:

```bash
mkdir -p ~/.claude/agents
ln -s "$(cd falco-expert && pwd)/agents/falco-expert.md" ~/.claude/agents/falco-expert.md
```

Allow Claude Code to read the knowledge base without prompting (recommended for background agent execution). Add this to your `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Read(//<absolute-path-to-falco-expert>/**)"
    ]
  }
}
```

Replace `<absolute-path-to-falco-expert>` with the output of `cd falco-expert && pwd`. Note the `//` prefix for absolute paths.

Verify by running `/agents` in Claude Code.

> **Note:** The agent already includes all five skills. Installing skills separately is only needed if you want to use them without the agent.

### Workflows ([`WORKFLOWS.md`](WORKFLOWS.md))

Predefined procedures for common operations.

| Workflow | Purpose |
|----------|---------|
| [Dig Deeper](WORKFLOWS.md#dig-deeper) | Extract factual, verifiable information from the knowledge base |
| [Ingest](WORKFLOWS.md#ingest) | Add new content to the knowledge base and produce its digest |
| [Era Transition](WORKFLOWS.md#era-transition) | Transition the knowledge base to a new Falco release era |
