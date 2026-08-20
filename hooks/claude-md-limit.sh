#!/bin/bash
# PostToolUse(Write|Edit): enforce CLAUDE.md <=200 lines (docs/harness-playbook.md § skills-layer
# Step 2.6). Turns the line limit into a gate instead of prose nobody checks — blocks
# the edit that pushed it over. Skills trigger themselves; moved content needs no
# pointer line back in CLAUDE.md. Not a security hook (see guard.sh) — soft-fails
# (exit 0) if jq is missing rather than fail-closed.
command -v jq >/dev/null || exit 0
FILE=$(jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0
[ "$(basename "$FILE")" = "CLAUDE.md" ] || exit 0
[ -f "$FILE" ] || exit 0

LIMIT="${CLAUDE_MD_LINE_LIMIT:-200}"
# awk NR at END, not wc -l: wc -l counts newlines, so a file whose last line
# has no trailing newline (a real serialization case) would undercount by one
# and let an over-limit file through.
LINES=$(awk 'END{print NR}' "$FILE")
if [ "$LINES" -gt "$LIMIT" ]; then
  echo "BLOCKED: CLAUDE.md is now $LINES lines (limit $LIMIT). Move procedures into a" \
       "Skill (.claude/skills/<name>/SKILL.md) instead — CLAUDE.md loads in EVERY" \
       "session, a Skill loads only when relevant. See docs/harness-playbook.md § skills-layer" \
       "Step 2.6, or raise CLAUDE_MD_LINE_LIMIT if this project has a deliberate" \
       "exception." >&2
  exit 2
fi
exit 0
