---
paths:
  - "**/infra/*.tf"
  - "**/infra/*.tfvars"
  - "**/infra/**/*.tf"
  - "**/infra/**/*.tfvars"
---

# Azure Resource Naming Convention

**This is mandatory.** Every Azure resource name, and every Cloudflare Pages project name, MUST follow this convention. No exceptions.

## Format

```
rise<project><purpose><resourceType><environment><index>
```

All names are **lowercase**, no hyphens, no underscores. Example: `risesharergprod01`.

## Components

| Component      | Rule                                                                                         |
| -------------- | -------------------------------------------------------------------------------------------- |
| `rise`         | Fixed prefix for every resource                                                              |
| `project`      | The app or product. At most 12 characters. Shared services use `share`                       |
| `purpose`      | Optional, from the purpose codes below. `project` + `purpose` together: at most 12 characters |
| `resourceType` | Microsoft's abbreviation for the resource type (see below)                                   |
| `environment`  | `dev`, `qa` or `prod`                                                                        |
| `index`        | Two digits: `01`, `02`                                                                       |

The 12-character cap keeps the tightest Azure names inside their limit: a storage account or a Key Vault allows 24 characters.

### Purpose codes

| Code                       | Meaning                                                                                        |
| -------------------------- | ---------------------------------------------------------------------------------------------- |
| `be`                       | Backend                                                                                        |
| `fe`                       | Frontend                                                                                       |
| `mcp`                      | MCP server                                                                                     |
| `sc`                       | Service client: a standalone identity that is its own security principal                       |
| `free`                     | A Free App Service plan                                                                        |
| `sub`, `svc`, `bl`, `rg`   | What a cost view groups spend by: subscription, service, business line, resource group         |

An App Service always has a purpose: `be` or `mcp`. Omit `purpose` elsewhere when it adds nothing.

### When `project` + `purpose` is over 12 characters

Shorten the product name. Never drop the purpose. Example: `datagateway` + a domain becomes `dg` + domain (`dggeo`, `dgfx`). An abbreviation needs sign-off from the naming-convention owner.

## Resource type codes

**Microsoft's [abbreviation list](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations) is the table.** Read the code there, every time. The common ones:

| Resource                         | Code    |
| -------------------------------- | ------- |
| Resource group                   | `rg`    |
| App Service (web app)            | `app`   |
| App Service plan                 | `asp`   |
| Function app                     | `func`  |
| Static web app, or Cloudflare Pages project | `stapp` |
| Logic app                        | `logic` |
| Azure SQL server                 | `sql`   |
| Azure SQL database               | `sqldb` |
| Storage account                  | `st`    |
| Key Vault                        | `kv`    |
| Container registry               | `cr`    |
| User-assigned managed identity   | `id`    |
| Application Insights             | `appi`  |
| Log Analytics workspace          | `log`   |
| Container Apps environment       | `cae`   |
| Container app                    | `ca`    |

Codes Microsoft's list does not have:

| Resource                                                  | Code   |
| --------------------------------------------------------- | ------ |
| Entra app registration                                    | `ar`   |
| Budget (`Microsoft.Consumption/budgets`)                  | `bud`  |
| Cost anomaly alert (`Microsoft.CostManagement/scheduledActions`) | `anom` |
| Cost analysis saved view (`Microsoft.CostManagement/views`)     | `cv`   |
| Log search alert rule (`Microsoft.Insights/scheduledQueryRules`) | `sqr`  |

Examples: `riseairfarebeappprod01` (an API), `riseairfaremcpappprod01` (its MCP), `risesharefreeaspprod01` (a shared Free plan), `risesandboxfearprod01` (a frontend app registration).

**A name is never changed only to follow the rule.** Most Azure resources cannot be renamed. An older code (`api`, `sp`, `caenv`, `fa`, `app` for a Static Web App or a Pages project) goes when its resource is recreated for another reason.

## Names inside a resource

Something that exists only inside one resource (a firewall rule, a blob container, a Key Vault secret) is named by its purpose alone, in lowercase kebab-case: `terraform-state`. Its parent's name already carries prefix, project and environment.

A Key Vault secret is `<service>-<credential>`: `service` is the external system in one word, `credential` one of `api-key`, `client-id`, `client-secret`, `username`, `password`, `connection-string`, `token`, `signing-key`. Example: `countrystatecity-api-key`. The name never carries an app's setting name.

## When Microsoft has no code

**Stop and tell the user.** Do not invent a code. Ask for one to be defined: 2 to 6 characters, unique, obvious.
