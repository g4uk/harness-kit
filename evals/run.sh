#!/bin/bash
# Eval runner: fresh worktree per trace → headless run → deterministic checks.
# Checks in a trace: lines "- [ ] cmd: <shell>" are executed in the worktree (exit 0 = PASS).
# Lines without "cmd:" are documentation for humans; the script skips them.
set -u
REPO=$(git rev-parse --show-toplevel)
RESULTS="$REPO/evals/results/$(date +%F-%H%M).md"
mkdir -p "$REPO/evals/results"
echo "# Eval run $(date -Iseconds)" > "$RESULTS"
PASS=0; TOTAL=0

# EDIT_ME: baseline checks for every trace
BASE_CHECK="go test ./..."
# EDIT_ME: base branch for worktrees (auto-detected; override if needed)
BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
BASE_BRANCH=${BASE_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}

for TRACE in "$REPO"/evals/traces/*.md; do
  [ -e "$TRACE" ] || continue
  NAME=$(basename "$TRACE" .md); TOTAL=$((TOTAL+1))
  WT="/tmp/eval-$NAME"
  git worktree remove -f "$WT" >/dev/null 2>&1 || true
  git worktree add -f "$WT" "$BASE_BRANCH" >/dev/null 2>&1

  PROMPT=$(awk '/^## Prompt/{f=1;next}/^## /{f=0}f' "$TRACE")
  (cd "$WT" && claude -p "$PROMPT" --output-format json > "/tmp/eval-$NAME.json" 2>&1)

  OK=1
  (cd "$WT" && eval "$BASE_CHECK" >/dev/null 2>&1) || OK=0
  while IFS= read -r CHECK; do
    (cd "$WT" && eval "$CHECK" >/dev/null 2>&1) || { OK=0; echo "  - FAIL check: $CHECK" >> "$RESULTS"; }
  done < <(grep -oP '^\s*-\s*\[\s*\]\s*cmd:\s*\K.*' "$TRACE")

  if [ "$OK" = 1 ]; then echo "- $NAME: PASS" >> "$RESULTS"; PASS=$((PASS+1));
  else echo "- $NAME: FAIL" >> "$RESULTS"; fi
  git worktree remove -f "$WT" >/dev/null 2>&1
done
echo "" >> "$RESULTS"; echo "**$PASS/$TOTAL**" >> "$RESULTS"
echo "Pass rate: $PASS/$TOTAL → $RESULTS"
[ "$PASS" = "$TOTAL" ]
