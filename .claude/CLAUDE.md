# CLAUDE.md

Personal catalogue of Claude plugins, and home of the `is-it-magic` plugin. No build.

- Each plugin lives in `plugins/<name>/` and is listed in `.claude-plugin/marketplace.json` with a relative `source`.
- Each entry's `description` must match the plugin's own `plugin.json`.
- Bump a plugin's `version` in its own `plugin.json` only when that plugin changes.
- Keep the README's plugin table in sync with `marketplace.json`.
- Run `claude plugin validate .` before every push.
- Keep each plugin's README (skills and components) in sync with its folder.

## Editing a plugin in `plugins/`

Changes here affect every project that uses the plugin.

- `is-it-magic` is the **base** plugin in the layered model — broad, general-purpose, installed user-level. Company-scoped plugins layer on top per project. Where a skill, agent or rule belongs: @../docs/plugin-model.md.
- Nothing at a plugin's root besides its components is loaded by consumers — put context for them in a skill, not a `CLAUDE.md`.
- Skills reference shared docs via `${CLAUDE_PLUGIN_ROOT}/skills/shared/` — keep `shared/` as a sibling of the skill folders.
- Agent references in skills use `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`, never `.claude/agents/` (that is the consumer project).
- Rules use YAML frontmatter `paths:` for file-type scoping; `/devbox-init` syncs them to `~/.claude/rules/`.
- Test a change in a consumer project with `claude --plugin-dir <path to plugins/<name>>`.
