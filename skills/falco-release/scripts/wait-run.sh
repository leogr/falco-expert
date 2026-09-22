#!/usr/bin/env bash
# wait-run.sh - wait until a GitHub Actions workflow run concludes.
#
# Purpose:    Poll one workflow run until its status is "completed". Exit 0 on
#             conclusion "success"; on any other conclusion list the jobs of the
#             latest attempt with their conclusions and URLs, then exit 1.
# Usage:      wait-run.sh --repo <owner/repo> --run-id <id> [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 RUN_SUCCESS | 1 RUN_FAILED | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10

usage() {
  cat <<'EOF'
wait-run.sh - wait until a GitHub Actions workflow run concludes.

Polls one workflow run until it completes. Success exits 0; every other
conclusion (failure, cancelled, timed_out, action_required, startup_failure,
neutral, skipped, stale) prints the per-job conclusions of the latest attempt
and exits 1. Read-only.

Usage:
  wait-run.sh --repo <owner/repo> --run-id <id> [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>      Repository full name (required, no default org)
  --run-id <id>            Workflow run id, the number in .../actions/runs/<id> (required)
  --max-minutes <n>        Give up after n minutes (default 180)
  --interval-seconds <n>   Seconds between polls (default 60)
  -h, --help               Print this help and exit 0

Exit codes:
  0  RUN_SUCCESS  the run completed with conclusion success
  1  RUN_FAILED   the run completed with any other conclusion (jobs listed)
  2  usage error
  3  TIMEOUT      deadline reached while the run is still in progress
  4  API_ERROR    10 consecutive GitHub API failures

Example:
  wait-run.sh --repo my-org/my-repo --run-id 123456789 --max-minutes 90
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }
need_value() { [ "$#" -ge 2 ] || die_usage "flag $1 requires a value"; }

REPO=""
RUN_ID=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    --run-id) need_value "$@"; RUN_ID="$2"; shift 2 ;;
    --max-minutes) need_value "$@"; MAX_MINUTES="$2"; shift 2 ;;
    --interval-seconds) need_value "$@"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ] || die_usage "missing required --repo"
[ -n "$RUN_ID" ] || die_usage "missing required --run-id"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die_usage "--repo must be <owner/repo>"
[[ "$RUN_ID" =~ ^[1-9][0-9]*$ ]] || die_usage "--run-id must be a positive integer"
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
    log "TIMEOUT after ${MAX_MINUTES}m: $REPO run $RUN_ID not completed: ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

# Fixed-order fields; the workflow name comes last because it may contain spaces.
JQ_RUN='"\(.status) \(.conclusion // "-") \(.run_attempt) \(.html_url) \(.head_branch // "-") \(.name // "-")"'
JQ_JOBS='.[].jobs[] | "  \(.conclusion // .status) | \(.name) | \(.html_url)"'

while :; do
  if J=$(gh api "repos/$REPO/actions/runs/$RUN_ID" --jq "$JQ_RUN" 2>"$ERRFILE"); then
    API_FAILS=0
    read -r STATUS CONCLUSION ATTEMPT URL BRANCH NAME <<<"$J"
    S="status=$STATUS conclusion=$CONCLUSION attempt=$ATTEMPT branch=$BRANCH name=$NAME"
    if [ "$S" != "$LAST" ]; then
      log "$REPO run $RUN_ID: $S"
      LAST="$S"
    fi
    if [ "$STATUS" = "completed" ]; then
      if [ "$CONCLUSION" = "success" ]; then
        log "RUN_SUCCESS $REPO run $RUN_ID attempt=$ATTEMPT $URL"
        exit 0
      fi
      # --slurp cannot be combined with --jq in gh: capture the slurped pages, then filter.
      if JOBS_JSON=$(gh api --paginate --slurp "repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=100" 2>"$ERRFILE"); then
        printf '%s' "$JOBS_JSON" | jq -r "$JQ_JOBS"
      else
        log "API_WARN could not list jobs for run $RUN_ID: $(head -n1 "$ERRFILE" 2>/dev/null || true)"
      fi
      log "RUN_FAILED $REPO run $RUN_ID conclusion=$CONCLUSION attempt=$ATTEMPT $URL (jobs listed above)"
      exit 1
    fi
  else
    api_fail "gh api actions/runs/$RUN_ID for $REPO"
  fi
  sleep_or_timeout
done
