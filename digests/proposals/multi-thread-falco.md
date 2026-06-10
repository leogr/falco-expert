# Multi-Thread Falco Proposals

> **Era Relevance:** Post-0.43 — multi-thread design proposal merged in 0.44; implementation still in progress | **Status:** Open proposals, not yet verified | **No ETA**
>
> **Source:** [`refs/proposals/multi-thread-falco/`](../../refs/proposals/multi-thread-falco/)

This digest documents the multi-thread Falco initiative — a set of proposals to transition Falco from its current single-threaded event processing architecture to a multi-threaded one. The proposals span two repositories (falco and libs) and address both the high-level architecture and the low-level data structure changes needed.

**Important caveats:**
- Multi-threading has **not been enabled at runtime** in any release through 0.44; the high-level design proposal was merged into the falco repo in 0.44 (`proposals/20251205-multi-thread-falco-design.md`) and only multi-thread-safety hardening (foundation work) landed in 0.44
- The proposals have **not yet been verified** through a PoC or code implementation
- Several approaches are presented as possibilities that require benchmarking to validate
- The proposals may evolve significantly before any implementation

---

## Table of Contents

- [Motivation and Problem Statement](#motivation-and-problem-statement)
- [Proposal Overview](#proposal-overview)
- [Current Architecture (Baseline)](#current-architecture-baseline)
- [High-Level Design: Multi-Threaded Falco](#high-level-design-multi-threaded-falco)
- [Work Partitioning Strategy](#work-partitioning-strategy)
- [Thread-Safe Thread Manager: RCU Approach](#thread-safe-thread-manager-rcu-approach)
- [Thread-Safe Thread Manager: Folly ConcurrentHashMap Approach](#thread-safe-thread-manager-folly-concurrenthashmap-approach)
- [Comparison of Thread Manager Approaches](#comparison-of-thread-manager-approaches)
- [Cross-Cutting Concerns](#cross-cutting-concerns)
- [Open Questions and Unresolved Areas](#open-questions-and-unresolved-areas)
- [PR Review Feedback](#pr-review-feedback)
- [Related Work](#related-work)
- [Sources](#sources)

---

## Motivation and Problem Statement

Falco's current single-threaded architecture creates a scalability bottleneck on modern multi-core systems[^1]. When the volume of generated syscall events exceeds the processing capacity of a single CPU core, Falco drops events — a critical failure for a security monitoring tool.

The problem is amplified by the trend toward higher core counts in cloud instances[^1]:

| Provider | Instance | vCPUs | Memory |
|----------|----------|-------|--------|
| AWS | u7inh-32tb.480xlarge | 1,920 | 32 TiB |
| Azure | Standard_M416bs_v3 | 416 | ~3.8 TiB |
| Google | M2-ultramem | 416 | 12 TiB |
| OCI | BM.Standard.E6.256 | 512 | 3 TiB |

**Core issue:** A single event loop processing syscall events risks CPU saturation, leading to dropped events that create blind spots in security monitoring[^1].

**Alternative (orthogonal) approach:** Pushing more filtering work to the kernel side ([libs#1557](https://github.com/falcosecurity/libs/issues/1557)) may reduce the problem but does not eliminate the fundamental single-thread bottleneck[^1].

**Historical context:** This problem was first raised in [falco#1403](https://github.com/falcosecurity/falco/issues/1403) (earlier discussion) and formally proposed in [falco#3749](https://github.com/falcosecurity/falco/issues/3749) (December 2025)[^1].

---

## Proposal Overview

The initiative comprises three proposal documents from a single author (Iacopo Rozzo, [@irozzo-1A](https://github.com/irozzo-1A)):

| Document | Scope | Repository | Status |
|----------|-------|------------|--------|
| [Multi-Thread Falco High-Level Design](../../refs/proposals/multi-thread-falco/20251205-multi-thread-falco-design.md) | Falco-level architecture, partitioning strategies, ring buffer routing | [falco#3751](https://github.com/falcosecurity/falco/pull/3751) | Open PR |
| [Thread-Safe sinsp_thread_manager (RCU)](../../refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md) | libs-level data structure using RCU + atomic array | [libs#2739](https://github.com/falcosecurity/libs/pull/2739) | Open PR |
| [Thread-Safe Thread Manager (Folly)](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md) | libs-level data structure using Folly ConcurrentHashMap | [WIP on author's fork](https://github.com/irozzo-1A/agent-libs/blob/145d3c2db2da582054828a8376b3a386c6972634/proposals/20260212-thread-safe-thread-manager.md) | WIP |

The third document (Folly approach) is a **revised alternative** to the second (RCU approach), motivated by the RCU approach being deemed "challenging and intrusive"[^3]. Both thread manager proposals address the same problem but with different trade-offs.

**Relationship between proposals:**
- The high-level design[^2] defines the overall multi-threaded architecture and partitioning strategy
- The thread manager proposals[^4][^3] address one specific component: making `sinsp_thread_manager` thread-safe to support the high-level design
- Additional proposals are expected for: thread-safe plugin architecture, `sinsp_threadinfo` field synchronization, and FD table thread safety[^2]

---

## Current Architecture (Baseline)

Understanding the current architecture is essential to evaluate the proposals. Key aspects:

### Single-Threaded Event Loop

Falco processes syscall events in a tight single-threaded loop[^2]:
1. **libscap** performs an `O(n_cpus)` scan across per-CPU ring buffers, returning the event with the minimum timestamp
2. **libsinsp** parses the event sequentially, updating state (thread table, FD table, process tree)
3. **falco_engine** evaluates rules against the enriched event
4. **falco_outputs** enqueues alerts (already thread-safe via TBB `concurrent_bounded_queue`)

When multiple event sources are configured, each gets its own thread with its own `sinsp` inspector instance, but the common case (syscall only) runs entirely on the main thread[^5].

### Current Thread Manager Storage

The `sinsp_thread_manager` uses `threadinfo_map_t`, which wraps `std::unordered_map<int64_t, std::shared_ptr<sinsp_threadinfo>>`[^6]. Key characteristics:
- **Not concurrent** — designed for single-threaded access
- **Single-entry find cache** (`m_last_tid`, `m_last_tinfo`) — exploits temporal locality of syscall enter/exit pairs sharing the same TID[^7]
- **Default max threads:** 262,144 entries[^8]
- **Thread groups** tracked separately in `std::unordered_map<int64_t, std::shared_ptr<thread_group_info>>`[^8]
- Methods like `get_thread()` return `const shared_ptr&` (reference to internal storage), and `get_threads()` returns a raw pointer to the table[^6]
- Several methods (`get_ancestor_process`, `find_new_reaper`, `get_oldest_matching_ancestor`) return raw `sinsp_threadinfo*` pointers[^3]

### Ring Buffers (Modern eBPF)

The modern eBPF driver uses `BPF_MAP_TYPE_RINGBUF` stored in `BPF_MAP_TYPE_ARRAY_OF_MAPS`[^9]. Configuration via `cpus_for_each_buffer`:
- `1` (default): one ring buffer per CPU — best performance
- `0`: single shared ring buffer for all CPUs
- `N > 1`: one ring buffer per N CPUs

The ring buffers are zero-copy (memory-mapped), and pointers to events remain valid until the next `next()` call[^9].

### Output System

`falco_outputs` is **already thread-safe** for multi-threaded event processing[^10]. It uses Intel TBB's `concurrent_bounded_queue<ctrl_msg>` in a multi-producer, single-consumer pattern. A dedicated worker thread consumes from the queue and dispatches to all output channels. This system is already proven in production with Falco's multi-source support[^2].

---

## High-Level Design: Multi-Threaded Falco

**Source:** [20251205-multi-thread-falco-design.md](../../refs/proposals/multi-thread-falco/20251205-multi-thread-falco-design.md)[^2]

### Goals

1. Reduce event drops under high event rates (primary metric)[^2]
2. Demonstrate throughput scaling with worker thread count[^2]
3. Better utilize available CPU cores[^2]
4. Preserve single-threaded performance (multi-threading is opt-in, single-thread remains default)[^2]

### Non-Goals

- Low-level implementation details (deferred to component-specific proposals)[^2]
- Performance optimization (focus is on scalability)[^2]

### Proposed Architecture

The proposed architecture modifies multiple layers[^2]:

1. **Kernel driver (modern eBPF only):** Routes events into per-partition ring buffers based on TGID hash. Only the modern eBPF probe is supported because it uses `BPF_MAP_TYPE_RINGBUF` (not per-CPU like `BPF_MAP_TYPE_PERF_EVENT_ARRAY` used by kmod/legacy eBPF)[^2]

2. **Worker threads:** Each ring buffer is consumed by a dedicated worker thread that handles event parsing, state updates, and rule evaluation for its partition[^2]

3. **Shared state:** The `libsinsp` state (thread table, etc.) is maintained in shared concurrent data structures accessible by all workers[^2]

4. **Rule evaluation:** Performed in parallel by each worker thread against the events it processes. Current plugins are not thread-safe; a separate proposal is expected[^2]

5. **Output handling:** No changes needed — `falco_outputs` already supports multi-producer concurrent access[^2]

### Kernel-Space Routing

The routing formula in the eBPF program[^2]:
```
ring_buffer_index = hash(event->tgid) % num_workers
```
The hash function and number of workers are configured at eBPF program initialization time, enabling the kernel to route events directly without userspace intervention[^2].

---

## Work Partitioning Strategy

The high-level design[^2] evaluates four partitioning approaches. This is one of the most critical and challenging design aspects, requiring trade-offs among:
1. **Even load balancing** between threads
2. **Low contention** on shared data
3. **Avoiding temporal inconsistencies and causality violations** (correctness)

### Selected Approach: Static Partitioning by TGID

Events are routed by Thread Group ID (TGID ≈ Process ID) in kernel space to dedicated ring buffers consumed by worker threads[^2].

**Advantages:**
- Low synchronization needs — data stored per thread-group (e.g., file descriptors) is mostly accessed by the assigned worker thread (single writer)[^2]
- Sequential ordering within a process — events for the same TGID are handled by the same worker[^2]
- Cross-partition synchronization needed only for: (a) clone/fork events (parent state inheritance) and (b) process exit reparenting[^2]

**Disadvantages:**
- **Hot process vulnerability** — high-activity processes overload their assigned worker[^2]
- **Cross-partition temporal inconsistency** — clone events may reference parent data in a different, lagging partition; ancestor fields used in rule evaluation (`proc.aname[N]`, `proc.aexepath[N]`, `proc.aexe[N]`) may access stale or ahead-of-time data[^2]
- Load imbalance amplifies temporal inconsistency[^2]

**Proposed mitigations for temporal inconsistency:**

1. **Last-resort fetching:** Read thread info from `/proc` or eBPF iterators. Considered a last resort because it risks slowing the event loop[^2]

2. **Context synchronization:** Wait or defer until required data is available. This decomposes into four approaches[^2]:

| | Polling | Signaling |
|---|---------|-----------|
| **Wait/Sleep** | Spin-check until ready | Sleep on condition variable |
| **Deferring** | Periodically retry deferred events | Process deferred events when signaled |

**Natural synchronization point:** The **clone exit parent event** — at this point, the parent has finished setting up the child's inherited state[^2].

**Special case — `vfork()` / `CLONE_VFORK`:** The parent is blocked until the child calls `exec()` or exits, delaying the clone exit parent event. An alternative synchronization point may be needed (e.g., clone enter parent)[^2].

### Rejected Alternatives

| Approach | Why Rejected |
|----------|-------------|
| **TID partitioning** | Increases cross-partition access for thread group leader data (FD table, env vars, CWD); higher coordination cost[^2] |
| **CPU Core partitioning** | Process migration causes temporal inconsistencies; incompatible with modern eBPF (`BPF_MAP_TYPE_RINGBUF` is not per-CPU); only viable with kmod or legacy eBPF[^2] |
| **Functional Pipelining** (parse single-threaded, evaluate rules multi-threaded) | Parsing becomes bottleneck; requires MVCC for state consistency across parallel rule evaluations; requires ring buffer changes to avoid consuming events on `next()`[^2] |

**Comparison summary[^2]:**

| Approach | Load Balancing | Contention | Temporal Consistency |
|----------|----------------|------------|----------------------|
| TGID | Moderate (hot process risk) | Low | Good (within process) |
| TID | Good | Higher | Partial (thread-level only) |
| CPU Core | Good | Low | Poor (process migration) |
| Pipelining | Good (rules phase) | Low (writes) | Requires MVCC |

---

## Thread-Safe Thread Manager: RCU Approach

**Source:** [20251127-thread-safe-sinsp-thread-manager.md](../../refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md)[^4]

This is the **first** thread manager proposal, submitted as [libs#2739](https://github.com/falcosecurity/libs/pull/2739). It proposes replacing the current `std::unordered_map` with a custom RCU-based data structure inspired by Linux kernel patterns.

### Goal

Demonstrate the feasibility of a thread-safe, wait-free `sinsp_thread_manager` implementation while maintaining high performance for the single-threaded case[^4].

### Architecture: Atomic Pointers Array + RCU

**Lookup layer:** A pre-allocated `std::vector<std::atomic<sinsp_thread_info*>>` indexed directly by TID. Pre-allocates 2^22 (≈4M) entries (~32 MB) for O(1) lookups with minimal overhead[^4].

**Iteration layer:** RCU-protected intrusive linked lists within `sinsp_thread_info` objects, modeled after Linux kernel's `list_head`. Navigation pointers include[^4]:
- `std::atomic<sinsp_thread_info*> m_ptid` — parent thread
- `list_head<sinsp_thread_info> m_children` — iterate over children
- `list_head<sinsp_thread_info> m_tasks` — global process list traversal (named after Linux kernel's `task_struct.tasks`)
- `std::atomic<sinsp_thread_info*> m_group_leader` — thread group leader
- `list_head m_group_node` — thread group membership

**Concurrency control[^4]:**
- **Readers:** `rcu_read_lock()` / `rcu_read_unlock()` to delimit critical sections; `rcu_dereference()` for atomic loads
- **Writers:** `rcu_assign_pointer()` for atomic pointer updates; a `std::mutex` to serialize writers
- **Reclamation:** `retire()` for asynchronous deferred memory reclamation

### Concurrency Model

**Hot path — Lookup (wait-free):** Uses a visitor pattern[^4]:
```cpp
void visit(int64_t tid, thread_visitor callback) {
    rcu_read_lock();
    sinsp_thread_info* current = rcu_dereference(table_[tid]);
    if (current) callback(current);
    rcu_read_unlock();
}
```

**Iteration (wait-free):** Traverses the RCU-protected linked list[^4]:
```cpp
void for_each_thread(thread_visitor callback) {
    rcu_read_lock();
    sinsp_thread_info* current = rcu_dereference(init_thread);
    while (current) {
        callback(current);
        current = rcu_dereference(current->m_next);
    }
    rcu_read_unlock();
}
```

**Write path — Clone/Exec/Exit (single writer, serialized with mutex):** Add/remove/replace operations lock `list_lock_`, update RCU pointers, and retire old objects for deferred reclamation[^4].

### Deferred Memory Reclamation

Two schemes considered[^4]:
1. **Synchronous deletion:** Writer waits for all readers to complete. Simpler but adds write-path latency.
2. **Asynchronous deletion:** Writer schedules reclamation after a grace period. Less cache-friendly, requires additional threads.

The proposal notes that experimental results are needed to determine which approach is better[^4].

### Userspace RCU Libraries

Two options considered[^4]:
- [Userspace RCU (liburcu)](https://github.com/urcu/userspace-rcu) — Pure C, multiple RCU flavors (QSBR, signal-based)
- [Folly RCU](https://github.com/facebook/folly/blob/main/folly/docs/Rcu.md) — C++ interface, easier integration with existing codebase

### Risks and Open Issues

1. **Writer lock contention:** The global `std::mutex` serializes all topological changes (clone/fork/exit). In userspace, unlike the kernel, preemption cannot be disabled when holding the lock, risking context-switching under load[^4]. This is identified as "probably the weakest point of this design."

2. **Temporal inconsistencies between RCU structures:** A thread may be visible through pointer navigation but not via direct TID lookup (or vice versa), because different RCU structures are updated non-atomically[^4].

3. **In-place updates vs RCU replace:** Single-field updates should use atomics; complex updates should go through RCU replace. Nested structures (e.g., FD tables) may need their own RCU protection[^4].

4. **False sharing:** Contiguous atomic pointers in the vector may cause cache-line bouncing. Sequential TID allocation exacerbates this. Mitigation: bit-swap mapping to spread TIDs across non-contiguous locations[^4].

5. **32 MB up-front memory cost** for the pre-allocated vector, most of which will hold `nullptr`s. The proposal notes this is "an extreme solution" for rapid prototyping; a radix tree or hash table could be used later to reduce memory[^4].

---

## Thread-Safe Thread Manager: Folly ConcurrentHashMap Approach

**Source:** [20260212-thread-safe-thread-manager.md](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md)[^3]

This is the **revised alternative** to the RCU approach, written after the RCU approach was found to be "challenging and intrusive"[^3]. It proposes using Facebook's Folly library's `ConcurrentHashMap`.

### Motivation for the Shift

The Folly approach was chosen because[^3]:
- The RCU approach required custom intrusive lists and a pre-allocated table
- Alternatives like `boost::concurrent_flat_map` force a visitation-only API (no iterators), requiring a larger API rewrite
- Folly's `ConcurrentHashMap` offloads concurrency to a production-grade container, provides iterator-based access, and allows a closer-to-current API

### Storage

Replace `threadinfo_map_t` with[^3]:
```cpp
folly::ConcurrentHashMap<int64_t, std::shared_ptr<sinsp_threadinfo>> m_threadtable;
```

**Folly ConcurrentHashMap properties[^3]:**
- **Readers:** Wait-free
- **Writers:** Sharded (only part of the map is locked)
- **Memory reclamation:** Hazard pointers — elements removed from the map immediately on `erase()`, actual destruction deferred until no hazard pointer references the object
- **`size()`:** Rolling count (approximate, not exact at any instant)
- **`contains()`:** Deleted by Folly to avoid TOCTOU; use `find(tid) != end()` instead
- **Simultaneous iteration and erase/insert:** Safe; iterators hold hazard pointers

### Key API Changes

The proposal defines detailed API changes[^3]:

| Current API | Proposed API | Change |
|------------|-------------|--------|
| `get_thread(tid)` → `const ptr_t&` | Return `shared_ptr` **by value** via `find(tid)` + copy | No find cache; thread-safe |
| `find_thread(tid)` → `const ptr_t&` | Return `shared_ptr` **by value** | No find cache; thread-safe |
| `get_threads()` → `threadinfo_map_t*` | **Removed**; use `loop_threads(callback)` | Callback receives `shared_ptr` copies |
| `add_thread(...)` → `const ptr_t&` | Return `shared_ptr` **by value** | Uses `insert_or_assign` |
| `remove_thread(tid)` | Unchanged; uses `erase(tid)` | No cache invalidation needed |
| `get_ancestor_process` → raw `sinsp_threadinfo*` | Return `std::shared_ptr<sinsp_threadinfo>` | Prevents use-after-free |
| `find_new_reaper` → raw `sinsp_threadinfo*` | Return `std::shared_ptr<sinsp_threadinfo>` | Prevents use-after-free |
| `get_oldest_matching_ancestor` → raw `sinsp_threadinfo*` | Return `std::shared_ptr<sinsp_threadinfo>` | Prevents use-after-free |

**Critical change — removal of find cache:** The current single-entry cache (`m_last_tid`, `m_last_tinfo`)[^7] is removed because it would be unsafe with concurrent callers[^3]. All lookups return `shared_ptr` by value.

**Critical change — raw pointer elimination:** Methods that currently return `sinsp_threadinfo*` are changed to return `std::shared_ptr<sinsp_threadinfo>`. Four approaches were evaluated (return shared_ptr, return TID only, callback/visitor, keep raw pointer). The recommendation is to return `shared_ptr`[^3].

### Iteration Model

Replace direct table pointer access with callback-based iteration[^3]:
```cpp
using thread_visitor_t = std::function<bool(const std::shared_ptr<sinsp_threadinfo>&)>;
bool loop_threads(thread_visitor_t callback) const;
```
Implementation iterates the Folly map and passes a **copy** of the `shared_ptr` to each callback invocation, ensuring safety[^3].

### Scope Boundaries

**In scope:** Container-level operations (add, remove, lookup, iteration) — made thread-safe[^3].

**Explicitly out of scope[^3]:**
- Internal synchronization of `sinsp_threadinfo` field updates — callers must synchronize themselves
- FD table thread-safety
- State table / plugin API changes (though compatibility is a requirement)

### Dependencies

Requires adding **Folly** (Facebook's C++ library) as a dependency, specifically `ConcurrentHashMap` and `Hazptr` (hazard pointers). License is Apache 2.0, compatible with Falco's[^3].

### Test Strategy

- All existing unit tests must continue to pass[^3]
- New concurrency tests: concurrent add+lookup, concurrent remove+iteration, mixed operations[^3]
- ThreadSanitizer (TSAN) enabled in CI[^3]

---

## Comparison of Thread Manager Approaches

| Aspect | RCU Approach[^4] | Folly ConcurrentHashMap[^3] |
|--------|-------------------|------------------------------|
| **Data structure** | Pre-allocated `vector<atomic<sinsp_thread_info*>>` + intrusive linked lists | `folly::ConcurrentHashMap<int64_t, shared_ptr<sinsp_threadinfo>>` |
| **Memory overhead** | ~32 MB up-front (4M atomic pointers, mostly null) | Dynamic (hash map grows as needed) |
| **Reader performance** | Wait-free (RCU read-side) | Wait-free (Folly's design) |
| **Writer synchronization** | Global mutex serializes all writers | Sharded locks (only part of map locked) |
| **Memory reclamation** | Custom: synchronous or asynchronous RCU retire | Built-in: Folly hazard pointers |
| **Topology navigation** | Intrusive linked lists (parent/child/group) in `sinsp_thread_info` | Topology stays in `sinsp_threadinfo`; navigation via lookups |
| **API impact** | Visitor-based API (`visit()`, `for_each_thread()`) | Closer to current API (return `shared_ptr` by value) |
| **External dependencies** | liburcu or Folly RCU | Folly (ConcurrentHashMap + Hazptr) |
| **Implementation complexity** | High — custom RCU structures, intrusive lists, manual retire | Lower — offloads concurrency to production-grade library |
| **Find cache** | Not addressed directly | Explicitly removed for thread safety |
| **Raw pointer handling** | Not addressed directly | Detailed plan to eliminate raw pointer returns |
| **Iteration model** | RCU-protected linked list traversal | Folly iterator or `loop_threads(callback)` |

**Key trade-off:** The RCU approach offers theoretically better performance (direct-indexed array, intrusive lists for topology) but at the cost of significantly higher implementation complexity. The Folly approach prioritizes **lower migration cost and reduced implementation risk** by leveraging a battle-tested concurrent container[^3].

---

## Cross-Cutting Concerns

### Items Explicitly Deferred to Future Proposals

The following areas are identified as requiring separate design documents[^2][^4][^3]:

1. **`sinsp_threadinfo` field synchronization** — Both thread manager proposals explicitly exclude in-place field updates from scope. Frequent state updates (e.g., file descriptor changes) need their own synchronization strategy.

2. **FD table thread-safety** — The Folly proposal explicitly lists this as out of scope[^3].

3. **Thread-safe plugin architecture** — Current plugins are not thread-safe. The high-level design notes a dedicated proposal is needed[^2].

4. **State table / plugin API compatibility** — Both proposals ensure basic compatibility with `get_entry`/`add_entry`/`erase_entry`, but deep integration is deferred[^3].

### Performance Unknowns (Require Benchmarking)

1. **Cost of removing the find cache** — The current single-entry cache exploits enter/exit TID locality. Removing it for thread safety may impact single-threaded performance[^3]. This is an unverified concern.

2. **Writer lock contention (RCU approach)** — The global mutex may cause context-switching under high clone/fork/exit rates[^4].

3. **Sharded writer overhead (Folly approach)** — While theoretically better than a global mutex, the actual overhead under Falco's write patterns is unknown[^3].

4. **`std::function` overhead on hot path** — A reviewer noted that `std::function` on the hot path (visitor/callback) should be benchmarked against raw function pointers[^11].

5. **TGID partitioning load balance** — The impact of "hot processes" on worker thread saturation is unknown and requires real-world benchmarking[^2].

6. **Temporal inconsistency impact on rule accuracy** — Whether stale/ahead ancestor data during cross-partition rule evaluation causes meaningful false positives/negatives is an open question[^2].

### Architectural Constraints

- **Modern eBPF only** — The multi-threaded architecture requires `BPF_MAP_TYPE_RINGBUF` for TGID-based partitioning, which is only available in the modern eBPF probe. Kmod and legacy eBPF (deprecated in 0.43) use `BPF_MAP_TYPE_PERF_EVENT_ARRAY` with per-CPU design[^2].

- **Single-threaded remains default** — Multi-threading is opt-in. The design must preserve current single-threaded performance[^2].

- **Output system ready** — `falco_outputs` already supports multi-producer access via TBB queue, requiring no changes[^2].

---

## Open Questions and Unresolved Areas

These are areas where the proposals acknowledge uncertainty or explicitly defer decisions:

1. **Which thread manager approach will be adopted?** The Folly approach[^3] is positioned as a "less intrusive" alternative to RCU[^4], but no final decision has been made.

2. **How will `sinsp_threadinfo` field updates be synchronized?** Both proposals exclude this from scope. Options include atomics for single fields, RCU replace for complex updates, or other concurrent structures for nested data (e.g., FD tables)[^4][^3].

3. **What synchronization strategy for cross-partition clone/fork?** The high-level design describes four possible approaches (blocking/deferring × polling/signaling) but defers the choice to implementation[^2].

4. **How will `vfork()` / `CLONE_VFORK` be handled?** The natural synchronization point (clone exit parent) is delayed when `vfork()` is used[^2].

5. **Can the global writer lock (RCU approach) be eliminated?** A reviewer suggested partitioning writes so the same writer handles related topological changes, potentially eliminating the global mutex[^11]. The Folly approach partially addresses this with sharded locks.

6. **What is the Folly library's build/integration story?** Adding Folly as a dependency introduces build complexity. The proposal mentions vcpkg, system packages, or git submodule as options[^3].

7. **Will `loop_threads` with `std::function` cause measurable overhead on the hot path?** A reviewer flagged this for benchmarking[^11].

8. **How will strict temporal ordering of alerts be handled?** Alerts from different workers may be interleaved in the output queue. The proposal considers this acceptable for security monitoring[^2].

---

## PR Review Feedback

### libs#2739 (RCU Approach)

Reviewer **@ekoops** provided substantive feedback[^11]:

- **Global mutex concern:** The critical point is the `std::mutex` serializing all topological changes. It serializes clone/fork/exit operations across unrelated processes. The reviewer suggested exploring whether TGID partitioning could designate the same writer for related topological changes, potentially eliminating the global lock.

- **`std::function` performance:** On the hot path, `std::function` should be profiled against function pointers. A micro-benchmark was suggested.

- **Minor issues:** Clarifications on `list_head` usage and a typo ("read" mentioned twice where "read and write" was intended).

### falco#3751 (High-Level Design)

Reviewer **@c2ndev** provided minor typo corrections only[^12].

---

## Related Work

### Within Falco Ecosystem

- **Disable Syscall Enter Events** ([libs proposal 20240901](../../digests/falcosecurity/libs/proposals-and-architecture.md)) — Orthogonal performance optimization reducing events by ~50%. In progress. Would reduce per-thread event volume, potentially delaying the need for multi-threading.

- **Kernel-side filtering** ([libs#1557](https://github.com/falcosecurity/libs/issues/1557)) — Orthogonal approach to reduce event volume at the source. Does not eliminate the single-thread bottleneck[^1].

- **Legacy BPF/gRPC/gVisor Deprecation** ([falco proposal 20251215](../../digests/falcosecurity/falco/proposals.md)) — The deprecation of legacy eBPF aligns with the multi-threading proposal's requirement for modern eBPF only.

### External References (from proposals)

- [What is RCU, Fundamentally?](https://lwn.net/Articles/262464/) — RCU concepts[^4]
- [Userspace RCU (liburcu)](https://github.com/urcu/userspace-rcu) — C RCU library[^4]
- [Folly ConcurrentHashMap](https://github.com/facebook/folly/blob/main/folly/concurrency/ConcurrentHashMap.h) — Production-grade concurrent container[^3]
- [Folly RCU documentation](https://github.com/facebook/folly/blob/main/folly/docs/Rcu.md) — C++ RCU[^4]
- [Harris-Michael Algorithm](https://www.cl.cam.ac.uk/research/srg/netos/papers/2001-caslists.pdf) — Non-blocking linked-list[^4]

---

## Sources

| Topic | Source |
|-------|--------|
| Proposal refs directory | [`refs/proposals/multi-thread-falco/`](../../refs/proposals/multi-thread-falco/) |
| Refs README (provenance) | [`refs/proposals/multi-thread-falco/README.md`](../../refs/proposals/multi-thread-falco/README.md) |
| High-level design proposal | [`refs/proposals/multi-thread-falco/20251205-multi-thread-falco-design.md`](../../refs/proposals/multi-thread-falco/20251205-multi-thread-falco-design.md) |
| RCU thread manager proposal | [`refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md`](../../refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md) |
| Folly thread manager proposal (WIP) | [`refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md`](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md) |
| Issue: Multi-threaded Falco | [falcosecurity/falco#3749](https://github.com/falcosecurity/falco/issues/3749) |
| PR: High-level design | [falcosecurity/falco#3751](https://github.com/falcosecurity/falco/pull/3751) |
| PR: RCU thread manager | [falcosecurity/libs#2739](https://github.com/falcosecurity/libs/pull/2739) |
| WIP: Folly thread manager | [irozzo-1A/agent-libs@145d3c2](https://github.com/irozzo-1A/agent-libs/blob/145d3c2db2da582054828a8376b3a386c6972634/proposals/20260212-thread-safe-thread-manager.md) |
| Current threadinfo_map_t | [`refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h`](../../refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h) (lines 559-624) |
| Current find cache | [`refs/falcosecurity/libs/userspace/libsinsp/thread_manager.cpp`](../../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.cpp) (lines 1000-1038) |
| Thread manager class | [`refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h`](../../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h) |
| Modern eBPF engine params | [`refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h`](../../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h) (lines 26-40) |
| Falco event loop | [`refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp`](../../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp) |
| Falco outputs | [`refs/falcosecurity/falco/userspace/falco/falco_outputs.h`](../../refs/falcosecurity/falco/userspace/falco/falco_outputs.h) |
| Existing Falco proposals digest | [`digests/falcosecurity/falco/proposals.md`](../falcosecurity/falco/proposals.md) |
| Existing libs proposals digest | [`digests/falcosecurity/libs/proposals-and-architecture.md`](../falcosecurity/libs/proposals-and-architecture.md) |

---

## References

[^1]: [falcosecurity/falco#3749](https://github.com/falcosecurity/falco/issues/3749) — [Proposal] Multi-threaded Falco (issue)
[^2]: [20251205-multi-thread-falco-design.md](../../refs/proposals/multi-thread-falco/20251205-multi-thread-falco-design.md) — Multi-Threaded Falco High-Level Design (falco#3751)
[^3]: [20260212-thread-safe-thread-manager.md](../../refs/proposals/multi-thread-falco/20260212-thread-safe-thread-manager.md) — Thread-Safe Thread Manager Using Folly ConcurrentHashMap (WIP)
[^4]: [20251127-thread-safe-sinsp-thread-manager.md](../../refs/proposals/multi-thread-falco/20251127-thread-safe-sinsp-thread-manager.md) — Proposal for Thread-safe scalable sinsp_thread_manager (libs#2739)
[^5]: [`process_events.cpp`](../../refs/falcosecurity/falco/userspace/falco/app/actions/process_events.cpp) — Falco event loop, multi-source threading model (lines 565-588)
[^6]: [`threadinfo.h:559-624`](../../refs/falcosecurity/libs/userspace/libsinsp/threadinfo.h) — Current `threadinfo_map_t` class with `std::unordered_map` storage
[^7]: [`thread_manager.cpp:1000-1038`](../../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.cpp) — Current `find_thread()` with single-entry find cache
[^8]: [`thread_manager.h`](../../refs/falcosecurity/libs/userspace/libsinsp/thread_manager.h) — `sinsp_thread_manager` class, max threads default, thread groups map
[^9]: [`modern_bpf_public.h:26-40`](../../refs/falcosecurity/libs/userspace/libscap/engine/modern_bpf/modern_bpf_public.h) — Modern eBPF engine parameters, ring buffer configuration
[^10]: [`falco_outputs.h`](../../refs/falcosecurity/falco/userspace/falco/falco_outputs.h) — Thread-safe output system with TBB `concurrent_bounded_queue`
[^11]: [libs#2739 reviews](https://github.com/falcosecurity/libs/pull/2739) — @ekoops review feedback on global mutex and `std::function` performance
[^12]: [falco#3751 reviews](https://github.com/falcosecurity/falco/pull/3751) — @c2ndev minor typo corrections
