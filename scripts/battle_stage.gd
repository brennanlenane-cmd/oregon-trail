extends Control
class_name BattleStage

# The fight, StS-grammar: a full-bleed window into the West. Wagon left,
# enemy right on the ground strip, HP bar and a LIVE intent badge over the
# enemy's head. Zero prose — icon words, numbers, and an END TURN that glows
# when the hand is spent.

signal end_turn_pressed

var backdrop: TextureRect
var wagon_rect: TextureRect
var enemy_rect: TextureRect
var hp_fill: ColorRect
var hp_frame: Control
var hp_label: Label
var name_label: Label
var intent_panel: PanelContainer
var intent_label: Label
var end_turn_button: Button
var block_label: Label
var announce_label: Label

const TARGET_WORDS := {"supplies": "SUPPLIES", "morale": "MORALE", "wagon": "WAGON"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	# The wagon party holds the left of the ground strip.
	wagon_rect = TextureRect.new()
	wagon_rect.texture = load("res://assets/sprites/family/wagon.png")
	wagon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wagon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	wagon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wagon_rect.anchor_left = 0.03
	wagon_rect.anchor_right = 0.36
	wagon_rect.anchor_top = 0.42
	wagon_rect.anchor_bottom = 0.68
	wagon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wagon_rect)
	enemy_rect = TextureRect.new()
	enemy_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	enemy_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_rect.anchor_left = 0.62
	enemy_rect.anchor_right = 0.88
	enemy_rect.anchor_top = 0.40
	enemy_rect.anchor_bottom = 0.68
	enemy_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(enemy_rect)
	# Enemy nameplate + HP bar + intent, stacked over its head.
	name_label = UiKit.label("", 18, Color("#f6efdc"))
	name_label.add_theme_font_override("font", UiKit.display_font())
	name_label.anchor_left = 0.58
	name_label.anchor_right = 0.92
	name_label.anchor_top = 0.18
	name_label.anchor_bottom = 0.18
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	hp_frame = Control.new()
	hp_frame.anchor_left = 0.62
	hp_frame.anchor_right = 0.88
	hp_frame.anchor_top = 0.235
	hp_frame.anchor_bottom = 0.235
	hp_frame.offset_bottom = 14.0
	add_child(hp_frame)
	var hp_back := ColorRect.new()
	hp_back.color = Color(0.08, 0.05, 0.04, 0.9)
	hp_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_frame.add_child(hp_back)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("#a02818")
	hp_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_fill.offset_left = 2.0
	hp_fill.offset_top = 2.0
	hp_fill.offset_bottom = -2.0
	hp_frame.add_child(hp_fill)
	hp_label = UiKit.label("", 11, Color("#f6efdc"))
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_frame.add_child(hp_label)
	intent_panel = PanelContainer.new()
	intent_panel.add_theme_stylebox_override("panel", UiKit.panel("stamp"))
	intent_panel.anchor_left = 0.66
	intent_panel.anchor_right = 0.66
	intent_panel.anchor_top = 0.29
	intent_panel.anchor_bottom = 0.29
	add_child(intent_panel)
	intent_label = UiKit.label("", 15, Color("#f6efdc"))
	intent_label.add_theme_font_override("font", UiKit.display_font())
	intent_panel.add_child(intent_label)
	block_label = UiKit.label("", 16, Color("#7fa6c9"))
	block_label.add_theme_font_override("font", UiKit.display_font())
	block_label.anchor_left = 0.06
	block_label.anchor_top = 0.36
	block_label.anchor_bottom = 0.36
	add_child(block_label)
	announce_label = UiKit.label("", 30, Color("#f6efdc"))
	announce_label.add_theme_font_override("font", UiKit.display_font())
	announce_label.anchor_left = 0.35
	announce_label.anchor_right = 0.65
	announce_label.anchor_top = 0.3
	announce_label.anchor_bottom = 0.3
	announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce_label.visible = false
	add_child(announce_label)
	end_turn_button = Button.new()
	end_turn_button.text = "END TURN"
	end_turn_button.custom_minimum_size = Vector2(190, 52)
	end_turn_button.add_theme_stylebox_override("normal", UiKit.panel("wood"))
	end_turn_button.add_theme_stylebox_override("hover", UiKit.panel("wood"))
	end_turn_button.add_theme_font_override("font", UiKit.display_font())
	end_turn_button.add_theme_font_size_override("font_size", 17)
	end_turn_button.add_theme_color_override("font_color", Color("#e7dcbd"))
	end_turn_button.anchor_left = 1.0
	end_turn_button.anchor_right = 1.0
	end_turn_button.anchor_top = 1.0
	end_turn_button.anchor_bottom = 1.0
	end_turn_button.offset_left = -214.0
	end_turn_button.offset_right = -24.0
	end_turn_button.offset_top = -338.0
	end_turn_button.offset_bottom = -286.0
	end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	add_child(end_turn_button)

func open(enemy: Dictionary, region: String) -> void:
	visible = true
	var region_path := "res://assets/art/scene/battle-%s.png" % region
	if ResourceLoader.exists(region_path):
		backdrop.texture = load(region_path)
	var art_path := str(enemy.get("art", ""))
	if ResourceLoader.exists(art_path):
		enemy_rect.texture = load(art_path)
	enemy_rect.modulate = Color.WHITE
	enemy_rect.scale = Vector2.ONE
	name_label.text = str(enemy.get("name", ""))
	refresh()

func refresh() -> void:
	if not GameState.encounter_active and GameState.enemy_hp > 0:
		return
	var max_hp := maxi(1, GameState.enemy_max_hp)
	hp_fill.anchor_right = float(GameState.enemy_hp) / float(max_hp)
	hp_label.text = "%d / %d" % [GameState.enemy_hp, max_hp]
	var move := GameState.current_move()
	var kind := str(move.get("kind", ""))
	match kind:
		"attack":
			intent_label.text = "HIT %d → %s" % [GameState.intent_amount(move), TARGET_WORDS.get(str(move.get("target", "wagon")), "WAGON")]
		"buff":
			intent_label.text = "GATHERING STRENGTH"
		"guard":
			intent_label.text = "TAKING COVER"
		"curse":
			intent_label.text = "FOULING THE AIR"
	var guard := " · GUARD %d" % GameState.enemy_block if GameState.enemy_block > 0 else ""
	name_label.text = str(GameState.enemy.get("name", "")) + guard
	block_label.text = "BLOCK %d" % GameState.block if GameState.block > 0 else ""
	# END TURN glows when the hand can do nothing more.
	var anything_playable := false
	for card_id in GameState.hand:
		if GameState.can_play(card_id):
			anything_playable = true
			break
	end_turn_button.modulate = Color(1.35, 1.2, 0.85) if not anything_playable else Color.WHITE

func announce(move: Dictionary, landed: int) -> void:
	var text := str(move.get("name", ""))
	if landed > 0:
		text += "  ·  %d" % landed
	announce_label.text = text
	announce_label.visible = true
	announce_label.modulate = Color.WHITE
	announce_label.scale = Vector2(1.3, 1.3)
	announce_label.pivot_offset = announce_label.size / 2.0
	# The enemy lunges as its move lands.
	var lunge := create_tween()
	lunge.tween_property(enemy_rect, "position:x", enemy_rect.position.x - 26.0, 0.09)
	lunge.tween_property(enemy_rect, "position:x", enemy_rect.position.x, 0.18)
	var fade := create_tween()
	fade.tween_property(announce_label, "scale", Vector2.ONE, 0.12)
	fade.tween_interval(0.7)
	fade.tween_property(announce_label, "modulate", Color(1, 1, 1, 0), 0.3)
	fade.tween_callback(func() -> void: announce_label.visible = false)

func enemy_dies() -> void:
	var death := create_tween()
	death.tween_property(enemy_rect, "modulate", Color(1, 0.6, 0.5, 0.0), 0.5)
	death.parallel().tween_property(enemy_rect, "scale", Vector2(1.0, 0.85), 0.5)
