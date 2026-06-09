---
name: falco-dev
description: Develop, build, test, and debug Falco and its core components (libs, rules) using a Docker-based devcontainer. Manages multi-repo workspaces, CMake builds, unit/integration testing, and debugging with graduated privilege modes (safe, least-privilege, privileged).
metadata:
  falco-version: "0.43"
---

# Falco Dev

Develop, build, test, and debug Falco and its core components using a Docker-based devcontainer.

## 1. Overview and Safety

This skill enables AI agents to:

- **Build** Falco and libs from source with CMake
- **Test** using unit tests, `sinsp-example`, and the `falcosecurity/testing` suite
- **Debug** with gdb, log analysis, and `sinsp-example` diagnostics
- **Manage** multi-repo workspaces (`falco`, `libs`, `rules`, `testing`)

### Privilege Modes

| Mode | Docker Flags | Use Cases |
|------|-------------|-----------|
| **Safe** (default) | (none) | Build, unit tests, rules validation, .scap replay, gdb launch |
| **Least-privilege** | `--cap-add SYS_PTRACE --cap-add BPF --cap-add PERFMON --cap-add SYS_RESOURCE -v /proc:/host/proc:ro` | `sinsp-example` modern_ebpf live, gdb attach |
| **Privileged** | `--privileged -v /proc:/host/proc:ro -v /etc:/host/etc:ro` | Falco daemon, kernel module, end-to-end testing |

For the full Docker flags matrix and capability details, see [`references/build-reference.md`](references/build-reference.md).

### Safety Rules

1. **Always start in safe mode** — only escalate when the task requires it
2. **Least-privilege mode** is sufficient for most live testing (modern eBPF via `sinsp-example`)
3. **Never use privileged mode** unless the user explicitly requests it or the task requires running the full Falco daemon with kernel instrumentation
4. **Stop containers** when testing is complete — privileged containers can see all host activity
5. **Never commit or push** — ask the user before running `git commit` or `git push` in any falcosecurity repo. Prior approval for one commit does not extend to later ones. Applies regardless of branch or how trivial the change is.

### Human Observability

The agent prints the container name (e.g., `falco-dev-a3f2b1c9`) at session start. Humans can connect:

- **VS Code**: "Attach to Running Container" or open [`devcontainer/devcontainer.json`](devcontainer/devcontainer.json) directly
- **Shell**: `docker exec -u dev -it $CONTAINER_NAME bash`

### External Tools (GitHub, Remote Services)

**Use `gh`, git push/pull, and remote APIs from the host, not inside the container.** The container has no SSH keys or credentials. The workspace is bind-mounted, so file changes are visible on both sides immediately.

---

## 2. Devcontainer Setup

### Session Container

Each session creates its own container with a unique name, allowing parallel sessions without interference:

```bash
CONTAINER_NAME="falco-dev-$(head -c4 /dev/urandom | xxd -p)"
```

All subsequent commands use `$CONTAINER_NAME`. The **image** name remains `falco-dev`.

> **Key principle:** Creating a new container is cheap (~1 second). Rebuilding the image is expensive (minutes). Prefer creating fresh over elaborate reuse checks.

### Building the Image

Build with a context hash label for freshness detection:

```bash
CONTEXT_HASH=$(find skills/falco-dev/devcontainer/ -type f | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)
docker build -t falco-dev --label "devcontainer.context-hash=$CONTEXT_HASH" skills/falco-dev/devcontainer/
```

The image includes: C/C++ toolchain (GCC, Clang, CMake 3.31.x), dev libraries, bpftool 7.3.0, Go toolchain, debugging tools (gdb, valgrind, strace).

**Source:** [`devcontainer/Dockerfile`](devcontainer/Dockerfile)

### Starting the Container

See [Choosing a Workspace Location](#choosing-a-workspace-location) for `$WORKSPACE_DIR`.

> **Prerequisite:** The workspace directory must exist and be owned by your user before starting:
> ```bash
> mkdir -p "$WORKSPACE_DIR"
> ```

#### Safe Mode (Default)

```bash
docker run -d \
  --name "$CONTAINER_NAME" \
  --label falco-dev.session=true \
  -v "$WORKSPACE_DIR":/workspace \
  falco-dev
```

#### Least-Privilege Mode

```bash
docker run -d \
  --name "$CONTAINER_NAME" \
  --label falco-dev.session=true \
  --cap-add SYS_PTRACE --cap-add BPF --cap-add PERFMON --cap-add SYS_RESOURCE \
  -v /proc:/host/proc:ro \
  -v "$WORKSPACE_DIR":/workspace \
  falco-dev
```

> **Fallback:** If Docker does not support `BPF`/`PERFMON` capabilities, use `--cap-add SYS_ADMIN` instead.

#### Privileged Mode

```bash
docker run -d \
  --name "$CONTAINER_NAME" \
  --label falco-dev.session=true \
  --privileged \
  -v /proc:/host/proc:ro -v /etc:/host/etc:ro \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v "$WORKSPACE_DIR":/workspace \
  falco-dev
```

### File Ownership

The entrypoint auto-adjusts the `dev` user UID/GID to match `/workspace` ownership. Files created inside the container will be owned by the host user.

**Source:** [`devcontainer/scripts/entrypoint.sh`](devcontainer/scripts/entrypoint.sh)

### Executing Commands

Always use `-u dev` with `docker exec`:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "cd /workspace/github.com/falcosecurity/libs/build && make -j\$(nproc) sinsp-example"
```

### Container Lifecycle

```bash
docker stop $CONTAINER_NAME           # Preserves state (build artifacts, installed packages)
docker rm -f $CONTAINER_NAME          # Destroy
```

#### Cleanup

```bash
# List all session containers
docker ps -a --filter label=falco-dev.session=true --format '{{.Names}}\t{{.Status}}\t{{.CreatedAt}}'

# Remove all stopped session containers
docker rm $(docker ps -aq --filter label=falco-dev.session=true --filter status=exited)
```

### Session Lifecycle

#### New Session

1. **Image freshness check** — compare build context hash against the image label:

```bash
CONTEXT_HASH=$(find skills/falco-dev/devcontainer/ -type f | sort | xargs sha256sum | sha256sum | cut -d' ' -f1)
IMAGE_HASH=$(docker image inspect falco-dev:latest --format '{{index .Config.Labels "devcontainer.context-hash"}}' 2>/dev/null || true)

if [ "$CONTEXT_HASH" != "$IMAGE_HASH" ]; then
  echo "IMAGE OUTDATED: rebuild required"
  # Rebuild with the command from "Building the Image"
fi
```

2. **Create the container** using the appropriate [mode](#starting-the-container). Inform the user of the container name.

#### Resuming a Session

When `$CONTAINER_NAME` is already set (e.g., after context compaction):

```bash
CONTAINER_STATUS=$(docker inspect "$CONTAINER_NAME" --format '{{.State.Status}}' 2>/dev/null || echo "gone")
```

| Status | Action |
|--------|--------|
| `running` | Verify image match (below), then reuse |
| `exited` | `docker start $CONTAINER_NAME`, verify image match |
| `gone` | Fall back to [New Session](#new-session) |

**Image match** (only when resuming):

```bash
CONTAINER_IMAGE=$(docker inspect "$CONTAINER_NAME" --format '{{.Image}}' 2>/dev/null)
CURRENT_IMAGE=$(docker image inspect falco-dev:latest --format '{{.Id}}' 2>/dev/null)
[ "$CONTAINER_IMAGE" != "$CURRENT_IMAGE" ] && echo "STALE: recreate container"
```

### Installing Additional Packages

```bash
docker exec -u dev $CONTAINER_NAME sudo apt-get update
docker exec -u dev $CONTAINER_NAME sudo apt-get install -y --no-install-recommends <package>
```

Packages installed at runtime do not persist across container recreation. Document what you install and inform the user.

---

## 3. Workspace Management

### Choosing a Workspace Location

**MANDATORY**: Before starting the devcontainer, ask the user where to place the workspace:

| Option | When to Use | Example |
|--------|-------------|---------|
| **Current working directory** | Project-scoped work | `$(pwd)/workspace` |
| **Temporary directory** | Throwaway experiments | `/tmp/falco-dev-XXXXX/workspace` |
| **Existing git repo** | Single-repo tasks with user's existing checkout | `/home/user/code/falcosecurity/falco` |
| **User-provided path** | Resuming work, custom layouts. **Always offer.** | User specifies |

```bash
WORKSPACE_DIR="$(pwd)/workspace"
mkdir -p "$WORKSPACE_DIR"
```

### Directory Convention

```
/workspace/github.com/falcosecurity/
├── falco/       # Main Falco repo
├── libs/        # Core libraries (libscap, libsinsp, drivers)
├── plugins/     # Plugin registry (manual clone — see Section 11)
├── rules/       # Official detection rules
└── testing/     # Regression test suite
```

### Using setup-workspace

```bash
docker exec -u dev $CONTAINER_NAME setup-workspace                            # Clone all repos
docker exec -u dev $CONTAINER_NAME setup-workspace falco libs                  # Clone specific repos
docker exec -u dev $CONTAINER_NAME setup-workspace --install-hooks             # Install pre-commit hooks
```

Skips repos that already exist. Automatically installs pre-commit hooks for repos with `.pre-commit-config.yaml`.

**Source:** [`devcontainer/scripts/setup-workspace.sh`](devcontainer/scripts/setup-workspace.sh)

### Which Repos for Which Tasks

| Task | Required Repos | Notes |
|------|---------------|-------|
| Build Falco | `falco` (+ `libs` optional) | Falco fetches libs automatically |
| Build libs standalone | `libs` | Independent build |
| Rules validation/authoring | `rules`, `falco` | Need `falco -V` |
| End-to-end testing | `testing`, `falco` | May need privileged mode |
| Cross-component dev | `falco`, `libs` | Use `-DFALCOSECURITY_LIBS_SOURCE_DIR` |
| Plugin dev/testing | `plugins`, `falco` | See [Section 11](#11-working-with-plugins) |

### Using Existing Local Repos

Use a **direct bind mount** — symlinks do not work inside the container:

```bash
docker run -d \
  --name "$CONTAINER_NAME" \
  --label falco-dev.session=true \
  -v "$WORKSPACE_DIR":/workspace \
  -v /home/user/code/falcosecurity/falco:/workspace/github.com/falcosecurity/falco \
  falco-dev
```

> **Deep bind mounts**: Docker creates intermediate directories as root. The entrypoint auto-fixes ownership by reading `/proc/self/mountinfo`. If you hit "Permission denied", run `docker exec $CONTAINER_NAME chown -R dev:dev /workspace/github.com`.

When the task requires only a single repo, mount it directly without a general workspace:

```bash
docker run -d \
  --name "$CONTAINER_NAME" \
  --label falco-dev.session=true \
  -v /home/user/code/falcosecurity/falco:/workspace/github.com/falcosecurity/falco \
  falco-dev
```

### Git Operations

Git is pre-configured inside the container (all `/workspace` directories are `safe.directory`). For push/pull, use git on the **host** (which has SSH keys). Use `git commit -s` for DCO sign-off. See [Section 10](#10-code-standards) for commit conventions.

### Workspace State Inspection

Quickly check the state of all repos:

```bash
docker exec -u dev $CONTAINER_NAME bash -c '
  for repo in /workspace/github.com/falcosecurity/*/; do
    [ -d "$repo/.git" ] || continue
    name=$(basename "$repo")
    branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
    tag=$(git -C "$repo" describe --tags --abbrev=0 2>/dev/null || echo "none")
    dirty=$(git -C "$repo" status --porcelain | head -1)
    printf "%-12s %-20s tag:%-10s %s\n" "$name" "$branch" "$tag" "${dirty:+DIRTY}"
  done
'
```

---

## 4. Pre-Flight Checklist

Before starting a new development task, verify the environment is ready. Run these once per task.

### Step 1: Session

Ensure the devcontainer is running ([Session Lifecycle](#session-lifecycle)).

### Step 2: Branch and Version Awareness

Check what era/version each repo targets. The knowledge base documents era 0.43 — if repos are ahead (targeting 0.44+), APIs and behaviors may differ.

```bash
docker exec -u dev $CONTAINER_NAME bash -c '
  for repo in falco libs; do
    dir=/workspace/github.com/falcosecurity/$repo
    [ -d "$dir/.git" ] || continue
    echo "=== $repo ==="
    git -C "$dir" rev-parse --abbrev-ref HEAD
    git -C "$dir" describe --tags --abbrev=0 2>/dev/null || echo "(no tags)"
    git -C "$dir" log -1 --format="%h %s (%ci)"
  done
'
```

If the user says "fix a bug in 0.43" but `master` targets 0.44, clarify whether they want a hotfix branch or a fix on `master`.

For detailed version validation logic and cross-repo consistency rules, see [`references/branch-awareness.md`](references/branch-awareness.md).

### Step 3: Build Sanity

Quick-compile the repos involved in the task to catch pre-existing breakage:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/libs/build 2>/dev/null && make -j\$(nproc) sinsp-example 2>&1 | tail -5
"
```

If the build fails, **stop and ask the user** — never silently proceed on a broken codebase. Check for dirty trees too:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/libs && git status --short
"
```

---

## 5. Quick Reference

### Build Targets Cheat Sheet

| What you need | Repo | CMake flags | Make target |
|--------------|------|-------------|-------------|
| Falco binary | falco | `-DUSE_BUNDLED_DEPS=ON -DBUILD_FALCO_MODERN_BPF=ON` | `falco` |
| Falco (fast, no gRPC) | falco | add `-DMINIMAL_BUILD=ON` | `falco` |
| Falco unit tests | falco | add `-DBUILD_FALCO_UNIT_TESTS=ON` | `falco_unit_tests` |
| Falco + local libs | falco | add `-DFALCOSECURITY_LIBS_SOURCE_DIR=/workspace/.../libs` | `falco` |
| sinsp-example | libs | `-DUSE_BUNDLED_DEPS=ON -DBUILD_LIBSCAP_MODERN_BPF=ON -DCREATE_TEST_TARGETS=ON` | `sinsp-example` |
| libs unit tests | libs | same as sinsp-example | `unit-test-libsinsp` |
| Debug build (any) | any | add `-DCMAKE_BUILD_TYPE=Debug` | (same target) |

For all CMake flags, see [`references/build-reference.md`](references/build-reference.md).

### Common Errors → Actions

| Error pattern | Likely cause | Fix |
|--------------|-------------|-----|
| `CMakeCache.txt` path mismatch | Host build dir mounted in container | Use `build-dev/` or `rm -rf build/` |
| `fatal error: bpf_skel.h not found` | BPF skeleton not generated | Build `ProbeSkeleton` target first |
| `FALCOSECURITY_LIBS_VERSION` mismatch | libs checkout doesn't match Falco's pin | Check `grep FALCOSECURITY_LIBS_VERSION .../falcosecurity-libs.cmake` |
| `pre-commit` hook failures | Code not formatted | `pre-commit run --all-files`, stage fixes |
| `Permission denied` in `/workspace` | Root-owned intermediate dirs | `docker exec $CONTAINER_NAME chown -R dev:dev /workspace/github.com` |
| Linking error, missing symbol | Stale build after branch switch | `cmake --build . --target clean && cmake ..` then rebuild |

### Test Selection Guide

| What to test | Command |
|-------------|---------|
| Validate rules syntax | `falco -V rules.yaml` |
| Validate rules + config | `falco --dry-run -c config.yaml -r rules.yaml` |
| libs unit tests | `ctest --output-on-failure` in libs build dir |
| Specific test case | `./unit-test-libsinsp --gtest_filter='*pattern*'` |
| Falco unit tests | `sudo ./unit_tests/falco_unit_tests` |
| sinsp-example replay | `sinsp-example -s capture.scap -f 'filter'` |
| sinsp-example live | `sudo sinsp-example -o modern_ebpf -f 'filter'` (least-priv) |
| End-to-end | `go test ./tests/falco/... -v` in testing repo (privileged) |

### Cross-Skill Handoffs

| When you need to... | Hand off to |
|--------------------|-------------|
| Author/tune Falco rules | [`falco-rules-author`](../falco-rules-author/SKILL.md) |
| Validate rules without building from source | [`falco-cli`](../falco-cli/SKILL.md) |
| Triage a GitHub issue for context | [`falco-triage`](../falco-triage/SKILL.md) |
| Review a PR being developed | [`falco-reviewer`](../falco-reviewer/SKILL.md) |

---

## 6. Building

### Building Falco

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO_SRC=/workspace/github.com/falcosecurity/falco
  mkdir -p \${FALCO_SRC}/build && cd \${FALCO_SRC}/build
  cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_FALCO_MODERN_BPF=ON \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
  make -j\$(nproc) falco
"
```

Binary: `/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco`

> `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` generates `compile_commands.json` for IDE integration (clangd, VS Code).

**Source:** [`specs/build-system.md`](../../specs/build-system.md)

### Building Libs (Standalone)

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  LIBS_SRC=/workspace/github.com/falcosecurity/libs
  mkdir -p \${LIBS_SRC}/build && cd \${LIBS_SRC}/build
  cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_LIBSCAP_MODERN_BPF=ON \
    -DCREATE_TEST_TARGETS=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..
  make -j\$(nproc) sinsp-example
"
```

For non-bundled builds, run `sudo /workspace/.../libs/.github/install-deps.sh` first.

**Source:** [`refs/falcosecurity/libs/.github/install-deps.sh`](../../refs/falcosecurity/libs/.github/install-deps.sh)

### Using a Local Libs Checkout

Point Falco at your local `libs` for cross-component development:

```bash
cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_FALCO_MODERN_BPF=ON \
  -DFALCOSECURITY_LIBS_SOURCE_DIR=/workspace/github.com/falcosecurity/libs ..
```

Changes to libs source are picked up on incremental rebuilds. See [`references/branch-awareness.md`](references/branch-awareness.md) for cross-repo merge ordering.

### Incremental Rebuilds

After the initial build, just re-run make — CMake tracks dependencies automatically:

```bash
cd /workspace/github.com/falcosecurity/falco/build && make -j$(nproc) falco
```

> **After switching branches**: If headers or CMake files changed, re-run `cmake ..` before `make`. For stubborn issues, `cmake --build . --target clean` then reconfigure.

### Post-Build Verification

Quick smoke test after a successful build:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} --version && \${FALCO} --list | head -5
"
```

---

## 7. Running Tests

### Unit Tests (Falco)

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/falco/build
  cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_FALCO_MODERN_BPF=ON -DBUILD_FALCO_UNIT_TESTS=ON ..
  make -j\$(nproc) falco_unit_tests
  sudo ./unit_tests/falco_unit_tests
"
```

Run a specific test: `sudo ./unit_tests/falco_unit_tests --gtest_filter='*pattern*'`

> Some Falco unit tests require `sudo`.

**Source:** [`refs/falcosecurity/falco/unit_tests/CMakeLists.txt`](../../refs/falcosecurity/falco/unit_tests/CMakeLists.txt)

### Unit Tests (Libs)

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/libs/build
  make -j\$(nproc) unit-test-libsinsp
  ctest --output-on-failure
"
```

Run a specific test: `./test/libsinsp/unit-test-libsinsp --gtest_filter='*pattern*'`

### sinsp-example (Manual Testing)

#### Replay a .scap File (Safe Mode)

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  /workspace/github.com/falcosecurity/libs/build/libsinsp/examples/sinsp-example \
    -s /path/to/capture.scap -f 'proc.name=bash'
"
```

#### Live Capture (Least-Privilege Mode Required)

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  sudo /workspace/github.com/falcosecurity/libs/build/libsinsp/examples/sinsp-example \
    -o modern_ebpf -f 'evt.type=execve'
"
```

### Rules Validation

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  RULES=/workspace/github.com/falcosecurity/rules/rules
  \${FALCO} -V \${RULES}/falco_rules.yaml
"
```

### End-to-End Tests (falcosecurity/testing)

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/testing
  go generate ./...
  go test ./tests/falco/... -v
"
```

May require privileged mode. **Source:** [`digests/falcosecurity/testing.md`](../../digests/falcosecurity/testing.md)

### Test Failure Triage

When tests fail, diagnose before assuming your change is the cause:

1. **Check if the failure is pre-existing**: Run the same test on the base branch (before your changes)
2. **Check for flaky tests**: Some tests (especially BPF-related) can be environment-sensitive — re-run once
3. **Read the assertion**: gtest output includes expected vs actual values — match against your change
4. **For linker/compile errors in tests**: Usually a missing build dependency — check if you need to rebuild a target

```bash
# Run failing test with verbose output
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/libs/build
  ./test/libsinsp/unit-test-libsinsp --gtest_filter='*FailingTest*' --gtest_print_time=1
"
```

---

## 8. Debugging

### GDB on Falco (Safe Mode)

Build with debug symbols, then run under gdb:

```bash
docker exec -u dev -it $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/falco/build
  cmake -DCMAKE_BUILD_TYPE=Debug -DUSE_BUNDLED_DEPS=ON -DBUILD_FALCO_MODERN_BPF=ON ..
  make -j\$(nproc) falco
  gdb --args ./userspace/falco/falco -V /path/to/rules.yaml
"
```

Inside gdb:
```
(gdb) break falco_engine::load_rules
(gdb) run
(gdb) bt          # backtrace
(gdb) info locals
```

> In safe mode, gdb warns "Error disabling address space randomization: Operation not permitted" — this is harmless. Breakpoints, backtraces, and inspection all work. Use least-privilege mode to suppress this and enable `gdb -p <pid>` attach.

### GDB on sinsp-example

```bash
docker exec -u dev -it $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/libs/build
  cmake -DCMAKE_BUILD_TYPE=Debug -DUSE_BUNDLED_DEPS=ON -DBUILD_LIBSCAP_MODERN_BPF=ON -DCREATE_TEST_TARGETS=ON ..
  make -j\$(nproc) sinsp-example
  gdb --args ./libsinsp/examples/sinsp-example -s /path/to/capture.scap -f 'proc.name=bash'
"
```

### Attaching GDB to a Running Process (Least-Privilege Mode)

```bash
# In one terminal: start the process
docker exec -u dev $CONTAINER_NAME bash -c "sudo sinsp-example -o modern_ebpf"

# In another: attach
docker exec -u dev -it $CONTAINER_NAME bash -c "sudo gdb -p \$(pgrep -f sinsp-example)"
```

### Log Analysis

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} -v --dry-run 2>&1
"
```

### Core Dumps

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  ulimit -c unlimited
  echo '/tmp/core.%p' | sudo tee /proc/sys/kernel/core_pattern
  # After crash: gdb /path/to/binary /tmp/core.<pid>
"
```

---

## 9. Working with Rules

### Loading and Validating

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  RULES=/workspace/github.com/falcosecurity/rules/rules
  \${FALCO} -V \${RULES}/falco_rules.yaml
  \${FALCO} -r \${RULES}/falco_rules.yaml -L
"
```

### Testing Against Captures

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} \
    -o 'engine.kind=replay' \
    -o 'engine.replay.capture_file=/path/to/capture.scap' \
    -r /path/to/rules.yaml \
    -o json_output=true -o json_include_output_fields_property=true
"
```

For advanced rules authoring (live testing, iterative tuning, false-positive reduction), hand off to the [`falco-rules-author`](../falco-rules-author/SKILL.md) skill.

---

## 10. Code Standards

All falcosecurity repos require **DCO sign-off** (`git commit -s`), **Conventional Commits** format, and **pre-commit hooks** for code formatting. When adding dependencies, verify license compatibility (Apache-2.0 or CNCF allowlist).

### Run the Formatter After Every Code Change (MANDATORY)

In `falco` and `libs`, always run the formatter after modifying any C/C++ (`.c`, `.h`, `.cpp`) or CMake (`.cmake`, `CMakeLists.txt`) file — **regardless of whether a commit follows**. This matches what CI and the pre-commit hook enforce, and prevents surprise rewrites later.

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/<repo>
  pre-commit run --all-files
"
```

The hook auto-fixes clang-format (C/C++) and cmake-format (CMake) in place. Review the diff before staging. Alternative: `make format-all` (apply) or `make check-all` (dry-run) from the repo root.

For complete details — pre-commit setup, C++ coding style, copyright headers, banned APIs, license verification — see [`references/code-formatting.md`](references/code-formatting.md).

---

## 11. Working with Plugins

The devcontainer supports plugin development. The `plugins` repo is not included in `setup-workspace` — clone or bind-mount it explicitly.

For building plugins (Go, C++, hybrid), testing with Falco, plugin config iteration, and required extra dependencies, see [`references/plugins.md`](references/plugins.md).

---

## Sources

| Topic | Source |
|-------|--------|
| Build system | [`specs/build-system.md`](../../specs/build-system.md) |
| Architecture | [`specs/architecture-overview.md`](../../specs/architecture-overview.md) |
| Kernel instrumentation | [`specs/kernel-instrumentation.md`](../../specs/kernel-instrumentation.md) |
| Libs architecture | [`digests/falcosecurity/libs/architecture.md`](../../digests/falcosecurity/libs/architecture.md) |
| Testing suite | [`digests/falcosecurity/testing.md`](../../digests/falcosecurity/testing.md) |
| CLI reference | [`specs/cli-interface.md`](../../specs/cli-interface.md) |
| Plugin system | [`specs/plugin-system.md`](../../specs/plugin-system.md) |
| CNCF licensing | [`digests/cncf/foundation.md`](../../digests/cncf/foundation.md) |
| Build flags & container modes | [`references/build-reference.md`](references/build-reference.md) |
| Branch awareness & cross-repo | [`references/branch-awareness.md`](references/branch-awareness.md) |
| Code formatting & licensing | [`references/code-formatting.md`](references/code-formatting.md) |
| Plugin development | [`references/plugins.md`](references/plugins.md) |
