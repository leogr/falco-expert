---
name: falco-dependabot
description: Clear the open Dependabot PR backlog in a falcosecurity repository in bulk - rebase each PR, wait for CI, approve when green, stop when red. Use when asked to process Dependabot PRs, bump dependencies in bulk, clear the dependency backlog, or handle dependency security alerts in a falcosecurity repo.
metadata:
  falco-version: "0.44"
---

# Falco Dependabot

Clear a repository's open Dependabot PR backlog: **rebase → wait → approve**, in batches when the PRs are not expected to conflict, one at a time otherwise.

Most falcosecurity repos have Dependabot configured. Check before starting:

```bash
gh api "repos/falcosecurity/<repo>/contents/.github" --jq '.[].name' | grep -E '^dependabot\.ya?ml$'
```

## Before you start

1. **Is CI green on the default branch?** If the repo's CI is broken, *every* Dependabot PR is red and rebasing them is wasted effort. Fix CI in one PR, merge it, then run this skill.
2. **Are you an approver?** Check the repo's `OWNERS`. If not, you can rebase but not approve.
3. **Tell the human that approving means merging** (see [Approving](#approving)) and get explicit consent before the first approval.

## The loop

List open Dependabot PRs, oldest first:

```bash
gh pr list --repo falcosecurity/<repo> --state open --limit 100 \
  --json number,title,author,createdAt,mergeable \
  --template '{{range .}}#{{.number}} | {{.createdAt}} | {{.mergeable}} | {{.author.login}} | {{.title}}
{{end}}' | sort -t'|' -k2
```

Walk the list **oldest to newest**. Approve PRs **as a batch** when their checks are already green on a fresh head, none is `CONFLICTING`, and they are not expected to conflict with each other (bumps touching different files are safe; several bumps to the same `go.mod`/`go.sum` often collide). Otherwise, and as soon as a conflict shows up, go **one PR at a time**. A conflict is not fatal: each merge moves the default branch, so ask for `@dependabot rebase` (or rebase by hand) and run the PR through the loop again — the new head needs a fresh approval.

For each PR:

```bash
REPO=falcosecurity/<repo>; PR=<n>

# 1. baseline
BASE=$(gh pr view $PR --repo $REPO --json headRefOid --jq .headRefOid)

# 2. ask for a rebase
gh pr comment $PR --repo $REPO --body '@dependabot rebase'
```

3. **Wait for the head to move** off `$BASE`. Poll in the background (`Monitor`, or `Bash` with
   `run_in_background`) — never block the foreground on `sleep`. Poll every ~45s.

4. **Wait for the checks to settle**, excluding `tide`:

```bash
gh pr checks $PR --repo $REPO --json name,bucket | jq -r '
  [.[] | select(.name != "tide")] |
  if   any(.bucket == "pending")                       then "PENDING"
  elif any(.bucket == "fail" or .bucket == "cancel")   then "FAILED"
  else "GREEN" end'
```

5. **GREEN** → approve (below). **FAILED** → stop and ask the human. When going one at a time, do not
   move to the next PR until the current one has merged, because each merge moves the default branch.

## Approving

```bash
gh pr review $PR --repo $REPO --approve --body 'LGTM :+1:'
```

> **Approving is merging.** falcosecurity Prow sets [`review_acts_as_lgtm: true`](https://github.com/falcosecurity/test-infra/blob/master/config/plugins.yaml) org-wide, so a single GitHub approval from an `OWNERS` approver applies **both** `approved` and `lgtm`, which is exactly what tide is waiting for. It will merge the PR on its next sync. If the PR should wait for a second reviewer, post `/hold` first.

> **N.B. this does not hold on every repo - verify both labels actually landed.** On some repos the review applies only `lgtm`, `approved` never appears, and a follow-up `/approve` comment goes unanswered, even though the approve plugin is enabled for the repo with `lgtm_acts_as_approve: true`. tide then reports *"Not mergeable. Needs approved label."* It looks like a per-repo bug rather than intended configuration. Seen on `kernel-crawler` (Sep 2026). Check the labels, and set `approved` yourself when it is missing:
>
> ```bash
> gh pr view $PR --repo $REPO --json labels --jq '[.labels[].name] | join(", ")'
> gh pr edit $PR --repo $REPO --add-label approved
> ```

## Gotchas

- **Never wait for `tide` to go green.** It sits at `pending` with *"Not mergeable. Needs approved, lgtm labels"* until your approval lands. Including it in the settle check deadlocks the loop. This is why step 4 filters it out.

- **Dependabot may refuse to rebase**, replying *"Looks like this PR is already up-to-date with `<branch>`!"*. That is fine, **but the green checks on the existing head may predate a CI fix**. Verify freshness before trusting them:

  ```bash
  SHA=$(gh pr view $PR --repo $REPO --json headRefOid --jq .headRefOid)
  gh api "repos/$REPO/commits/$SHA/check-runs" \
    --jq '.check_runs[] | "\(.name): \(.conclusion) @\(.completed_at)"'
  ```

  If the runs are older than the CI fix, use `@dependabot recreate` instead.

- **A red PR after rebase is usually a real incompatibility, not flakiness.** Reproduce locally to get the actual compiler error rather than guessing from CI logs:

  ```bash
  git clone --depth 1 https://github.com/$REPO.git /tmp/verify && cd /tmp/verify
  go get <module>@<version> && go mod tidy && go build ./...
  ```

  `go mod why <package>` identifies which dependency pulls in the broken package.

- **Fix a broken bump on the Dependabot branch itself.** Dependabot PRs accept extra commits, so push the fix as a commit on the PR rather than opening a separate one. It keeps the bump and its fix in a single reviewable change.

- **`needs-kind` does not block tide.** poiana nags about a missing `/kind` label; tide only requires `approved` and `lgtm`. Add a kind label only if the human asks.

- **Cross-repo bumps need the upstream fixed first.** If repo A's Dependabot PR fails because repo B (a falcosecurity dependency) uses a removed API, fix and tag B first, then bump B in A.

## Security alerts

When the goal is closing Dependabot *alerts* rather than merging PRs:

```bash
gh api "repos/$REPO/dependabot/alerts?state=open&per_page=100" --jq '.[] |
  "[\(.security_advisory.severity)] \(.dependency.package.name) | \(.security_advisory.ghsa_id) | patched: \(.security_vulnerability.first_patched_version.identifier // "none")"'
```

**`patched: none` means no bump can fix it.** Check the real range before accepting any claimed fix:

```bash
gh api advisories/<GHSA-ID> --jq '.vulnerabilities[] |
  "\(.package.name): vulnerable \(.vulnerable_version_range) | patched \(.first_patched_version // "NONE")"'
```

A *downgrade* inside the vulnerable range fixes nothing even if a scanner stops reporting it. When there is no patched version, the honest outcomes are a dismissal with a written reachability rationale, or a tracked migration to the successor module — not a version shuffle.

## Related

- [`falco-triage`](../falco-triage/SKILL.md) - broader issue and PR triage
- [`falco-reviewer`](../falco-reviewer/SKILL.md) - substantive review of non-Dependabot PRs
- [`ci-cd-infrastructure.md`](../../specs/ci-cd-infrastructure.md) - Prow, tide, and merge automation
