# 0020. Move the investigation report into a file, print an executive digest

**Status**: Accepted
**Date**: 2026-09-16
**Scopes**: [ADR-0019](0019-give-the-human-reader-a-proactive-door.md)

## Context

ADR-0019 fact 4 recorded a premise load-bearing enough to state explicitly: "the report text printed
in the terminal *is* the machine handoff." `skills/project-decide/SKILL.md` Phase 0 step 1 locates its
input by scanning conversation text for an Investigation Report or Debug Report heading — there is no
separate machine channel — and `skills/shared/_ux-rules.md`'s "never re-validate suite-produced input"
rule depends on that same printed body being the thing the user already approved. ADR-0019 built its
`## At a glance` digest as a strictly additive header on top of that body, keeping everything below it
byte-identical, precisely so as not to disturb this premise.

A full `/project-investigate` run has since accumulated into a dense mandated print: a Phase 0 brief, a
Phase 0.5 Quick Summary, the Phase 3 `## At a glance` digest, then an unabridged eight-section report —
Issue/Question, Suspected Root Cause or Summary, Evidence or Relevant Code Areas, Data/Call Flow,
Related Tests or Patterns, Browser Findings, Azure Findings, Open Uncertainties — printing "Not
investigated" placeholders for sections that never ran, followed by a four-mode `/project-implement`
footer. None of that can be thinned without breaking the premise ADR-0019 recorded, because the printed
body is the only copy `/project-decide` can read.

A file-held precedent for exactly this shape already exists in the same skill family:
`agents/repo-archaeologist.md` Phase 4 writes its full report to
`.claude/reports/archaeology-<YYYY-MM-DD>.md`, and Phase 5 returns only a structured summary to the
orchestrating skill — the terminal never carries that path's full body at all.

## Decision

Split the printed output for Debug Mode and Investigate Mode into two channels: a file holding the
full report, and a bounded digest printed in its place.

(a) **Filenames**: `.claude/reports/debug-<YYYY-MM-DD-HHMMSS>.md` and
`.claude/reports/investigation-<YYYY-MM-DD-HHMMSS>.md`. Time-of-day is added to the timestamp because
`repo-archaeologist`'s `archaeology-<YYYY-MM-DD>.md` scheme assumes at most one run per day, which does
not hold for debug or investigation sessions — a second run against the same repository on the same
day must not silently overwrite the first.

(b) **Digest composition and bound**: Phase 3 prints an executive digest instead of the full report —
at most 8 bullets, each roughly 20 words, each grounded in a `file:line` pointer where the finding has
one. Row order: root cause/summary, up to 3 key-evidence bullets, one call/data-flow bullet (prose, hop
arrows permitted, no diagram), a Browser verdict bullet, an Azure verdict bullet, a top
open-uncertainty bullet — the last three included only when that source actually ran; a source that did
not run is omitted entirely, never printed as "Not investigated". The digest closes with the full
report's path and one next-step line, replacing the four-mode `/project-implement` footer.

(c) **Who writes the file**: the orchestrating skill (`project-investigate`), at Phase 3, not a spawned
agent. Only the orchestrating skill holds the merged code, browser, and Azure findings once Phase 2's
confirmation gates have run; agents spawned in Phase 1 keep their existing "do not write any report
file" spawn instructions, unchanged.

(d) **`/project-decide` Phase 0**: the primary path reads the file named on the digest's
`**Full report**` line; the fallback path scans the conversation for a legacy `## Debug Report —` /
`## Investigation Report —` heading, for transcripts predating this decision or for findings a user
pastes directly.

This scopes ADR-0019 rather than amending it. ADR-0019 fact 4's premise — that the printed body is
itself the machine handoff, with no separate channel — is dissolved by creating that separate channel:
the file is now the channel, and the digest is a pointer to it, not the handoff. The byte-identical-body
requirement ADR-0019 imposed on the Debug Report and Investigation Report bodies (so an additive header
could not be read as a change to the machine handoff) is retired for those two reports: their bodies now
live only in the file, printed nowhere, so there is no printed body left for that requirement to
protect.

The no-argument archaeology path's two-field `## At a glance` digest is untouched by this decision. It
never asserted the `/project-decide` handoff fact 4 protected — ADR-0019 gave that path's closing clause
no handoff clause at all, because that path ends the skill without producing a report for
`/project-decide` to read. There is, however, an incidental correction to make while editing this path:
its spawn instruction currently tells `repo-archaeologist` "not write any report file", while the
agent's own Phase 4 always writes one regardless of caller — the two have been contradicting each other
since ADR-0019 landed. This decision corrects the instruction to let the agent's default write stand,
and the printed summary now surfaces the returned path.

## Consequences

- `.claude/reports/` gains two new filename prefixes, `debug-` and `investigation-`, alongside the
  existing `archaeology-` prefix.
- Debug Report and Investigation Report files gain a metadata header (`**Date**`, `**Mode**`) and an
  `# ` H1 title, mirroring the archaeology file's shape.
- `/project-decide` gains its first file read — a single, read-only file located by Phase 0. Its
  description and constraints are updated to say so.
- `skills/shared/_ux-rules.md`'s "never re-validate suite-produced input" wording widens to cover
  content read from a file a digest names, not only content printed directly.
- Skill and agent counts are unaffected — `README.md` and `.claude-plugin/plugin.json` are not touched
  by this decision.
- The 8-bullet, ~20-word digest bound is a new convention, not inherited from any existing file, and is
  therefore in scope for the prompt-debt ritual proposed in the open backlog
  (`docs/anthropic-practices-gap-open-items.md`, "Prompt-debt ritual per model generation") the next
  time it runs — the same treatment ADR-0019 gave its own bounds.

## Alternatives considered

1. **Keep printing the full report with the digest above it.** Rejected: that is exactly the dense
   shape this decision fixes — the digest would become one more thing printed, not a replacement for
   anything.
2. **Have the spawned agents write the file directly.** Rejected: only the orchestrating skill holds
   the merged code, browser, and Azure findings after Phase 2's confirmation gates; no single agent has
   the full picture to write.
3. **A collapsible or fenced "details" block in the terminal.** Rejected: this surface has no such
   affordance — a fenced block still prints its full contents.
4. **Date-only filenames, mirroring `repo-archaeologist`.** Rejected: a debug or investigation session
   can plausibly run more than once in a day against the same repository; a date-only name would let a
   second run overwrite the first.

## Relates to

[ADR-0010](0010-keep-skills-deterministic-state-machines.md),
[ADR-0011](0011-author-reports-in-markdown.md),
[ADR-0019](0019-give-the-human-reader-a-proactive-door.md)
