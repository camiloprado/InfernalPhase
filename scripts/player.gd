class_name Player
extends CharacterBody2D

const SPEED := 268.0
const FIRE_CD := 0.15
const I_FRAMES := 1.05
const RADIUS := 16.0

var aim := Vector2.RIGHT
var fire_left := 0.0
var i_timer := 0.0
var blink := false
var knockback := Vector2.ZERO
var _hit_stamp_ms := -99999

@onready var _hurt: Area2D = $Hurtbox
@onready var _col: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	z_index = 8
	add_to_group("player")
	var circle := CircleShape2D.new()
	circle.radius = RADIUS - 2.0
	_col.shape = circle
	var hurt_shape := CircleShape2D.new()
	hurt_shape.radius = 8.0
	$Hurtbox/CollisionShape2D.shape = hurt_shape
	_hurt.collision_layer = 2
	_hurt.collision_mask = 20  # enemies + enemy bullets
	_hurt.area_entered.connect(_on_hurt_area)
	_hurt.body_entered.connect(_on_hurt_body)


func _physics_process(delta: float) -> void:
	if Game.is_dead or Game.is_won:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var wasd := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var arrows := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var move_vec := wasd
	if move_vec.length() < 0.15:
		move_vec = arrows

	velocity = move_vec.limit_length(1.0) * SPEED + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 980.0 * delta)
	move_and_slide()

	var mouse_aim := (get_global_mouse_position() - global_position)
	var dual := wasd.length() > 0.15 and arrows.length() > 0.25
	if dual:
		aim = arrows.normalized()
	elif arrows.length() > 0.35:
		aim = arrows.normalized()
	elif mouse_aim.length() > 4.0:
		aim = mouse_aim.normalized()
	elif velocity.length() > 12.0:
		aim = velocity.normalized()

	fire_left = maxf(fire_left - delta, 0.0)
	i_timer = maxf(i_timer - delta, 0.0)
	if i_timer > 0.0:
		blink = int(i_timer * 18.0) % 2 == 0
	else:
		blink = false

	var want_shoot := Input.is_action_pressed("shoot") or dual or (arrows.length() > 0.5)
	if want_shoot and fire_left <= 0.0:
		_shoot()

	queue_redraw()


func _shoot() -> void:
	fire_left = FIRE_CD
	var floor_node := get_tree().get_first_node_in_group("floor") as Floor
	if floor_node == null:
		return
	var muzzle := global_position + aim * (RADIUS + 8.0)
	floor_node.spawn_bullet(muzzle, aim, 560.0, false, Palette.EMBER_HOT, 4.5)


func take_hit(_source: Node = null) -> void:
	if Game.is_dead or Game.is_won:
		return
	var now := Time.get_ticks_msec()
	if i_timer > 0.0 or now - _hit_stamp_ms < int(I_FRAMES * 1000.0):
		return
	_hit_stamp_ms = now
	i_timer = I_FRAMES
	var from := Vector2.RIGHT.rotated(Game.rng.randf() * TAU)
	if _source is Node2D:
		from = (global_position - (_source as Node2D).global_position).normalized()
	knockback = from * 280.0
	Game.hurt(1)
	queue_redraw()


func _on_hurt_area(area: Area2D) -> void:
	if area is Bullet and (area as Bullet).from_enemy:
		take_hit(area)
		(area as Bullet)._spend()


func _on_hurt_body(body: Node) -> void:
	if body is Enemy:
		take_hit(body)


func _draw() -> void:
	if blink:
		return
	var body_col := Palette.PLAYER
	if i_timer > 0.0:
		body_col = Palette.EMBER
	draw_circle(Vector2.ZERO, RADIUS + 6.0, Color(Palette.EMBER.r, Palette.EMBER.g, Palette.EMBER.b, 0.18))
	var pts := PackedVector2Array([
		aim * (RADIUS + 4.0),
		aim.rotated(2.15) * RADIUS,
		aim.rotated(PI) * (RADIUS * 0.7),
		aim.rotated(-2.15) * RADIUS,
	])
	draw_colored_polygon(pts, body_col)
	draw_circle(Vector2.ZERO, 5.0, Palette.PLAYER_CORE)
	draw_circle(Vector2.ZERO, 2.0, Palette.EMBER_HOT)
