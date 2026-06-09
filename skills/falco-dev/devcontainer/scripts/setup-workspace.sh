#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Setup workspace with falcosecurity repositories.
#
# Usage:
#   setup-workspace                    # Clone all repos (falco, libs, rules, testing)
#   setup-workspace falco libs         # Clone only specified repos
#   setup-workspace --install-hooks    # Install pre-commit hooks on all existing repos
#   setup-workspace --install-hooks falco libs  # Install hooks on specific repos
#   setup-workspace --help             # Show help
#
# Repos are cloned into /workspace/github.com/falcosecurity/<repo>/

set -euo pipefail

WORKSPACE="${WORKSPACE:-/workspace}"
ORG_DIR="${WORKSPACE}/github.com/falcosecurity"
ALL_REPOS=(falco libs rules testing)

usage() {
    echo "Usage: $(basename "$0") [OPTIONS] [REPO...]"
    echo
    echo "Clone falcosecurity repositories into the workspace."
    echo
    echo "Available repos: ${ALL_REPOS[*]}"
    echo
    echo "If no repos are specified, all repos are cloned."
    echo
    echo "Options:"
    echo "  --install-hooks  Install pre-commit hooks on existing repos (skip cloning)"
    echo "  --help           Show this help message"
}

install_hooks() {
    local dest="$1"
    local repo="$2"

    if [ ! -f "${dest}/.pre-commit-config.yaml" ]; then
        return 0
    fi

    if ! command -v pre-commit &>/dev/null; then
        echo "  [warn] pre-commit not found — skipping hook installation for ${repo}"
        return 0
    fi

    echo "  [hooks] Installing pre-commit hooks for ${repo}"
    (cd "${dest}" && pre-commit install --install-hooks --hook-type pre-commit --overwrite 2>&1 | tail -1)
    (cd "${dest}" && pre-commit install --install-hooks --hook-type prepare-commit-msg --overwrite 2>&1 | tail -1)
}

clone_repo() {
    local repo="$1"
    local dest="${ORG_DIR}/${repo}"

    if [ -d "${dest}/.git" ]; then
        echo "  [skip] ${repo} — already exists at ${dest}"
        install_hooks "${dest}" "${repo}"
        return 0
    fi

    echo "  [clone] ${repo} → ${dest}"
    git clone "https://github.com/falcosecurity/${repo}.git" "${dest}"
    git -C "${dest}" config --local safe.directory "${dest}"
    install_hooks "${dest}" "${repo}"
}

do_install_hooks() {
    local repos=("$@")
    echo "=== Installing Pre-commit Hooks ==="
    echo "Workspace: ${WORKSPACE}"
    echo "Repos: ${repos[*]}"
    echo

    for repo in "${repos[@]}"; do
        local dest="${ORG_DIR}/${repo}"
        if [ -d "${dest}/.git" ]; then
            install_hooks "${dest}" "${repo}"
        else
            echo "  [skip] ${repo} — not found at ${dest}"
        fi
    done

    echo
    echo "=== Hook Installation Complete ==="
}

main() {
    if [[ "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    if [[ "${1:-}" == "--install-hooks" ]]; then
        shift
        local repos=("${@:-${ALL_REPOS[@]}}")
        do_install_hooks "${repos[@]}"
        exit 0
    fi

    local repos=("${@:-${ALL_REPOS[@]}}")

    echo "=== Falco Workspace Setup ==="
    echo "Workspace: ${WORKSPACE}"
    echo "Repos: ${repos[*]}"
    echo

    mkdir -p "${ORG_DIR}"

    for repo in "${repos[@]}"; do
        clone_repo "${repo}"
    done

    echo
    echo "=== Setup Complete ==="
    echo "Workspace layout:"
    for repo in "${repos[@]}"; do
        local dest="${ORG_DIR}/${repo}"
        if [ -d "${dest}/.git" ]; then
            local branch
            branch=$(git -C "${dest}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
            echo "  ${dest} (branch: ${branch})"
        fi
    done
}

# Handle the case where no arguments means "all repos"
if [ $# -eq 0 ]; then
    main "${ALL_REPOS[@]}"
else
    main "$@"
fi
