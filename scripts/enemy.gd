class_name Enemy
extends CharacterBody2D

enum Kind { IMP, WRETCH, CULTIST, BOSS }

const NAMES := {
	Kind.IMP: "Ember Imp",
	Kind.WRETCH: "Ring Wretch",
	Kind.CULTIST: "Ash Cantor",
	Kind.BOSS: "The Infernal Phase",
}

const IMP_LOADOUTS := ["vanilla", "sword", "sword_shield", "pitchfork", "pitchfork_shield"]
const DIR_NAMES := ["down", "up", "right", "left"]

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
var special_busy := false
var special_queue := 0
var special_i := 0
var tele_cd := 2.5
var tele_wind := 0.0
var tele_dest := Vector2.ZERO
var loadout := "vanilla"
var art := false
var attack_t := 0.0
var special_pick := 0

const SPECIAL_AT := [0.8, 0.6, 0.4, 0.2]

@onready var _col: CollisionShape2D = $CollisionShape2D
@onready var _sprite: AnimatedSprite2D = $Sprite


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
			hp = 6
			radius = 13.0
			fire_cd = Game.rng.randf_range(0.35, 0.7)
		Kind.WRETCH:
			hp = 14
			radius = 22.0
			fire_cd = Game.rng.randf_range(0.45, 0.8)
		Kind.CULTIST:
			if intro:
				hp = 6
				radius = 16.0
				fire_cd = 0.95
			else:
				hp = 9
				radius = 15.0
				fire_cd = Game.rng.randf_range(0.45, 0.85)
		Kind.BOSS:
			hp = 80
			radius = 38.0
			fire_cd = 0.85
			z_index = 9
			tele_cd = 2.4
			special_i = 0
			special_busy = false
			special_queue = 0
	max_hp = hp
	if _col and _col.shape:
		(_col.shape as CircleShape2D).radius = radius
	_setup_art()


func _physics_process(delta: float) -> void:
	if not alive or Game.is_dead or Game.is_won:
		velocity = Vector2.ZERO
		return
	flash = maxf(flash - delta * 3.5, 0.0)
	visual_rot += delta * (0.6 if kind != Kind.BOSS else 0.35)
	if kind == Kind.BOSS:
		_boss_clock(delta)
	_move(delta)
	move_and_slide()
	if not (kind == Kind.BOSS and (special_busy or tele_wind > 0.0)):
		fire_cd -= delta
		if fire_cd <= 0.0:
			_fire()
	_tick_art(delta)
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
			var strafe := 70.0 if intro else 95.0
			velocity = perp * strafe * sin(visual_rot * 2.0)
			if to_p.length() < 140.0:
				velocity += -to_p.normalized() * 40.0
			elif to_p.length() > 280.0:
				velocity += to_p.normalized() * 50.0
		Kind.BOSS:
			if special_busy or tele_wind > 0.0:
				velocity = Vector2.ZERO
			else:
				var center := home
				var wobble := Vector2(sin(visual_rot) * 36.0, cos(visual_rot * 0.7) * 22.0)
				velocity = (center + wobble - global_position) * 2.0
	velocity += drift
	drift = drift.move_toward(Vector2.ZERO, 400.0 * delta)


func _fire() -> void:
	match kind:
		Kind.IMP:
			_imp_spread()
			fire_cd = 0.88
		Kind.WRETCH:
			attack_t = 0.5
			_ring(16, 168.0, ring_off, Palette.EMBER, 6.0)
			ring_off += 11.0
			fire_cd = 1.28
		Kind.CULTIST:
			attack_t = 0.7
			if not wave_busy:
				_start_wave()
			fire_cd = 1.75 if intro else 1.55
		Kind.BOSS:
			_boss_fire()


func _imp_spread() -> void:
	var aim := _aim()
	attack_t = 0.44
	_spread(aim, 5, 14.0, 220.0, Palette.EMBER, 6.0)


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
	var count := 6 if intro else 12
	var spd := 128.0 if intro else 188.0
	var gap := 0.11 if intro else 0.06
	var amp := 22.0 if intro else 36.0
	for i in count:
		if not is_instance_valid(self) or not alive or not is_inside_tree():
			wave_busy = false
			return
		var lateral := sin(i * 0.55) * amp
		var origin := global_position + aim * (radius + 8.0) + perp * lateral
		floor_node.spawn_bullet(origin, aim, spd, true, Palette.ROBE_LIGHT, 6.0, 0.0)
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
			_ring(16 if phase == 1 else 20, 155.0 + phase * 14.0, ring_off, Palette.HELL_RED, 6.5)
			ring_off += 8.0
			fire_cd = 1.2 if phase < 3 else 0.9
		1:
			_spread(_aim(), 6 + phase, 12.0, 205.0 + phase * 16.0, Palette.EMBER, 6.0)
			fire_cd = 0.85
		2:
			_ring(12, 140.0, ring_off + 18.0, Palette.EMBER_HOT, 6.0)
			_start_boss_wave()
			fire_cd = 1.55 if phase < 3 else 1.15
		3:
			_spiral(18, 160.0, 1.15 if phase < 3 else 1.65)
			fire_cd = 1.15
		4:
			_cross()
			fire_cd = 0.95
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
			5.8,
			38.0,
			7.0,
			i * 0.4
		)
		await get_tree().create_timer(0.055).timeout


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
		floor_node.spawn_bullet(global_position + d * (radius + 8.0), d, spd, true, Palette.EMBER, 6.0, 0.0, 8.0, 0.0, ang * (1.0 if i % 2 == 0 else -1.0))


func _cross() -> void:
	var floor_node := _floor()
	if floor_node == null:
		return
	var base := _aim()
	for d in [base, base.orthogonal(), -base, -base.orthogonal()]:
		for k in 3:
			var spread := deg_to_rad((k - 1) * 8.0)
			floor_node.spawn_bullet(global_position + d.rotated(spread) * (radius + 8.0), d.rotated(spread), 195.0, true, Palette.BONE, 6.0)


func take_hit(amount: int = 1) -> void:
	if not alive:
		return
	hp -= amount
	flash = 1.0
	var p := _player()
	if p:
		drift = (global_position - p.global_position).normalized() * 90.0
	if kind == Kind.BOSS and hp > 0:
		_check_specials()
	if hp <= 0:
		_die()
	queue_redraw()


func _die() -> void:
	alive = false
	collision_layer = 0
	if kind == Kind.BOSS:
		Game.say(Flavor.pick(Flavor.WIN), 4.0)
		Game.win()
	var drop_at := global_position
	var drop_kind := kind
	queue_free()
	var floor_node := _floor()
	if floor_node:
		floor_node.drop_from(drop_kind, drop_at)
		floor_node.on_enemy_died(self)


func _check_specials() -> void:
	while special_i < SPECIAL_AT.size() and hp <= int(ceil(float(max_hp) * SPECIAL_AT[special_i])):
		special_i += 1
		if special_busy:
			special_queue += 1
		else:
			special_busy = true
			_begin_special()


func _begin_special() -> void:
	special_busy = true
	tele_wind = 0.0
	var room := _host_room()
	var pick := Game.rng.randi() % 5
	special_pick = pick
	var origin := global_position
	if room:
		match pick:
			3:
				origin = room.center_global()
			4:
				origin = _ring_hole(room)
	if pick < Flavor.SPECIAL.size():
		Game.say(Flavor.SPECIAL[pick], 1.7)
	var floor_node := _floor()
	if floor_node and room:
		floor_node.spawn_hazard(pick, origin, room)
	var dur := 1.4
	match pick:
		0, 1:
			dur = 1.38
		2:
			dur = 1.58
		3:
			dur = 1.55
		4:
			dur = 1.62
	get_tree().create_timer(dur).timeout.connect(_end_special, CONNECT_ONE_SHOT)


func _end_special() -> void:
	if not is_instance_valid(self) or not alive:
		return
	special_busy = false
	fire_cd = 0.28
	if special_queue > 0:
		special_queue -= 1
		special_busy = true
		_begin_special()


func _boss_clock(delta: float) -> void:
	if special_busy:
		return
	if tele_wind > 0.0:
		tele_wind -= delta
		if tele_wind <= 0.0:
			_finish_teleport()
		return
	tele_cd -= delta
	if tele_cd <= 0.0:
		_start_teleport()


func _start_teleport() -> void:
	var dest := _teleport_point()
	if dest == Vector2.ZERO:
		tele_cd = 1.2
		return
	tele_dest = dest
	tele_wind = 0.48
	tele_cd = Game.rng.randf_range(3.1, 3.9)


func _finish_teleport() -> void:
	global_position = tele_dest
	home = tele_dest
	flash = 1.0
	Game.shake.emit(8.0)


func _teleport_point() -> Vector2:
	var room := _host_room()
	if room == null:
		return Vector2.ZERO
	var inset := Game.WALL + 86.0
	var rect := Rect2(room.global_position + Vector2(inset, inset), room.size - Vector2(inset * 2.0, inset * 2.0))
	var player := _player()
	for _i in 16:
		var p := Vector2(
			Game.rng.randf_range(rect.position.x, rect.end.x),
			Game.rng.randf_range(rect.position.y, rect.end.y)
		)
		if player and p.distance_to(player.global_position) < 160.0:
			continue
		if p.distance_to(global_position) < 90.0:
			continue
		return p
	return room.center_global()


func _ring_hole(room: Room) -> Vector2:
	var inset := Game.WALL + 120.0
	var rect := Rect2(room.global_position + Vector2(inset, inset), room.size - Vector2(inset * 2.0, inset * 2.0))
	var player := _player()
	for _i in 14:
		var p := Vector2(
			Game.rng.randf_range(rect.position.x, rect.end.x),
			Game.rng.randf_range(rect.position.y, rect.end.y)
		)
		if player and p.distance_to(player.global_position) < 170.0:
			continue
		return p
	return room.center_global()


func _host_room() -> Room:
	var floor_node := _floor()
	if floor_node == null:
		return null
	if floor_node.current and floor_node.current.kind == Room.Kind.BOSS:
		return floor_node.current
	var rid := String(get_meta("room", ""))
	for r in floor_node.rooms.values():
		if (r as Room).room_id == rid:
			return r
	return floor_node.current


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


func _setup_art() -> void:
	art = false
	if _sprite == null:
		return
	_sprite.visible = false
	_sprite.sprite_frames = null
	match kind:
		Kind.IMP:
			_setup_imp_art()
		Kind.BOSS:
			_setup_boss_art()
		Kind.WRETCH:
			_setup_sheet_art("res://assets/sprites/wretch.png", 70.0, {
				"idle": {"row": 0, "fps": 5.0, "loop": true},
				"attack": {"row": 1, "fps": 9.0, "loop": false},
			})
		Kind.CULTIST:
			_setup_sheet_art("res://assets/sprites/cantor.png", 58.0 if intro else 54.0, {
				"walk": {"row": 0, "fps": 7.0, "loop": true},
				"attack": {"row": 1, "fps": 8.0, "loop": true},
			})
		_:
			pass


func _setup_imp_art() -> void:
	loadout = _pick_loadout()
	var walk := _tex("res://assets/characters/imp/walk_%s.png" % loadout)
	var atk := _tex("res://assets/characters/imp/attack_%s.png" % loadout)
	if walk == null or atk == null:
		return
	var frames := SpriteFrames.new()
	_slice_dirs(frames, walk, "walk", 8.0)
	_slice_dirs(frames, atk, "attack", 11.0)
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cell := Vector2(float(walk.get_width()) / 4.0, float(walk.get_height()) / 4.0)
	_fit_sprite(cell, 0.56)
	_sprite.visible = true
	art = true
	_sprite.play("walk_down")


func _setup_boss_art() -> void:
	var idle := _tex("res://assets/characters/boss/idle.png")
	var move := _tex("res://assets/characters/boss/move.png")
	var fire := _tex("res://assets/characters/boss/fire.png")
	var bolt := _tex("res://assets/characters/boss/lightning.png")
	if idle == null:
		return
	var frames := SpriteFrames.new()
	_slice_grid(frames, idle, "idle", 2, 2, 5.0, true)
	if move != null:
		_slice_grid(frames, move, "move", 2, 2, 9.0, true)
	else:
		_slice_grid(frames, idle, "move", 2, 2, 9.0, true)
	if fire != null:
		_slice_grid(frames, fire, "fire", 2, 2, 8.0, true)
	else:
		_slice_grid(frames, idle, "fire", 2, 2, 8.0, true)
	if bolt != null:
		_slice_grid(frames, bolt, "lightning", 2, 2, 8.0, true)
	else:
		_slice_grid(frames, idle, "lightning", 2, 2, 8.0, true)
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cell := Vector2(float(idle.get_width()) / 2.0, float(idle.get_height()) / 2.0)
	_fit_sprite(cell, 0.86)
	_sprite.offset = Vector2(0, 10)
	_sprite.visible = true
	art = true
	_sprite.play("idle")


func _setup_sheet_art(path: String, target_h: float, anims: Dictionary) -> void:
	var node := Sprites.actor(path, 4, 2, anims, target_h)
	if node == null:
		return
	_sprite.sprite_frames = node.sprite_frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = node.scale
	_sprite.centered = true
	_sprite.visible = true
	art = true
	var keys: Array = anims.keys()
	if not keys.is_empty():
		_sprite.play(String(keys[0]))
	node.free()


func _pick_loadout() -> String:
	var ok: Array[String] = []
	for lo in IMP_LOADOUTS:
		var walk_p := "res://assets/characters/imp/walk_%s.png" % lo
		var atk_p := "res://assets/characters/imp/attack_%s.png" % lo
		if ResourceLoader.exists(walk_p) and ResourceLoader.exists(atk_p):
			ok.append(lo)
	if ok.is_empty():
		return "vanilla"
	return ok[Game.rng.randi() % ok.size()]


func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _slice_dirs(frames: SpriteFrames, tex: Texture2D, prefix: String, fps: float) -> void:
	var fw := tex.get_width() / 4
	var fh := tex.get_height() / 4
	for r in 4:
		var anim := "%s_%s" % [prefix, DIR_NAMES[r]]
		if frames.has_animation(anim):
			frames.remove_animation(anim)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, true)
		for c in 4:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * fw, r * fh, fw, fh)
			atlas.filter_clip = true
			frames.add_frame(anim, atlas)


func _slice_grid(frames: SpriteFrames, tex: Texture2D, anim: String, cols: int, rows: int, fps: float, loop: bool) -> void:
	if frames.has_animation(anim):
		frames.remove_animation(anim)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var fw := tex.get_width() / cols
	var fh := tex.get_height() / rows
	for r in rows:
		for c in cols:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(c * fw, r * fh, fw, fh)
			atlas.filter_clip = true
			frames.add_frame(anim, atlas)


func _fit_sprite(cell: Vector2, occupy: float) -> void:
	var body := minf(cell.x, cell.y) * occupy
	if body < 1.0:
		return
	var target := radius * (2.4 if kind == Kind.IMP else 2.6)
	var s := target / body
	_sprite.scale = Vector2(s, s)


func _facing() -> String:
	var v := velocity
	if v.length() < 16.0:
		v = _aim()
	if absf(v.x) >= absf(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "down" if v.y >= 0.0 else "up"


func _tick_art(delta: float) -> void:
	if not art or _sprite == null:
		return
	attack_t = maxf(attack_t - delta, 0.0)
	if flash > 0.0:
		_sprite.modulate = Color.WHITE.lerp(Palette.BONE, flash * 0.8)
	else:
		_sprite.modulate = Color.WHITE
	if kind == Kind.IMP:
		var anim := ("attack_" if attack_t > 0.0 else "walk_") + _facing()
		if _sprite.animation != anim or not _sprite.is_playing():
			_sprite.play(anim)
	elif kind == Kind.WRETCH or kind == Kind.CULTIST:
		_sprite.flip_h = _aim().x < 0.0
		var want := "attack" if attack_t > 0.0 else ("idle" if kind == Kind.WRETCH else "walk")
		if _sprite.animation != want or not _sprite.is_playing():
			_sprite.play(want)
	elif kind == Kind.BOSS:
		var anim := "idle"
		if special_busy:
			anim = "fire" if special_pick == 2 or special_pick == 4 else "lightning"
		elif tele_wind > 0.0:
			anim = "move"
		if _sprite.animation != anim or not _sprite.is_playing():
			_sprite.play(anim)


func _draw_art_fx() -> void:
	if kind == Kind.BOSS and tele_wind > 0.0:
		var dest := to_local(tele_dest)
		var pulse := 0.55 + 0.45 * sin(visual_rot * 8.0)
		draw_arc(dest, 28.0 + pulse * 10.0, 0.0, TAU, 24, Palette.EMBER_HOT, 4.0, true)
		draw_circle(dest, 7.0, Palette.BONE)
		draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 28, Palette.EMBER_HOT, 3.0, true)
	if kind != Kind.BOSS and hp < max_hp:
		var w := radius * 2.0
		draw_rect(Rect2(-w * 0.5, -radius - 14, w, 3), Palette.VOID)
		draw_rect(Rect2(-w * 0.5, -radius - 14, w * (float(hp) / float(max_hp)), 3), Palette.EMBER)


func _draw() -> void:
	if art:
		_draw_art_fx()
		return
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
			if tele_wind > 0.0:
				var dest := to_local(tele_dest)
				var pulse := 0.55 + 0.45 * sin(visual_rot * 8.0)
				draw_arc(dest, 28.0 + pulse * 10.0, 0.0, TAU, 24, Palette.EMBER_HOT, 4.0, true)
				draw_circle(dest, 7.0, Palette.BONE)
				draw_arc(Vector2.ZERO, radius + 12.0, 0.0, TAU, 28, Palette.EMBER_HOT, 3.0, true)
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
