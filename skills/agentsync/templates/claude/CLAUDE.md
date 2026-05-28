# {{PROJECT_NAME}} — Claude Rules

{{PROJECT_DESCRIPTION}}

Languages: {{LANGUAGES}}. Default base branch: `{{BASE_BRANCH}}`.

---

## Skill Discipline

Consult `.claude/skills/{{PROJECT_NAME}}-ground-truth/` first for project orientation. Do not invent project rules; if a skill covers the topic, follow it.

When loading skills, follow rules literally. "MUST" is a hard constraint. Apply rules to every file you touch, not just the first.

---

## Available Agents

- `/architect` — design authority, produces plans
- `/code-reviewer` — plan-driven code review
- `/librarian` — keeps `agents/` in sync with reality
- `/engineer` — feature and bug implementation

## Available Skills

- `/grill-plan` — stress-test a plan before delegating work
- `/{{PROJECT_NAME}}-ground-truth` — project source of truth (read this first)

## Hard Rules

See `.claude/rules/` for binding constraints. The non-negotiable ones:
- `no-commit-attribution.md` — no AI attribution in commits or PRs
- `plan-before-code.md` — plan + approval before non-trivial implementation
