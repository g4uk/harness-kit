# Example: a custom MCP server (~50 lines)

Reference implementation for docs/harness-playbook.md § mcp Step 4.1 — MCP gives an
agent *access* to live data instead of letting it invent plausible-sounding numbers.
CraftPlan case: read-only lookup against the materials catalog in the local DB, so the
agent queries sheet sizes/prices instead of hallucinating them.

## Run it

```bash
go mod tidy          # fetches github.com/mark3labs/mcp-go, github.com/jackc/pgx/v5
DATABASE_URL=postgres://localhost:5432/craftplan_dev go run main.go
```

Wire it into a project via `.mcp.json` at the repo root (see
`templates/.mcp.json.template`) — project-scoped, goes into git:

```json
{
  "mcpServers": {
    "craftplan-materials": {
      "command": "go",
      "args": ["run", "/absolute/path/to/examples/mcp-server/main.go"],
      "env": { "DATABASE_URL": "postgres://localhost:5432/craftplan_dev" }
    }
  }
}
```

Check: `claude` → `/mcp` (server list and status) → ask "what 18mm sheets do we
stock?" — the agent must call `search_materials`, not invent an answer.

## Next steps
- Token budget: `/context` in a fresh session, then fill in `templates/mcp-budget.md.template`
  — tool definitions of every connected MCP server are injected into EVERY session,
  called or not.
- Hybrid Skill+MCP: pair this with a Skill that tells the agent *when* and *how* to use
  the tool (docs/harness-playbook.md § mcp Step 4.3) — MCP is access, a Skill is
  judgment.
