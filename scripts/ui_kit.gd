extends RefCounted
class_name UiKit

# The one place UI chrome comes from. Hard 90° corners via StyleBoxTexture
# 9-slices (assets/ui/), letterpress fonts, tag colors. No StyleBoxFlat
# rounded shapes anywhere.

const INK := Color("#221c14")
const PAPER := Color("#e7dcbd")
const VERMILION := Color("#a02818")
const BRASS := Color("#b18a45")

const TAG_COLORS := {
	"GUN": Color("#6b1a10"), "ROPE": Color("#8a6b3a"), "BLADE": Color("#44505c"),
	"FIRE": Color("#b3541e"), "CARE": Color("#2e6b45"), "TRAIL": Color("#3d5a4e"),
	"GOODS": Color("#7a5a2e"), "KIN": Color("#a02818")
}

static var _display_font: SystemFont
static var _body_font: SystemFont
static var _panels: Dictionary = {}

static func display_font() -> SystemFont:
	if _display_font == null:
		_display_font = SystemFont.new()
		_display_font.font_names = PackedStringArray(["Playbill", "Rockwell", "Georgia"])
		_display_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _display_font

static func body_font() -> SystemFont:
	if _body_font == null:
		_body_font = SystemFont.new()
		_body_font.font_names = PackedStringArray(["Bookman Old Style", "Palatino Linotype", "Georgia"])
	return _body_font

# panel("paper" | "wood" | "socket" | "stamp" | "plate") -> StyleBoxTexture
static func panel(kind: String) -> StyleBox:
	if _panels.has(kind):
		return _panels[kind]
	var box := StyleBoxTexture.new()
	match kind:
		"paper":
			box.texture = load("res://assets/ui/panel_paper.png")
		"wood":
			box.texture = load("res://assets/ui/panel_wood.png")
		"socket":
			box.texture = load("res://assets/ui/panel_socket.png")
		"stamp":
			box.texture = load("res://assets/ui/stamp_red.png")
		"plate":
			# The printed-plate frame is paper with its ink rule doing the work.
			box.texture = load("res://assets/ui/panel_paper.png")
	box.texture_margin_left = 12.0
	box.texture_margin_right = 12.0
	box.texture_margin_top = 12.0
	box.texture_margin_bottom = 12.0
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	_panels[kind] = box
	return box

static func label(text_value: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_override("font", body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

# The one card face, shared by the hand and the SPOILS screen. Pure visual —
# never receives mouse; the node that holds it decides what clicks mean.
static func card_face(data: Dictionary, cost: int) -> PanelContainer:
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", panel("paper"))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_row)
	var title := label(str(data.get("title", "")), 15, INK)
	title.add_theme_font_override("font", display_font())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title)
	var cost_stamp := PanelContainer.new()
	cost_stamp.add_theme_stylebox_override("panel", panel("stamp"))
	title_row.add_child(cost_stamp)
	var cost_label := label(str(cost), 14, Color("#f6efdc"))
	cost_label.add_theme_font_override("font", display_font())
	cost_stamp.add_child(cost_label)
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
	var rules := label(str(data.get("rules_text", "")), 11, Color("#4b3d2a"))
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.max_lines_visible = 3
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rules)
	var tag := str(data.get("tag", ""))
	if not tag.is_empty():
		var tag_chip := PanelContainer.new()
		var chip_style := panel("wood").duplicate() as StyleBoxTexture
		chip_style.modulate_color = TAG_COLORS.get(tag, Color.WHITE)
		tag_chip.add_theme_stylebox_override("panel", chip_style)
		tag_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tag_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tag_chip)
		var tag_label := label(tag, 9, Color("#f6efdc"))
		tag_label.add_theme_font_override("font", display_font())
		tag_chip.add_child(tag_label)
	return face
