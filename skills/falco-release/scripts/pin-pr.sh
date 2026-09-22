#!/usr/bin/env bash
# pin-pr.sh - bump a version pin (and its archive checksum) in a repository and open the PR.
#
# Gated: dry run by default, --apply writes.
#
# Purpose
#   Move a `set(NAME "value")` pin in a CMake module (libs, driver, falcoctl, rules, container
#   plugin, ...) to a new version, recompute the archive checksum from two independent downloads,
#   commit with the maintainer's identity and sign-off, push, open the PR, verify the PR head.
#   File path and variable names are flags so the script survives renames.
#
# Usage
#   pin-pr.sh --repo <owner/repo> --base <branch> --branch <new branch> --clone-dir <abs> --workdir <abs>
#       --file <path in repo> --version-var <NAME> --version <value> [--old-version <value>]
#       [--checksum-var <NAME> --archive-url <url> [--old-checksum <hex>]]...
#       --title-file <abs> --body-file <abs> --commit-message-file <abs>
#       --author-name <name> --author-email <email> [--push-remote <owner/repo>]
#       [--expect-base-sha <sha>] [--clone-url <url>] [--push-url <url>] [--apply]
#   pin-pr.sh --verify-only-checksum --workdir <abs> --archive-url <url>...
#
# Flags
#   --old-version / --old-checksum   select the line to edit when the variable is assigned more than
#                                    once (e.g. a "0.0.0-local" branch, or the amd64/arm64 hash pair);
#                                    --checksum-var, --archive-url and --old-checksum pair positionally
#   --checksum-var                   its current value keeps an existing `SHA256=` prefix
#   --author-name/--author-email     used for author and committer; the commit message file must
#                                    already carry exactly one `Signed-off-by: <name> <email>` trailer
#                                    (the script never adds -s itself) and no other trailer
#   --push-remote                    fork to push to (PR head becomes <forkowner>:<branch>)
#   --expect-base-sha                required with --apply: the base head seen during the dry run
#   --clone-url / --push-url         override the derived https://github.com/<repo>.git URLs (tests)
#
# Dry run: fresh shallow clone of --base (the clone dir must be absent; use a new path for each run),
#   remote branch absent, downloads and checksum agreement, exact-line edits through
#   _replace_line.py, `git diff`, local commit with identity checks, intended PR title and body,
#   DRY_RUN_OK.
# Apply: the same, plus base head == --expect-base-sha, push with the gh credential helper (never
#   force), remote head == local commit, `gh pr create`, PR head == local commit, PR_DONE <url>.
#
# Exit codes
#   0 dry run OK / PR created and verified   2 usage   3 ABORT: precondition or drift
#   4 GUARD_FAIL: post-push or post-create verification failed   5 refused (unused)
#
# Example
#   pin-pr.sh --repo falcosecurity/falco --base master --branch chore/pin-libs-0.26.0 \
#       --clone-dir /abs/work/falco --workdir /abs/work/dl --file cmake/modules/falcosecurity-libs.cmake \
#       --version-var FALCOSECURITY_LIBS_VERSION --version 0.26.0 --old-version 0.26.0-rc2 \
#       --checksum-var FALCOSECURITY_LIBS_CHECKSUM --archive-url https://github.com/falcosecurity/libs/archive/refs/tags/0.26.0.tar.gz \
#       --title-file /abs/pr-title.txt --body-file /abs/pr-body.md --commit-message-file /abs/commit-msg.txt \
#       --author-name "Jane Doe" --author-email jane@example.org
#
# Dry run by default; --apply performs the public action after re-checking every precondition.
#
# Structure assumed (falcosecurity/falco, pinned era 0.44.1 refs, live master identical in shape):
#   cmake/modules/falcosecurity-libs.cmake:45-48  set(FALCOSECURITY_LIBS_VERSION "x") + set(FALCOSECURITY_LIBS_CHECKSUM "SHA256=...")
#   cmake/modules/driver.cmake:38-41               set(DRIVER_VERSION "x+driver") + set(DRIVER_CHECKSUM "SHA256=...")
#   cmake/modules/falcoctl.cmake:23,29,32          set(FALCOCTL_VERSION "x") + set(FALCOCTL_HASH "<hex>") twice (amd64, arm64)
#   cmake/modules/rules.cmake:21-24                set(FALCOSECURITY_RULES_FALCO_VERSION "falco-rules-x") + set(FALCOSECURITY_RULES_FALCO_CHECKSUM "SHA256=...")
#   CMakeLists.txt:297,299,301                     set(CONTAINER_VERSION "x") + set(CONTAINER_HASH "<hex>") twice (x86_64, arm64)
# Sources generalized: output/2026-09-22-falco-release-helper-templates/falco-pin-0.26.0.sh,
#   falco-pin-falcoctl-0.14.2.sh, output/2026-09-08-falco-pin-libs-0.26.0-rc1-finish.sh,
#   output/2026-09-09-falco-pin-libs-0.26.0-final.sh.
set -euo pipefail

usage() { sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
die_usage() { echo "usage error: $*" >&2; usage >&2; exit 2; }
need2() { if [ $# -lt 2 ] || [ -z "$2" ]; then die_usage "$1 needs a value"; fi; }
abort() { echo "ABORT: $*"; exit 3; }
guard_fail() { echo "GUARD_FAIL: $*"; exit 4; }
stamp() { date -u +%FT%TZ; }
need_abs() { case "$2" in /*) ;; *) die_usage "$1 must be an absolute path: $2";; esac; }
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

REPO=""; BASE=""; BRANCH=""; CLONE=""; WORKDIR=""; FILE=""; VVAR=""; VERSION=""; OLD_VERSION=""
TITLE_FILE=""; BODY_FILE=""; MSG_FILE=""; AUTHOR_NAME=""; AUTHOR_EMAIL=""; PUSH_REMOTE=""; EXPECT_BASE=""
CLONE_URL=""; PUSH_URL=""; VERIFY_ONLY=0; APPLY=0
CVARS=(); URLS=(); OLDSUMS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0;;
    --repo) need2 "$@"; REPO=$2; shift 2;;
    --base) need2 "$@"; BASE=$2; shift 2;;
    --branch) need2 "$@"; BRANCH=$2; shift 2;;
    --clone-dir) need2 "$@"; CLONE=$2; shift 2;;
    --workdir) need2 "$@"; WORKDIR=$2; shift 2;;
    --file) need2 "$@"; FILE=$2; shift 2;;
    --version-var) need2 "$@"; VVAR=$2; shift 2;;
    --version) need2 "$@"; VERSION=$2; shift 2;;
    --old-version) need2 "$@"; OLD_VERSION=$2; shift 2;;
    --checksum-var) need2 "$@"; CVARS+=("$2"); shift 2;;
    --archive-url) need2 "$@"; URLS+=("$2"); shift 2;;
    --old-checksum) need2 "$@"; OLDSUMS+=("$2"); shift 2;;
    --title-file) need2 "$@"; TITLE_FILE=$2; shift 2;;
    --body-file) need2 "$@"; BODY_FILE=$2; shift 2;;
    --commit-message-file) need2 "$@"; MSG_FILE=$2; shift 2;;
    --author-name) need2 "$@"; AUTHOR_NAME=$2; shift 2;;
    --author-email) need2 "$@"; AUTHOR_EMAIL=$2; shift 2;;
    --push-remote) need2 "$@"; PUSH_REMOTE=$2; shift 2;;
    --expect-base-sha) need2 "$@"; EXPECT_BASE=$2; shift 2;;
    --clone-url) need2 "$@"; CLONE_URL=$2; shift 2;;
    --push-url) need2 "$@"; PUSH_URL=$2; shift 2;;
    --verify-only-checksum) VERIFY_ONLY=1; shift;;
    --apply) APPLY=1; shift;;
    *) die_usage "unknown flag: $1";;
  esac
done

download_twice() { # <url> <name>; prints the agreed sha256
  local url=$1 name=$2 a b h1 h2
  a="$WORKDIR/$name.1.download"; b="$WORKDIR/$name.2.download"
  curl -fsSL --retry 3 -o "$a" "$url" || abort "download 1 failed: $url"
  curl -fsSL --retry 3 -o "$b" "$url" || abort "download 2 failed: $url"
  sha256sum "$a" > "$a.sha256"
  sha256sum "$b" > "$b.sha256"
  read -r h1 _ < "$a.sha256"
  read -r h2 _ < "$b.sha256"
  [ "$h1" = "$h2" ] || abort "the two downloads of $url differ: $h1 vs $h2"
  [[ "$h1" =~ ^[0-9a-f]{64}$ ]] || abort "not a sha256: $h1"
  printf '%s' "$h1"
}

[ -n "$WORKDIR" ] || die_usage "--workdir is required"
need_abs --workdir "$WORKDIR"
if [ $VERIFY_ONLY = 1 ]; then
  [ ${#URLS[@]} -gt 0 ] || die_usage "--verify-only-checksum needs at least one --archive-url"
  mkdir -p "$WORKDIR"
  for i in "${!URLS[@]}"; do
    SUM=$(download_twice "${URLS[$i]}" "archive-$i")
    echo "CHECKSUM ${URLS[$i]} sha256=$SUM size=$(stat -c %s "$WORKDIR/archive-$i.1.download") (two downloads agree)"
  done
  echo "DRY_RUN_OK"; exit 0
fi

[ -n "$REPO" ] || die_usage "--repo is required"
case "$REPO" in */*) ;; *) die_usage "--repo must be owner/repo";; esac
[ -n "$BASE" ] || die_usage "--base is required"
[ -n "$BRANCH" ] || die_usage "--branch is required"
[ -n "$CLONE" ] || die_usage "--clone-dir is required"; need_abs --clone-dir "$CLONE"
[ ! -e "$CLONE" ] && [ ! -L "$CLONE" ] || abort "clone dir already exists; choose a fresh path (existing work is never removed): $CLONE"
[ -n "$FILE" ] || die_usage "--file is required"
case "$FILE" in /*) die_usage "--file is a path inside the repository, not absolute";; esac
[ -n "$VVAR" ] || die_usage "--version-var is required"
[ -n "$VERSION" ] || die_usage "--version is required"
[ ${#CVARS[@]} -eq ${#URLS[@]} ] || die_usage "--checksum-var and --archive-url must be given in pairs"
[ ${#OLDSUMS[@]} -eq 0 ] || [ ${#OLDSUMS[@]} -eq ${#CVARS[@]} ] || die_usage "--old-checksum must be given once per --checksum-var or not at all"
for f in "$TITLE_FILE" "$BODY_FILE" "$MSG_FILE"; do [ -n "$f" ] || die_usage "--title-file, --body-file and --commit-message-file are required"; done
need_abs --title-file "$TITLE_FILE"; need_abs --body-file "$BODY_FILE"; need_abs --commit-message-file "$MSG_FILE"
for f in "$TITLE_FILE" "$BODY_FILE" "$MSG_FILE"; do [ -f "$f" ] || die_usage "file not found: $f"; done
[ -n "$AUTHOR_NAME" ] && [ -n "$AUTHOR_EMAIL" ] || die_usage "--author-name and --author-email are required"
[ -x "$SCRIPT_DIR/_replace_line.py" ] || die_usage "helper missing: $SCRIPT_DIR/_replace_line.py"
if [ $APPLY = 1 ]; then [[ "$EXPECT_BASE" =~ ^[0-9a-f]{40}$ ]] || die_usage "--apply needs --expect-base-sha <full sha> from the dry run"; fi
[ -n "$CLONE_URL" ] || CLONE_URL="https://github.com/$REPO.git"
PUSH_REPO=${PUSH_REMOTE:-$REPO}
[ -n "$PUSH_URL" ] || PUSH_URL="https://github.com/$PUSH_REPO.git"
if [ "$PUSH_REPO" = "$REPO" ]; then HEADREF=$BRANCH; else HEADREF="${PUSH_REPO%%/*}:$BRANCH"; fi
mkdir -p "$WORKDIR"

echo "== $(stamp) pin-pr $REPO base=$BASE branch=$BRANCH file=$FILE $VVAR -> $VERSION apply=$APPLY"

# 1. commit message / title sanity (before any network call)
TITLE=$(head -n 1 "$TITLE_FILE"); [ -n "$TITLE" ] || abort "title file is empty"
SO="Signed-off-by: $AUTHOR_NAME <$AUTHOR_EMAIL>"
[ "$(grep -c -x -F -- "$SO" "$MSG_FILE" || true)" = 1 ] || abort "commit message must carry exactly one '$SO' line"
[ "$(grep -c '^Signed-off-by:' "$MSG_FILE" || true)" = 1 ] || abort "commit message has more than one Signed-off-by trailer"
[ "$(grep -c -i -E '^Co-authored-by:' "$MSG_FILE" || true)" = 0 ] || abort "commit message carries a Co-authored-by trailer; the pin commit is the maintainer's own"
echo "ok: title '$TITLE'; commit message signed off by $AUTHOR_NAME <$AUTHOR_EMAIL>"

# 2. remote branch must not exist
if gh api "repos/$PUSH_REPO/git/ref/heads/$BRANCH" --jq .object.sha >/dev/null 2>&1; then abort "branch $BRANCH already exists on $PUSH_REPO"; fi
echo "ok: branch $BRANCH absent on $PUSH_REPO"

# 3. fresh shallow clone of the base
[ ! -e "$CLONE" ] && [ ! -L "$CLONE" ] || abort "clone dir appeared during preflight: $CLONE"
git clone -q --depth 1 --branch "$BASE" "$CLONE_URL" "$CLONE" || abort "clone of $CLONE_URL@$BASE failed"
BASE_SHA=$(git -C "$CLONE" rev-parse HEAD)
API_BASE=$(gh api "repos/$REPO/commits/$BASE" --jq .sha) || abort "cannot read $BASE head through the API"
[ "$API_BASE" = "$BASE_SHA" ] || abort "clone head $BASE_SHA differs from API head $API_BASE of $BASE (race), re-run"
[ -z "$EXPECT_BASE" ] || [ "$EXPECT_BASE" = "$BASE_SHA" ] || abort "$BASE moved: $BASE_SHA, expected $EXPECT_BASE (re-run the dry run)"
[ -f "$CLONE/$FILE" ] || abort "$FILE not found in the clone"
echo "ok: $BASE at $BASE_SHA (pass --expect-base-sha $BASE_SHA to --apply)"

# 4. checksums from two downloads each
SUMS=()
for i in "${!URLS[@]}"; do
  SUM=$(download_twice "${URLS[$i]}" "archive-$i")
  SUMS+=("$SUM")
  echo "ok: ${CVARS[$i]} <- sha256 $SUM (${URLS[$i]}, two downloads agree)"
done

# 5. exact-line edits
if [ -n "$OLD_VERSION" ]; then
  python3 "$SCRIPT_DIR/_replace_line.py" set-var --file "$CLONE/$FILE" --var "$VVAR" --new "$VERSION" --old "$OLD_VERSION" || abort "version edit failed"
else
  python3 "$SCRIPT_DIR/_replace_line.py" set-var --file "$CLONE/$FILE" --var "$VVAR" --new "$VERSION" || abort "version edit failed"
fi
for i in "${!CVARS[@]}"; do
  if [ ${#OLDSUMS[@]} -gt 0 ]; then
    python3 "$SCRIPT_DIR/_replace_line.py" set-var --file "$CLONE/$FILE" --var "${CVARS[$i]}" --new "${SUMS[$i]}" --old "${OLDSUMS[$i]}" --keep-prefix || abort "checksum edit failed for ${CVARS[$i]}"
  else
    python3 "$SCRIPT_DIR/_replace_line.py" set-var --file "$CLONE/$FILE" --var "${CVARS[$i]}" --new "${SUMS[$i]}" --keep-prefix || abort "checksum edit failed for ${CVARS[$i]}"
  fi
done
EXPECTED=$((1 + ${#CVARS[@]}))
NUMSTAT=$(git -C "$CLONE" diff --numstat)
[ "$(printf '%s\n' "$NUMSTAT" | grep -c . || true)" = 1 ] || abort "expected exactly one changed file, numstat: $NUMSTAT"
read -r ADDED DELETED CHANGED_FILE <<<"$NUMSTAT"
[ "$CHANGED_FILE" = "$FILE" ] || abort "changed file is $CHANGED_FILE, expected $FILE"
[ "$ADDED" = "$EXPECTED" ] && [ "$DELETED" = "$EXPECTED" ] || abort "expected +$EXPECTED/-$EXPECTED changed lines, got +$ADDED/-$DELETED"
git -C "$CLONE" diff --check -- "$FILE" || abort "whitespace problems in the edit"
echo "-- diff"; git -C "$CLONE" --no-pager diff -- "$FILE"
echo "ok: exactly $EXPECTED line(s) replaced in $FILE"

# 6. local commit with the maintainer's identity
git -C "$CLONE" checkout -q -b "$BRANCH"
git -C "$CLONE" add -- "$FILE"
git -C "$CLONE" -c user.name="$AUTHOR_NAME" -c user.email="$AUTHOR_EMAIL" commit -q -F "$MSG_FILE" || abort "commit failed"
NEW_SHA=$(git -C "$CLONE" rev-parse HEAD)
IDENT=$(git -C "$CLONE" log -1 --format='%an <%ae>|%cn <%ce>')
[ "$IDENT" = "$AUTHOR_NAME <$AUTHOR_EMAIL>|$AUTHOR_NAME <$AUTHOR_EMAIL>" ] || abort "author/committer mismatch: $IDENT"
[ "$(git -C "$CLONE" log -1 --format='%(trailers:key=Signed-off-by,valueonly)' | grep -c . || true)" = 1 ] || abort "sign-off count in the commit is not 1"
echo "ok: commit $NEW_SHA on $BRANCH: $(git -C "$CLONE" log -1 --format=%s)"

echo "-- intended PR: $REPO base=$BASE head=$HEADREF"
echo "   title: $TITLE"
echo "-- body ($BODY_FILE):"; sed 's/^/   | /' "$BODY_FILE"
if [ $APPLY = 0 ]; then echo "DRY_RUN_OK"; exit 0; fi

# 7. push (plain, never force) and verify
echo "== $(stamp) pushing $BRANCH to $PUSH_URL"
git -C "$CLONE" remote add push-target "$PUSH_URL"
git -C "$CLONE" -c credential.helper= -c credential.helper='!gh auth git-credential' push -q push-target "HEAD:refs/heads/$BRANCH" || guard_fail "push failed"
REMOTE=$(gh api "repos/$PUSH_REPO/git/ref/heads/$BRANCH" --jq .object.sha) || guard_fail "pushed branch not readable"
[ "$REMOTE" = "$NEW_SHA" ] || guard_fail "remote $BRANCH head $REMOTE differs from local $NEW_SHA"
echo "ok: remote $BRANCH == $NEW_SHA"

# 8. PR
URL=$(gh pr create -R "$REPO" --base "$BASE" --head "$HEADREF" --title "$TITLE" --body-file "$BODY_FILE") || guard_fail "gh pr create failed (branch is pushed: $BRANCH)"
PR_HEAD=$(gh pr view "$URL" -R "$REPO" --json headRefOid --jq .headRefOid) || guard_fail "cannot read the new PR"
[ "$PR_HEAD" = "$NEW_SHA" ] || guard_fail "PR head $PR_HEAD differs from local $NEW_SHA"
echo "PR_DONE $URL"
