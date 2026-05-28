# Changelog

Notable changes per release. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-05-28

### Added
- GitHub / Copilot surface. Verbatim `.agent.md` agent profiles under `agents/github/agents/` fan out to `.github/agents/`, and shared skills to `.github/skills/`. Opt-in; default surfaces stay `claude,codex,opencode`.
- Configurable `CLAUDE.md` location via optional `agents/agentsync.conf` (`CLAUDE_MD_TARGET`). Default `.claude/CLAUDE.md`; repo-root `CLAUDE.md` is a documented alternative. Absent conf keeps the default.
- `templates/scripts/_lib.sh` — shared `normalize_skill` and `is_delegator_skill`, sourced by `sync_codex.sh` and `sync_github.sh`.

### Changed
- Driver bootstraps the `github` surface and renders `agentsync.conf`; reconcile is aware of the `github` surface and of `agentsync.conf` (a root-`CLAUDE.md` layout is not flagged as drift).

## [0.1.0] - 2026-05-28

### Added
- Initial release. Bootstrap/reconcile driver, source-of-truth `agents/` tree, and sync scripts fanning agents, skills, and rules out to Claude Code, Codex, and OpenCode. Four role agents (architect, code-reviewer, librarian, engineer), two rules (no-commit-attribution, plan-before-code), the `grill-plan` skill, and a codebase-derived ground-truth skill. Packaged as a Claude Code plugin.
