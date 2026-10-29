# 0022. Fork repo-commit and confirm every push in the session

**Status**: Accepted
**Date**: 2026-10-27

## Context

The Claude Code usage dashboard for 26–27 October 2026 put `/repo-commit` at 11% and 5% of usage over
two 24-hour windows, ahead of `/project-implement`. The skill is about 5 KB. Its cost comes from where it
runs: last in long sessions, on the session model, over six or more tool calls that each reprocess the
whole conversation, with unfiltered test logs and the full staged diff added to it.

A skill can set `context: fork`, which runs it as a fresh subagent without the conversation's history,
and `model`, which sets that subagent's model. A forked subagent cannot call `AskUserQuestion`: the
sub-agents documentation removes it from every subagent's tools. Nor can it tell whether the user typed
`/repo-commit` or Claude invoked it, which was the condition for pushing without asking.

## Decision

- `repo-commit` runs forked (`context: fork`, `background: false`) on `model: sonnet`.
- The fork tests, stages, commits, rebases and checks the remote owner, then stops and hands back a
  fixed block. It never pushes.
- The invoking session asks before every push and runs it. The direct-invocation exemption is removed
  for `repo-commit`: every push is confirmed.
- Test output keeps only its summary and failures, and the full diff is read only for small changes.

## Consequences

- The skill's cost no longer grows with the length of the session that calls it. What stays in the main
  session is one question and one `git push`.
- Pushing takes one click where a typed `/repo-commit` used to take none.
- A remote-owner mismatch reaches the user through the hand-back instead of a question from the skill.
- `repo-commit-and-deploy` still runs `repo-commit`'s steps inline, skips the hand-back, and keeps its
  own gate policy.
- Untested in a plugin: the documentation describes these fields for skills without saying whether a
  plugin's skills honour them. The first run after release confirms it.
- First run (2026-10-28): on a typed `/repo-commit` the fork's hand-back is shown to the user directly
  and the session gets no turn, so it cannot ask. The hand-back now asks the user to reply `push`, and
  that reply is the confirmation. A model-invoked run still asks via `AskUserQuestion`.

## Alternatives considered

**Fork `repo-commit-and-deploy` and `repo-git-trigger-workflow` too.** Rejected: both ask the user
several times — workflow choice, inputs, confirmation, and the review between plan and apply — and a
fork cannot ask.

**Set `model` on those two without forking.** Rejected: the override switches the main session's model
for the turn, and prompt caches are per model, so a long session would be reprocessed uncached on the
cheaper model, which can cost more than reading the cache on the session model.

**Keep the push in the fork with `disable-model-invocation: true`.** Only the user could then invoke the
skill, so every run would be a direct invocation and could push without asking. Rejected for now: the
user chose to confirm every push.

## Relates to

[ADR-0008](0008-gate-every-mutating-phase-on-a-human.md),
[ADR-0015](0015-repin-the-reasoning-agents-to-sonnet.md)
