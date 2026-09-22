#!/usr/bin/env bash
# wait-new-pr.sh - wait until a new pull request matching author/title/base appears.
#
# Purpose:    Poll the pull requests of a repository (newest first) until one
#             created after --since matches the optional author login, title
#             regex and base branch; print its number and URL.
# Usage:      wait-new-pr.sh --repo <owner/repo> --since <UTC ISO8601> [--author <login>] [--title-regex <ere>] [--base <branch>] [--state open|closed|all] [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 NEW_PR | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10
STATE="open"

usage() {
  cat <<'EOF'
wait-new-pr.sh - wait until a new pull request matching author/title/base appears.

Polls the repository's pull requests (100 newest by creation date) until one
created strictly after --since matches every filter given. Prints all matches
and reports the newest one. Read-only.

Usage:
  wait-new-pr.sh --repo <owner/repo> --since <UTC ISO8601> [--author <login>] [--title-regex <ere>] [--base <branch>] [--state open|closed|all] [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>      Repository full name (required, no default org)
  --since <timestamp>      Only PRs created after this UTC instant, format
                           YYYY-MM-DDTHH:MM:SSZ (required; e.g. the output of
                           date -u +%FT%TZ taken before triggering the bot)
  --author <login>         Exact author login as returned by the REST API
                           (bots end with [bot], e.g. dependabot[bot])
  --title-regex <ere>      Regular expression the title must match (jq test() syntax)
  --base <branch>          Base branch the PR must target
  --state <state>          open (default), closed or all
  --max-minutes <n>        Give up after n minutes (default 180)
  --interval-seconds <n>   Seconds between polls (default 60)
  -h, --help               Print this help and exit 0

Exit codes:
  0  NEW_PR       at least one matching PR exists (newest reported on the final line)
  2  usage error
  3  TIMEOUT      deadline reached with no matching PR
  4  API_ERROR    10 consecutive GitHub API failures

Example:
  wait-new-pr.sh --repo my-org/my-repo --since 2026-01-01T00:00:00Z --author 'dependabot[bot]' --title-regex '^chore\(deps\)' --base main
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }
need_value() { [ "$#" -ge 2 ] || die_usage "flag $1 requires a value"; }

REPO=""
SINCE=""
AUTHOR=""
TITLE_RE=""
BASE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    --since) need_value "$@"; SINCE="$2"; shift 2 ;;
    --author) need_value "$@"; AUTHOR="$2"; shift 2 ;;
    --title-regex) need_value "$@"; TITLE_RE="$2"; shift 2 ;;
    --base) need_value "$@"; BASE="$2"; shift 2 ;;
    --state) need_value "$@"; STATE="$2"; shift 2 ;;
    --max-minutes) need_value "$@"; MAX_MINUTES="$2"; shift 2 ;;
    --interval-seconds) need_value "$@"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ] || die_usage "missing required --repo"
[ -n "$SINCE" ] || die_usage "missing required --since"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die_usage "--repo must be <owner/repo>"
[[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || die_usage "--since must be UTC ISO8601 like 2026-01-31T12:00:00Z"
[[ "$STATE" =~ ^(open|closed|all)$ ]] || die_usage "--state must be open, closed or all"
if [ -n "$BASE" ]; then
  [[ "$BASE" =~ ^[A-Za-z0-9_./-]+$ ]] || die_usage "--base contains characters that are not allowed in a branch name"
fi
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
FILTERS="state=$STATE since=$SINCE author=${AUTHOR:--} title_regex=${TITLE_RE:--} base=${BASE:--}"
sleep_or_timeout() {
  local now remaining
  now=$(date +%s)
  if [ "$now" -ge "$DEADLINE" ]; then
    log "TIMEOUT after ${MAX_MINUTES}m: no PR in $REPO matched ($FILTERS): ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

QUERY="repos/$REPO/pulls?state=$STATE&sort=created&direction=desc&per_page=100"
if [ -n "$BASE" ]; then
  QUERY="$QUERY&base=$BASE"
fi

# Both timestamps share the YYYY-MM-DDTHH:MM:SSZ shape, so a string comparison
# orders them correctly. Line 1 = "<scanned> <matched>", then one match per line,
# newest first.
JQ_PROG='
[.[] | select(.created_at > $since)
     | select(($author == "") or (.user.login == $author))
     | select(($re == "") or (.title | test($re)))
     | {number, url: .html_url, created_at, user: .user.login, base: .base.ref, title}] as $m
| "\(length) \($m | length)",
  ($m[] | "  MATCH #\(.number) \(.url) created=\(.created_at) author=\(.user) base=\(.base) title=\(.title)")
'

while :; do
  if JSON=$(gh api "$QUERY" 2>"$ERRFILE"); then
    API_FAILS=0
    OUT=$(printf '%s' "$JSON" | jq -r --arg since "$SINCE" --arg author "$AUTHOR" --arg re "$TITLE_RE" "$JQ_PROG")
    SUMMARY=$(printf '%s\n' "$OUT" | head -n1)
    read -r SCANNED MATCHED <<<"$SUMMARY"
    S="scanned=$SCANNED matched=$MATCHED ($FILTERS)"
    if [ "$S" != "$LAST" ]; then
      log "$REPO: $S"
      LAST="$S"
    fi
    if [ "$MATCHED" -gt 0 ]; then
      printf '%s\n' "$OUT" | tail -n +2
      NEWEST=$(printf '%s\n' "$OUT" | sed -n '2p')
      read -r _ NUMBER URL _ <<<"$NEWEST"
      log "NEW_PR ${NUMBER#\#} $URL ($MATCHED matching, newest reported; all listed above)"
      exit 0
    fi
  else
    api_fail "gh api pulls for $REPO"
  fi
  sleep_or_timeout
done
