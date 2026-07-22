#!/bin/bash
# Installs the kit as a .claude/ directory.
#   ./install.sh /path/to/repo      → project-level (.claude/ in the repo, goes into git)
#   ./install.sh --user             → user-level (~/.claude/) for the onboarding scenario
#   ./install.sh /path/to/repo --update → update existing .claude/ to kit version
# Tip: for 2+ repos keep the kit itself as a separate git repo and update via re-install.
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)"
KIT_VERSION=$(cat "$SRC/VERSION")

command -v jq >/dev/null || echo "!! WARNING: jq not found. guard.sh is fail-closed and will block EVERYTHING. Install: apt/brew install jq"
command -v gitleaks >/dev/null || echo ">> Recommendation: install gitleaks — secrets-scan becomes far more accurate"

# Parse arguments
UPDATE_MODE=false
if [ $# -ge 2 ] && [ "${2:-}" = "--update" ]; then
  UPDATE_MODE=true
fi

if [ "${1:-}" = "--user" ]; then
  DST="$HOME/.claude"
  mkdir -p "$DST/hooks" "$DST/agents"
  
  if [ "$UPDATE_MODE" = true ]; then
    cp "$SRC"/hooks/guard.sh "$SRC"/hooks/secrets-scan.sh "$DST/hooks/" 2>/dev/null || true
    cp "$SRC"/agents/researcher.md "$SRC"/agents/reviewer.md "$DST/agents/" 2>/dev/null || true
  else
    cp -n "$SRC"/hooks/guard.sh "$SRC"/hooks/secrets-scan.sh "$DST/hooks/" 2>/dev/null || true
    cp -n "$SRC"/agents/researcher.md "$SRC"/agents/reviewer.md "$DST/agents/" 2>/dev/null || true
  fi
  chmod +x "$DST"/hooks/*.sh
  
  if [ ! -f "$DST/settings.json" ]; then
    cp "$SRC/settings/settings.user.json" "$DST/settings.json"
    echo ">> Created ~/.claude/settings.json (permissions deny + guard + secrets-scan)"
  else
    if [ "$UPDATE_MODE" = true ]; then
      echo ">> ~/.claude/settings.json exists — run 'diff' manually to merge new defaults"
    fi
  fi
  
  echo "$KIT_VERSION" > "$DST/VERSION"
  echo ">> User level: version $KIT_VERSION (guard + secrets-scan + researcher/reviewer)"
  exit 0
fi

REPO="${1:?provide a repo path, --user, or repo path --update}"
if [ "$UPDATE_MODE" = true ]; then
  DST="$REPO/.claude"
  [ ! -d "$DST" ] && { echo ">> ERROR: $DST not found. Did you mean ./install.sh /path/to/repo (first time)?"; exit 1; }
  OLD_VERSION=$(cat "$DST/VERSION" 2>/dev/null || echo "UNKNOWN")
  echo ">> Updating $DST from version $OLD_VERSION → $KIT_VERSION"
  COPY_CMD="cp"  # Always overwrite on update
else
  REPO="$1"
  DST="$REPO/.claude"
  COPY_CMD="cp -n"  # Don't overwrite on fresh install
fi

mkdir -p "$DST"/{skills,agents,commands/harness,hooks}
if [ "$COPY_CMD" = "cp" ]; then
  cp -r "$SRC"/skills/* "$DST/skills/" 2>/dev/null || true
  cp "$SRC"/agents/* "$DST/agents/" 2>/dev/null || true
  cp "$SRC"/commands/harness/* "$DST/commands/harness/" 2>/dev/null || true
  cp "$SRC"/hooks/*.sh "$DST/hooks/" 2>/dev/null || true
else
  cp -r "$SRC"/skills/* "$DST/skills/"
  cp "$SRC"/agents/* "$DST/agents/"
  cp "$SRC"/commands/harness/* "$DST/commands/harness/"
  cp "$SRC"/hooks/*.sh "$DST/hooks/"
fi
chmod +x "$DST"/hooks/*.sh

# v1.8 migration: commands moved from .claude/commands/*.md (bare /spec,
# /plan, ...) to .claude/commands/harness/*.md (/harness:spec, /harness:plan,
# ... — namespaced so they don't collide with other installed plugins). Clean
# up the old flat files so they don't linger as dead duplicates.
if [ "$UPDATE_MODE" = true ]; then
  for f in spec plan commit verify retro feature onboard log-metrics; do
    [ -f "$DST/commands/$f.md" ] && rm -f "$DST/commands/$f.md"
  done
fi

if [ ! -f "$DST/settings.json" ]; then
  cp "$SRC/settings/settings.project.json" "$DST/settings.json"
  echo ">> Created .claude/settings.json: permissions (deny-by-default) + 4 hooks"
  echo "   REVIEW the allow-list for your stack; permissions syntax — docs.claude.com"
else
  if [ "$UPDATE_MODE" = true ]; then
    echo ">> .claude/settings.json exists — run 'diff' manually to merge new defaults"
  else
    echo ">> .claude/settings.json already exists — merge manually from settings/settings.project.json"
  fi
fi

# v1.9 migration: docker/ and evals/ move under harness/ (avoids colliding
# with a project's own docker/ folder for its actual product — e.g. a
# docker-compose app). Only migrate if it looks like OUR files (never blindly
# delete: evals/traces/*.md and evals/results/*.md are real project history,
# not kit boilerplate) and only if the new location doesn't exist yet.
if [ "$UPDATE_MODE" = true ]; then
  if [ -f "$REPO/docker/claude-run.sh" ] && [ -f "$REPO/docker/exec.sh" ] && [ ! -d "$REPO/harness/docker" ]; then
    mkdir -p "$REPO/harness"
    mv "$REPO/docker" "$REPO/harness/docker"
    echo ">> Migrated docker/ -> harness/docker/"
  fi
  if [ -f "$REPO/evals/run.sh" ] && [ ! -d "$REPO/harness/evals" ]; then
    mkdir -p "$REPO/harness"
    mv "$REPO/evals" "$REPO/harness/evals"
    echo ">> Migrated evals/ -> harness/evals/ (traces/ and results/ preserved)"
  fi
fi

mkdir -p "$REPO/docs" "$REPO/specs" "$REPO/harness/evals/traces" "$REPO/harness/evals/results" "$REPO/.github/workflows" "$REPO/harness/docker"
if [ "$UPDATE_MODE" = true ]; then
  # Overwrite CI workflows on update
  cp "$SRC"/ci/harness-evals.yml "$REPO/.github/workflows/" 2>/dev/null || true
  cp "$SRC"/ci/agent-review.yml "$REPO/.github/workflows/" 2>/dev/null || true
  cp "$SRC"/ci/plan-verify.yml "$REPO/.github/workflows/" 2>/dev/null || true
  cp "$SRC"/ci/hooks-test.yml "$REPO/.github/workflows/" 2>/dev/null || true
  cp "$SRC"/harness/evals/run.sh "$REPO/harness/evals/run.sh" 2>/dev/null || true
  chmod +x "$REPO/harness/evals/run.sh" 2>/dev/null || true
  cp "$SRC"/harness/docker/Dockerfile "$SRC"/harness/docker/claude-run.sh "$SRC"/harness/docker/exec.sh "$REPO/harness/docker/" 2>/dev/null || true
  chmod +x "$REPO"/harness/docker/claude-run.sh "$REPO"/harness/docker/exec.sh 2>/dev/null || true
else
  # Fresh install: don't overwrite
  cp -n "$SRC"/ci/harness-evals.yml "$REPO/.github/workflows/" 2>/dev/null || true
  cp -n "$SRC"/ci/agent-review.yml "$REPO/.github/workflows/" 2>/dev/null || true
  cp -n "$SRC"/ci/plan-verify.yml "$REPO/.github/workflows/" 2>/dev/null || true
  cp -n "$SRC"/ci/hooks-test.yml "$REPO/.github/workflows/" 2>/dev/null || true
  cp -n "$SRC"/templates/metrics.md.template "$REPO/docs/metrics.md" 2>/dev/null || true
  cp -n "$SRC"/templates/dispatch-matrix.md.template "$REPO/docs/dispatch-matrix.md" 2>/dev/null || true
  cp -n "$SRC"/harness/evals/run.sh "$REPO/harness/evals/run.sh" 2>/dev/null || true
  chmod +x "$REPO/harness/evals/run.sh" 2>/dev/null || true
  [ -f "$REPO/CLAUDE.md" ] || cp "$SRC/templates/CLAUDE.md.template" "$REPO/CLAUDE.md"
  cp -n "$SRC"/harness/docker/Dockerfile "$SRC"/harness/docker/claude-run.sh "$SRC"/harness/docker/exec.sh "$REPO/harness/docker/" 2>/dev/null || true
  chmod +x "$REPO"/harness/docker/claude-run.sh "$REPO"/harness/docker/exec.sh 2>/dev/null || true
fi

echo "$KIT_VERSION" > "$DST/VERSION"
echo ">> Done. Version: $KIT_VERSION"
if [ "$UPDATE_MODE" = false ]; then
  echo "   Next:"
  echo "   1. CLAUDE.md: fill in the {{...}}"
  echo "   2. EDIT_ME: skills/ (stack), hooks/tests-green.sh (test command), settings.json (allow-list)"
  echo "   3. CI: add ANTHROPIC_API_KEY as a REPOSITORY secret (Settings > Secrets and"
  echo "      variables > Actions > Repository secrets) for harness-evals + agent-review."
  echo "      NOT an Environment secret — these workflows don't declare environment:,"
  echo "      so an environment-scoped (or org-scoped-but-unshared) secret silently"
  echo "      yields apiKeySource:none in the container, not an error."
  echo "   4. Smoke test: echo '{\"tool_input\":{\"command\":\"git push -f\"}}' | .claude/hooks/guard.sh; echo exit=\$?"
  echo "   5. Scenario: scenarios/{greenfield,onboarding,existing-own}.md"
fi
