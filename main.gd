extends Control

class TrailMapCanvas extends Control:
	signal route_selected(index: int)
	signal road_selected(option: int)
	var current_index := 0
	var stop_names: Array[String] = []
	# The fork: two roads to the next landmark, chosen by clicking a stamp
	# on the map itself. Option 0 is the drawn main trail, 1 is the detour arc.
	var fork_active := false
	var fork_names: Array[String] = []
	var fork_terms: Array[String] = []
	var hovered_road := -1
	var _stamp_rects: Array[Rect2] = []
	# EAST ON THE RIGHT, WEST ON THE LEFT — the wagon crawls right-to-left
	# across the parchment like a journey line in a picture show.
	# Independence sits bottom-right; Oregon City waits top-left.
	var route_points := [
		Vector2(0.92, 0.80), Vector2(0.83, 0.63), Vector2(0.73, 0.72), Vector2(0.64, 0.49),
		Vector2(0.54, 0.58), Vector2(0.45, 0.36), Vector2(0.35, 0.46), Vector2(0.26, 0.27),
		Vector2(0.16, 0.35), Vector2(0.07, 0.17), Vector2(0.04, 0.08)
	]
	var branch_routes := [
		[Vector2(0.83, 0.63), Vector2(0.75, 0.43), Vector2(0.63, 0.31), Vector2(0.54, 0.58)],
		[Vector2(0.54, 0.58), Vector2(0.45, 0.73), Vector2(0.33, 0.69), Vector2(0.26, 0.27)],
		[Vector2(0.35, 0.46), Vector2(0.23, 0.54), Vector2(0.12, 0.50), Vector2(0.07, 0.17)]
	]
	var landmark_labels := ["CAMP", "TOWN", "FORT", "DANGER", "CAMP", "FORT", "DANGER", "TOWN", "DANGER", "DESTINATION", "OREGON"]
	var label_font: Font
	# The family, marching at the head of the red line — 16-bit pilgrims on a
	# period map, like the journey scene in a picture show.
	var march_textures: Array[Texture2D] = []
	var wagon_texture: Texture2D
	var march_phase := 0.0

	func _process(delta: float) -> void:
		if visible and not march_textures.is_empty():
			march_phase += delta
			queue_redraw()

	# The drawn trail has 11 nodes standing in for 14 route stops.
	func _node_index_for_stop(stop_index: int) -> int:
		return clampi(int(round(float(stop_index) * float(route_points.size() - 1) / 13.0)), 0, route_points.size() - 1)

	func _current_node() -> int:
		return _node_index_for_stop(current_index)

	func _stop_for_node(node_index: int) -> int:
		return clampi(int(round(float(node_index) * 13.0 / float(route_points.size() - 1))), 0, 13)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and fork_active:
			var was := hovered_road
			hovered_road = -1
			for i in _stamp_rects.size():
				if _stamp_rects[i].grow(6.0).has_point((event as InputEventMouseMotion).position):
					hovered_road = i
			if was != hovered_road:
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered_road >= 0 else Control.CURSOR_ARROW
				queue_redraw()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and size.x > 0.0 and size.y > 0.0:
			var click_position: Vector2 = (event as InputEventMouseButton).position
			if fork_active:
				for i in _stamp_rects.size():
					if _stamp_rects[i].grow(6.0).has_point(click_position):
						road_selected.emit(i)
						return
			var nearest := 0
			var nearest_distance := INF
			for i in route_points.size():
				var point := Vector2(route_points[i].x * size.x, route_points[i].y * size.y)
				var distance := point.distance_to(click_position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest = i
			if nearest_distance < 60.0:
				route_selected.emit(_stop_for_node(nearest))

	func _alt_curve_points() -> PackedVector2Array:
		# Quadratic arc from the wagon's node to the next, bowed away from the
		# main line so both roads read at a glance.
		var arc := PackedVector2Array()
		var node := _current_node()
		if node >= route_points.size() - 1:
			return arc
		var from := Vector2(route_points[node].x * size.x, route_points[node].y * size.y)
		var to := Vector2(route_points[node + 1].x * size.x, route_points[node + 1].y * size.y)
		var mid := (from + to) * 0.5
		var perpendicular := (to - from).orthogonal().normalized()
		# Bow toward whichever side has more canvas.
		if (mid + perpendicular * 60.0).y < 0.0 or (mid + perpendicular * 60.0).y > size.y:
			perpendicular = -perpendicular
		if mid.y < size.y * 0.45 and perpendicular.y < 0.0:
			perpendicular = -perpendicular
		var control := mid + perpendicular * clampf(size.y * 0.22, 46.0, 110.0)
		for step in range(13):
			var t := float(step) / 12.0
			arc.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
		return arc

	func _dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float, gap: float) -> void:
		var length := from.distance_to(to)
		var direction := (to - from).normalized()
		var travelled := 0.0
		while travelled < length:
			var segment_end := minf(travelled + dash, length)
			draw_line(from + direction * travelled, from + direction * segment_end, color, width, true)
			travelled = segment_end + gap

	func _dotted_line(from: Vector2, to: Vector2, color: Color, step: float, radius: float) -> void:
		var length := from.distance_to(to)
		var direction := (to - from).normalized()
		var travelled := 0.0
		while travelled <= length:
			draw_circle(from + direction * travelled, radius, color)
			travelled += step

	func _draw() -> void:
		if route_points.is_empty() or size.x <= 0.0 or size.y <= 0.0:
			return
		var font := label_font if label_font != null else ThemeDB.fallback_font
		var ink := Color(0.29, 0.24, 0.18, 1.0)
		var faint_ink := Color(0.35, 0.30, 0.24, 0.45)
		# The painted chart beneath carries the geography — this overlay only
		# inks the JOURNEY onto it: iron-gall lines, vermilion stamp red.
		# --- The journey line: red dashes where the wagon has been -------
		var current_node := _current_node()
		for i in range(route_points.size() - 1):
			var from := Vector2(route_points[i].x * size.x, route_points[i].y * size.y)
			var to := Vector2(route_points[i + 1].x * size.x, route_points[i + 1].y * size.y)
			if i < current_node:
				_dashed_line(from, to, Color("#8c2d19"), 4.0, 11.0, 7.0)
			else:
				_dotted_line(from, to, Color(0.15, 0.11, 0.08, 0.75), 13.0, 2.2)
		for branch in branch_routes:
			for j in range(branch.size() - 1):
				var branch_from := Vector2(branch[j].x * size.x, branch[j].y * size.y)
				var branch_to := Vector2(branch[j + 1].x * size.x, branch[j + 1].y * size.y)
				_dotted_line(branch_from, branch_to, Color(0.45, 0.38, 0.30, 0.3), 15.0, 1.4)
		# --- Stops: real names on the paper, dangers marked with a skull --
		for i in route_points.size():
			var point := Vector2(route_points[i].x * size.x, route_points[i].y * size.y)
			var visited := i < current_node
			var current := i == current_node
			var destination := i == route_points.size() - 1
			var danger: bool = str(landmark_labels[i]) == "DANGER" and not visited
			# Markers stay small — the map is the star, the dots are punctuation.
			if danger:
				draw_circle(point, 5.0, Color("#30251b"))
				draw_circle(point, 3.4, Color("#a02818"))
				draw_string(font, point + Vector2(-5, -8), "☠", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a02818"))
			else:
				draw_circle(point, 4.0 if current else 3.4, Color("#30251b"))
				draw_circle(point, 2.6 if current else 2.0, Color("#4e7a5e") if visited else (Color("#e4bd65") if current or destination else Color(0.75, 0.68, 0.55)))
			var stop_name := ""
			if not stop_names.is_empty():
				stop_name = str(stop_names[_stop_for_node(i)])
			if stop_name != "":
				var name_color := Color("#a02818") if destination else ink
				# Three-step stagger keeps neighboring names off each other.
				var dy: float = [-12.0, 20.0, -24.0][i % 3]
				var name_width := font.get_string_size(stop_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
				# A little paper chip under each name so it stays legible over
				# the painted terrain — a pasted-on gazetteer label.
				draw_rect(Rect2(point.x - name_width * 0.5 - 3.0, point.y + dy - 9.0, name_width + 6.0, 12.0), Color(0.94, 0.90, 0.79, 0.72))
				draw_string(font, point + Vector2(-name_width * 0.5, dy), stop_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, name_color)
			if current and wagon_texture != null:
				# The marker IS the wagon — parked right on the node, swaying.
				var wagon_h := 31.0
				var wagon_w := wagon_texture.get_width() * (wagon_h / wagon_texture.get_height())
				var sway := sin(march_phase * 3.0) * 1.0
				_draw_piece_shadow(point.x, point.y + 2.5, wagon_w * 0.9)
				draw_texture_rect(wagon_texture, Rect2(Vector2(point.x - wagon_w * 0.5, point.y - wagon_h + 2.0 + sway), Vector2(wagon_w, wagon_h)), false)
			elif current:
				draw_circle(point, 10.0, Color("#a02818"), false, 2.0)
		_draw_march()
		_draw_fork()

	func _draw_piece_shadow(center_x: float, ground_y: float, width: float) -> void:
		# A tight soft ellipse under each piece anchors it to the paper —
		# game pieces sitting ON the map, not sprites floating over it.
		var points := PackedVector2Array()
		for step in range(14):
			var angle := TAU * float(step) / 14.0
			points.append(Vector2(center_x + cos(angle) * width * 0.42, ground_y + sin(angle) * 3.2))
		draw_colored_polygon(points, Color(0.14, 0.10, 0.06, 0.20))

	func _draw_march() -> void:
		# The little column walks in place just behind the wagon's node,
		# strung out along the trail they came in on, bobbing out of step.
		if march_textures.is_empty():
			return
		var node := _current_node()
		var head := Vector2(route_points[node].x * size.x, route_points[node].y * size.y)
		# The column trails behind the wagon node — except at Independence,
		# where behind is off the paper: there they string out AHEAD, setting out.
		var back_direction: Vector2
		if node > 0:
			back_direction = (Vector2(route_points[node - 1].x * size.x, route_points[node - 1].y * size.y) - head).normalized()
		else:
			back_direction = (Vector2(route_points[1].x * size.x, route_points[1].y * size.y) - head).normalized()
		for i in march_textures.size():
			var sprite := march_textures[i]
			if sprite == null:
				continue
			var sprite_h := 26.0
			var sprite_w := sprite.get_width() * (sprite_h / sprite.get_height())
			var spot := head + back_direction * (46.0 + float(i) * 17.0)
			var bob := sin(march_phase * 7.0 + float(i) * 1.3) * 1.4
			_draw_piece_shadow(spot.x, spot.y + 1.5, sprite_w)
			draw_texture_rect(sprite, Rect2(Vector2(spot.x - sprite_w * 0.5, spot.y - sprite_h + bob), Vector2(sprite_w, sprite_h)), false)

	func _draw_fork() -> void:
		_stamp_rects.clear()
		var node := _current_node()
		if not fork_active or fork_names.size() < 2 or node >= route_points.size() - 1:
			return
		var arc := _alt_curve_points()
		if arc.is_empty():
			return
		# The detour arc, drawn dashed-ish so the main trail stays the main trail.
		for j in range(arc.size() - 1):
			var width := 5.0 if hovered_road == 1 else 3.0
			draw_line(arc[j], arc[j + 1], Color("#8d4b32") if hovered_road == 1 else Color("#a98a5b"), width, true)
		var from := Vector2(route_points[node].x * size.x, route_points[node].y * size.y)
		var to := Vector2(route_points[node + 1].x * size.x, route_points[node + 1].y * size.y)
		if hovered_road == 0:
			draw_line(from, to, Color("#a02818"), 4.0, true)
		var anchors := [(from + to) * 0.5, arc[6]]
		var font := label_font if label_font != null else ThemeDB.fallback_font
		for i in range(2):
			var name_width := font.get_string_size(fork_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var terms_width := font.get_string_size(fork_terms[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var stamp_size := Vector2(maxf(name_width, terms_width) + 22.0, 42.0)
			var stamp := Rect2(Vector2(anchors[i]) - stamp_size * 0.5, stamp_size)
			stamp.position.x = clampf(stamp.position.x, 4.0, size.x - stamp.size.x - 4.0)
			stamp.position.y = clampf(stamp.position.y, 4.0, size.y - stamp.size.y - 4.0)
			_stamp_rects.append(stamp)
			var hovered := hovered_road == i
			var stamp_style := StyleBoxFlat.new()
			stamp_style.bg_color = Color("#fbf5e4") if hovered else Color(0.96, 0.92, 0.82, 0.94)
			stamp_style.border_color = Color("#a02818") if hovered else Color("#30251b")
			stamp_style.set_border_width_all(2 if hovered else 1)
			stamp_style.set_corner_radius_all(3)
			draw_style_box(stamp_style, stamp)
			draw_string(font, stamp.position + Vector2(11, 17), fork_names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a02818") if hovered else Color("#221c14"))
			draw_string(font, stamp.position + Vector2(11, 33), fork_terms[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#4b3d2a"))

const CARD_DATA = preload("res://data/cards.gd")
const CARDS: Dictionary = CARD_DATA.CARDS
const STARTER_DECK: Array = CARD_DATA.STARTER_DECK
const PARTY_DATA = preload("res://data/party.gd")
const TRINKETS = preload("res://data/trinkets.gd")
const BARK_DATA = preload("res://data/barks.gd")
const STORY = preload("res://data/story.gd")
const SAVE_PATH := "user://savegame.json"
const PROFILE_PATH := "user://profile.json"
# The ladder: each level ADDS one hardship you can read in a sentence.
const TRAILBLAZER_RULES := [
	"Thin Air — supplies drain +1 per travel day",
	"Fever Season — sickness risks are doubled",
	"Outlaw Country — every 2nd leg is dangerous",
	"Lean Times — card rewards offer only 2 choices",
	"Grudge — threats hit 2 harder",
	"Worn Axles — the wagon starts at 80",
	"No Credit — shop prices +25%",
	"The Long Dark — threats have +25% health"
]
# Cards that start locked; the number is finished runs (win or lose) to earn them.
const LOCKED_CARDS := {"wainwright": 2, "steady_nerve": 3, "trail_map": 4}
# Two roads to every landmark: the main trail, and a detour with teeth.
# The alternate is seeded per leg, so a shared trail seed shares its forks.
const MAIN_ROAD := {"id": "main", "name": "THE MAIN TRAIL", "terms": "steady wheels"}
const ALT_ROADS := [
	{"id": "river", "name": "RIVER ROAD", "terms": "1 day quicker · the water may be bad", "days": -1, "sick_risk": 0.3},
	{"id": "high", "name": "HIGH TRAIL", "terms": "+1 day · no ambush country", "days": 1, "safe": true},
	{"id": "toll", "name": "TOLL ROAD", "terms": "$6 · saves a day", "days": -1, "toll": 6},
	{"id": "hunting", "name": "HUNTING TRAIL", "terms": "+6 supplies · wilder country", "days": 1, "supplies": 6, "danger": 0.25}
]
const CONDITION_NAMES := ["HEALTHY", "HURT", "SICK"]
const CONDITION_COLORS := ["#2e6b45", "#9a6b00", "#a02818"]
const ROUTE_STOPS := [
	"Independence", "Kansas River", "Fort Kearny", "Chimney Rock", "Fort Laramie",
	"Independence Rock", "South Pass", "Soda Springs", "Fort Hall", "Snake River",
	"Blue Mountains", "The Dalles", "Barlow Pass", "Oregon City"
]
const EVENTS := [
	{"title": "A Clear Morning", "body": "The river crossing looks deep, but a scout knows a safer ford.", "card_type": "scout", "card_label": "a scout card", "a": "Use the scout's ford", "ad": "Discard a scout card  •  Supplies -2  •  Safe passage", "a_fx": {"supplies": -2}, "b": "Walk around the crossing", "bd": "Free leave  •  Days +1"},
	{"title": "A Trading Post", "body": "A trader admires the wagon's careful records and offers a bargain.", "card_type": "supply", "card_label": "a supply card", "a": "Trade from the ledger", "ad": "Discard a supply card  •  Supplies +6", "a_fx": {"supplies": 6}, "b": "Pass the post", "bd": "Free leave  •  Days +1"},
	{"title": "Night on the Prairie", "body": "The wind rises. Good stories could keep the party together.", "card_type": "morale", "card_label": "a morale card", "a": "Tell the right story", "ad": "Discard a morale card  •  Morale +8", "a_fx": {"morale": 8}, "b": "Sleep under the wagon", "bd": "Free leave  •  Days +1"},
	{"title": "The Washed-Out Road", "body": "Spring rain has erased the road ahead. A map can reveal a shortcut.", "card_type": "scout", "card_label": "a scout card", "a": "Read the old map", "ad": "Discard a scout card  •  Days -1", "a_fx": {"days": -1}, "b": "Take the long way", "bd": "Free leave  •  Days +1"},
	{"title": "A Broken Axle", "body": "The wagon groans at the next rut. Supplies can buy a careful repair.", "card_type": "supply", "card_label": "a supply card", "a": "Spend the spare timber", "ad": "Discard a supply card  •  Supplies +3", "a_fx": {"supplies": 3}, "b": "Limp onward", "bd": "Free leave  •  Days +1"},
	{"title": "A Lonely Camp", "body": "The party is tired. A warm meal and a shared tale restore hope.", "card_type": "morale", "card_label": "a morale card", "a": "Gather everyone close", "ad": "Discard a morale card  •  Morale +6", "a_fx": {"morale": 6}, "b": "Keep watch in silence", "bd": "Free leave  •  Days +1"},
	{"title": "The Mountain Pass", "body": "The climb is steep. A scout can spot the safest switchback.", "card_type": "scout", "card_label": "a scout card", "a": "Find the switchback", "ad": "Discard a scout card  •  Supplies -2  •  Morale +3", "a_fx": {"supplies": -2, "morale": 3}, "b": "Climb by the markers", "bd": "Free leave  •  Days +1"},
	{"title": "The Last Mile", "body": "The valley opens below. One final bit of preparation will steady the wagon.", "card_type": "supply", "card_label": "a supply card", "a": "Secure the wagon", "ad": "Discard a supply card  •  Supplies +4  •  Morale +2", "a_fx": {"supplies": 4, "morale": 2}, "b": "Trust the road", "bd": "Free leave  •  Days +1"},
	{"title": "Bad Water", "body": "The creek runs cloudy and smells wrong. Boiling every drop costs time and fuel.", "card_type": "supply", "card_label": "a supply card", "a": "Boil everything", "ad": "Discard a supply card  •  Supplies -2  •  Everyone stays well", "a_fx": {"supplies": -2}, "b": "Drink and push on", "bd": "Free leave  •  Days +1  •  30% chance: a family member falls sick", "b_risk": 0.3, "art": "res://assets/art/river-crossing.jpg"},
	{"title": "The Bison Herd", "body": "The prairie turns brown and moving — bison past counting. A clean hunt would fill every barrel in the wagon.", "card_type": "scout", "card_label": "a scout card", "a": "Ride into the hunt", "ad": "Discard a scout card  •  Supplies +10  •  Morale +3", "a_fx": {"supplies": 10, "morale": 3}, "b": "Let the herd pass", "bd": "Free leave  •  Days +1", "art": "res://assets/art/bison-hunt.jpg"},
	{"title": "Prairie Fire", "body": "Smoke on the horizon, then a line of orange running with the wind. There is a burned-over stretch that might be crossed — hot, but bare of fuel.", "card_type": "scout", "card_label": "a scout card", "a": "Cross the black ground", "ad": "Discard a scout card  •  Wagon -8  •  No lost days", "a_fx": {"wagon": -8}, "b": "Swing wide around the burn", "bd": "Free leave  •  Days +1", "art": "res://assets/art/prairie-fire.jpg"},
	{"title": "The Snake-Oil Man", "body": "A gleaming wagon, a waxed mustache, and a bottle that allegedly cures fever, gout, and cowardice. He'll trade for supplies.", "card_type": "supply", "card_label": "a supply card", "a": "Buy the tonic", "ad": "Discard a supply card  •  Supplies -3  •  One hurt or sick member recovers a step", "a_fx": {"supplies": -3, "rest": 1}, "b": "Tip your hat and move on", "bd": "Free leave  •  Days +1", "art": "res://assets/art/whiskey-ad.png"},
	{"title": "Gold Fever", "body": "A man rides east shouting that the creeks of California run yellow. Half the camp is repacking. The road to Oregon suddenly looks longer.", "card_type": "morale", "card_label": "a morale card", "a": "Steady the party", "ad": "Discard a morale card  •  Morale +6  •  The family remembers why it's Oregon", "a_fx": {"morale": 6}, "b": "Let them talk it out", "bd": "Free leave  •  Days +1  •  Morale -3", "b_fx": {"morale": -3}, "art": "res://assets/art/gold-panning.jpg"},
	{"title": "Cards at the Post", "body": "Teamsters at the trading post deal a friendly hand. The pot is groceries, mostly. 'Friendly,' they said.", "card_type": "morale", "card_label": "a morale card", "a": "Play a few hands", "ad": "Discard a morale card  •  Supplies +5  •  Morale +2", "a_fx": {"supplies": 5, "morale": 2}, "b": "Watch from the doorway", "bd": "Free leave  •  Days +1", "art": "res://assets/art/saloon-cards.jpg"},
	{"title": "The Circling Birds", "body": "Vultures wheel over something ahead. It turns out to be an abandoned wagon — broken axle, and a note weighted with a river stone: 'Take what you need.'", "card_type": "scout", "card_label": "a scout card", "a": "Search it carefully", "ad": "Discard a scout card  •  Supplies +6", "a_fx": {"supplies": 6}, "b": "Pass with hats off", "bd": "Free leave  •  Days +1  •  Morale +2 — some things matter more", "b_fx": {"morale": 2}, "art": "res://assets/art/vulture.jpg"}
]
const REWARD_POOL := ["river_guide", "wagon_repair", "steady_nerve", "trail_map", "wainwright", "rifle", "medicine"]
const ENCOUNTERS := [
	{"title": "Bandit Ambush", "name": "Road Agents", "art": "res://assets/sprites/enemies/road-agent.png", "body": "A masked bandit blocks the wagon road, pistol raised. The party has one turn to answer.", "intent": "FIRE ON THE WAGON", "hits": "wagon", "damage": 8, "health": 12, "reward": 6},
	{"title": "Wolf Pack", "name": "Hungry Wolves", "art": "res://assets/sprites/enemies/wolf.png", "body": "A gray pack circles the mules at the edge of camp. Their next lunge will cost supplies.", "intent": "LUNGE AT THE STORES", "hits": "supplies", "damage": 6, "health": 15, "reward": 5},
	{"title": "Grizzly at the Ford", "name": "Grizzly Bear", "art": "res://assets/sprites/enemies/grizzly.png", "body": "A grizzly claims the riverbank. Hold your nerve or the crossing becomes a rout.", "intent": "CHARGE THE PARTY", "hits": "morale", "damage": 9, "health": 26, "reward": 8},
	{"title": "Rattler in the Grass", "name": "Rattlesnake", "art": "res://assets/sprites/enemies/rattlesnake.png", "body": "The buzz comes from underfoot, close enough to count the rattles. Quick and small — but so is a bullet.", "intent": "STRIKE AT THE NERVES", "hits": "morale", "damage": 5, "health": 8, "reward": 3},
	{"title": "Eyes in the Rocks", "name": "Mountain Lion", "art": "res://assets/sprites/enemies/mountain-lion.png", "body": "It has been pacing the wagon since the last switchback, patient as winter, pricing out the food stores.", "intent": "RAID THE PROVISIONS", "hits": "supplies", "damage": 7, "health": 22, "reward": 6},
	{"title": "Toll of the Lonely Road", "name": "Highwaymen", "art": "res://assets/sprites/enemies/highwayman.png", "body": "Three riders block the cut, rifles crossed over saddle horns. 'Road tax,' says the tall one, pricing the wagon with his eyes.", "intent": "SHOOT UP THE WAGON", "hits": "wagon", "damage": 9, "health": 26, "reward": 9}
]

var day := 1
var completed_legs := 0
var route_index := 0
# Combo context: what the current turn has already seen. Resets when a turn
# ends (BRACE), a fight starts, or the wagon rolls out.
var turn_plays: Array[String] = []
var primed: Dictionary = {}  # tag -> multiplier armed for the next matching play
var pending_road := 0        # which road the player picked for the next leg (0 = main trail)
var supplies := 68
var morale := 82
var wagon_health := 100
var injuries := 0
var grit := 3
var feedback_count := 0
var route_transition_count := 0
var card_play_count := 0
var intent_pulse_active := false
var intent_pulse_tween: Tween
var event_active := false
var encounter_active := false
var encounter_index := 0
var encounter_health := 0
var encounter_max_health := 0
var encounter_threat := 0
var encounter_block := 0
var encounter_turn := 0
var encounter_resolved := false
var reward_pending := false
var game_over := false
var victory := false
var current_event_index := 0
var event_order: Array[int] = []
var event_cursor := 0
var reward_options: Array[String] = []
var deck_ids: Array[String] = []
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhausted: Array[String] = []

# ---- The Family ----
var party := {}                     # member_id -> runtime state; see data/party.gd
var graves: Array = []              # [{name, role, stop, day}]
var travel_bonus := 0               # banked days from the ox; spent on the next leg
var event_revealed := false         # Sarah's Keen Eyes: next event's ask is disclosed
var event_hint_member := ""         # member leaning into the current event choice
var event_hint_option := ""         # "a" or "b"
var pending_leave_confirm := false  # misclick protection on CONTINUE with unspent Grit
var pa_choice_active := false       # Pa's Steady Hands: choice overlay is up
var pa_choice_amount := 0
var death_cause := ""               # written into the journal's last page
var letter_pending := false         # a letter home waits to be sealed at a fort
var money := 30                     # coin for the fort sutlers
var shop_open := false              # the sutler's counter blocks the trail while open
var run_modifiers := {}             # camp toggles: well_stocked / steady_oxen / green_country
var run_seed := 1848                # every run rolls its own; type one at camp to share a trail
var character := "gunslinger"       # the chosen identity; each brings its own starting kit
var keepsakes: Array[String] = []   # always-on trinkets; one clause each
var tonics: Array[String] = []      # the belt: three slots, drink anytime, gone forever
var powder_horn_spent := false      # per-fight flag for the Gunslinger's starting keepsake
var character_buttons := {}         # id -> camp selection button
var trailblazer := 0                # stacking named hardships, unlocked by first victory
var profile := {}                   # user://profile.json — wins, finished runs, unlocks, ladder

var day_label: Label
var leg_label: Label
var destination_label: Label
var route_note: Label
var route_row: FlowContainer
var supply_value: Label
var morale_value: Label
var health_value: Label
var location_value: Label
var money_value: Label
var grit_value: Label
var grit_pips: Label
var deck_value: Label
var discard_value: Label
var hand_value: Label
var event_kicker: Label
var event_title: Label
var event_body: Label
var event_hint: Label
var outcome_label: Label
var encounter_art: TextureRect
var encounter_health_label: Label
var encounter_intent_label: Label
var encounter_stake_label: Label
var choice_a: Button
var choice_b: Button
var continue_button: Button
var hand_container: Control
var map_canvas: TrailMapCanvas
var draw_pile_label: Label
var discard_pile_label: Label
var map_event_sheet: PanelContainer
var card_status: Label
var card_buttons: Array[Control] = []   # the card panels; click plays, right-click discards
var discard_buttons: Array[Button] = []
var reward_box: VBoxContainer
var reward_buttons: Array[Button] = []
var camp_overlay: Control
var camp_start_button: Button
var camp_continue_button: Button
var return_to_camp_button: Button
var run_mode := "camp"
var route_choice_label: Label
var roster_row: HBoxContainer
var roster_chips := {}              # member_id -> {panel, label}
var bark_panel: PanelContainer
var bark_label: Label
var bark_tween: Tween
var name_edits := {}                # member_id -> LineEdit on the camp screen
var pile_panel: PanelContainer
var pile_title: Label
var pile_list: Label
var pa_panel: PanelContainer
var pa_title_label: Label
var pa_supplies_button: Button
var pa_wagon_button: Button
var landmark_art_rect: TextureRect
var map_wash_rect: ColorRect
var letter_panel: PanelContainer
var letter_text: Label
var letters_written: Array = []
var probe_seal_letter: Button
var shop_panel: PanelContainer
var shop_title: Label
var shop_buttons: Array[Button] = []
var shop_offers: Array = []
var history_label: Label
var modifier_checks := {}           # key -> CheckBox on the camp screen
var seed_edit: LineEdit
var trinket_row: HBoxContainer
var combat_stage: Control
var wagon_actor: Control
var enemy_actor: Control
var enemy_plate: TextureRect
var stage_hp_fill: ColorRect
var stage_hp_bg: ColorRect
var battle_backdrop: TextureRect
var reward_overlay: Control
var reward_card_row: HBoxContainer
var stage_hp_label: Label
var stage_intent_label: Label
var stage_intent_banner: PanelContainer
var stage_block_label: Label
var stage_hold := false            # keeps the stage up long enough to watch a death
var last_hand_signature := ""      # rebuild the fan only when the hand truly changes
var hand_slots: Array[Control] = []  # stationary hitboxes; the card visuals animate inside them
# Cosmetic dice only — stamps and chips get hand-placed tilts from here so
# the seeded gameplay RNG sequence is never disturbed by UI rebuilds.
var ui_rng := RandomNumberGenerator.new()
# ---- Audio: the trail finally makes a sound ----
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor := 0
var audio_streams := {}
var music_mode := ""
var hand_raised := true            # the hand is a drawer: down unless fighting or reached for
var hand_hover_count := 0
var hand_pinned := false           # the OPEN HAND tab holds the drawer up until clicked again
var hand_tab_button: Button
var last_ui_phase := ""            # travel / event / fight — drives what's on stage
var map_table_panel: PanelContainer
var landmark_plate_panel: PanelContainer
var encounter_art_plate: PanelContainer
# The viewport tree: HUD pinned top, one dynamic content layer in the middle
# (map view XOR encounter view), the hand deck banded at the bottom.
var camp_title_layer: Control      # step 1: the hook — campfire hero + three choices
var camp_manifest_layer: Control   # step 2: the wagon manifest (the old settings page)
var camp_history_modal: PanelContainer
var camp_history_modal_label: Label
var title_continue_button: Button
var camp_advanced_row: HBoxContainer
var top_hud_bar: Control
var dynamic_content_layer: Control
var map_view: Control
var encounter_view: Control
var player_hand_deck: Control
var drop_highlight: PanelContainer   # lights up when a dragged card can land
var keepsake_box: HBoxContainer
var tonic_slots: Array[Button] = []
var tb_label: Label
var tb_rules_label: Label
var tb_row: HBoxContainer
var probe_shop_buttons: Array[Button] = []
var probe_shop_leave: Button

# Letterpress typography: Playbill wood-type for headlines, Bookman for body ink.
var font_display: SystemFont
var font_body: SystemFont

func _load_fonts() -> void:
	font_display = SystemFont.new()
	font_display.font_names = PackedStringArray(["Playbill", "Rockwell", "Georgia"])
	# Tried AA-off for hard print edges — it shreds Playbill below ~20px into
	# illegible mush. Antialiasing stays; crispness comes from pixel snap only.
	font_display.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font_body = SystemFont.new()
	font_body.font_names = PackedStringArray(["Bookman Old Style", "Palatino Linotype", "Georgia"])

var probe_continue_button: Button
var probe_event_a: Button
var probe_event_b: Button
var probe_reward_skip: Button
var probe_reward_buttons: Array[Button] = []
var probe_play_buttons: Array[Button] = []
var probe_discard_buttons: Array[Button] = []
var probe_pa_supplies: Button
var probe_pa_wagon: Button
var probe_view_draw: Button
var probe_view_discard: Button
var probe_view_deck: Button
var probe_close_pile: Button
var probe_camp_continue: Button

# ---- Actual encounter deckbuilder surface (uses the same run piles above) ----
var deckbuilder_overlay: Control
var deckbuilder_hand_row: HBoxContainer
var deckbuilder_draw_count: Label
var deckbuilder_discard_count: Label
var deckbuilder_energy_label: Label
var deckbuilder_turn_label: Label
var deckbuilder_enemy_label: Label
var deckbuilder_status_label: Label
var deckbuilder_brace_button: Button
var deckbuilder_card_buttons: Array[Button] = []
var deckbuilder_energy := 3
var deckbuilder_turn := 1
var deckbuilder_enemy_health := 0
var deckbuilder_enemy_max_health := 0
var deckbuilder_enemy_intent := ""
var deckbuilder_block := 0
var deckbuilder_encounter_ready := false

func _wire_hand_card_juice() -> void:
	# Retired: hover/click now wire onto the stationary slots inside
	# _rebuild_hand_ui. The visual card never owns the mouse — a card that
	# rises out from under the cursor used to fire exit/enter forever (the
	# "stutter"). The slot stays put, so hover state stays put.
	pass

# ---- Card drag & drop: pick a card up and drop it on the table ----------
func _slot_drag_data(_at: Vector2, slot: Control, index: int) -> Variant:
	if index < 0 or index >= hand.size() or index >= card_buttons.size():
		return null
	if not is_instance_valid(card_buttons[index]):
		return null
	var preview := card_buttons[index].duplicate() as Control
	preview.rotation = 0.0
	preview.scale = Vector2(0.8, 0.8)
	preview.modulate = Color(1, 1, 1, 0.92)
	slot.set_drag_preview(preview)
	return {"card_index": index}

func _zone_can_drop(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not (data as Dictionary).has("card_index"):
		return false
	var index := int((data as Dictionary)["card_index"])
	if index < 0 or index >= hand.size():
		return false
	var card_id := hand[index]
	var acceptable := false
	if event_active and not encounter_active and current_event_index >= 0 and current_event_index < EVENTS.size():
		acceptable = str(CARDS[card_id].get("type", "")) == str(EVENTS[current_event_index]["card_type"])
	elif encounter_active:
		acceptable = _can_play(card_id)
	if drop_highlight != null:
		drop_highlight.visible = acceptable
	return acceptable

func _zone_drop(_at: Vector2, data: Variant) -> void:
	if drop_highlight != null:
		drop_highlight.visible = false
	_on_card_pressed(int((data as Dictionary)["card_index"]))

func _update_hand_tuck() -> void:
	# CARD PHASE state: the hand doesn't sit out all game. It rides low with
	# just the card tops peeking over the bottom bar, rises when the player
	# reaches for it, stays up through a fight, and offers itself when an
	# event can actually be paid with a card from it.
	if hand_container == null:
		return
	var event_wants_card := false
	if event_active and current_event_index >= 0 and current_event_index < EVENTS.size():
		event_wants_card = _find_card_in_hand(str(EVENTS[current_event_index]["card_type"])) >= 0
	var desired := encounter_active or hand_hover_count > 0 or event_wants_card or hand_pinned
	if hand_tab_button != null:
		hand_tab_button.text = ("▼  CLOSE HAND" if hand_pinned else "▲  OPEN HAND · %d" % hand.size()) if not encounter_active else "▲  HAND · %d" % hand.size()
	if desired == hand_raised:
		return
	hand_raised = desired
	var shift := 0.0 if desired else 170.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(hand_container, "offset_top", -290.0 + shift, 0.25)
	tween.tween_property(hand_container, "offset_bottom", 20.0 + shift, 0.25)

func _on_hand_tab_pressed() -> void:
	hand_pinned = not hand_pinned
	_update_hand_tuck()

func _on_hand_area_entered() -> void:
	hand_hover_count += 1
	_update_hand_tuck()

func _on_hand_area_exited() -> void:
	hand_hover_count = maxi(0, hand_hover_count - 1)
	# Grace period so sliding between cards doesn't bounce the drawer.
	get_tree().create_timer(0.28).timeout.connect(_update_hand_tuck)

func _on_hand_card_hover(card: Control, hovering: bool) -> void:
	# `card` is the VISUAL panel; its parent slot is the unmoving hitbox.
	if not is_instance_valid(card) or not card.has_meta("rest_r"):
		return
	var rest_r := float(card.get_meta("rest_r", 0.0))
	var slot := card.get_parent() as Control
	if slot != null:
		slot.z_index = 40 if hovering else int(card.get_meta("rest_z", 0))
	# One motion at a time: kill the wobble AND any in-flight hover tween,
	# then lift far enough to read the whole card (StS-style full reveal).
	if card.has_meta("wob"):
		var wobble: Tween = card.get_meta("wob")
		if wobble != null and wobble.is_valid():
			wobble.kill()
		card.remove_meta("wob")
	if card.has_meta("hover_tween"):
		var old_tween: Tween = card.get_meta("hover_tween")
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
	card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# The band already shows the whole card when raised — the hover is a nudge
	# and a scale, not a leap into the art above.
	tween.tween_property(card, "scale", Vector2(1.1, 1.1) if hovering else Vector2.ONE, 0.15)
	tween.tween_property(card, "position:y", -36.0 if hovering else 0.0, 0.15)
	tween.tween_property(card, "rotation_degrees", 0.0 if hovering else rest_r, 0.15)
	card.set_meta("hover_tween", tween)
	if not hovering:
		tween.finished.connect(_start_hand_wobble.bind(card, rest_r, int(card.get_meta("rest_z", 0))), CONNECT_ONE_SHOT)

func _play_hand_card_flourish(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var start_position := card.position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "position", start_position + Vector2(0.0, -maxf(56.0, card.size.y * 0.9)), 0.22)
	tween.tween_property(card, "modulate:a", 0.0, 0.22)

func _fit_ui_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	if hand_container != null:
		# A true bottom strip: anchored to the floor with a fixed height, so
		# the hand lives in its own bounded band instead of floating over
		# the map. The drawer shift rides on top of these offsets.
		hand_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		hand_container.anchor_left = 0.02
		hand_container.anchor_right = 0.98
		hand_container.anchor_top = 1.0
		hand_container.anchor_bottom = 1.0
		hand_container.offset_left = 0.0
		hand_container.offset_right = 0.0
		var tuck_shift := 0.0 if hand_raised else 170.0
		hand_container.offset_top = -290.0 + tuck_shift
		hand_container.offset_bottom = 20.0 + tuck_shift
		hand_container.clip_contents = false
		var card_count := maxi(1, hand_container.get_child_count())
		var gap := clampf(viewport_size.x * 0.007, 4.0, 9.0)
		if hand_container is Container:
			hand_container.add_theme_constant_override("separation", int(gap))
		var card_width := clampf((viewport_size.x * 0.96 - gap * float(card_count - 1)) / float(card_count), 116.0, 205.0)
		var card_height := clampf(viewport_size.y * 0.285, 158.0, 220.0)
		for card in hand_container.get_children():
			if card is Control:
				card.custom_minimum_size = Vector2(card_width, card_height)
				card.pivot_offset = Vector2(card_width * 0.5, card_height)
				for child in card.get_children():
					if child is Control:
						child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						if child is Label:
							child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if map_canvas != null:
		map_canvas.anchor_left = 0.04
		map_canvas.anchor_right = 0.64
		map_canvas.anchor_top = 0.175
		map_canvas.anchor_bottom = 0.75
	if camp_overlay != null:
		for child in camp_overlay.get_children():
			if child is MarginContainer:
				child.add_theme_constant_override("margin_left", 12)
				child.add_theme_constant_override("margin_right", 12)
				child.add_theme_constant_override("margin_top", 12)
				child.add_theme_constant_override("margin_bottom", 12)
				var page := child.get_child(0) as VBoxContainer
				if page != null:
					page.add_theme_constant_override("separation", 6)
					for page_child in page.get_children():
						if page_child is Label:
							page_child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
						if page_child is HBoxContainer and page_child.name == "CharacterChoice":
							for button in page_child.get_children():
								if button is Button:
									button.custom_minimum_size.y = 48.0
					var heading := page.get_child(0) as Label
					if heading != null:
						heading.add_theme_font_size_override("font_size", 34)

func _ready() -> void:
	ui_rng.randomize()
	_load_fonts()
	var ui_theme := Theme.new()
	ui_theme.default_font = font_body
	ui_theme.default_font_size = 13
	theme = ui_theme
	_load_profile()
	_initialize_run()
	_build_ui()
	_create_stable_probe_nodes()
	if camp_continue_button != null:
		camp_continue_button.visible = FileAccess.file_exists(SAVE_PATH)
	if title_continue_button != null:
		title_continue_button.visible = FileAccess.file_exists(SAVE_PATH)
	_refresh_trailblazer_ui()
	_setup_audio()
	_build_reward_overlay()
	_refresh_ui()
	_juice_all_buttons(self)
	get_viewport().size_changed.connect(_fit_ui_to_viewport)
	_fit_ui_to_viewport.call_deferred()

func _db_render_hand() -> void:
	if deckbuilder_hand_row == null:
		return
	for child in deckbuilder_hand_row.get_children():
		child.queue_free()
	deckbuilder_card_buttons.clear()
	for i in hand.size():
		var card_id := hand[i]
		var definition: Dictionary = CARDS.get(card_id, {})
		var face := PanelContainer.new()
		face.name = "CardFace_%02d_%s" % [i, card_id]
		face.custom_minimum_size = Vector2(158, 210)
		face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_type := str(definition.get("type", "supply"))
		var type_color := Color("#477b72") if card_type == "scout" else Color("#a5643b") if card_type == "combat" else Color("#9a7a36")
		face.add_theme_stylebox_override("panel", _make_style(Color(0.94, 0.88, 0.73, 1.0), type_color, 8, 2))
		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 3)
		face.add_child(card_box)
		var art := TextureRect.new()
		art.name = "CardArt"
		art.custom_minimum_size = Vector2(0, 82)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.texture = load(_ink_art(str(definition.get("art", "res://assets/art/compass.jpg")))) as Texture2D
		card_box.add_child(art)
		var top := HBoxContainer.new()
		card_box.add_child(top)
		var name_label := _label(_db_card_name(card_id), 13, FRONTIER_INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		top.add_child(name_label)
		var cost_label := _label("COST %d" % int(definition.get("cost", 0)), 11, type_color.darkened(0.25))
		top.add_child(cost_label)
		var badge := _label("%s  ·  %s" % [card_type.to_upper(), _db_card_role(definition)], 9, type_color.darkened(0.35))
		badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_box.add_child(badge)
		var effect := _label(str(definition.get("text", "A frontier rule.")), 10, FRONTIER_INK)
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_box.add_child(effect)
		var play := Button.new()
		play.name = "PlayCard"
		play.text = "PLAY CARD"
		play.custom_minimum_size.y = 28
		play.add_theme_font_size_override("font_size", 10)
		play.add_theme_color_override("font_color", FRONTIER_CREAM)
		play.add_theme_stylebox_override("normal", _make_style(type_color, type_color.darkened(0.5), 5, 1))
		play.disabled = int(definition.get("cost", 0)) > deckbuilder_energy
		play.tooltip_text = "Spend %d energy: %s" % [int(definition.get("cost", 0)), str(definition.get("text", ""))]
		play.pressed.connect(_db_play_card.bind(i))
		card_box.add_child(play)
		deckbuilder_card_buttons.append(play)
		deckbuilder_hand_row.add_child(face)

func _refresh_deckbuilder_ui() -> void:
	if deckbuilder_overlay == null:
		return
	deckbuilder_overlay.visible = false
	if not deckbuilder_overlay.visible:
		return
	if encounter_active:
		deckbuilder_enemy_health = encounter_health
		deckbuilder_enemy_max_health = encounter_max_health
		deckbuilder_enemy_intent = str(ENCOUNTERS[encounter_index % ENCOUNTERS.size()].get("intent", "ENEMY INTENT"))
	elif deckbuilder_enemy_max_health <= 0:
		deckbuilder_enemy_max_health = int(ENCOUNTERS[encounter_index % ENCOUNTERS.size()].get("health", 12))
		deckbuilder_enemy_health = deckbuilder_enemy_max_health
		deckbuilder_enemy_intent = str(ENCOUNTERS[encounter_index % ENCOUNTERS.size()].get("intent", "ENEMY INTENT"))
	if deckbuilder_draw_count != null:
		deckbuilder_draw_count.text = str(draw_pile.size())
	if deckbuilder_discard_count != null:
		deckbuilder_discard_count.text = str(discard_pile.size())
	if deckbuilder_energy_label != null:
		deckbuilder_energy_label.text = "ENERGY %d / 3" % deckbuilder_energy
	if deckbuilder_turn_label != null:
		deckbuilder_turn_label.text = "TURN %d" % deckbuilder_turn
	if deckbuilder_enemy_label != null:
		deckbuilder_enemy_label.text = "%s  ·  HP %d / %d  ·  INTENT: %s" % [str(ENCOUNTERS[encounter_index % ENCOUNTERS.size()].get("name", "ROAD THREAT")), deckbuilder_enemy_health, deckbuilder_enemy_max_health, deckbuilder_enemy_intent]
	if deckbuilder_hand_row != null and deckbuilder_hand_row.get_child_count() != hand.size():
		_db_render_hand()
	for play_button in deckbuilder_card_buttons:
		if is_instance_valid(play_button):
			var card_face := play_button.get_parent().get_parent()
			var card_index := card_face.get_index()
			if card_index >= 0 and card_index < hand.size():
				play_button.disabled = int(CARDS.get(hand[card_index], {}).get("cost", 0)) > deckbuilder_energy

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and run_mode == "map" and not game_over and not victory:
		_save_game()
	elif what == NOTIFICATION_DRAG_END and drop_highlight != null:
		drop_highlight.visible = false

func _initialize_run() -> void:
	seed(run_seed)
	deck_ids.clear()
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhausted.clear()
	party = PARTY_DATA.fresh_state()
	graves.clear()
	travel_bonus = 0
	event_revealed = false
	event_hint_member = ""
	pending_leave_confirm = false
	pa_choice_active = false
	death_cause = ""
	letter_pending = false
	letters_written.clear()
	if letter_panel != null:
		letter_panel.visible = false
	money = 30
	keepsakes.clear()
	var starting: String = TRINKETS.STARTING_KEEPSAKE.get(character, "")
	if starting != "":
		keepsakes.append(starting)
	tonics.clear()
	powder_horn_spent = false
	shop_open = false
	if shop_panel != null:
		shop_panel.visible = false
	game_over = false
	victory = false
	day = 1
	completed_legs = 0
	route_index = 0
	supplies = 68
	morale = 82
	wagon_health = 100
	injuries = 0
	encounter_index = 0
	event_cursor = 0
	for card_id in CARD_DATA.deck_for(character):
		deck_ids.append(card_id)
		draw_pile.append(card_id)
	draw_pile.shuffle()
	event_order.clear()
	for i in EVENTS.size():
		event_order.append(i)
	event_order.shuffle()
	_start_leg()
	# Launch on the journey desk; the existing continue action enters the first dangerous leg.

func _start_leg() -> void:
	if game_over or victory:
		return
	grit = 3
	_reset_turn_context()
	pending_leave_confirm = false
	# Memories exhaust for the leg only — they always come back.
	for card_id in exhausted:
		draw_pile.append(card_id)
	if not exhausted.is_empty():
		exhausted.clear()
		draw_pile.shuffle()
	_draw_until_five()
	event_active = false
	encounter_active = false
	reward_pending = false
	if outcome_label != null:
		outcome_label.text = ""
	if run_mode == "map":
		_save_game()

func _db_card_name(card_id: String) -> String:
	var definition: Dictionary = CARDS.get(card_id, {})
	var card_name := str(definition.get("name", card_id))
	var family_id := str(definition.get("family", ""))
	if card_name.contains("{name}") and party.has(family_id):
		card_name = card_name.replace("{name}", str(party[family_id].get("name", family_id.capitalize())))
	return card_name

func _db_card_role(definition: Dictionary) -> String:
	return str(definition.get("role", "traveler")).replace("_", " ").to_upper()

func _db_stack(title: String, tint: Color, node_name: String) -> PanelContainer:
	var stack := PanelContainer.new()
	stack.name = node_name
	stack.custom_minimum_size = Vector2(112, 104)
	stack.add_theme_stylebox_override("panel", _make_style(Color(tint, 0.92), tint.darkened(0.45), 8, 2))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	stack.add_child(box)
	var title_label := _label(title, 10, FRONTIER_INK)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var count_label := _label("0", 27, tint.darkened(0.38))
	count_label.name = "Count"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(count_label)
	var caption := _label("CARDS", 9, FRONTIER_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	return stack

func _build_deckbuilder_overlay() -> void:
	# RETIRED (Brennan + Claude): this parallel deck UI duplicated the hand panel and
	# broke the letterpress palette. The real combat UI lives in the hand panel + BRACE.
	# Do not re-enable without a fresh brief from Brennan.
	return
	deckbuilder_overlay = Control.new()
	deckbuilder_overlay.name = "ActualEncounterDeck"
	deckbuilder_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deckbuilder_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deckbuilder_overlay)
	var panel := PanelContainer.new()
	panel.name = "EncounterDeckPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.anchor_left = 0.018
	panel.anchor_right = 0.982
	panel.anchor_top = 0.585
	panel.anchor_bottom = 0.985
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.10, 0.12, 0.11, 0.97), FRONTIER_BRASS, 10, 2))
	deckbuilder_overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var deck_box := VBoxContainer.new()
	deck_box.add_theme_constant_override("separation", 5)
	margin.add_child(deck_box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	deck_box.add_child(header)
	var heading := _label("ENCOUNTER DECK", 17, FRONTIER_CREAM)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	deckbuilder_turn_label = _label("TURN 1", 12, Color("#d8bd77"))
	header.add_child(deckbuilder_turn_label)
	deckbuilder_energy_label = _label("ENERGY 3 / 3", 15, Color("#f0d37e"))
	header.add_child(deckbuilder_energy_label)
	deckbuilder_brace_button = Button.new()
	deckbuilder_brace_button.name = "BRACE"
	deckbuilder_brace_button.text = "BRACE  ·  END TURN"
	deckbuilder_brace_button.custom_minimum_size = Vector2(172, 34)
	deckbuilder_brace_button.add_theme_font_size_override("font_size", 12)
	deckbuilder_brace_button.add_theme_color_override("font_color", FRONTIER_INK)
	deckbuilder_brace_button.add_theme_stylebox_override("normal", _make_style(Color("#d1b06a"), Color("#f2d997"), 7, 2))
	deckbuilder_brace_button.add_theme_stylebox_override("hover", _make_style(Color("#e0c37e"), Color("#fff0bd"), 7, 2))
	deckbuilder_brace_button.pressed.connect(_db_brace)
	header.add_child(deckbuilder_brace_button)
	deckbuilder_enemy_label = _label("ROAD ENCOUNTER  ·  enemy intent pending", 11, Color("#f2c3a6"))
	deckbuilder_enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deck_box.add_child(deckbuilder_enemy_label)
	deckbuilder_status_label = _label("Draw five travelers. Play cards, then BRACE to resolve the enemy intent.", 10, Color("#e2d4b9"))
	deckbuilder_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deck_box.add_child(deckbuilder_status_label)
	var play_row := HBoxContainer.new()
	play_row.name = "HandAndPiles"
	play_row.add_theme_constant_override("separation", 8)
	play_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_box.add_child(play_row)
	var draw_stack := _db_stack("DRAW PILE", Color("#c8b58e"), "DrawPileStack")
	play_row.add_child(draw_stack)
	deckbuilder_hand_row = HBoxContainer.new()
	deckbuilder_hand_row.name = "PhysicalHand"
	deckbuilder_hand_row.add_theme_constant_override("separation", 7)
	deckbuilder_hand_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deckbuilder_hand_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_row.add_child(deckbuilder_hand_row)
	var discard_stack := _db_stack("DISCARD", Color("#b88972"), "DiscardPileStack")
	play_row.add_child(discard_stack)
	deckbuilder_draw_count = draw_stack.get_node("VBoxContainer/Count") as Label
	deckbuilder_discard_count = discard_stack.get_node("VBoxContainer/Count") as Label

func _db_draw_one() -> void:
	if draw_pile.is_empty() and not discard_pile.is_empty():
		draw_pile.append_array(discard_pile)
		discard_pile.clear()
		draw_pile.shuffle()
	if not draw_pile.is_empty():
		hand.append(draw_pile.pop_back())

func _db_draw_hand() -> void:
	while hand.size() < 5 and (not draw_pile.is_empty() or not discard_pile.is_empty()):
		_db_draw_one()

func _db_apply_card_rule(card_id: String) -> void:
	var definition: Dictionary = CARDS.get(card_id, {})
	var fx: Dictionary = definition.get("fx", {})
	supplies = maxi(0, supplies + int(fx.get("supplies", 0)))
	morale = clampi(morale + int(fx.get("morale", 0)), 0, 100)
	if fx.has("morale_resolve"):
		morale = clampi(morale + int(fx["morale_resolve"]) + (int(fx.get("resolve_low_bonus", 0)) if morale < 30 else 0), 0, 100)
	wagon_health = clampi(wagon_health + int(fx.get("wagon", 0)), 0, 100)
	day = maxi(1, day + int(fx.get("days", 0)))
	travel_bonus += int(fx.get("travel_bonus", 0))
	if fx.has("reveal"):
		event_revealed = true
	if fx.has("block"):
		deckbuilder_block += int(fx["block"])
	if fx.has("threat"):
		encounter_threat = maxi(0, encounter_threat + int(fx["threat"]))
	var damage := int(fx.get("enemy_damage", 0))
	if damage > 0:
		if encounter_active:
			encounter_health = maxi(0, encounter_health - damage)
		deckbuilder_enemy_health = maxi(0, deckbuilder_enemy_health - damage)
	if fx.has("draw"):
		for _i in range(int(fx["draw"])):
			_db_draw_one()

func _db_play_card(index: int) -> void:
	if index < 0 or index >= hand.size():
		return
	var card_id := hand[index]
	var definition: Dictionary = CARDS.get(card_id, {})
	var cost := int(definition.get("cost", 0))
	if cost > deckbuilder_energy:
		deckbuilder_status_label.text = "Not enough energy. BRACE restores 3 energy on the next turn."
		return
	deckbuilder_energy -= cost
	hand.remove_at(index)
	if bool(definition.get("exhaust", false)):
		exhausted.append(card_id)
	else:
		discard_pile.append(card_id)
	_db_apply_card_rule(card_id)
	deckbuilder_status_label.text = "%s played. Rule resolved; card moved to DISCARD." % _db_card_name(card_id)
	_refresh_deckbuilder_ui()
	_refresh_ui()

func _db_brace() -> void:
	if run_mode != "map" or game_over or victory:
		return
	var intent: Dictionary = ENCOUNTERS[encounter_index % ENCOUNTERS.size()]
	var damage := int(intent.get("damage", 0)) + encounter_threat
	var blocked := mini(deckbuilder_block, damage)
	damage -= blocked
	deckbuilder_block = maxi(0, deckbuilder_block - blocked)
	var hits := str(intent.get("hits", "wagon"))
	if hits == "wagon":
		wagon_health = maxi(0, wagon_health - damage)
	elif hits == "supplies":
		supplies = maxi(0, supplies - damage)
	else:
		morale = maxi(0, morale - damage)
	encounter_threat = 0
	for card_id in hand:
		discard_pile.append(card_id)
	hand.clear()
	deckbuilder_turn += 1
	deckbuilder_energy = 3
	_db_draw_hand()
	deckbuilder_status_label.text = "BRACE resolved %s for %d damage. New hand drawn." % [str(intent.get("intent", "enemy intent")), damage]
	_refresh_deckbuilder_ui()
	_refresh_ui()

# ---- Theme tokens: dark modern chrome around a lit parchment table. ----
# The engravings are multiply-printed and need light paper beneath them, so
# the play surface stays parchment while every panel, card frame, and strip
# of chrome goes deep charcoal with warm light type. Flip UI_DARK to false
# to print the whole game back onto the letterpress broadsheet.
const UI_DARK := true
const DARK_BASE := Color("#121214")
const DARK_SURFACE := Color("#1a1a1e")
const DARK_RAISED := Color("#222229")
const DARK_TEXT := Color("#eae6dc")
const DARK_MUTED := Color("#a49d90")
const DARK_LINE := Color("#41414b")
const PARCHMENT := Color("#e9dfc6")

const FRONTIER_CREAM := Color("#f4ead2")
const FRONTIER_INK := Color("#2a1d14")
const FRONTIER_PINE := Color("#1f4a41")
const FRONTIER_TEAL := Color("#4f8178")
const FRONTIER_RUST := Color("#a84d37")
const FRONTIER_BRASS := Color("#b18a45")
const FRONTIER_MUTED := Color("#6d5945")

func _has_keepsake(keepsake_id: String) -> bool:
	return keepsakes.has(keepsake_id)

func _gain_keepsake(keepsake_id: String) -> void:
	if keepsakes.has(keepsake_id) or not TRINKETS.KEEPSAKES.has(keepsake_id):
		return
	keepsakes.append(keepsake_id)
	if card_status != null:
		card_status.text = "KEEPSAKE FOUND  ·  %s — %s" % [str(TRINKETS.KEEPSAKES[keepsake_id]["name"]).to_upper(), TRINKETS.KEEPSAKES[keepsake_id]["text"]]
	_refresh_trinket_strip()

func _gain_tonic(tonic_id: String) -> bool:
	if tonics.size() >= 3 or not TRINKETS.TONICS.has(tonic_id):
		return false
	tonics.append(tonic_id)
	_refresh_trinket_strip()
	return true

func _drink_tonic(slot: int) -> void:
	if slot < 0 or slot >= tonics.size() or game_over or victory or run_mode != "map" or shop_open or letter_pending or pa_choice_active:
		return
	var tonic_id: String = tonics[slot]
	match tonic_id:
		"coffee":
			grit = mini(grit + 1, 5)
			_float_number("+1 GRIT", Color("#1f5c33"), grit_value)
		"bitters":
			morale = clamp(morale + 8, 0, 100)
			_float_number("+8", Color("#1f5c33"), morale_value)
		"laudanum_draught":
			if not encounter_active:
				card_status.text = "Laudanum is for the bad moments. Save it for a fight."
				return
			encounter_block += 8
			_float_number("+8 BLOCK", Color("#1f5c33"), encounter_intent_label)
		"snakebite_kit":
			_apply_cure()
		"gunpowder_sachet":
			if not encounter_active:
				card_status.text = "No sense wasting powder on an empty road."
				return
			_damage_encounter(10)
			_float_number("-10", Color("#a02818"), encounter_health_label)
			if encounter_health <= 0:
				_resolve_encounter()
		"hardtack":
			supplies += 10
			_float_number("+10", Color("#1f5c33"), supply_value)
	tonics.remove_at(slot)
	if card_status != null and tonic_id != "laudanum_draught" and tonic_id != "gunpowder_sachet":
		card_status.text = "%s — down the hatch." % TRINKETS.TONICS[tonic_id]["name"]
	_refresh_trinket_strip()
	_sync_and_refresh()

# A number that jumps off the page where the change happened. Playbill, of course.
func _float_number(text_value: String, color: Color, near: Control) -> void:
	if near == null or not is_instance_valid(near):
		return
	var pop := Label.new()
	pop.text = text_value
	pop.z_index = 60
	if font_display != null:
		pop.add_theme_font_override("font", font_display)
	pop.add_theme_font_size_override("font_size", 24)
	pop.add_theme_color_override("font_color", color)
	add_child(pop)
	pop.global_position = near.global_position + Vector2(near.size.x * 0.5 - 16.0, -6.0)
	var drift := create_tween()
	drift.set_parallel(true)
	drift.tween_property(pop, "global_position:y", pop.global_position.y - 34.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drift.tween_property(pop, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drift.chain().tween_callback(pop.queue_free)

func _float_combo(text_value: String) -> void:
	# Combo payoffs get the big gold stamp — over the enemy in a fight,
	# over the hand's status line on the trail.
	var near: Control = enemy_actor if encounter_active and enemy_actor != null else card_status
	if near == null or not is_instance_valid(near):
		return
	var pop := Label.new()
	pop.text = text_value
	pop.z_index = 60
	if font_display != null:
		pop.add_theme_font_override("font", font_display)
	pop.add_theme_font_size_override("font_size", 34)
	pop.add_theme_color_override("font_color", Color("#b8860b"))
	pop.add_theme_color_override("font_outline_color", Color("#30251b"))
	pop.add_theme_constant_override("outline_size", 3)
	add_child(pop)
	pop.global_position = near.global_position + Vector2(near.size.x * 0.5 - 60.0, near.size.y * 0.25)
	pop.scale = Vector2(0.6, 0.6)
	var drift := create_tween()
	drift.set_parallel(true)
	drift.tween_property(pop, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drift.tween_property(pop, "global_position:y", pop.global_position.y - 46.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drift.tween_property(pop, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drift.chain().tween_callback(pop.queue_free)

func _print_onto_paper(engraving: TextureRect) -> void:
	# Engravings ship with white backgrounds. Multiply blending turns white into
	# the paper underneath, so the ink reads as printed on the page, not pasted on it.
	var print_material := CanvasItemMaterial.new()
	print_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	engraving.material = print_material

# The theme boundary: every legacy letterpress color passes through these
# three mappers, so the dark theme is total without rewriting 200 literals.
# Neutral paper tones become charcoal surfaces, neutral inks become warm
# light type, and every true accent (stamp red, brass, pine) rides through.
func _themed_surface(c: Color) -> Color:
	if not UI_DARK:
		return c
	if c.s < 0.35 and c.v > 0.66:
		var out := DARK_RAISED if c.v > 0.9 else DARK_SURFACE
		return Color(out.r, out.g, out.b, c.a)
	return c

func _themed_line(c: Color) -> Color:
	if not UI_DARK:
		return c
	if (c.s < 0.5 and c.v < 0.4) or (c.s < 0.35 and c.v > 0.66):
		return Color(DARK_LINE.r, DARK_LINE.g, DARK_LINE.b, c.a)
	return c

func _themed_text(c: Color) -> Color:
	if not UI_DARK:
		return c
	if c.s < 0.55 and c.v < 0.34:
		return Color(DARK_TEXT.r, DARK_TEXT.g, DARK_TEXT.b, c.a)
	if c.s < 0.6 and c.v < 0.55:
		return Color(DARK_MUTED.r, DARK_MUTED.g, DARK_MUTED.b, c.a)
	return c

func _make_style(bg: Color, border: Color, radius: int = 12, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _themed_surface(bg)
	style.border_color = Color(_themed_line(border), 0.72)
	style.set_border_width_all(1 if width <= 1 else 2)
	# Hand-trimmed paper and letterpress blocks have square corners; only
	# true cards (radius <= 4, like poker stock) keep a gentle round.
	style.set_corner_radius_all(radius if radius <= 4 else (0 if UI_DARK else mini(radius, 8)))
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	# Depth: panels float over the table instead of sitting flush on it.
	style.shadow_color = Color(0, 0, 0, 0.45) if UI_DARK else Color(FRONTIER_INK, 0.24)
	style.shadow_size = 10 if UI_DARK else 6
	style.shadow_offset = Vector2(0, 3)
	return style

func _parchment_style(radius: int = 8) -> StyleBoxFlat:
	# The one surface the dark theme never touches: paper for the engravings.
	var style := StyleBoxFlat.new()
	style.bg_color = PARCHMENT
	style.border_color = Color("#30251b", 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 4)
	return style

func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	if size >= 16 and font_display != null:
		label.add_theme_font_override("font", font_display)
		label.add_theme_font_size_override("font_size", int(size * 1.15))
	else:
		label.add_theme_font_size_override("font_size", size if size <= 1 else maxi(size, 12))
	label.add_theme_color_override("font_color", _themed_text(color))
	label.add_theme_constant_override("line_spacing", 2)
	return label

func _build_ui() -> void:
	_build_map_first_ui()
	_build_camp_overlay()
	return

func _add_stage_shadow(actor: Control) -> void:
	# A soft dark pool under a stage actor's feet — the same grounding trick
	# as the map pieces, sized to the actor.
	var shadow := TextureRect.new()
	var shadow_grad := Gradient.new()
	shadow_grad.set_color(0, Color(0.1, 0.07, 0.04, 0.30))
	shadow_grad.set_color(1, Color(0.1, 0.07, 0.04, 0.0))
	var shadow_tex := GradientTexture2D.new()
	shadow_tex.gradient = shadow_grad
	shadow_tex.fill = GradientTexture2D.FILL_RADIAL
	shadow_tex.fill_from = Vector2(0.5, 0.5)
	shadow_tex.fill_to = Vector2(1.0, 0.5)
	shadow.texture = shadow_tex
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.anchor_left = 0.08
	shadow.anchor_right = 0.92
	shadow.anchor_top = 0.88
	shadow.anchor_bottom = 1.02
	shadow.offset_left = 0.0
	shadow.offset_right = 0.0
	shadow.offset_top = 0.0
	shadow.offset_bottom = 0.0
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.add_child(shadow)

func _place_hero_piece(hero: Control, piece: Control, left: float, right: float, top: float, bottom: float) -> void:
	piece.set_anchors_preset(Control.PRESET_FULL_RECT)
	piece.anchor_left = left
	piece.anchor_right = right
	piece.anchor_top = top
	piece.anchor_bottom = bottom
	piece.offset_left = 0.0
	piece.offset_right = 0.0
	piece.offset_top = 0.0
	piece.offset_bottom = 0.0
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(piece)

func _add_hero_sprite(hero: Control, sprite_name: String, left: float, right: float, top: float, bottom: float, flip: bool, tint: Color = Color.WHITE) -> void:
	var sprite_path := "res://assets/sprites/family/%s.png" % sprite_name
	if not ResourceLoader.exists(sprite_path):
		return
	var piece := TextureRect.new()
	piece.texture = load(sprite_path) as Texture2D
	piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	piece.flip_h = flip
	piece.modulate = tint
	_place_hero_piece(hero, piece, left, right, top, bottom)

func _open_manifest() -> void:
	if camp_title_layer != null:
		camp_title_layer.visible = false
	if camp_manifest_layer != null:
		camp_manifest_layer.visible = true

func _back_to_title() -> void:
	if camp_manifest_layer != null:
		camp_manifest_layer.visible = false
	if camp_history_modal != null:
		camp_history_modal.visible = false
	if camp_title_layer != null:
		camp_title_layer.visible = true

func _open_history_modal() -> void:
	if camp_history_modal == null:
		return
	if camp_history_modal_label != null and history_label != null:
		camp_history_modal_label.text = history_label.text
	camp_history_modal.visible = true

func _build_camp_overlay() -> void:
	camp_overlay = Control.new()
	camp_overlay.name = "ExpeditionCampHub"
	camp_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camp_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(camp_overlay)
	var camp_paper := ColorRect.new()
	camp_paper.name = "CampPaper"
	camp_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camp_paper.color = DARK_BASE if UI_DARK else Color(0.91, 0.87, 0.76, 1.0)
	camp_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_overlay.add_child(camp_paper)
	var camp_art := TextureRect.new()
	camp_art.name = "CampfireBackdrop"
	camp_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camp_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camp_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	camp_art.texture = load(_ink_art("res://assets/art/campfire.jpg")) as Texture2D
	# Bright enough to READ as a forest, warm-shifted toward firelight;
	# the vignette below pushes the edges back into night.
	camp_art.modulate = Color(0.46, 0.40, 0.33, 1.0) if UI_DARK else Color(0.98, 0.90, 0.74, 1.0)
	camp_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_overlay.add_child(camp_art)
	if UI_DARK:
		# Night presses in from the edges; the middle stays fire-lit.
		var vignette := TextureRect.new()
		vignette.name = "CampVignette"
		vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vignette_grad := Gradient.new()
		# add_point re-sorts stops and shifts indices — assign whole arrays.
		vignette_grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
		vignette_grad.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.18), Color(0.02, 0.02, 0.03, 0.9)])
		var vignette_tex := GradientTexture2D.new()
		vignette_tex.gradient = vignette_grad
		vignette_tex.fill = GradientTexture2D.FILL_RADIAL
		vignette_tex.fill_from = Vector2(0.5, 0.55)
		vignette_tex.fill_to = Vector2(1.02, 0.55)
		vignette.texture = vignette_tex
		vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		camp_overlay.add_child(vignette)
	var camp_wash := ColorRect.new()
	camp_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camp_wash.color = Color(0.07, 0.07, 0.08, 0.55) if UI_DARK else Color(0.93, 0.89, 0.78, 0.58)
	camp_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_overlay.add_child(camp_wash)
	# ---- STEP 1: the front door. Not a settings form — a family resting at
	# their fire before the dark country, and three choices. The paperwork
	# lives behind NEW JOURNEY. ----
	camp_title_layer = Control.new()
	camp_title_layer.name = "TitleLayer"
	camp_title_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camp_overlay.add_child(camp_title_layer)
	var masthead_box := VBoxContainer.new()
	masthead_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	masthead_box.anchor_top = 0.06
	masthead_box.anchor_bottom = 0.06
	masthead_box.offset_top = 0.0
	masthead_box.offset_bottom = 0.0
	camp_title_layer.add_child(masthead_box)
	var masthead := _label("THE LONG TRAIL", 58, Color("#a02818"))
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	masthead_box.add_child(masthead)
	var mast_sub := _label("—  AN OREGON TRAIL DECKBUILDER  ·  1848  —", 12, Color("#b18a45"))
	mast_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	masthead_box.add_child(mast_sub)
	# The hero: pixel family gathered at a fire in front of the dark engraving.
	var hero := Control.new()
	hero.name = "CampfireHero"
	hero.set_anchors_preset(Control.PRESET_FULL_RECT)
	hero.anchor_left = 0.16
	hero.anchor_right = 0.84
	hero.anchor_top = 0.22
	hero.anchor_bottom = 0.72
	hero.offset_left = 0.0
	hero.offset_right = 0.0
	hero.offset_top = 0.0
	hero.offset_bottom = 0.0
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_title_layer.add_child(hero)
	# Firelit ground: a warm pool the whole gathering stands in.
	var ground_pool := TextureRect.new()
	var pool_grad := Gradient.new()
	pool_grad.set_color(0, Color(0.88, 0.56, 0.28, 0.22))
	pool_grad.set_color(1, Color(0.88, 0.5, 0.2, 0.0))
	var pool_tex := GradientTexture2D.new()
	pool_tex.gradient = pool_grad
	pool_tex.fill = GradientTexture2D.FILL_RADIAL
	pool_tex.fill_from = Vector2(0.5, 0.5)
	pool_tex.fill_to = Vector2(1.0, 0.5)
	ground_pool.texture = pool_tex
	ground_pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_place_hero_piece(hero, ground_pool, 0.24, 0.88, 0.80, 1.10)
	# The fire's light, big and honest — this scene has one light source.
	var fire_glow := TextureRect.new()
	var glow_grad := Gradient.new()
	glow_grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	glow_grad.colors = PackedColorArray([Color(1.0, 0.74, 0.38, 0.50), Color(1.0, 0.62, 0.26, 0.18), Color(1.0, 0.6, 0.2, 0.0)])
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = glow_grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.6)
	glow_tex.fill_to = Vector2(1.0, 0.6)
	fire_glow.texture = glow_tex
	fire_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_place_hero_piece(hero, fire_glow, 0.22, 0.84, 0.06, 1.08)
	var flicker := create_tween().set_loops()
	flicker.tween_property(fire_glow, "modulate:a", 0.68, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flicker.tween_property(fire_glow, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The gathering: wagon dim in the dark behind; the family close around
	# the flames, warmed by them, overlapping like people actually sit.
	var firelight := Color(1.09, 0.97, 0.85)
	_add_hero_sprite(hero, "wagon", 0.01, 0.30, 0.24, 0.96, false, Color(0.60, 0.56, 0.53))
	_add_hero_sprite(hero, "dog", 0.40, 0.485, 0.70, 0.97, true, firelight)
	_add_hero_sprite(hero, "campfire", 0.475, 0.585, 0.54, 1.0, false)
	_add_hero_sprite(hero, "pa", 0.585, 0.675, 0.28, 0.97, false, firelight)
	_add_hero_sprite(hero, "ma", 0.655, 0.745, 0.34, 0.97, false, firelight)
	_add_hero_sprite(hero, "sarah", 0.725, 0.805, 0.42, 0.97, false, firelight)
	# Three unboxed choices, bottom right.
	# The menu sits centered beneath the scene, like a playbill's billing block.
	var title_menu := VBoxContainer.new()
	title_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_menu.anchor_left = 0.38
	title_menu.anchor_right = 0.62
	title_menu.anchor_top = 0.78
	title_menu.anchor_bottom = 0.78
	title_menu.offset_left = 0.0
	title_menu.offset_right = 0.0
	title_menu.add_theme_constant_override("separation", 8)
	camp_title_layer.add_child(title_menu)
	title_continue_button = Button.new()
	title_continue_button.name = "TitleContinue"
	title_continue_button.text = "CONTINUE JOURNEY  →"
	title_continue_button.visible = false
	title_continue_button.add_theme_font_override("font", font_display)
	title_continue_button.add_theme_font_size_override("font_size", 22)
	title_continue_button.add_theme_stylebox_override("normal", _make_style(Color("#d5b66d"), Color("#efd28e"), 9, 1))
	title_continue_button.add_theme_color_override("font_color", Color("#1b211e"))
	title_continue_button.pressed.connect(_on_continue_run_pressed)
	title_menu.add_child(title_continue_button)
	var new_journey := Button.new()
	new_journey.name = "NewJourney"
	new_journey.text = "NEW JOURNEY  →"
	new_journey.add_theme_font_override("font", font_display)
	new_journey.add_theme_font_size_override("font_size", 22)
	new_journey.add_theme_stylebox_override("normal", _make_style(Color("#a02818"), Color("#6b1a10"), 9, 2))
	new_journey.add_theme_color_override("font_color", Color("#f6efdc"))
	new_journey.pressed.connect(_open_manifest)
	title_menu.add_child(new_journey)
	var past_journeys := Button.new()
	past_journeys.name = "PastJourneys"
	past_journeys.text = "PAST JOURNEYS"
	past_journeys.flat = true
	past_journeys.add_theme_font_override("font", font_display)
	past_journeys.add_theme_font_size_override("font_size", 16)
	past_journeys.add_theme_color_override("font_color", _themed_text(Color("#4b3d2a")))
	past_journeys.pressed.connect(_open_history_modal)
	title_menu.add_child(past_journeys)
	# ---- STEP 2: the Wagon Manifest — shown only after NEW JOURNEY. ----
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.visible = false
	camp_overlay.add_child(margin)
	camp_manifest_layer = margin
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var manifest_header := HBoxContainer.new()
	page.add_child(manifest_header)
	var back_button := Button.new()
	back_button.text = "←"
	back_button.flat = true
	back_button.add_theme_font_size_override("font_size", 22)
	back_button.add_theme_color_override("font_color", _themed_text(Color("#4b3d2a")))
	back_button.tooltip_text = "Back to the fire."
	back_button.pressed.connect(_back_to_title)
	manifest_header.add_child(back_button)
	var heading := _label("THE WAGON MANIFEST", 30, Color("#a02818"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manifest_header.add_child(heading)
	var header_spacer := Control.new()
	header_spacer.custom_minimum_size.x = 34.0
	manifest_header.add_child(header_spacer)
	var subheading := _label("WHO RIDES, AND WHAT THE WAGON CARRIES", 11, Color("#6b5b41"))
	subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(subheading)
	var title_spacer := Control.new()
	title_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(title_spacer)

	var char_row := HBoxContainer.new()
	char_row.name = "CharacterChoice"
	char_row.add_theme_constant_override("separation", 10)
	page.add_child(char_row)
	for char_id in CARD_DATA.CHARACTERS.keys():
		var char_def: Dictionary = CARD_DATA.CHARACTERS[char_id]
		var char_button := Button.new()
		char_button.name = "Character_%s" % char_id
		char_button.text = "%s
%s" % [char_def["name"], str(char_def["blurb"])]
		char_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		char_button.custom_minimum_size.y = 56.0
		char_button.add_theme_font_override("font", font_display)
		char_button.add_theme_font_size_override("font_size", 15)
		char_button.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
		char_button.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
		char_button.pressed.connect(_select_character.bind(char_id))
		char_row.add_child(char_button)
		character_buttons[char_id] = char_button
	_refresh_character_buttons()

	var family_panel := PanelContainer.new()
	family_panel.name = "FamilyNaming"
	family_panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.885, 0.78, 0.95), Color("#30251b"), 6, 2))
	page.add_child(family_panel)
	var family_box := VBoxContainer.new()
	family_box.add_theme_constant_override("separation", 6)
	family_panel.add_child(family_box)
	var family_header := HBoxContainer.new()
	family_box.add_child(family_header)
	var family_title := _label("THE FAMILY", 18, Color("#a02818"))
	family_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	family_header.add_child(family_title)
	var suggest := Button.new()
	suggest.name = "SuggestNames"
	suggest.text = "✦  ROLL THE NAMES"
	suggest.add_theme_font_size_override("font_size", 12)
	suggest.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 8, 1))
	suggest.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	suggest.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	suggest.pressed.connect(_on_suggest_names)
	family_header.add_child(suggest)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	family_box.add_child(name_row)
	for member_id in PARTY_DATA.MEMBER_ORDER:
		var member: Dictionary = PARTY_DATA.MEMBERS[member_id]
		# Each member is a luggage tag: colored band on top, role, name line —
		# five little cards side by side, not a form grid.
		var tag_card := PanelContainer.new()
		tag_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag_card.add_theme_stylebox_override("panel", _make_style(Color("#ede4c8"), Color(member["chip_color"]), 10, 2))
		name_row.add_child(tag_card)
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 5)
		tag_card.add_child(slot)
		var band := ColorRect.new()
		band.color = Color(member["chip_color"])
		band.custom_minimum_size = Vector2(0, 4)
		slot.add_child(band)
		# The face on the tag — you're naming a person, not filling a field.
		var tag_portrait := TextureRect.new()
		tag_portrait.custom_minimum_size = Vector2(0, 92)
		tag_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tag_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tag_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tag_portrait_path := "res://assets/sprites/family/%s.png" % member_id
		if ResourceLoader.exists(tag_portrait_path):
			tag_portrait.texture = load(tag_portrait_path) as Texture2D
		slot.add_child(tag_portrait)
		var role_tag := _label(str(member["role"]), 10, Color(member["chip_color"]))
		role_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(role_tag)
		var edit := LineEdit.new()
		edit.name = "Name_%s" % member_id
		edit.text = member["default_name"]
		edit.max_length = 14
		edit.add_theme_font_size_override("font_size", 12)
		edit.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
		edit.add_theme_color_override("font_placeholder_color", Color("#9a8a6a"))
		edit.add_theme_color_override("caret_color", Color("#a02818"))
		edit.add_theme_stylebox_override("normal", _make_style(Color("#f6efdc"), Color("#8c6a40"), 4, 1))
		edit.add_theme_stylebox_override("focus", _make_style(Color("#fffaf0"), Color("#a02818"), 4, 2))
		edit.tooltip_text = "This name follows them onto their card, their words, and — if it comes to it — their grave."
		slot.add_child(edit)
		name_edits[member_id] = edit

	# Seeds, perks, difficulty, the record book: tucked behind one drawer so
	# the manifest stays a manifest, not a tax form.
	var advanced_toggle := Button.new()
	advanced_toggle.name = "AdvancedSupplies"
	advanced_toggle.text = "ADVANCED SUPPLIES  ▸"
	advanced_toggle.flat = true
	advanced_toggle.add_theme_font_override("font", font_display)
	advanced_toggle.add_theme_font_size_override("font_size", 14)
	advanced_toggle.add_theme_color_override("font_color", _themed_text(Color("#4b3d2a")))
	page.add_child(advanced_toggle)
	var extras_row := HBoxContainer.new()
	extras_row.add_theme_constant_override("separation", 10)
	extras_row.visible = false
	page.add_child(extras_row)
	camp_advanced_row = extras_row
	advanced_toggle.pressed.connect(func() -> void:
		camp_advanced_row.visible = not camp_advanced_row.visible
		advanced_toggle.text = "ADVANCED SUPPLIES  ▾" if camp_advanced_row.visible else "ADVANCED SUPPLIES  ▸")
	var outfit_panel := PanelContainer.new()
	outfit_panel.name = "WagonOutfitting"
	outfit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outfit_panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.885, 0.78, 0.95), Color("#2e6b45"), 6, 2))
	extras_row.add_child(outfit_panel)
	var outfit_box := VBoxContainer.new()
	outfit_box.add_theme_constant_override("separation", 2)
	outfit_panel.add_child(outfit_box)
	outfit_box.add_child(_label("OUTFITTING", 18, Color("#a02818")))
	for entry in [
		["well_stocked", "WELL-STOCKED WAGON — start with +20 supplies"],
		["steady_oxen", "STEADY OXEN — supplies drain 1 less per travel day"],
		["green_country", "GREEN COUNTRY — threats have 20% less health"]
	]:
		var check := CheckBox.new()
		check.name = "Outfit_%s" % entry[0]
		check.text = entry[1]
		check.add_theme_font_size_override("font_size", 12)
		check.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
		check.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
		check.add_theme_color_override("font_pressed_color", Color("#221c14"))
		outfit_box.add_child(check)
		modifier_checks[entry[0]] = check
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 6)
	outfit_box.add_child(seed_row)
	seed_row.add_child(_label("TRAIL SEED", 9, Color("#221c14")))
	seed_edit = LineEdit.new()
	seed_edit.name = "TrailSeed"
	seed_edit.placeholder_text = "leave blank for a fresh trail"
	seed_edit.custom_minimum_size.x = 170.0
	seed_edit.add_theme_font_size_override("font_size", 12)
	seed_edit.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	seed_edit.add_theme_color_override("font_placeholder_color", Color("#9a8a6a"))
	seed_edit.add_theme_stylebox_override("normal", _make_style(Color("#f6efdc"), Color("#8c6a40"), 4, 1))
	seed_edit.add_theme_stylebox_override("focus", _make_style(Color("#fffaf0"), Color("#a02818"), 4, 2))
	seed_edit.tooltip_text = "Every run rolls its own seed. Type one (from a death screen, or a friend) to walk the same trail."
	seed_row.add_child(seed_edit)
	tb_row = HBoxContainer.new()
	tb_row.name = "TrailblazerRow"
	tb_row.add_theme_constant_override("separation", 6)
	tb_row.visible = false
	outfit_box.add_child(tb_row)
	var tb_minus := Button.new()
	tb_minus.name = "TrailblazerDown"
	tb_minus.text = "−"
	tb_minus.add_theme_font_size_override("font_size", 12)
	tb_minus.pressed.connect(_change_trailblazer.bind(-1))
	tb_row.add_child(tb_minus)
	tb_label = _label("TRAILBLAZER 0 · PIONEER", 10, Color("#a02818"))
	tb_row.add_child(tb_label)
	var tb_plus := Button.new()
	tb_plus.name = "TrailblazerUp"
	tb_plus.text = "+"
	tb_plus.add_theme_font_size_override("font_size", 12)
	tb_plus.pressed.connect(_change_trailblazer.bind(1))
	tb_row.add_child(tb_plus)
	tb_rules_label = _label("", 9, Color("#6b5b41"))
	tb_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outfit_box.add_child(tb_rules_label)
	var history_panel := PanelContainer.new()
	history_panel.name = "TrailJournal"
	history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.885, 0.78, 0.95), Color("#3f617a"), 12, 2))
	extras_row.add_child(history_panel)
	var history_box := VBoxContainer.new()
	history_box.add_theme_constant_override("separation", 2)
	history_panel.add_child(history_box)
	history_box.add_child(_label("PAST JOURNEYS", 10, Color("#3f617a")))
	history_label = _label("No journeys in the book yet.", 10, Color("#4b3d2a"))
	history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_box.add_child(history_label)
	var compendium_button := Button.new()
	compendium_button.name = "CompendiumButton"
	compendium_button.text = "COMPENDIUM"
	compendium_button.add_theme_font_size_override("font_size", 12)
	compendium_button.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 8, 1))
	compendium_button.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	compendium_button.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	compendium_button.tooltip_text = "Every card on the trail — the ones you've earned, and the silhouettes still waiting."
	compendium_button.pressed.connect(_open_pile_view.bind("compendium"))
	history_box.add_child(compendium_button)
	_refresh_history_panel()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	page.add_child(footer)
	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)
	camp_continue_button = Button.new()
	camp_continue_button.name = "ContinueJourney"
	camp_continue_button.text = "CONTINUE JOURNEY"
	camp_continue_button.custom_minimum_size = Vector2(220, 54)
	camp_continue_button.visible = false
	camp_continue_button.add_theme_font_size_override("font_size", 15)
	camp_continue_button.add_theme_font_override("font", font_display)
	camp_continue_button.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	camp_continue_button.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	camp_continue_button.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 6, 2))
	camp_continue_button.add_theme_stylebox_override("hover", _make_style(Color("#f1e5c5"), Color("#a02818"), 6, 2))
	camp_continue_button.tooltip_text = "Pick the saved run back up right where the wagon stopped."
	camp_continue_button.pressed.connect(_on_continue_run_pressed)
	footer.add_child(camp_continue_button)
	camp_start_button = Button.new()
	camp_start_button.name = "StartExpedition"
	camp_start_button.text = "START EXPEDITION  →"
	camp_start_button.custom_minimum_size = Vector2(250, 54)
	camp_start_button.add_theme_font_size_override("font_size", 16)
	camp_start_button.add_theme_font_override("font", font_display)
	camp_start_button.add_theme_color_override("font_color", Color("#f2e4c4"))
	camp_start_button.add_theme_color_override("font_hover_color", Color("#fff4dc"))
	camp_start_button.add_theme_stylebox_override("normal", _make_style(Color("#a02818"), Color("#6b1a10"), 6, 2))
	camp_start_button.add_theme_stylebox_override("hover", _make_style(Color("#bb3524"), Color("#8c2a1d"), 6, 2))
	camp_start_button.tooltip_text = "Begins a fresh run. Any saved journey is retired."
	camp_start_button.pressed.connect(_on_start_expedition_pressed)
	footer.add_child(camp_start_button)
	# The record book: a modal over the title screen, opened from PAST JOURNEYS.
	camp_history_modal = PanelContainer.new()
	camp_history_modal.name = "PastJourneysModal"
	camp_history_modal.set_anchors_preset(Control.PRESET_CENTER)
	camp_history_modal.anchor_left = 0.28
	camp_history_modal.anchor_right = 0.72
	camp_history_modal.anchor_top = 0.24
	camp_history_modal.anchor_bottom = 0.24
	camp_history_modal.offset_left = 0.0
	camp_history_modal.offset_right = 0.0
	camp_history_modal.visible = false
	camp_history_modal.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.885, 0.78, 0.98), Color("#8c6a40"), 8, 2))
	camp_overlay.add_child(camp_history_modal)
	var modal_box := VBoxContainer.new()
	modal_box.add_theme_constant_override("separation", 8)
	camp_history_modal.add_child(modal_box)
	modal_box.add_child(_label("PAST JOURNEYS", 22, Color("#a02818")))
	camp_history_modal_label = _label("No journeys in the book yet.", 11, Color("#4b3d2a"))
	camp_history_modal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal_box.add_child(camp_history_modal_label)
	var modal_buttons := HBoxContainer.new()
	modal_buttons.add_theme_constant_override("separation", 8)
	modal_box.add_child(modal_buttons)
	var modal_compendium := Button.new()
	modal_compendium.text = "COMPENDIUM"
	modal_compendium.add_theme_font_size_override("font_size", 12)
	modal_compendium.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 8, 1))
	modal_compendium.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	modal_compendium.pressed.connect(_open_pile_view.bind("compendium"))
	modal_buttons.add_child(modal_compendium)
	var modal_close := Button.new()
	modal_close.text = "CLOSE"
	modal_close.add_theme_font_size_override("font_size", 12)
	modal_close.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 8, 1))
	modal_close.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	modal_close.pressed.connect(func() -> void: camp_history_modal.visible = false)
	modal_buttons.add_child(modal_close)

func _change_trailblazer(delta: int) -> void:
	var max_level: int = mini(int(profile.get("cleared", -1)) + 1, TRAILBLAZER_RULES.size())
	trailblazer = clampi(trailblazer + delta, 0, maxi(0, max_level))
	_refresh_trailblazer_ui()

func _refresh_trailblazer_ui() -> void:
	if tb_row == null:
		return
	tb_row.visible = int(profile.get("wins", 0)) > 0
	if trailblazer <= 0:
		tb_label.text = "TRAILBLAZER 0 · PIONEER"
		tb_rules_label.text = ""
	else:
		tb_label.text = "TRAILBLAZER %d" % trailblazer
		var active: Array[String] = []
		for i in range(trailblazer):
			active.append(TRAILBLAZER_RULES[i])
		tb_rules_label.text = " · ".join(active)

func _load_profile() -> void:
	profile = {"runs_finished": 0, "wins": 0, "cleared": -1}
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		profile["runs_finished"] = int(parsed.get("runs_finished", 0))
		profile["wins"] = int(parsed.get("wins", 0))
		profile["cleared"] = int(parsed.get("cleared", -1))

func _save_profile() -> void:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(profile))
		file.close()

func _card_unlocked(card_id: String) -> bool:
	if not LOCKED_CARDS.has(card_id):
		return true
	return int(profile.get("runs_finished", 0)) >= int(LOCKED_CARDS[card_id])

func _select_character(char_id: String) -> void:
	character = char_id
	_refresh_character_buttons()

func _refresh_character_buttons() -> void:
	for char_id in character_buttons.keys():
		var chosen: bool = char_id == character
		var char_button: Button = character_buttons[char_id]
		char_button.add_theme_stylebox_override("normal", _make_style(Color("#f2e6c2") if chosen else Color("#e6d9ba"), Color("#a02818") if chosen else Color("#8c6a40"), 6, 3 if chosen else 1))
		char_button.add_theme_stylebox_override("hover", _make_style(Color("#f6efdc"), Color("#a02818"), 6, 2))

func _on_suggest_names() -> void:
	for member_id in name_edits.keys():
		var pool: Array = PARTY_DATA.NAME_POOLS[member_id]
		name_edits[member_id].text = pool[randi() % pool.size()]

func _on_continue_run_pressed() -> void:
	if run_mode != "camp":
		return
	if not _load_game():
		camp_continue_button.visible = false
		return
	run_mode = "map"
	if camp_overlay != null:
		camp_overlay.visible = false
	_refresh_ui()

func _camp_station(title: String, detail: String, art_path: String, accent: Color) -> Control:
	# Stations are a quiet legend over the camp illustration, not four competing cards.
	var station := VBoxContainer.new()
	station.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	station.add_theme_constant_override("separation", 3)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = accent
	station.add_child(rule)
	var title_label := _label(title, 16, Color("#221c14"))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	station.add_child(title_label)
	var detail_label := _label(detail, 12, Color("#4b3d2a"))
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	station.add_child(detail_label)
	return station

func _on_start_expedition_pressed() -> void:
	if run_mode != "camp":
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	# Every run walks its own trail unless a seed is asked for by name.
	var typed_seed := seed_edit.text.strip_edges() if seed_edit != null else ""
	if typed_seed.is_valid_int():
		run_seed = absi(int(typed_seed))
	elif not typed_seed.is_empty():
		run_seed = absi(typed_seed.hash())
	else:
		randomize()
		run_seed = randi() & 0x7FFFFFFF
	_initialize_run()
	for member_id in name_edits.keys():
		var typed: String = name_edits[member_id].text.strip_edges()
		if not typed.is_empty():
			party[member_id]["name"] = typed
	# Wagon outfitting: each toggle is one named, readable rule change.
	run_modifiers.clear()
	for key in modifier_checks.keys():
		run_modifiers[key] = modifier_checks[key].button_pressed
	if run_modifiers.get("well_stocked", false):
		supplies += 20
	if trailblazer >= 6:
		wagon_health = 80
	run_mode = "map"
	if camp_overlay != null:
		camp_overlay.visible = false
	_start_leg()
	_refresh_ui()

func _build_map_first_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The room: deep charcoal, darker at the edges. The game happens on a lit
	# parchment sheet in the middle of it — poker-table model, Balatro-style.
	var map_wash := ColorRect.new()
	map_wash.name = "CharcoalRoom"
	map_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_wash.color = DARK_BASE if UI_DARK else Color(0.91, 0.87, 0.76, 1.0)
	map_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_wash)
	map_wash_rect = map_wash
	if UI_DARK:
		var room_glow := TextureRect.new()
		room_glow.name = "RoomGlow"
		room_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		room_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var glow_gradient := Gradient.new()
		glow_gradient.set_color(0, Color("#1d1d22"))
		glow_gradient.set_color(1, Color("#0e0e10"))
		var glow_texture := GradientTexture2D.new()
		glow_texture.gradient = glow_gradient
		glow_texture.fill = GradientTexture2D.FILL_RADIAL
		glow_texture.fill_from = Vector2(0.42, 0.42)
		glow_texture.fill_to = Vector2(1.0, 1.0)
		room_glow.texture = glow_texture
		room_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(room_glow)
		var map_table := PanelContainer.new()
		map_table.name = "ParchmentTable"
		map_table.set_anchors_preset(Control.PRESET_TOP_LEFT)
		map_table.anchor_left = 0.02
		map_table.anchor_right = 0.66
		map_table.anchor_top = 0.155
		map_table.anchor_bottom = 0.775
		map_table.offset_left = 0.0
		map_table.offset_right = 0.0
		map_table.offset_top = 0.0
		map_table.offset_bottom = 0.0
		map_table.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_table.add_theme_stylebox_override("panel", _parchment_style(14))
		add_child(map_table)
		map_table_panel = map_table
		# The table IS a painted map now — a full hand-painted chart of the
		# West fills the paper; the route overlay inks itself on top.
		if ResourceLoader.exists("res://assets/art/scene/map-west.png"):
			var painted_map := TextureRect.new()
			painted_map.name = "PaintedWest"
			painted_map.texture = load("res://assets/art/scene/map-west.png") as Texture2D
			painted_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			painted_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			painted_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			painted_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
			map_table.add_child(painted_map)
		# Real paper has tooth: a tiled grain multiplied into the parchment.
		if ResourceLoader.exists("res://assets/art/grain.png"):
			var grain := TextureRect.new()
			grain.texture = load("res://assets/art/grain.png") as Texture2D
			grain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			grain.stretch_mode = TextureRect.STRETCH_TILE
			grain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_print_onto_paper(grain)
			map_table.add_child(grain)
	# ---- The viewport tree (Slay-the-Spire rule: one view at a time) ----
	# Full-rect wrappers keep every child's anchors unchanged while giving
	# each zone a single switch: MapView XOR EncounterView, HUD over both,
	# the hand deck banded above everything at the bottom.
	dynamic_content_layer = Control.new()
	dynamic_content_layer.name = "DynamicContentLayer"
	dynamic_content_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dynamic_content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dynamic_content_layer)
	map_view = Control.new()
	map_view.name = "MapView"
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dynamic_content_layer.add_child(map_view)
	encounter_view = Control.new()
	encounter_view.name = "EncounterView"
	encounter_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encounter_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dynamic_content_layer.add_child(encounter_view)
	top_hud_bar = Control.new()
	top_hud_bar.name = "TopHUDBar"
	top_hud_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_hud_bar)
	player_hand_deck = Control.new()
	player_hand_deck.name = "PlayerHandDeck"
	player_hand_deck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_hand_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_hand_deck)
	# The current stop's engraving, presented as a framed plate from an atlas.
	var plate := PanelContainer.new()
	plate.name = "LandmarkPlate"
	# Bottom-left corner of the table, clear of the mirrored trail — an inset
	# vignette like the picture panel on an atlas plate.
	plate.set_anchors_preset(Control.PRESET_TOP_LEFT)
	plate.anchor_left = 0.045
	plate.anchor_right = 0.27
	plate.anchor_top = 0.53
	plate.anchor_bottom = 0.75
	plate.offset_left = 0.0
	plate.offset_right = 0.0
	plate.offset_top = 0.0
	plate.offset_bottom = 0.0
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No frame: the illustration's feathered edges melt straight into the
	# parchment, like an inset vignette on an atlas plate.
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0, 0, 0, 0)
	plate_style.border_color = Color("#30251b")
	plate_style.set_border_width_all(0)
	plate_style.content_margin_left = 6.0
	plate_style.content_margin_right = 6.0
	plate_style.content_margin_top = 6.0
	plate_style.content_margin_bottom = 6.0
	plate.add_theme_stylebox_override("panel", plate_style)
	map_view.add_child(plate)
	landmark_plate_panel = plate
	# The painted chart made the inset vignette redundant clutter.
	plate.visible = not ResourceLoader.exists("res://assets/art/scene/map-west.png")
	var regional_landmark := TextureRect.new()
	regional_landmark.name = "RegionalLandmarkPlateArt"
	regional_landmark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	regional_landmark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	regional_landmark.texture = load(_plate_art("res://assets/art/fort-laramie.jpg")) as Texture2D
	regional_landmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_print_onto_paper(regional_landmark)
	plate.add_child(regional_landmark)
	landmark_art_rect = regional_landmark
	map_canvas = TrailMapCanvas.new()
	map_canvas.name = "TrailRouteOverlay"
	map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The whole map lives ON the parchment table — nothing runs off the paper.
	map_canvas.anchor_left = 0.04
	map_canvas.anchor_right = 0.64
	map_canvas.anchor_top = 0.175
	map_canvas.anchor_bottom = 0.75
	map_canvas.offset_top = 0.0
	map_canvas.offset_bottom = 0.0
	map_canvas.clip_contents = true
	# Integer-crisp pixels for the marching pieces the canvas draws itself.
	map_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_view.add_child(map_canvas)
	map_canvas.stop_names.assign(ROUTE_STOPS)
	map_canvas.label_font = font_display
	# The 16-bit marching family (Summer-generated) — pa leads, ox brings up the rear.
	for member_sprite in ["pa", "ma", "sarah", "dog", "ox"]:
		var sprite_path := "res://assets/sprites/family/%s.png" % member_sprite
		if ResourceLoader.exists(sprite_path):
			map_canvas.march_textures.append(load(sprite_path) as Texture2D)
	if ResourceLoader.exists("res://assets/sprites/family/wagon.png"):
		map_canvas.wagon_texture = load("res://assets/sprites/family/wagon.png") as Texture2D
	map_canvas.route_selected.connect(_on_route_selected)
	map_canvas.road_selected.connect(_on_road_selected)

	# ONE ribbon, not seven boxes. The day's ledger is set as type on a single
	# strip of paper: captions small and red, numbers big and black, hairline
	# rules between entries. The paper is the container — nothing else is.
	var ribbon := PanelContainer.new()
	ribbon.name = "LedgerRibbon"
	ribbon.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ribbon.anchor_left = 0.02
	ribbon.anchor_right = 0.98
	ribbon.anchor_top = 0.018
	ribbon.anchor_bottom = 0.162
	ribbon.offset_left = 0.0
	ribbon.offset_right = 0.0
	ribbon.offset_top = 0.0
	ribbon.offset_bottom = 0.0
	var ribbon_style := StyleBoxFlat.new()
	ribbon_style.bg_color = _themed_surface(Color(0.945, 0.905, 0.80, 0.97))
	ribbon_style.border_color = _themed_line(Color("#30251b"))
	ribbon_style.border_width_top = 1
	ribbon_style.border_width_bottom = 2
	ribbon_style.set_corner_radius_all(0)
	ribbon_style.content_margin_left = 20.0
	ribbon_style.content_margin_right = 20.0
	ribbon_style.content_margin_top = 7.0
	ribbon_style.content_margin_bottom = 7.0
	if UI_DARK:
		ribbon_style.shadow_color = Color(0, 0, 0, 0.5)
		ribbon_style.shadow_size = 12
		ribbon_style.shadow_offset = Vector2(0, 3)
	ribbon.add_theme_stylebox_override("panel", ribbon_style)
	top_hud_bar.add_child(ribbon)
	# Two rows of type on one strip: the ledger, then the family beneath it.
	var ribbon_stack := VBoxContainer.new()
	ribbon_stack.add_theme_constant_override("separation", 2)
	ribbon.add_child(ribbon_stack)
	var hud := HBoxContainer.new()
	hud.name = "CompactHUD"
	hud.add_theme_constant_override("separation", 18)
	ribbon_stack.add_child(hud)
	hud.add_child(_ledger_card("DAY", "01", Color("#221c14"), "", "Days on the trail. Each leg takes 3–5 days."))
	hud.add_child(_ribbon_rule())
	hud.add_child(_ledger_card("SUPPLIES", "68", Color("#221c14"), "", "Food and goods. Travel drains 2 per day; at 0, morale bleeds."))
	hud.add_child(_ribbon_rule())
	hud.add_child(_ledger_card("MORALE", "82", Color("#221c14"), "", "The party's will to go on. At 0, the journey ends."))
	hud.add_child(_ribbon_rule())
	hud.add_child(_ledger_card("WAGON", "100", Color("#221c14"), "", "Wagon condition. Bandit fire damages it; at 0, the run collapses."))
	hud.add_child(_ribbon_rule())
	hud.add_child(_ledger_card("MONEY", "—", Color("#7a5c16"), "", "Coin for shops down the trail."))
	hud.add_child(_ribbon_rule())
	var grit_box := VBoxContainer.new()
	grit_box.name = "GritCell"
	grit_box.add_theme_constant_override("separation", 0)
	grit_box.tooltip_text = "Grit pays for playing cards. Refills to 3 at the start of every leg."
	grit_box.add_child(_label("GRIT", 9, DARK_MUTED if UI_DARK else Color("#a02818")))
	grit_value = _label("3 / 3", 26, Color("#221c14"))
	grit_box.add_child(grit_value)
	grit_pips = _label("● ● ●", 10, Color("#a02818"))
	grit_box.add_child(grit_pips)
	hud.add_child(grit_box)
	# Destination rides the right edge: where you're headed in red, the leg
	# you're walking in small ink beneath it. No DESTINATION caption — the
	# arrow says it.
	var destination_box := VBoxContainer.new()
	destination_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_box.alignment = BoxContainer.ALIGNMENT_CENTER
	destination_box.add_theme_constant_override("separation", 0)
	destination_box.tooltip_text = "Reach Oregon City with morale above zero to win the run."
	destination_label = _label("NEXT · Kansas River", 20, Color("#a02818"))
	destination_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	destination_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_box.add_child(destination_label)
	route_note = _label("Independence  →  Kansas River", 9, Color("#6b5b41"))
	route_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	route_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_box.add_child(route_note)
	leg_label = _label("", 1, Color(0, 0, 0, 0))
	destination_box.add_child(leg_label)
	hud.add_child(destination_box)

	# The paper theater: encounters play out here as plates on stands.
	combat_stage = Control.new()
	combat_stage.name = "CombatStage"
	# The fight is a WINDOW into the West — edge to edge under the ribbon,
	# never framed as parchment (art director's veto). Cards lie over its
	# bottom edge like a table in front of the view.
	combat_stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	combat_stage.anchor_left = 0.0
	combat_stage.anchor_right = 1.0
	combat_stage.anchor_top = 0.14
	combat_stage.anchor_bottom = 1.0
	combat_stage.offset_left = 0.0
	combat_stage.offset_right = 0.0
	combat_stage.offset_top = 0.0
	combat_stage.offset_bottom = 0.0
	combat_stage.visible = false
	combat_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	encounter_view.add_child(combat_stage)
	var has_battle_scene := ResourceLoader.exists("res://assets/art/scene/battle-prairie.png")
	if has_battle_scene:
		battle_backdrop = TextureRect.new()
		battle_backdrop.name = "BattleBackdrop"
		battle_backdrop.texture = load("res://assets/art/scene/battle-prairie.png") as Texture2D
		battle_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		battle_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		battle_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		battle_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		combat_stage.add_child(battle_backdrop)
	var stage_floor := PanelContainer.new()
	stage_floor.name = "StageFloor"
	stage_floor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stage_floor.anchor_top = 0.82
	stage_floor.anchor_bottom = 0.86
	stage_floor.offset_top = 0.0
	stage_floor.offset_bottom = 0.0
	stage_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_floor.visible = not has_battle_scene
	var floor_style := StyleBoxFlat.new()
	floor_style.bg_color = Color(0.55, 0.47, 0.35, 0.35)
	floor_style.border_color = Color("#30251b")
	floor_style.border_width_top = 3
	stage_floor.add_theme_stylebox_override("panel", floor_style)
	combat_stage.add_child(stage_floor)

	# Actors are frameless book-plate cutouts printed straight into the paper —
	# no stands, no white plates. The oval feather lives in the PNGs themselves.
	# Combatants stand ON the painted ground strip, lower third, LARGE —
	# the wagon at roughly a quarter of the screen's height.
	wagon_actor = Control.new()
	wagon_actor.name = "WagonActor"
	wagon_actor.custom_minimum_size = Vector2(430, 195)
	wagon_actor.size = Vector2(430, 195)
	wagon_actor.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	wagon_actor.anchor_top = 0.62
	wagon_actor.anchor_bottom = 0.62
	wagon_actor.offset_left = 70.0
	wagon_actor.offset_top = -195.0
	wagon_actor.offset_bottom = 0.0
	wagon_actor.offset_right = 500.0
	wagon_actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_stage.add_child(wagon_actor)
	# Both combatants are 16-bit pieces now — same box as the family on the
	# map. Shadows anchor them to the parchment boards.
	_add_stage_shadow(wagon_actor)
	var wagon_img := TextureRect.new()
	wagon_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	wagon_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wagon_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wagon_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var stage_wagon_path := "res://assets/sprites/family/wagon.png"
	if ResourceLoader.exists(stage_wagon_path):
		wagon_img.texture = load(stage_wagon_path) as Texture2D
		# In a fight the wagon faces its attacker — oxen toward the threat.
		wagon_img.flip_h = true
		var wagon_tex_size := (wagon_img.texture as Texture2D).get_size()
		var wagon_fit := minf(430.0 / wagon_tex_size.x, 195.0 / wagon_tex_size.y)
		wagon_img.offset_top = 195.0 - wagon_tex_size.y * wagon_fit
		# Dusk light: warm highlights so the pieces sit in the sunset scene.
		wagon_img.modulate = Color(1.05, 0.96, 0.9)
	else:
		wagon_img.texture = load("res://assets/art/cutouts/wagon.png") as Texture2D
		_print_onto_paper(wagon_img)
	wagon_actor.add_child(wagon_img)
	stage_block_label = _label("", 16, Color("#1f5c33"))
	stage_block_label.position = Vector2(70, -30)
	if font_display != null:
		stage_block_label.add_theme_font_override("font", font_display)
	wagon_actor.add_child(stage_block_label)

	enemy_actor = Control.new()
	enemy_actor.name = "EnemyActor"
	enemy_actor.custom_minimum_size = Vector2(380, 320)
	enemy_actor.size = Vector2(380, 320)
	enemy_actor.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	enemy_actor.anchor_left = 1.0
	enemy_actor.anchor_right = 1.0
	enemy_actor.anchor_top = 0.62
	enemy_actor.anchor_bottom = 0.62
	enemy_actor.offset_left = -800.0
	enemy_actor.offset_right = -420.0
	enemy_actor.offset_top = -320.0
	enemy_actor.offset_bottom = 0.0
	enemy_actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_stage.add_child(enemy_actor)
	_add_stage_shadow(enemy_actor)
	enemy_plate = TextureRect.new()
	enemy_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	enemy_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_plate.modulate = Color(1.05, 0.96, 0.9)
	enemy_actor.add_child(enemy_plate)
	# The health bar hangs just over the creature's head; its exact height is
	# set per enemy in _stage_show_enemy.
	stage_hp_bg = ColorRect.new()
	stage_hp_bg.color = Color(0.12, 0.09, 0.07, 0.55)
	stage_hp_bg.position = Vector2(80, 120)
	stage_hp_bg.size = Vector2(220, 10)
	enemy_actor.add_child(stage_hp_bg)
	stage_hp_fill = ColorRect.new()
	stage_hp_fill.color = Color("#a02818")
	stage_hp_fill.position = Vector2(80, 120)
	stage_hp_fill.size = Vector2(220, 10)
	enemy_actor.add_child(stage_hp_fill)
	stage_hp_label = _label("", 14, Color("#f6efdc"))
	stage_hp_label.position = Vector2(306, 116)
	if font_display != null:
		stage_hp_label.add_theme_font_override("font", font_display)
	enemy_actor.add_child(stage_hp_label)
	stage_intent_banner = PanelContainer.new()
	stage_intent_banner.position = Vector2(30, -52)
	stage_intent_banner.add_theme_stylebox_override("panel", _make_style(Color("#a02818"), Color("#6b1a10"), 6, 2))
	enemy_actor.add_child(stage_intent_banner)
	stage_intent_label = _label("", 15, Color("#f6efdc"))
	if font_display != null:
		stage_intent_label.add_theme_font_override("font", font_display)
	stage_intent_banner.add_child(stage_intent_label)

	trinket_row = HBoxContainer.new()
	trinket_row.name = "TrinketStrip"
	trinket_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	trinket_row.anchor_left = 0.025
	trinket_row.anchor_right = 0.98
	trinket_row.anchor_top = 0.168
	trinket_row.anchor_bottom = 0.202
	trinket_row.offset_left = 0.0
	trinket_row.offset_right = 0.0
	trinket_row.offset_top = 0.0
	trinket_row.offset_bottom = 0.0
	trinket_row.add_theme_constant_override("separation", 5)
	top_hud_bar.add_child(trinket_row)
	keepsake_box = HBoxContainer.new()
	keepsake_box.add_theme_constant_override("separation", 5)
	keepsake_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trinket_row.add_child(keepsake_box)
	for i in range(3):
		var slot := Button.new()
		slot.name = "TonicSlot%d" % i
		slot.custom_minimum_size = Vector2(120, 0)
		slot.add_theme_font_size_override("font_size", 10)
		slot.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
		slot.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
		slot.add_theme_stylebox_override("normal", _make_style(Color("#efe6cf"), Color("#8c6a40"), 6, 1))
		slot.add_theme_stylebox_override("hover", _make_style(Color("#f6efdc"), Color("#a02818"), 6, 2))
		slot.add_theme_stylebox_override("disabled", _make_style(Color("#e6dcc2"), Color("#b0a284"), 6, 1))
		slot.pressed.connect(_drink_tonic.bind(i))
		trinket_row.add_child(slot)
		tonic_slots.append(slot)
	_refresh_trinket_strip()

	map_event_sheet = PanelContainer.new()
	map_event_sheet.name = "MapEncounterSheet"
	map_event_sheet.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_event_sheet.anchor_left = 0.68
	map_event_sheet.anchor_right = 0.975
	map_event_sheet.anchor_top = 0.16
	# Height follows content: the broadsheet ends where its last line ends,
	# instead of dragging a half-empty form down the screen.
	map_event_sheet.anchor_bottom = 0.16
	map_event_sheet.offset_left = 0.0
	map_event_sheet.offset_right = 0.0
	map_event_sheet.offset_top = 0.0
	map_event_sheet.offset_bottom = 0.0
	# The broadsheet: cream paper, ink-black type, red stamps — the letterpress look.
	map_event_sheet.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.89, 0.78, 0.97), Color("#30251b"), 6, 2))
	# The card drop target: the whole table accepts a dragged card during an
	# event or a fight. It sits UNDER the sheet so buttons stay clickable.
	var drop_zone := Control.new()
	drop_zone.name = "CardDropTarget"
	drop_zone.set_anchors_preset(Control.PRESET_TOP_LEFT)
	drop_zone.anchor_left = 0.02
	drop_zone.anchor_right = 0.66
	drop_zone.anchor_top = 0.155
	drop_zone.anchor_bottom = 0.775
	drop_zone.offset_left = 0.0
	drop_zone.offset_right = 0.0
	drop_zone.offset_top = 0.0
	drop_zone.offset_bottom = 0.0
	drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	drop_zone.set_drag_forwarding(Callable(), _zone_can_drop, _zone_drop)
	encounter_view.add_child(drop_zone)
	drop_highlight = PanelContainer.new()
	drop_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drop_highlight.visible = false
	drop_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var highlight_style := StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.63, 0.16, 0.09, 0.08)
	highlight_style.border_color = Color("#a02818")
	highlight_style.set_border_width_all(3)
	highlight_style.set_corner_radius_all(14)
	drop_highlight.add_theme_stylebox_override("panel", highlight_style)
	drop_zone.add_child(drop_highlight)
	encounter_view.add_child(map_event_sheet)
	var event_box := VBoxContainer.new()
	event_box.add_theme_constant_override("separation", 6)
	map_event_sheet.add_child(event_box)
	event_kicker = _label("UPCOMING TRAIL EVENT", 10, Color("#a02818"))
	event_box.add_child(event_kicker)
	event_title = _label("A Clear Morning", 21, Color("#221c14"))
	event_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(event_title)
	event_body = _label("Play cards in the hand, then travel to reveal the road's choice.", 12, Color("#4b3d2a"))
	event_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(event_body)
	# Event art hangs in the dark sheet like a painting: heavy dark-iron
	# outer frame, thin brass inner rule, parchment behind the engraving.
	# The feathered plate art melts into the parchment inside the frame.
	encounter_art_plate = PanelContainer.new()
	var iron_frame := StyleBoxFlat.new()
	iron_frame.bg_color = Color("#241c12")
	iron_frame.border_color = Color("#0e0b08")
	iron_frame.set_border_width_all(3)
	iron_frame.set_corner_radius_all(3)
	iron_frame.content_margin_left = 5.0
	iron_frame.content_margin_right = 5.0
	iron_frame.content_margin_top = 5.0
	iron_frame.content_margin_bottom = 5.0
	iron_frame.shadow_color = Color(0, 0, 0, 0.5)
	iron_frame.shadow_size = 12
	iron_frame.shadow_offset = Vector2(0, 4)
	encounter_art_plate.add_theme_stylebox_override("panel", iron_frame)
	encounter_art_plate.visible = false
	event_box.add_child(encounter_art_plate)
	var brass_rule := PanelContainer.new()
	var brass_style := StyleBoxFlat.new()
	brass_style.bg_color = PARCHMENT
	brass_style.border_color = Color("#b18a45")
	brass_style.set_border_width_all(1)
	brass_style.content_margin_left = 2.0
	brass_style.content_margin_right = 2.0
	brass_style.content_margin_top = 2.0
	brass_style.content_margin_bottom = 2.0
	brass_rule.add_theme_stylebox_override("panel", brass_style)
	encounter_art_plate.add_child(brass_rule)
	encounter_art = TextureRect.new()
	encounter_art.name = "EncounterEnemyArt"
	encounter_art.custom_minimum_size = Vector2(0, 126)
	encounter_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	encounter_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	encounter_art.visible = false
	_print_onto_paper(encounter_art)
	brass_rule.add_child(encounter_art)
	encounter_health_label = _label("", 11, Color("#6b3a1e"))
	encounter_health_label.visible = false
	event_box.add_child(encounter_health_label)
	encounter_intent_label = _label("", 13, Color("#a02818"))
	encounter_intent_label.visible = false
	event_box.add_child(encounter_intent_label)
	encounter_stake_label = _label("", 10, Color("#5a4932"))
	encounter_stake_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encounter_stake_label.visible = false
	event_box.add_child(encounter_stake_label)
	outcome_label = _label("", 11, Color("#1f5c33"))
	outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(outcome_label)
	choice_a = _make_choice_button("A  ·  Card branch")
	choice_a.name = "EventChoiceA"
	choice_a.pressed.connect(_on_choice_a)
	event_box.add_child(choice_a)
	choice_b = _make_choice_button("B  ·  Leave")
	choice_b.name = "EventChoiceB"
	choice_b.pressed.connect(_on_choice_b)
	event_box.add_child(choice_b)
	event_hint = _label("The map keeps the journey in view while the next decision is disclosed.", 10, Color("#6b5b41"))
	event_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(event_hint)
	reward_box = VBoxContainer.new()
	reward_box.name = "RewardChoices"
	reward_box.add_theme_constant_override("separation", 4)
	reward_box.visible = false
	event_box.add_child(reward_box)
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "CONTINUE JOURNEY   →"
	continue_button.custom_minimum_size.y = 43.0
	continue_button.add_theme_font_size_override("font_size", 13)
	continue_button.add_theme_font_override("font", font_display)
	continue_button.add_theme_color_override("font_color", Color("#1b211e"))
	continue_button.add_theme_stylebox_override("normal", _make_style(Color("#d5b66d"), Color("#efd28e"), 9, 1))
	continue_button.add_theme_stylebox_override("hover", _make_style(Color("#e2c681"), Color("#f5dfab"), 9, 2))
	continue_button.pressed.connect(_on_continue_pressed)
	event_box.add_child(continue_button)
	return_to_camp_button = Button.new()
	return_to_camp_button.name = "ReturnToCamp"
	return_to_camp_button.text = "RETURN TO CAMP"
	return_to_camp_button.custom_minimum_size.y = 34.0
	return_to_camp_button.visible = false
	return_to_camp_button.add_theme_font_size_override("font_size", 13)
	return_to_camp_button.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 8, 1))
	return_to_camp_button.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	return_to_camp_button.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	return_to_camp_button.pressed.connect(_return_to_camp)
	event_box.add_child(return_to_camp_button)

	var hand_panel := PanelContainer.new()
	hand_panel.name = "PhysicalHandOverlay"
	hand_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hand_panel.anchor_left = 0.02
	hand_panel.anchor_right = 0.98
	hand_panel.anchor_top = 0.9
	hand_panel.anchor_bottom = 0.995
	hand_panel.offset_left = 0.0
	hand_panel.offset_right = 0.0
	hand_panel.offset_top = 0.0
	hand_panel.offset_bottom = 0.0
	hand_panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.885, 0.78, 0.96), Color("#a97847"), 13, 2))
	player_hand_deck.add_child(hand_panel)
	var hand_box := VBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 4)
	hand_panel.add_child(hand_box)
	var hand_header := HBoxContainer.new()
	hand_box.add_child(hand_header)
	# The drawer's handle: a small tab that pins the hand open or lets it rest.
	hand_tab_button = Button.new()
	hand_tab_button.name = "OpenHandTab"
	hand_tab_button.text = "▲  OPEN HAND · 5"
	hand_tab_button.add_theme_font_size_override("font_size", 11)
	hand_tab_button.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 32, 1))
	hand_tab_button.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	hand_tab_button.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	hand_tab_button.pressed.connect(_on_hand_tab_pressed)
	hand_header.add_child(hand_tab_button)
	hand_header.add_child(_label("YOUR HAND", 11, Color("#a02818")))
	hand_value = _label("HAND 05", 10, Color("#4b3d2a"))
	hand_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand_header.add_child(hand_value)
	var view_deck := Button.new()
	view_deck.name = "ViewDeckButton"
	view_deck.text = "VIEW DECK"
	view_deck.add_theme_font_size_override("font_size", 12)
	view_deck.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 6, 1))
	view_deck.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	view_deck.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	view_deck.tooltip_text = "Every card the wagon carries, counted."
	view_deck.pressed.connect(_open_pile_view.bind("deck"))
	hand_header.add_child(view_deck)
	var draw_stack := Button.new()
	draw_stack.name = "DrawPileButton"
	draw_stack.add_theme_stylebox_override("normal", _make_style(Color("#efe6cf"), Color("#30251b"), 6, 1))
	draw_stack.add_theme_stylebox_override("hover", _make_style(Color("#f6efdc"), Color("#a02818"), 6, 2))
	draw_stack.tooltip_text = "Cards still to come this leg. Click to view (shown shuffled — the order stays secret)."
	draw_stack.pressed.connect(_open_pile_view.bind("draw"))
	draw_pile_label = _label("DRAW\n05", 9, Color("#4b3d2a"))
	draw_pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_pile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_stack.add_child(draw_pile_label)
	hand_header.add_child(draw_stack)
	var discard_stack := Button.new()
	discard_stack.name = "DiscardPileButton"
	discard_stack.add_theme_stylebox_override("normal", _make_style(Color("#e6dcc2"), Color("#8c6a40"), 6, 1))
	discard_stack.add_theme_stylebox_override("hover", _make_style(Color("#f0e7cf"), Color("#a02818"), 6, 2))
	discard_stack.tooltip_text = "Cards already used this leg. They reshuffle when the draw pile empties. Click to view."
	discard_stack.pressed.connect(_open_pile_view.bind("discard"))
	discard_pile_label = _label("DISCARD\n00", 9, Color("#6b5b41"))
	discard_pile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_pile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_stack.add_child(discard_pile_label)
	hand_header.add_child(discard_stack)
	card_status = _label("Click plays a card · right-click discards it.", 10, Color("#6b5b41"))
	hand_box.add_child(card_status)
	# The held hand: cards sit tucked into the bottom edge of the screen like a
	# fan of paper in your fist. Hover slides one up to read it whole (StS-style).
	hand_container = Control.new()
	hand_container.name = "HandCards"
	hand_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hand_container.anchor_left = 0.1
	hand_container.anchor_right = 0.9
	hand_container.anchor_top = 0.79
	hand_container.anchor_bottom = 1.0
	hand_container.offset_bottom = 20.0
	hand_container.offset_top = 0.0
	hand_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_hand_deck.add_child(hand_container)
	_rebuild_hand_ui()
	_wire_hand_card_juice()

	# The Family, set as the ribbon's second line of type — not five gray
	# pills. A colored swatch names each member; the words carry the
	# condition. On the strip, nothing ever covers them, fight or no fight.
	roster_row = HBoxContainer.new()
	roster_row.name = "FamilyRoster"
	roster_row.add_theme_constant_override("separation", 16)
	ribbon_stack.add_child(roster_row)
	for member_id in PARTY_DATA.MEMBER_ORDER:
		var chip := PanelContainer.new()
		chip.name = "Roster_%s" % member_id
		chip.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var chip_row := HBoxContainer.new()
		chip_row.add_theme_constant_override("separation", 6)
		chip.add_child(chip_row)
		# The family are FACES now, not colored dots: 16-bit busts matching the
		# marching sprites on the map — one character identity everywhere.
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(32, 32)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var portrait_path := "res://assets/sprites/busts/%s.png" % member_id
		if ResourceLoader.exists(portrait_path):
			portrait.texture = load(portrait_path) as Texture2D
		chip_row.add_child(portrait)
		var chip_label := _label("", 10, Color("#4b3d2a"))
		chip_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip_row.add_child(chip_label)
		roster_row.add_child(chip)
		roster_chips[member_id] = {"panel": chip, "label": chip_label, "portrait": portrait}

	# Bark bubble: one line from the family, fades on its own.
	bark_panel = PanelContainer.new()
	bark_panel.name = "BarkBubble"
	bark_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bark_panel.anchor_left = 0.025
	bark_panel.anchor_right = 0.38
	bark_panel.anchor_top = 0.195
	bark_panel.anchor_bottom = 0.195
	bark_panel.offset_left = 0.0
	bark_panel.offset_right = 0.0
	bark_panel.offset_top = 0.0
	bark_panel.offset_bottom = 0.0
	bark_panel.visible = false
	bark_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bark_panel.add_theme_stylebox_override("panel", _make_style(Color(0.94, 0.89, 0.76, 0.96), Color("#8c5a35"), 12, 2))
	bark_label = _label("", 11, Color("#3a2c1c"))
	bark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bark_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bark_panel.add_child(bark_label)
	dynamic_content_layer.add_child(bark_panel)

	# Pile viewer overlay (draw / discard / whole deck).
	pile_panel = PanelContainer.new()
	pile_panel.name = "PileViewer"
	pile_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pile_panel.anchor_left = 0.27
	pile_panel.anchor_right = 0.73
	pile_panel.anchor_top = 0.14
	pile_panel.anchor_bottom = 0.74
	pile_panel.offset_left = 0.0
	pile_panel.offset_right = 0.0
	pile_panel.offset_top = 0.0
	pile_panel.offset_bottom = 0.0
	pile_panel.visible = false
	pile_panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.885, 0.78, 0.97), Color("#d5b66d"), 14, 2))
	add_child(pile_panel)
	var pile_box := VBoxContainer.new()
	pile_box.add_theme_constant_override("separation", 6)
	pile_panel.add_child(pile_box)
	pile_title = _label("DRAW PILE", 14, Color("#a02818"))
	pile_box.add_child(pile_title)
	var pile_scroll := ScrollContainer.new()
	pile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pile_box.add_child(pile_scroll)
	pile_list = _label("", 11, Color("#2c2114"))
	pile_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pile_scroll.add_child(pile_list)
	var pile_close := Button.new()
	pile_close.name = "ClosePileView"
	pile_close.text = "CLOSE"
	pile_close.custom_minimum_size.y = 36.0
	pile_close.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 8, 1))
	pile_close.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	pile_close.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	pile_close.pressed.connect(_close_pile_view)
	pile_box.add_child(pile_close)

	# Pa's Steady Hands: a disclosed either/or, never a hidden roll.
	pa_panel = PanelContainer.new()
	pa_panel.name = "PaChoicePanel"
	pa_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pa_panel.anchor_left = 0.3
	pa_panel.anchor_right = 0.7
	pa_panel.anchor_top = 0.3
	pa_panel.anchor_bottom = 0.58
	pa_panel.offset_left = 0.0
	pa_panel.offset_right = 0.0
	pa_panel.offset_top = 0.0
	pa_panel.offset_bottom = 0.0
	pa_panel.visible = false
	pa_panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.885, 0.78, 0.97), Color("#221c14"), 14, 2))
	add_child(pa_panel)
	var pa_box := VBoxContainer.new()
	pa_box.add_theme_constant_override("separation", 8)
	pa_panel.add_child(pa_box)
	pa_title_label = _label("PA'S STEADY HANDS", 14, Color("#a02818"))
	pa_box.add_child(pa_title_label)
	pa_supplies_button = _make_choice_button("GAIN 5 SUPPLIES")
	pa_supplies_button.name = "PaChoiceSupplies"
	pa_supplies_button.pressed.connect(_resolve_pa_choice.bind(false))
	pa_box.add_child(pa_supplies_button)
	pa_wagon_button = _make_choice_button("REPAIR THE WAGON BY 5")
	pa_wagon_button.name = "PaChoiceWagon"
	pa_wagon_button.pressed.connect(_resolve_pa_choice.bind(true))
	pa_box.add_child(pa_wagon_button)

	# Letterpress finish: a lightweight procedural paper grain and soft vignette over the map.
	var paper_shader := Shader.new()
	paper_shader.code = """
shader_type canvas_item;
render_mode unshaded;

float paper_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float edge_distance = distance(UV, vec2(0.5));
	float vignette = smoothstep(0.34, 0.76, edge_distance);
	float coarse_grain = paper_hash(floor(UV * vec2(720.0, 450.0))) - 0.5;
	float fine_grain = paper_hash(floor(UV * vec2(1800.0, 1100.0))) - 0.5;
	float grain = coarse_grain * 0.022 + fine_grain * 0.012;
	vec3 ink_tint = vec3(0.12, 0.075, 0.035) + vec3(grain);
	float alpha = 0.018 + vignette * 0.105 + grain * 0.18;
	COLOR = vec4(ink_tint, clamp(alpha, 0.0, 0.15));
}
"""
	var paper_overlay := ColorRect.new()
	paper_overlay.name = "PaperGrainVignette"
	paper_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper_overlay.color = Color.WHITE
	paper_overlay.material = ShaderMaterial.new()
	(paper_overlay.material as ShaderMaterial).shader = paper_shader
	paper_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper_overlay)

	# Letter home: written at the forts, sealed by hand. Screenshot the grief and the grit.
	letter_panel = PanelContainer.new()
	letter_panel.name = "LetterHome"
	letter_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	letter_panel.anchor_left = 0.22
	letter_panel.anchor_right = 0.78
	letter_panel.anchor_top = 0.1
	letter_panel.anchor_bottom = 0.72
	letter_panel.offset_left = 0.0
	letter_panel.offset_right = 0.0
	letter_panel.offset_top = 0.0
	letter_panel.offset_bottom = 0.0
	letter_panel.visible = false
	letter_panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.88, 0.75, 0.98), Color("#30251b"), 6, 2))
	add_child(letter_panel)
	var letter_box := VBoxContainer.new()
	letter_box.add_theme_constant_override("separation", 8)
	letter_panel.add_child(letter_box)
	letter_box.add_child(_label("A LETTER HOME", 13, Color("#a02818")))
	var letter_scroll := ScrollContainer.new()
	letter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	letter_box.add_child(letter_scroll)
	letter_text = _label("", 12, Color("#2c2114"))
	letter_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	letter_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letter_scroll.add_child(letter_text)
	var seal := Button.new()
	seal.name = "SealLetter"
	seal.text = "SEAL AND SEND  ·  MORALE +2"
	seal.custom_minimum_size.y = 40.0
	seal.add_theme_font_size_override("font_size", 12)
	seal.add_theme_font_override("font", font_display)
	seal.add_theme_color_override("font_color", Color("#f2e4c4"))
	seal.add_theme_stylebox_override("normal", _make_style(Color("#a02818"), Color("#6b1a10"), 8, 2))
	seal.add_theme_stylebox_override("hover", _make_style(Color("#bb3524"), Color("#8c2a1d"), 8, 2))
	seal.pressed.connect(_seal_letter)
	letter_box.add_child(seal)

	# The sutler's counter: fort shopping, every price on the sign.
	shop_panel = PanelContainer.new()
	shop_panel.name = "SutlerShop"
	shop_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	shop_panel.anchor_left = 0.24
	shop_panel.anchor_right = 0.76
	shop_panel.anchor_top = 0.12
	shop_panel.anchor_bottom = 0.72
	shop_panel.offset_left = 0.0
	shop_panel.offset_right = 0.0
	shop_panel.offset_top = 0.0
	shop_panel.offset_bottom = 0.0
	shop_panel.visible = false
	shop_panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.88, 0.75, 0.98), Color("#30251b"), 6, 2))
	add_child(shop_panel)
	var shop_box := VBoxContainer.new()
	shop_box.add_theme_constant_override("separation", 6)
	shop_panel.add_child(shop_box)
	shop_title = _label("THE SUTLER'S STORE", 14, Color("#a02818"))
	shop_box.add_child(shop_title)
	var shop_art := TextureRect.new()
	shop_art.custom_minimum_size = Vector2(0, 90)
	shop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	shop_art.texture = load("res://assets/art/general-store.jpg") as Texture2D
	_print_onto_paper(shop_art)
	shop_box.add_child(shop_art)
	for i in range(6):
		var offer_button := _make_choice_button("")
		offer_button.name = "ShopOffer%d" % i
		offer_button.pressed.connect(_buy_shop_offer.bind(i))
		shop_box.add_child(offer_button)
		shop_buttons.append(offer_button)
	var leave_button := Button.new()
	leave_button.name = "LeaveShop"
	leave_button.text = "BACK TO THE TRAIL"
	leave_button.custom_minimum_size.y = 38.0
	leave_button.add_theme_font_size_override("font_size", 12)
	leave_button.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	leave_button.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	leave_button.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 8, 1))
	leave_button.pressed.connect(_leave_shop)
	shop_box.add_child(leave_button)

func _build_journey_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "JourneyRoute"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.4
	panel.add_theme_stylebox_override("panel", _make_style(Color("#2b2119"), Color("#a28b63"), 13, 2))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	heading.add_child(_label("YOUR JOURNEY", 11, Color("#c9a86a")))
	route_note = _label("Following the Platte River west", 18, Color("#f1eee2"))
	heading.add_child(route_note)
	destination_label = _label("NEXT · Kansas River", 11, Color("#8fbaa0"))
	destination_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(destination_label)
	var rule := ColorRect.new()
	rule.color = Color("#a02818")
	rule.custom_minimum_size.y = 2.0
	box.add_child(rule)
	var route_art := TextureRect.new()
	route_art.name = "RouteArtwork"
	route_art.custom_minimum_size = Vector2(0, 104)
	route_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	route_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	route_art.texture = load("res://assets/art/wagon-train.jpg") as Texture2D
	box.add_child(route_art)
	route_row = FlowContainer.new()
	route_row.name = "RouteStops"
	route_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_row.custom_minimum_size.y = 86.0
	route_row.add_theme_constant_override("h_separation", 4)
	route_row.add_theme_constant_override("v_separation", 4)
	box.add_child(route_row)
	_build_route_stops()
	box.add_child(_label("THE OREGON ROUTE  ·  14 LANDMARKS  ·  12+ TRAVEL LEGS", 10, Color("#6b5b41")))

	var status := PanelContainer.new()
	status.add_theme_stylebox_override("panel", _make_style(Color("#efe6cf"), Color("#8c6a40"), 9, 1))
	box.add_child(status)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 18)
	status.add_child(status_row)
	var day_stack := VBoxContainer.new()
	day_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(day_stack)
	day_stack.add_child(_label("CURRENT DAY", 9, Color("#a02818")))
	day_label = _label("DAY 01", 20, Color("#221c14"))
	day_stack.add_child(day_label)
	var leg_stack := VBoxContainer.new()
	leg_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(leg_stack)
	leg_stack.add_child(_label("TRAIL PROGRESS", 9, Color("#a02818")))
	leg_label = _label("LEG 0 / 12", 20, Color("#f1eee2"))
	leg_stack.add_child(leg_label)
	var status_stack := VBoxContainer.new()
	status_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_stack)
	status_stack.add_child(_label("TRAVEL STATUS", 9, Color("#a02818")))
	status_stack.add_child(_label("ON THE TRAIL", 14, Color("#1f5c33")))

	box.add_child(_label("THE PARTY LEDGER", 10, Color("#c9a86a")))
	var ledger := HBoxContainer.new()
	ledger.add_theme_constant_override("separation", 8)
	box.add_child(ledger)
	ledger.add_child(_ledger_card("SUPPLIES", "68", Color("#221c14"), "drain: 2 × travel day"))
	ledger.add_child(_ledger_card("MORALE", "82", Color("#221c14"), "starvation drains 8"))
	ledger.add_child(_ledger_card("WAGON HEALTH", "100", Color("#221c14"), "injuries: 0"))
	var warning := _label("Telegraph: threat can hit morale, supplies, or wagon health. Morale ≤ 0 ends the run.", 10, Color("#6b5b41"))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warning)

func _ledger_card(caption: String, value: String, color: Color, detail: String, tooltip: String = "") -> PanelContainer:
	# A ledger entry is TYPE, not a box: red small-caps caption over a big
	# black number. The ribbon strip behind it is the only container.
	var panel := PanelContainer.new()
	if not tooltip.is_empty():
		panel.tooltip_text = tooltip
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	panel.add_child(stack)
	# Captions whisper, numbers speak — red stays reserved for what matters.
	stack.add_child(_label(caption, 9, DARK_MUTED if UI_DARK else Color("#a02818")))
	var number := _label(value, 26, color)
	if caption == "DAY":
		day_label = number
	elif caption == "SUPPLIES":
		supply_value = number
	elif caption == "MORALE":
		morale_value = number
	elif caption == "LOCATION":
		location_value = number
	elif caption == "MONEY":
		money_value = number
	elif caption == "WAGON" or caption == "WAGON CONDITION" or caption == "WAGON HEALTH":
		health_value = number
	stack.add_child(number)
	if not detail.is_empty():
		stack.add_child(_label(detail, 8, Color("#6b5b41")))
	return panel

func _build_reward_overlay() -> void:
	# Rewards are CARDS on the table, not text buttons — pick one up.
	reward_overlay = Control.new()
	reward_overlay.name = "RewardOverlay"
	reward_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_overlay.visible = false
	add_child(reward_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_overlay.add_child(dim)
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stack.anchor_left = 0.5
	stack.anchor_right = 0.5
	stack.anchor_top = 0.20
	stack.anchor_bottom = 0.20
	stack.offset_left = -300.0
	stack.offset_right = 300.0
	stack.add_theme_constant_override("separation", 18)
	reward_overlay.add_child(stack)
	var reward_title := _label("CHOOSE ONE REWARD", 30, Color("#e4bd65"))
	reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(reward_title)
	reward_card_row = HBoxContainer.new()
	reward_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_card_row.add_theme_constant_override("separation", 22)
	stack.add_child(reward_card_row)
	var skip := Button.new()
	skip.text = "LEAVE THEM  ·  POCKET $3"
	skip.add_theme_font_override("font", font_display)
	skip.add_theme_font_size_override("font_size", 15)
	skip.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#30251b"), 2, 1))
	skip.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	skip.pressed.connect(_skip_reward)
	var skip_row := HBoxContainer.new()
	skip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_row.add_child(skip)
	stack.add_child(skip_row)

func _on_reward_face_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_sfx("stamp")
		_choose_reward(index)

func _setup_audio() -> void:
	var manifest := {
		"theme": "res://assets/audio/theme.mp3",
		"drone": "res://assets/audio/drone.mp3",
		"ambient": "res://assets/audio/ambient.wav",
		"card": "res://assets/audio/card-play.wav",
		"gunshot": "res://assets/audio/gunshot.wav",
		"click": "res://assets/audio/click.wav",
		"hit": "res://assets/audio/hit.wav",
		"growl": "res://assets/audio/growl.wav",
		"stamp": "res://assets/audio/stamp.wav",
		"roll": "res://assets/audio/wagon-roll.wav",
	}
	for key in manifest.keys():
		if ResourceLoader.exists(str(manifest[key])):
			audio_streams[key] = load(str(manifest[key]))
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -10.0
	add_child(music_player)
	music_player.finished.connect(func() -> void: music_player.play())
	ambient_player = AudioStreamPlayer.new()
	ambient_player.volume_db = -15.0
	add_child(ambient_player)
	ambient_player.finished.connect(func() -> void: ambient_player.play())
	for i in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -6.0
		add_child(voice)
		sfx_players.append(voice)
	if audio_streams.has("ambient"):
		ambient_player.stream = audio_streams["ambient"]
		ambient_player.play()
	_set_music("theme")

func _set_music(mode: String) -> void:
	# Two states, per the score's design: the trail theme, and the lone
	# drone that takes over when morale runs low.
	if music_mode == mode or not audio_streams.has(mode) or music_player == null:
		return
	music_mode = mode
	music_player.stream = audio_streams[mode]
	music_player.play()

func _play_sfx(key: String) -> void:
	if not audio_streams.has(key) or sfx_players.is_empty():
		return
	var voice := sfx_players[sfx_cursor % sfx_players.size()]
	sfx_cursor += 1
	voice.stream = audio_streams[key]
	voice.play()

func _juice_all_buttons(node: Node) -> void:
	# Every button in the game answers the hand: brighten on hover, squash on
	# press. One recursive pass instead of two hundred connect calls.
	if node is Button:
		var button := node as Button
		if not button.has_meta("juiced"):
			button.set_meta("juiced", true)
			button.mouse_entered.connect(func() -> void:
				button.pivot_offset = button.size * 0.5
				var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				t.tween_property(button, "modulate", Color(1.12, 1.12, 1.08), 0.1))
			button.mouse_exited.connect(func() -> void:
				var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				t.set_parallel(true)
				t.tween_property(button, "modulate", Color.WHITE, 0.12)
				t.tween_property(button, "scale", Vector2.ONE, 0.12))
			button.button_down.connect(func() -> void:
				_play_sfx("click")
				button.pivot_offset = button.size * 0.5
				var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				t.tween_property(button, "scale", Vector2(0.95, 0.95), 0.06))
			button.button_up.connect(func() -> void:
				var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				t.tween_property(button, "scale", Vector2.ONE, 0.14))
	for child in node.get_children():
		_juice_all_buttons(child)

func _ribbon_rule() -> Control:
	# Hairline separator between ledger entries — a printer's rule, not a wall.
	var rule := ColorRect.new()
	rule.color = Color(0.55, 0.47, 0.36, 0.55)
	rule.custom_minimum_size = Vector2(1, 0)
	return rule

func _build_sidebar(parent: HBoxContainer) -> void:
	var side := VBoxContainer.new()
	side.name = "JourneySidebar"
	side.custom_minimum_size.x = 300.0
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 0.8
	side.add_theme_constant_override("separation", 9)
	parent.add_child(side)
	var ledger_panel := PanelContainer.new()
	ledger_panel.add_theme_stylebox_override("panel", _make_style(Color("#2b2119"), Color("#a28b63"), 13, 2))
	side.add_child(ledger_panel)
	var ledger_box := VBoxContainer.new()
	ledger_box.add_theme_constant_override("separation", 6)
	ledger_panel.add_child(ledger_box)
	ledger_box.add_child(_label("GRIT / ACTION BUDGET", 11, Color("#c9a86a")))
	grit_value = _label("3 / 3", 23, Color("#a02818"))
	ledger_box.add_child(grit_value)
	grit_pips = _label("● ● ●", 14, Color("#a02818"))
	ledger_box.add_child(grit_pips)
	ledger_box.add_child(_label("Refills to 3 at the start of every leg.", 10, Color("#6b5b41")))

	var event_panel := PanelContainer.new()
	event_panel.name = "TrailEvent"
	event_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_panel.add_theme_stylebox_override("panel", _make_style(Color("#302219"), Color("#a02818"), 13, 2))
	side.add_child(event_panel)
	var event_box := VBoxContainer.new()
	event_box.add_theme_constant_override("separation", 6)
	event_panel.add_child(event_box)
	event_kicker = _label("UPCOMING TRAIL EVENT", 10, Color("#a02818"))
	event_box.add_child(event_kicker)
	event_title = _label("A Clear Morning", 20, Color("#f2dfb3"))
	event_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(event_title)
	event_body = _label("Play cards below, then continue to reveal the road's choice.", 13, Color("#c6bda9"))
	event_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	event_box.add_child(event_body)
	encounter_art = TextureRect.new()
	encounter_art.name = "EncounterArtwork"
	encounter_art.custom_minimum_size = Vector2(0, 82)
	encounter_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	encounter_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	encounter_art.visible = false
	if encounter_art_plate != null:
		encounter_art_plate.visible = false
	_print_onto_paper(encounter_art)
	event_box.add_child(encounter_art)
	encounter_health_label = _label("", 12, Color("#f0c28a"))
	encounter_health_label.visible = false
	event_box.add_child(encounter_health_label)
	encounter_intent_label = _label("", 12, Color("#f08c70"))
	encounter_intent_label.visible = false
	event_box.add_child(encounter_intent_label)
	encounter_stake_label = _label("", 10, Color("#c6bda9"))
	encounter_stake_label.visible = false
	encounter_stake_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(encounter_stake_label)
	outcome_label = _label("", 11, Color("#1f5c33"))
	outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(outcome_label)
	choice_a = _make_choice_button("A  ·  Card branch")
	choice_a.name = "EventChoiceA"
	choice_a.pressed.connect(_on_choice_a)
	event_box.add_child(choice_a)
	choice_b = _make_choice_button("B  ·  Leave")
	choice_b.name = "EventChoiceB"
	choice_b.pressed.connect(_on_choice_b)
	event_box.add_child(choice_b)
	event_hint = _label("Every event has a visible card requirement and a free leave.", 10, Color("#9e927b"))
	event_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(event_hint)
	reward_box = VBoxContainer.new()
	reward_box.name = "RewardChoices"
	reward_box.add_theme_constant_override("separation", 4)
	reward_box.visible = false
	event_box.add_child(reward_box)
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "CONTINUE JOURNEY   →"
	continue_button.custom_minimum_size.y = 49.0
	continue_button.add_theme_font_size_override("font_size", 15)
	continue_button.add_theme_color_override("font_color", Color("#1b211e"))
	continue_button.add_theme_stylebox_override("normal", _make_style(Color("#d5b66d"), Color("#efd28e"), 9, 1))
	continue_button.add_theme_stylebox_override("hover", _make_style(Color("#e2c681"), Color("#f5dfab"), 9, 2))
	continue_button.pressed.connect(_on_continue_pressed)
	side.add_child(continue_button)

func _build_deck_panel(page: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "DeckbuilderPanel"
	panel.custom_minimum_size.y = 190.0
	panel.add_theme_stylebox_override("panel", _make_style(Color("#2b2119"), Color("#a02818"), 13, 2))
	page.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_child(_label("TRAIL DECK  /  HAND", 11, Color("#a02818")))
	heading.add_child(_label("Play or discard cards to prepare the wagon for its next mile.", 13, Color("#f1eee2")))
	hand_value = _label("HAND 05  ·  DRAW PILE 05  ·  DISCARD PILE 00", 11, Color("#4b3d2a"))
	hand_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(hand_value)
	var rule := ColorRect.new()
	rule.color = Color("#5c4a32")
	rule.custom_minimum_size.y = 1.0
	box.add_child(rule)
	hand_container = HBoxContainer.new()
	hand_container.name = "HandCards"
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_container.add_theme_constant_override("separation", 5)
	box.add_child(hand_container)
	card_status = _label("Click plays a card · right-click discards it.", 10, Color("#6b5b41"))
	box.add_child(card_status)
	_rebuild_hand_ui()
	_wire_hand_card_juice()

func _build_route_stops() -> void:
	for i in ROUTE_STOPS.size():
		var stop := VBoxContainer.new()
		stop.name = "Stop%d" % i
		stop.custom_minimum_size = Vector2(88, 37)
		var marker := _label("○", 16, Color("#66766b"))
		marker.name = "Marker"
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stop.add_child(marker)
		var name_label := _label(ROUTE_STOPS[i], 8, Color("#829187"))
		name_label.name = "StopLabel"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stop.add_child(name_label)
		route_row.add_child(stop)

func _make_choice_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 47.0
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
	button.add_theme_color_override("font_hover_color", _themed_text(Color("#221c14")))
	button.add_theme_color_override("font_disabled_color", Color("#8a7d68"))
	button.add_theme_stylebox_override("normal", _make_style(Color("#e6d9ba"), Color("#8c6a40"), 4, 1))
	button.add_theme_stylebox_override("hover", _make_style(Color("#f1e5c5"), Color("#a02818"), 4, 2))
	button.add_theme_stylebox_override("disabled", _make_style(Color("#d4c9ae"), Color("#a89877"), 4, 1))
	return button

func _create_stable_probe_nodes() -> void:
	probe_continue_button = Button.new()
	probe_continue_button.name = "probe_continue"
	probe_continue_button.visible = false
	probe_continue_button.pressed.connect(_on_continue_pressed)
	add_child(probe_continue_button)
	probe_event_a = Button.new()
	probe_event_a.name = "probe_event_a"
	probe_event_a.visible = false
	probe_event_a.pressed.connect(_on_choice_a)
	add_child(probe_event_a)
	probe_event_b = Button.new()
	probe_event_b.name = "probe_event_b"
	probe_event_b.visible = false
	probe_event_b.pressed.connect(_on_choice_b)
	add_child(probe_event_b)
	probe_reward_skip = Button.new()
	probe_reward_skip.name = "probe_reward_skip"
	probe_reward_skip.visible = false
	probe_reward_skip.pressed.connect(_skip_reward)
	add_child(probe_reward_skip)
	for i in range(8):
		var play := Button.new()
		play.name = "probe_card_%d" % i
		play.visible = false
		play.pressed.connect(_on_card_pressed.bind(i))
		add_child(play)
		probe_play_buttons.append(play)
		var discard := Button.new()
		discard.name = "probe_discard_%d" % i
		discard.visible = false
		discard.pressed.connect(_on_discard_pressed.bind(i))
		add_child(discard)
		probe_discard_buttons.append(discard)
		var reward := Button.new()
		reward.name = "probe_reward_%d" % i
		reward.visible = false
		reward.pressed.connect(_choose_reward.bind(i))
		add_child(reward)
		probe_reward_buttons.append(reward)
	probe_pa_supplies = Button.new()
	probe_pa_supplies.name = "probe_pa_supplies"
	probe_pa_supplies.visible = false
	probe_pa_supplies.pressed.connect(_resolve_pa_choice.bind(false))
	add_child(probe_pa_supplies)
	probe_pa_wagon = Button.new()
	probe_pa_wagon.name = "probe_pa_wagon"
	probe_pa_wagon.visible = false
	probe_pa_wagon.pressed.connect(_resolve_pa_choice.bind(true))
	add_child(probe_pa_wagon)
	probe_view_draw = Button.new()
	probe_view_draw.name = "probe_view_draw"
	probe_view_draw.visible = false
	probe_view_draw.pressed.connect(_open_pile_view.bind("draw"))
	add_child(probe_view_draw)
	probe_view_discard = Button.new()
	probe_view_discard.name = "probe_view_discard"
	probe_view_discard.visible = false
	probe_view_discard.pressed.connect(_open_pile_view.bind("discard"))
	add_child(probe_view_discard)
	probe_view_deck = Button.new()
	probe_view_deck.name = "probe_view_deck"
	probe_view_deck.visible = false
	probe_view_deck.pressed.connect(_open_pile_view.bind("deck"))
	add_child(probe_view_deck)
	probe_close_pile = Button.new()
	probe_close_pile.name = "probe_close_pile"
	probe_close_pile.visible = false
	probe_close_pile.pressed.connect(_close_pile_view)
	add_child(probe_close_pile)
	probe_camp_continue = Button.new()
	probe_camp_continue.name = "probe_camp_continue"
	probe_camp_continue.visible = false
	probe_camp_continue.pressed.connect(_on_continue_run_pressed)
	add_child(probe_camp_continue)
	probe_seal_letter = Button.new()
	probe_seal_letter.name = "probe_seal_letter"
	probe_seal_letter.visible = false
	probe_seal_letter.pressed.connect(_seal_letter)
	add_child(probe_seal_letter)
	for i in range(6):
		var shop_probe := Button.new()
		shop_probe.name = "probe_shop_%d" % i
		shop_probe.visible = false
		shop_probe.pressed.connect(_buy_shop_offer.bind(i))
		add_child(shop_probe)
		probe_shop_buttons.append(shop_probe)
	probe_shop_leave = Button.new()
	probe_shop_leave.name = "probe_shop_leave"
	probe_shop_leave.visible = false
	probe_shop_leave.pressed.connect(_leave_shop)
	add_child(probe_shop_leave)

func _draw_one() -> bool:
	if draw_pile.is_empty() and not discard_pile.is_empty():
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		draw_pile.shuffle()
	if draw_pile.is_empty():
		return false
	var drawn: String = draw_pile.pop_back()
	hand.append(drawn)
	_on_family_card_drawn(drawn)
	return true

func _on_family_card_drawn(card_id: String) -> void:
	var member_id := str(CARDS[card_id].get("family", ""))
	if member_id == "" or not party.has(member_id):
		return
	if CARDS[card_id].get("memory", false):
		return
	var member: Dictionary = party[member_id]
	if not member["alive"]:
		return
	if not member["greeted"]:
		member["greeted"] = true
		_show_bark(member_id, "drawn")
	elif morale < 30:
		_show_bark(member_id, "low_morale")
	elif member["condition"] == 2 and randf() < 0.5:
		_show_bark(member_id, "sick")
	elif randf() < 0.25:
		_show_bark(member_id, "drawn")

func _show_bark(member_id: String, category: String) -> void:
	if not party.has(member_id):
		return
	var line: String = BARK_DATA.pick(member_id, category, party[member_id]["name"], int(party[member_id]["bond_level"]))
	if line.is_empty() or bark_panel == null:
		return
	bark_label.text = line
	bark_panel.visible = true
	bark_panel.modulate = Color.WHITE
	if bark_tween != null and bark_tween.is_valid():
		bark_tween.kill()
	bark_tween = create_tween()
	bark_tween.tween_interval(2.5)
	bark_tween.tween_property(bark_panel, "modulate", Color(1, 1, 1, 0), 0.5)
	bark_tween.tween_callback(func() -> void: bark_panel.visible = false)

func _card_display_name(card_id: String) -> String:
	var raw := str(CARDS[card_id]["name"])
	var member_id := str(CARDS[card_id].get("family", ""))
	if member_id != "" and party.has(member_id):
		raw = raw.replace("{name}", party[member_id]["name"])
	return raw

func _card_display_text(card_id: String) -> String:
	var raw := str(CARDS[card_id]["text"])
	var member_id := str(CARDS[card_id].get("family", ""))
	if member_id != "" and party.has(member_id):
		raw = raw.replace("{name}", party[member_id]["name"])
	return raw

# Hurt trims 1 from each helpful number; Sick halves them and drops the extras
# (draws, reveals, threat cuts, travel bonuses). Shown on the card, applied here —
# the text and the effect can never disagree.
func _effective_fx(card_id: String) -> Dictionary:
	var fx: Dictionary = (CARDS[card_id]["fx"] as Dictionary).duplicate()
	var member_id := str(CARDS[card_id].get("family", ""))
	if member_id == "" or not party.has(member_id) or CARDS[card_id].get("memory", false):
		return fx
	var condition := int(party[member_id]["condition"])
	if condition == 0:
		return fx
	var numeric_keys := ["supplies", "morale", "morale_resolve", "pa_choice", "enemy_damage", "block"]
	var rider_keys := ["draw", "reveal", "threat", "travel_bonus", "resolve_low_bonus"]
	if condition == 1:
		for key in numeric_keys:
			if fx.has(key) and int(fx[key]) > 1:
				fx[key] = int(fx[key]) - 1
	else:
		for key in numeric_keys:
			if fx.has(key) and int(fx[key]) > 1:
				fx[key] = maxi(1, int(fx[key]) / 2)
		for key in rider_keys:
			fx.erase(key)
	return fx

func _card_tags(card_id: String) -> Array:
	return CARDS[card_id].get("tags", []) as Array

func _turn_tag_count(tag: String) -> int:
	var count := 0
	for played_id in turn_plays:
		if _card_tags(played_id).has(tag):
			count += 1
	return count

func _card_cost(card_id: String) -> int:
	var cost := int(CARDS[card_id]["cost"])
	var combo: Dictionary = CARDS[card_id].get("combo", {})
	if combo.has("discount_per_play"):
		cost = maxi(0, cost - int(combo["discount_per_play"]) * turn_plays.size())
	return cost

func _reset_turn_context() -> void:
	turn_plays.clear()
	primed.clear()

func _condition_suffix(card_id: String) -> String:
	var member_id := str(CARDS[card_id].get("family", ""))
	if member_id == "" or not party.has(member_id) or CARDS[card_id].get("memory", false):
		return ""
	match int(party[member_id]["condition"]):
		1: return "  ·  HURT: numbers -1"
		2: return "  ·  SICK: halved, no extras"
	return ""

func _draw_until_five() -> void:
	while hand.size() < 5 and _draw_one():
		pass

func _ink_art(path: String) -> String:
	# Color plates break the letterpress look; prefer the pre-baked grayscale
	# "ink" variant when tools/make_cutouts.py produced one for this file.
	var ink_path := "res://assets/art/ink/%s.png" % path.get_file().get_basename()
	return ink_path if ResourceLoader.exists(ink_path) else path

func _plate_art(path: String) -> String:
	# Scene illustrations prefer the feathered plate: edges baked to fade
	# white, so the multiply blend melts them into parchment — no hard
	# rectangle, no white block.
	var plate_path := "res://assets/art/plates/%s.png" % path.get_file().get_basename()
	return plate_path if ResourceLoader.exists(plate_path) else _ink_art(path)

func _make_card_button(card_id: String, index: int) -> PanelContainer:
	var panel := _make_card_face(card_id)
	panel.name = "CardSlot%d" % index
	card_buttons.append(panel)
	return panel

func _make_card_face(card_id: String) -> PanelContainer:
	var card: Dictionary = CARDS[card_id]
	var member_id := str(card.get("family", ""))
	var is_memory: bool = card.get("memory", false)
	var is_family: bool = member_id != "" and not is_memory
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(170, 240)
	if is_memory:
		panel.add_theme_stylebox_override("panel", _make_style(Color("#c9c2b2"), Color("#565046"), 4, 3))
	elif is_family:
		panel.add_theme_stylebox_override("panel", _make_style(Color("#f2e6c2"), Color("#a02818"), 4, 3))
	else:
		panel.add_theme_stylebox_override("panel", _make_style(Color("#ede4c8"), Color("#30251b"), 4, 3))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var hearts := ""
	if is_family and party.has(member_id):
		hearts = "  " + "♥".repeat(int(party[member_id]["bond_level"]))
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	box.add_child(title_row)
	var title_text := "%s%s" % [_card_display_name(card_id).to_upper(), hearts]
	var title := _label(title_text, 12, Color("#221c14"))
	title.add_theme_font_override("font", font_display)
	# Long family names ("HENRY'S STEADY HANDS") drop a size instead of
	# truncating into "HENRY'S STEADY H…".
	title.add_theme_font_size_override("font_size", 16 if title_text.length() <= 13 else 13)
	# One line, trimmed — a wrapped title adds height the 240px face doesn't have.
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var cost_stamp := PanelContainer.new()
	cost_stamp.custom_minimum_size = Vector2(34, 34)
	var badge_style := _make_style(Color("#a02818"), Color("#6b1a10"), 32, 1)
	badge_style.content_margin_left = 6.0
	badge_style.content_margin_right = 6.0
	badge_style.content_margin_top = 2.0
	badge_style.content_margin_bottom = 2.0
	cost_stamp.add_theme_stylebox_override("panel", badge_style)
	var cost_label := _label(str(_card_cost(card_id)), 12, Color("#f6efdc"))
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_override("font", font_display)
	cost_label.add_theme_font_size_override("font_size", 15)
	cost_stamp.add_child(cost_label)
	# No press hits the paper perfectly square — every stamp lands a little off.
	cost_stamp.rotation_degrees = ui_rng.randf_range(-2.0, 2.0)
	title_row.add_child(cost_stamp)
	panel.set_meta("cost_label", cost_label)
	var art_path := str(card.get("art", ""))
	if art_path.is_empty():
		match str(card.get("type", "journey")):
			"supply": art_path = "res://assets/art/general-store.jpg"
			"morale": art_path = "res://assets/art/campfire.jpg"
			"scout": art_path = "res://assets/art/compass.jpg"
			_: art_path = "res://assets/art/wagon-train.jpg"
	# The art window stays parchment even on the dark card — the engraving
	# needs paper under its multiply blend, and the lit plate in a dark
	# frame is the depth the whole theme is built on.
	var art_frame := PanelContainer.new()
	art_frame.add_theme_stylebox_override("panel", _parchment_style(6))
	art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(art_frame)
	var card_art := TextureRect.new()
	card_art.custom_minimum_size = Vector2(0, 80)
	card_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card_art.texture = load(_ink_art(art_path)) as Texture2D
	_print_onto_paper(card_art)
	art_frame.add_child(card_art)
	var full_text := _card_display_text(card_id) + _condition_suffix(card_id)
	var text := _label(full_text, 12, Color("#4b3d2a"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Cap the rules text at three lines so the card stays a true 170x240
	# poker face — an uncapped wrap inflates the container's minimum size
	# and the "card" quietly becomes a tower. Tooltip carries the rest.
	text.max_lines_visible = 3
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(text)
	# Tags as a quiet letterpress footer — what the card IS, for combo-reading.
	var tags: Array = card.get("tags", [])
	if not tags.is_empty():
		var tag_words := PackedStringArray()
		for tag in tags:
			tag_words.append(str(tag).to_upper())
		var tag_line := _label(" · ".join(tag_words), 9, Color("#8d4b32"))
		tag_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tag_line)
	# The visual never touches the mouse — the slot beneath it does.
	_ignore_mouse_tree(panel)
	return panel

func _ignore_mouse_tree(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse_tree(child)

func _on_card_panel_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_pressed(index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_on_discard_pressed(index)

func _rebuild_hand_ui() -> void:
	if hand_container == null:
		return
	# Rebuilding tears cards out from under the cursor — only do it when the
	# hand truly changed. Otherwise refresh the existing panels in place.
	var signature := ""
	for i in hand.size():
		signature += hand[i] + _condition_suffix(hand[i]) + "|"
	if signature == last_hand_signature and card_buttons.size() == hand.size() and not card_buttons.is_empty():
		for i in card_buttons.size():
			if is_instance_valid(card_buttons[i]):
				card_buttons[i].modulate = Color(1, 1, 1, 1) if _can_play(hand[i]) else Color(0.72, 0.7, 0.66, 0.92)
				# Dynamic costs (Dynamite) tick down live as the turn grows.
				if card_buttons[i].has_meta("cost_label"):
					(card_buttons[i].get_meta("cost_label") as Label).text = str(_card_cost(hand[i]))
		return
	last_hand_signature = signature
	for child in hand_container.get_children():
		child.queue_free()
	card_buttons.clear()
	hand_slots.clear()
	discard_buttons.clear()
	for i in hand.size():
		# The slot is the hitbox: it never rotates, never rises, never leaves
		# the cursor. The visual card animates inside it.
		var slot := Control.new()
		slot.name = "HandSlot%d" % i
		slot.custom_minimum_size = Vector2(172, 240)
		slot.size = Vector2(172, 240)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var card_panel := _make_card_button(hand[i], i)
		slot.add_child(card_panel)
		slot.tooltip_text = "%s\n%s" % [_card_display_name(hand[i]), _card_display_text(hand[i]) + _condition_suffix(hand[i])]
		hand_container.add_child(slot)
		hand_slots.append(slot)
		slot.gui_input.connect(_on_card_panel_input.bind(i))
		slot.mouse_entered.connect(_on_hand_card_hover.bind(card_panel, true))
		slot.mouse_exited.connect(_on_hand_card_hover.bind(card_panel, false))
		# Reaching for a peeking card raises the whole drawer.
		slot.mouse_entered.connect(_on_hand_area_entered)
		slot.mouse_exited.connect(_on_hand_area_exited)
		# Cards can also be picked up and dropped onto the table.
		slot.set_drag_forwarding(_slot_drag_data.bind(slot, i), Callable(), Callable())
		card_panel.modulate = Color(1, 1, 1, 1) if _can_play(hand[i]) else Color(0.72, 0.7, 0.66, 0.92)
	call_deferred("_layout_hand")

# Balatro's CardArea:align_cards, ported: linear rotation across the fan,
# abs() droop for the arch, and a slow sine wobble so the hand breathes.
func _layout_hand() -> void:
	if hand_container == null:
		return
	var count := card_buttons.size()
	if count == 0 or hand_slots.size() != count:
		return
	var area_w: float = hand_container.size.x
	var card_w := 172.0
	var spacing: float = minf(card_w * 0.72, (area_w - card_w) / maxf(count - 1, 1.0)) if count > 1 else 0.0
	var total: float = spacing * (count - 1) + card_w
	var start_x: float = (area_w - total) * 0.5
	var center := (count - 1) * 0.5
	for k in count:
		var slot: Control = hand_slots[k]
		var card: Control = card_buttons[k]
		if not is_instance_valid(card) or not is_instance_valid(slot):
			continue
		var rot_deg: float = rad_to_deg(0.25 * (float(k) - center) / maxf(float(count), 1.0))
		var droop: float = pow(absf(float(k) - center), 1.5) * 7.0
		# Fan geometry lands on the SLOT; the tilt and breath live on the visual.
		slot.position = Vector2(start_x + k * spacing, droop)
		slot.z_index = k
		card.position = Vector2.ZERO
		card.rotation_degrees = rot_deg
		card.pivot_offset = Vector2(card_w * 0.5, 238.0)
		card.set_meta("rest_r", rot_deg)
		card.set_meta("rest_z", k)
		_start_hand_wobble(card, rot_deg, k)

func _start_hand_wobble(card: Control, rest_r: float, k: int) -> void:
	if card.has_meta("wob"):
		var old: Tween = card.get_meta("wob")
		if old != null and old.is_valid():
			old.kill()
	var wobble := create_tween().set_loops()
	var beat := 1.7 + float(k) * 0.19
	wobble.tween_property(card, "rotation_degrees", rest_r + 0.7, beat).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(card, "rotation_degrees", rest_r - 0.7, beat).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	card.set_meta("wob", wobble)
	if hand.is_empty():
		hand_container.add_child(_label("No cards in hand. The next leg draws a fresh hand.", 12, Color("#6b5b41")))

func _can_play(card_id: String) -> bool:
	if game_over or victory or reward_pending or pa_choice_active or letter_pending or shop_open:
		return false
	var affordable := grit >= _card_cost(card_id)
	if encounter_active:
		# Family rides into danger too: their cards stay playable in a fight.
		var is_family := str(CARDS[card_id].get("family", "")) != ""
		return (CARDS[card_id]["type"] == "combat" or is_family) and affordable
	return not event_active and affordable

func _animate_card_play() -> void:
	feedback_count += 1
	if card_status == null:
		return
	var tween := create_tween()
	tween.tween_property(card_status, "modulate", Color("#f6e0a2"), 0.10)
	tween.tween_property(card_status, "modulate", Color.WHITE, 0.28)

func _animate_route_transition() -> void:
	route_transition_count += 1
	feedback_count += 1
	if route_note == null:
		return
	route_note.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.tween_property(route_note, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_card_pressed(index: int) -> void:
	if index < 0 or index >= hand.size():
		return
	var card_id := hand[index]
	# CARD-DRIVEN EVENTS: during a trail event there are no choice buttons —
	# playing a card of the asked-for type IS the choice. The card is paid
	# into the event (no grit asked), the branch resolves on the spot.
	if event_active and not encounter_active and not game_over and not victory \
			and current_event_index >= 0 and current_event_index < EVENTS.size():
		var event: Dictionary = EVENTS[current_event_index]
		if str(CARDS[card_id].get("type", "")) == str(event["card_type"]):
			hand.remove_at(index)
			discard_pile.append(card_id)
			card_play_count += 1
			_animate_card_play()
			var payer := str(CARDS[card_id].get("family", ""))
			if payer != "" and not CARDS[card_id].get("memory", false):
				_register_bond_play(payer)
			_apply_effect_dictionary(event["a_fx"])
			_play_sfx("stamp")
			_float_combo("THE CARD ANSWERS")
			_resolve_event("CARD PLAYED  ·  " + str(event["ad"]))
			_sync_and_refresh()
			return
	if not _can_play(card_id):
		return
	var cost := _card_cost(card_id)
	grit -= cost
	if encounter_active and not powder_horn_spent and _has_keepsake("powder_horn") and CARDS[card_id]["type"] == "combat":
		powder_horn_spent = true
		grit += cost
		_float_number("FREE", Color("#1f5c33"), grit_value)
	hand.remove_at(index)
	pending_leave_confirm = false
	if CARDS[card_id].get("exhaust", false):
		exhausted.append(card_id)
	else:
		discard_pile.append(card_id)
	card_play_count += 1
	_play_sfx("card")
	_animate_card_play()
	var member_id := str(CARDS[card_id].get("family", ""))
	if member_id != "" and not CARDS[card_id].get("memory", false):
		_register_bond_play(member_id)
	_apply_card(card_id)
	# The turn remembers this play only AFTER it resolves, so "per GUN fired
	# this turn" never counts the card itself. Priming arms the next play.
	var combo: Dictionary = CARDS[card_id].get("combo", {})
	if combo.has("prime_tag"):
		primed[str(combo["prime_tag"])] = int(combo.get("mult", 2))
	turn_plays.append(card_id)
	if CARDS[card_id].get("memory", false):
		_show_bark(member_id, "memory")
	if encounter_active and not pa_choice_active and encounter_health <= 0:
		_resolve_encounter()
	card_status.text = "%s played. %s" % [_card_display_name(card_id), "The enemy waits for the BRACE." if encounter_active else "Discarded after resolving; Grit now %d." % grit]
	_sync_and_refresh()

func _register_bond_play(member_id: String) -> void:
	var member: Dictionary = party[member_id]
	if not member["alive"]:
		return
	member["bond_plays"] = int(member["bond_plays"]) + 1
	var thresholds: Array = PARTY_DATA.BOND_THRESHOLDS
	var new_level := int(member["bond_level"])
	while new_level < thresholds.size() and int(member["bond_plays"]) >= int(thresholds[new_level]):
		new_level += 1
	if new_level == int(member["bond_level"]):
		return
	member["bond_level"] = new_level
	var upgraded := PARTY_DATA.card_for_bond(member_id, new_level)
	_swap_family_card(member_id, upgraded)
	_show_bark(member_id, "drawn")
	if card_status != null:
		card_status.text = "BOND DEEPENS  ·  %s reaches bond %d — their card grows stronger." % [member["name"], new_level]

# Replace every copy of a member's card (any tier) across all piles.
func _swap_family_card(member_id: String, new_id: String) -> void:
	var old_ids: Array[String] = []
	for card_id in CARDS.keys():
		if str(CARDS[card_id].get("family", "")) == member_id and card_id != new_id:
			old_ids.append(card_id)
	for pile in [deck_ids, draw_pile, hand, discard_pile, exhausted]:
		for i in pile.size():
			if old_ids.has(pile[i]):
				pile[i] = new_id
	party[member_id]["card_id"] = new_id

func _on_discard_pressed(index: int) -> void:
	if index < 0 or index >= hand.size() or event_active or reward_pending or game_over or victory:
		return
	var card_id := hand[index]
	hand.remove_at(index)
	discard_pile.append(card_id)
	card_status.text = "%s discarded without a cost." % CARDS[card_id]["name"]
	_sync_and_refresh()

func _apply_card(card_id: String) -> void:
	var effects := _effective_fx(card_id)
	var combo: Dictionary = CARDS[card_id].get("combo", {})
	var if_tag_met: bool = combo.has("if_tag") and _turn_tag_count(str(combo["if_tag"])) > 0
	var per_tag_count: int = _turn_tag_count(str(combo["per_tag"])) if combo.has("per_tag") else 0
	for key in effects.keys():
		var amount := int(effects[key])
		match key:
			"supplies":
				if amount > 0 and _has_keepsake("iron_skillet") and str(CARDS[card_id].get("type", "")) == "supply":
					amount += 1
				if amount > 0 and per_tag_count > 0 and combo.has("bonus_supplies"):
					var extra: int = per_tag_count * int(combo["bonus_supplies"])
					amount += extra
					_float_combo("COMBO +%d" % extra)
				supplies = max(0, supplies + amount)
				_float_number(("+%d" if amount >= 0 else "%d") % amount, Color("#1f5c33") if amount >= 0 else Color("#a02818"), supply_value)
			"morale":
				if _has_keepsake("daguerreotype") and CARDS[card_id].get("memory", false):
					amount += 4
				if amount > 0 and if_tag_met and combo.has("bonus_morale"):
					amount += int(combo["bonus_morale"])
					_float_combo("COMBO +%d" % int(combo["bonus_morale"]))
				morale = clamp(morale + amount, 0, 100)
				_float_number(("+%d" if amount >= 0 else "%d") % amount, Color("#1f5c33") if amount >= 0 else Color("#a02818"), morale_value)
			"morale_resolve":
				var gained := amount
				if morale < 30:
					gained += int(effects.get("resolve_low_bonus", 0))
				morale = clamp(morale + gained, 0, 100)
			"resolve_low_bonus":
				pass  # consumed by morale_resolve above
			"wagon":
				wagon_health = clamp(wagon_health + amount, 0, 100)
			"draw":
				if if_tag_met and combo.has("bonus_draw"):
					amount += int(combo["bonus_draw"])
					_float_combo("COMBO DRAW +%d" % int(combo["bonus_draw"]))
				_draw_cards(amount)
			"grit":
				grit = clamp(grit + amount, 0, 3)
			"days":
				day = max(1, day + amount)
			"reveal":
				event_revealed = true
			"travel_bonus":
				travel_bonus += amount
			"cure":
				_apply_cure()
			"pa_choice":
				_open_pa_choice(card_id, amount)
			"enemy_damage":
				if encounter_active:
					_play_sfx("gunshot" if _card_tags(card_id).has("gun") else "hit")
					var dealt := amount
					if per_tag_count > 0 and combo.has("bonus_damage"):
						var extra: int = per_tag_count * int(combo["bonus_damage"])
						dealt += extra
						_float_combo("COMBO +%d" % extra)
					# A primed multiplier (Lasso's "next GUN hits double") fires
					# once, on the first matching tag, then disarms.
					for tag in _card_tags(card_id):
						if primed.has(str(tag)):
							dealt *= int(primed[str(tag)])
							primed.erase(str(tag))
							_float_combo("×2  COMBO")
							break
					_damage_encounter(dealt)
			"threat":
				if encounter_active:
					encounter_threat = maxi(0, encounter_threat + amount)
			"block":
				if encounter_active:
					if if_tag_met and combo.has("bonus_block"):
						amount += int(combo["bonus_block"])
						_float_combo("COMBO BLOCK +%d" % int(combo["bonus_block"]))
					encounter_block += amount
	if morale <= 0:
		_end_run(false)

func _apply_cure() -> void:
	var worst_id := ""
	var worst_condition := 0
	for member_id in PARTY_DATA.MEMBER_ORDER:
		var member: Dictionary = party[member_id]
		if member["alive"] and int(member["condition"]) > worst_condition:
			worst_condition = int(member["condition"])
			worst_id = member_id
	if worst_id == "":
		card_status.text = "The medicine waits in the chest — everyone is well."
		return
	party[worst_id]["condition"] = 0
	party[worst_id]["legs_sick"] = 0
	party[worst_id]["disease"] = ""
	if _has_keepsake("worn_stethoscope"):
		morale = clamp(morale + 4, 0, 100)
		_float_number("+4", Color("#1f5c33"), morale_value)
	card_status.text = "%s is cured and back on their feet." % party[worst_id]["name"]
	_show_bark(worst_id, "drawn")

func _open_pa_choice(card_id: String, amount: int) -> void:
	pa_choice_active = true
	pa_choice_amount = amount
	if pa_panel != null:
		pa_title_label.text = "%s WEIGHS THE LEDGER" % str(party["pa"]["name"]).to_upper()
		pa_supplies_button.text = "GAIN %d SUPPLIES" % amount
		pa_wagon_button.text = "REPAIR THE WAGON BY %d  (now %d / 100)" % [amount, wagon_health]
		pa_panel.visible = true

func _resolve_pa_choice(repair: bool) -> void:
	if not pa_choice_active:
		return
	pa_choice_active = false
	if pa_panel != null:
		pa_panel.visible = false
	if repair:
		wagon_health = clamp(wagon_health + pa_choice_amount, 0, 100)
		card_status.text = "%s patches the wagon: +%d condition." % [party["pa"]["name"], pa_choice_amount]
	else:
		supplies = max(0, supplies + pa_choice_amount)
		card_status.text = "%s squares the stores: +%d supplies." % [party["pa"]["name"], pa_choice_amount]
	if encounter_active and encounter_health <= 0:
		_resolve_encounter()
	_sync_and_refresh()

func _draw_cards(amount: int) -> void:
	for i in range(max(0, amount)):
		if not _draw_one():
			break

func _find_card_in_hand(card_type: String) -> int:
	# Prefer spending an ordinary card; the family only steps up when nothing else fits.
	var family_match := -1
	for i in hand.size():
		if CARDS[hand[i]]["type"] == card_type:
			if str(CARDS[hand[i]].get("family", "")) == "":
				return i
			if family_match < 0:
				family_match = i
	return family_match

func _discard_required_card(card_type: String) -> bool:
	var index := _find_card_in_hand(card_type)
	if index < 0:
		return false
	discard_pile.append(hand[index])
	hand.remove_at(index)
	return true

func _sync_and_refresh() -> void:
	if supplies <= 0 and not encounter_active:
		morale = max(0, morale - 1)
	if morale <= 0:
		_end_run(false)
	call_deferred("_refresh_ui")

func _ensure_combat_card_in_hand() -> void:
	var combat_count := 0
	for card_id in hand:
		if CARDS[card_id]["type"] == "combat":
			combat_count += 1
	while combat_count < 2:
		var source_id := ""
		for i in draw_pile.size():
			if CARDS[draw_pile[i]]["type"] == "combat":
				source_id = draw_pile[i]
				draw_pile.remove_at(i)
				break
		if source_id == "":
			for i in discard_pile.size():
				if CARDS[discard_pile[i]]["type"] == "combat":
					source_id = discard_pile[i]
					discard_pile.remove_at(i)
					break
		if source_id == "":
			break
		if hand.size() >= 5:
			# Evict a non-combat card only — evicting combat undoes the append and loops forever.
			# Prefer ordinary cards; the family stays in hand when possible.
			var removed_index := -1
			for i in range(hand.size() - 1, -1, -1):
				if CARDS[hand[i]]["type"] != "combat" and str(CARDS[hand[i]].get("family", "")) == "":
					removed_index = i
					break
			if removed_index < 0:
				for i in range(hand.size() - 1, -1, -1):
					if CARDS[hand[i]]["type"] != "combat":
						removed_index = i
						break
			if removed_index < 0:
				discard_pile.append(source_id)
				break
			discard_pile.append(hand[removed_index])
			hand.remove_at(removed_index)
		hand.append(source_id)
		combat_count += 1

func _stage_show_enemy(art_path: String) -> void:
	if combat_stage == null:
		return
	enemy_plate.texture = load(art_path) as Texture2D
	# Feet on the painted ground, honest sizes scaled for the big window:
	# the grizzly and the mounted man loom; everything else is animal-sized.
	const ENEMY_STAGE_HEIGHTS := {
		"wolf": 150.0, "grizzly": 250.0, "rattlesnake": 100.0,
		"mountain-lion": 140.0, "road-agent": 200.0, "highwayman": 250.0
	}
	if enemy_plate.texture != null:
		var stem := art_path.get_file().get_basename()
		var target_h: float = ENEMY_STAGE_HEIGHTS.get(stem, 190.0)
		var tex_size := (enemy_plate.texture as Texture2D).get_size()
		var draw_w := tex_size.x * (target_h / tex_size.y)
		var side_slack := maxf(0.0, (enemy_actor.size.x - draw_w) * 0.5)
		enemy_plate.offset_top = enemy_actor.size.y - target_h
		enemy_plate.offset_bottom = 0.0
		enemy_plate.offset_left = side_slack
		enemy_plate.offset_right = -side_slack
		# Readouts stack over the creature's head: bar, number, intent.
		var bar_y := enemy_actor.size.y - target_h - 24.0
		if stage_hp_bg != null:
			stage_hp_bg.position.y = bar_y
			stage_hp_fill.position.y = bar_y
			stage_hp_label.position.y = bar_y - 5.0
		if stage_intent_banner != null:
			stage_intent_banner.position.y = bar_y - 46.0
	enemy_actor.modulate = Color.WHITE
	enemy_actor.rotation_degrees = 0.0
	enemy_actor.pivot_offset = Vector2(190, 320)
	wagon_actor.pivot_offset = Vector2(215, 195)
	# Shooting-gallery pop-up: the target rises from below the boards.
	enemy_actor.position.y += 90.0
	var rise := create_tween()
	rise.tween_property(enemy_actor, "position:y", enemy_actor.position.y - 90.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.finished.connect(_stage_idle_loops, CONNECT_ONE_SHOT)

func _stage_idle_loops() -> void:
	if combat_stage == null or not encounter_active:
		return
	var bob := create_tween().set_loops()
	bob.tween_property(enemy_actor, "rotation_degrees", 1.2, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(enemy_actor, "rotation_degrees", -1.2, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	enemy_actor.set_meta("bob", bob)
	var rock := create_tween().set_loops()
	rock.tween_property(wagon_actor, "rotation_degrees", 0.8, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rock.tween_property(wagon_actor, "rotation_degrees", -0.8, 1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wagon_actor.set_meta("rock", rock)

func _stage_stop_loops() -> void:
	for actor in [enemy_actor, wagon_actor]:
		if actor == null:
			continue
		for key in ["bob", "rock"]:
			if actor.has_meta(key):
				var loop_tween: Tween = actor.get_meta(key)
				if loop_tween != null and loop_tween.is_valid():
					loop_tween.kill()
				actor.remove_meta(key)

func _stage_player_strike(amount: int) -> void:
	if combat_stage == null or not combat_stage.visible:
		return
	# An ink slash across the plate.
	var slash := ColorRect.new()
	slash.color = Color("#a02818")
	slash.size = Vector2(260, 5)
	slash.rotation_degrees = -24.0
	slash.position = Vector2(30, 150)
	slash.z_index = 30
	enemy_actor.add_child(slash)
	var slash_fade := create_tween()
	slash_fade.tween_property(slash, "modulate:a", 0.0, 0.22)
	slash_fade.tween_callback(slash.queue_free)
	# Recoil with a squash punch. No modulate flash: tinting a multiply-blend
	# cutout re-colors its white feather margins and the rectangle reappears.
	var recoil := create_tween()
	recoil.set_parallel(true)
	recoil.tween_property(enemy_actor, "position:x", enemy_actor.position.x + 26.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recoil.tween_property(enemy_actor, "scale", Vector2(1.04, 0.93), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recoil.chain().tween_property(enemy_actor, "position:x", enemy_actor.position.x, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	recoil.parallel().tween_property(enemy_actor, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_float_number("-%d" % amount, Color("#a02818"), enemy_actor)

func _stage_enemy_lunge() -> void:
	if combat_stage == null or not combat_stage.visible:
		return
	_play_sfx("hit")
	var lunge := create_tween()
	lunge.tween_property(enemy_actor, "position:x", enemy_actor.position.x - 90.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lunge.tween_property(enemy_actor, "position:x", enemy_actor.position.x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shudder := create_tween()
	shudder.tween_interval(0.14)
	shudder.tween_property(wagon_actor, "rotation_degrees", -4.0, 0.06)
	shudder.tween_property(wagon_actor, "rotation_degrees", 3.0, 0.08)
	shudder.tween_property(wagon_actor, "rotation_degrees", 0.0, 0.12)

func _stage_enemy_death() -> void:
	if combat_stage == null or not combat_stage.visible:
		return
	stage_hold = true
	_stage_stop_loops()
	var fall := create_tween()
	fall.set_parallel(true)
	fall.tween_property(enemy_actor, "rotation_degrees", 82.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(enemy_actor, "position:y", enemy_actor.position.y + 46.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(enemy_actor, "modulate:a", 0.0, 0.7)
	fall.chain().tween_callback(func() -> void:
		stage_hold = false
		enemy_actor.rotation_degrees = 0.0
		enemy_actor.position.y -= 46.0
		enemy_actor.modulate = Color.WHITE
		_refresh_ui())

func _stage_update_readouts() -> void:
	if combat_stage == null or not combat_stage.visible or encounter_max_health <= 0:
		return
	stage_hp_fill.size.x = 220.0 * clampf(float(encounter_health) / float(encounter_max_health), 0.0, 1.0)
	stage_hp_label.text = "%d / %d" % [encounter_health, encounter_max_health]
	var encounter: Dictionary = ENCOUNTERS[encounter_index]
	var target_word := "SUPPLIES" if str(encounter.get("hits", "wagon")) == "supplies" else ("MORALE" if str(encounter.get("hits", "wagon")) == "morale" else "WAGON")
	stage_intent_label.text = "⚔ %d → %s" % [maxi(0, encounter_threat - encounter_block), target_word]
	stage_block_label.text = "BLOCK %d" % encounter_block if encounter_block > 0 else ""

func _start_encounter() -> void:
	if game_over or victory:
		return
	# Danger grows with the miles: early legs draw from the shallow end of the pool.
	var max_health := 15 if completed_legs <= 4 else (22 if completed_legs <= 8 else 99)
	var pool: Array[int] = []
	for i in ENCOUNTERS.size():
		if int(ENCOUNTERS[i]["health"]) <= max_health and i != encounter_index:
			pool.append(i)
	if not pool.is_empty():
		encounter_index = pool[randi() % pool.size()]
	var encounter: Dictionary = ENCOUNTERS[encounter_index]
	encounter_health = int(encounter["health"])
	if run_modifiers.get("green_country", false):
		encounter_health = maxi(1, int(encounter_health * 0.8))
	if trailblazer >= 8:
		encounter_health = int(encounter_health * 1.25)
	encounter_max_health = encounter_health
	encounter_threat = int(encounter["damage"]) + _threat_bonus()
	encounter_block = 0
	encounter_turn = 1
	encounter_resolved = false
	powder_horn_spent = false
	encounter_active = true
	event_active = false
	_reset_turn_context()
	intent_pulse_active = false
	if intent_pulse_tween != null and intent_pulse_tween.is_valid():
		intent_pulse_tween.kill()
	_ensure_combat_card_in_hand()
	# The country changes as the trail runs west: prairie, then the Rockies,
	# then the Snake, then the cold pine dark of the Blue Mountains.
	if battle_backdrop != null:
		var region := "prairie"
		if route_index >= 10:
			region = "forest"
		elif route_index >= 8:
			region = "river"
		elif route_index >= 5:
			region = "mountains"
		var region_path := "res://assets/art/scene/battle-%s.png" % region
		if ResourceLoader.exists(region_path):
			battle_backdrop.texture = load(region_path) as Texture2D
	# Beasts announce themselves; men let the road go quiet.
	var enemy_stem := str(encounter["art"]).get_file().get_basename()
	if enemy_stem in ["wolf", "grizzly", "mountain-lion", "rattlesnake"]:
		_play_sfx("growl")
	_stage_show_enemy(str(encounter["art"]))
	_refresh_ui()

func _animate_encounter_feedback(damage: bool) -> void:
	if encounter_art == null:
		return
	var flash_color := Color("#ff8b6b") if damage else Color("#f6e0a2")
	var feedback := create_tween()
	feedback.tween_property(encounter_art, "modulate", flash_color, 0.08)
	feedback.tween_property(encounter_art, "modulate", Color.WHITE, 0.18)
	feedback.parallel().tween_property(encounter_art, "scale", Vector2(1.08, 1.08), 0.08)
	feedback.tween_property(encounter_art, "scale", Vector2.ONE, 0.22)

func _damage_encounter(amount: int) -> void:
	encounter_health = maxi(0, encounter_health - amount)
	encounter_threat = maxi(0, encounter_threat - 1)
	_stage_player_strike(amount)
	_stage_update_readouts()

func _enemy_turn() -> void:
	if not encounter_active:
		return
	var encounter: Dictionary = ENCOUNTERS[encounter_index]
	_stage_enemy_lunge()
	# The disclosed intent number IS the hit — threat cuts and escalation both count.
	var incoming := encounter_threat
	var blocked := mini(encounter_block, incoming)
	encounter_block -= blocked
	incoming -= blocked
	if incoming > 0:
		match str(encounter.get("hits", "wagon")):
			"supplies":
				supplies = maxi(0, supplies - incoming)
				_float_number("-%d" % incoming, Color("#a02818"), supply_value)
				if supplies == 0:
					morale = maxi(0, morale - 4)
			"morale":
				morale = clamp(morale - incoming, 0, 100)
				_float_number("-%d" % incoming, Color("#a02818"), morale_value)
			_:
				var wagon_hit := incoming
				if _has_keepsake("spare_axle"):
					wagon_hit = maxi(0, wagon_hit - 2)
				wagon_health = maxi(0, wagon_health - wagon_hit)
				injuries += 1
				morale = clamp(morale - maxi(1, int(incoming / 2.0)), 0, 100)
				if wagon_health == 0:
					morale = 0
		if incoming >= 8:
			_injure_random_member()
		_animate_encounter_feedback(true)
	encounter_turn += 1
	encounter_threat = int(encounter["damage"]) + _threat_bonus() + encounter_turn - 1
	if morale <= 0:
		death_cause = "the %s finished what the miles began" % str(encounter["name"]).to_lower()
		_end_run(false)
	call_deferred("_refresh_ui")

# A landed hit of 8+ hurts someone in the family (disclosed in the stakes line).
func _injure_random_member() -> void:
	var candidates: Array[String] = []
	for member_id in PARTY_DATA.MEMBER_ORDER:
		if party[member_id]["alive"] and int(party[member_id]["condition"]) < 2:
			candidates.append(member_id)
	if candidates.is_empty():
		return
	var member_id: String = candidates[randi() % candidates.size()]
	var member: Dictionary = party[member_id]
	member["condition"] = int(member["condition"]) + 1
	if int(member["condition"]) == 2:
		member["legs_sick"] = 0
		member["disease"] = "camp fever"
		_show_bark(member_id, "sick")
		if outcome_label != null:
			outcome_label.text = "%s HAS CAMP FEVER  ·  cure within 2 legs (medicine or a slow day) or lose them." % str(member["name"]).to_upper()
	else:
		_show_bark(member_id, "sick")
		if outcome_label != null:
			outcome_label.text = "%s IS HURT  ·  their card weakens until they heal." % str(member["name"]).to_upper()

func _resolve_encounter() -> void:
	if encounter_resolved:
		return
	encounter_resolved = true
	encounter_active = false
	_stage_enemy_death()
	var encounter: Dictionary = ENCOUNTERS[encounter_index]
	supplies += int(encounter["reward"])
	money += int(encounter["reward"]) + (3 if _has_keepsake("lucky_arrowhead") else 0)
	morale = clamp(morale + 4, 0, 100)
	outcome_label.text = "THREAT BROKEN  ·  %s reward: supplies +%d, $%d, morale +4" % [encounter["name"], int(encounter["reward"]), int(encounter["reward"])]
	# Milestone fights (legs 6 and 12) leave a keepsake in the wreckage.
	if completed_legs == 6 or completed_legs == 12:
		var unowned: Array = TRINKETS.KEEPSAKE_POOL.filter(func(k): return not keepsakes.has(k))
		if not unowned.is_empty():
			_gain_keepsake(unowned[randi() % unowned.size()])
			outcome_label.text += "\n" + card_status.text
	elif randf() < 0.3:
		var found: String = TRINKETS.TONIC_POOL[randi() % TRINKETS.TONIC_POOL.size()]
		if _gain_tonic(found):
			outcome_label.text += "  ·  found a tonic: %s" % TRINKETS.TONICS[found]["name"]
	if completed_legs == 0:
		completed_legs = 1
		route_index = 1
	if route_index > 0 and not game_over:
		_prepare_reward()
	else:
		_start_leg()
	call_deferred("_refresh_ui")

func _return_to_camp() -> void:
	if camp_overlay == null:
		return
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_initialize_run()
	run_mode = "camp"
	camp_overlay.visible = true
	if camp_continue_button != null:
		camp_continue_button.visible = false
	if title_continue_button != null:
		title_continue_button.visible = false
	if return_to_camp_button != null:
		return_to_camp_button.visible = false
	# Coming back to camp always lands on the fire, not the paperwork.
	_back_to_title()
	_refresh_ui()

func _on_route_selected(index: int) -> void:
	if run_mode != "map" or map_canvas == null or route_note == null:
		return
	if index <= route_index:
		route_note.text = "%s  ·  already charted" % ROUTE_STOPS[route_index]
	elif index <= min(route_index + 2, ROUTE_STOPS.size() - 1):
		route_note.text = "CHARTED FORK  ·  %s  ·  Continue to commit the next leg" % ROUTE_STOPS[index]
		card_status.text = "Route selected: %s. The next journey action follows this fork." % ROUTE_STOPS[index]
	else:
		route_note.text = "Distant landmark  ·  reach the nearer fork before scouting farther west"
	_refresh_ui()

func _has_playable_card() -> bool:
	for card_id in hand:
		if _can_play(card_id):
			return true
	return false

func _on_continue_pressed() -> void:
	if event_active or reward_pending or game_over or victory or run_mode != "map" or pa_choice_active or letter_pending or shop_open:
		return
	if encounter_active:
		# BRACE: end the turn. The hand is discarded, the disclosed hit lands,
		# then Grit refills and five fresh cards come up — the deck keeps cycling.
		while not hand.is_empty():
			discard_pile.append(hand.pop_back())
		_enemy_turn()
		if game_over or morale <= 0:
			return
		grit = 3
		_reset_turn_context()
		_draw_until_five()
		if _has_keepsake("hymnal"):
			morale = clamp(morale + 2, 0, 100)
			_float_number("+2", Color("#1f5c33"), morale_value)
		if card_status != null:
			card_status.text = "The party braces and regroups: new hand, Grit back to 3."
		_sync_and_refresh()
		return
	# Misclick protection: leaving Grit on the table with a playable card asks once.
	if not pending_leave_confirm and grit > 0 and _has_playable_card():
		pending_leave_confirm = true
		continue_button.text = "LEAVE %d GRIT UNSPENT?  ·  PRESS AGAIN" % grit
		return
	pending_leave_confirm = false
	_depart()

func _alt_road_for_leg() -> Dictionary:
	# A private generator keeps road variety from disturbing the run's main
	# dice — the same trail seed always offers the same forks.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run_seed) * 131 + completed_legs
	return ALT_ROADS[rng.randi() % ALT_ROADS.size()]

func _on_road_selected(option: int) -> void:
	if event_active or reward_pending or game_over or victory or run_mode != "map" or pa_choice_active or letter_pending or shop_open or encounter_active:
		return
	var road: Dictionary = MAIN_ROAD if option == 0 else _alt_road_for_leg()
	if road.has("toll") and money < int(road["toll"]):
		card_status.text = "The toll keeper wants $%d — the purse holds $%d." % [int(road["toll"]), money]
		return
	if not pending_leave_confirm and grit > 0 and _has_playable_card():
		pending_leave_confirm = true
		continue_button.text = "LEAVE %d GRIT UNSPENT?  ·  PRESS AGAIN" % grit
		card_status.text = "Grit still in hand — click the road again to ride anyway."
		return
	pending_leave_confirm = false
	pending_road = option
	_depart()

func _depart() -> void:
	var road: Dictionary = MAIN_ROAD if pending_road == 0 else _alt_road_for_leg()
	pending_road = 0
	_reset_turn_context()
	_play_sfx("roll")
	if road.has("toll"):
		money -= int(road["toll"])
		_float_number("-$%d" % int(road["toll"]), Color("#a02818"), money_value)
	var travel_days := maxi(2, randi_range(3, 5) + int(road.get("days", 0)))
	var saved_days := 0
	if _has_keepsake("ox_shoe") and (completed_legs + 1) % 4 == 0 and travel_days > 1:
		travel_days -= 1
		saved_days += 1
	if travel_bonus > 0:
		saved_days = mini(travel_bonus, travel_days - 1)
		travel_days -= saved_days
		travel_bonus -= saved_days
	day += travel_days
	var drain_per_day := 1 if run_modifiers.get("steady_oxen", false) else 2
	if trailblazer >= 1:
		drain_per_day += 1
	supplies -= drain_per_day * travel_days
	if road.has("supplies"):
		supplies += int(road["supplies"])
	morale = clamp(morale - travel_days, 0, 100)  # trail fatigue: 1 morale per day on the road
	if supplies <= 0:
		morale = max(0, morale - 8)
	if morale <= 0:
		death_cause = "hunger walked beside the wagon until the wagon stopped"
		_end_run(false)
		return
	var road_note := ""
	if str(road["id"]) != "main":
		road_note = "  ·  by the %s" % str(road["name"]).to_lower()
	if road.has("sick_risk"):
		var risk := float(road["sick_risk"])
		if trailblazer >= 2:
			risk *= 2.0
		if _has_keepsake("rabbits_foot"):
			risk *= 0.5
		if randf() < risk:
			var healthy: Array[String] = []
			for member_id in PARTY_DATA.MEMBER_ORDER:
				if party[member_id]["alive"] and int(party[member_id]["condition"]) < 2:
					healthy.append(member_id)
			if not healthy.is_empty():
				var member_id: String = healthy[randi() % healthy.size()]
				party[member_id]["condition"] = 2
				party[member_id]["legs_sick"] = 0
				party[member_id]["disease"] = "dysentery"
				_show_bark(member_id, "sick")
				road_note += "  ·  %s HAS DYSENTERY from the river water" % str(party[member_id]["name"]).to_upper()
	completed_legs += 1
	route_index = min(completed_legs, ROUTE_STOPS.size() - 1)
	var ox_note := "  ·  %s saved %d day%s" % [party["ox"]["name"], saved_days, "" if saved_days == 1 else "s"] if saved_days > 0 else ""
	outcome_label.text = "WAGON MOVES WEST  ·  %d travel days  ·  supplies -%d  ·  morale -%d%s%s" % [travel_days, drain_per_day * travel_days, travel_days, ox_note, road_note]
	_animate_route_transition()
	# Rhythm of the trail: every third leg is dangerous (every 2nd in Outlaw
	# Country) — unless the chosen road promises otherwise, or invites worse.
	var dangerous := completed_legs % _danger_cadence() == 0
	if road.get("safe", false):
		if dangerous:
			outcome_label.text += "  ·  the high trail skirts the danger"
		dangerous = false
	elif road.has("danger") and not dangerous:
		dangerous = randf() < float(road["danger"])
	if dangerous:
		_start_encounter()
	else:
		_begin_event()

func _danger_cadence() -> int:
	return 2 if trailblazer >= 3 else 3

func _threat_bonus() -> int:
	return 2 if trailblazer >= 5 else 0

func _begin_event() -> void:
	if game_over or victory:
		return
	current_event_index = event_order[event_cursor % event_order.size()]
	event_cursor += 1
	event_active = true
	encounter_active = false
	event_revealed = false
	event_hint_member = ""
	event_hint_option = ""
	# Sometimes one of the family leans into the choice. Personality, not an answer key.
	if randf() < 0.4:
		var living: Array[String] = []
		for member_id in PARTY_DATA.MEMBER_ORDER:
			if party[member_id]["alive"]:
				living.append(member_id)
		if not living.is_empty():
			event_hint_member = living[randi() % living.size()]
			event_hint_option = str(PARTY_DATA.MEMBERS[event_hint_member]["hint"])
			_show_bark(event_hint_member, "event_hint")
	_refresh_ui()

func _on_choice_a() -> void:
	if not event_active:
		return
	var event: Dictionary = EVENTS[current_event_index]
	if _find_card_in_hand(event["card_type"]) < 0:
		event_hint.text = "[Requires: %s] Keep this option visible and bring the right card next leg." % event["card_label"]
		return
	_discard_required_card(event["card_type"])
	_apply_effect_dictionary(event["a_fx"])
	_resolve_event("CARD BRANCH  ·  " + event["ad"])

func _on_choice_b() -> void:
	if not event_active:
		return
	var event: Dictionary = EVENTS[current_event_index]
	_apply_effect_dictionary({"days": 1})
	if event.has("b_fx"):
		_apply_effect_dictionary(event["b_fx"])
	var message := "FREE LEAVE  ·  " + str(event["bd"])
	# The slow day lets one hurt or sick member recover a step.
	var rested := _rest_one_member()
	if rested != "":
		message += "  ·  %s recovered a little on the slow day" % rested
	# Some free leaves carry a disclosed risk (e.g. Bad Water's 30% sickness).
	var risk := float(event.get("b_risk", 0.0))
	if trailblazer >= 2:
		risk *= 2.0
	if _has_keepsake("rabbits_foot"):
		risk *= 0.5
	if event.has("b_risk") and randf() < risk:
		var healthy: Array[String] = []
		for member_id in PARTY_DATA.MEMBER_ORDER:
			if party[member_id]["alive"] and int(party[member_id]["condition"]) < 2:
				healthy.append(member_id)
		if not healthy.is_empty():
			var member_id: String = healthy[randi() % healthy.size()]
			party[member_id]["condition"] = 2
			party[member_id]["legs_sick"] = 0
			party[member_id]["disease"] = "dysentery"
			_show_bark(member_id, "sick")
			message += "  ·  %s HAS DYSENTERY from the water" % str(party[member_id]["name"]).to_upper()
	_resolve_event(message)

func _rest_one_member() -> String:
	var worst_id := ""
	var worst_condition := 0
	for member_id in PARTY_DATA.MEMBER_ORDER:
		var member: Dictionary = party[member_id]
		if member["alive"] and int(member["condition"]) > worst_condition:
			worst_condition = int(member["condition"])
			worst_id = member_id
	if worst_id == "":
		return ""
	var steps := 2 if character == "doctor" else 1
	party[worst_id]["condition"] = maxi(0, worst_condition - steps)
	if worst_condition == 2:
		party[worst_id]["legs_sick"] = 0
		party[worst_id]["disease"] = ""
	return str(party[worst_id]["name"])

func _apply_effect_dictionary(effects: Dictionary) -> void:
	for key in effects.keys():
		var amount := int(effects[key])
		match key:
			"supplies": supplies = max(0, supplies + amount)
			"morale": morale = clamp(morale + amount, 0, 100)
			"days": day = max(1, day + amount)
			"grit": grit = clamp(grit + amount, 0, 3)
			"wagon": wagon_health = clamp(wagon_health + amount, 0, 100)
			"rest": _rest_one_member()
	if morale <= 0:
		if death_cause.is_empty():
			death_cause = "the heart went out of the party on the open road"
		_end_run(false)

func _resolve_event(message: String) -> void:
	event_active = false
	outcome_label.text = message
	if route_index > 0 and not game_over:
		_prepare_reward()
	else:
		_start_leg()
	_refresh_ui()

func _prepare_reward() -> void:
	reward_options.clear()
	var target := 2 if trailblazer >= 4 else 3
	var pool := REWARD_POOL.duplicate()
	pool = pool.filter(_card_unlocked)
	pool.shuffle()
	for card_id in pool:
		if reward_options.size() >= target:
			break
		if not deck_ids.has(card_id):
			reward_options.append(card_id)
	if reward_options.size() < target:
		for card_id in pool:
			if reward_options.size() >= target:
				break
			if not reward_options.has(card_id):
				reward_options.append(card_id)
	reward_pending = true

func _choose_reward(index: int) -> void:
	if not reward_pending or index < 0 or index >= reward_options.size():
		return
	var card_id := reward_options[index]
	deck_ids.append(card_id)
	draw_pile.append(card_id)
	draw_pile.shuffle()
	outcome_label.text = "REWARD TAKEN  ·  Added %s to the deck." % CARDS[card_id]["name"]
	_finish_stop()

func _skip_reward() -> void:
	if not reward_pending:
		return
	money += 3
	outcome_label.text = "REWARD SKIPPED  ·  The wagon keeps its lean deck, and $3 for the trouble."
	_finish_stop()

func _finish_stop() -> void:
	var stop_message := outcome_label.text
	reward_pending = false
	encounter_active = false
	event_active = false
	encounter_resolved = false
	encounter_block = 0
	intent_pulse_active = false
	if intent_pulse_tween != null and intent_pulse_tween.is_valid():
		intent_pulse_tween.kill()
	# Sickness marches with the legs: two untreated legs and the trail collects.
	var death_note := _advance_sickness()
	if not death_note.is_empty():
		stop_message = death_note if stop_message.is_empty() else stop_message + "\n" + death_note
	if route_index >= ROUTE_STOPS.size() - 1:
		_end_run(true)
	else:
		_start_leg()
		_animate_route_transition()
		var stop_name: String = ROUTE_STOPS[route_index]
		var vignette: String = STORY.VIGNETTES.get(stop_name, "")
		if not vignette.is_empty():
			stop_message = (stop_message + "\n" if not stop_message.is_empty() else "") + "%s  ·  %s" % [stop_name.to_upper(), vignette]
		# The trail remembers: markers from earlier runs stand where they fell.
		for marker in _past_graves_at(stop_name):
			stop_message += "\nA weathered marker here: %s — %s, an earlier crossing." % [str(marker.get("name", "")), str(marker.get("cause", "the trail"))]
		if not stop_message.is_empty():
			outcome_label.text = stop_message
		if _has_keepsake("old_fiddle"):
			morale = clamp(morale + 2, 0, 100)
		if randf() < 0.6:
			var living: Array[String] = []
			for member_id in PARTY_DATA.MEMBER_ORDER:
				if party[member_id]["alive"]:
					living.append(member_id)
			if not living.is_empty():
				_show_bark(living[randi() % living.size()], "landmark")
		_maybe_write_letter(stop_name)
	_refresh_ui()

func _maybe_write_letter(stop_name: String) -> void:
	if game_over or victory or letters_written.has(stop_name) or not STORY.LETTER_STOPS.has(stop_name):
		return
	letters_written.append(stop_name)
	letter_pending = true
	if letter_panel != null:
		letter_text.text = STORY.compose_letter(stop_name, day, party, graves, supplies, PARTY_DATA.MEMBER_ORDER)
		letter_panel.visible = true

func _seal_letter() -> void:
	if not letter_pending:
		return
	letter_pending = false
	if letter_panel != null:
		letter_panel.visible = false
	var seal_lift := 5 if _has_keepsake("grandmas_quilt") else 2
	morale = clamp(morale + seal_lift, 0, 100)
	if card_status != null:
		card_status.text = "The letter is sealed and left with the post trader. Morale +%d." % seal_lift
	_open_shop()
	_save_game()
	_sync_and_refresh()

# ---- The sutler's store: opens after the letter at each fort. ----

func _shop_price(base: int) -> int:
	var price := base
	if trailblazer >= 7:
		price = int(ceil(price * 1.25))
	if _has_keepsake("snake_oil_bottle"):
		price = int(ceil(price * 0.8))
	return price

func _roll_shop_offers() -> void:
	shop_offers = [
		{"label": "PROVISIONS CRATE  ·  $%d  ·  +15 supplies" % _shop_price(10), "cost": _shop_price(10), "fx": "supplies"},
		{"label": "WAGON PARTS  ·  $%d  ·  repair +20 condition" % _shop_price(12), "cost": _shop_price(12), "fx": "wagon"},
		{"label": "DOCTOR'S CALL  ·  $%d  ·  fully cure the worst-off family member" % _shop_price(8), "cost": _shop_price(8), "fx": "cure"}
	]
	var pool := REWARD_POOL.duplicate()
	pool = pool.filter(_card_unlocked)
	pool.shuffle()
	var card_offer := ""
	for card_id in pool:
		if not deck_ids.has(card_id):
			card_offer = card_id
			break
	if card_offer == "":
		card_offer = pool[0]
	shop_offers.append({"label": "CARD: %s  ·  $%d  ·  %s" % [str(CARDS[card_offer]["name"]).to_upper(), _shop_price(15), CARDS[card_offer]["text"]], "cost": _shop_price(15), "fx": "card", "card": card_offer})
	var keepsake_stock: Array = TRINKETS.KEEPSAKE_POOL.filter(func(k): return not keepsakes.has(k))
	if not keepsake_stock.is_empty():
		var offered: String = keepsake_stock[randi() % keepsake_stock.size()]
		shop_offers.append({"label": "KEEPSAKE: %s  ·  $%d  ·  %s" % [str(TRINKETS.KEEPSAKES[offered]["name"]).to_upper(), _shop_price(18), TRINKETS.KEEPSAKES[offered]["text"]], "cost": _shop_price(18), "fx": "keepsake", "keepsake": offered})
	var tonic_offer: String = TRINKETS.TONIC_POOL[randi() % TRINKETS.TONIC_POOL.size()]
	shop_offers.append({"label": "TONIC: %s  ·  $%d  ·  %s" % [str(TRINKETS.TONICS[tonic_offer]["name"]).to_upper(), _shop_price(8), TRINKETS.TONICS[tonic_offer]["text"]], "cost": _shop_price(8), "fx": "tonic", "tonic": tonic_offer})

func _open_shop() -> void:
	if game_over or victory or shop_panel == null:
		return
	_roll_shop_offers()
	shop_open = true
	shop_title.text = "THE SUTLER'S STORE  ·  %s  ·  YOU HOLD $%d" % [str(ROUTE_STOPS[route_index]).to_upper(), money]
	for i in shop_buttons.size():
		if i < shop_offers.size():
			shop_buttons[i].visible = true
			shop_buttons[i].text = str(shop_offers[i]["label"])
			shop_buttons[i].disabled = money < int(shop_offers[i]["cost"])
		else:
			shop_buttons[i].visible = false
	shop_panel.visible = true
	_refresh_ui()

func _buy_shop_offer(index: int) -> void:
	if not shop_open or index < 0 or index >= shop_offers.size():
		return
	var offer: Dictionary = shop_offers[index]
	if money < int(offer["cost"]):
		return
	money -= int(offer["cost"])
	match str(offer["fx"]):
		"supplies":
			supplies += 15
		"wagon":
			wagon_health = clamp(wagon_health + 20, 0, 100)
		"cure":
			_apply_cure()
		"card":
			var card_id := str(offer["card"])
			deck_ids.append(card_id)
			draw_pile.append(card_id)
			draw_pile.shuffle()
		"keepsake":
			_gain_keepsake(str(offer["keepsake"]))
		"tonic":
			if not _gain_tonic(str(offer["tonic"])):
				money += int(offer["cost"])
				card_status.text = "The belt only holds three tonics."
	if card_status != null:
		card_status.text = "Bought: %s. $%d remains." % [str(offer["label"]).split("  ·  ")[0], money]
	shop_title.text = "THE SUTLER'S STORE  ·  %s  ·  YOU HOLD $%d" % [str(ROUTE_STOPS[route_index]).to_upper(), money]
	for i in shop_buttons.size():
		if i < shop_offers.size():
			shop_buttons[i].disabled = money < int(shop_offers[i]["cost"])
	_refresh_ui()

func _leave_shop() -> void:
	if not shop_open:
		return
	shop_open = false
	if shop_panel != null:
		shop_panel.visible = false
	_save_game()
	_sync_and_refresh()

func _advance_sickness() -> String:
	var notes: Array[String] = []
	for member_id in PARTY_DATA.MEMBER_ORDER:
		var member: Dictionary = party[member_id]
		if not member["alive"] or int(member["condition"]) != 2:
			continue
		member["legs_sick"] = int(member["legs_sick"]) + 1
		if int(member["legs_sick"]) >= 2:
			notes.append(_kill_member(member_id))
		else:
			notes.append("%s IS FADING  ·  one leg left to find a cure." % str(member["name"]).to_upper())
	return "\n".join(notes)

func _kill_member(member_id: String) -> String:
	var member: Dictionary = party[member_id]
	member["alive"] = false
	member["condition"] = 2
	var member_name := str(member["name"])
	var disease := str(member.get("disease", ""))
	if disease.is_empty():
		disease = PARTY_DATA.DISEASES[randi() % PARTY_DATA.DISEASES.size()]
	var stop_name: String = ROUTE_STOPS[route_index]
	graves.append({"name": member_name, "role": PARTY_DATA.MEMBERS[member_id]["role"], "stop": stop_name, "day": day, "cause": disease})
	_swap_family_card(member_id, "memory_" + member_id)
	_show_bark(member_id, "death")
	morale = clamp(morale - 10, 0, 100)
	if morale <= 0:
		death_cause = "after burying %s, nobody could find a reason to hitch the team" % member_name
		_end_run(false)
	return "A GRAVE AT %s  ·  %s died of %s. Their card becomes a memory. Morale -10." % [stop_name.to_upper(), member_name, disease]

func _end_run(won: bool) -> void:
	game_over = not won
	victory = won
	event_active = false
	encounter_active = false
	reward_pending = false
	pa_choice_active = false
	if pa_panel != null:
		pa_panel.visible = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if return_to_camp_button != null:
		return_to_camp_button.visible = true
	intent_pulse_active = false
	if intent_pulse_tween != null and intent_pulse_tween.is_valid():
		intent_pulse_tween.kill()
	var grave_note := ""
	if not graves.is_empty():
		var lines: Array[String] = []
		for grave in graves:
			lines.append("%s (%s) — died of %s at %s, day %d" % [grave["name"], grave["role"], str(grave.get("cause", "the trail")), grave["stop"], int(grave["day"])])
		grave_note = "  ·  Graves along the trail: " + "; ".join(lines)
	if won:
		outcome_label.text = "OREGON CITY REACHED  ·  %d days survived  ·  %d miles of trail.%s" % [day, completed_legs * 100, grave_note]
	else:
		outcome_label.text = "THE JOURNEY ENDS  ·  %d days survived  ·  %d miles of trail.%s" % [day, completed_legs * 100, grave_note]
	_append_run_history(won)
	# The book of the player: finished runs earn unlocks; victories climb the ladder.
	var before_finished := int(profile.get("runs_finished", 0))
	profile["runs_finished"] = before_finished + 1
	if won:
		profile["wins"] = int(profile.get("wins", 0)) + 1
		if trailblazer > int(profile.get("cleared", -1)):
			profile["cleared"] = trailblazer
	_save_profile()
	var unlock_notes: Array[String] = []
	for card_id in LOCKED_CARDS.keys():
		if int(LOCKED_CARDS[card_id]) == before_finished + 1:
			unlock_notes.append(str(CARDS[card_id]["name"]))
	if not unlock_notes.is_empty():
		outcome_label.text += "  ·  NEW CARD UNLOCKED: " + ", ".join(unlock_notes)
	if won and int(profile.get("wins", 0)) == 1:
		outcome_label.text += "  ·  THE TRAILBLAZER LADDER IS OPEN — harder trails wait at camp."
	_refresh_trailblazer_ui()

# ---- The trail journal: every finished run goes in the book. ----

const HISTORY_PATH := "user://history.json"

func _append_run_history(won: bool) -> void:
	var history: Array = _read_history()
	var grave_names: Array[String] = []
	for grave in graves:
		grave_names.append("%s (%s)" % [grave["name"], str(grave.get("cause", "the trail"))])
	var toggles: Array[String] = []
	for key in run_modifiers.keys():
		if run_modifiers[key]:
			toggles.append(str(key))
	history.append({
		"date": Time.get_date_string_from_system(),
		"won": won, "days": day, "legs": completed_legs, "miles": completed_legs * 100,
		"cause": "reached Oregon City" if won else (death_cause if not death_cause.is_empty() else "the trail"),
		"graves": grave_names, "grave_details": graves.duplicate(true),
		"deck_size": deck_ids.size(), "modifiers": toggles,
		"seed": run_seed, "trailblazer": trailblazer, "character": character
	})
	while history.size() > 50:
		history.pop_front()
	var file := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(history))
		file.close()
	_refresh_history_panel()

func _past_graves_at(stop_name: String) -> Array:
	var markers: Array = []
	for entry in _read_history():
		for grave in entry.get("grave_details", []):
			if str(grave.get("stop", "")) == stop_name:
				markers.append(grave)
	return markers

func _read_history() -> Array:
	if not FileAccess.file_exists(HISTORY_PATH):
		return []
	var file := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Array else []

func _refresh_history_panel() -> void:
	if history_label == null:
		return
	var history: Array = _read_history()
	if history.is_empty():
		history_label.text = "No journeys in the book yet."
		return
	var lines: Array[String] = []
	var start: int = maxi(0, history.size() - 5)
	for i in range(history.size() - 1, start - 1, -1):
		var entry: Dictionary = history[i]
		var mark := "★" if bool(entry.get("won", false)) else "†"
		var line := "%s  %s — day %d, %d mi — %s" % [mark, str(entry.get("date", "")), int(entry.get("days", 0)), int(entry.get("miles", 0)), str(entry.get("cause", ""))]
		var entry_graves: Array = entry.get("graves", [])
		if not entry_graves.is_empty():
			line += "  ·  lost: " + ", ".join(entry_graves)
		lines.append(line)
	history_label.text = "\n".join(lines)

func _refresh_ui() -> void:
	if day_label == null:
		return
	day_label.text = "DAY %02d" % day
	leg_label.text = "LEG %d / 12" % completed_legs
	destination_label.text = "NEXT · %s" % ROUTE_STOPS[min(route_index + 1, ROUTE_STOPS.size() - 1)]
	route_note.text = "%s  →  %s" % [ROUTE_STOPS[route_index], ROUTE_STOPS[min(route_index + 1, ROUTE_STOPS.size() - 1)]]
	var stage_up := (encounter_active or stage_hold) and run_mode == "map"
	if combat_stage != null:
		combat_stage.visible = stage_up
	# The Slay the Spire rule: MapView and EncounterView are never visible
	# together. The map yields the whole stage to the encounter and returns
	# when the encounter resolves. (First two legs keep the tutor sheet up;
	# side panels like rewards and the sutler ride the encounter view too.)
	if map_view != null:
		map_view.visible = not stage_up and not event_active
	if encounter_view != null:
		encounter_view.visible = not map_view.visible or completed_legs < 2 \
			or reward_pending or pa_choice_active or letter_pending or shop_open
	if map_canvas != null:
		map_canvas.current_index = route_index
		# Offer the fork whenever the wagon is free to roll: two roads, two stamps.
		map_canvas.fork_active = run_mode == "map" and not stage_up and not encounter_active \
			and not event_active and not reward_pending and not letter_pending and not shop_open \
			and not game_over and not victory and route_index < ROUTE_STOPS.size() - 1
		if map_canvas.fork_active:
			var alt: Dictionary = _alt_road_for_leg()
			map_canvas.fork_names = [str(MAIN_ROAD["name"]), str(alt["name"])]
			map_canvas.fork_terms = [str(MAIN_ROAD["terms"]), str(alt["terms"])]
		map_canvas.queue_redraw()
	# The score follows morale: the theme while hope holds, a lone fiddle
	# drone when it runs low.
	if run_mode == "map":
		_set_music("drone" if morale < 30 else "theme")
	if reward_overlay != null:
		reward_overlay.visible = reward_pending and run_mode == "map"
	# --- UI phase state machine: travel / event / fight ------------------
	# TRAVEL: the map IS the screen — the sheet slides off-stage right and
	# the roads are the only call to action. EVENT: the sheet slides in and
	# the map dims into the background. FIGHT: stage up, sheet in, hand up.
	var ui_phase := "fight" if encounter_active or stage_hold else \
		("event" if event_active or reward_pending or pa_choice_active or letter_pending or shop_open else "travel")
	if ui_phase != last_ui_phase and run_mode == "map":
		last_ui_phase = ui_phase
		if map_event_sheet != null:
			# TRAVEL: sheet slides off-stage right (the map's roads are the CTA;
			# first two legs it stays as the tutor). EVENT: sheet slides to the
			# CENTER of the vacated table — the focused scene. FIGHT: side rail.
			var sheet_target := 0.0
			if ui_phase == "travel" and completed_legs >= 2:
				sheet_target = 470.0
			elif event_active:
				sheet_target = -420.0
			var slide := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			slide.set_parallel(true)
			slide.tween_property(map_event_sheet, "offset_left", sheet_target, 0.28)
			slide.tween_property(map_event_sheet, "offset_right", sheet_target, 0.28)
		var recede := ui_phase == "event"
		var table_tone := Color(0.62, 0.62, 0.62, 1.0) if recede else Color.WHITE
		for surface in [map_table_panel, landmark_plate_panel]:
			if surface != null:
				var dim := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				dim.tween_property(surface, "modulate", table_tone, 0.28)
		if map_canvas != null:
			var dim_map := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			dim_map.tween_property(map_canvas, "modulate", table_tone, 0.28)
	_update_hand_tuck()
	if landmark_art_rect != null:
		var stop_art: String = STORY.LANDMARK_ART.get(ROUTE_STOPS[route_index], "")
		if not stop_art.is_empty():
			landmark_art_rect.texture = load(_plate_art(stop_art)) as Texture2D
	if location_value != null:
		location_value.text = ROUTE_STOPS[route_index]
	supply_value.text = "%02d" % supplies
	morale_value.text = "%02d" % morale
	health_value.text = "%02d" % wagon_health
	if money_value != null:
		money_value.text = "$%d" % money
	if grit_value != null:
		grit_value.text = "%d / 3" % grit
	if grit_pips != null:
		grit_pips.text = "● ".repeat(grit) + "○ ".repeat(3 - grit)
	_sync_deck_counters()
	deck_value = null
	if hand_value != null:
		hand_value.text = "HAND %02d  ·  DRAW PILE %02d  ·  DISCARD PILE %02d" % [hand.size(), draw_pile.size(), discard_pile.size()]
		hand_value.tooltip_text = "Deck total: %d  (hand + draw + discard)" % deck_ids.size()
	if draw_pile_label != null:
		draw_pile_label.text = "DRAW\n%02d" % draw_pile.size()
	if discard_pile_label != null:
		discard_pile_label.text = "DISCARD\n%02d" % discard_pile.size()
	_rebuild_hand_ui()
	_wire_hand_card_juice()
	for i in card_buttons.size():
		var card_id := hand[i]
		card_buttons[i].modulate = Color(1, 1, 1, 1) if _can_play(card_id) else Color(0.72, 0.7, 0.66, 0.92)
		var fx_now := _effective_fx(card_id)
		var fx_bits: Array[String] = []
		for key in fx_now.keys():
			fx_bits.append("%s %+d" % [key, int(fx_now[key])])
		card_buttons[i].tooltip_text = "Cost: %d Grit  ·  Right now: %s" % [int(CARDS[card_id]["cost"]), ", ".join(fx_bits)]
	if route_row != null:
		for i in ROUTE_STOPS.size():
			var stop: VBoxContainer = route_row.get_node("Stop%d" % i)
			var marker: Label = stop.get_node("Marker")
			var name_label: Label = stop.get_node("StopLabel")
			if i == route_index:
				marker.text = "▰"
				marker.add_theme_color_override("font_color", Color("#a02818"))
				name_label.add_theme_color_override("font_color", _themed_text(Color("#221c14")))
			elif i < route_index:
				marker.text = "●"
				marker.add_theme_color_override("font_color", Color("#88ad91"))
				name_label.add_theme_color_override("font_color", Color("#9bb29d"))
			else:
				marker.text = "○"
				marker.add_theme_color_override("font_color", Color("#66766b"))
				name_label.add_theme_color_override("font_color", Color("#829187"))
	if game_over or victory:
		_event_end_ui()
	elif reward_pending:
		_event_reward_ui()
	elif encounter_active:
		_event_encounter_ui()
	elif event_active:
		_event_active_ui()
	else:
		_event_idle_ui()
	if reward_box != null:
		reward_box.visible = reward_pending
	_refresh_roster()
	if trinket_row != null:
		trinket_row.visible = run_mode == "map"
	if hand_container != null:
		hand_container.visible = run_mode == "map"
	continue_button.disabled = event_active or reward_pending or game_over or victory or pa_choice_active or letter_pending
	probe_continue_button.disabled = continue_button.disabled
	probe_event_a.disabled = not event_active
	probe_event_b.disabled = not event_active
	probe_reward_skip.disabled = not reward_pending
	for i in probe_play_buttons.size():
		probe_play_buttons[i].disabled = i >= hand.size() or (i < hand.size() and not _can_play(hand[i]))
		probe_discard_buttons[i].disabled = i >= hand.size() or event_active or reward_pending or game_over or victory or pa_choice_active
		probe_reward_buttons[i].disabled = i >= reward_options.size() or not reward_pending
	if probe_pa_supplies != null:
		probe_pa_supplies.disabled = not pa_choice_active
		probe_pa_wagon.disabled = not pa_choice_active
		probe_camp_continue.disabled = run_mode != "camp" or not FileAccess.file_exists(SAVE_PATH)
		probe_seal_letter.disabled = not letter_pending
		probe_shop_leave.disabled = not shop_open
		for i in probe_shop_buttons.size():
			probe_shop_buttons[i].disabled = not shop_open or i >= shop_offers.size() or money < int(shop_offers[i]["cost"])

func _refresh_trinket_strip() -> void:
	if keepsake_box == null:
		return
	for child in keepsake_box.get_children():
		child.queue_free()
	for keepsake_id in keepsakes:
		var info: Dictionary = TRINKETS.KEEPSAKES[keepsake_id]
		var chip := PanelContainer.new()
		chip.tooltip_text = "%s — %s" % [info["name"], info["text"]]
		chip.add_theme_stylebox_override("panel", _make_style(Color("#f2e6c2"), Color("#a02818"), 6, 1))
		var chip_label := _label("%s %s" % [info["glyph"], str(info["name"]).to_upper()], 9, Color("#221c14"))
		chip.add_child(chip_label)
		chip.rotation_degrees = ui_rng.randf_range(-1.5, 1.5)
		keepsake_box.add_child(chip)
	for i in tonic_slots.size():
		if i < tonics.size():
			var tonic: Dictionary = TRINKETS.TONICS[tonics[i]]
			tonic_slots[i].text = "%s %s" % [tonic["glyph"], str(tonic["name"]).to_upper()]
			tonic_slots[i].tooltip_text = "%s — click to drink." % tonic["text"]
			tonic_slots[i].disabled = false
			tonic_slots[i].visible = true
		else:
			# An empty belt is invisible — three ghost panels floating under
			# the HUD read as broken UI, not as an invitation.
			tonic_slots[i].visible = false
			tonic_slots[i].disabled = true

func _refresh_roster() -> void:
	if roster_chips.is_empty():
		return
	for member_id in roster_chips.keys():
		var member: Dictionary = party.get(member_id, {})
		if member.is_empty():
			continue
		var chip_label: Label = roster_chips[member_id]["label"]
		var chip_panel: PanelContainer = roster_chips[member_id]["panel"]
		# The portrait carries the condition: sepia when hurt, cold slate
		# when sick, near-dark when they're gone. Faces, not status text.
		var chip_portrait: TextureRect = roster_chips[member_id].get("portrait")
		if chip_portrait != null:
			if not member["alive"]:
				chip_portrait.modulate = Color(0.42, 0.40, 0.38)
			else:
				match int(member["condition"]):
					1: chip_portrait.modulate = Color(0.93, 0.80, 0.62)
					2: chip_portrait.modulate = Color(0.74, 0.76, 0.88)
					_: chip_portrait.modulate = Color.WHITE
		var hearts := "♥".repeat(int(member["bond_level"]))
		if not member["alive"]:
			chip_label.text = "%s  ·  AT REST" % str(member["name"]).to_upper()
			chip_label.add_theme_color_override("font_color", Color("#8a8074"))
			chip_panel.tooltip_text = "%s is buried along the trail. Their card is a memory now." % member["name"]
			continue
		var condition := int(member["condition"])
		var status: String = CONDITION_NAMES[condition]
		if condition == 2:
			var disease_tag := str(member.get("disease", ""))
			status = "%s · %d LEG%s LEFT" % [disease_tag.to_upper() if not disease_tag.is_empty() else "SICK", 2 - int(member["legs_sick"]), "" if 2 - int(member["legs_sick"]) == 1 else "S"]
		chip_label.text = "%s %s ·  %s" % [str(member["name"]).to_upper(), hearts, status]
		chip_label.add_theme_color_override("font_color", Color(CONDITION_COLORS[condition]))
		chip_panel.tooltip_text = "%s (%s)  ·  bond %d (%d plays)  ·  %s" % [
			member["name"], PARTY_DATA.MEMBERS[member_id]["blurb"], int(member["bond_level"]),
			int(member["bond_plays"]),
			"Healthy." if condition == 0 else ("Hurt: their card's numbers drop by 1 until they heal." if condition == 1 else "Sick: card halved. Cure with medicine or a slow day — 2 untreated legs is fatal.")
		]

func _sync_deck_counters() -> void:
	# Invariant: every card is in exactly one of hand, draw pile, discard, or exhausted.
	if hand.size() + draw_pile.size() + discard_pile.size() + exhausted.size() != deck_ids.size():
		card_status.text = "Deck ledger repairing an out-of-sync card count."

func _hide_encounter_ui() -> void:
	if map_wash_rect != null:
		map_wash_rect.color = DARK_BASE if UI_DARK else Color(0.91, 0.87, 0.76, 1.0)
	if encounter_art == null:
		return
	encounter_art.visible = false
	if encounter_art_plate != null:
		encounter_art_plate.visible = false
	encounter_health_label.visible = false
	encounter_intent_label.visible = false
	encounter_stake_label.visible = false

func _event_idle_ui() -> void:
	_hide_encounter_ui()
	continue_button.add_theme_stylebox_override("normal", _make_style(Color("#d5b66d"), Color("#efd28e"), 9, 1))
	continue_button.add_theme_color_override("font_color", Color("#1b211e"))
	choice_a.visible = false
	choice_b.visible = false
	continue_button.visible = true
	continue_button.text = "LEAVE %d GRIT UNSPENT?  ·  PRESS AGAIN" % grit if pending_leave_confirm else "CONTINUE JOURNEY   →"
	var danger_next := (completed_legs + 1) % _danger_cadence() == 0
	var next_stop := str(ROUTE_STOPS[min(route_index + 1, ROUTE_STOPS.size() - 1)]).to_upper()
	event_kicker.text = "THE ROAD TO %s" % next_stop
	var event: Dictionary = EVENTS[event_order[event_cursor % event_order.size()]]
	# No rule-book on the paper: the skull on the map says what waits ahead.
	event_title.text = "POWDER DRY, EYES OPEN" if danger_next else str(event["title"]).to_upper()
	if completed_legs < 2:
		event_body.text = "Play cards in the hand, then pick a road on the map."
	else:
		event_body.text = ""
	if event_revealed and not danger_next:
		event_hint.text = "%s's keen eyes: the road ahead asks for %s." % [party["sarah"]["name"], event["card_label"]]
	else:
		event_hint.text = ""

func _event_encounter_ui() -> void:
	if map_wash_rect != null:
		map_wash_rect.color = Color(0.16, 0.09, 0.09, 1.0) if UI_DARK else Color(0.9, 0.78, 0.66, 1.0)
	var encounter: Dictionary = ENCOUNTERS[encounter_index]
	choice_a.visible = false
	choice_b.visible = false
	encounter_art.visible = false
	if encounter_art_plate != null:
		encounter_art_plate.visible = false
	# The stage carries the numbers now — HP bar on the boards, intent banner
	# over the enemy. The sheet keeps only the prose: title and one paragraph.
	encounter_health_label.visible = false
	encounter_intent_label.visible = false
	encounter_stake_label.visible = false
	event_kicker.text = "%s  →  %s" % [str(ROUTE_STOPS[route_index]).to_upper(), str(ROUTE_STOPS[min(route_index + 1, ROUTE_STOPS.size() - 1)]).to_upper()]
	event_title.text = str(encounter["title"]).to_upper()
	event_body.text = encounter["body"]
	_stage_update_readouts()
	event_hint.text = ""
	continue_button.visible = true
	continue_button.text = "BRACE FOR IT  ·  take the %d hit, refill Grit" % maxi(0, encounter_threat - encounter_block)
	if not _has_playable_card() or grit == 0:
		continue_button.add_theme_stylebox_override("normal", _make_style(Color("#a02818"), Color("#6b1a10"), 9, 2))
		continue_button.add_theme_color_override("font_color", Color("#f6efdc"))
	else:
		continue_button.add_theme_stylebox_override("normal", _make_style(Color("#d5b66d"), Color("#efd28e"), 9, 1))
		continue_button.add_theme_color_override("font_color", Color("#1b211e"))

func _event_active_ui() -> void:
	_hide_encounter_ui()
	var event: Dictionary = EVENTS[current_event_index]
	if event.has("art") and encounter_art != null:
		encounter_art.texture = load(_plate_art(str(event["art"]))) as Texture2D
		encounter_art.modulate = Color.WHITE
		encounter_art.custom_minimum_size = Vector2(0, 185)
		encounter_art.visible = true
		if encounter_art_plate != null:
			encounter_art_plate.visible = true
	# Card-driven: option A is not a button. Playing a matching card from the
	# hand IS the choice; the one button here is walking away.
	choice_a.visible = false
	choice_b.visible = true
	var lean := ""
	if event_hint_member != "" and party[event_hint_member]["alive"]:
		lean = "  ·  ✦ %s leans toward %s" % [party[event_hint_member]["name"], "paying the card" if event_hint_option == "a" else "moving on"]
	choice_b.text = "MOVE ON  ·  %s" % str(event["bd"]).replace("Free leave  •  ", "")
	choice_b.tooltip_text = "Costs a day of travel. The slow day lets one hurt or sick member recover a step."
	event_kicker.text = "ON THE ROAD TO %s" % str(ROUTE_STOPS[min(route_index + 1, ROUTE_STOPS.size() - 1)]).to_upper()
	event_title.text = str(event["title"]).to_upper()
	event_body.text = str(event["body"]) + lean
	var ask_terms := str(event["ad"])
	var terms_split := ask_terms.split("•", false, 1)
	if terms_split.size() > 1:
		ask_terms = terms_split[1].strip_edges()
	if _find_card_in_hand(event["card_type"]) >= 0:
		event_hint.text = "PLAY %s  →  %s" % [str(event["card_label"]).to_upper(), ask_terms]
	else:
		event_hint.text = "Not holding %s — move on." % event["card_label"]
	continue_button.visible = false

func _event_reward_ui() -> void:
	_hide_encounter_ui()
	choice_a.visible = false
	choice_b.visible = false
	event_kicker.text = "STOP REACHED  ·  CARD REWARD"
	event_title.text = "CHOOSE ONE REWARD"
	event_body.text = "The wagon reached %s. Add one card to the deck, or skip." % ROUTE_STOPS[route_index]
	event_hint.text = "Three cards disclosed; the reward enters the draw pile."
	continue_button.text = "REWARD PENDING"
	continue_button.visible = false
	for button in reward_buttons:
		button.queue_free()
	reward_buttons.clear()
	# Rewards are dealt as CARD FACES on a dimmed table — the sheet's old
	# text buttons are retired.
	if reward_overlay != null and reward_card_row != null:
		reward_box.visible = false
		# The overlay IS the reward screen — the sheet behind it goes quiet.
		event_kicker.text = ""
		event_title.text = ""
		event_body.text = ""
		event_hint.text = ""
		for child in reward_card_row.get_children():
			child.queue_free()
		for i in reward_options.size():
			var slot := Control.new()
			slot.custom_minimum_size = Vector2(172, 244)
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			var face := _make_card_face(reward_options[i])
			face.set_meta("rest_r", 0.0)
			face.set_meta("rest_z", 0)
			slot.add_child(face)
			slot.tooltip_text = "%s  ·  joins the draw pile" % str(CARDS[reward_options[i]]["rarity"]).to_upper()
			slot.gui_input.connect(_on_reward_face_input.bind(i))
			slot.mouse_entered.connect(_on_hand_card_hover.bind(face, true))
			slot.mouse_exited.connect(_on_hand_card_hover.bind(face, false))
			reward_card_row.add_child(slot)
		reward_overlay.visible = true
	else:
		for i in reward_options.size():
			var card: Dictionary = CARDS[reward_options[i]]
			var button := _make_choice_button("TAKE %s  ·  %s  ·  %dc\n%s" % [card["name"], card["rarity"].to_upper(), card["cost"], card["text"]])
			button.pressed.connect(_choose_reward.bind(i))
			reward_box.add_child(button)
			reward_buttons.append(button)
		var skip := _make_choice_button("SKIP REWARD  ·  Keep the deck lean")
		skip.pressed.connect(_skip_reward)
		reward_box.add_child(skip)
		reward_buttons.append(skip)

func _event_end_ui() -> void:
	_hide_encounter_ui()
	choice_a.visible = false
	choice_b.visible = false
	continue_button.text = "RUN COMPLETE" if victory else "JOURNAL CLOSED"
	event_kicker.text = "OREGON CITY" if victory else "JOURNEY ENDED"
	event_title.text = "THE TRAIL IS COMPLETE" if victory else "THE WAGON STOPS"
	event_body.text = STORY.epilogue(victory, party, graves, day, PARTY_DATA.MEMBER_ORDER, death_cause)
	event_hint.text = "Trail seed %d  ·  Trailblazer %d  ·  Deck %d cards  ·  type the seed at camp to walk this trail again" % [run_seed, trailblazer, deck_ids.size()]

# ---- Pile viewers: nobody decides blind. ----

func _open_pile_view(which: String) -> void:
	if pile_panel == null:
		return
	var ids: Array = []
	match which:
		"draw":
			pile_title.text = "DRAW PILE  ·  %d CARDS  ·  shown shuffled, order stays secret" % draw_pile.size()
			ids = draw_pile.duplicate()
			ids.shuffle()
		"discard":
			pile_title.text = "DISCARD PILE  ·  %d CARDS" % discard_pile.size()
			ids = discard_pile.duplicate()
		"compendium":
			pile_title.text = "COMPENDIUM  ·  every card on the trail  ·  locked ones keep their secrets"
			var lines_all: Array[String] = []
			var listed_ids: Array = CARDS.keys()
			listed_ids.sort_custom(func(a, b) -> bool: return _card_display_name(a) < _card_display_name(b))
			for card_id in listed_ids:
				if CARDS[card_id].get("memory", false):
					continue
				if _card_unlocked(card_id):
					var marker := "✦ " if str(CARDS[card_id].get("family", "")) != "" else ""
					lines_all.append("%s%s  ·  %dc  ·  %s" % [marker, _card_display_name(card_id), int(CARDS[card_id]["cost"]), _card_display_text(card_id)])
				else:
					lines_all.append("???  ·  a silhouette — finish %d runs to earn it" % int(LOCKED_CARDS[card_id]))
			pile_list.text = "\n".join(lines_all)
			pile_panel.move_to_front()
			pile_panel.visible = true
			return
		_:
			pile_title.text = "FULL DECK  ·  %d CARDS  ·  hand + draw + discard + exhausted" % deck_ids.size()
			ids = deck_ids.duplicate()
	var counts := {}
	for card_id in ids:
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	var lines: Array[String] = []
	var listed: Array = counts.keys()
	listed.sort_custom(func(a, b) -> bool: return _card_display_name(a) < _card_display_name(b))
	for card_id in listed:
		var marker := "✦ " if str(CARDS[card_id].get("family", "")) != "" else ""
		lines.append("%d×  %s%s  ·  %dc  ·  %s" % [counts[card_id], marker, _card_display_name(card_id), int(CARDS[card_id]["cost"]), _card_display_text(card_id)])
	pile_list.text = "\n".join(lines) if not lines.is_empty() else "Empty."
	pile_panel.visible = true

func _close_pile_view() -> void:
	if pile_panel != null:
		pile_panel.visible = false

# ---- Save & quit: the trail waits. ----

func _save_game() -> void:
	if game_over or victory:
		return
	var state := {
		"version": 1,
		"day": day, "completed_legs": completed_legs, "route_index": route_index,
		"supplies": supplies, "morale": morale, "wagon_health": wagon_health,
		"injuries": injuries, "grit": grit,
		"event_active": event_active, "current_event_index": current_event_index,
		"event_order": event_order, "event_cursor": event_cursor,
		"encounter_active": encounter_active, "encounter_index": encounter_index,
		"encounter_health": encounter_health, "encounter_max_health": encounter_max_health,
		"encounter_threat": encounter_threat, "encounter_block": encounter_block,
		"encounter_turn": encounter_turn,
		"reward_pending": reward_pending, "reward_options": reward_options,
		"deck_ids": deck_ids, "draw_pile": draw_pile, "hand": hand,
		"discard_pile": discard_pile, "exhausted": exhausted,
		"party": party, "graves": graves,
		"travel_bonus": travel_bonus, "event_revealed": event_revealed,
		"event_hint_member": event_hint_member, "event_hint_option": event_hint_option,
		"letters_written": letters_written, "death_cause": death_cause,
		"money": money, "run_modifiers": run_modifiers,
		"run_seed": run_seed, "trailblazer": trailblazer, "character": character,
		"keepsakes": keepsakes, "tonics": tonics
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(state))
	file.close()

func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return false
	var state: Dictionary = parsed
	day = int(state.get("day", 1))
	completed_legs = int(state.get("completed_legs", 0))
	route_index = int(state.get("route_index", 0))
	supplies = int(state.get("supplies", 68))
	morale = int(state.get("morale", 82))
	wagon_health = int(state.get("wagon_health", 100))
	injuries = int(state.get("injuries", 0))
	grit = int(state.get("grit", 3))
	event_active = bool(state.get("event_active", false))
	current_event_index = int(state.get("current_event_index", 0))
	event_cursor = int(state.get("event_cursor", 0))
	encounter_active = bool(state.get("encounter_active", false))
	encounter_index = int(state.get("encounter_index", 0))
	encounter_health = int(state.get("encounter_health", 0))
	encounter_max_health = int(state.get("encounter_max_health", 0))
	encounter_threat = int(state.get("encounter_threat", 0))
	encounter_block = int(state.get("encounter_block", 0))
	encounter_turn = int(state.get("encounter_turn", 0))
	reward_pending = bool(state.get("reward_pending", false))
	travel_bonus = int(state.get("travel_bonus", 0))
	event_revealed = bool(state.get("event_revealed", false))
	event_hint_member = str(state.get("event_hint_member", ""))
	event_hint_option = str(state.get("event_hint_option", ""))
	event_order.clear()
	for value in state.get("event_order", []):
		event_order.append(int(value))
	if event_order.is_empty():
		for i in EVENTS.size():
			event_order.append(i)
	reward_options.assign(state.get("reward_options", []))
	deck_ids.assign(state.get("deck_ids", []))
	draw_pile.assign(state.get("draw_pile", []))
	hand.assign(state.get("hand", []))
	discard_pile.assign(state.get("discard_pile", []))
	exhausted.assign(state.get("exhausted", []))
	graves = state.get("graves", [])
	letters_written = state.get("letters_written", [])
	death_cause = str(state.get("death_cause", ""))
	letter_pending = false
	money = int(state.get("money", 30))
	run_modifiers = state.get("run_modifiers", {})
	run_seed = int(state.get("run_seed", 1848))
	trailblazer = int(state.get("trailblazer", 0))
	character = str(state.get("character", "gunslinger"))
	keepsakes.assign(state.get("keepsakes", []))
	tonics.assign(state.get("tonics", []))
	powder_horn_spent = false
	_refresh_trinket_strip()
	shop_open = false
	if shop_panel != null:
		shop_panel.visible = false
	party = PARTY_DATA.fresh_state()
	var saved_party: Dictionary = state.get("party", {})
	for member_id in party.keys():
		if not saved_party.has(member_id):
			continue
		var saved: Dictionary = saved_party[member_id]
		party[member_id]["name"] = str(saved.get("name", party[member_id]["name"]))
		party[member_id]["condition"] = int(saved.get("condition", 0))
		party[member_id]["legs_sick"] = int(saved.get("legs_sick", 0))
		party[member_id]["disease"] = str(saved.get("disease", ""))
		party[member_id]["bond_plays"] = int(saved.get("bond_plays", 0))
		party[member_id]["bond_level"] = int(saved.get("bond_level", 0))
		party[member_id]["alive"] = bool(saved.get("alive", true))
		party[member_id]["card_id"] = str(saved.get("card_id", party[member_id]["card_id"]))
		party[member_id]["greeted"] = bool(saved.get("greeted", false))
	game_over = false
	victory = false
	pa_choice_active = false
	pending_leave_confirm = false
	# Fresh rolls from here on; the piles and stats carry the run.
	seed(run_seed + day * 131 + completed_legs * 17)
	if encounter_active and encounter_art != null:
		encounter_art.texture = load(ENCOUNTERS[encounter_index]["art"]) as Texture2D
		encounter_art.visible = true
		if encounter_art_plate != null:
			encounter_art_plate.visible = true
	return true

