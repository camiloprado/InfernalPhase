class_name RunPick
extends CanvasLayer
## Caim / Lilith and Bebê Chorão / Normal. Same combat numbers. One choice per run.
## Clicks are handled three ways so IGNORE children / HUD labels cannot swallow them:
## Button.pressed, Panel gui_input, and _input rect hit-tests.

signal chosen

var _body: Game.Body = Game.Body.CAIM
var _diff: Game.Difficulty = Game.Difficulty.NORMAL
var _caim_btn: Control
var _lilith_btn: Control
var _bebe_card: Control
var _baby_btn: Control
var _normal_btn: Control
var _hint: Label
var _confirm_btn: Button
var _click_ms := -99999
var _pick_frame := -1
var _sworn := false
const BABY_SHEET := "res://assets/sprites/baby.png"
const CAIM_RECT := Rect2(340, 140, 200, 260)
const LILITH_RECT := Rect2(740, 140, 200, 260)
const BEBE_RECT := Rect2(540, 140, 200, 260)
const BABY_DIFF_RECT := Rect2(300, 468, 300, 110)
const NORMAL_DIFF_RECT := Rect2(680, 468, 300, 110)
const CONFIRM_RECT := Rect2(490, 600, 300, 48)


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_body = Game.last_body
	_diff = Game.last_difficulty

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(Palette.VOID.r, Palette.VOID.g, Palette.VOID.b, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	_label(root, Vector2(0, 56), Vector2(1280, 36), "WHO WALKS THE FLOOR", Palette.BONE, 28)
	_label(root, Vector2(0, 96), Vector2(1280, 24), "Click a name to select  ·  Click again or Space / E to swear in", Palette.UI_DIM, 15)
	_caim_btn = _card(root, CAIM_RECT, "Caim", "same hearts, same fire", func() -> void: _on_body(Game.Body.CAIM), true)
	_lilith_btn = _card(root, LILITH_RECT, "Lilith", "same hearts, same fire", func() -> void: _on_body(Game.Body.LILITH), false)
	_bebe_card = _bebe_portrait(root, BEBE_RECT)
	_label(root, Vector2(0, 440), Vector2(1280, 28), "DIFFICULTY", Palette.BONE, 20)
	_baby_btn = _diff_card(root, BABY_DIFF_RECT, "Bebê Chorão", func() -> void: _on_diff(Game.Difficulty.BABY))
	_normal_btn = _diff_card(root, NORMAL_DIFF_RECT, "Normal", func() -> void: _on_diff(Game.Difficulty.NORMAL))
	_confirm_btn = _confirm_cta(root, CONFIRM_RECT)
	_hint = _label(root, Vector2(0, 656), Vector2(1280, 28), "", Palette.BONE_DIM, 14)
	_refresh()
	_preview_music()


func _label(parent: Node, pos: Vector2, size: Vector2, text: String, col: Color, px: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_font_size_override("font_size", px)
	lab.position = pos
	lab.size = size
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lab)
	return lab


func _card(parent: Node, rect: Rect2, caption: String, blurb: String, on_click: Callable, male: bool) -> Control:
	var btn := _shell(parent, rect, on_click)
	var path := "res://assets/sprites/player.png" if male else "res://assets/sprites/player_f.png"
	var portrait := Sprites.cell(path, 4, 3, 0, 0)
	if portrait:
		var tr := TextureRect.new()
		tr.position = Vector2(20, 16)
		tr.size = Vector2(160, 160)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture = portrait
		btn.add_child(tr)
	else:
		var art := Control.new()
		art.position = Vector2(40, 28)
		art.size = Vector2(120, 140)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_meta("male", male)
		art.draw.connect(func() -> void: _draw_body(art, male))
		btn.add_child(art)
	_caption(btn, caption, blurb, 180)
	return btn


func _bebe_portrait(parent: Node, rect: Rect2) -> Control:
	var btn := _shell(parent, rect, func() -> void: _on_diff(Game.Difficulty.BABY))
	btn.visible = false
	var tr := TextureRect.new()
	tr.position = Vector2(20, 16)
	tr.size = Vector2(160, 160)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := Sprites.tex(BABY_SHEET)
	if tex:
		tr.texture = tex
	btn.add_child(tr)
	if tr.texture == null:
		var art := Control.new()
		art.position = Vector2(40, 28)
		art.size = Vector2(120, 140)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.draw.connect(func() -> void: _draw_bebe(art))
		btn.add_child(art)
	_caption(btn, "Penitent", "", 184)
	return btn


func _diff_card(parent: Node, rect: Rect2, caption: String, on_click: Callable) -> Control:
	var btn := _shell(parent, rect, on_click)
	var name := Label.new()
	name.text = caption
	name.position = Vector2(12, 0)
	name.size = Vector2(rect.size.x - 24.0, rect.size.y)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Palette.BONE)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name)
	return btn


func _shell(parent: Node, rect: Rect2, on_click: Callable) -> Control:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.text = ""
	btn.flat = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_style(btn)
	btn.pressed.connect(on_click)
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if _is_click(event):
			on_click.call()
			btn.accept_event()
	)
	parent.add_child(btn)
	return btn


func _caption(btn: Control, caption: String, blurb: String, name_y: float) -> void:
	var name := Label.new()
	name.text = caption
	name.position = Vector2(0, name_y)
	name.size = Vector2(btn.size.x, 36)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Palette.BONE)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name)
	if blurb.is_empty():
		return
	var sub := Label.new()
	sub.text = blurb
	sub.position = Vector2(8, name_y + 36.0)
	sub.size = Vector2(btn.size.x - 16.0, 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Palette.UI_DIM)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sub)


func _confirm_cta(parent: Node, rect: Rect2) -> Button:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.text = "SWEAR IN"
	btn.flat = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Palette.VOID)
	btn.add_theme_color_override("font_hover_color", Palette.VOID)
	btn.add_theme_color_override("font_pressed_color", Palette.VOID)
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.EMBER
	box.set_border_width_all(0)
	box.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", box)
	btn.add_theme_stylebox_override("hover", box)
	btn.add_theme_stylebox_override("pressed", box)
	btn.add_theme_stylebox_override("focus", box)
	btn.pressed.connect(_confirm)
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if _is_click(event):
			_confirm()
			btn.accept_event()
	)
	parent.add_child(btn)
	return btn


func _style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.VOID
	normal.set_border_width_all(2)
	normal.border_color = Palette.ASH
	var hover := StyleBoxFlat.new()
	hover.bg_color = Palette.VOID
	hover.set_border_width_all(2)
	hover.border_color = Palette.BONE
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_stylebox_override("disabled", normal)


func _draw_penitent(node: Control, lilith: bool) -> void:
	var c := node.size * 0.5
	var rx := 28.0 if lilith else 32.0
	var ry := 48.0 if lilith else 42.0
	var pts := PackedVector2Array([
		c + Vector2(0, -ry),
		c + Vector2(rx, 0),
		c + Vector2(0, ry),
		c + Vector2(-rx, 0),
	])
	node.draw_colored_polygon(pts, Palette.BONE)
	var hood := PackedVector2Array([
		c + Vector2(0, -ry),
		c + Vector2(rx * 0.72, -ry * 0.22),
		c + Vector2(0, -ry * 0.12),
		c + Vector2(-rx * 0.72, -ry * 0.22),
	])
	node.draw_colored_polygon(hood, Palette.ASH)
	node.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -ry * 0.55),
		c + Vector2(8, -ry * 0.22),
		c + Vector2(-8, -ry * 0.22),
	]), Palette.VOID)
	var brand := PackedVector2Array([
		c + Vector2(0, -5),
		c + Vector2(5, 2),
		c + Vector2(0, 9),
		c + Vector2(-5, 2),
	])
	node.draw_colored_polygon(brand, Palette.EMBER)


func _draw_bebe(node: Control) -> void:
	_draw_penitent(node, false)


func _draw_body(node: Control, male: bool) -> void:
	_draw_penitent(node, not male)


func _is_click(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _viewport_mouse(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return get_viewport().get_mouse_position()
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return Vector2(-9999, -9999)


func _same_click() -> bool:
	var frame := Engine.get_process_frames()
	if frame == _pick_frame:
		return true
	_pick_frame = frame
	return false


func _on_body(which: Game.Body) -> void:
	if _same_click():
		return
	var now := Time.get_ticks_msec()
	if _body == which and _diff == Game.Difficulty.NORMAL and now - _click_ms < 700:
		_confirm()
		return
	_body = which
	_click_ms = now
	_refresh()


func _on_diff(which: Game.Difficulty) -> void:
	if _same_click():
		return
	var now := Time.get_ticks_msec()
	if _diff == which and now - _click_ms < 700:
		_confirm()
		return
	_diff = which
	_click_ms = now
	_preview_music()
	_refresh()


func _preview_music() -> void:
	if _diff == Game.Difficulty.BABY:
		Game.bgm("play_cry")
	else:
		Game.bgm("play_floor")


func _input(event: InputEvent) -> void:
	# Viewport-space hit test. Survives IGNORE children and lower-layer HUD labels.
	if not _is_click(event):
		return
	var pos := _viewport_mouse(event)
	if _diff == Game.Difficulty.NORMAL:
		if CAIM_RECT.has_point(pos):
			_on_body(Game.Body.CAIM)
			get_viewport().set_input_as_handled()
			return
		if LILITH_RECT.has_point(pos):
			_on_body(Game.Body.LILITH)
			get_viewport().set_input_as_handled()
			return
	elif BEBE_RECT.has_point(pos):
		_on_diff(Game.Difficulty.BABY)
		get_viewport().set_input_as_handled()
		return
	if BABY_DIFF_RECT.has_point(pos):
		_on_diff(Game.Difficulty.BABY)
		get_viewport().set_input_as_handled()
		return
	if NORMAL_DIFF_RECT.has_point(pos):
		_on_diff(Game.Difficulty.NORMAL)
		get_viewport().set_input_as_handled()
		return
	if CONFIRM_RECT.has_point(pos):
		_confirm()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_A):
		if _diff == Game.Difficulty.NORMAL:
			_body = Game.Body.CAIM
			_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_D):
		if _diff == Game.Difficulty.NORMAL:
			_body = Game.Body.LILITH
			_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_SPACE):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		# Enter is restart. Do not confirm on Enter.
		get_viewport().set_input_as_handled()


func _confirm() -> void:
	if _sworn:
		return
	_sworn = true
	Game.pick_run(_body, _diff)
	chosen.emit()
	queue_free()


func _refresh() -> void:
	var baby := _diff == Game.Difficulty.BABY
	_caim_btn.visible = not baby
	_lilith_btn.visible = not baby
	if _bebe_card:
		_bebe_card.visible = baby
		_paint(_bebe_card, true)
	_paint(_caim_btn, _body == Game.Body.CAIM)
	_paint(_lilith_btn, _body == Game.Body.LILITH)
	_paint(_baby_btn, baby)
	_paint(_normal_btn, not baby)
	if baby:
		_hint.text = "Bebê Chorão"
	else:
		_hint.text = "%s  ·  Normal" % Game.BODY_NAMES[_body]
	for art in [_caim_btn.get_child(0), _lilith_btn.get_child(0)]:
		if art is Control:
			(art as Control).queue_redraw()


func _paint(btn: Control, on: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.ASH_MID if on else Palette.VOID
	box.set_border_width_all(3 if on else 2)
	box.border_color = Palette.BONE if on else Palette.ASH
	if btn is Button:
		var b := btn as Button
		b.add_theme_stylebox_override("normal", box)
		b.add_theme_stylebox_override("hover", box)
		b.add_theme_stylebox_override("pressed", box)
		b.add_theme_stylebox_override("focus", box)
