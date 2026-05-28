---
name: grill-plan
description: Stress-test a plan, design, architecture choice, or implementation approach before work begins. Use when the user asks to be grilled, wants a plan challenged, is choosing between approaches, or is about to delegate substantial work to agents.
argument-hint: "[plan, design, feature idea, PRD, ticket, or question to stress-test]"
---

# Grill Plan

Turn fuzzy intent into an implementation-ready decision. Keep it tight — shared understanding, not a questionnaire.

## Rules

- One question at a time. Include your recommended answer and why.
- If the answer is in the repo, look — don't ask. Cite `file:line` for any factual claim.
- Label unverified claims as assumptions.
- Don't implement until the user exits the grill and asks for it.
- Keep a running ledger of confirmed / assumed / open. Format is your call; markdown block is fine for big plans, prose is fine for small ones.

## Process

1. Identify the artifact (plan, feature, bug approach, SOP, agent handoff), target repo, and expected output. Ask one clarifier only if ambiguous.
2. Read what's already there — `AGENTS.md`, relevant `workspace/{plans,rfcs,docs,knowledge}/`, the code for any behavior claim, the project's `{{PROJECT_NAME}}-ground-truth` skill, and any `<area>-patterns` skill that covers the target area.
3. Ask the highest-leverage unresolved question. Cover (in roughly this order, skipping what's already settled): goal & non-goals, user-visible behavior, contracts that change, existing constraints, risk & reversibility, verification, who executes.
4. If the session surfaces durable domain language, architecture rationale, or external research worth keeping, propose a `workspace/knowledge/` update — but only edit `workspace/knowledge/` when explicitly asked.

## Exit

Stop when the next implementation step is obvious, remaining unknowns are listed and non-blocking, and verification is named.

## Output

```markdown
## Recommendation
<one line>

## Decisions
- ...

## Open
- ...

## Evidence
- `path:line` — ...

## Next Step
Use `<agent-or-skill>` to <action>.
```

For small grills, prose is fine — don't ceremony a two-question clarification.
