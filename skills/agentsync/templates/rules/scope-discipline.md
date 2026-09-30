# Scope Discipline and the Defect Bar (Hard Rule)

## Smallest sufficient change

Implement the smallest change that fixes the stated problem. An approved plan authorizes its stated work and nothing more. Don't add frameworks, abstractions, retries, recovery machinery, compatibility layers, or new user-facing behavior the problem doesn't demonstrably need. Leave unrelated code as you found it.

When you find work outside the approved scope, classify it:
- **required** — the stated fix doesn't work without it. Proceed.
- **adjacent defect** — real and reproducible, but outside scope.
- **hypothetical** — plausible, not demonstrated.

Anything not required stops for the user: report it with `path:line`, whether it blocks the fix, the smallest version of it, and a recommendation. Don't implement it.

## What may block

A finding blocks (in a review, a grill, or a fix loop) only when it has all three:
1. a trigger the system actually receives,
2. an observable consequence, and
3. `path:line` evidence plus a failing test or a precise reproduction.

Anything short of that is a scope candidate: record it, don't fix it. Without a declared threat model, don't invent an adversary. Hardening against hostile inputs nobody named is a scope candidate, never a blocker.

## Approved plans are frozen

During implementation, don't reopen an approved decision, restate a requirement more strictly and then build to the stricter version, or propose something the plan lists as a non-goal. Where a plan sentence is ambiguous, take the smaller reading and say which one you took. A fix round should leave the diff the same size or smaller. If it keeps growing, the round is asking for the wrong thing.

## Tests earn their place

Write tests for logic that could realistically break: non-trivial business rules, parsers, state machines, boundaries between components. Don't write tests for framework behavior, trivial wiring, removed functionality, or hypothetical recovery paths. Missing coverage alone never blocks. When you remove a feature, remove its tests and any orphaned fixtures with it.
