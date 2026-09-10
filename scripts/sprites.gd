class_name Sprites
extends RefCounted
## Slice a cols×rows PNG. Never abort the tree if a sheet is missing.


static func tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Variant = ResourceLoader.load(path)
	if loaded is Texture2D:
		return loaded
	return null


static func cell(path: String, cols: int, rows: int, col: int, row: int) -> AtlasTexture:
	var sheet := tex(path)
	if sheet == null or cols < 1 or rows < 1:
		return null
	var fw := sheet.get_width() / cols
	var fh := sheet.get_height() / rows
	if fw < 1 or fh < 1:
		return null
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.filter_clip = true
	at.region = Rect2(col * fw, row * fh, fw, fh)
	return at


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
	var fw := sheet.get_width() / cols
	var fh := sheet.get_height() / rows
	if fw < 1 or fh < 1:
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
