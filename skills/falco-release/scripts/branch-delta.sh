#!/usr/bin/env bash
# branch-delta.sh - two-dot delta and tree-hash equality between two refs of a GitHub repository.
#
# Purpose:
#   Answer "does the release branch contain exactly the same content as master (or another ref)?"
#   without being misled by the GitHub compare page: a three-dot compare (merge-base based) lists
#   rebased cherry-picks as divergence even when both trees are identical. This script:
#     - resolves both refs to commit and tree SHAs
#     - prints TREES_EQUAL or TREES_DIFFER (tree SHA equality means identical content)
#     - prints the two-dot diff summary (files whose content differs between the two trees)
#     - prints the three-dot compare counters for context, with the warning above
#   Two modes:
#     API mode (default): gh api commits + recursive git trees (+ compare for context), no clone
#     clone mode (--clone-dir): fresh shallow clone (depth 1 of both refs) in the given empty
#     absolute directory, then `git diff --stat <base> <head>` (two-dot)
#   Prints:  OK|ERROR <what> <detail> lines, the diff summary, and the final token
#   TREES_EQUAL or TREES_DIFFER (always the last line).
#
# Usage:
#   branch-delta.sh --repo <owner/repo> --base <ref> --head <ref> [--clone-dir </abs/empty-dir>]
#                   [--remote-url URL] [--max-files N]
#
# Exit codes:
#   0  the two trees are equal (TREES_EQUAL)
#   1  the two trees differ (TREES_DIFFER)
#   2  usage error
#   4  a network or API error prevented the comparison (TREES_UNKNOWN)
#
# Read-only against GitHub (gh api GET, git fetch). Never changes directory: every git call uses `git -C`.
#
# Background: falcosecurity release branches (release/X.Y.x) receive cherry-picks of master commits;
# the GitHub compare page (three-dot) counts those as "ahead/behind" even when the trees match.
#
# Example:
#   branch-delta.sh --repo falcosecurity/falco --base master --head release/0.45.x
set -euo pipefail

# ---- project defaults (overridable by flags) ---------------------------------------------------
DEFAULT_REMOTE_HOST="https://github.com"   # clone URL is <host>/<owner/repo>.git
DEFAULT_MAX_FILES=200

usage() {
  cat <<'EOF'
Usage: branch-delta.sh --repo <owner/repo> --base <ref> --head <ref> [--clone-dir </abs/empty-dir>]
                       [--remote-url URL] [--max-files N]

Compare two refs by tree hash (content identity) and print the two-dot file delta.
  --repo        owner/repo on GitHub
  --base        base ref (branch, tag or commit SHA), e.g. master
  --head        head ref, e.g. release/0.45.x
  --clone-dir   absolute path of a non-existent or empty directory; when given, a fresh shallow clone
                is created there and git computes the delta locally (otherwise the GitHub API is used)
  --remote-url  clone URL (default: https://github.com/<owner/repo>.git)
  --max-files   maximum number of changed paths to print in API mode (default: 200)

Output: OK|ERROR lines, the diff summary, then TREES_EQUAL or TREES_DIFFER as the last line.
Exit codes: 0 trees equal; 1 trees differ; 2 usage; 4 network/API error.
Example: branch-delta.sh --repo falcosecurity/falco --base master --head release/0.45.x
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }

REPO="" BASE="" HEAD_REF="" CLONE_DIR="" REMOTE_URL="" MAX_FILES="$DEFAULT_MAX_FILES"
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --repo) [ $# -ge 2 ] || die_usage "--repo needs a value"; REPO="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || die_usage "--base needs a value"; BASE="$2"; shift 2 ;;
    --head) [ $# -ge 2 ] || die_usage "--head needs a value"; HEAD_REF="$2"; shift 2 ;;
    --clone-dir) [ $# -ge 2 ] || die_usage "--clone-dir needs a value"; CLONE_DIR="$2"; shift 2 ;;
    --remote-url) [ $# -ge 2 ] || die_usage "--remote-url needs a value"; REMOTE_URL="$2"; shift 2 ;;
    --max-files) [ $# -ge 2 ] || die_usage "--max-files needs a value"; MAX_FILES="$2"; shift 2 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done
[ -n "$REPO" ] || die_usage "--repo is required"
case "$REPO" in */*) ;; *) die_usage "--repo must be owner/repo" ;; esac
[ -n "$BASE" ] || die_usage "--base is required"
[ -n "$HEAD_REF" ] || die_usage "--head is required"
case "$MAX_FILES" in ''|*[!0-9]*) die_usage "--max-files must be an integer" ;; esac
if [ -n "$CLONE_DIR" ]; then
  case "$CLONE_DIR" in /*) ;; *) die_usage "--clone-dir must be an absolute path" ;; esac
  if [ -e "$CLONE_DIR" ] && [ -n "$(ls -A "$CLONE_DIR" 2>/dev/null)" ]; then
    die_usage "--clone-dir must not exist or must be empty (a fresh clone is created there)"
  fi
fi
[ -n "$REMOTE_URL" ] || REMOTE_URL="$DEFAULT_REMOTE_HOST/$REPO.git"
for tool in gh jq git; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'error: %s is required\n' "$tool" >&2; exit 2; }
done

printf 'START %s branch-delta repo=%s base=%s head=%s mode=%s\n' "$(date -u +%FT%TZ)" "$REPO" "$BASE" "$HEAD_REF" "$([ -n "$CLONE_DIR" ] && printf clone || printf api)"
printf 'WARNING the GitHub compare page and the compare API are three-dot (merge-base based): rebased cherry-picks show up as ahead/behind commits even when both trees are identical. Trust the tree hashes below, not the commit counters.\n'

TREE_BASE="" TREE_HEAD="" SHA_BASE="" SHA_HEAD=""
finish() { # $1 equal(1) or differ(0)
  printf 'END %s\n' "$(date -u +%FT%TZ)"
  if [ "$1" -eq 1 ]; then printf 'TREES_EQUAL\n'; exit 0; fi
  printf 'TREES_DIFFER\n'; exit 1
}
# network/API failure: the answer is unknown (token TREES_UNKNOWN, exit 4)
api_fail() { printf 'ERROR %s %s\n' "$1" "$2"; printf 'END %s\n' "$(date -u +%FT%TZ)"; printf 'TREES_UNKNOWN\n'; exit 4; }

if [ -n "$CLONE_DIR" ]; then
  # ---- clone mode -------------------------------------------------------------------------------
  mkdir -p "$CLONE_DIR"
  git -C "$CLONE_DIR" init -q
  git -C "$CLONE_DIR" remote add origin "$REMOTE_URL"
  git -C "$CLONE_DIR" fetch -q --depth 1 origin "$BASE:refs/delta/base" 2>"$CLONE_DIR/.fetch-base.err" || api_fail "fetch $BASE" "$(head -c 200 "$CLONE_DIR/.fetch-base.err" | tr '\n' ' ')"
  git -C "$CLONE_DIR" fetch -q --depth 1 origin "$HEAD_REF:refs/delta/head" 2>"$CLONE_DIR/.fetch-head.err" || api_fail "fetch $HEAD_REF" "$(head -c 200 "$CLONE_DIR/.fetch-head.err" | tr '\n' ' ')"
  SHA_BASE=$(git -C "$CLONE_DIR" rev-parse refs/delta/base)
  SHA_HEAD=$(git -C "$CLONE_DIR" rev-parse refs/delta/head)
  TREE_BASE=$(git -C "$CLONE_DIR" rev-parse "refs/delta/base^{tree}")
  TREE_HEAD=$(git -C "$CLONE_DIR" rev-parse "refs/delta/head^{tree}")
  printf 'OK base %s commit=%s tree=%s\n' "$BASE" "$SHA_BASE" "$TREE_BASE"
  printf 'OK head %s commit=%s tree=%s\n' "$HEAD_REF" "$SHA_HEAD" "$TREE_HEAD"
  if [ "$TREE_BASE" = "$TREE_HEAD" ]; then
    printf 'DIFF two-dot %s..%s: 0 files changed (identical trees)\n' "$BASE" "$HEAD_REF"
    finish 1
  fi
  n=$(git -C "$CLONE_DIR" diff --name-only refs/delta/base refs/delta/head | wc -l)
  printf 'DIFF two-dot %s..%s: %s files changed\n' "$BASE" "$HEAD_REF" "$n"
  git -C "$CLONE_DIR" diff --stat=120 refs/delta/base refs/delta/head | sed 's/^/  /'
  finish 0
fi

# ---- API mode -----------------------------------------------------------------------------------
resolve() { # $1 ref -> "commit tree"
  local out
  if out=$(gh api "repos/$REPO/commits/$1" --jq '.sha + " " + .commit.tree.sha' 2>/dev/null); then
    printf '%s' "$out"; return 0
  fi
  local enc; enc=$(printf '%s' "$1" | jq -sRr @uri)
  if out=$(gh api "repos/$REPO/commits/$enc" --jq '.sha + " " + .commit.tree.sha' 2>/dev/null); then
    printf '%s' "$out"; return 0
  fi
  return 1
}
rb=$(resolve "$BASE") || api_fail "resolve $BASE" "not found or API error"
rh=$(resolve "$HEAD_REF") || api_fail "resolve $HEAD_REF" "not found or API error"
SHA_BASE="${rb%% *}"; TREE_BASE="${rb##* }"
SHA_HEAD="${rh%% *}"; TREE_HEAD="${rh##* }"
printf 'OK base %s commit=%s tree=%s\n' "$BASE" "$SHA_BASE" "$TREE_BASE"
printf 'OK head %s commit=%s tree=%s\n' "$HEAD_REF" "$SHA_HEAD" "$TREE_HEAD"

# three-dot counters for context only
if cmp_out=$(gh api "repos/$REPO/compare/$BASE...$HEAD_REF" --jq '"ahead_by=\(.ahead_by) behind_by=\(.behind_by) total_commits=\(.total_commits) files_listed=\(.files|length) merge_base=\(.merge_base_commit.sha)"' 2>/dev/null); then
  printf 'INFO three-dot compare %s...%s %s (context only; rebased cherry-picks inflate these counters)\n' "$BASE" "$HEAD_REF" "$cmp_out"
else
  printf 'INFO three-dot compare %s...%s unavailable\n' "$BASE" "$HEAD_REF"
fi

if [ "$TREE_BASE" = "$TREE_HEAD" ]; then
  printf 'DIFF two-dot %s..%s: 0 files changed (identical trees)\n' "$BASE" "$HEAD_REF"
  finish 1
fi

# two-dot file delta from the recursive trees (blob path+sha symmetric difference)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
gh api "repos/$REPO/git/trees/$TREE_BASE?recursive=1" > "$TMP/base.json" 2>/dev/null || api_fail "tree $TREE_BASE" "trees API failed"
gh api "repos/$REPO/git/trees/$TREE_HEAD?recursive=1" > "$TMP/head.json" 2>/dev/null || api_fail "tree $TREE_HEAD" "trees API failed"
tb=$(jq -r '.truncated' "$TMP/base.json"); th=$(jq -r '.truncated' "$TMP/head.json")
if [ "$tb" = "true" ] || [ "$th" = "true" ]; then
  printf 'ERROR trees recursive listing truncated by the API; use --clone-dir for the file delta\n'
else
  jq -r '.tree[] | select(.type == "blob") | "\(.path)\t\(.sha)"' "$TMP/base.json" | sort > "$TMP/base.tsv"
  jq -r '.tree[] | select(.type == "blob") | "\(.path)\t\(.sha)"' "$TMP/head.json" | sort > "$TMP/head.tsv"
  # comm -3 prints "path<TAB>sha" for lines unique to either side (second-column lines get a leading TAB)
  comm -3 "$TMP/base.tsv" "$TMP/head.tsv" | sed -E 's/^\t//' | cut -f1 | sort -u > "$TMP/paths.txt"
  n=$(wc -l < "$TMP/paths.txt")
  printf 'DIFF two-dot %s..%s: %s files changed\n' "$BASE" "$HEAD_REF" "$n"
  head -n "$MAX_FILES" "$TMP/paths.txt" | sed 's/^/  /'
  if [ "$n" -gt "$MAX_FILES" ]; then printf '  ... (%s more, raise --max-files)\n' "$((n - MAX_FILES))"; fi
fi
finish 0
