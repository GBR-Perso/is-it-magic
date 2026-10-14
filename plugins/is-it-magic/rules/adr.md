---
paths:
  - "docs/adr/**"
---

# Architecture Decision Records — Conventions

> How a project records settled decisions so they are not re-litigated, and how a session loads them
> without paying for the whole history.

## Layout

```
docs/adr/
  DIGEST.md        the rules in force today — the only file loaded every session
  NNNN-kebab-case-title.md
```

- One decision per file, numbered in the order taken, zero-padded to four digits, never renumbered.
- The title states the decision, not the topic: `0042-an-spv-has-no-vendor-financing`, not `0042-spv`.

## When to write one

- Only once a trade-off is **settled**. Open questions and leanings stay in the conversation or the
  project's goal / open-decisions doc.
- One that a future session could plausibly reverse without knowing why it was chosen. A choice
  the code makes obvious needs no ADR.

## Writing an ADR

```
# ADR NNNN — <Title>

- **Date:** YYYY-MM-DD
- **Status:** Accepted
- **Supersedes:** [NNNN](NNNN-….md)        only when applicable
- **Related:** [NNNN](NNNN-….md)           ADRs it builds on without overturning

## Decision
## Why
## How to apply
```

- **Decision** — the commitment, stated as a rule. Name the concrete types, endpoints and fields.
- **Why** — the reasoning, and each rejected option with the reason it lost.
- **How to apply** — what a future change must do or must not do.
- **Budget: one page (~2 KB).** Evidence — execution plans, reconciliation figures, legacy traces,
  worked calculations — goes in a linked note under `docs/`, not the ADR. An ADR past ~4 KB is a
  design doc and should be split.
- No code, no restating other ADRs, no narrative of how the discussion went.

## Lifecycle

ADRs are append-only. A decision is never edited away or deleted — the trail is the point.

| Status | Meaning |
|---|---|
| `Accepted` | In force. |
| `Accepted — challenged` | In force, with a documented counter-example and no agreed replacement yet. Carries an `## Open challenge` section. |
| `Superseded by ADR NNNN` | Fully overturned. Kept for history; excluded from the digest. |

- **Reversing** a decision is a new ADR with `Supersedes:`; the old one's `Status` changes and
  nothing else in it does.
- **Partial supersession** (one clause overturned) leaves the old ADR `Accepted` with a one-line
  note naming the clause and the successor.
- A challenge that is resolved stays in the ADR as `## Challenge and resolution` — the reasoning that
  survived an attack is worth keeping.

## The digest

`DIGEST.md` is the current state of every decision in force: one bullet per ADR, grouped by topic,
each the binding rule in one or two lines plus a link to the full ADR.

- Superseded ADRs are absent; partially superseded ones state only the surviving clauses.
- It is a projection of the ADRs, never a source: if the two disagree, the ADR wins and the digest
  is corrected.
- Every ADR change updates the digest in the same commit — a new ADR adds its line, a supersession
  removes or rewrites the old one's.
- Budget: one line per decision. A digest growing past ~20 KB means decisions are being recorded
  that the code already makes obvious.

## Loading

- **Every session:** `DIGEST.md` is loaded through an `@` import in the project's `CLAUDE.md`
  (`@docs/adr/DIGEST.md` from a root `CLAUDE.md`, `@../docs/adr/DIGEST.md` from `.claude/CLAUDE.md`).
  Treat every line as binding; do not re-open a settled decision without new evidence.
- **On demand:** read the full ADR when the work touches its topic, before changing code it governs,
  or when its line is not enough to apply it.
- **Never** load the whole folder by default — the cost grows with history, while the value lies in
  the current state.

## Recording one

1. Draft title, decision, why and how-to-apply from the conversation; confirm them with the user in
   one exchange.
2. Find any ADR it supersedes or extends; update the old one's `Status` if it is overturned.
3. Write `NNNN-….md` with the highest existing number plus one.
4. Update `DIGEST.md`. For the project's first ADR, create it and add its import line to `CLAUDE.md`.
