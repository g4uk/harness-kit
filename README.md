# harness-kit v1.9

A shared harness core for three Claude Code working scenarios.
Progression is gated by evidence (exit criteria per stage), not by a calendar.

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

## Changelog v1.9 (BREAKING: docker/ and evals/ move under harness/)
- **`docker/` and `evals/` (in installed projects) move to `harness/docker/`
  and `harness/evals/`** — a project's own product can reasonably have its
  own `docker/` folder (compose services, its own Dockerfile) that has
  nothing to do with the kit's sandbox image; the two were sitting at the
  same root-level path with no relation, which is exactly the kind of
  confusion that prompted the `commands/harness/` namespace in v1.8. `docs/`
  and `specs/` stay at the root — they're project content (decisions,
  metrics, feature specs), not kit tooling, even though `/harness:onboard`
  and `/harness:spec` generate them.
- `install.sh --update` migrates existing installs: detects the old
  `docker/`/`evals/` by their kit-specific files (`docker/claude-run.sh` +
  `docker/exec.sh`; `evals/run.sh`) and **moves** them (never deletes blind —
  `evals/traces/*.md` and `evals/results/*.md` are real project history, not
  kit boilerplate). Verified: a fixture with real trace/result content
  migrates with that content intact; a fresh install produces
  `harness/{docker,evals}/` directly; `docker build` and the full
  `tests/runner-smoke.sh` pipeline both work from the new paths.
- `ci/harness-evals.yml`'s path filters, build step, and run step updated to
  `harness/docker/**` / `harness/evals/**`. Every doc, example, and the
  kit's own `harness/evals/run.sh` / `harness/docker/*.sh` self-references
  updated to match — `PATCH.md` (historical, describes v1.3) intentionally
  left as-is.

## Changelog v1.8 (BREAKING: commands namespaced under harness:)
- **All 8 kit commands moved from `.claude/commands/*.md` to
  `.claude/commands/harness/*.md`** — Claude Code namespaces commands by
  subdirectory with colon syntax, so `/spec` is now `/harness:spec`, and
  likewise `/harness:plan`, `/harness:commit`, `/harness:verify`,
  `/harness:retro`, `/harness:feature`, `/harness:onboard`,
  `/harness:log-metrics`. Reason: bare names like `/plan` or `/verify`
  collide with (or are ambiguous against) commands from other installed
  plugins/marketplaces — no way to tell which one just ran.
- **No bare-name alias** — Claude Code doesn't support one; this is a
  breaking change for anyone with muscle memory for the old names.
- `install.sh --update` migrates existing installs automatically: copies the
  new namespaced files into `commands/harness/` and deletes the old flat
  files at `commands/*.md` if present, so nothing lingers as a dead
  duplicate. Verified both a fresh install and an update-from-old-flat-layout
  install produce the same clean `commands/harness/*.md` result.
- All cross-references between commands (`feature.md`'s own pipeline steps),
  and every doc that told you to type one of these (`README.md`,
  `scenarios/*.md`, `docs/*.md`, `CONTRIBUTING.md`, `extras/harness-dashboard.jsx`)
  updated to the namespaced form. Historical `## Changelog` entries below
  this one are left as-is — they're a record of what was true when written.

## Changelog v1.7.3 (/log-metrics: read tokens from the session transcript, don't ask)
- **FIX**: step 1 asked the user to manually run `/cost`/`/usage` and paste
  the output — friction the command was supposed to remove in the first
  place (v1.6's whole point). Found that Claude Code exposes
  `$CLAUDE_CODE_SESSION_ID`, which pinpoints the current session's own
  transcript at `~/.claude/projects/*/$CLAUDE_CODE_SESSION_ID.jsonl` —
  every `assistant` message there carries real per-message token usage
  (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`,
  `cache_read_input_tokens`). `/log-metrics` now finds that file via `find`
  (sidesteps needing to know the project-path escaping scheme) and sums
  tokens directly — no copy-paste. Falls back to the old ask-the-user path
  only if the session ID/file isn't available.

## Changelog v1.7.2 (self-adjusting trace-count gate, not a manual uncomment)
- **Reworked v1.7.1's fix** after feedback that "uncomment the triggers later"
  is exactly the kind of manual step this whole session kept tripping over.
  `pull_request`/`push` triggers are back on, always — `evals/run.sh` now
  reads `EVAL_MIN_TRACES` itself and exits instantly (before docker, before
  touching the API key) when `evals/traces/` has fewer traces than that.
  `ci/harness-evals.yml` sets it to 6 for `push`/`pull_request` (Stage 3's
  own baseline threshold) but 0 for `workflow_dispatch` — a human explicitly
  requesting a run always gets a real one, count aside.
- Net effect: **nothing to edit, ever.** Early on it silently no-ops on
  every `/retro` commit at ~0 cost; once traces cross the threshold, real
  runs simply start happening. `scenarios/greenfield.md` and
  `docs/greenfield-harness.md` updated to describe this instead of the
  now-superseded "uncomment at Stage 3" instruction from v1.7.1.

## Changelog v1.7.1 (ci/harness-evals.yml: workflow_dispatch-only by default)
- **`harness-evals` no longer auto-triggers.** It costs a real API call per
  trace, and with fewer than the ~6 traces Stage 3 calls a real baseline, it
  was firing on every `/retro` commit (which always touches `CLAUDE.md` +
  `evals/traces/`) for little regression-catching value yet. Ships with
  `pull_request`/`push` triggers commented out, `workflow_dispatch` only —
  run it manually (`gh workflow run harness-evals`) until you have a real
  baseline, then uncomment. `scenarios/greenfield.md` and
  `docs/greenfield-harness.md` updated at both Stage 1 (why it's quiet by
  default) and Stage 3 (when/how to turn the triggers back on).

## Changelog v1.7 (evals: opt-in un-sandboxed checks via HARNESS_EVAL_CHECKS_HOST)
- **Resolves the docker-in-sandbox limitation** (open since v1.6.2/v1.6.3):
  `docker compose`-based `cmd:` checks could never pass, because
  `harness-runner` deliberately ships no docker CLI/socket. Root-cause
  decision: don't loosen the agent's sandbox (no socket mount, no DinD) —
  split trust instead. The agent's own run stays fully sandboxed everywhere,
  unconditionally. Checks (base check + trace `cmd:`) are human-approved
  commands via `/retro`'s "show me, don't commit yourself" gate, not
  agent-authored code — a different trust level.
- `evals/run.sh` gained a `run_check()` dispatcher and a new
  `HARNESS_EVAL_CHECKS_HOST=1` env var: unset (default), checks run in
  `harness-runner` same as the agent; set, they run directly on the host.
  The script itself has **no CI-vendor opinion** — it just reads the flag.
  `ci/harness-evals.yml` sets it for GitHub Actions specifically (already a
  fresh, single-job, isolated VM with a native Docker daemon, so
  `docker compose` actually works there); any other CI with the same
  property can opt in the same way. `docker/exec.sh` is unchanged — still
  the default path. Verified the routing directly: a
  `cmd: command -v docker` check fails under normal invocation (no docker in
  the sandbox) and passes under `HARNESS_EVAL_CHECKS_HOST=1` (runs on host).
- Docs updated to stop claiming checks are unconditionally sandboxed
  (README's Requirements + Security model, `ci/harness-evals.yml` header).

## Changelog v1.6.7 (retro.md: prevent malformed/stateful cmd: checks)
- **FIX**: `/retro` generated a trace (`003-user-auth.md` on kumite-analyzer)
  with two real bugs — a human-readable note baked directly into a `cmd:`
  value (`go test ./... -count=1 (set TEST_DSN to...)`, a guaranteed bash
  syntax error) and three checks assuming state shared across separate
  `cmd:` lines (`docker compose up` in one, bare `curl` against it in the
  next) — but each `cmd:` runs in its own throwaway container
  (`docker/exec.sh`), so nothing persists between them.
- `commands/retro.md` and `templates/eval-trace.md.template` now say this
  explicitly: chain multi-step verification in ONE `cmd:` with `&&`, and
  never put a note inline in the command — use a `(manual)` line instead.

## Changelog v1.6.6 (evals/run.sh: surface is_error even on a parseable result)
- **FIX**: the v1.5.1 raw-output diagnostic only fires when `num_turns` is
  unparseable (a fully-broken JSON transcript). A result CAN be perfectly
  parseable and still be an error — e.g. an auth failure returns
  `{"is_error":true,"num_turns":1,"result":"Not logged in · Please run
  /login"}`. That looked identical downstream to a legitimate empty diff
  (merged feature, nothing left to do): `NOTE: no diff` + failed checks on
  missing code, with zero indication the agent never actually ran. Caught
  running this repo's own `tests/runner-smoke.sh` locally without
  `ANTHROPIC_API_KEY` set. Now `is_error:true` prints an explicit
  `AGENT ERROR` line with the result text, regardless of whether `num_turns`
  parsed.

## Changelog v1.6.5 (ci/agent-review.yml: missing id-token permission)
- **FIX**: `anthropics/claude-code-action@v1` requests an OIDC token as part
  of its own auth setup, but the job's `permissions` block only granted
  `contents: read, pull-requests: write` — no `id-token: write`. Every PR
  failed after 3 retries: "Could not fetch an OIDC token. Did you remember
  to add `id-token: write` to your workflow permissions?" (the action's own
  error names the fix). Added `id-token: write` to the job permissions.

## Changelog v1.6.4 (ci/harness-evals.yml: push trigger missing paths filter)
- **FIX**: the `push: branches: [main]` trigger had no `paths:` filter, unlike
  its own `pull_request` trigger (and unlike `hooks-test.yml`, which had it
  right). Invariant #6 is "a change to `.claude/**`/`CLAUDE.md` doesn't merge
  without green evals" — but with no path filter, `harness-evals` ran (and
  could fail) on *every* push to main, including pure product-code commits
  that never touch `.claude/**`/`CLAUDE.md`/`evals/**`/`docker/**`. Now the
  `push` trigger has the same `paths:` list as `pull_request`.

## Changelog v1.6.3 (install.sh: stop shipping the CraftPlan example trace)
- **FIX**: `install.sh` no longer copies `evals/traces/001-example.md` into
  new projects. It's a format reference for the fictional CraftPlan project
  (Go, `internal/api`, `company_id`) — its checks can't pass in any other
  project, so every fresh install got a guaranteed-permanent `harness-evals`
  FAIL from day one, on top of the real trace(s) added later. The file stays
  in the harness-kit repo itself as a reference (see `evals/traces/` and
  `examples/craftplan-*.md`); it's just not copied out anymore.

## Changelog v1.6.2 (CRITICAL: empty-run was a permanent fail for merged traces)
- **FIX**: `evals/run.sh` cloned the current tip of `$BASE_BRANCH` for every
  trace, always — so once a trace's feature was merged, replaying its own
  "implement X" prompt against a repo that already has X produces no diff,
  by design. The old `! git diff --quiet` gate treated that as a hard
  `FAIL: empty run`, meaning **every accumulated trace became permanently
  unpassable the moment it merged** — Stage 3's "eval baseline" was
  unreachable by construction. Caught live on kumite-analyzer's first
  multi-trace run (0/2, both flagged empty-run, one of them its own
  already-shipped walking-skeleton).
- No-diff is now logged as `NOTE`, not `FAIL` — pass/fail is decided purely
  by whether the base check and the trace's own `cmd:` checks pass, which is
  what actually indicates whether the codebase satisfies the trace.
- **Known follow-up (not fixed here):** `harness-runner` has no `docker`/
  `docker compose` CLI and no socket access, so `cmd:` checks that spin up a
  real Docker Compose stack (e.g. a project's own integration checks) cannot
  execute inside the sandbox regardless of this fix. Deferred — fixing it
  means loosening the sandbox (socket mount or DinD), a bigger call than a
  logic fix.

## Changelog v1.6.1 (greenfield docs: lessons from a real first run)
- **`scenarios/greenfield.md` + `docs/greenfield-harness.md`**: four gotchas
  documented after running a real greenfield project (kumite-analyzer)
  end-to-end through Stage 0/1/2 for the first time —
  1. guard.sh smoke test must be run by asking Claude, not by typing the
     forbidden command yourself in a terminal (hooks only see agent tool
     calls).
  2. `ANTHROPIC_API_KEY` must be a **repository** secret — an Environment or
     unshared org secret silently yields `apiKeySource:none`, no error.
  3. The shipped `evals/traces/001-example.md` is CraftPlan-specific and
     fails on every other project's first `harness-evals` run — expected,
     not broken, until `/retro` adds a real trace.
  4. `/clear` only resets the `/cost` counter on Claude Code CLI v2.1.211+;
     older versions accumulate cost across `/clear`, so per-feature $ in
     metrics.md is unreliable without checking `claude --version` first.

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
