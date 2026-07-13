import { useState, useEffect, useRef } from "react";

/* ------------------------------------------------------------------ */
/* Дані: чеклисти трьох сценаріїв (з harness-kit/scenarios/)           */
/* ------------------------------------------------------------------ */

const SCENARIOS = {
  greenfield: {
    label: "Greenfield",
    sub: "свій проєкт з нуля",
    phases: [
      {
        title: "День 0 — harness до коду",
        items: [
          "docs/decisions.md — кожне рішення письмово",
          "CLAUDE.md з рішень + YAGNI-гейт",
          "install.sh → .claude/, hooks активні з комміту №1",
          "docs/metrics.md заведений",
        ],
      },
      {
        title: "День 1–2 — walking skeleton",
        items: [
          "Фіча №0: наскрізний зріз задеплоєний (/spec → /plan → verify)",
          "CI + plan-verifier з PR №1",
          "Трейс №0 в evals/traces/",
        ],
      },
      {
        title: "Тиждень 1–2 — вертикальні зрізи",
        items: [
          "3–5 фіч тільки вертикальними зрізами",
          "/retro після КОЖНОГО мержа",
          "Skills народились з retro-повторів",
          "metrics.md з колонкою LOC diff",
        ],
      },
      {
        title: "Тиждень 3 — агенти + evals",
        items: [
          "5 субагентів + dispatch matrix",
          "evals baseline з накопичених трейсів",
          "MCP при першому зовнішньому стані + token-аудит",
        ],
      },
      {
        title: "Тиждень 4+ — масштаб",
        items: [
          "fan-out ×3 на першій механічній міграції",
          "plugin при другій людині / другому репо",
          "weekly digest від агента",
        ],
      },
    ],
  },
  onboarding: {
    label: "Onboarding",
    sub: "чужий існуючий проєкт",
    phases: [
      {
        title: "День 0 — особистий рівень",
        items: [
          "Доступи, локальний запуск, прогін тестів",
          "journal.md + metrics.md поза репо",
          "guard.sh у ~/.claude ДО першої сесії",
          "Прочитати наявні .claude/ і CLAUDE.md, token-аудит чужих MCP",
        ],
      },
      {
        title: "День 1–2 — розвідка",
        items: [
          "2 researcher-сесії: карта + критичні флови",
          "«ПРИПУЩЕННЯ» верифіковані людьми",
          "surface-map.md (особистий, поза репо)",
        ],
      },
      {
        title: "День 3–5 — перший цикл",
        items: [
          "CLAUDE.local.md (тільки перевірене!)",
          "Перший PR: гілка → ревʼю → мерж → деплой",
          "Зауваження ревʼю → «Як тут заведено»",
        ],
      },
      {
        title: "Тиждень 2 — особистий harness",
        items: [
          "3 особисті skills з реальних кейсів",
          "researcher + pr-preflight; жоден PR без preflight",
          "Особиста dispatch matrix: де агенту можна",
        ],
      },
      {
        title: "Тиждень 3 — глибина",
        items: [
          "Критичні модулі: пояснення своїми словами",
          "Перший внесок: README-фікс або surface-map як PR",
        ],
      },
      {
        title: "Тиждень 4 — легалізація",
        items: [
          "Командний CLAUDE.md як PR з цифрами perception-gap",
          "Далі по одному PR: skills → fmt-hook → guard-hook",
        ],
      },
    ],
  },
  existing: {
    label: "Existing",
    sub: "власний існуючий проєкт",
    phases: [
      {
        title: "Тиждень 1 — perception gap",
        items: [
          "Аудит: 10 питань без CLAUDE.md, таблиця оцінок",
          "docs/surface-map.md",
          "CLAUDE.md проти конкретних помилок; повторний аудит ≥8/10",
          "install.sh → .claude/, skills наповнені (EDIT_ME)",
          "Triggering-тест skills 10/10",
        ],
      },
      {
        title: "Тиждень 2 — топологія + MCP",
        items: [
          "5 агентів + dispatch matrix",
          "Одна задача ×3 топології → topology-report з цифрами",
          "Token-аудит MCP, вимкнене зайве, hybrid Skill+MCP",
        ],
      },
      {
        title: "Тиждень 3 — quality gates",
        items: [
          "Фіча повним циклом + cost.md + /retro",
          "3 hooks перевірені вручну (exit 2!)",
          "plan-verifier у CI",
          "20 трейсів + baseline; mutation report",
        ],
      },
      {
        title: "Тиждень 4 — масштаб",
        items: [
          "fan-out ×3: playbook → fanout-log → cost delta",
          "plugin + CI auto-review + rollout-план 30 днів",
        ],
      },
    ],
  },
};

const INVARIANTS = [
  "Фаза за фазою: perceive → spec → plan → implement → verify. Кожна фаза — файл під ревʼю.",
  "Безпека в hooks (exit 2), не в промптах. Промпт — побажання, hook — гарантія.",
  "Субагент повертає стислий результат. Дрібні задачі — без субагентів.",
  "Метрики з першого дня: /cost → журнал. Без цифр рішення — релігія.",
  "/retro після кожного мержа годує CLAUDE.md, шаблони і evals.",
  "Зміна CLAUDE.md/skills без прогону evals = код без тестів.",
];

const APPROACHES = ["моноліт", "hub-and-spoke", "mesh", "fan-out", "руками"];

/* ------------------------------------------------------------------ */

const CHECKS_KEY = "harness:checks:v1";
const METRICS_KEY = "harness:metrics:v1";

async function loadJSON(key, fallback) {
  try {
    const r = await window.storage.get(key);
    return r && r.value ? JSON.parse(r.value) : fallback;
  } catch {
    return fallback;
  }
}
async function saveJSON(key, value) {
  try {
    await window.storage.set(key, JSON.stringify(value));
  } catch (e) {
    console.error("storage save failed", e);
  }
}

const itemId = (sc, p, i) => `${sc}.${p}.${i}`;

/* ------------------------------------------------------------------ */

export default function HarnessDashboard() {
  const [scenario, setScenario] = useState("greenfield");
  const [checks, setChecks] = useState({});
  const [metrics, setMetrics] = useState([]);
  const [loaded, setLoaded] = useState(false);
  const [showRef, setShowRef] = useState(false);
  const [form, setForm] = useState({
    task: "",
    approach: "моноліт",
    tokens: "",
    cost: "",
    firstPass: true,
    mins: "",
  });
  const saveTimer = useRef(null);

  useEffect(() => {
    (async () => {
      setChecks(await loadJSON(CHECKS_KEY, {}));
      setMetrics(await loadJSON(METRICS_KEY, []));
      setLoaded(true);
    })();
  }, []);

  const persistChecks = (next) => {
    setChecks(next);
    clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => saveJSON(CHECKS_KEY, next), 400);
  };

  const toggle = (id) => persistChecks({ ...checks, [id]: !checks[id] });

  const addMetric = () => {
    if (!form.task.trim()) return;
    const entry = {
      date: new Date().toISOString().slice(0, 10),
      ...form,
      tokens: Number(form.tokens) || 0,
      cost: Number(form.cost) || 0,
      mins: Number(form.mins) || 0,
    };
    const next = [entry, ...metrics];
    setMetrics(next);
    saveJSON(METRICS_KEY, next);
    setForm({ task: "", approach: form.approach, tokens: "", cost: "", firstPass: true, mins: "" });
  };

  const removeMetric = (idx) => {
    const next = metrics.filter((_, i) => i !== idx);
    setMetrics(next);
    saveJSON(METRICS_KEY, next);
  };

  const scData = SCENARIOS[scenario];

  const progressOf = (sc) => {
    const s = SCENARIOS[sc];
    let total = 0,
      done = 0;
    s.phases.forEach((p, pi) =>
      p.items.forEach((_, ii) => {
        total++;
        if (checks[itemId(sc, pi, ii)]) done++;
      })
    );
    return { total, done, pct: total ? Math.round((done / total) * 100) : 0 };
  };

  const prog = progressOf(scenario);
  const sum = {
    n: metrics.length,
    cost: metrics.reduce((a, m) => a + m.cost, 0),
    fp: metrics.length
      ? Math.round((metrics.filter((m) => m.firstPass).length / metrics.length) * 100)
      : 0,
  };

  return (
    <div className="hk-root">
      <style>{CSS}</style>

      {/* title block — як штамп на кресленні */}
      <header className="hk-title">
        <div className="hk-title-main">
          <span className="hk-logo">HARNESS&nbsp;KIT</span>
          <span className="hk-title-sub">панель проходження · spec → plan → implement → verify</span>
        </div>
        <div className="hk-stamp">
          <span>арк. 1/1</span>
          <span>{new Date().toISOString().slice(0, 10)}</span>
        </div>
      </header>

      {/* сценарії — вкладки-worktree */}
      <nav className="hk-tabs">
        {Object.entries(SCENARIOS).map(([key, s]) => {
          const p = progressOf(key);
          return (
            <button
              key={key}
              className={"hk-tab" + (scenario === key ? " active" : "")}
              onClick={() => setScenario(key)}
            >
              <span className="hk-tab-name">{s.label}</span>
              <span className="hk-tab-sub">{s.sub}</span>
              <span className="hk-tab-pct">{p.pct}%</span>
            </button>
          );
        })}
      </nav>

      {/* прогрес — торець фанери */}
      <section className="hk-progress">
        <div className="hk-ply">
          <div className="hk-ply-fill" style={{ width: prog.pct + "%" }} />
        </div>
        <div className="hk-progress-meta">
          <span>
            {prog.done}/{prog.total} позицій
          </span>
          <span className="hk-mono">{prog.pct}%</span>
        </div>
      </section>

      {!loaded && <p className="hk-loading">Читаю збережений прогрес…</p>}

      {/* чеклист — карта розкрою */}
      <main className="hk-list">
        {scData.phases.map((phase, pi) => {
          const doneInPhase = phase.items.filter((_, ii) => checks[itemId(scenario, pi, ii)]).length;
          return (
            <section key={pi} className="hk-phase">
              <h2 className="hk-phase-head">
                <span>{phase.title}</span>
                <span className="hk-mono hk-phase-count">
                  {doneInPhase}/{phase.items.length}
                </span>
              </h2>
              {phase.items.map((text, ii) => {
                const id = itemId(scenario, pi, ii);
                const on = !!checks[id];
                return (
                  <label key={id} className={"hk-row" + (on ? " done" : "")}>
                    <input type="checkbox" checked={on} onChange={() => toggle(id)} />
                    <span className="hk-row-id hk-mono">
                      {String.fromCharCode(65 + pi)}-{String(ii + 1).padStart(2, "0")}
                    </span>
                    <span className="hk-row-text">{text}</span>
                  </label>
                );
              })}
            </section>
          );
        })}
      </main>

      {/* метрики */}
      <section className="hk-metrics">
        <h2 className="hk-phase-head">
          <span>Журнал метрик</span>
          <span className="hk-mono hk-phase-count">
            {sum.n ? `${sum.n} записів · $${sum.cost.toFixed(2)} · first-pass ${sum.fp}%` : "порожньо"}
          </span>
        </h2>

        <div className="hk-form">
          <input
            className="hk-input grow"
            placeholder="Задача (напр. edge-banding spec)"
            value={form.task}
            onChange={(e) => setForm({ ...form, task: e.target.value })}
          />
          <select
            className="hk-input"
            value={form.approach}
            onChange={(e) => setForm({ ...form, approach: e.target.value })}
          >
            {APPROACHES.map((a) => (
              <option key={a}>{a}</option>
            ))}
          </select>
          <input
            className="hk-input num"
            placeholder="ток., k"
            inputMode="numeric"
            value={form.tokens}
            onChange={(e) => setForm({ ...form, tokens: e.target.value })}
          />
          <input
            className="hk-input num"
            placeholder="$"
            inputMode="decimal"
            value={form.cost}
            onChange={(e) => setForm({ ...form, cost: e.target.value })}
          />
          <input
            className="hk-input num"
            placeholder="хв"
            inputMode="numeric"
            value={form.mins}
            onChange={(e) => setForm({ ...form, mins: e.target.value })}
          />
          <label className="hk-fp">
            <input
              type="checkbox"
              checked={form.firstPass}
              onChange={(e) => setForm({ ...form, firstPass: e.target.checked })}
            />
            first-pass
          </label>
          <button className="hk-add" onClick={addMetric}>
            Записати
          </button>
        </div>

        {metrics.length > 0 && (
          <div className="hk-table-wrap">
            <table className="hk-table">
              <thead>
                <tr>
                  <th>дата</th>
                  <th>задача</th>
                  <th>підхід</th>
                  <th className="num">ток.k</th>
                  <th className="num">$</th>
                  <th className="num">хв</th>
                  <th>1st</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {metrics.map((m, i) => (
                  <tr key={i}>
                    <td className="hk-mono">{m.date.slice(5)}</td>
                    <td>{m.task}</td>
                    <td>{m.approach}</td>
                    <td className="num hk-mono">{m.tokens || "—"}</td>
                    <td className="num hk-mono">{m.cost ? m.cost.toFixed(2) : "—"}</td>
                    <td className="num hk-mono">{m.mins || "—"}</td>
                    <td>{m.firstPass ? "✓" : "✗"}</td>
                    <td>
                      <button className="hk-del" onClick={() => removeMetric(i)} aria-label="Видалити запис">
                        ×
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* довідка */}
      <section className="hk-ref">
        <button className="hk-ref-toggle" onClick={() => setShowRef(!showRef)}>
          {showRef ? "Сховати інваріанти" : "Показати 6 інваріантів"}
        </button>
        {showRef && (
          <ol className="hk-inv">
            {INVARIANTS.map((t, i) => (
              <li key={i}>{t}</li>
            ))}
          </ol>
        )}
      </section>

      <footer className="hk-foot">
        Прогрес і журнал зберігаються між сесіями. Правило проходження: позиція без цифр у журналі — не
        зарахована.
      </footer>
    </div>
  );
}

/* ------------------------------------------------------------------ */

const CSS = `
@import url('https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@75..100,400..800&family=IBM+Plex+Mono:wght@400;500&display=swap');

.hk-root {
  --paper:#E8EAE2; --card:#F6F7F1; --ink:#22261F; --dim:#6A7060;
  --line:#C7CCBB; --tape:#D99A06; --tape-soft:#F3D488; --ok:#4A7351;
  --ply1:#DBC69C; --ply2:#B99B69;
  min-height:100vh; background:var(--paper); color:var(--ink);
  font-family:'Archivo',system-ui,sans-serif; font-stretch:87%;
  max-width:880px; margin:0 auto; padding:20px 16px 48px;
}
.hk-mono { font-family:'IBM Plex Mono',monospace; }

.hk-title { display:flex; justify-content:space-between; align-items:flex-end;
  border:2px solid var(--ink); background:var(--card); padding:12px 14px; }
.hk-logo { font-weight:800; font-size:26px; letter-spacing:.04em; font-stretch:75%; }
.hk-title-sub { display:block; font-size:12px; color:var(--dim); margin-top:2px; }
.hk-stamp { display:flex; flex-direction:column; align-items:flex-end; gap:2px;
  font-family:'IBM Plex Mono',monospace; font-size:11px; color:var(--dim);
  border-left:1px solid var(--line); padding-left:12px; }

.hk-tabs { display:flex; gap:6px; margin-top:14px; }
.hk-tab { flex:1; text-align:left; background:transparent; border:1px solid var(--line);
  border-bottom:2px solid var(--line); padding:8px 10px; cursor:pointer; color:var(--ink);
  font:inherit; transition:background .15s; }
.hk-tab:hover { background:var(--card); }
.hk-tab.active { background:var(--card); border-color:var(--ink); border-bottom:3px solid var(--tape); }
.hk-tab-name { display:block; font-weight:700; font-size:15px; }
.hk-tab-sub { display:block; font-size:11px; color:var(--dim); }
.hk-tab-pct { display:block; margin-top:4px; font-family:'IBM Plex Mono',monospace;
  font-size:12px; color:var(--dim); }
.hk-tab.active .hk-tab-pct { color:var(--tape); font-weight:500; }

.hk-progress { margin-top:16px; }
.hk-ply { height:22px; border:1.5px solid var(--ink); background:var(--card); overflow:hidden; }
.hk-ply-fill { height:100%;
  background:repeating-linear-gradient(90deg,
    var(--ply1) 0 10px, var(--ply2) 10px 13px, #EADFC6 13px 22px, var(--ply2) 22px 25px);
  border-right:2px solid var(--ink); transition:width .35s ease; }
.hk-progress-meta { display:flex; justify-content:space-between; font-size:12px;
  color:var(--dim); margin-top:4px; }

.hk-loading { color:var(--dim); font-size:13px; margin-top:12px; }

.hk-phase { margin-top:20px; background:var(--card); border:1px solid var(--line); }
.hk-phase-head { display:flex; justify-content:space-between; align-items:baseline;
  font-size:14px; font-weight:700; letter-spacing:.02em; text-transform:uppercase;
  margin:0; padding:10px 12px; border-bottom:1px solid var(--line); }
.hk-phase-count { font-size:11px; color:var(--dim); font-weight:400; }

.hk-row { display:flex; align-items:flex-start; gap:10px; padding:9px 12px;
  border-bottom:1px dashed var(--line); cursor:pointer; }
.hk-row:last-child { border-bottom:none; }
.hk-row:hover { background:#EFF1E8; }
.hk-row input { margin-top:3px; width:15px; height:15px; accent-color:var(--ok); flex:none; }
.hk-row-id { font-size:11px; color:var(--dim); margin-top:2px; flex:none; width:38px; }
.hk-row-text { font-size:14px; line-height:1.4; }
.hk-row.done .hk-row-text { color:var(--dim); text-decoration:line-through;
  text-decoration-color:var(--ok); text-decoration-thickness:1.5px; }

.hk-metrics { margin-top:26px; background:var(--card); border:1px solid var(--line); }
.hk-form { display:flex; flex-wrap:wrap; gap:6px; padding:10px 12px; align-items:center; }
.hk-input { font:inherit; font-size:13px; padding:7px 8px; border:1px solid var(--line);
  background:#fff; color:var(--ink); min-width:0; }
.hk-input:focus { outline:2px solid var(--tape); outline-offset:0; border-color:var(--ink); }
.hk-input.grow { flex:1 1 100%; }
.hk-input.num { width:64px; font-family:'IBM Plex Mono',monospace; }
.hk-fp { display:flex; align-items:center; gap:5px; font-size:12px; color:var(--dim); }
.hk-fp input { accent-color:var(--ok); }
.hk-add { font:inherit; font-size:13px; font-weight:700; padding:7px 14px;
  background:var(--tape); color:var(--ink); border:1.5px solid var(--ink); cursor:pointer; }
.hk-add:hover { background:var(--tape-soft); }
.hk-add:focus-visible, .hk-tab:focus-visible, .hk-ref-toggle:focus-visible, .hk-del:focus-visible
  { outline:2px solid var(--ink); outline-offset:2px; }

.hk-table-wrap { overflow-x:auto; }
.hk-table { width:100%; border-collapse:collapse; font-size:12.5px; }
.hk-table th { text-align:left; font-size:10.5px; text-transform:uppercase; letter-spacing:.05em;
  color:var(--dim); padding:6px 8px; border-top:1px solid var(--line);
  border-bottom:1px solid var(--line); }
.hk-table td { padding:6px 8px; border-bottom:1px dashed var(--line); vertical-align:top; }
.hk-table .num { text-align:right; }
.hk-del { background:none; border:none; color:var(--dim); font-size:15px; cursor:pointer;
  line-height:1; padding:0 4px; }
.hk-del:hover { color:#A2402E; }

.hk-ref { margin-top:22px; }
.hk-ref-toggle { font:inherit; font-size:13px; background:none; border:none; color:var(--ink);
  text-decoration:underline; text-underline-offset:3px; cursor:pointer; padding:0; }
.hk-inv { margin:10px 0 0; padding:12px 14px 12px 34px; background:var(--card);
  border:1px solid var(--line); font-size:13.5px; line-height:1.5; }
.hk-inv li { margin-bottom:6px; }
.hk-inv li::marker { font-family:'IBM Plex Mono',monospace; color:var(--tape);
  font-weight:500; }

.hk-foot { margin-top:26px; font-size:12px; color:var(--dim); border-top:1px solid var(--line);
  padding-top:10px; }

@media (max-width:560px) {
  .hk-tabs { flex-direction:column; }
  .hk-tab { display:flex; align-items:baseline; gap:8px; }
  .hk-tab-pct { margin-top:0; margin-left:auto; }
  .hk-stamp { display:none; }
}
@media (prefers-reduced-motion:reduce) {
  .hk-ply-fill { transition:none; }
}
`;
