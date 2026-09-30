---
name: agentsync
description: Bootstrap OR reconcile a multi-surface agent/skill system in any project. On a fresh project, scaffolds a source-of-truth agents/ directory with single-source role files (architect, code-reviewer, engineer, librarian) generated for Claude Code, Codex, OpenCode, and GitHub Copilot, shared hard rules, the grill-plan / grill-converge / orchestrate skills, and sync scripts, then analyzes the codebase to generate a project ground-truth skill. On a project that already has a setup, audits it for gaps, sync drift, stale ground-truth, and version upgrades, then updates it in place without clobbering customizations. Use when starting a new project, onboarding agents into an existing one, or refreshing an existing agent setup.
argument-hint: "[project-name] — optional; defaults to basename of cwd"
---

# agentsync

Bootstrap an agent/skill system in any project from a single source-of-truth `agents/` directory plus sync scripts that fan it out to `.claude/`, `.codex/`, `.opencode/`, `.github/`, the shared `.agents/skills/`, and the root `AGENTS.md`.

The templates this skill copies from live alongside it at `${CLAUDE_PLUGIN_ROOT}/skills/agentsync/templates/` when installed as a plugin, or `~/.claude/skills/agentsync/templates/` when installed standalone. They're the canonical version: edit them there to evolve future scaffolds.

**This skill is agentsync `0.3.0`.** (Release chore: bump this string with every version.) Bootstrap stamps it into `agents/agentsync.conf` as `AGENTSYNC_VERSION`. On reconcile, compare the project's stamped version with this one. If this one is newer, apply the intervening versions' enhancements (see [Upgrades by version](#upgrades-by-version)) and re-stamp.

## How the source of truth is shaped

- `roles/<name>.md`: **one file per agent.** Canonical frontmatter (`name`, `description`, `tier`, `access`, `surfaces`, `skills`) plus optional per-surface blocks (`claude:`, `codex:`, `opencode:`, `github:`) holding keys only that tool understands. `scripts/gen_agents.sh` derives each tool's native file from it. This replaces the pre-0.3.0 layout of four hand-kept copies per agent, which drifted apart.
- `rules/*.md`: shared hard rules. They go to `.claude/rules/` and are injected into the root `AGENTS.md`, which Codex, OpenCode, and Copilot read. Claude-only rules can live in `claude/rules/`.
- `skills/<name>/SKILL.md`: shared skills, fanned out to `.claude/skills/`, `.agents/skills/`, and `.github/skills/` (frontmatter trimmed to portable keys for the non-Claude targets).
- `claude/agents/`, `codex/agents/`, `opencode/agents/`, `github/agents/` (all optional): hand-written, verbatim, single-surface agents. A verbatim file wins over a generated one with the same name.

### Model policy: inherit, don't pin

Role files set **no `model`** on any surface. Every tool inherits by default: a Claude subagent without `model` falls back to the main conversation's model; Codex subagents inherit the parent's model and effort; OpenCode subagents use the invoking primary agent's model; Copilot uses the model picker's selection. Pinned model names go stale on renames and retirements, and on Codex an unknown slug stops the agent from starting. Roles pin only **reasoning effort** via `tier` (Claude `effort`, Codex `model_reasoning_effort`). The defaults are `high` for architect, code-reviewer, and engineer, and `medium` for the librarian. These levels are supported broadly; `xhigh` and `max` depend on the model, so opt into them per project. Per-spawn model choices (a cheaper model for a mechanical phase) belong in the `orchestrate` skill at run time, not in the role files. Pin a model only when the user asks, by adding `model:` to that role's surface block.

---

## Preflight — Choose Mode

1. Confirm cwd is the target project root (or the workspace root for a multi-repo workspace).
2. **Detect mode by checking for an existing setup.** The source-of-truth dir is usually `agents/`, but users sometimes rename it (e.g. `<project>-agents/`, kept as its own repo inside a multi-repo workspace). Treat any immediate subdir holding `agentsync.conf` or `scripts/sync_agents.sh` as the source of truth, and use its real name wherever this skill says `agents/`.
   - Found → **Mode B: Reconcile** (jump to the Reconcile section).
   - Only `.claude/agents/` etc. exist, with no source-of-truth dir → the project was set up by hand. Tell the user, and offer to adopt it into the source-of-truth model via Reconcile (treat the existing `.claude/` as the seed). Get explicit approval before moving anything.
   - Neither exists → **Mode A: Bootstrap** (continue below).
3. Detect repo shape:
   - cwd has `.git/` → **single-repo** layout (templates land in `./agents/`)
   - cwd has no `.git/` but immediate subdirs do → **multi-repo workspace** (templates land in `./agents/` at the workspace root, beside the sub-repos)
   - Neither → ask the user.

---

# Mode A: Bootstrap (fresh project)

## Step 1 — Gather inputs

Ask the user for the following. Offer defaults, and batch the questions unless one is genuinely ambiguous.

| Input | Default | Notes |
|---|---|---|
| `project_name` | basename of cwd, kebab-cased | Used in the `<project>-ground-truth` skill name and in READMEs |
| `project_description` | (ask) | One sentence: what the project is |
| `primary_languages` | inferred from manifest files | e.g. `python`, `typescript`, `go`, `rust` |
| `base_branch` | `main` | `develop` if a `develop` branch already exists. In a multi-repo workspace, check each repo: they can differ, and then the ground-truth should list them per repo |
| `surfaces` | `claude codex opencode` | Any of `claude codex opencode github`. `github` (Copilot) is opt-in |
| `claude_md_target` | `.claude/CLAUDE.md` | Offer root `CLAUDE.md` as the alternative |
| `repo_shape` | detected | `single` or `multi` |

Don't ask about models (see the model policy above).

Detect, don't ask:
- **Environment loader.** If the project root or any sub-repo has an `.envrc` (direnv/Nix), set `CODEX_EXEC_PREFIX="direnv exec ."` in `agentsync.conf`. Codex shells don't load it, so without the prefix agents conclude tools are "not installed". Also add a short **Environment** section to `agents/AGENTS.md`: tools come from the direnv environment; for one-shot commands use `cd <repo> && direnv exec . <cmd>`; retry through the prefix before concluding a tool is missing.
- **TypeScript project references.** If a root `tsconfig.json` has `"files": []` plus `references`, the `verify-with-cli` rule's `tsc -b` caveat applies. Make sure the ground-truth names `tsc -b` (or the build script) as the type-check command, never `tsc --noEmit`.

Language inference: `pyproject.toml`/`requirements.txt` → python; `package.json` → typescript (with `tsconfig.json`) or javascript; `Cargo.toml` → rust; `go.mod` → go; `Gemfile` → ruby; several → list all.

---

## Step 2 — Copy and render templates

Copy the agentsync templates directory into `<workspace-root>/agents/`, renaming `AGENTS.md.tmpl` → `AGENTS.md` and `README.md.tmpl` → `README.md`. Substitute placeholders in every text file:

| Placeholder | Replacement |
|---|---|
| `{{PROJECT_NAME}}` | `project_name` |
| `{{PROJECT_DESCRIPTION}}` | `project_description` |
| `{{BASE_BRANCH}}` | `base_branch` |
| `{{LANGUAGES}}` | comma-joined `primary_languages` |
| `{{REPO_SHAPE}}` | `single` or `multi` |
| `{{SURFACES}}` | space-joined `surfaces` |
| `{{AGENTSYNC_VERSION}}` | this skill's version (see top) |

Then:
- Delete `agents/codex/` if `codex` isn't a selected surface, and `agents/claude/` if `claude` isn't. Leave the role files alone: `SURFACES` decides what gets generated.
- In `agents/agentsync.conf`, set `CLAUDE_MD_TARGET`, `OUTPUT_TRACKING` (default `root-docs`), and `CODEX_EXEC_PREFIX` if Step 1 detected an environment loader.
- In a **multi-repo workspace**, keep the `base.toml` note that `codex` must be launched from the workspace root. Codex treats the nearest `.git` as the project root, so launching inside a sub-repo skips workspace-level config.
- `chmod +x agents/scripts/*.sh`. The scripts also call each other via `bash`, so a lost exec bit doesn't break the sync.

**Optional: post-edit type-check reminder (Claude).** When the project has a CLI type-check, you may add a deterministic hook to the engineer role's `claude:` block so every edit to a matching source file reminds the agent to run it. It must be a `command` hook, filtered by path, that exits 0. A `prompt` (LLM-judged) hook with no path filter fires on every edit and can stop the agent mid-task. PostToolUse **plain stdout never reaches the model**, so emit the reminder as `additionalContext` JSON:

```yaml
claude:
  hooks:
    PostToolUse:
      - matcher: "Edit|Write"
        hooks:
          - type: command
            command: |
              jq -r '.tool_input.file_path // empty' | grep -qE '\.tsx?$' && printf '%s' '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Reminder: run `npx tsc -b` in the edited package before reporting done."}}' || true
```

Adjust the path regex and command per project (`jq` required). Offer this; don't add it silently.

---

## Step 3 — Generate the project ground-truth skill

This is the load-bearing step. Don't skip it, and don't bloat it.

Read, in this order:
- `README.md` at the project root (if it exists)
- Top-level manifest files (`pyproject.toml`, `package.json`, etc.)
- For multi-repo: each sub-repo's README and manifest
- The top-level directory tree (`ls` at the root, no recursion)
- The `docs/` directory listing, if it exists

Synthesize a single skill file at `agents/skills/{{project_name}}-ground-truth/SKILL.md`. Use this exact template:

```markdown
---
name: {{project_name}}-ground-truth
description: Architecture, repo layout, stack, commands, and conventions for {{project_name}}. Use for orientation before any non-trivial work in this project.
---

# {{Project Name}} Ground Truth

{{one-paragraph project description — what it is, who uses it, the core capability}}

## Repos / Layout

{{For single-repo: top-level directory roles. For multi-repo: each sub-repo's purpose and its default branch. One line each, no fluff.}}

## Primary Stack

- **{{language/framework}}**: {{1-line role}}
- ...

## Commands

{{The authoritative CLI commands per repo/package: install, type-check, lint, test, build. Verify each exists in the manifest. These are what agents run to verify work.}}

## Entry Points

{{Key files an engineer touches first when implementing a feature. Cite `path:line` where possible.}}

## Conventions

{{Project-specific norms detected from code/README: base branch, lockfile policy, test runner, formatter. Skip if unknown.}}

## What This Skill Is Not

Live code behaviour, current bug list, or in-flight work. For those, read the code or the relevant plan/issue.
```

**Anti-bloat rules** (agents read this skill constantly, so keep it dense):
- No marketing prose.
- Every line carries information. If a section has nothing concrete, omit it.
- No invention. If you can't ground a claim in the README, a manifest, or the directory tree, leave it out.
- Cap it at ~80 lines unless the project genuinely has more than 5 sub-repos.
- Lead the `description` with what the skill covers and when to use it. Runtimes truncate skill listings, and the start of the description is what survives.

If the project has clearly distinct domains (e.g. `frontend/` + `backend/`), you MAY generate up to 2 additional `agents/skills/<area>-patterns/SKILL.md` files with the same discipline, covering only conventions specific to that area. Stop at 1 ground-truth plus up to 2 patterns.

If the project has distinct areas with their own engineer/reviewer needs, you MAY suggest splitting a role (e.g. `backend-engineer` / `frontend-engineer`) by copying its role file. `orchestrate` routes phases by area. Only do it if the user agrees.

---

## Step 4 — First sync

Before syncing, scan the surface output dirs (`.claude/skills/`, `.agents/skills/`, `.github/skills/`, the agent dirs, and `.claude/settings.json`) for content agentsync didn't generate, especially files carrying another tool's "generated by … / do not edit" banner or a foreign manifest. The sync is merge-safe and preserves them, but if another generator co-owns a dir, report it (see "Shared output directories" in Hard Rules).

```
cd <workspace-root>
bash agents/scripts/sync_agents.sh
```

Confirm `.claude/agents/`, `.claude/skills/`, `.claude/rules/`, the CLAUDE.md target, and the per-surface equivalents exist. If the sync printed `skipped .claude/settings.json`, the user already had one: show them the `attribution` block from `agents/claude/settings.json` and offer to merge it in by hand.

---

## Step 5 — Report

Print:

```
## Agents bootstrapped for {{project_name}}

### Source of truth
- agents/  (agentsync {{AGENTSYNC_VERSION}} — stamped in agents/agentsync.conf)
- roles/ → generated for: <surfaces>

### Agents (4)
- architect, code-reviewer, engineer, librarian

### Skills
- grill-plan, grill-converge, orchestrate
- {{project_name}}-ground-truth (generated)
- <area>-patterns (if generated)

### Rules (shared: .claude/rules/ + AGENTS.md)
- no-commit-attribution, plan-before-code, scope-discipline, verify-with-cli

### Models
- Inherited on every surface (none pinned). Reasoning effort per role: architect/code-reviewer/engineer high, librarian medium.
- Codex commands run through `<CODEX_EXEC_PREFIX>`   # if set

### Next steps
1. Review agents/roles/*.md and tailor role bodies to {{project_name}}.
2. Review agents/skills/{{project_name}}-ground-truth/SKILL.md, especially the Commands section.
3. Re-run `bash agents/scripts/sync_agents.sh` after every edit under agents/.
4. Codex: trust the project on first `codex` run (agents and skills load only when trusted), then delegate by name: "spawn the architect agent to…".
```

---

# Mode B: Reconcile (existing setup)

Goal: bring an existing `agents/` setup back to full health — close gaps, fix sync drift, refresh stale ground-truth — **without clobbering the user's customizations.** The template is the *baseline*, not the *override*. A user-edited agent file is the source of truth for its role description; you only add what's missing and fix what's demonstrably wrong.

This is an **audit → report → approve → apply** loop, not a re-scaffold. Never blind-copy templates over existing files.

## R1 — Inventory the existing setup

Read what's there:
- `agents/agentsync.conf`: the `AGENTSYNC_VERSION` stamp — the agentsync version that last generated/reconciled this project. Absent (or no conf) → treat as pre-`0.2.3`, the earliest. Compare it to this skill's version (top of file): if this skill is newer, every intervening version's [Upgrades by version](#upgrades-by-version) entry is in scope.
- `agents/` tree: which roles (`roles/`) or legacy per-surface agents (`claude/agents/`, `codex/agents/`, …), skills, rules (`rules/`, `claude/rules/`), surfaces (`SURFACES` in the conf), and scripts exist.
- `agents/skills/*-ground-truth/SKILL.md`: the current ground-truth.
- The synced targets: `.claude/`, `.codex/`, `.opencode/`, `.github/`, `.agents/skills/`, root `AGENTS.md`.

## R2 — Audit against six gap classes

Compare and collect findings. Do NOT fix yet.

**1. Structural gaps** — diff the live `agents/` tree against the template baseline in the agentsync templates directory:
- Missing role agents (e.g. template has `engineer`, project lacks it).
- Missing surfaces (e.g. project has `claude/` + `codex/` but not `opencode/`, and the user wants all three). `github/` is opt-in — only flag it as missing if the user uses Copilot.
- Read `agents/agentsync.conf` if present: a root-`CLAUDE.md` layout (`CLAUDE_MD_TARGET="CLAUDE.md"`) is intentional, not sync drift. Under `OUTPUT_TRACKING=none`/`root-docs`, a gitignored output dir (`.claude/` etc.) being absent or untracked is expected — never flag it as a missing surface.
- `.gitignore` agentsync block drifts from `OUTPUT_TRACKING` → propose re-applying the policy (the re-sync fixes it).
- Missing shared rules (`no-commit-attribution`, `plan-before-code`, `scope-discipline`, `verify-with-cli`), in `rules/` (or, pre-0.3.0, `claude/rules/`).
- Legacy per-surface agents with no `roles/` → propose the 0.3.0 migration to single-source roles (see the ledger).
- Missing or outdated sync scripts (compare script bodies; flag if the template script has fixes the local one lacks).
- A role present in one surface but not another (legacy layout), or per-surface copies of one agent whose directives have drifted apart. This is the main argument for migrating to `roles/`.

**2. Sync drift** — does each target match its source?
- Run the sync into a scratch copy of the project, or diff the generated output against the current targets. A generated file that differs from what the sync would write means someone edited the target directly (anti-pattern) or forgot to sync. A common case is a model or effort bumped by hand in `.claude/agents/*.md`.
- Flag direct-target edits explicitly — those edits will be lost on next sync and must be back-ported into `agents/` first.

**3. Stale generated content** — re-analyze the codebase (same reads as Mode A Step 3) and diff reality against generated content.

*Ground-truth skill:*
- Documented paths/modules/dirs that no longer exist → stale, propose removal.
- New top-level dirs, sub-repos, or stack components not documented → gap, propose addition.
- Stack/version/base-branch changes (manifest diff) → propose update.
- Entry points cited with `path:line` that have moved → re-anchor.

*`agents/AGENTS.md` and `agents/claude/CLAUDE.md` — derived fields only:* re-derive the generated fields (project description, `Languages:`, base branch, agent roster table) and diff against what each file currently holds. Propose refreshing only the fields that drifted. This is a surgical field refresh — preserve all hand-written prose, never rewrite the file.

**4. Version upgrades & content drift** — the templates improve across versions:
- **Version-gated:** if the project's `AGENTSYNC_VERSION` (R1) is older than this skill, walk the [Upgrades by version](#upgrades-by-version) ledger and collect every entry newer than the stamp — new directives, effort/model changes, etc. These are concrete, known enhancements to apply.
- **Ad-hoc drift:** also catch directives present in the current template roles, rules, and skills that the project lacks but that aren't tied to a version bump.
- In both cases the action is **merge** the addition in, preserving the user's project-specific role prose — never wholesale overwrite.

**5. Foreign artifacts** — things that look agentsync-installed but are not in the template set:
- Git hooks, scripts, or config stamped with "agentsync" attribution that no agentsync version ships (e.g. a `.git/hooks/pre-commit` calling a nonexistent `check_sync.sh`). Check untracked locations like `.git/hooks/` — they survive `git restore` and outlive prior runs.
- **Report these, do not adopt or repair them.** Never invent the missing file an orphaned artifact references. See the Artifact guardrail in Hard Rules.

**6. Co-owned surface dirs** — another generator writing into a dir agentsync also writes:
- Skills/agents in `.claude/skills/`, `.agents/skills/`, `.github/skills/`, etc. that carry another tool's "generated by … / do not edit" banner, or a foreign manifest the other tool maintains. The sync preserves them (merge-safe), but the other tool may delete agentsync's skills on its next run.
- **Report the co-ownership and the reciprocal-clobber risk** so the user decides. See "Shared output directories" in Hard Rules.

## R3 — Report

Present a single findings table before touching anything:

```markdown
## Reconcile findings for {{project_name}}

### Structural gaps
- [ ] <missing item> → <proposed action>

### Sync drift
- [ ] <target> diverges from <source> — <direct edit? / unsynced?> → <action>

### Stale generated content
- [ ] <ground-truth claim, or AGENTS.md/CLAUDE.md derived field> no longer matches code → <propose edit>

### Version upgrades (AGENTSYNC_VERSION <stamp> → <this version>)
- [ ] <version>: <enhancement from the ledger> → <propose merge>

### Content drift (template improvements)
- [ ] <agent/skill> missing <directive> → <propose merge>

### Foreign artifacts (report only — do not adopt)
- [ ] <artifact> looks agentsync-installed but ships in no version → flag for the user to remove

### Co-owned surface dirs (report only)
- [ ] <dir> also written by <other generator> → merge-safe sync preserves it, but their tool may delete agentsync's skills; user decides

### Nothing to do
- <list what's already healthy>
```

Ask the user which findings to apply. Default recommendation: apply all structural gaps and sync-drift back-ports; apply stale-ground-truth and content-drift edits only with the diff shown.

## R4 — Apply (only approved findings)

- **Structural gaps**: copy the missing template file into `agents/`, render placeholders. For a new surface, add it to `SURFACES` (plus `codex/configs/` for Codex).
- **Sync drift from direct-target edits**: back-port the target's edit into the `agents/` source first, then re-sync (so the edit survives). Confirm with the user which version wins if both diverged.
- **Stale ground-truth**: edit the ground-truth skill surgically. Same anti-bloat discipline as Mode A — remove dead claims, add only grounded new ones, cap length. Never pad.
- **Stale AGENTS.md/CLAUDE.md fields**: edit the source (`agents/AGENTS.md`, `agents/claude/CLAUDE.md`) — only the drifted derived fields — then re-sync. Leave hand-written prose untouched.
- **Version upgrades & content drift**: merge each approved enhancement into the existing role (or legacy agent) file. Keep the user's role prose, insert the missing directive, and apply the effort change. Show the diff.
- **Migration to `roles/`** (0.3.0): for each agent, write `roles/<name>.md` whose body starts from the most complete existing variant (usually the Claude one), folding in any directive only another surface's copy had. Carry each surface's native-only keys into its block: Claude `color`/`maxTurns`/`hooks`/`permissionMode`/`disallowedTools`, Codex `nickname_candidates`, OpenCode `temperature`/`steps`/`color`, Copilot `handoffs`/`argument-hint`. Map `effort`/`model_reasoning_effort` to `tier` and tools/sandbox to `access`. Remove the migrated per-surface files only after a scratch sync shows equivalent output, and show the user the before/after for one agent first. Agents that exist on one surface only can stay as verbatim per-surface files.
- **Re-stamp**: once the approved version upgrades are applied, set `AGENTSYNC_VERSION` in `agents/agentsync.conf` to this skill's version (create the conf if the project lacked one). If the user declined some upgrades, do **not** advance the stamp past them — leave it at the newest version whose upgrades are fully applied, so the rest resurface next run.
- **Never** overwrite a customized agent's role description wholesale. When a template stub and a customized file conflict, the customization wins for prose; the template wins only for newly-added hard rules, and only with user sign-off.

## R5 — Re-sync and report

```
bash agents/scripts/sync_agents.sh
```

Then report what changed (including the `AGENTSYNC_VERSION` stamp before → after), what was intentionally left alone, and any findings the user declined.

---

# Upgrades by version

Reconcile uses this ledger to bring a project generated by an older agentsync up to the running version. For each version newer than the project's `AGENTSYNC_VERSION` stamp, apply its entry below — **merging** into customized files, preserving the user's prose — then advance the stamp (R4). A missing stamp means the project predates this mechanism: treat it as pre-`0.2.3` and apply everything.

**Every release adds an entry here** describing what an existing project should pick up. Keep entries concrete and action-oriented — reconcile follows them literally.

- **0.2.3** — Code-reviewer agents gain a **"Reviewing architect plans"** directive (review plans thoroughly; validate and scrutinize every decision against the actual code, cite `path:line`, no rubber-stamping) and **extra-high reasoning effort**: Claude `effort: xhigh`, Codex `model_reasoning_effort = "xhigh"`. Merge the directive into each surface's code-reviewer (claude / codex / opencode / github), preserving any customized review prose. Codex `base.toml` no longer pins a model — if the project hardcodes a Codex `model` the user didn't deliberately choose, comment it out so Codex uses its own default.
- **0.2.4** — New **orchestrate** skill (`templates/skills/orchestrate/`): drives an approved plan to clean, verified implementation by looping `engineer` → `code-reviewer` → `engineer`, phase by phase, from the main session. Copy it into `agents/skills/orchestrate/` if absent, then re-sync.
- **0.2.5** — **orchestrate is multi-surface.** It shipped in 0.2.4 mistakenly marked Claude-only (a `context:` frontmatter line that trips `is_delegator_skill`), on the wrong assumption that only Claude spawns subagents — Codex and OpenCode do too. Its body is already surface-agnostic ("delegate to the `engineer` / `code-reviewer`"). If `agents/skills/orchestrate/SKILL.md` has a `context:` line, **remove it** and re-sync so the skill fans out to `.agents/skills/` (Codex/OpenCode) and `.github/skills/` (if GitHub is enabled), not just `.claude/`.
- **0.2.6** — **Codex agents are now registered as spawnable roles.** *(Superseded by 0.3.0: current Codex auto-discovers `.codex/agents/*.toml`, so registration is now opt-in via `CODEX_REGISTER_ROLES`. When upgrading from ≤0.2.5 straight to 0.3.0, skip this entry and apply 0.3.0.)* Earlier versions wrote standalone `codex/agents/*.toml` and a comment-only `base.toml`, expecting Codex to auto-discover them. It does not: Codex (≥ 0.137) only spawns a role declared in `.codex/config.toml` under `[agents.<name>]` with a `config_file`, and only in a trusted project — so `spawn_agent` returned `unknown agent_type` and the agents were unusable. Fix: (1) replace `agents/scripts/sync_codex.sh` with the current template — it now rebuilds `.codex/config.toml` from the config fragments **and appends an `[agents.<name>]` registration per agent** (extracting `name`/`description`, `config_file = "agents/<name>.toml"`), and is `compgen`-free for portability; (2) update `agents/codex/configs/base.toml` to the current template — it adds a global `[agents]` block (`max_threads`/`max_depth`), `[features] multi_agent = true`, and header comments explaining the trust requirement and that there's no agent picker (invoke by asking Codex to delegate); (3) re-sync, then confirm `.codex/config.toml` carries an `[agents.<name>]` block for each role. Tell the user to trust the project in Codex if they haven't. Preserve any custom Codex config the user added to `base.toml`. Also add the Codex usage notes to the rendered `AGENTS.md` if absent: a line under **Agents** (no agent picker — invoke by delegating; roles load only when trusted) and one under **Skills** (no per-skill `/` entry — list with `/skills`, invoke by name; trust-gated). Skills themselves need no structural change — they are already auto-discovered under `.agents/skills/`; if `orchestrate` is missing from the AGENTS.md skills list, add it.
- **0.3.0** — **Single-source roles, inherited models, shared rules, and current CLI formats.** Walk these as separate, individually approvable findings:
  1. **Scripts.** Replace `agents/scripts/` with the current templates (adds `gen_agents.sh`; `_lib.sh` gains `stage_agents`, `sync_owned_file`, an allowlist `normalize_skill`, and `sync_skills_normalized`; scripts call each other via `bash`; `apply_gitignore.sh` no longer passes a multi-line value through `awk -v`, which BSD awk rejects). The new scripts still sync a legacy layout unchanged, so this step is safe on its own.
  2. **Conf.** Add `SURFACES` (the surfaces the project uses today), `CODEX_EXEC_PREFIX` (`"direnv exec ."` if the project has an `.envrc`, else empty), and `CODEX_REGISTER_ROLES="no"`. Codex now auto-discovers `.codex/agents/*.toml` — the 0.2.6 claim that it doesn't is outdated — so registrations are opt-in for older Codex releases only.
  3. **Models → inherit.** Remove `model:` lines that match an old template default (Claude `opus`/`sonnet` from ≤0.2.6, an OpenCode model written at bootstrap, any Codex slug) so every surface inherits the session model. If the user deliberately upgraded a model by hand (e.g. a reviewer bumped to the top tier), ask whether to keep that pin or inherit. Keep hand-set `effort`/`maxTurns`.
  4. **Roles migration.** Migrate per-surface agents into `roles/` (see R4 "Migration to `roles/`"). Copilot agents are now generated too; any hand-written `github/agents/*.agent.md` without a role stays verbatim.
  5. **Rules.** Move `claude/rules/no-commit-attribution.md` and `plan-before-code.md` to `rules/` (they now reach every surface through `AGENTS.md`), and add `scope-discipline.md` and `verify-with-cli.md`. Merge, don't overwrite, where the project has its own versions.
  6. **AGENTS.md / CLAUDE.md.** Add the `<!-- agentsync:roles -->` marker under **Agents** (replacing a hand-kept roster table) and `<!-- agentsync:rules -->` under a **Rules** heading. Replace any "Codex: roles are registered" wording with the delegate-by-name note from the template, and list `grill-converge`. In `claude/CLAUDE.md`, drop the agent/skill rosters (the runtime surfaces both; checked-in copies go stale) and keep only orientation, the rule headlines, and the source-of-truth note. Keep all hand-written project prose, such as environment sections.
  7. **Claude settings.** Add `claude/settings.json` with `attribution.commit` / `attribution.pr` set to `false`. If the project already has `.claude/settings.json`, merge the `attribution` block into its source by hand. The sync never overwrites a settings file it doesn't own. `includeCoAuthoredBy` and any `gitCommit`/`pullRequest` keys are deprecated or undocumented: replace them.
  8. **Codex base.toml.** Drop model-slug examples and the `[features] multi_agent` / `[agents] max_threads`/`max_depth` block (multi-agent is on by default, and `max_threads` is now a legacy alias). Keep any custom config the user added.
  9. **Skills.** Replace `orchestrate` and `grill-plan` with the current templates, merging project-specific additions (area routing, test policy, push-after-commit, etc.). Add `grill-converge`. If the project already has its own `grill-converge`, offer the template's shape (a native loop, then one peer-CLI gate at the end, instead of two engines every round) as a merge.
  10. Re-sync, then confirm: each surface has its agents, `.claude/settings.json` exists (or was reported as skipped), the root `AGENTS.md` contains the roles table and rules, and stale `.codex/AGENTS.md` / `.opencode/AGENTS.md` copies are gone.

---

# Hard Rules (both modes)

- Never write outside `agents/`, `.claude/`, `.codex/`, `.opencode/`, `.github/`, `.agents/`, the project's root `AGENTS.md`/`CLAUDE.md` (when `CLAUDE_MD_TARGET` points there)/README, or the agentsync block in the root `.gitignore`. Never edit source code.
- Agents are generated from `roles/` for every enabled surface, Copilot included. Hand-written per-surface files (`claude/agents/`, `codex/agents/`, `opencode/agents/`, `github/agents/`) are copied verbatim and win on a name clash. Don't hand-maintain a per-surface copy of a role that exists in `roles/`.
- Never pin a model in a template or at bootstrap. Models are inherited (see the model policy). Pin only when the user explicitly asks.
- `.claude/settings.json` is written only when agentsync owns it or it doesn't exist. Never overwrite a user's settings file.
- **Bootstrap** never overwrites an existing `.claude/agents/` etc. — if found, switch to Reconcile.
- **Reconcile** never blind-copies templates over customized files. Audit → report → approve → apply. Customizations win over template prose; templates contribute only missing structure and newly-added hard rules, with sign-off.
- Templates in the agentsync templates directory are read-only at runtime. To evolve them, the user edits there directly.
- No AI attribution in any generated file.
- When in doubt during ground-truth generation or refresh, write less. Stub sections the user can fill in are fine; invented prose is not.

## Artifact guardrail (both modes)

The driver may create **only** these artifacts. Anything else is out of bounds.

**Allowed:**
- Files copied/rendered from the agentsync template set (`templates/**`): the sync scripts, agent/skill/rule templates, `agentsync.conf`, `README`, `AGENTS.md`, and the agentsync block in the root `.gitignore`.
- The generated `<project>-ground-truth` skill and up to two `<area>-patterns` skills (the sanctioned generation step in Step 3 / R3).

**Never:**
- Install git hooks, write anything under `.git/`, or modify git configuration (`core.hooksPath`, etc.).
- Create scripts, config, or tooling that is not in the template set.
- Stamp "agentsync" / "Auto-installed by agentsync" — or any tool attribution — on anything the tool does not actually ship. (The only sanctioned attribution is the "Generated with agentsync" line in the rendered `agents/README.md`.)

**Pre-existing non-template artifacts (reconcile / adoption):**
- If the target project contains an artifact that references a missing agentsync file (e.g. an orphaned `.git/hooks/pre-commit` calling a nonexistent `check_sync.sh`), do **NOT** silently satisfy it by inventing the file. **Report it as a finding and ask.**
- Leftover artifacts from prior runs — especially in untracked locations like `.git/hooks/` that survive `git restore` — must be **surfaced**, not perpetuated. Treat "looks agentsync-installed but isn't in the template set" as a red flag to report, not adopt.
- If a hook (or similar) is genuinely wanted, it belongs in a future template version (tracked, consented, distributed via `core.hooksPath` to a tracked dir) — never improvised at run time.

## Shared output directories (both modes)

agentsync's surface output dirs (`.claude/skills/`, `.claude/agents/`, `.claude/rules/`, `.codex/agents/`, `.agents/skills/`, `.opencode/agents/`, `.github/agents/`, `.github/skills/`) and `.claude/settings.json` are not assumed to be exclusively owned by agentsync. Another generator or the user may keep files there too.

- **The sync is merge-safe.** Each managed dir carries a hidden `.agentsync-manifest` listing the entries agentsync owns. On every sync the scripts prune **only** previously-owned entries that left the source, and **never** touch entries they don't own. A skill or agent another tool wrote into a shared dir survives every sync untouched. Do not reintroduce blanket `rm -rf <dir>/*` into any sync script.
- **But agentsync cannot control the other tool.** If another generator owns the same dir (e.g. a product's own `sync-skills` that stamps `generated by … do not edit` banners and deletes anything it didn't write), *its* next run may delete agentsync's skills. agentsync coexisting does not make the other tool coexist.
- **So detect and report co-ownership.** Before the first sync (bootstrap) or during audit (reconcile), scan the surface dirs for content agentsync didn't generate — especially files carrying another tool's "generated by …" / "do not edit" banner, or a foreign manifest/lockfile. If found, report it: name the dir, the other owner, and the reciprocal-clobber risk. Let the user decide; do not silently proceed to share a dir an aggressive cleaner owns.
