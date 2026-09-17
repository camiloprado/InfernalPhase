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
	Sprites.require_gameplay()
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
			if ui:
				ui.visible = false
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().create_timer(0.35).timeout
			_qa_shot("start", true, "start_card")
			print("LOOK_START penitent=1 who_walks=0 ember_cta=SWEAR_IN")
			if ui:
				ui.visible = true
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
	if look or qa:
		_look_wire_log()
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
	var display_imp := _spawn_look_imp()
	await get_tree().process_frame
	_pixel_wire_log(display_imp)
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
	if display_imp and is_instance_valid(display_imp):
		display_imp.queue_free()
	get_tree().quit()


func _look_wire_log() -> void:
	var d := Sprites.tex("res://assets/sprites/doors.png")
	var h := Sprites.tex("res://assets/sprites/hearts.png")
	var s := Sprites.tex("res://assets/sprites/shots.png")
	var p := Sprites.tex("res://assets/env/pit.png")
	print(
		"LOOK_WIRE doors=", _tex_size(d),
		" hearts=", _tex_size(h),
		" shots=", _tex_size(s),
		" pit=", _tex_size(p),
		" disk=1 src_doors=", Sprites.src_of("res://assets/sprites/doors.png"),
		" src_hearts=", Sprites.src_of("res://assets/sprites/hearts.png")
	)


func _pixel_wire_log(imp: Enemy = null) -> void:
	var player_path := "res://assets/sprites/player.png"
	var door_cell := Sprites.cell("res://assets/sprites/doors.png", 4, 2, 0, 0)
	var heart_cell := Sprites.cell("res://assets/sprites/hearts.png", 4, 1, 0, 0)
	var shot_actor := Sprites.actor(
		"res://assets/sprites/shots.png",
		4,
		8,
		{"fly": {"row": 0, "fps": 8.0, "loop": true}},
		24.0
	)
	var player_sheet := 1 if player != null and player.has_pixel() else 0
	var player_body := 1 if Sprites.is_character_body(player_path, 4, 4) else 0
	if Game.body == Game.Body.LILITH:
		player_body = 1 if Sprites.is_character_body("res://assets/sprites/player_f.png") else 0
	var caim_own := 1 if Sprites.is_caim_own_body() else 0
	var door_spr := 0
	if current:
		for dir in current._door_art.keys():
			if current._door_art[dir] is Sprite2D:
				door_spr = 1
				break
	var enemy_art := 1 if imp and imp.art else 0
	if enemy_art == 0:
		for n in actors.get_children():
			if n is Enemy and (n as Enemy).art:
				enemy_art = 1
				break
	var doors := 1 if door_cell != null and door_spr == 1 else 0
	var hearts := 1 if heart_cell != null else 0
	var ok := 1 if player_sheet == 1 and player_body == 1 and caim_own == 1 and enemy_art == 1 and doors == 1 and hearts == 1 else 0
	print(
		"QA_ASSERT player_sheet=", player_sheet,
		" player_body=", player_body,
		" caim_own=", caim_own,
		" enemy_art=", enemy_art,
		" doors=", doors,
		" hearts=", hearts,
		" src=", Sprites.src_of(player_path),
		" ok=", ok
	)
	if ok != 1:
		push_error("QA_ASSERT FAIL player_sheet=%s player_body=%s caim_own=%s enemy_art=%s doors=%s hearts=%s" % [player_sheet, player_body, caim_own, enemy_art, doors, hearts])
		printerr("QA_ASSERT FAIL ok=0")
	print(
		"PIXEL_WIRE player_tex=", _tex_size(Sprites.tex(player_path)),
		" src=", Sprites.src_of(player_path),
		" player_sheet=", player_sheet,
		" doors_cell=", 1 if door_cell else 0,
		" hearts_cell=", hearts,
		" shots_actor=", 1 if shot_actor else 0,
		" door_sprite=", door_spr,
		" imp_tex=", _tex_size(Sprites.tex("res://assets/characters/imp/walk_vanilla.png")),
		" imp_art=", enemy_art,
		" rl_player=", 1 if ResourceLoader.exists(player_path) else 0
	)
	if shot_actor:
		shot_actor.free()


func _tex_size(t: Texture2D) -> String:
	if t == null:
		return "missing"
	return "%dx%d" % [t.get_width(), t.get_height()]


func _look_dump() -> void:
	# F5 plates first (HUD + doors + pit as after Swear In), then isolated crops.
	if camera:
		camera.position_smoothing_enabled = false
		camera.zoom = Vector2.ONE
		if current:
			camera.global_position = current.center_global()
			camera.reset_smoothing()
	if current:
		current.set_door_sprites_visible(true)
		# Ember lit seal on the north arch; south / east / west stay cracked-open.
		current._set_door_blocked(Room.Dir.N, true)
	if ui:
		ui.visible = true
		ui.hint.visible = true
	if player and current:
		player.global_position = current.center_global() + Vector2(-40, 36)
		player.set_physics_process(false)
		player.aim = Vector2.DOWN
		player.velocity = Vector2.ZERO
		player._sync_sheet()
	var display_imp: Enemy = _spawn_look_imp()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	_pixel_wire_log(display_imp)
	_qa_shot("f5_threshold", true, "f5_threshold")
	if camera and player:
		camera.zoom = Vector2(4.0, 4.0)
		camera.global_position = player.global_position
		camera.reset_smoothing()
	await get_tree().process_frame
	_qa_shot("f5_caim_body", true, "f5_caim_body")
	if camera and current:
		camera.zoom = Vector2.ONE
		camera.global_position = current.center_global()
		camera.reset_smoothing()
	# Lilith: player-female-v2 → player_f.png. Caim stays on the generated
	# top-down male walker (player.png) — never the female or baby atlas.
	Game.body = Game.Body.LILITH
	if player:
		player.rebind_visual()
	if ui:
		ui.set_walker(Game.walker_label(), "")
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	_qa_shot("f5_threshold_lilith", true, "f5_threshold_lilith")
	if camera and player:
		camera.zoom = Vector2(4.0, 4.0)
		camera.global_position = player.global_position
		camera.reset_smoothing()
	await get_tree().process_frame
	_qa_shot("f5_lilith_body", true, "f5_lilith_body")
	if camera and current:
		camera.zoom = Vector2.ONE
		camera.global_position = current.center_global()
		camera.reset_smoothing()
	Game.body = Game.Body.CAIM
	if player:
		player.rebind_visual()
	if ui:
		ui.set_walker(Game.walker_label(), "")
	_qa_shot("doors", true, "doors")
	_spawn_look_shots()
	await get_tree().create_timer(0.35).timeout
	_qa_shot("f5_shots", true, "f5_shots")
	_qa_shot("shots", true, "shots")
	for n in projectiles.get_children():
		if n is Bullet:
			n.queue_free()
	await get_tree().process_frame
	if current:
		current._set_door_blocked(Room.Dir.N, false)
	# Mixed seals so the HUD crop shows full / hit / empty — combat numbers restore after.
	var keep_h := Game.hearts
	var keep_max := Game.max_hearts
	Game.hearts = 2
	Game.max_hearts = 4
	Game.hearts_changed.emit(2, 4)
	if current:
		current.set_door_sprites_visible(false)
	if ui:
		ui.hint.visible = false
		if ui.minimap:
			ui.minimap.visible = true
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	_qa_hud_crop()
	Game.hearts = keep_h
	Game.max_hearts = keep_max
	Game.hearts_changed.emit(keep_h, keep_max)
	if ui:
		ui.hint.visible = true
	await _qa_pit_still()
	if current:
		current.set_door_sprites_visible(true)
	if player:
		player.global_position = rooms[Vector2i.ZERO].center_global()
		if camera:
			camera.zoom = Vector2.ONE
			camera.global_position = rooms[Vector2i.ZERO].center_global()
	await _qa_combat_still(display_imp)
	if display_imp and is_instance_valid(display_imp):
		display_imp.queue_free()


func _spawn_look_imp() -> Enemy:
	if player == null:
		return null
	var imp: Enemy = _enemy_scene.instantiate()
	actors.add_child(imp)
	imp.configure(Enemy.Kind.IMP, player.global_position + Vector2(92, 16))
	imp.set_physics_process(false)
	return imp


func _qa_combat_still(display_imp: Enemy) -> void:
	var east: Room = rooms.get(Vector2i(1, 0))
	if east == null or player == null or camera == null:
		return
	if display_imp and is_instance_valid(display_imp):
		display_imp.visible = false
	player.global_position = east.center_global() + Vector2(-70, 40)
	_enter_room(east, true)
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE
	camera.global_position = east.center_global()
	camera.reset_smoothing()
	if ui:
		ui.visible = true
	east.set_door_sprites_visible(true)
	await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	var live_imp: Enemy = null
	for n in actors.get_children():
		if n is Enemy and (n as Enemy).kind == Enemy.Kind.IMP and (n as Enemy).alive:
			live_imp = n
			break
	_pixel_wire_log(live_imp)
	_qa_shot("f5_combat", true, "f5_combat")
	var start: Room = rooms.get(Vector2i.ZERO)
	if start:
		player.global_position = start.center_global()
		_enter_room(start, true)
		camera.global_position = start.center_global()


func _spawn_look_shots() -> void:
	if current == null:
		return
	var origin := current.center_global()
	var arts: Array[String] = ["player", "imp", "wretch", "cantor", "boss", "ember", "bone", "deflect"]
	var cols: Array[Color] = [
		Palette.EMBER, Palette.EMBER, Palette.BONE, Palette.BONE,
		Palette.EMBER, Palette.EMBER, Palette.BONE, Palette.EMBER,
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


func _qa_hud_crop() -> void:
	# Full top bar, doors hidden: Bone seals + Ember glyph + circular map. 1280×130 ≠ doors.
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	var crop := img.get_region(Rect2i(0, 0, img.get_width(), mini(130, img.get_height())))
	_write_look("hud", crop)
	crop.save_png("/workspace/gate/hud.png")
	crop.save_png("/opt/cursor/artifacts/hud.png")


func _qa_pit_still() -> void:
	# Close plate: Void-deep mouth + thin Ash/Bone lip + player on the lip.
	# Doors and HUD hidden so this cannot be read as a doors / hoop still.
	var start: Room = rooms.get(Vector2i.ZERO)
	if start == null or player == null or camera == null or not start.has_pit:
		return
	start.set_door_sprites_visible(false)
	if ui:
		ui.visible = false
	player.global_position = start.pit_global() + Vector2(-118.0, 8.0)
	camera.zoom = Vector2(1.55, 1.55)
	camera.global_position = start.pit_global() + Vector2(-36.0, 0.0)
	camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	var cw := img.get_width()
	var ch := img.get_height()
	var rw := mini(900, cw)
	var rh := mini(580, ch)
	var rx := maxi((cw - rw) / 2, 0)
	var ry := maxi((ch - rh) / 2, 0)
	var crop := img.get_region(Rect2i(rx, ry, rw, rh))
	_write_look("pit", crop)
	crop.save_png("/workspace/gate/pit.png")
	crop.save_png("/opt/cursor/artifacts/pit.png")
	if ui:
		ui.visible = true


func _qa_shot(shot_name: String, to_gate: bool = false, look_name: String = "") -> void:
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if to_gate:
		DirAccess.make_dir_recursive_absolute("/workspace/gate")
		img.save_png("/workspace/gate/%s.png" % shot_name)
		if look_name != "":
			_write_look(look_name, img)
	img.save_png("/opt/cursor/artifacts/%s.png" % shot_name)


func _write_look(look_name: String, img: Image) -> void:
	DirAccess.make_dir_recursive_absolute("/workspace/gate/look")
	img.save_png("/workspace/gate/look/look_%s.png" % look_name)
	img.save_jpg("/workspace/gate/look/look_%s.jpg" % look_name, 0.84)
	img.save_png("/opt/cursor/artifacts/look_%s.png" % look_name)
