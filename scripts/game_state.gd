extends Node

# GameState — the single owner of run state. UI nodes read it and emit intents;
# nothing but this file mutates the run. Every observable change fires a signal
# so the table, the juice layer, and the audio bed stay decoupled.

signal card_played(card_data: Dictionary)
signal juice_requested(shake_intensity: float, sound_event: String)
signal resources_changed
signal hand_changed
signal wager_rolled(roll: int, busted: bool)
signal kin_stoked(kin_id: String, risk_percent: int)
signal run_started

const BASE_GRIT := 2
const GRIT_CAP := 5
const STOKE_RISK := 0.10

var supplies := 60
var morale := 80
var wagon := 100
var grit := BASE_GRIT
var day := 1
var travel_bonus := 0
var hazard_revealed := false

var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhausted: Array[String] = []
var turn_plays: Array[String] = []
var primed: Dictionary = {}
var kin_stoked_counts: Dictionary = {}  # kin_id -> stokes this leg

var rng := RandomNumberGenerator.new()

func start_run(seed_value: int = 1848) -> void:
	rng.seed = seed_value
	supplies = 60
	morale = 80
	wagon = 100
	day = 1
	travel_bonus = 0
	draw_pile.assign(CardsData.STARTER_DECK.duplicate())
	shuffle(draw_pile)
	hand.clear()
	discard_pile.clear()
	exhausted.clear()
	start_leg()
	run_started.emit()

func shuffle(pile: Array[String]) -> void:
	# Deterministic for a shared seed — Array.shuffle() uses the global RNG.
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = pile[i]
		pile[i] = pile[j]
		pile[j] = tmp

func start_leg() -> void:
	grit = BASE_GRIT
	turn_plays.clear()
	primed.clear()
	kin_stoked_counts.clear()
	for card_id in exhausted:
		draw_pile.append(card_id)
	if not exhausted.is_empty():
		exhausted.clear()
		shuffle(draw_pile)
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
	hand.append(draw_pile.pop_back())
	return true

func card_cost(card_id: String) -> int:
	var card := CardsData.by_id(card_id)
	var cost := int(card.get("cost", 0))
	var combo: Dictionary = card.get("mech", {}).get("combo", {})
	if combo.has("discount_per_play"):
		cost = maxi(0, cost - int(combo["discount_per_play"]) * turn_plays.size())
	return cost

func can_play(card_id: String) -> bool:
	return grit >= card_cost(card_id)

# The one entry point for playing a card from the hand. Returns false if the
# table refuses it (cost). UI decides how to show refusal.
func play_card(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
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
	resources_changed.emit()
	hand_changed.emit()
	return true

# STOKE: the family is the furnace. Spend a member for the leg → +1 grit, +1 draw,
# and a stacking 10% chance they wake sick when camp is made.
func stoke(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card_id: String = hand[hand_index]
	var card := CardsData.by_id(card_id)
	var kin_id := str(card.get("kin", ""))
	if kin_id.is_empty():
		return false
	hand.remove_at(hand_index)
	exhausted.append(card_id)
	grit = clampi(grit + 1, 0, GRIT_CAP)
	kin_stoked_counts[kin_id] = int(kin_stoked_counts.get(kin_id, 0)) + 1
	draw_one()
	kin_stoked.emit(kin_id, int(kin_stoked_counts[kin_id]) * 100 * STOKE_RISK)
	juice_requested.emit(2.0, "card-play")
	resources_changed.emit()
	hand_changed.emit()
	return true

func _apply_mech(card: Dictionary, mech: Dictionary) -> void:
	# WAGER: roll first, in front of everyone.
	if mech.has("wager"):
		var wager: Dictionary = mech["wager"]
		var roll := rng.randi_range(1, 6)
		var busted := roll <= int(wager.get("fail_on", 0))
		for stat in wager.get("per_pip", {}).keys():
			_nudge(stat, roll * int(wager["per_pip"][stat]))
		if busted:
			for stat in wager.get("fail_fx", {}).keys():
				_nudge(stat, int(wager["fail_fx"][stat]))
			juice_requested.emit(5.0, "hit")
		wager_rolled.emit(roll, busted)
	# FUEL: burn the priciest non-KIN card left in hand.
	if mech.has("fuel"):
		var fuel: Dictionary = mech["fuel"]
		var burn_index := -1
		var burn_cost := -1
		for i in hand.size():
			var other := CardsData.by_id(hand[i])
			if str(other.get("kin", "")).is_empty() and int(other.get("cost", 0)) > burn_cost:
				burn_cost = int(other.get("cost", 0))
				burn_index = i
		var gained := int(fuel.get("base", 4))
		if burn_index >= 0:
			discard_pile.append(hand[burn_index])
			hand.remove_at(burn_index)
			gained += burn_cost * int(fuel.get("per_cost", 3))
		_nudge(str(fuel.get("stat", "morale")), gained)
	# DISCARD-TAG price: pitch a matching card or settle for the fallback.
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
		for stat in effects.keys():
			_nudge(stat, int(effects[stat]))
	elif mech.has("gain"):
		# SPEND/GAIN trade: refuse silently costs nothing extra — UI gates it.
		var affordable := true
		for stat in mech.get("spend", {}).keys():
			if _stat(stat) < int(mech["spend"][stat]):
				affordable = false
		if affordable:
			for stat in mech.get("spend", {}).keys():
				_nudge(stat, -int(mech["spend"][stat]))
			for stat in mech["gain"].keys():
				_nudge(stat, int(mech["gain"][stat]))
	if mech.has("resolve"):
		var resolve: Dictionary = mech["resolve"]
		_nudge("morale", int(resolve["low"]) if morale < int(resolve["threshold"]) else int(resolve["base"]))
	if mech.has("choice"):
		# Until the choice UI lands, Pa favors the wagon when it's hurting.
		var pick: Dictionary = mech["choice"]["b"] if wagon < 70 else mech["choice"]["a"]
		for stat in pick.keys():
			_nudge(stat, int(pick[stat]))
	if mech.has("draw"):
		for i in int(mech["draw"]):
			draw_one()
	if mech.has("travel_bonus"):
		travel_bonus += int(mech["travel_bonus"])
	if mech.has("reveal"):
		hazard_revealed = true

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
