---
name: repo-quick-commit
description: "Commit all changes with a conventional-commit message and no tests, then push once the user confirms. Runs inline, so it can flag changed files unrelated to the session. Use for a quick save of work in a project repo; use repo-commit when the tests must run first, and plugin-commit for the plugin repo itself."
---

## Arguments

- `$ARGUMENTS` is **optional**. Scope the commit to a subdirectory path.
- If empty, commit **all changes** across the whole repo.

**Examples:**

- `/repo-quick-commit` → commit everything
- `/repo-quick-commit api` → commit only changes under `api/`

## Runs inline

This skill sees the conversation, so it can tell which changed files belong to the session. It never
reads the full diff and makes at most two Bash calls before the push (ADR-0026). The push, its question
and any rebase retry sit outside that cap. No tests, no `contexts.json` remote-owner check, no rebase
up front.

## Process

### 1. Survey (call 1)

One Bash call: `git status --porcelain` and `git diff --stat`, plus `git diff --stat --cached` when
something is already staged. Append `-- <scope>/` when scoped.

Paths come from the porcelain output: for a rename (`R  old -> new`) use the new path; quote paths with
spaces.

Nothing changed → report it and **stop**.

### 2. Relevance check (no Bash call)

Compare the changed files with what the conversation shows was done. If the conversation is unclear,
judge from the stat.

- Files unrelated to the session, or risky (`.env`, secrets or keys, build output, large binaries) →
  ask **one** `AskUserQuestion` listing them, with options `Include them` / `Leave them out`.
- Otherwise ask nothing.

Every changed file left out → report nothing to commit and **stop**.

### 3. Stage and commit (call 2)

One Bash call: `git add -- <file>...` with explicit paths (never `-A` or `.`), then
`git commit -m ... -- <file>...` with the same paths, so other staged files stay staged and are not
committed.

- Format: `type(scope): description`, under 72 chars, lowercase, no period.
- Body bullets only for several distinct changes.
- End with the session's `Co-Authored-By` attribution line, taken from the system reminder; do not
  hard-code a model.

### 4. Push

Ask via `AskUserQuestion` first, naming the branch: `Push now (Recommended)` /
`Leave the commit local` (ADR-0008, ADR-0022). Then `git push`.

- Rejected as non-fast-forward → `git pull --rebase`, then push again. Only then.
- Conflict → `git rebase --abort`, **stop**, and say the commit is saved locally.
- Never force-push. Any other failure is reported, then **stop**.

## Output

```
Committed: <commit message, first line>
Pushed to: <branch>
```

or `Left local on: <branch>` in place of the second line.
