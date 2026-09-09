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

var room_id: String = ""
var grid := Vector2i.ZERO
var kind: Kind = Kind.COMBAT
var pack: Array[String] = []
var neighbors: Dictionary = {}  # Dir -> Room
var cleared := false
var visited := false
var locked := false
var size := Vector2.ZERO

var _door_bodies: Dictionary = {}
var _door_visuals: Dictionary = {}
var _door_seals: Dictionary = {}
var _door_art: Dictionary = {}
var _built := false
var has_pit := false
var pit_center := Vector2.ZERO
var _pit_area: Area2D
const PIT_SHEET := "res://assets/env/pit.png"


func setup(p_id: String, p_grid: Vector2i, p_kind: Kind, p_pack: Array[String]) -> void:
	room_id = p_id
	grid = p_grid
	kind = p_kind
	pack = p_pack.duplicate()
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


func unlock_doors() -> void:
	locked = false
	cleared = true
	for dir in neighbors.keys():
		_set_door_blocked(dir, false)


func contains_inner(point: Vector2) -> bool:
	var inset := Game.WALL + 24.0
	var r := Rect2(global_position + Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	return r.has_point(point)


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


func _floor_color() -> Color:
	match kind:
		Kind.START:
			return Palette.ASH
		Kind.NPC:
			return Color("2a2420")
		Kind.BOSS:
			return Color("140c14")
		_:
			return Color("201418")


func _wall_color() -> Color:
	match kind:
		Kind.START:
			return Palette.ASH_MID
		Kind.NPC:
			return Color("5a4a3a")
		Kind.BOSS:
			return Color("2a1830")
		_:
			return Color("4a2218")


func _owns_door(dir: int) -> bool:
	var dest: Room = neighbors.get(dir)
	if dest == null:
		return true
	return grid.x < dest.grid.x or (grid.x == dest.grid.x and grid.y < dest.grid.y)


func _build_geometry() -> void:
	var floor_r := ColorRect.new()
	floor_r.color = _floor_color()
	floor_r.size = size
	floor_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor_r.z_index = -8
	add_child(floor_r)

	var grid_n := Node2D.new()
	grid_n.z_index = -7
	grid_n.draw.connect(_draw_floor.bind(grid_n))
	add_child(grid_n)
	grid_n.queue_redraw()

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
	# Floor-colored throat. Jambs only on the owner side so shared walls
	# do not stamp two bone frames on the same opening.
	var hole := ColorRect.new()
	hole.color = _floor_color()
	hole.position = rect.position
	hole.size = rect.size
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.z_index = -6
	add_child(hole)
	if not _owns_door(dir):
		return
	var jamb_a := ColorRect.new()
	var jamb_b := ColorRect.new()
	jamb_a.color = Palette.BONE
	jamb_b.color = Palette.BONE
	jamb_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jamb_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jamb_a.z_index = -5
	jamb_b.z_index = -5
	const JAMB := 8.0
	if rect.size.x >= rect.size.y:
		jamb_a.size = Vector2(JAMB, rect.size.y)
		jamb_b.size = Vector2(JAMB, rect.size.y)
		jamb_a.position = rect.position
		jamb_b.position = Vector2(rect.position.x + rect.size.x - JAMB, rect.position.y)
	else:
		jamb_a.size = Vector2(rect.size.x, JAMB)
		jamb_b.size = Vector2(rect.size.x, JAMB)
		jamb_a.position = rect.position
		jamb_b.position = Vector2(rect.position.x, rect.position.y + rect.size.y - JAMB)
	add_child(jamb_a)
	add_child(jamb_b)


func _draw_floor(node: Node2D) -> void:
	var s := size
	var w := Game.WALL
	# One faint cross, not a 40px tile grid — that read as a broken tileset.
	var line := Color(_wall_color().r, _wall_color().g, _wall_color().b, 0.16)
	node.draw_line(Vector2(s.x * 0.5, w), Vector2(s.x * 0.5, s.y - w), line, 1.0)
	node.draw_line(Vector2(w, s.y * 0.5), Vector2(s.x - w, s.y * 0.5), line, 1.0)
	match kind:
		Kind.START:
			_draw_sigil(node, s * 0.5, 70.0)
		Kind.BOSS:
			_draw_sigil(node, s * 0.5, 110.0)
		Kind.NPC:
			node.draw_rect(Rect2(s.x * 0.5 - 70, s.y * 0.5 - 40, 140, 90), Color(Palette.ASH_MID.r, Palette.ASH_MID.g, Palette.ASH_MID.b, 0.85))
		Kind.COMBAT:
			pass


func _draw_sigil(node: Node2D, c: Vector2, r: float) -> void:
	var pts: PackedVector2Array = []
	for i in 5:
		var a := -PI * 0.5 + i * TAU * 2.0 / 5.0
		pts.append(c + Vector2.RIGHT.rotated(a) * r)
	pts.append(pts[0])
	node.draw_polyline(pts, Color(Palette.HELL_RED.r, Palette.HELL_RED.g, Palette.HELL_RED.b, 0.45), 2.0, true)
	node.draw_arc(c, r * 0.72, 0, TAU, 40, Color(Palette.EMBER.r, Palette.EMBER.g, Palette.EMBER.b, 0.28), 1.5, true)


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
	var vis := ColorRect.new()
	vis.color = _wall_color()
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(vis)
	var edge := ColorRect.new()
	edge.color = Palette.BONE_DIM
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rect.size.x >= rect.size.y:
		edge.size = Vector2(rect.size.x, 3)
		edge.position = Vector2(-rect.size.x * 0.5, -1.5)
	else:
		edge.size = Vector2(3, rect.size.y)
		edge.position = Vector2(-1.5, -rect.size.y * 0.5)
	body.add_child(edge)
	add_child(body)


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
	vis.color = Palette.EMBER
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vis.visible = false
	body.add_child(vis)
	add_child(body)
	# Seal lives on the room, not the physics body, so it cannot block.
	var seal := ColorRect.new()
	seal.name = "Seal_%d" % dir
	seal.color = Palette.EMBER_HOT
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


func _add_door_art(dir: int, rect: Rect2) -> void:
	if not _owns_door(dir):
		return
	var art := Node2D.new()
	art.name = "DoorArt_%d" % dir
	art.position = rect.position + rect.size * 0.5
	art.z_index = 3
	var inward := Vector2.ZERO
	match dir:
		Dir.N:
			inward = Vector2(0, 1)
		Dir.S:
			inward = Vector2(0, -1)
		Dir.W:
			inward = Vector2(1, 0)
		Dir.E:
			inward = Vector2(-1, 0)
	art.position += inward * 36.0
	art.set_meta("horiz", rect.size.x >= rect.size.y)
	art.set_meta("blocked", false)
	art.draw.connect(_draw_door.bind(art))
	add_child(art)
	art.queue_redraw()
	_door_art[dir] = art


func _draw_door(node: Node2D) -> void:
	var blocked := bool(node.get_meta("blocked", false))
	var horiz := bool(node.get_meta("horiz", true))
	var dest_kind: Kind = Kind.COMBAT
	for dir in _door_art.keys():
		if _door_art[dir] == node and neighbors.has(dir):
			dest_kind = (neighbors[dir] as Room).kind
			break
	var col := Palette.ASH_LIGHT
	match dest_kind:
		Kind.START:
			col = Palette.BONE_DIM
		Kind.NPC:
			col = Palette.BONE
		Kind.BOSS:
			col = Palette.HELL_RED
		_:
			col = Palette.EMBER
	var w := 92.0 if horiz else 28.0
	var h := 28.0 if horiz else 92.0
	node.draw_rect(Rect2(-w, -h, w * 2.0, h * 2.0), Color(col.r, col.g, col.b, 0.22))
	# Single arch — one stroke, not a tiled slab.
	if horiz:
		node.draw_arc(Vector2(0, 10), 70.0, PI, TAU, 18, col, 5.0, true)
		node.draw_line(Vector2(-70, 10), Vector2(-70, 22), col, 5.0)
		node.draw_line(Vector2(70, 10), Vector2(70, 22), col, 5.0)
	else:
		node.draw_arc(Vector2(10, 0), 70.0, -PI * 0.5, PI * 0.5, 18, col, 5.0, true)
		node.draw_line(Vector2(10, -70), Vector2(22, -70), col, 5.0)
		node.draw_line(Vector2(10, 70), Vector2(22, 70), col, 5.0)
	if blocked:
		node.draw_rect(Rect2(-18, -18, 36, 36), Palette.HELL_RED)
		node.draw_circle(Vector2.ZERO, 7.0, Palette.EMBER_HOT)
	else:
		node.draw_circle(Vector2.ZERO, 5.0, Palette.EMBER_HOT)


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
	if _door_art.has(dir):
		var art: Node2D = _door_art[dir]
		art.set_meta("blocked", blocked)
		art.queue_redraw()
		return
	if not _owns_door(dir):
		return
	vis.visible = blocked
	vis.color = Palette.HELL_RED if blocked and not cleared else Palette.EMBER
	if _door_seals.has(dir):
		var seal: ColorRect = _door_seals[dir]
		seal.visible = not blocked
		seal.color = Palette.EMBER_HOT


func add_pit() -> void:
	has_pit = true
	pit_center = size * 0.5 + Vector2(220, 80)
	var spr := Sprite2D.new()
	if ResourceLoader.exists(PIT_SHEET):
		spr.texture = load(PIT_SHEET) as Texture2D
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pit_center
	spr.scale = Vector2(0.22, 0.22)
	spr.z_index = -5
	add_child(spr)
	if spr.texture == null:
		var hole := Node2D.new()
		hole.z_index = -5
		hole.position = pit_center
		hole.draw.connect(func () -> void:
			hole.draw_circle(Vector2.ZERO, 46.0, Color(0.02, 0.01, 0.02, 0.92))
			hole.draw_arc(Vector2.ZERO, 48.0, 0.0, TAU, 28, Palette.EMBER, 3.0, true)
			hole.draw_circle(Vector2(0, 6), 18.0, Color(0, 0, 0, 1))
		)
		add_child(hole)
		hole.queue_redraw()
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	area.position = pit_center
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 28.0
	cs.shape = circ
	area.add_child(cs)
	area.body_entered.connect(_on_pit_body)
	add_child(area)
	_pit_area = area


func arm_pit(on: bool) -> void:
	if _pit_area:
		_pit_area.set_deferred("monitoring", on)


func _on_pit_body(body: Node) -> void:
	if not body is Player:
		return
	var floor_node := get_tree().get_first_node_in_group("floor") as Floor
	if floor_node:
		floor_node.fall_from(self)


func _spawn_npc() -> void:
	var npc := preload("res://scenes/npc.tscn").instantiate()
	npc.position = size * 0.5 + Vector2(0, -10)
	add_child(npc)
