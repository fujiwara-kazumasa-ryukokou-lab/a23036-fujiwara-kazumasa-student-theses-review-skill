#!/usr/bin/env bash
# Agent-oriented query interface for student repository activity.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${script_dir}/lib/common.sh"
# shellcheck source=lib/activity-data.sh
source "${script_dir}/lib/activity-data.sh"

QUERY="status"
REPO_FILTER=""
STUDENT_ID_FILTER=""

usage() {
	cat <<'EOF'
Usage: query-student-activity.sh [-r ROOT] -q QUERY [OPTIONS]

Agent-oriented JSON query for student repository activity.
Always prints JSON to stdout.

Queries (-q):
  status           Full snapshot: summary + repos + pending_issues (default)
  summary          Summary counts only
  repos            All student repos
  needs_review     Repos with review_status needs_review or not_reviewed
  pending_replies  Open issues awaiting supervisor reply
  inactive         Repos with activity idle (no push within STALE days)
  active           Repos with activity active or recent
  repo             Single repo detail (--repo required)
  student          Repos matching --student-id prefix (e.g. y220020)

Options:
  -r, --root PATH       student-theses workspace root
  -q, --query QUERY     query name (see above)
  --repo NAME           filter by exact repo name
  --student-id ID       filter by student id prefix (y###### / ##m###)
  -h, --help            show help

Environment:
  ORG, EXCLUDE_PREFIX, EXCLUDE_REPOS, LIMIT, STUDENT_THESES_ROOT
  ACTIVITY_ACTIVE_DAYS (7), ACTIVITY_RECENT_DAYS (14), ACTIVITY_STALE_DAYS (30)
  STUDENT_ONLY (1)

Examples:
  query-student-activity.sh -r /path/to/student-theses -q summary
  query-student-activity.sh -r /path/to/student-theses -q needs_review
  query-student-activity.sh -r /path/to/student-theses -q repo --repo y220020-takagi-yuusuke-typing
  query-student-activity.sh -r /path/to/student-theses -q student --student-id y230018
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-r | --root)
		STUDENT_THESES_ROOT="$2"
		shift 2
		;;
	-q | --query)
		QUERY="$2"
		shift 2
		;;
	--repo)
		REPO_FILTER="$2"
		shift 2
		;;
	--student-id)
		STUDENT_ID_FILTER="$2"
		shift 2
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

ROOT="$(resolve_student_theses_root 2>/dev/null || true)"
STATE_FILE=""
if [[ -n "$ROOT" ]]; then
	STATE_FILE="${ROOT}/log/review-state.json"
fi

pending_json="$(collect_pending_issues_json "$script_dir")"
repos_json="$(collect_student_repos_json "$ROOT" "${STATE_FILE:-/dev/null}" "$pending_json" "$script_dir")"
summary_json="$(build_activity_summary "$repos_json" "$pending_json")"

filter_repos() {
	local filter="$1"
	case "$filter" in
	needs_review)
		jq -c '[.[] | select(.review_status == "needs_review" or .review_status == "not_reviewed")]' <<<"$repos_json"
		;;
	inactive)
		jq -c '[.[] | select(.activity == "idle")]' <<<"$repos_json"
		;;
	active)
		jq -c '[.[] | select(.activity == "active" or .activity == "recent")]' <<<"$repos_json"
		;;
	repo)
		if [[ -z "$REPO_FILTER" ]]; then
			echo "error: --repo is required for query repo" >&2
			exit 2
		fi
		jq -c --arg n "$REPO_FILTER" '[.[] | select(.name == $n)]' <<<"$repos_json"
		;;
	student)
		if [[ -z "$STUDENT_ID_FILTER" ]]; then
			echo "error: --student-id is required for query student" >&2
			exit 2
		fi
		jq -c --arg id "$STUDENT_ID_FILTER" '[.[] | select(.student_id == $id)]' <<<"$repos_json"
		;;
	*)
		printf '%s' "$repos_json"
		;;
	esac
}

build_answer() {
	local query="$1"
	local items_json="$2"
	local count
	count="$(jq 'length' <<<"$items_json")"

	case "$query" in
	summary)
		jq -r '"学生リポ \(.total_repos) 件。active=\(.activity.active) recent=\(.activity.recent) stale=\(.activity.stale) idle=\(.activity.idle)。open issue \(.open_issues) 件、要返信 \(.pending_responses) 件、要レビュー \(.needs_review) 件、未clone \(.not_cloned) 件。"' <<<"$summary_json"
		;;
	needs_review)
		if [[ "$count" -eq 0 ]]; then
			printf '要レビューの学生リポはありません。'
		else
			local names
			names="$(jq -r '[.[].name] | join(", ")' <<<"$items_json")"
			printf '要レビュー %d 件: %s' "$count" "$names"
		fi
		;;
	pending_replies)
		if [[ "$count" -eq 0 ]]; then
			printf '要返信の issue はありません。'
		else
			local refs
			refs="$(jq -r 'map("\(.repo)#\(.number)") | join(", ")' <<<"$items_json")"
			printf '要返信 %d 件: %s' "$count" "$refs"
		fi
		;;
	inactive)
		if [[ "$count" -eq 0 ]]; then
			printf '長期間 push のない学生リポはありません。'
		else
			names="$(jq -r '[.[].name] | join(", ")' <<<"$items_json")"
			printf '非活動（idle）%d 件: %s' "$count" "$names"
		fi
		;;
	active)
		if [[ "$count" -eq 0 ]]; then
			printf '最近活動のある学生リポはありません。'
		else
			names="$(jq -r '[.[].name] | join(", ")' <<<"$items_json")"
			printf '最近活動 %d 件: %s' "$count" "$names"
		fi
		;;
	repo)
		if [[ "$count" -eq 0 ]]; then
			printf 'リポ %s は見つかりません（学生リポフィルタ・除外設定を確認）。' "$REPO_FILTER"
		else
			jq -r '.[0] | "\(.name): 最終push \(.pushed_at)（\(.days_since_push)日前）, activity=\(.activity), review=\(.review_status), open=\(.open_issues), 要返信=\(.pending_responses)"' <<<"$items_json"
		fi
		;;
	student)
		if [[ "$count" -eq 0 ]]; then
			printf '学籍 %s の学生リポは見つかりません。' "$STUDENT_ID_FILTER"
		else
			jq -r '.[0] | "\(.name): 最終push \(.pushed_at), review=\(.review_status), open=\(.open_issues)"' <<<"$items_json"
		fi
		;;
	status | repos)
		jq -r '"学生リポ \(.total_repos) 件。要レビュー \(.needs_review) 件、要返信 \(.pending_responses) 件。"' <<<"$summary_json"
		;;
	*)
		printf 'query=%s count=%d' "$query" "$count"
		;;
	esac
}

case "$QUERY" in
summary)
	result_json="$(jq -nc \
		--arg query "$QUERY" \
		--arg org "$ORG" \
		--arg root "${ROOT:-}" \
		--arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--arg answer "$(build_answer summary '[]')" \
		--argjson summary "$summary_json" \
		'{query: $query, org: $org, student_theses_root: $root, generated_at: $generated_at, answer: $answer, summary: $summary}')"
	;;
pending_replies)
	items_json="$pending_json"
	answer="$(build_answer pending_replies "$items_json")"
	result_json="$(jq -nc \
		--arg query "$QUERY" \
		--arg org "$ORG" \
		--arg root "${ROOT:-}" \
		--arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--arg answer "$answer" \
		--argjson count "$(jq 'length' <<<"$items_json")" \
		--argjson items "$items_json" \
		--argjson summary "$summary_json" \
		'{query: $query, org: $org, student_theses_root: $root, generated_at: $generated_at, answer: $answer, count: $count, items: $items, summary: $summary}')"
	;;
status)
	items_json="$repos_json"
	answer="$(build_answer status "$items_json")"
	result_json="$(jq -nc \
		--arg query "$QUERY" \
		--arg org "$ORG" \
		--arg root "${ROOT:-}" \
		--arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--arg answer "$answer" \
		--argjson summary "$summary_json" \
		--argjson repos "$repos_json" \
		--argjson pending_issues "$pending_json" \
		'{query: $query, org: $org, student_theses_root: $root, generated_at: $generated_at, answer: $answer, summary: $summary, repos: $repos, pending_issues: $pending_issues}')"
	;;
repos | needs_review | inactive | active | repo | student)
	items_json="$(filter_repos "$QUERY")"
	answer="$(build_answer "$QUERY" "$items_json")"
	result_json="$(jq -nc \
		--arg query "$QUERY" \
		--arg org "$ORG" \
		--arg root "${ROOT:-}" \
		--arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		--arg answer "$answer" \
		--argjson count "$(jq 'length' <<<"$items_json")" \
		--argjson items "$items_json" \
		--argjson summary "$summary_json" \
		'{query: $query, org: $org, student_theses_root: $root, generated_at: $generated_at, answer: $answer, count: $count, items: $items, summary: $summary}')"
	;;
*)
	echo "error: unknown query: ${QUERY}" >&2
	usage >&2
	exit 2
	;;
esac

printf '%s\n' "$result_json"
