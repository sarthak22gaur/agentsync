# agentsync

One source-of-truth `agents/` directory → fanned out to every AI coding tool, with no per-tool config drift.

`agentsync` is a Claude Code plugin that **scaffolds and maintains a per-project AI agent system**. You run it inside a project; it generates a single `agents/` source-of-truth directory and sync scripts that fan your agent, skill, and rule definitions out to `.claude/` (Claude Code), `.codex/` (Codex), `.opencode/` (OpenCode), and optionally `.github/` (GitHub Copilot) — plus a shared `.agents/skills/` location.

## The problem

If you use more than one AI coding tool, you end up maintaining the same agent/skill/rule definitions three times, in three formats, and they drift. agentsync makes one directory the source of truth and treats `.claude/`, `.codex/`, and `.opencode/` as **generated artifacts** — you never hand-edit them.

## Two modes

**Bootstrap** (fresh project) — scaffolds the `agents/` source-of-truth tree, the sync scripts, four role agents (architect, code-reviewer, librarian, engineer) in each tool's native format, two opinionated rules (no-commit-attribution, plan-before-code), the `grill-plan` skill, then **analyzes your codebase** to generate a project-specific `<project>-ground-truth` skill so agents start with real orientation.

**Reconcile** (existing setup) — audits an existing `agents/` setup for: structural gaps (missing agents/surfaces/rules), sync drift (a tool's generated files were hand-edited or never re-synced), stale ground-truth (documented paths/stack that no longer match the code), and template improvements you haven't picked up. It reports findings first, then applies only what you approve — it never clobbers your customizations.

## How it works

```
agents/                      # ← you edit here (source of truth)
  AGENTS.md                  # workspace overview (also rendered to repo root)
  agentsync.conf             # optional: where CLAUDE.md is written
  claude/  { CLAUDE.md, agents/, rules/ }
  codex/   { agents/*.toml, configs/ }
  opencode/{ agents/*.md }
  github/  { agents/*.agent.md }   # opt-in (GitHub Copilot)
  skills/  { grill-plan/, <project>-ground-truth/ }
  scripts/ { sync_*.sh }

bash agents/scripts/sync_agents.sh
        │
        ├── .claude/      (Claude Code: agents, skills, rules, CLAUDE.md)
        ├── .codex/       (Codex: agent TOMLs, config.toml)
        ├── .opencode/    (OpenCode: agent markdown)
        ├── .github/      (GitHub Copilot: agents, skills) — if enabled
        └── .agents/skills/  (shared skills for Codex/OpenCode)
```

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

From then on: **edit `agents/`, run the sync, commit both** the `agents/` source and the generated `.claude/` etc.

## Example: a generated `agents/` tree

Bootstrapping a project named `acme-api` produces:

```
agents/
├── AGENTS.md
├── README.md
├── claude/
│   ├── CLAUDE.md
│   ├── agents/
│   │   ├── architect.md
│   │   ├── code-reviewer.md
│   │   ├── engineer.md
│   │   └── librarian.md
│   └── rules/
│       ├── no-commit-attribution.md
│       └── plan-before-code.md
├── codex/
│   ├── agents/
│   │   ├── architect.toml
│   │   ├── code-reviewer.toml
│   │   ├── engineer.toml
│   │   └── librarian.toml
│   └── configs/
│       └── base.toml
├── opencode/
│   └── agents/
│       ├── architect.md
│       ├── code-reviewer.md
│       ├── engineer.md
│       └── librarian.md
├── github/                          # ← opt-in (GitHub Copilot)
│   └── agents/
│       ├── architect.agent.md
│       ├── code-reviewer.agent.md
│       ├── engineer.agent.md
│       └── librarian.agent.md
├── skills/
│   ├── grill-plan/
│   │   └── SKILL.md
│   └── acme-api-ground-truth/      # ← generated by analyzing the codebase
│       └── SKILL.md
└── scripts/
    ├── _lib.sh
    ├── apply_gitignore.sh
    ├── sync_agents.sh
    ├── sync_claude.sh
    ├── sync_codex.sh
    ├── sync_github.sh
    └── sync_opencode.sh
```

Running `sync_agents.sh` then produces `.claude/`, `.codex/`, `.opencode/`, `.agents/skills/`, a root `AGENTS.md`, and `.github/` if the GitHub surface is enabled.

## Defaults are defaults, not requirements

agentsync ships opinions, but they're all overridable:

- **Four role agents** (architect / code-reviewer / librarian / engineer) are a starting taxonomy. Add, remove, or rename them — they're just files under `agents/`.
- **Base branch** defaults to `main` (`develop` if a `develop` branch already exists). Change it during setup.
- **Two rules** (no AI attribution in commits; plan before non-trivial code) are opinionated and meant to be edited or dropped if they don't fit your workflow.
- **Codex model** in `agents/codex/configs/base.toml` is a `REPLACE_ME` placeholder — set it to whatever model your Codex setup uses.
- **Surfaces** — Claude/Codex/OpenCode are on by default; drop any you don't use, or add GitHub Copilot (opt-in).

## Configuration

One optional file, `agents/agentsync.conf` (sourced by the sync scripts):

```sh
# Where the Claude system prompt is written, relative to workspace root.
# Default: .claude/CLAUDE.md   |   Common alternative: CLAUDE.md (repo root)
CLAUDE_MD_TARGET=".claude/CLAUDE.md"

# Which generated output git tracks.
OUTPUT_TRACKING="root-docs"
```

Absent file means the defaults. Set `CLAUDE_MD_TARGET="CLAUDE.md"` to write the system prompt to the repo root instead.

`OUTPUT_TRACKING` decides which generated output git tracks; agentsync keeps a delimited block in your `.gitignore` to match and leaves the rest of the file alone. `all` commits everything (the 0.1.0 behavior); `root-docs` (default) commits the entrypoint docs (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`) and gitignores the bulky regenerable dirs (`.claude/`, `.codex/`, `.opencode/`, `.github/agents/`, `.github/skills/`, `.agents/`); `none` gitignores all generated output so only `agents/` is tracked.

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
- **Known constraint:** Codex enforces an ~8 KB per-skill cap. The agentsync driver logic is well over that, so a Codex port will require splitting this skill into a thin entry point plus a subagent that carries the long bootstrap/reconcile logic. That work isn't done yet.

## Tested against

- **Claude Code** `v2.1.154` — the scaffolder and plugin manifests were built and smoke-tested here. `claude plugin validate .` passes, and a full bootstrap → sync into a throwaway project populates `.claude/`, `.codex/`, `.opencode/`, and `.agents/skills/` correctly.
- The **Codex**, **OpenCode**, and **GitHub Copilot** emitters target those tools' config formats as of early 2026. The GitHub agent frontmatter follows the Copilot custom-agent spec (`tools`/`target`/`handoffs`). The generated output was structurally verified, but has not been runtime-tested inside those tools in this build. Treat those surfaces as best-effort.

## Warnings and disclaimers

- **Reconcile mode is new and lightly tested.** Always review the findings report before applying anything, apply changes incrementally, and keep your `agents/` directory under version control so you can diff and revert. Bootstrap mode is the more exercised path.
- **Works for me — no support guarantees.** This is a personal project shared as-is under the MIT license. No warranty, no commitment to respond to issues or PRs, no promise of backward compatibility across versions. Read the code before running it against a repo you care about.

## License

MIT — see [LICENSE](LICENSE).
