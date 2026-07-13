# Scenario: onboarding (someone else's existing project)

You are a guest. Personal (user-level) — immediately; team-level (.claude/ in the repo) — after week 4 and only via PR.
This kit is NOT installed into the repo. Use the user level: ~/.claude/ (install.sh --user).

## Day 0
- [ ] Access, local run, test suite passes
- [ ] ~/onboarding/<project>/{journal.md, metrics.md}
- [ ] guard.sh → ~/.claude/hooks/ + PreToolUse in ~/.claude/settings.json (BEFORE the first session)
- [ ] If the repo already has .claude/ or CLAUDE.md — read fully, don't break it; /context to token-audit others' MCP

## Day 1-2
- [ ] 2 researcher sessions: high-level map + critical flows end-to-end. Every "ASSUMPTION" → a question for humans
- [ ] surface-map.md (personal, outside the repo)

## Day 3-5
- [ ] CLAUDE.local.md (verified facts only!)
- [ ] First PR: branch → review → merge → deploy
- [ ] Review remarks → "How things are done here"

## Week 2
- [ ] 3 personal skills from real cases
- [ ] researcher + pr-preflight; no PR without preflight
- [ ] Personal dispatch matrix: where the agent can be trusted

## Week 3
- [ ] Critical modules: explanations in your own words
- [ ] First contribution: README fix or surface-map as a docs/ PR

## Week 4
- [ ] Team CLAUDE.md as a PR with perception-gap numbers
- [ ] Then one PR at a time: skills → fmt-hook → guard-hook
