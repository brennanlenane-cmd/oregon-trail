extends Node

# Fresh-start smoke test. Runs inside the real game (autoloads alive):
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

	# ---- The table booted off the real run ----
	var gates: Array = []
	var cards: Array = []
	for node in _walk(table):
		if node is HazardGate:
			gates.append(node)
		elif node is CardControl:
			cards.append(node)
	_check(gates.size() == 1, "one hazard gate on the table")
	_check(cards.size() == GameState.hand.size(), "a CardControl per card in hand (%d)" % cards.size())
	_check(GameState.hand.size() == 5, "opening hand of 5")
	_check(GameState.grit == GameState.BASE_GRIT, "grit opens at base 2")

	# ---- Data mandate: no flat arithmetic, terse rules text ----
	var flat := 0
	for card in CardsData.CARDS_DATA:
		var mech: Dictionary = card.get("mech", {})
		if mech.has("gain") and not (mech.has("spend") or mech.has("discard_tag")):
			if str(card.get("tag", "")) != "KIN":
				flat += 1
	_check(flat == 0, "zero flat-arithmetic non-KIN cards")
	var wordy := 0
	for card in CardsData.CARDS_DATA:
		if str(card["rules_text"]).replace("→", " ").split(" ", false).size() > 8:
			wordy += 1
	_check(wordy == 0, "all rules text reads at a glance")

	# ---- Mechanics ----
	GameState.hand.clear()
	GameState.hand.append("forage")
	GameState.grit = 2
	var before := GameState.supplies
	var wagon_before := GameState.wagon
	_check(GameState.play_card(0), "forage plays")
	var gained := GameState.supplies - before
	_check(gained >= 2 and gained <= 12 and gained % 2 == 0, "forage wagers 1d6 x2 supplies (got %d)" % gained)
	_check(gained > 2 or GameState.wagon == wagon_before - 6, "a roll of 1 breaks the wagon")
	GameState.hand.clear()
	GameState.hand.append_array(["campfire_stories", "dynamite"])
	GameState.grit = 2
	GameState.morale = 50
	GameState.play_card(0)
	_check(GameState.morale == 63, "campfire feeds on dynamite: 4 + 3x3")
	_check(not GameState.hand.has("dynamite"), "the fed card leaves the hand")
	GameState.hand.clear()
	GameState.hand.append("kin_dog")
	GameState.grit = 1
	_check(GameState.stoke(0), "the dog can be stoked")
	_check(GameState.grit == 2, "stoke grants +1 grit")
	_check(GameState.exhausted.has("kin_dog"), "stoked kin is spent for the leg")
	GameState.hand.clear()
	GameState.hand.append("scout_ahead")
	GameState.grit = 2
	GameState.play_card(0)
	_check(GameState.exhausted.has("scout_ahead"), "EXHAUST cards leave the cycle")
	GameState.start_leg()
	_check(not GameState.exhausted.has("scout_ahead") and GameState.hand.size() == 5, "exhausted cards return at the new leg")

	# ---- The gate eats a matching card ----
	var gate: HazardGate = gates[0]
	var sockets := get_tree().get_nodes_in_group("drop_targets")
	_check(sockets.size() == 1, "the gate socket registers as a drop target")
	if not sockets.is_empty():
		var socket: CardSocket = sockets[0]
		var matching: Dictionary = {}
		for card in CardsData.CARDS_DATA:
			if str(card.get("tag", "")) == gate.required_tag:
				matching = card
				break
		_check(socket.accepts(matching), "socket accepts a matching [%s] card" % gate.required_tag)
		var wrong := {"id": "x", "tag": "NOPE"}
		_check(not socket.accepts(wrong), "socket refuses a wrong-tag card")
		socket.receive(matching)
		await get_tree().process_frame
		_check(gate.resolved, "feeding the socket resolves the gate")
		_check(gate.forge_button.disabled, "FORGE AHEAD locks after the clear")

	print("RESULT  ·  %s" % ("ALL GREEN" if failures == 0 else "%d FAILURES" % failures))
	get_tree().quit(1 if failures > 0 else 0)

func _walk(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
