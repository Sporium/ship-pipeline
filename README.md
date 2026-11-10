# ship — a multi-agent feature pipeline for Claude Code and Codex

An architect plans the feature, the plan gets debated, you approve it, developers build it in parallel, then a reviewer and QA check the result:

```
/ship <task>   (Claude Code)   ·   $ship <task>   (Codex)
  │
  ├─ 1   architect ............ reads the code, writes the plan (read-only)
  ├─ 1.5 debate ............... challenger ⟷ defender per axis, isolated → judge
  ├─ 2   ⛔ YOU APPROVE ........ the plan, plus the tradeoffs the debate left open
  ├─ 3   developer × N ........ one per area (backend/, web/, admin/…), in parallel
  ├─ 4   code_reviewer ........ APPROVE / CHANGES REQUESTED → loops back to developer
  ├─ 4.5 debate (optional) .... on the implementation, after review passes
  ├─ 5   qa_lead .............. tests + docs/build-summary.md
  ├─ 6   visual_qa ............ browser screenshots at 3 breakpoints (UI changes only)
  └─ 7   final report
```

The main session acts as the conductor. It never writes feature code itself. Every subagent starts with no context, so the conductor gives each one a complete brief.

## Quick start

```bash
git clone https://github.com/Sporium/ship-pipeline
./ship-pipeline/install.sh /path/to/your/repo            # Claude Code + Codex
./ship-pipeline/install.sh /path/to/your/repo --codex    # Codex only
```

## What's inside

```
skills/ship/              — the conductor (pipeline, modes, rules); the same file for both tools
  assets/                 — task / feature doc templates (optional context docs)
  agents/openai.yaml      — Codex: turns off auto-invocation (Claude ignores it)
skills/debate/            — adversarial debate protocol, also usable on its own
  references/refutation-taxonomy.md — 12 attacks, admissibility, scoring rules
agents/claude/*.md        — 8 agents for Claude Code (code-reviewer, debate-judge, …)
agents/codex/*.toml       — the same 8 agents for Codex (code_reviewer, debate_judge, …)
codex-config.example.toml — recommended [agents] settings + optional Playwright MCP
install.sh
```

The skills follow the shared SKILL.md format, so one copy works in both tools. The agents have different formats in each tool but the same instructions. Each skill has a short "Runtime" section that tells the conductor how to spawn agents in whichever tool it's running in.

## Install

```bash
./install.sh /path/to/repo            # into a repo, for both Claude Code and Codex
./install.sh --user                   # into ~, available in every project
./install.sh /path/to/repo --codex    # Codex only   (or --claude)
./install.sh /path/to/repo --force    # overwrite existing files
```

| | Claude Code | Codex |
|---|---|---|
| Skills | `.claude/skills/{ship,debate}` | `.agents/skills/{ship,debate}` |
| Agents | `.claude/agents/*.md` | `.codex/agents/*.toml` |
| Run | `/ship …`, `/debate …` | `$ship …`, `$debate …` |

**Codex extra steps:**
1. Merge `codex-config.example.toml` into `~/.codex/config.toml`. The main setting is `agents.max_concurrent_threads_per_session = 8`, because the first debate round runs 6 agents in parallel.
2. Project-scoped `.codex/agents` only load in a **trusted** project.
3. Restart Codex and check that `/skills` shows `ship` and `debate`.

**Claude Code:** restart the session. `/agents` should list the 8 agents. The skills don't appear in `/agents`, and the model can't see them in its own skill list either. They only run when you type `/ship` or `/debate`.

Both tools are set up to run the skills **only when you call them explicitly** (`disable-model-invocation` in Claude Code, `allow_implicit_invocation: false` in Codex). A run is expensive (10–20 agents), so it shouldn't start on its own.

## Usage

Examples use Claude Code syntax. In Codex, use `$` instead of `/`.

```
/ship add CSV export to the orders page
/ship plan only add CSV export to the orders page      # architect + debate, no code
/ship skip debate fix the pagination bug in /users     # cheap mode
/ship debate full migrate sessions from cookies to JWT # debate the plan and the implementation
/ship debate cost,operability ...                      # choose the debate axes yourself
/debate                                                # debate the current uncommitted diff
/debate quick should the cursor live in Redis or in a DB TTL index?
```

Flags in the request text: `plan only`, `skip debate`, `debate full`, `debate implementation`, `debate <axes>`, `skip context docs`, `skip visual qa`.

The pipeline also auto-escalates. When the plan touches a schema/index, auth, money, a cross-repo contract, a new shared abstraction, or anything hard to reverse, the debate runs on 3 axes with 3 independent judges, and an upheld point needs 2 of 3 votes.

## Why the debate is built this way

- **Isolation.** The challenger never sees the architect's rationale, and the defender never sees the challenger's points. A critic who reads the author's reasoning first ends up agreeing with it.
- **Admissibility has a price.** Every point needs a scenario, evidence (`file:line`), an alternative, *and the cost of that alternative*. The conductor drops any point that's missing one of these before the defender sees it.
- **The defender is scored on honest concessions,** not on winning.
- **The judge verifies against the code** instead of picking the better-written argument. `UNRESOLVED` is a valid verdict, and those points go to you as explicit questions at the approval step.
- **The debate never blocks anything.** It can trigger at most one architect revision. Only you approve the plan.

## Adapting it to your project

- **Areas.** The architect splits the work into areas, meaning repos, packages or apps. The conductor starts one `developer` per area in parallel. Nothing assumes a specific stack.
- **Your rules go in `AGENTS.md` / `CLAUDE.md`.** Every agent reads them along the path to the code it touches. Put your stack, patterns and "don't do X" rules there rather than in the agents.
- **Review rules.** `code_reviewer` looks for `REVIEW.md`, `review-guidelines.md` (also under `.github/`), `CONTRIBUTING.md` and `AGENTS.md`. If your repo has CI review guidelines, the local review applies the same ones.
- **Context docs (optional).** If the repo has `docs/tasks/` or `docs/features/`, the architect creates a task file from the template and qa_lead archives it after ship. This makes a task resumable in a new session, and the feature docs record invariants for regression checks. To turn this on, run `mkdir -p docs/tasks/active docs/features`.
- **Model.** In Claude Code, architect, review and debate run on `opus`, and the rest inherit the session model. In Codex the agents only set `model_reasoning_effort` (high for the same roles), and the model comes from your session or from `agents.default_subagent_model`.
- **Read-only roles.** In Claude Code they only get the Read/Grep/Glob/Bash tools. In Codex, subagents inherit the parent sandbox, so those roles stay read-only because their instructions say so.
- **Editing.** The skills are a single shared copy. Agents live in two copies (`agents/claude` and `agents/codex`), so when you change an agent's instructions, change both files.
- **visual_qa** needs a browser MCP (Playwright). Without one, the step is skipped and the run says so.

## Output files

| File | Written by |
|---|---|
| `docs/tasks/active → completed/<date>-<slug>.md` | architect → qa_lead (if context docs are on) |
| `docs/reviews/<date>-<slug>-debate.md` | conductor, after a debate |
| `docs/build-summary.md` | qa_lead |
| `docs/visual-qa/<date>-<slug>/` | visual_qa |
