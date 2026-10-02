---
name: repo-security-scan
description: "Scan a repository for secrets, injection vulnerabilities, and exposure risks. Produces a unified read-only security report using three parallel scanner agents."
---

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Guardrails

- Never modify any source file in the scanned repository.
- Never commit, stage, or push anything.
- Never echo unredacted secret values — not in Phase 0 output, not in error messages.
- Always confirm with the user before cloning a remote repository (see Phase 0, Step 0.4).

## Arguments

```
/repo-security-scan [depth] [target]

depth:   surface (default) | deep
target:  (omitted) → current directory
         path/to/folder → local directory
         owner/repo-name → remote clone
```

**Parsing rules:**

- No arguments → `surface` depth, current directory.
- First token is exactly `surface` or `deep` → that is the depth; remainder is the target (empty = current directory).
- First token is neither `surface` nor `deep` → depth defaults to `surface`; all tokens form the target.
- Target containing `/` → remote mode, interpreted as `owner/repo-name`.

---

## Phase 0 — Preflight

### Step 0.1 — Echo parsed arguments

```
Security Scan
  Mode:   <surface|deep>
  Target: <resolved path or repo>
  Type:   <local|remote>
```

Bind `SCAN_DEPTH` = the parsed depth (`surface` or `deep`). `SCAN_ROOT` is bound below: in local mode it is the resolved target directory (Step 0.2); in remote mode it is the temp clone path (Step 0.4e).

### Step 0.2 — Local mode: verify target exists

If the target directory does not exist, stop immediately:

```
Target directory not found: <path>
Provide a valid path or omit the target to scan the current directory.
```

Otherwise, set `SCAN_ROOT` to the resolved target directory (or the current working directory if no target was provided).

### Step 0.3 — File count guard

Run from the target directory:

```bash
git ls-files | wc -l
```

Apply these thresholds:

| Mode    | Warn threshold | Hard stop threshold |
| ------- | -------------- | ------------------- |
| surface | >500 files     | >2,000 files        |
| deep    | >200 files     | >1,000 files        |

**Hard stop** — print and do NOT proceed:

In **deep mode**:

```
Hard stop: this repository contains N tracked files, which exceeds the deep mode limit of <threshold>.

Options:
  - Switch to surface mode: /repo-security-scan surface <target>
  - Scan a subdirectory:    /repo-security-scan deep <target>/src
```

In **surface mode**:

```
Hard stop: this repository contains N tracked files, which exceeds the surface mode limit of <threshold>.

Options:
  - Scan a subdirectory: /repo-security-scan surface <target>/src
```

**Warn** — print and continue:

```
Warning: N tracked files detected. Scan may take longer and consume significant tokens.
Proceeding with <mode> scan.
```

### Step 0.4 — Remote mode only

a. Check `gh` CLI: run `gh --version`. If not found, stop:

```
gh CLI is required for remote scans. Install it from https://cli.github.com and authenticate with: gh auth login
```

b. Check authentication: run `gh auth status`. If not authenticated, stop:

```
Not authenticated with gh CLI. Run: gh auth login
```

c. Check repo disk size:

```bash
gh repo view <owner>/<repo> --json diskUsage --jq '.diskUsage'
```

Value is in kilobytes. If `diskUsage / 1024 > 150`, stop:

```
Remote repo size check failed: <owner>/<repo> is approximately <N> MB on disk.
Maximum allowed size for cloning is 150 MB.
Consider scanning a specific subdirectory after a manual clone.
```

d. **Confirm before cloning.** Ask via `AskUserQuestion`:

```
About to clone <owner>/<repo> (~<N> MB) into a temporary directory and scan it. Proceed?
```

Options:

1. Yes — clone and scan _(Recommended)_
2. No — cancel

If **No**: stop with `Remote scan cancelled.`

e. Clone into a fresh temp directory under the OS temp location, named `security-scan-<repo>-<unique-suffix>`:

- Unix/macOS (bash):
  ```bash
  TEMP_DIR="${TMPDIR:-/tmp}/security-scan-<repo>-$(date +%s)"
  gh repo clone <owner>/<repo> "$TEMP_DIR"
  ```
- Windows (PowerShell):
  ```powershell
  $TEMP_DIR = Join-Path $env:TEMP "security-scan-<repo>-$([int][double]::Parse((Get-Date -UFormat %s)))"
  gh repo clone <owner>/<repo> $TEMP_DIR
  ```

Set `SCAN_ROOT` to the temp directory.

### Step 0.5 — Stack detection

Check for indicator files in `SCAN_ROOT`:

- `**/*.csproj` or `**/*.sln` → `dotnet`
- `**/package.json` → `node`
- `**/vite.config.*` or `**/vue.config.*` → `vue`
- `**/*.tf` → `terraform`
- `**/requirements.txt` or `**/*.py` → `python`
- `**/Dockerfile` or `**/docker-compose.*` → `docker`

Assemble `STACK_HINT` as a comma-separated string (e.g. `dotnet,vue`).

---

## Phase 1 — Parallel scan

Spawn all three scanner agents in parallel, passing `SCAN_ROOT`, `SCAN_DEPTH`, and `STACK_HINT`:

- `${CLAUDE_PLUGIN_ROOT}/agents/scanner-secrets.md`
- `${CLAUDE_PLUGIN_ROOT}/agents/scanner-injection.md`
- `${CLAUDE_PLUGIN_ROOT}/agents/scanner-exposure.md`

Wait for all three to complete. Collect their structured findings blocks.

---

## Phase 2 — Merge and report

### Step 2.1 — Parse findings

Parse all findings from the three agent outputs using the standard schema (agent, severity, confidence, file, line, title, description, impact, fix).

### Step 2.2 — Deduplicate

Key: `file + line`. If two agents report the same file+line:

- Keep the entry with higher severity.
- Set `agent` to note both sources (e.g. `secrets+exposure`).
- If severities are equal, keep the entry with higher confidence.

### Step 2.3 — Sort

1. Severity: Critical → High → Medium → Low
2. Confidence: high → medium → low

### Step 2.4 — Render report

```markdown
# Security Scan Report

**Target**: <path or owner/repo-name>
**Mode**: Surface / Deep
**Scanned**: <ISO timestamp>
**Agents**: Secrets, Injection, Exposure

---

## Summary

| Severity | Count |
| -------- | ----- |
| Critical | {n}   |
| High     | {n}   |
| Medium   | {n}   |
| Low      | {n}   |

**Total findings**: {n}
**Overall risk**: Critical / High / Medium / Low / Clean

---

## Findings

### Critical

| #   | Agent | File | Line | Title | Description | Confidence | Impact | Fix |
| --- | ----- | ---- | ---- | ----- | ----------- | ---------- | ------ | --- |

### High

_(same table structure)_

### Medium

_(same table structure)_

### Low

_(same table structure)_

---

## Agent Coverage

| Agent     | Patterns Run | Findings | Truncated? |
| --------- | ------------ | -------- | ---------- |
| Secrets   | {n}          | {n}      | Yes / No   |
| Injection | {n}          | {n}      | Yes / No   |
| Exposure  | {n}          | {n}      | Yes / No   |

---

## Notes

- Secret values are redacted (format: `first4***last4` or `[REDACTED]`).
- Confidence: **high** = strong signal with clear context; **medium** = pattern match, context reviewed; **low** = pattern match only, likely requires manual verification.
- This report is diagnostic only. No files were modified.
- **Surface mode**: focused high-risk file set, highest-signal patterns only.
- **Deep mode**: all tracked files, broader pattern set, full-file confirmation reads for secrets and injection hits. DTO/response model scanning uses grep only (confidence: medium).
```

---

## Phase 3 — Cleanup (remote mode only)

Remove the temp clone:

- Unix/macOS (bash): `rm -rf "$TEMP_DIR"`
- Windows (PowerShell): `Remove-Item -Recurse -Force $TEMP_DIR`

Print: `Temp clone removed: <TEMP_DIR>`
