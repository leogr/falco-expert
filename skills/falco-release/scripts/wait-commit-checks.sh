#!/usr/bin/env bash
# wait-commit-checks.sh - wait until the CI checks on one commit settle.
#
# Purpose:    Poll the workflow runs (actions/runs?head_sha=) and the check runs
#             of one full commit SHA until nothing is running. Meant for branch
#             heads with no PR to watch (default-branch merge commits, release
#             branch heads). Check runs from the CI app (github-actions by
#             default) gate the verdict; check runs from other apps are reported
#             as informational only. On settlement, non-green runs and check runs
#             are printed with their URLs.
# Usage:      wait-commit-checks.sh --repo <owner/repo> --sha <full-sha> [--ci-app <slug>] [--min-runs <n>] [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 SETTLED_GREEN | 1 SETTLED_RED | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10
CI_APP="github-actions"
MIN_RUNS=1

usage() {
  cat <<'EOF'
wait-commit-checks.sh - wait until the CI checks on one commit settle.

Polls the workflow runs and the check runs of one commit until none is running.
Only check runs from the CI app (default: github-actions) count for the verdict;
check runs from other apps are printed as informational. Green means every
counted run and check run concluded success, neutral or skipped. Read-only.

Usage:
  wait-commit-checks.sh --repo <owner/repo> --sha <full-sha> [--ci-app <slug>] [--min-runs <n>] [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>      Repository full name (required, no default org)
  --sha <full-sha>         Full 40-hex commit SHA (required)
  --ci-app <slug>          App slug whose check runs gate the verdict (default github-actions)
  --min-runs <n>           Do not consider the commit settled before at least n
                           workflow runs exist (default 1; runs appear a few
                           seconds after a push)
  --max-minutes <n>        Give up after n minutes (default 180)
  --interval-seconds <n>   Seconds between polls (default 60)
  -h, --help               Print this help and exit 0

Exit codes:
  0  SETTLED_GREEN  all workflow runs and CI-app check runs concluded success/neutral/skipped
  1  SETTLED_RED    settled with at least one non-green run or check run (listed with URLs)
  2  usage error
  3  TIMEOUT        deadline reached with runs still in progress
  4  API_ERROR      10 consecutive GitHub API failures

Example:
  wait-commit-checks.sh --repo my-org/my-repo --sha 0123456789abcdef0123456789abcdef01234567 --max-minutes 240
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }
need_value() { [ "$#" -ge 2 ] || die_usage "flag $1 requires a value"; }

REPO=""
SHA=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    --sha) need_value "$@"; SHA="$2"; shift 2 ;;
    --ci-app) need_value "$@"; CI_APP="$2"; shift 2 ;;
    --min-runs) need_value "$@"; MIN_RUNS="$2"; shift 2 ;;
    --max-minutes) need_value "$@"; MAX_MINUTES="$2"; shift 2 ;;
    --interval-seconds) need_value "$@"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ] || die_usage "missing required --repo"
[ -n "$SHA" ] || die_usage "missing required --sha"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die_usage "--repo must be <owner/repo>"
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || die_usage "--sha must be a full 40-hex lowercase commit SHA"
[[ "$CI_APP" =~ ^[A-Za-z0-9_.-]+$ ]] || die_usage "--ci-app must be an app slug"
[[ "$MIN_RUNS" =~ ^[0-9]+$ ]] || die_usage "--min-runs must be a non-negative integer"
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
    log "TIMEOUT after ${MAX_MINUTES}m: $REPO@$SHORT still running: ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

# Workflow runs: line 1 = "<total> <running> <not-green>", then one
# "  RUN <conclusion> | <name> | <url>" per non-green completed run.
JQ_RUNS='
[.workflow_runs[] | {name, status, conclusion: (.conclusion // "-"), url: .html_url}] as $r
| ($r | map(select(.status == "completed") | select(.conclusion | IN("success","neutral","skipped") | not))) as $red
| "\($r | length) \([$r[] | select(.status == "completed" | not)] | length) \($red | length)",
  ($red[] | "  RUN \(.conclusion) | \(.name) | \(.url)")
'
# Check runs (all pages slurped): line 1 = "<ci-total> <ci-pending> <ci-not-green> <other-total>",
# then "  CHECK <conclusion> | <name> | <url>" per non-green CI-app check run,
# then "  INFO <app> <status>/<conclusion> | <name> | <url>" per other-app check run.
JQ_CHECKS='
[.[].check_runs[] | {name, status, conclusion: (.conclusion // "-"), url: .html_url, app: (.app.slug // "-")}] as $c
| ($c | map(select(.app == $ciapp))) as $ci
| ($c | map(select(.app == $ciapp | not))) as $other
| ($ci | map(select(.status == "completed") | select(.conclusion | IN("success","neutral","skipped") | not))) as $red
| "\($ci | length) \([$ci[] | select(.status == "completed" | not)] | length) \($red | length) \($other | length)",
  ($red[] | "  CHECK \(.conclusion) | \(.name) | \(.url)"),
  ($other[] | "  INFO \(.app) \(.status)/\(.conclusion) | \(.name) | \(.url)")
'

while :; do
  if ! RUNS_JSON=$(gh api "repos/$REPO/actions/runs?head_sha=$SHA&per_page=100" 2>"$ERRFILE"); then
    api_fail "gh api actions/runs for $REPO@$SHORT"
    sleep_or_timeout
    continue
  fi
  if ! CHECKS_JSON=$(gh api --paginate --slurp "repos/$REPO/commits/$SHA/check-runs?per_page=100" 2>"$ERRFILE"); then
    api_fail "gh api check-runs for $REPO@$SHORT"
    sleep_or_timeout
    continue
  fi
  API_FAILS=0
  ROUT=$(printf '%s' "$RUNS_JSON" | jq -r "$JQ_RUNS")
  COUT=$(printf '%s' "$CHECKS_JSON" | jq -r --arg ciapp "$CI_APP" "$JQ_CHECKS")
  RSUM=$(printf '%s\n' "$ROUT" | head -n1)
  CSUM=$(printf '%s\n' "$COUT" | head -n1)
  read -r R_TOTAL R_RUNNING R_RED <<<"$RSUM"
  read -r C_TOTAL C_PENDING C_RED C_OTHER <<<"$CSUM"
  S="runs=$R_TOTAL running=$R_RUNNING notgreen=$R_RED checks[$CI_APP]=$C_TOTAL pending=$C_PENDING notgreen=$C_RED other_app_checks=$C_OTHER"
  if [ "$S" != "$LAST" ]; then
    log "$REPO@$SHORT: $S"
    LAST="$S"
  fi
  if [ "$R_TOTAL" -ge "$MIN_RUNS" ] && [ "$R_RUNNING" -eq 0 ] && [ "$C_PENDING" -eq 0 ]; then
    printf '%s\n' "$ROUT" | tail -n +2
    printf '%s\n' "$COUT" | tail -n +2
    if [ "$R_RED" -eq 0 ] && [ "$C_RED" -eq 0 ]; then
      log "SETTLED_GREEN $REPO@$SHA: $R_TOTAL runs and $C_TOTAL $CI_APP check runs all success/neutral/skipped ($C_OTHER other-app check runs informational)"
      exit 0
    fi
    log "SETTLED_RED $REPO@$SHA: $R_RED runs and $C_RED $CI_APP check runs not green (listed above; $C_OTHER other-app check runs informational)"
    exit 1
  fi
  sleep_or_timeout
done
