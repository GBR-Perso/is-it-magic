## Contexts Manifest — Schema Reference

This document is the **source of truth** for the `contexts.json` manifest format. All skills and shared docs in this plugin ecosystem that reference the manifest must conform to this schema.

---

### Manifest Location

| Platform | Path |
|----------|------|
| Windows  | `%USERPROFILE%\.claude\contexts.json` |
| Unix / macOS | `$HOME/.claude/contexts.json` |

The file belongs to the user and is not managed by any plugin. Skills may offer to write to it via explicit opt-in (`AskUserQuestion`) but never silently.

---

### Top-Level Shape

```json
{
  "contexts": [
    { ... },
    { ... }
  ]
}
```

The `contexts` array is ordered. The first entry whose `path_globs` matches the current working directory wins (first-match semantics — see Resolution Rules below).

---

### Context Entry Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | **Yes** | Short identifier (e.g. `work-qa`, `personal`, `client-ado`). Used in skill prompts and as the explicit context argument. |
| `path_globs` | string[] | **Yes** | One or more glob patterns matched against the current working directory. First-match wins across all contexts. |
| `github_org` | string | No | GitHub organisation slug (e.g. `MyOrg`). Mutually exclusive with `github_user`. |
| `github_user` | string | No | GitHub personal account slug (e.g. `my-personal-handle`). Mutually exclusive with `github_org`. |
| `ssh_alias` | string | No | SSH host alias declared in `~/.ssh/config` (e.g. `github-work`, `github-personal`). Used to compose SSH clone URLs and verify push remotes. |
| `commit_email` | string | No | Git commit email for this context. Skills may verify it matches `git config user.email` via an `includeIf` block. |
| `azure_tenant_id` | string | No | Azure / Entra tenant GUID for this context. |
| `azure_subscriptions` | object | No | Map of environment name → Azure subscription GUID (e.g. `{ "qa": "<guid>", "prod": "<guid>" }`). |
| `azure_env_file_prefix` | string | No | Prefix for local Azure env files (e.g. `myorg-env`). Used by Terraform auth skills. |
| `ado_org_url` | string | No | Azure DevOps organisation URL (e.g. `https://dev.azure.com/MyAdoOrg`). Presence (combined with absence of `github_org`/`github_user`) signals ADO-backed context. |
| `app_template_path` | string | No | Absolute path to the local clone of the application template repo (e.g. `C:/Workspace/Dev/work/my-app-template`). |

Fields not listed here are silently ignored by skills. The manifest is user-extensible.

---

### Resolution Rules

1. **`github_org` and `github_user` are mutually exclusive.** A context must declare at most one. Declaring both is a schema error — skills must report it and fall back to inline ask.
2. **ADO-backed context**: a context that declares `ado_org_url` and does **not** declare `github_org` or `github_user` is treated as Azure DevOps–backed. Skills use `ado_org_url` for repository discovery and clone URLs.
3. **First-match path_globs wins**: the `contexts` array is evaluated in order. The first context whose `path_globs` array contains a pattern matching the cwd is the resolved context. No further entries are evaluated.

---

### Glob Matching Semantics

- `**` matches any number of path segments recursively (e.g. `C:/Workspace/Dev/work/**` matches any subdirectory of `work`).
- `*` matches any sequence of characters within a single path segment.
- Matching is **case-insensitive on Windows** and case-sensitive on Unix/macOS.
- Patterns are matched against the **full absolute path** of the current working directory.

**Examples:**

| Pattern | Matches |
|---------|---------|
| `C:/Workspace/Dev/work/**` | Any directory under `work\` |
| `C:/Workspace/Dev/personal/**` | Any directory under `personal\` |
| `/home/user/dev/work/**` | Any directory under `~/dev/work/` (Unix) |
| `C:/Workspace/Dev/work/svc-*` | Only immediate children starting with `svc-` |

---

### Multi-Tenant Note

If your organisation's environments span multiple Azure tenants, declare **one context entry per tenant** rather than one per organisation. For example, if QA runs in one tenant and production in another:

```json
{ "name": "work-qa",   "azure_tenant_id": "<qa-tenant-guid>",   "azure_subscriptions": { "qa": "<qa-subscription-guid>" } }
{ "name": "work-prod", "azure_tenant_id": "<prod-tenant-guid>", "azure_subscriptions": { "prod": "<prod-subscription-guid>" } }
```

Each context's `azure_subscriptions` map contains only the subscriptions within that tenant. Skills that need to target a specific environment must resolve the correct context first.

---

### Example Manifest

```json
{
  "contexts": [
    {
      "name": "work-qa",
      "path_globs": ["C:/Workspace/Dev/work/**"],
      "github_org": "MyOrg",
      "ssh_alias": "github-work",
      "commit_email": "you@company.example",
      "azure_tenant_id": "<qa-tenant-guid>",
      "azure_subscriptions": {
        "qa": "<qa-subscription-guid>"
      },
      "azure_env_file_prefix": "myorg-env",
      "app_template_path": "C:/Workspace/Dev/work/my-app-template"
    },
    {
      "name": "work-prod",
      "path_globs": ["C:/Workspace/Dev/work/**"],
      "github_org": "MyOrg",
      "ssh_alias": "github-work",
      "commit_email": "you@company.example",
      "azure_tenant_id": "<prod-tenant-guid>",
      "azure_subscriptions": {
        "prod": "<prod-subscription-guid>"
      },
      "azure_env_file_prefix": "myorg-env",
      "app_template_path": "C:/Workspace/Dev/work/my-app-template"
    },
    {
      "name": "personal",
      "path_globs": ["C:/Workspace/Dev/personal/**"],
      "github_user": "my-personal-handle",
      "ssh_alias": "github-personal",
      "commit_email": "me@personal.example"
    },
    {
      "name": "client-ado",
      "path_globs": ["C:/Workspace/Dev/client/**"],
      "ado_org_url": "https://dev.azure.com/MyAdoOrg",
      "commit_email": "you@client.example"
    }
  ]
}
```

> **Note on `work-qa` / `work-prod`**: both entries share the same `path_globs`. The first match (`work-qa`) is returned when the skill does a cwd-based lookup. Skills that need to target production must receive an explicit context argument or ask the user to disambiguate.
