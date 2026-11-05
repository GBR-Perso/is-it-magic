---
name: explain
description: "Explain something on a short throwaway page — What, Why, How, one worked example — published as the project's single scratchpad Artifact (scratchpad-<project folder>), updated when the subject is the same and wiped and rewritten when it is new. Also re-explains something that came out obscure, re-derived from the source rather than from the earlier wording. Use whenever the user wants to understand something or signals an explanation missed — 'explain', 'I don't get it', 'you lost me', 'what is this', 'why does it', 'more simply', 'in plain English', 'ELI5', 'dumb it down', 'too much jargon', 'make me a page about' — even if they never say 'page' or 'artifact'."
---

Make the user understand one thing, on one short page they can glance at beside the work.

## The page

- **One Artifact per project**, titled `scratchpad-<project>`, where `<project>` is the folder name of
  the git repository root (or of the working directory outside a repository) — e.g.
  `scratchpad-it--platform`.
- **Throwaway.** It anchors understanding; it is not a document. No history, no archive, no Markdown
  copy, no pin, no comment watch. ADR-0025.

## Steps

1. **Find the page.** Published earlier in this conversation → reuse its file path. Otherwise
   `Artifact` `action: "list"` and look for the exact title; found → `action: "read"` it.
2. **Same subject or new?** Same when the request is about what the page already explains (a
   follow-up, a part that did not land) → **update**: rework the page so it absorbs the new point and
   stays within the bound — never append a Q&A tail. Anything else, or unclear → **rewrite**: discard
   the old content entirely.
3. **Re-derive from the source.** Before writing, re-open what the claim rests on — the file, the
   command output, the document. Never paraphrase your earlier message or recollection; a compressed
   memory is where a conclusion inverts. If the re-check contradicts something you said before, the
   page says so in one line and gives the corrected version. If the claim rests only on your
   judgement, say "my read, not verified".
4. **Write the page** (see Content). First creation: `Artifact` `action: "quickstart"`, `intent:
   "other"`; otherwise load `artifact-design` — and `artifact-diagramming` when drawing.
5. **Publish** to the same file path (this conversation) or with the found `url`; first publish takes
   `icon: "lightbulb"`.
6. **Reply** with the one-line answer and the link. Nothing else in chat.

## Content

Three sections, in this order, ~250 words in all plus at most one diagram:

| Section | Holds |
| ------- | ----- |
| **What** | The answer in one or two sentences, in the user's own words. Someone reading only this gets it. |
| **Why** | The problem it solves, or what goes wrong without it. Two or three lines. |
| **How** | The mechanism, carried by **one concrete case traced to a definite outcome**. |

- **The case does the work.** Numbers where the domain has them, reaching an actual figure; otherwise
  named actors, this input, this path, this result. Pick the case where the plausible alternatives
  disagree — one that comes out the same either way teaches nothing. One case per idea.
- **A diagram** (inline SVG) when the confusion is structural — a flow, a shape, who calls whom. It
  then carries the How and the prose supports it. ~12 nodes at most.
- **Code is a citation**, not the explanation: a `file:line` or one line, never a block.
- **Fewer ideas.** Cut coverage — caveats, branches, next steps — not the example. Something that
  matters and was not asked: one line at the end.
- **Everyday words.** A domain term that cannot be avoided is expanded in plain words the first time.
  Swapping one piece of jargon for a friendlier-sounding one is not plain words.
- Short sentences, no hedging, no meta-narration. The user's language; otherwise British English.

## Check before publishing

1. Does **What** answer the question on its own?
2. Is there a concrete case reaching a definite outcome, not definitions restated?
3. Was the source re-checked this turn?
4. Could a paragraph go with nothing lost? Cut it.
5. Would someone outside this codebase and domain follow every line?
