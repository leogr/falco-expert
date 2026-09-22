#!/usr/bin/env bash
# release-body-build.sh - build a GitHub release body locally the same way the release workflows do.
#
# Not gated: this script performs no public action. Editing the release body is the maintainer's
# step; the script prints the `gh release edit` command and never runs it.
#
# Purpose
#   The falcosecurity release workflows generate the release body with leodido/rn2md from the
#   milestone's merged PRs, then append `#### Release Manager @<login>`. When that step fails
#   (broken pin, token format, expired artifact) the body can be built here with the same tool at
#   the same pinned commit, then applied by hand.
#
# Usage
#   release-body-build.sh --repo <owner/repo> --milestone <title> --tool-dir <abs> --out <abs>
#       [--tool-repo <owner/repo>] [--tool-ref <sha or tag>] [--branch <name>] [--tag <tag>]
#       [--prefix-file <abs>] [--falco-source-dir <abs>] [--release-manager <login>]
#
# Flags
#   --tool-repo / --tool-ref   rn2md source and revision; defaults are the values pinned by the
#                              workflows (see "Pinned defaults" below); pass a fork revision when the
#                              pinned build rejects the token (it validates `len=40`)
#   --branch                   rn2md `-b` (PR base filter); default: the repository's default branch,
#                              like the action's `github.event.repository.default_branch`
#   --tag                      release tag for the printed command and for the falco template
#                              substitutions; default: --milestone
#   --prefix-file              text placed before the notes (libs: the two badge lines and a blank
#                              line; see release-body.yml:86-103 and :148-176)
#   --falco-source-dir         checkout of falcosecurity/falco at the tag: derive the prefix from
#                              .github/release_template.md with the LIBSVER/DRIVERVER/FALCOBUCKET/FALCOVER
#                              substitutions of release.yaml:152-163
#   --release-manager          login for the trailer; default: `gh api user --jq .login`
#
# Token: read inside the script with `gh auth token` into a variable and handed to the tool through
#   the RN2MD_TOKEN environment variable of that single child process (the _rn2md_envshim.go build
#   appends it to the in-process argument slice); it is never printed and never on a command line.
#
# Exit codes: 0 body built (last line BODY_BUILT <out>)   2 usage   3 ABORT: tool checkout/build or
#   rn2md failed   (no 4/5: nothing public is written)
#
# Example
#   release-body-build.sh --repo falcosecurity/libs --milestone 0.26.0 --tool-dir /abs/work/rn2md \
#       --prefix-file /abs/work/libs-badges.md --out /abs/output/body-0.26.0.md
#   then, by hand:  gh release edit 0.26.0 -R falcosecurity/libs --notes-file /abs/output/body-0.26.0.md
#
# Pinned defaults (era 0.44.1 refs; the live upstream master of rn2md is the same commit):
#   refs/falcosecurity/libs/.github/workflows/release-body.yml:106   uses: leodido/rn2md@9c351d81278644c0e17b1ca68edbdba305276c73
#   refs/falcosecurity/libs/.github/workflows/release-body.yml:211   uses: leodido/rn2md@9c351d81278644c0e17b1ca68edbdba305276c73 # main
#   refs/falcosecurity/falco/.github/workflows/release.yaml:166      uses: leodido/rn2md@9c351d81278644c0e17b1ca68edbdba305276c73
#   Body assembly mirrored: libs release-body.yml:105-117 (notes, blank line, Release Manager),
#   falco release.yaml:152-177 (template substitutions, notes, blank line, Release Manager).
#   rn2md action.yml runs `./rn2md -b <branch> -r <repo> -m <milestone> -t <token>`.
# Sources generalized: output/2026-09-22-falco-release-helper-templates/build-bodies.sh and
#   output/2026-09-14-libs-release-bodies/.
set -euo pipefail

usage() { sed -n '2,/^set -euo pipefail/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; echo "Dry run by default; --apply performs the public action after re-checking every precondition. (This script has no --apply: it only builds a file.)"; }
die_usage() { echo "usage error: $*" >&2; usage >&2; exit 2; }
need2() { if [ $# -lt 2 ] || [ -z "$2" ]; then die_usage "$1 needs a value"; fi; }
abort() { echo "ABORT: $*"; exit 3; }
stamp() { date -u +%FT%TZ; }
need_abs() { case "$2" in /*) ;; *) die_usage "$1 must be an absolute path: $2";; esac; }
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

REPO=""; MILESTONE=""; TOOL_DIR=""; OUT=""; TOOL_REPO="leodido/rn2md"; TOOL_REF="9c351d81278644c0e17b1ca68edbdba305276c73"
BRANCH=""; TAG=""; PREFIX_FILE=""; FALCO_SRC=""; RM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0;;
    --repo) need2 "$@"; REPO=$2; shift 2;;
    --milestone) need2 "$@"; MILESTONE=$2; shift 2;;
    --tool-dir) need2 "$@"; TOOL_DIR=$2; shift 2;;
    --out) need2 "$@"; OUT=$2; shift 2;;
    --tool-repo) need2 "$@"; TOOL_REPO=$2; shift 2;;
    --tool-ref) need2 "$@"; TOOL_REF=$2; shift 2;;
    --branch) need2 "$@"; BRANCH=$2; shift 2;;
    --tag) need2 "$@"; TAG=$2; shift 2;;
    --prefix-file) need2 "$@"; PREFIX_FILE=$2; shift 2;;
    --falco-source-dir) need2 "$@"; FALCO_SRC=$2; shift 2;;
    --release-manager) need2 "$@"; RM=$2; shift 2;;
    --apply) die_usage "this script has no --apply; apply the body by hand with the printed gh release edit command";;
    *) die_usage "unknown flag: $1";;
  esac
done
[ -n "$REPO" ] || die_usage "--repo is required"
case "$REPO" in */*) ;; *) die_usage "--repo must be owner/repo";; esac
case "$TOOL_REPO" in */*) ;; *) die_usage "--tool-repo must be owner/repo";; esac
[ -n "$MILESTONE" ] || die_usage "--milestone is required"
[ -n "$TOOL_DIR" ] || die_usage "--tool-dir is required"; need_abs --tool-dir "$TOOL_DIR"
[ -n "$OUT" ] || die_usage "--out is required"; need_abs --out "$OUT"
[ -z "$PREFIX_FILE" ] || { need_abs --prefix-file "$PREFIX_FILE"; [ -f "$PREFIX_FILE" ] || die_usage "prefix file not found: $PREFIX_FILE"; }
[ -z "$FALCO_SRC" ] || { need_abs --falco-source-dir "$FALCO_SRC"; [ -f "$FALCO_SRC/.github/release_template.md" ] || die_usage "no .github/release_template.md under $FALCO_SRC"; }
[ -z "$PREFIX_FILE" ] || [ -z "$FALCO_SRC" ] || die_usage "--prefix-file and --falco-source-dir are mutually exclusive"
[ -n "$TAG" ] || TAG=$MILESTONE
command -v go >/dev/null || die_usage "go is required to build the tool"
[ -f "$SCRIPT_DIR/_rn2md_envshim.go" ] || die_usage "helper missing: $SCRIPT_DIR/_rn2md_envshim.go"
TOOL_URL="https://github.com/$TOOL_REPO.git"
WORK=$(dirname "$OUT"); mkdir -p "$WORK"

echo "== $(stamp) release-body-build $REPO milestone=$MILESTONE tool=$TOOL_REPO@$TOOL_REF"

# 1. tool checkout at the pinned revision
if [ -e "$TOOL_DIR" ]; then
  [ -d "$TOOL_DIR/.git" ] || abort "tool dir exists and is not a git clone: $TOOL_DIR"
  PREV=$(git -C "$TOOL_DIR" remote get-url origin 2>/dev/null || true)
  [ "$PREV" = "$TOOL_URL" ] || abort "tool dir holds a clone of '$PREV', not of $TOOL_URL"
else
  git clone -q "$TOOL_URL" "$TOOL_DIR" || abort "clone of $TOOL_URL failed"
fi
git -C "$TOOL_DIR" fetch -q origin "$TOOL_REF" || abort "cannot fetch $TOOL_REF from $TOOL_URL"
git -C "$TOOL_DIR" checkout -q --detach FETCH_HEAD || abort "checkout of $TOOL_REF failed"
TOOL_SHA=$(git -C "$TOOL_DIR" rev-parse HEAD)
case "$TOOL_REF" in
  *[!0-9a-f]*) ;;  # tag or branch name
  *) case "$TOOL_SHA" in "$TOOL_REF"*) ;; *) abort "checked out $TOOL_SHA, expected $TOOL_REF";; esac;;
esac
echo "ok: tool at $TOOL_SHA"

# 2. build the env-shim binary inside the module
mkdir -p "$TOOL_DIR/envshim"
cp "$SCRIPT_DIR/_rn2md_envshim.go" "$TOOL_DIR/envshim/main.go"
go -C "$TOOL_DIR" build -o "$TOOL_DIR/rn2md-env" ./envshim >"$WORK/rn2md-build.log" 2>&1 || abort "go build failed (see $WORK/rn2md-build.log)"
echo "ok: built $TOOL_DIR/rn2md-env"

# 3. defaults from the API
[ -n "$BRANCH" ] || BRANCH=$(gh api "repos/$REPO" --jq .default_branch) || abort "cannot read the default branch"
[ -n "$RM" ] || RM=$(gh api user --jq .login) || abort "cannot read the current login"
echo "ok: branch filter '$BRANCH', release manager @$RM, tag '$TAG'"

# 4. run rn2md with the token in the child's environment only
RN2MD_TOKEN=$(gh auth token) || abort "gh auth token failed"
[ -n "$RN2MD_TOKEN" ] || abort "empty token from gh auth token"
NOTES="$WORK/rn2md-notes-$MILESTONE.md"; ERR="$WORK/rn2md-stderr-$MILESTONE.log"
echo "running rn2md -r $REPO -m $MILESTONE -b $BRANCH (token from the environment, length ${#RN2MD_TOKEN})"
if ! RN2MD_TOKEN="$RN2MD_TOKEN" "$TOOL_DIR/rn2md-env" -r "$REPO" -m "$MILESTONE" -b "$BRANCH" >"$NOTES" 2>"$ERR"; then
  ERRTXT=$(<"$ERR")
  case "$ERRTXT" in *"$RN2MD_TOKEN"*) echo "(stderr withheld: it contains the token)";; *) printf '%s\n' "$ERRTXT" | head -n 20;; esac
  case "$ERRTXT" in *"40 characters"*|*"len"*) echo "hint: the pinned rn2md validates the token length (cmd/opts.go len=40); pass --tool-repo/--tool-ref of a build without that check (leodido/rn2md#15)";; esac
  abort "rn2md failed (stderr: $ERR)"
fi
unset RN2MD_TOKEN
[ -s "$NOTES" ] || abort "rn2md produced no output"
echo "ok: notes $(wc -l < "$NOTES") lines -> $NOTES"

# 5. assemble the body like the workflow
{
  if [ -n "$PREFIX_FILE" ]; then cat "$PREFIX_FILE"; fi
  if [ -n "$FALCO_SRC" ]; then
    LIBS_VERS=$(grep 'set(FALCOSECURITY_LIBS_VERSION' "$FALCO_SRC/cmake/modules/falcosecurity-libs.cmake" | tail -n1 | grep -o '[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*' || true)
    DRIVER_VERS=$(grep 'set(DRIVER_VERSION' "$FALCO_SRC/cmake/modules/driver.cmake" | tail -n1 | grep -o '[[:digit:]]*\.[[:digit:]]*\.[[:digit:]]*+driver' || true)
    BUCKET=""; case "$TAG" in *-*) BUCKET="-dev";; esac
    T=$(<"$FALCO_SRC/.github/release_template.md")
    T=${T//LIBSVER/$LIBS_VERS}; T=${T//DRIVERVER/$DRIVER_VERS}; T=${T//FALCOBUCKET/$BUCKET}; T=${T//FALCOVER/$TAG}
    printf '%s\n' "$T"
  fi
  cat "$NOTES"
  echo ""
  echo "#### Release Manager @$RM"
} > "$OUT"
echo "-- body head:"; head -n 12 "$OUT" | sed 's/^/   | /'
echo "-- body: $(wc -l < "$OUT") lines, $(wc -c < "$OUT") bytes"
echo "apply by hand (not executed): gh release edit $TAG -R $REPO --notes-file $OUT"
echo "BODY_BUILT $OUT"
