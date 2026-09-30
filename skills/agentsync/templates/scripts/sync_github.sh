#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"

source "$SCRIPT_DIR/_lib.sh"

[[ -f "$AGENTS_DIR/agentsync.conf" ]] && source "$AGENTS_DIR/agentsync.conf"

SRC="$AGENTS_DIR/github"
SKILLS_SRC="$AGENTS_DIR/skills"
TARGET="$WORKSPACE_ROOT/.github"
SKILLS_TARGET="$TARGET/skills"

mkdir -p "$TARGET/agents" "$SKILLS_TARGET"

# Copilot agent profiles: generated from roles/, plus verbatim
# github/agents/*.agent.md (which win on a name clash). Merge-safe.
stage="$(stage_agents github "$SRC/agents" '*.agent.md')"
sync_dir_files "$stage" "$TARGET/agents" '*.agent.md'
rm -rf "$stage"

# Shared skills → .github/skills/, normalized; Copilot also understands its own
# argument-hint / invocation keys, so those are kept.
sync_skills_normalized "$SKILLS_SRC" "$SKILLS_TARGET" "" \
    "argument-hint|user-invocable|disable-model-invocation"

echo "Synced .github/"
