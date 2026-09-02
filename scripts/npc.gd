class_name Concierge
extends Area2D

var line_i := 0
var cooldown := 0.0
var shown := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 90.0
	shape.shape = circle
	add_child(shape)
	z_index = 6


func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	queue_redraw()


func _on_body(body: Node) -> void:
	if not body is Player:
		return
	if cooldown > 0.0:
		return
	if not shown:
		Game.heal(1)
		Game.say("\"One heart. Don't tell payroll. The boss is south of here.\"", 3.6)
	else:
		Game.say(Flavor.NPC[line_i % Flavor.NPC.size()], 3.6)
		line_i += 1
	cooldown = 4.2
	shown = true


func _draw() -> void:
	# Desk
	draw_rect(Rect2(-46, 10, 92, 28), Palette.ASH_MID)
	draw_rect(Rect2(-50, 8, 100, 6), Palette.BONE_DIM)
	# Skeleton concierge
	draw_circle(Vector2(0, -28), 14.0, Palette.BONE)
	draw_circle(Vector2(-5, -30), 2.4, Palette.VOID)
	draw_circle(Vector2(5, -30), 2.4, Palette.VOID)
	draw_arc(Vector2(0, -24), 5.0, 0.2, PI - 0.2, 8, Palette.VOID, 1.5, true)
	draw_rect(Rect2(-11, -14, 22, 28), Palette.BONE_DIM)
	draw_rect(Rect2(-18, -8, 8, 22), Palette.BONE)
	draw_rect(Rect2(10, -8, 8, 22), Palette.BONE)
	draw_circle(Vector2(0, -44), 4.0, Palette.EMBER)
	draw_line(Vector2(-22, -6), Vector2(-34, 8), Palette.BONE_DIM, 3.0)
	draw_line(Vector2(22, -6), Vector2(38, -2), Palette.BONE_DIM, 3.0)
