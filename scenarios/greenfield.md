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

## Stage 1 — Walking skeleton
- [ ] Feature #0 = the thinnest end-to-end slice, deployed. Via /spec → /plan → implement → /verify
- [ ] CI (test+lint) + plan-verifier from PR #1

**Exit:** a request hits production and comes back; CI is green; trace #0 exists in evals/.

## Stage 2 — Vertical slices
- [ ] Features shipped as vertical slices only; /retro after EVERY merge
- [ ] Skills filled from retro repeats, not upfront
- [ ] metrics.md tracks $/feature and LOC diff

**Exit:** 3-5 features merged through the full cycle; at least one skill and one template
improvement produced by /retro; cost per feature is known, not guessed.

## Stage 3 — Agents & evals
- [ ] Subagents — trigger: researcher becomes useful (roughly 15-20 logic files)
- [ ] evals/run.sh first baseline — trigger: ~6 accumulated traces
- [ ] MCP — trigger: the first external state; token audit (/context) right away

**Exit:** dispatch matrix reflects measured (not assumed) agent trustworthiness;
eval baseline recorded.

## Stage 4 — Scale
- [ ] fan-out — trigger: the first mechanical migration
- [ ] plugin — trigger: a second person or a second repo
- [ ] recurring digest from an agent

## Rules
1. Harness is commit #1. 2. Every merge feeds the harness (/retro). 3. YAGNI stricter than without agents.
