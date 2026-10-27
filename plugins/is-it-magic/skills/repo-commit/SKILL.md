---
name: repo-commit
description: "Run the test suite, then stage and commit the changes on the current branch with a conventional-commit message, and push once the user confirms. Runs in a forked context on Sonnet, so its cost does not grow with the length of the session. Use when the user wants to commit, save, or push their work in a project repo — runs tests first. For committing the plugin repo itself, use plugin-commit instead."
context: fork
model: sonnet
background: false
---

## Arguments

- `$ARGUMENTS` is **optional**. Scope the commit to a subdirectory path.
- If empty, commit **all changes** across the whole repo.

**Examples:**

- `/repo-commit` → commit everything
- `/repo-commit api` → commit only changes under `api/`
- `/repo-commit packages/web` → commit only changes under `packages/web/`

## Runs as a fork

This skill runs as a forked subagent: it sees `$ARGUMENTS` and the repository, not the conversation, and
it cannot ask the user anything. It runs steps 1 to 5 and never pushes; the session that invoked it asks
and pushes (step 6). See ADR-0022.

## Important rules

Read and follow the context resolution contract in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_context-resolution.md`.

Keep tool output small and calls few: every call is billed again for everything already in context.

## Process

### 1. Run tests

Determine and run the test command(s) for the scope by detecting the toolchain(s) present in it:

- **.NET** — a `*.sln` or `*.csproj` in scope → `dotnet test <solution-or-project> --verbosity quiet --nologo`
- **Node** — a `package.json` with a `test` script in scope → run it with the repo's package manager, silenced (detect from the lockfile: `package-lock.json` → `npm test --silent`, `pnpm-lock.yaml` → `pnpm test --silent`, `yarn.lock` → `yarn test --silent`)
- **Python** — `pyproject.toml`, `pytest.ini`, or a `tests/` directory in scope → `pytest -q`
- Other toolchains: detect analogously from their manifest/runner, in their quiet mode.

Keep only the summary and the failures: pipe each run through `tail -n 40` under `set -o pipefail`, so the
test runner's exit status survives the pipe.

If a scope has no detectable test setup, note `no tests detected for <scope>` and continue. If any test
fails, report the failures and **stop** — do not proceed.

### 2. Stage and generate commit message

Stage changes and read the summary in the same call:

- If scoped: `git add <scope-path>/`
- If unscoped: `git add` only the changed files `git status --porcelain` lists. Never use `git add -A`.
- Then `git diff --cached --stat`.

Read the full `git diff --cached` only when the stat shows fewer than about 400 changed lines; otherwise
read the diff of the few files that carry the change, enough to name it. Generate a conventional commit
message:

- Format: `type(scope): description` (e.g. `feat(auth): add token refresh`, `fix(api): handle null value`)
- Short description (under 72 chars), lowercase, no period
- Multi-line body with bullet points if multiple distinct changes
- Always append `Co-Authored-By: Claude <noreply@anthropic.com>`

### 3. Commit

Create the commit with the message, and run step 4 in the same call.

### 4. Pull and rebase

```bash
git fetch origin
git pull --rebase
```

If conflicts occur, abort the rebase (`git rebase --abort`) and **stop**. Tell the user their commit is saved locally but conflicts need manual resolution.

### 4a. Context consistency check

Apply R.2–R.3 from the context resolution contract against the current working directory, reading the
manifest and the remote in one call:

1. Read `%USERPROFILE%\.claude\contexts.json` (Windows) / `$HOME/.claude/contexts.json` (Unix). If absent, record `no context` and go on.
2. Match cwd against `path_globs` in manifest order (first match wins).
3. If a context matches, extract the owner from `git remote get-url origin` and compare it to the context's `github_org` or `github_user`.
   - **Match**: record `owner matches <context>`.
   - **Mismatch**: record it. Never push on a mismatch without the user's confirmation. Forked, the hand-back carries it to the user; run inline by `repo-commit-and-deploy`, ask per R.3 with options `Push anyway — I've verified this is correct` / `Cancel push — I'll fix the remote first`.
4. If no context matches: record `no context`.

### 5. Hand back

The fork's last message, and the only output of a forked run:

```
Committed: <commit-message, first line>
Branch:    <branch>
Rebased:   <yes — N remote commits | no>
Remote:    <owner matches <context> | MISMATCH — remote owner <x>, context expects <y> | no context>
Next:      ask the user via AskUserQuestion before pushing — `Push now (Recommended)` / `Don't push — leave the commit local`; on yes run `git -C <repo root> push`. Never force-push.
```

On a mismatch the `Next` options are `Push anyway — I've verified this is correct` / `Cancel push — I'll
fix the remote first`. If the run stopped at step 1 or 4, report where and why instead, with no `Next`
line.

### 6. Push

Run by whoever holds the conversation, never by the fork: the invoking session for `/repo-commit`, the
chain itself inside `repo-commit-and-deploy`. The push is always confirmed first, as the hand-back's
`Next` line says (ADR-0008).

```bash
git push
```

Never force-push. If push fails, report the error and stop.

## Output

After the push:

```
Committed: <commit-message>
Pushed to: <branch-name>
```
