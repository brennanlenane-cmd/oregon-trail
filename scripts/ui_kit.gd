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
