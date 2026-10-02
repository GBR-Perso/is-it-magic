---
name: apply-conventions
description: "Inject one or more generic convention bundles (clean architecture, Vue app, …) into this project — copies the chosen bundle(s) into .claude/conventions/ and links them via @import in CLAUDE.md as guidance. Idempotent; re-run to refresh."
disable-model-invocation: true
---

Inject generic convention bundles into the current project so that `/project-investigate`, `/project-decide`, `/project-requirements`, and `/project-implement` (and the agents they spawn) become aware of the project's conventions. Bundles are **guidance referenced from CLAUDE.md** — not enforced rules.

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Arguments

`$ARGUMENTS` is optional — one or more bundle ids (e.g. `clean-archi`, `app-vue`). If empty, the skill lists the available bundles and asks which to apply.

## Phase 0 — Discover available bundles

List the gold bundles shipped with the plugin (each `.md` file in `conventions/` is one bundle; its filename without extension is the bundle id):

```bash
# Unix
ls "${CLAUDE_PLUGIN_ROOT}/conventions/"*.md
```

```powershell
# Windows
Get-ChildItem -Path "${CLAUDE_PLUGIN_ROOT}/conventions" -Filter "*.md" -File
```

Store the bundle ids as `AVAILABLE_BUNDLES`. For each, read its first `# ` heading line to use as a one-line label. If `AVAILABLE_BUNDLES` is empty, stop:

```
No convention bundles found in ${CLAUDE_PLUGIN_ROOT}/conventions/. Is the plugin installed correctly?
```

## Phase 1 — Select bundles

- **If `$ARGUMENTS` names one or more bundles**: validate each against `AVAILABLE_BUNDLES`. If any id is unknown, print the available ids and stop.
- **If `$ARGUMENTS` is empty**: ask via `AskUserQuestion` (multiSelect) which bundle(s) to apply, listing each `AVAILABLE_BUNDLES` id with its heading label.

Store the chosen ids as `SELECTED_BUNDLES`.

## Phase 2 — Inject each selected bundle

For each bundle id `B` in `SELECTED_BUNDLES`:

1. **Source (gold bundle):** `${CLAUDE_PLUGIN_ROOT}/conventions/<B>.md` — the source of truth.
2. **Copy:** ensure `.claude/conventions/` exists; copy the gold bundle → `.claude/conventions/<B>.md`, overwriting. The plugin is the source of truth — edits to the project copy are overwritten on re-apply.
3. **Link in CLAUDE.md:**
   - If `.claude/CLAUDE.md` does not exist, create it with a `# <project name>` heading followed by a `## Stack Conventions` section.
   - If it exists but has no `## Stack Conventions` section, append that section.
   - Ensure the line `@./conventions/<B>.md` appears exactly once under `## Stack Conventions`. Add it if missing; leave it untouched if already present.

## Phase 3 — Report

Print one line per bundle:

```
apply-conventions — Complete
──────────────────────────────────────────────
  <B>   copied → .claude/conventions/<B>.md   | import: added | already present
  ...
──────────────────────────────────────────────
Conventions are now imported into .claude/CLAUDE.md and will load as project context.
Re-run any time to refresh. To remove a bundle: delete its `@import` line and `.claude/conventions/<B>.md`.
```

## Guardrails

- Never modify the gold bundles in `${CLAUDE_PLUGIN_ROOT}/conventions/` — they are the read-only source of truth.
- Copy bundles verbatim — no content transformation.
- This injects **guidance** into `CLAUDE.md`; it does **not** write enforced rules into `.claude/rules/`.
- Never stage, commit, or push anything.
