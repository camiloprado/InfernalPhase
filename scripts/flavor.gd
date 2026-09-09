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
	"A hole in the policy. Use it.",
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


static func pick(lines: Array) -> String:
	return lines[Game.rng.randi_range(0, lines.size() - 1)]
