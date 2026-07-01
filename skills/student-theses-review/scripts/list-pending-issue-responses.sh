#!/usr/bin/env bash
# List open issues where a non-supervisor commented after the last supervisor comment.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${script_dir}/lib/common.sh"

JSON_OUT=0
ISSUE_DAYS="${ISSUE_DAYS:-30}"

usage() {
	cat <<'EOF'
Usage: list-pending-issue-responses.sh [--json]

Scan org open issues (per-repo via gh issue list) for unreplied student/external comments.

Environment:
  ISSUE_DAYS         Only issues updated within this many days (default: 30)
  SUPERVISOR_LOGINS  Comma-separated supervisor GitHub logins
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
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

cutoff="$(cutoff_epoch "$ISSUE_DAYS")"
pending='[]'
ok_count=0

scan_issue() {
	local repo="$1"
	local row="$2"
	local updated num title

	updated="$(jq -r '.updatedAt' <<<"$row")"
	[[ "$(to_epoch "$updated")" -lt "$cutoff" ]] && return 0

	num="$(jq -r '.number' <<<"$row")"
	title="$(jq -r '.title' <<<"$row")"

	comments_json="$(gh api "repos/${ORG}/${repo}/issues/${num}/comments" --jq '.' 2>/dev/null || echo '[]')"
	[[ "$comments_json" == "[]" ]] && return 0

	count="$(jq 'length' <<<"$comments_json")"
	last_supervisor_idx=-1
	for ((idx = 0; idx < count; idx++)); do
		author="$(jq -r ".[$idx].user.login" <<<"$comments_json")"
		is_supervisor_login "$author" && last_supervisor_idx=$idx
	done

	needs_reply=0
	for ((idx = last_supervisor_idx + 1; idx < count; idx++)); do
		author="$(jq -r ".[$idx].user.login" <<<"$comments_json")"
		body="$(jq -r ".[$idx].body" <<<"$comments_json")"
		created="$(jq -r ".[$idx].created_at" <<<"$comments_json")"
		if ! is_supervisor_login "$author" && ! is_bot_login "$author"; then
			needs_reply=1
			excerpt="$(printf '%s' "$body" | tr '\n' ' ' | cut -c1-160)"
			url="https://github.com/${ORG}/${repo}/issues/${num}"
			pending="$(jq -c \
				--arg repo "$repo" \
				--argjson num "$num" \
				--arg title "$title" \
				--arg author "$author" \
				--arg created "$created" \
				--arg excerpt "$excerpt" \
				--arg url "$url" \
				'. + [{repo: $repo, number: $num, title: $title, author: $author, created_at: $created, excerpt: $excerpt, url: $url}]' \
				<<<"$pending")"
		fi
	done

	if [[ "$needs_reply" -eq 0 ]]; then
		ok_count=$((ok_count + 1))
	fi
}

while IFS= read -r repo; do
	[[ -z "$repo" ]] && continue
	is_excluded_repo "$repo" && continue

	repo_issues="$(gh issue list --repo "${ORG}/${repo}" --state open \
		--json number,title,updatedAt 2>/dev/null || true)"
	[[ -z "$repo_issues" || "$repo_issues" == "[]" ]] && continue

	while IFS= read -r row; do
		[[ -z "$row" ]] && continue
		scan_issue "$repo" "$row"
	done < <(jq -c '.[]' <<<"$repo_issues")
done < <(gh repo list "$ORG" --limit "$LIMIT" --json name -q '.[].name' 2>/dev/null || true)

if [[ "$JSON_OUT" -eq 1 ]]; then
	printf '%s\n' "$pending"
	exit 0
fi

echo "=== pending issue responses (${ORG}) ==="
if [[ "$(jq 'length' <<<"$pending")" -gt 0 ]]; then
	echo "PENDING (要対処):"
	jq -r '.[] | "  \(.repo)#\(.number)  \(.url)\n    author: \(.author)\n    at: \(.created_at)\n    excerpt: \(.excerpt)"' <<<"$pending"
else
	echo "PENDING: (none)"
fi
echo
echo "OK (指導者が最後に返信済み): ${ok_count} issue(s)"
echo "pending_count: $(jq 'length' <<<"$pending")"
