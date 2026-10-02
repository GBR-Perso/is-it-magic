---
name: project-upgrade-nuget
description: "Upgrade a .NET API's NuGet packages to their latest versions and verify with build + tests, holding back any package whose latest major is known-incompatible with the current framework until it is safe to bump."
---

## Context

Use this when asked to "upgrade all packages" (or update dependencies) in a .NET API. The job is to move every managed package to its latest version, then prove nothing broke via a clean build and the full test suite. Critically: **not every "latest" is safe** — a major-version bump can be incompatible with the pinned framework/SDK (e.g. a package whose new major changed an API that a framework-shipped source generator still emits against). Bump those only when the framework catches up; hold them at the highest compatible version in the meantime and record why.

## Prerequisites

- .NET SDK matching the projects' `TargetFramework` (verify with `dotnet --version`).
- The solution restores cleanly before you start (a green baseline).
- Integration tests' dependencies available if the suite needs them (e.g. LocalDB / a test database).

## Placeholders

Before running this skill, substitute all `{{PLACEHOLDER}}` tokens:

| Placeholder | Description |
|---|---|
| {{SOLUTION_FILE}} | Path to the `.sln` (or solution filter) to restore/build/test, e.g. `api/MyApi.sln`. |
| {{PACKAGES_PROPS}} | Central package-version file(s) — typically `Directory.Packages.props` (and any imported `eng/Directory.Packages.props` for `GlobalPackageReference`s). |
| {{API_DIR}} | Root of the API projects, used to scope framework/target checks. |

## Steps

1. **Establish the baseline.** From {{API_DIR}}, confirm the toolchain and framework: run `dotnet --version` and grep the `.csproj` files for `<TargetFramework>`. Note the major framework version (e.g. `net10.0`) — this is the compatibility anchor for later judgement calls.

2. **Locate how versions are managed.** Find central version files ({{PACKAGES_PROPS}}). If `ManagePackageVersionsCentrally` is true, all `<PackageVersion>` / `<GlobalPackageReference>` entries live there — edit versions in these files, never in individual `.csproj`. If versions are not centralised, they live per-project in the `.csproj` files.

3. **Restore and capture warnings.** Run `dotnet restore {{SOLUTION_FILE}}`. Record any `NU1903`/`NU1902` vulnerability warnings — these flag packages that *must* move (a later upgrade may clear them transitively).

4. **List what is outdated.** Run `dotnet list {{SOLUTION_FILE}} package --outdated`. Build a de-duplicated table of `package → resolved → latest`. Classify each row:
   - **Patch/minor** (same major): low risk — bump.
   - **Major** (major version changes): flag as breaking-risk — candidate for the hold-back check in step 6.

5. **Apply the safe bumps.** Edit {{PACKAGES_PROPS}} to set every patch/minor package to its latest. For major bumps, apply them too on a first pass **but be ready to revert** any that fail the build (step 7). Keep edits confined to the central version file(s).

6. **Judge major bumps against the framework before trusting them.** For any package that is part of, or tightly coupled to, the framework/SDK (ASP.NET Core, EF Core, analyzers, OpenAPI, source-generator-bearing packages), do **not** assume the newest major is compatible. Inspect the framework package's own dependency constraint before forcing a cross-major bump:
   ```bash
   NUGET=$(dotnet nuget locals global-packages -l | sed 's/^global-packages: //')
   find "$NUGET/<framework.package>/<version>" -name "*.nuspec" -exec grep -i "<coupled.package>" {} \;
   ```
   If the framework package pins the coupled package to an older major (e.g. `<dependency id="X" version="2.0.0" />` while latest X is 3.x), forcing the newer major will break framework-generated code. **Hold that package at its highest version within the framework-compatible major.**

7. **Build and let failures guide reverts.** Run `dotnet build {{SOLUTION_FILE}} -c Release` and read the errors. A `CS0200` / "cannot be assigned to — it is read only" (or similar) inside `*.generated.cs` from a framework source generator is the signature of a cross-major incompatibility: the framework's generator emits code against the old API. Revert that one package to its latest framework-compatible version (step 6) and rebuild. Iterate until the build is clean with **0 warnings / 0 errors** and no vulnerability warnings.

8. **Run the full test suite.** Run `dotnet test {{SOLUTION_FILE}} -c Release --no-build`. All projects must pass (unit + integration). If a major bump crossed a runtime-only boundary (e.g. an SDK client), smoke-test the affected paths even when compilation succeeded.

9. **Record the hold-back so it isn't re-attempted.** For every package deliberately held below its latest, add a comment next to its `<PackageVersion>` in {{PACKAGES_PROPS}} stating *why* and *when it can move* — e.g. "held at 2.x: framework package Y pins Microsoft.OpenApi <3; bump when a Y release depends on 3.x." This prevents a future run from rediscovering the incompatibility. State the same in the final summary.

10. **Report, don't commit.** Summarise: packages upgraded (with old→new), packages held back (with reason + unblock condition), build result, and test totals. Leave the working tree uncommitted for the user to review unless they ask otherwise.

## Verification

- `dotnet build {{SOLUTION_FILE}} -c Release` → `Build succeeded`, 0 warnings, 0 errors, no `NU190x` vulnerability warnings.
- `dotnet test {{SOLUTION_FILE}} -c Release` → every test project `Passed!` with `Failed: 0`.
- Every held-back package has an inline comment in {{PACKAGES_PROPS}} explaining the reason and the condition under which it can be bumped.
