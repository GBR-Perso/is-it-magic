# 0024. Retire project-port

**Status**: Accepted
**Date**: 2026-10-30

## Context

`/project-port` copied or merged files and features between sibling projects. In practice ports are done
by asking for them directly in a session, against the target project's own rules, and the skill added
little to that. The Rise app template now carries its porting rule in its own ADR digest (it--app-template
ADR 0009: template examples never travel in a port), which every scaffolded app inherits.

## Decision

Delete the `project-port` skill. A port is a plain request in the session; the target project's
instructions and ADR digest govern it.

## Consequences

- One skill fewer to maintain and to load.
- Project-specific porting rules live in the project, where both directions of a port read them, rather
  than in a generic skill that cannot know them.
- Reversal is restoring the skill folder from history.
