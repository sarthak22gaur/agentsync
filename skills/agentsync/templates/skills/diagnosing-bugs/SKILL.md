---
name: diagnosing-bugs
description: Diagnosis loop for hard bugs and performance regressions. Build a red-capable feedback loop first (a failing test, a scripted request, a replayed input), then reproduce, minimise, hypothesise, instrument, fix with a regression test, and clean up. Use when something is broken, throwing, failing, flaky, stuck, or slow and the cause isn't obvious.
---

# Diagnosing Bugs

A discipline for hard bugs. Skip a phase only when you can say why.

## Redact

Show commands and output with every secret replaced by `<REDACTED>`: credentials, API keys, tokens, cookies, auth headers, and personal data in payloads. Build loops that read credentials from the environment so they never appear in what you show. Quote only the lines of a log or payload that carry the signal. If the redacted output isn't enough, say so and ask.

## Phase 1: Build a feedback loop

This is the skill. With a tight pass/fail signal that goes red on **this** bug, the rest is mechanical. Without one, reading code won't save you. Spend disproportionate effort here.

Ways to build one, roughly in this order:

1. **A failing test** at the seam that reaches the bug, using the project's existing fixtures and seed helpers rather than ad-hoc mocks.
2. **A scripted request** against the local app (`curl` with auth from the environment), asserting on status and body.
3. **A replayed input**: a captured payload, message, or job arguments fed straight to the handler. Read-only queries against dev data to capture the real state; writes need the user's go.
4. **Logs from the running stack.** Useful for locating the failure, but not a loop by themselves.
5. **A browser driver** (e.g. Playwright) for UI-only symptoms.
6. **A differential loop**: the same input through two commits, two configs, or two tenants; diff the output.
7. **Bisection**: once the loop is a script, `git bisect run` it.
8. **Human in the loop**, as a last resort: copy `scripts/hitl-loop.template.sh` outside the repo, edit the steps, and run it. The captured answers come back to you.

Project specifics to bake into the loop: <fill in: the test command for one test, how to seed data, the local app URL and auth, where logs live, and common causes in this codebase (tenancy or auth context, background jobs that run inline in tests, at-least-once message delivery, time windows)>

Then tighten it: faster (narrow the test, skip unrelated setup), sharper (assert the exact symptom, not "didn't raise"), and deterministic (pin time, seed randomness, fix payloads). For a flaky bug, raise the reproduction rate (loop it 100 times, parallelise) until it's debuggable.

**Done when** you have one command, already run and shown (redacted), that asserts the user's exact symptom, is deterministic and fast, and runs unattended. No command, no Phase 2. If you can't build one, stop, list what you tried, and ask for an environment, a captured artifact, or permission for temporary instrumentation.

## Phase 2: Reproduce and minimise

Run the loop and confirm it shows the failure the user described, not a nearby one. Then cut inputs, records, callers, and config one at a time, re-running after each cut, until every remaining element is load-bearing.

## Phase 3: Hypothesise

Write 3–5 ranked, falsifiable hypotheses: "if X is the cause, changing Y makes it disappear." Show the list to the user before testing, since they often know which one it is. Don't block on an answer.

## Phase 4: Instrument

One probe per prediction, one variable at a time. Prefer a debugger; otherwise add targeted logs tagged with a unique prefix (`[DEBUG-a4f2]`) so cleanup is one grep. For performance, take a baseline first (a read-only `EXPLAIN ANALYZE`, a timing harness, enqueue/start/finish timestamps), then bisect.

## Phase 5: Fix and regression test

Write the regression test before the fix, at a seam that exercises the real bug pattern. Watch it fail, fix, watch it pass, then re-run the Phase 1 loop on the original scenario. If no correct seam exists, say so and name the manual check instead; that's a finding in itself.

The fix is the smallest change at the root cause (the `scope-discipline` rule), made once in the shared code. Grep every caller. Verify with the project's CLI checks (the `verify-with-cli` rule).

## Phase 6: Clean up

- [ ] The original loop is green.
- [ ] The regression test passes, or its absence is explained.
- [ ] No `[DEBUG-` tags are left (`grep -rn "DEBUG-" .`), and throwaway scripts are deleted.
- [ ] The commit message states the confirmed cause.
