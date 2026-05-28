#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"

source "$SCRIPT_DIR/_lib.sh"

SRC="$AGENTS_DIR/codex"
SKILLS_SRC="$AGENTS_DIR/skills"
TARGET="$WORKSPACE_ROOT/.codex"
SHARED_SKILLS_TARGET="$WORKSPACE_ROOT/.agents/skills"

mkdir -p "$TARGET/agents" "$SHARED_SKILLS_TARGET"

# Concatenate any configs into a single config.toml
if [[ -d "$SRC/configs" ]] && compgen -G "$SRC/configs/*.toml" > /dev/null; then
    : > "$TARGET/config.toml"
    for cfg in "$SRC/configs/"*.toml; do
        cat "$cfg" >> "$TARGET/config.toml"
        echo "" >> "$TARGET/config.toml"
    done
fi

# Agent TOMLs
rm -f "$TARGET/agents/"*.toml 2>/dev/null || true
if [[ -d "$SRC/agents" ]]; then
    for toml in "$SRC/agents/"*.toml; do
        [[ -f "$toml" ]] || continue
        cp -f "$toml" "$TARGET/agents/"
    done
fi

# Skills go to .agents/skills/ (Codex/OpenCode shared location).
# Strip Claude-only frontmatter keys so Codex can parse them.
rm -rf "$SHARED_SKILLS_TARGET/"*

if [[ -d "$SKILLS_SRC" ]]; then
    for skill_dir in "$SKILLS_SRC"/*; do
        [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
        if is_delegator_skill "$skill_dir/SKILL.md"; then
            continue
        fi
        name="$(basename "$skill_dir")"
        mkdir -p "$SHARED_SKILLS_TARGET/$name"
        for entry in "$skill_dir"/*; do
            base="$(basename "$entry")"
            [[ "$base" == "SKILL.md" ]] && continue
            cp -R "$entry" "$SHARED_SKILLS_TARGET/$name/"
        done
        normalize_skill < "$skill_dir/SKILL.md" > "$SHARED_SKILLS_TARGET/$name/SKILL.md"
    done
fi

if [[ -f "$AGENTS_DIR/AGENTS.md" ]]; then
    cp -f "$AGENTS_DIR/AGENTS.md" "$TARGET/AGENTS.md"
fi

echo "Synced .codex/ and .agents/skills/"
