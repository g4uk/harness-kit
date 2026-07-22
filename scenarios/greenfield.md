# Scenario: greenfield (your own project from scratch)

The harness is the FIRST commit, before any product code.
Stages advance on **exit criteria**, not the calendar — move on when the evidence exists,
whether that takes a day or a month.

## Stage 0 — Foundation (before writing product code)
- [ ] install.sh of this kit → .claude/; hooks active from commit #1
- [ ] docs/decisions.md from templates/decisions.md.template — every decision = a future CLAUDE.md line
- [ ] CLAUDE.md from templates/CLAUDE.md.template — derived from decisions, including the YAGNI gate
- [ ] docs/metrics.md from the template

Run `/onboard` after install to generate the three files above interactively
(it asks which to create, then walks decisions/CLAUDE.md/metrics questions) —
or write them by hand from the templates if you prefer.

**Exit:** harness committed before any product code; gate smoke test passes (guard exit=2).
Run the smoke test by asking Claude in chat to run the forbidden command (e.g. "run
`git push --force`") — guard.sh only intercepts Bash calls the agent makes through its
own tool; it can't see you typing the same command yourself in a terminal.

## Stage 1 — Walking skeleton
- [ ] Feature #0 = the thinnest end-to-end slice, deployed. Via /spec → /plan → implement → /verify
- [ ] CI (test+lint) + plan-verifier from PR #1

**Exit:** a request hits production and comes back; CI is green; trace #0 exists in evals/.

**Gotcha on the first CI push:** `ANTHROPIC_API_KEY` must be a **repository** secret
(Settings > Secrets and variables > Actions > Repository secrets), not an Environment or
org secret — `harness-evals`/`agent-review` don't declare `environment:`, so anything
scoped there is invisible to the job and silently yields `apiKeySource:none` in the
container, no error shown. (Only matters once you actually run `harness-evals` —
see the note in Stage 3: it's `workflow_dispatch`-only by default, not on every push.)

## Stage 2 — Vertical slices
- [ ] Features shipped as vertical slices only; /retro after EVERY merge
- [ ] Skills filled from retro repeats, not upfront
- [ ] metrics.md tracks $/feature and LOC diff — `/log-metrics` fills tokens/$/duration from
      `/cost` (or `/usage`, same command) and computes LOC diff via git; `/clear` resets the
      cost counter only on Claude Code CLI v2.1.211+ (check `claude --version` — below that,
      cost accumulates across `/clear` for the process lifetime, so per-feature $ is unreliable)

**Exit:** 3-5 features merged through the full cycle; at least one skill and one template
improvement produced by /retro; cost per feature is known, not guessed.

## Stage 3 — Agents & evals
- [ ] Subagents — trigger: researcher becomes useful (roughly 15-20 logic files)
- [ ] evals/run.sh first baseline — trigger: ~6 accumulated traces
- [ ] MCP — trigger: the first external state; token audit (/context) right away

`ci/harness-evals.yml` ships with automatic triggers commented out (`workflow_dispatch`
only) — before this stage it's real API $ per trace, on every `/retro` commit, for little
regression-catching value with only a couple of traces. Run it manually
(`gh workflow run harness-evals`, or Actions tab → Run workflow) until you have a real
baseline here; then uncomment the `pull_request`/`push` triggers in the workflow file.

**Exit:** dispatch matrix reflects measured (not assumed) agent trustworthiness;
eval baseline recorded.

## Stage 4 — Scale
- [ ] fan-out — trigger: the first mechanical migration
- [ ] plugin — trigger: a second person or a second repo
- [ ] recurring digest from an agent

## Rules
1. Harness is commit #1. 2. Every merge feeds the harness (/retro). 3. YAGNI stricter than without agents.
