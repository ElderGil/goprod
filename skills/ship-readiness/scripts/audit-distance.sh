#!/usr/bin/env bash
# Counts code commits since the last clean post-merge-audit and blocks when the
# count exceeds the project's threshold. Works two ways:
#
#   CLI:   audit-distance.sh [TARGET_REF]     (default TARGET_REF: HEAD)
#   Hook:  copy to .git/hooks/pre-push (or call it from husky/lefthook);
#          git passes "<remote> <url>" as args and the refs on stdin.
#
# Reads from docs/ship-readiness.md:
#   Last clean post-audit: <sha> ...
#   Post-audit threshold: <n>            (default 3)
# A "code commit" is a non-merge commit touching anything outside docs/ and *.md.
#
# Exit: 0 within threshold · 1 over threshold or baseline invalid · 2 no profile/baseline.
# Bypass (a human decision, not an agent's): git push --no-verify
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "audit-distance: not a git repository" >&2; exit 2; }
PROFILE="$ROOT/docs/ship-readiness.md"

if [[ ! -f "$PROFILE" ]]; then
  echo "audit-distance: no docs/ship-readiness.md — run ship-readiness first" >&2
  exit 2
fi

BASE=$(sed -n 's/^[Ll]ast clean post-audit:[[:space:]]*\([0-9a-fA-F]\{7,40\}\).*/\1/p' "$PROFILE" | head -n 1)
THRESHOLD=$(sed -n 's/^[Pp]ost-audit threshold:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$PROFILE" | head -n 1)
THRESHOLD=${THRESHOLD:-3}

if [[ -z "$BASE" ]]; then
  echo "audit-distance: no 'Last clean post-audit: <sha>' line in docs/ship-readiness.md" >&2
  exit 2
fi
if ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  echo "audit-distance: baseline $BASE not found in this clone (fetch, or re-run post-merge-audit)" >&2
  exit 1
fi

count_code_commits() { # count_code_commits <target-sha>
  local target="$1" n=0 c
  if ! git merge-base --is-ancestor "$BASE" "$target" 2>/dev/null; then
    echo "audit-distance: baseline $BASE is not an ancestor of $target (history rewritten?) — run post-merge-audit" >&2
    return 1
  fi
  for c in $(git rev-list --no-merges "$BASE..$target"); do
    if git diff-tree --no-commit-id --name-only -r "$c" | grep -qvE '^docs/|\.md$'; then
      n=$((n + 1))
    fi
  done
  printf '%s' "$n"
}

check() { # check <target-sha> <label>
  local n
  n=$(count_code_commits "$1") || return 1
  echo "audit-distance: $n code commit(s) on $2 since last clean post-audit ${BASE:0:7} (threshold $THRESHOLD)"
  if (( n > THRESHOLD )); then
    echo "audit-distance: over threshold — run post-merge-audit over ${BASE:0:7}..${1:0:7} and record the new clean SHA before pushing" >&2
    return 1
  fi
}

# Hook mode: git calls pre-push with two args and refs on stdin.
if [[ $# -eq 2 && ! -t 0 ]]; then
  DEFAULT=$(git symbolic-ref --short refs/remotes/"$1"/HEAD 2>/dev/null | sed "s|^$1/||")
  if [[ -z "$DEFAULT" ]]; then
    for b in main master; do git show-ref --verify --quiet "refs/heads/$b" && DEFAULT=$b && break; done
  fi
  rc=0
  while read -r _local_ref local_sha remote_ref _remote_sha; do
    [[ "$remote_ref" == "refs/heads/$DEFAULT" ]] || continue
    [[ "$local_sha" =~ ^0+$ ]] && continue   # branch deletion
    check "$local_sha" "$DEFAULT" || rc=1
  done
  exit $rc
fi

TARGET=$(git rev-parse --verify "${1:-HEAD}^{commit}" 2>/dev/null) || { echo "audit-distance: unknown ref ${1:-HEAD}" >&2; exit 2; }
check "$TARGET" "${1:-HEAD}"
