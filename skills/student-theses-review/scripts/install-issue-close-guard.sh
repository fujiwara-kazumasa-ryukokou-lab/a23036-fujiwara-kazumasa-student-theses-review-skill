#!/usr/bin/env bash
# 学生リポに issue close ガード workflow を配置する
set -euo pipefail

usage() {
  echo "Usage: $0 -r <STUDENT_THESES_ROOT> <repo-name> [repo-name ...]" >&2
  echo "   or: $0 -C <path-to-repo>" >&2
  exit 1
}

ROOT=""
REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r) ROOT="$2"; shift 2 ;;
    -C) REPOS+=("$2"); shift 2 ;;
    -h|--help) usage ;;
    *) REPOS+=("$1"); shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$SKILL_DIR/.github/workflows/issue-close-guard.yml.template"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "error: template not found: $TEMPLATE" >&2
  exit 1
fi

if [[ ${#REPOS[@]} -eq 0 ]]; then
  usage
fi

for name in "${REPOS[@]}"; do
  if [[ -n "$ROOT" ]]; then
    target="$ROOT/$name"
  else
    target="$name"
  fi
  if [[ ! -d "$target/.git" ]]; then
    echo "skip (not a git repo): $target" >&2
    continue
  fi
  mkdir -p "$target/.github/workflows"
  cp "$TEMPLATE" "$target/.github/workflows/issue-close-guard.yml"
  echo "installed: $target/.github/workflows/issue-close-guard.yml"
done
