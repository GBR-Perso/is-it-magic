---
name: repo-git-trigger-workflow
description: Trigger one or more GitHub Actions workflows via workflow_dispatch on a target repo. Resolves workflow shortnames by matching against the repo's discovered workflows and auto-detects required inputs. Fires immediately when the user invokes it directly with scope and all required inputs (including environment) fully specified — even for prod; otherwise gates firing behind explicit confirmation.
---

Trigger GitHub Actions workflows via `workflow_dispatch` on the current repo or a sibling project in the same org.

The skill resolves the target repo, looks up which workflows match the user's shortlist, discovers each workflow's required inputs, asks for any missing values, shows a confirmation gate, then fires all selected workflows in parallel and reports the queued run URLs.

## Arguments

`$ARGUMENTS` is **optional**. Free-text describing which workflows to trigger and on which project.

**Examples:**

- `/repo-git-trigger-workflow` → ask interactively
- `/repo-git-trigger-workflow app` → trigger the workflow matching "app" on the current repo
- `/repo-git-trigger-workflow app api mcp` → trigger workflows matching "app", "api", and "mcp" on the current repo
- `/repo-git-trigger-workflow all` → trigger every workflow_dispatch-enabled workflow on the current repo
- `/repo-git-trigger-workflow app on my-service` → trigger the "app" workflow on the repo matching "my-service"
- `/repo-git-trigger-workflow api mcp on my-service prod` → trigger the "api" and "mcp" workflows on my-service with `environment=prod`

## Important rules

Read and follow all rules in `${CLAUDE_PLUGIN_ROOT}/skills/shared/_ux-rules.md`.

## Guardrails

- **The confirmation gate is conditional** (see step 6). Fire *without* it only on a **direct, fully-specified user invocation** — the user personally typed `/repo-git-trigger-workflow` with the scope (workflow tokens) and every required input (including `environment`) supplied in the arguments. In **every** other case — programmatic invocation (Claude via the Skill tool, another skill/workflow, or an agent), or any value that was defaulted, asked, or interactively resolved — an explicit confirmation gate is **mandatory**, even for `qa`. When the source is unclear, treat it as programmatic and ask.
- The **plan/apply sequential gate** (step 6) is a safety mechanism and **always** applies — never auto-chain `plan` → `apply` without reviewing plan output, regardless of how the skill was invoked.
- **Never** assume input values (especially `environment`) — read them from the user's arguments, or ask.
- **Always** verify the target repo exists (`gh repo view`) before firing.
- **Never** trigger on a branch other than the default branch unless the user explicitly named one.
- If a workflow is gated by `if: github.ref == 'refs/heads/main'` (or similar), confirm the ref matches before firing — otherwise the run will queue then no-op.

## Process

### 1. Parse arguments

Extract from `$ARGUMENTS`:

- **Workflow tokens** — one or more free tokens (e.g. `app`, `api`, `infra`), each matched as a case-insensitive substring against the workflows discovered on the target repo (step 3), plus the literal `all` (every `workflow_dispatch` workflow). No fixed shortname list is assumed — tokens resolve against whatever the repo actually has.
- **Project hint** — text after `on`, `for`, or `in` (e.g. `on my-service`). If absent, target the current repo.
- **Environment / inputs** — bare tokens like `prod`, `qa`, `staging` are treated as candidate `environment` input values. Anything in `key=value` form is a direct input override.
- **Branch** — text after `from` or `on branch` (e.g. `from main`, `on branch release/v2`). Defaults to the repo's default branch.

If no workflow tokens were given, ask via `AskUserQuestion` after step 2 (once the available workflows are known).

### 2. Resolve target repo

**If a project hint was given:**

1. Detect the current GitHub org from `gh repo view --json owner -q .owner.login` (current repo's owner).
2. List repos in that org:
   ```
   gh repo list <org> --limit 200 --json name,nameWithOwner
   ```
3. Filter by case-insensitive substring match against the project hint. The hint may be a partial name (e.g. `ops` matches `my-ops-service`).
4. If exactly one match → use it.
5. If multiple matches → ask the user to pick via `AskUserQuestion`, listing each candidate with its full `nameWithOwner`.
6. If zero matches → print the hint, list the closest 5 names, and **stop**.

**If no project hint was given:**

Run `gh repo view --json nameWithOwner,defaultBranchRef -q '{repo: .nameWithOwner, branch: .defaultBranchRef.name}'`. If it fails (not in a git repo with a GitHub remote), print the error and **stop**.

Store as `TARGET_REPO` (e.g. `myorg/my-service`) and `DEFAULT_BRANCH` (e.g. `main`). If a branch was named in the arguments, it overrides `DEFAULT_BRANCH`.

### 3. Discover workflows on the target repo

Run:

```
gh workflow list --repo <TARGET_REPO>
```

Resolve the user's tokens against the discovered workflows:

- For each token, match it **case-insensitively as a substring** against the discovered workflow filenames (and display names). A token may match more than one workflow.
- The literal `all` selects every workflow on the repo that has a `workflow_dispatch` trigger.
- If a token matches **no** workflow on this repo, list the available workflows and ask the user to pick via `AskUserQuestion`.
- If a token matches **multiple** workflows and that is likely unintended, confirm the matched set with the user before proceeding.

To detect `workflow_dispatch` support, run `gh workflow view <file> --repo <TARGET_REPO> --yaml` and look for `workflow_dispatch:` in the `on:` block.

If no tokens were given in arguments, ask now:

> "Which workflow(s) do you want to trigger on `<TARGET_REPO>`?"
>
> [multiSelect option list of workflows that have `workflow_dispatch`]

Store the chosen workflow filenames as `SELECTED_WORKFLOWS`.

**Plan/apply pairs.** After resolving `SELECTED_WORKFLOWS`, check for a plan/apply pair: two selected workflows that share a common stem where one name contains `plan` and the other contains `apply` (e.g. `infra-plan.yml` + `infra-apply.yml`, `terraform-plan.yml` + `terraform-apply.yml`). When such a pair is present, treat it as **sequential** (plan → gate → apply), never parallel — see step 6.

### 4. Discover each workflow's inputs

For each filename in `SELECTED_WORKFLOWS`, run:

```
gh workflow view <file> --repo <TARGET_REPO> --yaml
```

Parse the `on.workflow_dispatch.inputs` block. For each declared input, record:

- `name` (e.g. `environment`, `target_environment`)
- `required` (true / false)
- `type` (e.g. `choice`, `string`, `boolean`, `environment`)
- `options` (for `choice` type)
- `default` (if set)

Build `WORKFLOW_INPUTS[workflow] = [...inputs]`.

### 5. Resolve input values

For each workflow's required inputs:

1. **If the argument string contains a `key=value` override** matching the input name → use that value (validate it against `options` if `choice`).
2. **Else if the input name suggests environment** (`environment`, `target_environment`, `env`) and a bare environment token was given in arguments (`prod`, `qa`, `staging`) → use it (validate against `options`).
3. **Else if the input has a `default`** → use the default (but still surface it in the confirmation gate).
4. **Else** → ask the user via `AskUserQuestion`. For `choice` inputs, present the options. For boolean, present Yes/No. For free-text, present the most likely values plus "Other".

Group all questions for all selected workflows into a single `AskUserQuestion` call where possible — never one prompt per workflow if they share inputs.

Store as `RESOLVED_INPUTS[workflow] = { key: value, ... }`.

### 6. Confirmation gate

**Gate applicability — decide first whether the routine confirmation is required.**

Skip the confirmation prompt and fire immediately — **even when `environment=prod`** — only when **all** of these hold:

- **Direct user invocation** — the user personally typed `/repo-git-trigger-workflow …` this turn (not Claude via the Skill tool, not another skill or workflow, not an agent/subagent).
- **Scope fully specified** — every target workflow was resolved from explicit tokens in the user's arguments; nothing in step 3 was chosen through an interactive prompt.
- **Inputs fully specified** — every required input, including `environment`, was taken directly from the user's arguments (step 5 case 1 or 2). None fell back to a default (case 3) or had to be asked (case 4).

When all three hold, still **show the summary picture below** (so the user sees exactly what fired), then proceed straight to step 7 — do **not** call `AskUserQuestion`.

In **every other case** — programmatic invocation, or any workflow/input that was defaulted, asked, or interactively resolved — the gate is **mandatory**. When the invocation source is unclear, treat it as programmatic and ask.

Show the user the full picture:

```
──────────────────────────────────────
  REPO:    <TARGET_REPO>
           https://github.com/<TARGET_REPO>
  BRANCH:  <DEFAULT_BRANCH or override>
──────────────────────────────────────

  Will trigger:
    • <workflow>.yml     environment=prod
    • <workflow>.yml     environment=prod

  Total: N workflows
──────────────────────────────────────
```

**If the gate applies** (per "Gate applicability" above), ask via `AskUserQuestion`:

> "Trigger these workflows on `<TARGET_REPO>`?"

Options:

1. Yes — trigger all *(Recommended)*
2. Cancel

If the selection contains a **plan/apply pair** (detected in step 3), the gate must be split — and this split **always applies, even on a direct fully-specified invocation** (it is a safety review of plan output, not a routine confirmation):

- **First gate:** confirm the `plan` workflow only.
- **After the plan run completes** — poll `gh run list --workflow=<plan-file> --repo <TARGET_REPO> --limit 1` until status is `completed`:
  1. Resolve the run id:
     ```
     gh run list --workflow=<plan-file> --repo <TARGET_REPO> --limit 1 --json databaseId,conclusion -q '.[0]'
     ```
  2. **If `conclusion` is not `success`** (failure, cancelled, timed out) → do **not** offer apply. Report the failed plan run URL and **stop**.
  3. Fetch the plan log and **analyse it** (see **Plan analysis** below):
     ```
     gh run view <run-id> --repo <TARGET_REPO> --log
     ```
  4. Present the analysis verdict, then ask the **second** gate to confirm the `apply` workflow.
- Never auto-chain plan → apply without the second gate.

**Plan analysis.** From the fetched plan log, extract and summarise the proposed changes so the user gets a verdict instead of a raw log. This is Terraform-oriented — adapt to whatever IaC tool the plan actually uses (Terraform, OpenTofu, Pulumi, Bicep/ARM what-if, CloudFormation change set):

- **Change summary** — the headline line (e.g. `Plan: N to add, M to change, K to destroy`, or `No changes`). Report the counts.
- **Destroys & replacements** — resources marked `will be destroyed`, or `-/+ ... must be replaced` / `# forces replacement`. List each by resource address. These are the highest-risk items.
- **Security-sensitive changes** — IAM roles/policies, security groups / firewall rules, public-access or ACL changes, secrets, Key Vault / KMS access. Flag any that appear.
- **Errors or warnings** surfaced in the plan output.

Then present one verdict line:

- ✅ **Looks good** — only additions and in-place updates; no destroys, replacements, or security-sensitive changes.
- ⚠️ **Review needed** — one or more destroys, replacements, or security-sensitive changes; list them explicitly so the user can weigh them.
- ❌ **Do not apply** — the plan errored, was truncated beyond use, or produced no valid plan.

State plainly that this is an **advisory summary parsed from the plan log**, not a guarantee — the user makes the final call at the second gate. If the log is truncated or the plan format is unrecognised, say so and fall back to showing the tail of the raw plan output rather than inventing a verdict.

If any workflow's resolved environment is `prod`, present it prominently in the gate text — but do not require a second prompt unless the user has configured one. The `AskUserQuestion` itself is the prod gate.

### 7. Fire workflows

After confirmation, fire all selected workflows in parallel (one `Bash` tool call per workflow, all in a single message). Each command:

```
gh workflow run <file> --repo <TARGET_REPO> --ref <branch> -f <input>=<value> [-f <input2>=<value2> ...]
```

Capture the URL returned by `gh workflow run` for each.

### 8. Verify and report

For each fired workflow, run:

```
gh run list --workflow=<file> --repo <TARGET_REPO> --limit 1
```

Confirm the run shows up with status `queued` or `in_progress` and a recent timestamp (within the last ~60 seconds — older means we matched a previous run).

Print:

```
Triggered <N> workflows on <TARGET_REPO>:

  • <file>  → <status>  <url>
  • <file>  → <status>  <url>
  ...

Watch them with:
  gh run watch --repo <TARGET_REPO>
```

If any `gh workflow run` returned an error, list it explicitly and do not pretend the run was queued.

## Verification

- Every selected workflow appears in `gh run list` with status `queued` or `in_progress` and a fresh timestamp.
- `gh run view <run-id> --repo <TARGET_REPO>` resolves for each printed URL.
- No workflow was fired without passing through the step 6 gate — **except** on a direct, fully-specified user invocation, where the routine gate is intentionally skipped (the plan/apply review gate still applies).
