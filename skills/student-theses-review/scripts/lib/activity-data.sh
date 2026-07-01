#!/usr/bin/env bash
# Shared helpers to collect student repo activity data (JSON-oriented).
set -euo pipefail

ACTIVITY_ACTIVE_DAYS="${ACTIVITY_ACTIVE_DAYS:-7}"
ACTIVITY_RECENT_DAYS="${ACTIVITY_RECENT_DAYS:-14}"
ACTIVITY_STALE_DAYS="${ACTIVITY_STALE_DAYS:-30}"
STUDENT_ONLY="${STUDENT_ONLY:-1}"

activity_now_epoch() {
	date +%s
}

is_student_repo() {
	local name="$1"
	[[ "$name" =~ ^y[0-9]{6}- ]] && return 0
	[[ "$name" =~ ^[0-9]{2}m[0-9]{3}- ]] && return 0
	return 1
}

parse_student_id() {
	local name="$1"
	if [[ "$name" =~ ^([a-z0-9]+)- ]]; then
		printf '%s' "${BASH_REMATCH[1]}"
	else
		printf '%s' ""
	fi
}

activity_label_for_epoch() {
	local pushed_epoch="$1"
	local now active_cutoff recent_cutoff stale_cutoff

	now="$(activity_now_epoch)"
	active_cutoff="$(cutoff_epoch "$ACTIVITY_ACTIVE_DAYS")"
	recent_cutoff="$(cutoff_epoch "$ACTIVITY_RECENT_DAYS")"
	stale_cutoff="$(cutoff_epoch "$ACTIVITY_STALE_DAYS")"

	if [[ "$pushed_epoch" -ge "$active_cutoff" ]]; then
		printf 'active'
	elif [[ "$pushed_epoch" -ge "$recent_cutoff" ]]; then
		printf 'recent'
	elif [[ "$pushed_epoch" -ge "$stale_cutoff" ]]; then
		printf 'stale'
	else
		printf 'idle'
	fi
}

days_since_push() {
	local pushed_epoch="$1"
	local now diff days
	now="$(activity_now_epoch)"
	diff=$((now - pushed_epoch))
	days=$((diff / 86400))
	printf '%d' "$days"
}

review_status_for_repo() {
	local name="$1"
	local pushed_epoch="$2"
	local root="$3"
	local state_file="$4"
	local dir reviewed_sha reviewed_at reviewed_epoch head_sha

	dir="${root}/${name}"

	if [[ -z "$root" || ! -f "$state_file" ]]; then
		if [[ -n "$root" && -d "$dir/.git" ]]; then
			printf 'not_reviewed'
		else
			printf 'not_cloned'
		fi
		return 0
	fi

	reviewed_sha="$(jq -r --arg n "$name" '.repos[$n].last_reviewed_sha // empty' "$state_file" 2>/dev/null || true)"
	reviewed_at="$(jq -r --arg n "$name" '.repos[$n].last_reviewed_at // empty' "$state_file" 2>/dev/null || true)"

	if [[ -z "$reviewed_sha" ]]; then
		if [[ -d "$dir/.git" ]]; then
			printf 'not_reviewed'
		else
			printf 'not_cloned'
		fi
		return 0
	fi

	if [[ ! -d "$dir/.git" ]]; then
		reviewed_epoch="$(to_epoch "$reviewed_at")"
		if [[ "$pushed_epoch" -gt "$reviewed_epoch" ]]; then
			printf 'needs_review'
		else
			printf 'reviewed'
		fi
		return 0
	fi

	head_sha="$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)"
	if [[ -z "$head_sha" ]]; then
		printf 'not_reviewed'
		return 0
	fi

	if [[ "$head_sha" == "$reviewed_sha" ]]; then
		printf 'reviewed'
	else
		printf 'needs_review'
	fi
}

clone_status_for_repo() {
	local name="$1"
	local root="$2"
	local dir="${root}/${name}"

	if [[ -z "$root" ]]; then
		printf 'unknown'
	elif [[ -d "$dir/.git" ]]; then
		printf 'present'
	else
		printf 'missing'
	fi
}

collect_pending_issues_json() {
	local script_dir="$1"
	"${script_dir}/list-pending-issue-responses.sh" --json 2>/dev/null || echo '[]'
}

collect_student_repos_json() {
	local root="$1"
	local state_file="$2"
	local pending_json="$3"
	local script_dir="${4:-}"

	local rows='[]'
	local repo_list

	repo_list="$(gh repo list "$ORG" --limit "$LIMIT" --json name,pushedAt,description,updatedAt,isArchived \
		| jq -c 'sort_by(.pushedAt) | reverse | .[]')"

	while IFS= read -r repo_row; do
		[[ -z "$repo_row" ]] && continue
		local name pushed_at description updated_at is_archived
		local pushed_epoch student_id activity review clone
		local open_count pending_count pending_for_repo
		local reviewed_sha reviewed_at head_sha repo_url days_since

		name="$(jq -r '.name' <<<"$repo_row")"
		is_excluded_repo "$name" && continue
		[[ "$STUDENT_ONLY" == "1" ]] && ! is_student_repo "$name" && continue

		pushed_at="$(jq -r '.pushedAt' <<<"$repo_row")"
		description="$(jq -r '.description // ""' <<<"$repo_row")"
		updated_at="$(jq -r '.updatedAt' <<<"$repo_row")"
		is_archived="$(jq -r '.isArchived' <<<"$repo_row")"
		pushed_epoch="$(to_epoch "$pushed_at")"
		student_id="$(parse_student_id "$name")"
		activity="$(activity_label_for_epoch "$pushed_epoch")"
		review="$(review_status_for_repo "$name" "$pushed_epoch" "$root" "$state_file")"
		clone="$(clone_status_for_repo "$name" "$root")"
		days_since="$(days_since_push "$pushed_epoch")"
		repo_url="https://github.com/${ORG}/${name}"

		open_count="$(gh issue list --repo "${ORG}/${name}" --state open --json number -q 'length' 2>/dev/null || echo 0)"
		pending_count="$(jq -r --arg n "$name" '[.[] | select(.repo == $n)] | length' <<<"$pending_json")"
		pending_for_repo="$(jq -c --arg n "$name" '[.[] | select(.repo == $n)]' <<<"$pending_json")"

		reviewed_sha=""
		reviewed_at=""
		head_sha=""
		if [[ -n "$root" && -f "$state_file" ]]; then
			reviewed_sha="$(jq -r --arg n "$name" '.repos[$n].last_reviewed_sha // empty' "$state_file" 2>/dev/null || true)"
			reviewed_at="$(jq -r --arg n "$name" '.repos[$n].last_reviewed_at // empty' "$state_file" 2>/dev/null || true)"
		fi
		if [[ -n "$root" && -d "${root}/${name}/.git" ]]; then
			head_sha="$(git -C "${root}/${name}" rev-parse HEAD 2>/dev/null || true)"
		fi

		rows="$(jq -c \
			--arg name "$name" \
			--arg student_id "$student_id" \
			--arg pushed_at "$pushed_at" \
			--arg updated_at "$updated_at" \
			--argjson days_since_push "$days_since" \
			--arg activity "$activity" \
			--argjson open_issues "$open_count" \
			--argjson pending_responses "$pending_count" \
			--argjson pending_issues "$pending_for_repo" \
			--arg review_status "$review" \
			--arg clone_status "$clone" \
			--arg description "$description" \
			--arg repo_url "$repo_url" \
			--arg reviewed_sha "$reviewed_sha" \
			--arg reviewed_at "$reviewed_at" \
			--arg head_sha "$head_sha" \
			--argjson is_archived "$is_archived" \
			'. + [{
				name: $name,
				student_id: $student_id,
				pushed_at: $pushed_at,
				updated_at: $updated_at,
				days_since_push: $days_since_push,
				activity: $activity,
				open_issues: $open_issues,
				pending_responses: $pending_responses,
				pending_issues: $pending_issues,
				review_status: $review_status,
				clone_status: $clone_status,
				description: $description,
				repo_url: $repo_url,
				last_reviewed_sha: (if $reviewed_sha == "" then null else $reviewed_sha end),
				last_reviewed_at: (if $reviewed_at == "" then null else $reviewed_at end),
				head_sha: (if $head_sha == "" then null else $head_sha end),
				is_archived: $is_archived
			}]' <<<"$rows")"
	done <<<"$repo_list"

	printf '%s' "$rows"
}

build_activity_summary() {
	local repos_json="$1"
	local pending_json="$2"

	jq -nc \
		--argjson repos "$repos_json" \
		--argjson pending "$pending_json" \
		'{
			total_repos: ($repos | length),
			activity: {
				active: ([$repos[] | select(.activity == "active")] | length),
				recent: ([$repos[] | select(.activity == "recent")] | length),
				stale: ([$repos[] | select(.activity == "stale")] | length),
				idle: ([$repos[] | select(.activity == "idle")] | length)
			},
			open_issues: ([$repos[].open_issues] | add // 0),
			pending_responses: ($pending | length),
			needs_review: ([$repos[] | select(.review_status == "needs_review" or .review_status == "not_reviewed")] | length),
			not_cloned: ([$repos[] | select(.clone_status == "missing")] | length)
		}'
}
