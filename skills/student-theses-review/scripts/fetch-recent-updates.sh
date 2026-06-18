#!/usr/bin/env bash
# Fast fetch for recently pushed non-a23036 org repos under student-theses workspace.
set -euo pipefail

ORG="${ORG:-fujiwara-kazumasa-ryukokou-lab}"
EXCLUDE_PREFIX="${EXCLUDE_PREFIX:-a23036}"
DAYS="${DAYS:-14}"
LIMIT="${LIMIT:-30}"
GIT_TIMEOUT="${GIT_TIMEOUT:-45}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# skills/student-theses-review/scripts -> repo root (a23036-student-theses-review-skill)
# Default student-theses root: sibling of this skill repo under common parent
SKILL_REPO_ROOT="$(cd "${script_dir}/../../.." && pwd)"
STUDENT_THESES_ROOT="${STUDENT_THESES_ROOT:-$(cd "${SKILL_REPO_ROOT}/.." 2>/dev/null && pwd || echo "")}"

usage() {
	cat <<'EOF'
Usage: fetch-recent-updates.sh

Fetch and fast-forward recently pushed repos (excluding a23036 prefix).

Environment:
  STUDENT_THESES_ROOT  Local clone root (default: parent of skill repo)
  ORG, EXCLUDE_PREFIX, DAYS, LIMIT  Same as list-review-targets.sh
  GIT_TIMEOUT          Per-repo fetch timeout seconds (default: 45)
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

if [[ -z "$STUDENT_THESES_ROOT" || ! -d "$STUDENT_THESES_ROOT" ]]; then
	echo "error: STUDENT_THESES_ROOT not found. Set it explicitly." >&2
	exit 1
fi

run_git() {
	if command -v timeout >/dev/null 2>&1; then
		timeout "$GIT_TIMEOUT" git "$@"
	else
		git "$@"
	fi
}

cutoff_epoch="$(date -d "${DAYS} days ago" +%s 2>/dev/null || date -v-"${DAYS}"d +%s)"

declare -a updated=()
declare -a uptodate=()
declare -a failed=()
declare -a missing=()

sync_one() {
	local name="$1"
	local dir="${STUDENT_THESES_ROOT}/${name}"

	if [[ ! -d "$dir/.git" ]]; then
		missing+=("$name")
		echo "MISSING ${name}"
		return 0
	fi

	local before branch remote_sha after pull_status=0
	before="$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo none)"
	branch="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo main)"

	if ! run_git -C "$dir" fetch origin -q 2>&1; then
		failed+=("$name")
		echo "FAIL ${name}: fetch timed out or failed"
		return 0
	fi

	remote_sha="$(git -C "$dir" rev-parse "origin/${branch}" 2>/dev/null || true)"
	if [[ -z "$remote_sha" ]]; then
		failed+=("$name")
		echo "FAIL ${name}: origin/${branch} not found"
		return 0
	fi

	if [[ "$before" == "$remote_sha" ]]; then
		uptodate+=("$name")
		echo "UPTODATE ${name}"
		return 0
	fi

	if ! run_git -C "$dir" merge --ff-only "origin/${branch}" -q 2>/dev/null; then
		if ! run_git -C "$dir" pull --ff-only -q 2>/dev/null; then
			failed+=("$name: non-fast-forward")
			echo "FAIL ${name}: non-fast-forward"
			return 0
		fi
	fi

	after="$(git -C "$dir" rev-parse HEAD)"
	updated+=("$name")
	echo "UPDATED ${name}: ${before} -> ${after}"
	git -C "$dir" log --oneline "${before}..${after}" 2>/dev/null | head -5 | sed 's/^/  /' || true
}

echo "=== fetch recent updates (${ORG}) ==="
echo "root: ${STUDENT_THESES_ROOT}"
echo

while IFS=$'\t' read -r pushed name; do
	[[ -z "$name" ]] && continue
	[[ "$name" == "${EXCLUDE_PREFIX}"* ]] && continue
	pushed_epoch="$(date -d "$pushed" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$pushed" +%s 2>/dev/null || echo 0)"
	if [[ "$pushed_epoch" -lt "$cutoff_epoch" ]]; then
		continue
	fi
	sync_one "$name"
done < <(gh repo list "$ORG" --limit "$LIMIT" --json name,pushedAt -q '.[] | "\(.pushedAt)\t\(.name)"' | sort -r)

echo
echo "=== summary ==="
if [[ ${#updated[@]} -gt 0 ]]; then
	echo "更新あり:"
	printf '  - %s\n' "${updated[@]}"
fi
if [[ ${#uptodate[@]} -gt 0 ]]; then
	echo "更新なし:"
	printf '  - %s\n' "${uptodate[@]}"
fi
if [[ ${#missing[@]} -gt 0 ]]; then
	echo "未 clone:"
	printf '  - %s\n' "${missing[@]}"
fi
if [[ ${#failed[@]} -gt 0 ]]; then
	echo "失敗:"
	printf '  - %s\n' "${failed[@]}"
	exit 1
fi
