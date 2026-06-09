# Falco Project Evolution - AI Digest

This digest provides a comprehensive overview of The Falco Project governance, organization structure, and repository ecosystem. It is derived from the [falcosecurity/evolution](https://github.com/falcosecurity/evolution) repository.

**Applicable to**: Falco 0.43 era (current)

---

## Table of Contents

- [Repository Map](#repository-map)
  - [Core Repositories](#core-repositories)
  - [Ecosystem Repositories](#ecosystem-repositories)
  - [Infrastructure Repositories](#infrastructure-repositories)
  - [Special Repositories](#special-repositories)
- [Governance](#governance)
  - [Principles](#principles)
  - [Decision Making](#decision-making)
  - [Community Roles](#community-roles)
- [Maintainers](#maintainers)
  - [Core Maintainers](#core-maintainers)
  - [All Maintainers](#all-maintainers)
- [Licensing](#licensing)
  - [License Requirements](#license-requirements)
  - [SPDX License Identifiers](#spdx-license-identifiers)
  - [CNCF License Exceptions for Falco](#cncf-license-exceptions-for-falco)
  - [HashiCorp MPL to BUSL Audit](#hashicorp-mpl-to-busl-audit)
  - [CI License Checking](#ci-license-checking)
- [Source Files](#source-files)

---

## Repository Map

The Falco Project organizes its repositories under the [falcosecurity](https://github.com/falcosecurity) GitHub organization. Each repository is assigned:

- **Scope**: Defines the repository's role (Core, Ecosystem, Infra, or Special)
- **Status**: Indicates maturity level (Stable, Incubating, Sandbox, or Deprecated)

### Repository Scopes

| Scope | Description |
|-------|-------------|
| **Core** | Essential for building, installing, running, documenting, or using Falco |
| **Ecosystem** | Optional components providing value-added features, integrations, and utilities |
| **Infra** | Infrastructure supporting the project's functioning and maintenance |
| **Special** | Repositories with unique functions (governance, community, forks, templates) |

### Repository Statuses

| Status | Description |
|--------|-------------|
| **Stable** | Production-ready, actively maintained, officially supported |
| **Incubating** | Intermediate maturity, may still change significantly, not recommended for mission-critical use |
| **Sandbox** | Early development, experimental, not for production use |
| **Deprecated** | No longer maintained, kept for historical purposes |

---

### Core Repositories

Core repositories are critically important - essential for building, installing, running, documenting, and using Falco.

| Repository | Status | Description |
|------------|--------|-------------|
| [falco](https://github.com/falcosecurity/falco) | Stable | Falco is a cloud native runtime security tool for Linux operating systems. It is designed to detect and alert on abnormal behavior and potential security threats in real-time. |
| [libs](https://github.com/falcosecurity/libs) | Stable | Foundational libraries that constitute the core of Falco's functionality, offering essential features including kernel drivers and eBPF probes. |
| [rules](https://github.com/falcosecurity/rules) | Stable | Official rulesets for Falco provide pre-defined detection rules for various security threats and abnormal behaviors. |
| [falcoctl](https://github.com/falcosecurity/falcoctl) | Stable | The official CLI tool for working with Falco and its ecosystem components. |
| [plugins](https://github.com/falcosecurity/plugins) | Stable | Plugins serve as extensions for Falco and applications built on top of Falco's libraries. This repository contains the official registry for all Falco plugins and host plugins maintained by The Falco Project. |
| [plugin-sdk-go](https://github.com/falcosecurity/plugin-sdk-go) | Stable | Plugins SDK for Go that facilitates writing plugins for Falco or applications built on top of Falco's libs. |
| [charts](https://github.com/falcosecurity/charts) | Stable | Helm charts repository for Falco and its ecosystem. |
| [deploy-kubernetes](https://github.com/falcosecurity/deploy-kubernetes) | Stable | Kubernetes deployment resources for Falco and its ecosystem. |
| [falco-website](https://github.com/falcosecurity/falco-website) | Stable | Falco website and documentation repository. |

---

### Ecosystem Repositories

Ecosystem repositories extend the core project with optional components, integrations, and utilities.

| Repository | Status | Description |
|------------|--------|-------------|
| [falcosidekick](https://github.com/falcosecurity/falcosidekick) | Stable | Falcosidekick seamlessly integrates Falco with your ecosystem, enabling event forwarding to multiple outputs in a fan-out manner. |
| [driverkit](https://github.com/falcosecurity/driverkit) | Incubating | Kit for building Falco drivers (kernel modules or eBPF probes). |
| [event-generator](https://github.com/falcosecurity/event-generator) | Incubating | Testing tool to generate a variety of suspect actions that are detected by Falco rules. |
| [falcosidekick-ui](https://github.com/falcosecurity/falcosidekick-ui) | Incubating | A simple WebUI with latest events from Falco. |
| [falco-talon](https://github.com/falcosecurity/falco-talon) | Incubating | Response Engine for managing threats in your Kubernetes. |
| [falco-operator](https://github.com/falcosecurity/falco-operator) | Incubating | Kubernetes Operator for Falco. |
| [k8s-metacollector](https://github.com/falcosecurity/k8s-metacollector) | Incubating | Fetches the metadata from kubernetes API server and dispatches them to Falco instances. |
| [falco-aws-terraform](https://github.com/falcosecurity/falco-aws-terraform) | Incubating | Terraform Module for Falco AWS Resources. |
| [plugin-sdk-cpp](https://github.com/falcosecurity/plugin-sdk-cpp) | Incubating | Falco plugins SDK for C++. |
| [plugin-sdk-rs](https://github.com/falcosecurity/plugin-sdk-rs) | Incubating | Falco plugins SDK for Rust. |
| [flycheck-falco-rules](https://github.com/falcosecurity/flycheck-falco-rules) | Incubating | A custom checker for Falco rules files that can be loaded using the Flycheck syntax checker for GNU Emacs. |
| [contrib](https://github.com/falcosecurity/contrib) | Sandbox | Sandbox repository to test-drive ideas/projects/code. |
| [libs-sdk-go](https://github.com/falcosecurity/libs-sdk-go) | Sandbox | Go SDK for Falco libs. |
| [falco-actions](https://github.com/falcosecurity/falco-actions) | Sandbox | Run Falco in a GitHub Actions to detect suspicious behavior in your CI/CD. |
| [falco-rustlings](https://github.com/falcosecurity/falco-rustlings) | Sandbox | Small exercises to get you used to writing Falco plugins in Rust. |
| [client-go](https://github.com/falcosecurity/client-go) | Deprecated | Go client and SDK for Falco. |

---

### Infrastructure Repositories

Infrastructure repositories support the project's functioning, management, and maintenance.

| Repository | Status | Description |
|------------|--------|-------------|
| [test-infra](https://github.com/falcosecurity/test-infra) | Stable | Test infrastructure and automation workflows for The Falco Project. |
| [kernel-crawler](https://github.com/falcosecurity/kernel-crawler) | Incubating | A tool to crawl Linux kernel versions. |
| [dbg-go](https://github.com/falcosecurity/dbg-go) | Incubating | A go tool to work with falcosecurity drivers build grid. |
| [pigeon](https://github.com/falcosecurity/pigeon) | Incubating | Secrets and config manager for Falco's infrastructure. |
| [testing](https://github.com/falcosecurity/testing) | Incubating | All-purpose test suite for Falco and its ecosystem. |
| [syscalls-bumper](https://github.com/falcosecurity/syscalls-bumper) | Incubating | A tool to automatically update supported syscalls in libs. |
| [kernel-testing](https://github.com/falcosecurity/kernel-testing) | Incubating | Ansible playbooks to provision firecracker VMs and run Falco kernel tests. |
| [cncf-green-review-testing](https://github.com/falcosecurity/cncf-green-review-testing) | Sandbox | Falco configurations intended for testing with the CNCF Green Reviews Working Group. |
| [falco-playground](https://github.com/falcosecurity/falco-playground) | Sandbox | falco-playground is a web application used to validate Falco rules and test against scap files. |

---

### Special Repositories

Special repositories serve unique functions for the organization and are curated by Core Maintainers.

| Repository | Description |
|------------|-------------|
| [.github](https://github.com/falcosecurity/.github) | Default files for all repos in the Falcosecurity GitHub org. |
| [community](https://github.com/falcosecurity/community) | Falco community content and resources. |
| [evolution](https://github.com/falcosecurity/evolution) | A space for the community to work together, discuss ideas, define processes, and document the evolution of Falco. |
| [elftoolchain](https://github.com/falcosecurity/elftoolchain) | Local version of https://sourceforge.net/projects/elftoolchain/ |

---

## Governance

The Falco Project is part of the CNCF (Cloud Native Computing Foundation) and adheres to its values.

### Principles

The project adheres to these fundamental principles:

1. **Open**: Falco is open source and open to contribution, accessible and welcoming for everyone
2. **Respectful**: The community pledges to respect all people involved in the project
3. **Diverse**: The project furthers the interest in the diversity of representation
4. **Transparent**: Discussions, collaboration, and decision-making are done in public
5. **Vibrant**: Evolution is better than stagnation

### Decision Making

| Decision Type | Method | Voters |
|--------------|--------|--------|
| **Ordinary decisions** | Lazy consensus | Maintainers of the relevant repository/area |
| **Governance changes** | Supermajority vote (2/3) | Core Maintainers |
| **Adding maintainers** | Majority vote | Maintainers of the relevant repository |
| **Removing maintainers** | Supermajority vote (2/3) | Core Maintainers |
| **Sensitive matters** | Private vote (if agreed) | Core Maintainers |

**Voting rules**:
- Voting must be open for one week (can be extended to three weeks)
- No organization should have more than 40% of eligible votes
- Votes are cast via comments on GitHub issues/PRs

### Community Roles

| Role | Description | Defined By |
|------|-------------|------------|
| **Adopters** | Organizations publicly using Falco | ADOPTERS.md in falco repo |
| **Community Members** | Anyone interacting with the project | Participation in channels |
| **Contributors** | Community members who contribute directly | GitHub contributions |
| **Reviewers** | Contributors with technical experience who help review PRs | OWNERS file `reviewers` entry |
| **Maintainers** | Contributors showing significant and sustained contribution | OWNERS file `approvers` entry |
| **Core Maintainers** | Maintainers of at least one core repository | OWNERS file `approvers` entry in core repos |
| **Emeritus Maintainers** | Former maintainers who stepped down | OWNERS file `emeritus_approvers` entry |

**Core Maintainer Responsibilities**:
- Overseeing overall project health and growth
- Speaking on behalf of the project
- Maintaining the brand, mission, vision, values, and scope
- Administering the falcosecurity GitHub organization
- Handling license and copyright issues
- Serving as last escalation point for disputes

---

## Maintainers

### Core Maintainers

Core Maintainers are maintainers of at least one core repository. They form the team that drives the direction, values, and governance of the overall project.

| Name | GitHub | Company |
|------|--------|---------|
| Aldo Lacuku | [@alacuku](https://github.com/alacuku) | Kong |
| Andrea Terzolo | [@andreagit97](https://github.com/andreagit97) | SUSE |
| Angelo Puglisi | [@deepskyblue86](https://github.com/deepskyblue86) | Sysdig |
| Carlos Tadeu Panato Junior | [@cpanato](https://github.com/cpanato) | Chainguard |
| Federico Di Pierro | [@fededp](https://github.com/fededp) | Sysdig |
| Gerald Combs | [@geraldcombs](https://github.com/geraldcombs) | Wireshark Foundation |
| Grzegorz Nosek | [@gnosek](https://github.com/gnosek) | Sysdig |
| Iacopo Rozzo | [@irozzo-1a](https://github.com/irozzo-1a) | Sysdig |
| Jason Dellaluce | [@jasondellaluce](https://github.com/jasondellaluce) | Replit |
| Leonardo Di Giovanna | [@ekoops](https://github.com/ekoops) | Sysdig |
| Leonardo Grasso | [@leogr](https://github.com/leogr) | Sysdig |
| Lorenzo Susini | [@loresuso](https://github.com/loresuso) | Sysdig |
| Luca Guerra | [@lucaguerra](https://github.com/lucaguerra) | Sysdig |
| Mark Stemm | [@mstemm](https://github.com/mstemm) | Sysdig |
| Massimiliano Giovagnoli | [@maxgio92](https://github.com/maxgio92) | Chainguard |
| Mauro Ezequiel Moltrasio | [@molter73](https://github.com/molter73) | RedHat |
| Michele Zuccala | [@zuc](https://github.com/zuc) | Sysdig |
| Samuel Gaist | [@sgaist](https://github.com/sgaist) | Idiap Research Institute |
| Thomas Labarussias | [@issif](https://github.com/issif) | Yubo |

### All Maintainers

The complete list of maintainers across all repositories:

| Name | GitHub | Company |
|------|--------|---------|
| Ahmed Amin | [@ahmedameenaim](https://github.com/ahmedameenaim) | Zartis |
| Aldo Lacuku | [@alacuku](https://github.com/alacuku) | Kong |
| Andrea Terzolo | [@andreagit97](https://github.com/andreagit97) | SUSE |
| Angelo Puglisi | [@deepskyblue86](https://github.com/deepskyblue86) | Sysdig |
| Aurelie Vache | [@scraly](https://github.com/scraly) | OVHcloud |
| Carlos Tadeu Panato Junior | [@cpanato](https://github.com/cpanato) | Chainguard |
| David Windsor | [@dwindsor](https://github.com/dwindsor) | Independent |
| Edd Wilder-James | [@ewilderj](https://github.com/ewilderj) | Independent |
| Federico Di Pierro | [@fededp](https://github.com/fededp) | Sysdig |
| Frank Jogeleit | [@fjogeleit](https://github.com/fjogeleit) | LOVOO |
| Fred Araujo | [@araujof](https://github.com/araujof) | IBM |
| Gerald Combs | [@geraldcombs](https://github.com/geraldcombs) | Wireshark Foundation |
| Gianmatteo Palmieri | [@mrgian](https://github.com/mrgian) | Sysdig |
| Grzegorz Nosek | [@gnosek](https://github.com/gnosek) | Sysdig |
| Hendrik Brueckner | [@hbrueckner](https://github.com/hbrueckner) | IBM |
| Iacopo Rozzo | [@irozzo-1a](https://github.com/irozzo-1a) | Sysdig |
| Igor Eulalio | [@igoreulalio](https://github.com/igoreulalio) | Sysdig |
| Jason Dellaluce | [@jasondellaluce](https://github.com/jasondellaluce) | Replit |
| Jonah Jones | [@jonahjon](https://github.com/jonahjon) | Amazon |
| Leonardo Di Donato | [@leodido](https://github.com/leodido) | Independent |
| Leonardo Di Giovanna | [@ekoops](https://github.com/ekoops) | Sysdig |
| Leonardo Grasso | [@leogr](https://github.com/leogr) | Sysdig |
| Logan Bond | [@exoner4ted](https://github.com/exoner4ted) | Secureworks |
| Lorenzo Susini | [@loresuso](https://github.com/loresuso) | Sysdig |
| Loris Degioianni | [@ldegio](https://github.com/ldegio) | Sysdig |
| Luca Guerra | [@lucaguerra](https://github.com/lucaguerra) | Sysdig |
| Lyonel Martinez | [@lowaiz](https://github.com/lowaiz) | Numberly |
| Mark Stemm | [@mstemm](https://github.com/mstemm) | Sysdig |
| Massimiliano Giovagnoli | [@maxgio92](https://github.com/maxgio92) | Chainguard |
| Mauro Ezequiel Moltrasio | [@molter73](https://github.com/molter73) | RedHat |
| Michele Zuccala | [@zuc](https://github.com/zuc) | Sysdig |
| Nedim Sabic Sabic | [@rabbitstack](https://github.com/rabbitstack) | Sysdig |
| Roberto Scolaro | [@therealbobo](https://github.com/therealbobo) | Sysdig |
| Rohith Raju | [@rohith-raju](https://github.com/rohith-raju) | Independent |
| Samuel Gaist | [@sgaist](https://github.com/sgaist) | Idiap Research Institute |
| Samuele Cappellin | [@cappellinsamuele](https://github.com/cappellinsamuele) | Ca' Foscari University of Venice |
| Stefano Chierici | [@darryk10](https://github.com/darryk10) | Sysdig |
| Sverre Boschman | [@sboschman](https://github.com/sboschman) | Topicus.Education |
| Teryl Taylor | [@terylt](https://github.com/terylt) | IBM |
| Thomas Labarussias | [@issif](https://github.com/issif) | Yubo |
| Vicente Javier Jimenez Miras | [@vjjmiras](https://github.com/vjjmiras) | Independent |

### Company Affiliations Summary

| Company | Core Maintainers | All Maintainers |
|---------|-----------------|-----------------|
| Sysdig | 10 | 17 |
| Chainguard | 2 | 2 |
| IBM | 0 | 3 |
| Independent | 0 | 5 |
| Kong | 1 | 1 |
| SUSE | 1 | 1 |
| Replit | 1 | 1 |
| RedHat | 1 | 1 |
| Wireshark Foundation | 1 | 1 |
| Idiap Research Institute | 1 | 1 |
| Yubo | 1 | 1 |
| Others | 0 | 7 |

---

## Licensing

This section documents The Falco Project's licensing requirements, decisions, and compliance efforts. For the underlying CNCF policies, see the [CNCF Foundation licensing digest](../cncf/foundation.md).

### License Requirements

The Falco Project's license requirements are defined in [GOVERNANCE.md, §License](../../refs/falcosecurity/evolution/GOVERNANCE.md):

| Artifact | License | Reference |
|----------|---------|-----------|
| **Repository contents (code)** | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) | [GOVERNANCE.md, §License](../../refs/falcosecurity/evolution/GOVERNANCE.md) |
| **Third-party dependencies** | Must adhere to the [CNCF Allowed Third-Party License Policy](../../refs/cncf/foundation/policies-guidance/allowed-third-party-license-policy.md) | [GOVERNANCE.md, §License](../../refs/falcosecurity/evolution/GOVERNANCE.md) |
| **Documentation** | [Creative Commons Attribution 4.0 International (CC-BY-4.0)](https://creativecommons.org/licenses/by/4.0/legalcode) | [GOVERNANCE.md, §License](../../refs/falcosecurity/evolution/GOVERNANCE.md) |
| **Copyright notices** | `Copyright (C) XXXX The Falco Authors` (where `XXXX` is the most recent year the file was updated) | [GOVERNANCE.md, §License](../../refs/falcosecurity/evolution/GOVERNANCE.md), per [CNCF Copyright Notices](../../refs/cncf/foundation/copyright-notices.md) |
| **Contributions** | [DCO sign-off](https://developercertificate.org/) required for all new code | [GOVERNANCE.md, §License](../../refs/falcosecurity/evolution/GOVERNANCE.md) |

### SPDX License Identifiers

In September 2023, following a CNCF license scan, the Falco project adopted SPDX License Identifiers across all repositories ([evolution#318](https://github.com/falcosecurity/evolution/issues/318)).

**Background**: A CNCF-requested license scan revealed no outstanding issues but recommended two action items:
1. Add `LICENSE` file to repos that only had `COPYING` ([evolution#317](https://github.com/falcosecurity/evolution/issues/317)) — completed October 2023
2. Add SPDX License Identifiers to all source file headers ([evolution#318](https://github.com/falcosecurity/evolution/issues/318)) — rollout across 24+ repositories

**SPDX identifier format**: `// SPDX-License-Identifier: Apache-2.0` added to all source file headers across the organization. PRs were opened for every repository under the `falcosecurity` organization.

### CNCF License Exceptions for Falco

The Falco project has obtained the following license exceptions from the CNCF Governing Board:

#### Kernel Module (GPL-2.0-only OR MIT)

Falco's [kernel module](https://github.com/falcosecurity/libs/blob/master/driver/main.c) is dual-licensed under `GPL-2.0-only OR MIT`. Since GPL is not on the CNCF allowlist, an exception was required.

- **Request**: [cncf/foundation#645](https://github.com/cncf/foundation/issues/645) (filed October 2023)
- **Approved**: February 27, 2024 by the CNCF Governing Board
- **Documented**: In [`license-exceptions/`](../../refs/cncf/foundation/license-exceptions/) as approved exception

#### libelf (LGPL — dynamic linking only)

`libelf` is an ELF file handling library used by Falco for eBPF program processing. It is licensed under LGPL, which is not on the CNCF allowlist.

- **Request**: [cncf/foundation#629](https://github.com/cncf/foundation/issues/629) (filed August 2023, also covering `libcurl` and `uthash`)
- **Approved**: February 12, 2024 — exception for `libelf` granted for **dynamic linking only**
- **Follow-up**: The CNCF Legal Committee recommended switching from static to dynamic linking. Tracked in [evolution#359](https://github.com/falcosecurity/evolution/issues/359) (closed February 2024). Relevant PRs: [libs#1666](https://github.com/falcosecurity/libs/pull/1666), [falco#3048](https://github.com/falcosecurity/falco/pull/3048), [falco#3053](https://github.com/falcosecurity/falco/pull/3053).

#### libcurl (curl License) and uthash (BSD-style)

`libcurl` and `uthash` are C libraries statically linked in Falco. `libcurl` uses the "curl License" (MIT-inspired but not identical); `uthash` uses a BSD-style license.

- **Request**: [cncf/foundation#629](https://github.com/cncf/foundation/issues/629) (filed August 2023)
- **Approved**: February 12, 2024

### HashiCorp MPL to BUSL Audit

In August 2023, following HashiCorp's license change from MPL to BUSL, the Falco project conducted an audit of all Go dependencies across the `falcosecurity` organization ([evolution#305](https://github.com/falcosecurity/evolution/issues/305)).

**Key findings**:
- **No BUSL-licensed packages** were in use — the project was unaffected by the MPL→BUSL transition
- Several HashiCorp packages under **MPL-2.0** were identified that lacked a CNCF Governing Board exception
- Cleanup PRs were opened for `driverkit`, `falcoctl`, `event-generator`, `plugins`, and `falcosidekick` to remove unnecessary MPL-2.0 dependencies
- Already-approved HashiCorp packages (via [allowlist](../../refs/cncf/foundation/policies-guidance/allowed-third-party-license-policy.md) or prior exceptions) were documented

This audit was closed January 2024 after cleanups were completed.

### CI License Checking

An initiative to automate license compliance checking in CI ([evolution#330](https://github.com/falcosecurity/evolution/issues/330), filed October 2023) was proposed to check licensing requirements when PRs are opened. This was related to the SPDX and LICENSE file standardization efforts ([evolution#317](https://github.com/falcosecurity/evolution/issues/317), [evolution#318](https://github.com/falcosecurity/evolution/issues/318)). The issue was closed in September 2025 due to inactivity without implementation.

---

## Source Files

This digest was created from the following source files in the [falcosecurity/evolution](https://github.com/falcosecurity/evolution) repository:

| File | Description |
|------|-------------|
| [README.md](../../refs/falcosecurity/evolution/README.md) | Repository overview with repository tables |
| [GOVERNANCE.md](../../refs/falcosecurity/evolution/GOVERNANCE.md) | Project governance model and decision-making processes |
| [REPOSITORIES.md](../../refs/falcosecurity/evolution/REPOSITORIES.md) | Repository lifecycle, scope, and status definitions |
| [repositories.yaml](../../refs/falcosecurity/evolution/repositories.yaml) | Machine-readable list of all repositories with scope and status |
| [MAINTAINERS.md](../../refs/falcosecurity/evolution/MAINTAINERS.md) | Auto-generated list of core maintainers and maintainers |
| [maintainers.yaml](../../refs/falcosecurity/evolution/maintainers.yaml) | Machine-readable list of maintainers with affiliations and projects |
| [MAINTAINERS_GUIDELINES.md](../../refs/falcosecurity/evolution/MAINTAINERS_GUIDELINES.md) | Guidelines for onboarding/offboarding maintainers |
| [CODE_OF_CONDUCT.md](../../refs/falcosecurity/evolution/CODE_OF_CONDUCT.md) | CNCF Code of Conduct reference |

---

*Last updated: 2026-02-03*
