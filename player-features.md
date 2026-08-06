# Player-Requested Features — The Long Trail

Prioritized checklist of features players consistently demand in roguelike deckbuilders
(sourced from community feedback threads + analysis of the genre leaders). Work top to bottom:
Tier 1 items read as "broken" when missing; Tier 4 items are cheap delight.

## Tier 1 — Table stakes (do these first)
- [ ] **Pile viewers**: clicking the DRAW and DISCARD counters opens a panel listing those cards
      (draw pile order hidden — show it shuffled/sorted). Also a "view full deck" button available
      on every screen. Players refuse to make decisions blind.
- [ ] **Save & quit**: persist the full run state (all vars: deck/hand/piles, route_index, day,
      supplies, morale, wagon_health, grit, event/encounter state, rng position) to
      `user://savegame.json` on quit and on every leg transition; restore on launch with a
      "Continue Journey / New Run" title choice. Losing a 30-minute run to a closed window is
      the #1 uninstall reason in this genre.
- [ ] **Keyword tooltips**: every keyword (Grit, Supplies, Morale, Wagon Condition, card types,
      any status effect) gets a hover tooltip, one sentence, ≤15 words. Godot `tooltip_text`
      is enough. No term may appear anywhere in the UI without one.
- [ ] **Enemy intent with numbers**: encounters always display exactly what the enemy does next
      turn ("⚔ 8 damage") — never vague text. Already partially present; make it a hard rule.
- [ ] **Misclick protection**: pressing CONTINUE JOURNEY with unspent Grit AND a playable card in
      hand asks one confirm ("Leave 2 Grit unspent?"). One consistent input everywhere: single
      click plays a card; never mixed click/drag.

## Tier 2 — Quality of life
- [ ] **Animation speed toggle** (1x / 2x / instant) in a small settings corner; persist choice.
- [ ] **Run history**: append each finished run to `user://history.json` (date, days survived,
      miles, cause of death or victory, final deck list); show last 10 on a title-screen panel.
- [ ] **Skip reward compensation**: skipping a card reward grants a small consolation (+$ or +2 supplies)
      so skipping is a strategy, not a punishment.
- [ ] **Effect preview**: card text shows computed values with current modifiers, not base values
      ("Deal 6 → 9" when strengthened).

## Tier 3 — Replayability (the 100-hour engine)
- [ ] **Unlocks**: 6-10 cards and a few events start locked; each finished run (win or lose)
      unlocks one, with a "NEW CARD UNLOCKED" moment on the death/victory screen. Track in
      `user://profile.json`.
- [ ] **Difficulty as rule modifiers (both directions)** — StS-style: every difficulty step is ONE
      named rule change the player can read in a sentence. Title screen offers three presets plus
      a custom mode:

      **Greenhorn (casual)** — pick-your-comfort toggles, any combination, framed as wagon
      outfitting (never as "easy mode"):
      - "Well-Stocked Wagon" — start with +20 supplies
      - "Feather Beds" — camps heal 50% more
      - "Green Country" — enemies have −20% health
      - "Steady Oxen" — supplies drain 1 less per day
      - "Second Wind" — the first time the party would die, wake at the last landmark instead
        (once per run)
      - "Scout's Almanac" — event choices show their exact odds ("50% chance: lose 12 HP")
      Casual runs keep ALL unlocks and progression — never lock content behind difficulty;
      just tag the run history entry with the modifiers used.

      **Pioneer (standard)** — the game as designed, no modifiers.

      **Trailblazer 1..10 (the ladder)** — unlocked by first victory; each level ADDS one named
      hardship on top of the previous ones:
      1 "Harsh Winter: camps heal −25%" · 2 "Thin Air: supplies drain +1/day" ·
      3 "Outlaw Country: +1 encounter per act" · 4 "Lean Times: card rewards offer 2 choices" ·
      5 "Tainted Water: start each act with 2 fewer max morale" · 6 "Grudge: elites hit +20%" ·
      7 "Worn Axles: wagon starts at 80 condition" · 8 "No Credit: shop prices +20%" ·
      9 "Fever Season: first event each act is always sickness" · 10 "The Long Dark: boss has +25% HP"
      Beating a level unlocks the next; title screen shows highest cleared.

      **Custom Trail** — after first victory: free mix of ANY modifiers from both lists, for
      players who want their exact game. Custom runs are tagged in history.

      Implementation: one `run_modifiers` dictionary checked at the few affected sites
      (heal amount, drain rate, enemy HP multiplier, shop price multiplier...) — same
      stacking-modifier pattern Balatro uses for stakes (see DESIGN-NOTES.md).
- [ ] **Seeded runs + daily challenge**: route/event/shop rolls from named RNG streams seeded by
      a run seed (see DESIGN-NOTES.md, Balatro pattern). "Daily Trail" = seed from today's date,
      one attempt, score shown. Display seed on death screen; allow entering a seed manually.
- [ ] **Second character** (later, biggest lift): a second starting deck + identity, e.g. the Doctor
      (morale/heal engine) vs the default Gunslinger (combat engine).

## Tier 4 — Delight (cheap, review-bait)
- [ ] **Rich death screen**: tombstone, cause of death ("died of dysentery" must remain possible),
      days/miles, stats, final deck. Screenshot-friendly layout.
- [ ] **Enemy variety pacing**: no enemy appears more than twice per act; add 1-2 variants per
      enemy (same art, one changed move) before adding new art.
- [ ] **Compendium**: title-screen collection browser of every card/relic/enemy seen so far
      (locked ones as silhouettes).

## Rules that apply to everything above
- Every cost and reward disclosed before the player clicks (already project law — keep it).
- New interactive elements get probe_ handles like existing ones (automation/playtests).
- New keywords go into the tooltip system in the same commit that introduces them.
- Playtest each checkbox in a real run before marking it done.
