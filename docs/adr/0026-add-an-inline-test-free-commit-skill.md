# 0026. Add an inline, test-free commit skill

**Status**: Accepted
**Date**: 2026-11-09

## Context

`repo-commit` is forked and test-gated ([ADR-0022](0022-fork-repo-commit-and-confirm-every-push.md)).
A fork cannot see the conversation, so it cannot tell which changed files belong to the session, and the
test run is heavy for a quick save.

## Decision

- New skill `repo-quick-commit` commits all changes with a conventional-commit message and runs no tests.
- It runs inline, in two tool calls before the push: a survey (`git status --porcelain` and
  `git diff --stat`, never the full diff), then an explicit `git add` and commit.
- One `AskUserQuestion` at most, only when a file looks unrelated to the session or risky. Inline because
  that check needs the conversation, and a fork cannot call `AskUserQuestion`.
- Every push is confirmed ([ADR-0008](0008-gate-every-mutating-phase-on-a-human.md)). `git pull --rebase`
  and a retry happen only after a non-fast-forward rejection; a conflict aborts the rebase.

## Consequences

- The two calls re-send the session. Accepted; revisit if it shows on the usage dashboard, with a forked
  Haiku variant as the fallback, losing the relevance check.
- No remote-owner check against `contexts.json`.
- No tests, by the user's choice.

## Alternatives considered

**Forked Haiku variant.** Rejected: no conversation and no questions.

**A no-tests argument on `repo-commit`.** Rejected: still forked, so no relevance check, and it keeps the
rebase and owner-check weight.

## Relates to

[ADR-0008](0008-gate-every-mutating-phase-on-a-human.md),
[ADR-0022](0022-fork-repo-commit-and-confirm-every-push.md)
