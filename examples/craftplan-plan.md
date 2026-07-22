# Example: CraftPlan Feature Plan

**Feature**: Parametric 3D Configurator Baseline
**Owner**: alice@craftplan.dev

## Phases

### Phase 1: Frontend Scaffold + Three.js Setup (2h)
**Tasks**:
- [ ] Vite + React/TS setup; Three.js in package.json
- [ ] Canvas component (App.jsx)
- [ ] WebGL context initialization + cube geometry

**Verification**: `npm run dev` → browser loads, renders cube.

### Phase 2: BOM Calculation + State (2h)
**Tasks**:
- [ ] Parameter store (width slider, quantity)
- [ ] BOM builder (mock: "PART_001: qty=width×2")
- [ ] Update BOM on parameter change

**Verification**: Adjust width → BOM qty changes.

### Phase 3: API Skeleton + Database (3h)
**Tasks**:
- [ ] chi route: `POST /api/bom` (json: `{width: int, ...}`)
- [ ] sqlc + goose migration: `bom_parts` table
- [ ] Handler: query mock data, return JSON

**Verification**: curl API → returns BOM JSON.

### Phase 4: Integration (1h)
**Tasks**:
- [ ] Frontend calls `POST /api/bom` on parameter change
- [ ] Display API response in BOM list

**Verification**: Adjust width → fetches from API → displays result.

### Phase 5: Eval Trace + CI (1h)
**Tasks**:
- [ ] Write evals/traces/craftplan-v0.1.md (checks: npm test, go test, curl /api/bom)
- [ ] Add to harness-evals.yml

**Verification**: CI runs; trace passes.

## Dependencies
- None (greenfield).

## Effort estimate
- 9 hours planned; actual often 12–15 (async debugging, schema tweaks).
- Tokens: ~80k per /harness:spec + /harness:plan + implement cycles (estimate).

## Risks & Mitigations
| Risk | Mitigation |
|------|-----------|
| Three.js context fails headless | Skip 3D, use 2D canvas test fallback |
| sqlc codegen hangs | Regenerate in clean clone |
