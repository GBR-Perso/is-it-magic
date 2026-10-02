---
name: project-port
description: >
  Port files or a feature between sibling projects under the same parent directory.
  Resolves the target and direction from natural language, resolves files
  from session context and search, asks for confirmation, then merges or
  copies intelligently. Never stages or commits.
---

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Input

`$ARGUMENTS` — a free-text sync intent, e.g.:
  "sync the splashscreen mechanism to other-app"
  "bring Button.tsx in from the template project"
  "push *.ts to my-other-app"

If `$ARGUMENTS` is empty, use `AskUserQuestion` to ask the user what they want to sync and between which projects before proceeding.

## Phase 1 — Target Discovery

### Step 1.1: Extract the target name

Extract the target name or phrase from `$ARGUMENTS`. Target names typically follow directional keywords: "to \<name\>", "into \<name\>", "from \<name\>", "sync to \<name\>", "pull from \<name\>". If no target name can be extracted, ask via `AskUserQuestion`:
- Question: "Which project is the sync target?"
- Option: `I'll type it` (user provides free text)

### Step 1.2: Run the locator agent

Spawn the agent defined in `${CLAUDE_PLUGIN_ROOT}/agents/project-locator.md`.

Prompt it with:

```
Locate project: <extracted target name>
```

Wait for the agent to return its result block.

### Step 1.3: Resolve the target path from the result block

Branch on the `Status:` field in the result block:

**`Status: MATCH`**
- Extract the `Path:` value and record it as `TARGET_PATH`.
- If the confidence is **High**: proceed to Phase 2 silently.
- If the confidence is **Medium** or **Low**: ask via `AskUserQuestion`:
  - Question: "The locator found `<folder name>` under `<parent>` with **<confidence>** confidence (`<rationale>`). Is this the right sync target?"
  - Options:
    - `Yes — this is correct`
    - `No — search again with a different name`
  - If "No": ask for a revised name and repeat from Step 1.1 with the new input.

**`Status: MULTIPLE_MATCHES`**
- Present the ranked match list via `AskUserQuestion`:
  - Question: "The name `<input>` matched multiple projects. Which one is the sync target?"
  - Options: one per match — label is `<folder-name> (<parent>)`, description is the confidence and rationale
- Record the selected `Path:` as `TARGET_PATH` and proceed to Phase 2.

**`Status: NO_MATCH`**
- Display the agent's no-match output and stop.

**`Status: ERROR`**
- Display the agent's error message and stop.

## Phase 2 — Direction Resolution

Analyse `$ARGUMENTS` for directional keywords:
- Keywords "to", "into", "push to", "sync to", "copy to" → SOURCE = current project; DESTINATION = target
- Keywords "from", "bring in from", "pull from", "sync from" → SOURCE = target; DESTINATION = current project

State the resolved direction: "Direction: <SOURCE_PATH> → <DESTINATION_PATH>"

If direction cannot be determined: ask once via `AskUserQuestion` with these options:
- "Push from current project to <target>" (current → target)
- "Pull from <target> into current project" (target → current)

The resolved direction is shown as part of the Phase 3 confirmation — not a separate prompt.

## Phase 3 — Intent & File Resolution

### Step 3.1: Classify the file argument

- Extract the file/concept portion from `$ARGUMENTS` (everything that is not a direction keyword or target name)
- **Glob pattern** (contains `*` or `?`): use `Glob` against the SOURCE project file tree, list all matching files
- **Specific filename** (e.g. `Button.tsx`, `UserService.ts`): use `Glob` to search SOURCE project for files matching that name, present resolved path(s)
- **Concept phrase** (everything else): proceed to Step 3.2

### Step 3.2: Concept-based resolution (concept phrases only)

Apply two signals in parallel:
- Signal A — Session context: scan the current conversation for files, paths, and component names mentioned or discussed that exist within the SOURCE project's directory
- Signal B — File search: use `Glob` and `Grep` to search the SOURCE project for filenames, import references, and content strings matching key nouns from the concept phrase
- Merge both signal lists, deduplicate by path, produce a candidate file list
- If the merged list is empty: stop with "No files could be resolved for '<concept>'. Please clarify — name specific files or describe the feature using terms visible in the codebase."

### Step 3.3: Present resolved file list for confirmation

Present via `AskUserQuestion`:
```
Sync plan:
  Direction: <SOURCE> → <DESTINATION>

  Files to sync:
    <relative-path-in-source>  — <one-line rationale>
    ...

Proceed?
```
Options:
1. "Proceed with all files (Recommended)"
2. "Remove some files from the list"
3. "Cancel"

If "Remove some files": ask the user to name the files to drop, remove them, re-present the final list with options "Confirm final list" or "Cancel".
If the final list is empty after removals: stop with "No files remaining. Sync cancelled."

## Phase 4 — Sync Execution

### Step 4.1: Determine action per file

For each SOURCE file:
- Compute the corresponding DESTINATION path by replacing the SOURCE root prefix with the DESTINATION root prefix, preserving the relative sub-path
- Check whether the DESTINATION file exists:
  - Exists → AI Merge (Step 4.2)
  - Does not exist → Copy (Step 4.3)

### Step 4.2: AI Merge (file exists in destination)

- Read both the SOURCE file and the DESTINATION file in full
- Perform an AI merge: bring in all changes from SOURCE while preserving destination-specific additions, domain-specific identifiers, and any logic unique to the DESTINATION project (different component names, namespaces, local config values)
- Write the merged result to the DESTINATION path
- Record action as "merged — review recommended"

### Step 4.3: Copy (file does not exist in destination)

- Copy the SOURCE file to the DESTINATION path verbatim, creating any intermediate directories that do not exist
- Record action as "copied"

### Step 4.4: Never stage or commit

- Do not run `git add`, `git commit`, or any staging command at any point

## Phase 5 — Post-apply Summary

Print:
```
Sync complete — <SOURCE_BASENAME> → <DESTINATION_BASENAME>

| File | Action | Review |
|------|--------|--------|
| <relative dest path> | copied / merged | — / Recommended |
...

Run `git diff` in <DESTINATION_PATH> to review all changes before committing.
```

## Guardrails

- Never stage, commit, or push any file.
- Never create a directory at workspace-root or target level — only create intermediate directories within an already-existing target project when copying a file into a subdirectory that doesn't exist yet.
- Never overwrite a destination file without an AI merge step — if a destination file exists, always merge rather than overwrite blindly.
- Never proceed with an empty file list.
- Always confirm with the user before any file is written (Phase 3 gate).

## Conversation Style

- Be direct and specific — show paths, not descriptions.
- Keep rationale lines in the file list to one sentence maximum.
- Use British English throughout.
