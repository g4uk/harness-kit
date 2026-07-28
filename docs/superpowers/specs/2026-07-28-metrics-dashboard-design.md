# Metrics dashboard: build-time, reads docs/metrics.md — design

## Problem

`extras/harness-dashboard.jsx` only works pasted into a Claude.ai artifact:
no filesystem access, so all data (scenario checkboxes, metrics rows) is
entered by hand into the UI and persisted via the artifact's `window.storage`.
Real per-feature metrics already exist in `docs/metrics.md` (populated by
`/harness:log-metrics` after each retro) but the dashboard never sees them —
it's a second, disconnected place to re-type the same numbers.

Also carries two bugs, unrelated to the redesign but worth fixing while
touching this code:
- Invariant #2 panel text omits permissions ("Safety lives in hooks...") —
  README's actual invariant #2 and Security model both call permissions the
  primary layer, hooks the secondary one.
- `build/dashboard.sh` appends an `exportMetricsAsMarkdown()` function that
  reads `localStorage['harness_metrics']` — a key the dashboard component
  never writes to (it uses `window.storage` key `"harness:metrics:v1"`) —
  and no UI element ever calls it. Dead, broken code.

## Goal

A dashboard that is part of the kit, ships to every installed project via
`install.sh`, and shows real development performance — reading
`docs/metrics.md` at build time, no server, no manual re-entry.

## Design

**Replace, not add alongside**: `extras/harness-dashboard.jsx` and the
artifact-mode logic in `build/dashboard.sh` are removed. There is one
dashboard going forward.

**New files:**
- `harness/dashboard/template.html` — self-contained HTML. React + ReactDOM +
  Babel standalone loaded via CDN `<script>` tags (no build step needed to
  edit the template directly in a browser). JSX lives inline in a
  `<script type="text/babel">` block. A single placeholder marker
  (`/*__METRICS_JSON__*/`) is where the build step injects real data as a
  JS array literal; with the marker untouched the template still opens and
  renders with an empty dataset (so it's editable/testable standalone).
- `build/dashboard.sh` (rewritten) — `./build/dashboard.sh [path]` (defaults
  to `.`). Reads `<path>/docs/metrics.md`, parses the pipe-table into JSON,
  substitutes it into the template, writes `dist/dashboard.html`. If
  `docs/metrics.md` doesn't exist yet, prints a clear message and builds with
  an empty dataset rather than failing.

**`install.sh`**: now copies `build/dashboard.sh` and
`harness/dashboard/template.html` into every installed project (currently
copies nothing dashboard-related — this whole path was kit-repo-only before).

**Parsing** (bash/awk, matching the kit's existing bash-only tooling —
no Node dependency introduced):
- Skip `#`-comment lines, the header row, and the `|---|` separator row.
- Split remaining rows on `|`, trim cells.
- Date, Task, Approach, Note: used as-is (strings).
- `$`: first `[0-9]+\.?[0-9]*` match extracted as the numeric cost; if the
  cell also contains `~` or `est` the row is flagged `approxCost: true` (real
  data has cells like `~$11.65 (est., intro pricing)`).
- `First-pass?`: `"Yes"` → `true`, anything else → `false`.
- `Human min`: parsed as a plain number (real data is already clean here).
- `Tokens` and `LOC diff` are kept as display strings only — their free-text
  format (`"104k out / 13.2M cache (Sonnet+Haiku)"`, `"+1285 / −1"`) isn't
  reliably reducible to one number per row, and the requested trends (cost,
  first-pass rate, human minutes) don't need them as numerics.
- A row that fails to parse (malformed table edit) is skipped with a warning
  printed to stderr, not a hard failure — one bad row shouldn't block seeing
  the rest.

**Dashboard content:**
- Default tab, **Performance**: summary cards (feature count, avg cost,
  first-pass %, avg human minutes) + simple inline SVG bar/line trends for
  cost, first-pass rate, and human minutes over time — no charting library,
  the data volumes here are small (tens of rows). Plus a first-half-vs-
  second-half comparison block (the compounding-retro thesis already stated
  in `docs/harness-playbook.md`: "every retro fix makes the NEXT feature
  cheaper"). Plus the raw table (all columns including Note, for qualitative
  context numbers alone don't carry).
- Second tab: the existing three scenario checklists, unchanged in content,
  now persisted via real `localStorage` (this is a real browser page, not an
  artifact sandbox) instead of `window.storage`.
- **No manual "add metric" form.** The old form wrote only to the browser's
  local storage, never to `docs/metrics.md` — a second, divergent copy of
  the same data. Since the file is now the single source of truth, adding a
  row means editing the file (already how `/harness:log-metrics` works) and
  rebuilding, not typing into the dashboard UI.
- Invariant reference panel: fixed text for #2 (permissions + hooks, not
  hooks alone), kept as a collapsible secondary panel like today.

**Docs**: `README.md`'s Extras section and Structure table updated —
`extras/harness-dashboard.jsx` references replaced with
`harness/dashboard/template.html` + `build/dashboard.sh [path] → dist/dashboard.html, open directly in a browser`.

## Out of scope

- No auto-refresh / file-watching — rebuild is an explicit, deliberate step
  (matches invariant #4: metrics are "deliberately manual").
- No charting library, no Node/build-tool dependency — CDN + Babel standalone
  and hand-rolled SVG only.
- Doesn't read `harness/evals/traces/` or `results/` — scope is
  `docs/metrics.md` only, per what was asked.
