# Clean Architecture (.NET) — Conventions

> How a clean-architecture .NET codebase is organised, so changes land in the right place.
> Guidance for planning and implementation — not enforced line-rules.

## Layers (dependencies point inward only: API → Application → Domain)

- **Domain** — entities, value objects, domain events. No dependencies.
- **Application** — commands, queries (CQRS), validators, interfaces. Depends on Domain only.
- **Infrastructure** — persistence (EF Core), external services, repositories. Implements Application interfaces.
- **API** — thin controllers (delegate to the mediator; no business logic), DTOs, middleware. Depends on Application.

Infrastructure is never referenced by Application or Domain.

## Where things go

- New entity → `Domain/Entities/`
- New command/query → `Application/Features/{Entity}/`
- New validator → alongside its command in `Application/Features/{Entity}/`
- New endpoint → `API/Controllers/{Entity}Controller.cs`
- New persistence config → `Infrastructure/Persistence/Configurations/{Entity}Configuration.cs`

## Naming

- Commands `{Verb}{Entity}Command`; Queries `Get{Entity}Query` / `List{Entities}Query`
- Handlers `{Command/Query}Handler`; Validators `{Command/Query}Validator`
- Repositories `I{Entity}Repository` (interface) / `{Entity}Repository` (impl)

## Handler conventions

- Query/Command + its Handler live in the same file — never split.
- Controllers stay thin — delegate to the mediator.
- Query → DTO projection inside the query (single SQL round-trip). Load-then-map only for a polymorphic hierarchy where a shared projection would force formula duplication.
- Extract shared logic into services — no cross-handler duplication.

## Seeding reference data

Before seeding a table, decide who owns its rows:

- **Model-owned** — rows change only when code changes, and code references their identity (enum mirrors: statuses, kinds, categories). Declare them in the entity configuration (`HasData`) — they ship with the migration, present in every environment.
- **Runtime-owned** — rows have a lifecycle independent of releases (rates set by law, fee schedules, thresholds — anything an administrator must correct without a deploy). These are *not* seed data: they need a CRUD feature plus permanent bootstrap code for the initial rows.

> Deciding question: *"Can this value change while the code stays the same?"* Yes → runtime-owned. No → model-owned.

Getting it wrong is asymmetric: model-owned rows in production can only be changed by shipping a migration, and wiping them is unrecoverable without hand-writing one — the original migration is recorded as applied and never re-runs.

`HasData` constraints to weigh before choosing it: primary keys must be explicit constants; values must be deterministic (no `DateTime.Now`, no `Guid.NewGuid()`, no FK resolved by lookup); rows are identical in every environment; and it bypasses `SaveChanges`, so no interceptor ever runs over seeded rows.

Dev fixtures (sample customers, orders, sample hierarchies) are a third category — local seeder only, never the model.

## Testing Policy

Domain and Application changes — entities, domain rules, command/query handlers, and validators —
are developed test-first (RED → GREEN):

1. The developer scaffolds the signatures/stubs needed (handler shells, validator shells, entity/method
   signatures) — compiling, but with no real behaviour.
2. The test-writer derives tests from the architect's Test Strategy and the requirements, runs them, and
   confirms true RED — every test fails because the behaviour is missing, not because of a compile error
   or a wrong assumption about the stub.
3. Only once RED is confirmed does the developer implement the real behaviour, to GREEN.

**Governed layers**: Domain, Application
