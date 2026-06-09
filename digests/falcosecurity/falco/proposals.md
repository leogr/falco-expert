# Falco Proposals

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/falco/proposals/`](../../../refs/falcosecurity/falco/proposals/)

This digest documents the design proposals that shaped falcosecurity/falco. Understanding these provides context for why the system is designed the way it is.

## Proposal Status Summary

| # | Proposal | Date | Title | Status |
|---|----------|------|-------|--------|
| 1 | 20190826 | Aug 2019 | gRPC Outputs | **Implemented**, then Deprecated in 0.43, **Removed in 0.44** |
| 2 | 20190909 | Sep 2019 | PSP Rules Support | Not Implemented / Obsolete |
| 3 | 20191030 | Oct 2019 | Falco APIs | Partially Implemented, Partially Superseded |
| 4 | 20191217 | Dec 2019 | Rules Naming Convention | **Implemented** |
| 5 | 20200506 | May 2020 | Artifacts Scope Part 1 | Superseded |
| 6 | 20200506 | May 2020 | Artifacts Scope Part 2 | Superseded |
| 7 | 20200818 | Aug 2020 | Artifacts Storage | Superseded |
| 8 | 20200828 | Aug 2020 | Structured Exception Handling | **Implemented** |
| 9 | 20200901 | Sep 2020 | Artifacts Cleanup | Superseded |
| 10 | 20201025 | Oct 2020 | Drivers Storage S3 | **Implemented** |
| 11 | 20210119 | Jan 2021 | Libraries Contribution | **Implemented** |
| 12 | 20210501 | May 2021 | Plugin System | **Implemented** |
| 13 | 20221129 | Nov 2022 | Artifacts Distribution | **Implemented** |
| 14 | 20230511 | May 2023 | Roadmap Management | **Implemented** |
| 15 | 20230620 | Jun 2023 | Anomaly Detection Framework | In Progress (Experimental) |
| 16 | 20231220 | Dec 2023 | Features Adoption & Deprecation | **Implemented** |
| 17 | 20251215 | Dec 2025 | Legacy BPF/gRPC/gVisor Deprecation | **Completed**: deprecated in 0.43, removed in 0.44 |
| 18 | 20251205 | Dec 2025 | Multi-thread Falco Design | Design proposal merged in 0.44 (see [`refs/proposals/multi-thread-falco/`](../../../refs/proposals/multi-thread-falco/)) |

## Implemented Proposals

### gRPC Outputs (20190826) — Removed in 0.44

**Problem:** Falco could only deliver alerts via basic channels (stdout, syslog, file). Users needed a programmatic, extensible way to receive alerts with a well-defined contract.

**Solution:** A gRPC streaming server embedded in Falco with proto3 contracts, mutual TLS authentication, and Unix socket support. Both `sub` (streaming subscription) and `get` (batch retrieval) RPC methods were defined.

**Implementation:** Originally shipped with `grpc_server.cpp` and `outputs_grpc.cpp` in `userspace/falco/`. A Go client SDK was created as `falcosecurity/client-go` (also deprecated, see [`client-go.md`](../client-go.md)).

**Current Status:** **Removed** in Falco 0.44.0 via [#3798](https://github.com/falcosecurity/falco/pull/3798) (gRPC output and server) per [proposal 20251215](../../../refs/falcosecurity/falco/proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md). The 0.43 era emitted deprecation warnings; 0.44 dropped the gRPC framework dependency entirely. Recommended replacements: HTTP output or Falcosidekick.

**Source:** [`proposals/20190826-grpc-outputs.md`](../../../refs/falcosecurity/falco/proposals/20190826-grpc-outputs.md)

### Rules Naming Convention (20191217)

**Problem:** Contributors had inconsistent naming preferences for rules, macros, and lists, making the rules repository hard to maintain.

**Solution:** Formal naming conventions:
- **Rules**: Capitalize every word except prepositions (e.g., "Search Private Keys or Passwords")
- **Descriptions**: Start with "Detect", end with period
- **Output**: Must include at least `user=%user.name command=%proc.cmdline container_id=%container.id`
- **Tags**: At least one of `[network, process, filesystem]`; encourage `mitre_*` tags
- **Macros/Lists**: `lowercase_separated_by_underscores`

**Implementation:** Adopted as community standard. Rules in [`refs/falcosecurity/rules/`](../../../refs/falcosecurity/rules/) follow these conventions. The rules repository has further evolved with a full Maturity Framework.

**Source:** [`proposals/20191217-rules-naming-convention.md`](../../../refs/falcosecurity/falco/proposals/20191217-rules-naming-convention.md)

### Structured Exception Handling (20200828)

**Problem:** Rule customization via macro/list append/override was unwieldy and error-prone. Appending to conditions could produce incorrect boolean logic, and managing multiple exception sources was confusing.

**Solution:** First-class `exceptions` objects within rules. Each exception defines `name`, `fields`, optional `comps` (comparison operators), and `values`. Exceptions are syntactic sugar that append `and not (...)` clauses to conditions. Rule authors control the exception schema (which fields/operators are allowed).

**Implementation:** Fully implemented in the Falco engine. Rules files confirm: "Starting with version 8, the Falco engine supports exceptions." Rules widely use the `exceptions` key with `fields`, `comps`, and `values` properties.

**Source:** [`proposals/20200828-structured-exception-handling.md`](../../../refs/falcosecurity/falco/proposals/20200828-structured-exception-handling.md) | See also [`rule-language.md`](rule-language.md)

### Drivers Storage S3 (20201025)

**Problem:** Bintray rate-limited users due to a spike in driver downloads (~700k in 10 days), breaking the driver download workflow.

**Solution:** Move prebuilt drivers and container dependencies from Bintray to an S3 bucket behind `download.falco.org` with CloudFront distribution, keeping the same directory structure.

**Implementation:** Fully implemented. Falco CMakeLists.txt confirms: `set(DRIVERS_REPO "https://download.falco.org/driver")`. All driver downloads go through `download.falco.org`.

**Source:** [`proposals/20201025-drivers-storage-s3.md`](../../../refs/falcosecurity/falco/proposals/20201025-drivers-storage-s3.md)

### Libraries Contribution (20210119)

**Problem:** The core libraries (libsinsp, libscap) and drivers were in Sysdig Inc.'s `draios/sysdig` repository, not under the Falco project's open governance.

**Solution:** Sysdig Inc. donates libsinsp, libscap, kernel module, and eBPF driver to `falcosecurity/libs` with preserved commit history, proper CI, release process, and governance.

**Implementation:** One of the most transformative proposals. The `falcosecurity/libs` repository exists and contains libsinsp, libscap, and all driver sources with independent release cycles. See [`libs/`](../libs/) digests.

**Source:** [`proposals/20210119-libraries-contribution.md`](../../../refs/falcosecurity/falco/proposals/20210119-libraries-contribution.md)

### Plugin System (20210501)

**Problem:** The libraries (libscap/libsinsp) were designed for syscalls only, but their capture/enrichment/filtering framework was generically adaptable to many input types. The project needed a modular, extensible framework.

**Solution:** Plugin infrastructure with two initial types:
- **Source plugins**: Provide new event sources (open/close sessions, return events)
- **Extractor plugins**: Extract fields from events generated by other plugins or core

Plugins are dynamic libraries (.so/.dll) loaded at runtime with a well-defined C API. A Go SDK was the preferred development language.

**Implementation:** Fully implemented and GA since Falco 0.31.0 (January 2022). The plugin system has since been extended with additional capabilities:
- Parsing capability (event injection)
- Async events capability
- State table sharing between plugins and core
- Schema version validation ([libs proposal 20250923](../../../refs/falcosecurity/libs/proposals/20250923-plugin-system-event-schema-versioning.md))

Multiple SDKs exist: Go ([`plugin-sdk-go`](../plugin-sdk-go.md)), C++ ([`plugin-sdk-cpp`](../plugin-sdk-cpp.md)), Rust ([`plugin-sdk-rs`](../plugin-sdk-rs.md)). Official plugins are in [`falcosecurity/plugins`](../plugins.md).

**Key PRs:** [falco#1637](https://github.com/falcosecurity/falco/pull/1637) (proposal), [libs#93](https://github.com/falcosecurity/libs/pull/93), [libs#107](https://github.com/falcosecurity/libs/pull/107) (implementation)

**Source:** [`proposals/20210501-plugin-system.md`](../../../refs/falcosecurity/falco/proposals/20210501-plugin-system.md)

### Artifacts Distribution (20221129)

**Problem:** Distribution of Falco artifacts was fragmented across different channels with inconsistent tooling and naming.

**Solution:**
- Two distribution channels: HTTP (`download.falco.org`, GitHub releases) and OCI (`docker.io`, `ghcr.io`)
- Semantic versioning for all artifacts
- falcoctl as the primary artifact management tool (promoted to Core)
- Rules moved to their own repository (`falcosecurity/rules`)
- Deprecate `falco-driver-loader` script in favor of `falcoctl driver`
- Artifact namespacing reflecting originating repository

**Implementation:** Largely implemented:
- Rules in separate `falcosecurity/rules` repository (see [`rules.md`](../rules.md))
- falcoctl is the official CLI tool with Core status (see [`falcoctl.md`](../falcoctl.md))
- OCI distribution via `ghcr.io` for rules, plugins, and drivers
- `falco-driver-loader` replaced by `falcoctl driver` commands

**Source:** [`proposals/20221129-artifacts-distribution.md`](../../../refs/falcosecurity/falco/proposals/20221129-artifacts-distribution.md)

### Roadmap Management (20230511)

**Problem:** Falco lacked a structured process for managing its roadmap, release cycles, and development iterations.

**Solution:**
- 16-week release cycles with three iterations: Development (8 weeks), Stabilization (4 weeks), Release Preparation (4 weeks)
- 3 releases per year: last Monday of January, May, September
- GitHub Project ("Falco Roadmap") for tracking
- Monthly Core Maintainer planning sessions

**Implementation:** Adopted. The 3-releases-per-year cadence is active (Falco 0.43 released January 28, 2026, matching the "last Monday of January" target). GitHub Milestones are used for release planning.

**Source:** [`proposals/20230511-roadmap-management.md`](../../../refs/falcosecurity/falco/proposals/20230511-roadmap-management.md)

### Features Adoption and Deprecation (20231220)

**Problem:** Falco historically favored rapid evolution over long-term feature support. Implicit conventions about backward compatibility were never formalized.

**Solution:** Formal maturation levels and deprecation policies:
- **Maturation levels:** Sandbox (experimental) → Incubating (beta) → Stable (GA) → Deprecated
- **Adoption rules:** New features start at Sandbox (opt-in) or Incubating; promotion requires one release cycle without user-facing changes; no demotion
- **Deprecation rules (pre-1.0):** Stable features get 1 release cycle deprecation; Incubating features get 0
- **Coverage areas:** CLI/Config, Rules System, Outputs/Alerts, Subsystem APIs, Platform Support

**Implementation:** Actively followed. The deprecation proposal 20251215 explicitly references this policy. Falco 0.43 emitted deprecation warnings for gRPC, gVisor, and legacy eBPF; 0.44 then removed all three per the 1-release-cycle minimum. The `falco.yaml` marked features as `(deprecated)` with `DEPRECATION NOTICE:` headers in 0.43; those notices are gone in 0.44.

**Key PRs:** [falco#2986](https://github.com/falcosecurity/falco/pull/2986) (proposal), [falco#3206](https://github.com/falcosecurity/falco/pull/3206) (applied to config keys)

**Source:** [`proposals/20231220-features-adoption-and-deprecation.md`](../../../refs/falcosecurity/falco/proposals/20231220-features-adoption-and-deprecation.md)

## Proposals In Progress

### Anomaly Detection Framework (20230620)

**Status:** In Progress (Experimental)

**Problem:** Rule-based detections focus on what attackers are expected to do, not what they are actually doing. Security analysts face low signal-to-noise alerts. Advanced data analytics could detect deviations from normal behavior.

**Solution:**
- `anomalydetection` plugin using Count Min Sketch probabilistic data structure
- Users define "behavior profiles" combining event fields (process name, fd, executable path)
- Falco compresses and stores behavior data in sketches during event parsing
- Count estimates exposed as filterchecks for use in Falco rules
- Enables broader monitoring with a "safety boundary" to prevent noisy rules

**Implementation Progress:**
- Plugin exists in [`refs/falcosecurity/plugins/plugins/anomalydetection/`](../../../refs/falcosecurity/plugins/plugins/anomalydetection/) with Count Min Sketch implementation, plugin source, sinsp filtercheck integration, and unit tests
- Marked **Experimental** — not yet production-ready
- Original timeline (scaffolding 0.37, experimental 0.38, first release 0.39) was not met
- Development is ongoing; plugin API enhancements are needed (e.g., filtercheck access from plugins)

**Key PRs:** [falco#2655](https://github.com/falcosecurity/falco/pull/2655) (proposal), [libs#1453](https://github.com/falcosecurity/libs/pull/1453) (MVP draft)

**Source:** [`proposals/20230620-anomaly-detection-framework.md`](../../../refs/falcosecurity/falco/proposals/20230620-anomaly-detection-framework.md) | [`kubeconna23-anomaly-detection-slides.pdf`](../../../refs/falcosecurity/falco/proposals/kubeconna23-anomaly-detection-slides.pdf)

### Legacy BPF, gRPC Output, gVisor Engine Deprecation (20251215) — Completed

**Status:** **Completed**: deprecation active in 0.43, removal landed in 0.44

**Problem:** Three components imposed maintainability burdens and build complexity disproportionate to their usage:
- **Legacy eBPF probe**: Cannot leverage CO-RE features, hard to keep up with other drivers, kernel coverage entirely contained within kmod's range
- **gVisor engine**: Little used, doesn't provide full event parity, requires protobuf dependency
- **gRPC output**: Little used, requires heavy C++ gRPC framework, communication model (one-way server-to-client) doesn't justify gRPC complexity

**Solution:** Deprecate all three per the [features adoption and deprecation policy](../../../refs/falcosecurity/falco/proposals/20231220-features-adoption-and-deprecation.md). Since these are Stable features and Falco is pre-1.0, the minimum deprecation period is 1 release cycle — removal was scheduled for Falco 0.44.0.

**Removal in 0.44 (completed):**
- gRPC output and server: dropped via [#3798](https://github.com/falcosecurity/falco/pull/3798)
- gVisor engine support: dropped via [#3797](https://github.com/falcosecurity/falco/pull/3797)
- Legacy BPF probe: dropped via [#3796](https://github.com/falcosecurity/falco/pull/3796); the libs `driver/bpf/` directory no longer exists in libs 0.25.x
- `--gvisor-generate-config` CLI flag removed
- `outputs_grpc.cpp`, `grpc_server.cpp`, and `outputs.proto` removed from `userspace/falco/`
- `falco.yaml` no longer contains `grpc:` or `gvisor:` sections

**Replacements (now official):**
- Legacy eBPF → Modern eBPF (default since 0.38) or kernel module
- gVisor engine → Future source plugin (not committed)
- gRPC output → HTTP output or Falcosidekick

**Key PRs:** [falco#3755](https://github.com/falcosecurity/falco/pull/3755) (deprecation proposal), [#3796](https://github.com/falcosecurity/falco/pull/3796), [#3797](https://github.com/falcosecurity/falco/pull/3797), [#3798](https://github.com/falcosecurity/falco/pull/3798) (removals) | **See also:** [KubeCon NA 2025 Maintainer Track](https://www.youtube.com/watch?v=5JoNk7_Sors)

**Source:** [`proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md`](../../../refs/falcosecurity/falco/proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md)

### Multi-thread Falco Design (20251205) — New in 0.44

**Status:** Design proposal merged in Falco 0.44 (high-level design)

**Problem:** Falco currently runs a single-thread event loop per inspector. As event volumes grow (especially with plugins like k8s_audit and multiple sources), the single-thread design becomes a throughput bottleneck and a contention point for cleanup/teardown paths.

**Solution:** A multi-thread Falco redesign that separates event ingestion, parsing/state-tracking, and rule evaluation across worker threads, with a clear ownership model for inspector state and thread-safety guarantees throughout libsinsp.

**Status in 0.44:** The high-level design proposal was merged via [#3751](https://github.com/falcosecurity/falco/pull/3751). Implementation is incremental; see the multi-thread Falco initiative for the full set of supporting proposals.

**Source:** [`proposals/20251205-multi-thread-falco-design.md`](../../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md) | **See also:** [`refs/proposals/multi-thread-falco/`](../../../refs/proposals/multi-thread-falco/) for related cross-repo proposals.

## Obsolete / Not Implemented Proposals

### PSP Rules Support (20190909)

**Problem:** Kubernetes Pod Security Policies (PSPs) were hard to author. Users needed a way to "dry run" PSPs by converting them to Falco rules that observe and alert on violations without blocking.

**Proposed Solution:** Add `--psp` CLI argument to convert PSP YAML files to Falco rules using template-based generation, leveraging K8s Audit Events.

**Status:** **Not Implemented / Obsolete.** Kubernetes deprecated Pod Security Policies in v1.21 (2021) and removed them in v1.25 (2022), replacing them with Pod Security Admission. No `--psp` flag exists in Falco. The proposal is effectively dead due to the upstream Kubernetes deprecation.

**Source:** [`proposals/20190909-psp-rules-support.md`](../../../refs/falcosecurity/falco/proposals/20190909-psp-rules-support.md)

## Partially Implemented / Superseded Proposals

### Falco APIs (20191030)

**Problem:** Falco needed a structured API for third-party clients to interface with its outputs, inputs, rules, and configurations.

**Proposed Solution:** A comprehensive gRPC-based API with six services: Outputs (streaming), Drops (streaming), Version (unary), Configs (unary), Rules (unary), and Inputs (bidirectional streaming).

**Status:** Only **Outputs** and **Version** services were implemented as part of the gRPC server (now deprecated). The Rules, Configs, Inputs, and Drops services were never implemented. The broader vision was partially superseded by the plugin system (custom inputs), falcoctl (external config/rules management), and HTTP output.

**Source:** [`proposals/20191030-api.md`](../../../refs/falcosecurity/falco/proposals/20191030-api.md)

### Artifacts Proposals (20200506, 20200818, 20200901, 20201025)

Four interrelated proposals that defined and iterated on Falco's artifact lifecycle:

| Proposal | Title | Outcome |
|----------|-------|---------|
| [20200506 Part 1](../../../refs/falcosecurity/falco/proposals/20200506-artifacts-scope-part-1.md) | Artifacts Scope Part 1 | Concepts adopted (cleanup, contrib repo), specifics superseded |
| [20200506 Part 2](../../../refs/falcosecurity/falco/proposals/20200506-artifacts-scope-part-2.md) | Artifacts Scope Part 2 | Naming conventions partially adopted, superseded by later evolution |
| [20200818](../../../refs/falcosecurity/falco/proposals/20200818-artifacts-storage.md) | Artifacts Storage | Bintray-based storage documented; Bintray shut down in 2021 |
| [20200901](../../../refs/falcosecurity/falco/proposals/20200901-artifacts-cleanup.md) | Artifacts Cleanup | Superseded by drivers-storage-s3 (stated in the proposal itself) |

These were collectively superseded by the [Artifacts Distribution proposal (20221129)](../../../refs/falcosecurity/falco/proposals/20221129-artifacts-distribution.md) and the evolution of OCI-based distribution via falcoctl.

## Sources

| Topic | Source File |
|-------|-------------|
| gRPC outputs proposal | [`proposals/20190826-grpc-outputs.md`](../../../refs/falcosecurity/falco/proposals/20190826-grpc-outputs.md) |
| PSP rules proposal | [`proposals/20190909-psp-rules-support.md`](../../../refs/falcosecurity/falco/proposals/20190909-psp-rules-support.md) |
| API proposal | [`proposals/20191030-api.md`](../../../refs/falcosecurity/falco/proposals/20191030-api.md) |
| Rules naming proposal | [`proposals/20191217-rules-naming-convention.md`](../../../refs/falcosecurity/falco/proposals/20191217-rules-naming-convention.md) |
| Artifacts scope Part 1 | [`proposals/20200506-artifacts-scope-part-1.md`](../../../refs/falcosecurity/falco/proposals/20200506-artifacts-scope-part-1.md) |
| Artifacts scope Part 2 | [`proposals/20200506-artifacts-scope-part-2.md`](../../../refs/falcosecurity/falco/proposals/20200506-artifacts-scope-part-2.md) |
| Artifacts storage | [`proposals/20200818-artifacts-storage.md`](../../../refs/falcosecurity/falco/proposals/20200818-artifacts-storage.md) |
| Structured exceptions | [`proposals/20200828-structured-exception-handling.md`](../../../refs/falcosecurity/falco/proposals/20200828-structured-exception-handling.md) |
| Artifacts cleanup | [`proposals/20200901-artifacts-cleanup.md`](../../../refs/falcosecurity/falco/proposals/20200901-artifacts-cleanup.md) |
| Drivers storage S3 | [`proposals/20201025-drivers-storage-s3.md`](../../../refs/falcosecurity/falco/proposals/20201025-drivers-storage-s3.md) |
| Libraries contribution | [`proposals/20210119-libraries-contribution.md`](../../../refs/falcosecurity/falco/proposals/20210119-libraries-contribution.md) |
| Plugin system | [`proposals/20210501-plugin-system.md`](../../../refs/falcosecurity/falco/proposals/20210501-plugin-system.md) |
| Artifacts distribution | [`proposals/20221129-artifacts-distribution.md`](../../../refs/falcosecurity/falco/proposals/20221129-artifacts-distribution.md) |
| Roadmap management | [`proposals/20230511-roadmap-management.md`](../../../refs/falcosecurity/falco/proposals/20230511-roadmap-management.md) |
| Anomaly detection | [`proposals/20230620-anomaly-detection-framework.md`](../../../refs/falcosecurity/falco/proposals/20230620-anomaly-detection-framework.md) |
| Features adoption/deprecation | [`proposals/20231220-features-adoption-and-deprecation.md`](../../../refs/falcosecurity/falco/proposals/20231220-features-adoption-and-deprecation.md) |
| Legacy BPF/gRPC/gVisor deprecation | [`proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md`](../../../refs/falcosecurity/falco/proposals/20251215-legacy-bpf-grpc-output-gvisor-engine-deprecation.md) |
| Anomaly detection slides | [`proposals/kubeconna23-anomaly-detection-slides.pdf`](../../../refs/falcosecurity/falco/proposals/kubeconna23-anomaly-detection-slides.pdf) |

## Related Digests

- [`architecture.md`](architecture.md) — System design and event flow
- [`configuration.md`](configuration.md) — Full configuration reference (includes deprecation notices)
- [`outputs.md`](outputs.md) — Output channels including deprecated gRPC
- [`../libs/proposals-and-architecture.md`](../libs/proposals-and-architecture.md) — Libs proposals (versioning, drivers, plugin schema)
- [`../rules.md`](../rules.md) — Detection rules (naming convention, exceptions)
- [`../falcoctl.md`](../falcoctl.md) — Artifact management (replaces falco-driver-loader)
- [`../../proposals/multi-thread-falco.md`](../../proposals/multi-thread-falco.md) — Multi-thread Falco proposals (post-0.43, not implemented)
