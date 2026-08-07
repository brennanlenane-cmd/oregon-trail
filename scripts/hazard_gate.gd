extends PanelContainer
class_name HazardGate

# The Hazard Gate: a physical obstacle on the manifest. A painting, a 2-word
# title, a penalty badge, and a CardSocket cut into the painting's bottom edge.
# Feed it the right card and a CLEARED stamp slams down; refuse and FORGE AHEAD
# takes the printed penalty.

signal cleared(hazard: Dictionary)
signal forged(hazard: Dictionary)
signal trigger_juice(shake_intensity: float, sound_event: String)

@export var painting: Texture2D
@export var title := "WASHED-OUT ROAD"
@export var penalty_text := "+1 DAY"
@export var required_tag := "TRAIL"
@export var pay_text := "→  -1 DAY"

var hazard: Dictionary = {}
var resolved := false

var title_label: Label
var art_rect: TextureRect
var socket: Control
var socket_label: Label
var pay_label: Label
var forge_button: Button
var stamp_label: Label
var pulse_tween: Tween

func _ready() -> void:
	_build()

func configure(new_hazard: Dictionary) -> void:
	hazard = new_hazard
	title = str(new_hazard.get("title", title))
	penalty_text = str(new_hazard.get("pass", penalty_text))
	required_tag = str(new_hazard.get("tag", required_tag))
	pay_text = "→  %s" % str(new_hazard.get("pay", ""))
	var art_path := str(new_hazard.get("art", ""))
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		painting = load(art_path) as Texture2D
	resolved = false
	_refresh()

func _build() -> void:
	add_theme_stylebox_override("panel", UiKit.panel("paper"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	title_label = UiKit.label(title, 24, UiKit.INK)
	title_label.add_theme_font_override("font", UiKit.display_font())
	box.add_child(title_label)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiKit.panel("plate"))
	box.add_child(plate)
	art_rect = TextureRect.new()
	art_rect.custom_minimum_size = Vector2(0, 200)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.add_child(art_rect)
	# The socket hangs over the painting's bottom edge.
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(overlay)
	socket = Control.new()
	socket.anchor_left = 0.5
	socket.anchor_right = 0.5
	socket.anchor_top = 1.0
	socket.anchor_bottom = 1.0
	socket.offset_left = -66.0
	socket.offset_right = 66.0
	socket.offset_top = -56.0
	socket.offset_bottom = 26.0
	socket.add_to_group("drop_targets")
	socket.set_meta("gate", self)
	socket.set_script(preload("res://scripts/card_socket.gd"))
	overlay.add_child(socket)
	var socket_panel := PanelContainer.new()
	socket_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	socket_panel.add_theme_stylebox_override("panel", UiKit.panel("socket"))
	socket_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socket.add_child(socket_panel)
	var socket_box := VBoxContainer.new()
	socket_box.alignment = BoxContainer.ALIGNMENT_CENTER
	socket_panel.add_child(socket_box)
	socket_label = UiKit.label("[%s]" % required_tag, 18, Color("#f0d9a8"))
	socket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	socket_label.add_theme_font_override("font", UiKit.display_font())
	socket_box.add_child(socket_label)
	var drop_hint := UiKit.label("DROP CARD", 9, Color("#c9b98e"))
	drop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	socket_box.add_child(drop_hint)
	pay_label = UiKit.label(pay_text, 15, Color("#1f5c33"))
	pay_label.custom_minimum_size = Vector2(0, 42)
	pay_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	pay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(pay_label)
	forge_button = Button.new()
	forge_button.custom_minimum_size = Vector2(0, 42)
	forge_button.add_theme_stylebox_override("normal", UiKit.panel("wood"))
	forge_button.add_theme_stylebox_override("hover", UiKit.panel("wood"))
	forge_button.add_theme_color_override("font_color", Color("#e7dcbd"))
	forge_button.add_theme_font_override("font", UiKit.display_font())
	forge_button.add_theme_font_size_override("font_size", 14)
	forge_button.pressed.connect(_on_forge)
	box.add_child(forge_button)
	# The verdict stamp, hidden until a card answers.
	stamp_label = UiKit.label("CLEARED", 54, Color("#a02818"))
	stamp_label.add_theme_font_override("font", UiKit.display_font())
	stamp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp_label.rotation_degrees = -8.0
	stamp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_label.visible = false
	add_child(stamp_label)
	_refresh()

func _refresh() -> void:
	if title_label == null:
		return
	title_label.text = title
	socket_label.text = "[%s]" % required_tag
	pay_label.text = pay_text
	forge_button.text = "FORGE AHEAD  ·  %s" % penalty_text
	forge_button.disabled = resolved
	art_rect.texture = painting
	stamp_label.visible = false

# CardSocket delegates here.
func socket_accepts(card_data: Dictionary) -> bool:
	return not resolved and str(card_data.get("tag", "")) == required_tag

func socket_receive(card_data: Dictionary) -> void:
	if resolved:
		return
	resolved = true
	forge_button.disabled = true
	stamp_label.visible = true
	stamp_label.pivot_offset = stamp_label.size / 2.0
	stamp_label.scale = Vector2(2.4, 2.4)
	stamp_label.modulate = Color(1, 1, 1, 0)
	var slam := create_tween()
	slam.set_parallel(true)
	slam.tween_property(stamp_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	slam.tween_property(stamp_label, "modulate", Color.WHITE, 0.1)
	trigger_juice.emit(6.0, "stamp")
	cleared.emit(hazard if not hazard.is_empty() else {"tag": required_tag})

func set_socket_pulse(active: bool) -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	socket.scale = Vector2.ONE
	if active and not resolved:
		socket.pivot_offset = socket.size / 2.0
		pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(socket, "scale", Vector2(1.07, 1.07), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(socket, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_forge() -> void:
	if resolved:
		return
	resolved = true
	forge_button.disabled = true
	trigger_juice.emit(2.0, "wagon-roll")
	forged.emit(hazard)
