---
name: repo-git-env
description: Manage GitHub environment variables and secrets for a repository from a JSON config file — validates, confirms, and applies directly via gh CLI. Can also scan a project codebase to generate a config, auto-filling as many real values as it can from existing GitHub variables, infrastructure-as-code naming, and read-only cloud lookups, leaving descriptive placeholders only for what it cannot determine.
disable-model-invocation: true
---

Manage GitHub environment variables and secrets for a repository from a JSON config file.

The skill validates the config, verifies the target repo, shows a dry-run summary, asks for explicit confirmation, then applies changes directly via `gh` CLI. No intermediate script is generated — secrets never touch disk.

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## When invoked without arguments

If `$ARGUMENTS` is empty, **run `init` for the current working directory** — do not print usage, do not wait for input. Proceed directly to the **Init mode** section using `.` as the project path.

## Arguments

`$ARGUMENTS`: either:
- _(empty)_ — run `init` for the current working directory (see **Init mode** below)
- `init [project-path]` — scan a project codebase and create `.github/env-config.json` (see **Init mode** below)
- `apply` — auto-detect the current repo and apply `.github/env-config.json` (see **Apply mode** below)

If the first argument is `init`, follow the **Init mode** section.
If the first argument is `apply`, follow the **Apply mode** section.
If arguments are empty, follow the **Init mode** section using `.` as the project path.

## Guardrails

- **Never log secret values** in output — only print key names and masked placeholders (`****`)
- **Never write secrets to disk** — no generated scripts, no temp files
- The JSON config file must exist and be valid JSON
- Reject configs with empty secret values (print which keys are empty and stop)
- For `@file:` references, verify the referenced file exists before proceeding
- Removals must be **explicit** — only delete a variable or secret when its value is `"@remove"` in the config
- **Always verify the target repo via `gh repo view`** before showing the summary — abort if the repo doesn't exist or the user lacks access
- **Never proceed without explicit user confirmation** — the user must type YES after reviewing the summary
- **Cloud lookups during `init` are strictly read-only** — query provider CLIs only to read values; never create, modify, or delete cloud resources
- **Never fabricate values during auto-fill** — fill only what you can determine deterministically (IaC) or read from an authoritative source (existing GitHub vars, cloud); leave a descriptive placeholder for everything else, and never invent secret material

## JSON Config Format

```json
{
  "environments": {
    "qa": {
      "variables": {
        "WEBAPP_NAME": "app-qa",
        "APP_URL": "https://qa.example.com",
        "OLD_SETTING": "@remove"
      },
      "secrets": {
        "APP_CONFIG_JSON": "@file:./secrets/qa/config.json",
        "DEPLOY_TOKEN": "token-qa",
        "LEGACY_KEY": "@remove"
      }
    },
    "prod": {
      "variables": {
        "WEBAPP_NAME": "app-prod",
        "APP_URL": "https://example.com"
      },
      "secrets": {
        "APP_CONFIG_JSON": "@file:./secrets/prod/config.json",
        "DEPLOY_TOKEN": "token-prod"
      }
    }
  }
}
```

- `environments`: keyed by environment name (`qa`, `prod`, etc.), each with `variables` and `secrets`

### File references (`@file:`)

When a value starts with `@file:`, it means "read the secret value from this file path". This is used for secrets whose value is an entire file (e.g. an app config blob, an XML publish profile, a kubeconfig).

- The path is relative to the config file's directory
- The referenced file must exist (validation step)
- In the summary, show as `@file:./path` (never print file contents)
- At apply time, read the file content and pipe it directly to `gh secret set` — never store it in a variable or print it

This avoids having to escape JSON-inside-JSON or large file blobs.

### Removal marker (`@remove`)

When a value is exactly `"@remove"`, the variable or secret will be **deleted** from the environment.

- Works for both `variables` and `secrets`
- In the summary, show removals on dedicated `REMOVE:` lines so they stand out

## Init mode

When the first argument is `init` (or when no arguments are provided), scan a project's codebase to discover which GitHub environment variables and secrets it expects, then write `.github/env-config.json` — auto-filling as many real values as possible (from existing GitHub variables, infrastructure-as-code naming, and read-only cloud lookups) and using descriptive placeholders only for what cannot be determined.

### Init 1. Resolve project path

- If a path is given after `init`, use it. Otherwise use the current working directory.
- Verify the path exists and looks like a project root (has `.github/` or `src/` or a recognised project manifest).
- **If `.github/env-config.json` already exists in the resolved project path, print a message and stop — do not overwrite:**
  ```
  .github/env-config.json already exists. Edit it directly or delete it to re-init.
  ```

### Init 2. Scan the codebase for variable and secret references

Scan these sources in order, collecting variable and secret names per environment:

1. **GitHub workflow files** (`.github/workflows/*.yml`) — *the authoritative, stack-neutral source*:
   - Extract `vars.<NAME>` references → add to `variables`
   - Extract `secrets.<NAME>` references → add to `secrets`
   - Detect environment names from `environment:` fields in jobs (e.g. `qa`, `prod`)
   - Ignore `secrets.GITHUB_TOKEN` (built-in, not user-managed)

2. **Per-environment config-file directories** (file-valued secrets) — generic pattern with a built-in default:
   - Detect a directory that holds one config file per environment, to be uploaded as `@file:` secrets.
   - **Built-in default pattern**: `.github/appsettings-value/<env>/appsettings.json`. When present, list the `<env>` subdirectories as environment names and add an `@file:` secret for each, named after the file (see naming rule below) with value `@file:./secrets/<env>/<filename>`.
   - **General form**: any directory whose immediate subdirectories are environment names, each containing the same config file → map that file as an `@file:` secret per environment.
   - **Secret-name rule**: uppercase the filename and replace each run of non-alphanumeric characters with a single `_` (e.g. `appsettings.json` → `APPSETTINGS_JSON`, `config.yaml` → `CONFIG_YAML`).

3. **Infrastructure-as-code files** (`**/*.tf`):
   - Look for `var.<NAME>` references that are fed from GitHub variables (e.g. variables passed via `-var` in workflow files) and add them to `variables`.

### Init 3. Resolve values — best-effort auto-fill, placeholder fallback

For every discovered variable and secret, try to resolve a **real value** before falling back to a placeholder. Fill only values you can determine deterministically or read from an authoritative source; **never guess secret material and never fabricate a value**. Resolve in this order, per environment:

**a. Already-configured GitHub values.** Query existing values first so a re-init never blanks them:

```bash
gh variable list --repo <owner/repo> --env <env>
gh variable list --repo <owner/repo>            # repo-level
```

Use any existing value verbatim. Secrets cannot be read back (names only), so never try to fill a secret from GitHub.

**b. Infrastructure-as-code (Terraform, Bicep, …) — resource names and URLs.** Read the IaC to learn the project's naming convention and per-environment inputs, then derive resource-name variables deterministically:

- Read the per-environment var files (e.g. `*.tfvars`) for the inputs that drive names — commonly a `project_name` / `env` / `index` triplet.
- Read the resource definitions (e.g. `main.tf`, modules) for the name expressions, e.g. `"<prefix>${project}${component}${env}${index}"`.
- Substitute the per-env inputs into those expressions to produce concrete names (web app, resource group, container registry, container app, storage, static-site project, …) and any URLs built from them (e.g. `https://<webapp>.azurewebsites.net`).

Some IaC inputs are *sourced from* the very GitHub variables you are setting (circular) — resolve those from the cloud in step (c), not from IaC.

**c. Cloud provider (read-only) — identity and connection values.** If the matching cloud CLI is authenticated, read values that only exist post-deploy. **Read only — never create, modify, or delete cloud resources.** Typical Azure examples (adapt to whichever provider the project uses):

- **App-registration client IDs / API scopes**: `az ad app list --filter "startswith(displayName,'<name-prefix>')" --query "[].{name:displayName, appId:appId}"`. The frontend app-reg's `appId` → the SPA client-id variable; the backend app-reg's `appId` combined with the scope value defined in IaC → the API-scope variable (e.g. `api://<backend-appId>/<scope>`).
- **Telemetry / App Insights connection strings**: find the instance (`az resource list --resource-type microsoft.insights/components`) then read `az resource show ... --query properties.ConnectionString`.
- **Deployed app settings** can confirm values: `az webapp config appsettings list ...`.

Match resources to environments by name **and** by tenant/subscription — different environments may live in different tenants or subscriptions (e.g. a sandbox tenant for `qa`, the company tenant for `prod`). Switch context per env (`az account set --subscription ...`) and read each environment from where it actually lives. If an environment's resources aren't found in any accessible context, say so and leave placeholders — do not invent values.

**If a cloud CLI needs interactive sign-in** (Conditional Access → `InteractionRequired`) and the normal browser flow hangs, use **device-code** login (`az login --tenant <id> --use-device-code`): it prints a code the user enters in a browser and does not depend on a localhost redirect. Run it in the background, relay the code to the user, and continue once it completes. Never block on the hanging browser-redirect flow; if a prior attempt is wedged, kill the stuck `az`/`python` login process before retrying.

**d. Placeholder fallback.** For anything not resolved above, assign a placeholder — and make it describe *where the real value comes from* rather than a bare token:

- **Variables**: `"<WEBAPP_NAME>"`, or better `"<from terraform output ... after infra-apply (qa)>"`.
- **File-valued secrets** (source 2, `@file:` pattern): `"@file:./<path>/<filename>"` — prefer pointing at the project's existing per-env config files if they exist, otherwise the default `./secrets/<env>/<filename>`.
- **Other secrets**: `"<SECRET_NAME>"` — never a fabricated value.

**Company-global / inherited values.** If a referenced variable or secret is managed at the **org level** (inherited by every repo) or is otherwise a shared company secret (service-principal credentials, cloud API tokens), do not set it per-repo — omit it from the config and note it in the summary. When unsure whether something is shared, ask the user rather than guessing.

If no environments were detected, default to `qa` and `prod`. If a variable or secret appears in workflows without a specific `environment:` context, include it in **all** detected environments.

### Init 4. Write the config file

Write the generated JSON to `<project-path>/.github/env-config.json`.

Before writing, show the user a preview of the generated JSON and the output path. In the preview, clearly distinguish **auto-filled** values from remaining **placeholders** (e.g. a short `Filled N, placeholder M` line per environment) and state where the filled values came from (existing GitHub / IaC / cloud). Ask for confirmation before writing.

(The file-already-exists check happens in Init 1 — by this step the file is guaranteed not to exist.)

### Init 5. Ensure the file is gitignored

After writing, check whether `.github/env-config.json` is covered by `<project-path>/.gitignore`:

- Read `.gitignore` (if it exists).
- If `.github/env-config.json` (or a pattern that matches it, e.g. `env-config.json` or `.github/`) is **not** already present, append the following line to `.gitignore`:
  ```
  .github/env-config.json
  ```
- Print one of:
  - `.github/env-config.json` already in `.gitignore` — no change needed.
  - Added `.github/env-config.json` to `.gitignore`.

If `.gitignore` does not exist, create it with `.github/env-config.json` as the sole entry.

### Init 6. Print next steps

After writing, print:

```
Config written to <path>/.github/env-config.json

Next steps:
  1. Fill in any remaining placeholder values (search for < and >)
  2. For @file: secrets, place the actual files at the referenced paths
  3. Apply with: /repo-git-env apply
```

If every value was auto-filled, say so and note that only secrets / genuinely post-deploy values remain (if any).

---

## Apply mode

The following steps apply when the skill is invoked with `apply`.

### Apply 1. Auto-detect the repo

Run:
```bash
gh repo view --json nameWithOwner,url
```
from the current working directory (no repo argument — `gh` resolves it from the git remote automatically).

- If the command fails (not a git repo, no remote, no access), print the error and **stop**.
- Extract `nameWithOwner` (e.g. `my-org/my-repo`) and `url` for display.

### Apply 2. Locate the config file

Look for `.github/env-config.json` relative to the current working directory.

- If the file does not exist, print:
  ```
  .github/env-config.json not found. Run /repo-git-env init first.
  ```
  and **stop**.

### Apply 3. Read and validate the config

Read the JSON config file. Validate:

- Valid JSON
- Has `environments` with at least one environment
- No empty string values in `secrets` or `variables` (print which keys are empty and stop)
- All `@file:` references point to files that exist, resolved relative to `.github/` (print which are missing and stop)
- `@remove` values are valid in both `variables` and `secrets` — they mark items for deletion

### Apply 4. Show confirmation gate and ask for approval

Before doing anything, present the full picture to the user — what was auto-detected and what will happen:

```
──────────────────────────────────────
  REPO:   my-org/my-repo
          https://github.com/my-org/my-repo
  CONFIG: .github/env-config.json
──────────────────────────────────────

  [qa]
    SET variables:  WEBAPP_NAME = app-qa, APP_URL = https://qa.example.com
    SET secrets:    APP_CONFIG_JSON = @file:./secrets/qa/config.json
                    DEPLOY_TOKEN = ****
    REMOVE:         OLD_SETTING (variable), LEGACY_KEY (secret)

  [prod]
    SET variables:  WEBAPP_NAME = app-prod, APP_URL = https://example.com
    SET secrets:    APP_CONFIG_JSON = @file:./secrets/prod/config.json
                    DEPLOY_TOKEN = ****

  Total: 4 variables to set, 4 secrets to set, 1 variable to remove, 1 secret to remove
──────────────────────────────────────
```

Then ask:

```
Apply these changes to my-org/my-repo? Type YES to confirm, or anything else to cancel.
```

**Do NOT proceed unless the user responds with exactly `YES`.** Any other response = cancel.

### Apply 5. Apply changes

Execute `gh` commands one by one, printing progress for each:

1. **Create environments** if they don't exist:
   ```
   gh api --method PUT "repos/<owner/repo>/environments/<env-name>"
   ```

2. **Set variables** (non-`@remove`):
   ```
   gh variable set <NAME> --body "<value>" --repo <owner/repo> --env <env>
   ```

3. **Set secrets** with plain values (non-`@file:`, non-`@remove`):
   ```
   gh secret set <NAME> --body "<value>" --repo <owner/repo> --env <env>
   ```

4. **Set secrets** with `@file:` references — read and pipe directly:
   ```bash
   cat "<resolved-path>" | gh secret set <NAME> --repo <owner/repo> --env <env>
   ```

5. **Remove variables** marked `@remove`:
   ```
   gh variable delete <NAME> --repo <owner/repo> --env <env> --yes
   ```

6. **Remove secrets** marked `@remove`:
   ```
   gh secret delete <NAME> --repo <owner/repo> --env <env> --yes
   ```

For each command, print a status line:

```
  [qa] SET variable WEBAPP_NAME ✓
  [qa] SET secret APP_CONFIG_JSON ✓
  [qa] REMOVE variable OLD_SETTING ✓
  ...
```

If any command fails, print the error for that item and **continue with the remaining items** (don't abort the whole batch). At the end, print a final summary:

```
Done. 8 succeeded, 0 failed.
```

If there were failures, list them so the user can retry manually.
