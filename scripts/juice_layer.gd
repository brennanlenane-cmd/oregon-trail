extends Node
class_name JuiceLayer

# Owns feel: screen shake and sound. Everything reaches it through
# GameState.juice_requested — no gameplay node touches audio or the camera.

const SOUNDS := {
	"card-play": "res://assets/audio/card-play.wav",
	"stamp": "res://assets/audio/stamp.wav",
	"hit": "res://assets/audio/hit.wav",
	"click": "res://assets/audio/click.wav",
	"gunshot": "res://assets/audio/gunshot.wav",
	"growl": "res://assets/audio/growl.wav",
	"wagon-roll": "res://assets/audio/wagon-roll.wav",
}

var shake_target: Control
var players: Dictionary = {}
var shake_tween: Tween
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	for key in SOUNDS.keys():
		if ResourceLoader.exists(SOUNDS[key]):
			var player := AudioStreamPlayer.new()
			player.stream = load(SOUNDS[key])
			player.volume_db = -6.0
			add_child(player)
			players[key] = player
	GameState.juice_requested.connect(_on_juice)

func _on_juice(shake_intensity: float, sound_event: String) -> void:
	if players.has(sound_event):
		players[sound_event].play()
	if shake_intensity > 0.0:
		shake(shake_intensity)

func shake(strength: float) -> void:
	if shake_target == null:
		return
	if shake_tween != null and shake_tween.is_valid():
		shake_tween.kill()
		shake_target.position = Vector2.ZERO
	var jolt := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.6, 0.6)).normalized() * strength
	shake_tween = create_tween()
	shake_tween.tween_property(shake_target, "position", jolt, 0.03)
	shake_tween.tween_property(shake_target, "position", -jolt * 0.6, 0.05)
	shake_tween.tween_property(shake_target, "position", Vector2.ZERO, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
