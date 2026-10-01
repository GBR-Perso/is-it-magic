# Dev Workflow — Claude Code Plugin

This repository is a general-purpose Claude Code plugin providing AI-assisted development workflow — agents, orchestration skills, machine setup, and language rules.

## Plugin model

This is the **base** plugin in the layered model — broad, general-purpose, installed user-level. Specialized (company/stack-scoped) plugins layer on top per-project. For the full model and the litmus test on where any skill/agent/rule belongs, see @../docs/plugin-model.md.

## Plugin Structure

- `skills/` — 20 skills as `<name>/SKILL.md` + shared architecture docs in `skills/shared/`
- `agents/` — 14 agent definitions (implementation pipeline, investigation, security scanners)
- `rules/` — 6 rule files (synced to `~/.claude/rules/` by `/devbox-init`, then auto-loaded natively by Claude Code)
- `.claude-plugin/plugin.json` — plugin manifest

## How It Works

1. Install the plugin (user-level).
2. Run `/devbox-init` once on this machine to sync all plugin rules into `~/.claude/rules/` and enable favoured language LSPs in `~/.claude/settings.json`. Rules load globally in every session. Re-run after plugin updates to refresh.
3. Skills become available as slash commands (`/devbox-init`, `/project-implement`, etc.); agents are spawned by skills or invoked directly.

## Development

When editing this repo, you are editing the plugin source. Changes here affect all consumer projects.

- Skills reference shared docs via `${CLAUDE_PLUGIN_ROOT}/skills/shared/` — keep `shared/` as a sibling of skill directories.
- Rules use YAML frontmatter `paths:` for file-type scoping — Claude Code auto-loads them natively; no skill involvement needed.
- Agent references in skills must use `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md` — never `.claude/agents/` (that's the consumer project, not the plugin).
- Test skill changes by running them in a consumer project after updating the plugin.
