#!/usr/bin/env bash
# wait-org-sync.sh - wait until a user's permission on a repository reaches a level.
#
# Purpose:    Poll the collaborator permission of one user on one repository
#             until it is at least the expected level (used after an
#             organization membership change, e.g. an org.yaml PR merged and
#             the org-sync postsubmit ran). Levels, lowest to highest:
#             none < read < triage < write < maintain < admin.
# Usage:      wait-org-sync.sh --repo <owner/repo> --user <login> --permission <level> [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 PERMISSION_REACHED | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10

usage() {
  cat <<'EOF'
wait-org-sync.sh - wait until a user's permission on a repository reaches a level.

Polls GET /repos/<owner/repo>/collaborators/<login>/permission and succeeds as
soon as the user's role is at least the expected level, in the order
none < read < triage < write < maintain < admin. Prints every change of the
reported permission and role. Read-only.

Usage:
  wait-org-sync.sh --repo <owner/repo> --user <login> --permission <level> [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>      Repository full name (required, no default org)
  --user <login>           GitHub login to check (required)
  --permission <level>     Expected minimum level: read, triage, write, maintain or admin (required)
  --max-minutes <n>        Give up after n minutes (default 180)
  --interval-seconds <n>   Seconds between polls (default 60)
  -h, --help               Print this help and exit 0

Exit codes:
  0  PERMISSION_REACHED  the user's role is at least the expected level
  2  usage error
  3  TIMEOUT             deadline reached below the expected level
  4  API_ERROR           10 consecutive GitHub API failures (including a
                         persistent 404 for an unknown login)

Example:
  wait-org-sync.sh --repo my-org/my-repo --user octocat --permission write --max-minutes 30
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }
need_value() { [ "$#" -ge 2 ] || die_usage "flag $1 requires a value"; }

REPO=""
USER_LOGIN=""
EXPECTED=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    --user) need_value "$@"; USER_LOGIN="$2"; shift 2 ;;
    --permission) need_value "$@"; EXPECTED="$2"; shift 2 ;;
    --max-minutes) need_value "$@"; MAX_MINUTES="$2"; shift 2 ;;
    --interval-seconds) need_value "$@"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

rank_of() {
  case "$1" in
    none) echo 0 ;;
    read|pull) echo 1 ;;
    triage) echo 2 ;;
    write|push) echo 3 ;;
    maintain) echo 4 ;;
    admin) echo 5 ;;
    *) echo -1 ;;
  esac
}

[ -n "$REPO" ] || die_usage "missing required --repo"
[ -n "$USER_LOGIN" ] || die_usage "missing required --user"
[ -n "$EXPECTED" ] || die_usage "missing required --permission"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die_usage "--repo must be <owner/repo>"
[[ "$USER_LOGIN" =~ ^[A-Za-z0-9-]+(\[bot\])?$ ]] || die_usage "--user must be a GitHub login"
[[ "$EXPECTED" =~ ^(read|triage|write|maintain|admin)$ ]] || die_usage "--permission must be read, triage, write, maintain or admin"
[[ "$MAX_MINUTES" =~ ^[1-9][0-9]*$ ]] || die_usage "--max-minutes must be a positive integer"
[[ "$INTERVAL" =~ ^[1-9][0-9]*$ ]] || die_usage "--interval-seconds must be a positive integer"
EXPECTED_RANK=$(rank_of "$EXPECTED")

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
    log "TIMEOUT after ${MAX_MINUTES}m: $USER_LOGIN on $REPO below $EXPECTED: ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

# permission is the coarse level (admin/write/read/none); role_name is the
# fine-grained role (admin/maintain/write/triage/read) when available.
JQ_PROG='"\(.permission // "none") \(.role_name // .permission // "none")"'

while :; do
  if LINE=$(gh api "repos/$REPO/collaborators/$USER_LOGIN/permission" --jq "$JQ_PROG" 2>"$ERRFILE"); then
    API_FAILS=0
    read -r PERMISSION ROLE <<<"$LINE"
    S="permission=$PERMISSION role=$ROLE (expected at least $EXPECTED)"
    if [ "$S" != "$LAST" ]; then
      log "$USER_LOGIN on $REPO: $S"
      LAST="$S"
    fi
    ACTUAL_RANK=$(rank_of "$ROLE")
    if [ "$ACTUAL_RANK" -lt 0 ]; then
      ACTUAL_RANK=$(rank_of "$PERMISSION")
    fi
    if [ "$ACTUAL_RANK" -ge "$EXPECTED_RANK" ]; then
      log "PERMISSION_REACHED $USER_LOGIN on $REPO: permission=$PERMISSION role=$ROLE (expected at least $EXPECTED)"
      exit 0
    fi
  else
    api_fail "gh api collaborators/$USER_LOGIN/permission for $REPO"
  fi
  sleep_or_timeout
done
