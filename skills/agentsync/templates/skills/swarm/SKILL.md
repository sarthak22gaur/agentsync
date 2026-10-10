---
name: swarm
description: Run a lane-structured plan as a swarm. One coordinator session owns the plan and the integration branch, and up to N lane sessions each run orchestrate on one plan section in their own git worktree. Covers worktree setup, test isolation, briefing lanes, the merge protocol (owned-paths and duplication checks, full verification, revert on red), interface change requests, the dependency frontier, process budget, the ledger, and cleanup. Use when a plan defines parallel lanes.
argument-hint: "coordinator <plan path> | lane <lane> <plan path>"
---

# Swarm

An orchestrator of orchestrators. The **coordinator** is the session the user talks to. Each **lane** is a separate agent session running `orchestrate` on one plan section. They share each repo through git worktrees and one integration branch per repo. Every rule and the `orchestrate` rules still apply inside each session. Lane branches stay local: never pushed, never PR'd.

**Lanes are sessions, never subagents.** A lane runs `orchestrate`, which spawns its own engineer and reviewer subagents, and a subagent can't spawn subagents. A lane run as a subagent would also share the coordinator's context and turn budget. The coordinator's own work (shared-contract changes, merge reviews) does run as subagents in its session.

Defaults (the plan's working rules win where they name something else):

| Thing | Default |
|---|---|
| Integration branch | the plan's feature branch, checked out in each touched repo's main checkout |
| Lane branch | `swarm/<lane>`, local only |
| Lane worktree | `<worktrees-root>/<lane>/<repo>`, outside the main checkout, one per repo the lane touches |
| Max active lanes | 4, plus the coordinator |
| Ledger | `workspace/plans/.<plan-slug>.swarm.md`: lanes, branches, worktrees, session IDs, PIDs, status, open requests, findings |
| Lane brief | `workspace/handoffs/swarm/<lane>.md` |
| Lane prompt | `workspace/handoffs/swarm/<lane>.prompt.md` |

## Project specifics

- **Routing and verification:** <fill in: which engineer/reviewer pair owns which paths, and the full verification commands per repo>
- **Worktree environment:** <fill in: how tools load inside a worktree (env loader, virtualenv, `node_modules`), and what must never be installed or mutated from a lane (shared lockfiles, shared virtualenvs)>
- **Test isolation:** <fill in: how each lane gets its own test data (disposable containers, a per-lane test database name, a fixture dir). Lanes never share a writable test store and never touch dev data>
- **Shared stack:** <fill in: the one local stack every session shares (databases, queues, app server, ports)>
- **Shared contracts:** <fill in: files only the coordinator changes, e.g. migrations and schema, route registration, config and settings, dependency manifests and lockfiles, API types consumed across areas>

## Coordinator

You own the plan, the integration branches, the shared contracts, and the ledger. You don't implement lane work. Shared-contract changes go to the area's engineer, delegated on the integration branch.

### Setup (once per lane)

1. **Preconditions.** The plan's foundation is merged on the integration branch and its shared contracts are final. Check the frontier before starting a lane.
2. **Worktree.** From each touched repo's main checkout: `git worktree add <worktrees-root>/<lane>/<repo> -b swarm/<lane> <integration-branch>`. Set up its environment per Project specifics, writing only inside the worktree.
3. **Test isolation.** Provision the lane's test store per Project specifics. Creating a database is a write: show the user the exact commands and names once, and get a go.
4. **Brief.** Write the lane brief with pointers only: plan path and lane section heading, decisions doc, owned paths per repo, integration branch, worktree paths, test env, the lane's dependencies, and which contracts are still stubs. Don't restate plan text.
5. **Prompt.** Write the lane prompt. Its first line is `/swarm lane <lane> <plan>`, followed by pointers to the brief, worktree paths, and test env, and your own session name so the lane knows where to report.
6. **Launch** from the workspace root, so rules and skills load:
   - *Claude*: start a background session, `claude --bg --name <plan-slug>-<lane> --permission-mode <mode> "$(cat <lane prompt>)"`. It inherits the default model and effort; add `--model` / `--effort` only if the project pins them. Use the permission mode the user approved for unattended work, and ask once if they haven't said.
   - *Codex*, or a runtime without background sessions: ask the user to open a session per lane in its own terminal and paste the prompt. Codex can't message other sessions, so the ledger and the user carry every report.

   Record lane, branch, worktrees, session name, and session ID in the ledger.

### Messaging

If the runtime can list and message other sessions (Claude Code's `ListAgents` / `SendMessage`, for one), use it. Otherwise the user relays. Either way the ledger is the durable record. Keep messages short and pointer-based: "integration tip of `<repo>` is `<sha>`, merge it", "request 3 accepted, contract at `<path>` in `<sha>`". Never paste a lane's transcript back to it.

Watch and control background lanes with `claude agents` (list), `claude logs <id>` (recent output), `claude stop <id>` (stop; the conversation is kept), and `claude attach <id>` (open or resume one).

### Merge protocol

1. A lane reports **done** only after merging the current integration tip into its branch and passing its verification there.
2. Check the report against the branch, per repo: `git log <integration>..swarm/<lane>`.
   - **Owned paths.** `git diff --stat <integration>...swarm/<lane>` touches only the lane's owned paths. Anything else goes back to the lane.
   - **Duplication.** Read the lane's new public and private functions and search the integration branch for code that already does the same job (the same domain rule, transition, lookup, formatting, or external call, under any name). A copy goes back to the lane to call the existing owner. If the logic belongs in a module the lane doesn't own, you move it there behind the owner's interface and both lanes switch to it. Small helpers that merely look alike aren't duplicates. Record each finding in the ledger.
3. Merge in the main checkout: `git merge --no-ff swarm/<lane>`.
4. Run the **full** verification on the merged repo. Red means you revert the merge (`git revert -m 1 <merge>`) and send the failure to the owning lane. You don't fix lane code. Manual checks against the shared stack happen here, after the merge, never in a lane.
5. Record the new tip in the ledger, tell every other active lane to merge it, and recompute the frontier.

### Interface change requests

Lanes never edit shared contracts. They send a request (format under Lane), and you:

- Check it against the plan. A request that changes a plan decision or adds scope goes to the user (the `scope-discipline` rule), not into the branch.
- If accepted, delegate the smallest change to the area's engineer on the integration branch, run the full verification, commit, then notify the requesting lane and every lane that consumes the contract. Schema migrations are authored only by you, on the integration branch, so there's one migration head.
- Batch requests that touch the same file. Answer every request: accepted, rejected with one line, or waiting on the user.

### Frontier

The lanes form a dependency graph, not a sequence. The **frontier** is the set of lanes and tasks whose dependencies are merged. After every merge, recompute it and start the next ready lane while fewer than the max are active. A lane may start against a stub contract when the plan says so; tell it which stubs swap to real implementations as their lanes merge.

### Process budget

- One shared local stack. Check what's running (`lsof -nP -iTCP -sTCP:LISTEN`, `docker ps`) before starting anything. Never start a second copy of a database, queue, or app server, or start one from a worktree. Test containers that the test runner starts and stops itself are the only sanctioned extras.
- Any process a session starts (a dev server, a worker, a one-off script) goes in the ledger with its PID, port, owner, and purpose, and its owner stops it when done.

### Stalls and escalation

- A lane that hits its `orchestrate` fix-round cap, or waits on the user, is **paused**: its worktree and test store stay intact, the ledger says why, and you tell the user what decision is needed.
- A lane that stops responding: check its branch for recent commits before assuming it's dead, then ask the user.
- Escalate, don't decide: any plan change, any scope candidate, any destructive data command.
- Two lanes that need the same file outside a contract means the owned-path split is wrong. Stop both and resolve ownership with the user.

### Cleanup

When the plan's final phase is done: per repo, `git worktree remove <path>` and `git branch -d swarm/<lane>` (merged branches only, never `-D`). Stop every lane session (`claude stop <id>`) and every PID in the ledger, check for leaked test containers, and drop lane test databases only after the user confirms the exact statements. Mark the ledger closed. The integration branch stays; open PRs only when the user asks.

## Lane

You implement one plan section inside your worktrees and branch. Read your brief, then the plan section and decisions it points to.

- **Run `orchestrate`** on your lane section. Every engineer and reviewer prompt names your worktree paths, owned paths, test env, exact verification commands, and the skills to load. Commit per task inside your worktree.
- **Stay in owned paths.** Anything else is an interface request or a scope candidate. Don't work around a missing contract by editing it locally: stub it behind your own code and send a request.
- **Merge cadence.** Merge the integration tip into your branch (`git merge <integration-branch>`; never rebase a shared branch) when the coordinator announces a new tip, before each `orchestrate` round, and before reporting done. Resolve conflicts yourself, since you know your side's intent: read both sides' commit messages, keep both behaviors where they're compatible, and verify before committing the merge. Never resolve with a blanket `--ours` or `--theirs`.
- **Verify** in your worktree, against your own test store. Don't start services, and don't manually test against the shared stack: it runs the main checkout's code, not yours.

### Interface request

```
INTERFACE REQUEST · lane <lane>
Contract: <migration / schema / registration / file>
Change: <exact signature, column, route, setting, or dependency>
Why: <evidence, path:line>
Blocking: yes / no (working against a local stub until then)
```

### Report to the coordinator

Send on done, on block, and when asked. Done is valid only with the integration tip merged and verification green.

```
LANE <lane> · done | blocked | progress
Branch: swarm/<lane> @ <sha> per repo (integration tip merged: <sha>)
Commits: <sha> <subject>, ...
Verification: <command> → <result>, per gate
Interface requests: <open ids or none>
Blockers: <what, and what decision unblocks it>
Not checked / risks: <one or two lines>
```
