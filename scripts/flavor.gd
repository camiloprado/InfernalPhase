class_name Flavor
extends RefCounted

const START := [
	"INFERNAL PHASE — one floor, no campaign, no union break.",
	"The fire is complimentary. The rest is performance.",
]
const DEATH := [
	"You died. The floor files a complaint, then rewinds.",
	"Restarting. The imps already forgot your name.",
	"That was not a metaphor. You are ash. Press R.",
]


static func death_line() -> String:
	if Game.is_baby():
		return "The bebê is ash. The floor rewinds."
	var who := Game.body_name()
	var extra := [
		"%s is ash. The floor rewinds." % who,
		"The imps already forgot %s." % who,
	]
	if Game.rng.randf() < 0.45:
		return extra[Game.rng.randi() % extra.size()]
	return pick(DEATH)
const BOSS := [
	"THE INFERNAL PHASE — middle management of the damned.",
	"It brought a meeting. The agenda is bullets.",
]
const SPECIAL := [
	"A plus-sign, filed in triplicate.",
	"X. You are the signature.",
	"It slams the minutes shut.",
	"Lanes merge. You do not.",
	"A ring of policy. Stand inside.",
]
const WIN := [
	"The phase ends. You do not get a raise.",
	"Hell politely applauds. It will still be here tomorrow.",
]
const NPC := [
	"\"Doors stay shut until the room is clear. Liability. Hell has HR now.\"",
	"\"Boss is south. It asked not to be disturbed, which is a threat.\"",
	"\"If you die we restart the floor. Cheaper than grief counseling.\"",
]
const CLEAR := [
	"Doors unclench.",
	"The room exhales. You may leave.",
	"Clear. The ash settles in your favor.",
]


static func concierge_script() -> Array[Dictionary]:
	var who := "Bebê Chorão" if Game.is_baby() else Game.body_name()
	var reply := "I don't work here."
	if Game.is_baby():
		reply = "Waa—"
	elif Game.body == Game.Body.LILITH:
		reply = "I quit before I was hired."
	var lines: Array[Dictionary] = [
		{"who": "Concierge", "text": "Badge."},
		{"who": who, "text": reply},
	]
	if Game.is_baby():
		lines.append({"who": "Concierge", "text": "The crying one. Deflects. Fine. Don't get it on the desk."})
	else:
		lines.append({"who": "Concierge", "text": "Nobody works here. That's the trick. Take this — payroll would scream."})
	lines.append({"who": "Concierge", "text": "Doors stay shut until the room is clear. Liability. Hell has HR now."})
	lines.append({"who": "Concierge", "text": "Boss is south. It asked not to be disturbed, which is a threat."})
	lines.append({"who": "Concierge", "text": "Die and we rewind the floor. Cheaper than grief counseling."})
	lines.append({"who": "Concierge", "text": "E if you want the speech again. I get paid either way."})
	return lines


static func pick(lines: Array) -> String:
	return lines[Game.rng.randi_range(0, lines.size() - 1)]
