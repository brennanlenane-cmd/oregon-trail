extends Control

# The table. Two views on one screen — the JOURNEY (painted map + hazard
# manifest) and the FIGHT (full-bleed window into the West) — plus the SPOILS
# overlay and the end-of-run sheet. All rules live in GameState; this file
# renders, forwards intents, and reacts to signals.

const HAZARDS := [
	{"title": "WASHED-OUT ROAD", "tag": "TRAIL", "pay": "-1 DAY", "pass": "+1 DAY",
		"pay_fx": {"days": -1}, "pass_fx": {"days": 1}, "art": "res://assets/art/scene/event-morning.png"},
	{"title": "BROKEN AXLE", "tag": "GOODS", "pay": "WAGON +6", "pass": "+1 DAY · WAGON -8",
		"pay_fx": {"wagon": 6}, "pass_fx": {"days": 1, "wagon": -8}, "art": "res://assets/art/scene/event-breakdown.png"},
	{"title": "COLD CAMP", "tag": "FIRE", "pay": "MORALE +8", "pass": "+1 DAY · MORALE -4",
		"pay_fx": {"morale": 8}, "pass_fx": {"days": 1, "morale": -4}, "art": "res://assets/art/scene/event-camp.png"},
	{"title": "THE BISON HERD", "tag": "GUN", "pay": "SUPPLIES +10", "pass": "+1 DAY",
		"pay_fx": {"supplies": 10}, "pass_fx": {"days": 1}, "art": "res://assets/art/bison-hunt.jpg"},
	{"title": "BAD WATER", "tag": "GOODS", "pay": "SUPPLIES -2 · SAFE", "pass": "+1 DAY · MORALE -6",
		"pay_fx": {"supplies": -2}, "pass_fx": {"days": 1, "morale": -6}, "art": "res://assets/art/river-crossing.jpg"},
	{"title": "PRAIRIE FIRE", "tag": "TRAIL", "pay": "NO LOST DAY · WAGON -6", "pass": "+2 DAYS",
		"pay_fx": {"wagon": -6}, "pass_fx": {"days": 2}, "art": "res://assets/art/prairie-fire.jpg"},
]

var world: Control
var journey_view: Control
var gate: HazardGate
var battle: BattleStage
var rewards: RewardPanel
var end_sheet: PanelContainer
var hand_row: Control
var strip_values: Dictionary = {}
var next_stop_label: Label
var juice: JuiceLayer
var hazard_cursor := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 7
	_build_table()
	GameState.resources_changed.connect(_refresh_strip)
	GameState.hand_changed.connect(_rebuild_hand)
	GameState.wager_rolled.connect(_on_wager_rolled)
	GameState.status_bites.connect(_on_status_bites)
	GameState.leg_advanced.connect(_on_leg_advanced)
	GameState.encounter_updated.connect(func() -> void: battle.refresh())
	GameState.enemy_acted.connect(func(move: Dictionary, landed: int) -> void: battle.announce(move, landed))
	GameState.encounter_won.connect(_on_encounter_won)
	GameState.rewards_offered.connect(func(options: Array) -> void: rewards.offer(options))
	GameState.game_ended.connect(_on_game_ended)
	GameState.start_run()
	# Headless hooks: `-- --smoke` runs the suite, `-- --probe` saves screenshots.
	if OS.get_cmdline_user_args().has("--smoke"):
		add_child((load("res://tests/smoke.gd") as GDScript).new())
	elif OS.get_cmdline_user_args().has("--probe"):
		_probe_screenshots()

func _build_table() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#151009")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	world = Control.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	# ---- Journey view: the painted West + the hazard manifest ----
	journey_view = Control.new()
	journey_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journey_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(journey_view)
	var map := TextureRect.new()
	map.texture = load("res://assets/art/scene/map-west.png")
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.modulate = Color(0.82, 0.78, 0.7)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	journey_view.add_child(map)
	gate = HazardGate.new()
	gate.anchor_left = 0.56
	gate.anchor_right = 0.97
	gate.anchor_top = 0.11
	gate.anchor_bottom = 0.11
	gate.cleared.connect(func(hazard: Dictionary) -> void: GameState.travel(hazard.get("pay_fx", {})))
	gate.forged.connect(func(hazard: Dictionary) -> void: GameState.travel(hazard.get("pass_fx", {})))
	gate.trigger_juice.connect(func(s: float, e: String) -> void: GameState.juice_requested.emit(s, e))
	journey_view.add_child(gate)
	# ---- Fight view: full-bleed window into the West ----
	battle = BattleStage.new()
	battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle.visible = false
	battle.end_turn_pressed.connect(func() -> void: GameState.end_turn())
	world.add_child(battle)
	# ---- Wood strip on top ----
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiKit.panel("wood"))
	strip.anchor_right = 1.0
	strip.offset_bottom = 54.0
	world.add_child(strip)
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 24)
	strip.add_child(strip_row)
	for stat in ["DAY", "SUPPLIES", "MORALE", "WAGON", "$", "GRIT"]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		strip_row.add_child(cell)
		var caption := UiKit.label(stat, 11, Color("#9a8c72"))
		cell.add_child(caption)
		var value := UiKit.label("0", 22, Color("#e7dcbd"))
		value.add_theme_font_override("font", UiKit.display_font())
		cell.add_child(value)
		strip_values[stat] = value
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_row.add_child(spacer)
	next_stop_label = UiKit.label("", 16, Color("#c98d4b"))
	next_stop_label.add_theme_font_override("font", UiKit.display_font())
	strip_row.add_child(next_stop_label)
	# ---- The hand ----
	hand_row = Control.new()
	hand_row.anchor_top = 1.0
	hand_row.anchor_bottom = 1.0
	hand_row.anchor_right = 1.0
	hand_row.offset_top = -278.0
	hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(hand_row)
	# ---- Overlays ----
	rewards = RewardPanel.new()
	rewards.taken.connect(func(index: int) -> void: GameState.take_reward(index))
	rewards.skipped.connect(func() -> void: GameState.skip_reward())
	add_child(rewards)
	end_sheet = PanelContainer.new()
	end_sheet.add_theme_stylebox_override("panel", UiKit.panel("paper"))
	end_sheet.anchor_left = 0.3
	end_sheet.anchor_right = 0.7
	end_sheet.anchor_top = 0.3
	end_sheet.anchor_bottom = 0.3
	end_sheet.visible = false
	add_child(end_sheet)
	juice = JuiceLayer.new()
	juice.shake_target = world
	add_child(juice)

# ---- view switching ----

func _on_leg_advanced(stop_name: String, is_fight: bool) -> void:
	next_stop_label.text = "NEXT  ·  %s" % stop_name.to_upper()
	battle.visible = is_fight
	journey_view.visible = not is_fight
	if is_fight:
		battle.open(GameState.enemy, EnemiesData.region_for_stop(GameState.stop_index))
	else:
		var hazard: Dictionary = HAZARDS[hazard_cursor % HAZARDS.size()]
		hazard_cursor += 1
		gate.configure(hazard)
		gate.set_socket_pulse(_holding_tag(str(hazard["tag"])))

func _on_encounter_won(gold: int) -> void:
	battle.enemy_dies()
	_float_note("THREAT BROKEN  ·  +$%d" % gold, Color("#1f5c33"))

func _on_game_ended(won: bool, cause: String) -> void:
	battle.visible = false
	rewards.visible = false
	end_sheet.visible = true
	for child in end_sheet.get_children():
		child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	end_sheet.add_child(box)
	var headline := UiKit.label("OREGON CITY" if won else "THE WAGON STOPS", 40, UiKit.INK if won else UiKit.VERMILION)
	headline.add_theme_font_override("font", UiKit.display_font())
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(headline)
	var line := UiKit.label(
		"%d days  ·  %d legs" % [GameState.day, GameState.leg] if won else cause,
		14, Color("#4b3d2a"))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)
	var again := Button.new()
	again.text = "NEW JOURNEY"
	again.custom_minimum_size = Vector2(0, 46)
	again.add_theme_stylebox_override("normal", UiKit.panel("stamp"))
	again.add_theme_stylebox_override("hover", UiKit.panel("stamp"))
	again.add_theme_font_override("font", UiKit.display_font())
	again.add_theme_color_override("font_color", Color("#f6efdc"))
	again.pressed.connect(func() -> void:
		end_sheet.visible = false
		GameState.start_run(int(Time.get_unix_time_from_system()) % 100000)
	)
	box.add_child(again)

# ---- strip + hand ----

func _refresh_strip() -> void:
	strip_values["DAY"].text = "%02d" % GameState.day
	strip_values["DAY"].add_theme_color_override("font_color",
		Color("#a02818") if GameState.day > GameState.WINTER_HARD_DAY
		else (Color("#c98d4b") if GameState.day > GameState.WINTER_SOFT_DAY else Color("#e7dcbd")))
	strip_values["SUPPLIES"].text = str(GameState.supplies)
	strip_values["MORALE"].text = str(GameState.morale)
	strip_values["WAGON"].text = str(GameState.wagon)
	strip_values["$"].text = str(GameState.money)
	strip_values["GRIT"].text = str(GameState.grit)

func _rebuild_hand() -> void:
	for child in hand_row.get_children():
		child.queue_free()
	var count := GameState.hand.size()
	if count == 0:
		return
	var card_w := 172.0
	var spread: float = minf(card_w + 10.0, (hand_row.size.x * 0.6) / maxf(1.0, count))
	var total := spread * (count - 1) + card_w
	var left := (hand_row.size.x - total) / 2.0
	for i in count:
		var card := _make_card(GameState.hand[i], i)
		card.position = Vector2(left + spread * i, 18.0 + absf(i - (count - 1) / 2.0) * 7.0)
		card.rotation_degrees = (i - (count - 1) / 2.0) * 2.2
		card.home_position = card.position
		card.home_rotation = card.rotation_degrees
		hand_row.add_child(card)
	if battle.visible:
		battle.refresh()

func _make_card(card_id: String, index: int) -> CardControl:
	var data := CardsData.by_id(card_id)
	var card := CardControl.new()
	card.card_data = data
	card.hand_index = index
	card.custom_minimum_size = Vector2(172, 232)
	card.size = Vector2(172, 232)
	card.loose_play = GameState.encounter_active
	var face := UiKit.card_face(data, GameState.card_cost(card_id))
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(face)
	if not GameState.can_play(card_id):
		face.modulate = Color(0.72, 0.7, 0.66)
	card.card_played.connect(_on_card_dropped.bind(card))
	card.stoke_requested.connect(_on_stoke.bind(card))
	card.trigger_juice.connect(func(s: float, e: String) -> void: GameState.juice_requested.emit(s, e))
	return card

# In a fight, dropping a card ANYWHERE plays it (the enemy is the target);
# on the trail it must land in the gate's socket (the socket calls receive).
func _on_card_dropped(card_data: Dictionary, card: CardControl) -> void:
	var index := GameState.hand.find(str(card_data.get("id", "")))
	if index >= 0:
		GameState.play_card(index)
	card.queue_free()

func _on_stoke(card_data: Dictionary, card: CardControl) -> void:
	var index := GameState.hand.find(str(card_data.get("id", "")))
	if index >= 0 and GameState.stoke(index):
		card.queue_free()

# ---- floats ----

func _on_wager_rolled(roll: int, busted: bool) -> void:
	_float_note("ROLL  %d%s" % [roll, "  ·  BUST" if busted else ""], UiKit.VERMILION if busted else Color("#1f5c33"))

func _on_status_bites(text: String) -> void:
	_float_note(text, UiKit.VERMILION)

func _float_note(text: String, color: Color) -> void:
	var pop := UiKit.label(text, 32, color)
	pop.add_theme_font_override("font", UiKit.display_font())
	pop.position = Vector2(size.x * 0.40, size.y * 0.4)
	add_child(pop)
	var tween := create_tween()
	tween.tween_property(pop, "position:y", pop.position.y - 60.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pop, "modulate", Color(1, 1, 1, 0), 0.9)
	tween.tween_callback(pop.queue_free)

func _holding_tag(tag: String) -> bool:
	for card_id in GameState.hand:
		if str(CardsData.by_id(card_id).get("tag", "")) == tag:
			return true
	return false

# ---- probe ----

func _probe_screenshots() -> void:
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("user://probe_journey.png")
	# Force a fight for the second shot.
	GameState.leg = 3
	GameState.start_encounter()
	_on_leg_advanced(GameState.next_stop_name(), true)
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png("user://probe_fight.png")
	# And the spoils screen.
	GameState.encounter_active = false
	GameState._offer_rewards()
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("user://probe_spoils.png")
	print("PROBE SAVED")
	get_tree().quit()
