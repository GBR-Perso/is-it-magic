# Project deploy steps

A project declares steps its commit and deploy must run in `.claude/commit-and-deploy.json`. The skills stay generic: they read the file and know nothing of the project's tooling (ADR-0027).

```json
{
  "migrationsPath": "api/src/Infrastructure/Data/Migrations",
  "generate": "python tools/generate_upgrade_scripts.py",
  "scripts": { "qa": "sql-scripts/_upgrade-qa.sql", "prod": "sql-scripts/_upgrade-prod.sql" }
}
```

- `migrationsPath` — a commit that adds files under it needs fresh scripts.
- `generate` — the command that writes or deletes the `scripts` files. `generate <env>` limits it to one environment. Exit 0 means every environment was read; it prints, per environment, `SCRIPT <env> <path>` followed by one `PENDING <id>` line per migration the script holds, or `CURRENT <env>`. Any other exit (or a command that cannot run) means an environment cannot be proven current; its reason is the `NOT READ <env>: <reason>` line, or the `FAILED` / `PRECONDITION` line on stderr.
- `scripts` — keys are environment names, values are repo-relative paths. A script file existing after a successful `generate` is outstanding: a person must run it on that environment.

No file, no step: skip silently.

## Reporting scripts

Per environment, give the script path and its `PENDING` ids, or say it is current. Tell the user each script is to be run on its environment before that environment's deploy.

## Commit-time generation

1. Run only when the file exists and `git status --porcelain -- <migrationsPath>` has a line starting `??` or `A`, and the commit scope includes `migrationsPath`.
2. Run `generate` from the repo root.
3. Non-zero exit, or `generate` cannot run → stop before committing and report the reason line. Never commit new migrations without their scripts, and never work around the cause (firewall, sign-in).
4. Stage every `scripts` path, deletions included, with the rest of the commit.
5. Report as in **Reporting scripts**.

## Deploy hold

Applies before firing any workflow whose resolved `environment` equals a key in `scripts`, even when the routine gate is skipped. Run it once per distinct environment, before firing any workflow; its answer covers every workflow for that environment, and a no withholds them all.

1. Run `generate <env>`.
2. Exit 0 and no script file for the environment → nothing outstanding; fire without asking.
3. Exit 0 and a script file present → ask via `AskUserQuestion`: "Has `<path>` been run on <env>?" with `Yes, it has been run` / `No, do not deploy`. Fire only on yes.
4. Non-zero exit, or `generate` cannot run → show the reason line, then ask the same question for the environment's `scripts` path. Fire only on yes.
