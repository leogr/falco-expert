# Branch Awareness and Cross-Repo Consistency

Understanding version relationships across falcosecurity repositories, and how to handle cross-repo development.

---

## Development Branches Are Unstable

The `master` or `main` branches of all falcosecurity repositories are **development branches**. They may:

- Contain work-in-progress that doesn't compile
- Be temporarily inconsistent across repositories (e.g., `falco/master` may expect a libs API that only exists in a not-yet-merged libs PR)
- Differ from the current knowledge base era (0.44) -- the latest `master` may be ahead of or behind what this knowledge base documents

## Era and Target Version Validation

Determine what era/version the work targets and validate it is consistent with the user's request.

1. **Check the current date** to establish temporal context:

```bash
date +%Y-%m-%d
```

2. **Check the git state** of each repo involved in the task:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/<repo>
  echo 'Branch:' && git rev-parse --abbrev-ref HEAD
  echo 'Latest tag:' && git describe --tags --abbrev=0 2>/dev/null || echo '(no tags)'
  echo 'Last commit:' && git log -1 --format='%h %s (%ci)'
"
```

3. **Determine the target version**:

| Git State | Current Date vs Release Schedule | Likely Target |
|-----------|----------------------------------|---------------|
| On `master`/`main`, after latest release | Development cycle for next release | **Next era** (e.g., 0.45 if current era is 0.44) |
| On a release branch (e.g., `release/0.44.x`) | After release of 0.44.0 | **Hotfix** for current era (0.44.x) |
| On a specific tag (e.g., `0.44.0`) | Any | Investigation/read-only, not active development |
| On a feature branch | Check parent branch | Inherits target from parent |

4. **Validate against the user's request**:
   - If the user says "fix a bug in Falco 0.44" but `master` is already targeting 0.45, clarify whether they want a hotfix branch or a fix in `master`
   - If the user says "add a feature" and the repo is on a release tag, clarify that development should happen on `master`
   - **If in doubt, ask the user** to confirm the target version before proceeding

> **Why this matters:** The knowledge base documents the **current era** (0.44). If the repos being developed are already ahead (targeting 0.45), some APIs, configurations, or behaviors may have changed from what the knowledge base describes.

---

## Cross-Repo Version Pinning

**Do not assume the latest `master` of `libs` works with the latest `master` of `falco`.** Falco pins a specific libs version in its CMake configuration:

```bash
# Check which libs version falco expects
docker exec -u dev $CONTAINER_NAME bash -c "
  grep FALCOSECURITY_LIBS_VERSION /workspace/github.com/falcosecurity/falco/cmake/modules/falcosecurity-libs.cmake
"
```

This shows the exact libs version (git ref) that Falco's `master` is designed to work with. If you're building with a local libs checkout (`-DFALCOSECURITY_LIBS_SOURCE_DIR`), ensure your libs checkout is compatible.

**Source:** [`refs/falcosecurity/falco/cmake/modules/falcosecurity-libs.cmake`](../../../refs/falcosecurity/falco/cmake/modules/falcosecurity-libs.cmake)

---

## Cross-Component Development

When a change requires modifications in both `falco` and `libs`:

1. **Use `-DFALCOSECURITY_LIBS_SOURCE_DIR`** to point Falco at your local libs checkout
2. **Develop and test both together** inside the devcontainer
3. **Inform the user about merge ordering** -- libs changes must typically be merged first, then Falco's libs version pin must be updated

```bash
# Build falco with local libs
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/falco/build
  cmake -DUSE_BUNDLED_DEPS=ON \
    -DBUILD_FALCO_MODERN_BPF=ON \
    -DFALCOSECURITY_LIBS_SOURCE_DIR=/workspace/github.com/falcosecurity/libs \
    ..
  make -j\$(nproc) falco
"
```

**Merge sequence for cross-repo changes:**
1. Open and merge the `libs` PR first
2. Update `FALCOSECURITY_LIBS_VERSION` in `falco/cmake/modules/falcosecurity-libs.cmake` to reference the new libs commit/tag
3. Open and merge the `falco` PR second

Always inform the user of this dependency when proposing cross-repo changes.

---

## Handling Pre-existing Build Directories

When mounting a repo that was previously built on the host, the existing `build/` directory will contain a `CMakeCache.txt` with host-absolute paths. Inside the container, the same directory appears at `/workspace/...`, causing a CMake path mismatch.

**Recommended:** Use a separate build directory for container builds:

```bash
mkdir -p build-dev && cd build-dev
cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_FALCO_MODERN_BPF=ON ..
make -j$(nproc) falco
```

**Alternative:** Remove the host build and start fresh:

```bash
rm -rf build && mkdir build && cd build
cmake -DUSE_BUNDLED_DEPS=ON -DBUILD_FALCO_MODERN_BPF=ON ..
```

> **Note:** This issue only affects repos mounted from the host via bind mount. Repos cloned inside the container with `setup-workspace` are unaffected.
