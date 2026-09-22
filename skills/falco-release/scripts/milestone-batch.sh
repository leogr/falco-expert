#!/usr/bin/env bash
# milestone-batch.sh - classified milestone assignment through Prow `/milestone` comments.
#
# Gated: dry run by default, --apply writes.
#
# Purpose
#   Assign milestones to a classified list of issues and PRs (next milestone for default-branch
#   merges after the branch point, patch milestone for release-branch cherry-picks, none for stale
#   or user-side items). Never blanket-assigns: every row carries its classification, every item is
#   re-read live before anything is posted, and a milestone already set to a different value stops
#   the script unless --allow-override is given.
#
# Usage
#   milestone-batch.sh --repo <owner/repo> --milestone <title> --items-file <abs> --workdir <abs>
#       [--patch-milestone <title>] [--allow-override] [--wait-seconds <n>] [--poll-seconds <n>] [--apply]
#
# Items file: one item per line, `<number> <classification>` with classification in next|patch|none.
#   Blank lines and lines starting with # are ignored. `next` rows get --milestone, `patch` rows get
#   --patch-milestone (required when a patch row exists), `none` rows are listed and skipped.
#
# Dry run: verify both milestones exist in the repository, then per item: exists, kind (issue/pr),
#   state, current milestone, planned target -> PLAN / ALREADY_SET / SKIP lines, DRY_RUN_OK.
# Apply: for every next/patch row not already set, write `/milestone <title>` to
#   <workdir>/milestone-<number>.md, post it as a comment through the issues API (`-F body=@file`,
#   works for issues and PRs alike), wait until the milestone landed (bounded), MILESTONE_BATCH_DONE.
#
# Exit codes
#   0 dry run OK / every item verified   2 usage   3 ABORT: milestone missing, item missing, or a
#   different milestone already set (without --allow-override)   4 GUARD_FAIL: the milestone did
#   not land within --wait-seconds   5 refused (unused)
#
# Example
#   milestone-batch.sh --repo falcosecurity/falco --milestone 0.45.0 --patch-milestone 0.44.2 \
#       --items-file /abs/output/milestone-items.txt --workdir /abs/output/milestone-batch
#
# Dry run by default; --apply performs the public action after re-checking every precondition.
#
# Sources generalized: output/2026-09-22-falco-release-helper-templates/falco-milestone-batch-sep11.sh
#   (per-item fail-closed state check) and the classification rule in
#   output/2026-09-03-release-prep-process-notes.md section 4b. Prow `milestone` plugin: the
#   `/milestone <title>` comment is honoured for members of the configured maintainer teams.
set -euo pipefail

usage() { sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
die_usage() { echo "usage error: $*" >&2; usage >&2; exit 2; }
need2() { if [ $# -lt 2 ] || [ -z "$2" ]; then die_usage "$1 needs a value"; fi; }
abort() { echo "ABORT: $*"; exit 3; }
guard_fail() { echo "GUARD_FAIL: $*"; exit 4; }
stamp() { date -u +%FT%TZ; }
need_abs() { case "$2" in /*) ;; *) die_usage "$1 must be an absolute path: $2";; esac; }

REPO=""; MILESTONE=""; PATCH_MILESTONE=""; ITEMS=""; WORKDIR=""; ALLOW_OVERRIDE=0
WAIT_SECONDS=180; POLL_SECONDS=10; APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0;;
    --repo) need2 "$@"; REPO=$2; shift 2;;
    --milestone) need2 "$@"; MILESTONE=$2; shift 2;;
    --patch-milestone) need2 "$@"; PATCH_MILESTONE=$2; shift 2;;
    --items-file) need2 "$@"; ITEMS=$2; shift 2;;
    --workdir) need2 "$@"; WORKDIR=$2; shift 2;;
    --allow-override) ALLOW_OVERRIDE=1; shift;;
    --wait-seconds) need2 "$@"; WAIT_SECONDS=$2; shift 2;;
    --poll-seconds) need2 "$@"; POLL_SECONDS=$2; shift 2;;
    --apply) APPLY=1; shift;;
    *) die_usage "unknown flag: $1";;
  esac
done
[ -n "$REPO" ] || die_usage "--repo is required"
case "$REPO" in */*) ;; *) die_usage "--repo must be owner/repo";; esac
[ -n "$MILESTONE" ] || die_usage "--milestone is required"
[ -n "$ITEMS" ] || die_usage "--items-file is required"
need_abs --items-file "$ITEMS"; [ -f "$ITEMS" ] || die_usage "items file not found: $ITEMS"
[ -n "$WORKDIR" ] || die_usage "--workdir is required"
need_abs --workdir "$WORKDIR"
mkdir -p "$WORKDIR"

echo "== $(stamp) milestone-batch $REPO next='$MILESTONE' patch='${PATCH_MILESTONE:-}' apply=$APPLY"

# parse the items file first (usage errors before any API call)
NUMS=(); CLASSES=()
while read -r NUM CLASS REST; do
  case "$NUM" in ''|'#'*) continue;; esac
  [[ "$NUM" =~ ^[0-9]+$ ]] || die_usage "bad item number '$NUM' in $ITEMS"
  case "$CLASS" in next|patch|none) ;; *) die_usage "bad classification '$CLASS' for #$NUM (next|patch|none)";; esac
  [ -z "$REST" ] || die_usage "trailing text after '#$NUM $CLASS': $REST"
  NUMS+=("$NUM"); CLASSES+=("$CLASS")
done < "$ITEMS"
[ ${#NUMS[@]} -gt 0 ] || die_usage "items file is empty"
for CLASS in "${CLASSES[@]}"; do
  if [ "$CLASS" = patch ] && [ -z "$PATCH_MILESTONE" ]; then die_usage "a patch row needs --patch-milestone"; fi
done

# 1. milestones exist
TITLES=$(gh api --paginate "repos/$REPO/milestones?state=all&per_page=100" --jq '.[].title') || abort "cannot list milestones"
printf '%s\n' "$TITLES" | grep -q -x -F -- "$MILESTONE" || abort "milestone '$MILESTONE' does not exist in $REPO"
[ -z "$PATCH_MILESTONE" ] || printf '%s\n' "$TITLES" | grep -q -x -F -- "$PATCH_MILESTONE" || abort "milestone '$PATCH_MILESTONE' does not exist in $REPO"
echo "ok: milestone(s) exist"

# 2. per-item live state
TODO_NUMS=(); TODO_TARGETS=(); PROBLEMS=""
for i in "${!NUMS[@]}"; do
  NUM=${NUMS[$i]}; CLASS=${CLASSES[$i]}
  INFO=$(gh api "repos/$REPO/issues/$NUM" --jq '"\(.state) \(.milestone.title // "-") \(if .pull_request then "pr" else "issue" end) \(.title)"' 2>"$WORKDIR/issue-$NUM.err") || { PROBLEMS="$PROBLEMS #$NUM(missing)"; echo "MISSING #$NUM: $(head -c 120 "$WORKDIR/issue-$NUM.err")"; continue; }
  read -r STATE CUR KIND TITLE <<<"$INFO"
  case "$CLASS" in next) TARGET=$MILESTONE;; patch) TARGET=$PATCH_MILESTONE;; none) TARGET="";; esac
  if [ -z "$TARGET" ]; then echo "SKIP #$NUM $KIND $STATE milestone=$CUR (classified none): ${TITLE:0:70}"; continue; fi
  if [ "$CUR" = "$TARGET" ]; then echo "ALREADY_SET #$NUM $KIND $STATE milestone=$CUR: ${TITLE:0:70}"; continue; fi
  if [ "$CUR" != "-" ] && [ $ALLOW_OVERRIDE = 0 ]; then
    echo "CONFLICT #$NUM $KIND $STATE milestone=$CUR, wanted $TARGET (pass --allow-override to move it)"; PROBLEMS="$PROBLEMS #$NUM(has $CUR)"; continue
  fi
  echo "PLAN #$NUM $KIND $STATE milestone=$CUR -> $TARGET: ${TITLE:0:70}"
  TODO_NUMS+=("$NUM"); TODO_TARGETS+=("$TARGET")
done
[ -z "$PROBLEMS" ] || abort "item problems:$PROBLEMS"
echo "plan: ${#TODO_NUMS[@]} comment(s) to post"
if [ $APPLY = 0 ]; then echo "DRY_RUN_OK"; exit 0; fi
[ ${#TODO_NUMS[@]} -gt 0 ] || { echo "nothing to do (every item already carries its milestone)"; echo "MILESTONE_BATCH_DONE $(stamp)"; exit 0; }

# 3. apply: one Prow command per item, verified
for i in "${!TODO_NUMS[@]}"; do
  NUM=${TODO_NUMS[$i]}; TARGET=${TODO_TARGETS[$i]}
  BODY="$WORKDIR/milestone-$NUM.md"
  printf '/milestone %s\n' "$TARGET" > "$BODY"
  URL=$(gh api -X POST "repos/$REPO/issues/$NUM/comments" -F body=@"$BODY" --jq .html_url) || guard_fail "comment on #$NUM failed"
  echo "posted #$NUM: $URL"
  DEADLINE=$(( $(date +%s) + WAIT_SECONDS ))
  while :; do
    NOW=$(gh api "repos/$REPO/issues/$NUM" --jq '.milestone.title // "-"')
    if [ "$NOW" = "$TARGET" ]; then echo "ok: #$NUM milestone=$NOW"; break; fi
    [ "$(date +%s)" -lt "$DEADLINE" ] || guard_fail "#$NUM milestone is '$NOW' after ${WAIT_SECONDS}s (Prow may be slow; re-check by hand before re-posting)"
    sleep "$POLL_SECONDS"
  done
done
echo "MILESTONE_BATCH_DONE $(stamp) items=${#TODO_NUMS[@]}"
