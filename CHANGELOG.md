# Changelog

Notable changes per release. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.2.5] - 2026-06-01

### Changed
- **orchestrate is now multi-surface.** It shipped in 0.2.4 marked Claude-only via a `context:` frontmatter line (which trips `is_delegator_skill` and excludes a skill from the Codex/OpenCode/GitHub fan-out), on the mistaken assumption that only Claude Code spawns subagents. Codex and OpenCode both have a subagent/delegation model (Codex surfaces the role agents as named subagents — e.g. the `engineer`/`code-reviewer` as Wrench/Auditor — via the `nickname_candidates` in their TOMLs). The skill's body was already surface-agnostic ("delegate to the `engineer` / `code-reviewer`," never a Claude-specific tool call), so removing the marker is the whole change: orchestrate now fans out to `.agents/skills/` and `.github/skills/` alongside `.claude/`. On GitHub Copilot the loop is guidance rather than an auto-driven cycle (Copilot models it as declarative handoffs), but the skill is valid there. Reconcile strips the stray `context:` line from projects that installed the 0.2.4 form (new Upgrades-by-version entry).

## [0.2.4] - 2026-06-01

### Added
- **orchestrate** skill (`templates/skills/orchestrate/`). A Claude-only delegator that drives an approved plan to clean, verified implementation: the main session reads the plan, then for each phase loops `engineer` (implement) → `code-reviewer` (review the phase diff) → `engineer` (fix blocking findings) until the reviewer returns clean, then runs the plan's stated verification — advancing phase by phase. The orchestrator never edits code itself, caps the per-phase fix loop (default 3 rounds) and escalates to the user instead of looping forever, and stops before committing. Marked Claude-only via `context:` frontmatter, so `is_delegator_skill` keeps it out of the Codex/OpenCode/GitHub fan-out (subagent orchestration is a main-session capability; the `engineer` agent itself can't spawn subagents). Reconcile picks it up for existing projects via a new **Upgrades by version** ledger entry.

## [0.2.3] - 2026-05-29

### Fixed
- Codex `base.toml` no longer hardcodes a model. It first shipped `model = "REPLACE_ME"` (a non-placeholder literal the driver sometimes left dangling); a pinned id is fragile anyway — a model the user's Codex auth/version doesn't expose shows up as "custom" and makes agents that inherit it fail to load. `base.toml` now leaves `model` commented out so Codex uses its own default (the latest available for that auth), with guidance for pinning one deliberately.

### Added
- Per-surface model defaults during bootstrap, surfaced in the final report (Step 5 **Models** section) so the user sees exactly what was set:
  - **Claude** — `architect` → `opus` (Opus 4.8), the other three → `sonnet` (Sonnet 4.6); aliases that track the latest of each tier.
  - **Codex** — Codex's own default model (none pinned).
  - **OpenCode** — the driver **asks** which model to use (multi-provider, no safe default); fail-safe — a `model:` line is written only when a real value is given, never an unsubstituted placeholder.
- Code-reviewer agents (all surfaces) gain a **"Reviewing architect plans"** directive — review plans thoroughly, validating every decision against the actual code (cite `path:line`), no rubber-stamping — and **extra-high reasoning effort** (Claude `effort: xhigh`, Codex `model_reasoning_effort = "xhigh"`).
- **Version-aware upgrades.** Bootstrap stamps `AGENTSYNC_VERSION` into `agents/agentsync.conf`. On reconcile, agentsync compares the stamp to the running version and applies the enhancements of every newer version from a new **Upgrades by version** ledger in the skill — merging into customized files, preserving user prose — then advances the stamp. So running agentsync after upgrading brings an existing project up to date (e.g. picks up the 0.2.3 code-reviewer changes above).

## [0.2.2] - 2026-05-28

### Changed
- **Merge-safe sync.** The sync scripts no longer assume they exclusively own each surface output dir. Previously every script ran a blanket `rm -rf <dir>/*` (or `rm -f`) before copying, wiping any skill/agent/rule another generator or the user kept in `.claude/skills/`, `.agents/skills/`, `.github/skills/`, the agent dirs, etc. Now each managed dir carries a hidden `.agentsync-manifest` recording the entries agentsync owns; on every sync only previously-owned entries that left the source are pruned, and unowned (foreign) entries are preserved untouched. This lets agentsync share a directory with another skill generator instead of clobbering it.
- `_lib.sh` is now sourced by all four sync scripts and provides the shared ownership-scoped helpers (`sync_prune_owned`, `sync_dir_files`, `sync_skill_dirs_verbatim`). bash 3.2 compatible.

### Added
- Driver detection of **co-owned surface dirs** (both modes): before the first sync (bootstrap) and during audit (reconcile, sixth audit class), the driver scans surface dirs for content another tool generated — e.g. files stamped `generated by … / do not edit` — and reports the co-ownership plus the reciprocal-clobber risk (the other tool may delete agentsync's skills on its next run, which agentsync cannot prevent). Lets the user decide before sharing a dir an aggressive cleaner owns.

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
