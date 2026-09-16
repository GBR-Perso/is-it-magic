# Architecture Decision Records

Standing decisions behind the `is-it-magic` operating model: the plugin's tooling, the doctrine it
encodes, and the way of working it transmits.

Most of these records were written on 2026-08-07, when the operating model was confronted against
*"How building software is changing at Anthropic"* (The Pragmatic Engineer, 28 Jul 2026). The
decisions themselves are older: the record date is when each was written down, not when it was taken.
Where a decision post-dates the review, its own date says so.

## Index

| # | Decision | Status | Date |
|---|---|---|---|
| [0001](0001-manufacture-judgment-through-codified-doctrine.md) | Manufacture judgment through codified doctrine | Accepted | 2026-08-07 |
| [0002](0002-weight-the-pipeline-toward-verification.md) | Weight the pipeline toward verification | Accepted | 2026-08-07 |
| [0003](0003-enforce-red-green-on-governed-layers.md) | Enforce RED to GREEN test-first on governed layers | Accepted | 2026-08-07 |
| [0004](0004-scale-planning-rigour-to-complexity.md) | Scale planning rigour to change complexity | Accepted | 2026-08-07 |
| [0005](0005-inject-an-explicit-failure-modes-list.md) | Inject an explicit failure-modes list into the AI's context | Accepted | 2026-08-07 |
| [0006](0006-compound-solved-problems-into-skills.md) | Compound solved problems into skills | Accepted | 2026-08-07 |
| [0007](0007-line-level-defensibility-as-the-default.md) | Require line-level defensibility as the default | Accepted | 2026-08-07 |
| [0008](0008-gate-every-mutating-phase-on-a-human.md) | Gate every mutating phase on a human | Accepted | 2026-08-07 |
| [0009](0009-commit-direct-to-main.md) | Commit direct to main, no PR machinery | Accepted | 2026-08-07 |
| [0010](0010-keep-skills-deterministic-state-machines.md) | Keep skills deterministic state machines | Accepted (conditional) | 2026-08-07 |
| [0011](0011-author-reports-in-markdown.md) | Author reports in Markdown, not HTML | Accepted | 2026-08-07 |
| [0012](0012-inherit-the-session-model-on-reasoning-agents.md) | Inherit the session model on the reasoning agents | Superseded by ADR-0015 | 2026-08-07 |
| [0013](0013-scan-for-security-on-cadence-not-per-change.md) | Scan for security on cadence, not per change | Accepted | 2026-08-07 |
| [0014](0014-raise-correction-loop-budgets-to-three-passes.md) | Raise correction-loop budgets to three passes | Accepted | 2026-08-26 |
| [0015](0015-repin-the-reasoning-agents-to-sonnet.md) | Repin the reasoning agents to Sonnet | Accepted | 2026-08-28 |
| [0016](0016-bound-the-developer-per-gate-run-and-per-review-round.md) | Bound the developer per gate run and per review round | Accepted | 2026-08-28 |
| [0017](0017-loop-only-on-violations.md) | Loop only on violations | Accepted | 2026-08-28 |
| [0018](0018-re-verify-proportionally.md) | Re-verify proportionally on the design-error path | Accepted | 2026-08-31 |
| [0019](0019-give-the-human-reader-a-proactive-door.md) | Give the human-reader path its own proactive door | Accepted | 2026-09-03 |
| [0020](0020-move-the-investigation-report-into-a-file.md) | Move the investigation report into a file, print an executive digest | Accepted | 2026-09-16 |

## What is not here

Open questions with no decision yet taken remain a backlog in
[`../anthropic-practices-gap-open-items.md`](../anthropic-practices-gap-open-items.md): items A3, A4,
A5 (tooling), B1 to B5 (doctrine, which live in the `it--claude-rise-plugin` repo) and C1 (ritual).
They are deliberately not written as `Proposed` ADRs, because nothing has been decided about them.

Team-shape findings from the source article (two-pizza teams, a cap of two engineers per project) map
onto nothing here: there is no team to reshape. They are out of scope rather than rejected.

## Conventions

- One decision per file, named `NNNN-kebab-case-title.md`.
- Status is `Accepted`, `Proposed`, `Deprecated` or `Superseded by ADR-NNNN`.
- Rejected alternatives live inside the record they were weighed against, not as separate ADRs.
- Numbers are never reused. A reversal supersedes rather than edits.
