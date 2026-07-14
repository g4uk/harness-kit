# Example: CraftPlan Feature Spec

**Feature**: Parametric 3D Configurator Baseline
**Goal**: End-to-end vertical slice deployed (configurator loads, generates BOM, returns part references).
**Scope**: UI (React/Three.js) → API (chi, SQL) → DB (PostgreSQL).

## Exit Criteria
- [ ] Configurator loads a fixed model (cube/sphere parametrization)
- [ ] Adjust one parameter (width) → BOM recalculates
- [ ] CI passes; traces green (at least 1)

## Risks
- Three.js WebGL context issues on CI (headless-chrome workaround if needed)
- sqlc codegen race-condition on fresh clone

## Design Decisions
1. No authentication v0.1 (add after v1)
2. Fixed material library (expand after MVP)
3. Sync BOM calculation (batch async later)
