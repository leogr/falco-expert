# Falco Documentation Digest (Era 0.44)

> AI-optimized digest of the Falco documentation from falcosecurity/falco-website.
> Source: [content/en/docs/_index.md](../../../refs/falcosecurity/falco-website/content/en/docs/_index.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Installation and Setup](#2-installation-and-setup)
3. [Configuration](#3-configuration)
4. [Rules System](#4-rules-system)
5. [Event Sources](#5-event-sources)
6. [Plugin System](#6-plugin-system)
7. [Outputs and Alerting](#7-outputs-and-alerting)
8. [Metrics and Monitoring](#8-metrics-and-monitoring)
9. [Troubleshooting](#9-troubleshooting)
10. [Developer Guide](#10-developer-guide)

---

## 1. Overview

**Source:** [`_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/_index.md)

### What is Falco?

Falco is a cloud native security tool providing runtime security across hosts, containers, Kubernetes, and cloud environments. It detects and alerts on abnormal behavior and potential security threats in real-time.

**Core functionality:**
- Monitors system activity by parsing Linux syscalls from the kernel at runtime
- Asserts the event stream against a rules engine
- Alerts when a rule is violated
- Enriches events with metadata from container runtimes and Kubernetes

Falco is a graduated CNCF project, originally created by Sysdig.

### What Falco Checks For (Default Rules)

- Privilege escalation using privileged containers
- Namespace changes using tools like `setns`
- Read/writes to `/etc`, `/usr/bin`, `/usr/sbin`, etc.
- Creating symlinks
- Ownership and mode changes
- Unexpected network connections or socket mutations
- Spawned processes using `execve`
- Executing shell binaries (`sh`, `bash`, `csh`, `zsh`, etc.)
- Executing SSH binaries (`ssh`, `scp`, `sftp`, etc.)
- Mutating Linux `coreutils` executables
- Mutating login binaries
- Mutating `shadowutil` or `passwd` executables

### Main Components

| Component | Description |
|-----------|-------------|
| **Userspace program** | CLI tool `falco` that handles signals, parses driver info, sends alerts |
| **Configuration** | Defines how Falco runs, what rules to assert, how to alert (`falco.yaml`) |
| **Driver** | Software adhering to driver spec that sends kernel events stream |
| **Plugins** | Extend functionality with new event sources and fields |
| **Falcoctl** | Tool for managing rules, plugins, and administrative tasks |

### Driver Types

| Driver | Status | Description |
|--------|--------|-------------|
| **Modern eBPF probe** | Default | CO-RE paradigm, bundled in binary |
| **Legacy eBPF probe** | Removed in 0.44.0 | Previously required kernel >= 4.14 (x86_64) / 4.17 (aarch64) |
| **Kernel module** | Supported | Requires kernel >= 3.10 |

### Alert Output Channels

- Standard Output
- File
- Syslog
- Spawned program
- HTTP/HTTPS endpoint
- ~~gRPC API~~ (removed in 0.44.0)

---

## 2. Installation and Setup

**Source:** [`setup/`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/_index.md)

### 2.1 Download and Packages

**Source:** [`setup/download.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/download.md), [`setup/packages.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/packages.md)

#### Package Downloads

| Architecture | RPM | DEB | Binary |
|-------------|-----|-----|--------|
| x86_64 | `download.falco.org/packages/rpm/falco-<version>-x86_64.rpm` | `download.falco.org/packages/deb/stable/falco-<version>-x86_64.deb` | `download.falco.org/packages/bin/x86_64/falco-<version>-x86_64.tar.gz` |
| aarch64 | `download.falco.org/packages/rpm/falco-<version>-aarch64.rpm` | `download.falco.org/packages/deb/stable/falco-<version>-aarch64.deb` | `download.falco.org/packages/bin/aarch64/falco-<version>-aarch64.tar.gz` |

#### Container Images

| Tag | Description |
|-----|-------------|
| `falcosecurity/falco:latest` | Distroless, latest release |
| `falcosecurity/falco:<version>` | Distroless, specific version |
| `falcosecurity/falco:latest-debian` | Debian-based (since 0.40) |
| `falcosecurity/falco-driver-loader:latest` | Driver loader with build toolchain |

### 2.2 Installation via Package Manager

**Source:** [`setup/packages.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/packages.md)

#### Environment Variables for Installation

| Variable | Values | Description |
|----------|--------|-------------|
| `FALCO_FRONTEND` | `noninteractive` | Disable dialog prompts |
| `FALCO_DRIVER_CHOICE` | `kmod`, `ebpf`, `modern_ebpf`, `none` | Driver selection |
| `FALCOCTL_ENABLED` | `no` | Disable automatic rules update |

#### Debian/Ubuntu Installation

```bash
# Trust GPG key
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
  sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg

# Configure apt repository
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
  sudo tee -a /etc/apt/sources.list.d/falcosecurity.list

# Update and install dependencies (for kmod/ebpf)
sudo apt-get update -y
sudo apt install -y dkms make linux-headers-$(uname -r) clang llvm dialog

# Install Falco
sudo apt-get install -y falco
```

#### CentOS/RHEL/Fedora Installation

```bash
# Trust GPG key
sudo rpm --import https://falco.org/repo/falcosecurity-packages.asc

# Configure yum repository
sudo curl -o /etc/yum.repos.d/falcosecurity.repo https://falco.org/repo/falcosecurity-rpm.repo

# Update and install dependencies
sudo yum update -y
sudo yum install -y dkms make kernel-devel-$(uname -r) clang llvm dialog

# Install Falco
sudo yum install -y falco
```

**RHEL 8 Note:** Set `LD_PRELOAD=/lib64/libresolv.so.2` for glibc compatibility.

#### Systemd Services

| Service | Description |
|---------|-------------|
| `falco-modern-bpf.service` | Modern eBPF driver |
| `falco-bpf.service` | Legacy eBPF driver |
| `falco-kmod.service` | Kernel module driver |
| `falco-custom.service` | Custom configuration |
| `falcoctl-artifact-follow.service` | Automatic rules updates |

```bash
# Enable modern eBPF
sudo systemctl enable falco-modern-bpf.service
sudo systemctl start falco-modern-bpf.service

# Disable automatic rules update
sudo systemctl mask falcoctl-artifact-follow.service
```

### 2.3 Tarball Installation

**Source:** [`setup/tarball.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/tarball.md)

```bash
# Download and extract
curl -L -O https://download.falco.org/packages/bin/x86_64/falco-<version>-x86_64.tar.gz
tar -xvf falco-<version>-x86_64.tar.gz
cp -R falco-<version>-x86_64/* /

# Configure driver (if not using modern eBPF)
falcoctl driver config --type kmod  # or --type ebpf
falcoctl driver install
```

### 2.4 Container Deployment

**Source:** [`setup/container.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/container.md)

#### Modern eBPF (Recommended - Least Privileged)

```bash
docker run --rm -it \
  --cap-drop all \
  --cap-add sys_admin \
  --cap-add sys_resource \
  --cap-add sys_ptrace \
  -v /sys/kernel/debug:/sys/kernel/debug:ro \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v /proc:/host/proc:ro \
  -v /etc:/host/etc:ro \
  falcosecurity/falco:<version>
```

**Required capabilities for Modern eBPF:**
- `CAP_SYS_PTRACE`
- `CAP_SYS_RESOURCE`
- `CAP_BPF` (or `CAP_SYS_ADMIN` if Docker doesn't support it)
- `CAP_PERFMON` (or `CAP_SYS_ADMIN` if Docker doesn't support it)

#### Kernel Module (Fully Privileged)

```bash
# First, install driver on host
docker run --rm -it --privileged \
  -v /root/.falco:/root/.falco \
  -v /boot:/host/boot:ro \
  -v /lib/modules:/host/lib/modules \
  -v /usr:/host/usr:ro \
  -v /proc:/host/proc:ro \
  -v /etc:/host/etc:ro \
  falcosecurity/falco-driver-loader:<version> kmod

# Then run Falco
docker run --rm -it --privileged \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v /dev:/host/dev \
  -v /proc:/host/proc:ro \
  -v /etc:/host/etc:ro \
  falcosecurity/falco:<version> falco -o engine.kind=kmod
```

### 2.5 Kubernetes Deployment

**Source:** [`setup/kubernetes.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/kubernetes.md)

```bash
# Add Helm repository
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Install Falco
helm install --replace falco --namespace falco --create-namespace \
  --set tty=true falcosecurity/falco

# Verify pods are running
kubectl get pods -n falco
kubectl wait pods --for=condition=Ready --all -n falco
```

**Helm Chart:** [github.com/falcosecurity/charts](https://github.com/falcosecurity/charts)

### 2.6 Specific Environments

**Source:** [`setup/enviroments.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/enviroments.md)

#### GKE (Google Kubernetes Engine)

GKE uses Container-Optimized OS which doesn't support kernel modules. Use the Modern eBPF driver (default since 0.38.0).

#### gVisor

**Removed in 0.44.0** - Use modern eBPF probe (default) or kmod instead.

---

## 3. Configuration

**Source:** [`reference/daemon/config-options/`](../../../refs/falcosecurity/falco-website/content/en/docs/reference/daemon/config-options/index.md), [`reference/daemon/cli-arguments/`](../../../refs/falcosecurity/falco-website/content/en/docs/reference/daemon/cli-arguments/cli-arguments.md)

### 3.1 Configuration File

Location: `/etc/falco/falco.yaml`

Full configuration reference: [github.com/falcosecurity/falco/blob/master/falco.yaml](https://github.com/falcosecurity/falco/blob/master/falco.yaml)

### 3.2 Configuration Files Merging (since 0.38) (Since 0.38.0)

```yaml
config_files:
  - /etc/falco/config.d
  - path: /etc/falco/config.append.d/
    strategy: append
  - path: /etc/falco/extra_config.yaml
    strategy: add-only
```

**Merge Strategies (since 0.41.0):**

| Strategy | Behavior |
|----------|----------|
| `append` (default) | Append sequences, override scalars, add non-existing |
| `override` | Override existing keys, add non-existing |
| `add-only` | Ignore existing keys, add non-existing only |

**Important:** Merging occurs at root key level only, not nested keys.

### 3.3 Command-Line Arguments

```
falco [OPTION...]

  -h, --help                    Print help and exit
  -c <path>                     Configuration file (default: /etc/falco/falco.yaml)
  --config-schema               Print config JSON schema and exit
  --rule-schema                 Print rule JSON schema and exit
  --disable-source <source>     Disable event source
  --dry-run                     Run without processing events
  --enable-source <source>      Enable specific event source
  -i                            Print ignored events and exit
  -L                            Show all rules and exit
  -l <rule>                     Show specific rule and exit
  --list [=<source>]            List defined fields and exit
  --list-events                 List syscall/tracepoint/meta events
  --list-plugins                Print plugin info and exit
  -M <seconds>                  Stop after N seconds
  -o, --option <opt>=<val>      Override config option
  --plugin-info <name>          Print plugin info and exit
  -r <rules_file>               Rules file/directory to load
  --support                     Print support info (JSON) and exit
  -U, --unbuffered              Disable output buffering
  -V, --validate <rules_file>   Validate rules file and exit
  -v                            Enable verbose output
  --version                     Print version and exit
  --page-size                   Print system page size and exit
```

### 3.4 Configuration Override Examples

```bash
# Override via command line
falco -o engine.kind=modern_ebpf
falco -o "rules[].enable.tag=network"
falco -o key.subkey=value
falco -o key.list[0]=value
falco -o "key.list[]=newvalue"  # Append to list (since 0.38.0)
```

### 3.5 Hot Reload

With `watch_config_files: true` (default), Falco automatically reloads on config/rules changes.

Manual reload: `kill -1 $(pidof falco)` (SIGHUP)

---

## 4. Rules System

**Source:** [`concepts/rules/`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/_index.md)

### 4.1 Rules File Structure

A Falco rules file is YAML containing:

| Element | Description |
|---------|-------------|
| **Rules** | Conditions under which alerts are generated |
| **Macros** | Reusable condition snippets |
| **Lists** | Collections of items for use in rules/macros |
| `required_engine_version` | Minimum Falco engine version |
| `required_plugin_versions` | Plugin version compatibility |

### 4.2 Rule Definition

**Source:** [`concepts/rules/basic-elements.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/basic-elements.md)

```yaml
- rule: shell_in_container
  desc: Notice shell activity within a container
  condition: >
    spawned_process and
    container and
    proc.name in (shell_binaries)
  output: >
    shell in container |
    user=%user.name container_id=%container.id
    shell=%proc.name parent=%proc.pname cmdline=%proc.cmdline
  priority: WARNING
  tags: [container, shell]
```

#### Required Rule Fields

| Field | Required | Description |
|-------|----------|-------------|
| `rule` | Yes | Unique rule name |
| `condition` | Yes | Boolean filtering expression |
| `desc` | Yes | Description of what rule detects |
| `output` | Yes | Alert message with field interpolation |
| `priority` | Yes | Severity level |

#### Optional Rule Fields

| Field | Default | Description |
|-------|---------|-------------|
| `enabled` | `true` | Enable/disable rule |
| `tags` | empty | Categorization tags |
| `exceptions` | empty | Exception conditions |
| `source` | `syscall` | Event source (`syscall`, `k8s_audit`, plugin sources) |
| `warn_evttypes` | `true` | Warn if no event type specified |
| `skip-if-unknown-filter` | `false` | Skip unknown filterchecks |

#### Priority Levels

- `EMERGENCY`
- `ALERT`
- `CRITICAL`
- `ERROR`
- `WARNING`
- `NOTICE`
- `INFORMATIONAL`
- `DEBUG`

### 4.3 Macros

```yaml
- macro: container
  condition: (container.id != host)

- macro: spawned_process
  condition: (evt.type in (execve, execveat))

- macro: shell_procs
  condition: proc.name in (shell_binaries)
```

Macros can reference other previously-defined macros.

### 4.4 Lists

```yaml
- list: shell_binaries
  items: [bash, csh, ksh, sh, tcsh, zsh, dash]

- list: known_binaries
  items: [shell_binaries, userexec_binaries]  # Can include other lists
```

Lists cannot be parsed as filtering expressions.

### 4.5 Condition Syntax

**Source:** [`concepts/rules/conditions.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/conditions.md)

#### Logical Operators

| Operator | Description |
|----------|-------------|
| `and` | Logical AND |
| `or` | Logical OR |
| `not` | Logical NOT |

#### Comparison Operators

| Operator | Description |
|----------|-------------|
| `=`, `!=` | Equality/inequality |
| `<`, `<=`, `>`, `>=` | Numeric comparison |
| `contains`, `icontains`, `bcontains` | String/byte containment |
| `startswith`, `bstartswith`, `endswith` | String prefix/suffix |
| `exists` | Field existence check |
| `glob` | Glob pattern matching |
| `in` | Set membership (complete) |
| `intersects` | Set intersection (partial) |
| `pmatch` | Path prefix matching |
| `regex` | RE2 regex matching (full match only) |

#### Transformers

| Transformer | Description |
|-------------|-------------|
| `tolower(<field>)` | Convert to lowercase |
| `toupper(<field>)` | Convert to uppercase |
| `b64(<field>)` | Base64 decode |
| `basename(<field>)` | Extract filename |
| `len(<field>)` | Get length |

#### Field-to-Field Comparison

```yaml
condition: proc.name = val(proc.pname)  # Process name equals parent name
condition: tolower(proc.name) = tolower(proc.pname)
```

#### Event Type and Direction

**Note:** `evt.dir` is deprecated in 0.42.0.

```yaml
# Typical condition structure
condition: evt.type in (open, openat) and fd.typechar='f'
```

### 4.6 Rule Exceptions

**Source:** [`concepts/rules/exceptions.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/exceptions.md)

```yaml
- rule: Write below binary dir
  condition: open_write and bin_dir
  exceptions:
    - name: proc_writer
      fields: [proc.name, fd.directory]
      comps: [=, =]
      values:
        - [my-custom-yum, /usr/bin]
        - [my-custom-apt, /usr/local/bin]
    - name: filenames
      fields: fd.filename
      comps: in
      values: [python, go]
```

**Exception Shortcuts:**
- `values` can be omitted (defined later via override)
- `fields`/`comps` can be single values (not lists) when using `in`/`pmatch`/`intersects`
- `comps` defaults to `=` for lists or `in` for single fields

### 4.7 Overriding Rules

**Source:** [`concepts/rules/overriding.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/overriding.md)

```yaml
# Append to a list
- list: my_programs
  items: [cp]
  override:
    items: append

# Replace list items
- list: my_programs
  items: [vi, vim, nano]
  override:
    items: replace

# Append to macro condition
- macro: access_file
  condition: or evt.type=openat
  override:
    condition: append

# Append condition, replace output
- rule: program_accesses_file
  condition: and not user.name=root
  output: New output message
  override:
    condition: append
    output: replace

# Enable disabled rule
- rule: test_rule
  enabled: true
  override:
    enabled: replace
```

**Override Keys:**
- Lists: `items` (append/replace)
- Macros: `condition` (append/replace)
- Rules (append): `condition`, `output`, `desc`, `tags`, `exceptions`
- Rules (replace): `condition`, `output`, `desc`, `priority`, `tags`, `exceptions`, `enabled`, `warn_evttypes`, `skip-if-unknown-filter`

**Note:** The `append: true` syntax is deprecated and will be removed in Falco 1.0.0.

### 4.8 Controlling Rules

**Source:** [`concepts/rules/controlling-rules.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/controlling-rules.md)

#### Via Configuration (since 0.38.0)

```yaml
rules:
  - disable:
      rule: "*"
  - enable:
      rule: "Netcat Remote Code Execution in Container"
  - enable:
      tag: network
```

```bash
falco -o "rules[].enable.tag=network" -o "rules[].disable.rule=noisy_rule"
```

#### Via Tags

```bash
falco -T filesystem -T cis    # Disable rules with these tags
falco -t filesystem -t cis    # Only run rules with these tags
```

**Common Tags:**
`filesystem`, `software_mgmt`, `process`, `database`, `host`, `shell`, `container`, `cis`, `users`, `network`

#### Via Custom Rule Override

```yaml
- rule: User mgmt binaries
  enabled: false
```

### 4.9 Rules Versioning

**Source:** [`concepts/rules/versioning.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/versioning.md)

```yaml
- required_engine_version: 7

- required_plugin_versions:
  - name: cloudtrail
    version: 0.6.0
```

Check engine version: `falco --version`

### 4.10 Style Guide

**Source:** [`concepts/rules/style-guide.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/style-guide.md)

**Best Practices:**

1. **Always include `evt.type` filter** - Required for performance
2. **Prioritize `evt.type` first** in conditions
3. **Only mix related event types** (e.g., `open`, `openat`, `openat2`)
4. **Use positive `evt.type` expressions** - Avoid `evt.type!=`
5. **Place positive filters before exclusions**
6. **Use `and not` for negation** consistently
7. **Prefer `startswith`/`endswith` over `contains`**
8. **Use parentheses** to clarify precedence

**Output Fields Guidelines:**

Core fields for every rule:
```yaml
output: "... evt_type=%evt.type user=%user.name user_uid=%user.uid user_loginuid=%user.loginuid process=%proc.name proc_exepath=%proc.exepath parent=%proc.pname command=%proc.cmdline terminal=%proc.tty"
```

Network rules add: `connection=%fd.name lport=%fd.lport rport=%fd.rport fd_type=%fd.type`

File rules add: `file=%fd.name`

**Maturity Tags:**
- `maturity_stable`
- `maturity_incubating`
- `maturity_sandbox`
- `maturity_deprecated`

### 4.11 Default and Local Rules

**Source:** [`concepts/rules/default-custom.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/default-custom.md)

Default `rules_files` configuration:
```yaml
rules_files:
  - /etc/falco/falco_rules.yaml
  - /etc/falco/falco_rules.local.yaml
  - /etc/falco/rules.d
```

**Falcoctl for Rules Management:**
```bash
falcoctl index add falcosecurity https://falcosecurity.github.io/falcoctl/index.yaml
falcoctl artifact install falco-rules:3.2.0
```

---

## 5. Event Sources

**Source:** [`concepts/event-sources/`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/_index.md)

### 5.1 Overview

Falco evaluates event streams against security rules. Each event source operates in an isolated thread.

**Built-in:** `syscall` (enabled by default)
**Plugin-based:** Can add additional sources

**Note:** Falco does not support correlating events from different sources.

### 5.2 Managing Event Sources

```bash
# Enable specific sources only
falco --enable-source=syscall --enable-source=k8s_audit

# Disable specific sources
falco --disable-source=syscall

# Run syscall source without driver
falco -o engine.kind=nodriver
```

### 5.3 Kernel Events (Drivers)

**Source:** [`concepts/event-sources/kernel/`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/_index.md)

#### Driver Comparison

| Feature | Modern eBPF | Legacy eBPF | Kernel Module |
|---------|-------------|-------------|---------------|
| Status | Default | Removed in 0.44.0 | Supported |
| Bundled | Yes | No | No |
| Min Kernel (x86_64) | ~5.8 (varies) | 4.14 (pre-0.44) | 3.10 |
| Min Kernel (aarch64) | ~5.8 (varies) | 4.17 (pre-0.44) | 3.10 |
| CO-RE | Yes | No | N/A |
| Install needed | No | Yes | Yes |

#### Modern eBPF Requirements

1. BPF ring buffer support
2. Kernel exposing BTF

Check with:
```bash
sudo bpftool feature probe kernel | grep -q "map_type ringbuf is available" && echo "true"
sudo bpftool feature probe kernel | grep -q "program_type tracing is available" && echo "true"
```

#### Engine Configuration

```yaml
engine:
  kind: modern_ebpf  # or: kmod, ebpf, nodriver
```

Or via CLI: `falco -o engine.kind=modern_ebpf`

#### Least Privileged Mode Capabilities

**Modern eBPF:**
- `CAP_SYS_BPF` (or `CAP_SYS_ADMIN`)
- `CAP_SYS_PERFMON` (or `CAP_SYS_ADMIN`)
- `CAP_SYS_RESOURCE`
- `CAP_SYS_PTRACE`

**Legacy eBPF:**
- `CAP_SYS_ADMIN`
- `CAP_SYS_RESOURCE`
- `CAP_SYS_PTRACE`

**Kernel Module:** Requires full privileges

### 5.4 Kernel Architecture

**Source:** [`concepts/event-sources/kernel/architecture.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/architecture.md)

**libscap** handles driver interaction and event collection.

**Version Negotiation:**
- **API Version:** Communication mechanism between kernel/userspace
- **Schema Version:** Supported event types

Check versions: `falco --version`

**Event Format:**
```c
struct ppm_evt_hdr {
    uint64_t ts;       // timestamp (ns from epoch)
    uint64_t tid;      // thread ID
    uint32_t len;      // event length including header
    uint16_t type;     // event type
    uint32_t nparams;  // number of parameters
};
```

### 5.5 Performance Tuning

**Source:** [`concepts/event-sources/kernel/tuning.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/tuning.md)

#### Adaptive Syscalls Selection

```yaml
base_syscalls:
  custom_set: []       # Additional syscalls to trace
  repair: false        # Auto-select minimal set for state engine
  all: false           # Monitor all events (performance impact!)
```

**Recommended Sets:**
- Process monitoring: `[clone, clone3, fork, vfork, execve, execveat, close]`
- Networking: Add `[socket, bind, getsockopt]`
- UID/GID tracking: Add `[setresuid, setsid, setuid, setgid, setpgid, setresgid, capset, chdir, chroot, fchdir]`

Use `falco -i` to list ignored events.

### 5.6 Dropped Events

**Source:** [`concepts/event-sources/kernel/dropped-events.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/dropped-events.md)

Falco detects dropped syscall events and can take actions:

```yaml
syscall_event_drops:
  actions:
    - log      # Log CRITICAL message
    - alert    # Emit Falco alert
    - exit     # Exit with non-zero code
  # Or: ignore
```

---

## 6. Plugin System

**Source:** [`concepts/plugins/`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/plugins/_index.md)

### 6.1 Overview

Plugins are shared libraries (.so/.dll) extending Falco functionality:
- Add new event sources
- Add new fields for extraction
- Parse event content
- Inject events asynchronously

Plugins are versioned with semantic versioning.

### 6.2 Plugin Capabilities

**Source:** [`concepts/plugins/architecture.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/plugins/architecture.md)

| Capability | Description |
|------------|-------------|
| **Event Sourcing** | Generate events from new sources |
| **Field Extraction** | Extract information from events |
| **Event Parsing** | Hook into event stream for parsing |
| **Async Events** | Inject events asynchronously |

Capabilities are composable - a single plugin can implement multiple.

### 6.3 Plugin Configuration

**Source:** [`concepts/plugins/usage.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/plugins/usage.md)

```yaml
plugins:
  - name: cloudtrail
    library_path: libcloudtrail.so
    init_config: ""
    open_params: ""
  - name: json
    library_path: libjson.so
    init_config: ""

load_plugins: [cloudtrail, json]
```

### 6.4 Plugin Event Sources

Plugins define event sources that:
- Map to rule `source` field
- Must be unique per loaded plugin
- Enable field extraction for matching events

Example sources: `k8s_audit`, `aws_cloudtrail`, `okta`

### 6.5 Plugin Version Compatibility

```yaml
- required_plugin_versions:
  - name: cloudtrail
    version: 0.6.0
```

### 6.6 Available Plugins

**Source:** [`concepts/event-sources/plugins/`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/plugins/_index.md)

| Plugin | Source | Description |
|--------|--------|-------------|
| k8saudit | `k8s_audit` | Kubernetes Audit Events |
| cloudtrail | `aws_cloudtrail` | AWS CloudTrail |
| okta | `okta` | Okta events |

Registry: [github.com/falcosecurity/plugins](https://github.com/falcosecurity/plugins/blob/master/registry.yaml)

### 6.7 Plugin SDKs

- **Go SDK:** [github.com/falcosecurity/plugin-sdk-go](https://github.com/falcosecurity/plugin-sdk-go)
- **C++ SDK:** [github.com/falcosecurity/plugin-sdk-cpp](https://github.com/falcosecurity/plugin-sdk-cpp)
- **Rust SDK:** [github.com/falcosecurity/plugin-sdk-rs](https://github.com/falcosecurity/plugin-sdk-rs)

---

## 7. Outputs and Alerting

**Source:** [`concepts/outputs/`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/outputs/_index.md)

### 7.1 Output Channels

**Source:** [`concepts/outputs/channels.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/outputs/channels.md)

#### Standard Output

```yaml
stdout_output:
  enabled: true
```

Use `-U/--unbuffered` for real-time output (higher CPU).

#### File Output

```yaml
file_output:
  enabled: true
  keep_alive: false  # true = keep file open
  filename: ./events.txt
```

File rotation: Send `SIGUSR1` to reopen file.

#### Syslog Output

```yaml
syslog_output:
  enabled: true
```

Uses `LOG_USER` facility with rule priority as syslog priority.

#### Program Output

```yaml
program_output:
  enabled: true
  keep_alive: false
  program: mail -s "Falco Notification" someone@example.com
```

**Examples:**
```yaml
# Slack webhook
program: "jq '{text: .output}' | curl -d @- -X POST https://hooks.slack.com/services/XXX"

# Network stream
program: "nc host.example.com 1234"
```

#### HTTP/HTTPS Output

```yaml
http_output:
  enabled: true
  url: http://some.url/some/path/
```

Only supports unencrypted HTTP or valid HTTPS certificates.

#### gRPC Output (Deprecated)

**Removed in 0.44.0** - Use HTTP output or Falcosidekick instead.

### 7.2 JSON Output

```yaml
json_output: true
```

JSON format includes:
- `time`: ISO8601 timestamp with nanoseconds
- `rule`: Rule name
- `priority`: Rule priority
- `output`: Formatted output string
- `hostname`: Host name
- `tags`: Rule tags
- `output_fields`: Extracted field values

### 7.3 Output Formatting

**Source:** [`concepts/outputs/formatting.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/outputs/formatting.md)

#### Appending Extra Output

```yaml
append_output:
  - match:
      source: syscall    # Filter by source
      # rule: "Rule Name"  # Or by rule name
      # tags: [container]  # Or by tags
    extra_output: "on CPU %evt.cpu"
    extra_fields:
      - home_directory: "${HOME}"
      - evt.hostname
```

CLI: `falco -o 'append_output[]={"match": {"source": "syscall"}, "extra_output": "on CPU %evt.cpu"}'`

#### Suggested Output Fields

```yaml
append_output:
  - suggested_output: true  # Enable plugin suggested fields
```

### 7.4 Alerts Forwarding (Falcosidekick)

**Source:** [`concepts/outputs/forwarding.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/outputs/forwarding.md)

Falcosidekick is a proxy forwarder supporting 50+ outputs:

**Categories:**
- Chat: Slack, Teams, Discord, Telegram, etc.
- Metrics: Datadog, InfluxDB, Prometheus, etc.
- Alerting: AlertManager, Opsgenie, PagerDuty
- Logs: Elasticsearch, Loki, CloudWatch, etc.
- Object Storage: AWS S3, GCP Storage
- FaaS: AWS Lambda, GCP Cloud Functions, OpenFaaS
- Message Queue: Kafka, NATS, SQS, SNS, RabbitMQ
- SIEM: AWS Security Lake
- Response: Falco Talon

**Installation:**

```bash
# Kubernetes with Helm
helm install falco falcosecurity/falco \
  -n falco --create-namespace \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set tty=true

# Docker
docker run -d -p 2801:2801 -e SLACK_WEBHOOKURL=XXXX falcosecurity/falcosidekick:2.27.0
```

---

## 8. Metrics and Monitoring

**Source:** [`concepts/metrics/`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/metrics/_index.md)

### 8.1 Configuration

```yaml
metrics:
  enabled: true
  interval: 1h
  output_rule: true
  # output_file: /tmp/falco_stats.jsonl
  rules_counters_enabled: true
  resource_utilization_enabled: true
  state_counters_enabled: true
  kernel_event_counters_enabled: true
  kernel_event_counters_per_cpu_enabled: false
  libbpf_stats_enabled: true
  plugins_metrics_enabled: true
  jemalloc_stats_enabled: false
  convert_memory_to_mb: true
  include_empty_values: false
```

### 8.2 Prometheus Support

```yaml
webserver:
  enabled: true
  prometheus_metrics_enabled: true
```

Endpoint: `/metrics` on webserver port.

### 8.3 Key Metrics

**Base Metrics:**
- `falco.version`
- `falco.duration_sec`
- `falco.evts_rate_sec`
- `falco.num_evts`
- `scap.n_drops_perc`

**Resource Utilization:**
- `falco.cpu_usage_perc`
- `falco.memory_rss_mb`
- `falco.memory_vsz_mb`
- `falco.memory_pss_mb`
- `falco.host_cpu_usage_perc`
- `falco.host_memory_used_mb`

**State Counters:**
- `falco.n_threads`
- `falco.n_fds`
- `falco.n_added_threads`
- `falco.n_removed_threads`
- `falco.n_drops_full_threadtable`

**Rules Counters:**
- `falco.rules.<rule_name>`: Match count per rule
- `falco.rules.matches_total`: Total matches

---

## 9. Troubleshooting

**Source:** [`troubleshooting/`](../../../refs/falcosecurity/falco-website/content/en/docs/troubleshooting/_index.md)

### 9.1 Startup Issues

**Source:** [`troubleshooting/start-up-error.md`](../../../refs/falcosecurity/falco-website/content/en/docs/troubleshooting/start-up-error.md)

**Common Issues:**

1. **Kernel Driver Issues:**
   - Check preconditions (bpf syscall allowed, DKMS installed)
   - Verify host mounts: `/etc:/host/etc`, `/proc:/host/proc`, `/boot:/host/boot`, `/dev:/host/dev`
   - Check driver availability: [download.falco.org/driver/site/index.html](https://download.falco.org/driver/site/index.html)
   - For kernel >= 5.8, consider `modern_ebpf`

2. **eBPF Verifier Failures:** Contact maintainers with `uname -r`

3. **Configuration Errors:** Check logs for warnings

### 9.2 Dropped Events

**Source:** [`troubleshooting/dropping.md`](../../../refs/falcosecurity/falco-website/content/en/docs/troubleshooting/dropping.md)

**Action Items:**

1. Adjust `buf_size_preset` in falco.yaml (try 5-6 for kmod/ebpf, 6-7 for modern_ebpf)
2. Use `base_syscalls` to limit monitoring scope
3. Optimize rules to reduce backpressure
4. Try running without plugins

**Buffer Configuration:**
```yaml
engine:
  buf_size_preset: 6  # For kmod/ebpf

  # For modern_ebpf
  modern_ebpf:
    buf_size_preset: 7
    cpus_for_each_buffer: 4
```

**Testing Syscall Sets:**

```yaml
# Test 1: Minimal spawned_process
base_syscalls:
  custom_set: [clone, clone3, fork, vfork, execve, execveat, procexit]
  repair: false

# Test 2: With state engine
base_syscalls:
  custom_set: []
  repair: true
```

**Event Rate Guidelines (per CPU):**
- < 1K/sec: Usually fine
- < 1.5K/sec: Should be fine
- > 3K/sec: May have issues
- 1-2% drops on busy servers: Acceptable

### 9.3 Performance

**Source:** [`troubleshooting/performance.md`](../../../refs/falcosecurity/falco-website/content/en/docs/troubleshooting/performance.md)

**Key Considerations:**

1. **CPU/Memory Utilization:**
   - Falco's hot path is single-threaded
   - Set resource limits via systemd or Kubernetes

2. **Server Load:**
   - Falco utilization depends on workload
   - More syscalls = more Falco work

**Top Metrics to Monitor:**
- CPU usage (percentage of one CPU)
- Memory RSS/VSZ/PSS
- Event counts and drop counts
- Kernel tracepoint invocation counts

---

## 10. Developer Guide

**Source:** [`developer-guide/`](../../../refs/falcosecurity/falco-website/content/en/docs/developer-guide/_index.md)

### 10.1 Building from Source

**Source:** [`developer-guide/source.md`](../../../refs/falcosecurity/falco-website/content/en/docs/developer-guide/source.md)

**Dependencies (Debian/Ubuntu):**
```bash
apt update && apt install git cmake clang build-essential linux-tools-common linux-tools-generic libelf-dev bpftool
```

**Build Steps:**
```bash
git clone https://github.com/falcosecurity/falco.git
cd falco
mkdir -p build
cd build
cmake -DUSE_BUNDLED_DEPS=On ..
make falco
```

**Build Targets:**
- `make falco` - Falco binary
- `make driver` - Kernel module
- `make bpf` - eBPF probe (requires `-DBUILD_BPF=ON`)

**CMake Options:**
- `-DUSE_BUNDLED_DEPS=True` - Bundle dependencies statically
- `-DCMAKE_BUILD_TYPE=Debug` - Debug build
- `-DBUILD_BPF=True` - Enable eBPF build

### 10.2 Plugin Development

**Source:** [`developer-guide/plugins/how-to-develop.md`](../../../refs/falcosecurity/falco-website/content/en/docs/developer-guide/plugins/how-to-develop.md)

**Project Structure:**
```
.
├── Makefile
├── go.mod
├── pkg/
│   └── plugin.go
├── plugin/
│   └── main.go
└── rules/
    └── plugin_rules.yaml
```

**main.go Example:**
```go
package main

import (
    myplugin "github.com/user/myplugin/pkg"
    "github.com/falcosecurity/plugin-sdk-go/pkg/sdk/plugins"
    "github.com/falcosecurity/plugin-sdk-go/pkg/sdk/plugins/extractor"
    "github.com/falcosecurity/plugin-sdk-go/pkg/sdk/plugins/source"
)

const (
    PluginID          uint32 = 999  // Must be unique
    PluginName               = "myplugin"
    PluginDescription        = "My Plugin Description"
    PluginContact            = "github.com/user/myplugin"
    PluginVersion            = "0.1.0"
    PluginEventSource        = "myplugin"
)

func init() {
    plugins.SetFactory(func() plugins.Plugin {
        p := &myplugin.Plugin{}
        p.SetInfo(PluginID, PluginName, PluginDescription, PluginContact, PluginVersion, PluginEventSource)
        extractor.Register(p)
        source.Register(p)
        return p
    })
}

func main() {}
```

**Required Plugin Methods:**
- `Info()` - Return plugin information
- `Init(config string)` - Initialize plugin
- `Fields()` - Define extractable fields
- `Extract()` - Extract field values from events
- `Open()` - Open event stream
- `String()` - Event string representation

**Build:**
```bash
go build -buildmode=c-shared -o libmyplugin.so ./plugin
```

**Registration:** Register plugins at [github.com/falcosecurity/plugins](https://github.com/falcosecurity/plugins/blob/master/registry.yaml)

---

## Supported Fields Reference

**Source:** [`reference/rules/supported-fields/`](../../../refs/falcosecurity/falco-website/content/en/docs/reference/rules/supported-fields/index.md)

### Field Classes

| Class | Description |
|-------|-------------|
| `evt` | Event fields (type, time, args, etc.) |
| `process` / `proc` | Process context (name, pid, cmdline, etc.) |
| `thread` | Thread-specific fields |
| `user` | User information (uid, name, loginuid) |
| `group` | Group information (gid, name) |
| `fd` | File descriptor fields (name, type, ip, port) |
| `fs.path` | Filesystem path fields |
| `container` | Container metadata (via plugin) |
| `k8s` | Kubernetes metadata (pod, namespace, labels) |

### Common Fields

**Event Fields:**
- `evt.type` - Event name (e.g., 'open')
- `evt.time` - Timestamp string
- `evt.arg.<name>` - Event argument by name
- `evt.args` - All arguments as string
- `evt.res` - Return value as string
- `evt.rawres` - Return value as number
- `evt.failed` - True if event failed
- `evt.is_open_read/write/exec/create` - Open flags

**Process Fields:**
- `proc.name` - Process name (16 char limit)
- `proc.exe` - argv[0]
- `proc.exepath` - Full executable path
- `proc.cmdline` - Full command line
- `proc.args` - Command arguments
- `proc.pid` / `proc.ppid` - Process/parent PID
- `proc.aname[N]` / `proc.apid[N]` - Ancestor name/pid
- `proc.cwd` - Current working directory
- `proc.tty` - Controlling terminal
- `proc.is_exe_upper_layer` - Executable in overlayfs upper layer
- `proc.is_exe_from_memfd` - Executable from memfd

**File Descriptor Fields:**
- `fd.name` - FD full name/path
- `fd.directory` - Directory containing file
- `fd.filename` - Filename without path
- `fd.type` / `fd.typechar` - FD type
- `fd.ip` / `fd.cip` / `fd.sip` - IP addresses
- `fd.port` / `fd.lport` / `fd.rport` - Ports
- `fd.l4proto` - Protocol (tcp, udp, icmp)

**Container Fields (via plugin):**
- `container.id` - Container ID (first 12 chars)
- `container.name` - Container name
- `container.image` / `container.image.repository` - Image info
- `container.privileged` - Privileged flag

**Kubernetes Fields (via plugin):**
- `k8s.pod.name` - Pod name
- `k8s.ns.name` - Namespace
- `k8s.pod.uid` - Pod UID
- `k8s.pod.label[key]` - Pod label

Full reference: `falco --list=syscall`

---

## Quick Reference

### Essential Commands

```bash
# Run Falco
falco -c /etc/falco/falco.yaml -r /etc/falco/falco_rules.yaml

# Validate rules
falco -V /path/to/rules.yaml

# List fields
falco --list=syscall

# List events
falco --list-events

# Dry run
falco --dry-run

# Print support info
falco --support
```

### Driver Selection

```bash
# Modern eBPF (default)
falco -o engine.kind=modern_ebpf

# Kernel module
falcoctl driver config --type kmod
falcoctl driver install
falco -o engine.kind=kmod

# Legacy eBPF: removed in 0.44.0 (engine.kind=ebpf no longer exists; use modern_ebpf or kmod)

# No driver (plugins only)
falco -o engine.kind=nodriver
```

### Common Configuration Patterns

```yaml
# Enable JSON output
json_output: true

# Disable syscall source for plugin-only
--disable-source=syscall

# Override config via CLI
-o key=value
-o "key.subkey=value"
-o "list[]=newitem"

# Multiple rules files
-r /path/rules1.yaml -r /path/rules2.yaml
```

---

## Version Information

This digest covers Falco documentation for **Era 0.44**.

**Key Removals in 0.44 (deprecated in earlier releases):**
- gVisor engine (removed)
- Legacy eBPF probe (removed)
- gRPC output and embedded gRPC server (removed)

**Other deprecations still in effect:**
- `append: true` syntax for rules (use `override:` section)
- `evt.dir` field (deprecated in 0.42)
- `--markdown` CLI flag (deprecated in 0.44; use `--format markdown`)

**Default Driver:** Modern eBPF (since 0.38.0)

---

## Source Files Reference

The following source files from the Falco documentation were used to create this digest. All paths are relative to `../../../refs/falcosecurity/falco-website/content/en/docs/`.

### Core Documentation

| Section | Source File |
|---------|-------------|
| Overview | [`_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/_index.md) |

### Installation and Setup

| Topic | Source File |
|-------|-------------|
| Setup Index | [`setup/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/_index.md) |
| Download | [`setup/download.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/download.md) |
| Packages | [`setup/packages.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/packages.md) |
| Tarball | [`setup/tarball.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/tarball.md) |
| Container | [`setup/container.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/container.md) |
| Kubernetes | [`setup/kubernetes.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/kubernetes.md) |
| Environments | [`setup/enviroments.md`](../../../refs/falcosecurity/falco-website/content/en/docs/setup/enviroments.md) |

### Configuration

| Topic | Source File |
|-------|-------------|
| Config Options | [`reference/daemon/config-options/index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/reference/daemon/config-options/index.md) |
| CLI Arguments | [`reference/daemon/cli-arguments/cli-arguments.md`](../../../refs/falcosecurity/falco-website/content/en/docs/reference/daemon/cli-arguments/cli-arguments.md) |

### Rules System

| Topic | Source File |
|-------|-------------|
| Rules Index | [`concepts/rules/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/_index.md) |
| Basic Elements | [`concepts/rules/basic-elements.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/basic-elements.md) |
| Conditions | [`concepts/rules/conditions.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/conditions.md) |
| Exceptions | [`concepts/rules/exceptions.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/exceptions.md) |
| Overriding | [`concepts/rules/overriding.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/overriding.md) |
| Controlling Rules | [`concepts/rules/controlling-rules.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/controlling-rules.md) |
| Versioning | [`concepts/rules/versioning.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/versioning.md) |
| Style Guide | [`concepts/rules/style-guide.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/style-guide.md) |
| Default/Custom | [`concepts/rules/default-custom.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/rules/default-custom.md) |

### Event Sources

| Topic | Source File |
|-------|-------------|
| Event Sources Index | [`concepts/event-sources/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/_index.md) |
| Kernel Index | [`concepts/event-sources/kernel/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/_index.md) |
| Kernel Architecture | [`concepts/event-sources/kernel/architecture.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/architecture.md) |
| Tuning | [`concepts/event-sources/kernel/tuning.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/tuning.md) |
| Dropped Events | [`concepts/event-sources/kernel/dropped-events.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/kernel/dropped-events.md) |

### Plugin System

| Topic | Source File |
|-------|-------------|
| Plugins Index | [`concepts/plugins/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/plugins/_index.md) |
| Architecture | [`concepts/plugins/architecture.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/plugins/architecture.md) |
| Usage | [`concepts/plugins/usage.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/plugins/usage.md) |
| Available Plugins | [`concepts/event-sources/plugins/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/event-sources/plugins/_index.md) |

### Outputs and Alerting

| Topic | Source File |
|-------|-------------|
| Outputs Index | [`concepts/outputs/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/outputs/_index.md) |
| Channels | [`concepts/outputs/channels.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/outputs/channels.md) |
| Formatting | [`concepts/outputs/formatting.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/outputs/formatting.md) |
| Forwarding | [`concepts/outputs/forwarding.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/outputs/forwarding.md) |

### Metrics and Monitoring

| Topic | Source File |
|-------|-------------|
| Metrics | [`concepts/metrics/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/concepts/metrics/_index.md) |

### Troubleshooting

| Topic | Source File |
|-------|-------------|
| Troubleshooting Index | [`troubleshooting/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/troubleshooting/_index.md) |
| Startup Errors | [`troubleshooting/start-up-error.md`](../../../refs/falcosecurity/falco-website/content/en/docs/troubleshooting/start-up-error.md) |
| Dropped Events | [`troubleshooting/dropping.md`](../../../refs/falcosecurity/falco-website/content/en/docs/troubleshooting/dropping.md) |
| Performance | [`troubleshooting/performance.md`](../../../refs/falcosecurity/falco-website/content/en/docs/troubleshooting/performance.md) |

### Developer Guide

| Topic | Source File |
|-------|-------------|
| Developer Index | [`developer-guide/_index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/developer-guide/_index.md) |
| Building from Source | [`developer-guide/source.md`](../../../refs/falcosecurity/falco-website/content/en/docs/developer-guide/source.md) |
| Plugin Development | [`developer-guide/plugins/how-to-develop.md`](../../../refs/falcosecurity/falco-website/content/en/docs/developer-guide/plugins/how-to-develop.md) |

### Reference

| Topic | Source File |
|-------|-------------|
| Supported Fields | [`reference/rules/supported-fields/index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/reference/rules/supported-fields/index.md) |
| Supported Events | [`reference/rules/supported-events/index.md`](../../../refs/falcosecurity/falco-website/content/en/docs/reference/rules/supported-events/index.md) |
