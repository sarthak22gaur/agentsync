---
name: handoff
description: Write a compact handoff document so a fresh session can continue the current work after a context reset or compaction, covering state, decisions, next steps, artifact paths, and suggested skills, saved under workspace/handoffs/. Use when ending a long session, before compacting, pausing a swarm lane, or passing work to another session.
argument-hint: "[what the next session will focus on]"
disable-model-invocation: true
---

# Handoff

Write `workspace/handoffs/<YYYY-MM-DD>-<slug>.md` at the workspace root (a swarm lane uses `workspace/handoffs/swarm/<lane>-<YYYY-MM-DD>.md`). Handoffs live in the workspace, not a temp dir, because the work spans sessions. Take the date from `date`, not memory.

If arguments were given, they describe what the next session will do; tailor the document to that.

Contents, briefly:

- **Goal**: one or two lines, and the plan section it serves.
- **State**: per repo, the branch, last commit sha, worktree path if any, and uncommitted changes; what's verified (commands and results) and what isn't. Note anything running that the next session must know about (a dev server, a stack started with non-default config).
- **Decisions made this session** that aren't written down elsewhere, each with its reason.
- **Open items**: blockers, pending interface requests, scope candidates, and questions waiting on the user.
- **Next steps**: ordered and concrete.
- **Artifacts**: plan, decisions, reports, ledger, commits, by path or sha. Reference them; don't copy their content.
- **Suggested skills** for the next session to load (e.g. `orchestrate`, `swarm`, `diagnosing-bugs`, `{{PROJECT_NAME}}-ground-truth`).

Redact secrets and personal data: credentials, API keys, tokens, cookies, customer data.

Report the file path when done.
