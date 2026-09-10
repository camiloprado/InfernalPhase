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
	var r := 7.0
	var gap := 6.0
	var step := r * 2.0 + gap
	for g in rooms.keys():
		var room: Room = rooms[g]
		var p := Vector2((g.x - min_g.x) * step + r + 2.0, (g.y - min_g.y) * step + r + 2.0)
		var col := Palette.ASH
		if room.kind == Room.Kind.START:
			col = Palette.BONE_DIM
		elif room.kind == Room.Kind.NPC:
			col = Palette.BONE_DIM
		elif room.kind == Room.Kind.BOSS:
			col = Palette.WOUND
		elif room.cleared:
			col = Palette.BONE_DIM
		else:
			col = Palette.ASH_MID
		draw_circle(p, r, col)
		if room == current:
			draw_arc(p, r + 3.0, 0.0, TAU, 18, Palette.BONE, 2.0, true)
