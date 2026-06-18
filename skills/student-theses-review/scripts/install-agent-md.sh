#!/usr/bin/env bash
# Install agent.md from template to student-theses workspace (or custom path).
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
template="${skill_dir}/references/agent.md.template"

TARGET_DIR=""
SKILL_DIR="$skill_dir"
FORCE=0

usage() {
	cat <<'EOF'
Usage: install-agent-md.sh -r STUDENT_THESES_ROOT [OPTIONS]

Copy references/agent.md.template to <target>/agent.md with paths filled in.

Options:
  -r, --root PATH     student-theses workspace root (required)
  -t, --target PATH   Output directory (default: same as --root)
  -s, --skill-dir PATH  Skill directory (default: parent of this script)
  -f, --force         Overwrite existing agent.md
  -h, --help          Show help

Examples:
  install-agent-md.sh -r ~/student-theses
  install-agent-md.sh -r ~/student-theses -s ~/.cursor/skills/student-theses-review
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-r | --root)
		STUDENT_THESES_ROOT="$2"
		shift 2
		;;
	-t | --target)
		TARGET_DIR="$2"
		shift 2
		;;
	-s | --skill-dir)
		SKILL_DIR="$2"
		shift 2
		;;
	-f | --force)
		FORCE=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "error: unknown option: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

[[ -n "${STUDENT_THESES_ROOT:-}" ]] || {
	echo "error: -r/--root is required" >&2
	exit 2
}

[[ -f "$template" ]] || {
	echo "error: template not found: ${template}" >&2
	exit 1
}

TARGET_DIR="${TARGET_DIR:-$STUDENT_THESES_ROOT}"
OUT="${TARGET_DIR}/agent.md"

[[ -f "$OUT" && "$FORCE" -ne 1 ]] && {
	echo "error: ${OUT} already exists (use --force)" >&2
	exit 1
}

mkdir -p "$TARGET_DIR"

sed \
	-e "s|<STUDENT_THESES_ROOT>|${STUDENT_THESES_ROOT}|g" \
	-e "s|<SKILL_DIR>|${SKILL_DIR}|g" \
	"$template" >"$OUT"

echo "installed: ${OUT}"
echo "skill_dir: ${SKILL_DIR}"
echo "student_theses_root: ${STUDENT_THESES_ROOT}"
