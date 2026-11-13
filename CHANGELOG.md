# Changelog

The plugin version lives in `.claude-plugin/plugin.json`. Plugin users only get
an update when it changes, so bump it with every release and tag `vX.Y.Z`.

## 1.2.0
- Claude Code plugin and marketplace manifests (`/plugin install ship-crew --marketplace Sporium/ship-crew`).
- Repository renamed from `ship-pipeline` to `ship-crew`.
- Decision page at the approval gate: open choices, decisions, Mermaid flow, risk map, what the debate changed; via `lavish` when installed, text otherwise. `text plan` mode.
- Architect plan gains Decisions and Behaviour and flow sections.
- The review learns: dismissed findings become narrow `Do not report` lines; `learn <bug>` turns an escaped bug into a project rule; `rules` merges instead of overwriting.
- Small-task auto-lite: the plan debate is skipped for one-area, ~3-file, non-high-stakes plans; `debate` forces it.
- Final report lists red-risk files to read yourself and proposed rule changes.

## 1.1.0
- Skill renamed `ship` -> `ship-crew`.
- Step 0 recon via `Explore`.
- Layered review: project rules > stack packs > `review/core.md` (28 rules). Packs: typescript, react, node-backend, php-laravel, python, go, sql-migrations, llm, ci-infra.
- `review` and `rules` modes; review-guidelines template.
- developer, qa-lead, visual-qa pinned to sonnet; optional advisor and `checker` gates.

## 1.0.0
- The `ship` pipeline: architect, adversarial debate, approval gate, parallel developers, code review, QA, visual QA. Claude Code and Codex.
