# Agent Notes

Project-specific guidance for AI agents lives here.

## Two-agent workflow (Summer agent + Claude Code)
- Design docs: `deckbuilder_design.md` (implementation brief for the current milestone) and `DESIGN-NOTES.md` (research-derived design bible). Read both before making gameplay changes.
- File ownership: the Summer agent owns `main.gd` / `main.tscn` and the journey UI. Claude Code owns `res://data/cards.gd` (card definitions), the future `res://combat/` module, and the design docs. Neither edits the other's files without saying so in chat first.
- Shared contract: the card schema defined in `deckbuilder_design.md` — coordinate changes to it through that doc, not ad hoc.
- Art: frontier-letterpress direction (cream #ede4c8 / ink #221c14 / red #a02818); public-domain engravings staged at `Desktop\Apps\westward\assets\art`.
