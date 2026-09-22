# Chain table

One table per active chain. Refresh it at every chain event and show it in recaps and before asking for a go. "Waiting" names the commit, the run, or the approval waited on.

State vocabulary (fixed, so it scans): `staged` (local only) → `open / in review` → `CI settling` → `green at <sha>` → `needs <n> reviews` → `merged` → `branch green at <sha>` → `gate satisfied` → `tagged` → `run green` → `artifacts verified` → `announced`. Overlays: `held`, `parked`, `waiting on others (no pings)`, `go aged`, `needs go`.

```markdown
### Chain: <name> (blocks: <what it blocks>)

| Step | State | Who | Next |
|---|---|---|---|
| <upstream fix PR> merged | needs 1 review (author cannot approve) | other approver | wait; no ping |
| <upstream> default branch green at merge commit | CI settling (`<sha>`, run `<id>`) | waiter `<id>` | read the log if red |
| <upstream> tag `<version>` | gate satisfied | maintainer | give the command only when the gate holds |
| artifacts verified | needs the tag | agent | `plugin-artifacts-check.sh --plugin ... --version ...` |
| pin PR in <consumer> | staged (dry run OK) | agent on go | `pin-pr.sh --apply` after the go |
| cherry-pick into <release-branch> sync PR | staged | agent on go | append to `<sync-pr>` |
| <consumer> candidate `<candidate>` | needs go | maintainer | restate target SHA, gate, command |

Parallel tracks: chart compatibility check (sub-agent, running); website doc-impact list (report ready); rules sweep (done).
```

Rules: a late event voids every step after it (say which); a go ages after any chain event or maintainer message; an announced intent is not a go; a hold marks every public step `held` while watchers continue.
