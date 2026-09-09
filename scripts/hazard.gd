class_name Hazard
extends Node2D
## Telegraphed area attack used by The Infernal Phase.

enum Kind { CROSS, DIAG, SLAM, LANES, RING }

var kind: Kind = Kind.CROSS
var telegraph := 0.9
var active := 0.45
var age := 0.0
var hot := false
var origin := Vector2.ZERO
var room_rect := Rect2()
var bar_w := 112.0
var slam_r := 72.0
var slam_max := 300.0
var safe_lane := 1
var ring_inner := 96.0
var ring_outer := 520.0
var lane_h := 168.0
var inner_top := 0.0


func setup(p_kind: int, p_origin: Vector2, room: Room) -> void:
	kind = p_kind as Kind
	origin = p_origin
	z_index = 12
	var inset := Game.WALL + 8.0
	room_rect = Rect2(room.global_position + Vector2(inset, inset), room.size - Vector2(inset * 2.0, inset * 2.0))
	inner_top = room_rect.position.y
	lane_h = room_rect.size.y / 3.0
	match kind:
		Kind.CROSS:
			telegraph = 0.9
			active = 0.42
			bar_w = 118.0
		Kind.DIAG:
			telegraph = 0.9
			active = 0.42
			bar_w = 108.0
		Kind.SLAM:
			telegraph = 0.72
			active = 0.78
			slam_r = 64.0
			slam_max = 310.0
		Kind.LANES:
			telegraph = 1.0
			active = 0.48
			safe_lane = Game.rng.randi() % 3
		Kind.RING:
			telegraph = 1.05
			active = 0.5
			ring_inner = 100.0
			ring_outer = maxf(room_rect.size.x, room_rect.size.y) * 0.72
	Game.shake.emit(7.0)
	if kind == Kind.RING:
		_mark_hole()


func _mark_hole() -> void:
	# The RING special's safe inner disk is the buraco — same pit art, not a floor tile.
	var spr := Sprite2D.new()
	if ResourceLoader.exists("res://assets/env/pit.png"):
		spr.texture = load("res://assets/env/pit.png") as Texture2D
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = to_local(origin)
	if spr.texture:
		var tex_w := float(spr.texture.get_width())
		if tex_w > 1.0:
			spr.scale = Vector2.ONE * ((ring_inner * 2.0) / tex_w)
	spr.z_index = -1
	add_child(spr)
	if spr.texture == null:
		spr.queue_free()


func _physics_process(delta: float) -> void:
	age += delta
	if not hot and age >= telegraph:
		hot = true
		Game.shake.emit(14.0)
	if hot and kind == Kind.SLAM:
		var t := clampf((age - telegraph) / maxf(active, 0.01), 0.0, 1.0)
		slam_r = lerpf(64.0, slam_max, t)
	if age >= telegraph + active:
		queue_free()
		return
	if hot:
		_try_hit()
	queue_redraw()


func _try_hit() -> void:
	if Game.is_dead or Game.is_won:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if _contains(player.global_position):
		player.take_hit(self)


func _contains(p: Vector2) -> bool:
	if not room_rect.has_point(p):
		return false
	match kind:
		Kind.CROSS:
			return absf(p.x - origin.x) <= bar_w * 0.5 or absf(p.y - origin.y) <= bar_w * 0.5
		Kind.DIAG:
			return _line_dist(p, Vector2.ONE) <= bar_w * 0.5 or _line_dist(p, Vector2(1, -1)) <= bar_w * 0.5
		Kind.SLAM:
			return p.distance_to(origin) <= slam_r
		Kind.LANES:
			var i := int(clampf((p.y - inner_top) / lane_h, 0.0, 2.0))
			return i != safe_lane
		Kind.RING:
			var d := p.distance_to(origin)
			return d >= ring_inner and d <= ring_outer
	return false


func _line_dist(p: Vector2, dir: Vector2) -> float:
	var d := dir.normalized()
	var v := p - origin
	return absf(v.x * d.y - v.y * d.x)


func _draw() -> void:
	var col := Palette.EMBER_HOT if not hot else Palette.HELL_RED
	var a := 0.28 if not hot else 0.5
	col.a = a
	var local_o := to_local(origin)
	match kind:
		Kind.CROSS:
			_draw_bar(local_o, Vector2(room_rect.size.x + 40.0, bar_w), col)
			_draw_bar(local_o, Vector2(bar_w, room_rect.size.y + 40.0), col)
		Kind.DIAG:
			_draw_rot_bar(local_o, Vector2.ONE, col)
			_draw_rot_bar(local_o, Vector2(1, -1), col)
		Kind.SLAM:
			draw_circle(local_o, slam_r, col)
			draw_arc(local_o, slam_r, 0.0, TAU, 48, Palette.EMBER_HOT if not hot else Palette.BONE, 3.0, true)
		Kind.LANES:
			for i in 3:
				if i == safe_lane:
					continue
				var y := inner_top + lane_h * (float(i) + 0.5)
				var c := to_local(Vector2(origin.x, y))
				_draw_bar(c, Vector2(room_rect.size.x + 40.0, lane_h - 10.0), col)
		Kind.RING:
			var mid := (ring_inner + ring_outer) * 0.5
			draw_arc(local_o, mid, 0.0, TAU, 64, col, ring_outer - ring_inner, true)
			draw_arc(local_o, ring_inner, 0.0, TAU, 40, Palette.BONE, 4.0, true)
			if not hot:
				draw_arc(local_o, ring_inner - 8.0, 0.0, TAU, 32, Palette.EMBER_HOT, 2.0, true)


func _draw_bar(center: Vector2, size: Vector2, col: Color) -> void:
	draw_rect(Rect2(center - size * 0.5, size), col)


func _draw_rot_bar(center: Vector2, dir: Vector2, col: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var half_len := maxf(room_rect.size.x, room_rect.size.y)
	var hw := bar_w * 0.5
	var pts := PackedVector2Array([
		center + d * half_len + n * hw,
		center + d * half_len - n * hw,
		center - d * half_len - n * hw,
		center - d * half_len + n * hw,
	])
	draw_colored_polygon(pts, col)
