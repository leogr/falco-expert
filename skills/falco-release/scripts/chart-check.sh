#!/usr/bin/env bash
# chart-check.sh - verify the publication of a falcosecurity Helm chart version.
#
# Purpose:
#   For one chart version:
#     - the Helm repository index (index.yaml on the charts site) has an entry for <chart> <version>
#       whose appVersion equals --app-version
#     - the packaged chart (.tgz linked by the index entry) downloads and its SHA256 equals the
#       index digest
#     - with helm installed: the default template render uses the image <image-repo>:<app-version>
#       (otherwise: SKIP)
#     - the GitHub release <chart>-<version> in the charts repository exists, its prerelease flag
#       equals --expect-prerelease, and a final chart is not a draft
#   Prints one line per check:  OK|MISSING|MISMATCH|SKIP|ERROR <what> <detail>
#   and a final token: CHART_OK or CHART_INCOMPLETE (always the last line).
#
# Usage:
#   chart-check.sh --chart <name> --version <v> --app-version <v> --workdir </abs/dir>
#                  [--expect-prerelease] [--index-url URL] [--repo owner/repo] [--image-repo PATH] [--timeout SEC]
#
# Exit codes:
#   0  every check passed (a SKIP does not fail the run)
#   1  at least one MISSING or MISMATCH
#   2  usage error
#   4  a network or API error prevented at least one check
#
# Read-only. curl GET, `gh release view`, and local `helm template` on the downloaded package only
# (helm state is confined to --workdir through HELM_*_HOME).
#
# Expectations come from falcosecurity/charts:
#   .github/workflows/release.yml   chart-releaser publishes GitHub releases and the gh-pages index (served at
#                                   https://falcosecurity.github.io/charts/index.yaml), then pushes/signs the OCI copy
#   charts/falco/templates/_helpers.tpl ("falco.image")  image tag defaults to .Chart.AppVersion when .Values.image.tag is empty
#   observed release tag layout: <chart>-<version> (e.g. falco-9.2.0, falco-9.2.0-rc1 with prerelease=true)
#
# Example:
#   chart-check.sh --chart falco --version 9.2.0 --app-version 0.45.0 --workdir /tmp/chart-falco-9.2.0
set -euo pipefail

# ---- project defaults (overridable by flags) ---------------------------------------------------
DEFAULT_INDEX_URL="https://falcosecurity.github.io/charts/index.yaml"   # gh-pages index written by chart-releaser (release.yml)
DEFAULT_REPO="falcosecurity/charts"                                     # GitHub repository holding the chart releases (release.yml)
DEFAULT_IMAGE_NAMESPACE="falcosecurity"                                 # default --image-repo is <namespace>/<chart> (charts/<chart>/values.yaml image.repository)
DEFAULT_TIMEOUT=60

usage() {
  cat <<'EOF'
Usage: chart-check.sh --chart <name> --version <v> --app-version <v> --workdir </abs/dir>
                      [--expect-prerelease] [--index-url URL] [--repo owner/repo] [--image-repo PATH] [--timeout SEC]

Verify a published Helm chart: index entry (appVersion), package digest, default rendered image tag,
and the GitHub release flags of <chart>-<version>.
  --chart              chart name (e.g. falco)
  --version            chart version (e.g. 9.2.0 or 9.2.0-rc1)
  --app-version        expected appVersion / image tag (e.g. 0.45.0)
  --workdir            absolute directory for downloads and helm state (created if missing)
  --expect-prerelease  the GitHub release must be flagged prerelease (default: must not be)
  --index-url          Helm repository index (default: https://falcosecurity.github.io/charts/index.yaml)
  --repo               GitHub repository with the chart releases (default: falcosecurity/charts)
  --image-repo         image repository whose tag must equal --app-version (default: falcosecurity/<chart>)
  --timeout            per-request timeout in seconds (default: 60)

Output: one "OK|MISSING|MISMATCH|SKIP|ERROR <what> <detail>" line per check; last line CHART_OK or CHART_INCOMPLETE.
Exit codes: 0 all OK; 1 a check failed; 2 usage; 4 network/API error prevented a check.
Example: chart-check.sh --chart falco --version 9.2.0 --app-version 0.45.0 --workdir /tmp/chart-falco-9.2.0
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }

CHART="" VERSION="" APP_VERSION="" WORKDIR="" EXPECT_PRE=0 INDEX_URL="$DEFAULT_INDEX_URL" REPO="$DEFAULT_REPO"
IMAGE_REPO="" TIMEOUT="$DEFAULT_TIMEOUT"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --chart) [ $# -ge 2 ] || die_usage "--chart needs a value"; CHART="$2"; shift 2 ;;
    --version) [ $# -ge 2 ] || die_usage "--version needs a value"; VERSION="$2"; shift 2 ;;
    --app-version) [ $# -ge 2 ] || die_usage "--app-version needs a value"; APP_VERSION="$2"; shift 2 ;;
    --workdir) [ $# -ge 2 ] || die_usage "--workdir needs a value"; WORKDIR="$2"; shift 2 ;;
    --expect-prerelease) EXPECT_PRE=1; shift ;;
    --index-url) [ $# -ge 2 ] || die_usage "--index-url needs a value"; INDEX_URL="$2"; shift 2 ;;
    --repo) [ $# -ge 2 ] || die_usage "--repo needs a value"; REPO="$2"; shift 2 ;;
    --image-repo) [ $# -ge 2 ] || die_usage "--image-repo needs a value"; IMAGE_REPO="$2"; shift 2 ;;
    --timeout) [ $# -ge 2 ] || die_usage "--timeout needs a value"; TIMEOUT="$2"; shift 2 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$CHART" ] || die_usage "--chart is required"
[ -n "$VERSION" ] || die_usage "--version is required"
[ -n "$APP_VERSION" ] || die_usage "--app-version is required"
[ -n "$WORKDIR" ] || die_usage "--workdir is required"
case "$WORKDIR" in /*) ;; *) die_usage "--workdir must be an absolute path" ;; esac
case "$CHART" in *[!a-z0-9_.-]*|'') die_usage "--chart has unexpected characters" ;; esac
case "$VERSION" in *[!0-9A-Za-z.+-]*|'') die_usage "--version has unexpected characters" ;; esac
case "$REPO" in */*) ;; *) die_usage "--repo must be owner/repo" ;; esac
case "$TIMEOUT" in ''|*[!0-9]*) die_usage "--timeout must be an integer" ;; esac
[ -n "$IMAGE_REPO" ] || IMAGE_REPO="$DEFAULT_IMAGE_NAMESPACE/$CHART"
for tool in curl gh sha256sum awk; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'error: %s is required\n' "$tool" >&2; exit 2; }
done

mkdir -p "$WORKDIR"
ERRLOG="$WORKDIR/http-errors.log"
: > "$ERRLOG"
N_OK=0 N_FAIL=0 N_ERR=0
ok()   { N_OK=$((N_OK+1));     printf 'OK %s %s\n' "$1" "$2"; }
fail() { N_FAIL=$((N_FAIL+1)); printf '%s %s %s\n' "$1" "$2" "$3"; }
err()  { N_ERR=$((N_ERR+1));   printf 'ERROR %s %s\n' "$1" "$2"; }

# one curl per line; 429/5xx answers are retried after 2, 5 and 10 seconds
RETRY_SLEEPS="2 5 10"
retry_again() { case "${1:-000}" in 429|5[0-9][0-9]) return 0 ;; *) return 1 ;; esac; }
get_code() { # $1 url  $2 out -> http code
  local code s
  for s in 0 $RETRY_SLEEPS; do
    if [ "$s" -gt 0 ]; then sleep "$s"; fi
    code=$(curl -sS -L -m "$TIMEOUT" -o "$2" -w '%{http_code}' "$1" 2>>"$ERRLOG") || true
    retry_again "$code" || break
  done
  printf '%s' "${code:-000}"
}

TAG="$CHART-$VERSION"
printf 'START %s chart-check chart=%s version=%s app-version=%s expect-prerelease=%s workdir=%s\n' "$(date -u +%FT%TZ)" "$CHART" "$VERSION" "$APP_VERSION" "$EXPECT_PRE" "$WORKDIR"

# ---- index entry ---------------------------------------------------------------------------------
INDEX="$WORKDIR/index.yaml"
ENTRY_URL="" ENTRY_DIGEST="" ENTRY_APP=""
code=$(get_code "$INDEX_URL" "$INDEX")
case "$code" in
  200)
    # index.yaml is written by `helm repo index` (chart-releaser): entries -> <chart> -> list items with
    # 4-space keys, `urls:` list items at 4 spaces, nested maps (dependencies, maintainers) at 6+ spaces.
    if entry=$(awk -v want="$CHART" -v ver="$VERSION" '
      function parse(l,   k, v) { k = l; sub(/^ +/, "", k); sub(/:.*/, "", k); v = l; sub(/^ *[^:]+:[ ]*/, "", v); gsub(/^"|"$/, "", v); f[k] = v; lastkey = k }
      function emit() { if (initem && f["version"] == ver) { print "appVersion=" f["appVersion"]; print "url=" f["url"]; print "digest=" f["digest"]; print "created=" f["created"]; found = 1 } }
      /^entries:/ { inent = 1; next }
      inent && /^  [A-Za-z0-9_.-]+:[ ]*$/ { emit(); delete f; initem = 0; chart = $1; sub(/:$/, "", chart); next }
      inent && chart == want && /^  - / { emit(); delete f; initem = 1; line = $0; sub(/^  - /, "    ", line); parse(line); next }
      inent && chart == want && initem && /^    - / { if (lastkey == "urls" && f["url"] == "") { u = $0; sub(/^    - /, "", u); gsub(/^"|"$/, "", u); f["url"] = u } next }
      inent && chart == want && initem && /^      / { next }
      inent && chart == want && initem && /^    [A-Za-z0-9_.-]+:/ { parse($0); next }
      END { emit(); if (!found) exit 3 }
    ' "$INDEX"); then
      ENTRY_APP=$(printf '%s\n' "$entry" | sed -n 's/^appVersion=//p')
      ENTRY_URL=$(printf '%s\n' "$entry" | sed -n 's/^url=//p')
      ENTRY_DIGEST=$(printf '%s\n' "$entry" | sed -n 's/^digest=//p')
      created=$(printf '%s\n' "$entry" | sed -n 's/^created=//p')
      if [ "$ENTRY_APP" = "$APP_VERSION" ]; then
        ok "index-entry $TAG" "appVersion=$ENTRY_APP created=$created url=$ENTRY_URL"
      else
        fail MISMATCH "index-entry $TAG" "appVersion=$ENTRY_APP expected=$APP_VERSION url=$ENTRY_URL"
      fi
    else
      fail MISSING "index-entry $TAG" "no entry with version $VERSION under entries.$CHART in $INDEX_URL"
    fi
    ;;
  000) err "index $INDEX_URL" "network error" ;;
  *) err "index $INDEX_URL" "http=$code" ;;
esac

# ---- package download + digest -----------------------------------------------------------------
TGZ=""
if [ -n "$ENTRY_URL" ]; then
  TGZ="$WORKDIR/$TAG.tgz"
  code=$(get_code "$ENTRY_URL" "$TGZ")
  case "$code" in
    200)
      sha=$(sha256sum "$TGZ" | cut -d' ' -f1)
      if [ -z "$ENTRY_DIGEST" ]; then
        ok "package $TAG.tgz" "bytes=$(stat -c %s "$TGZ") sha256=$sha (index has no digest field)"
      elif [ "$sha" = "$ENTRY_DIGEST" ]; then
        ok "package-digest $TAG.tgz" "sha256=$sha matches the index digest"
      else
        fail MISMATCH "package-digest $TAG.tgz" "sha256=$sha index=$ENTRY_DIGEST"
        TGZ=""
      fi
      ;;
    404|403) fail MISSING "package $TAG.tgz" "http=$code url=$ENTRY_URL"; TGZ="" ;;
    000) err "package $TAG.tgz" "network error"; TGZ="" ;;
    *) err "package $TAG.tgz" "http=$code"; TGZ="" ;;
  esac
else
  printf 'SKIP package %s.tgz no index entry to download from\n' "$TAG"
fi

# ---- template render -----------------------------------------------------------------------------
if [ -z "$TGZ" ]; then
  printf 'SKIP render %s package not available\n' "$TAG"
elif ! command -v helm >/dev/null 2>&1; then
  printf 'SKIP render %s helm not installed\n' "$TAG"
else
  export HELM_CACHE_HOME="$WORKDIR/helm/cache" HELM_CONFIG_HOME="$WORKDIR/helm/config" HELM_DATA_HOME="$WORKDIR/helm/data"
  mkdir -p "$HELM_CACHE_HOME" "$HELM_CONFIG_HOME" "$HELM_DATA_HOME"
  if helm template chartcheck "$TGZ" > "$WORKDIR/rendered.yaml" 2>"$WORKDIR/helm-template.err"; then
    tags=""
    while IFS= read -r ref; do
      ref="${ref%\"}"; ref="${ref#\"}"; ref="${ref%\'}"; ref="${ref#\'}"
      repo_part="${ref%:*}"; tag_part="${ref##*:}"
      case "$ref" in */*:*) ;; *) continue ;; esac
      if [ "$repo_part" = "$IMAGE_REPO" ] || [[ "$repo_part" == */"$IMAGE_REPO" ]]; then
        tags="$tags $tag_part"
      fi
    done < <(grep -E '^[[:space:]]*(- )?image:[[:space:]]' "$WORKDIR/rendered.yaml" | sed -E 's/^[[:space:]]*(- )?image:[[:space:]]*//')
    uniq_tags=$(printf '%s\n' $tags | sort -u | tr '\n' ' ' | sed 's/ $//')
    if [ -z "$uniq_tags" ]; then
      fail MISMATCH "render $TAG" "no image matching $IMAGE_REPO in the default render"
    elif [ "$uniq_tags" = "$APP_VERSION" ]; then
      ok "render $TAG" "$IMAGE_REPO:$uniq_tags (default values)"
    else
      fail MISMATCH "render $TAG" "$IMAGE_REPO tags=[$uniq_tags] expected=$APP_VERSION"
    fi
  else
    err "render $TAG" "helm template failed: $(head -c 300 "$WORKDIR/helm-template.err" | tr '\n' ' ')"
  fi
fi

# ---- GitHub release flags -------------------------------------------------------------------------
if out=$(gh release view "$TAG" -R "$REPO" --json tagName,isPrerelease,isDraft,url,publishedAt 2>"$WORKDIR/gh-release.err"); then
  is_pre=$(printf '%s' "$out" | jq -r '.isPrerelease')
  is_draft=$(printf '%s' "$out" | jq -r '.isDraft')
  url=$(printf '%s' "$out" | jq -r '.url')
  want_pre=false; [ "$EXPECT_PRE" -eq 1 ] && want_pre=true
  if [ "$is_pre" = "$want_pre" ]; then
    ok "release $REPO $TAG" "prerelease=$is_pre draft=$is_draft $url"
  else
    fail MISMATCH "release $REPO $TAG" "prerelease=$is_pre expected=$want_pre draft=$is_draft $url"
  fi
  if [ "$EXPECT_PRE" -eq 0 ] && [ "$is_draft" = "true" ]; then
    fail MISMATCH "release-draft $REPO $TAG" "a final chart release must not be a draft"
  fi
else
  if grep -qi "not found\|could not find\|HTTP 404" "$WORKDIR/gh-release.err"; then
    fail MISSING "release $REPO $TAG" "no GitHub release with this tag"
  else
    err "release $REPO $TAG" "gh failed: $(head -c 200 "$WORKDIR/gh-release.err" | tr '\n' ' ')"
  fi
fi

printf 'END %s ok=%d failed=%d errors=%d\n' "$(date -u +%FT%TZ)" "$N_OK" "$N_FAIL" "$N_ERR"
if [ "$N_ERR" -gt 0 ]; then printf 'CHART_INCOMPLETE\n'; exit 4; fi
if [ "$N_FAIL" -gt 0 ]; then printf 'CHART_INCOMPLETE\n'; exit 1; fi
printf 'CHART_OK\n'
exit 0
