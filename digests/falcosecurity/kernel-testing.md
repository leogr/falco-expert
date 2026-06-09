# kernel-testing Digest

> **Era Relevance:** 0.44 | **Source:** [`refs/falcosecurity/kernel-testing/`](../../refs/falcosecurity/kernel-testing/) | **Commit:** `deca9eb` (February 4, 2026)

**Repository:** [falcosecurity/kernel-testing](https://github.com/falcosecurity/kernel-testing)
**Scope:** Infra
**Status:** Incubating

Automated testing framework for Falco drivers across multiple kernel versions using Firecracker microVMs.

---

## Overview

kernel-testing validates that Falco's kernel drivers (kmod and modern-bpf) work correctly across a wide range of Linux kernels and distributions. It uses [Firecracker](https://firecracker-microvm.github.io/) microVMs to spawn lightweight virtual machines with specific kernel versions, then runs driver tests inside each VM.

**Purpose:**
- Validate driver compatibility across kernel versions (3.10 to 6.x)
- Test both kernel module (kmod) and modern eBPF drivers
- Provide CI/CD integration for the libs repository
- Generate compatibility matrices for driver releases

**Key tool tested:** `scap-open` - A minimal libscap example that opens system event capture

**Source:** [`README.md`](../../refs/falcosecurity/kernel-testing/README.md), [`architecture.md`](../../refs/falcosecurity/kernel-testing/architecture.md)

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           kernel-testing Architecture                         │
└──────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────────┐
                              │   GitHub Actions    │
                              │   (libs CI/CD)      │
                              └──────────┬──────────┘
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │  kernel-testing     │
                              │  composite action   │
                              └──────────┬──────────┘
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │  Ansible Playbooks  │
                              │                     │
                              │  - bootstrap.yml    │
                              │  - common.yml       │
                              │  - git-repos.yml    │
                              │  - scap-open.yml    │
                              │  - clean-up.yml     │
                              └──────────┬──────────┘
                                         │
            ┌────────────────────────────┼────────────────────────────┐
            │                            │                            │
            ▼                            ▼                            ▼
    ┌───────────────┐           ┌───────────────┐           ┌───────────────┐
    │  Firecracker  │           │  Firecracker  │           │  Firecracker  │
    │  MicroVM 1    │           │  MicroVM 2    │           │  MicroVM N    │
    │               │           │               │           │               │
    │ centos-3.10   │           │ ubuntu-6.5    │           │ fedora-6.2    │
    │ (x86_64)      │           │ (x86_64)      │           │ (aarch64)     │
    └───────┬───────┘           └───────┬───────┘           └───────┬───────┘
            │                           │                           │
            ▼                           ▼                           ▼
    ┌───────────────┐           ┌───────────────┐           ┌───────────────┐
    │ Test Results  │           │ Test Results  │           │ Test Results  │
    │ - kmod build  │           │ - kmod build  │           │ - kmod build  │
    │ - kmod test   │           │ - kmod test   │           │ - kmod test   │
    │ - modern-bpf  │           │ - modern-bpf  │           │ - modern-bpf  │
    └───────────────┘           └───────────────┘           └───────────────┘
```

**Source:** [`architecture.md`](../../refs/falcosecurity/kernel-testing/architecture.md)

## VM Components

Each Firecracker microVM requires three components, delivered via OCI images:

| Component | Source | Description |
|-----------|--------|-------------|
| `vmlinux` | `*-kernel` image | Kernel binary for the target kernel version |
| `initrd` | `*-kernel` image | Initial ramdisk |
| `rootfs` | `*-image` image | Root filesystem (ext4 disk image) |

**Image registry:** `ghcr.io/falcosecurity/kernel-testing`

**Example image names:**
- `ghcr.io/falcosecurity/kernel-testing/ubuntu-kernel:6.5-x86_64-v0.3.2`
- `ghcr.io/falcosecurity/kernel-testing/ubuntu-image:6.5-x86_64-v0.3.2`

**Source:** [`architecture.md`](../../refs/falcosecurity/kernel-testing/architecture.md)

## Supported Test Matrix

### x86_64 Kernels

| Distribution | Kernel Versions |
|--------------|-----------------|
| Amazon Linux 2 | 4.19, 5.4, 5.10, 5.15 |
| Amazon Linux 2022 | 5.15 |
| Amazon Linux 2023 | 6.1 |
| Arch Linux | 6.0, 6.7 |
| CentOS | 3.10, 4.18, 5.14 |
| Fedora | 5.8, 5.17, 6.2 |
| Oracle Linux | 3.10, 4.14, 5.4, 5.15 |
| Ubuntu | 5.8, 6.5 |

### aarch64 Kernels

| Distribution | Kernel Versions |
|--------------|-----------------|
| Amazon Linux 2 | 5.4 |
| Amazon Linux 2022 | 5.15 |
| Fedora | 6.2 |
| Oracle Linux | 4.14, 5.15 |
| Ubuntu | 6.5 |

**Source:** [`ansible-playbooks/group_vars/all/vars.yml`](../../refs/falcosecurity/kernel-testing/ansible-playbooks/group_vars/all/vars.yml)

## Tests Performed

For each kernel/distro combination:

### 1. Kernel Module (kmod) Test
```
1. Clone libs repository into VM
2. Configure with cmake (USE_BUNDLED_DEPS=ON)
3. Build kernel module: cmake --build . --target driver
4. Load module: insmod driver/scap.ko
5. Run test: /tmp/scap-open --num_events 50 --kmod
6. Unload module: rmmod driver/scap.ko
```

### 2. Modern eBPF Test (if supported)
```
1. Check support: /tmp/scap-open --num_events 0 --modern_bpf
2. If supported, run: /tmp/scap-open --num_events 50 --modern_bpf
```

**Output files per VM:**
- `cmake-configure.json` - CMake configuration result
- `kmod_build.json` - Kernel module build result
- `kmod_scap-open.json` - Kmod test result
- `modern-bpf_scap-open.json` - Modern BPF test result

**Source:** [`ansible-playbooks/roles/scap_open/tasks/main.yml`](../../refs/falcosecurity/kernel-testing/ansible-playbooks/roles/scap_open/tasks/main.yml)

## GitHub Action Usage

kernel-testing provides a composite action for CI integration:

```yaml
- uses: falcosecurity/kernel-testing@main
  id: kernel_tests
  with:
    # libs version to test (branch, tag, or commit)
    libsversion: master

    # libs repository (fork support)
    libsrepo: falcosecurity/libs

    # Generate compatibility matrix artifact
    build_matrix: 'true'

    # Required: images tag (vX.Y.Z format)
    images_tag: 'v0.3.2'

# Upload test results
- uses: actions/upload-artifact@latest
  with:
    name: ansible_output
    path: ${{ steps.kernel_tests.outputs.ansible_output }}

- uses: actions/upload-artifact@latest
  with:
    name: matrix
    path: ${{ steps.kernel_tests.outputs.matrix_output }}
```

**Requirements:** Must run on virtualization-enabled nodes (KVM support).

**Reference:** [libs reusable workflow](https://github.com/falcosecurity/libs/blob/master/.github/workflows/reusable_kernel_tests.yaml)

**Source:** [`action.yml`](../../refs/falcosecurity/kernel-testing/action.yml), [`README.md`](../../refs/falcosecurity/kernel-testing/README.md)

## Local Usage

### Prerequisites

- Ansible >= 2.16.3
- Firecracker >= 1.13.1
- Docker
- Go >= 1.25.4
- KVM support (virtualization enabled)

### Running Tests

```shell
cd ansible-playbooks

# Configure SSH key in local vars.yml
cat > local-vars.yml <<EOF
ssh_key_path: "/path/to/ssh/keys"
ssh_key_name: "my_key"
run_id: "test-run-1"
EOF

# Run full test suite
ansible-playbook main-playbook.yml --ask-become --extra-vars "@local-vars.yml"

# Rerun tests only (VMs already bootstrapped)
ansible-playbook scap-open.yml --ask-become --extra-vars "@local-vars.yml"

# Clean up VMs
ansible-playbook clean-up.yml --ask-become --extra-vars "@local-vars.yml"
```

**Source:** [`README.md`](../../refs/falcosecurity/kernel-testing/README.md)

## Networking

Each VM connects via TAP interface with dedicated `/30` subnet from `172.16.0.0/16`:

```
┌─────────────┐     TAP Interface      ┌─────────────┐
│    Host     │◄──────────────────────►│  MicroVM    │
│             │                        │             │
│ 172.16.X.1  │                        │ 172.16.X.2  │
└─────────────┘                        └─────────────┘
       │
       ▼
    Internet (NAT)
```

**Host requirements:**
- IPv4 forwarding enabled
- Reverse path filtering disabled
- NAT for `172.16.0.0/16` traffic
- FORWARD chain allows `172.16.0.0/16`

**Source:** [`architecture.md`](../../refs/falcosecurity/kernel-testing/architecture.md)

## Integration with Falco Ecosystem

kernel-testing ensures driver compatibility before releases:

```
libs development ──▶ kernel-testing ──▶ driver release
                          │
                          ▼
                    Compatibility matrix
                    (kernel X distro)
```

**Used by:**
- **libs CI/CD** - Tests driver changes across kernels
- **Release process** - Validates driver compatibility before releases

**Related repositories:**
- **[libs](https://github.com/falcosecurity/libs)** - Driver source code being tested
- **[driverkit](https://github.com/falcosecurity/driverkit)** - Builds production drivers
- **[kernel-crawler](https://github.com/falcosecurity/kernel-crawler)** - Discovers kernel versions

**Source:** [`README.md`](../../refs/falcosecurity/kernel-testing/README.md)

## Sources

| Topic | Source File |
|-------|-------------|
| Overview, usage | [`README.md`](../../refs/falcosecurity/kernel-testing/README.md) |
| Architecture | [`architecture.md`](../../refs/falcosecurity/kernel-testing/architecture.md) |
| GitHub Action | [`action.yml`](../../refs/falcosecurity/kernel-testing/action.yml) |
| VM configuration | [`ansible-playbooks/group_vars/all/vars.yml`](../../refs/falcosecurity/kernel-testing/ansible-playbooks/group_vars/all/vars.yml) |
| Test tasks | [`ansible-playbooks/roles/scap_open/tasks/main.yml`](../../refs/falcosecurity/kernel-testing/ansible-playbooks/roles/scap_open/tasks/main.yml) |

## Related Documentation

- [`libs/kernel-instrumentation.md`](libs/kernel-instrumentation.md) - Driver architecture being tested
- [`libs/modern-bpf.md`](libs/modern-bpf.md) - Modern eBPF driver details
- [`driverkit.md`](driverkit.md) - Production driver building
- [`kernel-crawler.md`](kernel-crawler.md) - Kernel version discovery
- [`evolution.md`](evolution.md) - Infra scope repositories
