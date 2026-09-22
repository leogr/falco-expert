#!/usr/bin/env bash
# gated-rerun.sh - re-run the failed jobs of a workflow run only when the failure is an infrastructure flake.
#
# Gated: dry run by default, --apply writes.
#
# Purpose
#   A red job is re-run only if its log matches at least one known infrastructure pattern (download
#   50x, Go module proxy stream error, expired artifact, runner provisioning error, ...) and, when
#   given, the external dependency answers again. Compile and test failures never match: the script
#   stops with ABORT and the human reads the log. Retries are bounded by the run attempt counter.
#
# Usage
#   gated-rerun.sh --repo <owner/repo> --run-id <id> --workdir <abs> --pattern <regex>...
#       [--health-url <url>] [--health-follow] [--max-attempts <n>] [--whole-run]
#       [--wait-seconds <n>] [--poll-seconds <n>] [--apply]
#
# Flags
#   --pattern <regex>     extended regex (grep -E); repeatable; every failed job's log must match at
#                         least one of them (the whole log is searched: block-buffered logs put the
#                         error far from the progress lines)
#   --health-url <url>    must answer HTTP 200 before a re-run (HEAD request, 20 s timeout);
#                         --health-follow follows redirects so a 302 -> 200 chain counts as 200
#   --max-attempts <n>    stop when the run's run_attempt has reached n (default 3)
#   --whole-run           `gh run rerun <id>` instead of `--failed`, for workflows whose downstream
#                         jobs consume artifacts produced by earlier jobs of the same attempt
#   --workdir <abs>       where the job logs are stored (job-<id>.log and job-<id>.clean.log)
#
# Dry run: run state, failed job list, log fetch through `gh api repos/<r>/actions/jobs/<id>/logs`,
#   ANSI codes stripped, MATCH / NO_MATCH per job, then DRY_RUN_OK or
#   `ABORT: <job> does not match an infrastructure pattern` (exit 3).
# Apply: the same checks, then `gh run rerun <id> --failed` (or the whole run), wait until
#   run_attempt increases, print the new attempt, RERUN_DONE.
#
# Exit codes
#   0 dry run OK / re-run requested and attempt increased   2 usage   3 ABORT: precondition
#   4 GUARD_FAIL: the attempt counter did not increase within --wait-seconds   5 refused (unused)
#
# Example
#   gated-rerun.sh --repo falcosecurity/falco --run-id 34854786966 --workdir /abs/output/rerun-logs \
#       --pattern 'Each download failed' --pattern 'returned error: 50[234]' \
#       --health-url https://github.com/oneapi-src/oneTBB/archive/refs/tags/v2022.1.0.tar.gz --health-follow
#
# Dry run by default; --apply performs the public action after re-checking every precondition.
#
# Sources generalized: output/2026-09-22-falco-release-helper-templates/falco-3995-rerun-when-healthy.sh,
#   falcoctl-ci-rerun-until-green.sh, libs-rerun-34616491964.sh (log pattern gate, health probe,
#   bounded retries). Log endpoint: GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs.
set -euo pipefail

usage() { sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
die_usage() { echo "usage error: $*" >&2; usage >&2; exit 2; }
need2() { if [ $# -lt 2 ] || [ -z "$2" ]; then die_usage "$1 needs a value"; fi; }
abort() { echo "ABORT: $*"; exit 3; }
guard_fail() { echo "GUARD_FAIL: $*"; exit 4; }
stamp() { date -u +%FT%TZ; }
need_abs() { case "$2" in /*) ;; *) die_usage "$1 must be an absolute path: $2";; esac; }

REPO=""; RUN_ID=""; WORKDIR=""; HEALTH_URL=""; HEALTH_FOLLOW=0; MAX_ATTEMPTS=3; WHOLE_RUN=0
WAIT_SECONDS=120; POLL_SECONDS=10; APPLY=0
PATTERNS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0;;
    --repo) need2 "$@"; REPO=$2; shift 2;;
    --run-id) need2 "$@"; RUN_ID=$2; shift 2;;
    --workdir) need2 "$@"; WORKDIR=$2; shift 2;;
    --pattern) need2 "$@"; PATTERNS+=("$2"); shift 2;;
    --health-url) need2 "$@"; HEALTH_URL=$2; shift 2;;
    --health-follow) HEALTH_FOLLOW=1; shift;;
    --max-attempts) need2 "$@"; MAX_ATTEMPTS=$2; shift 2;;
    --whole-run) WHOLE_RUN=1; shift;;
    --wait-seconds) need2 "$@"; WAIT_SECONDS=$2; shift 2;;
    --poll-seconds) need2 "$@"; POLL_SECONDS=$2; shift 2;;
    --apply) APPLY=1; shift;;
    *) die_usage "unknown flag: $1";;
  esac
done
[ -n "$REPO" ] || die_usage "--repo is required"
case "$REPO" in */*) ;; *) die_usage "--repo must be owner/repo";; esac
[[ "$RUN_ID" =~ ^[0-9]+$ ]] || die_usage "--run-id must be numeric"
[ -n "$WORKDIR" ] || die_usage "--workdir is required"
need_abs --workdir "$WORKDIR"
[ ${#PATTERNS[@]} -gt 0 ] || die_usage "at least one --pattern is required"
[[ "$MAX_ATTEMPTS" =~ ^[0-9]+$ ]] || die_usage "--max-attempts must be numeric"
mkdir -p "$WORKDIR"

echo "== $(stamp) gated-rerun $REPO run=$RUN_ID apply=$APPLY max_attempts=$MAX_ATTEMPTS whole_run=$WHOLE_RUN"

# 1. run state
STATE=$(gh api "repos/$REPO/actions/runs/$RUN_ID" --jq '"\(.status) \(.conclusion // "-") \(.run_attempt) \(.head_sha) \(.name)"') || abort "cannot read run $RUN_ID"
read -r STATUS CONCLUSION ATTEMPT HEAD_SHA NAME <<<"$STATE"
echo "run: name='$NAME' status=$STATUS conclusion=$CONCLUSION attempt=$ATTEMPT head=$HEAD_SHA"
[ "$STATUS" = "completed" ] || abort "run $RUN_ID is not completed yet ($STATUS)"
if [ "$CONCLUSION" = "success" ]; then abort "run $RUN_ID is green (conclusion=success), nothing to re-run"; fi
[ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ] || abort "run_attempt $ATTEMPT has reached --max-attempts $MAX_ATTEMPTS, needs a human look"

# 2. failed jobs
FAILED=$(gh api "repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=100" --jq '.jobs[] | select(.conclusion=="failure" or .conclusion=="cancelled" or .conclusion=="timed_out") | "\(.id) \(.conclusion) \(.name)"')
[ -n "$FAILED" ] || abort "no failed jobs in run $RUN_ID (conclusion=$CONCLUSION)"
printf '%s\n' "$FAILED" | sed 's/^/  failed job: /'

# 3. log pattern gate (whole log, ANSI stripped)
NO_MATCH=""
while read -r JID JCONCL JNAME; do
  [ -n "$JID" ] || continue
  RAW="$WORKDIR/job-$JID.log"; CLEAN="$WORKDIR/job-$JID.clean.log"
  gh api --allow-escape-sequences "repos/$REPO/actions/jobs/$JID/logs" > "$RAW" 2>"$WORKDIR/job-$JID.fetch.err" || abort "log fetch failed for job $JID ($JNAME): $(head -c 200 "$WORKDIR/job-$JID.fetch.err")"
  sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$RAW" > "$CLEAN"
  HIT=""
  for PAT in "${PATTERNS[@]}"; do
    N=$(grep -c -E -- "$PAT" "$CLEAN" || true)
    if [ "${N:-0}" -gt 0 ]; then HIT="$PAT"; echo "MATCH job $JID ($JNAME, $JCONCL): pattern '$PAT' on $N line(s); log $CLEAN"; break; fi
  done
  if [ -z "$HIT" ]; then
    echo "NO_MATCH job $JID ($JNAME, $JCONCL): no infrastructure pattern; first error lines:"
    grep -n -E '##\[error\]|FAIL|Error:|error:' "$CLEAN" | head -n 5 | cut -c1-200 | sed 's/^/    /' || true
    NO_MATCH="$NO_MATCH $JID($JNAME)"
  fi
done <<<"$FAILED"
[ -z "$NO_MATCH" ] || abort "job(s)$NO_MATCH does not match an infrastructure pattern"
echo "ok: every failed job matches an infrastructure pattern"

# 4. health probe
if [ -n "$HEALTH_URL" ]; then
  if [ $HEALTH_FOLLOW = 1 ]; then
    CODE=$(curl -sS -o /dev/null -w '%{http_code}' -I -L --max-time 20 "$HEALTH_URL" || echo "000")
  else
    CODE=$(curl -sS -o /dev/null -w '%{http_code}' -I --max-time 20 "$HEALTH_URL" || echo "000")
  fi
  [ "$CODE" = "200" ] || abort "health URL answered $CODE (need 200): $HEALTH_URL"
  echo "ok: health URL answers 200"
fi

if [ $WHOLE_RUN = 1 ]; then PLAN="gh run rerun $RUN_ID -R $REPO (whole run)"; else PLAN="gh run rerun $RUN_ID -R $REPO --failed"; fi
echo "plan: $PLAN (current attempt $ATTEMPT, limit $MAX_ATTEMPTS)"
if [ $APPLY = 0 ]; then echo "DRY_RUN_OK"; exit 0; fi

echo "== $(stamp) requesting re-run"
if [ $WHOLE_RUN = 1 ]; then
  gh run rerun "$RUN_ID" -R "$REPO" || guard_fail "gh run rerun refused the request"
else
  gh run rerun "$RUN_ID" -R "$REPO" --failed || guard_fail "gh run rerun --failed refused the request"
fi
DEADLINE=$(( $(date +%s) + WAIT_SECONDS ))
while :; do
  NEW=$(gh api "repos/$REPO/actions/runs/$RUN_ID" --jq '"\(.run_attempt) \(.status) \(.conclusion // "-")"')
  read -r NEW_ATTEMPT NEW_STATUS NEW_CONCL <<<"$NEW"
  if [ "$NEW_ATTEMPT" -gt "$ATTEMPT" ]; then
    echo "ok: run_attempt $ATTEMPT -> $NEW_ATTEMPT status=$NEW_STATUS conclusion=$NEW_CONCL"
    echo "RERUN_DONE $(stamp) run=$RUN_ID attempt=$NEW_ATTEMPT"
    exit 0
  fi
  [ "$(date +%s)" -lt "$DEADLINE" ] || guard_fail "run_attempt still $NEW_ATTEMPT after ${WAIT_SECONDS}s (re-run request may be queued; check the run page)"
  sleep "$POLL_SECONDS"
done
