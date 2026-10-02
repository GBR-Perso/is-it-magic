# Azure Authentication

Include this section in any skill that needs `az` CLI access. Run it as the very first step before any other az command.

---

## Step 0 — Resolve home directory

Resolve `HOME_DIR`: `%USERPROFILE%` on Windows (if `USERPROFILE` is set), otherwise `$HOME` on Unix/macOS. Azure env files live under `<HOME_DIR>/.azure/`.

---

## Step 1 — Check current session

```bash
az account show --query "{name:name, tenantId:tenantId, subscriptionId:id, user:user.name}" -o json 2>/dev/null
```

**Success** — print the active context and require explicit confirmation before proceeding:

```
Currently connected to:
  Tenant:       <tenantId>
  Subscription: <name> (<subscriptionId>)
  User:         <user>

Confirm this is the correct tenant before continuing.
```

Use `AskUserQuestion`:
- `Yes — proceed on this tenant` → skip to done — proceed with the current az session
- `No — switch tenant` → continue to Step 2

Do NOT proceed until the user explicitly confirms. Never assume the active session is correct.

**Failure** (not logged in) → continue to Step 2 without prompting.

---

## Step 2 — Select target environment

Determine the env-file prefix from the contexts manifest. Follow the **Context Resolution Contract** in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_context-resolution.md` to resolve the active context for the current working directory, then read its `azure_env_file_prefix` field (see `_contexts-schema.md`).

- If a context resolves and declares `azure_env_file_prefix` → `PREFIX = <that value>`; the env-file glob is `<HOME_DIR>/.azure/<PREFIX>-*.env`.
- If no context resolves, or it has no `azure_env_file_prefix` → fall back to scanning all env files: `<HOME_DIR>/.azure/*.env`.

Discover env files (consider only files that contain `ARM_TENANT_ID` — i.e. tenant env files):

```bash
# with a resolved prefix
ls "<HOME_DIR>/.azure/<PREFIX>-"*.env 2>/dev/null
# fallback (no prefix resolved)
ls "<HOME_DIR>/.azure/"*.env 2>/dev/null
```

- **One file found** — announce it and ask the user to confirm via `AskUserQuestion`:
  ```
  Found environment file: <filename>
  Connect to this tenant?
  ```
  Options: `Yes — connect` / `Cancel`.
- **Multiple files found** — extract a label from each filename (the filename without its `.env` extension, with any `<PREFIX>-` stripped if present), then ask the user which one to use via `AskUserQuestion`. Wait for the answer before continuing.
- **No files found** — stop and tell the user:
  ```
  Not connected to Azure and no environment file found.

  Create <HOME_DIR>/.azure/<label>.env with:

    ARM_SUBSCRIPTION_ID=<Azure_Subscription_ID>
    ARM_TENANT_ID=<Azure_Tenant_ID>

  Where <label> is a short identifier for the tenant (matching your context's
  azure_env_file_prefix if you use one, e.g. "<prefix>-qa"). Then re-run this skill.
  ```

---

## Step 3 — Login

Parse the selected `.env` file:

```bash
ARM_TENANT_ID=$(grep 'ARM_TENANT_ID' "<file>" | cut -d= -f2 | tr -d '[:space:]')
ARM_SUBSCRIPTION_ID=$(grep 'ARM_SUBSCRIPTION_ID' "<file>" | cut -d= -f2 | tr -d '[:space:]')
```

Run interactive login (no secret stored on disk — MFA/browser flow):

```bash
az login --tenant "$ARM_TENANT_ID" --output none 2>&1
az account set --subscription "$ARM_SUBSCRIPTION_ID" 2>&1
```

If either command fails, show the error and stop. Do NOT proceed.

Announce:

```
Connected to:
  Tenant:       <ARM_TENANT_ID>
  Subscription: <ARM_SUBSCRIPTION_ID>
```
