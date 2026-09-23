class_name Sprites
extends RefCounted
## Slice a cols×rows PNG. Gameplay sheets must bind; never mask a miss with
## vector `_draw`. Prefer PNG bytes on disk (res:// and OS path) so a missing
## or stale `.godot/imported/*.ctex` cannot blank F5. Imported CompressedTexture2D
## is used only when ImageTexture is unusable on the GPU.
##
## Hazard FX (fx_beam / fx_slam / fx_wisp / fx_tele / fx_ring) may stay
## fail-soft — those are telegraphs, not actors. Documented in hazard.gd.

const GAMEPLAY_SHEETS: PackedStringArray = [
	"res://assets/sprites/player.png",
	"res://assets/sprites/player_f.png",
	"res://assets/sprites/baby.png",
	"res://assets/sprites/cantor.png",
	"res://assets/sprites/wretch.png",
	"res://assets/sprites/concierge.png",
	"res://assets/sprites/pickups.png",
	"res://assets/sprites/pickup_aura.png",
	"res://assets/sprites/skills.png",
	"res://assets/sprites/shots.png",
	"res://assets/sprites/hearts.png",
	"res://assets/sprites/doors.png",
	"res://assets/sprites/env.png",
	"res://assets/env/pit.png",
	"res://assets/characters/imp/walk_vanilla.png",
	"res://assets/characters/imp/attack_vanilla.png",
	"res://assets/characters/boss/idle.png",
	"res://assets/characters/boss/move.png",
	"res://assets/characters/boss/fire.png",
	"res://assets/characters/boss/lightning.png",
]

static var _tex_cache: Dictionary = {}
static var _src_cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t := _load_png(path)
	if t:
		_tex_cache[path] = t
	return t


static func fail(path: String, detail: String = "") -> void:
	var src := src_of(path) if not path.is_empty() else "none"
	var msg := "SPRITE_BIND FAIL path=%s src=%s" % [path, src]
	if not detail.is_empty():
		msg += " detail=" + detail
	push_error(msg)
	printerr(msg)
	assert(false, msg)


static func require(path: String) -> Texture2D:
	var t := tex(path)
	if not _usable(t):
		fail(path, "texture missing or 0x0")
	return t


static func require_cell(path: String, cols: int, rows: int, col: int, row: int) -> AtlasTexture:
	var at := cell(path, cols, rows, col, row)
	if at == null:
		fail(path, "cell %sx%s @ %s,%s" % [cols, rows, col, row])
	return at


static func require_gameplay() -> void:
	for path in GAMEPLAY_SHEETS:
		require(path)
	if cell("res://assets/sprites/doors.png", 4, 2, 0, 0) == null:
		fail("res://assets/sprites/doors.png", "look cell want 256x96")
	if cell("res://assets/sprites/hearts.png", 4, 1, 0, 0) == null:
		fail("res://assets/sprites/hearts.png", "look cell want 64x64")
	if cell("res://assets/sprites/pickup_aura.png", 2, 1, 0, 0) == null:
		fail("res://assets/sprites/pickup_aura.png", "look cell want 64x64")
	if cell("res://assets/sprites/shots.png", 4, 8, 0, 0) == null:
		fail("res://assets/sprites/shots.png", "look cell want 64x64")
	# In-world Caim / Lilith / Bebê must be pixel bodies, not look-pass
	# Penitent diamonds (12 geometric frames, ~5 Bone/Ash/Ember colors).
	if not is_character_body("res://assets/sprites/player.png", 4, 3):
		fail("res://assets/sprites/player.png", "penitent geometry / not a character body")
	if not is_character_body("res://assets/sprites/player_f.png"):
		fail("res://assets/sprites/player_f.png", "penitent geometry / not a character body")
	if not is_character_body("res://assets/sprites/baby.png", 1, 1):
		fail("res://assets/sprites/baby.png", "penitent geometry / not a character body")
	# Gate FAIL if Caim is void-hood 4×4, look-pass diamond, Lilith, or Bebê.
	if not is_caim_own_body():
		fail("res://assets/sprites/player.png", "caim reused female/bebe/diamond/void-hood")


static func sheet_exists(path: String) -> bool:
	return not path.is_empty() and tex(path) != null


static func disk_md5(path: String) -> String:
	for p in _png_paths(path):
		var md := FileAccess.get_md5(p)
		if md != "":
			return md
	return ""


static func is_void_hood(path: String) -> bool:
	# Pointed Ash hood / void-face Penitent lived on a square 4×4 sheet
	# (1044×1044). Male-from-Lilith Caim is a landscape 4×3 (1280×720).
	var t := tex(path)
	if t == null:
		return true
	var w := t.get_width()
	var h := t.get_height()
	if w < 8 or h < 8:
		return true
	var ratio := float(w) / float(h)
	return ratio > 0.82 and ratio < 1.22


static func is_caim_own_body() -> bool:
	var caim := "res://assets/sprites/player.png"
	var lilith := "res://assets/sprites/player_f.png"
	var baby := "res://assets/sprites/baby.png"
	var a := disk_md5(caim)
	var b := disk_md5(lilith)
	var c := disk_md5(baby)
	if a.is_empty() or a == b or a == c:
		return false
	if is_void_hood(caim):
		return false
	return is_character_body(caim, 4, 3)


static func is_character_body(path: String, cols: int = 4, rows: int = 3) -> bool:
	# Penitent look-pass cells are 3–8 unique colors. A walk body has hundreds.
	var t := tex(path)
	if t == null:
		return false
	var img := t.get_image()
	if img == null:
		return false
	var cw := maxi(img.get_width() / maxi(cols, 1), 1)
	var ch := maxi(img.get_height() / maxi(rows, 1), 1)
	var seen: Dictionary = {}
	var y := 0
	while y < ch:
		var x := 0
		while x < cw:
			var c := img.get_pixel(x, y)
			if c.a > 0.08:
				var key := int(c.r * 31.0) * 10000 + int(c.g * 31.0) * 100 + int(c.b * 31.0)
				seen[key] = true
				if seen.size() >= 80:
					return true
			x += 1
		y += 1
	return false


static func src_of(path: String) -> String:
	return String(_src_cache.get(path, "none"))


static func _png_paths(path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not path.is_empty():
		out.append(path)
	var abs := ProjectSettings.globalize_path(path)
	if not abs.is_empty() and abs != path:
		out.append(abs)
		var slashed := abs.replace("\\", "/")
		if slashed != abs:
			out.append(slashed)
		var backed := abs.replace("/", "\\")
		if backed != abs:
			out.append(backed)
	return out


static func _usable(t: Texture2D) -> bool:
	return t != null and t.get_width() > 0 and t.get_height() > 0


static func _ensure_rgba(img: Image) -> void:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)


static func _texture_from_image(img: Image) -> Texture2D:
	if img == null or img.get_width() < 1 or img.get_height() < 1:
		return null
	_ensure_rgba(img)
	var tex := ImageTexture.create_from_image(img)
	if _usable(tex):
		return tex
	return null


static func _image_from_bytes(bytes: PackedByteArray) -> Image:
	if bytes.size() < 8:
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	if img.get_width() < 1 or img.get_height() < 1:
		return null
	return img


static func _image_from_disk(path: String) -> Image:
	# Read PNG bytes through the project FS (res://) and the OS path.
	# FileAccess.file_exists(absolute) is false on some Windows editor setups,
	# and Image.load_from_file(abs) never runs — F5 then has no sheet at all
	# if .ctex is missing or ResourceLoader.exists is still false.
	for p in _png_paths(path):
		var is_res := p.begins_with("res://") or p.begins_with("user://")
		if not is_res and not FileAccess.file_exists(p):
			continue
		var bytes := FileAccess.get_file_as_bytes(p)
		if bytes.size() >= 8:
			var from_buf := _image_from_bytes(bytes)
			if from_buf:
				return from_buf
		if not is_res and not FileAccess.file_exists(p):
			continue
		var img := Image.new()
		if img.load(p) == OK and img.get_width() > 0 and img.get_height() > 0:
			return img
		var loaded := Image.load_from_file(p)
		if loaded and loaded.get_width() > 0 and loaded.get_height() > 0:
			return loaded
	return null


static func _texture_from_import(path: String) -> Texture2D:
	# Missing .ctex makes exists() false; disk bytes already handled that.
	# Use the importer only when it actually has a texture to give us.
	if not ResourceLoader.exists(path):
		return null
	var loaded: Variant = ResourceLoader.load(path)
	if loaded is Texture2D and _usable(loaded):
		return loaded
	return null


static func _load_png(path: String) -> Texture2D:
	# Disk PNG wins when it actually produced a GPU texture. That bypasses a
	# leftover hell .ctex at the same res:// path. If ImageTexture is unusable
	# (width 0 on some GL Compatibility GPUs), fall through to the importer.
	var disk_img := _image_from_disk(path)
	var disk_tex: Texture2D = null
	if disk_img:
		disk_tex = _texture_from_image(disk_img)
	if _usable(disk_tex):
		_src_cache[path] = "disk"
		return disk_tex
	var imported := _texture_from_import(path)
	if _usable(imported):
		_src_cache[path] = "import"
		return imported
	if _usable(disk_tex):
		_src_cache[path] = "disk"
		return disk_tex
	_src_cache[path] = "none"
	return null


static func cell(path: String, cols: int, rows: int, col: int, row: int) -> AtlasTexture:
	var sheet := _sheet_for_grid(path, cols, rows)
	if sheet == null or cols < 1 or rows < 1:
		return null
	var fw := float(sheet.get_width()) / float(cols)
	var fh := float(sheet.get_height()) / float(rows)
	if fw < 1.0 or fh < 1.0:
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


static func _look_cell_size(path: String, cols: int, rows: int) -> Vector2:
	if path.ends_with("doors.png") and cols == 4 and rows == 2:
		return Vector2(256, 96)
	if path.ends_with("hearts.png") and cols == 4 and rows == 1:
		return Vector2(64, 64)
	if path.ends_with("pickup_aura.png") and cols == 2 and rows == 1:
		return Vector2(64, 64)
	if path.ends_with("shots.png") and cols == 4 and rows == 8:
		return Vector2(64, 64)
	return Vector2.ZERO


static func _matches_look(sheet: Texture2D, path: String, cols: int, rows: int) -> bool:
	if not _usable(sheet) or cols < 1 or rows < 1:
		return false
	var want := _look_cell_size(path, cols, rows)
	if want == Vector2.ZERO:
		return true
	var fw := float(sheet.get_width()) / float(cols)
	var fh := float(sheet.get_height()) / float(rows)
	return absf(fw - want.x) <= 1.0 and absf(fh - want.y) <= 1.0


static func _sheet_for_grid(path: String, cols: int, rows: int) -> Texture2D:
	var sheet := tex(path)
	if _matches_look(sheet, path, cols, rows):
		return sheet
	# Cached import may be a leftover hell sheet. Re-read PNG bytes once.
	_tex_cache.erase(path)
	var disk_img := _image_from_disk(path)
	if disk_img:
		var disk_tex := _texture_from_image(disk_img)
		if _matches_look(disk_tex, path, cols, rows):
			_tex_cache[path] = disk_tex
			_src_cache[path] = "disk"
			return disk_tex
	if _usable(sheet):
		var fw := float(sheet.get_width()) / float(cols)
		var fh := float(sheet.get_height()) / float(rows)
		var want := _look_cell_size(path, cols, rows)
		if want != Vector2.ZERO:
			push_warning("LOOK_WIRE reject %s cell %sx%s (want %sx%s)" % [path.get_file(), fw, fh, want.x, want.y])
			return null
	return sheet


static func actor(
		path: String,
		cols: int,
		rows: int,
		anims: Dictionary,
		target_h: float,
		required: bool = false
	) -> AnimatedSprite2D:
	var sheet := _sheet_for_grid(path, cols, rows)
	if sheet == null or cols < 1 or rows < 1:
		if required:
			fail(path, "actor sheet missing cols=%s rows=%s" % [cols, rows])
		elif sheet == null:
			push_warning("SPRITE_BIND FX miss path=%s (hazard FX may stay vector)" % path)
		return null
	var fw := float(sheet.get_width()) / float(cols)
	var fh := float(sheet.get_height()) / float(rows)
	if fw < 1.0 or fh < 1.0:
		if required:
			fail(path, "actor cell %sx%s" % [fw, fh])
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
