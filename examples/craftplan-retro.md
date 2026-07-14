# Example: CraftPlan Feature Retro

**Feature**: Parametric 3D Configurator Baseline
**Date**: 2025-01-15 · **Branch**: `feat/v0.1-configurator` · **Merge**: #42

## Metrics
| Item | Plan | Actual | Note |
|------|------|--------|------|
| Effort (h) | 9 | 14.5 | Three.js WebGL headless debugging +3h |
| Tokens | 80k | 124k | Extra /verify → /replan loop |
| First-pass? | — | No | Headless WebGL failed; rewrote canvas |
| PR rounds | — | 2 | Missed edge case: width=0 → div-by-zero in BOM |

## Divergences
1. **3D rendering offline**: Headless Three.js → fallback to 2D canvas mock. Pushed 3D CI to v0.2.
2. **Async BOM**: Planned sync, but API response time was 80ms. Kept sync for v0.1; revisit after profile.
3. **Migration file**: goose migration named by timestamp (auto); didn't match spec's `bom_parts` convention. Added comment in CLAUDE.md.

## What Stuck
- Three.js WebGL in headless CI — expected in Next.js/Vite setups; mitigation: unit test BOM logic separately.
- Spec said "fixed material library" but we hardcoded material IDs; should be a tiny LUT. Add to v0.2.

## Next Phase Decisions
1. **Sketch 3D rendering strategy** before committing to Three.js in CI (spike).
2. **Template**: BOM calculation → extract to `BOM Builder` skill.
3. **Trace**: evals/craftplan-v0.1 passed; add to baseline (no regression).
4. **Cost**: ~$0.07 per cycle at this scale; acceptable. Monitor on 3D spike.
