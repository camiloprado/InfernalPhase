class_name Pickup
extends Area2D
## Ground loot. Pulse so it reads against ash floor.

enum Kind { HEART, EMBER, MAX_HEART, PIERCE, RAPID, HEAVY, BURN }

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
	_icon.scale = Vector2.ONE * 0.9
	add_child(_icon)
	_bind_icon()


func setup(p_kind: Kind, at: Vector2) -> void:
	kind = p_kind
	global_position = at
	_bind_icon()


func _bind_icon() -> void:
	if _icon == null:
		return
	_icon.texture = _tex()
	_icon.visible = _icon.texture != null


func _tex() -> Texture2D:
	match kind:
		Kind.HEART:
			return Sprites.require_cell("res://assets/sprites/pickups.png", 3, 1, 0, 0)
		Kind.EMBER:
			return Sprites.require_cell("res://assets/sprites/pickups.png", 3, 1, 1, 0)
		Kind.MAX_HEART:
			return Sprites.require_cell("res://assets/sprites/pickups.png", 3, 1, 2, 0)
		Kind.PIERCE:
			return Sprites.require_cell("res://assets/sprites/skills.png", 4, 1, 0, 0)
		Kind.RAPID:
			return Sprites.require_cell("res://assets/sprites/skills.png", 4, 1, 1, 0)
		Kind.HEAVY:
			return Sprites.require_cell("res://assets/sprites/skills.png", 4, 1, 2, 0)
		Kind.BURN:
			return Sprites.require_cell("res://assets/sprites/skills.png", 4, 1, 3, 0)
	return null


func _process(delta: float) -> void:
	_age += delta
	if _icon:
		_icon.position.y = sin(_age * 3.4) * 4.0
	queue_redraw()


func _on_body(body: Node) -> void:
	if _taken or not body is Player:
		return
	if kind == Kind.HEART and Game.hearts >= Game.max_hearts:
		return
	_taken = true
	Game.say(apply(kind), 1.7)
	queue_free()


static func apply(p_kind: Kind) -> String:
	match p_kind:
		Kind.HEART:
			Game.heal(1)
			return "A brimstone heart. Don't get used to it."
		Kind.EMBER:
			Game.add_ember()
			return "Ember under the tongue. Shots hit harder."
		Kind.MAX_HEART:
			if Game.add_max_heart():
				return "Another chamber in the ribcage."
			Game.heal(1)
			return "The vessel is already full. A heart instead."
		Kind.PIERCE:
			if Game.add_pierce():
				return "Bone spike. Shots keep going."
			Game.add_ember()
			return "Already punching through. Ember instead."
		Kind.RAPID:
			if Game.add_rapid():
				return "Fan the hammer. Faster, wider."
			Game.add_ember()
			return "Trigger finger is already ruined. Ember instead."
		Kind.HEAVY:
			if Game.add_heavy():
				return "Slower. Meaner. A molten slug."
			Game.add_ember()
			return "The slug is already fat. Ember instead."
		Kind.BURN:
			if Game.add_burn():
				return "Trail of hell. They cook after the hit."
			Game.add_ember()
			return "Already smoldering. Ember instead."
	return ""


func _draw() -> void:
	# Glow under the bound icon only. No vector loot if the sheet missed.
	if _icon == null or _icon.texture == null:
		return
	var pulse := 0.55 + 0.45 * sin(_age * 6.2)
	var bob := Vector2(0, sin(_age * 3.4) * 4.0)
	var glow := Palette.EMBER_HOT
	match kind:
		Kind.HEART, Kind.MAX_HEART:
			glow = Palette.EMBER_HOT
		Kind.EMBER, Kind.BURN:
			glow = Palette.EMBER
		Kind.HEAVY:
			glow = Palette.BLOOD
		_:
			glow = Palette.BONE
	glow.a = 0.22 + 0.28 * pulse
	draw_circle(bob, 22.0 + pulse * 8.0, glow)
