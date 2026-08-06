extends RefCounted
class_name TrailCards

const CARDS := {
	# TAGS name what a card IS (GUN, ROPE, BLADE, FIRE, CARE, TRAIL, GOODS, KIN).
	# COMBOS read the current turn: what you already played changes what the
	# next card does. That chain is the game.
	#   per_tag + bonus_*     — scales with matching cards ALREADY played this turn
	#   if_tag + bonus_*      — one-time kicker if the tag showed up this turn
	#   prime_tag + mult      — the NEXT card with that tag this turn is multiplied
	#   discount_per_play     — cost drops per card already played this turn
	"trail_rations": {
		"name": "Trail Rations", "cost": 1, "type": "supply", "role": "quartermaster", "rarity": "starter",
		"art": "res://assets/art/wagon-train.jpg", "tags": ["goods"],
		"text": "Spend 3 supplies. Gain 6 morale.",
		"fx": {"supplies": -3, "morale": 6}
	},
	"forage": {
		"name": "Forage", "cost": 1, "type": "supply", "rarity": "starter",
		"art": "res://assets/art/bison-hunt.jpg", "tags": ["trail"],
		"text": "Find 4 supplies. +2 per TRAIL card this turn.",
		"fx": {"supplies": 4},
		"combo": {"per_tag": "trail", "bonus_supplies": 2}
	},
	"campfire_stories": {
		"name": "Campfire Stories", "cost": 1, "type": "morale", "rarity": "starter",
		"art": "res://assets/art/campfire.jpg", "tags": ["fire"],
		"text": "Gain 7 morale. After a KIN card: +4 more.",
		"fx": {"morale": 7},
		"combo": {"if_tag": "kin", "bonus_morale": 4}
	},
	"scout_ahead": {
		"name": "Scout Ahead", "cost": 0, "type": "scout", "rarity": "starter",
		"art": "res://assets/art/chimney-rock.jpg", "tags": ["trail"],
		"text": "Read the trail. Draw 2 cards.",
		"fx": {"draw": 2}
	},
	"trading_ledger": {
		"name": "Trading Ledger", "cost": 2, "type": "supply", "rarity": "starter",
		"art": "res://assets/art/whiskey-ad.png", "tags": ["goods"],
		"text": "Gain 8 supplies. +3 per GOODS card this turn.",
		"fx": {"supplies": 8},
		"combo": {"per_tag": "goods", "bonus_supplies": 3}
	},
	"river_guide": {
		"name": "River Guide", "cost": 1, "type": "scout", "rarity": "common",
		"art": "res://assets/art/river-crossing.jpg", "tags": ["trail"],
		"text": "Cross safely. Gain 5 supplies, 2 morale.",
		"fx": {"supplies": 5, "morale": 2}
	},
	"wagon_repair": {
		"name": "Wagon Repair", "cost": 1, "type": "supply", "rarity": "common",
		"art": "res://assets/art/wagon-train.jpg", "tags": ["goods"],
		"text": "Patch the wagon. Gain 6 supplies.",
		"fx": {"supplies": 6}
	},
	"steady_nerve": {
		"name": "Steady Nerve", "cost": 1, "type": "morale", "rarity": "uncommon",
		"art": "res://assets/art/grizzly-vs-bison.png", "tags": ["fire"],
		"text": "Gain 10 morale and draw 1.",
		"fx": {"morale": 10, "draw": 1}
	},
	"trail_map": {
		"name": "Trail Map", "cost": 0, "type": "scout", "rarity": "uncommon",
		"art": "res://assets/art/compass.jpg", "tags": ["trail"],
		"text": "Shortcut: +2 supplies, -1 day, draw 1.",
		"fx": {"supplies": 2, "days": -1, "draw": 1}
	},
	"wainwright": {
		"name": "Wainwright", "cost": 0, "type": "supply", "rarity": "rare",
		"art": "res://assets/art/wagon-train.jpg", "tags": ["goods"],
		"text": "A perfect repair. Gain 10 supplies and draw 1.",
		"fx": {"supplies": 10, "draw": 1}
	},
	"revolver": {
		"name": "Revolver", "cost": 1, "type": "combat", "role": "attack", "rarity": "starter",
		"text": "Deal 7. +2 per GUN fired this turn.",
		"art": "res://assets/art/revolver-patent.jpg", "tags": ["gun"],
		"fx": {"enemy_damage": 7},
		"combo": {"per_tag": "gun", "bonus_damage": 2}
	},
	"lasso": {
		"name": "Lasso", "cost": 1, "type": "combat", "role": "control", "rarity": "starter",
		"text": "Deal 5, Block 5. Next GUN this turn hits DOUBLE.",
		"art": "res://assets/art/lasso.jpg", "tags": ["rope"],
		"fx": {"enemy_damage": 5, "block": 5},
		"combo": {"prime_tag": "gun", "mult": 2}
	},
	"rifle": {
		"name": "Winchester Rifle", "cost": 1, "type": "combat", "role": "attack", "rarity": "common",
		"text": "Deal 10. +3 per GUN fired this turn.",
		"art": "res://assets/art/rifle-winchester-ad.jpg", "tags": ["gun"],
		"fx": {"enemy_damage": 10},
		"combo": {"per_tag": "gun", "bonus_damage": 3}
	},
	"bowie_knife": {
		"name": "Bowie Knife", "cost": 0, "type": "combat", "role": "utility", "rarity": "starter",
		"text": "Deal 4, draw 1. After a GUN: +4 Block.",
		"art": "res://assets/art/bowie-knife.jpg", "tags": ["blade"],
		"fx": {"enemy_damage": 4, "block": 2, "draw": 1},
		"combo": {"if_tag": "gun", "bonus_block": 4}
	},
	"dynamite": {
		"name": "Dynamite", "cost": 3, "type": "combat", "role": "finisher", "rarity": "starter",
		"text": "Deal 14. Costs 1 less per card played this turn.",
		"art": "res://assets/art/dynamite-ad.jpg", "tags": ["fire"],
		"fx": {"enemy_damage": 14},
		"combo": {"discount_per_play": 1}
	},
	"medicine": {
		"name": "Medicine Chest", "cost": 1, "type": "supply", "rarity": "common",
		"art": "res://assets/art/medicine-ad.jpg", "tags": ["care"],
		"text": "Cure the worst-off member. Gain 2 morale.",
		"fx": {"cure": 1, "morale": 2}
	},
	"laudanum": {
		"name": "Laudanum", "cost": 1, "type": "morale", "role": "remedy", "rarity": "doctor",
		"art": "res://assets/art/whiskey-ad.png", "tags": ["care"],
		"text": "Gain 4 morale. Block 4.",
		"fx": {"morale": 4, "block": 4}
	},
	"scalpel": {
		"name": "Scalpel", "cost": 1, "type": "combat", "role": "precision", "rarity": "doctor",
		"art": "res://assets/art/medicine-ad.jpg", "tags": ["blade", "care"],
		"text": "Deal 6. +3 per CARE card this turn.",
		"fx": {"enemy_damage": 6},
		"combo": {"per_tag": "care", "bonus_damage": 3}
	},

	# ---- The Family: persistent party-member cards. "family" names the member;
	# ---- they can never leave the deck, they talk, they bond, they can die.
	"family_pa": {
		"name": "{name}'s Steady Hands", "cost": 1, "type": "supply", "role": "father", "rarity": "family", "tags": ["kin"],
		"family": "pa", "art": "res://assets/art/portraits/pa.png",
		"text": "Choose: gain 5 supplies, or repair the wagon by 5.",
		"fx": {"pa_choice": 5}
	},
	"family_pa_u": {
		"name": "{name}'s Steady Hands+", "cost": 1, "type": "supply", "role": "father", "rarity": "family", "tags": ["kin"],
		"family": "pa", "art": "res://assets/art/portraits/pa.png",
		"text": "Choose: gain 7 supplies, or repair the wagon by 7.",
		"fx": {"pa_choice": 7}
	},
	"family_pa_u2": {
		"name": "{name}'s Steady Hands++", "cost": 1, "type": "supply", "role": "father", "rarity": "family", "tags": ["kin"],
		"family": "pa", "art": "res://assets/art/portraits/pa.png",
		"text": "Choose: gain 7 supplies, or repair the wagon by 7. Draw 1.",
		"fx": {"pa_choice": 7, "draw": 1}
	},
	"family_ma": {
		"name": "{name}'s Resolve", "cost": 1, "type": "morale", "role": "mother", "rarity": "family", "tags": ["kin"],
		"family": "ma", "art": "res://assets/art/portraits/ma.png",
		"text": "Gain 6 morale. If morale is below 30, gain 10 instead.",
		"fx": {"morale_resolve": 6, "resolve_low_bonus": 4}
	},
	"family_ma_u": {
		"name": "{name}'s Resolve+", "cost": 1, "type": "morale", "role": "mother", "rarity": "family", "tags": ["kin"],
		"family": "ma", "art": "res://assets/art/portraits/ma.png",
		"text": "Gain 8 morale. If morale is below 30, gain 13 instead.",
		"fx": {"morale_resolve": 8, "resolve_low_bonus": 5}
	},
	"family_ma_u2": {
		"name": "{name}'s Resolve++", "cost": 1, "type": "morale", "role": "mother", "rarity": "family", "tags": ["kin"],
		"family": "ma", "art": "res://assets/art/portraits/ma.png",
		"text": "Gain 8 morale. If morale is below 30, gain 13 instead. Draw 1.",
		"fx": {"morale_resolve": 8, "resolve_low_bonus": 5, "draw": 1}
	},
	"family_sarah": {
		"name": "{name}'s Keen Eyes", "cost": 0, "type": "scout", "role": "kid", "rarity": "family", "tags": ["kin"],
		"family": "sarah", "art": "res://assets/art/portraits/sarah.png",
		"text": "Draw 1. {name} reveals what the next trail event asks for.",
		"fx": {"draw": 1, "reveal": 1}
	},
	"family_sarah_u": {
		"name": "{name}'s Keen Eyes+", "cost": 0, "type": "scout", "role": "kid", "rarity": "family", "tags": ["kin"],
		"family": "sarah", "art": "res://assets/art/portraits/sarah.png",
		"text": "Draw 2. {name} reveals what the next trail event asks for.",
		"fx": {"draw": 2, "reveal": 1}
	},
	"family_sarah_u2": {
		"name": "{name}'s Keen Eyes++", "cost": 0, "type": "scout", "role": "kid", "rarity": "family", "tags": ["kin"],
		"family": "sarah", "art": "res://assets/art/portraits/sarah.png",
		"text": "Draw 2, gain 2 morale. {name} reveals the next event's ask.",
		"fx": {"draw": 2, "reveal": 1, "morale": 2}
	},
	"family_dog": {
		"name": "{name}", "cost": 0, "type": "morale", "role": "good dog", "rarity": "family", "tags": ["kin"],
		"family": "dog", "art": "res://assets/art/portraits/dog.png",
		"text": "Gain 2 morale. In a fight: the next hit lands 2 lighter.",
		"fx": {"morale": 2, "threat": -2}
	},
	"family_dog_u": {
		"name": "{name}+", "cost": 0, "type": "morale", "role": "good dog", "rarity": "family", "tags": ["kin"],
		"family": "dog", "art": "res://assets/art/portraits/dog.png",
		"text": "Gain 3 morale. In a fight: the next hit lands 3 lighter.",
		"fx": {"morale": 3, "threat": -3}
	},
	"family_dog_u2": {
		"name": "{name}++", "cost": 0, "type": "morale", "role": "good dog", "rarity": "family", "tags": ["kin"],
		"family": "dog", "art": "res://assets/art/portraits/dog.png",
		"text": "Gain 3 morale, draw 1. In a fight: the next hit lands 3 lighter.",
		"fx": {"morale": 3, "threat": -3, "draw": 1}
	},
	"family_ox": {
		"name": "{name}", "cost": 2, "type": "supply", "role": "the ox", "rarity": "family", "tags": ["kin"],
		"family": "ox", "art": "res://assets/art/portraits/ox.png",
		"text": "The next leg of travel takes 1 fewer day.",
		"fx": {"travel_bonus": 1}
	},
	"family_ox_u": {
		"name": "{name}+", "cost": 1, "type": "supply", "role": "the ox", "rarity": "family", "tags": ["kin"],
		"family": "ox", "art": "res://assets/art/portraits/ox.png",
		"text": "The next leg of travel takes 1 fewer day.",
		"fx": {"travel_bonus": 1}
	},
	"family_ox_u2": {
		"name": "{name}++", "cost": 1, "type": "supply", "role": "the ox", "rarity": "family", "tags": ["kin"],
		"family": "ox", "art": "res://assets/art/portraits/ox.png",
		"text": "The next leg takes 1 fewer day. Forage 2 supplies on the move.",
		"fx": {"travel_bonus": 1, "supplies": 2}
	},

	# ---- Memory cards: what a family card becomes when that member dies.
	# ---- Exhausts when played (gone for the leg); returns each new leg.
	"memory_pa": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "pa", "memory": true, "exhaust": true,
		"text": "Gain 8 morale. Exhausts for the leg. It always comes back.",
		"fx": {"morale": 8}
	},
	"memory_ma": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "ma", "memory": true, "exhaust": true,
		"text": "Gain 8 morale. Exhausts for the leg. It always comes back.",
		"fx": {"morale": 8}
	},
	"memory_sarah": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "sarah", "memory": true, "exhaust": true,
		"text": "Gain 8 morale. Exhausts for the leg. It always comes back.",
		"fx": {"morale": 8}
	},
	"memory_dog": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "dog", "memory": true, "exhaust": true,
		"text": "Gain 8 morale. Exhausts for the leg. It always comes back.",
		"fx": {"morale": 8}
	},
	"memory_ox": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "ox", "memory": true, "exhaust": true,
		"text": "Gain 8 morale. Exhausts for the leg. It always comes back.",
		"fx": {"morale": 8}
	}
}

const STARTER_BASE := [
	"trail_rations", "trail_rations", "trail_rations",
	"forage", "forage", "forage",
	"campfire_stories", "campfire_stories",
	"scout_ahead", "trading_ledger",
	"family_pa", "family_ma", "family_sarah", "family_dog", "family_ox"
]

# Characters: each identity brings its own kit to the same family and trail.
const CHARACTERS := {
	"gunslinger": {
		"name": "THE GUNSLINGER",
		"blurb": "answers trouble with iron",
		"kit": ["revolver", "lasso", "bowie_knife", "dynamite"]
	},
	"doctor": {
		"name": "THE DOCTOR",
		"blurb": "keeps everybody breathing",
		"kit": ["lasso", "bowie_knife", "scalpel", "medicine", "medicine", "laudanum"]
	}
}

const STARTER_DECK := STARTER_BASE  # legacy alias; real decks come from deck_for()

static func deck_for(character: String) -> Array:
	var deck := STARTER_BASE.duplicate()
	var kit: Array = CHARACTERS.get(character, CHARACTERS["gunslinger"])["kit"]
	deck.append_array(kit)
	return deck
