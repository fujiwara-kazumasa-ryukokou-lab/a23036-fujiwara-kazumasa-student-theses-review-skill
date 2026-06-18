#!/usr/bin/env bash
# List org repos with recent pushes, excluding configured repos.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${script_dir}/lib/common.sh"

JSON_OUT=0

usage() {
	cat <<'EOF'
Usage: list-review-targets.sh [-r ROOT] [--json]

List repositories in ORG pushed within DAYS, excluding EXCLUDE_PREFIX / EXCLUDE_REPOS.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-r | --root)
		STUDENT_THESES_ROOT="$2"
		shift 2
		;;
	--json)
		JSON_OUT=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "error: unknown option: $1" >&2
		exit 2
		;;
	esac
done

require_gh
require_jq

cutoff="$(cutoff_epoch "$DAYS")"
targets='[]'

while IFS=$'\t' read -r pushed name; do
	[[ -z "$name" ]] && continue
	is_excluded_repo "$name" && continue
	[[ "$(to_epoch "$pushed")" -lt "$cutoff" ]] && continue
	targets="$(jq -c --arg n "$name" --arg p "$pushed" '. + [{name: $n, pushed_at: $p}]' <<<"$targets")"
done < <(list_target_repos)

if [[ "$JSON_OUT" -eq 1 ]]; then
	jq -nc --arg org "$ORG" --argjson repos "$targets" '{org: $org, targets: $repos}'
	exit 0
fi

echo "=== review targets (${ORG}, last ${DAYS} days) ==="
jq -r '.[] | "\(.pushed_at)\t\(.name)"' <<<"$targets"
echo
echo "count: $(jq 'length' <<<"$targets")"
