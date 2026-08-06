# The Long Trail / Westward — Design Bible

Distilled from deep reads of Balatro's Lua source, Slay the Spire's full content database, and a survey of the map/exploration systems in Forty-Five, Roguebook, Inscryption, Across the Obelisk, Loop Hero, and Monster Train (all from the owner's legally-owned copies). Patterns and numbers only — no copied names, text, or assets.

A playable HTML reference prototype lives at `Desktop\Apps\westward\index.html` (combat, map travel, shops, camps, events, tonics, upgrades — frontier-letterpress art direction).

## Vision
Slay-the-Spire-grade card combat + Balatro-grade economy/engine-building, inside an explorable Oregon Trail overworld (1848). Art direction: frontier letterpress — cream paper, black ink engravings, wood-type headlines, one red spot color.

## Core exchange rates (from StS — calibrate every card against these)
- 1 energy ("Grit") ≈ 6–9 single-target damage ≈ 5–8 block ≈ 2–3 card draw
- AoE damage ≈ 70–80% of single-target rate
- Starter cards priced 25–35% UNDER rate (6 dmg / 5 block) so every found card feels like an upgrade
- Riders (draw 1, small debuff) cost ~2–3 damage of budget; drawbacks REFUND budget (exhaust ≈ +30–60% rate, lose-HP ≈ +2.5–3 dmg per HP, junk-card-shuffle ≈ +4–6)
- Mono-effect cards overpay (~110–130% rate); split effects pay flexibility tax
- 0-cost cards always carry exhaust/condition/tiny numbers (infinite-combo tax)
- Delayed damage (poison) cheaper per point than instant: ~5–7 per energy
- Consumables (tonics) get 1.5–2× card rate because action-free and scarce; healing lives in consumables/relics, NOT cards

## Upgrade grammar (StS)
An upgrade changes EXACTLY ONE line: +2..+5 damage (bigger base → bigger delta), +2..+4 block, magic number +1 (draw/stacks/energy), cost −1 (tempo upgrade for expensive cards), DELETE a drawback line, or ADD one keyword. Never two unrelated changes.

## Relic tiers (StS)
Same expected value per tier, different condition count: common = unconditional trickle; uncommon = one condition ("every 3rd attack…"); rare = build-around rule-bend; boss = big constant benefit + structural cost ("+1 energy but can't heal at camps"); event relics = narrated tradeoffs. Counter-curse economy: relics that monetize your junk cards create builds out of punishments.

## Event grammar (StS)
Five currencies: HP, Max HP, gold, deck quality (add/remove/transform/upgrade), curses. Sentence templates: pay HP → deck improvement; pay gold → surgery/healing; accept curse → outsized reward (curse names the sin); % gamble with escalating stakes on repeat; fight now → guaranteed rare; KEY-ITEM UNLOCKS (item from one event opens a hidden branch in a later event — show the locked option); permanent-rule sacrifice → run-scale power. Always a free [Leave]. Costs and rewards always disclosed and color-coded.

## Enemy design (StS)
Every player strategy gets an enemy tax: skill-punisher, power-punisher, card-count punisher, hit-count shield, anti-big-hit flight, kill-punisher (on-death debuff). Archetypes: scaler (race clock), punisher (reactive), debuffer, guard/fortress with mode shift, split/summon/leader, charge→nuke telegraph, gold thief, support healer. ALL intents telegraphed with exact numbers — skill = reacting to known information.

## Balatro engine architecture (build the combat engine this way)
1. ONE serializable game-state object = whole run (save/load/undo/seeded daily runs free).
2. Content as data: every card/relic/enemy is a flat config record {id, rarity, cost, config:{numbers}, gates}; behavior = one function keyed by id.
3. Context-callback effect system: engine fires `calculateEffect(entity, context)` at ~25 named lifecycle moments (beforeScoring, perCardScored, endOfTurn, onDiscard, onBuy, onSell, endOfCombat…); effects return plain data ({multMod:4, dollars:3, repetitions:1}) that the CALLER applies. Scoring order lives in one function.
4. Event queue for animation sequencing: logic enqueues mutations; renderer consumes at game speed.
5. Named-seed RNG streams per purpose ('shop'+ante, 'boss', 'rarity') → deterministic runs.
6. Debuff = universal off-switch flag checked in every getter.
7. Pool flags & gates: content appears only when relevant (payoff cards gated on owning the enabler) — makes shops feel curated.

## Balatro economy numbers (adapt)
- Interest: $1 per $5 held, cap $5/round (≈20%/round capped at ~1 fight reward) — creates save-vs-spend tension; raiseable cap via upgrades
- Reroll: base $5, +$1 per reroll, resets each shop
- Shop rarity roll: 70% common / 25% uncommon / 5% rare; no duplicates of owned
- Skip-a-fight tags: EV ≈ fight reward, trading tempo for specialization
- Difficulty knobs that stack (stakes): remove small rewards → harder scaling → unsellable items → decaying items
- Requirement curve ×1.5–2.7 per act step vs. linear-ish player growth = the engine-building pressure

## Exploration merge (the sweep's findings)
- **Towns-and-roads topology (Forty-Five)**: landmarks (Independence, Fort Kearny, Chimney Rock, Fort Laramie, Independence Rock, South Pass, Fort Hall, Snake River, Blue Mountains, The Dalles, Barlow Pass, Oregon City) = small hand-authored persistent hub maps (NPCs with completed-flags, shops); trail segments between = procedurally generated node graphs. Bidirectional edges — backtracking allowed at a cost (days/supplies). Map data model: `{nodes:[{x,y,edgesTo:[],event:{type,...state}}], startNode, endNode, progress:[from%,to%]}`.
- **Segment pacing baseline (Forty-Five's generated roads)**: ~70% fights, ~13% card rewards, ~8% heals, 1 shop, boss/crossing at end; ~13-node DAG 2–3 wide (Inscryption's grid model).
- **Fog-of-war scouting economy (Roguebook)**: segments start hidden; reveals cost a resource with different SHAPES per tool (spyglass = 3-node line, guide = radius 2, butte lookout = big radius from that node, rumor = 1 node anywhere). Wagon upgrades modify the economy (+1 reveal, show all loot of a type). Uncertainty becomes a spendable currency.
- **Nested sub-maps**: cave/fort interior = own tiny node graph via paired entry/exit events. Cheap depth.
- **Progress contract**: every segment owns a slice of the 2,000-mile bar; classic Oregon Trail progress meter = run-length UI.
- Optional combat spatiality (Monster Train): raiders board rear wagon, advance one wagon per turn toward the family wagon.

## Writing/tooltip discipline (StS)
Keyword defs ≤15 words. Five trigger frames: "At the start/end of turn, X" / "Whenever you Y, Z" / "The first time … each combat" / "Every N times you Y, Z" / "If [cond], X, else Y". Computed numbers always displayed on the card. Reward green / cost red, both disclosed before clicking.
