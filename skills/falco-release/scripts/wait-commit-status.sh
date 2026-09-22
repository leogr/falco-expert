#!/usr/bin/env bash
# wait-commit-status.sh - wait until one commit status context reaches a terminal state.
#
# Purpose:    Poll the combined status of one commit and watch a single context
#             (third-party statuses such as a deploy preview, or Prow contexts)
#             until it reports success (exit 0) or failure/error (exit 1).
# Usage:      wait-commit-status.sh --repo <owner/repo> --sha <full-sha> --context <name> [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 STATUS_SUCCESS | 1 STATUS_FAILED | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10

usage() {
  cat <<'EOF'
wait-commit-status.sh - wait until one commit status context reaches a terminal state.

Polls the combined commit status and follows one context (for example a deploy
preview or a Prow postsubmit) until its state is success, failure or error.
A context that has not been reported yet, or is pending, keeps the wait going.
Read-only.

Usage:
  wait-commit-status.sh --repo <owner/repo> --sha <full-sha> --context <name> [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>      Repository full name (required, no default org)
  --sha <full-sha>         Full 40-hex commit SHA (required)
  --context <name>         Exact status context name to follow (required)
  --max-minutes <n>        Give up after n minutes (default 180)
  --interval-seconds <n>   Seconds between polls (default 60)
  -h, --help               Print this help and exit 0

Exit codes:
  0  STATUS_SUCCESS  the context reported success
  1  STATUS_FAILED   the context reported failure or error
  2  usage error
  3  TIMEOUT         deadline reached with the context absent or pending
  4  API_ERROR       10 consecutive GitHub API failures

Example:
  wait-commit-status.sh --repo my-org/my-repo --sha 0123456789abcdef0123456789abcdef01234567 --context netlify/my-site/deploy-preview
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }
need_value() { [ "$#" -ge 2 ] || die_usage "flag $1 requires a value"; }

REPO=""
SHA=""
CONTEXT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    --sha) need_value "$@"; SHA="$2"; shift 2 ;;
    --context) need_value "$@"; CONTEXT="$2"; shift 2 ;;
    --max-minutes) need_value "$@"; MAX_MINUTES="$2"; shift 2 ;;
    --interval-seconds) need_value "$@"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ] || die_usage "missing required --repo"
[ -n "$SHA" ] || die_usage "missing required --sha"
[ -n "$CONTEXT" ] || die_usage "missing required --context"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die_usage "--repo must be <owner/repo>"
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || die_usage "--sha must be a full 40-hex lowercase commit SHA"
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
SHORT="${SHA:0:12}"
sleep_or_timeout() {
  local now remaining
  now=$(date +%s)
  if [ "$now" -ge "$DEADLINE" ]; then
    log "TIMEOUT after ${MAX_MINUTES}m: $REPO@$SHORT context $CONTEXT not terminal: ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

# The combined status carries the latest status per context. Fixed order:
# "<state> <target_url> <description...>" (description last, may contain spaces).
JQ_PROG='[.statuses[] | select(.context == $ctx)] | if length == 0 then "absent - " else "\(.[0].state) \(.[0].target_url // "-") \(.[0].description // "")" end'

while :; do
  if JSON=$(gh api "repos/$REPO/commits/$SHA/status" 2>"$ERRFILE"); then
    API_FAILS=0
    LINE=$(printf '%s' "$JSON" | jq -r --arg ctx "$CONTEXT" "$JQ_PROG")
    read -r STATE URL DESC <<<"$LINE"
    S="state=$STATE url=$URL description=$DESC"
    if [ "$S" != "$LAST" ]; then
      log "$REPO@$SHORT $CONTEXT: $S"
      LAST="$S"
    fi
    case "$STATE" in
      success) log "STATUS_SUCCESS $REPO@$SHA $CONTEXT: url=$URL description=$DESC"; exit 0 ;;
      failure|error) log "STATUS_FAILED $REPO@$SHA $CONTEXT: state=$STATE url=$URL description=$DESC"; exit 1 ;;
    esac
  else
    api_fail "gh api commits/$SHORT/status for $REPO"
  fi
  sleep_or_timeout
done
