#!/usr/bin/env bash
# List open issues where a non-supervisor commented after the last supervisor comment.
set -euo pipefail

ORG="${ORG:-fujiwara-kazumasa-ryukokou-lab}"
EXCLUDE_PREFIX="${EXCLUDE_PREFIX:-a23036}"
SUPERVISOR_LOGINS="${SUPERVISOR_LOGINS:-KazumasaFUJIWARA}"
LIMIT="${LIMIT:-30}"
DAYS="${DAYS:-30}"

usage() {
	cat <<'EOF'
Usage: list-pending-issue-responses.sh

List open issues with student/external comments awaiting supervisor review.

Environment:
  ORG, EXCLUDE_PREFIX, LIMIT, DAYS   Same as fetch-recent-updates.sh
  SUPERVISOR_LOGINS                  Comma-separated GitHub logins (default: KazumasaFUJIWARA)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
	echo "error: gh CLI is required" >&2
	exit 1
fi

is_supervisor() {
	local login="$1"
	local IFS=,
	for sup in $SUPERVISOR_LOGINS; do
		[[ "$login" == "$sup" ]] && return 0
	done
	return 1
}

is_bot() {
	local login="$1"
	[[ "$login" == *[Bb]ot* ]] || [[ "$login" == "github-actions" ]]
}

cutoff_epoch="$(date -d "${DAYS} days ago" +%s 2>/dev/null || date -v-"${DAYS}"d +%s)"

declare -a pending=()
declare -a ok=()

check_repo() {
	local name="$1"
	[[ "$name" == "${EXCLUDE_PREFIX}"* ]] && return 0

	local issues_json
	issues_json="$(gh issue list --repo "${ORG}/${name}" --state open --limit 50 --json number,title,updatedAt 2>/dev/null || true)"
	[[ -z "$issues_json" || "$issues_json" == "[]" ]] && return 0

	while IFS= read -r issue_line; do
		[[ -z "$issue_line" ]] && continue
		local num title updated
		num="$(jq -r '.number' <<<"$issue_line")"
		title="$(jq -r '.title' <<<"$issue_line")"
		updated="$(jq -r '.updatedAt' <<<"$issue_line")"

		local updated_epoch
		updated_epoch="$(date -d "$updated" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated" +%s 2>/dev/null || echo 0)"
		[[ "$updated_epoch" -lt "$cutoff_epoch" ]] && continue

		local comments_json
		comments_json="$(gh api "repos/${ORG}/${name}/issues/${num}/comments" --jq '.' 2>/dev/null || echo '[]')"
		[[ "$comments_json" == "[]" ]] && continue

		local last_supervisor_idx=-1
		local idx=0
		local count
		count="$(jq 'length' <<<"$comments_json")"

		while [[ "$idx" -lt "$count" ]]; do
			local author
			author="$(jq -r ".[$idx].user.login" <<<"$comments_json")"
			if is_supervisor "$author"; then
				last_supervisor_idx=$idx
			fi
			idx=$((idx + 1))
		done

		local needs_reply=0
		idx=$((last_supervisor_idx + 1))
		while [[ "$idx" -lt "$count" ]]; do
			local author body created
			author="$(jq -r ".[$idx].user.login" <<<"$comments_json")"
			body="$(jq -r ".[$idx].body" <<<"$comments_json")"
			created="$(jq -r ".[$idx].created_at" <<<"$comments_json")"
			if ! is_supervisor "$author" && ! is_bot "$author"; then
				needs_reply=1
				local excerpt
				excerpt="$(printf '%s' "$body" | head -3 | tr '\n' ' ' | cut -c1-120)"
				pending+=("${ORG}/${name}#${num}|${author}|${created}|${excerpt}")
			fi
			idx=$((idx + 1))
		done

		if [[ "$needs_reply" -eq 0 && "$count" -gt 0 ]]; then
			ok+=("${ORG}/${name}#${num}")
		fi
	done < <(jq -c '.[]' <<<"$issues_json")
}

echo "=== pending issue responses (${ORG}, exclude ^${EXCLUDE_PREFIX}) ==="

mapfile -t repos < <(gh repo list "$ORG" --limit "$LIMIT" --json name -q '.[].name')
for repo in "${repos[@]}"; do
	check_repo "$repo"
done

if [[ ${#pending[@]} -gt 0 ]]; then
	echo "PENDING (要対処):"
	for entry in "${pending[@]}"; do
		IFS='|' read -r ref author created excerpt <<<"$entry"
		printf '  %s\n    author: %s\n    at: %s\n    excerpt: %s\n' "$ref" "$author" "$created" "$excerpt"
	done
else
	echo "PENDING: (none)"
fi

echo
if [[ ${#ok[@]} -gt 0 ]]; then
	echo "OK (指導者が最後に返信済み): ${#ok[@]} issue(s)"
fi

echo "pending_count: ${#pending[@]}"
