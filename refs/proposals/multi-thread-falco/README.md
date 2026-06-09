# Multi-Thread Falco Proposals

This directory contains raw proposal documents for the multi-threaded Falco initiative. These proposals are **not yet merged** into the main repositories and represent ongoing design work.

## Status

- **Proposal status:** Open / Work in Progress
- **Target era:** Post-0.43 (no ETA)
- **Not implemented** in Falco 0.43
- **Not yet verified** — proposals include several approaches that require PoC or implementation to validate

## Documents

| File | Source | Author | Date |
|------|--------|--------|------|
| [`20251205-multi-thread-falco-design.md`](20251205-multi-thread-falco-design.md) | [falcosecurity/falco#3751](https://github.com/falcosecurity/falco/pull/3751) | Iacopo Rozzo ([@irozzo-1A](https://github.com/irozzo-1A)) | Dec 5, 2025 |
| [`20251127-thread-safe-sinsp-thread-manager.md`](20251127-thread-safe-sinsp-thread-manager.md) | [falcosecurity/libs#2739](https://github.com/falcosecurity/libs/pull/2739) | Iacopo Rozzo ([@irozzo-1A](https://github.com/irozzo-1A)) | Nov 27, 2025 |
| [`20260212-thread-safe-thread-manager.md`](20260212-thread-safe-thread-manager.md) | [irozzo-1A/agent-libs@145d3c2](https://github.com/irozzo-1A/agent-libs/blob/145d3c2db2da582054828a8376b3a386c6972634/proposals/20260212-thread-safe-thread-manager.md) (WIP) | Iacopo Rozzo ([@irozzo-1A](https://github.com/irozzo-1A)) | Feb 12, 2026 |

## Related Issue

- [falcosecurity/falco#3749](https://github.com/falcosecurity/falco/issues/3749) — [Proposal] Multi-threaded Falco

## Provenance Notes

- The first two documents were fetched from open (unmerged) PRs on Dec 5, 2025
- The third document is a WIP from the proposal author's fork, fetched on Feb 18, 2026
- The third document (Folly ConcurrentHashMap approach) is a revised alternative to the first libs proposal (RCU approach)
- Contents may change as the proposals evolve; refer to the source links for the latest versions
