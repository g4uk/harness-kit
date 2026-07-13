# Onboarding onto a new project — step-by-step guide (harness approach)

Scenario: you're a senior engineer joining someone else's project (new job / new client).
Neither you nor Claude knows the codebase. Goal for the first stages: (1) become productive
faster than the team expects, (2) build yourself a harness without breaking team habits,
(3) have something to offer the team by the trust gate.

The key difference from your own project: **you are a guest.** So everything splits into
two levels:
- **Personal** (ask nobody): `~/.claude/settings.json`, `CLAUDE.local.md`, local skills —
  applies only to you.
- **Team-level** (only after trust and agreement): commits into the repo's `.claude/`,
  CI agents, hooks for everyone.

Until the trust gate, you work ONLY at the personal level. Stages advance on exit
criteria, not the calendar.

---

## STAGE 0 (before the first task): access + launch

**0.1.** The classics without which nothing else matters: access (repo, CI, tracker,
staging, logs/APM), clone, local run, test suite. If the project doesn't start by
following the README — that's your first finding; write it down.

**0.2.** Start a personal onboarding journal outside the repo:

```bash
mkdir -p ~/onboarding/<project>
touch ~/onboarding/<project>/journal.md   # findings, questions, WTF moments
touch ~/onboarding/<project>/metrics.md   # the usual table: task/tokens/$/first-pass
```

WTF moments are the most valuable: in a month you'll stop noticing them, and right now
they're a ready-made list for CLAUDE.md and for questions to the team.

**0.3.** Install personal guard hooks BEFORE your first session in this repo — in
`~/.claude/settings.json` (user level, applies everywhere, never enters the project's git).
The kit does this for you: `./install.sh --user` (guard.sh + secrets-scan.sh +
a permissions deny-list). Add one denial specific to being new:

```bash
echo "$CMD" | grep -qE '(prod|production|live)' && deny "prod-context commands — by hand only, I'm new here"
```

On someone else's project the cost of an agent mistake is higher, and your sense of "what's
dangerous" is lower. The gate goes in before the first risk, not after.

**0.4.** Check whether the repo already has `.claude/`, `CLAUDE.md`, `.mcp.json`,
`.cursorrules`, etc. If yes — read them fully: these are team agreements about AI tools;
don't break them. If there's an `.mcp.json` — see which servers will connect and do a quick
token audit (`/context`): other people's configs can be greedy.

**Exit:** the project runs locally; your personal gates block a test command (exit=2).

---

## STAGE 1: recon (the two-way perception gap)

Here the perception-gap audit works in reverse: you're not checking Claude against your
knowledge — you **use Claude as the researcher and humans as the verifiers.**

**1.1.** Recon session #1 — the high-altitude map. Prompt:

```
Explore this repository and report:
1. What the system is, who the users are (from code/docs — do not invent)
2. Architecture: entry points, layers, how a request flows
3. Stack and versions, especially unusual/old dependencies
4. How tests run, how many there are, what they roughly cover
5. Top 10 largest / most-changed files (git log --stat helps)
6. What looks like legacy or "here be dragons"
Format: a condensed report. Where unsure — write "ASSUMPTION".
```

Every "ASSUMPTION" in the report → journal.md as a question for humans.

**1.2.** Recon session #2 — the money/data flows. Ask it to trace 2-3 critical flows
end-to-end ("from the order-creation HTTP request to the DB write and side effects").
That's the fastest way to find the real business logic instead of the directory layout.

**1.3.** Human verification. Come to the 1:1 with your lead/mentor not with "tell me about
the project" but with specifics:

```
I've worked out: [3 sentences]. Check me in three places:
1. Am I right that X works like this?
2. Module Y looks frozen — is it really untouched?
3. Tests in Z don't cover W — known debt, or did I miss something?
```

A senior who asks questions like that on day two gets remembered. Answers → journal.md.

**1.4.** Build `surface-map.md` — for now in `~/onboarding/<project>/`, NOT in the repo.
Same format: entry points / critical modules / standard / codegen / external services /
dragons. It's your study notes and the seed of a future team artifact at once.

**Exit:** you can explain the critical flows to a teammate and get corrected on nothing major.

---

## STAGE 2: personal CLAUDE.md + first task

**2.1.** Create `CLAUDE.local.md` in the repo root (Claude Code reads it; git must ignore
it — check .gitignore; if it's not there, exclude it locally via `.git/info/exclude`):

```markdown
# <Project> — my local notes (do not commit)

## Commands (verified by me)
- tests: ...       # the exact incantations that worked, with all env vars
- local run: ...
- lint: ...

## How things are done here (per the team, dated!)
- 2026-07-06, team lead: migrations only via X, never Y
- 2026-07-07, code review: the Z pattern is disliked here

## Dragons
- module A untouchable (team B is rewriting it)

## My WTFs (verify later)
- why is the config duplicated in C and D?
```

Rule: only **verified** facts enter CLAUDE.local.md (a command that ran, or a human who
confirmed). Unverified things live in journal.md. Otherwise you encode your own early
mistakes into the harness.

**2.2.** Take the first task — deliberately small (good-first-issue, a minor bug). The goal
isn't to impress; it's to **exercise the full cycle**: branch → change → tests → PR →
review → merge → deploy. That cycle is where all the unwritten rules surface.

**2.3.** Run it spec-lite even if it's an hour of work: have Claude draft a 5-line plan →
you or the agent implements → tests → PR. The point is to calibrate how far the agent can
be trusted in THIS repo (in legacy with weak tests, the first-pass rate will be sharply
lower than what you're used to — measure it, record it in metrics.md).

**2.4.** The first review of your PR is gold. Every reviewer remark → a line in
CLAUDE.local.md under "How things are done here". After 3-4 PRs you'll hold the team's
de-facto style guide — the one that isn't in their docs.

**Exit:** at least one PR merged and deployed; every review remark captured.

---

## STAGE 3: skills + subagents for this project

**3.1.** Once 3+ recurring procedures have accumulated — extract them into personal skills
(`~/.claude/skills/<project>-*/`, user level, not in the repo):

- `<project>-testing` — how tests are really written here (from your first PRs and reviews)
- `<project>-review` — a pre-PR self-check list = the remarks you've already collected
- `<project>-domain` — a domain glossary: what the terms in the code mean (every project
  has its own "Item/Part/Position", and term confusion is half of agent errors)

Each skill's description gets concrete trigger words from this project.

**3.2.** Two onboarding subagents:

- `researcher` — same as in the kit: read-only, report ≤400 words. On a new project this
  is your main tool — every new task starts with it, because YOUR knowledge of the code
  doesn't yet cover dispatch.
- `pr-preflight` — a reviewer trained on the remarks from your first reviews: run it before
  every PR so human review isn't spent on the already-known.

**3.3.** The team-trust economy rule: **no PR goes to human review until it has passed
pr-preflight.** Your reputation in the early period = the quality of your first 10 PRs.
An agent that catches your own mistakes before the reviewer does converts straight into it.

**3.4.** Keep the metrics going: by the end of this stage you should be able to answer
"on which task types in this repo can the agent be delegated, and where is it hands-only" —
that's your personal dispatch matrix. In legacy zones it will look nothing like it does in
fresh code.

**Exit:** preflight catches issues before human review does; the dispatch matrix is backed
by metrics.md entries, not vibes.

---

## STAGE 4: depth + the first process contribution

**4.1.** Time for depth in the critical modules (from the surface map). Technique: take a
researcher report → read the key files yourself → write a "how this works" explanation in
your own words into journal.md → ask Claude to find errors in YOUR explanation. A
divergence = either your gap or a discovered bug.

**4.2.** Take normal-sized tasks now and run them through the full spec flow (spec.md +
plan.md locally; committing them is optional). Bonus: when standup asks for status, you
have a plan with steps instead of "still digging".

**4.3.** The first process contribution to the team — pick the CHEAPEST one for them:
- a fixed README/onboarding doc ("how to boot the project in an hour, not a day" — you have
  fresh eyes; do it now or never), or
- surface-map.md as a PR into docs/ — useful to everyone, imposes nothing.

Do NOT propose hooks/CI agents/review-process changes yet. Too early.

**4.4.** If someone on the team already uses Claude Code / another agent — find that person.
They're your channel for legitimizing the harness: proposing a team CLAUDE.md as a pair is
far easier.

**Exit:** the docs PR is merged — your first process contribution cost the team nothing.

---

## STAGE 5: legitimizing the harness (the trust gate)

The trigger is evidence, not a date: several merged PRs, a verified CLAUDE.local.md,
metrics, and a reputation. Now convert personal into team-level — **through a proposal,
not a fait accompli.**

**5.1.** Prepare a team `CLAUDE.md` as a PR: a distillation of your CLAUDE.local.md minus
the personal bits, facts and commands only, ≤150 lines. In the PR description — numbers
from your metrics.md ("with this file the agent answers N/10 project questions correctly
vs M/10 without" — yes, run the classic before/after perception-gap audit from the playbook).

**5.2.** If the PR lands — next iterations (one PR at a time, never everything at once):
skills → `.claude/settings.json` with the fmt hook (the safest; blocks nobody) → the guard
hook → then per the staged rollout plan from the playbook.

**5.3.** If the team is skeptical about AI tooling — stop at the team CLAUDE.md/docs level
and keep working at the personal level. Your harness works for you regardless of their
buy-in; pushing it would destroy more than it gains.

---

## Checklist

- [ ] S0: project runs locally, tests pass, guard hook installed, journal+metrics started
- [ ] S1: two researcher reports · ASSUMPTIONS verified by humans · surface map (personal)
- [ ] S2: CLAUDE.local.md · first PR through the full cycle · review remarks → CLAUDE.local.md
- [ ] S3: 3 personal skills · researcher + pr-preflight agents · no PR without preflight · first dispatch matrix
- [ ] S4: critical modules understood (explained in your own words) · README/surface-map PR merged · tasks run spec-flow
- [ ] S5: team CLAUDE.md as a PR with numbers · decision on further rollout or personal mode

## The three rules that hold it together

1. **Verified → CLAUDE.local.md; unverified → journal.md.** A harness is built only from
   verified facts.
2. **Personal immediately, team-level after trust.** Guard hooks on day zero; team hooks
   only past the trust gate.
3. **Metrics from day one.** Sooner or later the question won't be "does the harness help"
   but "show me the numbers" — and you'll have them.
