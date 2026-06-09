# CNCF Foundation - Licensing Policies Digest

This digest covers the licensing and intellectual property policies from the [CNCF Foundation](https://github.com/cncf/foundation) repository that are relevant to CNCF projects, with particular attention to how they apply to the Falco project.

**Applicable to**: All CNCF projects (not era-specific)

---

## Table of Contents

- [CNCF Charter Section 11: IP Policy](#cncf-charter-section-11-ip-policy)
- [Allowed Third-Party License Policy](#allowed-third-party-license-policy)
  - [Allowlist Criteria](#allowlist-criteria)
  - [Approved Licenses](#approved-licenses)
  - [Exception Process](#exception-process)
- [Container Image Guidance](#container-image-guidance)
  - [Base Image Selection](#base-image-selection)
  - [Binary Releases and Built Container Images](#binary-releases-and-built-container-images)
- [Copyright Notices](#copyright-notices)
- [Sources](#sources)

---

## CNCF Charter Section 11: IP Policy

The CNCF Charter [Section 11](../../refs/cncf/foundation/charter.md) defines the foundational intellectual property requirements for all CNCF projects.

### Project Admission Requirements

Every CNCF project must ([charter.md, §11(a)](../../refs/cncf/foundation/charter.md)):

1. **Trademark transfer**: Transfer ownership of trademark and logo assets to the Linux Foundation or a Linux Foundation project hosting entity
2. **OSI-approved licenses only**: Use only OSI-approved open source software licenses for code development
3. **Standards licensing**: For new technical specifications/standards not tied to specific software, use the Community Specification License (CSL) or a JDF template
4. **Software-tied specifications**: For specifications designed for a specific piece of software (e.g., API specs), use CSL, JDF, or Apache License 2.0

### Code and Documentation Licensing

Per [charter.md, §11(b)](../../refs/cncf/foundation/charter.md):

| Artifact | License | Notes |
|----------|---------|-------|
| **Inbound code contributions** | Apache License 2.0 | Must be accompanied by a DCO sign-off |
| **Outbound code** | Apache License 2.0 | All code made available under Apache-2.0 |
| **Documentation** | Creative Commons Attribution 4.0 International (CC-BY-4.0) | Both received and distributed under CC-BY-4.0 |

### CLA vs DCO

Each project decides whether to require a CNCF CLA ([charter.md, §11(b)(i)](../../refs/cncf/foundation/charter.md)). If a CLA is used, contributors undertake obligations from the Apache CLA, adapted for CNCF/the project. Regardless of CLA choice, all contributions must include a DCO sign-off.

> **Falco context**: The Falco project uses DCO sign-off (not CLA). Contributors must sign off Git commits to certify they adhere to the [Developer Certificate of Origin](https://developercertificate.org/).

### Governing Board Exceptions

The Governing Board may approve alternative licenses on an exception basis when required for compliance with a leveraged open source project or to achieve CNCF's mission ([charter.md, §11(c)](../../refs/cncf/foundation/charter.md)).

---

## Allowed Third-Party License Policy

**Source**: [`policies-guidance/allowed-third-party-license-policy.md`](../../refs/cncf/foundation/policies-guidance/allowed-third-party-license-policy.md)

Dependencies licensed under Apache-2.0 require no additional review since they match the CNCF project license. The Allowlist License Policy (adopted by the CNCF Governing Board on 2018-05-01) streamlines approval for certain non-Apache-2.0 components.

### Allowlist Criteria

A third-party component under a non-Apache-2.0 license receives **automatic** Governing Board approval if **all** of the following conditions are met ([allowed-third-party-license-policy.md](../../refs/cncf/foundation/policies-guidance/allowed-third-party-license-policy.md)):

1. **Approved license**: Fully licensable under one or more of the [Approved Licenses](#approved-licenses) (including combinations with Apache-2.0)

2. **Storage**: Either:
   - (A) Stored unmodified in a designated third-party folder, **or**
   - (B) Not stored in the CNCF project repository — retrieved at installation or build time from the upstream repository

3. **Established usage**: Demonstrates substantial external use via:
   - Part of the applicable programming language's standard library, **or**
   - Created on GitHub at least 12 months prior with minimum 10 stars or 10 forks

### Approved Licenses

Components must be fully licensable under one or more of these licenses (SPDX identifiers unless noted) ([allowed-third-party-license-policy.md](../../refs/cncf/foundation/policies-guidance/allowed-third-party-license-policy.md)):

| License | SPDX ID |
|---------|---------|
| Zero-clause BSD | `0BSD` |
| 2-Clause BSD | `BSD-2-Clause` |
| 2-Clause BSD (FreeBSD) | `BSD-2-Clause-FreeBSD` |
| 3-Clause BSD | `BSD-3-Clause` |
| MIT License | `MIT` |
| MIT No Attribution | `MIT-0` |
| ISC License | `ISC` |
| OpenSSL License | `OpenSSL` |
| OpenSSL Standalone | `OpenSSL-standalone` |
| Python Software Foundation 2.0 | `PSF-2.0` |
| Python License 2.0 | `Python-2.0` |
| Python License 2.0.1 | `Python-2.0.1` |
| PostgreSQL License | `PostgreSQL` |
| SSLeay Standalone | `SSLeay-standalone` |
| Universal Permissive License 1.0 | `UPL-1.0` |
| X11 License | `X11` |
| zlib License | `Zlib` |
| Google patent license for Golang | [PATENTS](https://golang.org/PATENTS) (not on SPDX list) |

**Key takeaway**: Licenses **not** on this list (e.g., LGPL, GPL, MPL-2.0) require an explicit Governing Board exception.

### Exception Process

For dependencies that don't satisfy the allowlist ([allowed-third-party-license-policy.md](../../refs/cncf/foundation/policies-guidance/allowed-third-party-license-policy.md)):

1. Project maintainer files a request using the [issue template](https://github.com/cncf/foundation/issues/new?template=license-exception-request.yaml)
2. CNCF staff reviews and adds to the [Licensing Exception Board](https://github.com/orgs/cncf/projects/44)
3. Staff coordinates with Legal for Legal Committee review and Governing Board presentation
4. Vote is called per CNCF Charter procedures
5. Approval: staff posts in the issue with link to the PR where approved
6. Denial: issue is closed

Exception results are documented in the [`license-exceptions/`](../../refs/cncf/foundation/license-exceptions/) directory (CSV, JSON, and SPDX formats).

---

## Container Image Guidance

**Source**: [`policies-guidance/container-image-guidance.md`](../../refs/cncf/foundation/policies-guidance/container-image-guidance.md)

Version 1.0 (June 4, 2025). This guidance addresses how CNCF projects should handle container base images and binary releases, focusing on security, licensing, and transparency.

> **Context**: This guidance was developed following a request from the Falco project about container base image licensing (specifically Red Hat UBI) in [cncf/foundation#362](https://github.com/cncf/foundation/issues/362).

### Base Image Selection

CNCF projects should abide by these guidelines when selecting base images ([container-image-guidance.md, §A](../../refs/cncf/foundation/policies-guidance/container-image-guidance.md)):

1. **Minimization**: Use the most minimal base image reasonably necessary; prefer `FROM scratch` or minimal base images over larger distributions; use multi-stage builds to reduce components. The base image itself should have a publicly-visible Dockerfile/Containerfile.

2. **Supports Compliance**: Use base images that make available artifacts (license notices, copyright notices, source code) enabling license compliance. Avoid base images where applicable license texts or notices have been omitted.

### Binary Releases and Built Container Images

Guidelines for releasing binary/container images ([container-image-guidance.md, §B](../../refs/cncf/foundation/policies-guidance/container-image-guidance.md)):

1. **Transparency**: Only include software/content from:
   - (A) The project's own source code repositories
   - (B) Standard package managers for the applicable ecosystems
   - (C) Exceptional circumstances (must be documented publicly)

2. **Compliance**: Make available all artifacts necessary for open source license compliance. Binary blobs without source code must at minimum be under a license permitting free redistribution, and should be reviewed by CNCF Legal Committee & Governing Board.

3. **Visibility**: Clearly communicate base image details to end users through SBOMs (software bills of materials) or equivalent mechanisms in standardized, machine-readable formats.

---

## Copyright Notices

**Source**: [`copyright-notices.md`](../../refs/cncf/foundation/copyright-notices.md)

### Ownership Model

Copyright ownership in CNCF project contributions is **retained by the original copyright holders**. Copyrights are **licensed** (not assigned) to CNCF, whether the project uses DCO or CLA.

### Recommended Notice Format

CNCF recommends using general statements rather than listing individual contributors ([copyright-notices.md](../../refs/cncf/foundation/copyright-notices.md)):

- `Copyright The <Project> Authors.`
- `Copyright The <Project> Contributors.`
- `Copyright Contributors to the <Project> project.`

> **Falco context**: The Falco project uses the format `Copyright (C) XXXX The Falco Authors` where `XXXX` is the most recent year the file was updated, as specified in [GOVERNANCE.md, §License](../../refs/falcosecurity/evolution/GOVERNANCE.md).

### Third-Party Code

Preserve existing copyright and license notices unchanged for third-party code. When adding copyrightable content to pre-existing third-party files, a general copyright statement may be added. Never modify or remove someone else's notices without explicit permission.

---

## Sources

| Topic | Source File |
|-------|-------------|
| IP Policy (Charter §11) | [`charter.md`](../../refs/cncf/foundation/charter.md) |
| Allowed Third-Party License Policy | [`policies-guidance/allowed-third-party-license-policy.md`](../../refs/cncf/foundation/policies-guidance/allowed-third-party-license-policy.md) |
| Container Image Guidance | [`policies-guidance/container-image-guidance.md`](../../refs/cncf/foundation/policies-guidance/container-image-guidance.md) |
| Copyright Notices | [`copyright-notices.md`](../../refs/cncf/foundation/copyright-notices.md) |
| License Exceptions | [`license-exceptions/`](../../refs/cncf/foundation/license-exceptions/) |

---

*Last updated: 2026-02-19*
