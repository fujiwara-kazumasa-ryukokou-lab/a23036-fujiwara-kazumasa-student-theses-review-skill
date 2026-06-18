#!/usr/bin/env bash
# Orchestrate student-theses review: pending issues, fetch updates, emit agent summary.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${script_dir}/lib/common.sh"

JSON_OUT=0
SKIP_FETCH=0
SKIP_PENDING=0

usage() {
	cat <<'EOF'
Usage: run-review.sh [OPTIONS]

Run the full agent-friendly review prelude.

Options:
  -r, --root PATH   student-theses workspace root
  --json            Emit machine-readable JSON summary on stdout (human log on stderr)
  --skip-fetch      Only list targets / pending issues
  --skip-pending    Skip pending issue scan
  -h, --help        Show help

Environment: ORG, EXCLUDE_PREFIX, EXCLUDE_REPOS, DAYS, LIMIT, GIT_TIMEOUT,
             SUPERVISOR_LOGINS, STUDENT_THESES_ROOT
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
	--skip-fetch)
		SKIP_FETCH=1
		shift
		;;
	--skip-pending)
		SKIP_PENDING=1
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

require_gh
require_jq

ROOT="$(resolve_student_theses_root)" || {
	echo "error: STUDENT_THESES_ROOT not found. Pass -r/--root." >&2
	exit 1
}

log() {
	if [[ "$JSON_OUT" -eq 0 ]]; then
		printf '%s\n' "$*"
	else
		printf '%s\n' "$*" >&2
	fi
}

pending_json='[]'
updated_json='[]'
uptodate_json='[]'
missing_json='[]'
failed_json='[]'
targets_json='[]'
next_actions_json='[]'

if [[ "$SKIP_PENDING" -eq 0 ]]; then
	pending_raw="$("${script_dir}/list-pending-issue-responses.sh" --json 2>/dev/null || echo '[]')"
	pending_json="$pending_raw"
	pending_count="$(jq 'length' <<<"$pending_json")"
	if [[ "$pending_count" -gt 0 ]]; then
		next_actions_json="$(jq -c --argjson p "$pending_json" \
			'$p | map("verify_and_reply_issue: " + .repo + "#" + (.number|tostring))' <<<"$pending_json")"
	fi
else
	pending_count=0
fi

cutoff="$(cutoff_epoch "$DAYS")"

while IFS=$'\t' read -r pushed name; do
	[[ -z "$name" ]] && continue
	is_excluded_repo "$name" && continue
	[[ "$(to_epoch "$pushed")" -lt "$cutoff" ]] && continue

	targets_json="$(jq -c --arg n "$name" --arg p "$pushed" '. + [{name: $n, pushed_at: $p}]' <<<"$targets_json")"
done < <(list_target_repos)

if [[ "$SKIP_FETCH" -eq 0 ]]; then
	fetch_output="$("${script_dir}/fetch-recent-updates.sh" -r "$ROOT" 2>&1)" || fetch_status=$?
	fetch_status="${fetch_status:-0}"

	while IFS= read -r line; do
		case "$line" in
		UPDATED\ *)
			rest="${line#UPDATED }"
			name="${rest%%:*}"
			range="${rest#*: }"
			before="${range%% -> *}"
			after="${range##* -> }"
			updated_json="$(jq -c --arg n "$name" --arg b "$before" --arg a "$after" \
				'. + [{name: $n, before: $b, after: $a}]' <<<"$updated_json")"
			next_actions_json="$(jq -c --arg a "review_repo: ${name} (${after:0:7})" '. + [$a]' <<<"$next_actions_json")"
			;;
		UPTODATE\ *)
			name="${line#UPTODATE }"
			uptodate_json="$(jq -c --arg n "$name" '. + [$n]' <<<"$uptodate_json")"
			;;
		MISSING\ *)
			name="${line#MISSING }"
			missing_json="$(jq -c --arg n "$name" '. + [$n]' <<<"$missing_json")"
			next_actions_json="$(jq -c --arg a "clone_repo: ${name}" '. + [$a]' <<<"$next_actions_json")"
			;;
		FAIL\ *)
			entry="${line#FAIL }"
			failed_json="$(jq -c --arg e "$entry" '. + [$e]' <<<"$failed_json")"
			;;
		esac
	done <<<"$fetch_output"

	[[ "$fetch_status" -ne 0 ]] && log "warning: fetch exited with status ${fetch_status}"
fi

summary="$(jq -nc \
	--arg org "$ORG" \
	--arg root "$ROOT" \
	--argjson pending "$pending_json" \
	--argjson targets "$targets_json" \
	--argjson updated "$updated_json" \
	--argjson uptodate "$uptodate_json" \
	--argjson missing "$missing_json" \
	--argjson failed "$failed_json" \
	--argjson next_actions "$next_actions_json" \
	'{
		org: $org,
		student_theses_root: $root,
		pending_issues: $pending,
		targets: $targets,
		updated_repos: $updated,
		uptodate_repos: $uptodate,
		missing_repos: $missing,
		failed_repos: $failed,
		next_actions: $next_actions
	}')"

log "=== student-theses-review summary ==="
log "root: ${ROOT}"
log "pending_issues: $(jq 'length' <<<"$pending_json")"
log "updated_repos: $(jq 'length' <<<"$updated_json")"
log "next_actions:"
jq -r '.next_actions[]' <<<"$summary" | while IFS= read -r action; do
	log "  - ${action}"
done

if [[ "$JSON_OUT" -eq 1 ]]; then
	printf '%s\n' "$summary"
fi

if [[ "$(jq '.failed_repos | length' <<<"$summary")" -gt 0 ]]; then
	exit 1
fi
