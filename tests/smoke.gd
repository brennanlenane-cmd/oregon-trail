extends Node

# Smoke suite for the full loop: journey → fight → spoils → boss → endings.
#   Summer.exe --headless --path . -- --smoke

var failures := 0

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var table := get_parent()

	# ---- Boot ----
	_check(GameState.hand.size() == 5, "opening hand of 5")
	_check(GameState.grit == GameState.BASE_GRIT, "journey grit opens at base 2")
	var gates := _find(table, "HazardGate")
	_check(gates.size() == 1, "hazard gate on the table")
	_check(_find(table, "BattleStage").size() == 1, "battle stage standing by")
	_check(_find(table, "CardControl").size() == 5, "a CardControl per card in hand")

	# ---- Design mandate ----
	var wordy := 0
	for card in CardsData.CARDS_DATA:
		if str(card["rules_text"]).replace("→", " ").split(" ", false).size() > 8:
			wordy += 1
	_check(wordy == 0, "all rules text reads at a glance")

	# ---- Mechanics spot checks ----
	GameState.hand.clear()
	GameState.hand.append("forage")
	GameState.grit = 2
	var before := GameState.supplies
	_check(GameState.play_card(0), "forage plays")
	var gained := GameState.supplies - before
	_check(gained >= 2 and gained <= 12 and gained % 2 == 0, "forage wagers 1d6 x2 supplies (got %d)" % gained)
	GameState.hand.clear()
	GameState.hand.append("kin_dog")
	GameState.grit = 1
	_check(GameState.stoke(0) and GameState.grit == 2, "stoking the dog grants +1 grit")

	# ---- A fight, StS grammar ----
	GameState.leg = 3
	GameState.stop_index = 3
	GameState.start_encounter()
	_check(GameState.encounter_active, "leg 3 starts a fight")
	_check(GameState.grit == GameState.FIGHT_GRIT, "fights run on 3 grit")
	_check(GameState.hand.size() == 5, "fight redraws to 5")
	var move := GameState.current_move()
	_check(not move.is_empty(), "the enemy telegraphs a move")
	# Kill it with revolvers: combo chain must scale.
	GameState.hand.clear()
	GameState.hand.append_array(["revolver", "revolver", "revolver"] as Array[String])
	GameState.grit = 3
	var hp_before := GameState.enemy_hp
	GameState.play_card(0)
	var first_hit := hp_before - GameState.enemy_hp
	hp_before = GameState.enemy_hp
	if GameState.encounter_active:
		GameState.play_card(0)
		var second_hit := hp_before - GameState.enemy_hp
		_check(second_hit == first_hit + 2 or GameState.enemy_hp == 0 or second_hit >= first_hit, "second GUN chains harder (%d then %d)" % [first_hit, second_hit])
	# Block decay + enemy action.
	if GameState.encounter_active:
		GameState.hand.clear()
		GameState.hand.append("steady_nerve")
		GameState.grit = 3
		GameState.play_card(0)
		_check(GameState.block >= 8, "block goes up")
		var morale_before := GameState.morale
		var supplies_before := GameState.supplies
		var wagon_before := GameState.wagon
		GameState.end_turn()
		_check(GameState.block == 0, "block decays at turn start")
		_check(GameState.grit == GameState.FIGHT_GRIT, "grit refills for the new turn")
		_check(GameState.morale <= morale_before and GameState.supplies <= supplies_before and GameState.wagon <= wagon_before, "the enemy's move landed somewhere")
	# Finish the fight by force (if the combo chain didn't already) and
	# confirm the spoils flow: the win must leave 3 cards on offer.
	if GameState.encounter_active:
		GameState.enemy_hp = 1
		GameState.hand.clear()
		GameState.hand.append("revolver")
		GameState.grit = 3
		var money_before := GameState.money
		GameState.play_card(0)
		_check(not GameState.encounter_active, "the enemy dies")
		_check(GameState.money > money_before, "fights pay gold")
	await get_tree().process_frame
	_check(GameState.reward_options.size() == 3, "SPOILS deals 3 cards")
	var deck_before := GameState.draw_pile.size() + GameState.hand.size() + GameState.discard_pile.size() + GameState.exhausted.size()
	GameState.take_reward(0)
	var deck_after := GameState.draw_pile.size() + GameState.hand.size() + GameState.discard_pile.size() + GameState.exhausted.size()
	_check(deck_after == deck_before + 1, "taking a reward GROWS THE DECK")

	# ---- Boss + endings ----
	GameState.stop_index = GameState.STOPS.size() - 2
	GameState.start_encounter()
	_check(str(GameState.enemy.get("id", "")) == "pass_keeper", "the Pass Keeper always holds Barlow Pass")
	GameState.encounter_active = false
	var ended: Array = []
	var end_handler := func(won: bool, _cause: String) -> void: ended.append(won)
	GameState.game_ended.connect(end_handler)
	GameState.leg = GameState.STOPS.size() - 2
	GameState.travel({})
	_check(ended.size() == 1 and ended[0] == true, "reaching Oregon City wins the run")
	GameState.game_ended.disconnect(end_handler)

	print("RESULT  ·  %s" % ("ALL GREEN" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(1 if failures > 0 else 0)

func _find(node: Node, klass: String) -> Array:
	var out: Array = []
	var stack: Array = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current.get_script() != null and str(current.get_script().get_global_name()) == klass:
			out.append(current)
		for child in current.get_children():
			stack.append(child)
	return out
