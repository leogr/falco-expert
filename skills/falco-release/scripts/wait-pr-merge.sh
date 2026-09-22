#!/usr/bin/env bash
# wait-pr-merge.sh - wait until a pull request is merged or closed without merge.
#
# Purpose:    Poll one PR and print one line per change of state, head SHA,
#             review decision, gating labels (lgtm/approved/do-not-merge/needs-*)
#             and approving/blocking reviews, until the PR is merged or closed.
# Usage:      wait-pr-merge.sh --repo <owner/repo> --pr <n> [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 MERGED | 1 CLOSED_UNMERGED | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10

usage() {
  cat <<'EOF'
wait-pr-merge.sh - wait until a pull request is merged or closed without merge.

Polls one PR and prints one line per state change (state, mergeability, review
decision, head SHA, gating labels, approving/blocking reviews). Read-only.

Usage:
  wait-pr-merge.sh --repo <owner/repo> --pr <n> [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>      Repository full name (required, no default org)
  --pr <n>                 Pull request number (required)
  --max-minutes <n>        Give up after n minutes (default 180)
  --interval-seconds <n>   Seconds between polls (default 60)
  -h, --help               Print this help and exit 0

Exit codes:
  0  MERGED           the PR was merged
  1  CLOSED_UNMERGED  the PR was closed without being merged
  2  usage error
  3  TIMEOUT          deadline reached while the PR is still open
  4  API_ERROR        10 consecutive GitHub API failures

Example:
  wait-pr-merge.sh --repo my-org/my-repo --pr 42 --max-minutes 240
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
    log "TIMEOUT after ${MAX_MINUTES}m: $REPO#$PR still open: ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

# One summary line per poll. Reviews: latest review per author, approvals and
# change requests only. Labels: Prow gating labels only.
JQ_SUMMARY='"state=\(.state) merge=\(.mergeStateStatus // "-") decision=\(.reviewDecision // "-") head=\(.headRefOid) labels=\([.labels[].name] | map(select(startswith("lgtm") or startswith("approved") or startswith("do-not-merge") or startswith("needs-"))) | sort | join(",")) reviews=\([.reviews | group_by(.author.login)[] | last | select(.state | IN("APPROVED","CHANGES_REQUESTED")) | "\(.author.login)=\(.state)"] | join(",")) mergedAt=\(.mergedAt // "-")"'

while :; do
  if S=$(gh pr view "$PR" -R "$REPO" --json state,mergeStateStatus,reviewDecision,headRefOid,labels,reviews,mergedAt --jq "$JQ_SUMMARY" 2>"$ERRFILE"); then
    API_FAILS=0
    if [ "$S" != "$LAST" ]; then
      log "$REPO#$PR: $S"
      LAST="$S"
    fi
    case "$S" in
      state=MERGED*) log "MERGED $REPO#$PR: $S"; exit 0 ;;
      state=CLOSED*) log "CLOSED_UNMERGED $REPO#$PR: $S"; exit 1 ;;
    esac
  else
    api_fail "gh pr view $REPO#$PR"
  fi
  sleep_or_timeout
done
