# Kanban

This directory is the repository's local work board. Each card is a Markdown file that lives in exactly one column directory.

Only work with the Kanban board when the user asks to create or manage cards, or asks for work on an existing card. Changes do not require a card by default. Never create a card unless the user explicitly instructs you to do so.

## Columns

1. `1 - Problems to Solve/` contains known problems that could be solved but are not being worked on. Cards in this column describe problems, not prescribed solutions.
2. `2 - In Progress/` contains work an agent is currently working on.
3. `3 - In Review/` contains work the agent considers complete and has asked the user to review.
4. `4 - Done/` contains work that resulted in a code change, passed the user's review, and was committed.
5. `5 - Won't Do/` contains cards that will not be worked on, including duplicates, deferred problems, and reports that were determined not to be issues. This is a permanent graveyard for cards, but placing a card here does not necessarily mean the underlying problem will never be addressed. Agents should not inspect this column unless the user specifically references it or asks them to.

## Cards

Name each card `<CODE> - <Title>.md`, where `<CODE>` is a four-letter uppercase code and `<Title>` is a concise description of the problem. Use the same code and title for the card's document title. For example:

```text
SRAT - Review attachments are missing from App Store Connect submissions.md
```

Cards describe problems to solve, not solutions to implement. Describe the current situation, affected users, evidence, impact, and desired outcome. Never prescribe a solution, implementation, architecture, interface, or technical approach in a card.

Use this basic template for each card:

```markdown
# <CODE> - <Title>

## user value

As a <user type>, I want to <do thing>, so that <value>.

## Problem description

<freeform description of problem>

## Status, notes, context, etc (optional)

<agent to edit as desired or needed>

## Prompts

<user prompts copied verbatim, interleaved with brief summaries of the agent's work>
```

Keep useful problem and review context in the card so another agent chat can continue the work without turning the card into an implementation plan.

Keep `## Prompts` as the final section of every card and use it as a chronological interaction log. When a user prompt creates, changes, or advances the card or its work, append the complete prompt exactly as it was given to the agent. Preserve its wording and formatting; do not summarize, correct, or otherwise rewrite it. After each prompt, append a brief summary of the work the agent performed in response before recording the next prompt.

Refer to a card by its code, title, or filename. Preserve its filename while moving it between columns.

## Card Management Commits

When the user asks only to create, edit, or move a card, make the requested change and commit it immediately without asking for confirmation. This includes changes to cards in `1 - Problems to Solve/` and moves to `5 - Won't Do/`.

Commit only the card files changed by the request. Never include unrelated working-tree changes in a card management commit.

These immediate commits apply to standalone card management. Card moves and edits made as part of implementation work follow the review workflow below and are committed with the implementation when the user approves it.

## Workflow

1. When the user instructs you to create a card, create it in `1 - Problems to Solve/`.
2. When the user asks an agent to work on a card, the agent moves it to `2 - In Progress/` before changing the implementation.
3. The card remains in `2 - In Progress/` across agent chats until an agent is satisfied that the work is complete and verified.
4. The agent moves completed work to `3 - In Review/` and asks the user to review it. The implementation and card move remain uncommitted while review is pending.
5. If the user reports an issue or requests a change, the agent moves the card back to `2 - In Progress/`, updates the work, verifies it, and returns the card to `3 - In Review/`.
6. When the user explicitly approves the work, use the `commit` skill to move the card to `4 - Done/` and commit the completed work and card move together.
7. When the user decides a card should not be worked on, the agent moves it to `5 - Won't Do/` and records the reason in the card. Cards never leave `5 - Won't Do/`. If the user later decides to address the underlying problem, create a new card in `1 - Problems to Solve/` instead of restoring the old card.

## Other

There will always be exceptions to the rules, so use your best judgement and consider the guidance the user has given to you.
