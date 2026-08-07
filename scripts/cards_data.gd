extends RefCounted
class_name CardsData

# THE DESIGN MANDATE: zero flat arithmetic. Every card is an exhaust, a wager,
# a discard, or a wound — friction on every face. Rules text: verb-first,
# uppercase, max 6 words.
#
# Mechanics vocabulary (the `mech` dictionary):
#   {"wager": {"per_pip": {...}, "fail_on": n, "fail_fx": {...}}}  1d6 push-your-luck
#   {"fuel": {"base": n, "per_cost": n, "stat": "..."}}            discard 1 → pay by its cost
#   {"spend": {...}, "gain": {...}}                                 trade one stat for another
#   {"exhaust": true, ...}                                          gone for the leg when played
#   {"deal": n, "block": n, "combo": {...}}                         fight verbs (per-tag chains)
#   {"self_fx": {...}}                                              wound-priced effects

const CARDS_DATA: Array = [
	# ---- The six anti-boring utility cards ----
	{
		"id": "forage", "title": "FORAGE", "cost": 1, "tag": "TRAIL",
		"rules_text": "WAGER 1d6 → SUPPLIES ×2. 1: WAGON -6.",
		"art": "res://assets/art/bison-hunt.jpg",
		"mech": {"wager": {"per_pip": {"supplies": 2}, "fail_on": 1, "fail_fx": {"wagon": -6}}}
	},
	{
		"id": "hunt", "title": "HUNT", "cost": 1, "tag": "GUN",
		"rules_text": "EXHAUST. WAGER 1d6 → SUPPLIES ×3. 1-2: MORALE -4.",
		"art": "res://assets/art/rifle-winchester-ad.jpg",
		"mech": {"exhaust": true, "wager": {"per_pip": {"supplies": 3}, "fail_on": 2, "fail_fx": {"morale": -4}}}
	},
	{
		"id": "campfire_stories", "title": "CAMPFIRE STORIES", "cost": 0, "tag": "FIRE",
		"rules_text": "FEED IT 1 CARD → MORALE 4+3×COST.",
		"art": "res://assets/art/campfire.jpg",
		"mech": {"fuel": {"base": 4, "per_cost": 3, "stat": "morale"}}
	},
	{
		"id": "mend_wheel", "title": "MEND THE WHEEL", "cost": 0, "tag": "GOODS",
		"rules_text": "DISCARD 1 [GOODS] → WAGON +8.",
		"art": "res://assets/art/wagon-train.jpg",
		"mech": {"discard_tag": "GOODS", "gain": {"wagon": 8}, "fallback_fx": {"wagon": 2}}
	},
	{
		"id": "scout_ahead", "title": "SCOUT AHEAD", "cost": 0, "tag": "TRAIL",
		"rules_text": "EXHAUST: DRAW 3.",
		"art": "res://assets/art/chimney-rock.jpg",
		"mech": {"exhaust": true, "draw": 3}
	},
	{
		"id": "trail_rations", "title": "TRAIL RATIONS", "cost": 1, "tag": "GOODS",
		"rules_text": "SPEND 3 SUPPLIES → MORALE +6.",
		"art": "res://assets/art/general-store.jpg",
		"mech": {"spend": {"supplies": 3}, "gain": {"morale": 6}}
	},

	# ---- The fight kit (combo grammar carried from v0) ----
	{
		"id": "revolver", "title": "REVOLVER", "cost": 1, "tag": "GUN",
		"rules_text": "DEAL 7 (+2 PER [GUN] PLAYED).",
		"art": "res://assets/art/revolver-patent.jpg",
		"mech": {"deal": 7, "combo": {"per_tag": "GUN", "bonus_deal": 2}}
	},
	{
		"id": "lasso", "title": "LASSO", "cost": 1, "tag": "ROPE",
		"rules_text": "DEAL 5, BLOCK 5. NEXT [GUN] ×2.",
		"art": "res://assets/art/lasso.jpg",
		"mech": {"deal": 5, "block": 5, "combo": {"prime_tag": "GUN", "mult": 2}}
	},
	{
		"id": "bowie_knife", "title": "BOWIE KNIFE", "cost": 0, "tag": "BLADE",
		"rules_text": "DEAL 4. AFTER [GUN]: BLOCK +4.",
		"art": "res://assets/art/bowie-knife.jpg",
		"mech": {"deal": 4, "block": 2, "combo": {"if_tag": "GUN", "bonus_block": 4}}
	},
	{
		"id": "dynamite", "title": "DYNAMITE", "cost": 3, "tag": "FIRE",
		"rules_text": "DEAL 14. COSTS -1 PER PLAY.",
		"art": "res://assets/art/dynamite-ad.jpg",
		"mech": {"deal": 14, "combo": {"discount_per_play": 1}}
	},
	{
		"id": "medicine", "title": "MEDICINE CHEST", "cost": 1, "tag": "CARE",
		"rules_text": "EXHAUST: CURE 1 [KIN].",
		"art": "res://assets/art/medicine-ad.jpg",
		"mech": {"exhaust": true, "cure": 1}
	},

	# ---- Reward-pool cards: what the deck BUILDS toward ----
	{
		"id": "rifle", "title": "WINCHESTER RIFLE", "cost": 1, "tag": "GUN",
		"rules_text": "DEAL 10 (+3 PER [GUN] PLAYED).",
		"art": "res://assets/art/rifle-winchester-ad.jpg",
		"mech": {"deal": 10, "combo": {"per_tag": "GUN", "bonus_deal": 3}}
	},
	{
		"id": "scattergun", "title": "SCATTERGUN", "cost": 1, "tag": "GUN",
		"rules_text": "WAGER 1d6 → DEAL 3×ROLL.",
		"art": "res://assets/art/revolver-patent.jpg",
		"mech": {"wager": {"per_pip": {"deal": 3}}}
	},
	{
		"id": "steady_nerve", "title": "STEADY NERVE", "cost": 1, "tag": "FIRE",
		"rules_text": "BLOCK 8. DRAW 1.",
		"art": "res://assets/art/grizzly-vs-bison.png",
		"mech": {"block": 8, "draw": 1}
	},
	{
		"id": "laudanum", "title": "LAUDANUM", "cost": 1, "tag": "CARE",
		"rules_text": "BLOCK 6. EXHAUST: CURE 1 [KIN].",
		"art": "res://assets/art/whiskey-ad.png",
		"mech": {"exhaust": true, "block": 6, "cure": 1}
	},
	{
		"id": "trail_map", "title": "TRAIL MAP", "cost": 0, "tag": "TRAIL",
		"rules_text": "EXHAUST: NEXT LEG -1 DAY.",
		"art": "res://assets/art/compass.jpg",
		"mech": {"exhaust": true, "travel_bonus": 1}
	},

	# ---- Statuses: junk the trail shoves into the deck. Unplayable; they
	# ---- bite when drawn and burn off when the wagon rolls out.
	{
		"id": "dust_inhalation", "title": "DUST INHALATION", "cost": 0, "tag": "",
		"rules_text": "UNPLAYABLE. DRAWN: -1 GRIT.",
		"art": "res://assets/art/prairie-fire.jpg",
		"status": true, "mech": {}, "on_draw": {"grit": -1}
	},
	{
		"id": "broken_axle", "title": "BROKEN AXLE", "cost": 0, "tag": "",
		"rules_text": "UNPLAYABLE. DRAWN: LOSES 2 CARDS.",
		"art": "res://assets/art/scene/event-breakdown.png",
		"status": true, "mech": {}, "on_draw": {"exhaust_random": 2}
	},

	# ---- The family: permanent KIN. Right-click = STOKE (+1 grit, +1 draw,
	# ---- spent for the leg, night sickness risk). That IS their economy.
	{
		"id": "kin_pa", "title": "PA'S STEADY HANDS", "cost": 1, "tag": "KIN", "kin": "pa",
		"rules_text": "CHOOSE: SUPPLIES +5 / WAGON +5.",
		"art": "res://assets/sprites/family/pa.png",
		"mech": {"choice": {"a": {"supplies": 5}, "b": {"wagon": 5}}}
	},
	{
		"id": "kin_ma", "title": "MA'S RESOLVE", "cost": 1, "tag": "KIN", "kin": "ma",
		"rules_text": "MORALE +6. UNDER 30: +10.",
		"art": "res://assets/sprites/family/ma.png",
		"mech": {"resolve": {"base": 6, "low": 10, "threshold": 30}}
	},
	{
		"id": "kin_sarah", "title": "SARAH'S KEEN EYES", "cost": 0, "tag": "KIN", "kin": "sarah",
		"rules_text": "DRAW 1. REVEAL NEXT HAZARD.",
		"art": "res://assets/sprites/family/sarah.png",
		"mech": {"draw": 1, "reveal": true}
	},
	{
		"id": "kin_dog", "title": "THE DOG", "cost": 0, "tag": "KIN", "kin": "dog",
		"rules_text": "MORALE +2. ENEMY HIT -2.",
		"art": "res://assets/sprites/family/dog.png",
		"mech": {"gain": {"morale": 2}, "threat": -2}
	},
	{
		"id": "kin_ox", "title": "THE OX", "cost": 2, "tag": "KIN", "kin": "ox",
		"rules_text": "NEXT LEG: -1 DAY.",
		"art": "res://assets/sprites/family/ox.png",
		"mech": {"travel_bonus": 1}
	}
]

const STARTER_DECK := [
	"forage", "forage", "hunt", "campfire_stories", "campfire_stories",
	"mend_wheel", "scout_ahead", "trail_rations", "trail_rations",
	"revolver", "lasso", "bowie_knife", "dynamite",
	"kin_pa", "kin_ma", "kin_sarah", "kin_dog", "kin_ox"
]

# What the SPOILS screen deals from — the deck-building menu.
const REWARD_POOL := [
	"rifle", "scattergun", "steady_nerve", "laudanum", "trail_map",
	"revolver", "forage", "hunt", "medicine", "campfire_stories", "mend_wheel"
]

static func by_id(card_id: String) -> Dictionary:
	for card in CARDS_DATA:
		if str(card["id"]) == card_id:
			return card
	return {}
