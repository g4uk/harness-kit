# harness-kit v1.9

A shared harness core for three Claude Code working scenarios.
Progression through each scenario's stages is gated by evidence — exit criteria, not a schedule.

## Requirements
- **docker** (mandatory for eval runs). Policy: the agent's own run always executes in the harness-runner sandbox; checks (base check + trace `cmd:`, human-approved via `/harness:retro`) do too by default, but run directly on the host when `HARNESS_EVAL_CHECKS_HOST=1` — set by `ci/harness-evals.yml` for GitHub Actions (already an isolated, single-job VM with a native Docker daemon), opt-in for any other CI. See `harness/evals/run.sh`.
- **bash** + **jq** (for guard.sh and local orchestration).
  - macOS: `brew install jq docker`
  - Linux: `apt install jq` + install Docker from docker.io
  - Windows: Not supported. Run via WSL with Docker.
- **git** (obviously)
- **gitleaks** (recommended for secrets-scan accuracy; falls back to grep)

## Structure
```
commands/    harness/ namespace (avoids collisions with other installed plugins):
             /harness:spec /harness:plan /harness:commit /harness:verify /harness:retro
             /harness:feature /harness:onboard /harness:log-metrics
agents/      researcher, test-writer, implementer, reviewer, doc-writer
             — model: per-role tier (routine work cheaper, implementer keeps primary)
skills/      code-review, testing, db-migrations, frontend      ← EDIT_ME for your stack
hooks/       guard.sh (PreToolUse, exit 2, fail-closed without jq)
             secrets-scan.sh (PostToolUse: gitleaks or grep fallback)
             fmt.sh · tests-green.sh (Stop, scoped to changed packages)
settings/    settings.project.json / settings.user.json — permissions deny-by-default + hooks
ci/          harness-evals.yml (invariant #6 as code) · agent-review.yml
             plan-verify.yml (custom plan coherence checks) · hooks-test.yml (regression detection)
templates/   CLAUDE.md, CLAUDE.local.md, surface-map, decisions, metrics,
             dispatch-matrix, spec, plan, eval-trace
harness/     installed at the project's harness/ (not root — avoids colliding with the
             project's own docker/ folder for its actual product, if it has one):
  evals/       run.sh — Docker-only orchestrator; output eval (checks) + trajectory eval
               (turns/tools) + cost from the JSON transcript · traces/
  docker/      Dockerfile (harness-runner image) · claude-run.sh · exec.sh (container boundary)
scenarios/   greenfield · onboarding · existing-own — checklist overlays
docs/        full step-by-step guides the kit was distilled from
examples/    craftplan-spec.md, plan.md, retro.md — complete spec→plan→retro cycle (learning reference)
extras/      harness-dashboard.jsx — interactive progress tracker (Claude artifact)
tests/       hooks.test.sh — guard.sh regression tests · runner-smoke.sh — eval runner self-test
build/       dashboard.sh — generates artifact-ready version for offline use
install.sh   → project .claude/ + harness/ (with settings and CI) or ~/.claude (--user)
VERSION      Kit version for update detection
```

## Security model (three layers)
0. **container boundary** — the agent's own headless run always happens in the harness-runner
   sandbox (non-root user, dropped capabilities, resource limits, throwaway mounts). Checks
   (human-approved via `/harness:retro`, not agent-authored) do too by default; `HARNESS_EVAL_CHECKS_HOST=1`
   (set for GitHub Actions in `ci/harness-evals.yml`) runs them directly on an already-isolated
   CI runner instead — see `harness/evals/run.sh`.
1. **permissions in settings.json — deny-by-default.** Only the allow-list is permitted.
   Primary layer for interactive sessions on the host: can't be bypassed by rephrasing.
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
1. perceive → spec → plan → implement → verify (/harness:verify is a command, not a mood).
2. Safety lives in permissions+hooks, not prompts. A prompt is a wish; a gate is a guarantee.
3. A subagent returns a condensed result; small tasks skip subagents (/harness:feature declines them itself).
4. Metrics from day one: /cost → the log. Deliberately manual — numbers without your judgment are dead.
5. /harness:retro after every merge: divergences → templates, conventions → CLAUDE.md, criteria → a trace.
6. A change to .claude/** or CLAUDE.md doesn't merge without green evals — now a CI gate, not a wish.

## How the scenarios differ
| | greenfield | onboarding | existing-own |
|---|---|---|---|
| CLAUDE.md is written from | decisions (decisions.md) | verified facts (CLAUDE.local) | perception-gap audit |
| Gates | commit #1 | user-level immediately; in repo — after the trust gate | quality-gates stage |
| Install level | .claude/ in repo | ~/.claude | .claude/ in repo |
| Evals | grow via /harness:retro | after legitimization | 20 traces from done tasks |

## Where this sits on the vibe coding ↔ agentic engineering spectrum
The differentiator between the two isn't whether an agent is used — it's how the
output gets verified. Casual prompting with "does it seem to work" is one end;
formal specs + automated evals + CI gates is the other. This kit is built for the
disciplined end, but not every task on a project needs to sit there:
- **Prototypes, throwaway scripts, exploring an unfamiliar API** — vibe coding is the
  right speed. Don't route these through /harness:spec → /harness:plan → evals; that's friction
  without payoff for code nobody will run twice.
- **Anything merging into a shared branch** — the kit's gates apply: spec before
  code (invariant #1), hooks over prompts for safety (invariant #2), green evals
  before `.claude/**` or `CLAUDE.md` changes ship (invariant #6).
Keep that boundary explicit per task, not implicit per developer — a team that
blurs it ships prototypes to production by accident.

## Evals: what gets verified
`harness/evals/run.sh` checks two different things per trace, because a fluent diff that
skipped its own verification is a worse failure than one that errored visibly:
- **Output eval** — the `cmd:` checks in a trace file, run against the agent's
  final diff (does it compile, does the expected line exist, is scope respected).
- **Trajectory eval** — read from the agent's own JSON transcript, which the run
  already paid for: turn count, tool-call histogram, cost, duration. A trace that
  passes every `cmd:` check after 50 turns of thrashing is a quality signal the
  output check alone can't see — `EVAL_MAX_TURNS` (default 30) fails it.
Per-trace trajectory/cost and PASS/FAIL stream to the console as each trace runs
(`tee`d to the results file too) — nothing about a run is only visible after the
fact by opening `harness/evals/results/*.md`; that file exists for the durable record
and CI logs, not as the only place to see what happened.

## Changelog
Version history moved to [CHANGELOG.md](CHANGELOG.md).

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
