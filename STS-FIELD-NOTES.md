# Slay the Spire — Field Notes for The Long Trail
*Study method: extracted and read StS's own content files (relics.json: 195 entries, potions.json: 45, powers.json: 178, events.json: 54, tutorials/ui strings) plus the Balatro hand-layout source already ported. Play-session was blocked (window access denied), but the files tell the whole design story.*

## How StS actually works — the loops that matter

**The turn loop.** Draw 5, spend 3 energy, END TURN → enemies act on *telegraphed intents with exact numbers*. Block decays every turn, so defense is a per-turn decision, not a stockpile. Nothing waits for animations — you can queue plays as fast as you click, and the game catches up. *(We have this now: Grit + BRACE. Missing: block decay — our block persists until spent. Consider: block clears when you BRACE, making Lasso a timing decision.)*

**The reward loop.** Every fight: gold + pick-1-of-3 cards (skippable) + chance of potion. Elites: guaranteed relic. Chests: relics. The pull of "one more fight" is the *relic*, not the card. *(We have card rewards + $; we have NO relic-equivalent and NO consumables — the two biggest holes.)*

**The map loop.** The whole route is visible; every node is typed (fight / elite / ? / rest / shop / treasure / boss). Strategy starts before the first card is played: "can I afford the elite path for the relic?" *(Our trail is a line with a hidden cadence. The map already draws branch forks — they should be REAL choices: River Route [faster, Bad Water risk] vs Ridge Route [slower, bandit country].)*

**The campfire loop.** Rest (heal 30%) OR Smith (upgrade one card, permanently). One choice, always a sacrifice. *(We only have rest-via-events. No card upgrades for non-family cards at all — bond upgrades exist for family only.)*

**The economy loop.** Shops sell cards, relics, potions, and — critically — **card REMOVAL** (75g, price rises). Deck-thinning is half of every winning strategy. *(Our sutler sells no removal. This is also where "Family stays together" finally gets its UI moment — the grayed-out family cards in the removal list ARE the mechanic's emotional beat.)*

## What the files say about feel
- Tutorial strings are one sentence each ("End your turn to draw a new hand"). No paragraphs, ever. UI strings are 1–4 words.
- Keywords are a closed set (~12: Vulnerable, Weak, Strength, Poison, Artifact...) and every one has a hover definition. Content scales because effects recombine a tiny vocabulary.
- Intents are ICONS + numbers (⚔ 12, ⚔ 3×2, 🛡, buff), not sentences. Ours is a text line — needs glyphs.
- Relic text is one clause: "At the start of each combat, draw 2." The power is in the *always-on* rule change, not complexity.

## THE BUILD LIST for The Long Trail (priority order)

**P0 — Keepsakes (our relics).** The single biggest missing layer. Trail-flavored passive trinkets: found at graves ("a locket half-buried"), elite fights, rare shop stock. Start with ~15, one per character at run start:
- Gunslinger starts: *Powder Horn* — the first combat card each fight costs 0 Grit.
- Doctor starts: *Worn Stethoscope* — medicine effects also heal +1 condition step.
- Examples: *Ox Shoe* (travel bonus +1 every 4th leg), *Hymnal* (BRACE gives +2 morale), *Iron Skillet* (+2 supplies at every camp event), *Daguerreotype* (Memory cards give +12 morale — grief made mechanical), *Snake Oil* (shop prices -20%), *Broken Compass* (see next TWO legs' types, but events lose option hints).

**P0 — Tonics (our potions).** 3 belt slots (the HTML prototype already had this design). Drink anytime, gone forever: *Coffee* (+1 Grit now), *Laudanum Draught* (block 8), *Bitters* (+8 morale), *Snakebite Kit* (cure), *Gunpowder Sachet* (deal 10). Sources: events, fights (25%), sutler.

**P0 — Card removal at the sutler** ($12, +$3 each use). Family cards shown grayed: "THE FAMILY STAYS TOGETHER." Deck-thinning gives the Trading Ledger / Wainwright picks real tension.

**P1 — Camp choice at rest stops:** REST (heal a member a step / wagon +10) or MEND (upgrade one ordinary card: numbers +2/+3, name gets "+"). One choice per stop. Uses the upgrade grammar family cards already have.

**P1 — Intent glyphs + number pops.** ⚔/🛡 icons with numbers; floating damage/gain numbers on card play (+6 in green ink, -8 in stamp red, Playbill). Cheap, huge.

**P1 — Real forks on the map.** At Fort Kearny, Fort Hall, The Dalles: two named routes with disclosed tradeoffs. The branch lines are already drawn on the canvas.

**P1 — Audio.** The game is still fully silent. Even 8 sounds (card play, draw, brace-hit, coin, bark pop, letter seal, death toll, victory) transforms it. Needs asset generation or CC0 packs — flag for a session with Summer's cloud gen or freesound.

**P2 — Status effects** (closed vocabulary, 4 max): *Spooked* (enemy -25% next hit), *Bleeding* (enemy loses 2/turn), *Winded* (you draw 1 fewer), *Dug In* (block doesn't clear on BRACE).

**P2 — Elites + a boss.** Named elites on danger legs ("BLOODY HANDS McGREW") with a keepsake reward; final Barlow Pass boss ("THE LONG DARK" — the mountain itself, weather phases instead of attacks).

**P2 — Treasure nodes:** abandoned wagons/caches as a third leg type (free keepsake-or-tonic, small risk).

## One StS lesson we should NOT copy
StS heals between acts and expects you to tank hits. Our morale-as-HP plus family sickness is *slower dread* — Oregon Trail's identity. Keep hits scarcer but heavier, keep death arriving by neglect (untreated sickness) rather than burst damage. The Family is our Ascension — protect that difference.

---

# ADDENDUM — hands-on play session (actually played it, Ironclad, floors 1–3)
*Run left saved at floor 3, 80/88 HP — resume or abandon from the main menu as you like.*

## Feel details observed live, in priority order for us

1. **Selecting a card raises it HUGE, center-screen, fully readable** — hover lifts a card slightly; *clicking/selecting* is the full reveal, with keyword words colored (gold "Vulnerable"). Our hover-lift exists; we need the big selected state before targeting/confirm.
2. **Intents are icon + live number** (⚔ 7), and the number UPDATES when the enemy buffs (cultist's ritual pushed ⚔6 → ⚔9 → ⚔12 while we watched). Every intent and status chip has a hover tooltip ("Strategic — this enemy intends to use a Buff"). Ours is a text line; needs glyph + number + tooltip.
3. **Two enemies, separate intents** = the entire target-priority game. Worth the lift for wolf packs.
4. **Enemy actions are announced by name** ("Spit Web") and statuses land as big floating words ("Weakened") plus a *visible costume on the sprite* (a literal web wrapped the hero). Status = something you SEE.
5. **End Turn glows** when you have nothing useful left to do. BRACE should glow at 0 grit / no playable card. The button also carries a tooltip explaining exactly what ending the turn does — and its text is precisely our BRACE (discard hand, enemies act, draw 5).
6. **Rewards are a claim list** ("Spoils!": 18 Gold / Add a card / Skip arrow), and the card pick shows THREE FULL CARD FACES + explicit Skip button. Our reward text-buttons should become card faces.
7. **Pile viewers show full card faces in a grid**, caption: "(Cards shown are sorted by rarity)" — sorted to hide draw order, same trick we text-listed. Upgrade viewers + compendium to card-face grids.
8. **The shop is a rug** — cards lying on a blanket with price tags, a SALE sticker on one, relics/potions rows, Card Removal Service as its own item, merchant who talks. Our sutler = 5 text buttons; it should be goods laid out on the counter (card faces + engraving icons + Playbill price stamps).
9. **The run opens with a choice** (Neow's blessing: we took MAX HP +8) and a promise ("reach the boss for more"). Cheap ritual, instant investment. A "leaving-Independence blessing" (pick 1 of 3 trail boons) would fit us perfectly.
10. **Fast Mode is a settings checkbox** (their anim-speed toggle), along with "Bigger Text" accessibility. Their map has a Legend scroll. Victory heals via the relic *visibly in the top bar* — numbers you can watch move.
11. Boss is VISIBLE at the top of the map from floor 1 (skull banner). Our Oregon City is on the map — good — but the danger legs should be visible ahead too (our next-leg preview exists; extend to the next 2–3).

## Verdict vs our build
Our combat model (Grit/BRACE) matches theirs almost exactly — the bones are right. The gap is **presentation of information** (glyphs, numbers, statuses-as-sights, card faces everywhere) and the **two missing strategic layers** (keepsakes/relics, tonics/potions) from the main notes above. Nothing observed contradicts the P0/P1/P2 list — it confirms it.
