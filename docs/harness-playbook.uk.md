# Harness Framework — покроковий playbook з прикладами

Усі приклади прив'язані до реального репо **MebleSaaS** (Go + chi + sqlc + goose + PostgreSQL, React/TS фронт). Підстав свої назви, якщо працюєш в іншому репо. Кожен крок — конкретна дія з очікуваним результатом.

---

## Крок 0. Підготовка (30 хв, один раз)

**0.1.** Заведи гілку для harness-роботи і директорію метрик:

```bash
cd ~/dev/meblesaas
git checkout -b harness-setup
mkdir -p .claude docs/harness
touch docs/harness/metrics.md
```

**0.2.** Створи `docs/harness/metrics.md` — сюди пишеш після КОЖНОЇ значущої сесії:

```markdown
# Harness Metrics Log

| Дата | Задача | Підхід | Токени | $ | First-pass? | Хв людини | Нотатка |
|------|--------|--------|--------|---|-------------|-----------|---------|
| 2026-07-02 | baseline audit | no harness | 45k | 0.80 | — | 20 | до CLAUDE.md |
```

Звідки брати цифри: команда `/cost` в кінці сесії показує токени і вартість поточної сесії. Записуй одразу, потім не відновиш.

**0.3.** Переконайся, що `claude --version` актуальний (`npm update -g @anthropic-ai/claude-code` за потреби, деталі — https://docs.claude.com/en/docs/claude-code/overview).

---

# ТИЖДЕНЬ 1

## L01. Perception-gap аудит + CLAUDE.md v1 + surface map

### Крок 1.1 — Baseline аудит (без CLAUDE.md)

Тимчасово прибери CLAUDE.md, якщо він уже є:

```bash
mv CLAUDE.md CLAUDE.md.bak 2>/dev/null; claude
```

У чистій сесії постав ці 10 питань (адаптовані під MebleSaaS — заміни під свій репо). Питання став ПО ОДНОМУ, не списком:

1. Опиши архітектуру цього проєкту в 5 реченнях.
2. Де живе логіка генерації списку деталей з параметрів виробу?
3. Як запустити всі тести? А один пакет?
4. Як у нас робляться міграції БД і де вони лежать?
5. Яка конвенція для sqlc-запитів — де .sql файли, як регенерувати код?
6. Як реалізовано multi-tenancy? Що не можна зламати?
7. Який flow AI-рендеру — від скріншота Three.js до картинки клієнту?
8. Які зовнішні сервіси викликає бекенд і де їхні клієнти?
9. Яка конвенція error handling у Go-коді цього проєкту?
10. Що в цьому репо легасі/заморожене, що не можна чіпати?

### Крок 1.2 — Оцінка відповідей

Створи `docs/harness/perception-gap.md`:

```markdown
# Perception Gap Audit

## Baseline (без CLAUDE.md), 2026-07-02

| # | Питання | Оцінка | Що саме не так |
|---|---------|--------|----------------|
| 1 | Архітектура | partial | не знає про поділ seller/tech view |
| 2 | Генерація деталей | wrong | вказав на неіснуючий пакет |
| 3 | Тести | correct | — |
| 4 | Міграції | partial | знайшов goose, але не знає naming convention |
| 5 | sqlc | wrong | вигадав шлях до queries |
| 6 | Multi-tenancy | hallucinated | описав middleware, якого немає |
| ... | | | |

Score: 3/10 correct
```

Оцінки: `correct` / `partial` / `wrong` / `hallucinated` (найгірше — впевнено вигадав).
**Кожен рядок ≠ correct — це рядок майбутнього CLAUDE.md.** Це головний інсайт уроку: CLAUDE.md пишеться не "про проєкт", а "проти конкретних помилок".

### Крок 1.3 — Surface map

Створи `docs/surface-map.md` (~1 сторінка, приклад для MebleSaaS):

```markdown
# Surface Map — MebleSaaS

## Entry points
- `cmd/api/main.go` — HTTP API (chi router)
- `cmd/worker/main.go` — фонові задачі (рендер, розкрій)

## Критичні модулі (зміни тут = обов'язкове ревʼю людини)
- `internal/details/` — генерація списку деталей з params JSONB. Серце продукту.
- `internal/tenant/` — multi-tenancy. Кожен запит фільтрується по company_id.
- `internal/cutting/` — bin packing розкрій. Алгоритм FFD, не чіпати без бенчмарків.

## Стандартні модулі (агент може працювати вільно)
- `internal/api/handlers/` — HTTP handlers
- `internal/db/` — згенерований sqlc код. НЕ редагувати руками, тільки через .sql + sqlc generate.
- `web/src/` — React фронт

## Конфіги / генерація
- `sqlc.yaml`, `db/queries/*.sql` → `sqlc generate`
- `db/migrations/` → goose, формат `NNNNN_name.sql`

## Зовнішні сервіси
- Replicate API (AI рендер) — клієнт у `internal/render/replicate.go`
- Railway PostgreSQL — DATABASE_URL з env

## Тут дракони
- `internal/legacy_import/` — старий xlsx-імпорт, буде переписаний. Не рефакторити.
```

### Крок 1.4 — CLAUDE.md v1

Пиши тільки те, що закриває рядки ≠ correct з кроку 1.2. Приклад:

```markdown
# MebleSaaS

B2B SaaS для меблевих компаній: продавець збирає виріб у параметричному
3D-конструкторі → система генерує список деталей, AI-рендер і карту розкрою
→ тех.відділ бачить картку замовлення.

## Stack
Go 1.23 (chi, pgx/v5, sqlc, goose) · PostgreSQL 16 · React+TS+Three.js · Railway

## Команди
- Тести: `go test ./...` · один пакет: `go test ./internal/details/`
- Лінт: `golangci-lint run`
- sqlc: правиш `db/queries/*.sql` → `sqlc generate`. Код у `internal/db/` НЕ редагувати руками.
- Міграції: `goose -dir db/migrations create <name> sql` → `goose up`. Формат down-міграції обов'язковий.
- Фронт: `cd web && npm run dev` / `npm test`

## Конвенції
- Errors: wrap через `fmt.Errorf("details: generate: %w", err)`, sentinel errors у `errors.go` пакета.
- Кожен tenant-scoped запит МУСИТЬ мати `company_id` у WHERE. sqlc-запит без нього — блокер на ревʼю.
- HTTP handlers тонкі: парсинг + виклик сервісу + маппінг помилки. Логіка — в `internal/<domain>/`.
- Params виробів — JSONB, схема описана в `internal/details/params.go`. Нові поля — тільки через неї.

## Заборони
- Не редагувати `internal/db/` (generated) і `internal/legacy_import/` (заморожено).
- Не запускати міграції проти прод-бази. Локально — тільки `make db-reset`.

## Карта проєкту
Див. `docs/surface-map.md` — читай перед задачами, що зачіпають >1 модуль.
```

### Крок 1.5 — Повторний аудит

Нова сесія (`/clear` або перезапуск), ті самі 10 питань, друга таблиця в `perception-gap.md`. Ціль: **≥8/10 correct**. Що досі не correct — допиши в CLAUDE.md. Запиши в metrics.md обидві сесії.

---

## L02. Skills Layer + slash-команди

### Крок 2.1 — Розділи факти й процедури

Пройди CLAUDE.md рядок за рядком:
- **Факт** ("у нас chi", "params — JSONB") → лишається в CLAUDE.md.
- **Процедура** ("як писати тести", "як робити ревʼю", "як додавати міграцію") → виноситься у Skill.

CLAUDE.md завантажується в контекст ЗАВЖДИ. Skill — тільки коли релевантний. Тому процедури в CLAUDE.md — це податок на кожну сесію.

### Крок 2.2 — Skill №1: go-testing

```bash
mkdir -p .claude/skills/go-testing
```

`.claude/skills/go-testing/SKILL.md`:

```markdown
---
name: go-testing
description: >
  Як писати Go-тести в MebleSaaS. Використовуй ЗАВЖДИ коли пишеш або
  редагуєш *_test.go файли, додаєш нову функціональність (спочатку тест!),
  або коли тести падають і треба зрозуміти конвенції.
---

# Go Testing — MebleSaaS

## Правила
1. Table-driven tests за замовчуванням. Ім'я кейсу — людською мовою: `"box without facades generates only carcass details"`.
2. БД-тести: справжній PostgreSQL через testcontainers, НЕ моки sqlc.
   Хелпер: `internal/testutil/db.go` → `testutil.NewDB(t)` дає ізольовану схему.
3. Зовнішні API (Replicate): інтерфейс + фейк у `internal/render/fake.go`. httpmock не використовуємо.
4. Assertions: `require` для передумов, `assert` для перевірок. Бібліотека testify.
5. Тест на генерацію деталей ЗАВЖДИ перевіряє і кількість, і розміри, і edge-поля.

## Шаблон
```go
func TestGenerateDetails(t *testing.T) {
    tests := []struct{
        name   string
        params details.Params
        want   []details.Detail
    }{
        {name: "box 800x2000x600 two shelves", params: ..., want: ...},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) { ... })
    }
}
```

## Анти-патерни
- Тест, що дублює реалізацію (перевіряє виклик, а не результат)
- `time.Sleep` — тільки synctest або канали
```

### Крок 2.3 — Skill №2 і №3

За тим самим шаблоном:
- `.claude/skills/code-review/SKILL.md` — критерії ревʼю: tenant-фільтр у кожному запиті, N+1 у циклах з БД-викликами, error wrapping, розмір handlers, відсутність логіки у згенерованому коді. Description: "Використовуй коли ревʼюїш код, дивишся diff, або перед створенням PR".
- `.claude/skills/db-migrations/SKILL.md` — naming, обов'язковий down, backward-compatible зміни (спочатку add column nullable → backfill → not null окремою міграцією), заборона `DROP` без явного погодження.

### Крок 2.4 — Slash-команди

```bash
mkdir -p .claude/commands
```

`.claude/commands/spec.md`:

```markdown
---
description: Згенерувати spec.md для фічі
---
Створи файл specs/$ARGUMENTS/spec.md за шаблоном:

# Spec: <назва>
## Проблема — 2-3 речення, чому це потрібно користувачу
## Scope — що входить
## Non-scope — що ЯВНО не входить (мінімум 3 пункти)
## Acceptance criteria — нумерований список, кожен пункт ПЕРЕВІРЮВАНИЙ
   (формат: "Коли X, тоді Y". Жодних "має працювати добре")
## Edge cases — мінімум 5
## Обмеження — сумісність, продуктивність, безпека (tenant isolation!)

Перед генерацією: прочитай релевантний код і docs/surface-map.md.
Постав мені уточнюючі питання, якщо scope неоднозначний. НЕ пиши код.
```

`.claude/commands/plan.md`:

```markdown
---
description: Згенерувати plan.md зі spec
---
Прочитай specs/$ARGUMENTS/spec.md. Створи specs/$ARGUMENTS/plan.md:

## Кроки — нумеровані, кожен: що робимо / які файли / як перевіряємо
## Порядок — тести перед реалізацією (TDD)
## Ризики — що може піти не так, план Б
## Out of scope guard — які файли НЕ чіпаємо

Кожен крок має закінчуватись зеленими тестами. НЕ починай реалізацію.
```

`.claude/commands/commit.md`:

```markdown
---
description: Conventional commit зі staged змін
---
Подивись `git diff --staged`. Згенеруй conventional commit:
тип(scope): опис ≤72 символи, body — ЩО і ЧОМУ (не ЯК).
Типи: feat/fix/refactor/test/chore/docs. Scope = пакет (details, cutting, api...).
Якщо staged порожній — скажи про це, нічого не роби. Не додавай файли сам.
```

### Крок 2.5 — Triggering-тест

10 запитів у нових сесіях, лог у `docs/harness/triggering-test.md`:

| Запит | Очікую | Спрацював? |
|---|---|---|
| "додай тест на генерацію полиць" | go-testing | ✅/❌ |
| "подивись цей diff перед PR" | code-review | |
| "додай поле edge_type у details" | db-migrations | |
| "поясни що робить FFD алгоритм" | нічого | |
| "запусти dev-сервер" | нічого | |

Якщо Skill не тригериться — проблема в `description`: додай туди конкретні слова-тригери ("тест", "*_test.go", "ревʼю", "diff", "міграція", "ALTER TABLE"). Якщо тригериться зайвий раз — звузь ("ТІЛЬКИ коли...").

### Крок 2.6 — Дотисни CLAUDE.md до ≤200 рядків

```bash
wc -l CLAUDE.md
```

Все, що виніс у Skills, — видали з CLAUDE.md, лишивши однорядкові вказівники не треба (Skills самі тригеряться). Комміт: `feat(harness): skills layer + slash commands`.

**Чек тижня 1:** perception-gap до/після ≥8/10 · CLAUDE.md ≤200 рядків · 3 Skills · 3 команди · triggering 10/10 · metrics.md має ≥4 записи.

---

# ТИЖДЕНЬ 2

## L03. Субагенти: Hub-and-Spoke vs Peer Mesh

### Крок 3.1 — Створи 5 субагентів

```bash
mkdir -p .claude/agents
```

Важливо: вміст файлу агента — це його **system prompt**, не user prompt. Пиши як інструкцію ролі.

`.claude/agents/researcher.md`:

```markdown
---
name: researcher
description: >
  Досліджує кодову базу і повертає стислий звіт. Використовуй для задач
  "де живе X", "як влаштовано Y", "що зачепить зміна Z" — перед плануванням.
tools: Read, Grep, Glob
---
Ти — дослідник кодової бази MebleSaaS. Твоя робота: прочитати все потрібне
і повернути СТИСЛИЙ звіт, а не сирі файли.

Формат відповіді (жорсткий):
## Відповідь на питання — 3-5 речень
## Ключові файли — шлях: одна фраза, що там
## Ризики/залежності — що зламається, якщо тут щось міняти
## Чого я НЕ знайшов — явно

Обмеження: НЕ пропонуй реалізацію. НЕ цитуй код блоками >10 рядків.
Твоя відповідь ≤400 слів — вона піде в контекст оркестратора.
```

`.claude/agents/test-writer.md`:

```markdown
---
name: test-writer
description: Пише failing-тести за spec ПЕРЕД реалізацією (TDD червона фаза).
tools: Read, Grep, Glob, Write, Edit, Bash
---
Ти пишеш тести за спекою ДО того, як існує реалізація.
Дотримуйся skill go-testing. Тести МАЮТЬ компілюватись і падати
(червона фаза TDD): запусти їх і переконайся, що падають з правильної причини.
Поверни: список створених тест-файлів + вивід go test (скорочений).
Реалізацію НЕ пиши — навіть заглушки понад мінімум для компіляції.
```

`.claude/agents/implementer.md` — реалізує план крок за кроком, після кожного кроку `go test ./...`, комміт на крок; не виходить за межі плану.

`.claude/agents/reviewer.md` — read-only tools (`Read, Grep, Glob, Bash`), дивиться diff за skill code-review, повертає вердикт `APPROVE` / `REQUEST_CHANGES` + список зауважень з file:line.

`.claude/agents/doc-writer.md` — оновлює README/surface-map після мержа, ≤1 екран змін.

### Крок 3.2 — Dispatch matrix

`docs/harness/dispatch-matrix.md`:

```markdown
| Тип задачі | Хто | Вхід | Вихід | Коли НЕ використовувати |
|---|---|---|---|---|
| "де/як влаштовано X" | researcher | питання | звіт ≤400 слів | якщо відповідь = 1 grep |
| нова фіча | test-writer → implementer → reviewer | spec+plan | PR | фікс ≤10 рядків |
| bugfix | test-writer (репро-тест) → implementer | опис бага | fix+тест | тривіальна одноряд. правка |
| ревʼю чужого PR | reviewer | diff | вердикт | — |
| рефакторинг | researcher → implementer → reviewer | ціль | PR | — |
| дрібні правки, питання | БЕЗ субагентів, головна сесія | — | — | — |
```

Останній рядок — найважливіший: субагент має overhead (свій контекст, свій виклик), для дрібниць він дорожчий за моноліт.

### Крок 3.3 — Експеримент: одна задача, три топології

Візьми реальну задачу середнього розміру. Приклад для MebleSaaS: **"додати параметр `back_panel` (тип задньої стінки: ДВП у паз / накладна / без) у Params і генерацію деталей"**.

**Прогін A — моноліт.** Нова сесія, одна інструкція: "реалізуй фічу X: досліди код, напиши тести, реалізуй, зроби ревʼю сам собі". Все в одному контексті. В кінці: `/cost` → запиши.

**Прогін B — hub-and-spoke.** Скинь гілку до старту (`git reset --hard start-point`, нова гілка). Нова сесія-оркестратор:

```
Реалізуй фічу back_panel через субагентів:
1. researcher: як влаштовані Params і генерація деталей, що зачепить back_panel
2. на основі звіту склади короткий план, покажи мені     ← approval stop
3. test-writer: тести за планом
4. implementer: реалізація до зелених тестів
5. reviewer: вердикт по diff
Сам код не пиши — тільки координуй і передавай стислі результати.
```

**Прогін C — peer mesh.** Знову скинь гілку. Дозволь агентам передавати результати одне одному без стискання через хаб (test-writer отримує повний звіт researcher, implementer — повний вивід test-writer). Практично: інструктуєш оркестратора "передавай виходи агентів наступному агенту повністю, без резюмування".

### Крок 3.4 — Cost-per-topology звіт

`docs/harness/topology-report.md`:

```markdown
| Метрика | A: моноліт | B: hub-spoke | C: mesh |
|---|---|---|---|
| Токени total | | | |
| $ | | | |
| Wall-clock | | | |
| Тести зелені з 1-ї спроби | | | |
| Зауваження reviewer | | | |
| Моїх втручань | | | |

## Висновок
Для задач типу ___ обираю ___, тому що ___.
Правило: ___
```

Порівняй свій 7-агентний пайплайн з цими цифрами: чи всі 7 стадій окуповуються, чи частину варто злити для дрібних задач?

---

## L04. MCP: custom server + token budget

### Крок 4.1 — Custom MCP server на Go (~50 рядків)

Кейс для MebleSaaS: read-only доступ до довідника матеріалів у локальній БД — щоб агент не вигадував розміри листів і ціни, а питав систему.

```bash
mkdir -p ~/dev/meble-mcp && cd ~/dev/meble-mcp
go mod init meble-mcp
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

	s := server.NewMCPServer("meble-materials", "0.1.0")

	tool := mcp.NewTool("search_materials",
		mcp.WithDescription("Пошук матеріалів у довіднику MebleSaaS за назвою. Повертає розміри листа, товщину, ціну."),
		mcp.WithString("query", mcp.Required(), mcp.Description("Частина назви, напр. 'ДСП' або 'Egger'")),
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
			Name                string  `json:"name"`
			Thickness           int     `json:"thickness"`
			SheetW, SheetH      int     `json:"sheet_w"`
			Price               float64 `json:"price"`
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

Підключення — `.mcp.json` у корені MebleSaaS (project-scoped, іде в git):

```json
{
  "mcpServers": {
    "meble-materials": {
      "command": "go",
      "args": ["run", "/home/rh/dev/meble-mcp/main.go"],
      "env": { "DATABASE_URL": "postgres://localhost:5432/meble_dev" }
    }
  }
}
```

Перевірка: `claude` → `/mcp` (список серверів і статус) → запит "які в нас є ДСП 18мм?" — агент має викликати tool, а не вигадати.

### Крок 4.2 — Token budget аудит

Tool definitions УСІХ підключених MCP-серверів інжектяться в кожну сесію, навіть якщо жоден tool не викликано.

1. Нова сесія → `/context` — подивись розбивку контексту, знайди частку MCP tools.
2. Побудуй таблицю в `docs/harness/mcp-budget.md`:

```markdown
| MCP server | Tools | ~токенів у КОЖНІЙ сесії | Викликів за тиждень | Вердикт |
|---|---|---|---|---|
| meble-materials | 1 | ~150 | 12 | лишаю |
| github (офіційний) | 30+ | ~15000 | 2 | ВИМКНУТИ, вистачає gh CLI |
| ... | | | | |
```

3. Все з вердиктом "вимкнути" — прибери з конфігів. Типовий результат аудиту: 1-2 "великі" сервери з'їдають більше, ніж уся твоя CLAUDE.md+Skills разом.

### Крок 4.3 — Hybrid Skill+MCP

MCP дав *доступ*, Skill дає *знання як користуватись*. `.claude/skills/materials-lookup/SKILL.md`:

```markdown
---
name: materials-lookup
description: >
  Робота з довідником матеріалів. Використовуй коли задача стосується
  матеріалів, розмірів листів, цін, розкрою — перш ніж хардкодити числа.
---
# Матеріали

1. НІКОЛИ не хардкодь розміри листа чи ціни — питай tool search_materials.
2. Стандартний лист ДСП в Україні 2800×2070, але ЗАВЖДИ перевіряй по конкретному матеріалу.
3. Якщо матеріал не знайдено — питай користувача, не підставляй схожий.
4. У розрахунках розкрою враховуй пропил 4мм (kerf) — це параметр cutting-сервісу, не матеріалу.
```

### Крок 4.4 — Правило вибору (запиши своє)

У `docs/harness/mcp-budget.md` додай висновок:

```markdown
## Правило
- live-дані / стан / auth → MCP (вузькі tools, ≤3 на сервер)
- знання і процедури → Skill
- разовий виклик, який робиться curl/gh/psql → bash-скрипт у Skill, БЕЗ MCP
- широкі офіційні сервери (30+ tools) → тільки якщо використовую ≥5 tools щотижня
```

**Чек тижня 2:** 5 агентів · dispatch matrix · topology-report з реальними цифрами · working MCP server · mcp-budget.md · hybrid пара · вимкнено ≥1 зайвий сервер.

---

# ТИЖДЕНЬ 3

## L05. Spec-Driven Development

### Крок 5.1 — Обери фічу

Критерій: 0.5–1 день ручної роботи, торкається БД + логіки + API. Приклад для MebleSaaS: **"розрахунок кромки (edge banding): для кожної деталі — які торці кромкуються, яким типом кромки, сумарні метри по типах у картці замовлення"**.

### Крок 5.2 — `/spec edge-banding`

Команда з L02 згенерує чернетку. Твоя робота сіньйора — ревʼю спеки. Приклад того, як має виглядати ГОТОВА спека:

```markdown
# Spec: Edge Banding

## Проблема
Тех.відділ рахує метраж кромки вручну з списку деталей — 10-15 хв на
замовлення, помилки в 1 з 5 випадків. Кромка має рахуватись автоматично.

## Scope
- Поля edge_top/bottom/left/right у details (тип кромки або NULL)
- Дефолтні правила кромкування за типом деталі (фасад: 4 сторони; полиця:
  1 передній торець; стінка короба: видимі торці)
- Ручний override продавцем у конструкторі
- Підсумок метрів по типах кромки в картці замовлення (+10% запас)

## Non-scope
- Кромка у карті розкрою (v2)
- Ціна кромки в калькуляторі (окрема фіча)
- Зміна існуючих замовлень (тільки нові)

## Acceptance criteria
1. Коли створюється деталь "фасад 600×800", тоді всі 4 edge-поля = дефолтний тип кромки матеріалу.
2. Коли продавець змінює edge_top на NULL, тоді метраж перераховується без цього торця.
3. Коли в проєкті 3 деталі з кромкою "ПВХ 2мм", тоді картка показує суму периметрів кромкованих торців ×1.10, округлено до 0.1 м.
4. Коли деталь без жодної кромки, тоді вона не з'являється в підсумку.
5. API: GET /projects/{id}/edge-summary повертає {type, meters}[] за ≤200мс на проєкті зі 100 деталей.

## Edge cases
- Деталь 0 кромок / всі 4
- Два різні типи кромки на одній деталі
- Радіусний фасад (кромкування по дузі) — поза scope, явна помилка валідації
- Проєкт іншого tenant → 404 (не 403!)
- Метраж при qty > 1

## Обмеження
- Міграція backward-compatible: старі details → edge_* = NULL, підсумок = 0
- Tenant isolation у кожному новому запиті
```

Правило ревʼю спеки: кожен acceptance criterion можна перетворити на тест механічно. Якщо ні — переписуй.

### Крок 5.3 — `/plan edge-banding`

Ревʼюїш план. На що дивитись: (а) тести перед реалізацією; (б) міграція окремим кроком з окремим коммітом; (в) є "out of scope guard" — список файлів, які НЕ чіпаються; (г) кожен крок закінчується зеленими тестами. Правити план — 5 хв; правити код, написаний за поганим планом — година.

### Крок 5.4 — Implement

```
Виконуй plan.md крок за кроком. Після кожного кроку: go test ./... і комміт
через /commit. Якщо крок вимагає відхилення від плану — СТОП, спитай мене.
```

Ти в цей час НЕ читаєш кожен рядок — перевіряєш комміти проти кроків плану.

### Крок 5.5 — Verify

```
Пройди acceptance criteria зі spec.md по одному. Для кожного: покажи тест
або команду, що його доводить, і результат. Формат: № критерію → доказ → PASS/FAIL.
```

FAIL → повертається в implement. Ніяких "виглядає готовим".

### Крок 5.6 — Cost breakdown + retro-spec

У `specs/edge-banding/cost.md`: `/cost` по кожній фазі (spec/plan/implement/verify), хвилини твого часу. Сенс reference-цифри "$17 за фічу" — не збігтись з нею, а ЗНАТИ свою і бачити тренд.

`specs/edge-banding/retro.md`:

```markdown
## Розбіжності spec ↔ реалізація
1. Спека не покрила qty>1 у метражі → знайшлось на verify → додати в шаблон /spec питання про кількісні поля
2. План не передбачив регенерацію sqlc після нового запиту → implementer застряг → додати в шаблон /plan крок "codegen"
## Зміни в harness
- [ ] оновити .claude/commands/spec.md
- [ ] оновити .claude/commands/plan.md
```

Кожна retro-правка робить НАСТУПНУ фічу дешевшою — це і є compound-ефект harness.

---

## L06. Quality Gates: hooks → TDD → plan-verifier → evals

### Крок 6.1 — Hook 1: авто-формат/лінт після кожного edit

```bash
mkdir -p .claude/hooks
```

`.claude/settings.json` (проєктний, іде в git — уся команда отримує ті самі гейти):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/fmt.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tests-green.sh" }
        ]
      }
    ]
  }
}
```

`.claude/hooks/fmt.sh`:

```bash
#!/bin/bash
# PostToolUse: форматує змінений файл. Не блокує (exit 0 завжди).
FILE=$(jq -r '.tool_input.file_path // empty')
case "$FILE" in
  *.go)  gofmt -w "$FILE"; golangci-lint run --fix "$FILE" 2>/dev/null || true ;;
  *.ts|*.tsx) (cd web && npx prettier --write "$FILE") || true ;;
esac
exit 0
```

### Крок 6.2 — Hook 2: блок небезпечних команд

`.claude/hooks/guard.sh`:

```bash
#!/bin/bash
# PreToolUse(Bash): exit 2 = блок, stderr іде агенту як пояснення.
CMD=$(jq -r '.tool_input.command // empty')

deny() { echo "BLOCKED: $1" >&2; exit 2; }

echo "$CMD" | grep -qE 'rm -rf (/|~|\$HOME)'        && deny "rm -rf на корінь/home"
echo "$CMD" | grep -qE 'git push.*(--force|-f)\b'    && deny "force push заборонено"
echo "$CMD" | grep -qE 'DROP (TABLE|DATABASE)'       && deny "DROP тільки через міграцію з ревʼю"
echo "$CMD" | grep -qE 'goose.*(prod|railway)'       && deny "міграції на прод — тільки руками"
echo "$CMD" | grep -qE '(cat|less|grep).*\.env($|[^.])' && deny "читання .env заборонено"

exit 0
```

Ключова семантика: **exit 2 блокує дію** (stderr повертається агенту), exit 1 — лише попередження без блокування, exit 0 — пропустити. Кожен security-hook МУСИТЬ використовувати exit 2. Hooks спрацьовують і для субагентів — гейти рекурсивні.

### Крок 6.3 — Hook 3: не завершувати з червоними тестами

`.claude/hooks/tests-green.sh`:

```bash
#!/bin/bash
# Stop: якщо тести червоні — не даємо агенту "закінчити".
INPUT=$(cat)
# захист від нескінченного циклу: якщо це вже повторний stop-hook — пропускаємо
[ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ] && exit 0

# ганяємо тільки якщо в сесії були зміни go-файлів
git diff --name-only HEAD 2>/dev/null | grep -q '\.go$' || exit 0

cd "$CLAUDE_PROJECT_DIR"
if ! go test ./... > /tmp/claude-test.log 2>&1; then
  echo '{"decision":"block","reason":"Тести червоні. Подивись /tmp/claude-test.log і виправ перед завершенням."}'
fi
exit 0
```

`chmod +x .claude/hooks/*.sh`. Перевір кожен hook вручну, подаючи JSON на stdin:

```bash
echo '{"tool_input":{"command":"git push --force origin main"}}' | .claude/hooks/guard.sh; echo "exit=$?"
# очікуємо: BLOCKED..., exit=2
```

Потім живий тест: попроси агента зробити force push — має отримати блок і пояснення.

### Крок 6.4 — Plan-verifier у CI

`.github/workflows/plan-verify.yml` — окремий агент перевіряє diff проти плану на кожному PR:

```yaml
name: plan-verify
on: { pull_request: { types: [opened, synchronize] } }
jobs:
  verify:
    runs-on: ubuntu-latest
    permissions: { contents: read, pull-requests: write }
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Verify diff against plan
        uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            У PR має бути файл specs/*/plan.md. Порівняй git diff origin/main...HEAD
            з планом: 1) чи всі кроки виконані; 2) чи є зміни файлів ПОЗА планом
            (порушення out-of-scope guard); 3) чи є кроки без тестів.
            Залиш коментар: VERDICT: PASS/FAIL + список знахідок з file:line.
            Якщо plan.md немає — FAIL "PR без плану".
```

(Синтаксис action звір з актуальним README https://github.com/anthropics/claude-code-action — параметри змінюються.)

### Крок 6.5 — Eval-набір: 20 трейсів

Це регресійний тест на сам harness. Структура:

```
evals/
  traces/
    001-edge-summary-endpoint.md   # задача + критерії перевірки
    002-tenant-filter-bug.md
    ...020-*.md
  run.sh
  results/2026-07-XX.md
```

Кожен трейс:

```markdown
# 001: endpoint edge-summary
## Prompt
Додай GET /projects/{id}/edge-summary що повертає метраж кромки по типах.
## Checks (виконуються скриптом після прогону)
- [ ] go test ./... зелений
- [ ] новий запит у db/queries має company_id у WHERE
- [ ] handler ≤40 рядків, логіка в internal/details
- [ ] є тест на чужий tenant → 404
```

`evals/run.sh` (ідея): для кожного трейсу — свіжий worktree від main, headless-прогін `claude -p "$(cat prompt)" --output-format json`, потім детерміновані checks (go test, grep по diff), запис PASS/FAIL. Ганяєш після кожної зміни CLAUDE.md/Skills/hooks → бачиш, pass rate виріс чи впав. Baseline запиши в перший results-файл.

### Крок 6.6 — Mutation report

```bash
go install github.com/zimmski/go-mutesting/cmd/go-mutesting@latest
go-mutesting ./internal/details/ > docs/harness/mutation-report.txt
```

Mutation score = частка "вбитих" мутантів. Порівняй score пакета з агентськими тестами проти пакета з твоїми ручними. Якщо агентські тести мають score помітно нижчий — тести "театральні" (перевіряють виклики, а не поведінку) → правиш skill go-testing і retro-spec.

**Чек тижня 3:** фіча через повний spec→plan→implement→verify цикл · cost.md + retro.md · 3 робочих hooks (протестовані вручну і наживо) · plan-verifier коментує PR · 20 трейсів + baseline pass rate · mutation report з висновком.

---

# ТИЖДЕНЬ 4

## L07. Паралельний fan-out: worktree × 3

### Крок 7.1 — Обери задачу, що шардиться

Критерій: механічна, однотипна, багато файлів, шарди незалежні. Приклад для MebleSaaS: **міграція логування з `log.Printf` на структурований `slog` з tenant-context у всіх internal-пакетах** (або: перехід error wrapping на єдину конвенцію; оновлення pgx v4→v5, якщо актуально).

### Крок 7.2 — Migration playbook

`docs/harness/migration-playbook-slog.md`:

```markdown
# Playbook: log.Printf → slog

## Шарди (незалежні, без перетину файлів)
- shard-a: internal/details, internal/cutting
- shard-b: internal/api, internal/tenant
- shard-c: internal/render, internal/db-адаптери, cmd/*

## Спільні правила (для ВСІХ агентів)
1. Заміна: log.Printf("...%v", err) → slog.Error("msg", "err", err, "company_id", cid)
2. Рівні: Error - помилки, Warn - деградація, Info - бізнес-події, Debug - решта
3. Логер приходить через context (хелпер internal/obs/log.go — створює shard-b ПЕРШИМ, решта чекає)
4. Жодних інших змін у файлах. Побачив баг — TODO-коментар, НЕ фіксити.
5. Кожен пакет = окремий комміт "refactor(slog): <package>"

## Інваріанти
- go test ./... зелений після кожного пакета
- жодного log.Printf у diff (перевірка: git grep -n 'log\.Printf' -- <shard>)

## Мерж-порядок
shard-b (хелпер) → shard-a → shard-c. Конфлікти розвʼязує людина.
```

Зверни увагу на залежність: спільний хелпер створює ОДИН шард першим — інші стартують після його комміту. Це типовий підводний камінь fan-out.

### Крок 7.3 — Worktrees + запуск

```bash
git checkout -b slog-base && git push -u origin slog-base
git worktree add ../meble-slog-a -b slog-shard-a
git worktree add ../meble-slog-b -b slog-shard-b
git worktree add ../meble-slog-c -b slog-shard-c
```

Три термінали, у кожному:

```bash
cd ../meble-slog-b && claude
> Виконай docs/harness/migration-playbook-slog.md, твій шард: shard-b. Починай з хелпера internal/obs/log.go.
```

(worktree ділять .git, але кожен має свою робочу копію — агенти не топчуться по файлах одне одного; CLAUDE.md/Skills/hooks працюють у кожному, бо це той самий репо.)

### Крок 7.4 — Ти = tech lead

Веди `docs/harness/fanout-log.md` у реальному часі:

```markdown
| Час | Shard | Подія | Моя дія |
|---|---|---|---|
| 14:02 | b | старт, пише хелпер | — |
| 14:15 | b | хелпер готовий, комміт | дав старт a і c |
| 14:31 | a | питає про логи в тестах | відповів: у тестах slog.Discard |
| 14:40 | c | застряг на cmd/worker (глобальний логер) | підказав патерн |
| 15:05 | a | шард готовий | ревʼю + мерж |
```

Практична стеля — 3-4 паралельні сесії на одну людину: далі час на переключення з'їдає виграш.

### Крок 7.5 — Мерж + cost delta

Мерж за порядком з playbook, `git worktree remove` після кожного. Потім `docs/harness/fanout-cost-delta.md`:

```markdown
| Метрика | Послідовно (оцінка: shard-b факт ×3) | Fan-out ×3 |
|---|---|---|
| Wall-clock | | |
| $ total | | |
| Моїх хвилин | | |
| Конфліктів мержу | | |

Висновок: fan-out для ___, НЕ для ___.
```

Очікуй: wall-clock ↓ у ~2-2.5 рази, $ приблизно той самий або трохи ↑, твоя увага ↑ помітно.

---

## L08. Plugin + CI agent + rollout

### Крок 8.1 — Запакуй harness у plugin

Плагін = усе, що ти зробив, як один встановлюваний артефакт:

```
meble-harness/
  .claude-plugin/
    plugin.json
  skills/        ← go-testing, code-review, db-migrations, materials-lookup
  agents/        ← researcher, test-writer, implementer, reviewer, doc-writer
  commands/      ← spec, plan, commit
  hooks/
    hooks.json   ← конфіг хуків
    fmt.sh guard.sh tests-green.sh
```

`.claude-plugin/plugin.json`:

```json
{
  "name": "meble-harness",
  "version": "1.0.0",
  "description": "Spec-driven harness: skills + agents + commands + quality gates"
}
```

Точну схему plugin.json і hooks-конфігу в плагіні звір з https://docs.claude.com/en/docs/claude-code — формат ще еволюціонує. Тест придатності: чистий клон репо на іншій машині + встановлення плагіна (`/plugin` у Claude Code) = повний harness за одну дію, без ручного копіювання .claude/.

### Крок 8.2 — CI agent: auto-review на кожен PR

`.github/workflows/agent-review.yml` — reviewer з L03 переїжджає в CI:

```yaml
name: agent-review
on: { pull_request: { types: [opened, synchronize] } }
jobs:
  review:
    runs-on: ubuntu-latest
    permissions: { contents: read, pull-requests: write }
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Зроби code review цього PR за критеріями зі skill code-review
            (.claude/skills/code-review/SKILL.md): tenant isolation, N+1,
            error wrapping, тонкі handlers, generated code untouched.
            Формат: вердикт + список file:line. Тільки коментуй, НЕ мерж, НЕ пуш.
```

Принцип прав: CI-агент **коментує, не мержить**. Довіру нарощуєш поступово.

### Крок 8.3 — DevDigest v1 (capstone)

Продукт, побудований ЧЕРЕЗ harness — доказ повного циклу:

1. `/spec devdigest` — щоденний дайджест активності репо MebleSaaS: комміти, PR, відкриті питання з fanout/retro-логів → markdown у Slack/Telegram/email.
2. `/plan devdigest` → implement через субагентів → verify → hooks і plan-verifier працюють по дорозі.
3. Деплой: Railway cron або GitHub Actions schedule (`cron: '0 6 * * 1-5'`), headless `claude -p` збирає дайджест.
4. Критерій "deployed": дайджест приходить сам, три дні поспіль, без твоєї участі.

### Крок 8.4 — 30-day rollout план

`docs/harness/rollout.md` (навіть якщо "команда" = ти + майбутній фронтендер):

```markdown
| Тиждень | Що вмикаємо | Метрика adoption | Відкочуємо, якщо |
|---|---|---|---|
| 1 | CLAUDE.md + Skills | perception-audit ≥8/10 у кожного | скарги на неправильні поради > 2/тиждень |
| 2 | hooks + /spec /plan /commit | 100% PR мають spec | hooks дають false-block > 1/день |
| 3 | CI agent (тільки коментує) | ≥50% зауважень агента визнані слушними | шум > сигнал |
| 4 | subagents + evals baseline | pass rate ≥ 15/20 | вартість/фічу зросла vs тиждень 1 |

Ретро наприкінці: metrics.md тиждень 1 vs тиждень 4 — $/фічу, first-pass rate, хв людини/фічу.
```

**FINAL BUNDLE:** встановлюваний plugin · CI agent живе на реальних PR · DevDigest деплойнутий і шле сам · rollout.md з метриками до/після.

---

# Наскрізний чеклист (роздрукуй)

- [ ] W1: perception-gap до/після · CLAUDE.md ≤200 · 3 Skills · /spec /plan /commit · triggering 10/10
- [ ] W2: 5 агентів · dispatch matrix · topology-report (3 прогони, цифри) · Go MCP server · mcp-budget + вимкнені зайві сервери · hybrid Skill+MCP
- [ ] W3: фіча повним циклом + cost.md + retro.md · 3 hooks (exit 2 перевірений!) · plan-verifier у CI · 20 трейсів + baseline · mutation report
- [ ] W4: migration через fan-out ×3 · playbook · fanout-log · cost delta · plugin · CI agent · DevDigest deployed · rollout.md
- [ ] metrics.md ведеться з кроку 0 і має ≥25 рядків наприкінці

Головне правило проходження: **жоден урок не зараховано, поки немає цифр.** Артефакт без виміру — демо; артефакт з виміром — інженерне рішення.
