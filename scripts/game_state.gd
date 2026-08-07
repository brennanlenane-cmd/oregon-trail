extends Node

# GameState — the single owner of run state. UI nodes read it and emit intents;
# nothing but this file mutates the run. Every observable change fires a signal.
#
# THE LOOP (ripped honestly from Slay the Spire, reskinned for the trail):
#   leg → hazard gate OR fight → travel drain → SPOILS (gold + pick-1-of-3
#   card, skippable) → next leg. Every 3rd leg fights; Barlow Pass is always
#   the boss. Winter is the clock. Oregon City is the win.
#
# FIGHTS: draw 5, spend 3 grit, END TURN. The enemy telegraphs its next move
# with a live number; buffs push the number up while you watch. Your block
# absorbs the hit, then CLEARS at the start of your turn — defense is a
# per-turn decision, never a stockpile.

signal card_played(card_data: Dictionary)
signal juice_requested(shake_intensity: float, sound_event: String)
signal resources_changed
signal hand_changed
signal wager_rolled(roll: int, busted: bool)
signal kin_stoked(kin_id: String, risk_percent: int)
signal run_started
signal leg_advanced(stop_name: String, is_fight: bool)
signal encounter_updated
signal enemy_acted(move: Dictionary, landed: int)
signal encounter_won(gold: int)
signal rewards_offered(options: Array)
signal status_bites(text: String)
signal game_ended(won: bool, cause: String)

const BASE_GRIT := 2          # journey turns stay lean
const FIGHT_GRIT := 3         # fights run on the StS rhythm
const GRIT_CAP := 5
const STOKE_RISK := 0.10
const WINTER_SOFT_DAY := 80
const WINTER_HARD_DAY := 110
const STOPS := [
	"Independence", "Kansas River", "Fort Kearny", "Chimney Rock", "Fort Laramie",
	"Independence Rock", "South Pass", "Soda Springs", "Fort Hall", "Snake River",
	"Blue Mountains", "The Dalles", "Barlow Pass", "Oregon City"
]

var supplies := 60
var morale := 80
var wagon := 100
var grit := BASE_GRIT
var day := 1
var money := 25
var leg := 0
var stop_index := 0
var travel_bonus := 0
var hazard_revealed := false
var game_over := false

var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhausted: Array[String] = []
var turn_plays: Array[String] = []
var primed: Dictionary = {}
var kin_stoked_counts: Dictionary = {}

# ---- fight state ----
var encounter_active := false
var enemy: Dictionary = {}
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_block := 0
var enemy_strength := 0
var move_cursor := 0
var block := 0
var enemy_hit_this_turn := false
var last_enemy_id := ""

var reward_options: Array[String] = []
var rng := RandomNumberGenerator.new()

func start_run(seed_value: int = 1848) -> void:
	rng.seed = seed_value
	supplies = 60
	morale = 80
	wagon = 100
	day = 1
	money = 25
	leg = 0
	stop_index = 0
	travel_bonus = 0
	game_over = false
	encounter_active = false
	draw_pile.assign(CardsData.STARTER_DECK.duplicate())
	shuffle(draw_pile)
	hand.clear()
	discard_pile.clear()
	exhausted.clear()
	start_leg()
	run_started.emit()
	leg_advanced.emit(next_stop_name(), false)

func next_stop_name() -> String:
	return STOPS[mini(stop_index + 1, STOPS.size() - 1)]

func shuffle(pile: Array[String]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = pile[i]
		pile[i] = pile[j]
		pile[j] = tmp

func start_leg() -> void:
	grit = FIGHT_GRIT if encounter_active else BASE_GRIT
	turn_plays.clear()
	primed.clear()
	kin_stoked_counts.clear()
	for card_id in exhausted:
		if not CardsData.by_id(card_id).get("status", false):
			draw_pile.append(card_id)
	if not exhausted.is_empty():
		exhausted.clear()
		shuffle(draw_pile)
	# Trail junk burns off when the wagon rolls out.
	for pile: Array in [draw_pile, hand, discard_pile]:
		for i in range(pile.size() - 1, -1, -1):
			if CardsData.by_id(pile[i]).get("status", false):
				pile.remove_at(i)
	draw_to(5)
	resources_changed.emit()
	hand_changed.emit()

func draw_to(target: int) -> void:
	while hand.size() < target and draw_one():
		pass

func draw_one() -> bool:
	if draw_pile.is_empty() and not discard_pile.is_empty():
		draw_pile.assign(discard_pile)
		discard_pile.clear()
		shuffle(draw_pile)
	if draw_pile.is_empty():
		return false
	var drawn: String = draw_pile.pop_back()
	hand.append(drawn)
	# Statuses bite the moment they surface.
	var on_draw: Dictionary = CardsData.by_id(drawn).get("on_draw", {})
	if on_draw.has("grit"):
		grit = clampi(grit + int(on_draw["grit"]), 0, GRIT_CAP)
		status_bites.emit("DUST  ·  -1 GRIT")
		juice_requested.emit(2.0, "hit")
	if on_draw.has("exhaust_random"):
		var lost := 0
		var tries := 0
		while lost < int(on_draw["exhaust_random"]) and tries < 20:
			tries += 1
			if hand.size() <= 1:
				break
			var pick := rng.randi_range(0, hand.size() - 1)
			if hand[pick] == drawn or CardsData.by_id(hand[pick]).get("status", false):
				continue
			exhausted.append(hand[pick])
			hand.remove_at(pick)
			lost += 1
		var self_index := hand.find(drawn)
		if self_index >= 0:
			hand.remove_at(self_index)
			exhausted.append(drawn)
		if lost > 0:
			status_bites.emit("THE AXLE GIVES  ·  %d CARDS LOST" % lost)
			juice_requested.emit(3.0, "hit")
	return true

func card_cost(card_id: String) -> int:
	var card := CardsData.by_id(card_id)
	var cost := int(card.get("cost", 0))
	var combo: Dictionary = card.get("mech", {}).get("combo", {})
	if combo.has("discount_per_play"):
		cost = maxi(0, cost - int(combo["discount_per_play"]) * turn_plays.size())
	return cost

func can_play(card_id: String) -> bool:
	var card := CardsData.by_id(card_id)
	if card.get("status", false):
		return false
	var mech: Dictionary = card.get("mech", {})
	# Fight verbs are dead weight on the open trail.
	if not encounter_active and (mech.has("deal") or mech.has("block")) \
			and not (mech.has("wager") and not mech.get("wager", {}).get("per_pip", {}).has("deal")) \
			and not mech.has("cure") and not mech.has("travel_bonus"):
		return false
	return grit >= card_cost(card_id)

func play_card(hand_index: int) -> bool:
	if game_over or hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id: String = hand[hand_index]
	if not can_play(card_id):
		juice_requested.emit(1.0, "click")
		return false
	var card := CardsData.by_id(card_id)
	grit -= card_cost(card_id)
	hand.remove_at(hand_index)
	var mech: Dictionary = card.get("mech", {})
	if mech.get("exhaust", false):
		exhausted.append(card_id)
	else:
		discard_pile.append(card_id)
	_apply_mech(card, mech)
	if mech.get("combo", {}).has("prime_tag"):
		primed[str(mech["combo"]["prime_tag"])] = int(mech["combo"].get("mult", 2))
	turn_plays.append(card_id)
	card_played.emit(card)
	juice_requested.emit(3.0, "card-play")
	if encounter_active and enemy_hp <= 0:
		_win_encounter()
	resources_changed.emit()
	hand_changed.emit()
	return true

func stoke(hand_index: int) -> bool:
	if game_over or hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id: String = hand[hand_index]
	var kin_id := str(CardsData.by_id(card_id).get("kin", ""))
	if kin_id.is_empty():
		return false
	hand.remove_at(hand_index)
	exhausted.append(card_id)
	grit = clampi(grit + 1, 0, GRIT_CAP)
	kin_stoked_counts[kin_id] = int(kin_stoked_counts.get(kin_id, 0)) + 1
	draw_one()
	kin_stoked.emit(kin_id, int(kin_stoked_counts[kin_id]) * int(STOKE_RISK * 100))
	juice_requested.emit(2.0, "card-play")
	resources_changed.emit()
	hand_changed.emit()
	return true

func _apply_mech(card: Dictionary, mech: Dictionary) -> void:
	var tag := str(card.get("tag", ""))
	if mech.has("wager"):
		var wager: Dictionary = mech["wager"]
		var roll := rng.randi_range(1, 6)
		var busted := roll <= int(wager.get("fail_on", 0))
		for stat: String in wager.get("per_pip", {}).keys():
			var amount: int = roll * int(wager["per_pip"][stat])
			if stat == "deal":
				_hit_enemy(amount, tag)
			else:
				_nudge(stat, amount)
		if busted:
			for stat: String in wager.get("fail_fx", {}).keys():
				_nudge(stat, int(wager["fail_fx"][stat]))
			juice_requested.emit(5.0, "hit")
		wager_rolled.emit(roll, busted)
	if mech.has("deal"):
		var amount := int(mech["deal"])
		var combo: Dictionary = mech.get("combo", {})
		if combo.has("per_tag"):
			amount += _turn_tag_count(str(combo["per_tag"])) * int(combo.get("bonus_deal", 0))
		_hit_enemy(amount, tag)
	if mech.has("block") and encounter_active:
		var amount := int(mech["block"])
		var combo: Dictionary = mech.get("combo", {})
		if combo.has("if_tag") and _turn_tag_count(str(combo["if_tag"])) > 0:
			amount += int(combo.get("bonus_block", 0))
		block += amount
		encounter_updated.emit()
	if mech.has("fuel"):
		var fuel: Dictionary = mech["fuel"]
		var burn_index := -1
		var burn_cost := -1
		for i in hand.size():
			var other := CardsData.by_id(hand[i])
			if str(other.get("kin", "")).is_empty() and not other.get("status", false) \
					and int(other.get("cost", 0)) > burn_cost:
				burn_cost = int(other.get("cost", 0))
				burn_index = i
		var gained := int(fuel.get("base", 4))
		if burn_index >= 0:
			discard_pile.append(hand[burn_index])
			hand.remove_at(burn_index)
			gained += burn_cost * int(fuel.get("per_cost", 3))
		_nudge(str(fuel.get("stat", "morale")), gained)
	if mech.has("discard_tag"):
		var want := str(mech["discard_tag"])
		var found := -1
		for i in hand.size():
			if str(CardsData.by_id(hand[i]).get("tag", "")) == want:
				found = i
				break
		var effects: Dictionary = mech.get("gain", {}) if found >= 0 else mech.get("fallback_fx", {})
		if found >= 0:
			discard_pile.append(hand[found])
			hand.remove_at(found)
		for stat: String in effects.keys():
			_nudge(stat, int(effects[stat]))
	elif mech.has("gain") and mech.has("spend"):
		var affordable := true
		for stat: String in mech["spend"].keys():
			if _stat(stat) < int(mech["spend"][stat]):
				affordable = false
		if affordable:
			for stat: String in mech["spend"].keys():
				_nudge(stat, -int(mech["spend"][stat]))
			for stat: String in mech["gain"].keys():
				_nudge(stat, int(mech["gain"][stat]))
	elif mech.has("gain"):
		for stat: String in mech["gain"].keys():
			_nudge(stat, int(mech["gain"][stat]))
	if mech.has("resolve"):
		var resolve: Dictionary = mech["resolve"]
		_nudge("morale", int(resolve["low"]) if morale < int(resolve["threshold"]) else int(resolve["base"]))
	if mech.has("choice"):
		var pick: Dictionary = mech["choice"]["b"] if wagon < 70 else mech["choice"]["a"]
		for stat: String in pick.keys():
			_nudge(stat, int(pick[stat]))
	if mech.has("draw"):
		for i in int(mech["draw"]):
			draw_one()
	if mech.has("travel_bonus"):
		travel_bonus += int(mech["travel_bonus"])
	if mech.has("reveal"):
		hazard_revealed = true

func _turn_tag_count(tag: String) -> int:
	var count := 0
	for played_id in turn_plays:
		if str(CardsData.by_id(played_id).get("tag", "")) == tag:
			count += 1
	return count

func _hit_enemy(amount: int, tag: String) -> void:
	if not encounter_active or amount <= 0:
		return
	if primed.has(tag):
		amount *= int(primed[tag])
		primed.erase(tag)
	# The enemy's guard chews the hit first, like your block chews theirs.
	var chewed := mini(enemy_block, amount)
	enemy_block -= chewed
	amount -= chewed
	enemy_hp = maxi(0, enemy_hp - amount)
	enemy_hit_this_turn = true
	juice_requested.emit(3.0, "gunshot" if tag == "GUN" else "hit")
	encounter_updated.emit()

# ---- fights ----

func start_encounter() -> void:
	var is_boss := stop_index >= STOPS.size() - 2
	enemy = EnemiesData.boss() if is_boss else EnemiesData.pick(leg, rng, last_enemy_id)
	last_enemy_id = str(enemy["id"])
	enemy_hp = int(enemy["hp"])
	enemy_max_hp = enemy_hp
	enemy_block = 0
	enemy_strength = 0
	move_cursor = 0
	block = 0
	enemy_hit_this_turn = false
	encounter_active = true
	grit = FIGHT_GRIT
	turn_plays.clear()
	primed.clear()
	draw_to(5)
	if str(enemy["id"]) in ["wolves", "grizzly", "mountain_lion", "rattlesnake"]:
		juice_requested.emit(0.0, "growl")
	encounter_updated.emit()
	hand_changed.emit()
	resources_changed.emit()

func current_move() -> Dictionary:
	if enemy.is_empty():
		return {}
	var moves: Array = enemy["moves"]
	return moves[move_cursor % moves.size()]

func intent_amount(move: Dictionary) -> int:
	return int(move.get("amount", 0)) + enemy_strength if str(move.get("kind", "")) == "attack" else int(move.get("amount", 0))

func end_turn() -> void:
	if not encounter_active or game_over:
		return
	while not hand.is_empty():
		discard_pile.append(hand.pop_back())
	var move := current_move()
	var landed := 0
	match str(move.get("kind", "")):
		"attack":
			var incoming := intent_amount(move)
			var blocked := mini(block, incoming)
			block -= blocked
			landed = incoming - blocked
			if landed > 0:
				_nudge(str(move.get("target", "wagon")), -landed)
				juice_requested.emit(5.0, "hit")
		"buff":
			enemy_strength += int(move.get("strength", 0))
		"guard":
			enemy_block += int(move.get("block", 0))
		"curse":
			discard_pile.append(str(move.get("card", "dust_inhalation")))
	enemy_acted.emit(move, landed)
	move_cursor += 1
	# Block decays: defense is a per-turn decision.
	block = 0
	grit = FIGHT_GRIT
	turn_plays.clear()
	primed.clear()
	enemy_hit_this_turn = false
	draw_to(5)
	_check_defeat("the %s finished what the miles began" % str(enemy.get("name", "trail")).to_lower())
	encounter_updated.emit()
	resources_changed.emit()
	hand_changed.emit()

func _win_encounter() -> void:
	encounter_active = false
	var gold := int(enemy.get("loot", 5))
	money += gold
	morale = clampi(morale + 4, 0, 100)
	encounter_won.emit(gold)
	juice_requested.emit(4.0, "stamp")
	travel({})

# ---- the road ----

func travel(effects: Dictionary) -> void:
	if game_over:
		return
	for stat: String in effects.keys():
		if stat == "days":
			day = maxi(1, day + int(effects[stat]))
		else:
			_nudge(stat, int(effects[stat]))
	var travel_days := maxi(1, rng.randi_range(3, 4) - travel_bonus)
	travel_bonus = 0
	day += travel_days
	supplies = maxi(0, supplies - travel_days * 2)
	morale = clampi(morale - 1, 0, 100)
	# Winter is the clock.
	if day > WINTER_HARD_DAY:
		supplies = maxi(0, supplies - 6)
		morale = clampi(morale - 8, 0, 100)
	elif day > WINTER_SOFT_DAY:
		supplies = maxi(0, supplies - 3)
		morale = clampi(morale - 3, 0, 100)
	if supplies <= 0:
		morale = clampi(morale - 6, 0, 100)
	leg += 1
	stop_index = mini(leg, STOPS.size() - 1)
	resources_changed.emit()
	if _check_defeat("winter caught the wagon on the open road" if day > WINTER_SOFT_DAY else "hunger walked beside the wagon"):
		return
	if stop_index >= STOPS.size() - 1:
		game_over = true
		game_ended.emit(true, "")
		return
	_offer_rewards()

func _offer_rewards() -> void:
	reward_options.clear()
	var pool := CardsData.REWARD_POOL.duplicate()
	while reward_options.size() < 3 and not pool.is_empty():
		var pick: String = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(pick)
		reward_options.append(pick)
	rewards_offered.emit(reward_options.duplicate())

func take_reward(index: int) -> void:
	if index >= 0 and index < reward_options.size():
		discard_pile.append(reward_options[index])
		juice_requested.emit(2.0, "stamp")
	_next_leg()

func skip_reward() -> void:
	_next_leg()

func _next_leg() -> void:
	reward_options.clear()
	var is_fight := (leg % 3 == 0 and leg > 0) or stop_index >= STOPS.size() - 2
	if is_fight:
		start_encounter()
	else:
		encounter_active = false
		start_leg()
	leg_advanced.emit(next_stop_name(), is_fight)

func _check_defeat(cause: String) -> bool:
	if morale <= 0 and not game_over:
		game_over = true
		encounter_active = false
		game_ended.emit(false, cause)
		return true
	return false

func _stat(stat: String) -> int:
	match stat:
		"supplies": return supplies
		"morale": return morale
		"wagon": return wagon
		"grit": return grit
	return 0

func _nudge(stat: String, amount: int) -> void:
	match stat:
		"supplies": supplies = maxi(0, supplies + amount)
		"morale": morale = clampi(morale + amount, 0, 100)
		"wagon": wagon = clampi(wagon + amount, 0, 100)
		"grit": grit = clampi(grit + amount, 0, GRIT_CAP)
	if stat == "morale":
		_check_defeat("the heart went out of the party")
