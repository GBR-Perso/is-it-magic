---
name: project-investigate
description: >
  Investigate a codebase or system or an idea. Three modes, inferred from the input (asked only when ambiguous):
  no args = ask for a question or offer full repository archaeology;
  Bug hunt = locate root cause of a defect, report only;
  Analytical = explore patterns, tradeoffs, or design.
  Always read-only — never modifies code or infrastructure.
---

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Constraints

- **Read-only.** This skill itself never writes a file, in any of its three paths, and every agent it spawns must never modify source files, configuration, or Azure resources. The one write anywhere in this skill's flows belongs to an agent, not the skill: on the no-argument archaeology path, the spawned `repo-archaeologist` agent writes its own report as part of its own Phase 4 — the same behaviour that agent has outside this skill. Debug Mode and Investigate Mode write nothing, at any phase; their Phase 1 agents keep their existing "do not write any report file" spawn instructions, unchanged.
- **No fixes.** Report findings only; the user decides how to act on them.

## Input

`$ARGUMENTS` determines the mode:

| Value | Behaviour |
|---|---|
| Empty | Prompt the user for a question via `AskUserQuestion` before doing anything |
| Any text | Treat as the question/symptom and proceed to Phase 0 of the appropriate mode |

Mode selection (Bug hunt vs Analytical) is inferred from the input in Phase 0 — the user is asked only when the input could plausibly be either.

---

### No-argument behaviour

When `$ARGUMENTS` is empty:

1. Ask via `AskUserQuestion`:
   - Question: "What would you like to investigate? You can describe a specific question or symptom, or run a full repository archaeology scan to understand the codebase from scratch."
   - Options:
     - `I have a specific question or symptom — I'll describe it`
     - `Run full repository archaeology — blind scan of everything`

2. If the user selects **"Run full repository archaeology"**:
   - Spawn the agent defined in `${CLAUDE_PLUGIN_ROOT}/agents/repo-archaeologist.md`.
     - Pass no additional arguments — the agent operates on the current working directory.
     - Instruct it to complete all phases and return its structured summary. (The agent writes its own report file as part of its Phase 4 — do not override that.)
   - Wait for the agent to return its summary, then present it:

     ```markdown
     <At-a-glance digest — insert the block from "Shared: At-a-glance digest" above the summary.>

     ## Repository Archaeology — Summary

     ### Purpose
     <agent's Purpose paragraph>

     ### Key Workflows
     <agent's Key Workflows list>

     ### Notable Quirks
     <agent's Notable Quirks list>

     ### Documentation Gaps
     Total: N gaps (Type A: N — undocumented code | Type B: N — stale docs | Type C: N — unexplained rules)

     **Report**: <path returned by the agent>
     ```

   - The skill ends here.

3. If the user selects **"I have a specific question or symptom"**:
   - Accept their free-text input as `$ARGUMENTS` and proceed to Phase 0 of the mode-selection flow below.

---

### Phase 0 — Understand the question *(applies to both Bug Hunt and Analytical paths)*

1. If `$ARGUMENTS` was provided, read it as the initial question or symptom. If it was blank and the user typed their question in response to the no-argument prompt, use that text.

2. Restate the input as a short investigation brief:
   - **Question / Symptom** — what the user wants to understand or what they are seeing
   - **Scope** — component, layer, or service (if mentioned)
   - **Azure involved?** — infrastructure, auth, Key Vault, app registrations, Azure AD, Entra, MSAL, tenant, subscription, Static Web App, App Service, managed identity, deployments, or cloud resources
   - **Browser involved?** — URL, live app, web UI, API response in a browser, page behaviour, network requests, console errors, or anything requiring a running application

3. Infer the mode from the brief: a defect, error, or unexpected behaviour → **Bug hunt**; a question about patterns, design, performance, or how something works → **Analytical**. Present the brief and the inferred mode as plain text — do not gate on either (see *Understanding-validation gates* in `_ux-rules.md`).

   Ask via a single `AskUserQuestion` call only when something is genuinely unclear:
   - **Mode could plausibly be either** → ask: "Is this a bug hunt or an analytical investigation?" (`Bug hunt — find a defect` / `Analytical — understand patterns / design`)
   - **Input is materially ambiguous** (missing scope, contradictory, or open to multiple plausible readings) → ask the user to confirm or correct the brief (`Looks right — continue` / `Let me clarify`)

   Merge both questions into the same call when both apply. Ask neither for a clear input.

4. Proceed to **Debug Mode Phase 0.5** or **Investigate Mode Phase 0.5** per the selected mode.

---

### Debug Mode

#### Phase 0.5 — Quick scan

Using only Glob, Grep, and Read — no agents:

1. Use `Glob` to locate files matching the suspected area.
2. Use `Grep` to search for error-site indicators: exception types, error messages, null-guard patterns, relevant function names.
3. Read the most relevant 3–5 files focusing on error-handling paths and the suspected call chain.
4. Produce a **Quick Debug Summary**:

```markdown
## Quick Debug Summary — <one-line issue title>

### Suspected error site
<file path + approximate location, one-sentence explanation>

### Supporting evidence
<bullet list: file paths, error-handling patterns, code observations>

### Limitations of this scan
<what static analysis cannot determine>
```

Judge whether the quick scan has resolved the question or symptom with confidence:
- **Resolved** → print the Quick Debug Summary block above in full, note the user can ask to go deeper with agents, and end here.
- **Not resolved** → do NOT print the block above. Print only a one-to-two-line verdict — the suspected area and why it is not confirmed — then proceed to Phase 1. (Phase 3's digest supersedes this summary; printing both is the same ground twice.)

#### Phase 1 — Parallel investigation

Launch agents simultaneously based on what is relevant.

**1a — Code investigation (always)**

Spawn `${CLAUDE_PLUGIN_ROOT}/agents/repo-archaeologist.md` with:

```
IMPORTANT: You are being used for targeted bug investigation, not a repository overview.
Do NOT write any file to .claude/reports/ and do NOT produce an archaeology report.
Produce only the Bug Location Report format below.

Your goal is to locate and understand the bug — NOT to fix it.

Issue brief:
<paste the brief from Phase 0>

Investigation tasks:
1. Identify the files, classes, and functions most likely involved in the symptom.
2. Trace the relevant data flow or call chain end-to-end.
3. Look for obvious defects: null paths, missing guards, incorrect logic, wrong assumptions, mismatched types, off-by-one errors, race conditions, misconfigured values.
4. Note any related tests (passing or failing) that are relevant.
5. Flag any code patterns that are surprising or deviate from surrounding conventions.

---

## Bug Location Report

### Suspected Root Cause
One paragraph. What you think is actually wrong and why.

### Evidence
Bullet list. For each piece: file path + line range, what it shows, why it is relevant.

### Data / Call Flow
Step-by-step trace from entry point to the point of failure (file:line for each step).

### Related Tests
List test files covering the affected area. Note if passing, failing, or missing.

### Uncertainties
What could not be determined from static analysis alone.
```

**1b — Browser investigation** (only when Browser is relevant) — see shared browser steps below.

**1c — Azure investigation** (only when Azure is relevant) — see shared Azure steps below.

#### Phase 2 — Confirmation gates

Same as Investigate Mode Phase 2.

#### Phase 3 — Synthesise and report

Assemble the full report:

```markdown
## Debug Report — <one-line issue title>

### Issue
<symptom from Phase 0 brief>

---

### Suspected Root Cause
<from the Bug Location Report>

### Evidence
<from the Bug Location Report>

### Data / Call Flow
<from the Bug Location Report>

### Related Tests
<from the Bug Location Report>

---

### Browser Findings
<Browser Findings section — omit this heading and its surrounding `---` separators entirely if Browser was not investigated>

---

### Azure Findings
<Azure Findings Report, or a one-line "Skipped by user" / "Not logged in" entry — omit this heading and its surrounding `---` separators entirely if Azure was not investigated>

---

### Open Uncertainties
<merged list from both agents>

---

> This report is read-only. No code or infrastructure was modified.

---

<Executive digest — see "Shared: Executive digest" below.>
```

After the report, ask via `AskUserQuestion`:

- Question: "The Debug Report is complete. Continue to `/project-decide` now to evaluate solution options? (`/project-decide` reads this report straight from the conversation — no need to re-run the investigation.)"
- Options:
  - `Continue to /project-decide now (Recommended)`
  - `Stop here — I'll decide what to do next`

If **"Continue to /project-decide now"**: invoke `/project-decide` with no arguments — it locates this Debug Report in the conversation automatically.
If **"Stop here"**: end the skill; the report remains in the conversation.

---

### Investigate Mode

#### Phase 0.5 — Quick scan

Using only Glob, Grep, and Read — no agents:

1. Use `Glob` to locate files relevant to the question's subject area.
2. Use `Grep` to search for key symbols, identifiers, or terms from the brief.
3. Read the most relevant 3–5 files or sections.
4. Produce a **Quick Findings** summary:

```markdown
## Quick Findings — <one-line question title>

### What was found
<bullet list: relevant files, key symbols, patterns, structural observations>

### Limitations of this scan
<what the quick scan could not determine>
```

Judge whether the quick scan has resolved the question or symptom with confidence:
- **Resolved** → print the Quick Findings block above in full, note the user can ask to go deeper with agents, and end here.
- **Not resolved** → do NOT print the block above. Print only a one-to-two-line verdict — the suspected area and why it is not confirmed — then proceed to Phase 1. (Phase 3's digest supersedes this summary; printing both is the same ground twice.)

#### Phase 1 — Parallel investigation

Launch agents simultaneously based on what is relevant.

**1a — Code investigation (always)**

Spawn `${CLAUDE_PLUGIN_ROOT}/agents/repo-archaeologist.md` with:

```
IMPORTANT: You are being used for targeted analytical investigation, not a repository overview.
Do NOT write any file to .claude/reports/ and do NOT produce an archaeology report.
Produce only the Code Investigation Report format below.

Your goal is NOT to find bugs — only to identify patterns, bottlenecks, design tradeoffs, and usage characteristics.

Investigation brief:
<paste the brief from Phase 0>

Investigation tasks:
1. Identify the files, classes, and functions most relevant to the question.
2. Trace the relevant data flow, call chain, or execution path end-to-end.
3. Describe how the relevant code is structured: layers, responsibilities, coupling, cohesion.
4. Identify any performance characteristics visible from static analysis (query patterns, N+1 risks, caching, synchrony, resource use).
5. Note design tradeoffs: what is the current approach optimised for, and what does it trade away?
6. Flag any patterns that are notable, unusual, or that would surprise a new developer.

---

## Code Investigation Report

### Summary
One paragraph. What the investigation question is about and what you found at a high level.

### Relevant Code Areas
Bullet list. For each area: file path + key locations, what it does, why it is relevant.

### Data / Call Flow
Step-by-step trace through the relevant path (file:line for each step).

### Patterns & Characteristics
Bullet list: design patterns in use, performance traits, coupling, cohesion, notable conventions.

### Design Tradeoffs
What the current approach is optimised for and what it sacrifices. Grounded in specific code evidence.

### Uncertainties
What could not be determined from static analysis alone.
```

**1b — Browser investigation** (only when Browser is relevant) — see shared browser steps below.

**1c — Azure investigation** (only when Azure is relevant) — see shared Azure steps below.

#### Phase 2 — Confirmation gates

Same as Debug Mode Phase 2.

#### Phase 3 — Synthesise and report

Assemble the full report:

```markdown
## Investigation Report — <one-line question title>

### Question
<question from Phase 0 brief>

---

### Summary
<from the Code Investigation Report>

### Relevant Code Areas
<from the Code Investigation Report>

### Data / Call Flow
<from the Code Investigation Report>

### Patterns & Characteristics
<from the Code Investigation Report>

### Design Tradeoffs
<from the Code Investigation Report>

---

### Browser Findings
<Browser Findings section — omit this heading and its surrounding `---` separators entirely if Browser was not investigated>

---

### Azure Findings
<Azure Findings Report, or a one-line "Skipped by user" / "Not logged in" entry — omit this heading and its surrounding `---` separators entirely if Azure was not investigated>

---

### Open Uncertainties
<merged list from both agents>

---

> This report is read-only. No code or infrastructure was modified.

---

<Executive digest — see "Shared: Executive digest" below.>
```

After the report, ask via `AskUserQuestion`:

- Question: "The Investigation Report is complete. Continue to `/project-decide` now to evaluate solution options? (`/project-decide` reads this report straight from the conversation — no need to re-run the investigation.)"
- Options:
  - `Continue to /project-decide now (Recommended)`
  - `Stop here — I'll decide what to do next`

If **"Continue to /project-decide now"**: invoke `/project-decide` with no arguments — it locates this Investigation Report in the conversation automatically.
If **"Stop here"**: end the skill; the report remains in the conversation.

---

## Shared: At-a-glance digest

Insert this block immediately above the report's own `## …` heading, inside the same fenced
template. Additive only — never replace or reorder anything below it. This block applies only to the
no-argument archaeology summary — the Debug Report and Investigation Report print the executive digest
below instead.

```markdown
## At a glance

**In one line**: <the answer / what this is>

**Shape**:
<ASCII flow, at most 5 hops — e.g. `Controller → Service → Repository → SQL (fails here)` — or one line of prose if no traceable path applies>

> Digest only. The full report below is unabridged.
```

**Bound**: at most 8 lines, at most ~60 words. No diagrams — this output is printed in a terminal. If the finding has no traceable path, write one line of prose in **Shape** rather than drawing a nominal flow.

---

## Shared: Executive digest (Debug Report / Investigation Report)

Phase 3 of Debug Mode and Investigate Mode prints this block at the end of the same template,
immediately after the full report and its read-only note — this is what is on screen when the run
finishes; the full report above it is a scroll away.

```markdown
## Executive digest

- <grounded finding, ~20 words> (`path/to/file:line`)
- <up to 8 bullets total>

**Next step**: `/project-decide` reads the report above — no need to re-run the investigation.
```

Composition rules:
- Skip any row whose source did not run — omit the row entirely, never print "Not investigated".
- Row order: (1) root cause / summary bullet, with `file:line`; (2) up to 3 key-evidence bullets, each
  `file:line` — drawn from Evidence / Relevant Code Areas, or, where it is the more load-bearing
  finding, from Related Tests, Patterns & Characteristics, or Design Tradeoffs; (3) one call/data-flow
  bullet, prose, hop arrows allowed, no diagram; (4) a Browser verdict bullet, only if Browser was
  investigated; (5) an Azure verdict bullet, only if Azure was investigated; (6) the top
  open-uncertainty bullet, only if material.
- Every section of the full report is covered by a row above or by this sentence: a template section
  that does not surface a bullet is intentionally held in the report body above only, not silently
  dropped.
- Bound: at most 8 bullets total, each one line (~20 words). The next-step line above replaces the
  old four-mode `/project-implement` footer entirely.

---

## Shared: Browser Investigation (Phase 1b)

Use Claude in Chrome tools directly (no agent spawn). Load each tool via `ToolSearch select:mcp__claude-in-chrome__<tool_name>` before calling it.

1. Load `mcp__claude-in-chrome__tabs_context_mcp` and call it. Reuse a matching tab or create a new one.
2. Navigate to the URL from the brief. If no URL was given, ask via `AskUserQuestion` first.
3. Use `get_page_text` and `read_page` to capture page content.
4. Use `read_console_messages` (with a relevant `pattern`) to collect errors and logs.
5. Use `read_network_requests` to observe API calls, status codes, and payloads.
6. If useful, use `javascript_tool` to inspect DOM state — never trigger alert/confirm/prompt.
7. Produce a **Browser Findings** section:

```markdown
### Browser Findings

#### URL / App
<URL navigated to>

#### Page State
<what the page shows, key UI elements, visible data>

#### Console
<relevant console messages, errors, warnings>

#### Network Requests
<key API calls: method, URL, status, notable response data>

#### Observations
<bullet list of browser-observable behaviours relevant to the question or symptom>
```

**Constraints:** Never trigger browser dialogs. Do not modify page state. If a tool fails after 2 attempts, note the failure and move on.

---

## Shared: Azure Investigation (Phase 1c)

Spawn `${CLAUDE_PLUGIN_ROOT}/agents/azure-investigator.md` with:

```
Investigation brief:
<paste the brief from Phase 0>

Begin Phase 0 only: run your detection flow and auth check, then stop and return your findings.
```

**Confirmation gate (Phase 2):**

- **NOT logged in** → inform user, skip Azure, note in report.
- **Active context** → present tenant/subscription/user to the user via `AskUserQuestion`:
  - `Yes — correct environment, continue`
  - `No — skip Azure investigation`
- If confirmed: `SendMessage` to the agent to proceed with Phase 1. Wait for the Azure Findings Report.
- If declined: note "Azure investigation skipped by user" in the report.

---

## Conversation Style

- Be analytical and neutral — surface what exists, not what should change.
- Do not propose solutions, fixes, or refactors.
- If agents surface contradictory evidence, present both views.
- Use British English throughout.
