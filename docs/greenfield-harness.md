# A project from scratch — step-by-step guide (harness-first)

Scenario: you own the project and no code exists yet (examples again use **CraftPlan**,
the fictional reference project). Greenfield's main advantage: **the harness is built
BEFORE the code, not chasing it.** Its main danger: agents generate code faster than you
can understand it — without gates from commit #1, a month later you'll own a stranger's
codebase in your own repo.

Three inversions relative to the other scenarios:
1. CLAUDE.md is written not "against failures" (there's no perception gap to measure yet) —
   it's written **from architecture decisions**. Every decision = a CLAUDE.md line the same day.
2. Spec-driven isn't "adopted" — it's the only way of working from feature #1. The specs/
   directory = the project's documentation, for free.
3. Evals aren't written separately — **every shipped feature becomes a trace.** After 20
   features you have 20 traces without trying.

Stages advance on exit criteria, not the calendar.

---

## STAGE 0: decisions → skeleton → harness (still no product code)

### 0.1 — Write the decisions down

`docs/decisions.md` — lightweight ADR format, 3-5 lines per decision:

```markdown
# 001: Go + chi + pgx/sqlc + goose
Why: primary stack, high-load experience, code generation from SQL.
Rejected: Rails (hiring-market stack ≠ the right product choice here), Fiber (smaller ecosystem).

# 002: PostgreSQL, product params in JSONB
Why: flexible parameters for different product types without a migration per type.
Cost: params schema validation lives in code (internal/parts/params.go), not the DB.

# 003: a managed PaaS to start
Why: deploy in an hour, PostgreSQL included. Migrate to raw cloud when there's traffic.

# 004: monorepo (Go backend + React frontend in one repo)
# 005: multi-tenant from day zero — company_id on every tenant table
```

This isn't bureaucracy: decisions.md is the raw material for CLAUDE.md and the answer to
the agent's "why is it like this here" — which it will otherwise invent.

### 0.2 — Repo skeleton

```bash
mkdir craftplan && cd craftplan && git init
mkdir -p cmd/api internal db/{migrations,queries} web docs specs evals/traces .claude/{skills,agents,commands,hooks}
go mod init github.com/me/craftplan
```

### 0.3 — CLAUDE.md v0 (from decisions, not failures)

Translate decisions.md into working rules. A starting example (it will grow with every
feature):

```markdown
# CraftPlan
B2B SaaS for made-to-order manufacturers: parametric configurator → parts list (BOM),
AI render, nesting layout. Two views: sales and production.

## Stack (decisions in docs/decisions.md — read before architectural changes)
Go 1.23 · chi · pgx/v5 · sqlc · goose · PostgreSQL 16 · React+TS+Three.js

## Structure
- cmd/api — entry point, thin
- internal/<domain>/ — all logic (parts, nesting, render, tenant, ...)
- internal/db — generated sqlc code ONLY; never hand-edit
- db/queries/*.sql → sqlc generate; db/migrations → goose (up AND down)
- specs/<feature>/ — spec.md + plan.md per feature. This is the project documentation.

## Hard rules (from day zero)
- Every tenant table has company_id; every query — company_id in WHERE
- Errors: fmt.Errorf("<pkg>: <op>: %w", err)
- Handler = parsing + service call + error mapping. Logic in internal/<domain>
- A feature starts with specs/<name>/spec.md — no spec, no code

## Commands
- go test ./... · golangci-lint run · sqlc generate · goose -dir db/migrations up
```

### 0.4 — Hooks from commit #1

Install the kit: `./install.sh ~/dev/craftplan` — it places all four hooks
(fmt / guard / secrets-scan / tests-green) plus the permissions deny-list. On greenfield
this is the cheapest moment ever: zero legacy noise, zero false positives. Add one
project-specific denial:

```bash
echo "$CMD" | grep -qE 'goose.*down' && deny "goose down by hand only — no silent local data loss"
```

### 0.5 — Slash commands `/spec`, `/plan`, `/commit`, `/retro`

All shipped by the kit. `/retro` is the greenfield-critical one:

```markdown
Feature $ARGUMENTS is merged. Do:
1. Compare specs/$ARGUMENTS/spec.md with the final implementation — list divergences
2. For each: a gap in the spec template, the plan, or CLAUDE.md? Propose the fix
3. Create evals/traces/NNN-$ARGUMENTS.md: prompt = the feature in one paragraph,
   checks = 3-4 verifiable criteria from the acceptance criteria
4. If a new convention emerged — propose a CLAUDE.md line
Show me everything for approval; commit nothing yourself.
```

That's the "harness grows with the code" mechanism — one command after every merge.

First commit: `chore: project skeleton + harness (CLAUDE.md, hooks, commands)`.
**The harness is committed before the first line of product code** — that's harness-first.

**Exit:** harness committed before product code; the gate smoke test passes (guard exit=2).
Run the smoke test by asking Claude itself to run the forbidden command — guard.sh is a
PreToolUse hook, it only fires on Bash calls the agent makes through its own tool. Typing
the same command yourself in a terminal never touches it; that's not a bypass, it's just
a different layer (the kit protects agent actions, not your own hands on the keyboard).

---

## STAGE 1: walking skeleton (feature #0)

The first "feature" isn't the configurator or the render — it's an **end-to-end tracer**:
the thinnest slice of the system that crosses every layer and deploys.

### 1.1 — `/spec walking-skeleton`

Scope for CraftPlan: `POST /projects` + `GET /projects/{id}` (client_name only),
companies+projects tables with a migration, tenant middleware (company_id from a header
for now — auth is in non-scope), a health endpoint, CI (test+lint), a deploy. Acceptance:
curl against the prod URL creates and reads a project; a request with another company_id → 404.

Non-scope is the most important section in the project's life: configurator, auth,
frontend, render — all NO. The skeleton must be boring.

### 1.2 — `/plan` → implement → verify

The full playbook cycle, including the CI file (a plain test+lint workflow; add the
plan-verifier from the kit's ci/ here too — on greenfield it exists from PR #1, and no PR
ever exists without a plan).

### 1.3 — Exit criterion

Product value: zero. But: the deploy pipeline works, migrations run, the tenant pattern is
laid down, CI is green, trace #0 sits in evals/. Every later feature is "adding meat to the
skeleton", not "assembling the system".

### 1.4 — `harness-evals` doesn't run automatically yet (by design)

`ci/harness-evals.yml` ships with `pull_request`/`push` triggers commented out —
`workflow_dispatch` only. Before ~6 accumulated traces (Stage 3's own trigger for a first
baseline), auto-running it means a real API call per trace on every `/retro` commit (which
always touches `CLAUDE.md` + `evals/traces/`), for little regression-catching value with
only one or two traces. Run it manually (`gh workflow run harness-evals`, or Actions tab →
Run workflow) whenever you want to check it; uncomment the triggers at Stage 3.

**Secret scope, for whenever you do run it:** `ANTHROPIC_API_KEY` must live in the repo's
**Repository secrets** (Settings > Secrets and variables > Actions), not an Environment
secret and not an org secret that isn't shared with this repo. Neither `harness-evals.yml`
nor `agent-review.yml` declares `environment:`, so anything scoped there is invisible to the
job — the container reports `apiKeySource:none` with no error, not a loud failure.
`evals/run.sh` surfaces the raw agent output on an unparseable trajectory (v1.5.1+)
specifically so this is diagnosable from the CI log instead of a bare `turns=? cost=?`.

---

## STAGE 2: vertical slices + harness growth

### 2.1 — Features only as vertical slices

Each feature = a sliver of value through every layer, not "all the DB first, then all the
API". A CraftPlan order: `params-model` (product parameter schema + validation) →
`parts-generation` (params → parts list, the heart of the product) → `materials-catalog` →
the first configurator screen. Each — through `/spec → /plan → implement → /verify → /retro`.

### 2.2 — The rule against greenfield's main risk

On an empty repo an agent will happily generate "for the future": repository patterns with
interfaces on everything, a config system, generic helpers. Add to CLAUDE.md immediately:

```markdown
## YAGNI gate
- No abstractions "for later": an interface appears at the SECOND implementation
- No utils/, common/, helpers/ packages
- Every added file must be required by the CURRENT spec. Extras — the reviewer cuts them
```

And check it at verify: "list the diff files that no plan step requires".

### 2.3 — Skills are born from retro, not upfront

Don't write skills on day zero — there's nothing to put in them. After 2-3 features, /retro
will start repeating the same fixes → that's the moment to extract a skill. Typically the
same three appear: `go-testing`, `code-review`, `db-migrations` — but filled with YOUR real
cases, not theory.

### 2.4 — Metrics

metrics.md from feature #0. On greenfield add a **LOC diff** column — watch the ratio of
$/feature to feature size. If cost grows feature-over-feature at constant size — the
context is silting up, CLAUDE.md has sprawled, or the YAGNI gate is leaking.

Use `/log-metrics` to fill the row: it reads tokens/$/duration from `/cost` (`/usage` is
the same command) already in the conversation, computes LOC diff via `git diff --shortstat`,
and only asks you for First-pass?/Human min/Note. For this to give a clean per-feature
number, `/clear` between features and check `claude --version` first — `/clear` only resets
the cost counter on Claude Code CLI **v2.1.211+**; on older versions cost accumulates across
`/clear` for the life of the process, so consecutive features' $ figures bleed into each
other.

**Exit:** 3-5 features merged through the full cycle; at least one skill and one template
improvement produced by /retro; cost per feature known, not guessed.

---

## STAGE 3: subagents + evals in combat mode

### 3.1 — Turn subagents on when the codebase outgrows "one head"

Signal: researcher becomes useful (there's something to research; ~15-20 files in
internal/). Bring in the kit's five. The greenfield dispatch matrix is simple: a new
feature → the full pipeline; edits to fresh code → a monolith session (the code is still
"hot" in your head; the agent overhead doesn't pay off).

### 3.2 — Evals have accumulated by themselves

After ~6-8 features, evals/traces/ holds 6-8 traces from /retro. Run the kit's run.sh and
take the first baseline. From this moment: **changing CLAUDE.md or a skill without an eval
run = changing code without tests** (the kit's ci/harness-evals.yml enforces it) — this is
also the point to uncomment the `pull_request`/`push` triggers in
`ci/harness-evals.yml` (shipped `workflow_dispatch`-only per 1.4, to avoid paying for a
real API call per trace on every early `/retro` commit before there was a baseline worth
protecting).

### 3.3 — MCP — only at the first external state

For CraftPlan that's the render-API integration or populating the materials catalog. Then —
the ~50-line materials server from the playbook. Before that, MCP is pointless: don't
breed tool definitions in the context for beauty. Do the token audit (`/context`) right
after connecting the first server — record the base cost.

**Exit:** the dispatch matrix reflects measured trust; the eval baseline is recorded.

---

## STAGE 4: scale, when it's real

### 4.1 — Fan-out ×3 — on the first mechanical migrations

The first real occasion will arrive on its own: "add field X to every part type", "move
all handlers to the new middleware". The playbook + worktrees apply unchanged. Until such
an occasion appears, don't force fan-out.

### 4.2 — Plugin — when a second person or second repo appears

Package `.claude/` as a plugin when the harness needs to travel: a hired frontend dev,
web/ split into its own repo, or a new side project (a greenfield harness is ~80%
reusable). Before that it's a folder in git; a plugin adds nothing.

### 4.3 — CI agents

The auto-review workflow makes sense from Stage 2 onward (it also works when the PR author
is an agent — a second agent with the reviewer skill catches what the first one missed).
The digest for a solo project: a recurring agent report — "what merged / what in specs/
hasn't started / where tests are thinnest" — a cheap way to keep the picture when you're
not the one writing.

---

## Checklist

- [ ] S0: decisions.md · skeleton · CLAUDE.md v0 · 4 hooks · /spec /plan /commit /retro · **harness committed before product code**
- [ ] S1: walking skeleton deployed · CI + plan-verifier from PR #1 · trace #0
- [ ] S2: 3-5 features as vertical slices · YAGNI gate in CLAUDE.md · /retro after EVERY merge · skills born from retro · metrics with the LOC column
- [ ] S3: 5 subagents + dispatch · evals baseline from accumulated traces · MCP at the first external state + token audit
- [ ] S4: fan-out on the first mechanical migration · plugin at the second person/repo · recurring digest

## The three greenfield rules

1. **The harness is commit #1.** Gates are cheap while there's no code and priceless when
   the code isn't written by you.
2. **Every merge feeds the harness.** /retro after every feature: divergences → template
   fixes, conventions → CLAUDE.md, acceptance → a trace. A project whose harness doesn't
   grow with the code reverts to vibe-coding within a month.
3. **YAGNI, stricter than without agents.** An agent generates architecture cheaply; you
   read it expensively. An abstraction only at its second use.
