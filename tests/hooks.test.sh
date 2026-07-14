#!/bin/bash
# Smoke tests for guard.sh: refspec-force, .env reading, sh -c wrapper, etc.
# Each test passes a JSON payload via stdin to guard.sh and checks the exit code.
# Exit 0 = allowed, exit 2 = blocked (expected for all these patterns).

set -e
GUARD="$(cd "$(dirname "$0")/../hooks" && pwd)/guard.sh"
PASS=0; TOTAL=0

test_guard() {
  local NAME="$1"
  local JSON="$2"
  local EXPECT_EXIT="$3"
  TOTAL=$((TOTAL+1))
  
  EXIT=0
  echo "$JSON" | bash "$GUARD" >/dev/null 2>&1 || EXIT=$?
  
  if [ "$EXIT" = "$EXPECT_EXIT" ]; then
    echo "✓ $NAME"
    PASS=$((PASS+1))
  else
    echo "✗ $NAME (expected exit $EXPECT_EXIT, got $EXIT)"
  fi
}

# BLOCKED (exit 2) patterns
test_guard "deny: rm -rf /" '{"tool_input":{"command":"rm -rf /"}}' 2
test_guard "deny: force push via git push -f" '{"tool_input":{"command":"git push -f"}}' 2
test_guard "deny: force push via refspec +" '{"tool_input":{"command":"git push origin +main:main"}}' 2
test_guard "deny: .env.local read" '{"tool_input":{"command":"cat .env.local"}}' 2
test_guard "deny: .env read via grep" '{"tool_input":{"command":"grep SECRET .env"}}' 2
test_guard "deny: sh -c wrapper" '{"tool_input":{"command":"sh -c '\''echo hello'\''"}}' 2
test_guard "deny: bash -c wrapper" '{"tool_input":{"command":"bash -c '\''git push'\''"}}' 2
test_guard "deny: chmod +x /tmp" '{"tool_input":{"command":"chmod +x /tmp/script.sh"}}' 2
test_guard "deny: DROP TABLE" '{"tool_input":{"command":"DROP TABLE users"}}' 2
test_guard "deny: prod migrate" '{"tool_input":{"command":"goose -dir migrations postgres prod up"}}' 2

# ALLOWED (exit 0) patterns
test_guard "allow: normal git push" '{"tool_input":{"command":"git push"}}' 0
test_guard "allow: normal push to branch" '{"tool_input":{"command":"git push origin feature"}}' 0
test_guard "allow: cat app.go" '{"tool_input":{"command":"cat app.go"}}' 0
test_guard "allow: grep in code" '{"tool_input":{"command":"grep TODO src/"}}' 0
test_guard "allow: chmod normal" '{"tool_input":{"command":"chmod +x script.sh"}}' 0
test_guard "allow: empty cmd" '{"tool_input":{"command":""}}' 0
test_guard "allow: null cmd" '{"tool_input":{}}' 0

echo ""
echo "Pass rate: $PASS/$TOTAL"
[ "$PASS" = "$TOTAL" ] || exit 1
