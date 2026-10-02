---
name: plugin-commit
description: "Intelligently bump the plugin version based on changes, commit with a meaningful message, and push to main."
---

## Important rules

Read and follow the rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

Analyse the changes in this plugin repo, determine the correct semantic version bump, commit, and push to main.

## Arguments

`$ARGUMENTS` is optional. If provided, treat it as the absolute path to the plugin repo root (e.g. `/path/to/your-plugin`). If absent, use the current working directory as the repo root.

Store the resolved path as REPO_ROOT.

Resolve PLUGIN_ROOT: REPO_ROOT if `<REPO_ROOT>/.claude-plugin/plugin.json` exists; otherwise the `<REPO_ROOT>/plugins/<name>/` folder holding a `.claude-plugin/plugin.json` whose files appear in the diff. If several plugins changed, ask which one to release — one release per run.

## Steps

### Phase 1 — Execute

#### 1. Gather context

Resolve REPO_ROOT from `$ARGUMENTS` (if provided) or CWD.

Run these in parallel, using `git -C "<REPO_ROOT>"` for all git commands:

```bash
git -C "<REPO_ROOT>" diff HEAD --stat
git -C "<REPO_ROOT>" status --short
git -C "<REPO_ROOT>" log --oneline -5
```

Read `<PLUGIN_ROOT>/.claude-plugin/plugin.json` to get the current version.

#### 2. Ask for the commit message

Use `AskUserQuestion` to ask:

> "What changed? (used as the commit message)"

Free-text input. This is the human summary of the work done.

#### 3. Determine the version bump

Analyse the diff stat + commit message together. Apply this logic:

| Bump | When |
|---|---|
| **major** | A skill or agent was **renamed or removed** (breaking change for consumers). Triggered by: deleted `SKILL.md`, renamed directory, removed agent file. |
| **minor** | A **new skill, agent, or rule** was added. Triggered by: new `SKILL.md`, new agent file, new rule file. |
| **patch** | **Fixes or improvements** to existing skills/agents/rules. Triggered by: edits to existing files only, no additions or deletions of skill entry points. |

If the commit message contains words like `breaking`, `remove`, `rename` → lean major.
If it contains `add`, `new`, `introduce` → lean minor.
If it contains `fix`, `update`, `improve`, `tweak`, `refactor`, `docs` → lean patch.

Compute the new version from the current one (e.g. `1.2.0`):
- major → `2.0.0`
- minor → `1.3.0`
- patch → `1.2.1`

#### 4. Confirm with the user

Use `AskUserQuestion` to present:

> "Proposed bump: **{bump_type}** → `{old_version}` → `{new_version}`
> Reason: {one sentence explaining why this bump type was chosen}"

Options:
- "Looks right — commit and push (Recommended)"
- "Patch instead"
- "Minor instead"
- "Major instead"

If the user picks an override, recompute the new version accordingly.

#### 5. Update the plugin manifest version

Edit in place:
- `<PLUGIN_ROOT>/.claude-plugin/plugin.json` — `version` field

#### 6. Commit

Stage only the plugin's own content directories — never `git add -A` or `git add .`, which would sweep in unrelated untracked files (scratch workspaces, local notes) that happen to sit in the repo.

Not every plugin has every directory. Git aborts the **entire** `add` with `fatal: pathspec '<dir>' did not match any files` if even one pathspec is unmatched, staging nothing, so build the list from what actually exists:

```bash
cd "<PLUGIN_ROOT>"
PLUGIN_PATHS=""
for d in .claude-plugin skills agents rules conventions scripts templates hooks commands README.md; do
  if [ -e "$d" ]; then PLUGIN_PATHS="$PLUGIN_PATHS $d"; fi
done
[ -n "$PLUGIN_PATHS" ] || { echo "No plugin content directories found in $PWD — stop and report."; exit 1; }
git add -- $PLUGIN_PATHS
```

When PLUGIN_ROOT is not REPO_ROOT, also stage `<REPO_ROOT>/.claude-plugin/marketplace.json` and `<REPO_ROOT>/README.md` if they changed.

Use the `if ... then ... fi` form inside the loop, **not** `[ -d "$d" ] && PLUGIN_PATHS=...`. A `for` loop exits with the status of its last command, so with the `&&` form a final directory that does not exist (`commands` is usually absent) makes the whole loop return non-zero. Chained as `probe && git add ...`, the `add` is then silently skipped and the commit stages nothing. The `if` form always exits `0`.

The `-n` guard exists because `git add --` with no pathspec is a silent no-op that exits `0`, which would otherwise produce an empty commit rather than an error.

The list cannot be exhaustive — plugins name their content directories differently (`conventions/` in one, `rise-conventions/` in another), and a directory holding real plugin content but missing from the list fails the same silent way: the commit succeeds carrying only the version bump, while the change it was meant to ship stays behind in the working tree. Add the missing directory when you meet one, and rely on the completeness check below to catch it.

Confirm the staged set before committing — in **both** directions:

```bash
git -C "<REPO_ROOT>" diff --cached --name-only   # what will be committed
git -C "<REPO_ROOT>" diff --name-only            # tracked, modified, NOT staged
```

The first catches unexpected additions. The second is the completeness check and matters more: any file it lists is a tracked change the pathspecs missed. Stop and report rather than committing — for each entry decide whether it belongs to this release (its directory is missing from `PLUGIN_PATHS` — add it) or is unrelated in-flight work that should stay out. Never commit past a non-empty second list without accounting for every line.

```bash
git -C "<REPO_ROOT>" commit -m "<user commit message>

chore: bump version to <new-version>"
```

#### 7. Push

```bash
git -C "<REPO_ROOT>" push origin main
```

#### 8. Summary

Output:

```
Released: <new-version>  (<bump-type> bump)
Commit:   <commit message>
Pushed to: main

To update in consumer projects:
  claude plugin update <plugin-name>
```
