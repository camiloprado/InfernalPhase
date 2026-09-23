class_name Room
extends Node2D

enum Kind { START, COMBAT, NPC, BOSS }
enum Dir { N, E, S, W }

const DIR_VEC := {
	Dir.N: Vector2i(0, -1),
	Dir.E: Vector2i(1, 0),
	Dir.S: Vector2i(0, 1),
	Dir.W: Vector2i(-1, 0),
}

const DOOR_SHEET := "res://assets/sprites/doors.png"
const ENV_SHEET := "res://assets/sprites/env.png"
## env.png is 8×5 of 64. Rows 0 and 4 are an unused Void field.
## Rows 1–3 are the room themes. Cols 0–3 floor grit, 4–5 Ash walls.
## Cols 6–7 are a blank Void field. Nothing is stamped from them.
const ENV_COLS := 8
const ENV_ROWS := 5
## Flush doorway cells are 256×96. Width maps to the 256px opening; depth is 96px
## so the Ash frame sits on the 64px wall and shows ~32px into the room.
const DOOR_CELL := Vector2(256, 96)

var room_id: String = ""
var grid := Vector2i.ZERO
var kind: Kind = Kind.COMBAT
var pack: Array[String] = []
var neighbors: Dictionary = {}  # Dir -> Room
var cleared := false
var visited := false
var locked := false
var size := Vector2.ZERO
var theme: int = 1

var _door_bodies: Dictionary = {}
var _door_visuals: Dictionary = {}
var _door_seals: Dictionary = {}
var _door_art: Dictionary = {}
var _built := false
var has_pit := false
var pit_center := Vector2.ZERO
var pit_dest: Room = null
var pit_radius := 56.0
var _pit_area: Area2D
const PIT_SHEET := "res://assets/env/pit.png"


func setup(p_id: String, p_grid: Vector2i, p_kind: Kind, p_pack: Array[String]) -> void:
	room_id = p_id
	grid = p_grid
	kind = p_kind
	pack = p_pack.duplicate()
	theme = _theme_row()
	size = Game.ROOM_SIZE
	position = Vector2(grid) * size
	name = "Room_%s" % room_id
	cleared = kind == Kind.START or kind == Kind.NPC
	z_index = 0


func connect_to(dir: int, other: Room) -> void:
	neighbors[dir] = other


func finalize() -> void:
	if _built:
		return
	_built = true
	_build_geometry()
	if kind == Kind.NPC:
		_spawn_npc()


func lock_doors() -> void:
	if cleared:
		return
	locked = true
	for dir in neighbors.keys():
		_set_door_blocked(dir, true)
	Game.sfx("door")


func unlock_doors() -> void:
	var was_locked := locked
	locked = false
	cleared = true
	for dir in neighbors.keys():
		_set_door_blocked(dir, false)
	if was_locked:
		Game.sfx("unlock")


func contains_inner(point: Vector2) -> bool:
	var inset := Game.WALL
	var r := Rect2(global_position + Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	return r.has_point(point)


func door_gap(dir: int) -> Rect2:
	if _door_art.has(dir) and _door_art[dir] is Sprite2D:
		var g: Rect2 = (_door_art[dir] as Sprite2D).get_meta("gap", Rect2())
		if g.size != Vector2.ZERO:
			return g
	return Rect2()


func door_trigger_global(dir: int) -> Rect2:
	var gap := door_gap(dir)
	if gap.size == Vector2.ZERO:
		return Rect2()
	var inset := 0.0
	if _door_art.has(dir) and _door_art[dir] is Sprite2D:
		var spr := _door_art[dir] as Sprite2D
		var cell := DOOR_CELL
		if spr.texture is AtlasTexture:
			cell = (spr.texture as AtlasTexture).region.size
		elif spr.texture:
			cell = Vector2(spr.texture.get_width(), spr.texture.get_height())
		var along := maxf(gap.size.x, gap.size.y) / maxf(cell.x, 1.0)
		var depth := cell.y * along
		inset = maxf(depth * 0.5 - Game.WALL * 0.5, 0.0)
	match dir:
		Dir.N:
			gap.size.y += inset
		Dir.S:
			gap.position.y -= inset
			gap.size.y += inset
		Dir.W:
			gap.size.x += inset
		Dir.E:
			gap.position.x -= inset
			gap.size.x += inset
	return Rect2(global_position + gap.position, gap.size)


func transition_at(point: Vector2) -> Room:
	if locked:
		return null
	for dir in neighbors.keys():
		if not _door_bodies.has(dir):
			continue
		var body: StaticBody2D = _door_bodies[dir]
		var col := body.get_node_or_null("Col") as CollisionShape2D
		if col and not col.disabled and body.collision_layer != 0:
			continue
		var tr := door_trigger_global(dir)
		if tr.has_point(point):
			return neighbors[dir]
	return null


func entry_from(through_dir: int) -> Vector2:
	var c := center_global()
	var pad := Game.WALL + 188.0
	match through_dir:
		Dir.N:
			return Vector2(c.x, global_position.y + pad)
		Dir.S:
			return Vector2(c.x, global_position.y + size.y - pad)
		Dir.W:
			return Vector2(global_position.x + pad, c.y)
		Dir.E:
			return Vector2(global_position.x + size.x - pad, c.y)
	return c


func center_global() -> Vector2:
	return global_position + size * 0.5


func spawn_offset(index: int, total: int) -> Vector2:
	var c := center_global()
	if kind == Kind.BOSS:
		return c + Vector2(0, 48)
	if total <= 1:
		return c + Vector2(0, -20)
	var ring := 96.0 + float(index % 3) * 26.0
	var a := TAU * float(index) / float(maxi(total, 1)) - PI * 0.5
	return c + Vector2.RIGHT.rotated(a) * ring


func title() -> String:
	match kind:
		Kind.START:
			return "THE THRESHOLD"
		Kind.COMBAT:
			return "A BAD ROOM"
		Kind.NPC:
			return "THE CONCIERGE"
		Kind.BOSS:
			return "THE PHASE"
	return ""


func _theme_row() -> int:
	# Rows 1–3 of env.png. Rows 0 and 4 are not a room theme.
	match kind:
		Kind.START:
			return 1
		Kind.NPC:
			return 3
		Kind.BOSS:
			return 2
		_:
			if pack.has("wretch"):
				return 3
			if pack.has("cultist") or pack.has("cantor"):
				return 2
			return 2


func _floor_color() -> Color:
	return Palette.VOID


func _wall_color() -> Color:
	return Palette.ASH


func _owns_door(dir: int) -> bool:
	var dest: Room = neighbors.get(dir)
	if dest == null:
		return true
	return grid.x < dest.grid.x or (grid.x == dest.grid.x and grid.y < dest.grid.y)


func _build_geometry() -> void:
	# Void underlay so transparent env texels never punch the F5 checker.
	var floor_n := Node2D.new()
	floor_n.name = "FloorFill"
	floor_n.z_index = -9
	var floor_col := _floor_color()
	floor_n.draw.connect(func () -> void:
		floor_n.draw_rect(Rect2(Vector2.ZERO, size), floor_col)
	)
	add_child(floor_n)
	floor_n.queue_redraw()
	Sprites.require(ENV_SHEET)
	_stamp_floor()
	_stamp_sigil()

	var w := Game.WALL
	var s := size
	var dw := Game.DOOR_WIDTH
	var mid_x := (s.x - dw) * 0.5
	var mid_y := (s.y - dw) * 0.5

	# North
	if neighbors.has(Dir.N):
		_add_wall(Rect2(0, 0, mid_x, w))
		_add_wall(Rect2(mid_x + dw, 0, s.x - mid_x - dw, w))
		_add_door_blocker(Dir.N, Rect2(mid_x, 0, dw, w))
		_paint_gap(Rect2(mid_x, 0, dw, w), Dir.N)
	else:
		_add_wall(Rect2(0, 0, s.x, w))
	# South
	if neighbors.has(Dir.S):
		_add_wall(Rect2(0, s.y - w, mid_x, w))
		_add_wall(Rect2(mid_x + dw, s.y - w, s.x - mid_x - dw, w))
		_add_door_blocker(Dir.S, Rect2(mid_x, s.y - w, dw, w))
		_paint_gap(Rect2(mid_x, s.y - w, dw, w), Dir.S)
	else:
		_add_wall(Rect2(0, s.y - w, s.x, w))
	# West
	if neighbors.has(Dir.W):
		_add_wall(Rect2(0, 0, w, mid_y))
		_add_wall(Rect2(0, mid_y + dw, w, s.y - mid_y - dw))
		_add_door_blocker(Dir.W, Rect2(0, mid_y, w, dw))
		_paint_gap(Rect2(0, mid_y, w, dw), Dir.W)
	else:
		_add_wall(Rect2(0, 0, w, s.y))
	# East
	if neighbors.has(Dir.E):
		_add_wall(Rect2(s.x - w, 0, w, mid_y))
		_add_wall(Rect2(s.x - w, mid_y + dw, w, s.y - mid_y - dw))
		_add_door_blocker(Dir.E, Rect2(s.x - w, mid_y, w, dw))
		_paint_gap(Rect2(s.x - w, mid_y, w, dw), Dir.E)
	else:
		_add_wall(Rect2(s.x - w, 0, w, s.y))


func _paint_gap(rect: Rect2, dir: int) -> void:
	var t := Game.WALL
	var floor_xy := _env_xy()
	var y := rect.position.y
	while y < rect.end.y - 0.5:
		var x := rect.position.x
		while x < rect.end.x - 0.5:
			_stamp_cell(Vector2(x, y), _floor_col(x, y), floor_xy.y, -6, minf(t, rect.end.x - x), minf(t, rect.end.y - y))
			x += t
		y += t
	if not _owns_door(dir):
		return
	Sprites.require(DOOR_SHEET)


func _env_xy() -> Vector2i:
	var row := clampi(theme, 1, 3)
	return Vector2i(0, row)


func _floor_col(x: float, y: float) -> int:
	# Four Void grit variants. The 3-step lattice is not a two-tone checker.
	var tx := int(x / Game.WALL)
	var ty := int(y / Game.WALL)
	return posmod(tx + ty * 3, 4)


func _wall_col(x: float, y: float) -> int:
	var tx := int(x / Game.WALL)
	var ty := int(y / Game.WALL)
	# Chipped Ash block on a sparse lattice, not every other tile.
	if posmod(tx * 2 + ty, 5) == 0:
		return 5
	return 4


func _wall_xy() -> Vector2i:
	var row := clampi(theme, 1, 3)
	return Vector2i(4, row)


func _stamp_floor() -> void:
	# Inner field only — wall band is col 1, never mixed into the floor.
	var t := Game.WALL
	var base := _env_xy()
	var inset := t
	var y := inset
	while y < size.y - inset - 0.5:
		var x := inset
		while x < size.x - inset - 0.5:
			_stamp_cell(Vector2(x, y), _floor_col(x, y), base.y, -8, minf(t, size.x - inset - x), minf(t, size.y - inset - y))
			x += t
		y += t


func _stamp_sigil() -> void:
	# Cols 6–7 are blank Void. A scaled stamp of that cell would blot the grit
	# floor with a flat square, which is the debug gizmo Designer rejected.
	if kind == Kind.NPC:
		_stamp_dais()


func _stamp_dais() -> void:
	var t := Game.WALL
	var origin := Vector2(size.x * 0.5 - t * 1.5, size.y * 0.5 - t)
	for iy in 2:
		for ix in 3:
			_stamp_cell(origin + Vector2(ix * t, iy * t), 1, 3, -7, t, t)


func _stamp_cell(at: Vector2, col: int, row: int, z: int, w: float, h: float) -> void:
	var atlas := Sprites.require_cell(ENV_SHEET, ENV_COLS, ENV_ROWS, col, row)
	if atlas == null:
		return
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = at.round()
	spr.z_index = z
	if z >= 1:
		spr.name = "EnvWall_%d_%d" % [int(at.x), int(at.y)]
	elif z <= -8:
		spr.name = "EnvFloor_%d_%d" % [int(at.x), int(at.y)]
	else:
		spr.name = "EnvDecal_%d_%d" % [int(at.x), int(at.y)]
	if w < 63.5 or h < 63.5:
		var cropped := atlas.duplicate() as AtlasTexture
		cropped.region = Rect2(atlas.region.position, Vector2(w, h))
		spr.texture = cropped
	else:
		spr.texture = atlas
	add_child(spr)


func _add_wall(rect: Rect2) -> void:
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	var wall := _wall_xy()
	var t := Game.WALL
	var y := rect.position.y
	while y < rect.end.y - 0.5:
		var x := rect.position.x
		while x < rect.end.x - 0.5:
			_stamp_cell(Vector2(x, y), _wall_col(x, y), wall.y, 1, minf(t, rect.end.x - x), minf(t, rect.end.y - y))
			x += t
		y += t


func _add_door_blocker(dir: int, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "Door_%d" % dir
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position + rect.size * 0.5
	var col := CollisionShape2D.new()
	col.name = "Col"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	body.add_child(col)
	var vis := ColorRect.new()
	vis.name = "Slab"
	vis.color = Palette.ASH
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vis.visible = false
	body.add_child(vis)
	add_child(body)
	# Seal lives on the room, not the physics body, so it cannot block.
	var seal := ColorRect.new()
	seal.name = "Seal_%d" % dir
	seal.color = Palette.EMBER
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.z_index = -4
	seal.visible = false
	if rect.size.x >= rect.size.y:
		seal.size = Vector2(rect.size.x - 16.0, 12)
		seal.position = Vector2(rect.position.x + 8.0, rect.position.y + rect.size.y * 0.5 - 6.0)
	else:
		seal.size = Vector2(12, rect.size.y - 16.0)
		seal.position = Vector2(rect.position.x + rect.size.x * 0.5 - 6.0, rect.position.y + 8.0)
	add_child(seal)
	_door_bodies[dir] = body
	_door_visuals[dir] = vis
	_door_seals[dir] = seal
	_add_door_art(dir, rect)
	# Start open so you can walk in; lock_doors() slams them after entry.
	_set_door_blocked(dir, false)


func _scatter_decals() -> void:
	pass


func _door_col(k: Kind) -> int:
	match k:
		Kind.START:
			return 0
		Kind.NPC:
			return 2
		Kind.BOSS:
			return 3
		_:
			return 1


func _door_atlas(k: Kind, blocked: bool) -> AtlasTexture:
	# Full cell, not a used-rect crop, so the rectangular frame keeps its jambs.
	return Sprites.cell(DOOR_SHEET, 4, 2, _door_col(k), 1 if blocked else 0)


func _door_inward(dir: int) -> Vector2:
	match dir:
		Dir.N:
			return Vector2(0, 1)
		Dir.S:
			return Vector2(0, -1)
		Dir.W:
			return Vector2(1, 0)
		Dir.E:
			return Vector2(-1, 0)
	return Vector2.ZERO


func set_active_doors(on: bool) -> void:
	# Only the room the player is in draws or collides its arches.
	# Neighbors keep the carved gap but hide their art so shared edges
	# do not stack two inward frames.
	for dir in _door_art.keys():
		var art: Node = _door_art[dir]
		if art is CanvasItem:
			(art as CanvasItem).visible = on
	if on:
		for dir in neighbors.keys():
			_set_door_blocked(dir, locked)
		return
	for dir in _door_bodies.keys():
		var body: StaticBody2D = _door_bodies[dir]
		body.collision_layer = 0
		body.collision_mask = 0
		var col := body.get_node_or_null("Col") as CollisionShape2D
		if col:
			col.disabled = true
			if col.shape is RectangleShape2D:
				(col.shape as RectangleShape2D).size = Vector2(0.1, 0.1)
		if _door_visuals.has(dir):
			(_door_visuals[dir] as ColorRect).visible = false
		if _door_seals.has(dir):
			(_door_seals[dir] as ColorRect).visible = false


func _door_rotation(dir: int) -> float:
	# doors.png: room-side lip = texture top / local -Y. The lip faces into the
	# room so the Ash frame sits flush in the wall band.
	match dir:
		Dir.N:
			return PI
		Dir.S:
			return 0.0
		Dir.E:
			return -PI * 0.5
		Dir.W:
			return PI * 0.5
	return 0.0


func _apply_door_sprite(spr: Sprite2D, atlas: AtlasTexture, dir: int, rect: Rect2) -> void:
	spr.texture = atlas
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.rotation = _door_rotation(dir)
	var cell := atlas.region.size
	var opening := maxf(rect.size.x, rect.size.y)
	# Uniform scale from cell width → 256px opening (4×64). A 256×96 frame
	# sits flush in the wall band, lip into the room.
	var along := opening / maxf(cell.x, 1.0)
	spr.scale = Vector2(along, along)
	spr.position = rect.position + rect.size * 0.5
	# 256×96 at scale 1 sits on the 64px wall (32px of frame into the room).
	var depth := cell.y * along
	var inset := maxf(depth * 0.5 - Game.WALL * 0.5, 0.0)
	spr.position += _door_inward(dir) * inset
	spr.position = spr.position.round()
	spr.set_meta("gap", rect)
	spr.set_meta("dir", dir)


func _add_door_art(dir: int, rect: Rect2) -> void:
	var dest: Room = neighbors.get(dir)
	var atlas := _door_atlas(dest.kind if dest else Kind.COMBAT, false)
	if atlas == null:
		Sprites.fail(DOOR_SHEET, "door atlas kind=%s" % (dest.kind if dest else Kind.COMBAT))
		return
	var spr := Sprite2D.new()
	spr.name = "DoorArt_%d" % dir
	_apply_door_sprite(spr, atlas, dir, rect)
	spr.z_index = 3
	spr.visible = true
	add_child(spr)
	_door_art[dir] = spr


func set_door_sprites_visible(on: bool) -> void:
	for dir in _door_art.keys():
		var art: Node = _door_art[dir]
		if art is CanvasItem:
			(art as CanvasItem).visible = on


func _set_door_blocked(dir: int, blocked: bool) -> void:
	if not _door_bodies.has(dir):
		return
	var body: StaticBody2D = _door_bodies[dir]
	var vis: ColorRect = _door_visuals[dir]
	var col := body.get_node_or_null("Col") as CollisionShape2D
	if col:
		col.disabled = not blocked
		if col.shape is RectangleShape2D:
			var full: Vector2 = vis.size
			(col.shape as RectangleShape2D).size = full if blocked else Vector2(0.1, 0.1)
	body.collision_layer = 1 if blocked else 0
	body.collision_mask = 0
	# One graphic per carved edge. Neighbor keeps collision and the gap only.
	vis.visible = false
	if _door_seals.has(dir):
		(_door_seals[dir] as ColorRect).visible = false
	if _door_art.has(dir) and _door_art[dir] is Sprite2D:
		var dest: Room = neighbors.get(dir)
		var atlas := _door_atlas(dest.kind if dest else Kind.COMBAT, blocked)
		if atlas == null:
			Sprites.fail(DOOR_SHEET, "blocked atlas dir=%s" % dir)
			return
		var art := _door_art[dir] as Sprite2D
		var gap: Rect2 = art.get_meta("gap", Rect2())
		if gap.size == Vector2.ZERO:
			gap = Rect2(body.position - vis.size * 0.5, vis.size)
		_apply_door_sprite(art, atlas, dir, gap)
		return
	if _owns_door(dir):
		Sprites.fail(DOOR_SHEET, "missing Sprite2D door art dir=%s" % dir)


func landing_global() -> Vector2:
	if has_pit:
		return global_position + size * 0.5 + Vector2(-140, -20)
	return center_global() + Vector2(-90, 36)


func add_pit(dest: Room = null) -> void:
	has_pit = true
	pit_dest = dest
	pit_center = size * 0.5 + Vector2(220, 80)
	# Opaque Void under the FULL sprite quad. The sheet is 1024px at 0.30
	# (~307px). A mouth-radius disk (~88px) left the lip-outside texels
	# uncovered; those alpha-0 pixels punch the editor F5 checkerboard.
	var under := Node2D.new()
	under.name = "PitUnderlay"
	under.z_index = -6
	under.position = pit_center
	add_child(under)
	var spr := Sprite2D.new()
	spr.name = "PitSprite"
	spr.texture = Sprites.require(PIT_SHEET)
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pit_center
	spr.scale = Vector2(0.25, 0.25)
	spr.z_index = -5
	add_child(spr)
	# Trigger the Void mouth, not the Ash lip / sprite quad.
	pit_radius = 88.0
	var half := Vector2(1024.0, 1024.0) * spr.scale * 0.5
	if spr.texture:
		half = Vector2(float(spr.texture.get_width()), float(spr.texture.get_height())) * spr.scale * 0.5
		pit_radius = maxf(float(spr.texture.get_width()) * spr.scale.x * 0.33, 80.0)
	# 1px pad so nearest-filter edge samples stay on the opaque underlay.
	half += Vector2.ONE
	var cover := half
	under.draw.connect(func () -> void:
		under.draw_rect(Rect2(-cover, cover * 2.0), Palette.VOID)
	)
	under.queue_redraw()
	var area := Area2D.new()
	area.name = "EnvPit"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	area.position = pit_center
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = pit_radius
	cs.shape = circ
	area.add_child(cs)
	area.body_entered.connect(_on_pit_body)
	add_child(area)
	_pit_area = area


func pit_global() -> Vector2:
	return global_position + pit_center


func covers_pit(point: Vector2) -> bool:
	return has_pit and point.distance_to(pit_global()) <= pit_radius


func arm_pit(on: bool) -> void:
	if _pit_area:
		_pit_area.set_deferred("monitoring", on)


func _on_pit_body(body: Node) -> void:
	if not body is Player:
		return
	var floor_node := get_tree().get_first_node_in_group("floor") as Floor
	if floor_node:
		# body_entered runs while physics is flushing — defer the room swap.
		floor_node.call_deferred("fall_from", self, pit_dest)


func _spawn_npc() -> void:
	var npc := preload("res://scenes/npc.tscn").instantiate()
	npc.position = size * 0.5 + Vector2(0, -10)
	add_child(npc)
