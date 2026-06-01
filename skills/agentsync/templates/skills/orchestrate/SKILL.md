---
name: orchestrate
description: Drive an approved plan to clean, verified implementation by looping engineer → code-reviewer → engineer, phase by phase, until each phase passes review and verification. Use when you have an approved plan file and want the main session to delegate implementation and review end-to-end without writing code itself.
argument-hint: "[path to the approved plan file]"
context: main-session
---

# Orchestrate

Drive an approved plan to clean, verified implementation. The main session owns the loop; agents do the work. You delegate — you never edit code yourself.

## Rules

- You orchestrate; you do not implement. Code goes to the `engineer`, review to the `code-reviewer`. (Subagents can't spawn subagents — this skill only runs in the main session.)
- One phase in flight at a time. Don't start the next phase until the current one passes review **and** verification.
- Hand each agent only what it needs — the plan, the current phase, the diff under review, the prior findings on a fix pass. Don't replay the whole transcript.
- Blocking vs. nit: correctness bugs, plan deviations, and convention violations block and must be fixed. Pure nits don't — record them and move on.
- Cap the fix loop per phase (default 3 rounds). If the reviewer still returns blocking findings after the cap, stop and escalate to the user with the open findings — never loop forever.
- Don't commit. Stop at clean + verified and hand back to the user — the no-commit-attribution / plan-before-code rules still hold.

## Process

1. **Read the plan.** Load the plan file named in the argument. Identify its phases. If it isn't phased, treat the whole plan as a single phase. If the breakdown is ambiguous, confirm the phase list with the user before delegating.
2. **Per phase, run the loop:**
   1. **Implement** — delegate the phase to the `engineer`: the phase's goal, the files/contracts it touches, and the plan for context. Capture the engineer's change summary and the verification step it names.
   2. **Review** — delegate to the `code-reviewer`: the phase intent plus the `git diff` for this phase's work. It returns findings only, cited to `path:line`.
   3. **Fix** — if there are blocking findings, hand them back to the `engineer` to address (round += 1), then re-review (2). Repeat until the reviewer returns no blocking findings or the round cap is hit.
   4. **Verify** — run the plan's stated verification for the phase (test/build/manual check). On failure, feed the failure back to the `engineer` as a fix round and re-review. Clean review + passing verification = phase done.
3. **Advance** to the next phase, carrying forward only what it depends on.
4. **Escalate** if any phase exceeds the fix-round cap, verification can't be run, or a finding needs a decision the plan doesn't cover — stop and ask the user.

## Exit

Stop when every phase has passed review with no blocking findings and the plan's verification passes — or when a phase escalates. Don't commit; report and hand back.

## Output

Keep a running phase ledger as you go, then a final summary:

```markdown
## Orchestration: <plan>

| Phase | Status | Fix rounds | Verification |
|---|---|---|---|
| <phase> | ✓ clean / ⚠ escalated | <n> | <pass / fail / cmd> |

### Open (non-blocking)
- `path:line` — <nit the reviewer flagged, left unfixed>

### Escalations
- <phase>: <why it stopped, what decision is needed>

### Next step
<commit / run X / decision needed from user>
```

For a single-phase plan, prose is fine — don't ceremony a one-phase table.
