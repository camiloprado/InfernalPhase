class_name Pickup
extends Area2D
## Ground loot. Pulse so it reads against ash floor.

enum Kind { HEART }

var kind: Kind = Kind.HEART
var _age := 0.0
var _taken := false
var _icon: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 9
	body_entered.connect(_on_body)
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	col.shape = circle
	add_child(col)
	_icon = Sprite2D.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.centered = true
	_icon.texture = Sprites.cell("res://assets/sprites/pickups.png", 3, 1, 0, 0)
	if _icon.texture:
		_icon.scale = Vector2.ONE * 0.9
		add_child(_icon)
	else:
		_icon.queue_free()
		_icon = null


func setup(p_kind: Kind, at: Vector2) -> void:
	kind = p_kind
	global_position = at


func _process(delta: float) -> void:
	_age += delta
	if _icon:
		_icon.position.y = sin(_age * 3.4) * 4.0
	queue_redraw()


func _on_body(body: Node) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	Game.heal(1)
	Game.say("A brimstone heart. Don't get used to it.", 1.6)
	queue_free()


func _draw() -> void:
	var pulse := 0.55 + 0.45 * sin(_age * 6.2)
	var bob := Vector2(0, sin(_age * 3.4) * 4.0)
	var glow := Palette.EMBER_HOT
	glow.a = 0.22 + 0.28 * pulse
	draw_circle(bob, 22.0 + pulse * 8.0, glow)
	if _icon:
		return
	var ring := Palette.EMBER
	ring.a = 0.85
	draw_arc(bob, 16.0 + pulse * 3.0, 0.0, TAU, 28, ring, 2.4, true)
	var s := 11.0
	var pts := PackedVector2Array([
		bob + Vector2(0, s * 0.9),
		bob + Vector2(-s * 0.85, -s * 0.05),
		bob + Vector2(-s * 0.35, -s * 0.7),
		bob + Vector2(0, -s * 0.25),
		bob + Vector2(s * 0.35, -s * 0.7),
		bob + Vector2(s * 0.85, -s * 0.05),
	])
	draw_colored_polygon(pts, Palette.HELL_RED)
	draw_circle(bob + Vector2(-3, -2), 2.0, Palette.EMBER_HOT)
