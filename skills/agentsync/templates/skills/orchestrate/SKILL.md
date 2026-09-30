---
name: orchestrate
description: Drive an approved plan to clean, verified implementation by looping engineer → code-reviewer → engineer, phase by phase, committing each phase once it passes review and verification. Use when you have an approved plan file and want the main session to delegate implementation and review end-to-end without writing code itself.
argument-hint: "[path to the approved plan file]"
---

# Orchestrate

Drive an approved plan to clean, verified implementation. The main session owns the loop; agents do the work. You delegate — you never edit code yourself.

## Rules

- You orchestrate; you do not implement. Code goes to the `engineer`, review to the `code-reviewer`. (Subagents can't spawn subagents — this skill only runs in the main session.)
- One phase in flight at a time. Don't start the next phase until the current one passes review **and** verification.
- Hand each agent only what it needs — the plan, the current phase, the diff under review, the prior findings on a fix pass. Don't replay the whole transcript.
- Blocking vs. nit: correctness bugs, plan deviations, and convention violations block and must be fixed. Pure nits don't — record them and move on.
- Cap the fix loop per phase (default 3 rounds). If the reviewer still returns blocking findings after the cap, stop and escalate to the user with the open findings — never loop forever.
- Commit each phase once it's clean + verified, before starting the next — one commit per phase, on the current branch, with a message naming the phase. No AI attribution in the message (the no-commit-attribution / plan-before-code rules still hold). Never commit a phase that escalated — leave its partial work in the tree for the user. Push only if the user asks.

## Process

1. **Read the plan.** Load the plan file named in the argument. Identify its phases. If it isn't phased, treat the whole plan as a single phase. If the breakdown is ambiguous, confirm the phase list with the user before delegating. If you're on the default branch, create a feature branch before phase 1 so the per-phase commits don't land on the trunk.
2. **Per phase, run the loop:**
   1. **Implement** — delegate the phase to the `engineer`: the phase's goal, the files/contracts it touches, and the plan for context. Capture the engineer's change summary and the verification step it names.
   2. **Review** — delegate to the `code-reviewer`: the phase intent plus the `git diff` for this phase's work. It returns findings only, cited to `path:line`.
   3. **Fix** — if there are blocking findings, hand them back to the `engineer` to address (round += 1), then re-review (2). Repeat until the reviewer returns no blocking findings or the round cap is hit.
   4. **Verify** — run the plan's stated verification for the phase (test/build/manual check). On failure, feed the failure back to the `engineer` as a fix round and re-review. Clean review + passing verification = phase done.
   5. **Commit** — stage and commit this phase's work on the current branch with a concise message naming the phase (e.g. `<plan>: phase N — <title>`). One commit per phase, no AI attribution. Record any non-blocking nits in the commit body or the ledger, not as a follow-up commit.
3. **Advance** to the next phase, carrying forward only what it depends on.
4. **Escalate** if any phase exceeds the fix-round cap, verification can't be run, or a finding needs a decision the plan doesn't cover — stop and ask the user.

## Exit

Stop when every phase has passed review with no blocking findings and the plan's verification passes — or when a phase escalates. Each completed phase is already committed (one commit apiece); an escalated phase's work is left uncommitted in the tree. Report and hand back — push or open a PR only if the user asks.

## Output

Keep a running phase ledger as you go, then a final summary:

```markdown
## Orchestration: <plan>

| Phase | Status | Fix rounds | Verification | Commit |
|---|---|---|---|---|
| <phase> | ✓ clean / ⚠ escalated | <n> | <pass / fail / cmd> | <short sha / — if escalated> |

### Open (non-blocking)
- `path:line` — <nit the reviewer flagged, left unfixed>

### Escalations
- <phase>: <why it stopped, what decision is needed>

### Next step
<run X / push / open a PR / decision needed from user>
```

For a single-phase plan, prose is fine — don't ceremony a one-phase table.
