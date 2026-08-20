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
  # harness/templates/ is where install.sh seeds this template in an installed
  # project; templates/ (kit source root) covers running run.sh straight out of
  # the kit repo. Single source of truth either way — no inline fallback copy.
  TEMPLATE="$KIT_DIR/harness/templates/mutation-report.md.template"
  [ -f "$TEMPLATE" ] || TEMPLATE="$KIT_DIR/templates/mutation-report.md.template"
  [ -f "$TEMPLATE" ] || {
    echo "mutation-report.md.template not found under harness/templates/ or templates/ — re-run install.sh to restore it." >&2
    exit 1
  }
  cp "$TEMPLATE" "$OUT"
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
