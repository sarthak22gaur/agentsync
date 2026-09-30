#!/bin/bash
set -euo pipefail

# Keep an agentsync-owned block in the workspace .gitignore in sync with the
# OUTPUT_TRACKING policy. Only the delimited block is touched; everything else
# in the file is preserved.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$AGENTS_DIR/.." && pwd)"

[[ -f "$AGENTS_DIR/agentsync.conf" ]] && source "$AGENTS_DIR/agentsync.conf"
OUTPUT_TRACKING="${OUTPUT_TRACKING:-root-docs}"

BEGIN="# >>> agentsync >>>"
END="# <<< agentsync <<<"
GITIGNORE="$WORKSPACE_ROOT/.gitignore"

case "$OUTPUT_TRACKING" in
    all)
        patterns="# OUTPUT_TRACKING=all — generated output is committed"
        ;;
    root-docs)
        patterns=".claude/
.codex/
.opencode/
.github/agents/
.github/skills/
.agents/"
        ;;
    none)
        patterns=".claude/
.codex/
.opencode/
.github/agents/
.github/skills/
.agents/
/AGENTS.md
/CLAUDE.md"
        ;;
    *)
        echo "Unknown OUTPUT_TRACKING='$OUTPUT_TRACKING' (use all|root-docs|none)" >&2
        exit 1
        ;;
esac

block="$BEGIN
$patterns
$END"

# The block goes through a file, not `awk -v`: BSD awk (macOS) rejects a -v
# value that contains newlines.
block_file="$(mktemp "${TMPDIR:-/tmp}/agentsync-gitignore.XXXXXX")"
trap 'rm -f "$block_file" "$GITIGNORE.tmp"' EXIT
printf '%s\n' "$block" > "$block_file"

if [[ -f "$GITIGNORE" ]] && grep -qF "$BEGIN" "$GITIGNORE"; then
    awk -v begin="$BEGIN" -v end="$END" -v block_file="$block_file" '
        $0 == begin { while ((getline l < block_file) > 0) print l; close(block_file); skip = 1; next }
        $0 == end   { skip = 0; next }
        skip != 1   { print }
    ' "$GITIGNORE" > "$GITIGNORE.tmp"
    mv "$GITIGNORE.tmp" "$GITIGNORE"
else
    [[ -s "$GITIGNORE" ]] && printf '\n' >> "$GITIGNORE"
    cat "$block_file" >> "$GITIGNORE"
fi

echo "Applied .gitignore policy: OUTPUT_TRACKING=$OUTPUT_TRACKING"
