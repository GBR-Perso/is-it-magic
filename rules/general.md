# General Engineering Standards

- Windows environment — use PowerShell for scripts
- British English in all comments and documentation

## Git

- Prefer `/repo-commit` for commits — it runs tests, applies the conventional format, and gates the push
- Conventional commits: `type(scope): description` (feat / fix / chore / refactor) — applies to direct commits too
- Commit directly on `main` — commits may span multiple concerns — **unless a project rule requires otherwise, in which case the project rule takes precedence**
- Never push to remote without user confirmation
- **Never use destructive local git commands** — `git checkout -- <path>`, `git restore`, `git reset --hard`, `git clean` are forbidden for any agent, at any time. Handle unwanted or out-of-scope edits non-destructively: report them, or undo only the agent's own edits by re-editing the specific lines back — never by reverting the working tree. The prohibition is on discarding uncommitted work or reverting the tree to a prior state; restoring lost work from an internal recovery checkpoint is not covered.

## Dependencies — No Global Installs

The repo must be self-contained after cloning, given only the platform prerequisites (language runtimes and any required services). All other tools must be declared inside the repo, in the appropriate per-language or per-tool manifest, so they are restored as part of normal setup.

Never work around a missing tool with a global install or an ad-hoc fetch — add it to the appropriate manifest instead.

## Code Quality

- No magic strings/numbers — use constants/enums
- Prefer explicit over implicit
- Single responsibility per class/component

## Simplicity First

- Minimum code that solves the problem — nothing speculative
- No abstractions for single-use code; no "flexibility" or configurability that wasn't requested
- No error handling for impossible scenarios
- If it could be half the size, rewrite it — would a senior engineer call this overcomplicated?

## Surgical Changes

- Touch only what the task requires — don't "improve" adjacent code, comments, or formatting
- Don't refactor what isn't broken; match existing style even if you'd do it differently
- Remove only the orphans your own change created — never delete pre-existing dead code, mention it instead

## Comments

A comment describes the member it sits on, as it is.

- **Never point outward in space** — no claim about how another file behaves, who consumes this member, or what a caller guarantees. Such a claim rots the moment that other code moves, and then it misleads. State the constraint this member itself enforces instead.
- **Never point outward in time** — no "added for", "was previously", "is unchanged", and no reference to a transient document (`REQ-1.3`, ticket ids). Permanent, globally-unique, never-renumbered records (`ADR-0029`) are fine. Once shipped, the code is the specification.
- **Write one only for what the code cannot say** — an invariant the type does not express, a documented absence, the meaning of a sentinel, or why this construct rather than the obvious one.
- **Delete any comment that restates its declaration.** No section labels.
- This **overrides** matching the surrounding comment density: a codebase full of outward-pointing comments is not a pattern to match. Binds the comments you write or touch — pre-existing ones are reported, never swept (see *Surgical Changes*).

## Reason Before You Act

- Re-read what was actually asked before committing to an approach — don't lock onto the first idea.
- The codebase is the source of truth, not memory — verify before asserting; never invent APIs, flags, or behaviour.
- If a fix fails twice, stop and re-frame the problem instead of retrying variations.
- When patching a structure that's already wrong, say it needs restructuring rather than adding the Nth patch.
- Push back on a wrong assumption rather than agreeing to be helpful.

## Understand & Verify

- Read the surrounding code and match its patterns before changing it; check whether something already exists before adding it.
- "It should work" is not done — build it, run it, and observe the behaviour you changed.
