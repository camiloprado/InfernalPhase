class_name Floor
extends Node2D

const LAYOUT := [
	{ "id": "start", "grid": Vector2i(0, 0), "kind": Room.Kind.START, "pack": [] },
	{ "id": "north", "grid": Vector2i(0, -1), "kind": Room.Kind.COMBAT, "pack": ["imp", "imp"] },
	{ "id": "west", "grid": Vector2i(-1, 0), "kind": Room.Kind.COMBAT, "pack": ["wretch"] },
	{ "id": "east", "grid": Vector2i(1, 0), "kind": Room.Kind.COMBAT, "pack": ["cantor"] },
	{ "id": "npc", "grid": Vector2i(2, 0), "kind": Room.Kind.NPC, "pack": [] },
	{ "id": "south", "grid": Vector2i(0, 1), "kind": Room.Kind.COMBAT, "pack": ["cultist", "cultist"] },
	{ "id": "se", "grid": Vector2i(1, 1), "kind": Room.Kind.COMBAT, "pack": ["wretch", "imp"] },
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


func _ready() -> void:
	add_to_group("floor")
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.reset_run()
	Game.shake.connect(_on_shake)
	Game.died.connect(_on_died)
	Game.won.connect(_on_won)
	_build_floor()
	_spawn_player()
	_enter_room(rooms[Vector2i.ZERO], true)
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


func _spawn_player() -> void:
	player = _player_scene.instantiate()
	actors.add_child(player)
	player.global_position = rooms[Vector2i.ZERO].center_global()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.make_current()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		Game.restart_floor()
		return
	if Game.is_dead or Game.is_won:
		return
	if player == null:
		return
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
		actors.add_child(enemy)
		var at := room.spawn_offset(i, total)
		enemy.configure(KIND_MAP[key], at, key == "cantor")
		enemy.set_meta("room", room.room_id)
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
		angular: float = 0.0
	) -> Bullet:
	var b: Bullet = _bullet_scene.instantiate()
	projectiles.add_child(b)
	b.setup(origin, dir, speed, from_enemy, color, radius, sine_amp, sine_freq, sine_phase, angular)
	return b


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
			player.i_timer = 0.7
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
	ui.show_end(false, Flavor.pick(Flavor.DEATH))


func _on_won() -> void:
	await get_tree().create_timer(1.1).timeout
	get_tree().paused = true
	ui.show_end(true, Flavor.WIN[0] + "\n" + Flavor.WIN[1])
