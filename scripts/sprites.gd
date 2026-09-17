class_name Sprites
extends RefCounted
## Slice a cols×rows PNG. Never abort the tree if a sheet is missing.
## Look sheets (doors / hearts / shots / pit) load from the PNG on disk so a
## stale `.godot/imported/*.ctex` cannot keep hell art after a sheet replace.

static var _tex_cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t := _load_png(path)
	if t:
		_tex_cache[path] = t
	return t


static func _load_png(path: String) -> Texture2D:
	# Editor / F5: read the PNG bytes. ResourceLoader.load() can return a
	# CompressedTexture2D whose .ctex is an older hell sheet at the same path.
	var abs := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs):
		var img := Image.load_from_file(abs)
		if img and img.get_width() > 0 and img.get_height() > 0:
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		var loaded: Variant = ResourceLoader.load(path)
		if loaded is Texture2D:
			return loaded
	return null


static func cell(path: String, cols: int, rows: int, col: int, row: int) -> AtlasTexture:
	var sheet := tex(path)
	if sheet == null or cols < 1 or rows < 1:
		return null
	var fw := float(sheet.get_width()) / float(cols)
	var fh := float(sheet.get_height()) / float(rows)
	if fw < 1.0 or fh < 1.0:
		return null
	# Locked look cells. A stale hell ctex with the same path but a different
	# sheet size must not be sliced as gothic / Bone / diamond art.
	if path.ends_with("doors.png") and cols == 4 and rows == 2:
		if absf(fw - 384.0) > 1.0 or absf(fh - 512.0) > 1.0:
			push_warning("LOOK_WIRE reject doors cell %sx%s (want 384x512)" % [fw, fh])
			return null
	if path.ends_with("hearts.png") and cols == 4 and rows == 1:
		if absf(fw - 64.0) > 1.0 or absf(fh - 64.0) > 1.0:
			push_warning("LOOK_WIRE reject hearts cell %sx%s (want 64x64)" % [fw, fh])
			return null
	if path.ends_with("shots.png") and cols == 4 and rows == 8:
		if absf(fw - 64.0) > 1.0 or absf(fh - 64.0) > 1.0:
			push_warning("LOOK_WIRE reject shots cell %sx%s (want 64x64)" % [fw, fh])
			return null
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.filter_clip = true
	at.region = Rect2(col * fw, row * fh, fw, fh)
	return at


## Crop a sheet cell to its opaque pixels so asymmetric padding cannot shift art.
## 1px inset avoids sampling the next cell on rotate. Falls back to the full cell.
static func cell_used(path: String, cols: int, rows: int, col: int, row: int) -> AtlasTexture:
	var at := cell(path, cols, rows, col, row)
	if at == null:
		return null
	var img: Image = null
	if at.atlas:
		img = at.atlas.get_image()
	if img == null:
		_inset_region(at, 1)
		return at
	var ir := Rect2i(Vector2i(int(at.region.position.x), int(at.region.position.y)), Vector2i(int(at.region.size.x), int(at.region.size.y)))
	if ir.size.x < 2 or ir.size.y < 2:
		return at
	var used := img.get_region(ir).get_used_rect()
	if used.size.x < 8 or used.size.y < 8:
		_inset_region(at, 1)
		return at
	at.region = Rect2(at.region.position + Vector2(used.position), Vector2(used.size))
	_inset_region(at, 1)
	return at


static func _inset_region(at: AtlasTexture, px: int) -> void:
	var r := at.region
	if r.size.x > float(px * 2) and r.size.y > float(px * 2):
		at.region = Rect2(r.position + Vector2(px, px), r.size - Vector2(px * 2, px * 2))


## Reverse the middle frames so a 4-stamp row reads as a flicker, not a freeze.
static func ping_pong(spr: AnimatedSprite2D, anim: StringName = &"") -> void:
	if spr == null or spr.sprite_frames == null:
		return
	var sf := spr.sprite_frames
	if anim == StringName():
		anim = spr.animation
	if not sf.has_animation(anim):
		return
	var n := sf.get_frame_count(anim)
	if n < 3:
		return
	for i in range(n - 2, 0, -1):
		sf.add_frame(anim, sf.get_frame_texture(anim, i), sf.get_frame_duration(anim, i))


static func ping_pong_all(spr: AnimatedSprite2D) -> void:
	if spr == null or spr.sprite_frames == null:
		return
	for anim in spr.sprite_frames.get_animation_names():
		ping_pong(spr, StringName(anim))


## Fail-soft: missing frames just skip. Random start so a volley does not blink in lockstep.
static func stagger(spr: AnimatedSprite2D, fps: float = -1.0) -> void:
	if spr == null or spr.sprite_frames == null:
		return
	var anim := spr.animation
	if not spr.sprite_frames.has_animation(anim):
		var names := spr.sprite_frames.get_animation_names()
		if names.is_empty():
			return
		anim = StringName(names[0])
		spr.animation = anim
	if fps > 0.0:
		spr.sprite_frames.set_animation_speed(anim, fps)
	spr.play(anim)
	var n := spr.sprite_frames.get_frame_count(anim)
	if n > 1:
		spr.frame = randi() % n
		spr.frame_progress = randf()
	spr.speed_scale = randf_range(0.88, 1.18)


static func actor(
		path: String,
		cols: int,
		rows: int,
		anims: Dictionary,
		target_h: float
	) -> AnimatedSprite2D:
	var sheet := tex(path)
	if sheet == null or cols < 1 or rows < 1:
		return null
	var fw := float(sheet.get_width()) / float(cols)
	var fh := float(sheet.get_height()) / float(rows)
	if fw < 1.0 or fh < 1.0:
		return null
	if path.ends_with("shots.png") and cols == 4 and rows == 8:
		if absf(fw - 64.0) > 1.0 or absf(fh - 64.0) > 1.0:
			push_warning("LOOK_WIRE reject shots actor %sx%s (want 64x64)" % [fw, fh])
			return null
	var sf := SpriteFrames.new()
	for anim_name in anims:
		var spec: Dictionary = anims[anim_name]
		if not sf.has_animation(anim_name):
			sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, float(spec.get("fps", 8.0)))
		sf.set_animation_loop(anim_name, bool(spec.get("loop", true)))
		var row := int(spec.get("row", 0))
		var start := int(spec.get("start", 0))
		var count := int(spec.get("count", cols))
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.filter_clip = true
			at.region = Rect2((start + i) * fw, row * fh, fw, fh)
			sf.add_frame(anim_name, at)
	var node := AnimatedSprite2D.new()
	node.sprite_frames = sf
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.centered = true
	if fh > 0 and target_h > 0.0:
		node.scale = Vector2.ONE * (target_h / float(fh))
	var keys: Array = anims.keys()
	if not keys.is_empty():
		var first := StringName(keys[0])
		node.animation = first
		node.play(first)
	return node
