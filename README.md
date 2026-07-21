# harness-kit v1.6

A shared harness core for three Claude Code working scenarios.
Progression is gated by evidence (exit criteria per stage), not by a calendar.

## Requirements
- **docker** (mandatory for eval runs). Policy: every project-touching execution (agent + checks) runs in the harness-runner sandbox.
- **bash** + **jq** (for guard.sh and local orchestration).
  - macOS: `brew install jq docker`
  - Linux: `apt install jq` + install Docker from docker.io
  - Windows: Not supported. Run via WSL with Docker.
- **git** (obviously)
- **gitleaks** (recommended for secrets-scan accuracy; falls back to grep)

## Structure
```
commands/    /spec /plan /commit /verify /retro /feature /onboard /log-metrics
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
evals/       run.sh — Docker-only orchestrator; output eval (checks) + trajectory eval
             (turns/tools) + cost from the JSON transcript · traces/001-example.md
scenarios/   greenfield · onboarding · existing-own — checklist overlays
docs/        full step-by-step guides the kit was distilled from
examples/    craftplan-spec.md, plan.md, retro.md — complete spec→plan→retro cycle (learning reference)
extras/      harness-dashboard.jsx — interactive progress tracker (Claude artifact)
tests/       hooks.test.sh — guard.sh regression tests · runner-smoke.sh — eval runner self-test
build/       dashboard.sh — generates artifact-ready version for offline use
docker/      Dockerfile (harness-runner image) · claude-run.sh · exec.sh (container boundary)
install.sh   → project .claude/ (with settings and CI) or ~/.claude (--user)
VERSION      Kit version for update detection
```

## Security model (three layers)
0. **container boundary** — all headless runs (agent + checks) happen in harness-runner sandbox.
   Non-root user, dropped capabilities, resource limits, throwaway mounts.
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

## Where this sits on the vibe coding ↔ agentic engineering spectrum
The differentiator between the two isn't whether an agent is used — it's how the
output gets verified. Casual prompting with "does it seem to work" is one end;
formal specs + automated evals + CI gates is the other. This kit is built for the
disciplined end, but not every task on a project needs to sit there:
- **Prototypes, throwaway scripts, exploring an unfamiliar API** — vibe coding is the
  right speed. Don't route these through /spec → /plan → evals; that's friction
  without payoff for code nobody will run twice.
- **Anything merging into a shared branch** — the kit's gates apply: spec before
  code (invariant #1), hooks over prompts for safety (invariant #2), green evals
  before `.claude/**` or `CLAUDE.md` changes ship (invariant #6).
Keep that boundary explicit per task, not implicit per developer — a team that
blurs it ships prototypes to production by accident.

## Evals: what gets verified
`evals/run.sh` checks two different things per trace, because a fluent diff that
skipped its own verification is a worse failure than one that errored visibly:
- **Output eval** — the `cmd:` checks in a trace file, run against the agent's
  final diff (does it compile, does the expected line exist, is scope respected).
- **Trajectory eval** — read from the agent's own JSON transcript, which the run
  already paid for: turn count, tool-call histogram, cost, duration. A trace that
  passes every `cmd:` check after 50 turns of thrashing is a quality signal the
  output check alone can't see — `EVAL_MAX_TURNS` (default 30) fails it.
Per-trace trajectory/cost and PASS/FAIL stream to the console as each trace runs
(`tee`d to the results file too) — nothing about a run is only visible after the
fact by opening `evals/results/*.md`; that file exists for the durable record
and CI logs, not as the only place to see what happened.

## Changelog v1.6 (/log-metrics)
- **`/log-metrics`**: new command — appends a row to `docs/metrics.md` per
  Invariant #4, but only asks for what actually needs human judgment
  (First-pass?, Human min, Note). Tokens/$/duration come from `/cost` or
  `/usage` output already in the conversation (or asks you to run it once);
  LOC diff is computed via `git diff --shortstat`, no manual math.

## Changelog v1.5.2 (install.sh: clarify ANTHROPIC_API_KEY must be a repo secret)
- **FIX**: `install.sh`'s next-steps hint just said "add secrets.ANTHROPIC_API_KEY"
  — an Environment secret (or an org secret not shared with the repo) satisfies
  that instruction but is invisible to `harness-evals`/`agent-review`, since
  neither workflow declares `environment:`. The container then reports
  `apiKeySource:none` with no error, only visible via the raw-output diagnostic
  from v1.5.1. Hint now says REPOSITORY secret explicitly and why.
- **evals/run.sh**: surfaces the raw agent output when trajectory parsing
  fails, so a silent auth/config failure is diagnosable from the CI log
  instead of just `turns=? cost=?`.

## Changelog v1.5.1 (CRITICAL: install.sh never shipped docker/)
- **FIX**: `install.sh` copies `ci/harness-evals.yml` into every installed
  project, and that workflow runs `docker build -t harness-runner:latest
  docker/` — but `install.sh` never copied the `docker/` directory itself.
  Every fresh install's first push broke CI with `path "docker/" not found`.
  Now `docker/{Dockerfile,claude-run.sh,exec.sh}` is copied on both fresh
  install and `--update` (executable bits preserved on the two scripts).

## Changelog v1.5 (/onboard wizard)
- **`/onboard`**: new command — interactive Stage 0 wizard that generates
  `docs/decisions.md`, `CLAUDE.md`, `docs/metrics.md` through a Claude Code
  conversation (multi-select which files, open-ended questions, no
  prescribed tech choices) instead of hand-copying templates.
- Self-contained: falls back to an inline structure when
  `templates/*.template` isn't present in the target repo (`install.sh`
  never copies `templates/` there — only `skills/agents/commands/hooks`).
- Skips the overwrite prompt when an existing file is still raw/unfilled
  (unresolved `{{...}}` placeholders, or an empty metrics table); only asks
  before overwriting real, filled-in content.
- `scenarios/greenfield.md` Stage 0 now points at `/onboard` as the fast path.

## Changelog v1.4 (trajectory eval + model routing)
- **FIX**: `evals/run.sh` — `git grep`-based checks were failing on correct agent
  output because the agent doesn't commit; now `git add -A` after the run so
  git-aware checks see untracked new files.
- **Trajectory eval**: `docker/claude-run.sh` switched to `--output-format
  stream-json --verbose` so the agent's tool-call trajectory is captured, not
  just the final result. `evals/run.sh` reads it: per-trace turns/tools/cost/
  duration streamed to the console (and `tee`d to the results file) as each
  trace runs, `EVAL_MAX_TURNS` (default 30) as a thrashing gate, total run
  cost in the summary line.
- **agents/*.md**: explicit `model:` per role — routine/checklist-shaped work
  (test-writer, reviewer, doc-writer, researcher) routed to a cheaper/faster tier;
  implementer keeps the primary model for multi-step reasoning. EDIT_ME: tune per
  project budget and stack.
- **README**: new "vibe coding ↔ agentic engineering" section — makes explicit
  which work should skip the harness (prototypes) vs. which must go through it
  (anything merging to a shared branch).

## Changelog v1.3 (Docker-only project policy)
- **Docker container boundary**: all headless runs (agent + checks/tests) execute in harness-runner image — no exceptions.
- **evals/run.sh**: rewritten as Docker orchestrator only; fail-fast without docker (escape hatch HARNESS_ALLOW_HOST=1 for debug).
- **Clone instead of worktree**: worktree .git file has absolute host path, breaks on container mount; local clone is self-contained & fast.
- **tests/runner-smoke.sh**: eval runner's own smoke test (Go fixture + trivial trace; PASS proves sandbox + real diff + check execution).
- **ci/harness-evals.yml**: builds harness-runner image; EVAL_LIMIT via github.event_name (3 traces on PR, all on main).
- **BSD-portable sed**: no grep -oP (macOS incompatible); using sed -n with portable patterns.
- **docker/**:  Dockerfile (node20 + claude-code + Go + non-root) · claude-run.sh (5min timeout + caps-drop + resource limits) · exec.sh (checks/tests).
- **Known boundary** (documented): network egress not restricted (needs api.anthropic.com); interactive sessions stay on host.

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
