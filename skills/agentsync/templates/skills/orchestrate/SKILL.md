---
name: orchestrate
description: Drive an approved plan to clean, verified, committed implementation by looping engineer → code-reviewer → engineer phase by phase, with the main session delegating and filtering findings rather than writing code. Use when you have an approved plan file and want implementation and review run end-to-end.
argument-hint: "[path to the approved plan file]"
---

# Orchestrate

The main session owns the loop, and agents do the work. You delegate; you never edit code yourself.

## Rules

- **You orchestrate; you don't implement.** Code goes to the `engineer`, review goes to the `code-reviewer`. Run this from the main session. The session's model is the orchestrator: don't spawn a replacement orchestrator.
- **Spawn deliberately.** One agent per job. Never spawn a second agent to double-check the first one's work; that's the reviewer's job, done once. Extra agents add cost and wall-clock time without improving the result.
- **Name the spawn explicitly.** Some runtimes (Codex, for one) only delegate when told to directly. Say "spawn the `engineer` agent for this phase" rather than hoping the runtime infers it.
- **Route by area.** If the project defines several engineer/reviewer pairs (for example backend and frontend), send each phase to the pair that owns its files, and split a phase that spans both.
- **Size the work, then the model.** Classify each phase before spawning:
  - *mechanical*: renames, moves, boilerplate, config edits, no design judgment
  - *moderate*: everyday feature work that follows an existing pattern
  - *sophisticated*: novel or subtle logic, ambiguous edge cases, cross-cutting design

  If the runtime supports a per-spawn model or effort override, run mechanical phases on a cheaper, faster setting and sophisticated ones on the strongest. Otherwise let agents inherit the session model. Reviewers always run at the strongest setting, whatever the phase's tier. Pick overrides from what the active runtime actually offers (its model list or effort levels); don't hardcode model names here.
- **Group small phases.** Before starting, fold runs of small or tightly coupled phases into one execution round: implement them in order, commit each phase separately, then review the combined diff once. Split a phase that's too broad to review in one diff. State the grouping up front, and confirm it with the user if it departs materially from the plan.
- **State scope in every prompt.** Each engineer and reviewer prompt names the phase's goal, its explicit non-goals, and the files it's expected to touch. Hand each agent only what it needs (the plan, the phase, the diff, prior findings on a fix pass), not the whole transcript.
- **Reviewers report; you filter.** Never tell a reviewer to be conservative or to skip low-severity items, because models follow that literally and drop real bugs. Let the reviewer report everything with its own severity and confidence, then apply the defect bar yourself (the `scope-discipline` rule).
- **Sort every finding into one lane:**
  - *Fix*: correctness bugs, plan deviations, and scope the diff introduced beyond the phase. It must clear the defect bar: trigger, observable consequence, `path:line`. Goes back to the engineer.
  - *Reject*: contradicts an approved decision or a non-goal, restates a requirement more strictly, or is a hypothetical with no trigger. Record it with one line of reasoning. It never reaches the engineer, and it's never put to the user as a plan revision.
  - *Escalate*: a real, reproducible defect outside the approved scope. Pause it and report it to the user.
- **Watch the diff size.** Compare each round's diff with the plan's expected footprint. A fix round that grows the diff is a self-expanding loop: stop and cut back to the plan.
- **Proportional review.** A five-line config change gets a light pass, not the full ceremony.
- **Demand the report.** Tell the reviewer its findings must be its final message. If it stops without writing them up, resume the same agent and ask for the write-up rather than treating the partial transcript as the review.
- **Cap the fix loop** at 3 rounds per phase. Never ask for an extra round. At the cap, re-apply the defect bar to what remains (findings that survive three rounds are often hypotheticals), commit what is reviewed and verified, and escalate the rest.
- **Tests don't block on their own.** Missing coverage or test-style nits never start a fix round. A failing test that exercises the phase's behavior does.
- **Commit as you go.** Commit each phase once its review is clean and verification passes, before you start the next phase: one commit per phase, on the current branch, named in plain terms (no plan or phase IDs), with no AI attribution. Never end a long run with zero commits. Escalate on top of a commit. Never commit to the default base branch, and don't force-push. Push only if the user asked or the project's conventions say to.
- **Respect repo boundaries.** In a multi-repo workspace, run `git` from inside the repo that owns the change.

## Process

1. **Read the plan.** Load the plan file named in the argument, identify its phases and which area each touches, and decide the execution grouping. An unphased plan is a single phase. If you're on the default branch, create a feature branch before the first commit.
2. **For each round:**
   1. **Implement.** Classify the tier, then delegate to the area's engineer with the goal, non-goals, files, and plan context. Tell it to implement only the approved scope and to report anything outside it rather than build it. Capture its change summary and the verification step it names.
   2. **Review.** Delegate to the area's reviewer with the phase intent, the non-goals verbatim, and the diff for this round. It returns findings only, cited to `path:line`.
   3. **Fix.** Sort the findings into lanes. Send the Fix lane back to the same engineer (round += 1), then re-review. Repeat until no bar-clearing findings remain or you hit the cap.
   4. **Verify.** Run the plan's stated verification (build, type-check, tests, or a manual check). A failure goes back to the engineer as a fix round. A clean review plus passing verification means the phase is done.
   5. **Commit** each phase in the round (see Rules).
3. **Peer gate (optional, once).** After every phase is done, if the cumulative change is genuinely complex or touches critical surfaces (public contracts, schemas and migrations, auth and secrets, concurrency, cross-repo seams), run one independent review with the *other* CLI, headless and read-only. From Claude, use `codex exec --sandbox read-only -o <outfile> - < <promptfile>`. From Codex, use `claude -p "$(cat <promptfile>)" > <outfile>`. Give it the cumulative diff, the non-goals, and the decided list. Validate every finding against the code before acting on it. Bar-clearing findings get one final fix, review, verify, and commit pass. Never run the peer gate per phase or twice. Skip it for routine work, or if the user asks for native review only.
4. **Escalate** when a phase hits the cap, verification can't run, or a finding needs a decision the plan doesn't cover.

## Exit

Stop when every phase is reviewed, verified, and committed (and the optional peer gate has run once), or when a phase escalates. Don't open a PR unless asked. Report and hand back.

## Output

Keep a running ledger, then summarize:

```markdown
## Orchestration: <plan>

| Phase | Tier | Engineer / Reviewer | Status | Fix rounds | Verification | Commit |
|---|---|---|---|---|---|---|
| <phase> | mechanical/moderate/sophisticated | <agent@setting> / <agent> | ✓ clean / ⚠ escalated | <n> | <pass / fail / cmd> | <sha> |

### Rejected findings
- `path:line` — <finding> | why: <no trigger / contradicts decision / non-goal / stricter than written>

### Scope candidates (awaiting user)
- `path:line` — <finding> | blocking: <yes/no> | smallest change: <...> | recommendation: <...>

### Escalations
- <phase>: <why it stopped, what decision is needed>

### Next step
<push / open a PR / decision needed>
```

For a single-phase plan, prose is fine.
