class_name HUD
extends CanvasLayer

@onready var hearts: HBoxContainer = $Margin/VBox/Top/Hearts
@onready var room_label: Label = $Margin/VBox/Top/RoomLabel
@onready var flavor: Label = $Flavor
@onready var minimap: Control = $Margin/VBox/Top/Minimap
@onready var overlay: ColorRect = $Overlay
@onready var overlay_title: Label = $Overlay/Center/VBox/Title
@onready var overlay_body: Label = $Overlay/Center/VBox/Body
@onready var hint: Label = $Margin/VBox/Hint
@onready var boss_bar: ProgressBar = $Margin/VBox/BossBar

var _flavor_left := 0.0
var _heart_max := 5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	boss_bar.visible = false
	Game.hearts_changed.connect(_on_hearts)
	Game.flavor.connect(_on_flavor)
	Game.boss_intro.connect(func () -> void: boss_bar.visible = true)
	Game.won.connect(func () -> void: boss_bar.visible = false)
	_on_hearts(Game.hearts, Game.MAX_HEARTS)
	hint.text = "WASD move  ·  Mouse aim  ·  Click / Space shoot  ·  Arrows shoot  ·  R restart"
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.HELL_RED
	fill.set_corner_radius_all(3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.VOID
	bg.set_corner_radius_all(3)
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_bar.add_theme_stylebox_override("background", bg)
	flavor.text = ""
	flavor.modulate.a = 0.0


func _process(delta: float) -> void:
	if _flavor_left > 0.0:
		_flavor_left -= delta
		if _flavor_left <= 0.0:
			var tw := create_tween()
			tw.tween_property(flavor, "modulate:a", 0.0, 0.35)
	_update_boss_bar()


func set_room_title(text: String) -> void:
	room_label.text = text


func set_minimap(rooms: Dictionary, current: Room) -> void:
	minimap.rooms = rooms
	minimap.current = current
	minimap.queue_redraw()


func show_end(won: bool, body: String) -> void:
	overlay.visible = true
	overlay_title.text = "THE PHASE ENDS" if won else "YOU DIED"
	overlay_body.text = body + "\n\nPress Enter or R to restart the floor."


func _on_hearts(current: int, maximum: int) -> void:
	_heart_max = maximum
	for c in hearts.get_children():
		c.queue_free()
	for i in maximum:
		var h := HeartPip.new()
		h.filled = i < current
		h.custom_minimum_size = Vector2(28, 24)
		hearts.add_child(h)


func _on_flavor(text: String, hold: float) -> void:
	flavor.text = text
	flavor.modulate.a = 1.0
	_flavor_left = hold


func _update_boss_bar() -> void:
	if not boss_bar.visible:
		return
	var boss: Enemy = null
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Enemy and (n as Enemy).kind == Enemy.Kind.BOSS and (n as Enemy).alive:
			boss = n
			break
	if boss == null:
		boss_bar.visible = false
		return
	boss_bar.max_value = boss.max_hp
	boss_bar.value = boss.hp


class HeartPip extends Control:
	var filled := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Palette.HELL_RED if filled else Palette.ASH_LIGHT
		var s := size
		var pts := PackedVector2Array([
			Vector2(s.x * 0.5, s.y * 0.92),
			Vector2(s.x * 0.08, s.y * 0.42),
			Vector2(s.x * 0.28, s.y * 0.12),
			Vector2(s.x * 0.5, s.y * 0.32),
			Vector2(s.x * 0.72, s.y * 0.12),
			Vector2(s.x * 0.92, s.y * 0.42),
		])
		draw_colored_polygon(pts, col)
		if filled:
			draw_circle(Vector2(s.x * 0.38, s.y * 0.32), 2.0, Palette.EMBER_HOT)
