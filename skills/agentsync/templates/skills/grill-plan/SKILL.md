---
name: grill-plan
description: Stress-test a plan, design, architecture choice, or implementation approach before work begins, either interactively with the user or as an autonomous adversarial pass. Use when the user asks to be grilled, wants a plan challenged, is choosing between approaches, or is about to delegate substantial work to agents.
argument-hint: "[plan, design, feature idea, PRD, ticket, or question to stress-test]"
---

# Grill Plan

Turn fuzzy intent into a decision that's ready to implement. Keep it tight: the goal is shared understanding, not a questionnaire.

## Modes

- **Interactive (default):** the user is present. Ask one question at a time, each with your recommended answer and why.
- **Adversarial (autonomous, e.g. from `grill-converge`):** no user is present. Ask no questions. Verify every claim against the code, treat the supplied decided list as settled, and return a numbered BLOCKER / MAJOR / MINOR list, each item with `path:line` evidence and a concrete fix. Find what's wrong or missing; don't praise.

In both modes, severity follows the defect bar (the `scope-discipline` rule). BLOCKER and MAJOR need a real trigger, an observable consequence, and `path:line` evidence. Don't invent an adversary the plan never declared, and don't restate a requirement more strictly and then fault the plan for missing your version. **A pass that finds only hypotheticals is a clean pass: say so.**

Classify every finding as **required** (the plan's fix doesn't work without it), **adjacent confirmed defect**, or **hypothetical**. Only required items go into the recommendation. The rest go under Scope Candidates. If the plan already looks overengineered for the problem it solves, make that your top finding.

## Rules

- If the answer is in the repo, look it up instead of asking. Cite `file:line` for any factual claim, and label anything unverified as an assumption.
- Don't implement until the user ends the grill and asks for implementation.
- Keep a running ledger of confirmed, assumed, and open items.
- Don't spend questions on test coverage. Tests belong only where logic could realistically break.

## Process

1. Identify the artifact, the target repo, and the expected output. Ask one clarifying question only if something is genuinely ambiguous.
2. Read what's already there: `AGENTS.md`, relevant `workspace/{plans,docs,knowledge}/`, the code behind any behavior claim, the project's `{{PROJECT_NAME}}-ground-truth` skill, and any `<area>-patterns` skill for the target area.
3. Ask (or, in adversarial mode, check) the highest-leverage unresolved point, roughly in this order: goal and non-goals, user-visible behavior, contracts that change, existing constraints, risk and reversibility, verification, who executes.
4. If durable domain language or rationale comes up, propose a `workspace/knowledge/` update, but edit it only when asked.

## Exit

Stop when the next implementation step is obvious, the remaining unknowns are listed and non-blocking, and verification is named.

## Output

```markdown
## Recommendation
<one line>

## Decisions
- ...

## Open
- ...

## Scope Candidates
- `path:line` — <finding> | blocking: <yes/no> | smallest change: <...> | recommendation: <include / backlog / discard>

## Evidence
- `path:line` — ...

## Next Step
Use `<agent-or-skill>` to <action>.
```

For a small grill, prose is fine.
