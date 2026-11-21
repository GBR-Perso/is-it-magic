# 0027. Hold QA and prod deploys until project schema scripts are run

**Status**: Accepted
**Date**: 2026-11-20

## Context

A deploy never touches a QA or prod schema; a person runs the SQL. Nothing made the commit or the deploy
produce that SQL or wait for it, so a deploy could ship code against a schema that lacked its migrations.
The tooling that knows the schema is the project's, not the plugin's.

## Decision

- A project declares its step in `.claude/commit-and-deploy.json`: `migrationsPath`, a `generate` command,
  and `scripts`, the script path per environment. Contract and procedures: `skills/shared/_project-deploy-steps.md`.
- `repo-commit-and-deploy`, after the tests and before staging, runs `generate` when the commit adds files
  under `migrationsPath`, stages the scripts, and tells the user, per environment, the script and the
  migrations it holds. A non-zero exit stops the chain before the commit.
- Before firing a workflow whose `environment` is a key of `scripts`, `repo-deploy` (and so
  `repo-commit-and-deploy`) runs `generate <env>`. A script left after exit 0 is outstanding: ask "Has
  `<path>` been run on `<env>`?" and fire only on yes. This hold applies even when the routine gates are skipped.
- The hold is exit-code based and fails closed: a non-zero exit, or a `generate` that cannot run, is asked
  the same question; only exit 0 with no script means nothing is outstanding.
- `repo-commit` generates nothing; its hand-back warns that migrations were added without scripts.

## Consequences

- The skills stay project-agnostic; a project without the file sees no change.
- The deploy re-reads the environment, so a script that was already run is not asked about twice.
- An environment that cannot be proven current, for any failure, is asked about: the user answers for it.
- The hold is a question to the user, not a verification that the script ran.

## Alternatives considered

**Hard-code the project's generator in the skills.** Rejected: ties a base plugin to one project's tooling.

**Generate in `repo-commit` too.** Rejected: a fork cannot ask or sign in, and it needs the database.

## Relates to

[ADR-0008](0008-gate-every-mutating-phase-on-a-human.md),
[ADR-0022](0022-fork-repo-commit-and-confirm-every-push.md)
