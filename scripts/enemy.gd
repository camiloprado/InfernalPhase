class_name Enemy
extends CharacterBody2D

enum Kind { IMP, WRETCH, CULTIST, BOSS }

const NAMES := {
	Kind.IMP: "Ember Imp",
	Kind.WRETCH: "Ring Wretch",
	Kind.CULTIST: "Ash Cantor",
	Kind.BOSS: "The Infernal Phase",
}

var kind: Kind = Kind.IMP
var hp: int = 3
var max_hp: int = 3
var radius := 12.0
var fire_cd := 99.0
var pattern_i := 0
var alive := true
var flash := 0.0
var drift := Vector2.ZERO
var spawn_pos := Vector2.ZERO
var phase := 1
var intro_done := false
var wave_busy := false
var ring_off := 0.0
var visual_rot := 0.0
var home := Vector2.ZERO
var intro := false

@onready var _col: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 1
	z_index = 7
	add_to_group("enemies")
	set_physics_process(true)
	home = global_position
	spawn_pos = global_position
	var circle := CircleShape2D.new()
	circle.radius = radius
	_col.shape = circle


func configure(p_kind: Kind, at: Vector2, p_intro: bool = false) -> void:
	kind = p_kind
	intro = p_intro
	global_position = at
	home = at
	spawn_pos = at
	match kind:
		Kind.IMP:
			hp = 3
			radius = 13.0
			fire_cd = Game.rng.randf_range(0.7, 1.2)
		Kind.WRETCH:
			hp = 8
			radius = 22.0
			fire_cd = Game.rng.randf_range(0.9, 1.4)
		Kind.CULTIST:
			if intro:
				hp = 2
				radius = 16.0
				fire_cd = 4.0
			else:
				hp = 5
				radius = 15.0
				fire_cd = Game.rng.randf_range(0.8, 1.3)
		Kind.BOSS:
			hp = 56
			radius = 38.0
			fire_cd = 1.35
			z_index = 9
	max_hp = hp
	if _col and _col.shape:
		(_col.shape as CircleShape2D).radius = radius


func _physics_process(delta: float) -> void:
	if not alive or Game.is_dead or Game.is_won:
		velocity = Vector2.ZERO
		return
	flash = maxf(flash - delta * 3.5, 0.0)
	visual_rot += delta * (0.6 if kind != Kind.BOSS else 0.35)
	_move(delta)
	move_and_slide()
	fire_cd -= delta
	if fire_cd <= 0.0:
		_fire()
	queue_redraw()


func _move(delta: float) -> void:
	var player := _player()
	var to_p := Vector2.ZERO
	if player:
		to_p = player.global_position - global_position
	match kind:
		Kind.IMP:
			var desired := to_p
			if to_p.length() < 170.0:
				desired = to_p.orthogonal()
			velocity = desired.normalized() * 70.0
		Kind.WRETCH:
			var orbit := (global_position - home).normalized().rotated(0.6) if (global_position - home).length() > 4.0 else Vector2.RIGHT.rotated(visual_rot)
			velocity = ((home + orbit * 42.0) - global_position) * 1.4
		Kind.CULTIST:
			var perp := to_p.orthogonal().normalized() if to_p.length() > 1.0 else Vector2.RIGHT
			var strafe := 50.0 if intro else 90.0
			velocity = perp * strafe * sin(visual_rot * 2.0)
			if to_p.length() < 140.0:
				velocity += -to_p.normalized() * 40.0
			elif to_p.length() > 280.0:
				velocity += to_p.normalized() * 50.0
		Kind.BOSS:
			var center := home
			var wobble := Vector2(sin(visual_rot) * 36.0, cos(visual_rot * 0.7) * 22.0)
			velocity = (center + wobble - global_position) * 2.0
	velocity += drift
	drift = drift.move_toward(Vector2.ZERO, 400.0 * delta)


func _fire() -> void:
	match kind:
		Kind.IMP:
			_imp_spread()
			fire_cd = 1.15
		Kind.WRETCH:
			_ring(12, 148.0, ring_off, Palette.EMBER, 5.5)
			ring_off += 13.0
			fire_cd = 1.85
		Kind.CULTIST:
			if not wave_busy:
				_start_wave()
			fire_cd = 4.2 if intro else 2.35
		Kind.BOSS:
			_boss_fire()


func _imp_spread() -> void:
	var aim := _aim()
	_spread(aim, 3, 20.0, 205.0, Palette.EMBER, 5.0)


func _start_wave() -> void:
	wave_busy = true
	var aim := _aim()
	var perp := Vector2(-aim.y, aim.x)
	_wave_shots(aim, perp)


func _wave_shots(aim: Vector2, perp: Vector2) -> void:
	var floor_node := _floor()
	if floor_node == null:
		wave_busy = false
		return
	var count := 2 if intro else 10
	var spd := 78.0 if intro else 175.0
	var gap := 0.32 if intro else 0.075
	var amp := 10.0 if intro else 34.0
	for i in count:
		if not is_instance_valid(self) or not alive or not is_inside_tree():
			wave_busy = false
			return
		var lateral := sin(i * 0.55) * amp
		var origin := global_position + aim * (radius + 8.0) + perp * lateral
		floor_node.spawn_bullet(origin, aim, spd, true, Palette.ROBE_LIGHT, 5.0, 0.0)
		await get_tree().create_timer(gap).timeout
	wave_busy = false


func _boss_fire() -> void:
	var ratio := float(hp) / float(max_hp)
	if ratio <= 0.33:
		phase = 3
	elif ratio <= 0.66:
		phase = 2
	else:
		phase = 1
	match pattern_i % (4 if phase == 1 else 5):
		0:
			_ring(14 if phase == 1 else 18, 150.0 + phase * 16.0, ring_off, Palette.HELL_RED, 6.0)
			ring_off += 8.0
			fire_cd = 1.55 if phase < 3 else 1.1
		1:
			_spread(_aim(), 5 + phase, 14.0, 210.0 + phase * 20.0, Palette.EMBER, 5.5)
			fire_cd = 1.05
		2:
			_ring(10, 130.0, ring_off + 18.0, Palette.EMBER_HOT, 5.0)
			_start_boss_wave()
			fire_cd = 1.9 if phase < 3 else 1.35
		3:
			_spiral(16, 155.0, 1.1 if phase < 3 else 1.6)
			fire_cd = 1.4
		4:
			_cross()
			fire_cd = 1.2
	pattern_i += 1


func _start_boss_wave() -> void:
	var player := _player()
	var aim := Vector2.DOWN
	if player:
		aim = _aim()
	var perp := Vector2(-aim.y, aim.x)
	_boss_wave(aim, perp)


func _boss_wave(aim: Vector2, perp: Vector2) -> void:
	var floor_node := _floor()
	if floor_node == null:
		return
	for i in 8:
		if not is_instance_valid(self) or not alive or not is_inside_tree():
			return
		floor_node.spawn_bullet(
			global_position + aim * (radius + 10.0),
			aim,
			180.0,
			true,
			Palette.ROBE_LIGHT,
			5.5,
			42.0,
			7.0,
			i * 0.4
		)
		await get_tree().create_timer(0.06).timeout


func _spread(aim: Vector2, count: int, arc_deg: float, spd: float, col: Color, rad: float) -> void:
	var floor_node := _floor()
	if floor_node == null:
		return
	var start := -arc_deg * 0.5 * (count - 1)
	for i in count:
		var a := deg_to_rad(start + arc_deg * i)
		floor_node.spawn_bullet(global_position + aim.rotated(a) * (radius + 6.0), aim.rotated(a), spd, true, col, rad)


func _ring(count: int, spd: float, offset_deg: float, col: Color, rad: float) -> void:
	var floor_node := _floor()
	if floor_node == null:
		return
	for i in count:
		var a := deg_to_rad(offset_deg + i * (360.0 / count))
		var d := Vector2.RIGHT.rotated(a)
		floor_node.spawn_bullet(global_position + d * (radius + 8.0), d, spd, true, col, rad)


func _spiral(count: int, spd: float, ang: float) -> void:
	var floor_node := _floor()
	if floor_node == null:
		return
	for i in count:
		var a := TAU * float(i) / float(count) + ring_off * 0.04
		var d := Vector2.RIGHT.rotated(a)
		floor_node.spawn_bullet(global_position + d * (radius + 8.0), d, spd, true, Palette.EMBER, 5.0, 0.0, 8.0, 0.0, ang * (1.0 if i % 2 == 0 else -1.0))


func _cross() -> void:
	var floor_node := _floor()
	if floor_node == null:
		return
	var base := _aim()
	for d in [base, base.orthogonal(), -base, -base.orthogonal()]:
		for k in 3:
			var spread := deg_to_rad((k - 1) * 8.0)
			floor_node.spawn_bullet(global_position + d.rotated(spread) * (radius + 8.0), d.rotated(spread), 200.0, true, Palette.BONE, 5.5)


func take_hit(amount: int = 1) -> void:
	if not alive:
		return
	hp -= amount
	flash = 1.0
	var p := _player()
	if p:
		drift = (global_position - p.global_position).normalized() * 90.0
	if hp <= 0:
		_die()
	queue_redraw()


func _die() -> void:
	alive = false
	collision_layer = 0
	if kind == Kind.BOSS:
		Game.say(Flavor.pick(Flavor.WIN), 4.0)
		Game.win()
	queue_free()
	var floor_node := _floor()
	if floor_node:
		floor_node.on_enemy_died(self)


func _aim() -> Vector2:
	var player := _player()
	if player == null:
		return Vector2.DOWN
	var v := player.global_position - global_position
	if v.length() < 1.0:
		return Vector2.DOWN
	return v.normalized()


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _floor() -> Floor:
	return get_tree().get_first_node_in_group("floor") as Floor


func _draw() -> void:
	var col := _color()
	if flash > 0.0:
		col = col.lerp(Palette.BONE, flash)
	draw_circle(Vector2.ZERO, radius + 8.0, Color(col.r, col.g, col.b, 0.16))
	match kind:
		Kind.IMP:
			var pts := PackedVector2Array([
				Vector2(0, -radius - 4),
				Vector2(radius, radius * 0.7),
				Vector2(0, radius * 0.25),
				Vector2(-radius, radius * 0.7),
			])
			draw_colored_polygon(pts, col)
			draw_circle(Vector2(-4, -2), 2.2, Palette.EMBER_HOT)
			draw_circle(Vector2(4, -2), 2.2, Palette.EMBER_HOT)
		Kind.WRETCH:
			draw_circle(Vector2.ZERO, radius + 10.0, Color(Palette.BONE.r, Palette.BONE.g, Palette.BONE.b, 0.38))
			draw_circle(Vector2.ZERO, radius + 3.0, Palette.BONE_DIM)
			draw_circle(Vector2.ZERO, radius - 5.0, Palette.VOID)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Palette.BONE, 9.0, true)
			draw_arc(Vector2.ZERO, radius - 6.0, 0.0, TAU, 28, Palette.EMBER_HOT, 3.0, true)
			for i in 6:
				var a := visual_rot + i * TAU / 6.0
				var tip := Vector2.RIGHT.rotated(a) * radius
				draw_line(tip * 0.2, tip, Palette.EMBER_HOT, 2.6)
				draw_circle(tip, 6.5, Palette.BONE)
				draw_circle(tip, 2.4, Palette.EMBER_HOT)
			draw_circle(Vector2.ZERO, 8.0, Palette.EMBER)
			draw_circle(Vector2.ZERO, 3.5, Palette.EMBER_HOT)
		Kind.CULTIST:
			var robe := PackedVector2Array([
				Vector2(0, -radius - 2),
				Vector2(radius * 0.85, radius),
				Vector2(0, radius * 0.7),
				Vector2(-radius * 0.85, radius),
			])
			draw_colored_polygon(robe, Palette.ROBE_LIGHT if intro else col)
			var outline := robe.duplicate()
			outline.append(robe[0])
			draw_polyline(outline, Palette.BONE, 2.0, true)
			draw_circle(Vector2(0, -radius * 0.35), 7.0, Palette.BONE)
			draw_circle(Vector2(-2.5, -radius * 0.4), 1.6, Palette.VOID)
			draw_circle(Vector2(2.5, -radius * 0.4), 1.6, Palette.VOID)
			draw_circle(Vector2(0, -radius - 6.0), 3.0, Palette.EMBER_HOT)
		Kind.BOSS:
			draw_circle(Vector2.ZERO, radius, Palette.VOID)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, col, 6.0, true)
			draw_arc(Vector2.ZERO, radius * 0.62, visual_rot, visual_rot + TAU, 5, Palette.EMBER, 3.5, true)
			for i in 5:
				var a := visual_rot + i * TAU / 5.0
				draw_circle(Vector2.RIGHT.rotated(a) * (radius * 0.55), 5.5, Palette.EMBER_HOT)
			draw_circle(Vector2.ZERO, 8.0, Palette.HELL_RED)
			draw_circle(Vector2.ZERO, 3.0, Palette.EMBER_HOT)
	# hp pip
	if kind != Kind.BOSS and hp < max_hp:
		var w := radius * 2.0
		draw_rect(Rect2(-w * 0.5, -radius - 10, w, 3), Palette.VOID)
		draw_rect(Rect2(-w * 0.5, -radius - 10, w * (float(hp) / float(max_hp)), 3), Palette.EMBER)


func _color() -> Color:
	match kind:
		Kind.IMP:
			return Palette.EMBER
		Kind.WRETCH:
			return Palette.BONE
		Kind.CULTIST:
			return Palette.ROBE
		Kind.BOSS:
			return Palette.HELL_RED
	return Palette.ASH_LIGHT
