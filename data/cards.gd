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
	# WAGERS make resource cards a gamble instead of a spreadsheet:
	#   per_pip + pip_supplies — roll 1d6, gain pip_supplies × the roll
	#   fail_on + fail_fx      — rolling at or under fail_on also triggers fail_fx
	# FUEL burns another card from hand as the price:
	#   base_morale + per_cost — morale = base + per_cost × the burned card's cost
	"trail_rations": {
		"name": "Trail Rations", "cost": 1, "type": "supply", "role": "quartermaster", "rarity": "starter",
		"art": "res://assets/art/wagon-train.jpg", "tags": ["goods"],
		"text": "-3 SUPPLIES → +6 MORALE.",
		"fx": {"supplies": -3, "morale": 6}
	},
	"forage": {
		"name": "Forage", "cost": 1, "type": "supply", "rarity": "starter",
		"art": "res://assets/art/bison-hunt.jpg", "tags": ["trail"],
		"text": "ROLL 1d6 → +2 SUPPLIES × ROLL. ON 1: WAGON -6.",
		"fx": {},
		"wager": {"pip_supplies": 2, "fail_on": 1, "fail_fx": {"wagon": -6}}
	},
	"campfire_stories": {
		"name": "Campfire Stories", "cost": 0, "type": "morale", "rarity": "starter",
		"art": "res://assets/art/campfire.jpg", "tags": ["fire"],
		"text": "FEED IT 1 CARD → MORALE +4 +3×COST.",
		"fx": {},
		"fuel": {"base_morale": 4, "per_cost": 3}
	},
	"scout_ahead": {
		"name": "Scout Ahead", "cost": 0, "type": "scout", "rarity": "starter",
		"art": "res://assets/art/chimney-rock.jpg", "tags": ["trail"],
		"text": "DRAW 2.",
		"fx": {"draw": 2}
	},
	"trading_ledger": {
		"name": "Trading Ledger", "cost": 2, "type": "supply", "rarity": "starter",
		"art": "res://assets/art/whiskey-ad.png", "tags": ["goods"],
		"text": "+8 SUPPLIES (+3 PER GOODS PLAYED).",
		"fx": {"supplies": 8},
		"combo": {"per_tag": "goods", "bonus_supplies": 3}
	},
	"river_guide": {
		"name": "River Guide", "cost": 1, "type": "scout", "rarity": "common",
		"art": "res://assets/art/river-crossing.jpg", "tags": ["trail"],
		"text": "+5 SUPPLIES, +2 MORALE.",
		"fx": {"supplies": 5, "morale": 2}
	},
	"wagon_repair": {
		"name": "Wagon Repair", "cost": 1, "type": "supply", "rarity": "common",
		"art": "res://assets/art/wagon-train.jpg", "tags": ["goods"],
		"text": "WAGON +8.",
		"fx": {"wagon": 8}
	},
	"steady_nerve": {
		"name": "Steady Nerve", "cost": 1, "type": "morale", "rarity": "uncommon",
		"art": "res://assets/art/grizzly-vs-bison.png", "tags": ["fire"],
		"text": "+10 MORALE. DRAW 1.",
		"fx": {"morale": 10, "draw": 1}
	},
	"trail_map": {
		"name": "Trail Map", "cost": 0, "type": "scout", "rarity": "uncommon",
		"art": "res://assets/art/compass.jpg", "tags": ["trail"],
		"text": "+2 SUPPLIES. -1 DAY. DRAW 1.",
		"fx": {"supplies": 2, "days": -1, "draw": 1}
	},
	"wainwright": {
		"name": "Wainwright", "cost": 0, "type": "supply", "rarity": "rare",
		"art": "res://assets/art/wagon-train.jpg", "tags": ["goods"],
		"text": "+10 SUPPLIES. DRAW 1.",
		"fx": {"supplies": 10, "draw": 1}
	},
	"revolver": {
		"name": "Revolver", "cost": 1, "type": "combat", "role": "attack", "rarity": "starter",
		"text": "DEAL 7 (+2 PER GUN PLAYED).",
		"art": "res://assets/art/revolver-patent.jpg", "tags": ["gun"],
		"fx": {"enemy_damage": 7},
		"combo": {"per_tag": "gun", "bonus_damage": 2}
	},
	"lasso": {
		"name": "Lasso", "cost": 1, "type": "combat", "role": "control", "rarity": "starter",
		"text": "DEAL 5, BLOCK 5. NEXT GUN ×2.",
		"art": "res://assets/art/lasso.jpg", "tags": ["rope"],
		"fx": {"enemy_damage": 5, "block": 5},
		"combo": {"prime_tag": "gun", "mult": 2}
	},
	"rifle": {
		"name": "Winchester Rifle", "cost": 1, "type": "combat", "role": "attack", "rarity": "common",
		"text": "DEAL 10 (+3 PER GUN PLAYED).",
		"art": "res://assets/art/rifle-winchester-ad.jpg", "tags": ["gun"],
		"fx": {"enemy_damage": 10},
		"combo": {"per_tag": "gun", "bonus_damage": 3}
	},
	"bowie_knife": {
		"name": "Bowie Knife", "cost": 0, "type": "combat", "role": "utility", "rarity": "starter",
		"text": "DEAL 4. DRAW 1. AFTER GUN: BLOCK +4.",
		"art": "res://assets/art/bowie-knife.jpg", "tags": ["blade"],
		"fx": {"enemy_damage": 4, "block": 2, "draw": 1},
		"combo": {"if_tag": "gun", "bonus_block": 4}
	},
	"dynamite": {
		"name": "Dynamite", "cost": 3, "type": "combat", "role": "finisher", "rarity": "starter",
		"text": "DEAL 14. COSTS -1 PER PLAY.",
		"art": "res://assets/art/dynamite-ad.jpg", "tags": ["fire"],
		"fx": {"enemy_damage": 14},
		"combo": {"discount_per_play": 1}
	},
	"medicine": {
		"name": "Medicine Chest", "cost": 1, "type": "supply", "rarity": "common",
		"art": "res://assets/art/medicine-ad.jpg", "tags": ["care"],
		"text": "CURE WORST-OFF. +2 MORALE.",
		"fx": {"cure": 1, "morale": 2}
	},
	"laudanum": {
		"name": "Laudanum", "cost": 1, "type": "morale", "role": "remedy", "rarity": "doctor",
		"art": "res://assets/art/whiskey-ad.png", "tags": ["care"],
		"text": "+4 MORALE. BLOCK 4.",
		"fx": {"morale": 4, "block": 4}
	},
	"scalpel": {
		"name": "Scalpel", "cost": 1, "type": "combat", "role": "precision", "rarity": "doctor",
		"art": "res://assets/art/medicine-ad.jpg", "tags": ["blade", "care"],
		"text": "DEAL 6 (+3 PER CARE PLAYED).",
		"fx": {"enemy_damage": 6},
		"combo": {"per_tag": "care", "bonus_damage": 3}
	},

	# ---- Statuses: junk the trail shoves into the deck. Unplayable, they
	# ---- hurt when drawn, and they burn away when the wagon rolls out.
	"dust_inhalation": {
		"name": "Dust Inhalation", "cost": 0, "type": "status", "rarity": "status", "tags": [],
		"unplayable": true, "art": "res://assets/art/prairie-fire.jpg",
		"text": "UNPLAYABLE. DRAWN: -1 GRIT.",
		"fx": {}, "on_draw": {"grit": -1}
	},
	"broken_axle": {
		"name": "Broken Axle", "cost": 0, "type": "status", "rarity": "status", "tags": [],
		"unplayable": true, "art": "res://assets/art/scene/event-breakdown.png",
		"text": "UNPLAYABLE. DRAWN: LOSES 2 CARDS.",
		"fx": {}, "on_draw": {"exhaust_random": 2}
	},

	# ---- The Family: persistent party-member cards. "family" names the member;
	# ---- they can never leave the deck, they talk, they bond, they can die.
	"family_pa": {
		"name": "{name}'s Steady Hands", "cost": 1, "type": "supply", "role": "father", "rarity": "family", "tags": ["kin"],
		"family": "pa", "art": "res://assets/sprites/family/pa.png",
		"text": "CHOOSE: +5 SUPPLIES / WAGON +5.",
		"fx": {"pa_choice": 5}
	},
	"family_pa_u": {
		"name": "{name}'s Steady Hands+", "cost": 1, "type": "supply", "role": "father", "rarity": "family", "tags": ["kin"],
		"family": "pa", "art": "res://assets/sprites/family/pa.png",
		"text": "CHOOSE: +7 SUPPLIES / WAGON +7.",
		"fx": {"pa_choice": 7}
	},
	"family_pa_u2": {
		"name": "{name}'s Steady Hands++", "cost": 1, "type": "supply", "role": "father", "rarity": "family", "tags": ["kin"],
		"family": "pa", "art": "res://assets/sprites/family/pa.png",
		"text": "CHOOSE: +7 SUPPLIES / WAGON +7. DRAW 1.",
		"fx": {"pa_choice": 7, "draw": 1}
	},
	"family_ma": {
		"name": "{name}'s Resolve", "cost": 1, "type": "morale", "role": "mother", "rarity": "family", "tags": ["kin"],
		"family": "ma", "art": "res://assets/sprites/family/ma.png",
		"text": "+6 MORALE. UNDER 30: +10.",
		"fx": {"morale_resolve": 6, "resolve_low_bonus": 4}
	},
	"family_ma_u": {
		"name": "{name}'s Resolve+", "cost": 1, "type": "morale", "role": "mother", "rarity": "family", "tags": ["kin"],
		"family": "ma", "art": "res://assets/sprites/family/ma.png",
		"text": "+8 MORALE. UNDER 30: +13.",
		"fx": {"morale_resolve": 8, "resolve_low_bonus": 5}
	},
	"family_ma_u2": {
		"name": "{name}'s Resolve++", "cost": 1, "type": "morale", "role": "mother", "rarity": "family", "tags": ["kin"],
		"family": "ma", "art": "res://assets/sprites/family/ma.png",
		"text": "+8 MORALE. UNDER 30: +13. DRAW 1.",
		"fx": {"morale_resolve": 8, "resolve_low_bonus": 5, "draw": 1}
	},
	"family_sarah": {
		"name": "{name}'s Keen Eyes", "cost": 0, "type": "scout", "role": "kid", "rarity": "family", "tags": ["kin"],
		"family": "sarah", "art": "res://assets/sprites/family/sarah.png",
		"text": "DRAW 1. REVEAL NEXT EVENT.",
		"fx": {"draw": 1, "reveal": 1}
	},
	"family_sarah_u": {
		"name": "{name}'s Keen Eyes+", "cost": 0, "type": "scout", "role": "kid", "rarity": "family", "tags": ["kin"],
		"family": "sarah", "art": "res://assets/sprites/family/sarah.png",
		"text": "DRAW 2. REVEAL NEXT EVENT.",
		"fx": {"draw": 2, "reveal": 1}
	},
	"family_sarah_u2": {
		"name": "{name}'s Keen Eyes++", "cost": 0, "type": "scout", "role": "kid", "rarity": "family", "tags": ["kin"],
		"family": "sarah", "art": "res://assets/sprites/family/sarah.png",
		"text": "DRAW 2, +2 MORALE. REVEAL EVENT.",
		"fx": {"draw": 2, "reveal": 1, "morale": 2}
	},
	"family_dog": {
		"name": "{name}", "cost": 0, "type": "morale", "role": "good dog", "rarity": "family", "tags": ["kin"],
		"family": "dog", "art": "res://assets/sprites/family/dog.png",
		"text": "+2 MORALE. ENEMY HIT -2.",
		"fx": {"morale": 2, "threat": -2}
	},
	"family_dog_u": {
		"name": "{name}+", "cost": 0, "type": "morale", "role": "good dog", "rarity": "family", "tags": ["kin"],
		"family": "dog", "art": "res://assets/sprites/family/dog.png",
		"text": "+3 MORALE. ENEMY HIT -3.",
		"fx": {"morale": 3, "threat": -3}
	},
	"family_dog_u2": {
		"name": "{name}++", "cost": 0, "type": "morale", "role": "good dog", "rarity": "family", "tags": ["kin"],
		"family": "dog", "art": "res://assets/sprites/family/dog.png",
		"text": "+3 MORALE, DRAW 1. ENEMY HIT -3.",
		"fx": {"morale": 3, "threat": -3, "draw": 1}
	},
	"family_ox": {
		"name": "{name}", "cost": 2, "type": "supply", "role": "the ox", "rarity": "family", "tags": ["kin"],
		"family": "ox", "art": "res://assets/sprites/family/ox.png",
		"text": "NEXT LEG: -1 DAY.",
		"fx": {"travel_bonus": 1}
	},
	"family_ox_u": {
		"name": "{name}+", "cost": 1, "type": "supply", "role": "the ox", "rarity": "family", "tags": ["kin"],
		"family": "ox", "art": "res://assets/sprites/family/ox.png",
		"text": "NEXT LEG: -1 DAY.",
		"fx": {"travel_bonus": 1}
	},
	"family_ox_u2": {
		"name": "{name}++", "cost": 1, "type": "supply", "role": "the ox", "rarity": "family", "tags": ["kin"],
		"family": "ox", "art": "res://assets/sprites/family/ox.png",
		"text": "NEXT LEG: -1 DAY. +2 SUPPLIES.",
		"fx": {"travel_bonus": 1, "supplies": 2}
	},

	# ---- Memory cards: what a family card becomes when that member dies.
	# ---- Exhausts when played (gone for the leg); returns each new leg.
	"memory_pa": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "pa", "memory": true, "exhaust": true,
		"text": "+8 MORALE. EXHAUSTS.",
		"fx": {"morale": 8}
	},
	"memory_ma": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "ma", "memory": true, "exhaust": true,
		"text": "+8 MORALE. EXHAUSTS.",
		"fx": {"morale": 8}
	},
	"memory_sarah": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "sarah", "memory": true, "exhaust": true,
		"text": "+8 MORALE. EXHAUSTS.",
		"fx": {"morale": 8}
	},
	"memory_dog": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "dog", "memory": true, "exhaust": true,
		"text": "+8 MORALE. EXHAUSTS.",
		"fx": {"morale": 8}
	},
	"memory_ox": {
		"name": "Memory of {name}", "cost": 0, "type": "morale", "rarity": "memory", "tags": ["kin"],
		"family": "ox", "memory": true, "exhaust": true,
		"text": "+8 MORALE. EXHAUSTS.",
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
