#!/usr/bin/env bash
# wait-pr-checks.sh - wait until the checks on a pull request head settle.
#
# Purpose:    Poll the status check rollup of a PR head (check runs plus commit
#             statuses) until nothing is pending, excluding the "tide" context
#             (Prow's tide stays pending until the gating labels land and would
#             deadlock the wait). The head SHA is re-derived on every poll and a
#             head move is reported. On settlement, non-green checks are printed
#             with their URLs.
# Usage:      wait-pr-checks.sh --repo <owner/repo> --pr <n> [--exclude-context <name>]... [--min-checks <n>] [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 SETTLED_GREEN | 1 SETTLED_RED or CLOSED_UNMERGED | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10
EXCLUDE="tide"
MIN_CHECKS=1

usage() {
  cat <<'EOF'
wait-pr-checks.sh - wait until the checks on a pull request head settle.

Polls the PR's status check rollup (GitHub check runs and commit statuses)
until nothing is pending. The "tide" context is always excluded because it
stays pending until the gating labels land. Green means every remaining check
concluded SUCCESS, NEUTRAL or SKIPPED. The head SHA is re-derived on every poll
and reported when it moves. Read-only.

Usage:
  wait-pr-checks.sh --repo <owner/repo> --pr <n> [--exclude-context <name>]... [--min-checks <n>] [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>       Repository full name (required, no default org)
  --pr <n>                  Pull request number (required)
  --exclude-context <name>  Additional check/status name to ignore (repeatable; "tide" is always ignored)
  --min-checks <n>          Do not consider the head settled before at least n
                            non-excluded checks exist (default 1). Raise it when
                            workflows may not have been created yet (e.g. a fork
                            PR waiting for a maintainer to approve the runs shows
                            only "dco").
  --max-minutes <n>         Give up after n minutes (default 180)
  --interval-seconds <n>    Seconds between polls (default 60)
  -h, --help                Print this help and exit 0

Exit codes:
  0  SETTLED_GREEN    all non-excluded checks concluded SUCCESS/NEUTRAL/SKIPPED
  1  SETTLED_RED      settled with at least one non-green check (listed with URLs)
  1  CLOSED_UNMERGED  the PR was closed without merge while waiting
  2  usage error
  3  TIMEOUT          deadline reached with checks still pending
  4  API_ERROR        10 consecutive GitHub API failures

Example:
  wait-pr-checks.sh --repo my-org/my-repo --pr 42 --max-minutes 120
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }
need_value() { [ "$#" -ge 2 ] || die_usage "flag $1 requires a value"; }

REPO=""
PR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    --pr) need_value "$@"; PR="$2"; shift 2 ;;
    --exclude-context) need_value "$@"; EXCLUDE="$EXCLUDE,$2"; shift 2 ;;
    --min-checks) need_value "$@"; MIN_CHECKS="$2"; shift 2 ;;
    --max-minutes) need_value "$@"; MAX_MINUTES="$2"; shift 2 ;;
    --interval-seconds) need_value "$@"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ] || die_usage "missing required --repo"
[ -n "$PR" ] || die_usage "missing required --pr"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die_usage "--repo must be <owner/repo>"
[[ "$PR" =~ ^[1-9][0-9]*$ ]] || die_usage "--pr must be a positive integer"
[[ "$MIN_CHECKS" =~ ^[1-9][0-9]*$ ]] || die_usage "--min-checks must be a positive integer"
[[ "$MAX_MINUTES" =~ ^[1-9][0-9]*$ ]] || die_usage "--max-minutes must be a positive integer"
[[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]] || die_usage "--interval-seconds must be a positive integer"

ts() { date -u +%FT%TZ; }
log() { printf '%s %s\n' "$(ts)" "$*"; }

ERRFILE=$(mktemp)
trap 'rm -f "$ERRFILE"' EXIT
API_FAILS=0
api_fail() {
  local msg
  msg=$(head -n1 "$ERRFILE" 2>/dev/null || true)
  API_FAILS=$((API_FAILS + 1))
  log "API_WARN $1 failed (${API_FAILS}/${MAX_API_FAILS}): ${msg:-no error message}"
  if [ "$API_FAILS" -ge "$MAX_API_FAILS" ]; then
    log "API_ERROR ${MAX_API_FAILS} consecutive failures: $1: ${msg:-no error message}"
    exit 4
  fi
}

DEADLINE=$(( $(date +%s) + MAX_MINUTES * 60 ))
LAST=""
sleep_or_timeout() {
  local now remaining
  now=$(date +%s)
  if [ "$now" -ge "$DEADLINE" ]; then
    log "TIMEOUT after ${MAX_MINUTES}m: $REPO#$PR checks still pending: ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

# Normalize both rollup item kinds (CheckRun, StatusContext), drop excluded
# names, then emit: line 1 = "<pr-state> <head-sha> <total> <pending> <not-green>",
# following lines = one "  <result> | <name> | <url>" per non-green settled check.
JQ_PROG='
def norm:
  if .__typename == "StatusContext" then
    {name: .context, done: (.state | IN("SUCCESS","FAILURE","ERROR")), result: (.state // "-"), url: (.targetUrl // "")}
  else
    {name: .name, done: (.status == "COMPLETED"), result: (.conclusion // .status // "-"), url: (.detailsUrl // "")}
  end;
($excl | split(",")) as $ex
| [ .statusCheckRollup[]? | norm | select(.name | IN($ex[]) | not) ] as $n
| ($n | map(select(.done | not))) as $pending
| ($n | map(select(.done) | select(.result | IN("SUCCESS","NEUTRAL","SKIPPED") | not))) as $red
| "\(.state) \(.headRefOid) \($n | length) \($pending | length) \($red | length)",
  ($red[] | "  \(.result) | \(.name) | \(.url)")
'

PREV_HEAD=""
while :; do
  if JSON=$(gh pr view "$PR" -R "$REPO" --json state,headRefOid,statusCheckRollup 2>"$ERRFILE"); then
    API_FAILS=0
    OUT=$(printf '%s' "$JSON" | jq -r --arg excl "$EXCLUDE" "$JQ_PROG")
    SUMMARY=$(printf '%s\n' "$OUT" | head -n1)
    DETAILS=$(printf '%s\n' "$OUT" | tail -n +2)
    read -r STATE HEAD TOTAL PENDING RED <<<"$SUMMARY"
    if [ -n "$PREV_HEAD" ] && [ "$HEAD" != "$PREV_HEAD" ]; then
      log "HEAD_MOVED $REPO#$PR: $PREV_HEAD -> $HEAD (checks restart on the new head)"
    fi
    PREV_HEAD="$HEAD"
    S="state=$STATE head=$HEAD total=$TOTAL pending=$PENDING notgreen=$RED excluded=$EXCLUDE"
    if [ "$S" != "$LAST" ]; then
      log "$REPO#$PR: $S"
      LAST="$S"
    fi
    if [ "$STATE" = "CLOSED" ]; then
      log "CLOSED_UNMERGED $REPO#$PR: closed without merge while waiting for checks: $S"
      exit 1
    fi
    if [ "$TOTAL" -ge "$MIN_CHECKS" ] && [ "$PENDING" -eq 0 ]; then
      if [ "$RED" -eq 0 ]; then
        log "SETTLED_GREEN $REPO#$PR head=$HEAD: $TOTAL checks, all SUCCESS/NEUTRAL/SKIPPED"
        exit 0
      fi
      printf '%s\n' "$DETAILS"
      log "SETTLED_RED $REPO#$PR head=$HEAD: $TOTAL checks, $RED not green (listed above)"
      exit 1
    fi
  else
    api_fail "gh pr view $REPO#$PR"
  fi
  sleep_or_timeout
done
