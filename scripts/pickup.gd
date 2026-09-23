class_name Pickup
extends Area2D
## Ground loot. Pulse so it reads against ash floor.

enum Kind { HEART, EMBER, MAX_HEART, PIERCE, RAPID, HEAVY, BURN, CURSE }

const AURA_SHEET := "res://assets/sprites/pickup_aura.png"

var kind: Kind = Kind.HEART
var _age := 0.0
var _taken := false
var _icon: Sprite2D
var _aura: Sprite2D


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
	_aura = Sprite2D.new()
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_aura.centered = true
	_aura.z_index = -1
	add_child(_aura)
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
	if _aura == null:
		return
	# Good = Bone rim + Ember. Bad = Wound rim + Void X. No aura slot on the icon sheet.
	var aura := Sprites.cell_used(AURA_SHEET, 2, 1, 1 if _is_cursed() else 0, 0)
	_aura.texture = aura
	_aura.visible = aura != null
	if aura == null:
		return
	var ah := float(aura.get_height())
	if aura is AtlasTexture:
		ah = (aura as AtlasTexture).region.size.y
	_aura.scale = Vector2.ONE * (60.0 / maxf(ah, 1.0))


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
		Kind.CURSE:
			# Same heart craft as the boon. The Wound tint and bad halo mark it.
			return Sprites.cell_used("res://assets/sprites/pickups.png", 3, 1, 0, 0)
	return null


func _is_cursed() -> bool:
	return kind == Kind.CURSE


func _process(delta: float) -> void:
	_age += delta
	var bob := sin(_age * 3.4) * 4.0
	var pulse := 0.8 + 0.2 * absf(sin(_age * 4.2))
	if _icon:
		_icon.position.y = bob
		if _is_cursed():
			_icon.modulate = Color(0.95, 0.38 + 0.12 * pulse, 0.3)
		else:
			_icon.modulate = Color.WHITE
	if _aura:
		_aura.position.y = bob
		if _is_cursed():
			_aura.modulate = Color(0.55 + 0.25 * pulse, 0.16, 0.14, 0.94)
		else:
			_aura.modulate = Color(1.0, 0.72 + 0.22 * pulse, 0.5, 0.95)


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
			return Locale.t("pickup.heart")
		Kind.EMBER:
			Game.add_ember()
			return Locale.t("pickup.ember")
		Kind.MAX_HEART:
			if Game.add_max_heart():
				return Locale.t("pickup.vessel")
			Game.heal(1)
			return Locale.t("pickup.vessel_full")
		Kind.PIERCE:
			if Game.add_pierce():
				return Locale.t("pickup.pierce")
			Game.add_ember()
			return Locale.t("pickup.pierce_full")
		Kind.RAPID:
			if Game.add_rapid():
				return Locale.t("pickup.rapid")
			Game.add_ember()
			return Locale.t("pickup.rapid_full")
		Kind.HEAVY:
			if Game.add_heavy():
				return Locale.t("pickup.heavy")
			Game.add_ember()
			return Locale.t("pickup.heavy_full")
		Kind.BURN:
			if Game.add_burn():
				return Locale.t("pickup.burn")
			Game.add_ember()
			return Locale.t("pickup.burn_full")
		Kind.CURSE:
			Game.hurt(1)
			return Locale.t("pickup.curse")
	return ""
