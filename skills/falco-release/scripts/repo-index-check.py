#!/usr/bin/env python3
"""repo-index-check.py - check that the apt and rpm repository indexes list a Falco version.

Purpose:
  After a release, the deb and rpm packages are only installable through apt/dnf once the
  repository metadata has been regenerated and synced. This script fetches
    - dists/stable/main/binary-<arch>/Packages for every deb arch (default amd64, arm64)
    - repodata/repomd.xml and the "primary" metadata it points to, for every rpm arch
      (default x86_64, aarch64)
  and reports whether the requested version is listed.
  Prints one line per index:  OK|MISSING|ERROR <what> <detail>
  and a final token: INDEXES_OK or INDEXES_INCOMPLETE (always the last line).

Usage:
  repo-index-check.py --version <v> [--mode stable|dev] [--base-url URL] [--package NAME]
                      [--arch amd64 --arch arm64] [--timeout SEC]

Exit codes:
  0  the version is listed in every checked index
  1  at least one index does not list it
  2  usage error
  4  a network error prevented at least one check

Read-only (HTTP GET only).

Expectations come from falcosecurity/falco:
  scripts/publish-deb   repo deb|deb-dev, suite "stable", component "main", apt-ftparchive Packages per binary-<arch>
  scripts/publish-rpm   repo rpm|rpm-dev, createrepo metadata under repodata/
  .github/workflows/release.yaml   bucket_suffix "-dev" for pre-releases ("dev" mode here)

Example:
  repo-index-check.py --version 0.45.0 --mode stable
"""
import argparse
import gzip
import lzma
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

# ---- project defaults (overridable by flags) -------------------------------------------------------
DEFAULT_BASE_URL = "https://download.falco.org"   # CloudFront front of s3://falco-distribution (scripts/publish-*)
DEFAULT_PACKAGE = "falco"
DEFAULT_DEB_ARCHES = ["amd64", "arm64"]           # debian arch names used by publish-deb (binary-<arch>)
DEFAULT_TIMEOUT = 60

DEB_TO_RPM_ARCH = {"amd64": "x86_64", "arm64": "aarch64"}
RPM_TO_DEB_ARCH = {v: k for k, v in DEB_TO_RPM_ARCH.items()}
NS_REPO = "{http://linux.duke.edu/metadata/repo}"
NS_COMMON = "{http://linux.duke.edu/metadata/common}"


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def fetch(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": "repo-index-check"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def build_parser():
    p = argparse.ArgumentParser(
        prog="repo-index-check.py",
        description="Check that the apt and rpm repository indexes list a Falco version.",
        epilog="Exit codes: 0 all listed; 1 not listed somewhere; 2 usage; 4 network error. "
               "Example: repo-index-check.py --version 0.45.0 --mode stable",
    )
    p.add_argument("--version", required=True, help="Falco version, e.g. 0.45.0 or 0.45.0-rc2")
    p.add_argument("--mode", choices=["stable", "dev"], default="stable",
                   help="stable = deb/ and rpm/ repos; dev = deb-dev/ and rpm-dev/ (pre-releases)")
    p.add_argument("--base-url", default=DEFAULT_BASE_URL, help=f"download bucket base URL (default {DEFAULT_BASE_URL})")
    p.add_argument("--package", default=DEFAULT_PACKAGE, help=f"package name (default {DEFAULT_PACKAGE})")
    p.add_argument("--arch", action="append", default=[],
                   help="repeatable; deb arch (amd64, arm64) or rpm arch (x86_64, aarch64); default amd64 and arm64")
    p.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help=f"per-request timeout in seconds (default {DEFAULT_TIMEOUT})")
    return p


def parse_deb_packages(text):
    """Return a list of (package, version, architecture) tuples from a Packages file."""
    out = []
    stanza = {}
    for line in text.splitlines() + [""]:
        if not line.strip():
            if stanza:
                out.append((stanza.get("Package", ""), stanza.get("Version", ""), stanza.get("Architecture", "")))
                stanza = {}
            continue
        if line[0] in " \t":
            continue
        key, sep, val = line.partition(":")
        if sep:
            stanza[key.strip()] = val.strip()
    return out


def main():
    args = build_parser().parse_args()
    if not args.version or any(c not in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-+~" for c in args.version):
        print("error: --version has unexpected characters", file=sys.stderr)
        return 2
    if args.timeout <= 0:
        print("error: --timeout must be positive", file=sys.stderr)
        return 2

    deb_arches = []
    for a in (args.arch or DEFAULT_DEB_ARCHES):
        if a in DEB_TO_RPM_ARCH:
            deb_arches.append(a)
        elif a in RPM_TO_DEB_ARCH:
            deb_arches.append(RPM_TO_DEB_ARCH[a])
        else:
            print(f"error: unknown arch {a} (use amd64, arm64, x86_64 or aarch64)", file=sys.stderr)
            return 2
    rpm_arches = [DEB_TO_RPM_ARCH[a] for a in deb_arches]

    suffix = "-dev" if args.mode == "dev" else ""
    base = args.base_url.rstrip("/") + "/packages"
    deb_repo = f"{base}/deb{suffix}"
    rpm_repo = f"{base}/rpm{suffix}"
    v = args.version
    pkg = args.package

    print(f"START {now()} repo-index-check package={pkg} version={v} mode={args.mode} base={base}")
    n_fail = 0
    n_err = 0

    # ---- apt: one Packages index per arch (publish-deb: dists/stable/main/binary-<arch>/Packages) ----
    for arch in deb_arches:
        rel = f"deb{suffix}/dists/stable/main/binary-{arch}/Packages"
        url = f"{deb_repo}/dists/stable/main/binary-{arch}/Packages"
        try:
            body = fetch(url, args.timeout).decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code in (403, 404):
                print(f"MISSING deb {arch} {rel} http={e.code}")
                n_fail += 1
            else:
                print(f"ERROR deb {arch} {rel} http={e.code}")
                n_err += 1
            continue
        except (urllib.error.URLError, OSError) as e:
            print(f"ERROR deb {arch} {rel} network error: {e}")
            n_err += 1
            continue
        stanzas = parse_deb_packages(body)
        versions = [ver for (name, ver, _a) in stanzas if name == pkg]
        if v in versions:
            print(f"OK deb {arch} {pkg} {v} listed in {rel} (entries={len(versions)} last={versions[-3:]})")
        else:
            print(f"MISSING deb {arch} {pkg} {v} not in {rel} (entries={len(versions)} last={versions[-3:]})")
            n_fail += 1

    # ---- rpm: repomd.xml -> primary metadata (publish-rpm: createrepo, repodata/) ----------------------
    rel = f"rpm{suffix}/repodata/repomd.xml"
    primary_entries = None
    try:
        repomd = ET.fromstring(fetch(f"{rpm_repo}/repodata/repomd.xml", args.timeout))
        href = None
        for data in repomd.iter(NS_REPO + "data"):
            if data.get("type") == "primary":
                loc = data.find(NS_REPO + "location")
                if loc is not None:
                    href = loc.get("href")
        if not href:
            print(f"ERROR rpm {rel} has no primary location")
            n_err += 1
        else:
            raw = fetch(f"{rpm_repo}/{href}", args.timeout)
            if href.endswith(".gz"):
                raw = gzip.decompress(raw)
            elif href.endswith(".xz"):
                raw = lzma.decompress(raw)
            primary = ET.fromstring(raw)
            primary_entries = []
            for p in primary.iter(NS_COMMON + "package"):
                name = p.findtext(NS_COMMON + "name") or ""
                arch = p.findtext(NS_COMMON + "arch") or ""
                ver_el = p.find(NS_COMMON + "version")
                ver = ver_el.get("ver") if ver_el is not None else ""
                primary_entries.append((name, ver, arch, href))
    except urllib.error.HTTPError as e:
        if e.code in (403, 404):
            print(f"MISSING rpm {rel} http={e.code}")
            n_fail += 1
        else:
            print(f"ERROR rpm {rel} http={e.code}")
            n_err += 1
    except (urllib.error.URLError, OSError, ET.ParseError, EOFError, lzma.LZMAError) as e:
        print(f"ERROR rpm {rel} {type(e).__name__}: {e}")
        n_err += 1

    if primary_entries is not None:
        # RPM versions cannot contain "-": the RPM generator (cmake/modules/CPackConfig.cmake:88 passes FALCO_VERSION)
        # publishes pre-releases as e.g. 0.45.0_rc4, so accept both spellings.
        rpm_versions = {v, v.replace("-", "_")}
        for arch in rpm_arches:
            versions = [ver for (name, ver, a, _h) in primary_entries if name == pkg and a == arch]
            href = primary_entries[0][3] if primary_entries else "primary"
            if rpm_versions & set(versions):
                print(f"OK rpm {arch} {pkg} {v} listed in rpm{suffix}/{href} (entries={len(versions)} last={versions[-3:]})")
            else:
                print(f"MISSING rpm {arch} {pkg} {v} not in rpm{suffix}/{href} (entries={len(versions)} last={versions[-3:]})")
                n_fail += 1

    print(f"END {now()} failed={n_fail} errors={n_err}")
    if n_err:
        print("INDEXES_INCOMPLETE")
        return 4
    if n_fail:
        print("INDEXES_INCOMPLETE")
        return 1
    print("INDEXES_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
