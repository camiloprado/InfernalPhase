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
var _built := false


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


func _build_geometry() -> void:
	var floor_r := ColorRect.new()
	floor_r.color = Palette.ASH
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
		_paint_gap(Rect2(mid_x, 0, dw, w))
	else:
		_add_wall(Rect2(0, 0, s.x, w))
	# South
	if neighbors.has(Dir.S):
		_add_wall(Rect2(0, s.y - w, mid_x, w))
		_add_wall(Rect2(mid_x + dw, s.y - w, s.x - mid_x - dw, w))
		_add_door_blocker(Dir.S, Rect2(mid_x, s.y - w, dw, w))
		_paint_gap(Rect2(mid_x, s.y - w, dw, w))
	else:
		_add_wall(Rect2(0, s.y - w, s.x, w))
	# West
	if neighbors.has(Dir.W):
		_add_wall(Rect2(0, 0, w, mid_y))
		_add_wall(Rect2(0, mid_y + dw, w, s.y - mid_y - dw))
		_add_door_blocker(Dir.W, Rect2(0, mid_y, w, dw))
		_paint_gap(Rect2(0, mid_y, w, dw))
	else:
		_add_wall(Rect2(0, 0, w, s.y))
	# East
	if neighbors.has(Dir.E):
		_add_wall(Rect2(s.x - w, 0, w, mid_y))
		_add_wall(Rect2(s.x - w, mid_y + dw, w, s.y - mid_y - dw))
		_add_door_blocker(Dir.E, Rect2(s.x - w, mid_y, w, dw))
		_paint_gap(Rect2(s.x - w, mid_y, w, dw))
	else:
		_add_wall(Rect2(s.x - w, 0, w, s.y))


func _paint_gap(rect: Rect2) -> void:
	var hole := ColorRect.new()
	hole.color = Color("160e12")
	hole.position = rect.position
	hole.size = rect.size
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.z_index = -6
	add_child(hole)


func _draw_floor(node: Node2D) -> void:
	var s := size
	var w := Game.WALL
	for x in range(int(w), int(s.x - w), 40):
		node.draw_line(Vector2(x, w), Vector2(x, s.y - w), Color(Palette.ASH_MID.r, Palette.ASH_MID.g, Palette.ASH_MID.b, 0.35), 1.0)
	for y in range(int(w), int(s.y - w), 40):
		node.draw_line(Vector2(w, y), Vector2(s.x - w, y), Color(Palette.ASH_MID.r, Palette.ASH_MID.g, Palette.ASH_MID.b, 0.35), 1.0)
	match kind:
		Kind.START:
			_draw_sigil(node, s * 0.5, 70.0)
		Kind.BOSS:
			_draw_sigil(node, s * 0.5, 110.0)
		Kind.NPC:
			node.draw_rect(Rect2(s.x * 0.5 - 70, s.y * 0.5 - 40, 140, 90), Color(Palette.ASH_MID.r, Palette.ASH_MID.g, Palette.ASH_MID.b, 0.85))
		Kind.COMBAT:
			node.draw_circle(s * 0.5, 18.0, Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 0.55))


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
	vis.color = Palette.ASH_MID
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
	body.add_child(vis)
	add_child(body)
	_door_bodies[dir] = body
	_door_visuals[dir] = vis
	# Start open so you can walk in; lock_doors() slams them after entry.
	_set_door_blocked(dir, false)


func _set_door_blocked(dir: int, blocked: bool) -> void:
	if not _door_bodies.has(dir):
		return
	var body: StaticBody2D = _door_bodies[dir]
	var vis: ColorRect = _door_visuals[dir]
	var col := body.get_node_or_null("Col") as CollisionShape2D
	if col:
		col.disabled = not blocked
	body.collision_layer = 1 if blocked else 0
	vis.visible = blocked
	vis.color = Palette.HELL_RED if blocked and not cleared else Palette.EMBER


func _spawn_npc() -> void:
	var npc := preload("res://scenes/npc.tscn").instantiate()
	npc.position = size * 0.5 + Vector2(0, -10)
	add_child(npc)
