#!/usr/bin/env python3
"""drivers-published-count.py - count the prebuilt drivers published for a driver version.

Purpose:
  List the objects under driver/<driver-version>/<arch>/ on the distribution bucket (S3 ListObjectsV2
  with continuation-token pagination) and count them per target distro and per type
  (kmod ".ko", eBPF ".o"). When --configs-dir points at a local checkout of the DBG configs, print the
  gap between the config files of each target and the published drivers.
  Prints:  COUNT <arch> total=... ko=... o=... newest=...
           COUNT <arch> <target> ko=<n> o=<n>            (one per target)
           GAP   <arch> <target> configs=<files> configs_module=<m> configs_probe=<p> ko=<n> o=<n> missing_ko=<m-n> missing_o=<p-n>
                 (with --configs-dir; module/probe = how many configs declare that output type)
  and a final token DRIVERS_COUNTED (always the last line). Exit 0 unless usage/network error.

Usage:
  drivers-published-count.py --driver-version <X.Y.Z+driver> --arch <x86_64|aarch64> [--arch ...]
                             [--configs-dir </abs/path>] [--bucket-url URL] [--prefix driver]
                             [--driver-name falco] [--timeout SEC]

Exit codes:
  0  counts printed (informational script; gaps do not fail the run)
  2  usage error
  4  the bucket listing could not be completed

Read-only (HTTP GET on the public bucket listing).

Sources of the expectations:
  falcosecurity/falco scripts/publish-*, .github/workflows/reusable_publish_packages.yaml   bucket falco-distribution, region eu-west-1
  falcosecurity/dbg-go pkg/root/constants.go   output naming <driver>_<target>_<kernelrelease>_<kernelversion>.{ko,o}
  falcosecurity/test-infra driverkit/config/<driver-version>/<arch>/<target>_<kernelrelease>_<kernelversion>.yaml
  Note: a config may build only the kmod or only the probe (its "output" map); the gap is computed
  against the configs that declare each output type. Published drivers are never deleted, so the
  bucket may hold more drivers than the current configs.

Example:
  drivers-published-count.py --driver-version 11.0.0+driver --arch x86_64 --arch aarch64
"""
import argparse
import collections
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

# ---- project defaults (overridable by flags) -------------------------------------------------------
DEFAULT_BUCKET_URL = "https://falco-distribution.s3-eu-west-1.amazonaws.com"  # bucket falco-distribution (scripts/publish-*), region eu-west-1 (reusable_publish_packages.yaml)
DEFAULT_PREFIX = "driver"                                                    # driver/<version>/<arch>/ (specs: download.falco.org/driver/{version}/{arch}/...)
DEFAULT_DRIVER_NAME = "falco"                                                # dbg-go --driver-name default
DEFAULT_TIMEOUT = 60
S3NS = "{http://s3.amazonaws.com/doc/2006-03-01/}"


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def list_keys(bucket_url, prefix, timeout):
    """Yield (key, last_modified) for every object under prefix, following continuation tokens."""
    token = None
    while True:
        q = {"list-type": "2", "prefix": prefix, "max-keys": "1000"}
        if token:
            q["continuation-token"] = token
        url = bucket_url.rstrip("/") + "/?" + urllib.parse.urlencode(q)
        req = urllib.request.Request(url, headers={"User-Agent": "drivers-published-count"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            root = ET.fromstring(resp.read())
        for c in root.iter(S3NS + "Contents"):
            yield c.findtext(S3NS + "Key") or "", c.findtext(S3NS + "LastModified") or ""
        if (root.findtext(S3NS + "IsTruncated") or "false").lower() != "true":
            break
        token = root.findtext(S3NS + "NextContinuationToken")
        if not token:
            break


def build_parser():
    p = argparse.ArgumentParser(
        prog="drivers-published-count.py",
        description="Count the prebuilt drivers published for a driver version, per target and type.",
        epilog="Exit codes: 0 counted; 2 usage; 4 listing error. "
               "Example: drivers-published-count.py --driver-version 11.0.0+driver --arch x86_64",
    )
    p.add_argument("--driver-version", required=True, help="driver version directory, e.g. 11.0.0+driver")
    p.add_argument("--arch", action="append", default=[], help="repeatable: x86_64, aarch64 (at least one)")
    p.add_argument("--configs-dir", default=None,
                   help="absolute path to a local driverkit/config checkout (or a test-infra checkout) to compare against")
    p.add_argument("--bucket-url", default=DEFAULT_BUCKET_URL, help=f"S3 listing endpoint (default {DEFAULT_BUCKET_URL})")
    p.add_argument("--prefix", default=DEFAULT_PREFIX, help=f"key prefix before the driver version (default {DEFAULT_PREFIX})")
    p.add_argument("--driver-name", default=DEFAULT_DRIVER_NAME, help=f"driver file name prefix (default {DEFAULT_DRIVER_NAME})")
    p.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help=f"per-request timeout in seconds (default {DEFAULT_TIMEOUT})")
    return p


def config_counts(configs_dir, version, arch):
    """Return {target: Counter(files, module, probe)} or None when the directory is missing.

    A driverkit config declares what it builds under "output:" ("module:" for the kmod, "probe:" for the
    eBPF object); a target may build only one of them, so the gap is computed per output type.
    """
    base = configs_dir
    nested = os.path.join(configs_dir, "driverkit", "config")
    if os.path.isdir(nested):
        base = nested
    d = os.path.join(base, version, arch)
    if not os.path.isdir(d):
        return None, d
    c = collections.defaultdict(lambda: collections.Counter())
    for name in os.listdir(d):
        if not name.endswith(".yaml"):
            continue
        target = name.split("_", 1)[0]
        c[target]["files"] += 1
        try:
            with open(os.path.join(d, name), encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    s = line.strip()
                    if s.startswith("module:"):
                        c[target]["module"] += 1
                    elif s.startswith("probe:"):
                        c[target]["probe"] += 1
        except OSError:
            pass
    return c, d


def main():
    args = build_parser().parse_args()
    if not args.arch:
        print("error: at least one --arch is required", file=sys.stderr)
        return 2
    for a in args.arch:
        if a not in ("x86_64", "aarch64"):
            print(f"error: --arch must be x86_64 or aarch64 (got {a})", file=sys.stderr)
            return 2
    if not re.fullmatch(r"[0-9A-Za-z.+-]+", args.driver_version):
        print("error: --driver-version has unexpected characters", file=sys.stderr)
        return 2
    if args.configs_dir is not None and not os.path.isabs(args.configs_dir):
        print("error: --configs-dir must be an absolute path", file=sys.stderr)
        return 2
    if args.timeout <= 0:
        print("error: --timeout must be positive", file=sys.stderr)
        return 2

    v = args.driver_version
    key_re = re.compile(r"^" + re.escape(f"{args.prefix.strip('/')}/{v}/") + r"(?P<arch>[^/]+)/" + re.escape(args.driver_name) + r"_(?P<target>[a-z0-9-]+?)_.*\.(?P<ext>ko|o)$")

    print(f"START {now()} drivers-published-count driver-version={v} bucket={args.bucket_url} prefix={args.prefix}")
    n_err = 0
    for arch in args.arch:
        prefix = f"{args.prefix.strip('/')}/{v}/{arch}/"
        per_target = collections.defaultdict(lambda: collections.Counter())
        total = 0
        newest = ""
        unparsed = 0
        try:
            for key, lm in list_keys(args.bucket_url, prefix, args.timeout):
                total += 1
                if lm > newest:
                    newest = lm
                m = key_re.match(key)
                if not m or m.group("arch") != arch:
                    unparsed += 1
                    continue
                per_target[m.group("target")][m.group("ext")] += 1
        except (urllib.error.URLError, OSError, ET.ParseError) as e:
            print(f"ERROR {arch} listing {prefix} failed: {type(e).__name__}: {e}")
            n_err += 1
            continue
        ko = sum(c["ko"] for c in per_target.values())
        o = sum(c["o"] for c in per_target.values())
        print(f"COUNT {arch} total={total} ko={ko} o={o} unparsed={unparsed} newest={newest or 'n/a'} prefix={prefix}")
        for target in sorted(per_target):
            print(f"COUNT {arch} {target} ko={per_target[target]['ko']} o={per_target[target]['o']}")
        if args.configs_dir:
            cfg, d = config_counts(args.configs_dir, v, arch)
            if cfg is None:
                print(f"SKIP {arch} configs directory not found: {d}")
                continue
            for target in sorted(set(cfg) | set(per_target)):
                files = cfg[target]["files"] if target in cfg else 0
                cm = cfg[target]["module"] if target in cfg else 0
                cp = cfg[target]["probe"] if target in cfg else 0
                k = per_target[target]["ko"] if target in per_target else 0
                p = per_target[target]["o"] if target in per_target else 0
                print(f"GAP {arch} {target} configs={files} configs_module={cm} configs_probe={cp} ko={k} o={p} "
                      f"missing_ko={max(cm - k, 0)} missing_o={max(cp - p, 0)}")

    print(f"END {now()} errors={n_err}")
    print("DRIVERS_COUNTED")
    return 4 if n_err else 0


if __name__ == "__main__":
    sys.exit(main())
