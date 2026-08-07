extends SceneTree

# Boots the real game with rendering, drives to an encounter, and saves
# PNG frames to user:// so they can be reviewed outside the engine.
# Run: Summer.exe --path . --script res://tests/visual_probe.gd

var game: Control
var shot := 0

func _initialize() -> void:
	var packed: PackedScene = load("res://main.tscn")
	game = packed.instantiate()
	root.add_child(game)
	_run.call_deferred()

func _snap(tag: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	shot += 1
	image.save_png("user://probe_%02d_%s.png" % [shot, tag])

func _run() -> void:
	await create_timer(0.8).timeout
	await _snap("camp")
	game.seed_edit.text = "1848"
	game.camp_start_button.pressed.emit()
	await create_timer(0.5).timeout
	await _snap("map_idle")
	# Travel once to catch the focused event scene (card-driven, sheet centered).
	game.probe_continue_button.pressed.emit()
	await create_timer(0.2).timeout
	if game.pending_leave_confirm:
		game.probe_continue_button.pressed.emit()
	await create_timer(0.7).timeout
	if game.event_active:
		await _snap("event_scene")
	# March to the first fight (leg 3).
	var guard := 0
	var reward_snapped := false
	while not game.encounter_active and guard < 30:
		guard += 1
		if game.pa_choice_active:
			game.probe_pa_wagon.pressed.emit()
		elif game.letter_pending:
			game.probe_seal_letter.pressed.emit()
		elif game.shop_open:
			game.probe_shop_leave.pressed.emit()
		elif game.reward_pending:
			if not reward_snapped:
				reward_snapped = true
				await _snap("reward_cards")
			game.probe_reward_skip.pressed.emit()
		elif game.event_active:
			game.probe_event_b.pressed.emit()
		else:
			game.probe_continue_button.pressed.emit()
			await create_timer(0.15).timeout
			if game.pending_leave_confirm:
				game.probe_continue_button.pressed.emit()
		await create_timer(0.15).timeout
	await create_timer(1.2).timeout
	await _snap("fight_idle")
	# Hover a card for the reveal.
	if game.card_buttons.size() > 2 and is_instance_valid(game.card_buttons[2]):
		game._on_hand_card_hover(game.card_buttons[2], true)
		await create_timer(0.35).timeout
		await _snap("card_hover")
		game._on_hand_card_hover(game.card_buttons[2], false)
	# Play a combat card and catch the strike.
	var played := false
	for i in game.hand.size():
		if game._can_play(game.hand[i]) and game.CARDS[game.hand[i]]["type"] == "combat":
			game._on_card_pressed(i)
			played = true
			break
	if played:
		await create_timer(0.12).timeout
		await _snap("strike")
	# Brace and catch the lunge.
	if game.encounter_active:
		game.probe_continue_button.pressed.emit()
		await create_timer(0.2).timeout
		await _snap("lunge")
	await create_timer(0.6).timeout
	await _snap("fight_after")
	quit()
