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
	var tex := _tex()
	_icon.texture = tex
	_icon.visible = tex != null
	if tex == null:
		return
	var h := float(tex.get_height())
	if tex is AtlasTexture:
		h = (tex as AtlasTexture).region.size.y
	_icon.scale = Vector2.ONE * (48.0 / maxf(h, 1.0))


func _tex() -> Texture2D:
	match kind:
		Kind.HEART:
			return Sprites.cell_used("res://assets/sprites/pickups.png", 3, 1, 0, 0)
		Kind.EMBER:
			return Sprites.cell_used("res://assets/sprites/pickups.png", 3, 1, 1, 0)
		Kind.MAX_HEART:
			return Sprites.cell_used("res://assets/sprites/pickups.png", 3, 1, 2, 0)
		Kind.PIERCE:
			return Sprites.cell_used("res://assets/sprites/skills.png", 4, 1, 0, 0)
		Kind.RAPID:
			return Sprites.cell_used("res://assets/sprites/skills.png", 4, 1, 1, 0)
		Kind.HEAVY:
			return Sprites.cell_used("res://assets/sprites/skills.png", 4, 1, 2, 0)
		Kind.BURN:
			return Sprites.cell_used("res://assets/sprites/skills.png", 4, 1, 3, 0)
	return null


func _process(delta: float) -> void:
	_age += delta
	if _icon:
		_icon.position.y = sin(_age * 3.4) * 4.0


func _on_body(body: Node) -> void:
	if _taken or not body is Player:
		return
	if kind == Kind.HEART and Game.hearts >= Game.max_hearts:
		return
	_taken = true
	Game.sfx("pickup")
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
