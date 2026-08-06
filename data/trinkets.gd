extends RefCounted
class_name TrailTrinkets

# Keepsakes: always-on rule changes, one clause each (the relic layer).
# Tonics: three belt slots, drink anytime, gone forever (the potion layer).

const KEEPSAKES := {
	"powder_horn": {
		"name": "Powder Horn", "glyph": "⚡",
		"text": "The first combat card you play each fight costs no Grit."
	},
	"worn_stethoscope": {
		"name": "Worn Stethoscope", "glyph": "♥",
		"text": "Every cure also steadies the party: +4 morale."
	},
	"ox_shoe": {
		"name": "Ox Shoe", "glyph": "◎",
		"text": "Every 4th leg of travel takes 1 fewer day."
	},
	"hymnal": {
		"name": "Hymnal", "glyph": "♪",
		"text": "Bracing steadies the party: +2 morale."
	},
	"iron_skillet": {
		"name": "Iron Skillet", "glyph": "◐",
		"text": "Supply cards yield 1 more supply."
	},
	"daguerreotype": {
		"name": "Daguerreotype", "glyph": "❦",
		"text": "Memories comfort for 4 more morale."
	},
	"snake_oil_bottle": {
		"name": "Snake Oil", "glyph": "$",
		"text": "Sutler prices are 20% lower."
	},
	"rabbits_foot": {
		"name": "Rabbit's Foot", "glyph": "☘",
		"text": "Sickness risks are half as likely."
	},
	"spare_axle": {
		"name": "Spare Axle", "glyph": "✚",
		"text": "The wagon takes 2 less damage from every hit."
	},
	"grandmas_quilt": {
		"name": "Grandma's Quilt", "glyph": "▦",
		"text": "Sealing a letter home gives +5 morale instead of +2."
	},
	"lucky_arrowhead": {
		"name": "Lucky Arrowhead", "glyph": "➳",
		"text": "Won fights pay $3 more."
	},
	"old_fiddle": {
		"name": "Old Fiddle", "glyph": "♫",
		"text": "Reaching a landmark lifts morale by 2."
	}
}

const STARTING_KEEPSAKE := {
	"gunslinger": "powder_horn",
	"doctor": "worn_stethoscope"
}

# Keepsakes that can appear in shops / milestone drops (not the two starters).
const KEEPSAKE_POOL := [
	"ox_shoe", "hymnal", "iron_skillet", "daguerreotype", "snake_oil_bottle",
	"rabbits_foot", "spare_axle", "grandmas_quilt", "lucky_arrowhead", "old_fiddle"
]

const TONICS := {
	"coffee": {
		"name": "Strong Coffee", "glyph": "☕",
		"text": "+1 Grit, right now."
	},
	"bitters": {
		"name": "Bitters", "glyph": "◆",
		"text": "+8 morale."
	},
	"laudanum_draught": {
		"name": "Laudanum Draught", "glyph": "☾",
		"text": "In a fight: block the next 8 damage."
	},
	"snakebite_kit": {
		"name": "Snakebite Kit", "glyph": "✚",
		"text": "Fully cure the worst-off family member."
	},
	"gunpowder_sachet": {
		"name": "Gunpowder Sachet", "glyph": "✸",
		"text": "In a fight: deal 10 damage."
	},
	"hardtack": {
		"name": "Hardtack", "glyph": "▣",
		"text": "+10 supplies."
	}
}

const TONIC_POOL := ["coffee", "bitters", "laudanum_draught", "snakebite_kit", "gunpowder_sachet", "hardtack"]
