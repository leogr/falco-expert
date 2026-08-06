# Multi-Thread Falco Proposals

> **Era relevance:** Falco 0.44 contains the high-level design document, but its syscall event source still runs one event-processing loop. The pinned libs 0.25.4 sources do not contain the proposed concurrent thread-table implementation.

## Summary

The pinned proposal set contains three documents:

1. The Falco-level architecture and TGID partitioning design, present in the pinned Falco 0.44.1 sources.
2. A work-in-progress Folly-based thread-manager design snapshot fetched on February 18, 2026.
3. An earlier experimental RCU thread-manager design snapshot fetched on December 10, 2025.

The Folly document describes the RCU approach as challenging and intrusive and proposes a less invasive concurrent-container alternative. This digest treats the RCU document as design history, not as a second current recommendation.

**Sources:** [`20251205-multi-thread-falco-design.md`](../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md), [`20260212-thread-safe-thread-manager.md`](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md), [`20251127-thread-safe-sinsp-thread-manager.md`](../../refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md), [proposal snapshot metadata](../../refs/proposals/multi-thread-falco/README.md)

## Contents

- [Proposal and Status Map](#proposal-and-status-map)
- [Era 0.44 Baseline](#era-044-baseline)
- [Merged High-Level Design](#merged-high-level-design)
- [Pinned Folly Thread-Manager Proposal](#pinned-folly-thread-manager-proposal)
- [Historical RCU Proposal](#historical-rcu-proposal)
- [Sources](#sources)

## Proposal and Status Map

| Area / document | Scope | Current state |
|-----------------|-------|---------------|
| [Multi-Threaded Falco High-Level Design](../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md) | Falco architecture, event partitioning, ordering, rule evaluation, outputs | Present in the pinned Falco 0.44.1 proposal directory |
| [Thread-Safe Thread Manager Using Folly ConcurrentHashMap](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md) | Concurrent thread-table storage, lifetime-safe lookup and iteration, remaining shared state | Work-in-progress snapshot; proposed changes are absent from pinned libs 0.25.4 |
| [Original RCU Thread Manager](../../refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md) | Experimental RCU table and topology | Earlier experimental proposal superseded in the pinned proposal set by the Folly revision |

> **Provenance note:** This digest describes only documents stored under [`refs/`](../../refs/proposals/multi-thread-falco/README.md). Later branch-only revisions are intentionally excluded until they are ingested into the pinned corpus.

## Era 0.44 Baseline

### Falco event processing

Falco 0.44.1 creates one `source_sync_context` per enabled event source. With one source, it runs that source's processing loop on the main thread; with multiple sources, it creates one thread per source. It does not create multiple event-processing workers for a single syscall source.

**Source:** [`process_events.cpp:574-610`](../../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp)

### Libs state

Libs 0.25.4 still uses `std::unordered_map<int64_t, std::shared_ptr<sinsp_threadinfo>>` for the thread table. The manager exposes reference-returning lookups, raw-pointer topology helpers, and direct access to the table rather than the proposed concurrent-map API.

**Sources:** [`threadinfo.h:579-623`](../../refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h), [`thread_manager.h:60-156`](../../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h)

The pinned `sinsp_usergroup_manager` likewise has plain user/group maps and a plain `bool m_import_users`; its lookup APIs return raw pointers into those maps without the proposed synchronization or copy/visitor boundary.

**Sources:** [`user.h:62-206`](../../refs/falcosecurity/libs/userspace/libsinsp/user.h), [`user.cpp:521-561`](../../refs/falcosecurity/libs/userspace/libsinsp/user.cpp)

## Merged High-Level Design

The merged design targets event-drop reduction and throughput scaling beyond a single saturated core while preserving single-threaded performance as the default. It intentionally leaves component-level synchronization to separate designs.

**Source:** [`20251205-multi-thread-falco-design.md:3-26`](../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md)

### Selected architecture

The initial architecture selects static partitioning by TGID and supports only the modern eBPF probe. Its TGID routing depends on `BPF_MAP_TYPE_RINGBUF`; the kernel module and legacy eBPF probe instead use per-CPU buffers based on `BPF_MAP_TYPE_PERF_EVENT_ARRAY`.

```text
ring_buffer_index = hash(event->tgid) % num_workers
```

- The modern eBPF probe routes a TGID's events to a partition ring buffer.
- Each partition has a userspace event-loop worker.
- Libsinsp state is shared across workers and therefore requires synchronization.
- Rule evaluation runs in parallel on the worker processing each event.
- Falco's output queue is already designed for concurrent producers and a dedicated consumer.

**Source:** [`20251205-multi-thread-falco-design.md:28-69`](../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md)

### Ordering and consistency

TGID affinity preserves ordering within one thread group and usually gives thread-group-owned data a single writer. Cross-partition access remains necessary for parent/child state, process reparenting, and ancestor fields. A lagging partition can make ancestor data missing, stale, or temporally ahead, producing incorrect rule context. The proposal leaves the wait/defer and polling/signaling strategy to implementation and measurement.

**Source:** [`20251205-multi-thread-falco-design.md:71-116`](../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md)

Static TGID assignment can also concentrate a high-activity process on one worker. That worker becomes a bottleneck even if other workers have spare capacity, and the resulting lag increases the cross-partition consistency risk.

For clone/fork state, the proposal identifies the clone-exit-parent event as a natural synchronization point because the parent has finished preparing inherited state. `vfork()` is a special case: it blocks the parent until the child executes a new program or exits, delaying that event and potentially requiring a different synchronization point.

**Source:** [`20251205-multi-thread-falco-design.md:78-116`](../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md)

The proposal also evaluates TID, CPU, and functional-pipeline partitioning, but selects TGID as the initial trade-off among load distribution, contention, and temporal consistency.

**Source:** [`20251205-multi-thread-falco-design.md:118-180`](../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md)

## Pinned Folly Thread-Manager Proposal

The pinned work-in-progress thread-manager proposal replaces the `std::unordered_map` table with `folly::ConcurrentHashMap<int64_t, std::shared_ptr<sinsp_threadinfo>>`. It uses Folly iterators and hazard pointers for element lifetime, sharded writes, and copied `shared_ptr` values so callers do not retain references into the map.

**Source:** [`20260212-thread-safe-thread-manager.md:1-39`](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md)

### API and lifetime changes

| Current libs 0.25.4 shape | Proposed shape |
|---------------------------|----------------|
| `get_thread()` / `find_thread()` return an internal `shared_ptr` reference | Return `shared_ptr` by value |
| Single-entry lookup cache | Remove shared lookup/insert caches |
| `get_threads()` exposes the table | Use callback-based iteration |
| Some topology helpers return raw `sinsp_threadinfo*` | Return owning `shared_ptr` handles |
| `std::unordered_map` insertion/erase | Folly concurrent-map operations |

Returning copied handles keeps a thread object alive after a concurrent erase. The proposal also removes caches that would be shared mutable state under concurrent callers.

**Source:** [`20260212-thread-safe-thread-manager.md:71-134`](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md)

### Scope and remaining synchronization

Concurrent map operations cover thread-table lookup, insertion, removal, and iteration; they do not by themselves make mutable `sinsp_threadinfo` contents safe. FD-table synchronization is also explicitly out of scope. Compatibility with the state-table and plugin APIs remains a requirement at the `shared_ptr` boundary. The proposal specifies concurrent add/find/remove/iteration tests under ThreadSanitizer.

**Sources:** [`20260212-thread-safe-thread-manager.md:23-50`](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md), [`20260212-thread-safe-thread-manager.md:254-272`](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md)

## Historical RCU Proposal

The original libs proposal explored a custom RCU design: a preallocated atomic TID table, intrusive topology lists, a global writer mutex, and deferred reclamation. It was framed as an experimental starting point and identified writer serialization and cross-structure temporal inconsistency as central risks.

**Source:** [`20251127-thread-safe-sinsp-thread-manager.md`](../../refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md)

The pinned Folly snapshot describes the RCU approach as challenging and intrusive, then proposes using a concurrent container to reduce custom reclamation logic and API churn. The RCU document therefore remains useful design history, but the pinned proposal set presents Folly as its revision.

**Source:** [`20260212-thread-safe-thread-manager.md:9-19`](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md)

## Sources

| Topic | Source |
|-------|--------|
| Merged high-level design | [`20251205-multi-thread-falco-design.md`](../../refs/falcosecurity/falco/proposals/20251205-multi-thread-falco-design.md) |
| Falco 0.44 event loop | [`process_events.cpp`](../../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp) |
| Historical RCU proposal | [`20251127-thread-safe-sinsp-thread-manager.md`](../../refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md) |
| Pinned Folly proposal snapshot | [`20260212-thread-safe-thread-manager.md`](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md) |
| Proposal snapshot metadata | [`README.md`](../../refs/proposals/multi-thread-falco/README.md) |
| Pinned thread table | [`threadinfo.h`](../../refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h) |
| Pinned thread-manager API | [`thread_manager.h`](../../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h) |
| Pinned user/group manager | [`user.h`](../../refs/falcosecurity/libs/userspace/libsinsp/user.h), [`user.cpp`](../../refs/falcosecurity/libs/userspace/libsinsp/user.cpp) |
