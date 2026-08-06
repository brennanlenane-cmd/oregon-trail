# Deckbuilder Design Brief — The Long Trail

For the Summer Engine agent implementing the deck/hand/draw/discard/journey loop in `main.gd`.
Written by Claude Code (which will NOT touch `main.gd` / `main.tscn` while you implement).
Deep background lives in `DESIGN-NOTES.md` (card-budget math, event grammar, engine patterns — distilled from Balatro's source and Slay the Spire's content database). A playable HTML reference of the full vision is at `C:\Users\Brennan Lenane\Desktop\Apps\westward\index.html`.

## Current state (read from main.gd)
Good bones already present: `draw_pile/hand/discard_pile` arrays, `CARD_LIBRARY`, `_rebuild_hand_ui()`, `_apply_card()` (match on `action`), A/B `EVENTS`, `ROUTE_STOPS` (5), `supplies/morale/day/leg`, `_on_continue_pressed()` advancing one stop per press. Gaps this brief addresses: no reshuffle, no draw-to-N per leg, no card costs, no card acquisition/removal (deck never changes = not yet a deckbuilder), no fail state, events don't interact with cards beyond discarding one at random.

## The loop to build (v0.2 — journey deckbuilder)

**A leg = one decision cycle:**
1. START LEG: refill Grit to 3, draw until hand has 5 (reshuffle discard into draw when draw pile empties — shuffle with `randi`-seeded shuffle, this is the single most important missing rule).
2. PLAY PHASE: player plays any cards they can afford (each card has `cost` in Grit, 0–2 for journey cards). Playing moves card hand → discard and applies `fx`.
3. CONTINUE JOURNEY: advances the trail 1 leg, `day += rand 3..5`, supplies drain `2 × days` (provisions pressure makes supply cards matter), then a TRAIL EVENT fires.
4. EVENT: A/B/(C) choices per the grammar below; resolving ends the leg → back to 1.

**Route:** replace the 5 `ROUTE_STOPS` with 12 legs: Independence → Kansas River → Fort Kearny → Chimney Rock → Fort Laramie → Independence Rock → South Pass → Soda Springs → Fort Hall → Snake River → Blue Mountains → The Dalles → Barlow Pass → Oregon City. Reaching each stop = a CARD REWARD: choose 1 of 3 (rarity roll: 70% common / 25% uncommon / 5% rare) or skip. This is what makes it a deckbuilder.

**Fail states:** supplies ≤ 0 → morale drains 8/leg (starvation). morale ≤ 0 → run ends (journal-entry game-over screen, show days survived + miles). Both visible and telegraphed in the ledger before they hit.

## Card schema (the shared contract — please keep exactly this shape)
Move card data OUT of main.gd into `res://data/cards.gd` (a `const CARDS := {...}` resource script). Claude will later add combat cards to the same file without touching main.gd — this is our file boundary.

```gdscript
"trail_rations": {
    "name": "Trail Rations", "cost": 1, "type": "supply",   # supply | morale | scout | combat(later)
    "rarity": "starter",                                    # starter | common | uncommon | rare
    "text": "Spend 3 supplies. Gain 6 morale.",
    "fx": { "supplies": -3, "morale": 6 }                   # generic resolver applies keys; no per-card match
}
```
Resolver: iterate `fx` keys (`supplies`, `morale`, `draw`, `grit`, `days` [negative = shortcut], `reveal` [future scouting]). Replace `_apply_card()`'s match with this — adding cards then never requires code changes.

**Starter deck (10):** 3× Trail Rations (1c: −3 supplies, +6 morale), 3× Forage (1c: +4 supplies), 2× Campfire Stories (1c: +7 morale), 1× Scout Ahead (0c: draw 2), 1× Trading Ledger (2c: +8 supplies).
Budget rule from DESIGN-NOTES.md: 1 Grit ≈ 5 supplies ≈ 6 morale ≈ 2 draw; starters run ~25% under rate so found cards feel strong. Commons at rate; uncommons add riders (draw, dual effects); rares bend rules ("Wainwright: 0c, exhaust, skip the next event's cost entirely").

## Event grammar (from the StS analysis — keep this discipline)
- Five currencies: supplies, morale, days, cards (add/remove), Grit-next-leg.
- Every choice discloses its full cost AND reward in the button label before clicking (current `ad`/`bd` fields already do this — keep).
- Card-driven choices are the point of "card-driven journey": at least one branch per event should reference cards, e.g. "Ford now — *discard a supply card* to cross safely" (button disabled with reason shown if requirement unmet), "The trader admires your ledger — *remove any card from your deck* for $0". Requirement-locked options stay VISIBLE but disabled: `[Requires: a scout card]`.
- Always one free walk-away option (may cost days, never resources).
- 8–10 events minimum, drawn without repeats until pool exhausts.

## UI notes (fit the existing layout)
- Keep the lower `DeckbuilderPanel` band as the hand; add small Grit pips (●●○) and `DRAW n / DISCARD n` counts (labels exist: `hand_value`).
- Card buttons: show cost badge; unaffordable cards disabled (dim), not hidden.
- Keep the probe nodes (`_create_stable_probe_nodes`) pattern for any new interactive elements — add `probe_` handles for card slots so automated playtests can drive them.
- Art direction (when styling): frontier letterpress — cream paper `#ede4c8`, near-black ink `#221c14`, red accent `#a02818`, wood-type condensed headers. Public-domain engraving images are being collected at `Desktop\Apps\westward\assets\art` (with MANIFEST.md) — copy what you need into `res://assets/art/`.

## Division of labor (agreed workflow)
- **Summer agent owns:** `main.gd`, `main.tscn`, journey UI, this v0.2 loop.
- **Claude owns (separate files, added later; wire-up coordinated through this doc):** `res://data/cards.gd` extensions (combat cards), `res://combat/` module (StS-style encounter scene: energy, block, enemy intents — spec in DESIGN-NOTES.md), design docs. Claude will not edit main.gd/main.tscn without saying so first.
- **Future hook (don't build, just don't preclude):** some map events will call `start_encounter(encounter_id)` → switches to the combat scene, which returns `{victory, hp_lost, rewards}`. Keeping journey state in plain serializable vars (as now) makes this trivial.

## Acceptance checklist for v0.2
- [ ] Deck cycles: empty draw pile reshuffles discard; counters always consistent (hand + draw + discard == deck size)
- [ ] Grit refills each leg; costs enforced; draw-to-5 each leg
- [ ] 12-leg route with card reward (1-of-3, skippable) at each stop
- [ ] Cards live in `res://data/cards.gd`; generic fx resolver; zero per-card code
- [ ] Supplies drain per travel day; both fail states reachable and survivable-with-play
- [ ] ≥8 events, each with a card-referencing branch and a free leave
- [ ] A full run start→Oregon City (or death) is playable with mouse only
