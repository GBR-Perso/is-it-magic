---
name: dumb-down
description: "Re-explain something that came out obscure — too abstract, too long, unreadable, or not grounded in a real example. Forces a didactic rewrite: the answer first, then one concrete case traced all the way through, re-derived from the source rather than recalled from the earlier explanation. Use this whenever the user signals that an explanation missed — 'I don't get it', 'you lost me', 'more simply', 'in plain English', 'ELI5', 'too much detail' (about something already explained), 'dumb it down', 'too much jargon', 'in normal words', 'you're using big words', 'stop using technical terms', 'that's just the definition again' — or asks for something already explained to be put another way, even if they never use the word 'explain'. Not for a first-pass orientation to an application or system. This skill re-explains something already said in this conversation."
---

The last explanation did not land. Rewrite it so it does.

The user is not asking for more detail. They are asking for the **same conclusion, made
graspable**. More words is the failure mode, not the fix.

## Target

Whatever the user points at in the arguments, or — if they name nothing — the explanation you
gave in your immediately preceding message.

## Rule 1 — Re-derive from the source, never from your own earlier words

Before writing a line, go back to whatever the claim actually rests on and check it again.

Usually that is a file: open it and read the actual formula, the actual condition, the actual
default. Do not paraphrase your previous message, and do not trust your recollection of what a
class or an ADR said.

Sometimes there is no file — the claim rests on a command's output, an external document, a
measurement, or your own reasoning. The rule does not lapse; it changes shape. **Name what the
claim rests on, and re-check that.** Re-run the command. Re-read the document. Walk the
argument again from its premises rather than from its conclusion. If it rests on nothing but
your own judgement, say so in the rewrite — "this is my read, not something I verified" — so
the user knows what weight it carries.

This is the most important rule, and it is not politeness. A re-explanation built on memory is
how a confident explanation becomes a confidently wrong one: you compress, then you reason from
the compression, and the compression is exactly where the conclusion inverted.

If the re-check contradicts what you said before, **say so in one plain sentence, up front, and
give the corrected version.** No apology paragraph, no account of how the slip happened, no
tally. Correct it and carry on.

## Rule 2 — The answer comes first

Open with the conclusion in one or two sentences, in the user's own vocabulary — reuse the
words they used when they told you it had not landed. Someone who reads only your first line
should come away with the answer.

Evidence comes _after_ the answer, as support. Never build up to a conclusion; never make the
reader assemble it from clues.

## Rule 3 — One concrete case, traced all the way through

Every abstract claim gets a specific case walked end to end. Not a restated definition — a case
the reader can follow and check for themselves.

Where the domain has numbers, use them, and reach an actual figure.

Not this:

> `Valuation` is the holding's value net of vendor-financing outstanding.

This:

> A share is worth €100k and €60k of the financing is still owed.
> Valuation = 100 − 60 = **€40k** — the part genuinely yours.

Where the domain has no numbers, the equivalent is a specific scenario with named actors and a
definite outcome: this input, arriving in this state, takes this path, and ends here. "Two
people open the same record; the second save is rejected and they are shown the newer version"
does the same work as arithmetic — it is checkable, and it commits to a result. Vagueness is
the enemy, not the absence of digits.

Pick the case that actually distinguishes the options — the edge case, the one where the two
candidate behaviours disagree. A case that comes out the same either way teaches nothing.

One case per idea. Two cases of the same idea is padding.

## Rule 4 — Code is a citation, not the explanation

The explanation is yours to make — usually prose, and a diagram where the confusion is structural
(a shape, a flow, a set of relationships). In that case the diagram **is** the explanation and the
prose supports it; drawn in the terminal it must be ASCII, never unrendered mermaid source. What
never explains for you is a pasted block of code. A `file.cs:80` reference or a one-line snippet is
there so the user can verify you, not to do your explaining for you.

- Quote at most one or two lines, and only the lines that carry the point.
- Never paste a block and leave the reader to infer why it matters.
- Never quote a doc comment as a substitute for saying the thing yourself.

## Rule 5 — Fewer ideas, with more room each

The first attempt failed because it carried too much, not because its sentences were long. So
what you cut is **coverage** — fewer claims, fewer branches, fewer caveats — and what survives
gets more room, not less.

Give each surviving idea its own short section under a heading that names it in plain words,
and finish it before starting the next.

Resist scope creep: implications, caveats, adjacent concerns and next steps are what made the
first attempt unreadable. If something genuinely matters and was not asked about, it gets one
line at the end, not a section of its own.

Do not mistake length for the problem. A worked example is usually the longest part of a
rewrite, and it is the part doing the work — if grounding an abstract claim makes the answer
longer than the abstraction it replaces, that is the rewrite succeeding. The test is density:
if you can delete a paragraph and lose nothing, it was padding, and padding is what you are
here to remove.

## Rule 6 — Everyday words, not big words

Say it in the words a colleague would use across a desk, not the words a policy document would
use. This applies to every line of the rewrite, not a final polish pass at the end — jargon
buried in paragraph three defeats the rewrite as completely as jargon in the opening line.

Prefer the everyday word over the technical one: "worth" over "valuation", "money you still owe"
over "outstanding liability", "share" over "instrument". Where a domain term genuinely cannot be
avoided — because it is the thing being explained, or the reader needs it to talk to others about
this — expand it in plain words the first time it appears, then use it freely from there. Do not
swap one piece of jargon for another that merely sounds friendlier: trading "leverage" for
"gearing" is not a plain-words rewrite, it is the same problem in a different coat.

Not this:

> The valuation is computed net of the outstanding vendor-financing liability, applying a
> pro-rata attribution across the holding period.

This:

> Take what the share is worth, subtract what you still owe on it. If you only held it part of
> the year, count only that part.

## Style

- Short sentences.
- No hedging ("it may be that", "arguably"), no meta-narration ("as I mentioned above").
- Write in the language the user wrote in; otherwise British English.

## Check before sending

Read the rewrite once more, and for each of these, note what it is protecting against:

1. **Does the first line answer the question on its own?** If not, you have made the reader work
   for the conclusion a second time — the precise thing that failed before.
2. **Is there a concrete case, traced to a definite outcome?** If it is still definitions all the
   way down, only the wording has changed.
3. **Did you re-check the source this turn, rather than reuse your earlier summary?** If not, you
   may be about to restate a mistake more clearly.
4. **Could any paragraph be deleted with nothing lost?** That paragraph is the padding you were
   asked to remove.
5. **Would someone who does not know this codebase follow it?** An explanation that only works
   for a reader who already knows is not an explanation.
6. **Is every sentence in words someone outside this domain would recognise?** A rewrite that
   trades one technical term for another, or leaves jargon standing in a later paragraph, has
   moved the problem rather than fixed it.

Fix what fails before sending — a rewrite that misses these lands the same way the first one did.
