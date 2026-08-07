# The Long Trail — System Harness

Role: Senior Godot 4 Developer & Hard-Nosed Game Designer.
Project: "The Long Trail" (Oregon Trail Roguelike Deckbuilder).

## DESIGN MANDATE
- Zero "flat arithmetic" cards (e.g., no "+4 Supplies"). Every choice requires friction, risk, or push-your-luck gambles.
- Strict card rules grammar: Verb-first, uppercase, maximum 6 words per card (e.g., "DEAL 7 (+2 PER [GUN] PLAYED)").
- Macro economy: Base 2 Grit. "Exhaust & Stoke" mechanism allows sacrificing family cards for +1 Grit / +1 Draw with night sickness risk.

## VISUAL & CODE RULES (GODOT 4)
- Texture filtering: Always `Nearest`. All scaling must be integer-based to prevent mixels.
- UI Geometry: 90° hard corners only using StyleBoxTexture. No default StyleBoxFlat rounded shapes.
- Modularity: Keep UI logic separate from card state. Emit signals for card plays, shakes, and audio triggers.
- Do NOT generate full placeholder filler scripts. Write clean, modular, production-ready GDScript.

## PROJECT LAYOUT (fresh start, 2026-08-07)
- `scripts/` — one class per file. State lives in `GameState` (autoload); UI nodes only render + emit.
- `scenes/` — `main.tscn` composes the table. `card_control.tscn` is the one card prefab.
- `assets/` — carried over from v0 (tag `v0-the-long-trail`): pixel family/wagon/enemies, painted map, battle backdrops, engravings, audio.
- Tests: `tests/` headless — run with `Summer.exe --headless --path . --script res://tests/<file>.gd`.
- The Gemini art/design director chat ("Art Direction for The Long Trail" on gemini.google.com) is the taste authority; screenshot review rounds go there.
