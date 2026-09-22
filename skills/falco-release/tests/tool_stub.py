#!/usr/bin/env python3
"""Offline gh/curl/git fixtures. Unknown operations fail; nothing reaches a network."""
import json
import os
from pathlib import Path
import subprocess
import sys


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(99)


root = Path(os.environ["RELEASE_TEST_CASE"])
fixture = json.loads((root / "fixture.json").read_text())
tool = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "calls.jsonl").open("a") as log:
    log.write(json.dumps([tool, *args]) + "\n")


def value(flag):
    return args[args.index(flag) + 1]


def emit(doc):
    if "--jq" in args:
        result = subprocess.run(["jq", "-r", value("--jq")], input=json.dumps(doc), text=True)
        if result.returncode:
            sys.exit(result.returncode)
    else:
        print(json.dumps(doc))


if tool == "gh" and args[0] == "api":
    endpoint = next((arg for arg in args if arg.startswith(("repos/", "search/"))), None)
    response = fixture.get("api", {}).get(endpoint)
    if response is None:
        fail(f"unconfigured API: {args}")
    if "error" in response:
        fail(response["error"])
    if "sequence" in response:
        calls = [json.loads(line) for line in (root / "calls.jsonl").read_text().splitlines()]
        count = sum(endpoint in call for call in calls)
        emit(response["sequence"][min(count - 1, len(response["sequence"]) - 1)])
    elif "pages" in response:
        pages = response["pages"] if "--paginate" in args else response["pages"][:1]
        if "--slurp" in args:
            emit(pages)
        else:
            for page in pages:
                emit(page)
    else:
        emit(response["data"])
elif tool == "gh" and args[:2] == ["release", "create"]:
    (root / "publication.json").write_text(json.dumps(args))
    print("https://github.invalid/release")
elif tool == "gh" and args[:2] == ["release", "view"]:
    # Only supported gh release view fields; isLatest must cause a failure.
    fields = set(value("--json").split(","))
    if fields - {"tagName", "isPrerelease", "isDraft", "url"}:
        fail("unsupported release JSON fields")
    if not (root / "publication.json").exists():
        fail("release not created")
    emit(fixture["release"])
elif tool == "curl":
    response = fixture.get("http", {}).get(args[-1])
    if response is None:
        fail(f"unconfigured download: {args}")
    Path(value("-o")).write_text(json.dumps(response))
    Path(value("-D")).write_text("HTTP/1.1 200 OK\r\n\r\n")
    print("200", end="")
elif tool == "git" and args[-3:] == ["remote", "get-url", "origin"]:
    print("https://github.com/example/falco.git")
else:
    fail(f"unconfigured command: {tool} {args}")
