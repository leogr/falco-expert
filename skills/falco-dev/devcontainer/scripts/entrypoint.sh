#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Entrypoint for falco-dev container.
#
# When run as root, adjusts the 'dev' user UID/GID to match the owner of
# /workspace so that files created inside the container are owned by the
# host user. Then drops privileges and executes the command as 'dev'.
#
# When run as non-root, just executes the command directly.

set -euo pipefail

DEV_USER="dev"
DEV_HOME="/home/${DEV_USER}"

if [ "$(id -u)" = "0" ]; then
    # Detect workspace owner UID/GID
    if [ -d /workspace ]; then
        TARGET_UID=$(stat -c %u /workspace)
        TARGET_GID=$(stat -c %g /workspace)

        # Only adjust if workspace is owned by a non-root user
        if [ "$TARGET_UID" != "0" ]; then
            CURRENT_UID=$(id -u "$DEV_USER")
            CURRENT_GID=$(id -g "$DEV_USER")

            # Handle GID conflict: remove any other group holding the target GID
            if [ "$CURRENT_GID" != "$TARGET_GID" ]; then
                EXISTING_GROUP=$(getent group "$TARGET_GID" 2>/dev/null | cut -d: -f1 || true)
                if [ -n "$EXISTING_GROUP" ] && [ "$EXISTING_GROUP" != "$DEV_USER" ]; then
                    groupdel "$EXISTING_GROUP" 2>/dev/null || true
                fi
                groupmod -g "$TARGET_GID" "$DEV_USER" 2>/dev/null || true
            fi

            # Handle UID conflict: remove any other user holding the target UID
            if [ "$CURRENT_UID" != "$TARGET_UID" ]; then
                EXISTING_USER=$(getent passwd "$TARGET_UID" 2>/dev/null | cut -d: -f1 || true)
                if [ -n "$EXISTING_USER" ] && [ "$EXISTING_USER" != "$DEV_USER" ]; then
                    userdel "$EXISTING_USER" 2>/dev/null || true
                fi
                usermod -u "$TARGET_UID" "$DEV_USER" 2>/dev/null || true
            fi

            # Fix ownership of home directory
            chown -R "${TARGET_UID}:${TARGET_GID}" "$DEV_HOME" 2>/dev/null || true

            # Fix root-owned intermediate directories created by Docker for
            # deep bind mounts. When Docker processes a mount like
            #   -v /host/path:/workspace/github.com/falcosecurity/plugins
            # it creates the intermediate directories (github.com/,
            # falcosecurity/) as root. We identify these precisely by reading
            # mount points under /workspace from /proc/self/mountinfo and
            # fixing root-owned parent directories between each mount point
            # and /workspace.
            while IFS= read -r mount_point; do
                dir="$(dirname "$mount_point")"
                while [ "$dir" != "/workspace" ] && [ "$dir" != "/" ]; do
                    if [ "$(stat -c %u "$dir")" = "0" ]; then
                        chown "${TARGET_UID}:${TARGET_GID}" "$dir" 2>/dev/null || true
                    fi
                    dir="$(dirname "$dir")"
                done
            done < <(awk '$5 ~ "^/workspace/.+" {print $5}' /proc/self/mountinfo 2>/dev/null) || true
        fi
    fi

    # Execute command as dev user, preserving environment
    exec su -s /bin/bash -w PATH,GOPATH,HOME "$DEV_USER" -c "$*"
else
    # Already running as non-root, just exec
    exec "$@"
fi
