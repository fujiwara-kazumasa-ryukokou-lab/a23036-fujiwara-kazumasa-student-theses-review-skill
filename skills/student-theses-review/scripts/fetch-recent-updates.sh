#!/usr/bin/env bash
# Fast fetch for recently pushed repos under student-theses workspace.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${script_dir}/lib/common.sh"

JSON_OUT=0

usage() {
	cat <<'EOF'
Usage: fetch-recent-updates.sh [-r ROOT] [--json]

Fetch and fast-forward recently pushed repos (excluding configured repos).
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

ROOT="$(resolve_student_theses_root)" || {
	echo "error: STUDENT_THESES_ROOT not found. Pass -r/--root." >&2
	exit 1
}

cutoff="$(cutoff_epoch "$DAYS")"
updated='[]'
uptodate='[]'
missing='[]'
failed='[]'

sync_one() {
	local name="$1"
	local dir="${ROOT}/${name}"

	if [[ ! -d "$dir/.git" ]]; then
		missing="$(jq -c --arg n "$name" '. + [$n]' <<<"$missing")"
		echo "MISSING ${name}"
		return 0
	fi

	local before branch remote_sha after
	before="$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo none)"
	branch="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo main)"

	if ! run_git -C "$dir" fetch origin -q 2>&1; then
		failed="$(jq -c --arg e "${name}: fetch timed out or failed" '. + [$e]' <<<"$failed")"
		echo "FAIL ${name}: fetch timed out or failed"
		return 0
	fi

	remote_sha="$(git -C "$dir" rev-parse "origin/${branch}" 2>/dev/null || true)"
	if [[ -z "$remote_sha" ]]; then
		failed="$(jq -c --arg e "${name}: origin/${branch} not found" '. + [$e]' <<<"$failed")"
		echo "FAIL ${name}: origin/${branch} not found"
		return 0
	fi

	if [[ "$before" == "$remote_sha" ]]; then
		uptodate="$(jq -c --arg n "$name" '. + [$n]' <<<"$uptodate")"
		echo "UPTODATE ${name}"
		return 0
	fi

	if ! run_git -C "$dir" merge --ff-only "origin/${branch}" -q 2>/dev/null; then
		if ! run_git -C "$dir" pull --ff-only -q 2>/dev/null; then
			failed="$(jq -c --arg e "${name}: non-fast-forward" '. + [$e]' <<<"$failed")"
			echo "FAIL ${name}: non-fast-forward"
			return 0
		fi
	fi

	after="$(git -C "$dir" rev-parse HEAD)"
	updated="$(jq -c --arg n "$name" --arg b "$before" --arg a "$after" \
		'. + [{name: $n, before: $b, after: $a}]' <<<"$updated")"
	echo "UPDATED ${name}: ${before} -> ${after}"
	git -C "$dir" log --oneline "${before}..${after}" 2>/dev/null | head -5 | sed 's/^/  /' || true
}

if [[ "$JSON_OUT" -eq 0 ]]; then
	echo "=== fetch recent updates (${ORG}) ==="
	echo "root: ${ROOT}"
	echo
fi

while IFS=$'\t' read -r pushed name; do
	[[ -z "$name" ]] && continue
	is_excluded_repo "$name" && continue
	[[ "$(to_epoch "$pushed")" -lt "$cutoff" ]] && continue
	sync_one "$name"
done < <(list_target_repos)

if [[ "$JSON_OUT" -eq 1 ]]; then
	jq -nc \
		--arg root "$ROOT" \
		--argjson updated "$updated" \
		--argjson uptodate "$uptodate" \
		--argjson missing "$missing" \
		--argjson failed "$failed" \
		'{root: $root, updated: $updated, uptodate: $uptodate, missing: $missing, failed: $failed}'
	exit "$(jq 'length' <<<"$failed")"
fi

echo
echo "=== summary ==="
if [[ "$(jq 'length' <<<"$updated")" -gt 0 ]]; then
	echo "更新あり:"
	jq -r '.[] | "  - \(.name)"' <<<"$updated"
fi
if [[ "$(jq 'length' <<<"$uptodate")" -gt 0 ]]; then
	echo "更新なし:"
	jq -r '.[]' <<<"$uptodate" | sed 's/^/  - /'
fi
if [[ "$(jq 'length' <<<"$missing")" -gt 0 ]]; then
	echo "未 clone:"
	jq -r '.[]' <<<"$missing" | sed 's/^/  - /'
fi
if [[ "$(jq 'length' <<<"$failed")" -gt 0 ]]; then
	echo "失敗:"
	jq -r '.[]' <<<"$failed" | sed 's/^/  - /'
	exit 1
fi
