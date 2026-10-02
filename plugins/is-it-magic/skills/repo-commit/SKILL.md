---
name: repo-commit
description: "Run the test suite, then stage, commit, and push changes to the current branch with a conventional-commit message. Use when the user wants to commit, save, or push their work in a project repo — runs tests first. Pushes automatically when the user invokes it directly (/repo-commit); gates the push behind confirmation when invoked programmatically by Claude, another skill, or an agent. For committing the plugin repo itself, use plugin-commit instead."
---

## Arguments

- `$ARGUMENTS` is **optional**. Scope the commit to a subdirectory path.
- If empty, commit **all changes** across the whole repo.

**Examples:**

- `/repo-commit` → commit everything
- `/repo-commit api` → commit only changes under `api/`
- `/repo-commit packages/web` → commit only changes under `packages/web/`

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

Read and follow the context resolution contract in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_context-resolution.md`.

## Process

### 1. Run tests

Determine and run the test command(s) for the scope by detecting the toolchain(s) present in it:

- **.NET** — a `*.sln` or `*.csproj` in scope → `dotnet test <solution-or-project>`
- **Node** — a `package.json` with a `test` script in scope → run it with the repo's package manager (detect from the lockfile: `package-lock.json` → `npm test`, `pnpm-lock.yaml` → `pnpm test`, `yarn.lock` → `yarn test`)
- **Python** — `pyproject.toml`, `pytest.ini`, or a `tests/` directory in scope → `pytest`
- Other toolchains: detect analogously from their manifest/runner.

Run the detected tests for the scope. If a scope has no detectable test setup, note `no tests detected for <scope>` and continue. If any test fails, report the failures and **stop** — do not proceed.

### 2. Stage and generate commit message

Stage changes:

- If scoped: `git add <scope-path>/`
- If unscoped: `git add` only the changed files shown in step 1. Never use `git add -A`.

Run `git diff --cached` to review the staged diff. Generate a conventional commit message:

- Format: `type(scope): description` (e.g. `feat(auth): add token refresh`, `fix(api): handle null value`)
- Short description (under 72 chars), lowercase, no period
- Multi-line body with bullet points if multiple distinct changes
- Always append `Co-Authored-By: Claude <noreply@anthropic.com>`

### 3. Commit

Create the commit with the message.

### 4. Pull and rebase

```bash
git fetch origin
git pull --rebase
```

If conflicts occur, abort the rebase (`git rebase --abort`) and **stop**. Tell the user their commit is saved locally but conflicts need manual resolution.

### 4a. Context consistency check (before push)

Apply R.2–R.3 from the context resolution contract against the current working directory:

1. Read `%USERPROFILE%\.claude\contexts.json` (Windows) / `$HOME/.claude/contexts.json` (Unix). If absent, skip this step and proceed to Step 5 with existing behaviour.
2. Match cwd against `path_globs` in manifest order (first match wins).
3. If a context matches, extract the owner from `git remote get-url origin` and compare it to the context's `github_org` or `github_user`.
   - **Match**: proceed silently to Step 5.
   - **Mismatch**: invoke the R.3 signal-mismatch path — report and ask via `AskUserQuestion`. Do **not** push automatically. Options:
     1. Push anyway — I've verified this is correct
     2. Cancel push — I'll fix the remote first
   - The "save to manifest" opt-in is offered **at most once per push** if the user had to answer inline.
4. If no context matches: proceed to Step 5 with existing behaviour (no context check).

### 5. Push

Always show the user:

- The commit message
- The target branch
- Whether any remote changes were rebased in

**Push gate — conditional on how this skill was invoked:**

- **Direct user invocation** — the user personally typed `/repo-commit` (a user-issued slash command) this turn. The invocation *is* the authorisation: **push immediately, without asking.**
- **Programmatic invocation** — this skill was triggered any other way: Claude calling it via the Skill tool, a step inside another skill or workflow, or any agent/subagent. **Keep the gate** — ask via `AskUserQuestion` before pushing:
  1. `Push now (Recommended)`
  2. `Don't push — leave the commit local`
- **When the invocation source is unclear, treat it as programmatic and ask.** Only a direct, user-typed `/repo-commit` skips the gate.

This conditional governs only the routine push confirmation. The Step 4a context-mismatch check is a safety gate and still applies in **both** cases — never push on a remote-owner mismatch without confirmation.

On push:

```bash
git push
```

Never force-push. If push fails, report the error and stop.

## Output

```
Committed: <commit-message>
Pushed to: <branch-name>
```
