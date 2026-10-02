## UX rules for all skills

### Confirmation gates

Whenever a command requires user confirmation before proceeding (commit, push, PR creation, applying changes, etc.):

- **ALWAYS** use `AskUserQuestion` with interactive selectable options — never use plain text prompts like "Shall I proceed?".
- Group related confirmations into a **single question** when possible (e.g. all repos in one prompt, not one per repo).
- Include a recommended option first (e.g. "Commit and push all (Recommended)").
- The user can always select "Other" to provide custom input (e.g. revise a message, pick specific repos, or decline).
- Present the details (commit messages, PR titles, file lists, etc.) in the **question text**, then keep options short and actionable.

### Understanding-validation gates

A gate that asks the user to confirm a restated brief, problem statement, or requirement ("Does this capture it correctly?") is only justified when the input has not already been validated:

- **Never re-validate suite-produced input.** When a skill's input is a report or recommendation produced in this conversation by another suite skill (e.g. an Investigation Report feeding `/project-decide`, or a Decision Report recommendation feeding `/project-implement`), present the restatement as plain text and proceed without asking — the user approved that content when it was produced.
- **A handoff selection is the confirmation.** When the user reaches a skill by selecting a handoff option offered by the previous skill, do not re-confirm the input on arrival.
- **Cold input: gate only on material ambiguity.** For free-text input supplied directly by the user, restate it and ask for confirmation only when it is materially ambiguous — missing scope, contradictory, or open to multiple plausible readings. Otherwise present the restatement and proceed; the user can always interrupt if the reading is wrong.
- **Merge intake questions.** When an understanding-validation gate is warranted alongside another intake question (e.g. mode selection), combine them into a single `AskUserQuestion` call per the grouping rule above.
