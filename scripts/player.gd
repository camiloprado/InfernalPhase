class_name Player
extends CharacterBody2D

const SPEED := 258.0
const FIRE_CD := 0.2
const RADIUS := 16.0
const BABY_SHEET := "res://assets/sprites/baby.png"

var aim := Vector2.RIGHT
var fire_left := 0.0
var i_timer := 0.0
var blink := false
var knockback := Vector2.ZERO
var _hit_stamp_ms := -99999
var _baby: Sprite2D
var _sheet: AnimatedSprite2D

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
	hurt_shape.radius = 11.0
	$Hurtbox/CollisionShape2D.shape = hurt_shape
	_hurt.collision_layer = 2
	_hurt.collision_mask = 20  # enemies + enemy bullets
	_hurt.area_entered.connect(_on_hurt_area)
	_hurt.body_entered.connect(_on_hurt_body)
	_baby = Sprite2D.new()
	_baby.centered = true
	_baby.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_baby.visible = false
	_baby.z_index = 1
	add_child(_baby)
	rebind_visual()
	Game.loadout_changed.connect(rebind_visual)


func rebind_visual() -> void:
	if _baby == null:
		return
	_baby.visible = false
	if _sheet:
		_sheet.queue_free()
		_sheet = null
	if Game.is_baby():
		var loaded := Sprites.tex(BABY_SHEET)
		if loaded:
			_baby.texture = loaded
			var h := float(loaded.get_height())
			_baby.scale = Vector2.ONE * (48.0 / maxf(h, 1.0))
			_baby.visible = true
		queue_redraw()
		return
	var path := "res://assets/sprites/player_f.png" if Game.body == Game.Body.LILITH else "res://assets/sprites/player.png"
	_sheet = Sprites.actor(
		path,
		4,
		3,
		{
			"idle": {"row": 0, "fps": 5.0, "loop": true},
			"walk": {"row": 1, "fps": 8.0, "loop": true},
			"attack": {"row": 2, "fps": 14.0, "loop": false},
		},
		48.0
	)
	if _sheet:
		add_child(_sheet)
		_sheet.animation_finished.connect(_on_sheet_finished)
	queue_redraw()


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

	_sync_sheet()
	queue_redraw()


func _shoot() -> void:
	var cd := FIRE_CD * (1.0 - 0.2 * float(Game.rapid))
	if Game.heavy > 0:
		cd *= 1.18
	fire_left = cd
	var floor_node := get_tree().get_first_node_in_group("floor") as Floor
	if floor_node == null:
		return
	var count := 1 + Game.rapid
	var arc := 0.0 if count == 1 else 7.0
	var spd := 380.0 if Game.heavy > 0 else 560.0
	var rad := 7.2 if Game.heavy > 0 else (5.2 if Game.ember > 0 else 4.5)
	var col := Palette.EMBER_HOT
	if Game.burn > 0:
		col = Palette.EMBER
	elif Game.heavy > 0:
		col = Palette.BLOOD
	elif Game.ember > 0:
		col = Palette.EMBER
	var start := -arc * 0.5 * float(count - 1)
	for i in count:
		var a := deg_to_rad(start + arc * float(i))
		var dir := aim.rotated(a)
		var muzzle := global_position + dir * (RADIUS + 8.0)
		var shot := floor_node.spawn_bullet(muzzle, dir, spd, false, col, rad, 0.0, 8.0, 0.0, 0.0, "player")
		if shot:
			shot.damage = Game.shot_damage()
			shot.pierce_left = Game.pierce
			shot.burn = Game.burn > 0
	if _sheet:
		_sheet.play("attack")


func take_hit(_source: Node = null) -> void:
	if Game.is_dead or Game.is_won:
		return
	if _source is Bullet and Game.is_baby():
		(_source as Bullet).deflect(global_position)
		return
	var now := Time.get_ticks_msec()
	if i_timer > 0.0 or now - _hit_stamp_ms < Game.IFRAME_MS:
		return
	_hit_stamp_ms = now
	i_timer = float(Game.IFRAME_MS) / 1000.0
	var from := Vector2.RIGHT.rotated(Game.rng.randf() * TAU)
	if _source is Node2D:
		from = (global_position - (_source as Node2D).global_position).normalized()
	knockback = from * 280.0
	Game.hurt(1)
	queue_redraw()


func _on_hurt_area(area: Area2D) -> void:
	if area is Bullet and (area as Bullet).from_enemy:
		if Game.is_baby():
			(area as Bullet).deflect(global_position)
			return
		take_hit(area)
		(area as Bullet)._spend()


func _on_hurt_body(body: Node) -> void:
	if body is Enemy:
		take_hit(body)


func _sync_sheet() -> void:
	if _sheet == null:
		return
	_sheet.visible = not blink
	_sheet.flip_h = aim.x < 0.0
	if i_timer > 0.0 and not blink:
		_sheet.modulate = Color(1.7, 0.55, 0.2)
	elif Game.burn > 0:
		_sheet.modulate = Color(1.25, 0.7, 0.35)
	elif Game.ember > 0 or Game.heavy > 0:
		_sheet.modulate = Color(1.18, 0.82, 0.55)
	else:
		_sheet.modulate = Color.WHITE
	if _sheet.animation == &"attack" and _sheet.is_playing():
		return
	var want := "walk" if velocity.length() > 24.0 else "idle"
	if _sheet.animation != want:
		_sheet.play(want)


func _on_sheet_finished() -> void:
	if _sheet == null:
		return
	if _sheet.animation == &"attack":
		_sheet.play("walk" if velocity.length() > 24.0 else "idle")


func _draw() -> void:
	if blink:
		if _baby:
			_baby.modulate.a = 0.0
		if _sheet:
			_sheet.visible = false
		return
	if _baby:
		_baby.modulate.a = 1.0
		_baby.flip_h = aim.x < -0.15
	if Game.is_baby() and _baby and _baby.visible:
		return
	if _sheet:
		return
	if Game.is_baby():
		var pts := PackedVector2Array([
			Vector2(0, -16),
			Vector2(11, 0),
			Vector2(0, 16),
			Vector2(-11, 0),
		])
		draw_colored_polygon(pts, Palette.BONE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -16),
			Vector2(8, -6),
			Vector2(-8, -6),
		]), Palette.ASH)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -2),
			Vector2(3, 3),
			Vector2(0, 8),
			Vector2(-3, 3),
		]), Palette.EMBER)
		return
	var rx := 12.0 if Game.body == Game.Body.LILITH else 14.0
	var ry := 18.0 if Game.body == Game.Body.LILITH else 16.0
	var body_col := Palette.BONE
	if i_timer > 0.0:
		body_col = Palette.WOUND
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -ry),
		Vector2(rx, 0),
		Vector2(0, ry),
		Vector2(-rx, 0),
	]), body_col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -ry),
		Vector2(rx * 0.7, -ry * 0.2),
		Vector2(-rx * 0.7, -ry * 0.2),
	]), Palette.ASH)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -2),
		Vector2(3, 2),
		Vector2(0, 7),
		Vector2(-3, 2),
	]), Palette.EMBER)
