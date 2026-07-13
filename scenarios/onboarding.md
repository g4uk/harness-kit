# Scenario: onboarding (someone else's existing project)

You are a guest. Personal (user-level) — immediately; team-level (.claude/ in the repo) —
only after the trust gate, and only via PR.
This kit is NOT installed into the repo. Use the user level: ~/.claude/ (install.sh --user).
Stages advance on **exit criteria**, not the calendar.

## Stage 0 — Access & personal gates
- [ ] Access, local run, test suite passes
- [ ] ~/onboarding/<project>/{journal.md, metrics.md}
- [ ] guard.sh → ~/.claude/hooks/ + PreToolUse in ~/.claude/settings.json (BEFORE the first session)
- [ ] If the repo already has .claude/ or CLAUDE.md — read fully, don't break it; /context to token-audit others' MCP

**Exit:** the project runs locally; personal gates block a test command (exit=2).

## Stage 1 — Recon
- [ ] 2 researcher sessions: high-level map + critical flows end-to-end
- [ ] Every "ASSUMPTION" verified with humans
- [ ] surface-map.md (personal, outside the repo)

**Exit:** you can explain the system's critical flows to a teammate and be corrected on nothing major.

## Stage 2 — First cycle
- [ ] CLAUDE.local.md (verified facts only!)
- [ ] First PR: branch → review → merge → deploy
- [ ] Review remarks → "How things are done here"

**Exit:** at least one PR merged and deployed; every review remark captured.

## Stage 3 — Personal harness
- [ ] 3 personal skills from real cases
- [ ] researcher + pr-preflight; no PR without preflight
- [ ] Personal dispatch matrix: where the agent can be trusted here

**Exit:** preflight catches issues before human review does; your dispatch matrix is
backed by metrics.md entries, not vibes.

## Stage 4 — Depth
- [ ] Critical modules: explanations in your own words (then let the agent find errors in THEM)
- [ ] First contribution: README fix or surface-map as a docs/ PR

**Exit:** the docs PR is merged — your first process contribution cost the team nothing.

## Stage 5 — Legitimization (trust gate)
Trigger: several merged PRs + a reputation, not a date on the calendar.
- [ ] Team CLAUDE.md as a PR with perception-gap numbers (before/after audit)
- [ ] If accepted — one PR at a time: skills → fmt-hook → guard-hook
- [ ] If the team is skeptical — stay at the personal level; don't force it
