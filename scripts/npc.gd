class_name Concierge
extends Area2D

var line_i := 0
var cooldown := 0.0
var shown := false
var _sprite: AnimatedSprite2D

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
	_sprite = Sprites.actor(
		"res://assets/sprites/concierge.png",
		4,
		2,
		{
			"idle": {"row": 0, "fps": 3.5, "loop": true},
			"talk": {"row": 1, "fps": 6.0, "loop": true},
		},
		80.0,
		true
	)
	if _sprite:
		add_child(_sprite)


func _process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	if _sprite:
		if Game.in_dialogue or cooldown > 2.2:
			if _sprite.animation != &"talk":
				_sprite.play("talk")
		elif _sprite.animation != &"idle":
			_sprite.play("idle")


func _on_body(body: Node) -> void:
	if not body is Player:
		return
	if Game.in_dialogue:
		return
	if cooldown > 0.0:
		return
	if not shown:
		var kind := Pickup.Kind.HEART
		var floor_node := get_tree().get_first_node_in_group("floor") as Floor
		if floor_node:
			kind = floor_node.roll_item()
		Pickup.apply(kind)
		Game.sfx("pickup")
	_open_talk()
	cooldown = 1.2
	shown = true
	if _sprite:
		_sprite.play("talk")


func _open_talk() -> void:
	var qa := false
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--qa-"):
			qa = true
			break
	if qa:
		Game.say(Flavor.npc_line(line_i), 2.4)
		line_i += 1
		return
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud and hud.has_method("start_talk"):
		hud.start_talk(Flavor.concierge_script())
		return
	Game.say(Flavor.npc_line(line_i), 3.6)
	line_i += 1
