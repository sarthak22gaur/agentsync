#!/bin/bash
# Generate per-surface agent definitions from the single-source role files in
# agents/roles/<name>.md. One role = one file; each surface's native format is
# derived from the canonical frontmatter plus an optional per-surface block.
#
#   gen_agents.sh <claude|codex|opencode|github> <out_dir>
#
# Role frontmatter (flat `key: value` lines, plus indented per-surface blocks):
#   name, description          required
#   tier                       reasoning effort on every surface (low|medium|high|xhigh)
#   access                     write | read-only  → tools / sandbox / permissions
#   surfaces                   [claude, codex, opencode, github] — where it's emitted
#   skills                     [a, b] — preloaded (Claude) / listed as Required Skills
#   claude: / codex: / opencode: / github:
#                              indented native keys passed through to that surface
#                              only (e.g. Claude hooks, Copilot handoffs). A key set
#                              here overrides the derived one (tools, permission, …).
#                              For codex, `key: value` lines become `key = value`.
#
# No `model` is emitted anywhere unless a per-surface block sets one: agents
# inherit the session/parent model, so nothing goes stale on a model rename.
# Writes into <out_dir>; the caller does the merge-safe copy into the target.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROLES_DIR="$AGENTS_DIR/roles"

[[ -f "$AGENTS_DIR/agentsync.conf" ]] && source "$AGENTS_DIR/agentsync.conf"
CODEX_EXEC_PREFIX="${CODEX_EXEC_PREFIX:-}"

surface="${1:?usage: gen_agents.sh <surface> <out_dir>}"
out="${2:?usage: gen_agents.sh <surface> <out_dir>}"
mkdir -p "$out"

# Top-level scalar from the frontmatter (unindented `key: value`).
fm_get() {
    awk -v key="$2" '
        NR == 1 && $0 == "---" { in_fm = 1; next }
        in_fm && $0 == "---" { exit }
        in_fm && index($0, key ":") == 1 {
            v = substr($0, length(key) + 2); sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
            print v; exit
        }
    ' "$1"
}

# Per-surface block: lines indented under `<surface>:`, dedented by two spaces.
fm_block() {
    awk -v key="$2" '
        NR == 1 && $0 == "---" { in_fm = 1; next }
        in_fm && $0 == "---" { exit }
        in_fm && inb && /^  / { print substr($0, 3); next }
        in_fm && inb && /^[^ ]/ { inb = 0 }
        in_fm && $0 == key ":" { inb = 1 }
    ' "$1"
}

# Everything after the closing frontmatter fence, leading blank lines trimmed.
body() {
    awk '
        NR == 1 && $0 == "---" { in_fm = 1; next }
        in_fm && $0 == "---" { in_fm = 0; started = 0; next }
        in_fm { next }
        !started && /^[ \t]*$/ { next }
        { started = 1; print }
    ' "$1"
}

# "[a, b]" → one item per line.
list_items() {
    printf '%s\n' "$1" | tr -d '[]' | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'
}

# Does the block define a top-level key?
block_has() { printf '%s\n' "$1" | grep -q "^$2:"; }

# Block minus the given top-level keys (and their indented children).
block_without() {
    local blk="$1"; shift
    printf '%s\n' "$blk" | awk -v drop="$*" '
        BEGIN { n = split(drop, d, " "); for (i = 1; i <= n; i++) skip[d[i]] = 1 }
        /^[^ ]/ { k = $0; sub(/:.*/, "", k); cur = (k in skip) }
        !cur && NF { print }
    '
}

yaml_list() { # name, items...
    local name="$1"; shift
    [[ $# -gt 0 ]] || return 0
    echo "$name:"
    local i; for i in "$@"; do echo "  - $i"; done
}

skills_section() {
    [[ -n "$1" ]] || return 0
    echo "## Required Skills"
    echo ""
    echo "Load these skills before starting and apply them to every file you touch:"
    list_items "$1" | sed 's/^/- /'
    echo ""
}

toml_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

emit_claude() {
    local f="$1" name="$2" desc="$3" tier="$4" access="$5" skills="$6" blk
    blk="$(fm_block "$f" claude)"
    echo "---"
    echo "name: $name"
    echo "description: $desc"
    [[ -n "$tier" ]] && ! block_has "$blk" effort && echo "effort: $tier"
    if ! block_has "$blk" tools; then
        if [[ "$access" == "read-only" ]]; then yaml_list tools Read Grep Glob Bash
        else yaml_list tools Read Grep Glob Bash Edit Write; fi
    fi
    if ! block_has "$blk" disallowedTools && [[ "$access" == "read-only" ]]; then
        yaml_list disallowedTools Write Edit NotebookEdit Agent
    fi
    if [[ -n "$skills" ]] && ! block_has "$blk" skills; then
        # shellcheck disable=SC2046
        yaml_list skills $(list_items "$skills")
    fi
    # Inline lists in the block ([a, b]) are expanded to YAML lists for Claude.
    printf '%s\n' "$blk" | awk '
        /^[^ ][^:]*: \[.*\]$/ {
            k = $0; sub(/:.*/, "", k); v = $0; sub(/^[^:]*: \[/, "", v); sub(/\]$/, "", v)
            print k ":"; n = split(v, a, ","); for (i = 1; i <= n; i++) { gsub(/^ +| +$/, "", a[i]); if (a[i] != "") print "  - " a[i] }
            next
        }
        NF { print }
    '
    echo "---"
    echo ""
    body "$f"
}

emit_codex() {
    local f="$1" name="$2" desc="$3" tier="$4" access="$5" skills="$6" blk b
    blk="$(fm_block "$f" codex)"
    b="$(skills_section "$skills")"
    if [[ -n "$CODEX_EXEC_PREFIX" ]]; then
        b="$b

## Command Environment

Codex shells don't load the project's environment on their own. Run every project command through it: \`$CODEX_EXEC_PREFIX <command>\` (from inside the owning repo). If a tool reports \"command not found\", retry through the prefix before concluding it's missing.
"
    fi
    b="$b

$(body "$f")"
    b="$(printf '%s\n' "$b" | awk 'NF { started = 1 } started')"
    if [[ -n "$CODEX_EXEC_PREFIX" ]]; then
        # `cd <dir> && cmd` → `cd <dir> && <prefix> cmd` (idempotent).
        local p; p="$(printf '%s' "$CODEX_EXEC_PREFIX" | sed 's/[&/\]/\\&/g')"
        b="$(printf '%s\n' "$b" | sed -E "s/(cd [^ &;\`]+ && )/\1$p /g; s/($p )+/$p /g")"
    fi
    if printf '%s' "$b" | grep -q '"""'; then
        echo "gen_agents: $f body contains a TOML triple-quote (\"\"\")" >&2; exit 1
    fi
    echo "name = \"$(toml_escape "$name")\""
    echo "description = \"$(toml_escape "$desc")\""
    [[ -n "$tier" ]] && ! block_has "$blk" model_reasoning_effort && echo "model_reasoning_effort = \"$tier\""
    if ! block_has "$blk" sandbox_mode; then
        if [[ "$access" == "read-only" ]]; then echo 'sandbox_mode = "read-only"'
        else echo 'sandbox_mode = "workspace-write"'; fi
    fi
    printf '%s\n' "$blk" | awk '
        /^[^ ][^:]*:/ {
            k = $0; sub(/:.*/, "", k); v = $0; sub(/^[^:]*:[ \t]*/, "", v)
            if (v !~ /^(\[|"|[0-9.]+$|true$|false$)/) { gsub(/"/, "\\\"", v); v = "\"" v "\"" }
            print k " = " v
        }
    '
    echo ""
    echo 'developer_instructions = """'
    printf '%s\n' "$b"
    echo '"""'
}

emit_opencode() {
    local f="$1" name="$2" desc="$3" tier="$4" access="$5" skills="$6" blk edit
    blk="$(fm_block "$f" opencode)"
    echo "---"
    echo "description: $desc"
    block_has "$blk" mode || echo "mode: subagent"
    if ! block_has "$blk" permission; then
        [[ "$access" == "read-only" ]] && edit=deny || edit=allow
        echo "permission:"
        echo "  edit: $edit"
        echo "  bash:"
        echo '    "*": allow'
        echo '    "git push*": ask'
        echo "  task: deny"
    fi
    printf '%s\n' "$blk" | awk 'NF'
    echo "---"
    echo ""
    skills_section "$skills"
    body "$f"
}

emit_github() {
    local f="$1" name="$2" desc="$3" tier="$4" access="$5" skills="$6" blk
    blk="$(fm_block "$f" github)"
    echo "---"
    echo "name: $name"
    echo "description: $desc"
    if ! block_has "$blk" tools; then
        if [[ "$access" == "read-only" ]]; then echo "tools: ['read', 'search']"
        else echo "tools: ['read', 'search', 'edit', 'execute']"; fi
    fi
    printf '%s\n' "$blk" | awk 'NF'
    echo "---"
    echo ""
    skills_section "$skills"
    body "$f"
}

case "$surface" in
    claude|opencode) ext=".md" ;;
    codex)           ext=".toml" ;;
    github)          ext=".agent.md" ;;
    *) echo "gen_agents: unknown surface '$surface'" >&2; exit 1 ;;
esac

[[ -d "$ROLES_DIR" ]] || exit 0
n=0
for f in "$ROLES_DIR"/*.md; do
    [[ -f "$f" ]] || continue
    name="$(fm_get "$f" name)"
    desc="$(fm_get "$f" description)"
    if [[ -z "$name" || -z "$desc" ]]; then
        echo "gen_agents: $f needs name and description" >&2; exit 1
    fi
    surfaces="$(fm_get "$f" surfaces)"
    if [[ -n "$surfaces" ]] && ! list_items "$surfaces" | grep -qx "$surface"; then
        continue
    fi
    tier="$(fm_get "$f" tier)"
    access="$(fm_get "$f" access)"; access="${access:-write}"
    skills="$(fm_get "$f" skills)"
    [[ "$(list_items "$skills" | wc -l | tr -d ' ')" == "0" ]] && skills=""
    "emit_$surface" "$f" "$name" "$desc" "$tier" "$access" "$skills" > "$out/$name$ext"
    n=$((n + 1))
done
echo "  generated $n $surface agent(s) from roles/"
