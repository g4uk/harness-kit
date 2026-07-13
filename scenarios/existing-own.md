# Scenario: your own existing project (or working through the training program)

The code exists; the harness catches up. The order = the order of payoff.

## Week 1
- [ ] Perception-gap audit: 10 questions in a clean session WITHOUT CLAUDE.md → correct/partial/wrong/hallucinated table
- [ ] docs/surface-map.md
- [ ] CLAUDE.md written AGAINST the specific audit failures (not "about the project"); re-audit, target ≥8/10
- [ ] install.sh of the kit → .claude/; fill skills with your conventions (EDIT_ME spots)
- [ ] Skill triggering test: 10 queries, 10/10

## Week 2
- [ ] 5 agents + dispatch matrix; one task ×3 topologies (monolith/hub-spoke/mesh) → topology report with numbers
- [ ] MCP: token audit (/context), disable the greedy ones; custom server if you have a live reference dataset; hybrid Skill+MCP

## Week 3
- [ ] One feature through the full /spec→/plan→implement→/verify cycle + cost.md + /retro
- [ ] hooks active and hand-tested (echo JSON | hook.sh; exit=2 on denials)
- [ ] plan-verifier in CI; 20 traces (from tasks you've done) + baseline run.sh; mutation report
- [ ] Rule: changing CLAUDE.md/skills without an eval run = code without tests

## Week 4
- [ ] fan-out ×3 via git worktree on a mechanical migration: playbook → fanout-log → cost delta
- [ ] Package as plugin; CI auto-review (comments only); 30-day rollout plan with before/after metrics
