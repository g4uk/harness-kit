# Scenario: greenfield (your own project from scratch)

The harness is the FIRST commit, before any product code.

## Day 0
- [ ] docs/decisions.md from templates/decisions.md.template — every decision = a future CLAUDE.md line
- [ ] CLAUDE.md from templates/CLAUDE.md.template — derived from decisions, including the YAGNI gate
- [ ] install.sh of this kit → .claude/; hooks active from commit #1
- [ ] docs/metrics.md from the template

## Day 1-2
- [ ] Feature #0 = walking skeleton: the thinnest end-to-end slice, deployed. Via /spec → /plan → implement → /verify
- [ ] CI (test+lint) + plan-verifier from PR #1

## Then
- [ ] Vertical slices only; /retro after EVERY merge (feeds CLAUDE.md, templates, evals/traces)
- [ ] Skills are filled from retro repeats, not upfront
- [ ] Subagents — when researcher becomes useful (~15-20 logic files)
- [ ] evals/run.sh — first baseline after ~6 features
- [ ] MCP — at the first external state; token audit (/context) right away
- [ ] fan-out — at the first mechanical migration; plugin — at the second person/repo

## Rules
1. Harness is commit #1. 2. Every merge feeds the harness (/retro). 3. YAGNI stricter than without agents.
