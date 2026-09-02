extends Control

var rooms: Dictionary = {}
var current: Room

func _ready() -> void:
	custom_minimum_size = Vector2(140, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if rooms.is_empty():
		return
	var min_g := Vector2i(99, 99)
	var max_g := Vector2i(-99, -99)
	for g in rooms.keys():
		min_g.x = mini(min_g.x, g.x)
		min_g.y = mini(min_g.y, g.y)
		max_g.x = maxi(max_g.x, g.x)
		max_g.y = maxi(max_g.y, g.y)
	var cell := Vector2(22, 16)
	var gap := 4.0
	for g in rooms.keys():
		var room: Room = rooms[g]
		var p := Vector2((g.x - min_g.x) * (cell.x + gap), (g.y - min_g.y) * (cell.y + gap))
		var col := Palette.ASH_LIGHT
		if room.kind == Room.Kind.START:
			col = Palette.BONE_DIM
		elif room.kind == Room.Kind.NPC:
			col = Palette.ROBE_LIGHT
		elif room.kind == Room.Kind.BOSS:
			col = Palette.HELL_RED
		elif room.cleared:
			col = Palette.EMBER
		else:
			col = Palette.ASH_MID
		draw_rect(Rect2(p, cell), col)
		if room == current:
			draw_rect(Rect2(p, cell), Palette.EMBER_HOT, false, 2.0)
