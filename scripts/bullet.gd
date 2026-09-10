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
	queue_redraw()


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
	else:
		queue_redraw()


func bind_shot(art: String) -> void:
	_shot_art = art
	if _spr:
		_spr.queue_free()
		_spr = null
	var row := _shot_row()
	_spr = Sprites.actor(
		SHOT_SHEET,
		4,
		8,
		{"fly": {"row": row, "fps": 18.0, "loop": true}},
		maxf(radius * 5.2, 24.0)
	)
	_pulse_phase = randf() * TAU
	_configure_motion(row)
	if _spr:
		Sprites.ping_pong(_spr, &"fly")
		Sprites.stagger(_spr, 18.0)
		_base_scale = _spr.scale
		add_child(_spr)
		if _face_travel:
			_spr.rotation = _travel().angle()
		else:
			_spr.rotation = _pulse_phase


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
	# Orbs (ring, skull, ember, deflect) spin; bolts keep a travel heading plus a wobble.
	match row:
		2:
			_face_travel = false
			_spin_rate = 5.6
		4:
			_face_travel = false
			_spin_rate = 3.4
		5:
			_face_travel = false
			_spin_rate = 4.2
		7:
			_face_travel = false
			_spin_rate = 8.0
		_:
			_face_travel = true
			_spin_rate = 0.0


func _travel() -> Vector2:
	if not parametric and velocity.length_squared() > 4.0:
		return velocity
	return dir


func _animate_shot(delta: float) -> void:
	var pulse := 1.0 + 0.09 * sin(age * 14.0 + _pulse_phase)
	var flick := 0.86 + 0.14 * absf(sin(age * 17.0 + _pulse_phase * 0.7))
	_spr.scale = _base_scale * pulse
	_spr.modulate = Color(1.08 * flick, 0.96 * flick + 0.04, 0.88 * flick + 0.08, 1.0)
	if _face_travel:
		_spr.rotation = _travel().angle() + 0.14 * sin(age * 11.0 + _pulse_phase)
	else:
		_spr.rotation += _spin_rate * delta
		_spr.position = Vector2.RIGHT.rotated(age * 9.0 + _pulse_phase) * 1.4


func _draw() -> void:
	if _spr:
		return
	var pulse := 1.0 + 0.12 * sin(age * 16.0)
	var glow := color.lightened(0.35)
	glow.a = 0.35
	if deflected:
		glow = Palette.BONE
		glow.a = 0.55
		draw_arc(Vector2.ZERO, (radius + 7.0) * pulse, 0.0, TAU, 16, Palette.EMBER_HOT, 2.0, true)
	draw_circle(Vector2.ZERO, (radius + 4.0) * pulse, glow)
	draw_circle(Vector2.ZERO, radius * pulse, color)
	draw_circle(Vector2.ZERO, maxf(radius * 0.35, 1.5) * pulse, Palette.BONE if from_enemy else Palette.EMBER_HOT)


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
