# falcosecurity/falco Digest

> **Era Relevance:** 0.45 | **Source:** [`refs/falcosecurity/falco/`](../../../refs/falcosecurity/falco/) | **Version:** 0.45.0

**Repository:** https://github.com/falcosecurity/falco
**Status:** Core / Stable (CNCF Graduated)

The main Falco repository providing the runtime security tool binary. Built on top of [libs](../libs/), Falco adds the rule language engine, output management, and configuration system.

## Quick Reference

| Property | Value |
|----------|-------|
| Falco Version | 0.45.0 |
| Engine Version | 0.65.0 |
| Libs Version | 0.26.0 |
| Plugin API | 3.12.0 (from libs) |
| Default Driver | modern_ebpf |
| Architecture | x86-64, aarch64 |

## Era 0.45 Changes

- Generation-based reload status and an optional Unix HTTP administrative listener; SIGHUP notification persists across reload teardown. See [architecture](architecture.md#hot-reload) and [configuration](configuration.md#hot-reload).
- Raw byte comparisons and hexadecimal escapes in filter literals, with UTF-8 sanitation at output boundaries. See [rule language](rule-language.md#raw-bytes-in-conditions-045) and [outputs](outputs.md#byte-preservation-and-output-encoding-045).
- Package upgrades retain custom driver pins and defer RPM provisioning/startup until post-transaction cleanup. [Package helpers](../../../refs/falcosecurity/falco/scripts/packaging/functions.sh.in#L23-L64), [RPM posttrans](../../../refs/falcosecurity/falco/scripts/rpm/posttrans.in#L24-L49).

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                           Falco Binary                                │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                      Application Layer                           │ │
│  │  ┌──────────────┐ ┌───────────────┐ ┌──────────────────────┐   │ │
│  │  │ CLI Options  │ │ Configuration │ │   Signal Handlers    │   │ │
│  │  └──────────────┘ └───────────────┘ └──────────────────────┘   │ │
│  │  ┌──────────────┐ ┌──────────────────────────────────────────┐   │ │
│  │  │  Webserver   │ │   Restart Handler (hot reload, inotify)   │   │ │
│  │  │  (metrics)   │ └──────────────────────────────────────────┘   │ │
│  │  └──────────────┘                                                 │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ┌────────────────────────┐  ┌─────────────────────────────────────┐ │
│  │     Falco Engine       │  │         Output System               │ │
│  │  ┌──────────────────┐  │  │  ┌───────┐ ┌────────┐ ┌──────────┐ │ │
│  │  │   Rule Loader    │  │  │  │stdout │ │syslog  │ │  file    │ │ │
│  │  │ (read/collect/   │  │  │  └───────┘ └────────┘ └──────────┘ │ │
│  │  │    compile)      │  │  │  ┌──────────────┐ ┌─────────────┐  │ │
│  │  ├──────────────────┤  │  │  │  http (curl) │ │  program    │  │ │
│  │  │  Filter Ruleset  │  │  │  └──────────────┘ └─────────────┘  │ │
│  │  │ (event matching) │  │  │         (async queue)               │ │
│  │  ├──────────────────┤  │  └─────────────────────────────────────┘ │
│  │  │  Stats Manager   │  │                                          │
│  │  └──────────────────┘  │                                          │
│  └────────────────────────┘                                          │
│                                                                       │
├───────────────────────────────────────────────────────────────────────┤
│                         libs (libsinsp + libscap)                     │
│  ┌──────────────┐  ┌────────────────┐  ┌──────────────────────────┐  │
│  │   sinsp      │  │    Plugins     │  │    Driver Interface      │  │
│  │ (inspector)  │  │  (container,   │  │ (kmod/modern_bpf)        │  │
│  │              │  │   cloudtrail)  │  │                          │  │
│  └──────────────┘  └────────────────┘  └──────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
```

## What Falco Adds on Top of libs

| Component | Description |
|-----------|-------------|
| **Rule Language** | Full DSL for detection rules with lists, macros, conditions, and exceptions |
| **Rule Engine** | Compiles and evaluates rules against events, manages rulesets |
| **Output System** | Multi-channel async output with JSON/text formatting |
| **Configuration** | Layered YAML config with hot reload and merge strategies |
| **Application Framework** | Action-based execution flow with clean startup/teardown |

## Digests

| Digest | Description |
|--------|-------------|
| [`architecture.md`](architecture.md) | System design, event flow, libs integration |
| [`rule-language.md`](rule-language.md) | Complete rule language specification |
| [`configuration.md`](configuration.md) | Full configuration reference |
| [`outputs.md`](outputs.md) | Alert output channels and formatting |
| [`cli-reference.md`](cli-reference.md) | CLI options and introspection commands |
| [`proposals.md`](proposals.md) | Design proposals, adoption/deprecation policies, roadmap |

## Key Components

### Falco Engine (`userspace/engine/`)
The rule processing core:
- **Rule Loader** - Three-phase pipeline: Reader (YAML) → Collector → Compiler
- **Filter Ruleset** - Event-type indexed rule matching
- **Stats Manager** - Rule match statistics

**Source:** [`userspace/engine/`](../../../refs/falcosecurity/falco/userspace/engine/)

### Application (`userspace/falco/`)
The main application:
- **Configuration** - YAML config loading with merge strategies
- **Outputs** - Async multi-channel output system
- **Webserver** - HTTP server for health checks and metrics

**Source:** [`userspace/falco/`](../../../refs/falcosecurity/falco/userspace/falco/)

### App Actions (`userspace/falco/app/actions/`)
Modular action framework:
- `load_config` - Configuration loading
- `load_plugins` - Plugin initialization
- `init_falco_engine` - Engine setup
- `load_rules_files` - Rule loading
- `process_events` - Main event loop

**Source:** [`userspace/falco/app/actions/`](../../../refs/falcosecurity/falco/userspace/falco/app/actions/)

## Related Digests

| Digest | Relationship |
|--------|--------------|
| [`libs/`](../libs/) | Underlying event capture and inspection library |
| [`rules.md`](../rules.md) | Official detection rules repository |
| [`charts.md`](../charts.md) | Helm chart for Kubernetes deployment |
| [`falcoctl.md`](../falcoctl.md) | CLI tool for driver and artifact management |
| [`deploy-kubernetes.md`](../deploy-kubernetes.md) | Raw Kubernetes manifests |

## Version Sources

The release selects its libraries and driver independently: [`falcosecurity-libs.cmake:45`](../../../refs/falcosecurity/falco/cmake/modules/falcosecurity-libs.cmake#L45), [`driver.cmake:38`](../../../refs/falcosecurity/falco/cmake/modules/driver.cmake#L38). The final engine version is defined in [`falco_engine_version.h:21-24`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h#L21-L24).

## Sources

| Topic | Source File |
|-------|-------------|
| Main entry point | [`userspace/falco/falco.cpp`](../../../refs/falcosecurity/falco/userspace/falco/falco.cpp) |
| Application flow | [`userspace/falco/app/app.cpp`](../../../refs/falcosecurity/falco/userspace/falco/app/app.cpp) |
| Application state | [`userspace/falco/app/state.h`](../../../refs/falcosecurity/falco/userspace/falco/app/state.h) |
| Falco engine | [`userspace/engine/falco_engine.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine.h) |
| Engine version | [`userspace/engine/falco_engine_version.h`](../../../refs/falcosecurity/falco/userspace/engine/falco_engine_version.h) |
| Configuration | [`userspace/falco/configuration.h`](../../../refs/falcosecurity/falco/userspace/falco/configuration.h) |
| Default config | [`falco.yaml`](../../../refs/falcosecurity/falco/falco.yaml) |
| Outputs | [`userspace/falco/falco_outputs.h`](../../../refs/falcosecurity/falco/userspace/falco/falco_outputs.h) |
| CLI options | [`userspace/falco/app/options.h`](../../../refs/falcosecurity/falco/userspace/falco/app/options.h) |
| Build configuration | [`CMakeLists.txt`](../../../refs/falcosecurity/falco/CMakeLists.txt) |
| Repository README | [`README.md`](../../../refs/falcosecurity/falco/README.md) |
| Maintainers | [`OWNERS`](../../../refs/falcosecurity/falco/OWNERS) |
