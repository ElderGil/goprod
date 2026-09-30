#!/usr/bin/env bash
# Behavior test for skills/ship-readiness/scripts/audit-distance.sh.
# Builds a throwaway repo and checks: doc-only commits are not counted, the
# threshold passes, one more code commit blocks (CLI and pre-push hook modes),
# pushes to other branches pass, and a missing baseline blocks.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/skills/ship-readiness/scripts/audit-distance.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
failures=0

expect() { # expect <label> <expected-exit> <actual-exit>
  if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1 (expected exit $2, got $3)"; failures=$((failures + 1)); fi
}

cd "$TMP" && git init -q -b main && mkdir docs
echo base > app.txt && git add . && git commit -qm base
BASE=$(git rev-parse HEAD)
printf 'Last assessed: 2026-01-01\nLast clean post-audit: %s (baseline)\nPost-audit threshold: 3\n' "$BASE" > docs/ship-readiness.md
git add . && git commit -qm "profile"
echo note > docs/notes.md && git add . && git commit -qm "docs only"
echo readme > README.md && git add . && git commit -qm "markdown only"
for i in 1 2 3; do echo "change $i" >> app.txt && git commit -qam "code $i"; done

bash "$SCRIPT" >/dev/null 2>&1; expect "3 code commits at threshold 3 passes (doc commits ignored)" 0 $?

echo "change 4" >> app.txt && git commit -qam "code 4"
bash "$SCRIPT" >/dev/null 2>&1; expect "4 code commits blocks (CLI)" 1 $?

HEAD_SHA=$(git rev-parse HEAD)
echo "refs/heads/main $HEAD_SHA refs/heads/main 0000000000000000000000000000000000000000" \
  | bash "$SCRIPT" origin url >/dev/null 2>&1; expect "pre-push to default branch blocks" 1 $?
echo "refs/heads/work $HEAD_SHA refs/heads/feature 0000000000000000000000000000000000000000" \
  | bash "$SCRIPT" origin url >/dev/null 2>&1; expect "pre-push to feature branch passes" 0 $?

sed "s/^Last clean post-audit: .*/Last clean post-audit: $HEAD_SHA (post-merge-audit)/" docs/ship-readiness.md > p && mv p docs/ship-readiness.md
bash "$SCRIPT" >/dev/null 2>&1; expect "new clean baseline resets the distance" 0 $?

sed "s/^Last clean post-audit: .*/Last clean post-audit: deadbeef1/" docs/ship-readiness.md > p && mv p docs/ship-readiness.md
bash "$SCRIPT" >/dev/null 2>&1; expect "unknown baseline blocks" 1 $?

rm docs/ship-readiness.md
bash "$SCRIPT" >/dev/null 2>&1; expect "missing profile reports exit 2" 2 $?

exit $((failures > 0))
