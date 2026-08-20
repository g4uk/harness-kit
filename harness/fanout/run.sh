#!/bin/bash
# Parallel fan-out via worktrees (docs/harness-playbook.md § fanout Step 7.3-7.4): one
# worktree + branch per shard, sharing .git so agents never step on each other's files.
# Deliberately worktree, not clone — unlike harness/evals/run.sh, which clones on
# purpose for Docker mount isolation (see PATCH.md § "Why clone instead of worktree").
# This script only creates the worktrees and seeds the log; it does not launch `claude`
# for you — start those sessions yourself, one per printed directory.
#
# Usage: harness/fanout/run.sh <base-branch> <shard-1> [<shard-2> ...]
# Prereq: write docs/harness/migration-playbook-<name>.md first
#         (see templates/migration-playbook.md.template) and push <base-branch>.
set -eu
BASE="${1:?usage: harness/fanout/run.sh <base-branch> <shard-1> [shard-2 ...]}"
shift
[ $# -ge 1 ] || { echo "need at least 1 shard name" >&2; exit 1; }

REPO=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO")
KIT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG="$REPO/docs/harness/fanout-log.md"

git -C "$REPO" rev-parse --verify "$BASE" >/dev/null 2>&1 || {
  echo "Branch '$BASE' not found. Create and push it first:" >&2
  echo "  git checkout -b $BASE && git push -u origin $BASE" >&2
  exit 1
}

mkdir -p "$(dirname "$LOG")"
if [ ! -f "$LOG" ]; then
  if [ -f "$KIT_DIR/templates/fanout-log.md.template" ]; then
    cp "$KIT_DIR/templates/fanout-log.md.template" "$LOG"
  else
    # KIT_DIR is this project's own root when installed via install.sh (no templates/
    # copy there by design — see templates/fanout-log.md.template in the kit source).
    cat > "$LOG" <<'EOF'
# Fan-out Log

Keep this updated in real time while shards run in parallel. You are the tech lead
here: unblock shards, don't write their code.

| Time | Shard | Event | My action |
|---|---|---|---|

## Merge + cost delta (after all shards land)

| Metric | Sequential (estimate: one shard actual × N) | Fan-out × N |
|---|---|---|
| Wall-clock | | |
| $ total | | |
| My minutes | | |
| Merge conflicts | | |

Conclusion: fan-out for ___, NOT for ___.
EOF
  fi
fi

for SHARD in "$@"; do
  DIR="../${REPO_NAME}-${SHARD}"
  BRANCH="${BASE}-${SHARD}"
  if git -C "$REPO" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    echo ">> $SHARD: branch $BRANCH already exists — skipping worktree creation, reusing it."
  else
    git -C "$REPO" worktree add "$DIR" -b "$BRANCH" "$BASE"
    echo "| $(date +%H:%M) | $SHARD | worktree created ($DIR, branch $BRANCH) | — |" >> "$LOG"
  fi
  ABS_DIR="$(cd "$REPO/$DIR" && pwd)"
  echo ">> $SHARD: cd $ABS_DIR && claude"
done

echo ""
echo ">> Logged to $LOG — update it in real time as shards report in (docs/harness-playbook.md § fanout Step 7.4)."
echo ">> After merging each shard: git worktree remove ../${REPO_NAME}-<shard>"
