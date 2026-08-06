extends RefCounted
class_name TrailParty

# The Family — static member registry. Runtime state (names, condition, bonds)
# lives in main.gd's `party` dictionary and saves with the run.

const MEMBER_ORDER := ["pa", "ma", "sarah", "dog", "ox"]

const MEMBERS := {
	"pa": {
		"role": "FATHER", "default_name": "Henry", "card": "family_pa",
		"hint": "b", "chip_color": "#7a5c16",
		"blurb": "calm, understates everything"
	},
	"ma": {
		"role": "MOTHER", "default_name": "Clara", "card": "family_ma",
		"hint": "a", "chip_color": "#96422a",
		"blurb": "steel under warmth"
	},
	"sarah": {
		"role": "CHILD", "default_name": "Sarah", "card": "family_sarah",
		"hint": "a", "chip_color": "#2e6b45",
		"blurb": "curious, sees everything first"
	},
	"dog": {
		"role": "THE DOG", "default_name": "Biscuit", "card": "family_dog",
		"hint": "a", "chip_color": "#8a6a1f",
		"blurb": "a good dog. the best dog"
	},
	"ox": {
		"role": "THE OX", "default_name": "Brutus", "card": "family_ox",
		"hint": "b", "chip_color": "#5c4a32",
		"blurb": "slow, immense, dependable"
	}
}

# Bond levels unlock at these lifetime play counts (level 1 / 2 / 3).
const BOND_THRESHOLDS := [5, 15, 30]

# Card id per bond level: 0 = base, 1 = _u, 2+ = _u2 (level 3 adds barks only).
static func card_for_bond(member_id: String, bond_level: int) -> String:
	var base: String = MEMBERS[member_id]["card"]
	if bond_level <= 0:
		return base
	if bond_level == 1:
		return base + "_u"
	return base + "_u2"

const NAME_POOLS := {
	"pa": ["Elias", "Josiah", "Amos", "Silas", "Henry", "Obadiah", "Wyatt", "Clem"],
	"ma": ["Clara", "Abigail", "June", "Eliza", "Martha", "Cora", "Adelaide", "Ruth"],
	"sarah": ["Sadie", "Tom", "Lucy", "Caleb", "Nell", "Georgie", "Pearl", "Zeke"],
	"dog": ["Biscuit", "Scout", "Patch", "Blue", "Bones", "Copper", "Waffles", "General"],
	"ox": ["Brutus", "Samson", "Duke", "Moses", "Big Red", "Ajax", "Thunder", "Turnip"]
}

# The trail's killers, by name. Dysentery stays first for a reason.
const DISEASES := ["dysentery", "cholera", "typhoid fever", "camp fever"]

static func fresh_state() -> Dictionary:
	var state := {}
	for member_id in MEMBER_ORDER:
		state[member_id] = {
			"name": MEMBERS[member_id]["default_name"],
			"condition": 0,      # 0 healthy · 1 hurt · 2 sick
			"legs_sick": 0,      # legs spent sick; 2 untreated = death
			"disease": "",       # named while sick; written on the grave if it wins
			"bond_plays": 0,
			"bond_level": 0,
			"alive": true,
			"card_id": MEMBERS[member_id]["card"],
			"greeted": false     # first draw of the run always barks
		}
	return state
