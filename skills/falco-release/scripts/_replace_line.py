#!/usr/bin/env python3
"""_replace_line.py - exact-line replacement helper for pin-pr.sh (no sed).

Two modes:

  set-var   rewrite the value of a CMake `set(NAME "value")` assignment
            _replace_line.py set-var --file <abs> --var <NAME> --new <value> [--old <value>] [--keep-prefix]

            Handles both layouts found in falcosecurity/falco cmake modules:
              set(FALCOCTL_VERSION "0.13.0")                      single line
              set(FALCOSECURITY_LIBS_CHECKSUM                      multi line: value on the next
                  "SHA256=272a5a0c..."                             non-blank line
              )
            When the variable is assigned more than once (e.g. `set(DRIVER_VERSION "0.0.0-local")`
            in the local-source branch and the pinned value further down, or the amd64/arm64
            `FALCOCTL_HASH` pair), pass --old <current value> to select the single line to edit;
            --old matches the whole value or the part after `SHA256=`. --keep-prefix keeps an
            existing `PREFIX=` (e.g. `SHA256=`) in front of the new value.

  exact     replace one exact line
            _replace_line.py exact --file <abs> --old-line <text> --new-line <text>

Exit codes: 0 replaced (prints `REPLACED <var> line <n>: <old> -> <new>`), 2 usage,
3 the target line is missing or not unique (nothing written).
"""
import argparse
import os
import re
import sys

EXIT_USAGE, EXIT_ABORT = 2, 3


def fail(code, msg):
    print(("ABORT: " if code == EXIT_ABORT else "usage error: ") + msg, file=sys.stderr)
    sys.exit(code)


def read_lines(path):
    with open(path, encoding="utf-8", newline="") as fh:
        data = fh.read()
    nl = "\r\n" if "\r\n" in data else "\n"
    return data.split(nl), nl


def write_lines(path, lines, nl):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(nl.join(lines))


def candidates(lines, var):
    """Return [(value_line_index, indent_prefix, value)] for every set(VAR ...) assignment."""
    one = re.compile(r'^(\s*set\(\s*' + re.escape(var) + r'\s+")([^"]*)("\s*\)\s*)$')
    head = re.compile(r'^\s*set\(\s*' + re.escape(var) + r'\s*$')
    val = re.compile(r'^(\s*")([^"]*)("\s*)$')
    out = []
    for i, line in enumerate(lines):
        m = one.match(line)
        if m:
            out.append((i, m.group(1), m.group(2), m.group(3)))
            continue
        if head.match(line):
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines):
                mv = val.match(lines[j])
                if mv:
                    out.append((j, mv.group(1), mv.group(2), mv.group(3)))
    return out


def value_matches(value, old):
    return value == old or value.split("=", 1)[-1] == old


def main():
    p = argparse.ArgumentParser(prog="_replace_line.py", description=__doc__.split("\n\n")[0])
    sub = p.add_subparsers(dest="mode", required=True)
    s = sub.add_parser("set-var")
    s.add_argument("--file", required=True)
    s.add_argument("--var", required=True)
    s.add_argument("--new", required=True)
    s.add_argument("--old")
    s.add_argument("--keep-prefix", action="store_true")
    e = sub.add_parser("exact")
    e.add_argument("--file", required=True)
    e.add_argument("--old-line", required=True)
    e.add_argument("--new-line", required=True)
    a = p.parse_args()
    if not os.path.isabs(a.file):
        fail(EXIT_USAGE, f"--file must be absolute: {a.file}")
    if not os.path.isfile(a.file):
        fail(EXIT_USAGE, f"file not found: {a.file}")
    lines, nl = read_lines(a.file)

    if a.mode == "exact":
        hits = [i for i, l in enumerate(lines) if l == a.old_line]
        if len(hits) != 1:
            fail(EXIT_ABORT, f"exact line matches {len(hits)} times (need 1): {a.old_line!r}")
        if a.old_line == a.new_line:
            fail(EXIT_ABORT, "old and new line are identical")
        lines[hits[0]] = a.new_line
        write_lines(a.file, lines, nl)
        print(f"REPLACED line {hits[0] + 1}: {a.old_line!r} -> {a.new_line!r}")
        return

    cands = candidates(lines, a.var)
    if a.old is not None:
        cands = [c for c in cands if value_matches(c[2], a.old)]
    if len(cands) != 1:
        found = "; ".join(f"line {c[0] + 1}: {c[2]}" for c in cands) or "none"
        hint = "" if a.old is not None else " (pass --old <current value> to select one)"
        fail(EXIT_ABORT, f"set({a.var} ...) candidates: {len(cands)} (need 1){hint}: {found}")
    idx, pre, old_value, post = cands[0]
    new_value = a.new
    if a.keep_prefix and "=" in old_value:
        new_value = old_value.split("=", 1)[0] + "=" + a.new
    if new_value == old_value:
        fail(EXIT_ABORT, f"set({a.var}) already holds {new_value!r}")
    lines[idx] = pre + new_value + post
    write_lines(a.file, lines, nl)
    print(f"REPLACED {a.var} line {idx + 1}: {old_value} -> {new_value}")


if __name__ == "__main__":
    main()
