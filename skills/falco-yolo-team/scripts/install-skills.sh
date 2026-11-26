#!/usr/bin/env bash
# Link every falco-expert skill into an agent skill directory, without replacing anything.
# Usage: install-skills.sh --skills-dir DIR [--dry-run]
set -euo pipefail

skills_dir="" dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skills-dir) skills_dir="${2:?--skills-dir needs a value}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) sed -n 2,3p "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$skills_dir" ] || { echo "--skills-dir is required" >&2; exit 2; }

src_root="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd -P)"
[ -f "$src_root/../AGENTS.md" ] || { echo "refused: $src_root is not falco-expert/skills" >&2; exit 1; }

[ "$dry_run" = 1 ] || mkdir -p "$skills_dir"
status=0
for skill in "$src_root"/*/; do
  skill="${skill%/}"
  name="$(basename "$skill")"
  [ -f "$skill/SKILL.md" ] || continue
  case "$name" in *-workspace) continue ;; esac
  link="$skills_dir/$name"
  if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$skill" ]; then
    echo "already installed: $link"
  elif [ -e "$link" ] || [ -L "$link" ]; then
    echo "conflict preserved: $link -> $(readlink "$link" 2>/dev/null || echo 'not a symlink')" >&2
    status=1
  elif [ "$dry_run" = 1 ]; then
    echo "would install: $link -> $skill"
  else
    ln -s "$skill" "$link"
    echo "installed: $link -> $skill"
  fi
done
exit "$status"
