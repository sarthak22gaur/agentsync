#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"

source "$SCRIPT_DIR/_lib.sh"
[[ -f "$AGENTS_DIR/agentsync.conf" ]] && source "$AGENTS_DIR/agentsync.conf"

echo "Syncing agent surfaces from $AGENTS_DIR"

for s in claude codex opencode github; do
    if surface_enabled "$s"; then
        bash "$SCRIPT_DIR/sync_$s.sh"
    fi
done

# Root AGENTS.md (read by Codex, OpenCode, Copilot, and Claude Code when there
# is no CLAUDE.md), rendered from agents/AGENTS.md:
#   <!-- agentsync:roles -->  → a table of every role in roles/ (name + description)
#   <!-- agentsync:rules -->  → the shared rules/ text, so non-Claude tools get it
if [[ -f "$AGENTS_DIR/AGENTS.md" ]]; then
    tmp="$(mktemp "${TMPDIR:-/tmp}/agentsync-agentsmd.XXXXXX")"
    roles="$(mktemp "${TMPDIR:-/tmp}/agentsync-roles.XXXXXX")"
    rules="$(mktemp "${TMPDIR:-/tmp}/agentsync-rules.XXXXXX")"
    trap 'rm -f "$tmp" "$roles" "$rules"' EXIT
    {
        echo "| Agent | Role |"
        echo "|---|---|"
        for f in "$AGENTS_DIR"/roles/*.md; do
            [[ -f "$f" ]] || continue
            awk '
                NR == 1 && $0 == "---" { in_fm = 1; next }
                in_fm && $0 == "---" { exit }
                in_fm && /^name:/ { n = $0; sub(/^name:[ \t]*/, "", n) }
                in_fm && /^description:/ { d = $0; sub(/^description:[ \t]*/, "", d) }
                END { if (n != "") printf "| %s | %s |\n", n, d }
            ' "$f"
        done
    } > "$roles"
    first=1
    for f in "$AGENTS_DIR"/rules/*.md; do
        [[ -f "$f" ]] || continue
        [[ $first -eq 1 ]] || echo "" >> "$rules"
        first=0
        # Drop rule frontmatter (e.g. Claude paths:) and demote headings one level.
        awk '
            NR == 1 && $0 == "---" { in_fm = 1; next }
            in_fm { if ($0 == "---") in_fm = 0; next }
            /^#/ { print "#" $0; next }
            { print }
        ' "$f" >> "$rules"
    done
    awk -v roles="$roles" -v rules="$rules" '
        $0 == "<!-- agentsync:roles -->" { while ((getline l < roles) > 0) print l; close(roles); next }
        $0 == "<!-- agentsync:rules -->" { while ((getline l < rules) > 0) print l; close(rules); next }
        { print }
    ' "$AGENTS_DIR/AGENTS.md" > "$tmp"
    cp -f "$tmp" "$WORKSPACE_ROOT/AGENTS.md"
    echo "Wrote $WORKSPACE_ROOT/AGENTS.md"

    # Codex stops reading project docs past project_doc_max_bytes (32 KiB by default).
    size="$(wc -c < "$WORKSPACE_ROOT/AGENTS.md" | tr -d ' ')"
    if [[ "$size" -gt 32768 ]]; then
        echo "  ! AGENTS.md is $size bytes — Codex truncates project docs at 32 KiB by default; trim it or raise project_doc_max_bytes" >&2
    fi

    # Pre-0.3.0 syncs also wrote .codex/AGENTS.md and .opencode/AGENTS.md; no tool
    # reads those. Remove them only if they're still byte-identical to what
    # agentsync wrote (the source or the rendered file) — never a hand-edited copy.
    for stale in "$WORKSPACE_ROOT/.codex/AGENTS.md" "$WORKSPACE_ROOT/.opencode/AGENTS.md"; do
        if [[ -f "$stale" ]] && { cmp -s "$stale" "$AGENTS_DIR/AGENTS.md" || cmp -s "$stale" "$tmp"; }; then
            rm -f "$stale"
        fi
    done
fi

bash "$SCRIPT_DIR/apply_gitignore.sh"

echo "Sync complete."
