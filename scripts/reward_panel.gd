extends Control
class_name RewardPanel

# SPOILS — the deck-building moment, straight from the StS reward screen:
# three full card faces on a dimmed table, take one or walk away.

signal taken(index: int)
signal skipped

var dimmer: ColorRect
var sheet: PanelContainer
var row: HBoxContainer
var title_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer = ColorRect.new()
	dimmer.color = Color(0.05, 0.03, 0.02, 0.72)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiKit.panel("paper"))
	sheet.anchor_left = 0.24
	sheet.anchor_right = 0.76
	sheet.anchor_top = 0.16
	sheet.anchor_bottom = 0.16
	add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	sheet.add_child(box)
	title_label = UiKit.label("SPOILS  ·  ADD ONE CARD", 26, UiKit.INK)
	title_label.add_theme_font_override("font", UiKit.display_font())
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var skip := Button.new()
	skip.text = "WALK AWAY"
	skip.custom_minimum_size = Vector2(0, 40)
	skip.add_theme_stylebox_override("normal", UiKit.panel("wood"))
	skip.add_theme_stylebox_override("hover", UiKit.panel("wood"))
	skip.add_theme_font_override("font", UiKit.display_font())
	skip.add_theme_color_override("font_color", Color("#e7dcbd"))
	skip.pressed.connect(func() -> void:
		visible = false
		skipped.emit())
	box.add_child(skip)
	visible = false

func offer(options: Array, gold_note: String = "") -> void:
	title_label.text = "SPOILS  ·  ADD ONE CARD" + gold_note
	for child in row.get_children():
		child.queue_free()
	for i in options.size():
		var data := CardsData.by_id(str(options[i]))
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(176, 236)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var face := UiKit.card_face(data, int(data.get("cost", 0)))
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(face)
		var index := i
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				visible = false
				taken.emit(index))
		slot.mouse_entered.connect(func() -> void: face.modulate = Color(1.06, 1.04, 0.98))
		slot.mouse_exited.connect(func() -> void: face.modulate = Color.WHITE)
		row.add_child(slot)
	visible = true
