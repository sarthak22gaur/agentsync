# Contributing

This is a personal project shared as-is. Issues and PRs are welcome but not guaranteed a response.

## Layout

- `skills/agentsync/SKILL.md` — the driver logic (bootstrap + reconcile modes).
- `skills/agentsync/templates/` — the canonical scaffold copied into a target project's `agents/` directory.
- `.claude-plugin/` — plugin and marketplace manifests.

## Editing templates

The templates under `skills/agentsync/templates/` are the source of truth for what a scaffolded project gets. Placeholders use `{{PROJECT_NAME}}`, `{{PROJECT_DESCRIPTION}}`, `{{BASE_BRANCH}}`, `{{LANGUAGES}}`, `{{REPO_SHAPE}}` and are substituted at scaffold time.

## Before opening a PR

- Run `bash -n` on any shell script you touch.
- Run `claude plugin validate .` to confirm the manifests still parse.
- Smoke-test a bootstrap into a throwaway temp dir and confirm `.claude/`, `.codex/`, `.opencode/`, and `.agents/skills/` populate. Do not commit the throwaway.
- No AI attribution in commit messages.
