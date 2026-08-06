# The Long Trail

An Oregon Trail roguelike deckbuilder, built in Godot 4 (Summer Engine).

Take a family west from Independence to Oregon City in 1848. The family are
cards in your deck — they talk, they bond, they get sick, and they can die.
Fight off wolves and road agents in Slay-the-Spire-style card combat, pick
your roads on a period map, chain card combos, and try to reach the valley
with everyone still breathing.

## The look

Dark chrome around a lit parchment table. All art is cut from 19th-century
public-domain engravings (Darley, Bewick, and friends) and printed into the
paper with multiply blending. The family appear as carte-de-visite oval
portraits cut from the same engravings.

## Running it

Open the project in Godot 4 / Summer Engine and run `main.tscn`.

- Headless test suite: `Summer.exe --headless --path . --script res://tests/playtest.gd`
- Visual probe (auto-plays to a fight, saves screenshots to `user://`):
  `Summer.exe --path . --script res://tests/visual_probe.gd`
- Art pipeline (cutouts, ink variants, feathered plates, portraits):
  `python tools/make_cutouts.py`

## Art credits

All engravings are public domain; see `ASSET-CREDITS.md` and
`assets/art/MANIFEST.md` for sources.
