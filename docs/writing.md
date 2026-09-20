# Writing rules

## Scope

Every piece of text written for a project: READMEs, `docs/`, UI copy (headings, buttons, empty states, footers), error messages, PR descriptions, code comments, and Claude's own chat replies. Text should read like a person wrote it, not like a model did.

## Hard ban: em dashes

Never use an em dash ("—") or an en dash ("–") as punctuation. Not in READMEs, not in docs, not in UI copy, not in chat.

- Replace it with a period, a comma, a colon, or parentheses, or rewrite the sentence.
- Do not swap in a spaced hyphen (" - ") as a stand-in. That is the same tic with a different character.
- Plain hyphens stay for compound words (`client-side`) and numeric ranges (`3-5s`).

Before finishing any text, search it for "—" and "–" and remove every hit.

## Patterns to avoid

- **The contrastive tag:** "X, not Y." / "It's not just X, it's Y." Says what the thing isn't instead of what it is.
- **Throat-clearing openers:** "In today's fast-paced world...", "In the ever-evolving landscape of...".
- **Marketing verbs on a tool nobody is marketing:** "unlock", "boost", "supercharge", "elevate", "empower", "streamline".
- **Hollow superlatives:** "seamless", "effortless", "game-changing", "cutting-edge", "comprehensive", "robust". Fine only when specifically true.
- **Corporate padding:** "leverage", "utilize", "harness", "facilitate" where a plain verb would do.
- **Stock vocabulary:** "delve", "tapestry", "realm", "landscape", "crucial", "pivotal", "navigate" used as a metaphor.
- **Hedge-everything openers:** "Whether you're a beginner or an expert, ..."
- **Rhetorical-question filler:** "Ever wondered how...?"
- **Sign-posting and filler transitions:** "Moreover", "Furthermore", "Additionally", "It's worth noting that", "Let's dive in", "Here's the thing".
- **Reflexive triplets:** three adjectives or clauses because three sounds finished ("fast, simple, and powerful").
- **Closing recaps:** "In summary", "Ultimately", "At its core", or a last paragraph that restates the ones above it.
- **Bold-lead bullets on every list item** and headers on documents short enough not to need them.
- **Decorative emoji and exclamation marks.** Fine only when they are a deliberate part of the project's voice.
- **Stacked hedges:** "can potentially help", "may often be useful".

## Do instead

Say the specific true thing, plainly, in the voice of a person. Short sentences. Concrete nouns, real names, real numbers. Say what the thing is and does, and skip what it isn't. Give it a point of view: a dry joke or a plain opinion beats safe, balanced copy that could have been written about anything.

## Self-check before finishing any text

1. Search for "—" and "–". Remove every hit.
2. Scan for the patterns above.
3. Ask: could this sentence sit unchanged in a random other project's README? If yes, rewrite it with something only true of this project.

**Origin:** the copy tells were first caught in Coined's footer ("search real, public code, not a suggestion engine") and lived inside `design.md`. Em dashes kept showing up in READMEs and docs anyway, so text rules became their own file where they can be loaded and enforced on their own.
