#!/bin/bash
# Sandboxed one-shot Claude run — the ONLY sanctioned way to execute an agent
# against project code. Usage:
#   docker/claude-run.sh <project-dir> <prompt> [output-file]
#
# Why --dangerously-skip-permissions is safe HERE and only here:
# the boundary is the container, not the permission config —
# throwaway mount, non-root user, dropped capabilities, resource limits.
# NEVER use that flag on the host.
set -eu
DIR=$(cd "$1" && pwd); PROMPT="$2"; OUT="${3:-/dev/stdout}"
IMG="${HARNESS_IMAGE:-harness-runner:latest}"
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

command -v docker >/dev/null || { echo "FATAL: docker is required for project runs (policy)."; exit 1; }
docker image inspect "$IMG" >/dev/null 2>&1 || docker build -t "$IMG" "$KIT_DIR/docker"

docker run --rm \
  -e ANTHROPIC_API_KEY \
  -v "$DIR":/work -w /work \
  --memory=4g --cpus=2 --pids-limit=512 \
  --cap-drop=ALL --security-opt no-new-privileges \
  "$IMG" \
  timeout 300 claude -p "$PROMPT" --output-format json --dangerously-skip-permissions \
  > "$OUT" 2>&1
