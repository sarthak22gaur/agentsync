---
name: port
description: Discipline for porting behavior from a source system into this codebase. Read the source and its tests first, port tests with the code, take behavior from the source and structure from good design, translate idioms through a project idiom map, check a semantic-traps list, and log every substitution, skipped test, shortcut, and issue found in the host. Use when implementing any task that ports code from another system or language.
---

# Port

The port's scope is the source system's behavior. The plan fixes **what** gets ported; this skill governs **how**.

## Project specifics

- **Source:** <fill in: where the source system lives, read-only; its language and test command>
- **Target:** <fill in: the module or package the port lands in, and its contract files>
- **Fixed constraints:** <fill in: host invariants that are never traded for fidelity, e.g. the host's auth, tenancy, data-access path, service boundaries>
- **Port log:** `workspace/reports/<port-slug>/<lane or task>.md` by default

## 1. Read before writing

For each module you port:

1. Read the source and **its tests** in full. Grep its callers to learn the interface that's actually used.
2. Read the spec or docs for the behavior, if any. Where code and docs disagree, the code wins.
3. Read the target contract. If the source's call sites need something the contract doesn't expose, that's an interface request (`swarm`) or a scope candidate, not a local edit.

## 2. Tests first, or together

- Port in **vertical slices**: one source test (or a tight group for one behavior), its port, watch it fail against the stub, implement, green. Don't port a whole test file and then a whole module.
- Test through the module's **public interface**, the seam callers use. No tests of private functions or internal state.
- Expected values come from the source test's literals or a captured source run, never recomputed the way the code computes them.
- Keep source test names recognisable in plain domain terms, so parity is countable without source paths in the repo.
- A source test you don't port (a deferred feature, source-only infrastructure, language-internal behavior) goes in the port log with a one-line reason. No empty or skipped placeholders in the repo.

## 3. Idiom map

<fill in: one row per source idiom, mapped to the host's equivalent>

| Source | Host |
|---|---|
| value objects / records | |
| validation models | |
| ORM model, repository, transaction | |
| row lock / compare-and-set | |
| async / concurrency | |
| background tasks, scheduled jobs | |
| templating | |
| HTTP client | |
| test fixtures, parametrized tests, time freezing, HTTP mocks | |
| enums, custom exceptions | |

## 4. Semantic traps

Check every one when porting a branch or a computation:

- **Truthiness**: which of `0`, `""`, empty collections, and null are false differs by language. Port `if x` as the check the source means.
- **Numbers**: rounding mode (banker's vs half-up), integer vs float division, floor vs truncation on negatives, integer overflow, decimal precision.
- **Maps**: missing-key behavior (null, default, or raise), and key types (strings vs symbols, case).
- **Ordering**: sort stability, where nulls sort, map iteration order.
- **Time**: time-zone awareness, the clock source, and serialization format.
- **Strings**: formatting of floats and null (`"None"`, `""`, `"null"`), encoding, regex dialect, slicing past the end.
- **Errors**: exceptions vs return values, and what the source swallows.
- **Concurrency**: what the source serializes implicitly (a single thread, a transaction, a lock) that the host doesn't.

## 5. Preserve behavior

- **Never drop a feature as unneeded.** If the source does it and the plan doesn't defer it, port it.
- **Never "improve" semantics silently.** Port a source bug as-is and report it (source `path:line` and the consequence); the user decides.
- **Substitutions**: a source library with no host equivalent stops for the user. Log the decision: the library, what it did, the replacement, and the behavior differences.

## 6. How to write it

Apply the engineer's code-quality ladder to the implementation, never to the scope: reuse the host, then its stdlib or framework, then an existing dependency, then the minimum code. No speculative abstraction. A known limit gets a `shortcut: <limit>, <when to upgrade>` comment and a port-log entry.

**Behavior from the source, structure from good design.** The source grew by iteration, and some rules live in several places. Port each rule once, into the module that owns it, and route every caller through that module's contract. If another lane owns it, send an interface request instead of writing a second copy.

- Keep modules **deep**: a small interface hiding a lot of behavior. Don't mirror the source's file split if it produces shallow pass-through layers.
- Contracts take and return plain domain values, never ORM objects, clients, or framework types.
- Inject a collaborator only where something really varies or a test can't be written otherwise (an external provider, a clock, an ID generator).
- Follow host conventions (naming, result types, auth, jobs, fixtures), but don't copy host structure that's known to be slow. <fill in: host performance rules, e.g. no query in a loop, aggregates in the database, bounded lists, large columns loaded only where used>

## 7. Issues in the host

Anything that looks wrong elsewhere in the host codebase (a slow query, a bug, an authorization gap, dead code) goes in your report for the plan's issues log: `path:line`, what looks wrong, why it would matter, your confidence, and whether the port is affected. Note it and keep porting. Don't verify it, don't reproduce it, and never edit those repos or modules for it. Low-confidence entries are welcome.

## 8. Port log and report

Keep one port log per lane or task with three sections: **Skipped tests** (source test, reason), **Substitutions**, and **Shortcuts** (path, limit). It's a workspace artifact; never reference it from the repo (the `durable-references` rule).

End every task report with: source tests ported vs total for the module, tests run and their results, skipped or unchecked items, and risks. When a fixed constraint blocks a faithful port, stop and ask.
