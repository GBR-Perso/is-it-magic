# 0015. Repin the reasoning agents to Sonnet

**Status**: Accepted
**Date**: 2026-08-28
**Supersedes**: [ADR-0012](0012-inherit-the-session-model-on-reasoning-agents.md)
**Amended by**: [ADR-0023](0023-run-project-locator-and-scanner-devbox-on-haiku.md) (`project-locator` and `scanner-devbox` on Haiku)

## Context

[ADR-0012](0012-inherit-the-session-model-on-reasoning-agents.md) set `model: inherit` on `architect`,
`reviewer-design` and `reviewer-perf`, on the premise that the two reviewers were "the safe part":
diff-scoped, single-pass, capped at two runs by the review loop. `architect` was named the accepted
risk, run in draft mode and scaling with repository size rather than diff size. The record asked for a
trial ahead of adopting the posture by default, because five to ten parallel sessions multiply any
per-run delta.

Thirty days of transcripts on the main machine, de-duplicated by request and scanned on 28 August 2026
with `docs/investigations/token-usage-scan.py` (scan output not committed), give that trial a result.
`architect`, `reviewer-design` and `reviewer-perf` ran 79–89% of their turns on Opus, for 5.3% of the
suite's total tokens over the period. The spend is concentrated in the agents least suited to carry it:
a stronger model at the orchestrator now propagates below it disproportionately, into exactly the slots
ADR-0012 called safe.

The premise fails on inspection, not just on the numbers. "Diff-scoped" holds only loosely: both
reviewers scope from the git working tree — `git diff --name-only`, `git diff --cached --name-only`
and `git ls-files --others --exclude-standard` (`agents/reviewer-design.md:24`,
`agents/reviewer-perf.md:23`) — rather than from the plan's file list, which is finding S3 of
`docs/investigations/token-usage-brief.md`. Because the skill never commits, that scope is the
session's cumulative uncommitted work, so cost tracks how much the session has touched rather than the
change under review — not what "their cost tracks the size of the change" claimed. "Capped at two
runs" has also loosened: [ADR-0014](0014-raise-correction-loop-budgets-to-three-passes.md) raised the
review loop to three passes and, in its own consequences, named the worst case as three Opus-class
review rounds rather than two, with the re-spawn-only-flagged-reviewers rule as the sole mitigation.

A secondary-machine investigation (`docs/investigations/token-usage-brief.md`, line ~139) looked at
this same repin ahead of the main-machine measurement and filed it under "lost weight after
measurement" as negligible, because on that machine's data `architect` and `reviewer-design` had run
93% of turns on Sonnet anyway. Main-machine measurement overturns that call: the concentration runs the
other way here, and the repin is not negligible on the data this record is written against.

## Decision

Set `model: sonnet` on `architect`, `reviewer-design` and `reviewer-perf`, matching the other eleven
agents. All fourteen agents are now pinned.

## Consequences

- A stronger session model no longer propagates to any agent below the orchestrator. Choosing a
  stronger model for a session now buys nothing in the pipeline, full circle from ADR-0012's stated
  goal.
- The teaching argument for a stronger reviewer — that a junior promoting a draft run to full is shown
  what good review looks like, and weak reviewers teach weakly — is knowingly given up, until a
  plan-scoped reviewer exists to make the cost proportionate again.
- [ADR-0002](0002-weight-the-pipeline-toward-verification.md)'s description of `test-writer` as
  "pinned to a cheaper model" now reads as all agents pinned to that model, which was already the case
  for eleven of fourteen; no edit is needed there.
- The gap-items doc's item recording this repin as "closed (ADR-0012)" remains true in substance —
  the repin decision existed and was acted on — and is not edited by this record.
- Reversal is the same one word it was before: set the three agents back to `inherit`, once a
  plan-scoped reviewer exists to make that cheap again.

## Alternatives considered

**Full-mode-only model override at the spawn site.** Keep the frontmatter pinned and override the model
only where `project-implement` spawns these agents in full mode, leaving draft mode untouched. Rejected:
the measured spend is not draft-specific — the reviewers only ever run in full mode or on promotion to
it, so a full-mode-only override is the whole surface, not a subset of it — and it adds spawn-site state
to a skill [ADR-0010](0010-keep-skills-deterministic-state-machines.md) wants to keep a deterministic
state machine. ADR-0010 says nothing about model choice; this record's inference from it is that model
choice belongs in agent frontmatter rather than scattered across call sites.

**Scope the reviewers to the plan's file list first, then re-trial `inherit`.** Fix the scoping gap this
record identifies — read only the files the architect's plan names, rather than everything uncommitted
in the working tree — and re-open the model question once cost genuinely tracks the diff. This is the
right order if `inherit` is ever wanted again; it is left open rather than actioned here, since it is a
reviewer-scoping change, not a model-pin change, and this record does not touch reviewer internals.

## Relates to

[ADR-0002](0002-weight-the-pipeline-toward-verification.md),
[ADR-0004](0004-scale-planning-rigour-to-complexity.md),
[ADR-0012](0012-inherit-the-session-model-on-reasoning-agents.md),
[ADR-0014](0014-raise-correction-loop-budgets-to-three-passes.md)
