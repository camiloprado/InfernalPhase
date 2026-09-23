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

var _boss_tray: Control
var _boss_name: Label
var _flavor_left := 0.0
var _heart_max := 4
var _walker: Label
var _dlg: Control
var _dlg_face: TextureRect
var _dlg_name: Label
var _dlg_body: Label
var _dlg_hint: Label
var _dlg_lines: Array[Dictionary] = []
var _dlg_i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flavor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.visible = false
	Game.hearts_changed.connect(_on_hearts)
	Game.loadout_changed.connect(func () -> void: _on_hearts(Game.hearts, Game.max_hearts))
	Game.flavor.connect(_on_flavor)
	Game.boss_intro.connect(func () -> void: _set_boss_plate(true))
	Game.won.connect(func () -> void: _set_boss_plate(false))
	_on_hearts(Game.hearts, Game.max_hearts)
	_apply_locale()
	Game.locale_changed.connect(_apply_locale)
	_walker = Label.new()
	_walker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_walker.add_theme_color_override("font_color", Palette.UI_DIM)
	_walker.add_theme_font_size_override("font_size", 14)
	_walker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$Margin/VBox/Top.add_child(_walker)
	$Margin/VBox/Top.move_child(_walker, 2)
	_walker.text = ""
	_build_boss_plate()
	flavor.text = ""
	flavor.modulate.a = 0.0
	_build_dialogue()


func _process(delta: float) -> void:
	if _flavor_left > 0.0:
		_flavor_left -= delta
		if _flavor_left <= 0.0:
			var tw := create_tween()
			tw.tween_property(flavor, "modulate:a", 0.0, 0.35)
	_update_boss_bar()


func set_room_title(text: String) -> void:
	room_label.text = text


func set_walker(who: String, diff: String = "") -> void:
	if _walker == null:
		return
	if diff.is_empty():
		_walker.text = who
	else:
		_walker.text = "%s  ·  %s" % [who, diff]


func set_minimap(rooms: Dictionary, current: Room) -> void:
	minimap.rooms = rooms
	minimap.current = current
	minimap.queue_redraw()


func show_end(won: bool, body: String) -> void:
	overlay.visible = true
	overlay_title.text = Locale.t("ui.won") if won else Locale.t("ui.died")
	overlay_body.text = body + "\n\n" + Locale.t("ui.restart")


func _apply_locale() -> void:
	hint.text = Locale.t("ui.hint")
	if _boss_name:
		_boss_name.text = Locale.t("ui.boss")
	if _dlg_hint:
		_dlg_hint.text = Locale.t("ui.continue")


func _on_hearts(current: int, maximum: int) -> void:
	_heart_max = maximum
	for c in hearts.get_children():
		c.queue_free()
	for i in maximum:
		# 0 full Bone+Ember · 1 empty hollow Ash · 2 hit Wound cracks
		var col := 1
		if i < current:
			col = 0
		elif i == current and current < maximum:
			col = 2
		var pip := Sprites.cell_used("res://assets/sprites/hearts.png", 4, 1, col, 0)
		if pip == null:
			pip = Sprites.require_cell("res://assets/sprites/hearts.png", 4, 1, col, 0)
		if pip == null:
			continue
		var h := TextureRect.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.custom_minimum_size = Vector2(40, 40)
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.texture = pip
		hearts.add_child(h)
	_pip(Sprites.cell_used("res://assets/sprites/hearts.png", 4, 1, 3, 0), 28)
	if Game.pierce > 0:
		_pip(Sprites.require_cell("res://assets/sprites/skills.png", 4, 1, 0, 0), 22)
	if Game.rapid > 0:
		_pip(Sprites.require_cell("res://assets/sprites/skills.png", 4, 1, 1, 0), 22)
	if Game.heavy > 0:
		_pip(Sprites.require_cell("res://assets/sprites/skills.png", 4, 1, 2, 0), 22)
	if Game.burn > 0:
		_pip(Sprites.require_cell("res://assets/sprites/skills.png", 4, 1, 3, 0), 22)


func _pip(tex: Texture2D, px: int) -> void:
	if tex == null:
		return
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(px, px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = tex
	hearts.add_child(icon)


func _on_flavor(text: String, hold: float) -> void:
	flavor.text = text
	flavor.modulate.a = 1.0
	_flavor_left = hold


func _set_boss_plate(on: bool) -> void:
	boss_bar.visible = on
	if _boss_tray:
		_boss_tray.visible = on


func _build_boss_plate() -> void:
	var parent := boss_bar.get_parent()
	var idx := boss_bar.get_index()
	parent.remove_child(boss_bar)
	var center := CenterContainer.new()
	center.name = "BossPlate"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.visible = false
	var tray := PanelContainer.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Palette.VOID
	plate.border_color = Palette.ASH
	plate.set_border_width_all(3)
	plate.set_content_margin_all(12)
	plate.set_corner_radius_all(0)
	tray.add_theme_stylebox_override("panel", plate)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	var name_l := Label.new()
	name_l.text = Locale.t("ui.boss")
	_boss_name = name_l
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.add_theme_color_override("font_color", Palette.BONE)
	name_l.add_theme_font_size_override("font_size", 22)
	box.add_child(name_l)
	boss_bar.custom_minimum_size = Vector2(480, 18)
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.EMBER
	fill.set_corner_radius_all(0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.WOUND
	bg.set_corner_radius_all(0)
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_bar.add_theme_stylebox_override("background", bg)
	box.add_child(boss_bar)
	tray.add_child(box)
	center.add_child(tray)
	parent.add_child(center)
	parent.move_child(center, idx)
	_boss_tray = center


func _update_boss_bar() -> void:
	if _boss_tray == null or not _boss_tray.visible:
		return
	var boss: Enemy = null
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Enemy and (n as Enemy).kind == Enemy.Kind.BOSS and (n as Enemy).alive:
			boss = n
			break
	if boss == null:
		_set_boss_plate(false)
		return
	boss_bar.max_value = boss.max_hp
	boss_bar.value = boss.hp


func start_talk(lines: Array) -> void:
	_dlg_lines.clear()
	for item in lines:
		if item is Dictionary:
			_dlg_lines.append(item)
	if _dlg_lines.is_empty() or _dlg == null:
		return
	_dlg_i = 0
	Game.in_dialogue = true
	_dlg.visible = true
	flavor.modulate.a = 0.0
	_show_line()


func close_talk() -> void:
	Game.in_dialogue = false
	if _dlg:
		_dlg.visible = false
	_dlg_lines.clear()
	_dlg_i = 0


func _build_dialogue() -> void:
	_dlg = Control.new()
	_dlg.name = "Dialogue"
	_dlg.visible = false
	_dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	_dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dlg)
	var panel := ColorRect.new()
	panel.color = Palette.ASH_MID
	panel.position = Vector2(72, 548)
	panel.size = Vector2(1136, 196)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(panel)
	var inset := ColorRect.new()
	inset.color = Palette.VOID
	inset.position = Vector2(74, 550)
	inset.size = Vector2(1132, 192)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(inset)
	_dlg_face = TextureRect.new()
	_dlg_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_dlg_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dlg_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dlg_face.position = Vector2(96, 564)
	_dlg_face.size = Vector2(96, 96)
	_dlg_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(_dlg_face)
	_dlg_name = Label.new()
	_dlg_name.position = Vector2(208, 560)
	_dlg_name.size = Vector2(960, 32)
	_dlg_name.add_theme_color_override("font_color", Palette.EMBER)
	_dlg_name.add_theme_font_size_override("font_size", 20)
	_dlg_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(_dlg_name)
	_dlg_body = Label.new()
	_dlg_body.position = Vector2(208, 596)
	_dlg_body.size = Vector2(960, 100)
	_dlg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dlg_body.add_theme_color_override("font_color", Palette.BONE)
	_dlg_body.add_theme_font_size_override("font_size", 22)
	_dlg_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(_dlg_body)
	_dlg_hint = Label.new()
	_dlg_hint.position = Vector2(208, 704)
	_dlg_hint.size = Vector2(960, 24)
	_dlg_hint.text = Locale.t("ui.continue")
	_dlg_hint.add_theme_color_override("font_color", Palette.UI_DIM)
	_dlg_hint.add_theme_font_size_override("font_size", 14)
	_dlg_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_child(_dlg_hint)


func _show_line() -> void:
	if _dlg_i < 0 or _dlg_i >= _dlg_lines.size():
		close_talk()
		return
	var line: Dictionary = _dlg_lines[_dlg_i]
	var who := String(line.get("who", "Concierge"))
	_dlg_name.text = Locale.who(who)
	_dlg_body.text = String(line.get("text", ""))
	if _dlg_face:
		if who == "Concierge":
			_dlg_face.texture = Sprites.cell_used("res://assets/sprites/concierge.png", 4, 2, 0, 1)
		elif Game.is_baby():
			_dlg_face.texture = Sprites.require("res://assets/sprites/baby.png")
		elif Game.body == Game.Body.LILITH:
			_dlg_face.texture = Sprites.cell_used("res://assets/sprites/player_f.png", 4, 3, 0, 0)
		else:
			_dlg_face.texture = Sprites.cell_used("res://assets/sprites/player.png", 4, 3, 0, 0)
	Game.sfx("talk")


func _advance_talk() -> void:
	if not Game.in_dialogue:
		return
	_dlg_i += 1
	if _dlg_i >= _dlg_lines.size():
		close_talk()
	else:
		_show_line()


func _unhandled_input(event: InputEvent) -> void:
	if not Game.in_dialogue:
		return
	var go := false
	if event.is_action_pressed("interact") or event.is_action_pressed("shoot"):
		go = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		go = true
	if go:
		_advance_talk()
		get_viewport().set_input_as_handled()
