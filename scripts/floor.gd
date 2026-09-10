class_name Floor
extends Node2D

const LAYOUT := [
	{ "id": "start", "grid": Vector2i(0, 0), "kind": Room.Kind.START, "pack": [] },
	{ "id": "north", "grid": Vector2i(0, -1), "kind": Room.Kind.COMBAT, "pack": ["imp", "imp", "imp"] },
	{ "id": "west", "grid": Vector2i(-1, 0), "kind": Room.Kind.COMBAT, "pack": ["wretch", "imp"] },
	{ "id": "east", "grid": Vector2i(1, 0), "kind": Room.Kind.COMBAT, "pack": ["cantor", "imp"] },
	{ "id": "npc", "grid": Vector2i(2, 0), "kind": Room.Kind.NPC, "pack": [] },
	{ "id": "south", "grid": Vector2i(0, 1), "kind": Room.Kind.COMBAT, "pack": ["cultist", "cultist", "imp"] },
	{ "id": "se", "grid": Vector2i(1, 1), "kind": Room.Kind.COMBAT, "pack": ["wretch", "imp", "imp"] },
	{ "id": "boss", "grid": Vector2i(2, 1), "kind": Room.Kind.BOSS, "pack": ["boss"] },
	{ "id": "deep", "grid": Vector2i(0, 2), "kind": Room.Kind.COMBAT, "pack": ["imp", "wretch", "cultist"] },
]

const KIND_MAP := {
	"imp": Enemy.Kind.IMP,
	"wretch": Enemy.Kind.WRETCH,
	"cultist": Enemy.Kind.CULTIST,
	"cantor": Enemy.Kind.CULTIST,
	"boss": Enemy.Kind.BOSS,
}

var rooms: Dictionary = {}  # Vector2i -> Room
var current: Room
var player: Player
var shake_t := 0.0
var shake_amp := 0.0
var entered_boss := false
var start_lines_i := 0

@onready var rooms_root: Node2D = $Rooms
@onready var actors: Node2D = $Actors
@onready var projectiles: Node2D = $Projectiles
@onready var camera: Camera2D = $Camera2D
@onready var ui: HUD = $UI

var _bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
var _player_scene: PackedScene = preload("res://scenes/player.tscn")
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var _room_scene: PackedScene = preload("res://scenes/room.tscn")
var _hazard_scene: PackedScene = preload("res://scenes/hazard.tscn")
var _pickup_scene: PackedScene = preload("res://scenes/pickup.tscn")
var _run_pick_script: Script = preload("res://scripts/run_pick.gd")
var _fall_cd := 0.0


func _ready() -> void:
	add_to_group("floor")
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.reset_run()
	Game.shake.connect(_on_shake)
	Game.died.connect(_on_died)
	Game.won.connect(_on_won)
	_build_floor()
	_spawn_player()
	if player:
		player.set_physics_process(false)
	var qa := "--qa-proof" in OS.get_cmdline_user_args()
	var look := "--qa-look" in OS.get_cmdline_user_args()
	if qa and not look:
		Game.pick_run(Game.Body.CAIM, Game.Difficulty.NORMAL)
	else:
		var pick = _run_pick_script.new()
		add_child(pick)
		if look:
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().create_timer(0.2).timeout
			_qa_shot("start")
			Game.pick_run(Game.Body.CAIM, Game.Difficulty.NORMAL)
			pick.queue_free()
		elif pick.has_signal("chosen"):
			await pick.chosen
		else:
			push_warning("RunPick missing chosen signal")
	if player:
		player.rebind_visual()
		player.set_physics_process(true)
	ui.set_walker(Game.walker_label(), "")
	Game.bgm("play_for_run")
	_enter_room(rooms[Vector2i.ZERO], true)
	if look:
		await _look_dump()
		if not qa:
			get_tree().quit()
			return
	if qa:
		await _qa_proof()
		return
	await get_tree().create_timer(0.15).timeout
	Game.say(Flavor.START[0], 2.8)
	await get_tree().create_timer(2.9).timeout
	if is_inside_tree() and not Game.is_dead:
		Game.say(Flavor.START[1], 3.2)


func _build_floor() -> void:
	for spec in LAYOUT:
		var room: Room = _room_scene.instantiate()
		var pack: Array[String] = []
		for item in spec["pack"]:
			pack.append(String(item))
		room.setup(String(spec["id"]), spec["grid"], spec["kind"], pack)
		rooms_root.add_child(room)
		rooms[spec["grid"]] = room
	for grid in rooms.keys():
		var room: Room = rooms[grid]
		for dir in Room.DIR_VEC.keys():
			var ng: Vector2i = grid + Room.DIR_VEC[dir]
			if rooms.has(ng):
				room.connect_to(dir, rooms[ng])
	for room in rooms.values():
		(room as Room).finalize()
	if rooms.has(Vector2i.ZERO):
		(rooms[Vector2i.ZERO] as Room).add_pit(drop_room())


func _spawn_player() -> void:
	player = _player_scene.instantiate()
	actors.add_child(player)
	player.global_position = rooms[Vector2i.ZERO].center_global()
	camera.position_smoothing_enabled = false
	camera.global_position = rooms[Vector2i.ZERO].center_global()
	if camera.has_method("reset_smoothing"):
		camera.reset_smoothing()
	camera.make_current()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		if not Game.body_picked:
			return
		Game.restart_floor()
		return
	if Game.is_dead or Game.is_won:
		return
	if player == null:
		return
	var was_falling := _fall_cd > 0.0
	_fall_cd = maxf(_fall_cd - delta, 0.0)
	if was_falling and _fall_cd <= 0.0:
		for room in rooms.values():
			if (room as Room).has_pit:
				(room as Room).arm_pit(true)
	_check_pit()
	_check_room_change()
	if shake_t > 0.0:
		shake_t -= delta
		camera.offset = Vector2(Game.rng.randf_range(-shake_amp, shake_amp), Game.rng.randf_range(-shake_amp, shake_amp))
		shake_amp = move_toward(shake_amp, 0.0, delta * 28.0)
	else:
		camera.offset = Vector2.ZERO


func _check_room_change() -> void:
	for room in rooms.values():
		var r: Room = room
		if r == current:
			continue
		if r.contains_inner(player.global_position):
			_enter_room(r, false)
			return


func _enter_room(room: Room, instant: bool) -> void:
	current = room
	for node in rooms.values():
		(node as Room).set_active_doors(node == room)
	camera.position_smoothing_enabled = not instant
	camera.global_position = room.center_global()
	ui.set_room_title(room.title())
	ui.set_minimap(rooms, current)
	if room.visited:
		return
	room.visited = true
	if room.kind == Room.Kind.BOSS and not entered_boss:
		entered_boss = true
		Game.boss_intro.emit()
		Game.say(Flavor.BOSS[0], 2.6)
		get_tree().create_timer(2.7).timeout.connect(func () -> void:
			if is_inside_tree() and not Game.is_dead:
				Game.say(Flavor.BOSS[1], 3.0)
		)
	if room.cleared:
		room.unlock_doors()
		return
	room.lock_doors()
	_spawn_pack(room)


func _spawn_pack(room: Room) -> void:
	var total := room.pack.size()
	for i in total:
		var key := room.pack[i]
		if not KIND_MAP.has(key):
			continue
		var enemy: Enemy = _enemy_scene.instantiate()
		enemy.set_physics_process(false)
		actors.add_child(enemy)
		var at := room.spawn_offset(i, total)
		enemy.configure(KIND_MAP[key], at, key == "cantor")
		enemy.set_meta("room", room.room_id)
		enemy.set_physics_process(true)
	room.set_meta("alive", total)


func spawn_bullet(
		origin: Vector2,
		dir: Vector2,
		speed: float,
		from_enemy: bool,
		color: Color,
		radius: float = 5.0,
		sine_amp: float = 0.0,
		sine_freq: float = 8.0,
		sine_phase: float = 0.0,
		angular: float = 0.0,
		art: String = ""
	) -> Bullet:
	var b: Bullet = _bullet_scene.instantiate()
	projectiles.add_child(b)
	b.setup(origin, dir, speed, from_enemy, color, radius, sine_amp, sine_freq, sine_phase, angular, art)
	return b


func spawn_hazard(kind: int, origin: Vector2, room: Room) -> Node2D:
	var h := _hazard_scene.instantiate()
	projectiles.add_child(h)
	h.setup(kind, origin, room)
	return h


func spawn_pickup(kind: Pickup.Kind, at: Vector2) -> void:
	var p: Pickup = _pickup_scene.instantiate()
	actors.add_child(p)
	p.setup(kind, at)


func drop_from(kind: Enemy.Kind, at: Vector2) -> void:
	if kind == Enemy.Kind.BOSS:
		return
	if Game.rng.randf() >= 0.45:
		return
	var table := Game.rng.randf()
	if table < 0.40:
		spawn_pickup(Pickup.Kind.HEART, at)
	elif table < 0.65:
		spawn_pickup(Pickup.Kind.EMBER, at)
	elif table < 0.85:
		spawn_pickup(_roll_skill(), at)
	elif Game.max_hearts < Game.HEART_CAP:
		spawn_pickup(Pickup.Kind.MAX_HEART, at)
	else:
		spawn_pickup(Pickup.Kind.HEART, at)


func roll_item() -> Pickup.Kind:
	var pool: Array[Pickup.Kind] = [Pickup.Kind.EMBER]
	if Game.hearts < Game.max_hearts:
		pool.append(Pickup.Kind.HEART)
	if Game.max_hearts < Game.HEART_CAP:
		pool.append(Pickup.Kind.MAX_HEART)
	if Game.pierce < Game.PIERCE_CAP:
		pool.append(Pickup.Kind.PIERCE)
	if Game.rapid < Game.RAPID_CAP:
		pool.append(Pickup.Kind.RAPID)
	if Game.heavy < 1:
		pool.append(Pickup.Kind.HEAVY)
	if Game.burn < 1:
		pool.append(Pickup.Kind.BURN)
	return pool[Game.rng.randi() % pool.size()]


func _roll_skill() -> Pickup.Kind:
	var pool: Array[Pickup.Kind] = []
	if Game.pierce < Game.PIERCE_CAP:
		pool.append(Pickup.Kind.PIERCE)
	if Game.rapid < Game.RAPID_CAP:
		pool.append(Pickup.Kind.RAPID)
	if Game.heavy < 1:
		pool.append(Pickup.Kind.HEAVY)
	if Game.burn < 1:
		pool.append(Pickup.Kind.BURN)
	if pool.is_empty():
		return Pickup.Kind.EMBER
	return pool[Game.rng.randi() % pool.size()]


func drop_room() -> Room:
	if rooms.has(Vector2i(0, 2)):
		return rooms[Vector2i(0, 2)]
	if rooms.has(Vector2i(0, 1)):
		return rooms[Vector2i(0, 1)]
	return null


func _check_pit() -> void:
	if current == null or player == null or Game.is_dead:
		return
	if not current.has_pit or _fall_cd > 0.0:
		return
	if current.covers_pit(player.global_position):
		fall_from(current, current.pit_dest)


func fall_from(src: Room, dest: Room = null) -> void:
	if _fall_cd > 0.0 or player == null or Game.is_dead:
		return
	var land: Room = dest
	if land == null or land == src:
		land = src.pit_dest
	if land == null or land == src:
		land = drop_room()
	_fall_cd = 1.2
	src.arm_pit(false)
	player.i_timer = maxf(player.i_timer, 0.7)
	# Rim damage only if this floor has no drop target. Env pits teleport.
	if land == null or land == src:
		var away := (player.global_position - src.pit_global()).normalized()
		if away.length() < 0.15:
			away = Vector2.UP
		player.knockback = away * 360.0
		player.take_hit(src)
		Game.say("Ash gives. You catch the rim.", 1.5)
		return
	player.global_position = land.landing_global()
	Game.shake.emit(9.0)
	Game.say("The floor gives way.", 1.6)
	_enter_room(land, false)


func on_enemy_died(enemy: Enemy) -> void:
	if current == null:
		return
	var left := 0
	for node in actors.get_children():
		if node is Enemy and (node as Enemy).alive:
			var er := node as Enemy
			if er.get_meta("room", "") == current.room_id:
				left += 1
	if left <= 0 and not current.cleared:
		current.unlock_doors()
		_clear_enemy_bullets()
		if player:
			player.i_timer = 0.28
		Game.room_cleared.emit()
		if current.kind != Room.Kind.BOSS:
			Game.say(Flavor.pick(Flavor.CLEAR), 1.8)
	ui.set_minimap(rooms, current)


func _clear_enemy_bullets() -> void:
	for b in projectiles.get_children():
		if b is Bullet and (b as Bullet).from_enemy:
			b.queue_free()


func _on_shake(amount: float) -> void:
	shake_t = 0.18
	shake_amp = amount


func _on_died() -> void:
	get_tree().paused = true
	ui.show_end(false, Flavor.death_line())


func _on_won() -> void:
	await get_tree().create_timer(1.1).timeout
	get_tree().paused = true
	ui.show_end(true, Flavor.WIN[0] + "\n" + Flavor.WIN[1])


func _qa_proof() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var origin := current.center_global()
	var arts: Array[String] = ["player", "imp", "wretch", "cantor", "boss", "ember", "bone", "deflect"]
	var cols: Array[Color] = [
		Palette.EMBER_HOT, Palette.EMBER, Palette.EMBER, Palette.ROBE_LIGHT,
		Palette.HELL_RED, Palette.EMBER_HOT, Palette.BONE, Palette.BONE,
	]
	for i in arts.size():
		spawn_bullet(
			origin + Vector2(-280.0 + float(i) * 72.0, -90.0),
			Vector2.RIGHT,
			12.0,
			arts[i] != "player",
			cols[i],
			6.0,
			0.0,
			8.0,
			0.0,
			0.0,
			arts[i]
		)
	spawn_pickup(Pickup.Kind.HEART, origin + Vector2(-140, 100))
	spawn_pickup(Pickup.Kind.EMBER, origin + Vector2(-70, 100))
	spawn_pickup(Pickup.Kind.MAX_HEART, origin + Vector2(0, 100))
	spawn_pickup(Pickup.Kind.PIERCE, origin + Vector2(70, 100))
	spawn_pickup(Pickup.Kind.RAPID, origin + Vector2(140, 100))
	spawn_hazard(Hazard.Kind.CROSS, origin, current)
	await get_tree().create_timer(0.4).timeout
	_qa_shot("qa_shots_pickups_cross")
	for n in projectiles.get_children():
		if n is Hazard:
			n.queue_free()
	await get_tree().process_frame
	spawn_hazard(Hazard.Kind.RING, origin, current)
	spawn_hazard(Hazard.Kind.SLAM, origin, current)
	await get_tree().create_timer(0.4).timeout
	_qa_shot("qa_ring_slam")
	for n in projectiles.get_children():
		if n is Hazard:
			n.queue_free()
	await get_tree().process_frame
	spawn_hazard(Hazard.Kind.DIAG, origin, current)
	spawn_hazard(Hazard.Kind.LANES, origin, current)
	await get_tree().create_timer(0.4).timeout
	_qa_shot("qa_diag_lanes")
	var grant := Pickup.apply(roll_item())
	Game.say("QA Concierge: " + grant, 2.0)
	var dest: Room = drop_room()
	var before := player.global_position
	var src_id := current.room_id
	# Walk into the Area2D — do not call fall_from() here.
	player.global_position = current.pit_global()
	await get_tree().create_timer(0.35).timeout
	_qa_shot("qa_pit_landing")
	print("QA_PIT src=", src_id, " dest=", current.room_id if current else "?", " before=", before, " after=", player.global_position, " dest_ok=", dest != null)
	print("QA_CONCIERGE ", grant)
	get_tree().quit()


func _look_dump() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	_qa_shot("doors")
	_qa_shot("hud")
	var origin := current.center_global()
	var arts: Array[String] = ["player", "imp", "wretch", "cantor", "boss", "ember", "bone", "deflect"]
	var cols: Array[Color] = [
		Palette.EMBER, Palette.EMBER, Palette.BONE, Palette.BONE,
		Palette.EMBER, Palette.EMBER, Palette.BONE, Palette.EMBER,
	]
	for i in arts.size():
		spawn_bullet(
			origin + Vector2(-280.0 + float(i) * 72.0, -40.0),
			Vector2.RIGHT,
			8.0,
			arts[i] != "player",
			cols[i],
			6.0,
			0.0,
			8.0,
			0.0,
			0.0,
			arts[i]
		)
	await get_tree().create_timer(0.35).timeout
	_qa_shot("shots")
	for n in projectiles.get_children():
		if n is Bullet:
			n.queue_free()
	if player and current:
		player.global_position = current.pit_global() + Vector2(118, 0)
		camera.global_position = current.pit_global()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_qa_shot("pit")
	if player:
		player.global_position = rooms[Vector2i.ZERO].center_global()
		camera.global_position = rooms[Vector2i.ZERO].center_global()


func _qa_shot(shot_name: String) -> void:
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("/workspace/gate")
	img.save_png("/workspace/gate/%s.png" % shot_name)
	img.save_png("/opt/cursor/artifacts/%s.png" % shot_name)
