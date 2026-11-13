---
name: ship-crew
description: Full multi-agent feature pipeline for any stack - Explore maps the repo, architect plans, the plan is debated adversarially, the user approves, developer subagents implement in parallel per area, code-reviewer reviews against layered rules (project rules, stack packs, a universal core), qa-lead writes tests and a build summary, visual-qa checks the UI in a browser. Use for any multi-file or multi-repo feature, or when the user says ship, ship-crew, build this feature end to end, plan and implement, "plan only" for just the architect + debate stage, "review" for a standalone review of the current diff, or "rules" to write the repo's own review guidelines.
disable-model-invocation: true
---

# Ship crew

Orchestrate a full feature implementation for the user's task, in any stack.

You (the main session) are the **conductor**. You do not write feature code
yourself. You spawn the custom agents listed below, pass each one a
complete brief, wait for results, and relay between them:

| Agent (`name`) | Role | Writes code? | Model |
|---|---|---|---|
| `Explore` | Step 0 recon: repo map, stack, commands, rule files | no | haiku (built-in) |
| `architect` | investigates, produces the plan | no | opus |
| `debate-challenger` / `debate-defender` / `debate-judge` | adversarial plan/impl debate (via the `debate` skill) | no | opus |
| `developer` | implements one area (repo / package / app) of the plan | yes, only in its area | sonnet |
| `code-reviewer` | independent review of the combined diff | no | opus |
| `qa-lead` | tests + `docs/build-summary.md` | tests and docs only | sonnet |
| `visual-qa` | drives a real browser against the running app | no | sonnet |
| `checker` *(optional)* | final independent gate before the report | no | your own agent |

The models are set in each agent's frontmatter, so the crew keeps its split even
when the session or `CLAUDE_CODE_SUBAGENT_MODEL` defaults to a cheaper model.
Search and file-finding go to `Explore`; anything that writes code never runs
on haiku.

### Team of models (Claude Code)

- **Advisor.** If your session has the advisor tool (`/advisor <model>`),
  consult it at four points: before Step 2 (is this plan the right approach?),
  when the same failure comes back a second time (a developer or a review loop
  that does not converge), before resolving a stack-pack selection you are
  unsure of, and before the final report. If there is no advisor, skip silently.
- **Checker.** If a `checker` agent is installed (`~/.claude/agents/checker.md`
  or the project's), run it once before Step 7 with the plan, the changed-file
  list and the review/QA verdicts, and paste its verdict into the report. If it
  is not installed, say "checker: not installed" in the report.

**Every subagent starts cold.** It sees only the brief you give it — not this
conversation, not other agents' output. Anything you leave out, it cannot know.
Pass the full plan, never a summary of it.


## Runtime: Claude Code or Codex

This skill works in both. The agents ship in two formats with the same roles
and instructions:

| | Claude Code | Codex |
|---|---|---|
| Agent files | `.claude/agents/*.md` | `.codex/agents/*.toml` |
| Names | `code-reviewer`, `debate-judge`, … | `code_reviewer`, `debate_judge`, … (underscores) |
| How to spawn | `Agent` tool, `subagent_type: "<name>"`, full brief in `prompt` | ask to spawn the agent by its `name` with the full brief |
| Parallel | several `Agent` calls in **one** message | spawn them together; Codex waits for all |

This file uses the hyphenated names. In Codex, read `-` as `_`.

**Installed as a Claude Code plugin**, the agents are namespaced:
`ship-crew:architect`, `ship-crew:code-reviewer`, … and the debate skill is
`/ship-crew:debate`. Use whichever form appears in your list of available
agents; if both exist (plugin and a copy in `.claude/agents`), prefer the
namespaced one. Files next to this skill (`review/`, `assets/`,
`../debate/SKILL.md`) are at the same relative paths either way.

- Spawn one-shot agents. In Claude Code **do not pass `name:` / `team_name:`**
  (teammate mode): a named spawn can sit idle and never receive its prompt.
- Subagents may inherit the parent's permissions. Read-only roles are read-only
  by their instructions — repeat "read-only" in their brief.

## Modes (read from the user's request)

| Phrase | Effect |
|---|---|
| *(nothing)* | full pipeline, plan debate on 2 axes (`approach`, `contract`) |
| `plan only` | Steps 1–2 only, then stop with the plan. No code. |
| `skip debate` / `no debate` | both debate steps off |
| `debate full` | plan debate on every relevant axis **and** implementation debate |
| `debate implementation` | implementation debate also runs |
| `debate <axes>` (e.g. `debate cost,operability`) | overrides axis choice |
| `skip context docs` | context docs off (see below) |
| `skip visual qa` | Step 6 off |
| `text plan` | Step 2 in chat even when `lavish` is installed |
| `review` | standalone review of the current diff: Step 0 + Step 4 only, no plan, no code |
| `rules` | write the repo's own review guidelines (see **Rules mode**), no feature work |
| `learn <bug>` | turn an escaped bug (description, commit, issue link) into a project review rule (see **Learning**) |
| `debate` | force the plan debate on a small task that would otherwise skip it |

**Small-task auto-lite** — after Step 1, if the plan touches one area, at most
~3 files, and no high-stakes trigger below, skip the plan debate (unless the
user said `debate`) and say so in one line. Step 6 is skipped anyway when no UI
changed. Review and the approval gate always run.

**High-stakes auto-escalation** — regardless of the default, run the plan debate
on 3 axes with 3 independent judges when the plan touches any of:

- a new/changed DB schema, a migration, or a new index
- an auth path — guard, role check, token claim, session
- a money/billing/balance path
- a cross-repo API contract (backend endpoint + generated client elsewhere)
- a new shared abstraction other code will be told to copy
- anything hard to reverse — data migration, public URL, stored format

Say which trigger fired and the agent count before spawning.

## Context docs (optional, on when the project has them)

Turn on if `docs/tasks/` or `docs/features/` exists, or the user asks for
"context docs". Then:

- **task context:** architect creates `docs/tasks/active/<YYYY-MM-DD>-<slug>.md`
  from `assets/task-template.md` (in this skill folder — pass its absolute path) and pastes the plan in;
  qa-lead ticks the ship checklist and moves it to `docs/tasks/completed/`.
  This makes work resumable in a fresh session.
- **app context:** architect reads `docs/features/<feature>.md` for invariants
  ("Regression Risk"); qa-lead updates them, or seeds missing ones from `assets/feature-template.md`.

Tell each agent explicitly whether context docs are on — they cannot see this
skill.

## Before Step 1 — gather what agents cannot

Subagents inherit your tools, but you are the one who knows the conversation.
Collect up front and put in the architect brief: the full task text, links
(Figma, tickets, specs) and anything you fetched from them, which repos/areas
exist in the workspace, and the active modes.

## Pipeline

### Step 0 — Recon (Explore)

Spawn `Explore` (read-only, "medium" breadth) once per workspace and ask for a
short factual report, not file dumps:

- areas: each repo / package / app folder, its language and framework;
- the stack signals it found (`package.json` deps, `composer.json`, `go.mod`,
  `pyproject.toml` / `requirements*.txt`, `Gemfile`, `pom.xml` / `build.gradle`,
  `Cargo.toml`, migration folders, ORM schema files);
- how to build, test and lint each area (the actual scripts / commands);
- every review-rule file: `REVIEW.md`, `review-guidelines.md`,
  `.github/review-guidelines.md`, `.github/claude/review-guidelines.md`,
  `CONTRIBUTING.md`, `AGENTS.md` / `CLAUDE.md` per area;
- whether `docs/tasks/` or `docs/features/` exist (context docs).

In Codex (no built-in `Explore`), or if spawning it fails, do the recon yourself with read-only commands.

Use the report to pick the **review packs** (below) and put it, verbatim, in the
architect brief. In `review` mode this is the only recon you need.

### Review rules — three layers

The code-reviewer applies, from strongest to weakest:

1. **Project rules** found in Step 0. They win everywhere they speak.
2. **Stack packs** in `review/` next to this file, selected by the stack
   signals. Read each pack's `Detect:` line and choose the packs whose signal
   is present in a *changed* area. Typical picks:

   | Signal | Pack |
   |---|---|
   | any `.ts` / `.js` in the diff | `typescript.md` |
   | `react`, `next`, `react-native`, `expo` in deps | `react.md` |
   | `@nestjs/*`, `express`, `fastify`, `hono`, `@trpc/*`, an ORM in a Node area | `node-backend.md` |
   | `composer.json` (Laravel, Symfony, WordPress) | `php-laravel.md` |
   | `pyproject.toml` / `requirements*.txt` | `python.md` |
   | `go.mod` | `go.md` |
   | migrations, schema files or queries changed | `sql-migrations.md` |
   | an LLM / agent SDK in deps, prompts or tool definitions changed | `llm.md` |
   | `.github/workflows/`, `.gitlab-ci.yml`, `Dockerfile`, `*.tf`, k8s / Helm, serverless config changed | `ci-infra.md` |

   No pack fits (Rust, Ruby, Java, Swift/Kotlin…) → core only; the reviewer still
   reads the project rules and neighbouring code.
3. **`review/core.md`** — always.

Pass the **absolute paths** of `core.md` and the chosen packs in the reviewer
brief, plus the project rule files Step 0 found. The reviewer cannot see this
skill folder otherwise.

A repo without its own rules gets generic reviews forever. Once a review run
is done, offer `rules` mode if Step 0 found no project rule file.

### Step 1 — Plan

Spawn `architect` with the brief above and the Step 0 report. Wait for the plan. It must contain:
Goal, Affected Areas, Files to Change, API Contract, Work Units per area,
Execution Order, Risks & Open Questions, Decisions, Behaviour and flow (with a
Mermaid diagram).

### Step 1.5 — Debate the plan (default ON)

Skip only on opt-out. Otherwise read the `debate` skill (`../debate/SKILL.md`
next to this skill folder) and follow its protocol in full with the plan as the
subject — do not improvise a shorter version.

- Subject = the architect's plan (+ task file path if context docs are on).
  Motion = the plan's Goal in one sentence.
- **Isolation is the mechanism.** The challenger never sees the architect's
  rationale; the defender never sees the challenger's points. Only you see both.
- **Upheld blocking points** → spawn a fresh `architect` with the original brief
  + its plan + the verdicts, for a revised plan. **One revise cycle max**, then
  the user decides.
- **`UNRESOLVED` tradeoffs** → carry them verbatim into Step 2.
- **Zero admissible points** → say so and move on. A plan that survived a real
  attack is a result.

The debate advises. It never gates.

### Step 2 — Approval gate (STOP)

This is the point where the user decides, so give them the whole picture at
once: the plan **and** what the debate did to it. The content is the same
whether it is shown as a page or as text.

#### What to show, in this order

1. **Goal** in one sentence; active modes; which high-stakes triggers fired.
2. **Choices for you** — first, because the plan cannot be approved while they
   are open:
   - every `UNRESOLVED` debate tradeoff as a card: the question, each option
     with its cost, and the judge's note — all taken from the debate record;
   - every open question from plan §7, as the architect wrote it, with the
     context it gave. Do not invent options or costs the architect or judges
     did not state.
3. **Decisions** (plan §8) with why and the rejected alternative.
4. **Flow** — the Mermaid diagram from plan §9, plus what changes for the user
   and what is out of scope.
5. **Risk map** — one row per area: red (auth, money, schema/migration,
   cross-repo contract, hard to reverse), yellow (shared code, new dependency,
   config), green (the rest), with the reason. Keep it: Step 7 uses it.
6. **What the debate changed** — upheld blocking points and how the revised
   plan answers each; rejected points in one line each. If the debate was
   skipped, say so.
7. **Work** — areas, work units, execution order (parallel vs sequential);
   files to change and the API contract (collapsed on a page).

#### How to show it

- **Decision page.** If a `lavish` skill is installed (in your skill list),
  invoke it and build one HTML page with the sections above, following the
  guidance that skill gives you (it fetches its own CLI instructions; do not
  improvise its commands). Write it to `docs/plans/<YYYY-MM-DD>-<slug>.html`
  if the repo has a `docs/` folder, otherwise to a temporary folder, and tell
  the user the path. Then run the review loop the skill describes.
- **Text.** In the chat, same sections, same order, the flow as a Mermaid code
  block. Use text when there is no `lavish` skill, when the user asked for
  `text plan`, in Codex unless the page is known to work there, and whenever
  the page fails (the command errors, no browser opens, the loop returns
  nothing). Say why you fell back; never let the gate stall on the page.

#### Handling the user's response (both ways)

- **An answer to a choice** → record it. Recorded answers go verbatim into
  every later `architect` brief and into the `developer` briefs as fixed
  decisions.
- **A change request** (page comment or chat) → spawn a fresh `architect` with
  the original brief, its plan, the debate verdicts, the recorded answers and
  the requests verbatim. Show the result the same way again and mark what
  changed since the previous version. This is separate from the debate's
  one-revise limit.
- **Approval** must be an explicit statement from the user ("go", "approved",
  "yes", or the same words written on the page). Submitting annotations,
  answering choices, silence, or closing the page is **not** approval. Every
  choice must be answered before approval counts; if one is open, ask for it.

**Stop and wait** for that approval. Do not resolve tradeoffs yourself.

On approval: in `plan only` mode, **end here** — offer to save the plan as
`docs/plans/<YYYY-MM-DD>-<slug>.md` next to the page, and write no code.
Otherwise go to Step 3.

### Step 3 — Implementation (parallel per area)

Spawn one `developer` per affected area from the plan. Independent areas →
spawn them **all at once** so they run in parallel. Each brief contains:

- the approved plan, in full
- **its area only** (e.g. `backend/`) and the explicit list of paths it must
  not touch
- the exact API contract from the plan
- its ordered work units, and "one commit per unit" if the user uses commits
  in this flow (ask once if unclear)
- "follow the `AGENTS.md` / `CLAUDE.md` files in your area"

If work is genuinely sequential (frontend needs the real backend response), run
the backend `developer` first, then the frontend one with the final contract.

Developers run to completion — there is no live channel. A mid-flight
correction from the user is held until they return, then folded into a
follow-up spawn.

### Step 4 — Review

Spawn `code-reviewer` with the combined list of changed files per repo, the
approved plan (for contract verification), and the rule layers: project rule
files, absolute paths of the chosen packs and of `review/core.md`.

For a large diff (roughly 40+ files or several areas), split the review: one
`code-reviewer` per area in parallel, each with that area's files and packs,
then merge and de-duplicate their findings yourself.

`CHANGES REQUESTED` → spawn a fresh `developer` for the owning area with the
blocking findings pasted in, then a fresh `code-reviewer` on the result. Do not
go to QA until review is `APPROVE`.

If the user dismisses a finding (false positive, intended, out of scope), see
**Learning** below before moving on.

### Step 4.5 — Debate the implementation (conditional)

Only on `debate full`, `debate implementation`, or a high-stakes trigger that
the built code actually touched. Run **after** review is `APPROVE`, never
instead of it.

- Subject = the combined diff. Read it first, pick the 3 axes where a real
  choice was made.
- Give the *challenger only* the bare titles of the reviewer's findings under
  "another pipeline owns these — do not re-report them". Titles only.
- Upheld blocking → fresh `developer` with them, then fresh `code-reviewer`.
- "Worth doing" → offer to the user. Never auto-fix.

### Step 5 — QA

Spawn `qa-lead` with the plan, the changed-file list, the review verdict, and
whether context docs are on. It writes tests where the area has a test setup,
runs them, and writes `docs/build-summary.md`.

### Step 6 — Visual QA (only if UI changed)

If the plan touched a web UI and a browser MCP (e.g. Playwright) is configured,
spawn `visual-qa` with: affected routes, dev server URL if known, the Figma URL
if one was provided, breakpoints (default 375 / 768 / 1440), and dependent
flows from the plan. Skip silently for backend-only changes; if no browser MCP
is available, tell the user visual QA was skipped and why.

Blockers → fresh `developer` (frontend area) with them, then re-run `visual-qa`.
Nits may be deferred with the user's okay.

### Before the report — checker and advisor

Run `checker` if installed, and consult the advisor if available (see **Team of
models**). A checker `FAIL` with a concrete scenario goes back to a fresh
`developer` like a review blocker; anything vaguer goes to the user as an open
item.

### Step 7 — Final report

```
## Shipped: <task>

**Files changed:** per area
**Tests added:** ...
**Review verdict:** ...
**Read yourself:** the files in the red rows of the Step 2 risk map, with the hunks that changed
**Build summary:** docs/build-summary.md
**Debate record:** docs/reviews/<date>-<slug>-debate.md (if a debate ran)
**Visual QA:** docs/visual-qa/<date>-<slug>/report.md (if it ran)
**Review layers:** project rules used, packs applied
**Checker:** verdict (or "not installed")
**Proposed rule changes:** learned `Do not report` lines / new rules awaiting approval (if any)
**Context docs updated:** (if on)
**Open items / blockers:** ...
```

## Rules mode — write the repo's own review guidelines

Triggered by `rules`. Goal: replace generic packs with the project's real
failure modes, in the format of `assets/review-guidelines-template.md`.

1. Step 0 recon as usual.
2. Spawn `architect` (read-only) per area with: the Step 0 report, the template
   path, `review/core.md` and the matching packs as a *starting list*, and this
   job: find how the area does auth, ownership checks, transactions, money,
   config, errors, generated clients, migrations; read `git log` for fix
   commits (`fix`, `hotfix`, `revert`, `bug`) of the last ~6 months and what
   they fixed; keep only rules this codebase can actually violate, phrased with
   its own names (its guard, its helper, its folder); add "Do not report"
   entries for things the linter, generated code or the team's conventions
   already cover.
3. Show the user the draft per area. On approval, write it to
   `.github/claude/review-guidelines.md` in that area (or where the user says).
   If the file already exists, merge: keep every existing rule and every
   `Do not report` entry (they may be learned ones), add new rules after them,
   and show the diff instead of a fresh draft. Do not commit.

## Learning — the review gets better with every run

Project rules beat generic packs, so every correction goes into the project's
own guidelines file (`.github/claude/review-guidelines.md` in the area, or the
rule file Step 0 found; create it from the template if there is none). Nothing
is written without the user's approval, and nothing is committed.

- **A dismissed finding.** When the user rejects a review finding (in Step 4,
  in `review` mode, or on the page), propose one `Do not report` line in the
  project's terms: what not to flag and why it is safe here (e.g. "raw SQL in
  `reports/` — read-only replica, inputs are enum-validated in
  `ReportQuery`"). Narrow beats broad: never propose silencing a whole core
  rule. Show the line and the target file; append on approval.
- **An escaped bug** (`learn <bug>`: a description, a fix commit, an issue or
  incident link). Spawn `architect` (read-only) with it, the Step 0 report and
  the current rule files, to find: the root cause and the failing scenario;
  the code path; why review would have missed it (no rule, rule too vague,
  wrong layer); and a rule in the guidelines format (mechanism, how to spot it
  in a diff, the fix with the project's helper), severity by the core
  definitions. Show it; append on approval. If the rule is not specific to
  this project, also print it as a suggested addition to the matching stack
  pack, for the user to send upstream.
- **End of every run** — if findings were dismissed or the user named a bug
  that review missed, list the proposed rule changes once in the final
  report rather than interrupting the pipeline for each.

## Rules

- Never skip the approval gate. Never write code before it.
- Never skip review before QA.
- Never skip the plan debate without an opt-out phrase, and never move it after
  implementation — its whole value is being early.
- Never break debate isolation to "help" a side.
- The debate advises; only the user gates.
- Independent developers always run in parallel; developers never cross areas.
- Any agent reports a blocker → stop and ask the user. Do not paper over it.
- Every agent gets the relevant part of the plan in full, not the original task
  alone.
- Agents are one-shot. To follow up, spawn a fresh one with the previous result
  pasted in, rather than relying on a thread's memory.
