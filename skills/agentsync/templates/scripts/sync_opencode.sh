#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"

source "$SCRIPT_DIR/_lib.sh"

[[ -f "$AGENTS_DIR/agentsync.conf" ]] && source "$AGENTS_DIR/agentsync.conf"

SRC="$AGENTS_DIR/opencode"
SKILLS_SRC="$AGENTS_DIR/skills"
TARGET="$WORKSPACE_ROOT/.opencode"

mkdir -p "$TARGET/agents"

# Agents: generated from roles/, plus verbatim opencode/agents/*.md (which win
# on a name clash). Merge-safe: foreign agents are preserved.
stage="$(stage_agents opencode "$SRC/agents" '*.md')"
sync_dir_files "$stage" "$TARGET/agents" '*.md'
rm -rf "$stage"

# OpenCode reads skills from .agents/skills/ (written by sync_codex.sh) and
# AGENTS.md from the workspace root. Without the Codex surface, populate
# .agents/skills/ here.
if ! surface_enabled codex && [[ -d "$SKILLS_SRC" ]]; then
    sync_skills_normalized "$SKILLS_SRC" "$WORKSPACE_ROOT/.agents/skills"
fi

echo "Synced .opencode/"
