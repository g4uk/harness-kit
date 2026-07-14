#!/bin/bash
# Smoke test for the eval runner itself: a throwaway Go fixture + trivial trace.
# PASS proves: docker sandbox works, agent produced a real diff, checks executed.
set -eu
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIX=$(mktemp -d /tmp/runner-smoke-XXXX)
cd "$FIX" && git init -q && git config user.email t@t && git config user.name t
go_mod() { printf 'module smoke\n\ngo 1.23\n'; }; go_mod > go.mod
mkdir -p evals/traces evals/results
cp -r "$KIT_DIR/docker" . && cp "$KIT_DIR/evals/run.sh" evals/
cat > evals/traces/001-smoke.md << 'T'
# 001: smoke
## Prompt
Create hello.go with func Answer() int returning 42, and hello_test.go verifying it.
## Checks
- [ ] cmd: go test ./...
- [ ] cmd: git grep -q "func Answer" -- hello.go
T
git add -A && git commit -qm init
EVAL_LIMIT=1 ./evals/run.sh
