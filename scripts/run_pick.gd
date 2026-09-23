class_name RunPick
extends CanvasLayer
## Caim / Lilith and Bebê Chorão / Normal. Disk pixel portraits, not Penitent polygons.
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
var _preview: TextureRect
var _preview_caption: Label
var _hint: Label
var _prompt: Label
var _diff_label: Label
var _confirm_btn: Button
var _lang_pt: Button
var _lang_en: Button
var _click_ms := -99999
var _pick_frame := -1
var _sworn := false
const CAIM_SHEET := "res://assets/sprites/player.png"
const LILITH_SHEET := "res://assets/sprites/player_f.png"
const BABY_SHEET := "res://assets/sprites/baby.png"
const PREVIEW_RECT := Rect2(480, 48, 320, 268)
const CAIM_RECT := Rect2(280, 318, 240, 78)
const LILITH_RECT := Rect2(760, 318, 240, 78)
const BABY_DIFF_RECT := Rect2(300, 448, 300, 100)
const NORMAL_DIFF_RECT := Rect2(680, 448, 300, 100)
const CONFIRM_RECT := Rect2(490, 580, 300, 48)
const LANG_PT_RECT := Rect2(980, 14, 130, 36)
const LANG_EN_RECT := Rect2(1120, 14, 130, 36)


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

	_prompt = _label(root, Vector2(0, 16), Vector2(1280, 20), "", Palette.UI_DIM, 14)
	_lang_pt = _lang_btn(root, LANG_PT_RECT, "pt", "PT-BR")
	_lang_en = _lang_btn(root, LANG_EN_RECT, "en", "EN")
	Game.locale_changed.connect(_refresh)
	_bebe_card = _walker_preview(root, PREVIEW_RECT)
	_caim_btn = _name_card(root, CAIM_RECT, "Caim", _idle_tex(CAIM_SHEET), func() -> void: _on_body(Game.Body.CAIM))
	_lilith_btn = _name_card(root, LILITH_RECT, "Lilith", _idle_tex(LILITH_SHEET), func() -> void: _on_body(Game.Body.LILITH))
	_diff_label = _label(root, Vector2(0, 412), Vector2(1280, 28), "", Palette.BONE, 20)
	_baby_btn = _diff_card(root, BABY_DIFF_RECT, "Bebê Chorão", Sprites.require(BABY_SHEET), func() -> void: _on_diff(Game.Difficulty.BABY))
	_normal_btn = _diff_card(root, NORMAL_DIFF_RECT, "Normal", _idle_tex(CAIM_SHEET), func() -> void: _on_diff(Game.Difficulty.NORMAL))
	_confirm_btn = _confirm_cta(root, CONFIRM_RECT)
	_hint = _label(root, Vector2(0, 704), Vector2(1280, 28), "", Palette.BONE_DIM, 14)
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


func _name_card(parent: Node, rect: Rect2, caption: String, face: Texture2D, on_click: Callable) -> Control:
	var btn := _shell(parent, rect, on_click)
	_face(btn, Vector2(8, 7), Vector2(64, 64), face)
	var name := Label.new()
	name.text = caption
	name.position = Vector2(76, 0)
	name.size = Vector2(rect.size.x - 84.0, rect.size.y)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Palette.BONE)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name)
	return btn


func _walker_preview(parent: Node, rect: Rect2) -> Control:
	# Disk pixel body on Void. No env floor tiles in the portrait.
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chrome := ColorRect.new()
	chrome.color = Palette.VOID
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(chrome)
	var border := ColorRect.new()
	border.color = Palette.ASH
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.position = Vector2.ZERO
	border.size = rect.size
	frame.add_child(border)
	var inset := ColorRect.new()
	inset.color = Palette.VOID
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.position = Vector2(2, 2)
	inset.size = rect.size - Vector2(4, 4)
	frame.add_child(inset)
	_preview = TextureRect.new()
	_preview.name = "Preview"
	_preview.position = Vector2(24, 10)
	_preview.size = Vector2(rect.size.x - 48.0, 196)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_preview)
	_preview_caption = _caption(frame, "Caim", "", 214)
	parent.add_child(frame)
	return frame


func _diff_card(parent: Node, rect: Rect2, caption: String, face: Texture2D, on_click: Callable) -> Control:
	var btn := _shell(parent, rect, on_click)
	_face(btn, Vector2(12, 14), Vector2(72, 72), face)
	var name := Label.new()
	name.text = caption
	name.position = Vector2(92, 0)
	name.size = Vector2(rect.size.x - 104.0, rect.size.y)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", Palette.BONE)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name)
	return btn


func _face(parent: Control, pos: Vector2, size: Vector2, tex: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "Face"
	tr.position = pos
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = tex
	parent.add_child(tr)
	return tr


func _idle_tex(path: String) -> Texture2D:
	if path == BABY_SHEET:
		return Sprites.require(path)
	var cropped := Sprites.cell_used(path, 4, 3, 0, 0)
	if cropped:
		return cropped
	return Sprites.require_cell(path, 4, 3, 0, 0)


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


func _caption(btn: Control, caption: String, blurb: String, name_y: float) -> Label:
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
		return name
	var sub := Label.new()
	sub.text = blurb
	sub.position = Vector2(8, name_y + 36.0)
	sub.size = Vector2(btn.size.x - 16.0, 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Palette.UI_DIM)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sub)
	return name


func _confirm_cta(parent: Node, rect: Rect2) -> Button:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.text = "   SWEAR IN"
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
	var ember := TextureRect.new()
	ember.name = "Ember"
	ember.texture = Sprites.require_cell("res://assets/sprites/pickups.png", 3, 1, 1, 0)
	ember.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ember.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ember.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ember.position = Vector2(18, 6)
	ember.size = Vector2(36, 36)
	btn.add_child(ember)
	parent.add_child(btn)
	return btn


func _style(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	var wall := ColorRect.new()
	wall.name = "Wall"
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.color = Palette.ASH_MID
	btn.add_child(wall)
	btn.move_child(wall, 0)
	var inset := ColorRect.new()
	inset.name = "Inset"
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.color = Palette.VOID
	inset.set_anchors_preset(Control.PRESET_FULL_RECT)
	inset.offset_left = 2
	inset.offset_top = 2
	inset.offset_right = -2
	inset.offset_bottom = -2
	btn.add_child(inset)
	btn.move_child(inset, 1)


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


func qa_set_locale(code: String) -> void:
	Game.set_locale(code)
	_refresh()


func _on_locale(code: String) -> void:
	if _same_click():
		return
	Game.set_locale(code)


func _lang_btn(parent: Node, rect: Rect2, code: String, caption: String) -> Button:
	var btn := Button.new()
	btn.position = rect.position
	btn.size = rect.size
	btn.text = caption
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func() -> void: _on_locale(code))
	btn.gui_input.connect(func(event: InputEvent) -> void:
		if _is_click(event):
			_on_locale(code)
			btn.accept_event()
	)
	parent.add_child(btn)
	return btn


func _input(event: InputEvent) -> void:
	# Viewport-space hit test. Survives IGNORE children and lower-layer HUD labels.
	if not _is_click(event):
		return
	var pos := _viewport_mouse(event)
	if LANG_PT_RECT.has_point(pos):
		_on_locale("pt")
		get_viewport().set_input_as_handled()
		return
	if LANG_EN_RECT.has_point(pos):
		_on_locale("en")
		get_viewport().set_input_as_handled()
		return
	if _diff == Game.Difficulty.NORMAL:
		if CAIM_RECT.has_point(pos):
			_on_body(Game.Body.CAIM)
			get_viewport().set_input_as_handled()
			return
		if LILITH_RECT.has_point(pos):
			_on_body(Game.Body.LILITH)
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


func qa_show(body: Game.Body, diff: Game.Difficulty) -> void:
	_body = body
	_diff = diff
	_preview_music()
	_refresh()


func qa_preview_path() -> String:
	if _diff == Game.Difficulty.BABY:
		return BABY_SHEET
	if _body == Game.Body.LILITH:
		return LILITH_SHEET
	return CAIM_SHEET


func qa_has_pixel_preview() -> bool:
	return _preview != null and _preview.texture != null and _preview.texture.get_width() > 0


func qa_preview_nearest() -> bool:
	return _preview != null and _preview.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST


func qa_card_faces() -> int:
	var n := 0
	for btn in [_caim_btn, _lilith_btn, _baby_btn, _normal_btn]:
		if btn == null:
			continue
		var face: Node = btn.find_child("Face", true, false)
		if face is TextureRect and (face as TextureRect).texture != null:
			n += 1
	return n


func _refresh() -> void:
	if _prompt:
		_prompt.text = Locale.t("menu.prompt")
	if _diff_label:
		_diff_label.text = Locale.t("menu.difficulty")
	if _confirm_btn:
		_confirm_btn.text = Locale.t("menu.swear")
	_paint_lang(_lang_pt, Game.locale != "en")
	_paint_lang(_lang_en, Game.locale == "en")
	var baby := _diff == Game.Difficulty.BABY
	_caim_btn.visible = not baby
	_lilith_btn.visible = not baby
	if _bebe_card:
		_bebe_card.visible = true
	_paint(_caim_btn, _body == Game.Body.CAIM)
	_paint(_lilith_btn, _body == Game.Body.LILITH)
	_paint(_baby_btn, baby)
	_paint(_normal_btn, not baby)
	if _preview:
		_preview.texture = _idle_tex(qa_preview_path())
		_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _preview_caption:
		if baby:
			_preview_caption.text = "Bebê Chorão"
		else:
			_preview_caption.text = String(Game.BODY_NAMES[_body])
	if baby:
		_hint.text = "Bebê Chorão"
	else:
		_hint.text = "%s  ·  %s" % [Game.BODY_NAMES[_body], Locale.t("menu.normal")]


func _paint_lang(btn: Button, on: bool) -> void:
	if btn == null:
		return
	btn.add_theme_color_override("font_color", Palette.EMBER if on else Palette.BONE_DIM)
	btn.add_theme_color_override("font_hover_color", Palette.EMBER if on else Palette.BONE)


func _paint(btn: Control, on: bool) -> void:
	var wall := btn.find_child("Wall", true, false)
	if wall is CanvasItem:
		(wall as CanvasItem).modulate = Color(1.15, 1.08, 0.95) if on else Color(0.72, 0.7, 0.68)
