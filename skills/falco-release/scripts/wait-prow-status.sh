#!/usr/bin/env bash
# wait-prow-status.sh - wait until Prow's tide status on a PR head matches a pattern, or the PR merges.
#
# Purpose:    Poll the "tide" commit status on the current head of a PR (the
#             head SHA is re-derived on every poll) and print the tide
#             description on every change, until the description matches the
#             given regular expression (exit 0) or the PR merges (exit 0). A PR
#             closed without merge ends the wait with exit 1.
# Usage:      wait-prow-status.sh --repo <owner/repo> --pr <n> --description-regex <ere> [--context <name>] [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 DESCRIPTION_MATCH or MERGED | 1 CLOSED_UNMERGED | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10
CONTEXT="tide"

usage() {
  cat <<'EOF'
wait-prow-status.sh - wait until Prow's tide status on a PR head matches a pattern, or the PR merges.

Polls the PR state and the "tide" commit status of its current head. Every
change of the tide state/description is printed. The wait ends when the
description matches --description-regex (bash extended regex), or when the PR
is merged. Typical patterns: 'In merge pool', 'Not mergeable.*approved',
'Merge conflicts'. Read-only.

Usage:
  wait-prow-status.sh --repo <owner/repo> --pr <n> --description-regex <ere> [--context <name>] [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>          Repository full name (required, no default org)
  --pr <n>                     Pull request number (required)
  --description-regex <ere>    Extended regular expression the status description must match (required)
  --context <name>             Status context to follow (default tide)
  --max-minutes <n>            Give up after n minutes (default 180)
  --interval-seconds <n>       Seconds between polls (default 60)
  -h, --help                   Print this help and exit 0

Exit codes:
  0  DESCRIPTION_MATCH  the status description matched the pattern
  0  MERGED             the PR merged before (or instead of) a match
  1  CLOSED_UNMERGED    the PR was closed without merge
  2  usage error
  3  TIMEOUT            deadline reached without a match or merge
  4  API_ERROR          10 consecutive GitHub API failures

Example:
  wait-prow-status.sh --repo my-org/my-repo --pr 42 --description-regex 'In merge pool' --max-minutes 60
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }
need_value() { [ "$#" -ge 2 ] || die_usage "flag $1 requires a value"; }

REPO=""
PR=""
DESC_RE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    --pr) need_value "$@"; PR="$2"; shift 2 ;;
    --description-regex) need_value "$@"; DESC_RE="$2"; shift 2 ;;
    --context) need_value "$@"; CONTEXT="$2"; shift 2 ;;
    --max-minutes) need_value "$@"; MAX_MINUTES="$2"; shift 2 ;;
    --interval-seconds) need_value "$@"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ] || die_usage "missing required --repo"
[ -n "$PR" ] || die_usage "missing required --pr"
[ -n "$DESC_RE" ] || die_usage "missing required --description-regex"
[ -n "$CONTEXT" ] || die_usage "--context must not be empty"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die_usage "--repo must be <owner/repo>"
[[ "$PR" =~ ^[1-9][0-9]*$ ]] || die_usage "--pr must be a positive integer"
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
    log "TIMEOUT after ${MAX_MINUTES}m: $REPO#$PR $CONTEXT never matched '$DESC_RE': ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

JQ_PR='"\(.state) \(.headRefOid) \(.mergedAt // "-")"'
# Fixed order: "<state> <description...>" (description last, may contain spaces).
JQ_STATUS='[.statuses[] | select(.context == $ctx)] | if length == 0 then "absent" else "\(.[0].state) \(.[0].description // "")" end'

PREV_HEAD=""
while :; do
  if ! PR_LINE=$(gh pr view "$PR" -R "$REPO" --json state,headRefOid,mergedAt --jq "$JQ_PR" 2>"$ERRFILE"); then
    api_fail "gh pr view $REPO#$PR"
    sleep_or_timeout
    continue
  fi
  read -r PR_STATE HEAD MERGED_AT <<<"$PR_LINE"
  if [ "$PR_STATE" = "MERGED" ]; then
    log "MERGED $REPO#$PR head=$HEAD mergedAt=$MERGED_AT (before or instead of a $CONTEXT match)"
    exit 0
  fi
  if [ "$PR_STATE" = "CLOSED" ]; then
    log "CLOSED_UNMERGED $REPO#$PR head=$HEAD closed without merge"
    exit 1
  fi
  if [ -n "$PREV_HEAD" ] && [ "$HEAD" != "$PREV_HEAD" ]; then
    log "HEAD_MOVED $REPO#$PR: $PREV_HEAD -> $HEAD"
  fi
  PREV_HEAD="$HEAD"
  if ! STATUS_JSON=$(gh api "repos/$REPO/commits/$HEAD/status" 2>"$ERRFILE"); then
    api_fail "gh api commits/${HEAD:0:12}/status for $REPO"
    sleep_or_timeout
    continue
  fi
  API_FAILS=0
  LINE=$(printf '%s' "$STATUS_JSON" | jq -r --arg ctx "$CONTEXT" "$JQ_STATUS")
  read -r ST_STATE ST_DESC <<<"$LINE"
  ST_DESC="${ST_DESC:-}"
  S="pr=$PR_STATE head=$HEAD $CONTEXT=$ST_STATE description=$ST_DESC"
  if [ "$S" != "$LAST" ]; then
    log "$REPO#$PR: $S"
    LAST="$S"
  fi
  if [ "$ST_STATE" != "absent" ] && [[ "$ST_DESC" =~ $DESC_RE ]]; then
    log "DESCRIPTION_MATCH $REPO#$PR head=$HEAD $CONTEXT=$ST_STATE description=$ST_DESC (pattern '$DESC_RE')"
    exit 0
  fi
  sleep_or_timeout
done
