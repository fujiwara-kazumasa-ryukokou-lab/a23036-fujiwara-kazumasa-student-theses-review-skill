#!/usr/bin/env bash
# Shared helpers for student-theses-review scripts.
set -euo pipefail

ORG="${ORG:-fujiwara-kazumasa-ryukokou-lab}"
EXCLUDE_PREFIX="${EXCLUDE_PREFIX:-a23036}"
EXCLUDE_REPOS="${EXCLUDE_REPOS:-archive}"
SUPERVISOR_LOGINS="${SUPERVISOR_LOGINS:-KazumasaFUJIWARA}"
DAYS="${DAYS:-14}"
LIMIT="${LIMIT:-50}"
GIT_TIMEOUT="${GIT_TIMEOUT:-45}"

_common_script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
SKILL_SCRIPTS_DIR="$(cd "${_common_script_dir}/.." && pwd)"
SKILL_REPO_ROOT="$(cd "${SKILL_SCRIPTS_DIR}/../../.." && pwd)"

resolve_student_theses_root() {
	if [[ -n "${STUDENT_THESES_ROOT:-}" ]]; then
		printf '%s' "$STUDENT_THESES_ROOT"
		return 0
	fi
	local sibling
	sibling="$(cd "${SKILL_REPO_ROOT}/.." 2>/dev/null && pwd || true)"
	if [[ -n "$sibling" && -d "$sibling" ]]; then
		printf '%s' "$sibling"
		return 0
	fi
	return 1
}

review_state_file() {
	local root
	root="$(resolve_student_theses_root)" || return 1
	printf '%s/log/review-state.json' "$root"
}

cutoff_epoch() {
	local days="${1:-$DAYS}"
	date -d "${days} days ago" +%s 2>/dev/null || date -v-"${days}"d +%s
}

to_epoch() {
	local ts="$1"
	date -d "$ts" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo 0
}

is_supervisor_login() {
	local login="$1"
	local IFS=,
	for sup in $SUPERVISOR_LOGINS; do
		[[ "$login" == "$sup" ]] && return 0
	done
	return 1
}

is_bot_login() {
	local login="$1"
	[[ "$login" == *[Bb]ot* ]] || [[ "$login" == "github-actions" ]]
}

is_excluded_repo() {
	local name="$1"
	[[ "$name" == "${EXCLUDE_PREFIX}"* ]] && return 0
	local IFS=,
	for item in $EXCLUDE_REPOS; do
		[[ -n "$item" && "$name" == "$item" ]] && return 0
	done
	return 1
}

require_gh() {
	command -v gh >/dev/null 2>&1 || {
		echo "error: gh CLI is required" >&2
		return 1
	}
}

require_jq() {
	command -v jq >/dev/null 2>&1 || {
		echo "error: jq is required" >&2
		return 1
	}
}

run_git() {
	if command -v timeout >/dev/null 2>&1; then
		timeout "$GIT_TIMEOUT" git "$@"
	else
		git "$@"
	fi
}

parse_root_arg() {
	:
}

list_target_repos() {
	gh repo list "$ORG" --limit "$LIMIT" --json name,pushedAt -q '.[] | "\(.pushedAt)\t\(.name)"' | sort -r
}
