# Changelog

Notable changes per release. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-05-28

### Added
- "Generated with agentsync" attribution line in the rendered `agents/README.md`, linking back to the project.
- Driver artifact guardrail (both modes): an explicit allowed-artifact set plus hard prohibitions against installing git hooks, writing under `.git/`, modifying git config, or creating any script/config/tooling outside the template set. Closes a class of bug where the driver invented non-template files (e.g. an `.git/hooks/pre-commit` and a matching `check_sync.sh`) and falsely attributed them to agentsync.
- Reconcile gains a fifth audit class — **foreign artifacts** — that surfaces things which look agentsync-installed but ship in no version (including leftovers in untracked locations like `.git/hooks/` that survive `git restore`). These are reported, never adopted or repaired; the driver must not invent a missing file an orphaned artifact references.

## [0.2.0] - 2026-05-28

### Added
- GitHub / Copilot surface. Verbatim `.agent.md` agent profiles under `agents/github/agents/` fan out to `.github/agents/`, and shared skills to `.github/skills/`. Opt-in; default surfaces stay `claude,codex,opencode`.
- Configurable `CLAUDE.md` location via optional `agents/agentsync.conf` (`CLAUDE_MD_TARGET`). Default `.claude/CLAUDE.md`; repo-root `CLAUDE.md` is a documented alternative. Absent conf keeps the default.
- `templates/scripts/_lib.sh` — shared `normalize_skill` and `is_delegator_skill`, sourced by `sync_codex.sh` and `sync_github.sh`.
- `OUTPUT_TRACKING` config knob (`all` / `root-docs` / `none`). The sync keeps a delimited block in the workspace `.gitignore` matching the policy, preserving everything outside the block.

### Changed
- Default generated-output tracking is now `root-docs` (commit entrypoint docs, gitignore the bulky regenerable dirs) — a deliberate change from 0.1.0's commit-everything. Set `OUTPUT_TRACKING="all"` to keep the old behavior.
- Driver bootstraps the `github` surface and renders `agentsync.conf`; reconcile is aware of the `github` surface, of `agentsync.conf` (a root-`CLAUDE.md` layout is not flagged as drift), of the `OUTPUT_TRACKING` policy (gitignored output dirs are not flagged as missing surfaces), and now re-derives `AGENTS.md`/`CLAUDE.md` generated fields when auditing for staleness.

## [0.1.0] - 2026-05-28

### Added
- Initial release. Bootstrap/reconcile driver, source-of-truth `agents/` tree, and sync scripts fanning agents, skills, and rules out to Claude Code, Codex, and OpenCode. Four role agents (architect, code-reviewer, librarian, engineer), two rules (no-commit-attribution, plan-before-code), the `grill-plan` skill, and a codebase-derived ground-truth skill. Packaged as a Claude Code plugin.
