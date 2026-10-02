---
name: project-requirements
description: Produce a formal requirements document for app evolution. Explores the codebase for context, facilitates a structured conversation with the user, and outputs a versioned requirements document — never proposes implementation details.
---

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Constraints

- **No code changes** — this skill is for ideation and requirement writing only.
- **No implementation details** — never propose specific technical solutions, architecture patterns, file changes, or code snippets.
- **Codebase as context only** — read the codebase to understand what exists today, not to plan how to change it.
- Output is always a **requirements document**, not a technical spec.

## Instructions

### Phase 0 — Quick scan

Using only Glob, Grep, and Read tools — without spawning any agents — perform a lightweight self-scan to build an initial "State of the App" snapshot.

1. Read `.claude/CLAUDE.md` if present — for project identity, stack, and any stated architectural guardrails.
2. Read `.claude/project-context.md` if present — for business context, team, and user base.
3. Use `Glob` to locate project metadata files (`README.md`, `package.json`, `*.sln`/`*.csproj`, `pyproject.toml`, `go.mod`, etc. — whatever the project uses); read the most informative one.
4. Use `Glob` to identify the top-level directory structure — note the major areas, whatever they are.
5. Identify one or two key entry-point files (the app's main/bootstrap file, route or page registrations) and read them.
6. Produce a **Quick Context Summary** in this format:

```markdown
## Quick Context Summary

### Project identity
<name, purpose, and stack — derived from CLAUDE.md / project-context.md / metadata files>

### Major areas
<bullet list of top-level directories or layers and their stated purpose>

### Key entry points found
<bullet list: file paths and what they reveal about the application's structure>

### Gaps
<what could not be determined without a deeper scan — e.g. domain model detail, full feature list, internal service responsibilities>
```

Present the Quick Context Summary to the user, then judge whether it gives enough context to brainstorm on, and state the verdict in one line — do not ask (see *Understanding-validation gates* in `_ux-rules.md`):

- **Enough context** (the Gaps listed do not touch the areas the user is likely to evolve): skip Phase 1 entirely. Proceed directly to Phase 2 (Brainstorming), starting at step 4 (the `AskUserQuestion` about which area to evolve). Use the Quick Context Summary as the "State of the App" context for the brainstorming conversation — do not re-run context gathering. Note that the user can ask for a deeper codebase exploration if they want it.
- **Not enough** (the Gaps are material to the evolution being discussed): say why in one line and proceed to Phase 1 below, which will spawn the codebase-explorer agent.

---

### Phase 1 — Context Gathering

1. Spawn the agent defined in `${CLAUDE_PLUGIN_ROOT}/agents/codebase-explorer.md`.
2. Present the agent's output as a **"State of the App"** summary to the user — what exists, what the app currently does, who it serves.

### Phase 2 — Brainstorming

4. Ask the user what area(s) they want to evolve. Use `AskUserQuestion` with options like:
   - "Expand an existing feature"
   - "Add a completely new capability"
   - "Rethink the user experience"
   - "Add integrations / data sources"
   - "Other (describe)"
5. For each idea the user brings up:
   - **Explore** — ask open-ended questions to flesh out the idea (who benefits, what problem it solves, what would success look like)
   - **Challenge** — raise edge cases, user experience concerns, or scope questions — but stay at the _what_, never the _how_
   - **Resolve** — every question raised must be answered before moving on, even if the answer is approximate (e.g. "we'll refine this later" or "good enough for now"). Do not leave open questions dangling.
   - **Capture** — summarise the idea as a short requirement statement
   - **Split** — if the idea covers multiple independent concerns, propose splitting it into separate epics rather than letting scope grow unchecked.

### Phase 3 — Requirements Document

6. Once the user signals they're done brainstorming, compile everything into a structured requirements document. Use this format:

```markdown
# [App Name] — Evolution Requirements

## Vision

One paragraph describing the overall direction.

## Epics

### Epic 1: [Name]

**Goal**: What this achieves for users.

#### Requirements

- **REQ-1.1**: [Requirement statement — user-facing, testable]
- **REQ-1.2**: ...

#### Decisions & Assumptions

- [Any fuzzy or deferred answers acknowledged during brainstorming, e.g. "Exact threshold TBD — rough target is X"]

### Epic 2: [Name]

...

## Priorities

| Priority | Epic / Requirement | Rationale |
| -------- | ------------------ | --------- |
| 1        | ...                | ...       |

## Out of Scope

- Items explicitly deferred or rejected during brainstorming.

## Delivery Phases *(optional — omit for simple features)*

Break the implementation into ordered batches. Each phase should be deliverable independently.

| Phase | Scope | Layers affected |
| ----- | ----- | --------------- |
| 1     | ...   | e.g. data model / persistence |
| 2     | ...   | e.g. business logic + API |
| 3     | ...   | e.g. front-end |
| 4     | ...   | e.g. infrastructure |

> Omit this section entirely if the feature is small enough to implement in a single pass.
```

7. Present the draft to the user via `AskUserQuestion` with options:
   - "Looks good — save it"
   - "Don't save — go straight to implementation"
   - "I want to revise some requirements"
   - "Let's brainstorm more before finalising"
   - "Split into separate documents — this covers too much"
   - "Other"

8. **If "Looks good — save it"**: save the document to `docs/requirements/` with a descriptive filename (e.g. `docs/requirements/evolution-v2-pricing-overhaul.md`).

9. **If "Don't save — go straight to implementation"**: take the **transient path** — do **not** write anything to disk.
   - Keep the compiled requirements draft in the conversation as the working brief.
   - Ask the user via `AskUserQuestion`: "Proceed with implementation now using these requirements?" with options:
     - "Yes — full pipeline" (`/project-implement` — architect → dev → test → review)
     - "Yes — draft mode" (`/project-implement draft` — architect + developer only)
     - "Yes — increment mode" (`/project-implement increment` — developer + test loop, no architect or review)
     - "Yes — quick mode" (`/project-implement quick` — developer only)
     - "No — stop here"
   - If the user picks any "Yes" option, hand the in-conversation requirements brief straight to `/project-implement` (in the chosen mode) as the requirement input — no requirements file is created.
   - If the user picks "No — stop here", end the skill; the requirements remain only in the conversation.

## Conversation Style

- Be a **thinking partner**, not a note-taker — push back, ask "why", suggest angles the user hasn't considered.
- Keep the energy collaborative and forward-looking.
- When the user drifts into implementation ("we could use a queue for that"), gently redirect: _"That's an implementation detail — for now, what should the user experience be?"_
- Use British English throughout.

---

> **Next step**: once the requirements document is saved, use `/project-implement` to act on these requirements.
> - `/project-implement` — full architect → dev → test → review pipeline (default)
> - `/project-implement draft` — architect + developer only, no test loop, for fast iteration
> - `/project-implement increment` — developer + test loop, no architect or review (tested change to live code)
> - `/project-implement quick` — developer only, for small or contained changes
