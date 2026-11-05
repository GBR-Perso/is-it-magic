# 0025. Explain on a throwaway scratchpad page

**Status**: Accepted
**Date**: 2026-11-05
**Scopes**: [ADR-0011](0011-author-reports-in-markdown.md)
**Supersedes the `dumb-down` part of**: [ADR-0019](0019-give-the-human-reader-a-proactive-door.md)

## Context

Explanations printed in the terminal scroll away and cannot carry a rendered diagram. The user wants
each explanation on one short page beside the work, and wants the number of pages kept down.

## Decision

A new skill, `explain`, publishes each explanation (What, Why, How, one worked example) to a single
Artifact per project, titled `scratchpad-<project folder>`. Same subject → the page is updated; new
subject → it is wiped and rewritten. It absorbs `dumb-down`'s rules (re-derive from the source, answer
first, one traced case, plain words) and `dumb-down` is removed.

The page is authored in HTML with no Markdown source. ADR-0011 covers reports and working documents
written into the repository; this page is neither — it is thrown away on the next subject.

## Consequences

- `/dumb-down` no longer resolves; `/explain` replaces it. Breaking change to the slash-command surface.
- A re-explanation now always lands on the page, not in the chat.
- One artifact per project, however many explanations are asked for.

## Relates to

[ADR-0011](0011-author-reports-in-markdown.md), [ADR-0019](0019-give-the-human-reader-a-proactive-door.md)
