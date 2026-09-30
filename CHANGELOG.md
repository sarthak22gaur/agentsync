# Changelog

Notable changes per release. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-09-29

### Changed
- **Single-source roles.** Each agent is now one file, `agents/roles/<name>.md`: canonical frontmatter (`name`, `description`, `tier`, `access`, `surfaces`, `skills`) plus optional per-surface blocks for native-only keys. The new `scripts/gen_agents.sh` (bash 3.2 and BSD awk, no Python) generates the Claude, Codex, OpenCode, and Copilot files from it. It replaces four hand-kept copies per agent, which drifted: the plan-review directive, efforts, and models already differed between surfaces in real projects. Copilot agents are now generated too, instead of being verbatim-only. Hand-written agents in `agents/<surface>/agents/` are still copied verbatim and win on a name clash, so existing layouts keep syncing unchanged.
- **Models are inherited, not pinned.** No template or bootstrap step writes a `model` anymore, on any surface. Every tool's subagents inherit the session or parent model when `model` is omitted (Claude, Codex, OpenCode, and Copilot docs all confirm this). A pinned name goes stale on renames and retirements, and in Codex an unknown slug stops the agent from starting. Bootstrap no longer asks for an OpenCode model. Roles pin only reasoning effort: `high` for architect, reviewer, and engineer, `medium` for the librarian. The code-reviewer moves from `xhigh` to `high`, because effort levels above `high` depend on the model.
- **Codex agents are auto-discovered.** Current Codex docs define project agents as standalone `.codex/agents/*.toml` files. The `[agents.<name>]` registrations that 0.2.6 made mandatory are now opt-in (`CODEX_REGISTER_ROLES="yes"`) for older releases. `base.toml` drops model-slug examples (several were retired or are retiring) and the now-default `multi_agent` / legacy `max_threads` settings.
- **Shared rules reach every surface.** Rules moved from `claude/rules/` to `rules/`, which syncs to `.claude/rules/` and is injected into the root `AGENTS.md` via a `<!-- agentsync:rules -->` marker, so Codex, OpenCode, and Copilot get them too. A `<!-- agentsync:roles -->` marker renders the agent table from `roles/`, so the roster Codex relies on can't go stale.
- **Leaner CLAUDE.md.** It drops the agent and skill rosters (the runtime surfaces both, and the checked-in lists went stale) and keeps only orientation, rule headlines, and the source-of-truth note.
- **Role bodies rewritten for current models.** Each rule is stated once instead of repeated per agent. The reviewer reports everything with severity and confidence, and whoever runs the loop filters (telling a reviewer to self-filter makes it drop real bugs). The architect verifies prior artifacts' claims, compares against standard patterns, keeps the design the size of the problem, and states each phase's expected footprint. The engineer implements at the written strength of the plan and refuses unrequested hardening.
- **orchestrate**: the session model orchestrates, and spawns are explicit (Codex doesn't self-delegate). It adds complexity tiers for per-spawn model/effort choice (from what the runtime offers, not hardcoded names), grouping of small phases, fix/reject/escalate lanes under a defect bar, diff-size watching, a 3-round cap that never asks for more, "demand the final report", one optional peer-CLI gate at the end, and a commit per phase (folded in from the unreleased per-phase-commit change). The escalation rule is also reversed: commit reviewed work and escalate on top of it, never end a long run with zero commits.
- **grill-plan** gains an adversarial/autonomous mode, defect-bar severity, required/adjacent/hypothetical classification, and a Scope Candidates section.
- Skill frontmatter for `.agents/skills/` and `.github/skills/` is now reduced by an **allowlist** (`name`, `description`, `license`, `compatibility`, `metadata`; plus Copilot's invocation keys for `.github/skills/`). The old denylist stripped a key like `hooks:` but leaked its indented children as orphaned YAML.
- The sync no longer writes `.codex/AGENTS.md` / `.opencode/AGENTS.md` (no tool reads them). Existing copies are removed only while they're still byte-identical to what agentsync wrote.
- Preflight recognizes a renamed source-of-truth dir (any subdir with `agentsync.conf`), not just `agents/`.

### Added
- **grill-converge** skill: hardens a high-stakes plan by looping autonomous adversarial grills against in-place architect amendments until a round comes back clean, then gating once with the other CLI (`codex exec --sandbox read-only` / `claude -p`). It has a decided list, defect-bar severity, "amendments clarify, not grow", and a 3-round cap.
- **Rules** `scope-discipline` (smallest sufficient change, scope gate, defect bar, frozen approved plans, tests that earn their place) and `verify-with-cli` (CLI checks over editor diagnostics; `tsc --noEmit` is a false green under TypeScript project references, so use `tsc -b`). `plan-before-code` now also keeps plan and phase references out of code, branches, commits, and PRs.
- `claude/settings.json` template setting `attribution.commit` / `attribution.pr` to `false`, the documented keys that replace the deprecated `includeCoAuthoredBy`. It's written merge-safely: never over a settings file agentsync doesn't own.
- `agentsync.conf`: `SURFACES`, `CODEX_EXEC_PREFIX` (bootstrap sets `direnv exec .` when an `.envrc` exists; generated Codex agents rewrite `cd <dir> && cmd` through it and carry a standing note), and `CODEX_REGISTER_ROLES`.
- Driver guidance for an optional deterministic post-edit type-check reminder: a path-filtered `command` hook that emits `additionalContext` JSON. PostToolUse plain stdout never reaches the model, and an unfiltered LLM-judged `prompt` hook can stop an agent mid-task.
- The sync warns when the rendered `AGENTS.md` exceeds Codex's default 32 KiB project-doc limit.
- **Upgrades by version** entry for 0.3.0, covering migration to `roles/`, dropping pinned models, and moving rules.

### Fixed
- `apply_gitignore.sh` no longer passes the multi-line block through `awk -v`, which BSD awk (macOS) rejects.
- `apply_gitignore.sh` and `sync_github.sh` were committed without the executable bit, so syncing depended on bootstrap's `chmod`. All scripts are now `100755`, and they call each other via `bash`.

## [0.2.6] - 2026-06-04

### Fixed
- **Codex custom agents now actually load.** Through 0.2.5, the Codex sync wrote standalone `codex/agents/*.toml` definitions and a comment-only `base.toml`, on the assumption that Codex auto-discovers `.codex/agents/`. It does not. Verified against `codex-cli` 0.137.0: a role is spawnable **only** when declared in `.codex/config.toml` under `[agents.<name>]` with a `config_file` pointing at its definition, **and** only when the project is trusted — otherwise `spawn_agent` returns `unknown agent_type` and the agents are invisible/unusable. (Standalone-file auto-discovery, project-local config in an untrusted project, and registration-via-absolute-path in an untrusted project all fail; registration in a trusted project succeeds — confirmed end-to-end for all four roles, including the hyphenated `code-reviewer`.) `sync_codex.sh` now rebuilds `.codex/config.toml` from the `codex/configs/` fragments and **appends an `[agents.<name>]` registration for each agent** under `codex/agents/` (reusing the agent's own `name`/`description`, with `config_file = "agents/<name>.toml"` resolved relative to `.codex/`). Reconcile picks this up for existing projects via a new **Upgrades by version** entry.
- `sync_codex.sh` no longer depends on the `compgen` bash builtin (absent from some minimal/Nix bash builds, where the old `compgen -G` guard silently produced an empty `config.toml`). It uses the same `-f`-guarded glob idiom as `_lib.sh`.

### Added
- Codex `base.toml` now ships a global `[agents]` block (`max_threads = 6`, `max_depth = 2`) and `[features] multi_agent = true` (the delegation feature; stable and on by default, set explicitly so it survives a default change), plus header comments documenting the two things that trip people up: **the project must be trusted** for the `.codex/` layer to load, and **Codex has no agent picker** — you invoke a role by asking Codex to delegate ("use the architect sub-agent…"). The same guidance is surfaced in the rendered `AGENTS.md`, `agents/README.md`, and the bootstrap report's Next steps.
- Rendered `AGENTS.md` now explains how **skills** surface in Codex. Skills needed no structural change — they are auto-discovered under `.agents/skills/` (verified against 0.137.0: a skill dir there is loaded and listed; `./skills/` is not), and `normalize_skill` already strips the frontmatter keys Codex rejects (e.g. `argument-hint`). The confusion was the same as for agents: Codex has **no per-skill `/` entry** like Claude Code — skills are listed under `/skills` and invoked by name (or pulled in by the model when the task matches), and load only in a trusted project. `orchestrate` is now also listed in the AGENTS.md skills table.

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
