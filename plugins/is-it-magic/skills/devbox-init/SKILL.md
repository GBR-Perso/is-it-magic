---
name: devbox-init
description: "Set up this machine for the is-it-magic plugin — sync all plugin rules into ~/.claude/rules/ and enable favoured language LSPs in user settings. Idempotent; re-run to refresh."
disable-model-invocation: true
---

Set up (or refresh) this machine for use with the is-it-magic plugin. Syncs all bundled plugin rules into `~/.claude/rules/` and ensures the favoured language LSP plugins are present in the user-level `~/.claude/settings.json`. Fully idempotent — re-run at any time after a plugin update to pull in the latest rules or settings.

## No-argument behaviour

This skill takes no arguments. If any text is passed after the slash command, note that no arguments are accepted and proceed without interruption. Non-interactive — never use `AskUserQuestion`.

---

## Phase 0 — Resolve paths

`PLUGIN_RULES_DIR`, `TARGET_DIR` and `SETTINGS_FILE` are names for the resolved literal paths — report labels, written `<NAME>` wherever they appear in printed output. They are not shell variables: nothing assigns them in the shell that runs the commands below, so writing `$PLUGIN_RULES_DIR` in a command would expand to an empty string and the path would silently collapse to a relative one.

The commands below therefore use only references that genuinely resolve:

- `${CLAUDE_PLUGIN_ROOT}` — a plugin-root token that Claude Code substitutes for a literal absolute path in this file's text before the skill runs. It works in any shell because by then it is no longer a variable at all. Note that `$env:CLAUDE_PLUGIN_ROOT` is **not** equivalent: it is neither the token nor a real environment variable, and expands to nothing.
- `$HOME` (bash) and `$env:USERPROFILE` (PowerShell) — genuine environment variables. `$env:HOME` is usually unset on Windows, which is why the PowerShell commands use `USERPROFILE`.

### Step 0.1 — Resolve `PLUGIN_RULES_DIR`

Set `PLUGIN_RULES_DIR` to the bundled rules directory inside the plugin:

```
PLUGIN_RULES_DIR = ${CLAUDE_PLUGIN_ROOT}/rules/
```

### Step 0.2 — Resolve `TARGET_DIR` and `SETTINGS_FILE`

Detect the platform at runtime by inspecting environment variables — check `USERPROFILE` first (Windows), then `HOME` (Unix):

```bash
# Unix
echo "$HOME"
```

```powershell
# Windows
echo "$env:USERPROFILE"
```

Compute the target paths:

- **Windows** (`USERPROFILE` is set):
  - `TARGET_DIR` = `$env:USERPROFILE\.claude\rules\`
  - `SETTINGS_FILE` = `$env:USERPROFILE\.claude\settings.json`
- **Unix** (`HOME` is set):
  - `TARGET_DIR` = `$HOME/.claude/rules/`
  - `SETTINGS_FILE` = `$HOME/.claude/settings.json`

If neither variable resolves, stop immediately:

```
Cannot resolve home directory — neither USERPROFILE nor HOME is set.
Cannot determine target paths. Aborting.
```

### Step 0.3 — Print resolved paths

```
devbox-init — Resolved paths
──────────────────────────────────────────────
Plugin rules source : <PLUGIN_RULES_DIR>
Rules target        : <TARGET_DIR>
Settings file       : <SETTINGS_FILE>
──────────────────────────────────────────────
```

---

## Phase 1 — Rule sync

### Step 1.1 — Enumerate source files

List all `.md` files in `PLUGIN_RULES_DIR`:

```bash
# Unix
ls "${CLAUDE_PLUGIN_ROOT}/rules/"*.md
```

```powershell
# Windows
Get-ChildItem -Path "${CLAUDE_PLUGIN_ROOT}/rules" -Filter "*.md" -File
```

Expected files include (e.g.) `general.md`, `csharp-lang.md`, `typescript-lang.md`, `infra-lang.md`, `infra-naming.md`, `python-lang.md` — but the actual set is whatever `.md` files are present in `PLUGIN_RULES_DIR` at runtime. The glob commands above are the authoritative enumeration; the list here is illustrative only.

Store the result as `FILES_FOUND`.

If `FILES_FOUND` is empty or the directory is unreadable, stop immediately:

```
No rule files found in <PLUGIN_RULES_DIR>. Is the plugin installed correctly?
```

Otherwise, print the enumerated file list:

```
Source files found:
  <file 1>
  <file 2>
  … (one line per file in FILES_FOUND)
```

### Step 1.2 — Create target directory

Create `TARGET_DIR` if it does not already exist. This is idempotent.

```bash
# Unix
mkdir -p "$HOME/.claude/rules"
```

```powershell
# Windows
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\rules"
```

If directory creation fails, stop immediately:

```
Failed to create target directory: <TARGET_DIR>
Error: <error detail>
Aborting — no files were copied.
```

### Step 1.3 — Copy rule files

For each file enumerated in Step 1.1, copy it verbatim from source to target, overwriting any existing file. **No content transformation, no merge, no frontmatter stripping.** The plugin is the source of truth.

```bash
# Unix — repeat for each file
cp "${CLAUDE_PLUGIN_ROOT}/rules/<filename>" "$HOME/.claude/rules/<filename>"
```

```powershell
# Windows — repeat for each file
Copy-Item -Path "${CLAUDE_PLUGIN_ROOT}/rules/<filename>" -Destination "$env:USERPROFILE\.claude\rules\<filename>" -Force
```

Track each outcome individually:

- On success: record the file as **written** (add to `FILES_WRITTEN`).
- On failure: record the file as **FAILED** with the error message, then **continue** with the remaining files. Do not abort.

---

## Phase 2 — LSP enablement

Ensure the three favoured language LSP plugins are present under `enabledPlugins` in `SETTINGS_FILE`.

### Step 2.1 — Read existing settings

Read `SETTINGS_FILE` if it exists. If the file does not exist, start from `{}`.

### Step 2.2 — Determine missing keys

Check which of the following keys are absent from `enabledPlugins` (or missing entirely because the `enabledPlugins` object does not exist):

| Key | Purpose |
|-----|---------|
| `csharp-lsp@claude-plugins-official` | C# / .NET language intelligence |
| `typescript-lsp@claude-plugins-official` | TypeScript / Vue language intelligence |
| `pyright-lsp@claude-plugins-official` | Python language intelligence |

Collect the missing keys as `KEYS_TO_ADD`. Any key that is already present with any value is left untouched.

### Step 2.3 — Merge and write

If `KEYS_TO_ADD` is non-empty:

- Add each missing key under `enabledPlugins` set to `true`.
- Preserve all other existing JSON content unchanged.
- Write the result back to `SETTINGS_FILE`.

If `KEYS_TO_ADD` is empty, this step is a no-op — do not rewrite the file.

Use PowerShell or bash depending on the detected platform:

```powershell
# Windows — read, merge, write
$settingsFile = "$env:USERPROFILE\.claude\settings.json"
$settings = if (Test-Path $settingsFile) {
    Get-Content $settingsFile -Raw | ConvertFrom-Json
} else {
    [PSCustomObject]@{}
}
if (-not $settings.enabledPlugins) {
    $settings | Add-Member -NotePropertyName 'enabledPlugins' -NotePropertyValue ([PSCustomObject]@{})
}
# Add each missing key
$settings.enabledPlugins | Add-Member -NotePropertyName '<key>' -NotePropertyValue $true -Force
# Reached only when KEYS_TO_ADD is non-empty: this round-trip reformats the whole document, so a
# run where all three keys are already present must not write at all.
# -Depth 100 because ConvertTo-Json silently flattens anything nested deeper than -Depth into a
# string — that would corrupt the user's settings with no error raised.
$settings | ConvertTo-Json -Depth 100 | Set-Content $settingsFile
```

```bash
# Unix — read, merge, write (requires jq)
SETTINGS_FILE="$HOME/.claude/settings.json"
# jq cannot read a missing file, and the && chain below would then short-circuit silently —
# leaving a fresh machine unconfigured, which is exactly the case this skill exists to serve.
[ -f "$SETTINGS_FILE" ] || printf '{}' > "$SETTINGS_FILE"
jq '.enabledPlugins["<key>"] = true' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
```

If writing fails, record the failure and continue to Phase 3 (report the failure in the summary).

---

## Phase 3 — Summary

```
devbox-init — Complete
──────────────────────────────────────────────
Rules synced to <TARGET_DIR> (<count of FILES_WRITTEN>):
  <file 1>  → <TARGET_DIR><file 1>
  <file 2>  → <TARGET_DIR><file 2>
  … (one line per file in FILES_WRITTEN)

Rules now load globally in every Claude Code session on this machine.
Language-specific rules (csharp-lang, typescript-lang, etc.) stay dormant until
files matching their paths: frontmatter appear in the active project.
──────────────────────────────────────────────
LSP enablement (<SETTINGS_FILE>):
  csharp-lsp@claude-plugins-official      — <added | already present>
  typescript-lsp@claude-plugins-official  — <added | already present>
  pyright-lsp@claude-plugins-official     — <added | already present>
──────────────────────────────────────────────
```

Where `FILES_WRITTEN` is the subset of `FILES_FOUND` copied successfully. Counts and lines are derived at runtime — never hardcoded.

If any files failed to copy, append a separate FAILED section:

```
FAILED (<N>):
  <filename>  — <error detail>
```

If all files failed, replace the "Rules synced" section with:

```
No rule files were written. See FAILED section above.
```

---

## Guardrails

- Never stage, commit, or push anything.
- Never modify the source rules in `${CLAUDE_PLUGIN_ROOT}/rules/` — they are read-only for this skill.
- Copy rule files verbatim only — no content transformation, no merge, no frontmatter stripping.
- Non-interactive — never use `AskUserQuestion`. Proceed autonomously.
- Writes nothing project-local — only `~/.claude/rules/` and `~/.claude/settings.json` are touched.
- **Warning**: any hand-edits made directly to files in `~/.claude/rules/` will be overwritten the next time this skill is run. The plugin is the source of truth.
