class_name Hazard
extends Node2D
## Telegraphed area attack used by The Infernal Phase.

enum Kind { CROSS, DIAG, SLAM, LANES, RING }

const BEAM_SHEET := "res://assets/sprites/fx_beam.png"
const SLAM_SHEET := "res://assets/sprites/fx_slam.png"
const WISP_SHEET := "res://assets/sprites/fx_wisp.png"

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
var _fx: Array[Node] = []
var _slam: AnimatedSprite2D
var _has_art := false


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
	_build_art()


func _physics_process(delta: float) -> void:
	age += delta
	if not hot and age >= telegraph:
		hot = true
		Game.shake.emit(14.0)
		_play_hot()
	if hot and kind == Kind.SLAM:
		var t := clampf((age - telegraph) / maxf(active, 0.01), 0.0, 1.0)
		slam_r = lerpf(64.0, slam_max, t)
	if age >= telegraph + active:
		queue_free()
		return
	if hot:
		_try_hit()
	_sync_art()
	if not _has_art:
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


func _build_art() -> void:
	match kind:
		Kind.CROSS:
			_stamp_line(Vector2(room_rect.position.x, origin.y), Vector2(room_rect.end.x, origin.y), 58.0, 52.0)
			_stamp_line(Vector2(origin.x, room_rect.position.y), Vector2(origin.x, room_rect.end.y), 58.0, 52.0)
		Kind.DIAG:
			_stamp_line(_edge(origin, Vector2.ONE), _edge(origin, -Vector2.ONE), 58.0, 52.0)
			_stamp_line(_edge(origin, Vector2(1, -1)), _edge(origin, Vector2(-1, 1)), 58.0, 52.0)
		Kind.SLAM:
			_slam = _add_anim(
				SLAM_SHEET,
				4,
				2,
				{"warn": {"row": 0, "fps": 8.0, "loop": true}, "hot": {"row": 1, "fps": 12.0, "loop": true}},
				128.0
			)
			if _slam:
				_slam.position = to_local(origin)
		Kind.LANES:
			for i in 3:
				if i == safe_lane:
					continue
				var y := inner_top + lane_h * (float(i) + 0.5)
				_stamp_line(Vector2(room_rect.position.x, y), Vector2(room_rect.end.x, y), 64.0, 56.0)
		Kind.RING:
			_stamp_ring(ring_inner + 28.0, 18, 34.0)
			_stamp_ring((ring_inner + ring_outer) * 0.5, 26, 40.0)
			_stamp_ring(ring_outer - 36.0, 32, 36.0)
	_has_art = not _fx.is_empty()
	_play_warn()


func _edge(from: Vector2, dir: Vector2) -> Vector2:
	var d := dir.normalized() * 10.0
	var p := from
	for _i in 220:
		var nxt := p + d
		if not room_rect.has_point(nxt):
			return p
		p = nxt
	return p


func _stamp_line(a: Vector2, b: Vector2, step: float, tall: float) -> void:
	var span := b - a
	var length := span.length()
	if length < 8.0:
		return
	var n := maxi(int(round(length / step)), 1)
	var ang := span.angle() + PI * 0.5
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var spr := _add_anim(
			BEAM_SHEET,
			4,
			2,
			{"warn": {"row": 0, "fps": 8.0, "loop": true}, "hot": {"row": 1, "fps": 12.0, "loop": true}},
			tall
		)
		if spr == null:
			return
		spr.position = to_local(a + span * t)
		spr.rotation = ang


func _stamp_ring(radius: float, count: int, tall: float) -> void:
	for i in count:
		var a := TAU * float(i) / float(count)
		var spr := _add_anim(
			WISP_SHEET,
			4,
			1,
			{"burn": {"row": 0, "fps": 10.0, "loop": true}},
			tall
		)
		if spr == null:
			return
		spr.position = to_local(origin) + Vector2.RIGHT.rotated(a) * radius
		spr.rotation = a + PI * 0.5


func _add_anim(path: String, cols: int, rows: int, anims: Dictionary, tall: float) -> AnimatedSprite2D:
	var spr := Sprites.actor(path, cols, rows, anims, tall)
	if spr == null:
		return null
	spr.modulate = Color(1, 1, 1, 0.58)
	add_child(spr)
	_fx.append(spr)
	return spr


func _play_warn() -> void:
	for n in _fx:
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames:
			var spr := n as AnimatedSprite2D
			if spr.sprite_frames.has_animation("warn"):
				spr.play("warn")


func _play_hot() -> void:
	for n in _fx:
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames:
			var spr := n as AnimatedSprite2D
			if spr.sprite_frames.has_animation("hot"):
				spr.play("hot")
			spr.modulate = Color(1.2, 0.78, 0.55, 1.0)


func _sync_art() -> void:
	if _slam:
		var diam := slam_r * 2.15
		_slam.scale = Vector2.ONE * (diam / 128.0)
		_slam.position = to_local(origin)


func _draw() -> void:
	if _has_art:
		return
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
