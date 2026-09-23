class_name Bullet
extends Area2D

var velocity := Vector2.ZERO
var from_enemy := true
var radius := 5.0
var color := Palette.HELL_RED
var age := 0.0
var lifetime := 4.5
var origin := Vector2.ZERO
var dir := Vector2.RIGHT
var speed := 200.0
var sine_amp := 0.0
var sine_freq := 8.0
var sine_phase := 0.0
var angular := 0.0
var parametric := true
var damage := 1
var spent := false
var deflected := false
var pierce_left := 0
var burn := false
var _hit: Dictionary = {}
var _shot_art := ""
var _spr: AnimatedSprite2D
var _core: Sprite2D
var _base_scale := Vector2.ONE
var _spin_rate := 0.0
var _face_travel := true
var _pulse_phase := 0.0

const SHOT_SHEET := "res://assets/sprites/shots.png"

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	z_index = 20


func setup(
		p_origin: Vector2,
		p_dir: Vector2,
		p_speed: float,
		p_from_enemy: bool,
		p_color: Color,
		p_radius: float = 5.0,
		p_sine_amp: float = 0.0,
		p_sine_freq: float = 8.0,
		p_sine_phase: float = 0.0,
		p_angular: float = 0.0,
		p_art: String = ""
	) -> void:
	origin = p_origin
	global_position = p_origin
	dir = p_dir.normalized()
	speed = p_speed
	velocity = dir * speed
	from_enemy = p_from_enemy
	color = p_color
	radius = p_radius
	sine_amp = p_sine_amp
	sine_freq = p_sine_freq
	sine_phase = p_sine_phase
	angular = p_angular
	parametric = is_zero_approx(p_angular)
	collision_layer = 16 if from_enemy else 8
	# Enemy shots hit walls as bodies; the player's 8px hurtbox detects them as areas.
	# Do not also collide with the 14px CharacterBody2D or one pellet can eat two hearts.
	if from_enemy:
		collision_mask = 1
	else:
		collision_mask = 5  # world + enemies
	monitorable = true
	monitoring = true
	var circle := CircleShape2D.new()
	circle.radius = radius
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape)
	_shape.shape = circle
	bind_shot(p_art)


func _physics_process(delta: float) -> void:
	age += delta
	if age > lifetime:
		queue_free()
		return
	if parametric and is_zero_approx(angular):
		var along := dir * speed * age
		var side := Vector2(-dir.y, dir.x) * sin(age * sine_freq + sine_phase) * sine_amp
		global_position = origin + along + side
	else:
		if not is_zero_approx(angular):
			velocity = velocity.rotated(angular * delta)
		global_position += velocity * delta
	if _spr:
		_animate_shot(delta)


func bind_shot(art: String) -> void:
	_shot_art = art
	if _spr:
		_spr.queue_free()
		_spr = null
	if _core:
		_core.queue_free()
		_core = null
	var row := _shot_row()
	_spr = Sprites.actor(
		SHOT_SHEET,
		4,
		8,
		{"fly": {"row": row, "fps": 24.0, "loop": true}},
		maxf(radius * 5.2, 24.0),
		true
	)
	_pulse_phase = randf() * TAU
	_configure_motion(row)
	if _spr:
		Sprites.ping_pong(_spr, &"fly")
		Sprites.stagger(_spr, 24.0)
		_base_scale = _spr.scale
		add_child(_spr)
		if _face_travel:
			_spr.rotation = _travel().angle()
		else:
			_spr.rotation = _pulse_phase
		# Hard silhouettes only — no soft inner orb.


func _shot_row() -> int:
	var key := _shot_art
	if deflected:
		key = "deflect"
	elif key.is_empty():
		if not from_enemy:
			key = "player"
		elif color.is_equal_approx(Palette.ROBE_LIGHT):
			key = "cantor"
		elif color.is_equal_approx(Palette.BONE):
			key = "bone"
		elif color.is_equal_approx(Palette.HELL_RED):
			key = "boss"
		elif color.is_equal_approx(Palette.EMBER_HOT):
			key = "ember"
		else:
			key = "imp"
	match key:
		"player":
			return 0
		"imp":
			return 1
		"wretch":
			return 2
		"cantor":
			return 3
		"boss":
			return 4
		"ember":
			return 5
		"bone":
			return 6
		"deflect":
			return 7
	return 1


func _configure_motion(row: int) -> void:
	# Coal shards and Ash tears point along travel. Bone chips tumble.
	match row:
		2, 4, 6:
			_face_travel = false
			_spin_rate = 3.2
		_:
			_face_travel = true
			_spin_rate = 0.0


func _travel() -> Vector2:
	if not parametric and velocity.length_squared() > 4.0:
		return velocity
	return dir


func _bind_core() -> void:
	if _spr == null or _spr.sprite_frames == null:
		return
	if not _spr.sprite_frames.has_animation(&"fly"):
		return
	if _spr.sprite_frames.get_frame_count(&"fly") < 1:
		return
	_core = Sprite2D.new()
	_core.texture = _spr.sprite_frames.get_frame_texture(&"fly", 0)
	_core.centered = true
	_core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_core.z_index = 1
	_core.modulate = Color(1.45, 1.05, 0.55, 0.55)
	add_child(_core)


func _animate_shot(delta: float) -> void:
	var beat := age * 18.0 + _pulse_phase
	var pulse := 1.0 + 0.10 * sin(beat)
	_spr.modulate = Color.WHITE
	_spr.scale = _base_scale * pulse
	_spr.position = Vector2.ZERO
	if _face_travel:
		_spr.rotation = _travel().angle()
	else:
		_spr.rotation += _spin_rate * delta
	if _core:
		_core.queue_free()
		_core = null


func deflect(from: Vector2) -> void:
	if spent or deflected:
		return
	deflected = true
	from_enemy = false
	var away := (global_position - from)
	if away.length() < 0.2:
		away = -dir
	dir = away.normalized()
	speed = maxf(speed, 220.0) * 1.2
	velocity = dir * speed
	parametric = false
	angular = 0.0
	color = Palette.BONE
	collision_layer = 8
	collision_mask = 5
	Game.shake.emit(4.0)
	bind_shot("deflect")
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if spent:
		return
	if body is Player and from_enemy:
		if Game.is_baby():
			deflect(body.global_position)
			return
		(body as Player).take_hit(self)
		_spend()
	elif body is Enemy and not from_enemy:
		_hit_enemy(body as Enemy)
	elif body is StaticBody2D:
		_spend()


func _on_area_entered(area: Node) -> void:
	if spent:
		return
	if area is Player and from_enemy:
		(area as Player).take_hit(self)
		_spend()


func _hit_enemy(en: Enemy) -> void:
	var id := en.get_instance_id()
	if _hit.has(id):
		return
	_hit[id] = true
	en.take_hit(damage)
	if burn:
		en.apply_burn(1, 0.42)
	if pierce_left > 0:
		pierce_left -= 1
		return
	_spend()


func _spend() -> void:
	if spent:
		return
	spent = true
	queue_free()
