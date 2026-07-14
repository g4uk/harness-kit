# harness-kit v1.2.1

A shared harness core for three Claude Code working scenarios.
Progression is gated by evidence (exit criteria per stage), not by a calendar.

## Requirements
- **bash** + **jq** (for guard.sh). Without jq, guard.sh is fail-closed (blocks EVERYTHING).
  - macOS: `brew install jq`
  - Linux: `apt install jq` or `yum install jq`
  - Windows: Not supported. Run via WSL or Docker.
- **git** (obviously)
- **gitleaks** (recommended for secrets-scan accuracy; falls back to grep)

## Structure
```
commands/    /spec /plan /commit /verify /retro /feature
agents/      researcher, test-writer, implementer, reviewer, doc-writer
skills/      code-review, testing, db-migrations, frontend      ← EDIT_ME for your stack
hooks/       guard.sh (PreToolUse, exit 2, fail-closed without jq)
             secrets-scan.sh (PostToolUse: gitleaks or grep fallback)
             fmt.sh · tests-green.sh (Stop, scoped to changed packages)
settings/    settings.project.json / settings.user.json — permissions deny-by-default + hooks
ci/          harness-evals.yml (invariant #6 as code) · agent-review.yml
             plan-verify.yml (custom plan coherence checks) · hooks-test.yml (regression detection)
templates/   CLAUDE.md, CLAUDE.local.md, surface-map, decisions, metrics,
             dispatch-matrix, spec, plan, eval-trace
evals/       run.sh — executes "cmd:" checks from traces; exit≠0 on failure · traces/001-example.md
scenarios/   greenfield · onboarding · existing-own — checklist overlays
docs/        full step-by-step guides the kit was distilled from
examples/    craftplan-spec.md, plan.md, retro.md — complete spec→plan→retro cycle (learning reference)
extras/      harness-dashboard.jsx — interactive progress tracker (Claude artifact)
tests/       hooks.test.sh — smoke tests for guard.sh patterns (refspec, .env, sh -c)
build/       dashboard.sh — generates artifact-ready version for offline use
install.sh   → project .claude/ (with settings and CI) or ~/.claude (--user)
VERSION      Kit version for update detection
```

## Security model (two layers + a scanner)
1. **permissions in settings.json — deny-by-default.** Only the allow-list is permitted.
   The primary layer: it can't be bypassed by rephrasing a command.
2. **guard.sh** — readable block explanations + patterns beyond the permissions syntax
   (refspec force `+main`, `sh -c` wrappers, prod migrations). Fail-closed without jq.
3. **secrets-scan.sh** — catches secrets in just-written files (gitleaks, grep fallback).
The permissions syntax evolves — verify at docs.claude.com/en/docs/claude-code/settings.

## Quick start
```bash
./install.sh ~/dev/myproject     # your own project: .claude/ + settings + CI + evals
./install.sh --user              # someone else's project: personal level, nothing in the repo
./install.sh ~/dev/myproject --update  # update existing .claude/ to latest kit version
```
Then open your scenario in scenarios/ and follow the checklist. Gate smoke test — step 4 of install.sh output.

## Learn by Example
See `examples/craftplan-*.md` for a complete spec → plan → retro cycle in one go:
- Spec + design decisions
- Detailed plan with phases and effort estimates
- Retro with metrics, divergences, and next-phase decisions

Takes ~2 minutes to read; shows the full harness pattern in miniature.

## Invariants
1. perceive → spec → plan → implement → verify (/verify is a command, not a mood).
2. Safety lives in permissions+hooks, not prompts. A prompt is a wish; a gate is a guarantee.
3. A subagent returns a condensed result; small tasks skip subagents (/feature declines them itself).
4. Metrics from day one: /cost → the log. Deliberately manual — numbers without your judgment are dead.
5. /retro after every merge: divergences → templates, conventions → CLAUDE.md, criteria → a trace.
6. A change to .claude/** or CLAUDE.md doesn't merge without green evals — now a CI gate, not a wish.

## How the scenarios differ
| | greenfield | onboarding | existing-own |
|---|---|---|---|
| CLAUDE.md is written from | decisions (decisions.md) | verified facts (CLAUDE.local) | perception-gap audit |
| Gates | commit #1 | user-level immediately; in repo — after the trust gate | quality-gates stage |
| Install level | .claude/ in repo | ~/.claude | .claude/ in repo |
| Evals | grow via /retro | after legitimization | 20 traces from done tasks |

## Changelog v1.2.1 (CRITICAL: false-green eval fix)
- **CRITICAL**: eval-runner was using `--allowedTools fetch` (read-only)
  - Agent could not implement changes; tests passed on *unchanged* code = silent failure
  - Fixed: `--dangerously-skip-permissions` for isolated throwaway CI worktree
  - Added: `! git diff --quiet` check to catch zero-change traces
  - Upgraded: EVAL_LIMIT now auto-detects PR vs main via `GITHUB_EVENT_NAME`

## Changelog v1.2 (production hardening)
- **eval-runner fix**: 5min timeout prevents CI hang on permission-blocked traces
- **EVAL_LIMIT**: sample mode (PR: 3 traces) vs full run (main branch) to reduce CI cost/time
- **hooks-test.yml**: automated regression detection for guard.sh patterns (refspec, .env, wrappers)
- **plan-verify.yml**: explicit CI workflow stub for custom plan coherence checks
- **install.sh**: `--update` mode + VERSION tracking (detect outdated .claude/ directories)
- **guard.sh**: warning comment about wide permissions like `Bash(cat:*)` (dangerous; narrow to dir)
- **Requirements**: explicit bash + jq (Windows unsupported) in README

## Changelog v1.1 (review patch)
- permissions deny-by-default (project + user samples) — the primary security layer
- secrets-scan.sh on Write|Edit; guard.sh: fail-closed, +refspec-force, +sh -c
- /verify and /feature (orchestration with approval stops; declines the pipeline for trivial tasks)
- evals/run.sh executes cmd: checks and returns exit≠0; example trace 001
- ci/harness-evals.yml — invariant #6 as a CI gate; agent-review.yml included
- frontend skill (React/TS/Three.js); tests-green.sh scoped to changed packages
- install.sh: installs settings and CI, generates ready user settings, checks jq/gitleaks

## Docs
Full guides the kit is distilled from (all examples use CraftPlan, a fictional reference project):
- docs/harness-playbook.md — the full program, module by module, with worked examples
- docs/onboarding-new-project.md — joining someone else's project
- docs/greenfield-harness.md — starting a project from scratch, harness-first

## Extras
- **harness-dashboard.jsx** — interactive checklist/metrics dashboard
  (paste into a Claude.ai artifact; progress persists between sessions)
  Build script: `./build/dashboard.sh` → `dist/harness-dashboard-artifact.jsx`
  Export metrics to markdown for docs/metrics.md sync

## License
MIT — see LICENSE.
