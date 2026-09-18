---
name: project-decide
description: Decision layer between investigation/debug and implementation. Reads findings from the conversation, infers debt trajectory from the investigation evidence, weighs up to 4 distinct options — including retaining the status quo — with pros/cons and effort signal, and commits to a recommendation grounded in long-term maintainability and architectural correctness. Strictly read-only — no agents, no file I/O.
---

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Constraints

- **Read-only.** This skill must never modify source files, configuration, Azure resources, or any project artefact.
- **No agents.** This skill operates entirely from conversation context — it spawns no sub-agents and performs no file I/O.
- **No re-scanning.** The skill reasons over findings already present in the conversation. It does not re-run Glob, Grep, or Read operations against the codebase.
- **Option cap.** Generate at most 4 options. There is no minimum: retaining the status quo is always an admissible option and may stand as the sole recommendation, so a report need not manufacture alternatives to hit a quota.

## Input

`$ARGUMENTS` — optional short framing supplied by the user (e.g. "focus on the auth layer", "we can't touch the DB schema"). If absent, the skill infers scope from the investigation or debug report already in the conversation.

The skill's primary input is the **investigation or debug report already present in the conversation context**. It does not require the user to re-run a scan or re-paste findings.

---

### Phase 0 — Locate and absorb the report

1. Scan the current conversation context for an Investigation Report or a Debug Report — both produced by `/project-investigate`. If both are present, prefer the most recent one.

2. If no report is found in the conversation, stop and inform the user:

   Use `AskUserQuestion`:
   - Question: "No investigation or debug report was found in the conversation. Would you like to run one first, or paste the findings directly?"
   - Options:
     - `Run /project-investigate first`
     - `Paste findings now (I'll provide them)`

   If the user selects "Paste findings now", accept their free-text input as the findings and continue.

3. Read `$ARGUMENTS`. If provided, record it as the **user framing constraint** — it narrows the scope or excludes directions the user has ruled out. If absent, infer scope from the report content.

---

### Phase 1 — Restate the core problem

1. From the findings, derive a concise **Problem Statement** covering:
   - What the investigation or debug session determined is the core issue or opportunity
   - The affected area (layer, component, service) as evidenced by the report
   - Any constraints introduced by `$ARGUMENTS` (if provided)

2. Present the Problem Statement to the user, then (see *Understanding-validation gates* in `_ux-rules.md`):
   - **Input is a report produced in this conversation by `/project-investigate`** → proceed immediately without asking. The user already saw and approved those findings when the report was produced.
   - **Input was pasted or supplied directly by the user** → ask for confirmation via `AskUserQuestion` only when the findings are materially ambiguous:
     - Question: "Before going further, I want to confirm the problem we are solving. Does this capture it correctly?"
     - Present the Problem Statement in the question text.
     - Options:
       - `Yes — this is correct, continue`
       - `No — let me correct it` (user provides correction via the free-text Other input)

3. If the user corrects it: incorporate their correction into the Problem Statement and proceed. Do not re-ask — one correction pass is sufficient.

---

### Phase 2 — Decide whether action is warranted, then generate options

1. **Status-quo gate — a reasoning step, not a rendered option.** Before generating any change-options, judge whether the current state is an acceptable resting place. Reason from the findings and the same centrality / coupling / build-surface signal you will formalise in Phase 3:
   - **Status quo is defensible** (the concern is cosmetic, isolated, or speculative, and nothing compels a change) → carry "retain the status quo / defer" into Phase 3 as the leading candidate. Generate change-options only where they genuinely illuminate the trade-off — do not manufacture them to fill a quota.
   - **A change is plainly compelled** (correctness defect, security exposure, outage, legal or contractual obligation, or debt the assessment shows will compound) → say so in one line and proceed to options. Do not render a token "do nothing" option that does not belong.
   - **Genuinely unclear** → treat "retain the status quo" as one admissible option alongside the change-options and let Phase 3 weigh it.

2. Generate up to 4 distinct options by reasoning over the confirmed Problem Statement and the findings. Options must be meaningfully different directions — not variations of the same approach. Let the number and shape of the set follow the problem; do not impose a fixed template.

   When a change is warranted, make the span honest: surface the **smallest safe change** (minimum intervention, no restructuring) and, where it differs, the **most structurally correct** approach (best aligned with sound design principles — evidenced by, but not limited to, the conventions observed in the report), so the trade-off between them is visible. This is guidance for spanning a real change-space, not a mandate to produce change-options when none are warranted.

   Retaining the status quo is always **admissible** — as a candidate and as the recommendation — and never **mandatory**. Include it when the gate points there; omit it when a change is plainly compelled.

3. If user framing constraints from `$ARGUMENTS` rule out a direction (e.g. "we can't touch the DB schema"), do not generate options that violate that constraint. Note the constraint in the relevant section.

For each option, produce all of the following:

```markdown
#### Option {N}: {Short title}

**Approach**
A plain-language description of what would change at the conceptual level. No code snippets. No file edit instructions. Describe the direction, not the mechanics.

**Pros**
- ...

**Cons**
- ...

**Effort**: Low / Medium / High *(relative to the other options in this report)*
```

Effort is always relative — calibrate across the full set of options generated, not against an absolute scale.

---

### Phase 3 — Evaluate and recommend

1. Before evaluating options, derive a **Debt Trajectory Assessment** from the investigation report findings. Do not ask the user — reason from the evidence already in the conversation:
   - **Centrality**: Is the affected area a foundation other components depend on, or an isolated concern?
   - **Coupling**: How tightly is this area coupled to the rest of the system? Would debt here constrain changes elsewhere?
   - **Build surface**: Does the investigation suggest this area will be actively extended or built upon going forward?

   State the assessment explicitly in one sentence before proceeding — e.g. *"This area is central to the payment flow, depended on by three other modules — debt here will compound."* or *"This is an isolated utility with no downstream dependents — debt here is low-risk to defer."*

   If the investigation report does not surface enough signal to assess these dimensions, say so explicitly rather than guessing.

2. Review all options against the primary evaluation lens: **long-term maintainability and architectural correctness**, where "architectural correctness" is assessed against sound design principles — not merely against what the existing codebase does today. Conventions observed in the investigation report are evidence, not the standard.

   Weight the recommendation using the Debt Trajectory Assessment:
   - **High compounding risk** (central, coupled, actively built on): the structurally correct option is the default; departing from it requires an explicit, evidence-grounded justification.
   - **Low compounding risk** (isolated, low-touch, not a foundation for future work): the minimal-change option is defensible — and, where the findings show nothing that compels a change, retaining the status quo may be the right call outright. Either way, state what debt is deferred and why it is safe to carry.
   - **Uncertain**: call it based on the available evidence and flag the uncertainty in the rationale.

   **Debt deferral obligation**: If the recommendation is to retain the status quo or to make the smallest change, explicitly state (a) what technical debt it defers and (b) why that debt is acceptable given the Debt Trajectory Assessment.

3. Select one **Recommended Option** — one of the generated change-options, or retaining the status quo where the gate and the assessment point there. State it clearly with a short rationale (2–4 sentences) grounded in the evaluation lens and the Debt Trajectory Assessment.

4. If a different option would be preferred under specific conditions, state that conditional preference explicitly alongside the main recommendation. Frame conditions neutrally — do not imply that structural options are inherently conditional or exceptional choices.

---

### Phase 4 — Produce the Decision Report

Present the full Decision Report to the user. Ensure the rationale in the Recommended Option section explicitly references the **Debt Trajectory Assessment** derived in Phase 3.

```markdown
## Decision Report — <one-line problem title>

### Problem
<confirmed Problem Statement from Phase 1>

---

### Options

#### Option 1: <title>

**Approach**
<plain-language description>

**Pros**
- ...

**Cons**
- ...

**Effort**: Low / Medium / High

---

#### Option 2: <title>
... (repeat for each option)

---

### Recommended Option

**Option {N}: <title>**

<rationale — 2–4 sentences grounded in long-term maintainability, architectural correctness, and the Debt Trajectory Assessment>

**Conditional preference**: <if a different option would be better under specific conditions, state it here — or omit this line if no conditional preference applies>

---

> This report is read-only. No code or infrastructure was modified.
```

After presenting the Decision Report, ask via `AskUserQuestion`:

- Question: "The Decision Report is ready. What would you like to do next?"
- Options — these four. When the Recommended Option is a change, keep the order below with `(Recommended)` on the full-pipeline option. **When the Recommended Option is to retain the status quo**, move `Stop here` to the top and give it the `(Recommended)` tag, and drop `(Recommended)` from the implement option — recommending action would contradict the decision.
  - `Run /project-implement — full architect → dev → test → review pipeline (Recommended)`
  - `Run /project-implement — draft, increment, or quick (I'll specify which)`
  - `Run /project-requirements first — produce a formal requirements document`
  - `Stop here — I'll act on this report when ready`

Behaviour:
- Option 1 → invoke `/project-implement` with no mode argument (full pipeline).
- Option 2 → ask which mode (the user may state `draft`, `increment`, or `quick` directly via the "Other" input), then invoke `/project-implement <mode>`.
- Option 3 → invoke `/project-requirements`.
- Option 4 → end the skill; the report remains in the conversation.

This handoff offers to invoke another skill — selecting "Stop here" leaves everything untouched. The skill performs no file changes.

---

## Conversation Style

- Be analytical and opinionated — surface a clear recommendation, not a list of equally weighted choices.
- Ground every evaluation point in something specific from the findings (a pattern observed, a tradeoff identified, a convention in use).
- Do not propose implementation steps, code changes, or file edits — stay at the conceptual level.
- If the findings are ambiguous or incomplete, acknowledge the uncertainty in the relevant option's Cons rather than refusing to proceed.
- Use British English throughout.
