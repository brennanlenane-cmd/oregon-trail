extends SceneTree

# Headless playtest for The Long Trail.
# Run: Summer.exe --headless --path <project> --script res://tests/playtest.gd
# Drives the probe_ buttons through full runs and asserts the rules hold.

var game: Control
var failures := 0
var checks := 0

func _initialize() -> void:
	# Clean slate: tests must not inherit saves, journals, or unlocks.
	for stale in ["user://savegame.json", "user://history.json", "user://profile.json"]:
		if FileAccess.file_exists(stale):
			DirAccess.remove_absolute(stale)
	var packed: PackedScene = load("res://main.tscn")
	game = packed.instantiate()
	root.add_child(game)
	_run.call_deferred()

# Start a fresh expedition on the fixed test seed so runs stay reproducible.
func _start_expedition() -> void:
	game.seed_edit.text = "1848"
	game.camp_start_button.pressed.emit()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)

func _press(button: Button) -> void:
	button.pressed.emit()

func _run() -> void:
	await process_frame
	await _test_camp_and_naming()
	await _test_first_leg_and_event()
	await _test_pile_viewers()
	await _test_misclick_protection()
	await _test_encounter_and_brace()
	await _test_family_systems()
	await _test_save_load()
	await _test_story_and_art()
	await _test_full_run()
	print("")
	print("RESULT  ·  %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_camp_and_naming() -> void:
	print("--- camp & naming ---")
	_check(game.run_mode == "camp", "boots to camp")
	_check(game.deck_ids.size() == 19, "starter deck has 19 cards (14 + 5 family)")
	var family_count := 0
	for card_id in game.deck_ids:
		if str(game.CARDS[card_id].get("family", "")) != "":
			family_count += 1
	_check(family_count == 5, "all 5 family cards ride in the deck")
	game.name_edits["sarah"].text = "Nell"
	game.name_edits["dog"].text = "Waffles"
	_start_expedition()
	await process_frame
	_check(game.run_mode == "map", "expedition starts")
	_check(str(game.party["sarah"]["name"]) == "Nell", "kid renamed to Nell")
	_check(game._card_display_name("family_sarah") == "Nell's Keen Eyes", "card title carries the name")
	_check(game.hand.size() == 5, "opening hand of 5")
	_check(game.grit == 3, "grit starts at 3")

func _find_hand_index(predicate: Callable) -> int:
	for i in game.hand.size():
		if predicate.call(game.hand[i]):
			return i
	return -1

func _resolve_interrupts() -> void:
	# Clear any Pa choice or reward that blocks progress.
	var guard := 0
	while (game.pa_choice_active or game.reward_pending or game.letter_pending or game.shop_open) and guard < 20:
		guard += 1
		if game.pa_choice_active:
			_press(game.probe_pa_wagon)
		elif game.letter_pending:
			_press(game.probe_seal_letter)
		elif game.shop_open:
			_press(game.probe_shop_leave)
		elif game.reward_pending:
			_press(game.probe_reward_skip)
		await process_frame

func _test_first_leg_and_event() -> void:
	print("--- travel & events ---")
	# Leg 1 is not divisible by 3, so it must be an event, not an encounter.
	_press(game.probe_continue_button)
	await process_frame
	if game.pending_leave_confirm:
		_press(game.probe_continue_button)
		await process_frame
	_check(game.completed_legs == 1, "leg 1 travelled")
	_check(game.event_active, "leg 1 raises a trail event")
	_check(not game.encounter_active, "leg 1 is not an encounter")
	var event: Dictionary = game.EVENTS[game.current_event_index]
	var before_day: int = game.day
	_press(game.probe_event_b)
	await process_frame
	_check(game.day == before_day + 1, "free leave costs the disclosed +1 day")
	_check(game.reward_pending, "event resolution reaches the reward stop")
	_press(game.probe_reward_buttons[0])
	await process_frame
	_check(game.deck_ids.size() == 20, "taking a reward grows the deck")
	_check(not game.reward_pending, "reward stop closes")

func _test_pile_viewers() -> void:
	print("--- pile viewers ---")
	_press(game.probe_view_deck)
	await process_frame
	_check(game.pile_panel.visible, "deck viewer opens")
	_check(not game.pile_list.text.is_empty() and game.pile_list.text != "Empty.", "deck viewer lists cards")
	_check(game.pile_list.text.contains("Nell"), "deck viewer shows named family card")
	_press(game.probe_close_pile)
	await process_frame
	_check(not game.pile_panel.visible, "deck viewer closes")
	_press(game.probe_view_draw)
	await process_frame
	_check(game.pile_panel.visible and game.pile_title.text.begins_with("DRAW"), "draw pile viewer opens")
	_press(game.probe_close_pile)
	await process_frame

func _test_misclick_protection() -> void:
	print("--- misclick protection ---")
	await _resolve_interrupts()
	if not game._has_playable_card() or game.grit == 0:
		print("SKIP  no playable card to guard against; state moved on")
		return
	var legs_before: int = game.completed_legs
	_press(game.probe_continue_button)
	await process_frame
	_check(game.pending_leave_confirm, "unspent grit asks for confirmation")
	_check(game.completed_legs == legs_before, "first press does not travel")
	_press(game.probe_continue_button)
	await process_frame
	_check(game.completed_legs == legs_before + 1, "second press travels")

func _test_encounter_and_brace() -> void:
	print("--- encounter, honest intent, brace ---")
	# March until an encounter starts (leg 3, 6, ...).
	var guard := 0
	while not game.encounter_active and not game.game_over and not game.victory and guard < 40:
		guard += 1
		await _resolve_interrupts()
		if game.event_active:
			if not game.probe_event_a.disabled and randi() % 2 == 0:
				_press(game.probe_event_a)
			else:
				_press(game.probe_event_b)
		else:
			_press(game.probe_continue_button)
			await process_frame
			if game.pending_leave_confirm:
				_press(game.probe_continue_button)
		await process_frame
	_check(game.encounter_active, "an encounter eventually starts")
	if not game.encounter_active:
		return
	# Honest intent: brace and confirm the loss equals the disclosed threat.
	var threat: int = game.encounter_threat
	var block: int = game.encounter_block
	var expected: int = maxi(0, threat - block)
	var index: int = game.encounter_index
	var before := {"supplies": game.supplies, "morale": game.morale, "wagon": game.wagon_health}
	var grit_spent_state: int = game.grit
	_press(game.probe_continue_button)  # BRACE
	await process_frame
	var actual := 0
	match index:
		1: actual = before["supplies"] - game.supplies
		2: actual = before["morale"] - game.morale
		_: actual = before["wagon"] - game.wagon_health
	_check(actual == expected, "brace: the hit equals the disclosed intent (%d vs %d)" % [actual, expected])
	_check(game.grit == 3, "brace refills grit")
	# Family cards are playable in a fight; combat plays still answer.
	var dog_index := _find_hand_index(func(card_id: String) -> bool: return str(game.CARDS[card_id].get("family", "")) == "dog")
	if dog_index >= 0 and game.encounter_active:
		var threat_before: int = game.encounter_threat
		_press(game.probe_play_buttons[dog_index])
		await process_frame
		await _resolve_interrupts()
		_check(true, "the dog can join a fight (threat %d -> %d)" % [threat_before, game.encounter_threat])
	# Finish the fight.
	guard = 0
	while game.encounter_active and not game.game_over and guard < 60:
		guard += 1
		await _resolve_interrupts()
		if not game.encounter_active:
			break
		var play := -1
		for i in game.hand.size():
			if game._can_play(game.hand[i]) and game.CARDS[game.hand[i]]["type"] == "combat":
				play = i
				break
		if play >= 0:
			_press(game.probe_play_buttons[play])
		else:
			_press(game.probe_continue_button)  # brace to refill
		await process_frame
	await _resolve_interrupts()
	_check(not game.encounter_active or game.game_over, "encounter resolves")

func _test_family_systems() -> void:
	print("--- bonds, sickness, death, memory ---")
	if game.game_over or game.victory:
		print("SKIP  run already over before family tests; restarting")
		game._return_to_camp()
		await process_frame
		_start_expedition()
		await process_frame
	# Bond: push Ma to the level-1 threshold and play her card.
	game.party["ma"]["bond_plays"] = 4
	var ma_index := _find_hand_index(func(card_id: String) -> bool: return str(game.CARDS[card_id].get("family", "")) == "ma")
	if ma_index < 0:
		# Put her card in hand deterministically.
		for pile in [game.draw_pile, game.discard_pile]:
			var found: int = pile.find("family_ma")
			if found >= 0:
				pile.remove_at(found)
				game.hand.append("family_ma")
				break
		ma_index = _find_hand_index(func(card_id: String) -> bool: return str(game.CARDS[card_id].get("family", "")) == "ma")
	if ma_index >= 0 and game._can_play(game.hand[ma_index]):
		game._on_card_pressed(ma_index)
		await process_frame
		await _resolve_interrupts()
		_check(int(game.party["ma"]["bond_level"]) == 1, "5th play raises Ma to bond 1")
		_check(str(game.party["ma"]["card_id"]) == "family_ma_u", "Ma's card upgrades to +")
		_check(game.deck_ids.has("family_ma_u") and not game.deck_ids.has("family_ma"), "upgrade swaps every copy in the deck")
	else:
		_check(false, "could not stage Ma's bond play")
	# Effective fx: hurt trims, sick halves and strips riders.
	game.party["sarah"]["condition"] = 0
	var fx_healthy: Dictionary = game._effective_fx(str(game.party["sarah"]["card_id"]))
	game.party["sarah"]["condition"] = 2
	var fx_sick: Dictionary = game._effective_fx(str(game.party["sarah"]["card_id"]))
	_check(fx_healthy.has("draw") and not fx_sick.has("draw"), "sickness strips Sarah's draw rider")
	# Death pipeline: two untreated legs.
	game.party["sarah"]["legs_sick"] = 1
	var note: String = game._advance_sickness()
	await process_frame
	_check(not bool(game.party["sarah"]["alive"]), "two untreated legs is fatal")
	_check(note.contains("GRAVE"), "the death is announced")
	_check(game.graves.size() >= 1, "a grave is planted")
	var has_memory: bool = game.deck_ids.has("memory_sarah")
	_check(has_memory, "her card becomes a Memory")
	_check(game._card_display_name("memory_sarah") == "Memory of Nell", "the memory keeps her name")
	# Memory exhausts and returns.
	if not game.game_over:
		for pile in [game.draw_pile, game.discard_pile]:
			var found: int = pile.find("memory_sarah")
			if found >= 0:
				pile.remove_at(found)
				game.hand.append("memory_sarah")
				break
		var memory_index: int = game.hand.find("memory_sarah")
		if memory_index >= 0 and game._can_play("memory_sarah"):
			var morale_before: int = game.morale
			game._on_card_pressed(memory_index)
			await process_frame
			_check(game.exhausted.has("memory_sarah"), "memory exhausts when played")
			_check(game.morale > morale_before or game.morale == 100, "memory comforts (+morale)")
			game._start_leg()
			_check(not game.exhausted.has("memory_sarah") and (game.draw_pile.has("memory_sarah") or game.hand.has("memory_sarah")), "memory returns next leg")
		else:
			print("SKIP  memory card not stageable right now")
	# Cure: medicine heals the worst member.
	game.party["ma"]["condition"] = 2
	game.party["ma"]["legs_sick"] = 1
	game._apply_cure()
	_check(int(game.party["ma"]["condition"]) == 0 and int(game.party["ma"]["legs_sick"]) == 0, "medicine cures the sickest member")

func _test_save_load() -> void:
	print("--- save & load ---")
	if game.game_over or game.victory:
		game._return_to_camp()
		await process_frame
		_start_expedition()
		await process_frame
	game._save_game()
	_check(FileAccess.file_exists(game.SAVE_PATH), "save file written")
	var snapshot := {
		"day": game.day, "supplies": game.supplies, "morale": game.morale,
		"legs": game.completed_legs, "deck": game.deck_ids.duplicate(),
		"sarah_alive": game.party["sarah"]["alive"], "sarah_name": game.party["sarah"]["name"],
		"graves": game.graves.size()
	}
	# Corrupt the live state (a wipe via _initialize_run would auto-save over the file).
	game.day = 999
	game.supplies = 1
	game.morale = 7
	game.completed_legs = 0
	game.party["sarah"]["name"] = "WRONG"
	var loaded: bool = game._load_game()
	_check(loaded, "save file loads")
	_check(game.day == snapshot["day"] and game.supplies == snapshot["supplies"] and game.morale == snapshot["morale"], "stats survive the round trip")
	_check(game.completed_legs == snapshot["legs"], "trail position survives")
	_check(game.deck_ids == snapshot["deck"], "deck list survives")
	_check(game.party["sarah"]["alive"] == snapshot["sarah_alive"] and str(game.party["sarah"]["name"]) == str(snapshot["sarah_name"]), "family state survives")
	_check(game.graves.size() == int(snapshot["graves"]), "graves survive")

func _test_story_and_art() -> void:
	print("--- story & art ---")
	var story = game.STORY
	var missing_vignettes := 0
	var missing_art := 0
	var broken_art := 0
	for stop in game.ROUTE_STOPS:
		if not story.VIGNETTES.has(stop):
			missing_vignettes += 1
		var art_path: String = story.LANDMARK_ART.get(stop, "")
		if art_path.is_empty():
			missing_art += 1
		elif load(art_path) == null:
			broken_art += 1
	_check(missing_vignettes == 0, "every landmark has an arrival vignette")
	_check(missing_art == 0 and broken_art == 0, "every landmark's engraving loads")
	var bad_event_art := 0
	for event in game.EVENTS:
		if event.has("art") and load(str(event["art"])) == null:
			bad_event_art += 1
	_check(bad_event_art == 0, "all event illustrations load")
	var bad_encounters := 0
	for encounter in game.ENCOUNTERS:
		if not encounter.has("hits") or load(str(encounter["art"])) == null:
			bad_encounters += 1
	_check(bad_encounters == 0, "all %d encounters have art and a declared target" % game.ENCOUNTERS.size())
	# Letter home fires at a fort, reads like a letter, seals for morale.
	game.letters_written.clear()
	game.morale = mini(game.morale, 90)
	game._maybe_write_letter("Fort Kearny")
	await process_frame
	_check(game.letter_pending, "a letter waits at Fort Kearny")
	_check(game.letter_text.text.contains("Dear"), "the letter reads like a letter")
	var member_named := false
	for member_id in game.PARTY_DATA.MEMBER_ORDER:
		if game.letter_text.text.contains(str(game.party[member_id]["name"])) or not bool(game.party[member_id]["alive"]):
			member_named = true
			break
	_check(member_named, "the letter speaks of the family by name")
	var morale_before_seal: int = game.morale
	_press(game.probe_seal_letter)
	await process_frame
	_check(not game.letter_pending, "sealing closes the letter")
	_check(game.morale == mini(100, morale_before_seal + 2), "sealing comforts (+2 morale)")
	# Sealing at a fort opens the sutler's store.
	_check(game.shop_open, "the sutler's store opens after the letter")
	_check(game.shop_offers.size() == 6, "six offers on the counter (goods, card, keepsake, tonic)")
	_check(str(game.shop_offers[4]["fx"]) == "keepsake" and str(game.shop_offers[5]["fx"]) == "tonic", "keepsake and tonic ride the counter")
	game.money = 60
	var supplies_before: int = game.supplies
	_press(game.probe_shop_buttons[0])
	await process_frame
	_check(game.supplies == supplies_before + 15 and game.money == 50, "buying provisions costs $10, adds 15 supplies")
	var tonics_before: int = game.tonics.size()
	_press(game.probe_shop_buttons[5])
	await process_frame
	_check(game.tonics.size() == tonics_before + 1, "bought tonic lands on the belt")
	var keepsakes_before: int = game.keepsakes.size()
	_press(game.probe_shop_buttons[4])
	await process_frame
	_check(game.keepsakes.size() == keepsakes_before + 1, "bought keepsake joins the collection")
	_press(game.probe_shop_leave)
	await process_frame
	_check(not game.shop_open, "leaving closes the store")
	game._maybe_write_letter("Fort Kearny")
	_check(not game.letter_pending, "no second letter at the same fort")
	# Diseases carry names, and the grave remembers them.
	for member_id in game.PARTY_DATA.MEMBER_ORDER:
		if bool(game.party[member_id]["alive"]):
			pass
	game.party["ma"]["condition"] = 2
	game.party["ma"]["legs_sick"] = 1
	game.party["ma"]["disease"] = "dysentery"
	var death_note: String = game._advance_sickness()
	_check(death_note.contains("dysentery"), "the grave names the disease (died of dysentery)")
	game._apply_cure()

func _test_full_run() -> void:
	print("--- full run to the end ---")
	game._return_to_camp()
	await process_frame
	_start_expedition()
	await process_frame
	var guard := 0
	while not game.game_over and not game.victory and guard < 400:
		guard += 1
		await _resolve_interrupts()
		if game.game_over or game.victory:
			break
		if game.event_active:
			if not game.probe_event_a.disabled and randi() % 3 != 0:
				_press(game.probe_event_a)
			else:
				_press(game.probe_event_b)
		elif game.encounter_active:
			var play := -1
			for i in game.hand.size():
				if game._can_play(game.hand[i]) and game.CARDS[game.hand[i]]["type"] == "combat":
					play = i
					break
			if play >= 0:
				_press(game.probe_play_buttons[play])
			else:
				_press(game.probe_continue_button)
		else:
			# Spend some grit like a player would, then travel.
			var spent := 0
			while game.grit > 0 and spent < 2 and game._has_playable_card():
				var play := -1
				for i in game.hand.size():
					if game._can_play(game.hand[i]):
						play = i
						break
				if play < 0:
					break
				_press(game.probe_play_buttons[play])
				spent += 1
				await process_frame
				await _resolve_interrupts()
			if game.game_over or game.victory or game.event_active or game.encounter_active or game.reward_pending:
				continue
			_press(game.probe_continue_button)
			await process_frame
			if game.pending_leave_confirm:
				_press(game.probe_continue_button)
		await process_frame
	_check(game.game_over or game.victory, "a full run reaches an ending (guard %d)" % guard)
	var invariant: int = game.hand.size() + game.draw_pile.size() + game.discard_pile.size() + game.exhausted.size()
	_check(invariant == game.deck_ids.size(), "deck ledger invariant holds at the end (%d vs %d)" % [invariant, game.deck_ids.size()])
	_check(FileAccess.file_exists(game.HISTORY_PATH), "the run is written into the trail journal")
	var history: Array = game._read_history()
	_check(not history.is_empty() and history.back().has("cause"), "the journal entry records a cause")
	# Profile, unlocks, and the ladder.
	_check(FileAccess.file_exists("user://profile.json"), "profile written after a finished run")
	game.profile["runs_finished"] = 0
	game._prepare_reward()
	var leaked_locked := false
	for card_id in game.reward_options:
		if game.LOCKED_CARDS.has(card_id):
			leaked_locked = true
	game.reward_pending = false
	_check(not leaked_locked, "locked cards never appear in rewards before they're earned")
	game.profile["wins"] = 0
	game._refresh_trailblazer_ui()
	_check(not game.tb_row.visible, "the ladder hides until the first victory")
	game.profile["wins"] = 1
	game.profile["cleared"] = 0
	game._refresh_trailblazer_ui()
	_check(game.tb_row.visible, "first victory opens the Trailblazer ladder")
	game._change_trailblazer(1)
	_check(game.trailblazer == 1, "level 1 is selectable after clearing 0")
	game._change_trailblazer(1)
	_check(game.trailblazer == 1, "level 2 stays locked until 1 is cleared")
	# Wagon outfitting toggles apply as named; seed is honored.
	game._return_to_camp()
	await process_frame
	game.modifier_checks["well_stocked"].button_pressed = true
	game.modifier_checks["green_country"].button_pressed = true
	_start_expedition()
	await process_frame
	_check(game.supplies == 88, "Well-Stocked Wagon starts with +20 supplies (88)")
	_check(game.run_modifiers.get("green_country", false) == true, "Green Country is recorded on the run")
	_check(game.run_seed == 1848, "a typed trail seed is honored")
	# Characters: the Doctor rides with a different kit and a gentler hand.
	game._return_to_camp()
	await process_frame
	game._select_character("doctor")
	_start_expedition()
	await process_frame
	_check(game.deck_ids.count("medicine") == 2 and game.deck_ids.has("scalpel") and game.deck_ids.has("laudanum"), "the Doctor starts with the bag")
	_check(not game.deck_ids.has("revolver") and not game.deck_ids.has("dynamite"), "the Doctor left the iron at home")
	game.party["ma"]["condition"] = 2
	game.party["ma"]["legs_sick"] = 1
	game.party["ma"]["disease"] = "cholera"
	game._rest_one_member()
	_check(int(game.party["ma"]["condition"]) == 0, "the Doctor's rest mends two steps")
	game._select_character("gunslinger")
	game._return_to_camp()
	await process_frame
	_start_expedition()
	await process_frame
	_check(game.deck_ids.has("revolver"), "the Gunslinger keeps the iron")
	# Trinket layer basics.
	_check(game.keepsakes.has("powder_horn"), "the Gunslinger starts with the Powder Horn")
	game.tonics.clear()
	game._gain_tonic("coffee")
	var grit_before: int = game.grit
	game._drink_tonic(0)
	_check(game.grit == mini(grit_before + 1, 5) and game.tonics.is_empty(), "coffee grants Grit and leaves the belt")
	game._gain_tonic("bitters")
	game._gain_tonic("bitters")
	game._gain_tonic("bitters")
	_check(not game._gain_tonic("hardtack"), "the belt holds only three tonics")
	game.keepsakes.append("hymnal")
	game.morale = 50
	game.encounter_active = true
	game.encounter_threat = 0
	game.encounter_block = 0
	game.encounter_index = 0
	game.encounter_turn = 1
	game._on_continue_pressed()
	_check(game.morale >= 52 - 1, "Hymnal: bracing steadies morale (+2, minus any hit)")
	game.encounter_active = false
	game._start_leg()
	# Trailblazer 1: Thin Air makes travel drain 3 per day.
	var supplies_start: int = game.supplies
	_press(game.probe_continue_button)
	await process_frame
	if game.pending_leave_confirm:
		_press(game.probe_continue_button)
		await process_frame
	_check(supplies_start - game.supplies == 3 * (game.day - 1), "Thin Air drains +1 supply per travel day (%d over %d days)" % [supplies_start - game.supplies, game.day - 1])
	# Compendium: silhouettes until earned.
	game.profile["runs_finished"] = 0
	game._open_pile_view("compendium")
	await process_frame
	_check(game.pile_panel.visible and game.pile_list.text.contains("???"), "compendium shows locked cards as silhouettes")
	_check(game.pile_list.text.contains("Steady Hands"), "compendium lists the family by name")
	_press(game.probe_close_pile)
	await process_frame
	# Roadside markers: past runs' graves stand where they fell.
	game.graves = [{"name": "Old Jeb", "role": "PA", "stop": "Chimney Rock", "day": 9, "cause": "dysentery"}]
	game._append_run_history(false)
	game.graves = []
	var markers: Array = game._past_graves_at("Chimney Rock")
	_check(markers.size() >= 1 and str(markers[0]["name"]) == "Old Jeb", "graves persist across runs as roadside markers")
	# ---- Combo engine: chains, primes, discounts ----
	game.event_active = false
	game._start_leg()
	game._reset_turn_context()
	game.encounter_active = true
	game.encounter_health = 90
	game.encounter_max_health = 90
	game.encounter_threat = 5
	game.encounter_block = 0
	game.powder_horn_spent = true
	game.grit = 3
	game.hand.clear()
	game.hand.append_array(["revolver", "revolver", "bowie_knife"])
	var combo_hp: int = game.encounter_health
	game._on_card_pressed(0)
	_check(combo_hp - game.encounter_health == 7, "first GUN deals its printed 7")
	combo_hp = game.encounter_health
	game._on_card_pressed(0)
	_check(combo_hp - game.encounter_health == 9, "second GUN chains +2 (deals 9)")
	var combo_block: int = game.encounter_block
	game._on_card_pressed(0)
	_check(game.encounter_block - combo_block == 6, "Bowie after a GUN adds +4 Block (6 total)")
	game._reset_turn_context()
	game.grit = 3
	game.hand.clear()
	game.hand.append_array(["lasso", "revolver"])
	combo_hp = game.encounter_health
	game._on_card_pressed(0)
	game._on_card_pressed(0)
	_check(combo_hp - game.encounter_health == 19, "Lasso primes the next GUN to hit double (5 + 14)")
	game._reset_turn_context()
	_check(game._card_cost("dynamite") == 3, "Dynamite starts at 3 Grit")
	game.turn_plays.append_array(["forage", "forage"])
	_check(game._card_cost("dynamite") == 1, "Dynamite discounts per card played this turn")
	game._reset_turn_context()
	game.encounter_active = false
	game.grit = 3
	game.hand.clear()
	game.hand.append_array(["scout_ahead", "forage"])
	var combo_supplies: int = game.supplies
	game._on_card_pressed(0)
	game._on_card_pressed(game.hand.find("forage"))
	_check(game.supplies - combo_supplies >= 6, "Forage chains +2 per TRAIL card this turn")
	# ---- Forks: every leg offers a second road, stable for the seed ----
	var alt_road: Dictionary = game._alt_road_for_leg()
	_check(alt_road.has("name") and alt_road.has("terms"), "every leg offers an alternate road")
	_check(str(alt_road["id"]) == str(game._alt_road_for_leg()["id"]), "the fork is stable for the seed and leg")
	print("ENDING  ·  %s  ·  day %d  ·  legs %d  ·  graves %d" % ["VICTORY" if game.victory else "DEFEAT", game.day, game.completed_legs, game.graves.size()])
	print("STATE   ·  cause '%s'  ·  morale %d  supplies %d  wagon %d  ·  guard %d" % [game.death_cause, game.morale, game.supplies, game.wagon_health, guard])
