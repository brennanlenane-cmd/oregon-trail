extends Control

# The table. Composes the painted map, the resource strip, one HazardGate,
# and the hand of CardControls. All rules live in GameState; this file only
# renders, forwards intents, and reacts to signals.

const HAZARDS := [
	{"title": "WASHED-OUT ROAD", "tag": "TRAIL", "pay": "-1 DAY", "pass": "+1 DAY",
		"pay_fx": {"days": -1}, "pass_fx": {"days": 1}, "art": "res://assets/art/scene/event-morning.png"},
	{"title": "BROKEN AXLE", "tag": "GOODS", "pay": "WAGON +6", "pass": "+1 DAY · WAGON -8",
		"pay_fx": {"wagon": 6}, "pass_fx": {"days": 1, "wagon": -8}, "art": "res://assets/art/scene/event-breakdown.png"},
	{"title": "COLD CAMP", "tag": "FIRE", "pay": "MORALE +8", "pass": "+1 DAY · MORALE -4",
		"pay_fx": {"morale": 8}, "pass_fx": {"days": 1, "morale": -4}, "art": "res://assets/art/scene/event-camp.png"},
	{"title": "BAD WATER", "tag": "GOODS", "pay": "SUPPLIES -2 · SAFE", "pass": "+1 DAY · MORALE -6",
		"pay_fx": {"supplies": -2}, "pass_fx": {"days": 1, "morale": -6}, "art": "res://assets/art/river-crossing.jpg"},
]

var world: Control            # everything the screen shake jolts
var gate: HazardGate
var hand_row: Control
var strip_values: Dictionary = {}
var juice: JuiceLayer
var hazard_cursor := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 7
	_build_table()
	GameState.resources_changed.connect(_refresh_strip)
	GameState.hand_changed.connect(_rebuild_hand)
	GameState.wager_rolled.connect(_on_wager_rolled)
	GameState.start_run()
	_next_hazard()
	# Headless test hook: `Summer.exe --headless --path . -- --smoke`
	if OS.get_cmdline_user_args().has("--smoke"):
		add_child((load("res://tests/smoke.gd") as GDScript).new())
	elif OS.get_cmdline_user_args().has("--probe"):
		_probe_screenshot()

func _probe_screenshot() -> void:
	await get_tree().create_timer(1.2).timeout
	var shot := get_viewport().get_texture().get_image()
	shot.save_png("user://probe_fresh_table.png")
	print("PROBE SAVED")
	get_tree().quit()

func _build_table() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#151009")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	world = Control.new()
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(world)
	# The painted West fills the table.
	var map := TextureRect.new()
	map.texture = load("res://assets/art/scene/map-west.png")
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.modulate = Color(0.82, 0.78, 0.7)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(map)
	# Resource strip: one wood plank across the top.
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiKit.panel("wood"))
	strip.anchor_right = 1.0
	strip.offset_bottom = 54.0
	world.add_child(strip)
	var strip_row := HBoxContainer.new()
	strip_row.add_theme_constant_override("separation", 26)
	strip.add_child(strip_row)
	for stat in ["DAY", "SUPPLIES", "MORALE", "WAGON", "GRIT"]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		strip_row.add_child(cell)
		var caption := UiKit.label(stat, 11, Color("#9a8c72"))
		cell.add_child(caption)
		var value := UiKit.label("0", 22, Color("#e7dcbd"))
		value.add_theme_font_override("font", UiKit.display_font())
		cell.add_child(value)
		strip_values[stat] = value
	# The hazard manifest, pinned right of center.
	gate = HazardGate.new()
	gate.anchor_left = 0.56
	gate.anchor_right = 0.97
	gate.anchor_top = 0.12
	gate.anchor_bottom = 0.12
	gate.cleared.connect(_on_gate_cleared)
	gate.forged.connect(_on_gate_forged)
	gate.trigger_juice.connect(func(s: float, e: String) -> void: GameState.juice_requested.emit(s, e))
	world.add_child(gate)
	# The hand rides the bottom.
	hand_row = Control.new()
	hand_row.anchor_top = 1.0
	hand_row.anchor_bottom = 1.0
	hand_row.anchor_right = 1.0
	hand_row.offset_top = -278.0
	hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(hand_row)
	juice = JuiceLayer.new()
	juice.shake_target = world
	add_child(juice)

func _refresh_strip() -> void:
	strip_values["DAY"].text = "%02d" % GameState.day
	strip_values["SUPPLIES"].text = str(GameState.supplies)
	strip_values["MORALE"].text = str(GameState.morale)
	strip_values["WAGON"].text = str(GameState.wagon)
	strip_values["GRIT"].text = "%d" % GameState.grit

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

func _make_card(card_id: String, index: int) -> CardControl:
	var data := CardsData.by_id(card_id)
	var card := CardControl.new()
	card.card_data = data
	card.hand_index = index
	card.custom_minimum_size = Vector2(172, 232)
	card.size = Vector2(172, 232)
	# Face: paper panel, letterpress title, cost stamp, art plate, rules line, tag chip.
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", UiKit.panel("paper"))
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(face)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_row)
	var title := UiKit.label(str(data.get("title", card_id)), 15, UiKit.INK)
	title.add_theme_font_override("font", UiKit.display_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title)
	var cost := PanelContainer.new()
	cost.add_theme_stylebox_override("panel", UiKit.panel("stamp"))
	cost.rotation_degrees = rng.randf_range(-2.0, 2.0)
	title_row.add_child(cost)
	var cost_label := UiKit.label(str(GameState.card_cost(card_id)), 14, Color("#f6efdc"))
	cost_label.add_theme_font_override("font", UiKit.display_font())
	cost.add_child(cost_label)
	var art := TextureRect.new()
	var art_path := str(data.get("art", ""))
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	art.custom_minimum_size = Vector2(0, 104)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	var rules := UiKit.label(str(data.get("rules_text", "")), 11, Color("#4b3d2a"))
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.max_lines_visible = 3
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rules)
	var tag_chip := PanelContainer.new()
	var tag := str(data.get("tag", ""))
	var chip_style := UiKit.panel("wood").duplicate() as StyleBoxTexture
	chip_style.modulate_color = UiKit.TAG_COLORS.get(tag, Color.WHITE)
	tag_chip.add_theme_stylebox_override("panel", chip_style)
	tag_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag_chip)
	var tag_label := UiKit.label(tag, 9, Color("#f6efdc"))
	tag_label.add_theme_font_override("font", UiKit.display_font())
	tag_chip.add_child(tag_label)
	card.card_played.connect(_on_card_dropped.bind(card))
	card.stoke_requested.connect(_on_stoke.bind(card))
	card.trigger_juice.connect(func(s: float, e: String) -> void: GameState.juice_requested.emit(s, e))
	return card

func _on_card_dropped(card_data: Dictionary, card: CardControl) -> void:
	# The socket already stamped the gate; the play still goes through the state
	# (grit, mechanics, piles) so the card's own effect fires too.
	var index := GameState.hand.find(str(card_data.get("id", "")))
	if index >= 0:
		GameState.play_card(index)
	card.queue_free()

func _on_stoke(card_data: Dictionary, card: CardControl) -> void:
	var index := GameState.hand.find(str(card_data.get("id", "")))
	if index >= 0 and GameState.stoke(index):
		card.queue_free()

func _on_wager_rolled(roll: int, busted: bool) -> void:
	var pop := UiKit.label("ROLL  %d%s" % [roll, "  ·  BUST" if busted else ""], 34, UiKit.VERMILION if busted else Color("#1f5c33"))
	pop.add_theme_font_override("font", UiKit.display_font())
	pop.position = Vector2(size.x * 0.42, size.y * 0.42)
	add_child(pop)
	var tween := create_tween()
	tween.tween_property(pop, "position:y", pop.position.y - 60.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pop, "modulate", Color(1, 1, 1, 0), 0.9)
	tween.tween_callback(pop.queue_free)

func _on_gate_cleared(hazard: Dictionary) -> void:
	_apply_travel(hazard.get("pay_fx", {}))
	_after_leg()

func _on_gate_forged(hazard: Dictionary) -> void:
	_apply_travel(hazard.get("pass_fx", {}))
	_after_leg()

func _apply_travel(effects: Dictionary) -> void:
	for stat in effects.keys():
		if stat == "days":
			GameState.day += int(effects[stat])
		else:
			GameState._nudge(stat, int(effects[stat]))
	# The road itself always eats: a leg of travel.
	var travel := maxi(1, 3 - GameState.travel_bonus)
	GameState.travel_bonus = 0
	GameState.day += travel
	GameState.supplies = maxi(0, GameState.supplies - travel * 2)
	GameState.morale = clampi(GameState.morale - 1, 0, 100)
	GameState.resources_changed.emit()

func _after_leg() -> void:
	await get_tree().create_timer(0.9).timeout
	GameState.start_leg()
	_next_hazard()

func _next_hazard() -> void:
	var hazard: Dictionary = HAZARDS[hazard_cursor % HAZARDS.size()]
	hazard_cursor += 1
	gate.configure(hazard)
	gate.set_socket_pulse(_holding_tag(str(hazard["tag"])))

func _holding_tag(tag: String) -> bool:
	for card_id in GameState.hand:
		if str(CardsData.by_id(card_id).get("tag", "")) == tag:
			return true
	return false
