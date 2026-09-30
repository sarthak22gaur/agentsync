# Plan Before Code (Hard Rule)

Before any non-trivial implementation:

1. Produce or read an approved plan. Trivial means a single-file fix, a typo, formatting, or an isolated bug with an obvious cause. Everything else needs a plan: multi-file changes, cross-module or cross-repo work, new abstractions or schemas, and anything touching an external API surface.
2. The architect agent (or the user) writes the plan, and it lives in `workspace/plans/` or in the ticket/PR body.
3. The user approves the plan before implementation starts.
4. Engineers execute the plan; they don't author it.

When in doubt, ask the user whether a plan is needed.

## Plans stay private

Plans, phase labels, and review or grill artifacts are working documents. Never reference them in code, comments, docstrings, test names, branch names, commit messages, or PR titles and bodies. Explain the durable reason in plain domain terms, or leave it out.
