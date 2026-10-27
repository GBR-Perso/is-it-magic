# 0023. Run project-locator and scanner-devbox on Haiku

**Status**: Accepted
**Date**: 2026-10-27
**Amends**: [ADR-0015](0015-repin-the-reasoning-agents-to-sonnet.md)

## Context

ADR-0015 pinned all fourteen agents to Sonnet. The usage dashboard of 26–27 October 2026 recommended a
cheaper model for subagents. Its recommendation pointed at `developer`, whose cost is its turn count,
already bounded by ADR-0016, and whose code a weaker model would likely loop on longer.

Two agents do mechanical work with a fixed output format and little judgement: `project-locator` scores
folder names against a project name, and `scanner-devbox` matches credential-file patterns on the dev
box.

## Decision

Set `model: haiku` on `project-locator` and `scanner-devbox`. The other twelve agents stay on Sonnet.

## Consequences

- Both agents cost about a third of their Sonnet price per token. Neither shows in the dashboard's
  subagent list, so the saving is small. The decision is about matching each agent's model to its job.
- `scanner-secrets`, `scanner-injection` and `scanner-exposure` stay on Sonnet: a missed secret or
  injection costs more than the tokens saved, and the injection scan follows data flow.
- Reversal is one word per agent.

## Relates to

[ADR-0013](0013-scan-for-security-on-cadence-not-per-change.md),
[ADR-0016](0016-bound-the-developer-per-gate-run-and-per-review-round.md)
