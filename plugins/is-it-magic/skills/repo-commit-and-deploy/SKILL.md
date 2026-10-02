---
name: repo-commit-and-deploy
description: "Chain a commit-and-push with a GitHub Actions workflow trigger in one step — commit the working tree (tests gate it), push, then fire the named deploy workflow(s). Use when you want to commit your work and kick off a deploy in a single command. Pushes and fires gate-free when you invoke it directly with scope and environment fully specified (even prod); keeps every safety gate. For commit-only, use repo-commit; for trigger-only, use repo-git-trigger-workflow."
---

Chain **repo-commit** → **repo-git-trigger-workflow** in a single user-authorised step: commit and push the working tree, then trigger the deploy workflow(s) on the just-pushed state.

This skill **reuses the mechanics** of the two underlying skills rather than redefining them. Read both before executing:

- Commit/push mechanics: `${CLAUDE_PLUGIN_ROOT}/skills/repo-commit/SKILL.md`
- Workflow-trigger mechanics: `${CLAUDE_PLUGIN_ROOT}/skills/repo-git-trigger-workflow/SKILL.md`

Follow their detailed steps verbatim, but apply **this skill's gate policy** (below) — do not invoke them as separate skills, run their steps inline as one chain.

## Arguments

`$ARGUMENTS` is **optional**. Everything in it is passed to the **trigger** step (workflow tokens + optional `on <project>` + environment / `key=value` inputs), exactly as `repo-git-trigger-workflow` parses them. The commit step commits **all** changes by default.

- Optional `commit:<path>` token — if present, scope the **commit** to that subdirectory (passed to `repo-commit` as its scope) and strip it from the string before the trigger step parses the rest.

**Examples:**

- `/repo-commit-and-deploy app prod` → commit all changes, push, then trigger the `app` workflow with `environment=prod`
- `/repo-commit-and-deploy api mcp on my-service prod` → commit all, push, then trigger `api` + `mcp` on `my-service` with `environment=prod`
- `/repo-commit-and-deploy commit:api api prod` → commit only `api/`, push, then trigger the `api` workflow on prod
- `/repo-commit-and-deploy` → commit all, push, then ask which workflow(s) to trigger (no tokens given)

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

Read and follow the context resolution contract in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_context-resolution.md`.

## Gate policy (this chain)

Invoking `/repo-commit-and-deploy` directly **is** the authorisation for the whole chain — the user has asked to commit *and* deploy in one breath. Therefore:

- **Routine push gate** (repo-commit's **Push** step) — **skipped**. Push without asking.
- **Routine trigger gate** (repo-git-trigger-workflow's **Confirmation gate** step) — **skipped when scope and every required input (including `environment`) are fully specified** in `$ARGUMENTS` (even `environment=prod`). If a workflow token was missing/ambiguous, or a required input had to be defaulted or asked, the trigger gate applies as normal.
- **When this skill is invoked programmatically** (by Claude via the Skill tool, another skill or workflow, or an agent/subagent — not a direct user slash command) → **both** routine gates apply. When the source is unclear, treat it as programmatic and gate.

**Safety gates always apply — regardless of invocation source:**

- Tests must pass (repo-commit's **Run tests** step). On any failure → report and **stop**. Do **not** commit, push, or deploy.
- Rebase-conflict stop (repo-commit's **Pull and rebase** step). On conflict → abort the rebase and **stop**. The commit is saved locally; do **not** deploy.
- Remote-owner mismatch check (repo-commit's **Context consistency check** step). On mismatch → ask before pushing; do not push or deploy until resolved.
- Plan/apply review gate (repo-git-trigger-workflow's **Confirmation gate** step). Never auto-chain `plan` → `apply` without reviewing plan output.

## Process

### Phase 1 — Commit and push

1. If a `commit:<path>` token is present, extract it as the commit scope and remove it from `$ARGUMENTS`; otherwise the commit is unscoped (all changes).
2. Run the **repo-commit** process (**Run tests** through **Push**) for that scope, applying the gate policy above:
   - Run tests for the scope. **If any fail → stop here. Do not proceed to Phase 2.**
   - Stage (per `repo-commit`'s staging rules — never `git add -A`), generate a conventional-commit message, commit.
   - **If there are no changes to commit**, note `nothing to commit — deploying current state` and continue to Phase 2 (do not stop — the user asked to deploy).
   - Pull/rebase. **On conflict → stop.** Do not proceed to Phase 2.
   - Run repo-commit's **Context consistency check** step. **On mismatch → ask; do not push or deploy until resolved.**
   - Push **without the routine gate** (chain is user-authorised). On push failure → report and **stop**; do not deploy.
3. Report the commit + push result before moving on.

### Phase 2 — Trigger deploy workflow(s)

4. Run the **repo-git-trigger-workflow** process (**Parse arguments** through **Verify and report**) with the remaining `$ARGUMENTS`, applying the gate policy above:
   - Resolve the target repo, discover and resolve workflow tokens, discover and resolve inputs — exactly as that skill specifies.
   - Default the trigger to the repo's default branch (the branch just pushed in Phase 1) unless the arguments named one.
   - At the **Confirmation gate** step: **skip the routine confirmation gate** if scope and all required inputs (incl. `environment`) were fully specified in the arguments; otherwise gate. Always honour the plan/apply review split.
   - Fire, verify, and report the queued run URLs.

## Output

```
Committed: <commit-message>
Pushed to: <branch>

Triggered <N> workflow(s) on <TARGET_REPO>:
  • <file>  → <status>  <url>
  ...

Watch them with:
  gh run watch --repo <TARGET_REPO>
```

If the chain stopped at a safety gate (tests failed, rebase conflict, remote mismatch, push failure), report exactly where it stopped and that **no deploy was triggered**.
