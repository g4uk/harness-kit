#!/bin/bash
# Mutation report (docs/harness-playbook.md § quality-gates Step 6.6): run go-mutesting against a
# package and append the result to docs/harness/mutation-report.md. The point: compare
# the score of a package with agent-written tests against one with handwritten tests —
# a noticeably lower agent score means the tests verify calls, not behavior (theater);
# fix the testing skill and the retro-spec.
# EDIT_ME for your stack — default here is Go via go-mutesting.
set -eu
PKG="${1:?usage: harness/mutation/run.sh <package path, e.g. ./internal/parts/> [label]}"
LABEL="${2:-$PKG}"
REPO=$(git rev-parse --show-toplevel)
KIT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$REPO/docs/harness/mutation-report.md"

command -v go-mutesting >/dev/null || {
  echo "go-mutesting not found. Install: go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest" >&2
  exit 1
}

mkdir -p "$(dirname "$OUT")"
if [ ! -f "$OUT" ]; then
  if [ -f "$KIT_DIR/templates/mutation-report.md.template" ]; then
    cp "$KIT_DIR/templates/mutation-report.md.template" "$OUT"
  else
    # KIT_DIR is this project's own root when installed via install.sh (no templates/
    # copy there by design — see templates/mutation-report.md.template in the kit source).
    cat > "$OUT" <<'EOF'
# Mutation Report

Mutation score = share of "killed" mutants. Compare a package with agent-written tests
against one with handwritten tests: a noticeably lower agent score means the tests
verify calls, not behavior (theater) → fix the testing skill and the retro-spec.

| Package | Tests written by | Mutation score | Verdict |
|---|---|---|---|
| | | | |

## Runs
EOF
  fi
fi

RESULT=$(go-mutesting "$PKG" 2>&1) || true
{
  echo ""
  echo "### $LABEL — $(date +%Y-%m-%d\ %H:%M)"
  echo '```'
  echo "$RESULT"
  echo '```'
} >> "$OUT"

echo "$RESULT" | tail -5
echo ">> Appended to $OUT"
echo ">> Fill in the summary table at the top of that file: package, who wrote the tests, score, verdict."
