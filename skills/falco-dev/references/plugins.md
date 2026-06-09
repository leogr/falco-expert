# Working with Plugins

Building, testing, and configuring plugins from the [`falcosecurity/plugins`](../../../refs/falcosecurity/plugins/) monorepo.

---

## Setting Up the Plugins Repo

Add the `plugins` repository to your workspace. Clone it manually or bind-mount an existing checkout:

```bash
# Option A: Clone into workspace
docker exec -u dev $CONTAINER_NAME bash -c "
  git clone https://github.com/falcosecurity/plugins.git /workspace/github.com/falcosecurity/plugins
"

# Option B: Bind-mount from host (add to docker run command)
# -v /home/user/code/falcosecurity/plugins:/workspace/github.com/falcosecurity/plugins
```

> **Note:** The `plugins` repo is not included in `setup-workspace`'s default list. You must clone or mount it explicitly.

---

## Installing Extra Build Dependencies

The devcontainer image includes the C/C++ toolchain and Go, but some plugins require additional system libraries for CGO builds:

```bash
docker exec -u dev $CONTAINER_NAME sudo apt-get update
docker exec -u dev $CONTAINER_NAME sudo apt-get install -y --no-install-recommends \
  libbtrfs-dev libdevmapper-dev libgpgme-dev
```

Check the plugin's build files (`go.mod`, `CMakeLists.txt`, or `Makefile`) for its specific dependencies. Runtime-installed packages do not persist across container recreation.

---

## Building Plugins

Plugins in the monorepo follow two build patterns:

### Go Plugins (e.g., k8saudit, json, cloudtrail)

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/plugins/plugins/k8saudit
  make
"
```

Produces `libk8saudit.so` in the plugin directory.

### C++ / Hybrid Plugins (e.g., container, k8smeta)

C++ plugins use CMake. The `container` plugin is a hybrid C++/Go plugin:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/plugins/plugins/container
  mkdir -p build && cd build
  cmake ..
  make -j\$(nproc)
"
```

Produces `libcontainer.so` in the `build/` directory.

### Building All Plugins

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  cd /workspace/github.com/falcosecurity/plugins
  make
"
```

**Source:** [`refs/falcosecurity/plugins/Makefile`](../../../refs/falcosecurity/plugins/Makefile)

---

## Testing Plugins with Falco

To test a plugin, you need a Falco binary (built from source or installed), a configuration file that loads the plugin, and a rules file.

### Minimal Config for Plugin-Only Testing

When testing a plugin that doesn't require syscall instrumentation, use `engine.kind: nodriver`:

```yaml
# /workspace/plugin-test-config.yaml
engine:
  kind: nodriver

plugins:
  - name: <plugin-name>
    library_path: /workspace/github.com/falcosecurity/plugins/plugins/<plugin-name>/lib<plugin-name>.so
    init_config: {}

load_plugins: [<plugin-name>]

stdout_output:
  enabled: true
```

> **Key points:**
> - `engine.kind: nodriver` -- no kernel instrumentation, suitable for plugin-only testing
> - `library_path` -- use an absolute path to the built `.so` file
> - `init_config` -- plugin-specific; check the plugin's README for required fields
> - Falco requires at least one rules file to start (use `-r` with an appropriate rules file)

### Validating Plugin Loading

```bash
# List all loaded plugins
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} -c /workspace/plugin-test-config.yaml --list-plugins
"

# Show detailed info for a specific plugin
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} -c /workspace/plugin-test-config.yaml --plugin-info <plugin-name>
"

# List available fields (including plugin-provided fields)
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} -c /workspace/plugin-test-config.yaml --list
"
```

### Validating Rules with a Plugin

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} \
    -c /workspace/plugin-test-config.yaml \
    -V /path/to/plugin-rules.yaml
"
```

### Dry-Run (Full Validation Without Event Capture)

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} \
    -c /workspace/plugin-test-config.yaml \
    -r /path/to/plugin-rules.yaml \
    --dry-run
"
```

`--dry-run` validates the configuration, loads the plugin, compiles rules, and exits without starting event capture. Exit code 0 means everything is valid.

### Plugin Init Config Iteration

Plugin `init_config` schemas are validated at load time. Use `--plugin-info <name>` to see the expected JSON schema:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} -c /workspace/plugin-test-config.yaml --plugin-info <plugin-name>
"
```

Override plugin config from the command line:

```bash
docker exec -u dev $CONTAINER_NAME bash -c "
  FALCO=/workspace/github.com/falcosecurity/falco/build/userspace/falco/falco
  \${FALCO} \
    -c /workspace/plugin-test-config.yaml \
    -o 'plugins[0].init_config.key=value' \
    --list-plugins
"
```

**Source:** [`specs/plugin-system.md`](../../../specs/plugin-system.md), [`specs/cli-interface.md`](../../../specs/cli-interface.md), [`specs/configuration.md`](../../../specs/configuration.md)
