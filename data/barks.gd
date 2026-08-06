extends RefCounted
class_name TrailBarks

# Bark tables for The Family. {name} is replaced with the player-given name.
# Categories: drawn, drawn_b1, drawn_b2 (bond unlocks merge into the drawn pool),
# low_morale (drawn while morale < 30), landmark, event_hint, sick, death, memory.
# Pa/Ma/Sarah speak in quotes; the dog and ox never use words — action lines only.

const BARKS := {
	"pa": {
		"drawn": [
			"{name}: \"Road's a bit stubborn today.\"",
			"{name}: \"We'll manage.\"",
			"{name}: \"Axle sounds honest enough.\"",
			"{name}: \"Weather's thinking about it.\"",
			"{name}: \"Long way yet. That's fine.\"",
			"{name}: \"Seen worse ruts.\"",
			"{name}: \"Oxen know the way by now.\"",
			"{name}: \"Nothing broke that won't mend.\"",
			"{name}: \"Grease the hubs at noon. That's all.\"",
			"{name}: \"Sky says maybe. Sky always says maybe.\"",
			"{name}: \"Two thousand miles is just one mile, repeated.\""
		],
		"drawn_b1": [
			"{name}: \"You drive better than I did.\"",
			"{name}: \"Proud of this outfit.\"",
			"{name}: \"Making good time, quiet-like.\"",
			"{name}: \"Packed right, as usual.\""
		],
		"drawn_b2": [
			"{name}: \"Never said — I was scared at the Kansas.\"",
			"{name}: \"Whatever comes, we already won some.\"",
			"{name}: \"Oregon's the excuse. This here's the thing.\"",
			"{name}: \"You got my steadiness. Better eyes, though.\""
		],
		"low_morale": [
			"{name}: \"Chin up. Wheels still turn.\"",
			"{name}: \"Bad stretch. Not a bad trail.\"",
			"{name}: \"We eat, we sleep, we go on.\"",
			"{name}: \"Storms pass. Always have.\""
		],
		"landmark": [
			"{name}: \"Mark it in the book.\"",
			"{name}: \"One more behind us.\"",
			"{name}: \"Told you we'd make it this far.\"",
			"{name}: \"Good ground for a rest.\"",
			"{name}: \"That's real progress, that is.\""
		],
		"event_hint": [
			"{name}: \"I'd go careful here.\"",
			"{name}: \"Slow is smooth.\"",
			"{name}: \"No shame in the long way.\"",
			"{name}: \"Don't spend what we can't count.\""
		],
		"sick": [
			"{name}: \"Just a cough. Keep rolling.\"",
			"{name}: \"Don't fuss over me.\"",
			"{name}: \"I'll walk it off.\""
		],
		"death": ["{name}: \"Keep 'em moving west.\""],
		"memory": ["You hear {name} say it plain: \"We'll manage.\""]
	},
	"ma": {
		"drawn": [
			"{name}: \"Everyone's fed. Everyone's counted.\"",
			"{name}: \"Mended the canvas twice already.\"",
			"{name}: \"Sing something, would you?\"",
			"{name}: \"We didn't come this far to sulk.\"",
			"{name}: \"There's coffee if you're kind.\"",
			"{name}: \"The little one slept warm. That's a win.\"",
			"{name}: \"I keep the list. The list keeps us.\"",
			"{name}: \"Wash day when we hit the river.\"",
			"{name}: \"I traded two buttons for salt. Good buttons, better salt.\"",
			"{name}: \"Whoever named it Sweetwater never drank here.\"",
			"{name}: \"The dough rises even out here. So do we.\""
		],
		"drawn_b1": [
			"{name}: \"You're doing fine. I mean it.\"",
			"{name}: \"I was wrong about this trip. Mostly.\"",
			"{name}: \"We're stronger than Independence ever saw.\"",
			"{name}: \"I'd pick this family again.\""
		],
		"drawn_b2": [
			"{name}: \"My mother crossed an ocean. This is ours.\"",
			"{name}: \"When we get there, I want an orchard.\"",
			"{name}: \"Fear's just love with nowhere to go.\"",
			"{name}: \"You'll tell this story someday. Tell it true.\""
		],
		"low_morale": [
			"{name}: \"We are NOT done. Eat something.\"",
			"{name}: \"Cry tonight. Roll at dawn.\"",
			"{name}: \"I've stitched worse days together.\"",
			"{name}: \"Hold my hand. Now walk.\""
		],
		"landmark": [
			"{name}: \"Mark the miles, not the misses.\"",
			"{name}: \"It goes in the letter home.\"",
			"{name}: \"See? Told you. Onward.\"",
			"{name}: \"New ground. Same family.\"",
			"{name}: \"We earned this view.\""
		],
		"event_hint": [
			"{name}: \"Kindness has paid before.\"",
			"{name}: \"Take the sure thing.\"",
			"{name}: \"Think of the children first.\"",
			"{name}: \"We can spare it. Barely.\""
		],
		"sick": [
			"{name}: \"It's nothing. Mind the fire.\"",
			"{name}: \"I'll sit. Just a minute.\"",
			"{name}: \"Don't you dare slow down for me.\""
		],
		"death": ["{name}: \"Look after each other. Promise me.\""],
		"memory": ["You hear {name} counting everyone, soft and sure."]
	},
	"sarah": {
		"drawn": [
			"{name}: \"I counted forty prairie dogs!\"",
			"{name}: \"River looks angry today.\"",
			"{name}: \"Can I ride up front?\"",
			"{name}: \"I found a blue feather!\"",
			"{name}: \"Race you to that rock!\"",
			"{name}: \"The clouds look like oxen.\"",
			"{name}: \"I'm keeping a rock from every stop.\"",
			"{name}: \"Something smells funny up ahead.\"",
			"{name}: \"I taught Biscuit to shake. Sort of.\"",
			"{name}: \"Do clouds get tired? I get tired.\"",
			"{name}: \"When I blink fast the wagon looks like it's flying.\""
		],
		"drawn_b1": [
			"{name}: \"I'm not scared anymore. Mostly.\"",
			"{name}: \"I got to hold the reins!\"",
			"{name}: \"I'll spot Oregon first. Bet you.\"",
			"{name}: \"My rock collection weighs a POUND.\""
		],
		"drawn_b2": [
			"{name}: \"When I grow up, I'll map trails.\"",
			"{name}: \"I named every star we slept under.\"",
			"{name}: \"Best worst trip ever.\"",
			"{name}: \"I'll remember all of it. All.\""
		],
		"low_morale": [
			"{name}: \"Is everybody okay?\"",
			"{name}: \"I can share my biscuit.\"",
			"{name}: \"I'll sing the counting song?\"",
			"{name}: \"Are we almost there?\""
		],
		"landmark": [
			"{name}: \"NEW PLACE! New rock!\"",
			"{name}: \"I saw it first! I SAW it!\"",
			"{name}: \"Does it have a name? Can I name it?\"",
			"{name}: \"Wait till the letter home hears THIS!\""
		],
		"event_hint": [
			"{name}: \"Ooh, let's find out!\"",
			"{name}: \"I wanna see!\"",
			"{name}: \"Please can we try it?\"",
			"{name}: \"I have a good feeling!\""
		],
		"sick": [
			"{name}: \"*cough* I'm fine. Honest.\"",
			"{name}: \"My tummy's just tired.\""
		],
		"death": ["The wagon is very, very quiet."],
		"memory": ["A blue feather is still tucked in the canvas."]
	},
	"dog": {
		"drawn": [
			"{name} wags at the whole horizon.",
			"Woof!",
			"{name} trots a proud little circle.",
			"A wet nose checks on everyone in turn.",
			"{name} points at nothing. Growls anyway.",
			"Tail thump. Thump. Thump.",
			"{name} found a smell. THE smell.",
			"Ears up. On duty.",
			"{name} herds a confused chicken back to its wagon.",
			"A yawn that ends in a tiny howl.",
			"{name} is 100% certain about that bush. Certain."
		],
		"drawn_b1": [
			"{name} sleeps across the little one's feet now.",
			"One short bark: all present.",
			"{name} knows the wagon's creaks by heart.",
			"The whole camp is his to guard."
		],
		"drawn_b2": [
			"{name} walks point like he was born to it.",
			"Gray at the muzzle. Steady in the eyes.",
			"He'd follow you past Oregon.",
			"Best dog. The very best."
		],
		"low_morale": [
			"A heavy head lands on your knee.",
			"{name} leans in, warm and certain.",
			"A soft whine. He knows.",
			"He licks your hand until you laugh."
		],
		"landmark": [
			"{name} marks the new territory. Twice.",
			"Zoomies clean around the wagon!",
			"A triumphant howl for the map.",
			"New smells. A GREAT day."
		],
		"event_hint": [
			"{name} growls low at that one.",
			"{name}'s tail approves.",
			"Ears flat. He doesn't like it.",
			"A single hopeful bark!"
		],
		"sick": [
			"{name}'s nose is warm. He won't eat.",
			"The tail barely moves today."
		],
		"death": ["The wagon rolls on. Nothing runs beside it."],
		"memory": ["You remember {name} chasing prairie dogs."]
	},
	"ox": {
		"drawn": [
			"{name} leans in. The wagon obeys.",
			"A slow blink. All is well.",
			"{name} snorts at the horizon.",
			"The yoke creaks; {name} doesn't.",
			"One heavy hoof after another. Forever.",
			"{name} smells rain before the sky does.",
			"The big head swings, counting his people.",
			"Muscle like a hillside. Patience like one too.",
			"{name} chews. The horizon can wait.",
			"A fly lands on {name}. It is ignored into leaving.",
			"The grade steepens. {name} does not notice."
		],
		"drawn_b1": [
			"{name} takes the grade without being asked.",
			"He eats from the little one's hand now.",
			"The other animals stand near him in storms.",
			"{name} hauls like the trail owes him money."
		],
		"drawn_b2": [
			"Scars, miles, and not one step backward.",
			"He knows 'Oregon' means 'rest'. Almost there.",
			"The wagon and {name} are one animal now.",
			"Mountains move for patient things."
		],
		"low_morale": [
			"{name} stands close. A warm wall.",
			"A deep, steadying breath beside you.",
			"He lows once, softly, at the dark.",
			"Still here. Still pulling."
		],
		"landmark": [
			"{name} drinks like a lake is a job.",
			"A long, satisfied bellow.",
			"He rests one hip. Milestone acknowledged.",
			"Grass inspection: passed."
		],
		"event_hint": [
			"{name} plants his hooves at that one.",
			"He swings his head toward the safer road.",
			"An approving rumble.",
			"{name} won't budge toward it."
		],
		"sick": [
			"{name}'s head hangs low.",
			"The pulling is slower today."
		],
		"death": ["The yoke sits empty. The hills feel steeper."],
		"memory": ["The wagon still leans the way {name} pulled."]
	}
}

static func pick(member_id: String, category: String, member_name: String, bond_level: int = 0) -> String:
	if not BARKS.has(member_id):
		return ""
	var member_table: Dictionary = BARKS[member_id]
	var pool: Array = []
	if member_table.has(category):
		pool = (member_table[category] as Array).duplicate()
	# Bond levels widen the drawn pool with more personal lines.
	if category == "drawn":
		if bond_level >= 1 and member_table.has("drawn_b1"):
			pool.append_array(member_table["drawn_b1"])
		if bond_level >= 2 and member_table.has("drawn_b2"):
			pool.append_array(member_table["drawn_b2"])
	if pool.is_empty():
		return ""
	var line: String = pool[randi() % pool.size()]
	return line.replace("{name}", member_name)
