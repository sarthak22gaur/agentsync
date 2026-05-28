#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"

SRC="$AGENTS_DIR/claude"
SKILLS_SRC="$AGENTS_DIR/skills"
TARGET="$WORKSPACE_ROOT/.claude"

mkdir -p "$TARGET/agents" "$TARGET/skills" "$TARGET/rules"

rm -f "$TARGET/agents/"*
cp -r "$SRC/agents/"* "$TARGET/agents/"

rm -rf "$TARGET/skills/"*
if [[ -d "$SKILLS_SRC" ]]; then
    cp -r "$SKILLS_SRC/"* "$TARGET/skills/"
fi

if [[ -d "$SRC/rules" ]]; then
    rm -f "$TARGET/rules/"*
    cp -f "$SRC/rules/"* "$TARGET/rules/"
fi

if [[ -f "$SRC/CLAUDE.md" ]]; then
    cp -f "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md"
fi

if [[ -f "$SRC/settings.json" ]]; then
    cp -f "$SRC/settings.json" "$TARGET/settings.json"
fi

echo "Synced .claude/"
