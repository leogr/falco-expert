#!/usr/bin/env bash
# plugin-artifacts-check.sh - verify the published artifacts of a falcosecurity/plugins plugin release.
#
# Purpose:
#   For one plugin version:
#     - download the stable tarball of every arch twice, require the two copies to be identical,
#       print the SHA256 of each download (these are the hashes used for version pins)
#     - list the tarball contents, require the plugin shared object, and check its ELF machine
#       matches the arch (readelf, or `file` as fallback)
#     - resolve the OCI tags the registry tool pushes (full version, major.minor, major, latest for
#       a stable version; only the full version for a pre-release) and require one identical
#       multi-platform index digest across them, with linux/amd64 and linux/arm64 present
#   Prints one line per check:  OK|MISSING|MISMATCH|SKIP|ERROR <what> <detail>
#   and a final token: PLUGIN_ARTIFACTS_OK or PLUGIN_ARTIFACTS_INCOMPLETE (always the last line).
#
# Usage:
#   plugin-artifacts-check.sh --plugin <name> --version <v> --workdir </abs/dir>
#                             [--arch x86_64 --arch aarch64] [--lib-name lib<name>.so]
#                             [--base-url URL] [--registry HOST] [--oci-prefix PATH] [--timeout SEC]
#
# Exit codes:
#   0  every check passed
#   1  at least one MISSING or MISMATCH
#   2  usage error
#   4  a network or API error prevented at least one check
#
# Read-only. Only curl GET requests; the anonymous ghcr.io bearer token is written to a header
# file inside --workdir and passed with `curl -H @file`, never on the command line.
#
# Expectations come from falcosecurity/plugins:
#   Makefile (package/% target)                          tarball name <name>-<version>-linux-<arch>.tar.gz
#   .github/workflows/release.yml                        tag plugins/<name>/v<version>, suffix "stable"
#   .github/workflows/reusable_publish_packages.yaml     s3://falco-distribution/plugins/stable/ (served by download.falco.org)
#   .github/workflows/reusable-publish-oci-artifacts.yaml  REGISTRY ghcr.io, registry tool update-oci-registry
#   build/registry/pkg/oci/oci.go (tagsFromVersion)      tags: latest, <major>, <major>.<minor>, <full>; pre-release: <full> only
#
# Example:
#   plugin-artifacts-check.sh --plugin container --version 0.7.4 --workdir /tmp/plugin-container-0.7.4
set -euo pipefail

# ---- project defaults (overridable by flags) ---------------------------------------------------
DEFAULT_BASE_URL="https://download.falco.org"                 # CloudFront front of s3://falco-distribution (reusable_publish_packages.yaml)
DEFAULT_REGISTRY="ghcr.io"                                    # REGISTRY env in reusable-publish-oci-artifacts.yaml
DEFAULT_OCI_PREFIX="falcosecurity/plugins/plugin"             # ref layout ghcr.io/falcosecurity/plugins/plugin/<name> (registry.yaml consumers, e.g. charts values)
DEFAULT_TIMEOUT=60
ACCEPT_INDEX="application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json"

usage() {
  cat <<'EOF'
Usage: plugin-artifacts-check.sh --plugin <name> --version <v> --workdir </abs/dir>
                                 [--arch x86_64 --arch aarch64] [--lib-name lib<name>.so]
                                 [--base-url URL] [--registry HOST] [--oci-prefix PATH] [--timeout SEC]

Verify the stable tarballs (downloaded twice, SHA256 printed, contents and ELF machine checked)
and the OCI tags (identical multi-platform digest across version, major.minor, major, latest)
of a plugin release.
  --plugin     plugin name as in the tag plugins/<name>/v<version>
  --version    plugin version, with or without the leading "v"
  --workdir    absolute directory for downloads (created if missing)
  --arch       repeatable, default: x86_64 and aarch64
  --lib-name   shared object expected inside the tarball (default: lib<name>.so)
  --base-url   download bucket base URL (default: https://download.falco.org)
  --registry   OCI registry host (default: ghcr.io)
  --oci-prefix repository prefix under the registry (default: falcosecurity/plugins/plugin)
  --timeout    per-request timeout in seconds (default: 60)

Output: one "OK|MISSING|MISMATCH|SKIP|ERROR <what> <detail>" line per check; last line is
PLUGIN_ARTIFACTS_OK or PLUGIN_ARTIFACTS_INCOMPLETE.
Exit codes: 0 all OK; 1 a check failed; 2 usage; 4 network/API error prevented a check.
Example: plugin-artifacts-check.sh --plugin container --version 0.7.4 --workdir /tmp/plugin-container-0.7.4
EOF
}

die_usage() { printf 'error: %s\n\n' "$1" >&2; usage >&2; exit 2; }

PLUGIN="" VERSION="" WORKDIR="" LIB_NAME="" BASE_URL="$DEFAULT_BASE_URL" REGISTRY="$DEFAULT_REGISTRY"
OCI_PREFIX="$DEFAULT_OCI_PREFIX" TIMEOUT="$DEFAULT_TIMEOUT"
ARCHES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --plugin) [ $# -ge 2 ] || die_usage "--plugin needs a value"; PLUGIN="$2"; shift 2 ;;
    --version) [ $# -ge 2 ] || die_usage "--version needs a value"; VERSION="$2"; shift 2 ;;
    --workdir) [ $# -ge 2 ] || die_usage "--workdir needs a value"; WORKDIR="$2"; shift 2 ;;
    --arch) [ $# -ge 2 ] || die_usage "--arch needs a value"; ARCHES+=("$2"); shift 2 ;;
    --lib-name) [ $# -ge 2 ] || die_usage "--lib-name needs a value"; LIB_NAME="$2"; shift 2 ;;
    --base-url) [ $# -ge 2 ] || die_usage "--base-url needs a value"; BASE_URL="${2%/}"; shift 2 ;;
    --registry) [ $# -ge 2 ] || die_usage "--registry needs a value"; REGISTRY="$2"; shift 2 ;;
    --oci-prefix) [ $# -ge 2 ] || die_usage "--oci-prefix needs a value"; OCI_PREFIX="${2#/}"; OCI_PREFIX="${OCI_PREFIX%/}"; shift 2 ;;
    --timeout) [ $# -ge 2 ] || die_usage "--timeout needs a value"; TIMEOUT="$2"; shift 2 ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[ -n "$PLUGIN" ] || die_usage "--plugin is required"
[ -n "$VERSION" ] || die_usage "--version is required"
[ -n "$WORKDIR" ] || die_usage "--workdir is required"
case "$WORKDIR" in /*) ;; *) die_usage "--workdir must be an absolute path" ;; esac
case "$PLUGIN" in *[!a-z0-9_-]*|'') die_usage "--plugin has unexpected characters" ;; esac
case "$TIMEOUT" in ''|*[!0-9]*) die_usage "--timeout must be an integer" ;; esac
VERSION="${VERSION#v}"
if [[ "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"; MINOR="${BASH_REMATCH[2]}"; PRERELEASE="${BASH_REMATCH[4]}"
else
  die_usage "--version is not a semantic version: $VERSION"
fi
[ "${#ARCHES[@]}" -gt 0 ] || ARCHES=(x86_64 aarch64)
for a in "${ARCHES[@]}"; do
  case "$a" in x86_64|aarch64) ;; *) die_usage "--arch must be x86_64 or aarch64 (got $a)" ;; esac
done
[ -n "$LIB_NAME" ] || LIB_NAME="lib$PLUGIN.so"
for tool in curl jq tar sha256sum cmp; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'error: %s is required\n' "$tool" >&2; exit 2; }
done

mkdir -p "$WORKDIR"
ERRLOG="$WORKDIR/http-errors.log"
: > "$ERRLOG"

N_OK=0 N_FAIL=0 N_ERR=0
ok()   { N_OK=$((N_OK+1));     printf 'OK %s %s\n' "$1" "$2"; }
fail() { N_FAIL=$((N_FAIL+1)); printf '%s %s %s\n' "$1" "$2" "$3"; }
err()  { N_ERR=$((N_ERR+1));   printf 'ERROR %s %s\n' "$1" "$2"; }

# one curl per line; 429/5xx answers are retried after 2, 5 and 10 seconds (registries throttle anonymous bursts)
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
get_manifest_code() { # $1 url  $2 body-out  $3 auth header file  $4 response headers out -> http code
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

expected_machine() { # $1 arch -> readelf Machine substring
  case "$1" in
    x86_64) printf 'X86-64' ;;
    aarch64) printf 'AArch64' ;;
  esac
}
expected_file_machine() { # $1 arch -> `file` output substring
  case "$1" in
    x86_64) printf 'x86-64' ;;
    aarch64) printf 'aarch64' ;;
  esac
}

printf 'START %s plugin-artifacts-check plugin=%s version=%s workdir=%s\n' "$(date -u +%FT%TZ)" "$PLUGIN" "$VERSION" "$WORKDIR"

# ---- tarballs -------------------------------------------------------------------------------------
for arch in "${ARCHES[@]}"; do
  f="$PLUGIN-$VERSION-linux-$arch.tar.gz"                       # plugins/Makefile package/% target
  url="$BASE_URL/plugins/stable/$f"                             # reusable_publish_packages.yaml, suffix stable
  p1="$WORKDIR/$f"; p2="$WORKDIR/$f.copy2"
  code=$(get_code "$url" "$p1")
  case "$code" in
    200) ;;
    404|403) fail MISSING "tarball plugins/stable/$f" "http=$code"; continue ;;
    000) err "tarball plugins/stable/$f" "network error (download 1)"; continue ;;
    *) err "tarball plugins/stable/$f" "http=$code (download 1)"; continue ;;
  esac
  code=$(get_code "$url" "$p2")
  case "$code" in
    200) ;;
    000) err "tarball plugins/stable/$f" "network error (download 2)"; continue ;;
    *) err "tarball plugins/stable/$f" "http=$code (download 2)"; continue ;;
  esac
  sha1=$(sha256sum "$p1" | cut -d' ' -f1)
  sha2=$(sha256sum "$p2" | cut -d' ' -f1)
  size=$(stat -c %s "$p1")
  if cmp -s "$p1" "$p2"; then
    ok "tarball-two-downloads-identical $f" "bytes=$size sha256=$sha1 sha256(copy2)=$sha2"
  else
    fail MISMATCH "tarball-two-downloads-identical $f" "sha256(download1)=$sha1 sha256(download2)=$sha2"
  fi
  if tar -tzf "$p1" > "$WORKDIR/$f.list" 2>"$WORKDIR/$f.tar.err"; then
    contents=$(tr '\n' ' ' < "$WORKDIR/$f.list")
    if grep -qxF -e "$LIB_NAME" -e "./$LIB_NAME" "$WORKDIR/$f.list"; then
      ok "tarball-contents $f" "$contents"
    else
      fail MISMATCH "tarball-contents $f" "$LIB_NAME not found; contents: $contents"
      continue
    fi
  else
    fail MISMATCH "tarball-contents $f" "not a readable tar.gz: $(head -c 200 "$WORKDIR/$f.tar.err")"
    continue
  fi
  xdir="$WORKDIR/extract-$arch"
  mkdir -p "$xdir"
  if ! tar -xzf "$p1" -C "$xdir" 2>"$WORKDIR/$f.extract.err"; then
    fail MISMATCH "elf-machine $f" "extraction failed: $(head -c 200 "$WORKDIR/$f.extract.err")"
    continue
  fi
  lib=$(find "$xdir" -type f -name "$LIB_NAME" | head -n1)
  if [ -z "$lib" ]; then
    fail MISMATCH "elf-machine $f" "$LIB_NAME missing after extraction"
    continue
  fi
  if command -v readelf >/dev/null 2>&1; then
    machine=$(readelf -h "$lib" 2>/dev/null | awk -F: '/Machine:/ {sub(/^[ \t]+/, "", $2); print $2}')
    want=$(expected_machine "$arch")
    case "$machine" in
      *"$want"*) ok "elf-machine $f" "$LIB_NAME machine=$machine" ;;
      *) fail MISMATCH "elf-machine $f" "$LIB_NAME machine=$machine expected~$want" ;;
    esac
  elif command -v file >/dev/null 2>&1; then
    desc=$(file -b "$lib")
    want=$(expected_file_machine "$arch")
    case "$desc" in
      *"$want"*) ok "elf-machine $f" "$LIB_NAME file=$desc" ;;
      *) fail MISMATCH "elf-machine $f" "$LIB_NAME file=$desc expected~$want" ;;
    esac
  else
    printf 'SKIP elf-machine %s neither readelf nor file is installed\n' "$f"
  fi
done

# ---- OCI tags -------------------------------------------------------------------------------------
REPO_PATH="$OCI_PREFIX/$PLUGIN"
if [ -n "$PRERELEASE" ]; then
  TAGS=("$VERSION")                                            # oci.go tagsFromVersion: pre-release gets only the full version
else
  TAGS=("$VERSION" "$MAJOR.$MINOR" "$MAJOR" "latest")          # oci.go tagsFromVersion: latest, major, major.minor, full
fi

tokf="$WORKDIR/oci-token.json"
hdrf="$WORKDIR/oci-auth.hdr"
code=$(get_code "https://$REGISTRY/token?scope=repository:$REPO_PATH:pull&service=$REGISTRY" "$tokf")
OCI_READY=0
if [ "$code" = "200" ]; then
  tok=$(jq -r '.token // .access_token // empty' "$tokf")
  if [ -n "$tok" ]; then
    ( umask 077; printf 'Authorization: Bearer %s\n' "$tok" > "$hdrf" )
    OCI_READY=1
  fi
fi
if [ "$OCI_READY" -eq 0 ]; then
  err "oci-token $REGISTRY/$REPO_PATH" "anonymous token request failed (http=$code)"
else
  declare -A DIG=()
  VERSION_PLATS=""
  for t in "${TAGS[@]}"; do
    body="$WORKDIR/oci-manifest-$t.json"; resp="$WORKDIR/oci-manifest-$t.hdr"
    what="oci $REGISTRY/$REPO_PATH:$t"
    code=$(get_manifest_code "https://$REGISTRY/v2/$REPO_PATH/manifests/$t" "$body" "$hdrf" "$resp")
    case "$code" in
      200) ;;
      404) fail MISSING "$what" "http=404"; continue ;;
      000) err "$what" "network error"; continue ;;
      *) err "$what" "http=$code"; continue ;;
    esac
    dg=$(header_value "$resp" docker-content-digest)
    if [ -z "$dg" ]; then dg="sha256:$(sha256sum "$body" | cut -d' ' -f1)"; fi
    mt=$(jq -r '.mediaType // "unknown"' "$body")
    plats=$(jq -r '[.manifests[]? | select(.platform.os == "linux") | .platform.architecture] | sort | join(",")' "$body")
    if [ -z "$plats" ]; then
      fail MISMATCH "$what" "not a multi-platform index (mediaType=$mt) digest=${dg:-?}"
      continue
    fi
    DIG["$t"]="$dg"
    if [ "$t" = "$VERSION" ]; then VERSION_PLATS="$plats"; fi
    ok "$what" "digest=${dg:-?} mediaType=$mt platforms=$plats"
  done
  if [ -n "$VERSION_PLATS" ]; then
    if [ "$VERSION_PLATS" = "amd64,arm64" ]; then
      ok "oci-platforms $REPO_PATH:$VERSION" "linux/amd64 and linux/arm64 present"
    else
      fail MISMATCH "oci-platforms $REPO_PATH:$VERSION" "platforms=$VERSION_PLATS expected=amd64,arm64"
    fi
  fi
  if [ "${#DIG[@]}" -eq "${#TAGS[@]}" ]; then
    uniq_count=$(printf '%s\n' "${DIG[@]}" | sort -u | wc -l)
    if [ "$uniq_count" -eq 1 ]; then
      ok "oci-tags-identical-digest $REPO_PATH" "tags=$(IFS=,; printf '%s' "${TAGS[*]}") digest=${DIG[$VERSION]}"
    else
      detail=""
      for t in "${TAGS[@]}"; do detail="$detail $t=${DIG[$t]}"; done
      fail MISMATCH "oci-tags-identical-digest $REPO_PATH" "digests differ:$detail"
    fi
  else
    printf 'SKIP oci-tags-identical-digest %s not every tag resolved\n' "$REPO_PATH"
  fi
fi

printf 'END %s ok=%d failed=%d errors=%d\n' "$(date -u +%FT%TZ)" "$N_OK" "$N_FAIL" "$N_ERR"
if [ "$N_ERR" -gt 0 ]; then printf 'PLUGIN_ARTIFACTS_INCOMPLETE\n'; exit 4; fi
if [ "$N_FAIL" -gt 0 ]; then printf 'PLUGIN_ARTIFACTS_INCOMPLETE\n'; exit 1; fi
printf 'PLUGIN_ARTIFACTS_OK\n'
exit 0
