# SPDX-License-Identifier: Apache-2.0
#
# Falco Development Container
#
# Provides a complete build environment for Falco and its core components
# (falco, libs, rules, testing). Supports CMake builds with bundled deps,
# modern eBPF skeleton generation, and Go-based testing.
#
# Usage:
#   docker build -t falco-dev skills/falco-dev/devcontainer/
#   docker run -d --name falco-dev-<session-id> --label falco-dev.session=true -v ./workspace:/workspace falco-dev

FROM ubuntu:24.04

ARG TARGETARCH
ARG CMAKE_VERSION=3.31.6
ARG BPFTOOL_VERSION=7.3.0
ARG GO_VERSION=1.23.6

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# System packages: build toolchain, dev libraries, debugging tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build toolchain
    build-essential \
    clang \
    clangd \
    llvm \
    git \
    pkg-config \
    autoconf \
    automake \
    libtool \
    # Dev libraries (for libs with USE_BUNDLED_DEPS=OFF or system fallbacks)
    libelf-dev \
    libtbb-dev \
    libjq-dev \
    libjsoncpp-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libgtest-dev \
    libre2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libyaml-cpp-dev \
    zlib1g-dev \
    # Kernel headers for driver builds
    linux-headers-generic \
    # Debugging tools
    gdb \
    valgrind \
    strace \
    # Utilities
    curl \
    wget \
    jq \
    vim \
    less \
    sudo \
    ca-certificates \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# CMake (newer than Ubuntu 24.04's 3.28)
RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl -fsSL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${ARCH_SUFFIX}.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local

# bpftool (required for modern eBPF skeleton generation)
RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "amd64") && \
    curl -fsSL "https://github.com/libbpf/bpftool/releases/download/v${BPFTOOL_VERSION}/bpftool-v${BPFTOOL_VERSION}-${ARCH_SUFFIX}.tar.gz" \
    | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/bpftool

# Go toolchain (for falcosecurity/testing)
RUN ARCH_SUFFIX=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH_SUFFIX}.tar.gz" \
    | tar -xz -C /usr/local
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/home/dev/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# pre-commit (for code formatting hooks in falco/libs repos)
RUN pip3 install --break-system-packages pre-commit

# Remove default ubuntu user (frees UID 1000 for the dev user)
RUN userdel -r ubuntu 2>/dev/null || true

# Create dev user with passwordless sudo (UID 1000 by default, adjusted at runtime)
RUN useradd -m -s /bin/bash -u 1000 dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev

# Create workspace directory
RUN mkdir -p /workspace && chown dev:dev /workspace

# Copy scripts
COPY scripts/setup-workspace.sh /usr/local/bin/setup-workspace
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/setup-workspace /usr/local/bin/entrypoint

# Configure git defaults for dev user
RUN su -s /bin/bash dev -c "\
    git config --global init.defaultBranch main && \
    git config --global --add safe.directory '*'"

WORKDIR /workspace

ENTRYPOINT ["entrypoint"]
CMD ["sleep", "infinity"]
