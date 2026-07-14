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

# Sample mode for PR (3 traces); full run for main/push (all). Auto-detects via GITHUB_EVENT_NAME.
# Override with EVAL_LIMIT env var if needed.
if [ -z "${EVAL_LIMIT:-}" ]; then
  # Auto-detect: PR = sample, main/push = full
  if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
    EVAL_LIMIT=3
  else
    EVAL_LIMIT=""  # No limit = run all
  fi
fi

TRACES=($(ls "$REPO"/evals/traces/*.md 2>/dev/null | sort))
if [ -n "$EVAL_LIMIT" ] && [ ${#TRACES[@]} -gt "$EVAL_LIMIT" ]; then
  TRACES=($(printf '%s\n' "${TRACES[@]}" | head -n "$EVAL_LIMIT"))
  echo ">> PR mode: sampling ${#TRACES[@]} of $(ls "$REPO"/evals/traces/*.md 2>/dev/null | wc -l) traces (set EVAL_LIMIT=0 for full)" >> "$RESULTS"
fi

for TRACE in "${TRACES[@]}"; do
  [ -e "$TRACE" ] || continue
  NAME=$(basename "$TRACE" .md); TOTAL=$((TOTAL+1))
  WT="/tmp/eval-$NAME"
  git worktree remove -f "$WT" >/dev/null 2>&1 || true
  git worktree add -f "$WT" "$BASE_BRANCH" >/dev/null 2>&1

  PROMPT=$(awk '/^## Prompt/{f=1;next}/^## /{f=0}f' "$TRACE")
  # Isolated throwaway worktree in CI: agent needs full permissions to implement changes.
  # Safety: worktree is in /tmp, repo is fresh per trace, no prod/main diffs escape.
  (cd "$WT" && timeout 300 claude -p "$PROMPT" --output-format json --dangerously-skip-permissions > "/tmp/eval-$NAME.json" 2>&1 || echo "TIMEOUT/BLOCKED" >> "/tmp/eval-$NAME.json")

  OK=1
  (cd "$WT" && eval "$BASE_CHECK" >/dev/null 2>&1) || OK=0
  # Agent MUST make changes; empty diff = no implementation = false green
  (cd "$WT" && ! git diff --quiet) || { OK=0; echo "  - FAIL: agent made no changes" >> "$RESULTS"; }
  while IFS= read -r CHECK; do
    (cd "$WT" && eval "$CHECK" >/dev/null 2>&1) || { OK=0; echo "  - FAIL check: $CHECK" >> "$RESULTS"; }
  done < <(grep -E '^\s*-\s*\[\s*\]\s*cmd:' "$TRACE" | sed -E 's/.*cmd:[[:space:]]*//')

  if [ "$OK" = 1 ]; then echo "- $NAME: PASS" >> "$RESULTS"; PASS=$((PASS+1));
  else echo "- $NAME: FAIL" >> "$RESULTS"; fi
  git worktree remove -f "$WT" >/dev/null 2>&1
done
echo "" >> "$RESULTS"; echo "**$PASS/$TOTAL**" >> "$RESULTS"
echo "Pass rate: $PASS/$TOTAL → $RESULTS"
[ "$PASS" = "$TOTAL" ]
