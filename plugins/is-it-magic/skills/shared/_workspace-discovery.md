## Workspace Discovery Contract

A layout-agnostic way to locate repositories from the current working directory, without assuming any
parent-folder naming convention (e.g. `*.Applications`). Discovery keys on a **marker file** that
defines the kind of repo sought — never on folder names.

### D.1 — Inputs

- MARKER — the relative path identifying a target directory:
  - `.claude-plugin/plugin.json` → a plugin repo
  - `.git` → a project (git) repository
- MAX_LEVELS (optional) — ancestor levels to walk up. Default 4.

### D.2 — Walk and scan

1. Start at the current working directory.
2. Walk up through ancestors, up to MAX_LEVELS or the filesystem/drive root (whichever comes first).
3. At each ancestor level, scan child and grandchild directories (depth 1–2) for any containing MARKER.
4. For MARKER `.claude-plugin/plugin.json`, a directory containing `.claude-plugin/marketplace.json` also
   contributes each `plugins/<name>/` beneath it that contains MARKER.
5. Collect every match, deduplicated by absolute path → CANDIDATES.

Depth 1–2 covers both common layouts without hardcoding either:

- Flat workspace (`…/dev/<project>`, sibling repos one level up) → depth 1.
- Scoped workspace (`…/<Scope>.Applications/<project>`, repos under a sibling scope) → depth 2.

### D.3 — Output

Return CANDIDATES as absolute paths, each labelled by its directory name. The calling skill decides
what to do with them (enumerate as choices, score against a name, filter to siblings) — this contract
only **locates**; it does not select.

### D.4 — Empty result

If CANDIDATES is empty, the caller surfaces a clear error naming the MARKER searched and the levels
walked — never silently proceed.
