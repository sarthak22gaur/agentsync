# agentsync

One source-of-truth `agents/` directory → fanned out to every AI coding tool, with no per-tool config drift.

`agentsync` is a Claude Code plugin that **scaffolds and maintains a per-project AI agent system**. You run it inside a project; it generates a single `agents/` source-of-truth directory and sync scripts that fan your agent, skill, and rule definitions out to `.claude/` (Claude Code), `.codex/` (Codex), `.opencode/` (OpenCode), and optionally `.github/` (GitHub Copilot) — plus a shared `.agents/skills/` location.

## The problem

If you use more than one AI coding tool, you end up maintaining the same agent, skill, and rule definitions several times, in several formats, and they drift. agentsync makes one directory the source of truth and treats `.claude/`, `.codex/`, `.opencode/`, and `.github/agents/` as **generated artifacts** that you never hand-edit. Each agent is written **once**, in `agents/roles/<name>.md`, and generated into every tool's native format.

## Two modes

**Bootstrap** (fresh project) scaffolds the `agents/` source-of-truth tree: four single-source role agents (architect, code-reviewer, engineer, librarian), four shared hard rules (no AI attribution, plan before code, scope discipline and a defect bar for reviews, verify with the CLI rather than the editor), the `grill-plan`, `grill-converge`, and `orchestrate` skills, and the sync scripts. It then **analyzes your codebase** to generate a project-specific `<project>-ground-truth` skill, so agents start with real orientation.

**Reconcile** (existing setup) — audits an existing `agents/` setup for: structural gaps (missing agents, surfaces, or rules), sync drift (a tool's generated files were hand-edited or never re-synced), stale ground-truth (documented paths or stack that no longer match the code), and version upgrades or template improvements you haven't picked up, including migrating a pre-0.3.0 per-surface layout to single-source roles. It reports findings first, then applies only what you approve — it never clobbers your customizations.

## How it works

```
agents/                      # ← you edit here (source of truth)
  AGENTS.md                  # workspace guide → root AGENTS.md (roles table + rules injected)
  agentsync.conf             # surfaces, CLAUDE.md location, tracking policy, Codex options
  roles/    { architect.md, code-reviewer.md, engineer.md, librarian.md }   # one file per agent
  rules/    { *.md }         # shared hard rules
  skills/   { grill-plan/, grill-converge/, orchestrate/, <project>-ground-truth/ }
  claude/   { CLAUDE.md, settings.json }
  codex/    { configs/ }
  scripts/  { gen_agents.sh, sync_*.sh }

bash agents/scripts/sync_agents.sh
        │
        ├── .claude/      (Claude Code: agents, skills, rules, CLAUDE.md, settings.json)
        ├── .codex/       (Codex: agents/*.toml, config.toml)
        ├── .opencode/    (OpenCode: agents)
        ├── .github/      (GitHub Copilot: agents, skills) — if enabled
        ├── .agents/skills/  (shared skills: Codex, OpenCode, Copilot)
        └── AGENTS.md     (read by Codex, OpenCode, Copilot)
```

A role file has canonical frontmatter (`name`, `description`, `tier` for reasoning effort, `access` for read-only vs write, `surfaces`, `skills`) plus optional per-surface blocks for keys only one tool understands, such as Claude hooks, Codex nicknames, or Copilot handoffs. **No model is pinned anywhere**: every tool's subagents inherit the session model by default, and a pinned name goes stale the next time models are renamed or retired.

The sync scripts use only paths derived from their own location, so the generated `agents/` tree is fully portable — there are no machine-specific paths baked in.

The sync is **merge-safe**: each output dir (`.claude/skills/`, `.agents/skills/`, the agent dirs, …) carries a hidden `.agentsync-manifest` of the entries agentsync owns. Re-syncing prunes only agentsync's own stale entries and leaves anything else — skills or agents another tool or you put there — untouched. agentsync can share a directory with another generator instead of clobbering it.

## Install

### As a Claude Code plugin (recommended)

```
/plugin marketplace add sarthak22gaur/agentsync
/plugin install agentsync@agentsync
```

Then, inside any project you want to set up:

```
/agentsync:agentsync
```

### Standalone skill

Drop the skill into your skills directory:

```bash
cp -R skills/agentsync ~/.claude/skills/agentsync
```

Then invoke it with `/agentsync` inside a project.

## Quickstart

1. `cd` into the project (or multi-repo workspace root) you want to set up.
2. Run `/agentsync:agentsync` (or `/agentsync` standalone).
3. Answer a few inputs — project name, one-line description, languages (inferred from manifests), base branch (defaults to `main`), and which tool surfaces you want. Sensible defaults are offered for all of them.
4. agentsync scaffolds `agents/`, generates a `<project>-ground-truth` skill from your codebase, and runs the first sync.
5. Review `agents/claude/agents/*.md` and the generated ground-truth skill, tweak anything, and re-run `bash agents/scripts/sync_agents.sh`.

From then on: **edit `agents/`, run the sync, and commit** `agents/` plus whatever generated output `OUTPUT_TRACKING` tells git to track.

## Example: a generated `agents/` tree

Bootstrapping a project named `acme-api` produces:

```
agents/
├── AGENTS.md
├── README.md
├── agentsync.conf
├── roles/
│   ├── architect.md
│   ├── code-reviewer.md
│   ├── engineer.md
│   └── librarian.md
├── rules/
│   ├── no-commit-attribution.md
│   ├── plan-before-code.md
│   ├── scope-discipline.md
│   └── verify-with-cli.md
├── skills/
│   ├── grill-plan/SKILL.md
│   ├── grill-converge/SKILL.md     # ← harden a plan: grill rounds + one peer-CLI gate
│   ├── orchestrate/SKILL.md        # ← drive a plan: engineer → reviewer per phase
│   └── acme-api-ground-truth/      # ← generated by analyzing the codebase
│       └── SKILL.md
├── claude/
│   ├── CLAUDE.md
│   └── settings.json               # ← turns off Claude Code's commit/PR attribution
├── codex/
│   └── configs/base.toml
└── scripts/
    ├── _lib.sh
    ├── apply_gitignore.sh
    ├── gen_agents.sh
    ├── sync_agents.sh
    ├── sync_claude.sh
    ├── sync_codex.sh
    ├── sync_github.sh
    └── sync_opencode.sh
```

Running `sync_agents.sh` then produces `.claude/`, `.codex/`, `.opencode/`, `.agents/skills/`, a root `AGENTS.md`, and `.github/` if the GitHub surface is enabled.

## Defaults are defaults, not requirements

agentsync ships opinions, but they're all overridable:

- **Four role agents** (architect / code-reviewer / engineer / librarian) are a starting taxonomy. Add, remove, rename, or split them (e.g. backend/frontend engineers). Each is one file under `agents/roles/`.
- **Models are inherited, not pinned.** To pin one deliberately, add `model:` to that role's surface block.
- **Reasoning effort** is set per role (`tier`): `high` for architect, reviewer, and engineer, and `medium` for the librarian.
- **Base branch** defaults to `main` (`develop` if a `develop` branch already exists).
- **Rules** are opinionated and meant to be edited or dropped if they don't fit your workflow.
- **Surfaces**: Claude, Codex, and OpenCode are on by default. Drop any you don't use, or add GitHub Copilot (opt-in).
- **Hand-written agents for one tool** can sit in `agents/<surface>/agents/`. They're copied verbatim.

## Configuration

`agents/agentsync.conf` (sourced by the sync scripts; bootstrap writes it):

```sh
AGENTSYNC_VERSION="0.3.0"          # stamped by agentsync; drives version-aware reconcile
SURFACES="claude codex opencode"   # any of: claude codex opencode github
CLAUDE_MD_TARGET=".claude/CLAUDE.md"   # or "CLAUDE.md" for the repo root
OUTPUT_TRACKING="root-docs"        # all | root-docs | none
CODEX_EXEC_PREFIX=""               # e.g. "direnv exec ." — set at bootstrap when an .envrc exists
CODEX_REGISTER_ROLES="no"          # "yes" only for older Codex that doesn't auto-discover .codex/agents/
```

`OUTPUT_TRACKING` decides which generated output git tracks. agentsync keeps a delimited block in your `.gitignore` to match and leaves the rest of the file alone. `all` commits everything. `root-docs` (the default) commits the entrypoint docs (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`) and gitignores the bulky regenerable dirs (`.claude/`, `.codex/`, `.opencode/`, `.github/agents/`, `.github/skills/`, `.agents/`). `none` gitignores all generated output, so only `agents/` is tracked.

`CODEX_EXEC_PREFIX` exists because Codex's shells don't load a project's direnv/Nix environment, so tools look missing. When it's set, generated Codex agents route commands through the prefix.

## Prior art and how this differs

The multi-harness fan-out idea is not new. [**wshobson/agents**](https://github.com/wshobson/agents) is a mature project with the same core architecture — "one source-of-truth, five harnesses" — authoring agents/skills once in Markdown and compiling them to harness-native config via `make generate HARNESS=<tool>`. If you want a large, curated **catalog of ready-made agents** portable across Claude Code, Codex, Cursor, Gemini, and Copilot, use that.

agentsync is a different tool for a different job. It is a **project generator and maintainer**, not an agent library:

- It does **not** ship a fixed catalog of agents to drop in.
- It **scaffolds a per-project agent system** and generates a ground-truth skill by analyzing *your* codebase, so the agents are oriented to your repo from the start.
- It has a **reconcile mode** that keeps an existing setup honest over time — auditing for gaps, sync drift, and stale ground-truth — which is a maintenance loop, not a one-shot generation.

In short: wshobson/agents distributes agents; agentsync bootstraps and maintains *your project's* agent system.

## Roadmap / cross-tool support

- **Today:** agentsync runs as a **Claude Code skill/plugin**. Its *generated output* already targets **Claude Code + Codex + OpenCode + GitHub Copilot** (the templates emit `.claude/`, `.codex/`, `.opencode/`, `.github/`, and a shared `.agents/skills/`). That cross-tool *output* works now.
- **Planned:** native **Codex** and **OpenCode** entry points for running the scaffolder *itself* (not just consuming its output).
- **Known constraint:** Codex budgets its skill listing (about 2% of the context window) and truncates project docs past `project_doc_max_bytes` (32 KiB by default). The sync warns when the rendered `AGENTS.md` crosses 32 KiB. The agentsync driver itself is long, so a Codex port would split it into a thin entry point plus a subagent.

## Tested against

- **Claude Code**: the plugin manifests validate with `claude plugin validate .`, and a bootstrap → sync into a throwaway project populates every surface.
- **Sync scripts**: exercised with macOS's stock `/bin/bash` 3.2 and BSD `awk`/`sed`: fresh bootstrap, re-sync idempotency, pruning a removed role, preserving foreign skills, agents, and settings, and a pre-0.3.0 per-surface layout synced unchanged.
- **Output formats** were checked against each tool's official docs as of 2026-09: Claude Code subagent/skill/rules/settings frontmatter, Codex custom agents (`.codex/agents/*.toml`, auto-discovered) and config keys, OpenCode agent `permission` / `color` / `steps`, and Copilot `.agent.md` fields and tool aliases (`read`, `search`, `edit`, `execute`). The Codex, OpenCode, and Copilot output was verified against those formats but not runtime-tested inside each tool in this release. Treat those surfaces as best-effort.

## Warnings and disclaimers

- **Reconcile mode is new and lightly tested.** Always review the findings report before applying anything, apply changes incrementally, and keep your `agents/` directory under version control so you can diff and revert. Bootstrap mode is the more exercised path.
- **Works for me — no support guarantees.** This is a personal project shared as-is under the MIT license. No warranty, no commitment to respond to issues or PRs, no promise of backward compatibility across versions. Read the code before running it against a repo you care about.

## License

MIT — see [LICENSE](LICENSE).
