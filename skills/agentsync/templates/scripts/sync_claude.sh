#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"

source "$SCRIPT_DIR/_lib.sh"

[[ -f "$AGENTS_DIR/agentsync.conf" ]] && source "$AGENTS_DIR/agentsync.conf"
CLAUDE_MD_TARGET="${CLAUDE_MD_TARGET:-.claude/CLAUDE.md}"

SRC="$AGENTS_DIR/claude"
SKILLS_SRC="$AGENTS_DIR/skills"
TARGET="$WORKSPACE_ROOT/.claude"

mkdir -p "$TARGET/agents" "$TARGET/skills" "$TARGET/rules"

# Agents: generated from roles/, plus verbatim claude/agents/*.md (which win on
# a name clash). Merge-safe: only agentsync-owned entries are pruned/replaced.
stage="$(stage_agents claude "$SRC/agents" '*.md')"
sync_dir_files "$stage" "$TARGET/agents" '*.md'
rm -rf "$stage"

sync_skill_dirs_verbatim "$SKILLS_SRC" "$TARGET/skills"

# Rules: shared rules/ (all surfaces) plus Claude-only claude/rules/ (wins on a
# name clash).
stage="$(mktemp -d "${TMPDIR:-/tmp}/agentsync-rules.XXXXXX")"
for d in "$AGENTS_DIR/rules" "$SRC/rules"; do
    [[ -d "$d" ]] || continue
    for f in "$d"/*.md; do [[ -f "$f" ]] && cp -f "$f" "$stage/"; done
done
sync_dir_files "$stage" "$TARGET/rules" '*.md'
rm -rf "$stage"

if [[ -f "$SRC/CLAUDE.md" ]]; then
    CLAUDE_MD_DEST="$WORKSPACE_ROOT/$CLAUDE_MD_TARGET"
    mkdir -p "$(dirname "$CLAUDE_MD_DEST")"
    cp -f "$SRC/CLAUDE.md" "$CLAUDE_MD_DEST"
fi

# settings.json: written only if agentsync owns it or it doesn't exist yet — a
# hand-written .claude/settings.json is never overwritten.
if [[ -f "$SRC/settings.json" ]]; then
    sync_owned_file "$SRC/settings.json" "$TARGET/settings.json"
fi

echo "Synced .claude/"
