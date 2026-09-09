class_name RunPick
extends CanvasLayer
## Caim / Lilith and Bebê Chorão / Normal. Same combat numbers. One choice per run.
## Dim is IGNORE so it cannot swallow clicks. Cards are Buttons (STOP).

signal chosen

var _body: Game.Body = Game.Body.CAIM
var _diff: Game.Difficulty = Game.Difficulty.NORMAL
var _caim_btn: Button
var _lilith_btn: Button
var _baby_btn: Button
var _normal_btn: Button
var _hint: Label
var _click_ms := -99999
var _body_clicks := 0
var _diff_clicks := 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_body = Game.last_body
	_diff = Game.last_difficulty
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.035, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_label(Vector2(0, 56), Vector2(1280, 36), "WHO WALKS THE FLOOR", Palette.BONE, 28)
	_label(Vector2(0, 96), Vector2(1280, 24), "Click a name to select  ·  Click again or Space / E to swear in", Palette.UI_DIM, 15)
	_caim_btn = _card(Vector2(340, 140), "Caim", Game.Body.CAIM, true)
	_lilith_btn = _card(Vector2(740, 140), "Lilith", Game.Body.LILITH, false)
	_label(Vector2(0, 440), Vector2(1280, 28), "DIFFICULTY", Palette.BONE, 20)
	_baby_btn = _diff_card(Vector2(300, 480), "Bebê Chorão", "Enemy shots bounce off you.", Game.Difficulty.BABY)
	_normal_btn = _diff_card(Vector2(680, 480), "Normal", "The floor as written.", Game.Difficulty.NORMAL)
	_hint = _label(Vector2(0, 640), Vector2(1280, 28), "", Palette.EMBER_HOT, 14)
	_refresh()


func _label(pos: Vector2, size: Vector2, text: String, col: Color, px: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_font_size_override("font_size", px)
	lab.position = pos
	lab.size = size
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lab)
	return lab


func _card(pos: Vector2, caption: String, which: Game.Body, male: bool) -> Button:
	var btn := Button.new()
	btn.position = pos
	btn.size = Vector2(200, 260)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style(btn)
	btn.pressed.connect(func () -> void: _on_body(which))
	add_child(btn)
	var art := Control.new()
	art.position = Vector2(40, 28)
	art.size = Vector2(120, 140)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_meta("male", male)
	art.draw.connect(func () -> void: _draw_body(art, male))
	btn.add_child(art)
	var name := Label.new()
	name.text = caption
	name.position = Vector2(0, 180)
	name.size = Vector2(200, 36)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Palette.BONE)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name)
	var sub := Label.new()
	sub.text = "same hearts, same fire"
	sub.position = Vector2(8, 216)
	sub.size = Vector2(184, 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Palette.UI_DIM)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sub)
	return btn


func _diff_card(pos: Vector2, caption: String, blurb: String, which: Game.Difficulty) -> Button:
	var btn := Button.new()
	btn.position = pos
	btn.size = Vector2(300, 120)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style(btn)
	btn.pressed.connect(func () -> void: _on_diff(which))
	add_child(btn)
	var name := Label.new()
	name.text = caption
	name.position = Vector2(12, 16)
	name.size = Vector2(276, 36)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", Palette.BONE)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name)
	var sub := Label.new()
	sub.text = blurb
	sub.position = Vector2(16, 58)
	sub.size = Vector2(268, 44)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Palette.UI_DIM)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sub)
	return btn


func _style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1c1418")
	normal.set_border_width_all(2)
	normal.border_color = Palette.ASH_LIGHT
	var hover := StyleBoxFlat.new()
	hover.bg_color = Palette.ASH
	hover.set_border_width_all(2)
	hover.border_color = Palette.EMBER
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", normal)


func _draw_body(node: Control, male: bool) -> void:
	var c := node.size * 0.5
	var col := Palette.PLAYER if male else Palette.ROBE_LIGHT
	var core := Palette.PLAYER_CORE if male else Palette.EMBER_HOT
	node.draw_circle(c, 34.0, Color(Palette.EMBER.r, Palette.EMBER.g, Palette.EMBER.b, 0.18))
	if male:
		var pts := PackedVector2Array([
			c + Vector2(0, -32),
			c + Vector2(22, 24),
			c + Vector2(0, 12),
			c + Vector2(-22, 24),
		])
		node.draw_colored_polygon(pts, col)
	else:
		var robe := PackedVector2Array([
			c + Vector2(0, -30),
			c + Vector2(26, 28),
			c + Vector2(0, 18),
			c + Vector2(-26, 28),
		])
		node.draw_colored_polygon(robe, col)
		node.draw_circle(c + Vector2(0, -22), 11.0, Palette.BONE)
	node.draw_circle(c, 6.0, core)
	node.draw_circle(c, 2.4, Palette.EMBER_HOT)


func _on_body(which: Game.Body) -> void:
	var now := Time.get_ticks_msec()
	if _body == which and now - _click_ms < 700:
		_confirm()
		return
	_body = which
	_click_ms = now
	_body_clicks += 1
	_refresh()


func _on_diff(which: Game.Difficulty) -> void:
	var now := Time.get_ticks_msec()
	if _diff == which and now - _click_ms < 700:
		_confirm()
		return
	_diff = which
	_click_ms = now
	_diff_clicks += 1
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_A):
		_body = Game.Body.CAIM
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_D):
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
	Game.pick_run(_body, _diff)
	chosen.emit()
	queue_free()


func _refresh() -> void:
	_paint(_caim_btn, _body == Game.Body.CAIM)
	_paint(_lilith_btn, _body == Game.Body.LILITH)
	_paint(_baby_btn, _diff == Game.Difficulty.BABY)
	_paint(_normal_btn, _diff == Game.Difficulty.NORMAL)
	_hint.text = "%s  ·  %s" % [Game.BODY_NAMES[_body], Game.DIFF_NAMES[_diff]]
	for art in [_caim_btn.get_child(0), _lilith_btn.get_child(0)]:
		if art is Control:
			(art as Control).queue_redraw()


func _paint(btn: Button, on: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("3a2418") if on else Color("1c1418")
	box.set_border_width_all(3 if on else 2)
	box.border_color = Palette.EMBER_HOT if on else Palette.ASH_LIGHT
	btn.add_theme_stylebox_override("normal", box)
