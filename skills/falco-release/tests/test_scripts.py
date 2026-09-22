#!/usr/bin/env python3
"""Behavioral regressions with offline command fixtures; keep artifacts in --workdir."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import quote_plus

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
STUB = Path(__file__).with_name("tool_stub.py").resolve()
TARGET, OTHER, TREE, DIFFERENT = (char * 40 for char in "abcd")
REPO, TAG, BRANCH = "example/falco", "0.45.0-rc1", "release/0.45.x"
WORKDIR = None
REAL_GIT = shutil.which("git")
GIT_FIXTURE_ENV = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1", "GIT_TEMPLATE_DIR": ""}


def data(value):
    return {"data": value}


def page(field, rows, total=None):
    return {"total_count": len(rows) if total is None else total, field: rows}


def job(conclusion="success"):
    return {"status": "completed", "conclusion": conclusion}


def run(sha=TARGET, rid=1, event="push"):
    return {"id": rid, "head_sha": sha, "event": event, **job()}


class Scripts(unittest.TestCase):
    def case(self, fixture=None):
        root = Path(tempfile.mkdtemp(prefix=self._testMethodName + "-", dir=WORKDIR))
        (root / "bin").mkdir()
        for name in ("gh", "curl", "git"):
            (root / "bin" / name).symlink_to(STUB)
        self.save(root, fixture or {})
        return root

    def save(self, root, fixture):
        (root / "fixture.json").write_text(json.dumps(fixture))

    def invoke(self, root, script, args, expected):
        env = {**os.environ, "PATH": str(root / "bin") + os.pathsep + os.environ["PATH"],
               "RELEASE_TEST_CASE": str(root), "GIT_TERMINAL_PROMPT": "0"}
        executable = "python3" if script.endswith(".py") else "bash"
        result = subprocess.run([executable, str(SCRIPTS / script), *map(str, args)],
                                env=env, capture_output=True, text=True, timeout=30)
        (root / "stdout.log").write_text(result.stdout)
        (root / "stderr.log").write_text(result.stderr)
        self.assertEqual(result.returncode, expected, f"{root}\n{result.stdout}\n{result.stderr}")
        return result.stdout

    def tag_fixture(self, repo=REPO, tag=TAG):
        prefix = "repos/" + repo
        return {"api": {
            f"{prefix}/git/ref/heads/{BRANCH}": data({"object": {"sha": TARGET}}),
            f"{prefix}/git/commits/{TARGET}": data({"tree": {"sha": TREE}}),
            f"{prefix}/git/commits/{OTHER}": data({"tree": {"sha": TREE}}),
            f"{prefix}/git/matching-refs/tags/{tag}": {"pages": [[]]},
            f"{prefix}/releases?per_page=100": {"pages": [[]]},
            f"{prefix}/actions/runs?head_sha={TARGET}&per_page=100": {"pages": [page("workflow_runs", [run()])]},
            f"{prefix}/actions/runs/1": data(run()),
            f"{prefix}/actions/runs/1/jobs?per_page=100": {"pages": [page("jobs", [job()])]},
            f"{prefix}/commits/{TARGET}/check-runs?per_page=100": {"pages": [page("check_runs", [])]},
            f"{prefix}/git/ref/tags/{tag}": data({"object": {"type": "commit", "sha": TARGET}}),
            f"{prefix}/pulls/7": data({"head": {"sha": OTHER}}),
        }, "release": {"tagName": tag, "isPrerelease": True, "isDraft": False, "url": "https://github.invalid/release"}}

    def tag(self, fixture=None, extra=(), expected=0, repo=REPO, tag=TAG):
        root = self.case(fixture if fixture is not None else self.tag_fixture(repo, tag))
        output = self.invoke(root, "gated-tag.sh", ["--repo", repo, "--tag", tag,
                             "--target-sha", TARGET, "--branch", BRANCH, *extra], expected)
        if expected != 4 and (expected != 0 or "--apply" not in extra):
            self.assertFalse((root / "publication.json").exists(), root)
        return root, output

    def alternate_run(self, fixture, sha=OTHER, event="pull_request"):
        api = fixture["api"]
        api[f"repos/{REPO}/actions/runs?head_sha={TARGET}&per_page=100"] = {"pages": [page("workflow_runs", [])]}
        api[f"repos/{REPO}/actions/runs/2"] = data(run(sha, 2, event))
        api[f"repos/{REPO}/actions/runs/2/jobs?per_page=100"] = {"pages": [page("jobs", [job()])]}

    def test_final_tags_refused_before_any_api_call(self):
        tags = [("falco", "0.45.0"), ("libs", "0.26.0"), ("libs", "11.0.0+driver"),
                ("plugins", "plugins/container/v0.7.0"), ("rules", "falco-rules-5.0.0"),
                ("falcoctl", "v0.13.0"), ("charts", "falco-9.0.0-rc1"),
                ("falco", "0.45.0-rc0"), ("falco", "0.45.0-rc1+driver")]
        for repo, tag in tags:
            for extra in ([], ["--apply"]):
                with self.subTest(repo=repo, tag=tag, extra=extra):
                    root, _ = self.tag({}, extra, 5, "example/" + repo, tag)
                    self.assertFalse((root / "calls.jsonl").exists())

    def test_legacy_modes_and_explicit_final_refused(self):
        for extra in (["--satellite"], ["--no-release"], ["--final"],
                      ["--final", "--i-am-the-maintainer-and-ci-is-green"]):
            with self.subTest(extra=extra):
                self.tag({}, [*extra, "--apply"], 5)

    def test_candidate_tag_formats_and_dry_run(self):
        for repo, tag in [("falco", TAG), ("libs", "0.26.0-rc1"), ("libs", "11.0.0-rc2+driver"),
                          ("plugins", "plugins/container/v0.7.0-rc1"), ("rules", "falco-rules-5.0.0-rc1"),
                          ("falcoctl", "v0.13.0-rc1")]:
            with self.subTest(repo=repo):
                _, output = self.tag(repo="example/" + repo, tag=tag)
                self.assertIn("DRY_RUN_OK", output)

    def test_no_runs_does_not_bypass_ci(self):
        fixture = self.tag_fixture()
        self.alternate_run(fixture)
        for extra in ([], ["--allow-no-runs"]):
            with self.subTest(extra=extra):
                self.tag(fixture, extra, 3)

    def test_required_run_bound_to_target_tree(self):
        for tree, expected in [(DIFFERENT, 3), (TREE, 0)]:
            with self.subTest(tree=tree):
                fixture = self.tag_fixture()
                self.alternate_run(fixture)
                fixture["api"][f"repos/{REPO}/git/commits/{OTHER}"] = data({"tree": {"sha": tree}})
                self.tag(fixture, ["--allow-no-runs", "--require-run-id", "2"], expected)

    def test_pr_requires_current_head_ci(self):
        for sha, event, expected in [(OTHER, "pull_request", 0), (TARGET, "pull_request", 3), (OTHER, "push", 3)]:
            with self.subTest(sha=sha, event=event):
                fixture = self.tag_fixture()
                self.alternate_run(fixture, sha, event)
                self.tag(fixture, ["--allow-no-runs", "--require-run-id", "2", "--require-pr-tree-of", "7"], expected)

    def test_pr_run_must_be_explicitly_selected(self):
        fixture = self.tag_fixture()
        fixture["api"][f"repos/{REPO}/pulls/7"] = data({"head": {"sha": TARGET}})
        fixture["api"][f"repos/{REPO}/actions/runs/1"] = data(run(event="pull_request"))
        fixture["api"][f"repos/{REPO}/actions/runs/2"] = data(run(OTHER, 2))
        fixture["api"][f"repos/{REPO}/actions/runs/2/jobs?per_page=100"] = {"pages": [page("jobs", [job()])]}
        self.tag(fixture, ["--require-run-id", "2", "--require-pr-tree-of", "7"], 3)

    def test_empty_unfinished_or_failed_jobs_block(self):
        for jobs in ([], [job("failure")], [{"status": "in_progress", "conclusion": None}]):
            with self.subTest(jobs=jobs):
                fixture = self.tag_fixture()
                fixture["api"][f"repos/{REPO}/actions/runs/1/jobs?per_page=100"] = {"pages": [page("jobs", jobs)]}
                self.tag(fixture, ["--apply"], 3)

    def test_failure_on_later_ci_page_blocks(self):
        check_ok = {**job(), "app": {"slug": "github-actions"}, "name": "build"}
        for endpoint, field, first, last in [
            (f"actions/runs?head_sha={TARGET}&per_page=100", "workflow_runs", run(), {**run(rid=2), "conclusion": "failure"}),
            ("actions/runs/1/jobs?per_page=100", "jobs", job(), job("failure")),
            (f"commits/{TARGET}/check-runs?per_page=100", "check_runs", check_ok, {**check_ok, "conclusion": "failure"}),
        ]:
            with self.subTest(field=field):
                fixture = self.tag_fixture()
                fixture["api"][f"repos/{REPO}/{endpoint}"] = {"pages": [page(field, [first], 2), page(field, [last], 2)]}
                self.tag(fixture, ["--apply"], 3)

    def test_incomplete_ci_listing_blocks(self):
        fixture = self.tag_fixture()
        fixture["api"][f"repos/{REPO}/actions/runs/1/jobs?per_page=100"] = {"pages": [page("jobs", [job()], 2)]}
        self.tag(fixture, ["--apply"], 3)

    def test_apply_verifies_supported_release_fields(self):
        root, output = self.tag(extra=["--apply"])
        publication = json.loads((root / "publication.json").read_text())
        self.assertIn("--prerelease", publication)
        self.assertIn("--latest=false", publication)
        self.assertEqual(publication[publication.index("--target") + 1], TARGET)
        self.assertIn("TAG_DONE", output)

    def test_incorrect_published_flags_fail_verification(self):
        for field, value in [("isPrerelease", False), ("isDraft", True), ("tagName", "wrong")]:
            with self.subTest(field=field):
                fixture = self.tag_fixture()
                fixture["release"][field] = value
                _, output = self.tag(fixture, ["--apply"], 4)
                self.assertIn("GUARD_FAIL", output)

    def test_branch_and_pr_drift_before_publication_blocks(self):
        fixture = self.tag_fixture()
        fixture["api"][f"repos/{REPO}/git/ref/heads/{BRANCH}"] = {"sequence": [
            {"object": {"sha": TARGET}}, {"object": {"sha": OTHER}}]}
        self.tag(fixture, ["--apply"], 3)
        fixture = self.tag_fixture()
        self.alternate_run(fixture)
        fixture["api"][f"repos/{REPO}/pulls/7"] = {"sequence": [{"head": {"sha": OTHER}}, {"head": {"sha": TARGET}}]}
        self.tag(fixture, ["--apply", "--allow-no-runs", "--require-run-id", "2", "--require-pr-tree-of", "7"], 3)

    def test_tag_existence_is_exact_and_lookup_errors_block(self):
        endpoint = f"repos/{REPO}/git/matching-refs/tags/{TAG}"
        for existing, expected in [(TAG + "0", 0), (TAG, 3)]:
            fixture = self.tag_fixture()
            fixture["api"][endpoint] = {"pages": [[{"ref": "refs/tags/" + existing}]]}
            self.tag(fixture, expected=expected)
        fixture["api"][endpoint] = {"error": "API unavailable"}
        self.tag(fixture, ["--apply"], 3)

    def test_pr_helpers_preserve_existing_checkout_and_symlinks(self):
        for script in ("pin-pr.sh", "sync-pr.sh"):
            for apply in (False, True):
                for symlink in (False, True):
                    with self.subTest(script=script, apply=apply, symlink=symlink):
                        root = self.case()
                        clone = root / "checkout"
                        if symlink:
                            clone.symlink_to(root / "missing")
                        else:
                            subprocess.run([REAL_GIT, "init", "-q", str(clone)], check=True, env=GIT_FIXTURE_ENV)
                            subprocess.run([REAL_GIT, "-C", str(clone), "remote", "add", "origin", "https://github.com/example/falco.git"], check=True, env=GIT_FIXTURE_ENV)
                            (clone / "work.txt").write_text("uncommitted work\n")
                            subprocess.run([REAL_GIT, "-C", str(clone), "-c", "user.name=Tester", "-c", "user.email=test@example.org",
                                            "commit", "--allow-empty", "-qm", "local unpushed commit"], check=True, env=GIT_FIXTURE_ENV)
                            head = (clone / ".git" / "HEAD").read_bytes()
                        body = root / "body.txt"
                        body.write_text("chore: update pin\n\nSigned-off-by: Tester <test@example.org>\n")
                        args = ["--repo", REPO, "--branch", "test-branch", "--clone-dir", clone, "--workdir", root / "work",
                                "--title-file", body, "--body-file", body]
                        if script == "pin-pr.sh":
                            args += ["--base", "master", "--file", "pin.cmake", "--version-var", "VERSION", "--version", "2.0.0",
                                     "--commit-message-file", body, "--author-name", "Tester", "--author-email", "test@example.org", "--expect-base-sha", TARGET]
                        else:
                            args += ["--release-branch", BRANCH, "--pr", "1", "--committer-name", "Tester", "--committer-email", "test@example.org"]
                        output = self.invoke(root, script, [*args, *(["--apply"] if apply else [])], 3)
                        self.assertIn("clone dir already exists", output)
                        self.assertFalse((root / "calls.jsonl").exists(), "must refuse before invoking git or network commands")
                        if symlink:
                            self.assertTrue(clone.is_symlink())
                        else:
                            self.assertEqual((clone / "work.txt").read_text(), "uncommitted work\n")
                            self.assertEqual((clone / ".git" / "HEAD").read_bytes(), head)

    def test_crawler_distro_filter_and_skip(self):
        fixture = {"api": {"repos/example/configs/git/trees/main:configs/1.0.0+driver/x86_64": data({
            "truncated": False, "tree": [{"type": "blob", "path": "debian_6.1_1.yaml"}]})},
            "http": {"https://crawler.invalid/x86_64/list.json": {"debian": ["6.1"], "ubuntu": ["6.2"]}}}
        for distro, expected_text in [(None, "SKIP x86_64 ubuntu"), ("debian", "OK x86_64 debian"), ("ubuntu", "SKIP x86_64 ubuntu")]:
            root = self.case(fixture)
            args = ["--arch", "x86_64", "--driver-version", "1.0.0+driver", "--config-repo", "example/configs",
                    "--config-ref", "main", "--config-path", "configs", "--lists-base-url", "https://crawler.invalid", "--workdir", root / "downloads"]
            output = self.invoke(root, "crawler-lists-gate.sh", [*args, *(["--distro", distro] if distro else [])], 0)
            self.assertIn(expected_text, output)
            if distro == "debian":
                self.assertNotIn("SKIP x86_64 ubuntu", output)
        fixture["http"]["https://crawler.invalid/x86_64/list.json"] = {"ubuntu": ["6.2"]}
        root = self.case(fixture)
        args[args.index("--workdir") + 1] = root / "downloads"
        output = self.invoke(root, "crawler-lists-gate.sh", [*args, "--distro", "debian"], 1)
        self.assertIn("MISSING x86_64 debian", output)

    def test_release_notes_complete_and_incomplete_search(self):
        def pr(number):
            return {"number": number, "body": "```release-note\nfix: corrected behavior\n```", "labels": [{"name": "release-note"}]}
        def search(items, total, incomplete=False):
            return {"items": items, "total_count": total, "incomplete_results": incomplete}
        missing_flag = search([pr(1)], 1)
        del missing_flag["incomplete_results"]
        scenarios = [
            ([search([pr(1)], 2), search([pr(2)], 2)], 0),
            ([search([], 0)], 0),
            ([search([pr(1)], 2)], 4),
            ([search([pr(1)], 2), search([pr(1)], 2)], 4),
            ([search([pr(1)], 1, True)], 4),
            ([missing_flag], 4),
            ([], 4),
        ]
        query = quote_plus(f'repo:{REPO} is:pr is:merged milestone:"0.45.0"')
        for pages, expected in scenarios:
            with self.subTest(pages=pages):
                root = self.case({"api": {f"search/issues?q={query}&per_page=100": {"pages": pages}}})
                output = self.invoke(root, "release-notes-check.py", ["--repo", REPO, "--milestone", "0.45.0"], expected)
                self.assertTrue(output.rstrip().endswith("RELEASE_NOTES_OK" if expected == 0 else "RELEASE_NOTES_ISSUES"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workdir", type=Path, required=True)
    args, remaining = parser.parse_known_args()
    if not args.workdir.is_absolute():
        parser.error("--workdir must be absolute")
    args.workdir.mkdir(parents=True, exist_ok=True)
    WORKDIR = args.workdir
    unittest.main(argv=[sys.argv[0], *remaining], verbosity=2)
