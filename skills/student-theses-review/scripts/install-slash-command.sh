#!/usr/bin/env bash
# Install Cursor slash command for student-theses-review.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
skill_repo_root="$(cd "${skill_dir}/../.." && pwd)"
source_cmd="${skill_repo_root}/commands/student-theses-review.md"

SCOPE="project"
TARGET_ROOT=""
FORCE=0
GLOBAL=0

usage() {
	cat <<'EOF'
Usage: install-slash-command.sh [OPTIONS]

Install /student-theses-review slash command for Cursor.

Options:
  -r, --root PATH   student-theses workspace root (for project scope)
  --global          Install to ~/.cursor/commands/ (all projects)
  --project         Install to <root>/.cursor/commands/ (default)
  -f, --force       Overwrite existing command file
  -h, --help        Show help

Examples:
  install-slash-command.sh -r /path/to/student-theses
  install-slash-command.sh --global -f
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-r | --root)
		TARGET_ROOT="$2"
		shift 2
		;;
	--global)
		GLOBAL=1
		SCOPE="global"
		shift
		;;
	--project)
		SCOPE="project"
		shift
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

[[ -f "$source_cmd" ]] || {
	echo "error: command source not found: ${source_cmd}" >&2
	exit 1
}

if [[ "$GLOBAL" -eq 1 ]]; then
	dest_dir="${HOME}/.cursor/commands"
else
	[[ -n "$TARGET_ROOT" ]] || {
		echo "error: -r/--root required for project install" >&2
		exit 2
	}
	dest_dir="${TARGET_ROOT}/.cursor/commands"
fi

mkdir -p "$dest_dir"
dest="${dest_dir}/student-theses-review.md"

[[ -e "$dest" && "$FORCE" -ne 1 ]] && {
	echo "error: ${dest} already exists (use --force)" >&2
	exit 1
}

if [[ "$GLOBAL" -eq 1 ]]; then
	# WSL / NTFS: prefer copy over symlink
	cp "$source_cmd" "$dest"
	echo "installed (copy): ${dest}"
else
	cp "$source_cmd" "$dest"
	echo "installed (copy): ${dest}"
fi

echo "slash: /student-theses-review"
echo "scope: ${SCOPE}"
