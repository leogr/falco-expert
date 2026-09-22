#!/usr/bin/env bash
# wait-tag.sh - wait until a git tag (and optionally its GitHub release) exists.
#
# Purpose:    Poll the repository refs until refs/tags/<tag> exists, resolve the
#             commit it points to (dereferencing annotated tag objects), and
#             report the GitHub release for that tag when one exists (draft and
#             prerelease flags). With --require-release the wait also covers the
#             release itself.
# Usage:      wait-tag.sh --repo <owner/repo> --tag <name> [--require-release] [--max-minutes <n>] [--interval-seconds <n>]
# Exit codes: 0 TAG_PRESENT | 2 usage error | 3 TIMEOUT | 4 API_ERROR
# Read-only. Never writes to GitHub.
set -euo pipefail

MAX_MINUTES=180
INTERVAL=60
MAX_API_FAILS=10
REQUIRE_RELEASE=0

usage() {
  cat <<'EOF'
wait-tag.sh - wait until a git tag (and optionally its GitHub release) exists.

Polls until refs/tags/<tag> exists on GitHub, prints the commit it points to
(annotated tags are dereferenced) and, when a release exists for the tag, its
draft/prerelease flags and URL. Uses the exact ref name: prefix matches such as
release candidates of the same version are ignored. Read-only.

Usage:
  wait-tag.sh --repo <owner/repo> --tag <name> [--require-release] [--max-minutes <n>] [--interval-seconds <n>]

Flags:
  --repo <owner/repo>      Repository full name (required, no default org)
  --tag <name>             Tag name, exactly as it appears after refs/tags/ (required)
  --require-release        Also wait until a GitHub release for the tag exists
                           (searched among the 100 most recent releases)
  --max-minutes <n>        Give up after n minutes (default 180)
  --interval-seconds <n>   Seconds between polls (default 60)
  -h, --help               Print this help and exit 0

Exit codes:
  0  TAG_PRESENT  the tag exists (and the release too, with --require-release)
  2  usage error
  3  TIMEOUT      deadline reached before the tag (or release) appeared
  4  API_ERROR    10 consecutive GitHub API failures

Example:
  wait-tag.sh --repo my-org/my-repo --tag 1.2.3 --require-release --max-minutes 30
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }
need_value() { [ "$#" -ge 2 ] || die_usage "flag $1 requires a value"; }

REPO=""
TAG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    --tag) need_value "$@"; TAG="$2"; shift 2 ;;
    --require-release) REQUIRE_RELEASE=1; shift ;;
    --max-minutes) need_value "$@"; MAX_MINUTES="$2"; shift 2 ;;
    --interval-seconds) need_value "$@"; INTERVAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ] || die_usage "missing required --repo"
[ -n "$TAG" ] || die_usage "missing required --tag"
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || die_usage "--repo must be <owner/repo>"
[[ "$TAG" =~ ^[A-Za-z0-9_./+-]+$ ]] || die_usage "--tag contains characters that are not allowed in a ref name"
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
    log "TIMEOUT after ${MAX_MINUTES}m: $REPO tag $TAG: ${LAST:-no state observed}"
    exit 3
  fi
  remaining=$((DEADLINE - now))
  if [ "$remaining" -lt "$INTERVAL" ]; then sleep "$remaining"; else sleep "$INTERVAL"; fi
}

# matching-refs is a prefix match and answers 200 with [] when nothing matches,
# so a missing tag is not an API error. Filter on the exact ref name.
JQ_REF='[.[] | select(.ref == $ref)] | if length == 0 then "" else "\(.[0].object.type) \(.[0].object.sha)" end'
JQ_REL='[.[] | select(.tag_name == $tag)] | if length == 0 then "" else "draft=\(.[0].draft) prerelease=\(.[0].prerelease) name=\(.[0].name // "-") url=\(.[0].html_url)" end'

while :; do
  if ! REFS_JSON=$(gh api "repos/$REPO/git/matching-refs/tags/$TAG" 2>"$ERRFILE"); then
    api_fail "gh api matching-refs for $REPO tag $TAG"
    sleep_or_timeout
    continue
  fi
  API_FAILS=0
  REF=$(printf '%s' "$REFS_JSON" | jq -r --arg ref "refs/tags/$TAG" "$JQ_REF")
  if [ -z "$REF" ]; then
    S="tag absent"
    if [ "$S" != "$LAST" ]; then
      log "$REPO tag $TAG: $S"
      LAST="$S"
    fi
    sleep_or_timeout
    continue
  fi
  read -r OBJ_TYPE OBJ_SHA <<<"$REF"
  COMMIT="$OBJ_SHA"
  TAG_NOTE="lightweight"
  if [ "$OBJ_TYPE" = "tag" ]; then
    if ! COMMIT=$(gh api "repos/$REPO/git/tags/$OBJ_SHA" --jq '.object.sha' 2>"$ERRFILE"); then
      api_fail "gh api git/tags for $REPO tag object $OBJ_SHA"
      sleep_or_timeout
      continue
    fi
    TAG_NOTE="annotated tag object $OBJ_SHA"
  fi
  if ! REL_JSON=$(gh api "repos/$REPO/releases?per_page=100" 2>"$ERRFILE"); then
    api_fail "gh api releases for $REPO"
    sleep_or_timeout
    continue
  fi
  RELEASE=$(printf '%s' "$REL_JSON" | jq -r --arg tag "$TAG" "$JQ_REL")
  if [ -z "$RELEASE" ]; then
    RELEASE_DESC="release=none (not among the 100 most recent releases)"
  else
    RELEASE_DESC="release: $RELEASE"
  fi
  S="tag present commit=$COMMIT ($TAG_NOTE) $RELEASE_DESC"
  if [ "$S" != "$LAST" ]; then
    log "$REPO tag $TAG: $S"
    LAST="$S"
  fi
  if [ "$REQUIRE_RELEASE" -eq 1 ] && [ -z "$RELEASE" ]; then
    sleep_or_timeout
    continue
  fi
  log "TAG_PRESENT $REPO $TAG commit=$COMMIT ($TAG_NOTE) $RELEASE_DESC"
  exit 0
done
