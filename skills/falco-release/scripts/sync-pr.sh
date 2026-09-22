#!/usr/bin/env bash
# sync-pr.sh - cumulative cherry-pick sync PR onto a release branch.
#
# Gated: dry run by default, --apply writes.
#
# Purpose
#   Between the last candidate and the final release, fixes reach the release branch through ONE
#   cumulative sync PR: merged source-branch PRs are cherry-picked in order onto a sync branch,
#   keeping the original author and sign-off (only the committer changes, no -x), every pick is
#   checked against its source with `git patch-id`, and the result is pushed as a new PR or
#   appended to the open cumulative PR (plain push, never force).
#
# Usage
#   sync-pr.sh --repo <owner/repo> --release-branch <name> [--source-branch <name>] --branch <sync branch>
#       --clone-dir <abs> [--workdir <abs>] --pr <n>... [--existing-pr <n>]
#       [--title-file <abs>] [--body-file <abs>] --committer-name <name> --committer-email <email>
#       [--changelog-path <path>] [--expect-release-sha <sha>] [--clone-url <url>] [--push-url <url>] [--apply]
#
# Pick resolution per --pr (through `gh api repos/<r>/pulls/<n>`; the PR must be merged into the
# source branch): a merge commit is picked with -m 1; a single-commit PR picks merge_commit_sha; a
# multi-commit PR is a rebase merge when the patch-ids of the last N source-branch commits equal the
# PR commits' patch-ids (those N commits are picked in order), otherwise a squash (merge_commit_sha).
# A pick that turns out empty (already on the branch) is skipped and reported as EMPTY_PICK.
#
# Changelog rule (--changelog-path): when a pick conflicts on that path only, the lines the commit
# added go under the release branch's own `## Unreleased` section (_resolve_changelog.py); the
# patch-id check for that pick then excludes the changelog path (RESOLVED_CHANGELOG).
#
# Dry run: clone into an absent directory (use a new path for each run), resolve picks, pick locally,
#   verify author/sign-off/committer/patch-id, print the
#   tree hash and whether it equals the source branch tree, print the plan, DRY_RUN_OK.
# Apply: the same, plus release head == --expect-release-sha when given, push, remote head == local,
#   `gh pr create --title --body-file` or `gh pr edit <existing> --body-file`, PR head == local,
#   SYNC_PR_DONE <url>.
#
# Exit codes
#   0 dry run OK / PR created or updated and verified   2 usage   3 ABORT: precondition, conflict,
#   patch-id mismatch, drift   4 GUARD_FAIL: post-push or post-create verification failed   5 refused (unused)
#
# Example
#   sync-pr.sh --repo falcosecurity/falco --release-branch release/0.45.x --branch cherry-pick/release-0.45.x-rc3 \
#       --clone-dir /abs/work/falco-sync --pr 3990 --pr 3994 --changelog-path chart/falco/CHANGELOG.md \
#       --title-file /abs/title.txt --body-file /abs/body.md --committer-name "Jane Doe" --committer-email jane@example.org
#
# Dry run by default; --apply performs the public action after re-checking every precondition.
#
# Sources generalized: output/2026-09-22-falco-release-helper-templates/falco-pick-3990-3994.sh,
#   resolve-changelog-3990.py, falco-sync-rc3.sh, falco-sync-push-pr.sh; rule "one cumulative sync
#   PR" from output/2026-09-03-release-prep-process-notes.md section 6b.
set -euo pipefail

usage() { sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
die_usage() { echo "usage error: $*" >&2; usage >&2; exit 2; }
need2() { if [ $# -lt 2 ] || [ -z "$2" ]; then die_usage "$1 needs a value"; fi; }
abort() { echo "ABORT: $*"; exit 3; }
guard_fail() { echo "GUARD_FAIL: $*"; exit 4; }
stamp() { date -u +%FT%TZ; }
need_abs() { case "$2" in /*) ;; *) die_usage "$1 must be an absolute path: $2";; esac; }
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

REPO=""; RELEASE=""; SOURCE="master"; BRANCH=""; CLONE=""; WORKDIR=""; EXISTING=""; TITLE_FILE=""; BODY_FILE=""
CN=""; CE=""; CHANGELOG=""; EXPECT_RELEASE=""; CLONE_URL=""; PUSH_URL=""; APPLY=0
PRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0;;
    --repo) need2 "$@"; REPO=$2; shift 2;;
    --release-branch) need2 "$@"; RELEASE=$2; shift 2;;
    --source-branch) need2 "$@"; SOURCE=$2; shift 2;;
    --branch) need2 "$@"; BRANCH=$2; shift 2;;
    --clone-dir) need2 "$@"; CLONE=$2; shift 2;;
    --workdir) need2 "$@"; WORKDIR=$2; shift 2;;
    --pr) need2 "$@"; PRS+=("$2"); shift 2;;
    --existing-pr) need2 "$@"; EXISTING=$2; shift 2;;
    --title-file) need2 "$@"; TITLE_FILE=$2; shift 2;;
    --body-file) need2 "$@"; BODY_FILE=$2; shift 2;;
    --committer-name|--author-name) need2 "$@"; CN=$2; shift 2;;
    --committer-email|--author-email) need2 "$@"; CE=$2; shift 2;;
    --changelog-path) need2 "$@"; CHANGELOG=$2; shift 2;;
    --expect-release-sha) need2 "$@"; EXPECT_RELEASE=$2; shift 2;;
    --clone-url) need2 "$@"; CLONE_URL=$2; shift 2;;
    --push-url) need2 "$@"; PUSH_URL=$2; shift 2;;
    --apply) APPLY=1; shift;;
    *) die_usage "unknown flag: $1";;
  esac
done
[ -n "$REPO" ] || die_usage "--repo is required"
case "$REPO" in */*) ;; *) die_usage "--repo must be owner/repo";; esac
[ -n "$RELEASE" ] || die_usage "--release-branch is required"
[ -n "$CLONE" ] || die_usage "--clone-dir is required"; need_abs --clone-dir "$CLONE"
[ ! -e "$CLONE" ] && [ ! -L "$CLONE" ] || abort "clone dir already exists; choose a fresh path (existing work is never removed): $CLONE"
[ -n "$WORKDIR" ] || WORKDIR="$CLONE-work"; need_abs --workdir "$WORKDIR"
[ ${#PRS[@]} -gt 0 ] || die_usage "at least one --pr is required"
for n in "${PRS[@]}"; do [[ "$n" =~ ^[0-9]+$ ]] || die_usage "--pr must be numeric: $n"; done
[ -z "$EXISTING" ] || [[ "$EXISTING" =~ ^[0-9]+$ ]] || die_usage "--existing-pr must be numeric"
[ -n "$CN" ] && [ -n "$CE" ] || die_usage "--committer-name and --committer-email are required"
if [ -z "$EXISTING" ]; then
  [ -n "$BRANCH" ] || die_usage "--branch is required (or --existing-pr)"
  [ -n "$TITLE_FILE" ] && [ -n "$BODY_FILE" ] || die_usage "--title-file and --body-file are required for a new PR"
fi
[ -z "$TITLE_FILE" ] || { need_abs --title-file "$TITLE_FILE"; [ -f "$TITLE_FILE" ] || die_usage "file not found: $TITLE_FILE"; }
[ -z "$BODY_FILE" ] || { need_abs --body-file "$BODY_FILE"; [ -f "$BODY_FILE" ] || die_usage "file not found: $BODY_FILE"; }
case "$CHANGELOG" in /*) die_usage "--changelog-path is a path inside the repository, not absolute";; esac
if [ -n "$CHANGELOG" ]; then [ -x "$SCRIPT_DIR/_resolve_changelog.py" ] || die_usage "helper missing: $SCRIPT_DIR/_resolve_changelog.py"; fi
[ -z "$EXPECT_RELEASE" ] || [[ "$EXPECT_RELEASE" =~ ^[0-9a-f]{40}$ ]] || die_usage "--expect-release-sha must be a full sha"
[ -n "$CLONE_URL" ] || CLONE_URL="https://github.com/$REPO.git"
[ -n "$PUSH_URL" ] || PUSH_URL="$CLONE_URL"
mkdir -p "$WORKDIR"

G() { git -C "$CLONE" -c user.name="$CN" -c user.email="$CE" "$@"; }
patch_id() { # <commit> [pathspec...]; empty output for an empty diff
  local c=$1; shift
  git -C "$CLONE" diff-tree -p "$c^1" "$c" -- "$@" | git -C "$CLONE" patch-id --stable | cut -d' ' -f1
}

echo "== $(stamp) sync-pr $REPO $SOURCE -> $RELEASE branch=${BRANCH:-(existing #$EXISTING)} prs=${PRS[*]} apply=$APPLY"

# 1. clone (fresh) with the release and source branches
[ ! -e "$CLONE" ] && [ ! -L "$CLONE" ] || abort "clone dir appeared during preflight: $CLONE"
git clone -q --filter=blob:none --branch "$RELEASE" "$CLONE_URL" "$CLONE" 2>"$WORKDIR/clone.err" || abort "clone failed: $(head -c 300 "$WORKDIR/clone.err")"
git -C "$CLONE" fetch -q origin "+refs/heads/$SOURCE:refs/remotes/origin/$SOURCE" "+refs/heads/$RELEASE:refs/remotes/origin/$RELEASE" || abort "fetch failed"
RELEASE_SHA=$(git -C "$CLONE" rev-parse "origin/$RELEASE")
API_RELEASE=$(gh api "repos/$REPO/commits/$RELEASE" --jq .sha) || abort "cannot read $RELEASE through the API"
[ "$API_RELEASE" = "$RELEASE_SHA" ] || abort "clone $RELEASE=$RELEASE_SHA differs from API $API_RELEASE (race), re-run"
[ -z "$EXPECT_RELEASE" ] || [ "$EXPECT_RELEASE" = "$RELEASE_SHA" ] || abort "$RELEASE moved: $RELEASE_SHA, expected $EXPECT_RELEASE (re-run the dry run)"
SOURCE_SHA=$(git -C "$CLONE" rev-parse "origin/$SOURCE")
echo "ok: $RELEASE at $RELEASE_SHA, $SOURCE at $SOURCE_SHA (pass --expect-release-sha $RELEASE_SHA to --apply)"

# 2. sync branch: new or the open cumulative PR's branch
if [ -n "$EXISTING" ]; then
  EINFO=$(gh api "repos/$REPO/pulls/$EXISTING" --jq '"\(.state) \(.head.ref) \(.head.sha) \(.base.ref) \(.head.repo.full_name) \(.html_url)"') || abort "cannot read PR #$EXISTING"
  read -r ESTATE EREF ESHA EBASE EREPO EURL <<<"$EINFO"
  [ "$ESTATE" = open ] || abort "PR #$EXISTING is $ESTATE"
  [ "$EBASE" = "$RELEASE" ] || abort "PR #$EXISTING targets $EBASE, not $RELEASE"
  [ "$EREPO" = "$REPO" ] || abort "PR #$EXISTING head lives in $EREPO (fork), appending is only supported for in-repo branches"
  [ -z "$BRANCH" ] || [ "$BRANCH" = "$EREF" ] || abort "--branch $BRANCH differs from PR #$EXISTING head branch $EREF"
  BRANCH=$EREF
  git -C "$CLONE" fetch -q origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" || abort "cannot fetch $BRANCH"
  G checkout -q -B "$BRANCH" "origin/$BRANCH"
  [ "$(git -C "$CLONE" rev-parse HEAD)" = "$ESHA" ] || abort "fetched $BRANCH head differs from PR #$EXISTING head $ESHA"
  git -C "$CLONE" merge-base --is-ancestor "$RELEASE_SHA" HEAD || abort "PR #$EXISTING branch is not on top of the current $RELEASE head (rebase it by hand first)"
  echo "ok: appending to open PR #$EXISTING ($BRANCH at $ESHA)"
else
  if gh api "repos/$REPO/git/ref/heads/$BRANCH" --jq .object.sha >/dev/null 2>&1; then abort "branch $BRANCH already exists on $REPO (use --existing-pr to append)"; fi
  G checkout -q -B "$BRANCH" "origin/$RELEASE"
  echo "ok: new sync branch $BRANCH from $RELEASE"
fi
START_SHA=$(git -C "$CLONE" rev-parse HEAD)

# 3. resolve the picks
PICK_SHAS=(); PICK_MAINLINE=(); PICK_PR=(); PICK_KIND=()
for N in "${PRS[@]}"; do
  INFO=$(gh api "repos/$REPO/pulls/$N" --jq '"\(.merged) \(.merge_commit_sha // "-") \(.commits) \(.base.ref) \(.title)"') || abort "cannot read PR #$N"
  read -r MERGED MSHA NCOMMITS BASEREF PTITLE <<<"$INFO"
  [ "$MERGED" = true ] || abort "PR #$N is not merged"
  [ "$BASEREF" = "$SOURCE" ] || abort "PR #$N was merged into $BASEREF, not $SOURCE"
  git -C "$CLONE" cat-file -e "$MSHA^{commit}" 2>/dev/null || abort "merge commit $MSHA of PR #$N is not in the clone"
  git -C "$CLONE" merge-base --is-ancestor "$MSHA" "origin/$SOURCE" || abort "merge commit $MSHA of PR #$N is not reachable from $SOURCE"
  NPARENTS=$(( $(git -C "$CLONE" rev-list --parents -n 1 "$MSHA" | wc -w) - 1 ))
  KIND=""; SHAS=""
  if [ "$NPARENTS" -ge 2 ]; then
    KIND=merge; SHAS=$MSHA
  elif [ "$NCOMMITS" = 1 ]; then
    KIND=single; SHAS=$MSHA
  else
    PRC=$(gh api --paginate "repos/$REPO/pulls/$N/commits" --jq '.[].sha')
    git -C "$CLONE" fetch -q origin "+refs/pull/$N/head:refs/remotes/origin/pr-$N" 2>/dev/null || true
    CAND=$(git -C "$CLONE" rev-list --reverse "$MSHA~$NCOMMITS..$MSHA" 2>/dev/null || true)
    KIND=squash
    if [ "$(printf '%s\n' "$CAND" | grep -c . || true)" = "$NCOMMITS" ]; then
      KIND=rebase
      paste -d' ' <(printf '%s\n' "$CAND") <(printf '%s\n' "$PRC") > "$WORKDIR/pr-$N-pairs.txt"
      while read -r C P; do
        [ -n "$C" ] && [ -n "$P" ] || { KIND=squash; break; }
        git -C "$CLONE" cat-file -e "$P^{commit}" 2>/dev/null || { KIND=squash; break; }
        [ "$(patch_id "$C")" = "$(patch_id "$P")" ] || { KIND=squash; break; }
      done < "$WORKDIR/pr-$N-pairs.txt"
    fi
    if [ $KIND = rebase ]; then SHAS=$CAND; else SHAS=$MSHA; fi
  fi
  for S in $SHAS; do
    PICK_SHAS+=("$S"); PICK_PR+=("$N"); PICK_KIND+=("$KIND")
    if [ $KIND = merge ]; then PICK_MAINLINE+=("-m 1"); else PICK_MAINLINE+=(""); fi
  done
  echo "plan: PR #$N ($KIND, $NCOMMITS commit(s)) -> pick $(printf '%s ' $SHAS)| ${PTITLE:0:70}"
done

# 4. pick, one commit at a time
RESULT_SRC=(); RESULT_DST=(); RESULT_STATUS=()
for i in "${!PICK_SHAS[@]}"; do
  S=${PICK_SHAS[$i]}; ML=${PICK_MAINLINE[$i]}; LOG="$WORKDIR/pick-$S.log"
  STATUS=""
  # shellcheck disable=SC2086
  if G cherry-pick $ML "$S" >"$LOG" 2>&1; then
    STATUS=PICKED
  else
    CONF=$(git -C "$CLONE" diff --name-only --diff-filter=U)
    if [ -z "$CONF" ] && git -C "$CLONE" diff --cached --quiet && git -C "$CLONE" diff --quiet; then
      G cherry-pick --skip >/dev/null 2>&1 || G cherry-pick --quit >/dev/null 2>&1 || true
      STATUS=EMPTY_PICK
    elif [ -n "$CHANGELOG" ] && [ "$CONF" = "$CHANGELOG" ]; then
      git -C "$CLONE" show "HEAD:$CHANGELOG" > "$WORKDIR/changelog-base-$S.md"
      git -C "$CLONE" show "$S:$CHANGELOG" > "$WORKDIR/changelog-source-$S.md"
      git -C "$CLONE" show "$S^1:$CHANGELOG" > "$WORKDIR/changelog-parent-$S.md"
      python3 "$SCRIPT_DIR/_resolve_changelog.py" --base "$WORKDIR/changelog-base-$S.md" --source "$WORKDIR/changelog-source-$S.md" \
        --parent "$WORKDIR/changelog-parent-$S.md" --out "$CLONE/$CHANGELOG" || { G cherry-pick --abort >/dev/null 2>&1 || true; abort "changelog resolution failed for $S"; }
      git -C "$CLONE" add -- "$CHANGELOG"
      G -c core.editor=true cherry-pick --continue >/dev/null 2>&1 || { G cherry-pick --abort >/dev/null 2>&1 || true; abort "cherry-pick --continue failed for $S"; }
      STATUS=RESOLVED_CHANGELOG
    else
      G cherry-pick --abort >/dev/null 2>&1 || true
      abort "conflict picking $S (PR #${PICK_PR[$i]}) on: ${CONF:-$(head -c 300 "$LOG")}"
    fi
  fi
  DST=$(git -C "$CLONE" rev-parse HEAD)
  [ "$STATUS" = EMPTY_PICK ] && DST="-"
  RESULT_SRC+=("$S"); RESULT_DST+=("$DST"); RESULT_STATUS+=("$STATUS")
  echo "$STATUS $S -> $DST (PR #${PICK_PR[$i]}, ${PICK_KIND[$i]})"
done

# 5. verify every picked commit against its source
for i in "${!RESULT_SRC[@]}"; do
  S=${RESULT_SRC[$i]}; D=${RESULT_DST[$i]}; ST=${RESULT_STATUS[$i]}
  [ "$D" != "-" ] || continue
  SA=$(git -C "$CLONE" log -1 --format='%an <%ae>' "$S"); DA=$(git -C "$CLONE" log -1 --format='%an <%ae>' "$D")
  [ "$SA" = "$DA" ] || abort "author changed on $D: '$SA' -> '$DA'"
  SSO=$(git -C "$CLONE" log -1 --format='%(trailers:key=Signed-off-by,valueonly)' "$S"); DSO=$(git -C "$CLONE" log -1 --format='%(trailers:key=Signed-off-by,valueonly)' "$D")
  [ "$SSO" = "$DSO" ] || abort "sign-off changed on $D"
  [ "$(git -C "$CLONE" log -1 --format='%cn <%ce>' "$D")" = "$CN <$CE>" ] || abort "committer on $D is not $CN <$CE>"
  git -C "$CLONE" log -1 --format=%B "$D" | grep -q -i 'cherry picked from' && abort "-x trailer found on $D"
  if [ "$ST" = RESOLVED_CHANGELOG ]; then
    [ "$(patch_id "$S" . ":(exclude)$CHANGELOG")" = "$(patch_id "$D" . ":(exclude)$CHANGELOG")" ] || abort "patch-id mismatch (excluding $CHANGELOG) for $S -> $D"
    echo "ok: $D patch-id == source excluding $CHANGELOG; author, sign-off and committer verified"
  else
    [ "$(patch_id "$S")" = "$(patch_id "$D")" ] || abort "patch-id mismatch for $S -> $D"
    echo "ok: $D patch-id == source; author, sign-off and committer verified"
  fi
done

NEW_COUNT=$(git -C "$CLONE" rev-list --count "$START_SHA..HEAD")
HEAD_SHA=$(git -C "$CLONE" rev-parse HEAD)
TREE=$(git -C "$CLONE" rev-parse 'HEAD^{tree}'); STREE=$(git -C "$CLONE" rev-parse "origin/$SOURCE^{tree}")
if [ "$TREE" = "$STREE" ]; then EQ=yes; else EQ=no; fi
echo "-- result: $NEW_COUNT new commit(s) on $BRANCH, head $HEAD_SHA"
git -C "$CLONE" --no-pager log --format='   %h %an | %s' "$RELEASE_SHA..HEAD" || true
echo "TREE $TREE equals_source_tree=$EQ"
echo "-- diff --stat $RELEASE..HEAD"; git -C "$CLONE" --no-pager diff --stat "$RELEASE_SHA" HEAD | tail -n 15
if [ "$NEW_COUNT" = 0 ]; then echo "NOTHING_TO_PUSH: every pick is already on $BRANCH"; fi
if [ $APPLY = 0 ]; then echo "DRY_RUN_OK"; exit 0; fi
[ "$NEW_COUNT" != 0 ] || abort "nothing to push"

# 6. push (plain) and verify
echo "== $(stamp) pushing $BRANCH to $PUSH_URL"
git -C "$CLONE" remote add push-target "$PUSH_URL"
git -C "$CLONE" -c credential.helper= -c credential.helper='!gh auth git-credential' push -q push-target "HEAD:refs/heads/$BRANCH" || guard_fail "push failed"
REMOTE=$(gh api "repos/$REPO/git/ref/heads/$BRANCH" --jq .object.sha) || guard_fail "pushed branch not readable"
[ "$REMOTE" = "$HEAD_SHA" ] || guard_fail "remote $BRANCH head $REMOTE differs from local $HEAD_SHA"
echo "ok: remote $BRANCH == $HEAD_SHA"

# 7. PR create or update
if [ -n "$EXISTING" ]; then
  if [ -n "$BODY_FILE" ]; then gh pr edit "$EXISTING" -R "$REPO" --body-file "$BODY_FILE" >/dev/null || guard_fail "gh pr edit failed"; fi
  URL=$EURL
else
  TITLE=$(head -n 1 "$TITLE_FILE"); [ -n "$TITLE" ] || guard_fail "title file is empty (branch is pushed: $BRANCH)"
  URL=$(gh pr create -R "$REPO" --base "$RELEASE" --head "$BRANCH" --title "$TITLE" --body-file "$BODY_FILE") || guard_fail "gh pr create failed (branch is pushed: $BRANCH)"
fi
PR_HEAD=$(gh pr view "$URL" -R "$REPO" --json headRefOid --jq .headRefOid) || guard_fail "cannot read the PR"
[ "$PR_HEAD" = "$HEAD_SHA" ] || guard_fail "PR head $PR_HEAD differs from local $HEAD_SHA"
echo "SYNC_PR_DONE $URL"
