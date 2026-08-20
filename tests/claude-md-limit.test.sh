#!/bin/bash
# Smoke tests for claude-md-limit.sh: blocks CLAUDE.md edits that exceed the line
# limit, ignores everything else. Each test writes a fixture file, feeds a matching
# JSON payload via stdin, and checks the exit code (0 = allowed, 2 = blocked).

set -e
command -v jq >/dev/null || { echo "SKIP: jq missing (hook soft-fails by design)"; exit 0; }
HOOK="$(cd "$(dirname "$0")/../hooks" && pwd)/claude-md-limit.sh"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
PASS=0; TOTAL=0

test_hook() {
  local NAME="$1" FILE="$2" LINES="$3" EXPECT_EXIT="$4"
  TOTAL=$((TOTAL+1))

  if [ "$LINES" -gt 0 ]; then
    yes "line" | head -n "$LINES" > "$FILE"
  else
    rm -f "$FILE"
  fi

  EXIT=0
  echo "{\"tool_input\":{\"file_path\":\"$FILE\"}}" | bash "$HOOK" >/dev/null 2>&1 || EXIT=$?

  if [ "$EXIT" = "$EXPECT_EXIT" ]; then
    echo "✓ $NAME"
    PASS=$((PASS+1))
  else
    echo "✗ $NAME (expected exit $EXPECT_EXIT, got $EXIT)"
  fi
}

test_hook "block: CLAUDE.md over the 200-line limit" "$TMPDIR/CLAUDE.md" 201 2
test_hook "allow: CLAUDE.md at exactly the limit" "$TMPDIR/CLAUDE.md" 200 0
test_hook "allow: CLAUDE.md well under the limit" "$TMPDIR/CLAUDE.md" 20 0
test_hook "allow: CLAUDE.local.md ignored regardless of length" "$TMPDIR/CLAUDE.local.md" 300 0
test_hook "allow: unrelated file ignored regardless of length" "$TMPDIR/notes.md" 300 0

# Regression: wc -l counts newlines, so a 201-line file whose last line has no
# trailing newline would undercount to 200 and slip through — must still block.
TOTAL=$((TOTAL+1))
NO_TRAILING_NL="$TMPDIR/CLAUDE.md"
awk 'BEGIN{for(i=1;i<201;i++) print "line"; printf "line"}' > "$NO_TRAILING_NL"
EXIT=0
echo "{\"tool_input\":{\"file_path\":\"$NO_TRAILING_NL\"}}" | bash "$HOOK" >/dev/null 2>&1 || EXIT=$?
if [ "$EXIT" = 2 ]; then
  echo "✓ block: 201 lines, no trailing newline on the last line"
  PASS=$((PASS+1))
else
  echo "✗ block: 201 lines, no trailing newline on the last line (expected exit 2, got $EXIT)"
fi

TOTAL=$((TOTAL+1))
EXIT=0
echo '{"tool_input":{}}' | bash "$HOOK" >/dev/null 2>&1 || EXIT=$?
if [ "$EXIT" = 0 ]; then echo "✓ allow: no file_path in payload"; PASS=$((PASS+1)); else echo "✗ allow: no file_path in payload (got $EXIT)"; fi

echo ""
echo "Pass rate: $PASS/$TOTAL"
[ "$PASS" = "$TOTAL" ] || exit 1
