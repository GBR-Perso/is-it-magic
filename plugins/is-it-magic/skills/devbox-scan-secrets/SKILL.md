---
name: devbox-scan-secrets
description: "Audit the local dev machine for exposed secrets — credential files, private keys, cloud credentials, and hardcoded tokens. Writes a dated CSV report to .claude/secret-audit-YYYY-MM-DD.csv."
---

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Guardrails

- Never modify, delete, move, or rename any file.
- Never commit, stage, or push anything.
- Never print a full secret value. Verify agent output has applied Variant B redaction from `${CLAUDE_PLUGIN_ROOT}/skills/shared/_secret-redaction.md` before writing any CSV row.

## Arguments

```
/devbox-scan-secrets [path]
```

`$ARGUMENTS` is optional. If provided, it is an additional directory path to scan recursively. If empty, only the fixed high-risk locations are scanned.

---

### Phase 0 — Resolve scan scope

#### Step 0.1 — Resolve home directory and config base

Detect the platform at runtime and resolve `HOME_DIR` and `CONFIG_BASE`:

```bash
# Unix / macOS
echo "$HOME"
echo "${XDG_CONFIG_HOME:-$HOME/.config}"
```

```powershell
# Windows
echo "$env:USERPROFILE"
echo "$env:APPDATA"
```

- **Windows** (`USERPROFILE` is set): `HOME_DIR` = `%USERPROFILE%`, `CONFIG_BASE` = `%APPDATA%`
- **Unix / macOS** (`HOME` is set): `HOME_DIR` = `$HOME`, `CONFIG_BASE` = `$XDG_CONFIG_HOME` if set, otherwise `$HOME/.config`

If neither `USERPROFILE` nor `HOME` resolves, stop immediately:

```
Cannot resolve home directory — neither USERPROFILE nor HOME is set. Aborting.
```

If `CONFIG_BASE` cannot be resolved, skip that location and note the omission in the preflight output.

#### Step 0.2 — Build location list

Assemble the fixed high-risk locations:

| Path | Depth |
|------|-------|
| `<HOME_DIR>/.azure/` | recursive |
| `<HOME_DIR>/.ssh/` | recursive |
| `<HOME_DIR>/.aws/` | recursive |
| `<CONFIG_BASE>/` | shallow (top level only) |
| `<HOME_DIR>/` root | shallow (files at root level only, no subdirectories) |

If `$ARGUMENTS` is non-empty:
- Validate the path exists. If it does not, stop:
  ```
  Path not found: <path>
  Provide a valid path or omit the argument to scan only the default high-risk locations.
  ```
- Append it to the location list with depth `recursive`.

#### Step 0.3 — Count files

Enumerate files across all locations respecting depth constraints. Count:
- Total files found
- Binary files (will be skipped by the agent)
- Scan-eligible files (total minus binary)

---

### Phase 1 — Preflight announcement

Print the scope table:

```
Secret Audit — Scope
──────────────────────────────────────────────
Fixed high-risk locations:
  <HOME_DIR>/.azure/          (recursive)
  <HOME_DIR>/.ssh/            (recursive)
  <HOME_DIR>/.aws/            (recursive)
  <CONFIG_BASE>/              (one level deep)
  <HOME_DIR>/ root            (non-recursive)

[If user path provided:]
  <path>                      (recursive)

Total files to inspect: <N>
Binary files (will be skipped): <B>
──────────────────────────────────────────────
```

Then use `AskUserQuestion`:

**Question**: "Proceed with the secret audit?"

Options:
1. `Proceed with scan` (Recommended)
2. `Cancel — abort scan`

If Cancel: print `Scan aborted. No files were read or written.` and stop.

---

### Phase 2 — Spawn scanner agent

Spawn `${CLAUDE_PLUGIN_ROOT}/agents/scanner-devbox.md`, passing:

```json
SCAN_PATHS: [ "<list of resolved absolute paths>" ]
DEPTH_CONSTRAINTS: { "<path>": "recursive|shallow", ... }
```

Wait for the agent to complete. Parse the `SCANNER_DEVBOX_OUTPUT_START … SCANNER_DEVBOX_OUTPUT_END` block from the agent's output.

---

### Phase 3 — Write CSV report

Determine today's date (`YYYY-MM-DD`). Compute the output path:

```
<cwd>/.claude/secret-audit-<YYYY-MM-DD>.csv
```

Create `.claude/` if it does not exist. Overwrite the file if it already exists.

Write the CSV header row:

```
severity,secret_type,file_path,line_number,pattern_matched,partial_value
```

For each finding from the agent output, write one CSV row. Quote all values. Use forward slashes in file paths.

Sort rows: Critical first, then High, Medium, Low.

Print: `Report written to: <absolute path>`

---

### Phase 4 — Terminal summary

Print a summary grouped by severity:

```
Secret Audit Summary — <YYYY-MM-DD>
──────────────────────────────────────────────
CRITICAL (<N>)
  <secret_type>       <count>

HIGH (<N>)
  <secret_type>       <count>

MEDIUM (<N>)
  <secret_type>       <count>

LOW (<N>)
  <secret_type>       <count>

──────────────────────────────────────────────
Total findings:        <N>
Files scanned:         <F>
Binary files skipped:  <B>

Report saved to: <absolute path>
```

If zero findings:

```
No secrets detected across <F> files scanned.
Binary files skipped: <B>

Report saved to: <absolute path>
```
