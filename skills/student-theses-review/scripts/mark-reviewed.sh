#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${script_dir}/lib/common.sh"

usage() {
	cat <<'EOF'
Usage: mark-reviewed.sh [-r ROOT] <repo-name> [sha]

Record reviewed commit SHA (default: current HEAD of local clone).
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-r | --root)
		STUDENT_THESES_ROOT="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	-*)
		echo "error: unknown option: $1" >&2
		exit 2
		;;
	*)
		break
		;;
	esac
done

[[ $# -ge 1 ]] || {
	usage >&2
	exit 2
}

require_jq

ROOT="$(resolve_student_theses_root)" || {
	echo "error: STUDENT_THESES_ROOT not found. Pass -r/--root." >&2
	exit 1
}

REPO_NAME="$1"
SHA="${2:-}"
DIR="${ROOT}/${REPO_NAME}"
STATE_FILE="${ROOT}/log/review-state.json"

if [[ -z "$SHA" ]]; then
	[[ -d "$DIR/.git" ]] || {
		echo "error: not a git repo: ${DIR}" >&2
		exit 1
	}
	SHA="$(git -C "$DIR" rev-parse HEAD)"
fi

mkdir -p "${ROOT}/log"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

if [[ -f "$STATE_FILE" ]]; then
	jq --arg repo "$REPO_NAME" --arg sha "$SHA" --arg now "$NOW" \
		'.repos[$repo] = {last_reviewed_sha: $sha, last_reviewed_at: $now}' \
		"$STATE_FILE" >"${STATE_FILE}.tmp"
else
	jq -n --arg repo "$REPO_NAME" --arg sha "$SHA" --arg now "$NOW" \
		'{repos: {($repo): {last_reviewed_sha: $sha, last_reviewed_at: $now}}}' \
		>"${STATE_FILE}.tmp"
fi
mv "${STATE_FILE}.tmp" "$STATE_FILE"

echo "marked: ${REPO_NAME} @ ${SHA:0:7}"
echo "state: ${STATE_FILE}"
