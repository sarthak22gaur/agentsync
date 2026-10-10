---
name: cleanup-loop
description: Structured audit, fix, and verify cycle for code and UI cleanup. Scopes the work, audits it against concrete criteria, has the user triage, fixes the approved items, and re-verifies until clean. Use when asked to clean up, tidy, or de-cruft a file, feature area, or branch diff.
argument-hint: "[scope: files, a feature area, or \"all changed files on this branch\"]"
---

# Cleanup Loop

A repeatable audit → triage → fix → verify cycle that runs until the reviewer reports CLEAN. Cleanup removes problems; it doesn't add features.

## Process

1. **Scope.** Take it from the argument, or ask: a set of files, a feature area, or a branch diff (`git diff --name-only <base>...HEAD`).
2. **Audit.** Delegate to the area's `code-reviewer` with the scope and the criteria below. It returns a numbered list, each item with `path:line`, the problem, and a suggested fix, grouped as **Critical** (must fix), **Improvement** (should fix), and **Nitpick**, plus a one-line count.
3. **Triage.** Present the list and wait for the user: "fix all", "critical + improvement", or numbers.
4. **Fix.** Delegate the approved items, by number with `path:line`, to the area's `engineer`. It fixes each one, runs the project's verification, and commits.
5. **Verify.** Send it back to the same reviewer to confirm each item is resolved and the fixes introduced nothing new. It returns **CLEAN** or a new numbered list.
6. **Loop.** CLEAN means done: report a summary. Otherwise return to step 3. After 3 rounds, hand the remaining items to the user to decide.

## Rules

- The reviewer and the engineer are different agents. No self-review.
- Don't expand scope mid-loop. Issues outside the scope are noted separately as scope candidates.
- Commit after each fix round, and only once verification passes.
- No "while we're here" features, and no comments, docstrings, or type annotations added to code the cleanup didn't touch.
- Do add a concise comment where the cleanup creates or touches non-obvious behavior: a cross-boundary contract, a concurrency or resource limit, a security constraint, an invariant the names don't show. Don't narrate obvious code.

## Audit criteria

**Dead code**: unused imports, variables, functions, components, props, and dependencies; commented-out code (not TODOs); unreachable branches; state that's set but never read.

**Structure**: logic leaking across layers (business rules in handlers, controllers, or UI components; queries outside the data layer); functions or components doing several jobs; implicit dependencies on global state; circular imports or import-time side effects; internal imports that bypass a module's public interface.

**Consistency**: mixed patterns for the same thing (response shapes, error handling); names that don't match behavior (a `get_` that mutates).

**Type safety and suppressions**: escape-hatch types (`any`, `Any`, casts) where a concrete type is knowable; missing types on public functions; lint or type suppressions without a reason.

**Duplication**: copy-pasted blocks that should share one function; the same transformation done differently in several places.

**Error handling**: swallowed errors, messages that lose context ("something went wrong"), and paths that crash where they should degrade.

**Naming**: abbreviations that hurt reading (beyond `id`, `url`, `db`), booleans not phrased as questions, names describing implementation rather than intent.

**Useless tests** (delete, don't fix): snapshot tests of serialization, create-then-read-back tests of the ORM, tests that mock everything and verify only the wiring, assertions on exact log or format strings, trivial constructor tests, duplicate coverage, tautologies, tests of framework behavior, and snapshots that cement current rather than intended behavior.

**UI** (where in scope): business logic in components, state duplicated from props, effects where derived state or a handler would do, unstable list keys, inconsistent spacing and typography for same-level elements, interactive elements without keyboard support or labels, color as the only signal.

**Project-specific**: <fill in: stack-specific checks, e.g. framework anti-patterns, tenancy or auth scoping, the project's own conventions>
