class_name Flavor
extends RefCounted

const DEATH_COUNT := 3
const SPECIAL_COUNT := 5
const NPC_COUNT := 3
const CLEAR_COUNT := 3


static func start(i: int) -> String:
	return Locale.t("start.%d" % i)


static func boss(i: int) -> String:
	return Locale.t("boss.%d" % i)


static func special(i: int) -> String:
	return Locale.t("special.%d" % i)


static func win(i: int) -> String:
	return Locale.t("win.%d" % i)


static func win_line() -> String:
	return win(Game.rng.randi_range(0, 1))


static func npc_line(i: int) -> String:
	return Locale.t("npc.%d" % (posmod(i, NPC_COUNT)))


static func clear_line() -> String:
	return Locale.t("clear.%d" % Game.rng.randi_range(0, CLEAR_COUNT - 1))


static func death_line() -> String:
	if Game.is_baby():
		return Locale.t("death.baby")
	var who := Game.body_name()
	if Game.rng.randf() < 0.45:
		if Game.rng.randf() < 0.5:
			return Locale.t("death.who") % who
		return Locale.t("death.forgot") % who
	return Locale.t("death.%d" % Game.rng.randi_range(0, DEATH_COUNT - 1))


static func concierge_script() -> Array[Dictionary]:
	var who := "Bebê Chorão" if Game.is_baby() else Game.body_name()
	var reply := Locale.t("talk.caim")
	if Game.is_baby():
		reply = Locale.t("talk.baby")
	elif Game.body == Game.Body.LILITH:
		reply = Locale.t("talk.lilith")
	var lines: Array[Dictionary] = [
		{"who": "Concierge", "text": Locale.t("talk.badge")},
		{"who": who, "text": reply},
	]
	if Game.is_baby():
		lines.append({"who": "Concierge", "text": Locale.t("talk.cry")})
	else:
		lines.append({"who": "Concierge", "text": Locale.t("talk.payroll")})
	lines.append({"who": "Concierge", "text": Locale.t("talk.doors")})
	lines.append({"who": "Concierge", "text": Locale.t("talk.south")})
	lines.append({"who": "Concierge", "text": Locale.t("talk.rewind")})
	lines.append({"who": "Concierge", "text": Locale.t("talk.again")})
	return lines
