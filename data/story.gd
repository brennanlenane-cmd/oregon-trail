extends RefCounted
class_name TrailStory

# The narrative layer of The Long Trail. 1848, Independence to Oregon City.
# Period voice, restraint over melodrama. {name}-style slots are filled in main.gd.

const INTRO := "Independence, Missouri. Spring of 1848.\nEvery wagon on this field is a family betting everything they own against two thousand miles of weather, water, and luck. Yours is no different — except that it's yours.\nName them well. The trail will learn their names."

# One arrival vignette per landmark, shown when the wagon reaches the stop.
const VIGNETTES := {
	"Independence": "The jumping-off place. Mud, mules, and more hope than sense.",
	"Kansas River": "The ferryman counts coins with river-wrinkled hands. First water of consequence; the wagon floats like a promise kept.",
	"Fort Kearny": "Sod walls and a flag stiff with wind. Soldiers trade news for coffee: the season is early, the grass is good.",
	"Chimney Rock": "It rises for a full day before you reach it — a stone finger pointing at nothing. Everyone carves or paints a name. The rock keeps them all.",
	"Fort Laramie": "Adobe walls, trade blankets, the smell of cedar smoke. Half the trail's gossip is stacked on the sutler's porch.",
	"Independence Rock": "They say reach it by the Fourth of July or winter finds you in the mountains. The granite whale is scaled with ten thousand names.",
	"South Pass": "The spine of the continent, and it barely tilts the wagon bed. The water on the far side runs toward the Pacific now. So do you.",
	"Soda Springs": "The water fizzes like a peddler's tonic and tastes of iron and soda both. The oxen won't touch it. The children can't stop.",
	"Fort Hall": "A weathered post where the trail divides — California one way, Oregon the other. Men argue routes over the counter like preachers over scripture.",
	"Snake River": "Black rock and white water. The river runs in a trench it cut for itself, daring the thirsty to climb down.",
	"Blue Mountains": "Pine dark as evening all day long. The grades are cruel and the axle groans learn new notes.",
	"The Dalles": "The river narrows to a roar between basalt shelves. Wagons wait their turn for rafts, and the water keeps its own ledger.",
	"Barlow Pass": "The toll road around the mountain — steep enough that trees are your brakes. Mount Hood watches, wearing summer snow.",
	"Oregon City": "Falls thundering, sawmills shrieking, green in every direction. The end of the trail. The beginning of everything else."
}

# Engraving per landmark for the map backdrop.
const LANDMARK_ART := {
	"Independence": "res://assets/art/wagon-train.jpg",
	"Kansas River": "res://assets/art/river-crossing.jpg",
	"Fort Kearny": "res://assets/art/fort-laramie.jpg",
	"Chimney Rock": "res://assets/art/chimney-rock.jpg",
	"Fort Laramie": "res://assets/art/fort-laramie.jpg",
	"Independence Rock": "res://assets/art/independence-rock.jpg",
	"South Pass": "res://assets/art/mountain-pass.jpg",
	"Soda Springs": "res://assets/art/buffalo-river-crossing.jpg",
	"Fort Hall": "res://assets/art/general-store.jpg",
	"Snake River": "res://assets/art/river-crossing.jpg",
	"Blue Mountains": "res://assets/art/mountain-pass.jpg",
	"The Dalles": "res://assets/art/river-crossing.jpg",
	"Barlow Pass": "res://assets/art/mountain-pass.jpg",
	"Oregon City": "res://assets/art/gold-panning.jpg"
}

# Stops where the family sits down to write home. Sealing the letter is worth +2 morale.
const LETTER_STOPS := ["Fort Kearny", "Fort Laramie", "Fort Hall"]

const LETTER_OPENINGS := [
	"Dear Mother,\n\nWe are camped at %s, day %d on the road, and I am writing by firelight while the coffee argues with the pot.",
	"Dear Folks at Home,\n\nThis letter comes from %s. It is day %d of our journey and the wagon still rolls, which out here passes for good news.",
	"Dearest Family,\n\nWe have reached %s — day %d. The distances here would swallow the whole county and ask for the church besides."
]

const LETTER_CLOSINGS := [
	"Do not worry more than is proper. We are tougher than we look, and we looked plenty tough leaving.\n\nYour loving child of the trail.",
	"Kiss everyone for me and tell them the West is bigger than the preacher said and twice as loud.\n\nWith love from the road.",
	"If this reaches you before winter, know that we mean to beat it over the mountains. We are, as ever, westering.\n\nAll our love."
]

static func compose_letter(stop: String, day: int, party: Dictionary, graves: Array, supplies: int, member_order: Array) -> String:
	var text: String = LETTER_OPENINGS[randi() % LETTER_OPENINGS.size()] % [stop, day]
	var middle: Array[String] = []
	# The living, and how they're faring.
	for member_id in member_order:
		var member: Dictionary = party[member_id]
		if not member["alive"]:
			continue
		var member_name := str(member["name"])
		match int(member["condition"]):
			2:
				middle.append("%s has taken sick and we watch them close. Pray the medicine holds." % member_name)
			1:
				middle.append("%s is banged about but proud, and won't hear of riding in the bed." % member_name)
			_:
				if int(member["bond_level"]) >= 2:
					middle.append("%s has become the very heart of this outfit. You would hardly know them." % member_name)
				elif int(member["bond_level"]) >= 1:
					middle.append("%s grows steadier with every mile." % member_name)
	# The dead, plainly and gently.
	for grave in graves:
		middle.append("I must write it plain: we buried %s near %s. We marked the place well. The wagon is quieter than it was." % [grave["name"], grave["stop"]])
	# The larder.
	if supplies > 50:
		middle.append("The stores hold fine — we eat like harvest week, near enough.")
	elif supplies > 20:
		middle.append("Provisions are lean but honest. We trade a little and forage the rest.")
	else:
		middle.append("I will not lie to you: the flour barrel shows its bottom. We are careful, and we are quick about the hunting.")
	return text + "\n\n" + " ".join(middle) + "\n\n" + LETTER_CLOSINGS[randi() % LETTER_CLOSINGS.size()]

static func epilogue(won: bool, party: Dictionary, graves: Array, day: int, member_order: Array, cause: String) -> String:
	var survivors: Array[String] = []
	for member_id in member_order:
		if party[member_id]["alive"]:
			survivors.append(str(party[member_id]["name"]))
	if won:
		var lines: Array[String] = []
		lines.append("The wagon rolls down the last grade into Oregon City on day %d, wheels loud on planked road." % day)
		if graves.is_empty():
			lines.append("All of them made it. All of them. In the land office queue, nobody can stop grinning.")
		else:
			var grave_names: Array[String] = []
			for grave in graves:
				grave_names.append(str(grave["name"]))
			lines.append("%s stand in the land office queue. The claim form asks for the names of all settlers, and for a long moment the pen does not move — because %s should be on it." % [" and ".join([", ".join(survivors)]), " and ".join(grave_names)])
			lines.append("The claim is filed in their memory. The orchard, when it grows, will have their name on the sweetest row.")
		return "\n".join(lines)
	var cause_line := cause if not cause.is_empty() else "the trail simply took more than the wagon had"
	return "The journal's last page, day %d: %s. The names in this book deserved the valley. Some other spring, some other wagon will carry them the rest of the way." % [day, cause_line]
