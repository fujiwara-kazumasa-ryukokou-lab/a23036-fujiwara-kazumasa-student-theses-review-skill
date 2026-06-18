#!/usr/bin/env bash
# List org repos with recent pushes, excluding a23036 prefix.
set -euo pipefail

ORG="${ORG:-fujiwara-kazumasa-ryukokou-lab}"
EXCLUDE_PREFIX="${EXCLUDE_PREFIX:-a23036}"
DAYS="${DAYS:-14}"
LIMIT="${LIMIT:-30}"

usage() {
	cat <<'EOF'
Usage: list-review-targets.sh

List repositories in ORG pushed within DAYS, excluding EXCLUDE_PREFIX.

Environment:
  ORG             GitHub organization (default: fujiwara-kazumasa-ryukokou-lab)
  EXCLUDE_PREFIX  Repo name prefix to skip (default: a23036)
  DAYS            Lookback window in days (default: 14)
  LIMIT           gh repo list limit (default: 30)
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

cutoff_epoch="$(date -d "${DAYS} days ago" +%s 2>/dev/null || date -v-"${DAYS}"d +%s)"

echo "=== review targets (${ORG}, last ${DAYS} days, exclude ^${EXCLUDE_PREFIX}) ==="

count=0
while IFS=$'\t' read -r pushed name; do
	[[ -z "$name" ]] && continue
	if [[ "$name" == "${EXCLUDE_PREFIX}"* ]]; then
		continue
	fi
	pushed_epoch="$(date -d "$pushed" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$pushed" +%s 2>/dev/null || echo 0)"
	if [[ "$pushed_epoch" -lt "$cutoff_epoch" ]]; then
		continue
	fi
	printf '%s\t%s\n' "$pushed" "$name"
	count=$((count + 1))
done < <(gh repo list "$ORG" --limit "$LIMIT" --json name,pushedAt -q '.[] | "\(.pushedAt)\t\(.name)"' | sort -r)

if [[ "$count" -eq 0 ]]; then
	echo "(none)"
fi

echo
echo "count: ${count}"
