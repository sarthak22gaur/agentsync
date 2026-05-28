#!/bin/bash
# Shared helpers for skill fan-out. Sourced by sync_codex.sh and sync_github.sh.

# Delegator/Claude-only skills (frontmatter with agent: or context:) are not
# fanned out to other surfaces.
is_delegator_skill() {
    grep -Eq '^(agent|context): ' "$1"
}

# Strip Claude/OpenCode-only frontmatter keys so other tools can parse the skill.
normalize_skill() {
    awk '
        BEGIN { in_fm = 0; fm_count = 0 }
        /^---$/ {
            fm_count++
            if (fm_count == 1) { in_fm = 1; print; next }
            if (fm_count == 2) { in_fm = 0; print; next }
        }
        in_fm == 1 {
            if ($0 ~ /^(agent|context|disable-model-invocation|allowed-tools|argument-hint|model|effort|maxTurns|color|permission|permissionMode|tools|disallowedTools|hooks|mode|temperature|steps):/) next
            print
            next
        }
        { print }
    '
}
