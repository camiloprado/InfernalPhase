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
		p_angular: float = 0.0
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
	queue_redraw()


func _draw() -> void:
	var glow := color.lightened(0.35)
	glow.a = 0.35
	if deflected:
		glow = Palette.BONE
		glow.a = 0.55
		draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 16, Palette.EMBER_HOT, 2.0, true)
	draw_circle(Vector2.ZERO, radius + 4.0, glow)
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, maxf(radius * 0.35, 1.5), Palette.BONE if from_enemy else Palette.EMBER_HOT)


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
		(body as Enemy).take_hit(1)
		_spend()
	elif body is StaticBody2D:
		_spend()


func _on_area_entered(area: Node) -> void:
	if spent:
		return
	if area is Player and from_enemy:
		(area as Player).take_hit(self)
		_spend()


func _spend() -> void:
	if spent:
		return
	spent = true
	queue_free()
