# 0021. Return the investigation report to the conversation, move the digest to the end

**Status**: Accepted
**Date**: 2026-09-18
**Supersedes**: [ADR-0020](0020-move-the-investigation-report-into-a-file.md)
**Scopes**: [ADR-0019](0019-give-the-human-reader-a-proactive-door.md)

## Context

ADR-0020 gave Debug Mode and Investigate Mode a file channel — `.claude/reports/debug-<timestamp>.md`
and `.claude/reports/investigation-<timestamp>.md` — with `/project-decide` Phase 0 reading the path a
printed digest named. Two problems with that channel have since surfaced, neither visible from a
single-session vantage point.

**Parallel-session race.** The user runs on the order of ten concurrent `/project-investigate` sessions
against the same repository. Any file path shared across those sessions — timestamped or fixed — is
cross-session shared state: one session's `/project-decide` can read a *different* session's report if
their timestamps land close enough to resolve to "most recent", and a second investigation started
before the first's report has been consumed can overwrite it out from under the first session's pending
handoff. ADR-0020's `<YYYY-MM-DD-HHMMSS>` suffix was chosen explicitly to stop two runs *on the same
day* from colliding (`0020-move-the-investigation-report-into-a-file.md`, Decision (a)) — it says
nothing about, and does not stop, two runs *at the same time* in different sessions from colliding. The
conversation is the only store in this plugin's design that is naturally scoped to one session; a file
under a project-relative path is not, no matter how it is named.

**Transient-artefact clutter.** An investigation or a debug session is transient by definition — it
exists to answer one question, then hands off to `/project-decide` or is abandoned. Timestamped files
accumulate in `.claude/reports/` without bound in every consumer repository this plugin runs against,
with no expiry or cleanup mechanism, for output that was never meant to persist past the session that
produced it.

## Decision

(a) Debug Mode and Investigate Mode write no file, at any phase. Phase 3 of both modes prints the full
report and the executive digest, both to the conversation, exactly as before ADR-0020.

(b) The executive digest moves to the **end** of the printed report, after the full body and its
read-only note — not, as ADR-0019 placed it, in a header above the report. End-placement means the
digest is what is on screen when the run finishes; the full body is a scroll away rather than out of
view above a header a user has already read past. This inverts ADR-0019's `## At a glance` placement
for these two templates only; the no-argument archaeology path's `## At a glance` header is untouched
and keeps its top placement (see the Relates-to ADR-0019 for that rationale).

(c) The digest drops its `**Full report**: .claude/reports/...` pointer line — there is no file to
point at — and its next-step line becomes "`/project-decide` reads the report above — no need to
re-run the investigation."

(d) `skills/project-decide/SKILL.md` Phase 0 reverts to scanning the conversation directly for an
`## Debug Report —` or `## Investigation Report —` heading, most-recent-wins when both are present. Its
description, Constraints, and Input sections revert to their pre-ADR-0020 "no file I/O" wording.
`skills/shared/_ux-rules.md`'s "never re-validate suite-produced input" rule reverts to covering only
content printed directly to the conversation.

(e) The archaeology-path corrections made in commit `3d5f1bf` — the no-argument path's spawned
`repo-archaeologist` agent writing its own report as part of its own Phase 4, the `**Report**: <path
returned by the agent>` line, and the At-a-glance block scoped to that one path — are kept, not
reverted. Full repository archaeology is a rare, deliberately invoked scan producing a keeper document
meant to outlive the session, unlike a Debug Report or Investigation Report; nothing in the two Context
reasons above applies to it, since it is not run ten times in parallel per repository and its output is
meant to persist.

This restores ADR-0019 fact 4 — "the report text printed in the terminal *is* the machine handoff" —
for Debug Mode and Investigate Mode. The digest concept ADR-0019 introduced and ADR-0020 relocated is
not abandoned; it survives, printed alongside the full report rather than in place of it, at the end
rather than the top. ADR-0019 itself is not edited by this decision.

## Consequences

- The full report prints in the terminal again for every Debug Mode and Investigate Mode run — the
  dense-print problem ADR-0020 set out to fix returns as an accepted trade-off, weighed against the
  session-isolation and clutter problems it caused.
- The conversation-held handoff is subject to context compaction in a very long session. This is a risk
  ADR-0019 fact 4 always carried and never solved; ADR-0020 did not solve it either, since even its
  file-held report needed a digest naming the file to survive in-conversation for `/project-decide` to
  find it. Nothing about this decision makes that risk worse than it already was before ADR-0020.
- `.claude/reports/` keeps only the `archaeology-` prefix; the `debug-` and `investigation-` prefixes
  ADR-0020 introduced are retired.
- `skills/project-decide/SKILL.md`'s "no file I/O" and "no agents" claims are true again, not
  true-with-one-exception.

## Alternatives considered

1. **A fixed, overwritten filename** (e.g. `.claude/reports/latest-investigation.md`) instead of a
   timestamp. Rejected: this does not fix the parallel-session race, it sharpens it — every concurrent
   session now clobbers the same single path instead of merely landing close in time.
2. **A session-scoped temp directory** (e.g. under the OS temp root, keyed by session ID) instead of a
   project-relative path. Rejected by the user: paths outside the project are ugly to reference back to
   and die with routine OS temp-directory cleanup, taking an unconsumed report with them.
3. **Keep ADR-0020 as written.** Rejected for the two reasons in Context: the parallel-session race is a
   correctness problem, not a style preference, and the unbounded file accumulation is a real operational
   cost in every consumer repository — neither is addressed by any refinement of the file-channel design
   that keeps the channel a file.

## Relates to

[ADR-0010](0010-keep-skills-deterministic-state-machines.md),
[ADR-0011](0011-author-reports-in-markdown.md),
[ADR-0019](0019-give-the-human-reader-a-proactive-door.md),
[ADR-0020](0020-move-the-investigation-report-into-a-file.md)
