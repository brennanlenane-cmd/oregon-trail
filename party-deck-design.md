# The Family — Party-as-Deck Design

The signature mechanic of The Long Trail: **your party members ARE cards in your deck** — persistent,
talkative, Inscryption-style companions who stick with you the whole run, grow bonds, and can die.
This is the feature that makes this game unlike any other deckbuilder. Build it with love.

## The party
At run start the player NAMES their party (defaults offered, full custom allowed — naming your
family after friends is half the fun and all of the grief). Default roster:

| Member | Signature card (always in deck) | Personality in one line |
|---|---|---|
| **Pa** | "Pa's Steady Hands" — 1 Grit: +5 supplies OR repair 5 wagon (choose) | calm, understates everything |
| **Ma** | "Ma's Resolve" — 1 Grit: +6 morale; if morale < 30, +10 instead | steel under warmth |
| **Sarah (kid)** | "Sarah's Keen Eyes" — 0 Grit: draw 1; reveals next event type | curious, sees everything first |
| **The Dog (Biscuit)** | "Biscuit" — 0 Grit: +2 morale; in encounters: enemy loses 2 damage this turn | a good dog. the best dog |
| **The Ox (Brutus)** | "Brutus" — 2 Grit: travel bonus — next leg costs 1 fewer day | slow, immense, dependable |

Player character is the narrator/hand — not a card.

## The Inscryption rules (what "they stick around" means)
1. **Persistent**: family cards can never be removed, sold, or left behind by normal means.
   They are exempt from card-removal UIs (show them grayed with "Family stays together").
2. **They talk.** Every family card has a bark table — short one-liners (≤10 words) that pop in a
   small speech bubble ~25% of the time when the card is DRAWN, and always on special moments:
   first draw of a run, played during an encounter, drawn at low morale, at each landmark.
   Barks reference game state ("Sarah: 'River looks angry today.'" before a river event).
   Write 8-12 barks per member per category. This is cheap and it is the whole soul.
3. **They advise.** During events, one family member occasionally leans into the choice UI with a
   hint bark next to an option ("Ma nods at B."). The hinted option is never strictly wrong —
   advice reflects their personality (Pa favors caution, Sarah favors curiosity), not an answer key.
4. **They grow (bonds).** Playing a member's card counts toward their bond level (5/15/30 plays).
   Each bond level: the card upgrades (use the existing "_u" upgrade pattern, then a "_u2" tier)
   AND unlocks a new bark set. Show a tiny heart pip on the card frame per bond level.
5. **They get hurt.** Members have their own condition track (Healthy → Hurt → Sick) shown in a
   small roster strip on the map screen. Events and encounter overkill can Hurt/Sicken a member:
   their card gets a debuffed variant (e.g. Sick Sarah: "draw 1" loses the event-reveal) and a
   cough bark. Medicine/rest cures. This makes disease FELT in the deck.
6. **They die.** If a Sick member is untreated for 2 legs, or an event kills them, the member is
   gone: their card transforms permanently into **"Memory of <name>"** — 0 Grit, exhaust,
   +8 morale, one final bark ("You remember Biscuit chasing prairie dogs."). Play it and it's
   gone for the combat; it returns each fight. A grave is planted at the death spot (feeds the
   persistent-graves feature). The letter-home and death screens reference every loss by name.
7. **The wagon quiets.** Each death permanently removes that member's barks. A run where three
   family members died is mechanically fine and emotionally silent — that contrast is the point.

## Emotional guardrails
- Deaths must always trace to disclosed risks the player accepted (event odds, untreated sickness,
  overkill warnings) — never random gotchas. Grief lands only when the player knows it was them.
- Keep barks period-flavored and warm; never jokey-modern. The dog never talks — bark barks only.
- Kids can get sick and die (it's the Oregon Trail) but NEVER show it graphically — the game cuts
  to the grave and the letter home. Restraint is the horror.

## Implementation notes (for the Summer agent)
- `party.gd` registry: {id, name (player-set), condition, bond_plays, bond_level, alive, card_id}.
  Party state saves with the run.
- Family card ids live in data/cards.gd like all cards, flagged `"family": true` — the flag drives:
  removal exemption, bark hookup, bond counting, memory-transform on death.
- Bark system: `barks.gd` — dictionary keyed by member id + trigger (drawn/played/landmark/low_morale/
  event_hint/death). A small Label bubble near the card, 2.5s fade. One reusable function.
- Naming screen: simple 5-field form at run start with "Suggest names" button; names flow into
  barks via format strings, epitaphs, letters home, run history.
- Death transform: swap card_id in deck arrays for "memory_<member>" — the generic fx resolver
  already supports morale; add `"exhaust": true` handling if not present.
- Milestone order: (1) cards + removal exemption, (2) roster strip + condition, (3) barks,
  (4) bonds/upgrades, (5) sickness/death/memory pipeline, (6) event hints. Playtest each.
