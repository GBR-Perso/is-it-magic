---
paths:
  - "**/*.cs"
  - "**/appsettings*.json"
  - "**/*.csproj"
---

# C# Language Rules

## C# Style

- Never use `var` — always explicit types
- No `Async` suffix on method names — everything is async, the suffix adds no information
- Collection expressions: `[]` not `new List<T>()`; prefer `[.. enumerable]` over `.ToList()`
- No `#region` directives
- Prefer ternary/conditional over `if` for return/assign — format as 3 lines (condition, `? true`, `: false`)
- Records for commands, queries, DTOs, and value objects; sealed classes for handlers
- Nullable reference types enabled, implicit usings enabled
- .NET 10 / C# 14 features valid (primary constructors, collection expressions)

## C# Naming & Formatting

- PascalCase for constants, `s_` prefix for static fields, `_camelCase` for private fields
- 4-space indentation, braces on new lines, 120-char line guideline
- Keep methods under 30 lines
