# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

Languages: {{LANGUAGES}}. Default base branch: `{{BASE_BRANCH}}`.

**No AI attribution** in commits or PRs. **Plan before non-trivial code.** **Smallest sufficient change**: unrequested scope goes to the user, never silently into the diff. Detail for each lives in `.claude/rules/`. Those rules load every session at this file's priority, so keep this file and them short.

## Orientation

Load the `{{PROJECT_NAME}}-ground-truth` skill before non-trivial work. If a skill covers the topic, follow it instead of inventing project rules. When a skill says MUST, treat it as a hard constraint, and apply a rule to every file you touch, not just the first.

## Source of truth

`.claude/`, `.codex/`, `.opencode/`, `.agents/`, and the root `AGENTS.md` are generated from `agents/`. Edit there, then run `bash agents/scripts/sync_agents.sh`. Available agents and skills are surfaced by the runtime, so they aren't listed here.
