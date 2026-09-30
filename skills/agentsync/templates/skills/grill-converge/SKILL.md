---
name: grill-converge
description: Harden a high-stakes plan before implementation by looping autonomous adversarial grills against in-place architect amendments until a round comes back clean, then gating once with an independent review from the other CLI. Use after a plan is written and before orchestrate, for contract-level, cross-repo, or hard-to-reverse work where one grill pass isn't enough.
argument-hint: "[path to the plan file under review]"
---

# Grill Converge

```
architect (plan)  →  grill-converge (harden)  →  orchestrate (build)
```

`grill-plan` is one pass with the user present. This skill runs several autonomous rounds while the user is away: the user approves at convergence, not every round. It never writes code.

## Rules

- **You drive; the architect amends.** You run the loop and consolidate findings. The `architect` agent edits the plan in place. You never edit the plan yourself, and engineers don't enter until `orchestrate`.
- **A round is one grill plus one amendment.** Each round runs one adversarial grill with the active client (`grill-plan` in adversarial mode, or the `code-reviewer` agent reviewing the plan), followed by one architect amendment. Don't run two engines every round. Parallel adversaries produce hypotheticals faster than they find defects.
- **The peer CLI runs once, at the end.** When the native loop comes back clean, run one independent grill with the *other* CLI as a convergence gate: Codex if you're in Claude, Claude headless if you're in Codex. Its bar-clearing findings get one final amendment, and then you're done. There's no second peer pass. If the peer finds something structural, escalate to the user.
- **Decided list in every prompt.** Decisions the user already settled are never reopened. Flag only a broken *technical handling* of one.
- **Validate before folding.** Check every finding against the code (`path:line`) before it reaches the architect, and drop the ones that don't hold up.
- **The defect bar governs severity** (the `scope-discipline` rule). BLOCKER and MAJOR need a trigger, an observable consequence, and `path:line` evidence. Downgrade anything that falls short, whatever the engine tagged it. Tell every grill that finding nothing blocking is a valid result, because manufacturing a MAJOR to justify a round is the failure mode to avoid.
- **Findings don't auto-fold.** Only *required* findings go into the plan automatically. Adjacent defects and hypotheticals go to a Scope Candidates appendix for the user.
- **Amendments clarify; they don't grow.** Track the plan's length and its impacted-files list round over round. If the plan keeps getting longer, the loop is inflating the design rather than hardening it: stop and report that.
- **Cap at 3 native rounds.** If bar-clearing findings aren't falling by round 3, escalate. The plan needs a human decision or a rethink, not more grilling.

## Process

1. **Set up.** Create `workspace/grill-<topic>/`. Write the decided list: every choice the user has signed off on. List the context files the grill needs: the plan, its spec, and the code anchors its claims point at.
2. **Grill (round N).** Run the native adversarial grill with the plan, the context files, the decided list, and (from round 2 on) the previous round's consolidated findings. Ask it to verify each prior fix landed, to hunt for issues the amendments introduced, and to confirm nothing regressed. It writes `roundN-grill.md`: numbered BLOCKER / MAJOR / MINOR items, each with `path:line` and a concrete fix. The grill must not edit the plan.
3. **Consolidate** (your job; don't delegate it) into `roundN-consolidated.md`: validate each finding against the code, deduplicate, re-apply the defect bar, classify each item as required, adjacent, or hypothetical, and rank what's left.
4. **Amend.** Hand the consolidated list to the `architect`. For each item, it either folds the fix into the plan in place or adds a one-line `Rejected: <why>`. The plan stays implementation-ready after every pass.
5. **Converge.** Zero bar-clearing BLOCKER/MAJOR means the native loop is clean. Otherwise loop to step 2. Fold one-line fixes without spinning a full round.
6. **Peer gate (once).** Write a prompt file (role: skeptical principal engineer; task: find what's wrong or missing; inputs: the plan, context, decided list, and findings already addressed; output: a numbered BLOCKER / MAJOR / MINOR list with `path:line`; no edits). Then run the other CLI read-only:
   - From Claude: `codex exec --sandbox read-only -o workspace/grill-<topic>/peer-gate.md - < <promptfile>`
   - From Codex: `claude -p "$(cat <promptfile>)" > workspace/grill-<topic>/peer-gate.md`

   Validate and re-apply the bar. If nothing clears it, you've converged. If something does, run one final architect amendment and verify it yourself against the plan. A peer finding that contradicts a decision or a non-goal is rejected outright.

## Exit and output

Write `workspace/grill-<topic>/CONVERGED.md` and report back:

```markdown
# <Feature> — Grill: CONVERGED (<date>)

Plan: `<path>`

| Round | Blockers | Majors | Minors | Outcome |
|---|---|---|---|---|
| 1 | <n> | <n> | <n> | amended |
| peer gate | <n> | <n> | <n> | converged |

## Decisions made while the user was away (review these)
- ...

## Scope candidates (awaiting user)
- ...

## Next step
`orchestrate <plan path>`
```

For a plan that converges in one round with a clean peer gate, a short prose summary is fine.
