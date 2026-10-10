#!/usr/bin/env bash
# Human-in-the-loop reproduction loop. Copy outside the repo, edit the steps,
# run it; the user follows the prompts and the captured answers print as
# KEY=VALUE for the agent to read. Sign-in stays a `step`: never `capture`
# credentials, because captured values are echoed back.
set -euo pipefail

step() {
  printf '\n>>> %s\n' "$1"
  read -r -p "    [Enter when done] " _
}

capture() {
  local var="$1" question="$2" answer
  printf '\n>>> %s\n' "$question"
  read -r -p "    > " answer
  printf -v "$var" '%s' "$answer"
}

# --- edit below ---------------------------------------------------------

step "Open the app locally and sign in as the affected user."

capture ERRORED "Open the record from the bug report. Does the view fail to load or stop updating? (y/n)"

capture ERROR_MSG "Paste the error text or the failing request's status (or 'none'):"

# --- edit above ---------------------------------------------------------

printf '\n--- Captured ---\n'
printf 'ERRORED=%s\n' "$ERRORED"
printf 'ERROR_MSG=%s\n' "$ERROR_MSG"
