---
name: project-upgrade-npm-safe
description: >
  Upgrade a JavaScript/TypeScript project's npm dependencies to their latest
  stable versions with controlled risk — optionally align the Node runtime to
  the latest Active LTS first, then bump safe minor/patch and low-risk tooling
  majors while deliberately excluding breaking majors, verify with the project's
  own gates, and clean up audit vulnerabilities. Never commits.
---

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Context

Use this when a user asks to "upgrade the packages to the latest stable version"
without wanting a risky big-bang migration. It optionally aligns the Node runtime
to the latest Active LTS, separates cheap safe updates from breaking major upgrades,
lets the user choose how far to go, proves the result with the project's existing
verification scripts, and then reduces the `npm audit` surface without pulling in the
excluded majors.

## Prerequisites

- A Node/npm project with a `package.json` and a lockfile.
- The project defines verification scripts (some subset of type-check, lint, test, build).
- `npm` available; network access to the registry.
- For the optional runtime-alignment step: a Node version manager (e.g. `nvm`).

## Placeholders

Before running this skill, substitute all `{{PLACEHOLDER}}` tokens:

| Placeholder | Description |
|---|---|
| {{APP_DIR}} | Directory holding the target `package.json` (e.g. the repo root, or a `app/` / `frontend/` subfolder in a monorepo). |
| {{VERIFY_COMMANDS}} | The project's own verification scripts to run after upgrading, in order — e.g. `npm run type-check`, `npm run lint`, `npm run test`, `npm run build`. Discover them from the `scripts` block; run whichever exist. |

## Steps

1. **Survey.** From `{{APP_DIR}}`, run `npm outdated`. Read `package.json` to see the declared ranges and the `engines`/Node constraint. Note the installed Node version (`node --version`) — some majors raise the minimum. Also determine the **latest Active-LTS Node** (e.g. `nvm list available`, or the Node release schedule — the highest even-numbered major currently in *Active LTS* status, **not** the newer "Current" line) and note whether the project's pinned/`engines` Node lags it.

2. **Runtime alignment (optional — confirm with the user first).** Every other step treats the installed Node as a fixed constraint; this is the one place you decide whether to move it. If the project lags the latest Active LTS (or is on an end-of-life line), ask the user via `AskUserQuestion` whether to align the runtime. If yes:
   - Prefer the **Active LTS** line over the newer **"Current"** line for a shared or template project — a Current release only becomes LTS ~6 months after launch, so adopt it early **only** on explicit request. State the LTS-vs-Current trade-off so the choice is informed.
   - Install it (`nvm install <version>`), then update **every** place Node is pinned, together: `engines` in `package.json`, `.nvmrc`, each CI workflow's `node-version`, and any README/docs prerequisite.
   - Align `@types/node` to the **new runtime major** (see step 5) — never ahead of it.
   - Re-run the full verification (step 9) on the new runtime before proceeding.
   - **Caveat (state this to the user):** a Node bump does **not** unblock JavaScript-package majors gated by peer ranges — e.g. a test framework's next major held back by a plugin's peer ceiling, which in turn caps the build tool. Those ceilings are peer-dependency constraints independent of the runtime; a runtime upgrade will not free them. Don't conflate "latest Node" with "latest packages".

3. **Classify every outdated package into three buckets:**
   - **Safe** — new version is within the current major (minor/patch). Low risk.
   - **Low-risk major** — tooling that upgrades cleanly in practice: linters and their plugins, formatters, DOM test environments, dev CLIs, tsconfig presets.
   - **High-risk major** — the load-bearing toolchain: the build tool (e.g. Vite), the test framework (e.g. Vitest), the state library, the router, the language compiler (TypeScript) and its type-checker, and **anything touching authentication**. These carry migration work.

4. **Confirm scope with the user** via `AskUserQuestion` (single question, recommended option first): safe-only / safe + low-risk majors / everything / everything including auth. Auth-related majors are guardrailed — never include them without explicit opt-in. Let the answer define the target set.

5. **Vet each in-scope major BEFORE editing** — do not trust "latest" blindly:
   - `npm view <pkg>@<targetMajor> peerDependencies engines` for each.
   - **Exclude** any major whose peer requires an *excluded* major (classic trap: a build-tool plugin's new major requires the next build-tool major you chose to skip — keep the plugin on its current major). Coupling is transitive: if the test framework's held major caps the build tool, the build tool is held too, even if its own plugins would allow the bump.
   - **Exclude** any major that drags in unwanted peers (e.g. framework-specific peers irrelevant to this project) when the package is low value.
   - Confirm the installed Node satisfies each `engines` field.
   - **`@types/node` tracks the runtime major, never "latest".** Pin it to `^<running Node major>` (the major aligned in step 2, if you ran it). Types ahead of the runtime type-check your code against APIs that don't exist at runtime — a false-green; types behind the runtime is a real lag worth fixing.
   - Check any consuming config file (e.g. the ESLint flat config) for API the new major removes.

6. **Edit `package.json`** — set the in-scope packages to `^<latest-allowed>`; leave every excluded/coupling-locked package pinned at its current major. Keep peer-coupled pairs consistent (e.g. a testing helper pinned to match its host library's major).

7. **Install.** Run `npm install`. If it fails with `ERESOLVE` caused by a stale lockfile/tree, do a **clean reinstall**: delete `node_modules` and the lockfile, then `npm install` again. Missing peer deps are auto-installed by npm; note any deprecation warnings but don't chase transitive ones yet.

8. **Repair breaking config from tooling majors.** When a linter/formatter major tightens a rule's defaults and flags pre-existing code, prefer restoring prior behavior via a rule option over refactoring source — a dependency upgrade should not silently trigger a rename/refactor that ripples into imports or routing. (Example seen: `unicorn/filename-case` gained `checkDirectories: true` by default; set it to `false` to preserve behavior.)

9. **Verify.** Run `{{VERIFY_COMMANDS}}` in order, on the target runtime (the newly-aligned Node if step 2 ran). All must pass. Treat expected `console.error` output from failure-path tests as noise — confirm the suite summary is green, not the absence of red text.

10. **Audit — triage.** Run `npm audit`. Group findings into **chains** by their root vulnerable package. For each chain determine: is the culprit a *direct* dependency, a *transitive* one, and is it actually used (grep the codebase/scripts/config for real references)?

11. **Audit — fix the safe wins:**
    - **Unused direct dependency** in the chain → remove it from `package.json` (verify it's referenced nowhere but its own manifest line first).
    - **Vulnerable transitive dep whose top-level copy is already patched** → add an `overrides` entry scoped to the consuming package, forcing the patched version (use `"<dep>": "$<dep>"` to reuse the root-resolved version).
    - **Chain only fixable by an excluded major** → defer it; record it explicitly with severity and why (e.g. dev-server-only, needs the excluded build-tool major).

12. **Re-audit and re-verify.** Reinstall, run `npm audit`. When npm's human summary severity looks inflated, get ground truth with `npm audit --json` (inspect the actual vulnerable package list) — npm reports the *effective* severity a package participates in, which can overstate counts. Re-run the test suite to confirm any `overrides` didn't break anything.

13. **Report, don't commit.** Present a version table (declared vs installed), any runtime-alignment changes, the config changes made, and a **held-back register**: each excluded major and deferred vulnerability with its rationale and the trigger that would unblock it (e.g. "vitest 4 — waiting on the test-runner plugin's vitest-4 peer support; unblocks vite 8 too"). Leave the working tree uncommitted for the user to review unless they explicitly ask to commit.

## Verification

- `npm outdated` shows only the intentionally-excluded majors remaining (`Current == Wanted` for everything else).
- All `{{VERIFY_COMMANDS}}` pass.
- If the runtime was aligned: `node --version` matches the newly-pinned version, `engines` / `.nvmrc` / CI `node-version` / README all agree, and the `@types/node` major equals the runtime major.
- `npm audit` (cross-checked with `--json`) shows only the deferred chains, each traceable to an excluded major.
