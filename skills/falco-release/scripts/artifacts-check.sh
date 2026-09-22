#!/usr/bin/env bash
# artifacts-check.sh - verify the published artifacts of a Falco release (candidate or final).
#
# Purpose:
#   For one Falco version, check every artifact the release workflow publishes:
#     - packages on the download bucket: bin tarballs (x86_64, aarch64), static x86_64 tarball,
#       deb and rpm for both arches, their detached .asc signatures, and the wasm tarball
#     - the four multi-arch image families on Docker Hub (index digest, linux/amd64 + linux/arm64)
#       and the arch-specific tags pushed alongside them
#     - the ECR Public copies of the four multi-arch families (digest must equal the Docker Hub one)
#     - --mode final only: the "latest" family tags on both registries, whose digests must equal
#       the version digests
#   Prints one line per artifact:  OK|MISSING|MISMATCH|SKIP|ERROR <what> <detail>
#   and a final token: ARTIFACTS_OK or ARTIFACTS_INCOMPLETE (always the last line).
#
# Usage:
#   artifacts-check.sh --version <v> --mode candidate|final --workdir </abs/dir>
#                      [--component falco] [--base-url URL] [--hub-namespace NS]
#                      [--ecr-namespace NS] [--timeout SEC]
#
#   candidate = pre-release (-rc) : "-dev" buckets, no "latest" expectations
#   final     = stable release    : stable buckets, "latest" tags must point at the version digests
#
# Exit codes:
#   0  every expected artifact is present and consistent
#   1  at least one artifact is MISSING or MISMATCH
#   2  usage error
#   4  a network or API error prevented at least one check (result is inconclusive)
#
# Read-only. Only curl GET/HEAD requests. The anonymous ECR Public bearer token is written to a
# header file inside --workdir and passed with `curl -H @file`, never on the command line.
#
# Expectations come from falcosecurity/falco:
#   .github/workflows/release.yaml                    bucket_suffix "-dev" for pre-releases, is_latest for finals
#   .github/workflows/reusable_publish_packages.yaml  publish steps for rpm, bin, static, deb, wasm
#   scripts/publish-bin, scripts/publish-deb, scripts/publish-rpm, scripts/publish-wasm
#                                                     bucket key layout (packages/<repo>[/<suite>|/<arch>]) and .asc files
#   .github/workflows/reusable_publish_docker.yaml    tag families, arch-specific tags, ECR copies, latest tags
#
# Example:
#   artifacts-check.sh --version 0.45.0 --mode final --workdir /tmp/falco-artifacts-0.45.0
set -euo pipefail

# ---- project defaults (overridable by flags) ---------------------------------------------------
DEFAULT_BASE_URL="https://download.falco.org"      # CloudFront front of s3://falco-distribution (scripts/publish-*)
DEFAULT_HUB_NAMESPACE="falcosecurity"             # docker.io/falcosecurity (reusable_publish_docker.yaml)
DEFAULT_ECR_NAMESPACE="falcosecurity"             # public.ecr.aws/falcosecurity (reusable_publish_docker.yaml)
DEFAULT_HUB_API="https://hub.docker.com/v2"       # Docker Hub tag metadata API
DEFAULT_ECR_REGISTRY="https://public.ecr.aws"     # ECR Public registry API (crane copy target in reusable_publish_docker.yaml)
DEFAULT_COMPONENT="falco"
DEFAULT_TIMEOUT=60
ACCEPT_INDEX="application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json"

usage() {
  cat <<'EOF'
Usage: artifacts-check.sh --version <v> --mode candidate|final --workdir </abs/dir>
                          [--component falco] [--base-url URL] [--hub-namespace NS]
                          [--ecr-namespace NS] [--timeout SEC]

Verify the packages, Docker Hub tags and ECR Public copies published for a Falco release.
  --version    release version, e.g. 0.45.0 or 0.45.0-rc2
  --mode       candidate (pre-release: -dev buckets, no latest) | final (stable buckets, latest tags)
  --workdir    absolute directory for downloaded metadata (created if missing)
  --component  component whose artifact lists to use (default: falco; only falco is implemented)
  --base-url   download bucket base URL (default: https://download.falco.org)
  --hub-namespace / --ecr-namespace   registry namespaces (default: falcosecurity)
  --timeout    per-request timeout in seconds (default: 60)

Output: one "OK|MISSING|MISMATCH|SKIP|ERROR <what> <detail>" line per artifact; last line is
ARTIFACTS_OK or ARTIFACTS_INCOMPLETE.
Exit codes: 0 all OK; 1 a check failed; 2 usage; 4 network/API error prevented a check.
Example: artifacts-check.sh --version 0.45.0 --mode final --workdir /tmp/falco-artifacts-0.45.0
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }

VERSION="" MODE="" WORKDIR="" COMPONENT="$DEFAULT_COMPONENT" BASE_URL="$DEFAULT_BASE_URL"
HUB_NAMESPACE="$DEFAULT_HUB_NAMESPACE" ECR_NAMESPACE="$DEFAULT_ECR_NAMESPACE"
HUB_API="$DEFAULT_HUB_API" ECR_REGISTRY="$DEFAULT_ECR_REGISTRY" TIMEOUT="$DEFAULT_TIMEOUT"

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --version) [ $# -ge 2 ] || die_usage "--version needs a value"; VERSION="$2"; shift 2 ;;
    --mode) [ $# -ge 2 ] || die_usage "--mode needs a value"; MODE="$2"; shift 2 ;;
    --workdir) [ $# -ge 2 ] || die_usage "--workdir needs a value"; WORKDIR="$2"; shift 2 ;;
    --component) [ $# -ge 2 ] || die_usage "--component needs a value"; COMPONENT="$2"; shift 2 ;;
    --base-url) [ $# -ge 2 ] || die_usage "--base-url needs a value"; BASE_URL="${2%/}"; shift 2 ;;
    --hub-namespace) [ $# -ge 2 ] || die_usage "--hub-namespace needs a value"; HUB_NAMESPACE="$2"; shift 2 ;;
    --ecr-namespace) [ $# -ge 2 ] || die_usage "--ecr-namespace needs a value"; ECR_NAMESPACE="$2"; shift 2 ;;
    --timeout) [ $# -ge 2 ] || die_usage "--timeout needs a value"; TIMEOUT="$2"; shift 2 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$VERSION" ] || die_usage "--version is required"
[ -n "$MODE" ] || die_usage "--mode is required"
case "$MODE" in candidate|final) ;; *) die_usage "--mode must be candidate or final" ;; esac
[ -n "$WORKDIR" ] || die_usage "--workdir is required"
case "$WORKDIR" in /*) ;; *) die_usage "--workdir must be an absolute path" ;; esac
case "$TIMEOUT" in ''|*[!0-9]*) die_usage "--timeout must be an integer" ;; esac
case "$VERSION" in
  *[!0-9A-Za-z.-]*|'') die_usage "--version has unexpected characters" ;;
esac
for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'error: %s is required\n' "$tool" >&2; exit 2; }
done

# ---- per-component artifact lists (add a case per component) -----------------------------------
# Prints the expected package URLs, one per line.
package_urls() { # $1 component  $2 version  $3 mode
  local comp="$1" v="$2" sfx="" base u
  if [ "$3" = "candidate" ]; then sfx="-dev"; fi
  base="$BASE_URL/packages"
  case "$comp" in
    falco)
      # reusable_publish_packages.yaml: publish-bin -r bin$sfx -a <arch>; publish-deb -r deb$sfx (suite stable);
      # publish-rpm -r rpm$sfx. Each publish-* script also uploads <package>.asc.
      for u in \
        "$base/bin$sfx/x86_64/falco-$v-x86_64.tar.gz" \
        "$base/bin$sfx/aarch64/falco-$v-aarch64.tar.gz" \
        "$base/bin$sfx/x86_64/falco-$v-static-x86_64.tar.gz" \
        "$base/deb$sfx/stable/falco-$v-x86_64.deb" \
        "$base/deb$sfx/stable/falco-$v-aarch64.deb" \
        "$base/rpm$sfx/falco-$v-x86_64.rpm" \
        "$base/rpm$sfx/falco-$v-aarch64.rpm"; do
        printf '%s\n%s.asc\n' "$u" "$u"
      done
      # scripts/publish-wasm always publishes to packages/wasm-dev (no signature, no mode suffix)
      printf '%s\n' "$base/wasm-dev/falco-$v-wasm.tar.gz"
      ;;
    *) return 1 ;;
  esac
}

# Prints the multi-arch image families as "repo:tag", one per line.
image_families() { # $1 component  $2 version
  case "$1" in
    falco)
      # reusable_publish_docker.yaml: falco:<tag>, falco:<tag>-debian, falco-driver-loader:<tag>, falco-driver-loader:<tag>-buster
      printf '%s\n' "falco:$2" "falco:$2-debian" "falco-driver-loader:$2" "falco-driver-loader:$2-buster"
      ;;
    *) return 1 ;;
  esac
}

# Arch-specific single-platform tags pushed to Docker Hub only: "<arch>-<tag>" with arch in x86_64, aarch64.
arch_tag_prefixes() { # $1 component -> lines "<prefix> <platform>"
  case "$1" in
    falco) printf '%s\n' "x86_64 amd64" "aarch64 arm64" ;;
    *) return 1 ;;
  esac
}

package_urls "$COMPONENT" "$VERSION" "$MODE" >/dev/null 2>&1 || die_usage "unsupported component: $COMPONENT"

mkdir -p "$WORKDIR"
ERRLOG="$WORKDIR/http-errors.log"
: > "$ERRLOG"

N_OK=0 N_FAIL=0 N_ERR=0
ok()   { N_OK=$((N_OK+1));     printf 'OK %s %s\n' "$1" "$2"; }
fail() { N_FAIL=$((N_FAIL+1)); printf '%s %s %s\n' "$1" "$2" "$3"; }   # $1 MISSING|MISMATCH
err()  { N_ERR=$((N_ERR+1));   printf 'ERROR %s %s\n' "$1" "$2"; }

# ---- HTTP helpers: exactly one curl per line; 429/5xx answers are retried after 2, 5 and 10 seconds
# (ECR Public and Docker Hub throttle anonymous bursts) -------------------------------------------
RETRY_SLEEPS="2 5 10"
retry_again() { case "${1:-000}" in 429|5[0-9][0-9]) return 0 ;; *) return 1 ;; esac; }
head_code() { # $1 url  $2 headers-out -> http code (000 on transport failure)
  local code s
  for s in 0 $RETRY_SLEEPS; do
    if [ "$s" -gt 0 ]; then sleep "$s"; fi
    code=$(curl -sS -I -L -m "$TIMEOUT" -o "$2" -w '%{http_code}' "$1" 2>>"$ERRLOG") || true
    retry_again "$code" || break
  done
  printf '%s' "${code:-000}"
}
get_code() { # $1 url  $2 body-out -> http code
  local code s
  for s in 0 $RETRY_SLEEPS; do
    if [ "$s" -gt 0 ]; then sleep "$s"; fi
    code=$(curl -sS -L -m "$TIMEOUT" -o "$2" -w '%{http_code}' "$1" 2>>"$ERRLOG") || true
    retry_again "$code" || break
  done
  printf '%s' "${code:-000}"
}
get_manifest_code() { # $1 url  $2 body-out  $3 header-file(auth)  $4 response-headers-out -> http code
  local code s
  for s in 0 $RETRY_SLEEPS; do
    if [ "$s" -gt 0 ]; then sleep "$s"; fi
    code=$(curl -sS -m "$TIMEOUT" -o "$2" -D "$4" -w '%{http_code}' -H @"$3" -H "Accept: $ACCEPT_INDEX" "$1" 2>>"$ERRLOG") || true
    retry_again "$code" || break
  done
  printf '%s' "${code:-000}"
}
# header_value FILE NAME -> value of the last occurrence of a response header (case-insensitive), empty when absent; never fails
header_value() {
  awk -v h="$2" 'BEGIN { h = tolower(h) ":" } tolower($1) == h { v = $2 } END { gsub(/\r/, "", v); printf "%s", v }' "$1"
}

safe_name() { printf '%s' "$1" | tr '/:' '__'; }

printf 'START %s artifacts-check component=%s version=%s mode=%s workdir=%s\n' "$(date -u +%FT%TZ)" "$COMPONENT" "$VERSION" "$MODE" "$WORKDIR"

# ---- packages ------------------------------------------------------------------------------------
i=0
while IFS= read -r url; do
  [ -n "$url" ] || continue
  i=$((i+1))
  hdr="$WORKDIR/pkg-head-$i.txt"
  code=$(head_code "$url" "$hdr")
  case "$code" in
    200)
      len=$(header_value "$hdr" content-length)
      ok "package ${url#"$BASE_URL"/}" "http=200 bytes=${len:-?}"
      ;;
    404|403) fail MISSING "package ${url#"$BASE_URL"/}" "http=$code" ;;
    000) err "package ${url#"$BASE_URL"/}" "network error (see $ERRLOG)" ;;
    *) err "package ${url#"$BASE_URL"/}" "http=$code" ;;
  esac
done < <(package_urls "$COMPONENT" "$VERSION" "$MODE")

# ---- Docker Hub ---------------------------------------------------------------------------------
HUB_DIGEST=""
check_hub_tag() { # $1 repo  $2 tag  $3 expected platforms (comma-joined, sorted)  -> sets HUB_DIGEST
  local repo="$1" tag="$2" want="$3" what f code plats
  what="hub $HUB_NAMESPACE/$repo:$tag"
  f="$WORKDIR/hub-$(safe_name "$repo-$tag").json"
  HUB_DIGEST=""
  code=$(get_code "$HUB_API/repositories/$HUB_NAMESPACE/$repo/tags/$tag" "$f")
  case "$code" in
    200) ;;
    404) fail MISSING "$what" "http=404"; return 0 ;;
    000) err "$what" "network error"; return 0 ;;
    *) err "$what" "http=$code"; return 0 ;;
  esac
  HUB_DIGEST=$(jq -r '.digest // ([.images[]? | .digest // empty] | sort | join(","))' "$f")
  plats=$(jq -r '[.images[]? | select(.os == "linux") | .architecture] | sort | join(",")' "$f")
  if [ "$plats" = "$want" ]; then
    ok "$what" "digest=$HUB_DIGEST platforms=$plats"
  else
    fail MISMATCH "$what" "platforms=$plats expected=$want digest=$HUB_DIGEST"
  fi
}

# ---- ECR Public ---------------------------------------------------------------------------------
ECR_DIGEST=""
ecr_header_file() { # $1 repo -> prints header file path; returns 1 when the token cannot be obtained
  local repo="$1" tokf hdr code tok
  tokf="$WORKDIR/ecr-token-$(safe_name "$repo").json"
  hdr="$WORKDIR/ecr-auth-$(safe_name "$repo").hdr"
  if [ -s "$hdr" ]; then printf '%s' "$hdr"; return 0; fi
  code=$(get_code "$ECR_REGISTRY/token/?scope=repository:$ECR_NAMESPACE/$repo:pull" "$tokf")
  [ "$code" = "200" ] || return 1
  tok=$(jq -r '.token // empty' "$tokf")
  [ -n "$tok" ] || return 1
  ( umask 077; printf 'Authorization: Bearer %s\n' "$tok" > "$hdr" )
  printf '%s' "$hdr"
}
check_ecr_tag() { # $1 repo  $2 tag  $3 expected platforms -> sets ECR_DIGEST
  local repo="$1" tag="$2" want="$3" what hdr body resp code plats
  what="ecr $ECR_NAMESPACE/$repo:$tag"
  ECR_DIGEST=""
  if ! hdr=$(ecr_header_file "$repo"); then err "$what" "anonymous token request failed"; return 0; fi
  body="$WORKDIR/ecr-$(safe_name "$repo-$tag").json"
  resp="$WORKDIR/ecr-$(safe_name "$repo-$tag").hdr"
  code=$(get_manifest_code "$ECR_REGISTRY/v2/$ECR_NAMESPACE/$repo/manifests/$tag" "$body" "$hdr" "$resp")
  case "$code" in
    200) ;;
    404) fail MISSING "$what" "http=404"; return 0 ;;
    000) err "$what" "network error"; return 0 ;;
    *) err "$what" "http=$code"; return 0 ;;
  esac
  ECR_DIGEST=$(header_value "$resp" docker-content-digest)
  if [ -z "$ECR_DIGEST" ]; then
    # registry did not return the header: compute the index digest from the body (canonical bytes as served)
    ECR_DIGEST="sha256:$(sha256sum "$body" | cut -d' ' -f1)"
  fi
  plats=$(jq -r '[.manifests[]? | select(.platform.os == "linux") | .platform.architecture] | sort | join(",")' "$body")
  if [ "$plats" = "$want" ]; then
    ok "$what" "digest=${ECR_DIGEST:-?} platforms=$plats"
  else
    fail MISMATCH "$what" "platforms=$plats expected=$want digest=${ECR_DIGEST:-?}"
  fi
}

declare -A HUB_D=() ECR_D=()
MULTI="amd64,arm64"

while IFS= read -r rt; do
  [ -n "$rt" ] || continue
  repo="${rt%%:*}"; tag="${rt#*:}"
  check_hub_tag "$repo" "$tag" "$MULTI"; HUB_D["$rt"]="$HUB_DIGEST"
  while read -r prefix platform; do
    check_hub_tag "$repo" "$prefix-$tag" "$platform"
  done < <(arch_tag_prefixes "$COMPONENT")
  check_ecr_tag "$repo" "$tag" "$MULTI"; ECR_D["$rt"]="$ECR_DIGEST"
  if [ -n "${HUB_D[$rt]}" ] && [ -n "${ECR_D[$rt]}" ]; then
    if [ "${HUB_D[$rt]}" = "${ECR_D[$rt]}" ]; then
      ok "hub-vs-ecr $repo:$tag" "same digest ${HUB_D[$rt]}"
    else
      fail MISMATCH "hub-vs-ecr $repo:$tag" "hub=${HUB_D[$rt]} ecr=${ECR_D[$rt]} (crane copy preserves the index digest)"
    fi
  else
    printf 'SKIP hub-vs-ecr %s:%s one side unavailable\n' "$repo" "$tag"
  fi
done < <(image_families "$COMPONENT" "$VERSION")

# ---- latest family (final only) ----------------------------------------------------------------
if [ "$MODE" = "final" ]; then
  while IFS= read -r rt; do
    [ -n "$rt" ] || continue
    repo="${rt%%:*}"; tag="${rt#*:}"
    ltag="${tag/"$VERSION"/latest}"
    check_hub_tag "$repo" "$ltag" "$MULTI"
    if [ -n "$HUB_DIGEST" ] && [ -n "${HUB_D[$rt]}" ]; then
      if [ "$HUB_DIGEST" = "${HUB_D[$rt]}" ]; then
        ok "latest hub $repo:$ltag" "== $repo:$tag digest=$HUB_DIGEST"
      else
        fail MISMATCH "latest hub $repo:$ltag" "latest=$HUB_DIGEST version=${HUB_D[$rt]}"
      fi
    else
      printf 'SKIP latest hub %s:%s digest unavailable on one side\n' "$repo" "$ltag"
    fi
    check_ecr_tag "$repo" "$ltag" "$MULTI"
    if [ -n "$ECR_DIGEST" ] && [ -n "${ECR_D[$rt]}" ]; then
      if [ "$ECR_DIGEST" = "${ECR_D[$rt]}" ]; then
        ok "latest ecr $repo:$ltag" "== $repo:$tag digest=$ECR_DIGEST"
      else
        fail MISMATCH "latest ecr $repo:$ltag" "latest=$ECR_DIGEST version=${ECR_D[$rt]}"
      fi
    else
      printf 'SKIP latest ecr %s:%s digest unavailable on one side\n' "$repo" "$ltag"
    fi
  done < <(image_families "$COMPONENT" "$VERSION")
else
  printf 'SKIP latest tags not expected in candidate mode\n'
fi

printf 'SKIP signatures cosign verification of the images is not performed here (see the publish-docker job of the release run)\n'
printf 'END %s ok=%d failed=%d errors=%d\n' "$(date -u +%FT%TZ)" "$N_OK" "$N_FAIL" "$N_ERR"

if [ "$N_ERR" -gt 0 ]; then printf 'ARTIFACTS_INCOMPLETE\n'; exit 4; fi
if [ "$N_FAIL" -gt 0 ]; then printf 'ARTIFACTS_INCOMPLETE\n'; exit 1; fi
printf 'ARTIFACTS_OK\n'
exit 0
