# Falco Community Repository Digest

**Source:** [`refs/falcosecurity/community/`](../../refs/falcosecurity/community/)
**Era:** 0.44
**Last Updated:** 2026-05-27

## Overview

The [falcosecurity/community](https://github.com/falcosecurity/community) repository serves as the central hub for Falco community coordination. It contains resources for community engagement, meeting notes, contribution guidelines, and historical records of project discussions.

**Scope:** Special (per [evolution/repositories.yaml](../../refs/falcosecurity/evolution/repositories.yaml))

> **Note:** Governance, maintainer lists, and repository guidelines live in the [evolution](evolution.md) repository, not here. This repo focuses on community coordination and engagement.

## Communication Channels

| Channel | Location | Purpose |
|---------|----------|---------|
| Slack | `#falco` on [Kubernetes Slack](https://kubernetes.slack.com/messages/falco) | Real-time community chat |
| Mailing List | [cncf-falco-dev@lists.cncf.io](https://lists.cncf.io/g/cncf-falco-dev) | Announcements, calendar invites |
| YouTube | [Falco Channel](https://www.youtube.com/channel/UCd7LDOK1nN5jIULHk-LJJtA) | Recorded community calls |
| Twitter/X | [@falco_org](https://twitter.com/falco_org) | Social announcements |
| LinkedIn | [Falco Security OSS](https://www.linkedin.com/company/falco-security-oss) | Professional updates |

**Source:** [README.md](../../refs/falcosecurity/community/README.md)

## Community Calls

### Schedule

- **Frequency:** Biweekly (every 2 weeks)
- **Day:** Wednesday
- **Time:** 4pm UTC
- **Calendar:** [CNCF Falco Calendar](https://lists.cncf.io/g/cncf-falco-dev/calendar)
- **ICS Feed:** `https://lists.cncf.io/g/cncf-falco-dev/ics/7639482/1350118793/feed.ics`
- **Zoom:** https://zoom.us/my/cncffalcoproject

### Call Structure

Each community call has three parts:

1. **Latest News** - Project and ecosystem updates
2. **Lightning Talk** (5 min) - Anyone can present on any topic (features, POCs, use cases, tips)
3. **Open Discussion** - Q&A with maintainers

### How to Participate

- **Book a lightning talk:** Add to the [HackMD agenda](https://hackmd.io/bDCYZ717QSWA1UBZXRSPfw#/)
- **MC role:** Rotates among community members; volunteer in advance
- All calls adhere to [CNCF Code of Conduct](https://github.com/cncf/foundation/blob/master/code-of-conduct.md)

### Running a Call

Requirements for any Falco community call:
- Send calendar invite to [cncf-falco-dev@lists.cncf.io](mailto:cncf-falco-dev@lists.cncf.io)
- Record and upload to [YouTube channel](https://www.youtube.com/channel/UCd7LDOK1nN5jIULHk-LJJtA)
- Use [HackMD](https://hackmd.io) for collaborative minutes
- Post notes to repository after meeting

**Meeting Note Template:** [meeting-note-template.md](../../refs/falcosecurity/community/meeting-note-template.md)

```markdown
# Falco Community Call
## YYYY-MM-DD
### MC
- [Name](https://github.com/handle)
### Who joined
- [Name](https://github.com/handle)
### This week highlights
-
### Agenda
-
### Closing
- **MC Next Call**:
```

**Source:** [README.md](../../refs/falcosecurity/community/README.md)

## Blog Contribution Guidelines

The Falco blog serves as an educational resource for the community.

### Acceptable Content

- Technical content and how-to's
- Cloud-native runtime security stories
- Use cases and success stories
- Industry insight into Kubernetes threat detection
- Plugin development articles
- Rule writing guides
- Project updates and announcements
- Reposted content (with editing for SEO)

**Not Acceptable:** Vendor or product pitches

### Suggested Topics

- Falco best practices
- How-to guides for Falco and plugins
- Case studies
- Threat detection best practices
- Alert optimization
- Out-of-the-box rules explanation
- Roadmap and announcements

### Submission Process

1. **Fork** [falcosecurity/falco-website](https://github.com/falcosecurity/falco-website)
2. **Clone** and create a new branch
3. **Create** blog post in markdown (see [existing posts](https://github.com/falcosecurity/falco-website/tree/master/content/en/blog))
4. **Add images** to [img folder](https://github.com/falcosecurity/falco-website/tree/master/static/img)
5. **Commit** with signoff and push
6. **Create PR** to upstream repo

### Editorial Process

- **Review time:** 5-7 business days
- **Turnaround:** ~2 weeks end-to-end
- **Publication:** 1 blog per week goal
- **Schedule:** Community blogs publish Tuesday & Thursday
- **Calendar:** [Editorial Calendar](https://docs.google.com/spreadsheets/d/1LiE5yE3kplD_Kg3y1YVZphCiChmqC2xynMJLoqlREPM/edit?usp=sharing)

### Promotion

Published blogs are promoted via:
- Falco Twitter
- CNCF Kubeweekly
- Kubernetes Slack `#falco`
- [Falco Monthly Newsletter](https://www.linkedin.com/build-relation/newsletter-follow?entityUrn=7036397737373818880)
- Falco LinkedIn

**Source:** [blog-contribution-guidelines.md](../../refs/falcosecurity/community/blog-contribution-guidelines.md)

## Community Appreciation Program

Recognition program for community contributors with swag awards.

### Contribution Tiers

| Tier | Criteria | Rewards |
|------|----------|---------|
| **Bronze** | 1 blog on falco.org OR company blog; social share | Sticker, digital badge, social post |
| **Silver** | 1 doc post; 1st MC volunteer; 2+ blogs | Socks, sticker, digital badge, social post |
| **Gold** | 1 bug fix + docs; event staffing (2hr min); run KubeCon meeting | Echo bottle, sticker, digital badge, social post |
| **Platinum** | 1 new feature + docs; 3 contributor-of-month nominations; release manager; 5x MC | T-shirt, Falco coin, sticker, digital badge, social post |
| **Diamond** | High-priority issue; 5 bug fixes + docs; conference talk; workshop proctor; maintainer nomination; contributor-of-month winner | Hoodie, coin, pin, sticker, digital badge, social post |

### How to Claim

1. Go to [community repo issues](https://github.com/falcosecurity/community/issues)
2. Comment on current month's "[Community appreciation program Month - call for submissions](https://github.com/falcosecurity/community/issues/177)" issue
3. Submission closes 4th Wednesday of each month
4. Program manager sends swag order form by month end

**Submission Template:**
```
Name:
Contribution summary:
Github or link to your contribution:
```

**Source:** [community-appreciation-program.md](../../refs/falcosecurity/community/community-appreciation-program.md)

## Project History (from Meeting Notes)

Key milestones extracted from the meeting notes archive:

| Date | Milestone | Notes |
|------|-----------|-------|
| June 2019 | First official Office Hours | Falcosidekick proposed by Thomas Labarussias |
| July 2019 | CNCF Incubation preparation | Technical due diligence requirements discussed |
| Jan 2022 | Plugin system released (0.31) | "Gyrfalcon" release - major architectural change |
| Mar 2022 | Modern BPF probe proposal | libs PR#268 introduced new eBPF architecture |
| Apr 2022 | Lua removed from Falco | Rule engine rewritten in C++ |
| May 2022 | K8S Audit Logs became plugin | First major component moved to plugin architecture |
| Apr 2023 | Roadmap management adopted | New release cycle process ([proposal](https://github.com/falcosecurity/falco/blob/master/proposals/20230511-roadmap-management.md)) |
| Sep 2023 | Rules maturity framework | Stable/Incubating/Sandbox classification for rules |
| Mar 2024 | **CNCF Graduation** | Falco became a graduated CNCF project |
| May 2024 | Modern eBPF default (0.38) | Modern probe became the default driver |
| Jan 2025 | Biweekly community calls | Changed from weekly to biweekly schedule |
| 2025-2026 | Container plugin | Container metadata reimplemented as plugin |

**Sources:** [2019-06-06.md](../../refs/falcosecurity/community/meeting-notes/2019-06-06.md), [release-0.32.0.md](../../refs/falcosecurity/community/meeting-notes/release-0.32.0.md), [release-0.38.0.md](../../refs/falcosecurity/community/meeting-notes/release-0.38.0.md)

## Release Process

Adopted from the [April 2023 Roadmap Discussion](../../refs/falcosecurity/community/meeting-notes/2023-04-27-Falco-Roadmap-Discussion.md):

### Release Cycle

- **8 weeks** development phase
- **4 weeks** stabilization phase
- **4 weeks** release preparation

### Release Schedule

Falco releases 3 times per year:
- Last Monday of **January**
- Last Monday of **May**
- Last Monday of **September**

### Core Maintainers Meetings

- **Monthly meetings** (around first week of each month)
- Skip Mar, Jul, Nov (9 meetings per year)
- Agenda prepared in advance
- Planning sessions define priorities for each release

**Source:** [2023-04-27-Falco-Roadmap-Discussion.md](../../refs/falcosecurity/community/meeting-notes/2023-04-27-Falco-Roadmap-Discussion.md)

## Falco 1.0 Roadmap Status

From [February 2025 Core Maintainers Meeting](../../refs/falcosecurity/community/meeting-notes/2025-02-20-Falco-Core-Maintainers.md):

| Area | Goal | Status (as of Feb 2025) |
|------|------|-------------------------|
| **Engine** | Adoption/deprecation policies | Delayed |
| | Streamlining falco.yaml | In progress |
| | CLI args standardization | Done |
| | Advanced metrics support | Stable |
| **Syntax** | Language inconsistencies | On hold |
| | New constructs | Acceptable |
| **Drivers** | Modern eBPF as default | Done (0.38) |
| **Distribution** | Packages consolidation | Not started |
| | Signatures for drivers/packages | In progress |
| | No-driver/distroless default image | Done (0.40) |
| | Supply chain security | Needs review |
| **Documentation** | Feature adoption/deprecation docs | Not started |
| | Troubleshooting guide | Needs review |
| | Operationalizing alerts guide | Not started |
| | Non-Kubernetes docs | Done |
| **Integrations** | Container runtime stability | In progress (container plugin) |
| | Plugin Framework access | Done |

**Key decision:** Falco 1.0 will be declared when all goals are achieved; delayed due to capacity constraints.

## Technical Evolution Highlights

### Key Architectural Decisions (Still Relevant)

1. **Plugin System** (0.31+)
   - Extensible input sources and field extractors
   - K8S Audit Logs, CloudTrail, Okta, GitHub plugins available
   - Container metadata moving to plugin architecture (0.41+)

2. **Modern eBPF Probe** (default since 0.38)
   - CO-RE (Compile Once, Run Everywhere)
   - No kernel headers required
   - Better performance than legacy probe

3. **Rules Maturity Framework** (0.36+)
   - **Stable**: Production-ready rules
   - **Incubating**: Testing rules
   - **Sandbox**: Experimental rules

4. **Drop Syscall Enter Events** (libs 0.23.0)
   - Major performance improvement
   - Drivers no longer generate enter events
   - Exit events extended with enter event parameters

5. **Falcoctl as Driver Loader**
   - Replaced legacy `falco-driver-loader` script
   - Automatic driver selection mechanism

### Current Deprecations/Removals

| Component | Status | Alternative |
|-----------|--------|-------------|
| falco-exporter | Deprecated | Built-in Prometheus metrics |
| Legacy eBPF probe | Removed in 0.44 (deprecated in 0.43) | Modern eBPF probe |
| gVisor libscap engine | Removed in 0.44 (deprecated in 0.43) | - |
| gRPC output | Removed in 0.44 (deprecated in 0.43) | HTTP output, plugins |
| Chisels | Removed from libs | - |
| Python regression tests | Removed | Go testing framework |

**Sources:** [2023-06-08-Falco-Core-Maintainers.md](../../refs/falcosecurity/community/meeting-notes/2023-06-08-Falco-Core-Maintainers.md), [release-0.43.0.md](../../refs/falcosecurity/community/meeting-notes/release-0.43.0.md)

## Meeting Notes Archive

Historical meeting notes are stored in [`meeting-notes/`](../../refs/falcosecurity/community/meeting-notes/).

### Types of Meeting Notes

| Type | Naming Convention | Purpose |
|------|-------------------|---------|
| Community Calls | `YYYY-MM-DD.md` | Regular biweekly community meetings |
| Release Planning | `release-X.XX.X.md` | Release coordination and tracking |
| Core Maintainers | `YYYY-MM-DD-Falco-Core-Maintainers.md` | Technical maintainer discussions |
| Working Groups | `YYYY-MM-DD-infra-wg.md`, etc. | Focused working group meetings |
| Special Topics | Descriptive names | New contributors, roadmap discussions |

### Coverage

- **Earliest:** June 2019 (first Office Hours)
- **Latest:** February 2026 (current era)
- **Release notes:** 0.28.0 through 0.43.0 (0.44.0 meeting notes pending publication upstream)

### Key Historical Documents

| Document | Content |
|----------|---------|
| [2019-06-06.md](../../refs/falcosecurity/community/meeting-notes/2019-06-06.md) | First meeting, Falcosidekick proposal |
| [2019-07-04.md](../../refs/falcosecurity/community/meeting-notes/2019-07-04.md) | CNCF incubation requirements, rules versioning |
| [2023-04-27-Falco-Roadmap-Discussion.md](../../refs/falcosecurity/community/meeting-notes/2023-04-27-Falco-Roadmap-Discussion.md) | Release cycle definition |
| [2023-06-08-Falco-Core-Maintainers.md](../../refs/falcosecurity/community/meeting-notes/2023-06-08-Falco-Core-Maintainers.md) | Graduation requirements, roadmap planning |
| [2024-02-01-Falco-Core-Maintainers.md](../../refs/falcosecurity/community/meeting-notes/2024-02-01-Falco-Core-Maintainers.md) | Falco 1.0 roadmap discussion |
| [2025-02-20-Falco-Core-Maintainers.md](../../refs/falcosecurity/community/meeting-notes/2025-02-20-Falco-Core-Maintainers.md) | 1.0 roadmap status, K8s operator |

### Most Recent Published Release Notes (0.43)

The [release-0.43.0.md](../../refs/falcosecurity/community/meeting-notes/release-0.43.0.md) file is the latest published release-notes file in the community repo at the time of the 0.44 era pin. It documents the 0.43 release cycle (Oct 2025 - Jan 2026):

- **GPG Key Rotation** for Falco Packages (2026) - completed
- **Multi-thread Falco** proposal under discussion
- **Drop syscall enter events** completed in libs 0.23.0
- **Deprecations**: Legacy probe, gVisor libscap engine, gRPC output
- **Community funding** via [LFX Crowdfunding](https://crowdfunding.lfx.linuxfoundation.org/projects/falco)
- **OpenSSF Best Practices** and Scorecard review planned
- **Website updates**: Hugo 0.154.5, Docsy theme upgrade planned

## Repository Ownership

**Source:** [OWNERS](../../refs/falcosecurity/community/OWNERS)

| Role | Members |
|------|---------|
| **Approvers** | leogr, Issif, Andreagit97, terylt, maxgio92, araujof |
| **Reviewers** | kaizhe, mstemm |
| **Emeritus** | leodido, fntlnz, mfdii, kris-nova, danpopnyc, nibalizer |

## Additional Resources

### Logo Assets

Located in [`logo/`](../../refs/falcosecurity/community/logo/):
- `primary-logo.png` - Main Falco logo
- `teal-logo.svg` - Teal variant (SVG)
- `white-logo.png` - White variant

### Live Streams

The [`live-streams/`](../../refs/falcosecurity/community/live-streams/) directory contains materials for Falco live streaming sessions.

### Cross-References

For governance and organizational information, see:
- **Governance:** [evolution/GOVERNANCE.md](../../refs/falcosecurity/evolution/GOVERNANCE.md)
- **Code of Conduct:** [evolution/CODE_OF_CONDUCT.md](../../refs/falcosecurity/evolution/CODE_OF_CONDUCT.md)
- **Maintainers Guidelines:** [evolution/MAINTAINERS_GUIDELINES.md](../../refs/falcosecurity/evolution/MAINTAINERS_GUIDELINES.md)
- **Maintainers List:** [evolution/MAINTAINERS.md](../../refs/falcosecurity/evolution/MAINTAINERS.md)
- **Repository Guidelines:** [evolution/REPOSITORIES.md](../../refs/falcosecurity/evolution/REPOSITORIES.md)
- **Contributing:** [.github/CONTRIBUTING.md](https://github.com/falcosecurity/.github/blob/main/CONTRIBUTING.md)
- **Security Policy:** [.github/SECURITY.md](https://github.com/falcosecurity/.github/blob/main/SECURITY.md)
- **Adopters:** [falco/ADOPTERS.md](https://github.com/falcosecurity/falco/blob/master/ADOPTERS.md)

## Sources

| Topic | Source File |
|-------|-------------|
| Community README | [`README.md`](../../refs/falcosecurity/community/README.md) |
| Blog guidelines | [`blog-contribution-guidelines.md`](../../refs/falcosecurity/community/blog-contribution-guidelines.md) |
| Appreciation program | [`community-appreciation-program.md`](../../refs/falcosecurity/community/community-appreciation-program.md) |
| Meeting note template | [`meeting-note-template.md`](../../refs/falcosecurity/community/meeting-note-template.md) |
| Repository ownership | [`OWNERS`](../../refs/falcosecurity/community/OWNERS) |
| Roadmap discussion | [`meeting-notes/2023-04-27-Falco-Roadmap-Discussion.md`](../../refs/falcosecurity/community/meeting-notes/2023-04-27-Falco-Roadmap-Discussion.md) |
| Core maintainers Feb 2025 | [`meeting-notes/2025-02-20-Falco-Core-Maintainers.md`](../../refs/falcosecurity/community/meeting-notes/2025-02-20-Falco-Core-Maintainers.md) |
| Release 0.43.0 notes | [`meeting-notes/release-0.43.0.md`](../../refs/falcosecurity/community/meeting-notes/release-0.43.0.md) |

---

## Version History

| Date | Changes |
|------|---------|
| 2026-02-03 | Initial digest creation |
| 2026-02-03 | Added project history, release process, 1.0 roadmap status, technical evolution from meeting notes archive |
