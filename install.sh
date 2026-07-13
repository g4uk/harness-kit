#!/bin/bash
# Installs the kit as a .claude/ directory.
#   ./install.sh /path/to/repo      → project-level (.claude/ in the repo, goes into git)
#   ./install.sh --user             → user-level (~/.claude/) for the onboarding scenario
# Tip: for 2+ repos keep the kit itself as a separate git repo and update via re-install.
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)"

command -v jq >/dev/null || echo "!! WARNING: jq not found. guard.sh is fail-closed and will block EVERYTHING. Install: apt/brew install jq"
command -v gitleaks >/dev/null || echo ">> Recommendation: install gitleaks — secrets-scan becomes far more accurate"

if [ "${1:-}" = "--user" ]; then
  DST="$HOME/.claude"
  mkdir -p "$DST/hooks" "$DST/agents"
  cp -n "$SRC"/hooks/guard.sh "$SRC"/hooks/secrets-scan.sh "$DST/hooks/" 2>/dev/null || true
  chmod +x "$DST"/hooks/*.sh
  cp -n "$SRC"/agents/researcher.md "$SRC"/agents/reviewer.md "$DST/agents/" 2>/dev/null || true
  if [ ! -f "$DST/settings.json" ]; then
    cp "$SRC/settings/settings.user.json" "$DST/settings.json"
    echo ">> Created ~/.claude/settings.json (permissions deny + guard + secrets-scan)"
  else
    echo ">> ~/.claude/settings.json already exists. Merge manually from: $SRC/settings/settings.user.json"
  fi
  echo ">> User level ready: guard + secrets-scan + researcher/reviewer."
  exit 0
fi

REPO="${1:?provide a repo path or --user}"
DST="$REPO/.claude"
mkdir -p "$DST"/{skills,agents,commands,hooks}
cp -r "$SRC"/skills/*   "$DST/skills/"
cp    "$SRC"/agents/*   "$DST/agents/"
cp    "$SRC"/commands/* "$DST/commands/"
cp    "$SRC"/hooks/*.sh "$DST/hooks/"
chmod +x "$DST"/hooks/*.sh

if [ ! -f "$DST/settings.json" ]; then
  cp "$SRC/settings/settings.project.json" "$DST/settings.json"
  echo ">> Created .claude/settings.json: permissions (deny-by-default) + 4 hooks"
  echo "   REVIEW the allow-list for your stack; permissions syntax — docs.claude.com"
else
  echo ">> .claude/settings.json already exists — merge manually from settings/settings.project.json"
fi

mkdir -p "$REPO/docs" "$REPO/specs" "$REPO/evals/traces" "$REPO/evals/results" "$REPO/.github/workflows"
cp -n "$SRC"/ci/harness-evals.yml "$REPO/.github/workflows/" 2>/dev/null || true
cp -n "$SRC"/ci/agent-review.yml  "$REPO/.github/workflows/" 2>/dev/null || true
cp -n "$SRC"/templates/metrics.md.template "$REPO/docs/metrics.md" 2>/dev/null || true
cp -n "$SRC"/templates/dispatch-matrix.md.template "$REPO/docs/dispatch-matrix.md" 2>/dev/null || true
cp -n "$SRC"/evals/run.sh "$REPO/evals/run.sh" 2>/dev/null || true
cp -n "$SRC"/evals/traces/001-example.md "$REPO/evals/traces/" 2>/dev/null || true
chmod +x "$REPO/evals/run.sh" 2>/dev/null || true
[ -f "$REPO/CLAUDE.md" ] || cp "$SRC/templates/CLAUDE.md.template" "$REPO/CLAUDE.md"

echo ">> Done. Next:"
echo "   1. CLAUDE.md: fill in the {{...}}"
echo "   2. EDIT_ME: skills/ (stack), hooks/tests-green.sh (test command), settings.json (allow-list)"
echo "   3. CI: add secrets.ANTHROPIC_API_KEY for harness-evals and agent-review"
echo "   4. Smoke test: echo '{\"tool_input\":{\"command\":\"git push -f\"}}' | .claude/hooks/guard.sh; echo exit=\$?"
echo "   5. Scenario: scenarios/{greenfield,onboarding,existing-own}.md"
