# Harness Framework — step-by-step playbook with examples

All examples are anchored to **CraftPlan**, a fictional reference project (multi-tenant B2B SaaS:
a parametric 3D product configurator that generates a parts list / BOM, a nesting layout, and an
AI render for made-to-order manufacturers. Stack: Go + chi + sqlc + goose + PostgreSQL,
React/TS + Three.js frontend). Substitute your own names. Every step is a concrete action
with an expected result.

Progression is gated by evidence (exit criteria), not the calendar: the playbook is split into
four modules that map to the kit's stages — take a day or a month per module as needed.

---

## Step 0. Setup (30 min, once)

**0.1.** Create a branch for harness work and a metrics directory:

```bash
cd ~/dev/craftplan
git checkout -b harness-setup
mkdir -p .claude docs/harness
touch docs/harness/metrics.md
```

**0.2.** Create `docs/harness/metrics.md` — fill it in after EVERY significant session:

```markdown
# Harness Metrics Log

| Date | Task | Approach | Tokens | $ | First-pass? | Human min | Note |
|------|------|----------|--------|---|-------------|-----------|------|
| 2026-07-02 | baseline audit | no harness | 45k | 0.80 | — | 20 | before CLAUDE.md |
```

Where the numbers come from: `/cost` at the end of a session shows tokens and cost.
Record immediately; you won't reconstruct it later.

**0.3.** Make sure `claude --version` is current.

---

# MODULE 1 — System Design

## L01. Perception-gap audit + CLAUDE.md v1 + surface map

### Step 1.1 — Baseline audit (no CLAUDE.md)

Temporarily remove CLAUDE.md if it exists:

```bash
mv CLAUDE.md CLAUDE.md.bak 2>/dev/null; claude
```

In a clean session ask these 10 questions (CraftPlan-flavored — adapt to your repo).
Ask them ONE AT A TIME, not as a list:

1. Describe this project's architecture in 5 sentences.
2. Where does the logic live that generates the parts list from product parameters?
3. How do I run all tests? A single package?
4. How are DB migrations done here and where do they live?
5. What's the sqlc convention — where are the .sql files, how is code regenerated?
6. How is multi-tenancy implemented? What must never be broken?
7. What's the AI-render flow — from the Three.js screenshot to the image the customer sees?
8. Which external services does the backend call and where are their clients?
9. What's the error-handling convention in this project's Go code?
10. What in this repo is legacy/frozen and must not be touched?

### Step 1.2 — Score the answers

Create `docs/harness/perception-gap.md`:

```markdown
# Perception Gap Audit

## Baseline (no CLAUDE.md), 2026-07-02

| # | Question | Score | What exactly is wrong |
|---|----------|-------|-----------------------|
| 1 | Architecture | partial | doesn't know about the sales vs. production views |
| 2 | Parts generation | wrong | pointed to a package that doesn't exist |
| 3 | Tests | correct | — |
| 4 | Migrations | partial | found goose, missed the naming convention |
| 5 | sqlc | wrong | invented a queries path |
| 6 | Multi-tenancy | hallucinated | described middleware that doesn't exist |
| ... | | | |

Score: 3/10 correct
```

Scores: `correct` / `partial` / `wrong` / `hallucinated` (worst — confidently invented).
**Every row ≠ correct is a future CLAUDE.md line.** That's the module's core insight:
CLAUDE.md is written not "about the project" but "against specific failures".

### Step 1.3 — Surface map

Create `docs/surface-map.md` (~1 page, CraftPlan example):

```markdown
# Surface Map — CraftPlan

## Entry points
- `cmd/api/main.go` — HTTP API (chi router)
- `cmd/worker/main.go` — background jobs (render, nesting)

## Critical modules (changes here = mandatory human review)
- `internal/parts/` — parts-list generation from the params JSONB. The heart of the product.
- `internal/tenant/` — multi-tenancy. Every query is filtered by company_id.
- `internal/nesting/` — bin-packing layout. FFD algorithm; don't touch without benchmarks.

## Standard modules (the agent works freely)
- `internal/api/handlers/` — HTTP handlers
- `internal/db/` — generated sqlc code. NEVER hand-edit; only via .sql + sqlc generate.
- `web/src/` — React frontend

## Configs / codegen
- `sqlc.yaml`, `db/queries/*.sql` → `sqlc generate`
- `db/migrations/` → goose, format `NNNNN_name.sql`

## External services
- Image-generation API (AI render) — client in `internal/render/client.go`
- Managed PostgreSQL — DATABASE_URL from env

## Here be dragons
- `internal/legacy_import/` — old xlsx import, scheduled for rewrite. Do not refactor.
```

### Step 1.4 — CLAUDE.md v1

Write only what closes the ≠ correct rows from step 1.2. Example:

```markdown
# CraftPlan

B2B SaaS for made-to-order manufacturers: a sales rep configures a product in a
parametric 3D configurator → the system generates a parts list (BOM), an AI render,
and a nesting layout → the production team sees an order card.

## Stack
Go 1.23 (chi, pgx/v5, sqlc, goose) · PostgreSQL 16 · React+TS+Three.js

## Commands
- Tests: `go test ./...` · one package: `go test ./internal/parts/`
- Lint: `golangci-lint run`
- sqlc: edit `db/queries/*.sql` → `sqlc generate`. NEVER hand-edit `internal/db/`.
- Migrations: `goose -dir db/migrations create <name> sql` → `goose up`. Down migration is mandatory.
- Frontend: `cd web && npm run dev` / `npm test`

## Conventions
- Errors: wrap via `fmt.Errorf("parts: generate: %w", err)`, sentinel errors in the package's `errors.go`.
- Every tenant-scoped query MUST have `company_id` in WHERE. An sqlc query without it is a review blocker.
- HTTP handlers stay thin: parsing + service call + error mapping. Logic lives in `internal/<domain>/`.
- Product params are JSONB; the schema lives in `internal/parts/params.go`. New fields only through it.

## Forbidden
- Do not edit `internal/db/` (generated) or `internal/legacy_import/` (frozen).
- Do not run migrations against the prod database. Locally — `make db-reset` only.

## Project map
See `docs/surface-map.md` — read before tasks touching >1 module.
```

### Step 1.5 — Re-audit

New session (`/clear` or restart), the same 10 questions, a second table in
`perception-gap.md`. Target: **≥8/10 correct**. Whatever is still not correct — add
to CLAUDE.md. Log both sessions in metrics.md.

---

## L02. Skills layer + slash commands

### Step 2.1 — Separate facts from procedures

Walk CLAUDE.md line by line:
- **Fact** ("we use chi", "params are JSONB") → stays in CLAUDE.md.
- **Procedure** ("how to write tests", "how to review", "how to add a migration") → becomes a Skill.

CLAUDE.md is loaded into EVERY session. A Skill loads only when relevant.
Procedures in CLAUDE.md are a tax on every session.

### Step 2.2 — Skill #1: go-testing

```bash
mkdir -p .claude/skills/go-testing
```

`.claude/skills/go-testing/SKILL.md`:

```markdown
---
name: go-testing
description: >
  How to write Go tests in CraftPlan. Use ALWAYS when writing or editing
  *_test.go files, adding new functionality (test first!), or when tests
  fail and you need the conventions.
---

# Go Testing — CraftPlan

## Rules
1. Table-driven tests by default. Case names in plain language:
   `"cabinet without doors generates only carcass parts"`.
2. DB tests: real PostgreSQL via testcontainers, NOT sqlc mocks.
   Helper: `internal/testutil/db.go` → `testutil.NewDB(t)` gives an isolated schema.
3. External APIs (render): interface + fake in `internal/render/fake.go`. No httpmock.
4. Assertions: `require` for preconditions, `assert` for checks. testify.
5. A parts-generation test ALWAYS verifies count, dimensions, AND edge fields.

## Anti-patterns
- A test that mirrors the implementation (verifies the call, not the result)
- `time.Sleep` — channels or synctest only
```

### Step 2.3 — Skills #2 and #3

Same pattern:
- `.claude/skills/code-review/SKILL.md` — review criteria: tenant filter in every query,
  N+1 in loops with DB calls, error wrapping, handler size, no logic in generated code.
  Description: "Use when reviewing code, examining a diff, or before creating a PR".
- `.claude/skills/db-migrations/SKILL.md` — naming, mandatory down, backward-compatible
  changes (add column nullable → backfill → NOT NULL as a separate migration), no `DROP`
  without explicit approval.

### Step 2.4 — Slash commands

Create `.claude/commands/spec.md`, `plan.md`, `commit.md` (the kit ships ready versions —
see commands/). The key properties:
- `/spec` generates specs/<name>/spec.md with verifiable acceptance criteria and asks
  clarifying questions instead of writing code;
- `/plan` turns the spec into steps with files, risks, and an out-of-scope guard;
- `/commit` writes a conventional commit from the staged diff and refuses when nothing is staged.

### Step 2.5 — Triggering test

10 queries in fresh sessions, logged to `docs/harness/triggering-test.md`:

| Query | Expect | Fired? |
|---|---|---|
| "add a test for shelf generation" | go-testing | ✅/❌ |
| "look at this diff before the PR" | code-review | |
| "add an edge_type field to parts" | db-migrations | |
| "explain what the FFD algorithm does" | nothing | |
| "start the dev server" | nothing | |

If a skill doesn't fire — the problem is the `description`: add concrete trigger words
("test", "*_test.go", "review", "diff", "migration", "ALTER TABLE"). If it fires when it
shouldn't — narrow it ("ONLY when...").

### Step 2.6 — Squeeze CLAUDE.md to ≤200 lines

```bash
wc -l CLAUDE.md
```

Everything moved into skills gets deleted from CLAUDE.md (skills trigger themselves; no
pointer lines needed). Commit: `feat(harness): skills layer + slash commands`.

**Module 1 exit:** perception-gap before/after ≥8/10 · CLAUDE.md ≤200 lines · 3 skills ·
3 commands · triggering 10/10 · metrics.md has ≥4 entries.

---

# MODULE 2 — Agent Topology

## L03. Subagents: Hub-and-Spoke vs Peer Mesh

### Step 3.1 — Create 5 subagents

```bash
mkdir -p .claude/agents
```

Important: an agent file's content is its **system prompt**, not a user prompt.
The kit ships all five (agents/): researcher (read-only, ≤400-word reports),
test-writer (TDD red phase), implementer (plan step-by-step, commit per step),
reviewer (read-only verdict), doc-writer.

### Step 3.2 — Dispatch matrix

`docs/harness/dispatch-matrix.md`:

```markdown
| Task type | Who | Input | Output | When NOT to use |
|---|---|---|---|---|
| "where/how does X work" | researcher | question | report ≤400 words | if the answer = 1 grep |
| new feature | test-writer → implementer → reviewer | spec+plan | PR | fix ≤10 lines |
| bugfix | test-writer (repro test) → implementer | bug description | fix+test | trivial one-liner |
| reviewing a PR | reviewer | diff | verdict | — |
| refactor | researcher → implementer → reviewer | goal | PR | — |
| small edits, questions | NO subagents, main session | — | — | — |
```

The last row matters most: a subagent has overhead (its own context, its own call);
for small things it costs more than a monolith session.

### Step 3.3 — Experiment: one task, three topologies

Pick a real medium-sized task. CraftPlan example: **add a `back_panel` parameter
(back-panel type: grooved board / overlay / none) to Params and to parts generation.**

**Run A — monolith.** Fresh session, one instruction: "implement feature X: research the
code, write tests, implement, self-review". Everything in one context. At the end: `/cost` → record.

**Run B — hub-and-spoke.** Reset the branch to the start point, new orchestrator session:

```
Implement the back_panel feature via subagents:
1. researcher: how Params and parts generation work, what back_panel will touch
2. based on the report, draft a short plan and show me        ← approval stop
3. test-writer: tests per the plan
4. implementer: implementation until tests are green
5. reviewer: verdict on the diff
Do not write code yourself — coordinate and pass condensed results.
```

**Run C — peer mesh.** Reset again. Let agents pass results to each other without
compression through the hub (instruct the orchestrator: "pass agent outputs to the next
agent in full, no summarizing").

### Step 3.4 — Cost-per-topology report

`docs/harness/topology-report.md`:

```markdown
| Metric | A: monolith | B: hub-spoke | C: mesh |
|---|---|---|---|
| Total tokens | | | |
| $ | | | |
| Wall-clock | | | |
| Tests green on 1st try | | | |
| Reviewer remarks | | | |
| My interventions | | | |

## Conclusion
For tasks like ___ I choose ___, because ___.
Rule: ___
```

**Expected takeaway (verify with your own numbers):** hub-and-spoke wins on
read-heavy tasks — the research burns inside the spoke's context and doesn't pollute the
hub. Mesh is pricier and less predictable; rarely justified. Monolith is cheapest for
small tasks — subagents have overhead; don't use them for one-line fixes.

---

## L04. MCP: custom server + token budget

### Step 4.1 — Custom MCP server in Go (~50 lines)

CraftPlan case: read-only access to the materials catalog in the local DB — so the agent
queries the system for sheet sizes and prices instead of inventing them.

```bash
mkdir -p ~/dev/craftplan-mcp && cd ~/dev/craftplan-mcp
go mod init craftplan-mcp
go get github.com/mark3labs/mcp-go github.com/jackc/pgx/v5
```

`main.go`:

```go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
)

func main() {
	pool, err := pgxpool.New(context.Background(), os.Getenv("DATABASE_URL"))
	if err != nil {
		panic(err)
	}

	s := server.NewMCPServer("craftplan-materials", "0.1.0")

	tool := mcp.NewTool("search_materials",
		mcp.WithDescription("Search the CraftPlan materials catalog by name. Returns sheet size, thickness, price."),
		mcp.WithString("query", mcp.Required(), mcp.Description("Part of the name, e.g. 'plywood' or 'MDF'")),
	)

	s.AddTool(tool, func(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
		q, _ := req.Params.Arguments["query"].(string)
		rows, err := pool.Query(ctx,
			`SELECT name, thickness, sheet_width, sheet_height, price
			 FROM materials WHERE name ILIKE '%'||$1||'%' LIMIT 20`, q)
		if err != nil {
			return mcp.NewToolResultError(err.Error()), nil
		}
		defer rows.Close()

		type mat struct {
			Name           string  `json:"name"`
			Thickness      int     `json:"thickness"`
			SheetW, SheetH int     `json:"sheet_w"`
			Price          float64 `json:"price"`
		}
		var out []mat
		for rows.Next() {
			var m mat
			rows.Scan(&m.Name, &m.Thickness, &m.SheetW, &m.SheetH, &m.Price)
			out = append(out, m)
		}
		b, _ := json.Marshal(out)
		return mcp.NewToolResultText(string(b)), nil
	})

	if err := server.ServeStdio(s); err != nil {
		fmt.Fprintln(os.Stderr, err)
	}
}
```

Wire it up — `.mcp.json` in the CraftPlan repo root (project-scoped, goes into git):

```json
{
  "mcpServers": {
    "craftplan-materials": {
      "command": "go",
      "args": ["run", "/home/me/dev/craftplan-mcp/main.go"],
      "env": { "DATABASE_URL": "postgres://localhost:5432/craftplan_dev" }
    }
  }
}
```

Check: `claude` → `/mcp` (server list and status) → ask "what 18mm sheets do we stock?" —
the agent must call the tool, not invent an answer.

### Step 4.2 — Token budget audit

Tool definitions of ALL connected MCP servers are injected into every session, even if
no tool is ever called.

1. Fresh session → `/context` — inspect the context breakdown, find the MCP-tools share.
2. Build a table in `docs/harness/mcp-budget.md`:

```markdown
| MCP server | Tools | ~tokens in EVERY session | Calls per week | Verdict |
|---|---|---|---|---|
| craftplan-materials | 1 | ~150 | 12 | keep |
| github (official) | 30+ | ~15000 | 2 | DISABLE, gh CLI suffices |
```

3. Everything with a "disable" verdict — remove from configs. Typical audit result:
   one or two "big" servers cost more context than your entire CLAUDE.md+skills combined.

### Step 4.3 — Hybrid Skill+MCP

MCP gives *access*; a Skill gives *knowledge of how to use it*.
`.claude/skills/materials-lookup/SKILL.md`:

```markdown
---
name: materials-lookup
description: >
  Working with the materials catalog. Use whenever a task involves materials,
  sheet sizes, prices, or nesting — before hardcoding any numbers.
---
# Materials

1. NEVER hardcode sheet sizes or prices — ask the search_materials tool.
2. Common sheet sizes vary by supplier — ALWAYS verify per material.
3. Material not found — ask the user; do not substitute a similar one.
4. Nesting math must account for the saw kerf — that's a nesting-service parameter,
   not a material property.
```

### Step 4.4 — Your selection rule (write your own)

Add a conclusion to `docs/harness/mcp-budget.md`:

```markdown
## Rule
- live data / state / auth → MCP (narrow tools, ≤3 per server)
- knowledge and procedures → Skill
- a one-off call doable with curl/gh/psql → a bash script inside a Skill, NO MCP
- broad official servers (30+ tools) → only if I use ≥5 tools weekly
```

**Module 2 exit:** 5 agents · dispatch matrix · topology report with real numbers ·
working MCP server · mcp-budget.md · hybrid pair · ≥1 wasteful server disabled.

---

# MODULE 3 — CI Pipeline

## L05. Spec-Driven Development

### Step 5.1 — Pick a feature

Criterion: 0.5–1 day of manual work, touching DB + logic + API. CraftPlan example:
**surface finishing: for each part — which edges get finished, with which finish type,
plus per-type totals in meters on the order card.**

### Step 5.2 — `/spec edge-finishing`

The command generates a draft. Your senior job is to review the spec. What a FINISHED
spec looks like:

```markdown
# Spec: Edge Finishing

## Problem
Production calculates finishing lengths by hand from the parts list — 10-15 min
per order, errors in 1 of 5. Finishing must be computed automatically.

## Scope
- edge_top/bottom/left/right fields on parts (finish type or NULL)
- Default finishing rules by part type (front: 4 edges; shelf: 1 front edge;
  carcass side: visible edges)
- Manual override by the sales rep in the configurator
- Per-finish-type totals in meters on the order card (+10% allowance)

## Non-scope
- Finishing in the nesting layout (v2)
- Finishing price in the calculator (separate feature)
- Changing existing orders (new ones only)

## Acceptance criteria
1. When a "front 600×800" part is created, then all 4 edge fields = the material's default finish type.
2. When the rep sets edge_top to NULL, then totals are recomputed without that edge.
3. When a project has 3 parts with "PVC 2mm", then the card shows the sum of finished-edge
   lengths ×1.10, rounded to 0.1 m.
4. When a part has no finishing at all, then it does not appear in the totals.
5. API: GET /projects/{id}/finish-summary returns {type, meters}[] in ≤200ms on a
   100-part project.

## Edge cases
- A part with 0 finished edges / all 4
- Two different finish types on one part
- Curved front (finishing along an arc) — out of scope, explicit validation error
- Another tenant's project → 404 (not 403!)
- Totals when qty > 1

## Constraints
- Backward-compatible migration: old parts → edge_* = NULL, totals = 0
- Tenant isolation in every new query
```

Spec-review rule: every acceptance criterion converts to a test mechanically.
If it doesn't — rewrite it.

### Step 5.3 — `/plan edge-finishing`

Review the plan. Look for: (a) tests before implementation; (b) the migration as a
separate step and commit; (c) an out-of-scope guard — files that must NOT change;
(d) every step ends with green tests. Fixing a plan takes 5 minutes; fixing code written
from a bad plan takes an hour.

### Step 5.4 — Implement

```
Execute plan.md step by step. After every step: go test ./... and a commit via /commit.
If a step requires deviating from the plan — STOP and ask me.
```

You don't read every line during this — you check commits against plan steps.

### Step 5.5 — Verify

```
Walk the acceptance criteria from spec.md one by one. For each: show the test or the
command that proves it, and the result. Format: criterion # → evidence → PASS/FAIL.
```

FAIL → back to implement. Never "looks done".

### Step 5.6 — Cost breakdown + retro-spec

In `specs/edge-finishing/cost.md`: `/cost` per phase (spec/plan/implement/verify),
your minutes. The point of a reference number like "$17 per feature" is not to hit it —
it's to KNOW yours and watch the trend.

`specs/edge-finishing/retro.md`:

```markdown
## Divergences spec ↔ implementation
1. The spec missed qty>1 in totals → caught at verify → add a quantity-fields prompt to the /spec template
2. The plan missed sqlc regeneration after a new query → implementer got stuck → add a "codegen" step to the /plan template
## Harness changes
- [ ] update .claude/commands/spec.md
- [ ] update .claude/commands/plan.md
```

Every retro fix makes the NEXT feature cheaper — that's the harness compounding effect.

---

## L06. Quality gates: hooks → TDD → plan-verifier → evals

### Step 6.1-6.3 — Three hooks

The kit ships all of them ready (hooks/ + settings/): fmt.sh (auto-format on edit),
guard.sh (PreToolUse block of dangerous commands, exit 2 with an explanation),
tests-green.sh (Stop hook that refuses to finish with red tests, scoped to changed
packages), plus secrets-scan.sh on writes.

Key semantics: **exit 2 blocks the action** (stderr goes back to the agent),
exit 1 is a non-blocking warning, exit 0 passes. Every security hook MUST use exit 2.
Hooks also fire for subagents — the gates are recursive.

Test each hook manually by feeding JSON to stdin:

```bash
echo '{"tool_input":{"command":"git push --force origin main"}}' | .claude/hooks/guard.sh; echo "exit=$?"
# expect: BLOCKED..., exit=2
```

Then live: ask the agent to force-push — it must get blocked with an explanation.

### Step 6.4 — Plan-verifier in CI

`.github/workflows/plan-verify.yml` — a separate agent checks the diff against the plan
on every PR (the kit's ci/ has a ready workflow; verify the action syntax against
github.com/anthropics/claude-code-action):

```yaml
prompt: |
  The PR must contain specs/*/plan.md. Compare git diff origin/main...HEAD with the plan:
  1) are all steps done; 2) are there file changes OUTSIDE the plan (out-of-scope guard
  violation); 3) are there steps without tests.
  Comment: VERDICT: PASS/FAIL + findings with file:line. No plan.md — FAIL "PR without a plan".
```

### Step 6.5 — Eval set: 20 traces

This is the regression test for the harness itself. Structure:

```
evals/
  traces/
    001-finish-summary-endpoint.md   # task + verification criteria
    002-tenant-filter-bug.md
    ...020-*.md
  run.sh
  results/2026-07-XX.md
```

Each trace:

```markdown
# 001: finish-summary endpoint
## Prompt
Add GET /projects/{id}/finish-summary returning finishing meters per type.
## Checks
- [ ] cmd: go test ./...
- [ ] cmd: git grep -q 'company_id' -- db/queries/projects.sql
- [ ] (manual) handler ≤40 lines, logic in internal/parts
```

`evals/run.sh` (shipped in the kit): a fresh worktree per trace, a headless run
(`claude -p ... --output-format json`), then deterministic checks. Run it after every
CLAUDE.md/skills/hooks change → watch the pass rate move. Record the baseline in the
first results file. From then on: **changing CLAUDE.md or a skill without an eval run =
changing code without tests** (the kit's ci/harness-evals.yml turns this into a CI gate).

### Step 6.6 — Mutation report

```bash
go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest
go-mutesting ./internal/parts/ > docs/harness/mutation-report.txt
```

Mutation score = the share of "killed" mutants. Compare the score of a package with
agent-written tests against one with your handwritten tests. If the agent's score is
noticeably lower, the tests are theater (they verify calls, not behavior) → fix the
go-testing skill and the retro-spec.

**Module 3 exit:** one feature through the full spec→plan→implement→verify cycle ·
cost.md + retro.md · 3 working hooks (hand-tested and live-tested) · plan-verifier
commenting on PRs · 20 traces + baseline pass rate · mutation report with a conclusion.

---

# MODULE 4 — Scale + Production

## L07. Parallel fan-out: worktree × 3

### Step 7.1 — Pick a task that shards

Criterion: mechanical, uniform, many files, independent shards. CraftPlan example:
**migrating logging from `log.Printf` to structured `slog` with tenant context across all
internal packages** (or: unifying error wrapping; a major dependency upgrade).

### Step 7.2 — Migration playbook

`docs/harness/migration-playbook-slog.md`:

```markdown
# Playbook: log.Printf → slog

## Shards (independent, no file overlap)
- shard-a: internal/parts, internal/nesting
- shard-b: internal/api, internal/tenant
- shard-c: internal/render, internal/db adapters, cmd/*

## Shared rules (for ALL agents)
1. Replace: log.Printf("...%v", err) → slog.Error("msg", "err", err, "company_id", cid)
2. Levels: Error - failures, Warn - degradation, Info - business events, Debug - the rest
3. The logger arrives via context (helper internal/obs/log.go — shard-b creates it FIRST;
   others wait)
4. NO other changes in the files. Found a bug — TODO comment, do NOT fix.
5. Each package = its own commit "refactor(slog): <package>"

## Invariants
- go test ./... green after every package
- zero log.Printf in the diff (check: git grep -n 'log\.Printf' -- <shard>)

## Merge order
shard-b (helper) → shard-a → shard-c. Conflicts are resolved by the human.
```

Note the dependency: ONE shard creates the shared helper first — the rest start after its
commit. That's the classic fan-out trap.

### Step 7.3 — Worktrees + launch

```bash
git checkout -b slog-base && git push -u origin slog-base
git worktree add ../craftplan-slog-a -b slog-shard-a
git worktree add ../craftplan-slog-b -b slog-shard-b
git worktree add ../craftplan-slog-c -b slog-shard-c
```

Three terminals, in each:

```bash
cd ../craftplan-slog-b && claude
> Execute docs/harness/migration-playbook-slog.md, your shard: shard-b.
  Start with the helper internal/obs/log.go.
```

(Worktrees share .git but each has its own working copy — the agents never step on each
other's files; CLAUDE.md/skills/hooks work in every worktree since it's the same repo.)

### Step 7.4 — You = tech lead

Keep `docs/harness/fanout-log.md` in real time:

```markdown
| Time | Shard | Event | My action |
|---|---|---|---|
| 14:02 | b | started, writing the helper | — |
| 14:15 | b | helper done, committed | launched a and c |
| 14:31 | a | asks about logs in tests | answered: slog.Discard in tests |
| 14:40 | c | stuck on cmd/worker (global logger) | suggested the pattern |
| 15:05 | a | shard done | review + merge |
```

The practical ceiling is 3-4 parallel sessions per human — beyond that, context switching
eats the win.

### Step 7.5 — Merge + cost delta

Merge in playbook order, `git worktree remove` after each. Then
`docs/harness/fanout-cost-delta.md`:

```markdown
| Metric | Sequential (estimate: shard-b actual ×3) | Fan-out ×3 |
|---|---|---|
| Wall-clock | | |
| $ total | | |
| My minutes | | |
| Merge conflicts | | |

Conclusion: fan-out for ___, NOT for ___.
```

Expect: wall-clock ↓ ~2-2.5×, $ roughly flat or slightly ↑, your attention noticeably ↑.

---

## L08. Plugin + CI agent + rollout

### Step 8.1 — Package the harness as a plugin

The plugin = everything you've built as one installable artifact (the kit's own layout
mirrors this: .claude-plugin/plugin.json + skills/ + agents/ + commands/ + hooks/).
Fitness test: a clean clone on another machine + installing the plugin = the full harness
in one action, no manual copying of .claude/.

### Step 8.2 — CI agent: auto-review on every PR

The reviewer from L03 moves into CI (the kit's ci/agent-review.yml). The rights principle:
the CI agent **comments, never merges**. Trust is grown gradually.

### Step 8.3 — DevDigest (capstone)

A product built THROUGH the harness — proof of the full cycle:

1. `/spec devdigest` — a recurring digest of repo activity: commits, PRs, open questions
   from fanout/retro logs → markdown to chat/email.
2. `/plan devdigest` → implement via subagents → verify → hooks and plan-verifier fire
   along the way.
3. Deploy: a scheduler (managed cron or GitHub Actions schedule) runs a headless
   `claude -p` that assembles the digest.
4. "Deployed" criterion: the digest arrives on its own, three runs in a row, without you.

### Step 8.4 — Staged rollout plan

`docs/harness/rollout.md` (even if "the team" = you plus a future teammate). Each stage
has an adoption metric and a rollback criterion — advance on evidence:

```markdown
| Stage | What we enable | Adoption metric | Roll back if |
|---|---|---|---|
| 1 | CLAUDE.md + skills | perception audit ≥8/10 for everyone | wrong-advice complaints > 2/wk |
| 2 | hooks + /spec /plan /commit | 100% of PRs have a spec | hooks false-block > 1/day |
| 3 | CI agent (comments only) | ≥50% of its remarks deemed valid | noise > signal |
| 4 | subagents + evals baseline | pass rate ≥ 15/20 | cost/feature grew vs stage 1 |

Retro at the end: metrics.md first stage vs last — $/feature, first-pass rate,
human minutes per feature.
```

**FINAL BUNDLE:** installable plugin · CI agent living on real PRs · DevDigest deployed
and self-reporting · rollout.md with before/after metrics.

---

# Cross-cutting principles (what makes the approach senior)

1. **Every layer is measured.** Without cost/token/pass-rate numbers, "subagents vs
   monolith" or "MCP vs script" is religion, not engineering.
2. **Determinism where it's critical.** Safety and quality live in hooks and CI, not
   prompts. A prompt is a wish; a hook is a guarantee.
3. **Context is the primary resource.** The whole topology (skill triggering, subagents,
   MCP token budget) is really context management.
4. **The human sits at phase boundaries.** Review the spec and the plan, not every line
   of code. Approval stops live at phase transitions.
5. **The harness is code too.** It's versioned, tested (evals), has regressions, gets
   packaged (plugin), and rolls out in stages.
