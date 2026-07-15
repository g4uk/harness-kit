#!/bin/bash
# Eval runner. POLICY: every project-touching execution (agent AND checks)
# happens inside the harness-runner Docker container. This script only orchestrates.
#
# HARNESS_ALLOW_HOST=1 is an escape hatch for debugging — never for real runs.
set -u
REPO=$(git rev-parse --show-toplevel)
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$KIT_DIR/docker/claude-run.sh"
EXEC="$KIT_DIR/docker/exec.sh"

if [ "${HARNESS_ALLOW_HOST:-}" != "1" ]; then
  command -v docker >/dev/null || { echo "FATAL: docker required (policy: project runs only in Docker)."; exit 1; }
fi

RESULTS="$REPO/evals/results/$(date +%F-%H%M).md"
mkdir -p "$REPO/evals/results"
echo "# Eval run $(date -Iseconds)" > "$RESULTS"
PASS=0; TOTAL=0

# EDIT_ME: baseline check for every trace (runs inside the container)
BASE_CHECK="go test ./..."
# EDIT_ME: base branch (auto-detected; override if needed)
BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
BASE_BRANCH=${BASE_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}

# EVAL_LIMIT: run only the first N traces (PR sampling). Unset/0 = all.
LIMIT="${EVAL_LIMIT:-0}"

for TRACE in "$REPO"/evals/traces/*.md; do
  [ -e "$TRACE" ] || continue
  [ "$LIMIT" != "0" ] && [ "$TOTAL" -ge "$LIMIT" ] && break
  NAME=$(basename "$TRACE" .md); TOTAL=$((TOTAL+1))
  echo ">> trace $NAME (up to 5 min)..."

  # Plain clone, not a worktree: a worktree's .git file holds an absolute HOST
  # path and breaks when only the worktree is mounted into a container.
  WT="/tmp/eval-$NAME"
  rm -rf "$WT"
  git clone --quiet --branch "$BASE_BRANCH" "$REPO" "$WT"

  PROMPT=$(awk '/^## Prompt/{f=1;next}/^## /{f=0}f' "$TRACE")
  "$RUN" "$WT" "$PROMPT" "/tmp/eval-$NAME.json" || true

  OK=1
  # Empty-run detector: the agent MUST have changed something.
  "$EXEC" "$WT" "! git diff --quiet || ! git diff --cached --quiet || [ -n \"\$(git status --porcelain)\" ]" \
    || { OK=0; echo "  - FAIL: empty run (no diff)" >> "$RESULTS"; }

  # Stage the agent's output: it isn't expected to commit, but checks that use
  # git-aware tools (git grep, git diff --cached) must see its new/changed files.
  "$EXEC" "$WT" "git add -A" >/dev/null 2>&1
  "$EXEC" "$WT" "$BASE_CHECK" >/dev/null 2>&1 || { OK=0; echo "  - FAIL: base check" >> "$RESULTS"; }

  # BSD/GNU-portable extraction of "- [ ] cmd: <shell>" checks (no grep -P)
  while IFS= read -r CHECK; do
    [ -z "$CHECK" ] && continue
    "$EXEC" "$WT" "$CHECK" >/dev/null 2>&1 || { OK=0; echo "  - FAIL check: $CHECK" >> "$RESULTS"; }
  done < <(sed -n 's/^[[:space:]]*-[[:space:]]*\[[[:space:]]*\][[:space:]]*cmd:[[:space:]]*//p' "$TRACE")

  if [ "$OK" = 1 ]; then echo "- $NAME: PASS" >> "$RESULTS"; PASS=$((PASS+1));
  else echo "- $NAME: FAIL" >> "$RESULTS"; fi
  rm -rf "$WT"
done
echo "" >> "$RESULTS"; echo "**$PASS/$TOTAL**" >> "$RESULTS"
echo "Pass rate: $PASS/$TOTAL → $RESULTS"
[ "$PASS" = "$TOTAL" ] && [ "$TOTAL" -gt 0 ]
