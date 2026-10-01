# is-it-magic — Claude Code Plugin

General-purpose Claude Code plugin providing an AI-assisted development workflow — orchestration skills, specialised agents, project bootstrapping, and language rules.

## What's included

| Component  | Count | Items                                                                                                                                                                                                                                                                                                                              |
| ---------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Skills** | 20    | `devbox-init`, `project-investigate`, `project-decide`, `project-requirements`, `project-implement`, `project-port`, `project-upgrade-npm-safe`, `project-upgrade-nuget`, `apply-conventions`, `repo-commit`, `repo-commit-and-deploy`, `repo-git-env`, `repo-git-trigger-workflow`, `repo-security-scan`, `plugin-commit`, `devbox-scan-secrets`, `devbox-set-context`, `az-query`, `dumb-down`, `session-to-skill` |
| **Agents** | 14    | `architect`, `developer`, `test-writer`, `reviewer-quality`, `reviewer-design`, `reviewer-perf`, `codebase-explorer`, `repo-archaeologist`, `project-locator`, `azure-investigator`, `scanner-secrets`, `scanner-injection`, `scanner-exposure`, `scanner-devbox`                            |
| **Rules**  | 6     | `general`, `csharp-lang`, `typescript-lang`, `infra-lang`, `infra-naming`, `python-lang` — synced to `~/.claude/rules/` by `/devbox-init`                                                                                                                                                                                                     |

---

## Installation

### Prerequisites

- [Claude Code](https://code.claude.com) installed

### Step 1 — Register the marketplace

Add the following to your **user-level** settings file at `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "ekla-internal": {
      "source": {
        "source": "settings",
        "name": "ekla-internal",
        "owner": {
          "name": "Ekla"
        },
        "plugins": [
          {
            "name": "is-it-magic",
            "source": {
              "source": "url",
              "url": "https://github.com/GBR-Perso-1/is-it-magic.git"
            },
            "description": "AI-assisted development workflow — agents, skills, project init, and language rules."
          }
        ]
      }
    }
  }
}
```

### Step 2 — Install the plugin

```powershell
claude plugin install is-it-magic@ekla-internal --scope user
```

### Step 3 — Reload plugins

```
/reload-plugins
```

### Step 4 — Initialise this machine

Run once after install (and again after any plugin update to pick up refreshed rules):

```
/devbox-init
```

This syncs all bundled plugin rules into `~/.claude/rules/` so they load globally in every Claude Code session, and ensures the favoured language LSP plugins are present in `~/.claude/settings.json`.

---

## Skills

### Project workflow

| Skill                   | Purpose                                                                                                                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/devbox-init`          | Set up this machine for the is-it-magic plugin — sync all plugin rules into `~/.claude/rules/` and enable favoured language LSPs in user settings. Idempotent; re-run to refresh. |
| `/project-investigate`  | Investigate a codebase or system — bug hunt, analytical question, or full repository archaeology. Always read-only.                                                             |
| `/project-decide`       | Decision layer between investigation and implementation. Infers debt trajectory, generates 2–4 solution options with pros/cons and effort, and commits to a recommendation. Read-only. |
| `/project-requirements` | Produce a formal, versioned requirements document for app evolution — never proposes implementation details.                                                                   |
| `/project-implement`    | Implement a requirement. `full` (default): architect → dev → test → review. `draft`: architect + dev only. `quick`: dev only. Never commits.                                   |
| `/project-port`         | Port files or a feature between sibling projects under the same parent directory — merges or copies intelligently. Never stages or commits.                                     |
| `/apply-conventions`    | Inject generic convention bundles (clean architecture, Vue app, …) into this project — copies them into `.claude/` and links them via `@import` in `CLAUDE.md` as guidance. Idempotent. |

### Repository operations

| Skill                       | Purpose                                                                                                                  |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `/repo-commit`              | Run the test suite, then stage, commit, and push to the current branch with a conventional-commit message. Tests gate the push. Pushes automatically on direct invocation; gates when invoked programmatically. |
| `/repo-commit-and-deploy`   | Chain commit-and-push with a workflow trigger — commit, push, then fire the named deploy workflow(s). Gate-free on direct, fully-specified invocation (even prod); keeps all safety gates. |
| `/repo-git-env`             | Manage GitHub environment variables and secrets from a JSON config — validates, confirms, and applies via `gh`.          |
| `/repo-git-trigger-workflow`| Trigger GitHub Actions workflows via `workflow_dispatch`. Resolves shortnames (app, api, mcp, infra, all), gated by confirmation. |
| `/repo-security-scan`       | Scan a repo for secrets, injection vulnerabilities, and exposure risks via three parallel scanner agents. Read-only report. |
| `/project-upgrade-npm-safe` | Upgrade a JS/TS project's npm dependencies to the latest stable with controlled risk — optionally align Node to Active LTS, bump safe minors and low-risk tooling majors, verify with the project's gates. Never commits. |
| `/project-upgrade-nuget`    | Upgrade a .NET API's NuGet packages to their latest versions and verify with build + tests, holding back majors known-incompatible with the current framework. |

### Plugin development

| Skill                | Purpose                                                                                              |
| -------------------- | ---------------------------------------------------------------------------------------------------- |
| `/plugin-commit`     | Bump the plugin version based on the changes, commit with a meaningful message, and push to main.    |

### Dev machine & context

| Skill                  | Purpose                                                                                                              |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `/devbox-scan-secrets` | Audit the local dev machine for exposed secrets — writes a CSV report to `.claude/secret-audit-<date>.csv`.         |
| `/devbox-set-context`  | Manage the user-level `contexts.json` manifest describing your GitHub/Azure accounts.                               |
| `/az-query`            | Read-only Azure lookups (app registrations, groups, Key Vault, resources) using natural language.                  |

### Explanation

| Skill               | Purpose                                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `/dumb-down`        | Re-explain something that did not land — re-derived from the source, answer first, one worked example.                   |

### Meta

| Skill               | Purpose                                                                                                  |
| ------------------- | -------------------------------------------------------------------------------------------------------- |
| `/session-to-skill` | Retroactively distil a completed piece of session work into a reusable `fix-` or `migrate-` skill.       |

---

## Agents

Agents are spawned by skills (and can be invoked directly). Grouped by role:

| Group                     | Agents                                                                       |
| ------------------------- | ---------------------------------------------------------------------------- |
| **Implementation pipeline** | `architect`, `developer`, `test-writer`, `reviewer-quality`, `reviewer-design`, `reviewer-perf` |
| **Investigation**         | `codebase-explorer`, `repo-archaeologist`, `project-locator`, `azure-investigator` |
| **Security scanners**     | `scanner-secrets`, `scanner-injection`, `scanner-exposure`, `scanner-devbox` |

---

## Updating the plugin

```powershell
claude plugin update is-it-magic@ekla-internal
```

---

## Local development

```powershell
claude --plugin-dir "C:/Workspace/Dev/Perso.Applications/is-it-magic"
```
