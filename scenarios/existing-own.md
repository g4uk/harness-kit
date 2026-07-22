# Scenario: your own existing project (or working through a training program)

The code exists; the harness catches up. Stage order = payoff order.
Stages advance on **exit criteria**, not the calendar.

## Stage 1 — Perception gap
- [ ] Audit: 10 questions in a clean session WITHOUT CLAUDE.md → correct/partial/wrong/hallucinated table
- [ ] docs/surface-map.md
- [ ] CLAUDE.md written AGAINST the specific audit failures (not "about the project"); re-audit
- [ ] install.sh of the kit → .claude/; fill skills with your conventions (EDIT_ME spots)
- [ ] Skill triggering test: 10 queries

**Exit:** re-audit ≥8/10; triggering 10/10.

## Stage 2 — Topology & MCP
- [ ] 5 agents + dispatch matrix; one task ×3 topologies (monolith/hub-spoke/mesh) → topology report
- [ ] MCP: token audit (/context), disable the greedy ones; custom server if you have a live
      reference dataset; hybrid Skill+MCP

**Exit:** topology choice per task type is backed by your own numbers; MCP context cost is known.

## Stage 3 — Quality gates
- [ ] One feature through the full /harness:spec→/harness:plan→implement→/harness:verify cycle + cost.md + /harness:retro
- [ ] hooks active and hand-tested (echo JSON | hook.sh; exit=2 on denials)
- [ ] plan-verifier in CI; ~20 traces (from tasks you've done) + baseline run.sh; mutation report
- [ ] Rule: changing CLAUDE.md/skills without an eval run = code without tests

**Exit:** deliberately breaking a convention / running a forbidden command / drifting from the
plan — and each layer catches its own; eval baseline recorded.

## Stage 4 — Scale
- [ ] fan-out ×3 via git worktree on a mechanical migration: playbook → fanout-log → cost delta
- [ ] Package as plugin; CI auto-review (comments only); staged rollout plan with before/after
      metrics and per-stage rollback criteria

**Exit:** the harness survives contact with a real migration and a real PR stream;
metrics show the before/after delta.
