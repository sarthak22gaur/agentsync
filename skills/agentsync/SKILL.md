---
name: agentsync
description: Bootstrap OR reconcile a multi-surface agent/skill system in any project. On a fresh project, scaffolds a source-of-truth agents/ directory, sync scripts, four role agents (architect, code-reviewer, librarian, engineer) across Claude/Codex/OpenCode, two opinionated rules, the grill-plan skill, then analyzes the codebase to generate a project ground-truth skill. On a project that already has an agents/ setup, audits it for gaps, sync drift, and stale ground-truth, then updates it in place without clobbering customizations. Use when starting a new project, onboarding agents into an existing one, or refreshing an existing agent setup.
argument-hint: "[project-name] — optional; defaults to basename of cwd"
---

# agentsync

Bootstrap an agent/skill system in any project from a single source-of-truth `agents/` directory plus sync scripts that fan config out to `.claude/`, `.codex/`, and `.opencode/`.

The templates this skill copies from live alongside it at `${CLAUDE_PLUGIN_ROOT}/skills/agentsync/templates/` when installed as a plugin, or `~/.claude/skills/agentsync/templates/` when installed standalone. They are the canonical version — edit them there to evolve future scaffolds.

**This skill is agentsync `0.2.3`.** (Release chore: bump this string with every version.) Bootstrap stamps it into `agents/agentsync.conf` as `AGENTSYNC_VERSION`. On reconcile, compare the project's stamped version against this one — if this is newer, apply the intervening versions' enhancements (see [Upgrades by version](#upgrades-by-version)) and re-stamp.

---

## Preflight — Choose Mode

1. Confirm cwd is the target project root (or workspace root for multi-repo).
2. **Detect mode by checking for an existing setup:**
   - `agents/scripts/sync_agents.sh` exists (or `agents/` holds a recognizable claude/codex/opencode subtree) → **Mode B: Reconcile** (jump to the Reconcile section).
   - Only `.claude/agents/` etc. exist but no `agents/` source-of-truth → the project was set up by hand, not by this skill. Tell the user, and offer to adopt it into the `agents/` source-of-truth model via Reconcile (treat the existing `.claude/` as the seed). Get explicit approval before moving anything.
   - Neither exists → **Mode A: Bootstrap** (continue below).
3. Detect repo shape:
   - cwd has `.git/` → **single-repo** layout (templates land in `./agents/`)
   - cwd has no `.git/` but immediate subdirs do → **multi-repo workspace** (templates land in `./agents/` at workspace root, same level as sub-repos)
   - Neither → ask the user.

---

# Mode A: Bootstrap (fresh project)

## Step 1 — Gather inputs

Ask the user the following. Provide defaults; one question at a time only if any are ambiguous, otherwise batch.

| Input | Default | Notes |
|---|---|---|
| `project_name` | basename of cwd, kebab-cased | Used in `<project>-ground-truth` skill name and READMEs |
| `project_description` | (ask) | One sentence — what the project is |
| `primary_languages` | inferred from manifest files | List: `python`, `typescript`, `go`, `rust`, `ruby`, `java`, etc. |
| `base_branch` | `main` | `develop` if a `develop` branch already exists |
| `client_surfaces` | `claude,codex,opencode` | Comma-separated; user can drop any. `github` (Copilot) is opt-in — add it explicitly. |
| `claude_md_target` | `.claude/CLAUDE.md` | Where `CLAUDE.md` is written. Offer root `CLAUDE.md` as an alternative. |
| `repo_shape` | detected | `single` or `multi` |
| `opencode_model` | **ask** — blank = inherit OpenCode's default | Only if `opencode` selected. See model defaults below. |

**Model defaults per surface** — set per client; only OpenCode is asked:
- **Claude** — fixed in the agent templates: `architect` → `opus` (Opus 4.8), `code-reviewer` / `engineer` / `librarian` → `sonnet` (Sonnet 4.6). These aliases track the latest of each tier. Don't ask; leave them unless the user asks to change.
- **Codex** — leave `codex/configs/base.toml` with no active `model` line so Codex uses its own default (the latest model available for the user's auth). **Don't hardcode a model id** — a model the user's auth/version doesn't have shows up as "custom" and makes agents that inherit it fail to load. Pin one only if the user names a model their `codex` lists under `/model` (e.g. `gpt-5.5` for ChatGPT auth, `gpt-5.2-codex` for API-key auth).
- **OpenCode** — has no default worth assuming (it's multi-provider). **Ask** the user which model OpenCode should use, e.g. `anthropic/claude-sonnet-4-6` or `openai/gpt-5.5`. If they give one, it's written to each OpenCode agent; if they decline, leave OpenCode to its own configured default.

Inference rules:
- `pyproject.toml` / `requirements.txt` → python
- `package.json` → typescript (check `tsconfig.json`) or javascript
- `Cargo.toml` → rust
- `go.mod` → go
- `Gemfile` → ruby
- Multiple → list all

---

## Step 2 — Copy and render templates

Copy the agentsync templates directory (see the path noted at the top of this skill) into `<workspace-root>/agents/`. Substitute placeholders in every text file:

| Placeholder | Replacement |
|---|---|
| `{{PROJECT_NAME}}` | `project_name` |
| `{{PROJECT_DESCRIPTION}}` | `project_description` |
| `{{BASE_BRANCH}}` | `base_branch` |
| `{{LANGUAGES}}` | comma-joined `primary_languages` |
| `{{REPO_SHAPE}}` | `single` or `multi` |
| `{{AGENTSYNC_VERSION}}` | this skill's version (see top) |

Drop surface dirs the user opted out of (e.g., if `client_surfaces` excludes `opencode`, delete `agents/opencode/` and its sync script reference). `github/` is opt-in — keep it only if the user selected `github`, otherwise delete `agents/github/`.

**Models** (see Step 1 model defaults):
- **Claude** — agent templates already pin `model:` (architect `opus`, others `sonnet`). Leave them.
- **Codex** — `codex/configs/base.toml` ships with the `model` line commented out (Codex uses its own default). Only uncomment and set it if the user names a specific Codex model their setup has.
- **OpenCode** — if the user gave an `opencode_model`, add a `model: <opencode_model>` line to each `agents/opencode/agents/*.md` frontmatter (just below `mode:`). If they declined, add nothing — OpenCode falls back to its own default. (Never leave an unsubstituted placeholder; add the real value or no line at all.)

Write `agents/agentsync.conf` from `templates/agentsync.conf` with the chosen `CLAUDE_MD_TARGET`, `OUTPUT_TRACKING` (default `root-docs`), and `AGENTSYNC_VERSION` set to this skill's version. The file is optional for the sync scripts (absent means defaults), but always write it at bootstrap so the version stamp exists for future reconciles. The sync writes an agentsync-owned block in the workspace `.gitignore` to match `OUTPUT_TRACKING`.

Make sync scripts executable: `chmod +x agents/scripts/*.sh`.

---

## Step 3 — Generate the project ground-truth skill

This is the load-bearing step. Don't skip and don't bloat.

Read, in this order:
- `README.md` at project root (if exists)
- Top-level manifest files (`pyproject.toml`, `package.json`, etc.)
- For multi-repo: each sub-repo's README and manifest
- Top-level directory tree (`ls` at root, no recursion)
- `docs/` directory listing if it exists

Synthesize a single skill file at `agents/skills/{{project_name}}-ground-truth/SKILL.md`. Use this exact template:

```markdown
---
name: {{project_name}}-ground-truth
description: The single source of truth for {{project_name}} architecture, repo layout, primary stack, and project-wide conventions. Use when an agent needs orientation before any non-trivial work.
---

# {{Project Name}} Ground Truth

{{one-paragraph project description — what it is, who uses it, the core capability}}

## Repos / Layout

{{For single-repo: top-level directory roles. For multi-repo: each sub-repo's purpose. One line each, no fluff.}}

## Primary Stack

- **{{language/framework}}**: {{1-line role}}
- ...

## Entry Points

{{Key files an engineer touches first when implementing a feature. e.g. backend API entrypoint, frontend route registry, main CLI. Cite `path:line` where possible.}}

## Conventions

{{Project-specific norms detected from code/README — e.g. base branch, lockfile policy, test runner, formatter. Skip if unknown.}}

## What This Skill Is Not

Live code behaviour, current bug list, or in-flight work. For those, read the code or the relevant plan/issue.
```

**Anti-bloat rules** (this skill is read by every agent every time — keep it dense):
- No marketing prose. No "this is a powerful…" phrasing.
- Every line carries information. If a section has nothing concrete, omit it.
- No invention. If you can't ground a claim in the README, manifest, or directory tree, leave it out.
- Cap at ~80 lines unless the project genuinely has more than 5 sub-repos.

If the project has clearly distinct domains (e.g. `frontend/` + `backend/`, or recognizable framework like FastAPI / React / Next / Rails), you MAY generate up to 2 additional `agents/skills/<area>-patterns/SKILL.md` files with the same anti-bloat discipline. Each should cover only conventions specific to that area, not generic framework documentation.

Stop at 1 ground-truth + up to 2 patterns. Don't generate more.

---

## Step 4 — First sync

Before syncing, scan the surface output dirs (`.claude/skills/`, `.agents/skills/`, `.github/skills/`, and the agent dirs) for content agentsync didn't generate — especially files carrying another tool's "generated by … / do not edit" banner or a foreign manifest. The sync is merge-safe and will preserve them, but if another generator co-owns a dir, report it (see "Shared output directories" in Hard Rules) so the user knows that tool may delete agentsync's skills on its next run.

```
cd <workspace-root>
bash agents/scripts/sync_agents.sh
```

Confirm `.claude/agents/`, `.claude/skills/`, `.claude/rules/`, `.claude/CLAUDE.md`, and per-surface equivalents exist. The sync leaves any pre-existing foreign skills/agents in those dirs untouched.

---

## Step 5 — Report

Print:

```
## Agents bootstrapped for {{project_name}}

### Source of truth
- agents/  (agentsync {{AGENTSYNC_VERSION}} — stamped in agents/agentsync.conf)

### Surfaces synced
- .claude/  (Claude Code)
- .codex/   (Codex)
- .opencode/ (OpenCode)
- .github/  (GitHub Copilot) — if selected

### Agents (4)
- architect, code-reviewer, librarian, engineer

### Skills
- grill-plan
- {{project_name}}-ground-truth (generated)
- <area>-patterns (if generated)

### Rules
- no-commit-attribution
- plan-before-code

### Models
- Claude — architect: opus (Opus 4.8); code-reviewer, engineer, librarian: sonnet (Sonnet 4.6)
- Codex — Codex default model (none pinned; the latest available for your auth)   # if codex selected
- OpenCode — <chosen opencode_model, or "OpenCode default (none pinned)">   # if opencode selected
- GitHub Copilot — model selected in the IDE (none pinned)        # if github selected

### Next steps
1. Review agents/claude/agents/*.md and customize role descriptions for {{project_name}}.
2. Review agents/skills/{{project_name}}-ground-truth/SKILL.md and add what the analysis missed.
3. Re-run `bash agents/scripts/sync_agents.sh` after every edit to agents/.
```

---

# Mode B: Reconcile (existing setup)

Goal: bring an existing `agents/` setup back to full health — close gaps, fix sync drift, refresh stale ground-truth — **without clobbering the user's customizations.** The template is the *baseline*, not the *override*. A user-edited agent file is the source of truth for its role description; you only add what's missing and fix what's demonstrably wrong.

This is an **audit → report → approve → apply** loop, not a re-scaffold. Never blind-copy templates over existing files.

## R1 — Inventory the existing setup

Read what's there:
- `agents/agentsync.conf`: the `AGENTSYNC_VERSION` stamp — the agentsync version that last generated/reconciled this project. Absent (or no conf) → treat as pre-`0.2.3`, the earliest. Compare it to this skill's version (top of file): if this skill is newer, every intervening version's [Upgrades by version](#upgrades-by-version) entry is in scope.
- `agents/` tree: which agents, skills, rules, surfaces, scripts exist.
- `agents/skills/*-ground-truth/SKILL.md`: the current ground-truth.
- The synced targets: `.claude/`, `.codex/`, `.opencode/`, `.github/`, `.agents/skills/`, root `AGENTS.md`.

## R2 — Audit against four gap classes

Compare and collect findings. Do NOT fix yet.

**1. Structural gaps** — diff the live `agents/` tree against the template baseline in the agentsync templates directory:
- Missing role agents (e.g. template has `engineer`, project lacks it).
- Missing surfaces (e.g. project has `claude/` + `codex/` but not `opencode/`, and the user wants all three). `github/` is opt-in — only flag it as missing if the user uses Copilot.
- Read `agents/agentsync.conf` if present: a root-`CLAUDE.md` layout (`CLAUDE_MD_TARGET="CLAUDE.md"`) is intentional, not sync drift. Under `OUTPUT_TRACKING=none`/`root-docs`, a gitignored output dir (`.claude/` etc.) being absent or untracked is expected — never flag it as a missing surface.
- `.gitignore` agentsync block drifts from `OUTPUT_TRACKING` → propose re-applying the policy (the re-sync fixes it).
- Missing rules (`no-commit-attribution`, `plan-before-code`).
- Missing or outdated sync scripts (compare script bodies; flag if the template script has fixes the local one lacks).
- A role present in one surface but not another (e.g. `architect.md` in claude/ but no `architect.toml` in codex/).

**2. Sync drift** — does each target match its source?
- Run the sync into a temp dir or `diff` source vs target. If `.claude/agents/foo.md` differs from `agents/claude/agents/foo.md`, someone edited a target directly (anti-pattern) or forgot to sync.
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
- **Ad-hoc drift:** also catch directives present in the current template agents that the project's agents lack but that aren't tied to a version bump.
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

- **Structural gaps**: copy the missing template file into `agents/`, render placeholders. For a new surface, add the whole subtree + its sync script reference.
- **Sync drift from direct-target edits**: back-port the target's edit into the `agents/` source first, then re-sync (so the edit survives). Confirm with the user which version wins if both diverged.
- **Stale ground-truth**: edit the ground-truth skill surgically. Same anti-bloat discipline as Mode A — remove dead claims, add only grounded new ones, cap length. Never pad.
- **Stale AGENTS.md/CLAUDE.md fields**: edit the source (`agents/AGENTS.md`, `agents/claude/CLAUDE.md`) — only the drifted derived fields — then re-sync. Leave hand-written prose untouched.
- **Version upgrades & content drift**: merge each approved enhancement into the existing agent file; keep the user's role prose, append/insert the missing directive and apply the effort/model change. Show the diff.
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

---

# Hard Rules (both modes)

- Never write outside `agents/`, `.claude/`, `.codex/`, `.opencode/`, `.github/`, `.agents/`, the project's root `AGENTS.md`/README, or the agentsync block in the root `.gitignore`. Never edit source code.
- GitHub agents are verbatim source: `agents/github/agents/*.agent.md` are authored in Copilot format and copied as-is, never derived from the Claude agent. Only skills fan out to `.github/skills/`.
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

agentsync's surface output dirs (`.claude/skills/`, `.claude/agents/`, `.claude/rules/`, `.codex/agents/`, `.agents/skills/`, `.opencode/agents/`, `.github/agents/`, `.github/skills/`) are not assumed to be exclusively owned by agentsync. Another generator or the user may keep files there too.

- **The sync is merge-safe.** Each managed dir carries a hidden `.agentsync-manifest` listing the entries agentsync owns. On every sync the scripts prune **only** previously-owned entries that left the source, and **never** touch entries they don't own. A skill or agent another tool wrote into a shared dir survives every sync untouched. Do not reintroduce blanket `rm -rf <dir>/*` into any sync script.
- **But agentsync cannot control the other tool.** If another generator owns the same dir (e.g. a product's own `sync-skills` that stamps `generated by … do not edit` banners and deletes anything it didn't write), *its* next run may delete agentsync's skills. agentsync coexisting does not make the other tool coexist.
- **So detect and report co-ownership.** Before the first sync (bootstrap) or during audit (reconcile), scan the surface dirs for content agentsync didn't generate — especially files carrying another tool's "generated by …" / "do not edit" banner, or a foreign manifest/lockfile. If found, report it: name the dir, the other owner, and the reciprocal-clobber risk. Let the user decide; do not silently proceed to share a dir an aggressive cleaner owns.
