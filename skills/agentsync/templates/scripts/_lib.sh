#!/bin/bash
# Shared helpers for the sync scripts. Sourced by every sync_*.sh.

# Name of the per-directory ownership manifest agentsync writes into each target
# dir it manages (e.g. .claude/skills/.agentsync-manifest). It lists, one per
# line, the entries (skill dir names / agent file names) agentsync owns there.
# Entries not in the manifest were placed by the user or another generator and
# are NEVER touched — this is what lets agentsync share a dir like .claude/skills/
# with another tool instead of clobbering it.
AGENTSYNC_MANIFEST=".agentsync-manifest"

# Delegator/Claude-only skills (frontmatter with agent: or context:) are not
# fanned out to other surfaces.
is_delegator_skill() {
    grep -Eq '^(agent|context): ' "$1"
}

# Is <surface> enabled? SURFACES in agentsync.conf is authoritative; without it
# (pre-0.3.0 projects) a surface is on when its source dir exists.
surface_enabled() {
    local s="$1"
    if [[ -n "${SURFACES:-}" ]]; then
        [[ " $(printf '%s' "$SURFACES" | tr ',' ' ') " == *" $s "* ]]
    else
        [[ -d "$AGENTS_DIR/$s" ]]
    fi
}

# Ownership-scoped prune of a target directory. Removes only the entries
# agentsync owned on the previous sync (per the manifest) that are NOT in the
# new owned set — i.e. agentsync output the user has since removed from source.
# Foreign entries (never recorded in the manifest) are preserved. Then rewrites
# the manifest to the new owned set. Callers copy the owned entries in AFTER.
#
#   sync_prune_owned <target_dir> [owned_name ...]
sync_prune_owned() {
    local target="$1"; shift
    local -a owned=()
    [[ $# -gt 0 ]] && owned=("$@")
    local manifest="$target/$AGENTSYNC_MANIFEST"

    mkdir -p "$target"

    if [[ -f "$manifest" ]]; then
        local prev name keep
        while IFS= read -r prev; do
            [[ -n "$prev" ]] || continue
            keep=0
            for name in ${owned[@]+"${owned[@]}"}; do
                [[ "$name" == "$prev" ]] && { keep=1; break; }
            done
            [[ $keep -eq 0 ]] && rm -rf "${target:?}/$prev"
        done < "$manifest"
    fi

    if [[ ${#owned[@]} -gt 0 ]]; then
        printf '%s\n' "${owned[@]}" > "$manifest"
    else
        rm -f "$manifest"
    fi
}

# Merge-safe copy of regular files from a source dir into a target dir. Only
# agentsync-owned files are pruned; foreign files are preserved. $3 is an
# optional glob (default '*'); only regular files matching it are synced.
#
#   sync_dir_files <src_dir> <target_dir> [glob]
sync_dir_files() {
    local src="$1" target="$2" glob="${3:-*}"
    local -a names=()
    local f
    if [[ -d "$src" ]]; then
        for f in "$src"/$glob; do
            [[ -f "$f" ]] || continue
            names+=("$(basename "$f")")
        done
    fi
    sync_prune_owned "$target" ${names[@]+"${names[@]}"}
    for f in ${names[@]+"${names[@]}"}; do
        cp -f "$src/$f" "$target/$f"
    done
}

# Build one surface's agent set in a fresh staging dir: agents generated from
# the single-source roles/ first, then verbatim per-surface files on top (a
# same-named verbatim file overrides the generated one). Prints the staging dir;
# the caller syncs it into the target with sync_dir_files and removes it.
#
#   stage_agents <surface> <verbatim_src_dir> <glob>
stage_agents() {
    local surface="$1" verbatim="$2" glob="$3" stage f
    stage="$(mktemp -d "${TMPDIR:-/tmp}/agentsync-$surface.XXXXXX")"
    bash "$SCRIPT_DIR/gen_agents.sh" "$surface" "$stage" >&2
    if [[ -d "$verbatim" ]]; then
        for f in "$verbatim"/$glob; do
            [[ -f "$f" ]] && cp -f "$f" "$stage/"
        done
    fi
    printf '%s\n' "$stage"
}

# Merge-safe single-file write. Writes <src> to <dest> only when agentsync owns
# <dest> (recorded in the dir's manifest), <dest> doesn't exist yet, or <dest>
# already matches. A pre-existing foreign file — e.g. a hand-written
# .claude/settings.json — is left alone with a warning. Records ownership in
# <dest_dir>/.agentsync-manifest alongside any other owned entries.
#
#   sync_owned_file <src> <dest>
sync_owned_file() {
    local src="$1" dest="$2" dir base manifest
    dir="$(dirname "$dest")"; base="$(basename "$dest")"; manifest="$dir/$AGENTSYNC_MANIFEST"
    mkdir -p "$dir"
    if [[ -f "$dest" ]] && ! cmp -s "$src" "$dest" \
        && ! { [[ -f "$manifest" ]] && grep -qxF "$base" "$manifest"; }; then
        echo "  ! skipped $dest — exists and isn't agentsync-owned (merge $src into it by hand)" >&2
        return 0
    fi
    cp -f "$src" "$dest"
    { [[ -f "$manifest" ]] && grep -qxF "$base" "$manifest"; } || echo "$base" >> "$manifest"
}

# Keep only the portable skill frontmatter keys (the Agent Skills fields that
# Codex, OpenCode, and Copilot all recognize) plus any indented continuation
# lines of a kept key. An allowlist, not a denylist: dropping a key also drops
# its indented children, so a stripped nested key (hooks:, allowed-tools: …)
# never leaks orphaned YAML. $1 optionally extends the allowlist (regex alt).
#
#   normalize_skill [extra_keys] < SKILL.md
normalize_skill() {
    awk -v extra="${1:-}" '
        BEGIN {
            keep_re = "^(name|description|license|compatibility|metadata"
            if (extra != "") keep_re = keep_re "|" extra
            keep_re = keep_re "):"
            in_fm = 0; fm_count = 0; keep = 0
        }
        /^---$/ {
            fm_count++
            if (fm_count == 1) { in_fm = 1; print; next }
            if (fm_count == 2) { in_fm = 0; print; next }
        }
        in_fm == 1 {
            if ($0 ~ /^[^ \t]/) keep = ($0 ~ keep_re)
            if (keep) print
            next
        }
        { print }
    '
}

# Merge-safe, normalized copy of fan-out skills into a target dir: every
# non-delegator skill in <skills_src>, with <override_src>/<name> (if given)
# replacing a same-named shared skill for this target only.
#
#   sync_skills_normalized <skills_src> <target_dir> [override_src] [extra_keys]
sync_skills_normalized() {
    local src="$1" target="$2" override="${3:-}" extra="${4:-}"
    local -a owned=()
    local d name from entry
    for d in "$src"/* ${override:+"$override"/*}; do
        [[ -d "$d" && -f "$d/SKILL.md" ]] || continue
        is_delegator_skill "$d/SKILL.md" && continue
        name="$(basename "$d")"
        [[ " ${owned[*]+${owned[*]}} " == *" $name "* ]] || owned+=("$name")
    done
    sync_prune_owned "$target" ${owned[@]+"${owned[@]}"}
    for name in ${owned[@]+"${owned[@]}"}; do
        from="$src/$name"
        [[ -n "$override" && -f "$override/$name/SKILL.md" ]] && from="$override/$name"
        rm -rf "${target:?}/$name"
        mkdir -p "$target/$name"
        for entry in "$from"/*; do
            [[ "$(basename "$entry")" == "SKILL.md" ]] && continue
            cp -R "$entry" "$target/$name/"
        done
        normalize_skill "$extra" < "$from/SKILL.md" > "$target/$name/SKILL.md"
    done
}

# Merge-safe verbatim copy of skill directories (each must contain SKILL.md)
# from a source dir into a target dir. Foreign skill dirs are preserved.
#
#   sync_skill_dirs_verbatim <skills_src> <target_dir>
sync_skill_dirs_verbatim() {
    local src="$1" target="$2"
    local -a names=()
    local d
    if [[ -d "$src" ]]; then
        for d in "$src"/*; do
            [[ -d "$d" && -f "$d/SKILL.md" ]] || continue
            names+=("$(basename "$d")")
        done
    fi
    sync_prune_owned "$target" ${names[@]+"${names[@]}"}
    for d in ${names[@]+"${names[@]}"}; do
        rm -rf "${target:?}/$d"
        cp -r "$src/$d" "$target/$d"
    done
}
