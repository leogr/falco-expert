# Specifications

> Implementation-focused technical specifications of Falco, enabling the workflow: **modify spec → modify implementation**.

**Era:** 0.44 (released May 26, 2026)

## Component Map

```
┌─────────────────────────────────────────────────────────────────┐
│                        Falco Application                        │
│  ┌───────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ Rule Engine   │  │ Output System│  │ App Lifecycle        │ │
│  │ rule-engine   │  │ output-system│  │ application-lifecycle│ │
│  └───────┬───────┘  └──────┬───────┘  └──────────────────────┘ │
│          │                 │                                    │
│  ┌───────┴─────────────────┴──────────────────────────────────┐ │
│  │ Configuration: configuration    CLI: cli-interface          │ │
│  │ Metrics: metrics-and-observability                         │ │
│  └────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                      falcosecurity/libs                         │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐  │
│  │ Filter Engine  │  │ libsinsp       │  │ libscap          │  │
│  │ filter-engine  │  │ libsinsp       │  │ libscap          │  │
│  └────────┬───────┘  └────────┬───────┘  └────────┬─────────┘  │
│           └──────────┬────────┘                    │            │
│                      │                             │            │
│  ┌───────────────────┴─────────────────────────────┘           │
│  │ Plugin System: plugin-system                                │
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│  Kernel Driver: kernel-instrumentation                          │
├─────────────────────────────────────────────────────────────────┤
│  External Tools                                                 │
│  ┌───────────────┐  ┌──────────────┐                           │
│  │ falcoctl      │  │ Build System │                           │
│  │ falcoctl      │  │ build-system │                           │
│  └───────────────┘  └──────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
```

## Spec Files

### Reading Order (recommended)

Follow the event pipeline from bottom to top, then application concerns:

| # | Spec | Description |
|---|------|-------------|
| 1 | [`architecture-overview.md`](architecture-overview.md) | System architecture, event pipeline, threading model |
| 2 | [`kernel-instrumentation.md`](kernel-instrumentation.md) | Modern eBPF, kmod, syscall capture, event model |
| 3 | [`libscap.md`](libscap.md) | System capture library, engine vtable, ring buffers |
| 4 | [`libsinsp.md`](libsinsp.md) | Event parsing, state tables, thread/FD tracking |
| 5 | [`filter-engine.md`](filter-engine.md) | Filter language, AST, operators, filterchecks |
| 6 | [`rule-engine.md`](rule-engine.md) | Rule YAML schema, compilation pipeline, indexing |
| 7 | [`configuration.md`](configuration.md) | Config system, merging, JSON schema validation |
| 8 | [`output-system.md`](output-system.md) | Alert channels, async queue, formatting |
| 9 | [`plugin-system.md`](plugin-system.md) | Plugin API, capabilities, lifecycle |
| 10 | [`metrics-and-observability.md`](metrics-and-observability.md) | Internal metrics, stats, health monitoring |
| 11 | [`application-lifecycle.md`](application-lifecycle.md) | App actions, signal handling, hot reload |
| 12 | [`cli-interface.md`](cli-interface.md) | CLI flags, introspection, exit codes |
| 13 | [`falcoctl.md`](falcoctl.md) | Artifact/driver management, OCI distribution |
| 14 | [`build-system.md`](build-system.md) | CMake, dependencies, feature flags |
| 15 | [`kubernetes-deployment.md`](kubernetes-deployment.md) | Helm charts, DaemonSet/Deployment, pod architecture |
| 16 | [`rules-content.md`](rules-content.md) | Detection rules, maturity framework, tuning |
| 17 | [`falcosidekick.md`](falcosidekick.md) | Fan-out daemon, FalcoPayload, 70+ outputs |
| 18 | [`falco-operator.md`](falco-operator.md) | Kubernetes Operator, 5 CRDs, instance/artifact management |
| 19 | [`falco-lsp.md`](falco-lsp.md) | Language Server, CLI tool, VS Code extension for rules |
| 20 | [`falco-talon.md`](falco-talon.md) | Response Engine, actionners, automated threat response |
| 21 | [`driver-distribution.md`](driver-distribution.md) | Pre-built driver pipeline, kernel-crawler, driverkit |
| 22 | [`ci-cd-infrastructure.md`](ci-cd-infrastructure.md) | Prow components, AWS EKS, config, Tide, Pigeon |
| 23 | [`ci-cd-jobs.md`](ci-cd-jobs.md) | Job catalog, org management, OWNERS workflow |
| 24 | [`ci-cd-github-actions.md`](ci-cd-github-actions.md) | Falco Actions, CI/CD rules, testing suite |

### Quick Reference

| Spec File | Primary Source Repo | Key Source Files | Digest Files |
|-----------|-------------------|------------------|--------------|
| [`architecture-overview.md`](architecture-overview.md) | `falco`, `libs` | [`app/app.cpp`](../refs/falcosecurity/falco/userspace/falco/app/app.cpp), [`app/state.h`](../refs/falcosecurity/falco/userspace/falco/app/state.h) | [`falco/architecture.md`](../digests/falcosecurity/falco/architecture.md), [`libs/architecture.md`](../digests/falcosecurity/libs/architecture.md) |
| [`kernel-instrumentation.md`](kernel-instrumentation.md) | `libs` | [`driver/modern_bpf/`](../refs/falcosecurity/libs/driver/modern_bpf/), [`driver/ppm_events_public.h`](../refs/falcosecurity/libs/driver/ppm_events_public.h) | [`libs/kernel-instrumentation.md`](../digests/falcosecurity/libs/kernel-instrumentation.md), [`libs/modern-bpf.md`](../digests/falcosecurity/libs/modern-bpf.md) |
| [`libscap.md`](libscap.md) | `libs` | [`userspace/libscap/`](../refs/falcosecurity/libs/userspace/libscap/) | [`libs/libscap.md`](../digests/falcosecurity/libs/libscap.md) |
| [`libsinsp.md`](libsinsp.md) | `libs` | [`userspace/libsinsp/`](../refs/falcosecurity/libs/userspace/libsinsp/) | [`libs/libsinsp.md`](../digests/falcosecurity/libs/libsinsp.md), [`libs/state-management.md`](../digests/falcosecurity/libs/state-management.md) |
| [`filter-engine.md`](filter-engine.md) | `libs` | [`userspace/libsinsp/filter/`](../refs/falcosecurity/libs/userspace/libsinsp/filter/) | [`libs/filtering.md`](../digests/falcosecurity/libs/filtering.md) |
| [`rule-engine.md`](rule-engine.md) | `falco` | [`userspace/engine/`](../refs/falcosecurity/falco/userspace/engine/) | [`falco/rule-language.md`](../digests/falcosecurity/falco/rule-language.md) |
| [`configuration.md`](configuration.md) | `falco` | [`falco.yaml`](../refs/falcosecurity/falco/falco.yaml), [`configuration.cpp`](../refs/falcosecurity/falco/userspace/falco/configuration.cpp) | [`falco/configuration.md`](../digests/falcosecurity/falco/configuration.md) |
| [`output-system.md`](output-system.md) | `falco` | [`falco_outputs.h`](../refs/falcosecurity/falco/userspace/falco/falco_outputs.h) | [`falco/outputs.md`](../digests/falcosecurity/falco/outputs.md) |
| [`plugin-system.md`](plugin-system.md) | `libs`, `plugins` | [`userspace/libsinsp/plugin*.cpp`](../refs/falcosecurity/libs/userspace/libsinsp/) | [`libs/plugin-framework.md`](../digests/falcosecurity/libs/plugin-framework.md), [`plugins.md`](../digests/falcosecurity/plugins.md) |
| [`metrics-and-observability.md`](metrics-and-observability.md) | `falco`, `libs` | [`falco_metrics.cpp`](../refs/falcosecurity/falco/userspace/falco/falco_metrics.cpp) | [`falco/architecture.md`](../digests/falcosecurity/falco/architecture.md) |
| [`application-lifecycle.md`](application-lifecycle.md) | `falco` | [`app/`](../refs/falcosecurity/falco/userspace/falco/app/) | [`falco/architecture.md`](../digests/falcosecurity/falco/architecture.md) |
| [`cli-interface.md`](cli-interface.md) | `falco` | [`app/options.cpp`](../refs/falcosecurity/falco/userspace/falco/app/options.cpp) | [`falco/cli-reference.md`](../digests/falcosecurity/falco/cli-reference.md) |
| [`falcoctl.md`](falcoctl.md) | `falcoctl` | [`cmd/`](../refs/falcosecurity/falcoctl/cmd/), [`pkg/`](../refs/falcosecurity/falcoctl/pkg/) | [`falcoctl.md`](../digests/falcosecurity/falcoctl.md) |
| [`build-system.md`](build-system.md) | `falco`, `libs` | [`CMakeLists.txt`](../refs/falcosecurity/falco/CMakeLists.txt) | [`falco/architecture.md`](../digests/falcosecurity/falco/architecture.md) |
| [`kubernetes-deployment.md`](kubernetes-deployment.md) | `charts`, `deploy-kubernetes` | [`charts/falco/values.yaml`](../refs/falcosecurity/charts/charts/falco/values.yaml) | [`charts.md`](../digests/falcosecurity/charts.md), [`deploy-kubernetes.md`](../digests/falcosecurity/deploy-kubernetes.md) |
| [`rules-content.md`](rules-content.md) | `rules` | [`rules/falco_rules.yaml`](../refs/falcosecurity/rules/rules/falco_rules.yaml) | [`rules.md`](../digests/falcosecurity/rules.md) |
| [`falcosidekick.md`](falcosidekick.md) | `falcosidekick` | [`types/types.go`](../refs/falcosecurity/falcosidekick/types/types.go), [`config_example.yaml`](../refs/falcosecurity/falcosidekick/config_example.yaml) | [`falcosidekick/README.md`](../digests/falcosecurity/falcosidekick/README.md), [`falcosidekick/outputs.md`](../digests/falcosecurity/falcosidekick/outputs.md) |
| [`falco-operator.md`](falco-operator.md) | `falco-operator` | [`controllers/`](../refs/falcosecurity/falco-operator/controllers/), [`api/`](../refs/falcosecurity/falco-operator/api/) | [`falco-operator.md`](../digests/falcosecurity/falco-operator.md) |
| [`falco-lsp.md`](falco-lsp.md) | `falco-lsp` | [`falco-lsp/internal/`](../refs/falcosecurity/falco-lsp/falco-lsp/internal/), [`vscode-extension/`](../refs/falcosecurity/falco-lsp/vscode-extension/) | [`falco-lsp.md`](../digests/falcosecurity/falco-lsp.md) |
| [`falco-talon.md`](falco-talon.md) | `falco-talon` | [`actionners/`](../refs/falcosecurity/falco-talon/actionners/), [`internal/rules/`](../refs/falcosecurity/falco-talon/internal/rules/) | [`falco-talon.md`](../digests/falcosecurity/falco-talon.md) |
| [`driver-distribution.md`](driver-distribution.md) | `test-infra`, `driverkit`, `dbg-go`, `kernel-crawler` | [`driverkit/config/`](../refs/falcosecurity/test-infra/driverkit/config/) | [`driverkit.md`](../digests/falcosecurity/driverkit.md), [`dbg-go.md`](../digests/falcosecurity/dbg-go.md), [`test-infra/drivers-build-grid.md`](../digests/falcosecurity/test-infra/drivers-build-grid.md), [`kernel-crawler.md`](../digests/falcosecurity/kernel-crawler.md) |
| [`ci-cd-infrastructure.md`](ci-cd-infrastructure.md) | `test-infra` | [`config/config.yaml`](../refs/falcosecurity/test-infra/config/config.yaml), [`config/plugins.yaml`](../refs/falcosecurity/test-infra/config/plugins.yaml) | [`test-infra/prow-infrastructure.md`](../digests/falcosecurity/test-infra/prow-infrastructure.md), [`test-infra/prow-config.md`](../digests/falcosecurity/test-infra/prow-config.md), [`pigeon.md`](../digests/falcosecurity/pigeon.md) |
| [`ci-cd-jobs.md`](ci-cd-jobs.md) | `test-infra` | [`config/jobs/`](../refs/falcosecurity/test-infra/config/jobs/), [`config/org.yaml`](../refs/falcosecurity/test-infra/config/org.yaml) | [`test-infra/prow-jobs.md`](../digests/falcosecurity/test-infra/prow-jobs.md), [`test-infra/github-org-management.md`](../digests/falcosecurity/test-infra/github-org-management.md) |
| [`ci-cd-github-actions.md`](ci-cd-github-actions.md) | `falco-actions`, `testing` | [`start/action.yaml`](../refs/falcosecurity/falco-actions/start/action.yaml), [`action.yml`](../refs/falcosecurity/testing/action.yml) | [`falco-actions.md`](../digests/falcosecurity/falco-actions.md), [`testing.md`](../digests/falcosecurity/testing.md) |

## Dependency Graph

```
kernel-instrumentation
         │
         ▼
      libscap ◄──── plugin-system
         │
         ▼
      libsinsp
         │
    ┌────┴────┐
    ▼         ▼
filter-engine  (state tables)
    │
    ▼
rule-engine ──────► output-system
    │                    │
    ▼                    ▼
configuration    application-lifecycle
                         │
                    ┌────┴────┐
                    ▼         ▼
            cli-interface  metrics-and-observability

falcoctl (standalone)
build-system (cross-cutting)

rules-content (detection content for rule-engine)
kubernetes-deployment (deploys Falco, uses falcoctl + configuration)
falcosidekick (ecosystem, receives from output-system via HTTP)
falco-talon (ecosystem, receives from falcosidekick or output-system)
falco-operator (ecosystem, manages Falco instances and artifacts in Kubernetes)
falco-lsp (ecosystem, validates rules against rule-engine/filter-engine grammar)
driver-distribution (builds drivers for kernel-instrumentation)

ci-cd-infrastructure ──► ci-cd-jobs ──► driver-distribution
                    └──► ci-cd-github-actions
```

## Scope

These specifications cover:
- **Core Falco**: falco binary, falco_engine, output framework
- **Core Libraries**: libscap, libsinsp (from falcosecurity/libs)
- **Drivers**: Modern eBPF (default), kernel module
- **Plugin System**: API, capabilities, official plugins
- **falcoctl**: CLI management tool
- **Build System**: CMake structure, dependencies, feature flags
- **Kubernetes Deployment**: Helm charts, DaemonSet/Deployment topology, pod architecture
- **Detection Rules**: Rule content, maturity framework, tuning patterns
- **Ecosystem**: Falcosidekick (fan-out daemon), Falco Operator (Kubernetes-native management), Falco LSP (language tooling), Falco Talon (response engine), driver distribution pipeline
- **CI/CD**: Prow infrastructure, job catalog, GitHub Actions, organization management

**Not covered in detail:**
- Driverkit CLI details — driverkit build pipeline is covered in [`driver-distribution.md`](driver-distribution.md)
- Deprecated features (legacy eBPF, gVisor, gRPC output) — brief mentions only

## Guidelines

- All information includes source references traceable to [`refs/`](../refs/) or [`digests/`](../digests/)
- Code references link to specific files with line numbers where applicable
- Each spec is self-contained with cross-references to related specs
- Designed for the workflow: read spec → understand implementation → modify code
