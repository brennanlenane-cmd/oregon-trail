extends RefCounted
class_name EnemiesData

# StS-style enemies: every fight is a pattern-reading puzzle. Every enemy cycles
# telegraphed MOVES — the intent badge always shows the NEXT move with its
# live number, and buffs visibly push that number up while you watch.
#
# Move kinds:
#   attack — {target: supplies|morale|wagon, amount} (+ current strength)
#   buff   — {strength} permanent damage bonus, announced
#   guard  — {block} the enemy braces; your damage chews block first
#   curse  — {card} shoves a junk status card into your discard pile

const ENEMIES := [
	{
		"id": "rattlesnake", "name": "RATTLESNAKE", "hp": 8, "loot": 3, "min_leg": 0,
		"art": "res://assets/sprites/enemies/rattlesnake.png",
		"moves": [
			{"name": "STRIKE", "kind": "attack", "target": "morale", "amount": 5},
			{"name": "COIL", "kind": "buff", "strength": 2},
			{"name": "STRIKE", "kind": "attack", "target": "morale", "amount": 5},
		]
	},
	{
		"id": "wolves", "name": "HUNGRY WOLVES", "hp": 15, "loot": 5, "min_leg": 0,
		"art": "res://assets/sprites/enemies/wolf.png",
		"moves": [
			{"name": "BITE", "kind": "attack", "target": "supplies", "amount": 6},
			{"name": "HOWL", "kind": "buff", "strength": 2},
			{"name": "POUNCE", "kind": "attack", "target": "supplies", "amount": 8},
		]
	},
	{
		"id": "road_agent", "name": "ROAD AGENT", "hp": 12, "loot": 6, "min_leg": 0,
		"art": "res://assets/sprites/enemies/road-agent.png",
		"moves": [
			{"name": "FIRE", "kind": "attack", "target": "wagon", "amount": 8},
			{"name": "TAKE COVER", "kind": "guard", "block": 6},
			{"name": "FIRE", "kind": "attack", "target": "wagon", "amount": 8},
		]
	},
	{
		"id": "mountain_lion", "name": "MOUNTAIN LION", "hp": 22, "loot": 7, "min_leg": 4,
		"art": "res://assets/sprites/enemies/mountain-lion.png",
		"moves": [
			{"name": "STALK", "kind": "buff", "strength": 2},
			{"name": "RAID", "kind": "attack", "target": "supplies", "amount": 7},
			{"name": "RAID", "kind": "attack", "target": "supplies", "amount": 9},
		]
	},
	{
		"id": "grizzly", "name": "GRIZZLY BEAR", "hp": 26, "loot": 8, "min_leg": 4,
		"art": "res://assets/sprites/enemies/grizzly.png",
		"moves": [
			{"name": "MAUL", "kind": "attack", "target": "morale", "amount": 9},
			{"name": "ROAR", "kind": "buff", "strength": 3},
			{"name": "MAUL", "kind": "attack", "target": "morale", "amount": 11},
		]
	},
	{
		"id": "highwaymen", "name": "HIGHWAYMEN", "hp": 26, "loot": 9, "min_leg": 7,
		"art": "res://assets/sprites/enemies/highwayman.png",
		"moves": [
			{"name": "VOLLEY", "kind": "attack", "target": "wagon", "amount": 9},
			{"name": "TAKE COVER", "kind": "guard", "block": 8},
			{"name": "DUST STORM", "kind": "curse", "card": "dust_inhalation"},
			{"name": "VOLLEY", "kind": "attack", "target": "wagon", "amount": 11},
		]
	},
	{
		"id": "pass_keeper", "name": "THE PASS KEEPER", "hp": 40, "loot": 15, "min_leg": 99, "boss": true,
		"art": "res://assets/sprites/enemies/highwayman.png",
		"moves": [
			{"name": "BREAK THEIR WILL", "kind": "attack", "target": "morale", "amount": 10},
			{"name": "THE COLD CLOSES IN", "kind": "curse", "card": "dust_inhalation"},
			{"name": "TURN BACK", "kind": "attack", "target": "morale", "amount": 12},
			{"name": "STONE PATIENCE", "kind": "guard", "block": 10},
		]
	},
]

static func boss() -> Dictionary:
	for enemy in ENEMIES:
		if enemy.get("boss", false):
			return enemy
	return ENEMIES[0]

static func pick(leg: int, rng: RandomNumberGenerator, exclude_id: String = "") -> Dictionary:
	var pool: Array = []
	for enemy in ENEMIES:
		if enemy.get("boss", false):
			continue
		if leg >= int(enemy["min_leg"]) and str(enemy["id"]) != exclude_id:
			pool.append(enemy)
	if pool.is_empty():
		return ENEMIES[0]
	return pool[rng.randi_range(0, pool.size() - 1)]

static func region_for_stop(stop_index: int) -> String:
	if stop_index >= 10:
		return "forest"
	if stop_index >= 8:
		return "river"
	if stop_index >= 5:
		return "mountains"
	return "prairie"
