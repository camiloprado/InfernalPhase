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
	# The valence halo is baked into the item. A second ring would float off the silhouette.
	if _aura:
		_aura.visible = false
	if tex == null:
		return
	var h := float(tex.get_height())
	if tex is AtlasTexture:
		h = (tex as AtlasTexture).region.size.y
	var shown := 60.0 if _is_valence() else 48.0
	_icon.scale = Vector2.ONE * (shown / maxf(h, 1.0))


func _tex() -> Texture2D:
	match kind:
		Kind.HEART:
			# Full cell: cell_used's 1px inset would eat the Ember rim.
			return Sprites.cell(AURA_SHEET, 2, 1, 0, 0)
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
			return Sprites.cell(AURA_SHEET, 2, 1, 1, 0)
	return null


func _is_valence() -> bool:
	return kind == Kind.HEART or kind == Kind.CURSE


func _process(delta: float) -> void:
	_age += delta
	var bob := sin(_age * 3.4) * 4.0
	var pulse := 0.8 + 0.2 * absf(sin(_age * 4.2))
	if _icon:
		_icon.position.y = bob
		# Keep the baked Bone/Ember and Wound/Void. A tint would repaint the craft.
		_icon.modulate = Color.WHITE
		if _is_valence():
			_icon.scale = Vector2.ONE * (60.0 / 64.0) * (0.94 + 0.06 * pulse)


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
