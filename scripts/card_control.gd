extends Control
class_name CardControl

# A draggable card. Pure input handling and visual response — no game rules.
# The table listens to card_played / trigger_juice and talks to GameState.

signal card_played(card_data: Dictionary)
signal trigger_juice(shake_intensity: float, sound_event: String)
signal stoke_requested(card_data: Dictionary)

const HOVER_SCALE := Vector2(1.1, 1.1)
const DRAG_TILT_MAX := 9.0          # degrees of velocity lean while dragged
const SPRING_TIME := 0.28

@export var card_data: Dictionary = {}
@export var hand_index := 0

var home_position := Vector2.ZERO   # hand slot the spring returns to
var home_rotation := 0.0
var dragging := false
var drag_offset := Vector2.ZERO
var last_mouse := Vector2.ZERO
var hover_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size / 2.0
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

func _on_hover(hovering: bool) -> void:
	if dragging:
		return
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()
	hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(self, "scale", HOVER_SCALE if hovering else Vector2.ONE, 0.12)
	if hovering:
		trigger_juice.emit(0.0, "click")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_drag(event.global_position)
			elif dragging:
				_end_drag(event.global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if not str(card_data.get("kin", "")).is_empty():
				stoke_requested.emit(card_data)
	elif event is InputEventMouseMotion and dragging:
		_drag_to(event.global_position)

func _begin_drag(at: Vector2) -> void:
	dragging = true
	drag_offset = global_position - at
	last_mouse = at
	z_index = 100
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()
	scale = HOVER_SCALE

func _drag_to(at: Vector2) -> void:
	var velocity := at - last_mouse
	last_mouse = at
	global_position = at + drag_offset
	# Velocity lean: the card banks into the movement like a carried object.
	rotation_degrees = lerpf(rotation_degrees, clampf(velocity.x * 0.9, -DRAG_TILT_MAX, DRAG_TILT_MAX), 0.35)
	var target := _target_under_cursor(at)
	scale = scale.lerp(Vector2.ONE if target != null else HOVER_SCALE, 0.3)

func _end_drag(at: Vector2) -> void:
	dragging = false
	z_index = 0
	var target := _target_under_cursor(at)
	if target != null and target.has_method("accepts") and target.accepts(card_data):
		# Snap onto the target, tell it, then hand control to the table.
		var snap := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		snap.tween_property(self, "global_position", (target as Control).global_position + ((target as Control).size - size * 0.5) / 2.0, 0.08)
		snap.parallel().tween_property(self, "scale", Vector2(0.5, 0.5), 0.08)
		if target.has_method("receive"):
			target.receive(card_data)
		card_played.emit(card_data)
		trigger_juice.emit(4.0, "stamp")
	else:
		_spring_home()

func _spring_home() -> void:
	var spring := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spring.tween_property(self, "position", home_position, SPRING_TIME)
	spring.parallel().tween_property(self, "rotation_degrees", home_rotation, SPRING_TIME)
	spring.parallel().tween_property(self, "scale", Vector2.ONE, SPRING_TIME)
	trigger_juice.emit(0.0, "click")

func _target_under_cursor(at: Vector2) -> Control:
	for node in get_tree().get_nodes_in_group("drop_targets"):
		var target := node as Control
		if target != null and target.visible and target.get_global_rect().has_point(at):
			if target.has_method("accepts") and target.accepts(card_data):
				return target
	return null
