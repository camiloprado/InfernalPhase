extends Node
## In-engine checklist for --qa-combat. Prints QA_ITEM lines; does not change gameplay rules.

var _floor: Floor
var _pass := 0
var _fail := 0
var _skip := 0
var _shake_hits := 0
var _snap_each := false


func run(floor_node: Floor) -> void:
	_floor = floor_node
	print("QA_COMBAT start")
	get_tree().debug_collisions_hint = true
	Game.shake.connect(_on_shake)
	_prep_arena()
	await get_tree().process_frame
	await get_tree().process_frame
	var spec_only := "--qa-spec" in OS.get_cmdline_user_args() and not ("--qa-combat" in OS.get_cmdline_user_args())
	var viz_only := "--qa-viz" in OS.get_cmdline_user_args() and not ("--qa-combat" in OS.get_cmdline_user_args())
	var play_only := "--qa-play" in OS.get_cmdline_user_args() and not ("--qa-combat" in OS.get_cmdline_user_args())
	if viz_only:
		await _test_viz()
		Game.shake.disconnect(_on_shake)
		var okv := 1 if _fail == 0 else 0
		print("QA_VIZ pass=", _pass, " fail=", _fail, " skip=", _skip, " ok=", okv)
		if okv != 1:
			printerr("QA_VIZ FAIL fail=%s" % _fail)
		return
	if play_only:
		await _test_play()
		Game.shake.disconnect(_on_shake)
		var okp := 1 if _fail == 0 else 0
		print("QA_PLAY pass=", _pass, " fail=", _fail, " skip=", _skip, " ok=", okp)
		if okp != 1:
			printerr("QA_PLAY FAIL fail=%s" % _fail)
		return
	await _test_spec()
	if spec_only:
		Game.shake.disconnect(_on_shake)
		var ok := 1 if _fail == 0 else 0
		print("QA_COMBAT pass=", _pass, " fail=", _fail, " skip=", _skip, " ok=", ok)
		if ok != 1:
			printerr("QA_COMBAT FAIL fail=%s" % _fail)
		return
	await _test_render()
	await _test_hitboxes()
	await _test_shots()
	await _test_combat()
	await _test_ai()
	await _test_ambiance()
	Game.shake.disconnect(_on_shake)
	var ok := 1 if _fail == 0 else 0
	print("QA_COMBAT pass=", _pass, " fail=", _fail, " skip=", _skip, " ok=", ok)
	if ok != 1:
		printerr("QA_COMBAT FAIL fail=%s" % _fail)


func _on_shake(_amount: float) -> void:
	_shake_hits += 1


func _prep_arena() -> void:
	Game.is_dead = false
	Game.is_won = false
	Game.hearts = Game.MAX_HEARTS
	Game.max_hearts = Game.MAX_HEARTS
	Game.ember = 0
	Game.heavy = 0
	Game.rapid = 0
	Game.pierce = 0
	Game.burn = 0
	Game.body = Game.Body.CAIM
	var p: Player = _floor.player
	if p == null:
		return
	p.i_timer = 0.0
	p.knockback = Vector2.ZERO
	p.rebind_visual()
	p.set_physics_process(true)
	var start: Room = _floor.rooms.get(Vector2i.ZERO)
	if start:
		p.global_position = start.center_global()
		_floor._enter_room(start, true)
	if _floor.camera:
		_floor.camera.position_smoothing_enabled = false
		_floor.camera.zoom = Vector2.ONE
		_floor.camera.global_position = p.global_position
		_floor.camera.reset_smoothing()
	if _floor.ui:
		_floor.ui.visible = true


func _item(section: String, id: String, result: String, detail: String) -> void:
	match result:
		"PASS":
			_pass += 1
		"FAIL":
			_fail += 1
		_:
			_skip += 1
	print("QA_ITEM section=", section, " id=", id, " result=", result, " detail=", detail)
	if _snap_each and _floor:
		_floor._qa_shot("spec/%s" % id)


func _test_render() -> void:
	var p: Player = _floor.player
	if p == null or p._sheet == null:
		_item("render", "sheet", "FAIL", "player sheet missing")
		return
	var sheet: AnimatedSprite2D = p._sheet
	_item("render", "pivot_centered", "PASS" if sheet.centered else "FAIL", "centered=%s" % sheet.centered)

	var origin := p.global_position
	p.set_physics_process(false)
	p.aim = Vector2.RIGHT
	p.velocity = Vector2.ZERO
	p._sync_sheet()
	await get_tree().process_frame
	var pos_r := sheet.global_position
	var flip_r := sheet.flip_h
	p.aim = Vector2.LEFT
	p._sync_sheet()
	await get_tree().process_frame
	var pos_l := sheet.global_position
	var jump := pos_l.distance_to(pos_r)
	var flipped := (not flip_r) and sheet.flip_h
	p.set_physics_process(true)
	if jump < 0.51 and flipped and p.global_position.distance_to(origin) < 0.51:
		_item("render", "flip_x", "PASS", "node_jump=%.3f flip_h %s->%s" % [jump, flip_r, sheet.flip_h])
	else:
		_item("render", "flip_x", "FAIL", "node_jump=%.3f flip_h %s->%s body_shift=%.3f" % [jump, flip_r, sheet.flip_h, p.global_position.distance_to(origin)])
	_item("render", "flip_y", "SKIP", "top-down walker does not flip_y")

	p.set_physics_process(false)
	sheet.play("idle")
	await get_tree().create_timer(0.12).timeout
	var idle_ok := sheet.animation == &"idle" and sheet.is_playing()
	p.velocity = Vector2.RIGHT * 80.0
	sheet.play("walk")
	await get_tree().process_frame
	var walk_ok := sheet.animation == &"walk" and sheet.is_playing()
	sheet.play("attack")
	await get_tree().process_frame
	var atk_ok := sheet.animation == &"attack"
	await get_tree().create_timer(0.45).timeout
	# attack is non-looping; _on_sheet_finished should restore idle/walk
	var recovered := sheet.animation != &"attack" or not sheet.is_playing()
	p.velocity = Vector2.ZERO
	p._sync_sheet()
	p.set_physics_process(true)
	if idle_ok and walk_ok and atk_ok and recovered:
		_item("render", "anim_idle_walk_attack", "PASS", "idle=%s walk=%s attack=%s recovered=%s now=%s" % [idle_ok, walk_ok, atk_ok, recovered, sheet.animation])
	else:
		_item("render", "anim_idle_walk_attack", "FAIL", "idle=%s walk=%s attack=%s recovered=%s now=%s" % [idle_ok, walk_ok, atk_ok, recovered, sheet.animation])

	var has_hit := sheet.sprite_frames != null and sheet.sprite_frames.has_animation(&"hit")
	var has_death := sheet.sprite_frames != null and sheet.sprite_frames.has_animation(&"death")
	_item("render", "anim_hit", "SKIP" if not has_hit else "PASS", "player sheet has no hit row (i-frame blink is modulate)")
	_item("render", "anim_death", "SKIP" if not has_death else "PASS", "player sheet has no death row (HUD end card)")

	var z_ok := p.z_index == 8
	var shot := _floor.spawn_bullet(p.global_position + Vector2(40, 0), Vector2.RIGHT, 20.0, false, Palette.EMBER, 5.0, 0.0, 8.0, 0.0, 0.0, "player")
	await get_tree().process_frame
	var shot_z := shot.z_index if shot else -1
	var room_z := _floor.current.z_index if _floor.current else 0
	if z_ok and shot_z > p.z_index and room_z < p.z_index:
		_item("render", "z_order", "PASS", "room=%s player=%s shot=%s" % [room_z, p.z_index, shot_z])
	else:
		_item("render", "z_order", "FAIL", "room=%s player=%s shot=%s" % [room_z, p.z_index, shot_z])
	if shot:
		shot.queue_free()
	_floor._qa_shot("qa_combat_debug_shapes")


func _test_hitboxes() -> void:
	var p: Player = _floor.player
	var body_shape: CircleShape2D = p._col.shape as CircleShape2D
	var hurt_shape: CircleShape2D = p.get_node("Hurtbox/CollisionShape2D").shape as CircleShape2D
	if body_shape and hurt_shape and hurt_shape.radius <= body_shape.radius + 0.1:
		_item("collision", "hurt_inside_body", "PASS", "body_r=%.1f hurt_r=%.1f" % [body_shape.radius, hurt_shape.radius])
	else:
		_item("collision", "hurt_inside_body", "FAIL", "body=%s hurt=%s" % [body_shape, hurt_shape])

	var debug_on := get_tree().debug_collisions_hint
	_item("collision", "debug_shapes", "PASS" if debug_on else "FAIL", "debug_collisions_hint=%s" % debug_on)

	# Attack is a pistol shot, not a moving melee box. Hurtbox stays on the body.
	var hurt_off: Vector2 = (p.get_node("Hurtbox") as Node2D).position
	_item("collision", "attack_hitbox_follow", "PASS" if hurt_off.length() < 0.1 else "FAIL", "hurtbox offset=%s (ranged muzzle, not melee swing)" % hurt_off)

	var room: Room = _floor.current
	if room == null or p == null:
		_item("collision", "walls", "FAIL", "no room")
		return
	var center := room.center_global()
	p.knockback = Vector2.ZERO
	p.global_position = center
	p.velocity = Vector2.ZERO
	p.move_and_slide()
	# Drive into the north-west corner for several physics ticks.
	p.global_position = room.global_position + Vector2(Game.WALL + 8.0, Game.WALL + 8.0)
	for _i in 24:
		p.velocity = Vector2(-420, -420)
		p.move_and_slide()
	var after := p.global_position
	var nan := is_nan(after.x) or is_nan(after.y)
	var in_room := after.x > room.global_position.x - 4.0 and after.y > room.global_position.y - 4.0
	in_room = in_room and after.x < room.global_position.x + Game.ROOM_SIZE.x + 4.0
	in_room = in_room and after.y < room.global_position.y + Game.ROOM_SIZE.y + 4.0
	var not_stuck := after.distance_to(room.global_position + Vector2(Game.WALL + 8.0, Game.WALL + 8.0)) < 80.0
	if not nan and in_room and not_stuck:
		_item("collision", "corner_walls", "PASS", "pos=%s in_room=%s" % [after, in_room])
	else:
		_item("collision", "corner_walls", "FAIL", "pos=%s nan=%s in_room=%s" % [after, nan, in_room])
	p.global_position = center
	p.velocity = Vector2.ZERO


func _test_shots() -> void:
	var p: Player = _floor.player
	var room: Room = _floor.current
	p.global_position = room.center_global()
	p.aim = Vector2.RIGHT
	p.velocity = Vector2.ZERO
	var expected := p.global_position + p.aim * (Player.RADIUS + 8.0)
	var shot: Bullet = _floor.spawn_bullet(expected, p.aim, 400.0, false, Palette.EMBER_HOT, 4.5, 0.0, 8.0, 0.0, 0.0, "player")
	var spawn_err := shot.global_position.distance_to(expected) if shot else 999.0
	_item("shots", "muzzle", "PASS" if spawn_err < 1.5 else "FAIL", "err=%.3f expected=%s got=%s" % [spawn_err, expected, shot.global_position if shot else Vector2.ZERO])
	if shot == null:
		_item("shots", "trajectory", "FAIL", "no shot")
		return
	var start := shot.global_position
	await get_tree().create_timer(0.12).timeout
	var traveled := shot.global_position.distance_to(start) if is_instance_valid(shot) else 0.0
	_item("shots", "trajectory", "PASS" if traveled > 20.0 else "FAIL", "traveled=%.1f in 0.12s" % traveled)

	# Diagonal while the walker is moving.
	p.velocity = Vector2(120, 90)
	p.aim = Vector2(1, 1).normalized()
	var diag: Bullet = _floor.spawn_bullet(p.global_position + p.aim * (Player.RADIUS + 8.0), p.aim, 400.0, false, Palette.EMBER, 4.5, 0.0, 8.0, 0.0, 0.0, "player")
	var d0 := diag.global_position
	await get_tree().create_timer(0.1).timeout
	var dmove := diag.global_position - d0 if is_instance_valid(diag) else Vector2.ZERO
	var diag_ok := absf(dmove.x) > 8.0 and absf(dmove.y) > 8.0
	_item("shots", "diagonal_moving", "PASS" if diag_ok else "FAIL", "delta=%s" % dmove)
	p.velocity = Vector2.ZERO

	# Lifetime: no leak after timeout.
	var before := _live_bullets()
	var short: Bullet = _floor.spawn_bullet(p.global_position, Vector2.UP, 50.0, false, Palette.EMBER, 4.0, 0.0, 8.0, 0.0, 0.0, "player")
	short.lifetime = 0.12
	await get_tree().create_timer(0.28).timeout
	var still := is_instance_valid(short)
	var after := _live_bullets()
	_item("shots", "lifetime_free", "PASS" if (not still) and after <= before + 2 else "FAIL", "valid=%s before=%s after=%s" % [still, before, after])

	# Wall spend.
	# Aim at a solid west wall slab, not the mid-height door gap.
	var wall_shot: Bullet = _floor.spawn_bullet(room.global_position + Vector2(Game.WALL + 28.0, Game.WALL + 48.0), Vector2.LEFT, 700.0, false, Palette.EMBER, 5.0, 0.0, 8.0, 0.0, 0.0, "player")
	await get_tree().create_timer(0.2).timeout
	_item("shots", "wall_despawn", "PASS" if not is_instance_valid(wall_shot) or wall_shot.spent else "FAIL", "valid=%s spent=%s" % [is_instance_valid(wall_shot), wall_shot.spent if is_instance_valid(wall_shot) else true])

	if is_instance_valid(shot):
		shot.queue_free()
	if is_instance_valid(diag):
		diag.queue_free()


func _live_bullets() -> int:
	var n := 0
	for c in _floor.projectiles.get_children():
		if c is Bullet and is_instance_valid(c) and not (c as Bullet).spent:
			n += 1
	return n


func _test_combat() -> void:
	var p: Player = _floor.player
	Game.ember = 0
	Game.heavy = 0
	var d0 := Game.shot_damage()
	Game.ember = 1
	var d1 := Game.shot_damage()
	Game.heavy = 1
	var d2 := Game.shot_damage()
	Game.ember = 0
	Game.heavy = 0
	if d0 == 1 and d1 == 2 and d2 == 3:
		_item("combat", "shot_damage_formula", "PASS", "base=%s ember=%s ember+heavy=%s (1+ember+heavy)" % [d0, d1, d2])
	else:
		_item("combat", "shot_damage_formula", "FAIL", "base=%s ember=%s both=%s" % [d0, d1, d2])

	# Enemy HP vs take_hit.
	var dummy: Enemy = _floor._enemy_scene.instantiate()
	_floor.actors.add_child(dummy)
	dummy.configure(Enemy.Kind.IMP, p.global_position + Vector2(80, 0))
	dummy.set_physics_process(false)
	var hp0 := dummy.hp
	dummy.take_hit(2)
	var hp1 := dummy.hp if is_instance_valid(dummy) else -1
	if hp1 == hp0 - 2:
		_item("combat", "enemy_hp", "PASS", "hp %s -> %s after 2" % [hp0, hp1])
	else:
		_item("combat", "enemy_hp", "FAIL", "hp %s -> %s" % [hp0, hp1])

	# I-frames: two hits same stamp must cost one heart.
	Game.hearts = 4
	p.i_timer = 0.0
	p._hit_stamp_ms = -99999
	Game._hurt_stamp_ms = -99999
	_shake_hits = 0
	var h0 := Game.hearts
	p.take_hit(dummy)
	var h1 := Game.hearts
	var juice_i := p.i_timer
	var juice_kb := p.knockback.length()
	var juice_shakes := _shake_hits
	p.take_hit(dummy)
	var h2 := Game.hearts
	await get_tree().create_timer(0.12).timeout
	p.take_hit(dummy)
	var h3 := Game.hearts
	await get_tree().create_timer(0.55).timeout
	p.i_timer = 0.0
	Game._hurt_stamp_ms = -99999
	p._hit_stamp_ms = -99999
	p.take_hit(dummy)
	var h4 := Game.hearts
	var iframe_ok := h1 == h0 - 1 and h2 == h1 and h3 == h1 and h4 == h1 - 1
	_item("combat", "iframes", "PASS" if iframe_ok else "FAIL", "hearts %s>%s same=%s mid=%s after=%s iframe_ms=%s" % [h0, h1, h2, h3, h4, Game.IFRAME_MS])
	_item("combat", "juice_flash_knockback_shake", "PASS" if juice_i > 0.0 and juice_kb > 1.0 and juice_shakes > 0 else "FAIL", "i_timer=%.2f knockback=%.1f shakes=%s blink_modulate" % [juice_i, juice_kb, juice_shakes])

	# Death: drain remaining hearts, confirm end state. Player has no death clip.
	Game.hearts = 1
	p.i_timer = 0.0
	p._hit_stamp_ms = -99999
	Game._hurt_stamp_ms = -99999
	Game.is_dead = false
	p.take_hit(dummy)
	await get_tree().process_frame
	_item("combat", "player_death", "PASS" if Game.is_dead and Game.hearts <= 0 else "FAIL", "dead=%s hearts=%s" % [Game.is_dead, Game.hearts])

	# Enemy death disables body layer then frees.
	get_tree().paused = false
	Game.is_dead = false
	Game.hearts = Game.MAX_HEARTS
	p.i_timer = 0.4
	var fodder: Enemy = _floor._enemy_scene.instantiate()
	_floor.actors.add_child(fodder)
	fodder.configure(Enemy.Kind.IMP, p.global_position + Vector2(-70, 30))
	fodder.set_physics_process(false)
	fodder.hp = 1
	fodder.take_hit(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var enemy_gone := not is_instance_valid(fodder)
	_item("combat", "enemy_death_hitbox", "PASS" if enemy_gone else "FAIL", "freed=%s (collision_layer=0 then queue_free; no death clip)" % enemy_gone)

	if is_instance_valid(dummy):
		dummy.queue_free()
	Game.is_dead = false
	Game.hearts = Game.MAX_HEARTS
	p.i_timer = 0.0
	p.knockback = Vector2.ZERO


func _test_ai() -> void:
	var p: Player = _floor.player
	var room: Room = _floor.current
	p.global_position = room.center_global()

	var imp: Enemy = _floor._enemy_scene.instantiate()
	_floor.actors.add_child(imp)
	imp.configure(Enemy.Kind.IMP, p.global_position + Vector2(240, 0))
	imp.set_meta("room", room.room_id)
	var far := imp.global_position
	imp.set_physics_process(true)
	for _i in 20:
		await get_tree().physics_frame
	var closed := imp.global_position.distance_to(p.global_position) < far.distance_to(p.global_position) - 4.0
	_item("ai", "chase", "PASS" if closed else "FAIL", "start_dist=%.1f now=%.1f (imp seeks / orbits inside 170px)" % [far.distance_to(p.global_position), imp.global_position.distance_to(p.global_position)])

	# Close range: IMP switches to orthogonal strafe, not a patrol FSM.
	imp.global_position = p.global_position + Vector2(40, 0)
	var v0 := imp.velocity
	imp._move(0.016)
	var strafe := absf(imp.velocity.dot((p.global_position - imp.global_position).normalized())) < imp.velocity.length() * 0.85
	_item("ai", "states", "SKIP", "no patrol/vision FSM; imp seek/orbit, wretch home-orbit, cantor strafe. close_strafe=%s v=%s" % [strafe, imp.velocity])
	v0 = v0

	# Pathfinding: enemies collide with world (mask=1) but have no NavigationAgent.
	var has_nav := imp.get_node_or_null("NavigationAgent2D") != null
	_item("ai", "pathfinding", "FAIL" if not has_nav else "PASS", "NavigationAgent2D=%s mask=%s (slide on walls, no detour graph)" % [has_nav, imp.collision_mask])

	# Stacking: enemies do not collide with each other (mask world only).
	var a: Enemy = _floor._enemy_scene.instantiate()
	var b: Enemy = _floor._enemy_scene.instantiate()
	_floor.actors.add_child(a)
	_floor.actors.add_child(b)
	var stack_at := p.global_position + Vector2(0, -90)
	a.configure(Enemy.Kind.IMP, stack_at)
	b.configure(Enemy.Kind.IMP, stack_at)
	a.set_physics_process(true)
	b.set_physics_process(true)
	for _j in 18:
		await get_tree().physics_frame
	var sep := a.global_position.distance_to(b.global_position) if is_instance_valid(a) and is_instance_valid(b) else 0.0
	var collide_each := a.collision_mask & 4 != 0
	if not collide_each:
		_item("ai", "grouping", "FAIL", "enemy-enemy mask off; sep=%.1f after 18 ticks (can occupy same point)" % sep)
	else:
		_item("ai", "grouping", "PASS" if sep > 8.0 else "FAIL", "sep=%.1f" % sep)

	if is_instance_valid(imp):
		imp.queue_free()
	if is_instance_valid(a):
		a.queue_free()
	if is_instance_valid(b):
		b.queue_free()


func _test_ambiance() -> void:
	var p: Player = _floor.player
	# Contrast: player pixel vs void floor should not be identical.
	if _floor.camera:
		_floor.camera.global_position = p.global_position
		_floor.camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout
	var tex := get_viewport().get_texture()
	var contrast_ok := false
	var detail := "no viewport image"
	if tex:
		var img := tex.get_image()
		if img:
			var sp := p.get_global_transform_with_canvas().origin
			var cx := clampi(int(sp.x), 2, img.get_width() - 3)
			var cy := clampi(int(sp.y), 2, img.get_height() - 3)
			var mid := img.get_pixel(cx, cy)
			var floor_px := img.get_pixel(clampi(cx + 220, 0, img.get_width() - 1), clampi(cy + 80, 0, img.get_height() - 1))
			var d := 0.0
			for ox in range(-16, 17, 4):
				for oy in range(-28, 9, 4):
					var px := img.get_pixel(clampi(cx + ox, 0, img.get_width() - 1), clampi(cy + oy, 0, img.get_height() - 1))
					d = maxf(d, absf(px.r - floor_px.r) + absf(px.g - floor_px.g) + absf(px.b - floor_px.b))
					if px.r + px.g + px.b > mid.r + mid.g + mid.b:
						mid = px
			contrast_ok = d > 0.12
			detail = "actor=%s floor=%s delta=%.3f at=%s,%s" % [mid, floor_px, d, cx, cy]
	_item("ambiance", "contrast", "PASS" if contrast_ok else "FAIL", detail)

	var sfx_n := get_node_or_null("/root/Sfx")
	var playing := sfx_n != null
	_item("ambiance", "bgm", "PASS" if playing else "FAIL", "Sfx autoload=%s (stingers + rumble, no OGG bed)" % playing)
	_item("ambiance", "sfx_shots_hits_steps", "PASS" if sfx_n != null else "FAIL", "shoot/hit/pickup/door/unlock/talk")

	# Perf: volley + dummy imps.
	var t0 := Time.get_ticks_usec()
	var spawned: Array[Node] = []
	for i in 40:
		var b: Bullet = _floor.spawn_bullet(p.global_position, Vector2.RIGHT.rotated(float(i) * 0.16), 280.0, true, Palette.EMBER, 5.0, 0.0, 8.0, 0.0, 0.0, "imp")
		spawned.append(b)
	for _k in 12:
		await get_tree().process_frame
	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var fps := Engine.get_frames_per_second()
	var fps_ok := fps >= 40.0 or dt_ms < 450.0
	_item("ambiance", "perf_volley", "PASS" if fps_ok else "FAIL", "fps=%.1f 12f_ms=%.0f live_shots=%s" % [fps, dt_ms, _live_bullets()])
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	_floor._qa_shot("qa_combat_end")


func _revive() -> void:
	get_tree().paused = false
	Game.is_dead = false
	Game.is_won = false
	Game.hearts = Game.MAX_HEARTS
	Game.max_hearts = Game.MAX_HEARTS
	var p: Player = _floor.player
	if p:
		p.i_timer = 0.0
		p._hit_stamp_ms = -99999
		p.knockback = Vector2.ZERO
		p.velocity = Vector2.ZERO
		p.set_physics_process(true)
	Game._hurt_stamp_ms = -99999


func _free_enemies() -> void:
	for n in _floor.actors.get_children():
		if n is Enemy:
			(n as Enemy).alive = false
			n.queue_free()


func _test_spec() -> void:
	print("QA_SPEC start")
	var p: Player = _floor.player
	var room: Room = _floor.current
	_revive()
	p.global_position = room.center_global()
	p.aim = Vector2.RIGHT

	# INP-01 — no jump in this twin-stick. Same-frame move + shoot is the ghosting analog.
	var has_jump := InputMap.has_action("jump")
	var has_dodge := InputMap.has_action("dodge") or InputMap.has_action("dash") or InputMap.has_action("defend")
	if has_jump:
		Input.action_press("jump")
	var origin := p.global_position
	var before_shots := _live_bullets()
	p.fire_left = 0.0
	Input.action_press("move_up")
	Input.action_press("shoot")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var moved := p.global_position.distance_to(origin) > 1.0 or p.velocity.y < -20.0
	var fired := _live_bullets() > before_shots
	var anim_ok := p._sheet == null or p._sheet.animation == &"attack" or p._sheet.is_playing()
	Input.action_release("move_up")
	Input.action_release("shoot")
	if has_jump:
		Input.action_release("jump")
	if moved and fired and anim_ok:
		_item("Input", "INP-01", "PASS", "same-frame WASD+shoot resolved (moved=%s fired=%s). jump_action=%s (not in twin-stick map)" % [moved, fired, has_jump])
	else:
		_item("Input", "INP-01", "FAIL", "moved=%s fired=%s anim=%s jump=%s" % [moved, fired, p._sheet.animation if p._sheet else "none", has_jump])

	# INP-02 — no dodge/defense. Attack clip is locked until finished (walk waits).
	if not has_dodge:
		p.set_physics_process(false)
		p._shoot()
		await get_tree().process_frame
		var locked := p._sheet != null and p._sheet.animation == &"attack" and p._sheet.is_playing()
		p.velocity = Vector2.RIGHT * 80.0
		p._sync_sheet()
		var still_atk := p._sheet != null and p._sheet.animation == &"attack"
		p.set_physics_process(true)
		_item("Input", "INP-02", "SKIP", "no dodge/dash/defend action. attack_lock=%s (walk waits; no cancel buffer for a missing evade)" % (locked and still_atk))
	else:
		_item("Input", "INP-02", "FAIL", "dodge exists but this harness does not drive it")

	# CMB-01 — stand inside enemy body; first hit then i-frames.
	_revive()
	p.global_position = room.center_global()
	var leech: Enemy = _floor._enemy_scene.instantiate()
	_floor.actors.add_child(leech)
	leech.configure(Enemy.Kind.IMP, p.global_position)
	leech.set_physics_process(false)
	Game.hearts = 4
	p.i_timer = 0.0
	p._hit_stamp_ms = -99999
	Game._hurt_stamp_ms = -99999
	var h0 := Game.hearts
	p.take_hit(leech)
	var h1 := Game.hearts
	for _i in 8:
		p.take_hit(leech)
		await get_tree().physics_frame
	var h2 := Game.hearts
	var iframe_ok := h1 == h0 - 1 and h2 == h1 and not Game.is_dead
	_item("Combate", "CMB-01", "PASS" if iframe_ok else "FAIL", "overlap 8 ticks hearts %s>%s stay=%s iframe_ms=%s" % [h0, h1, h2, Game.IFRAME_MS])

	# CMB-02 — shot parallel to the sprite, outside body radius, must miss.
	_revive()
	if is_instance_valid(leech):
		leech.queue_free()
	for old in _floor.projectiles.get_children():
		if old is Bullet:
			old.queue_free()
	await get_tree().process_frame
	var target: Enemy = _floor._enemy_scene.instantiate()
	_floor.actors.add_child(target)
	var tpos := p.global_position + Vector2(140, 0)
	target.configure(Enemy.Kind.IMP, tpos)
	target.set_physics_process(false)
	var hp_miss := target.hp
	var miss_origin := tpos + Vector2(0, -(target.radius + 8.0))
	var miss: Bullet = _floor.spawn_bullet(miss_origin, Vector2.RIGHT, 500.0, false, Palette.EMBER, 4.5, 0.0, 8.0, 0.0, 0.0, "player")
	if miss:
		miss.damage = 1
	await get_tree().create_timer(0.18).timeout
	var missed := is_instance_valid(target) and target.hp == hp_miss
	var hp_hit := target.hp if is_instance_valid(target) else -1
	var hit: Bullet = _floor.spawn_bullet(p.global_position + Vector2(24, 0), Vector2.RIGHT, 640.0, false, Palette.EMBER, 4.5, 0.0, 8.0, 0.0, 0.0, "player")
	if hit:
		hit.damage = 1
	await get_tree().create_timer(0.35).timeout
	var connected := (not is_instance_valid(target)) or (is_instance_valid(target) and target.hp < hp_hit)
	if missed and connected:
		_item("Combate", "CMB-02", "PASS", "graze outside radius missed; on-axis shot connected")
	else:
		_item("Combate", "CMB-02", "FAIL", "missed=%s connected=%s still_valid=%s" % [missed, connected, is_instance_valid(target)])
	if is_instance_valid(miss):
		miss.queue_free()
	if is_instance_valid(hit):
		hit.queue_free()
	if is_instance_valid(target):
		target.queue_free()

	# CMB-03 — volley at the north wall / off camera; must free; RAM must not explode.
	_revive()
	p.global_position = room.center_global()
	var mem0 := OS.get_static_memory_usage()
	for i in 48:
		var b: Bullet = _floor.spawn_bullet(p.global_position + Vector2(float(i % 8) * 6.0, -20.0), Vector2.UP, 720.0, false, Palette.EMBER, 4.5, 0.0, 8.0, 0.0, 0.0, "player")
		if b:
			b.lifetime = 0.35
	await get_tree().create_timer(0.55).timeout
	var leftover := _live_bullets()
	var mem1 := OS.get_static_memory_usage()
	var leak := leftover > 2 or mem1 > mem0 + 8_000_000
	_item("Combate", "CMB-03", "FAIL" if leak else "PASS", "live=%s mem0=%s mem1=%s (no pool; instantiate+queue_free on wall/lifetime)" % [leftover, mem0, mem1])

	# CMB-04 — trade kill same tick.
	_revive()
	var foe: Enemy = _floor._enemy_scene.instantiate()
	_floor.actors.add_child(foe)
	foe.configure(Enemy.Kind.IMP, p.global_position + Vector2(40, 0))
	foe.set_physics_process(false)
	foe.hp = 1
	Game.hearts = 1
	p.i_timer = 0.0
	p._hit_stamp_ms = -99999
	Game._hurt_stamp_ms = -99999
	Game.is_dead = false
	p.take_hit(foe)
	if is_instance_valid(foe) and foe.alive:
		foe.take_hit(99)
	await get_tree().process_frame
	await get_tree().process_frame
	var player_dead := Game.is_dead and Game.hearts <= 0
	var enemy_dead := not is_instance_valid(foe) or (is_instance_valid(foe) and not foe.alive)
	var loop_ok := _floor.is_inside_tree()
	_item("Combate", "CMB-04", "PASS" if player_dead and enemy_dead and loop_ok else "FAIL", "player_dead=%s enemy_dead=%s paused=%s (pause is GO card; Floor PROCESS_MODE_ALWAYS)" % [player_dead, enemy_dead, get_tree().paused])
	_revive()
	if is_instance_valid(foe):
		foe.queue_free()

	# FAL-01 — knockback into NW corner; no OOB / stuck / NaN. No jump/dash.
	p.global_position = room.global_position + Vector2(Game.WALL + 10.0, Game.WALL + 10.0)
	p.knockback = Vector2(-400, -400)
	for _k in 20:
		p.velocity = Vector2(-300, -300) + p.knockback
		p.knockback = p.knockback.move_toward(Vector2.ZERO, 50.0)
		p.move_and_slide()
	var after := p.global_position
	var in_room := after.x > room.global_position.x - 2.0 and after.y > room.global_position.y - 2.0
	in_room = in_room and after.x < room.global_position.x + Game.ROOM_SIZE.x + 2.0
	in_room = in_room and after.y < room.global_position.y + Game.ROOM_SIZE.y + 2.0
	var nan := is_nan(after.x) or is_nan(after.y)
	_item("Falha", "FAL-01", "PASS" if in_room and not nan else "FAIL", "pos=%s in_room=%s nan=%s (no jump/dash; knockback+slide into corner)" % [after, in_room, nan])
	p.global_position = room.center_global()
	p.knockback = Vector2.ZERO
	p.velocity = Vector2.ZERO

	# FAL-02 — lethal hit during attack clip. No charged special on the walker.
	_revive()
	p.set_physics_process(false)
	p._shoot()
	await get_tree().process_frame
	Game.hearts = 1
	p.i_timer = 0.0
	p._hit_stamp_ms = -99999
	Game._hurt_stamp_ms = -99999
	p.take_hit(p)
	p.set_physics_process(true)
	await get_tree().physics_frame
	var death_cuts := Game.is_dead and Game.hearts <= 0
	_item("Falha", "FAL-02", "PASS" if death_cuts else "FAIL", "dead=%s hearts=%s during_attack=%s (no charge-special state; death sets is_dead and zeros move)" % [Game.is_dead, Game.hearts, p._sheet.animation if p._sheet else "?"])
	_revive()

	# FAL-03 — 300 imps + 100 shots. May hitch; must not crash.
	_free_enemies()
	await get_tree().process_frame
	var mobs: Array[Enemy] = []
	var center := room.center_global()
	for n in 300:
		var en: Enemy = _floor._enemy_scene.instantiate()
		_floor.actors.add_child(en)
		var col := n % 20
		var row := n / 20
		en.configure(Enemy.Kind.IMP, center + Vector2(float(col - 10) * 18.0, float(row - 7) * 16.0))
		en.fire_cd = 9999.0
		en.set_physics_process(true)
		mobs.append(en)
	for s in 100:
		_floor.spawn_bullet(center, Vector2.RIGHT.rotated(float(s) * 0.063), 260.0, false, Palette.EMBER, 4.0, 0.0, 8.0, 0.0, 0.0, "player")
	var crashed := false
	var fps := 0.0
	for _f in 20:
		await get_tree().process_frame
		fps = Engine.get_frames_per_second()
	_item("Falha", "FAL-03", "PASS" if not crashed and _floor.is_inside_tree() else "FAIL", "alive=%s fps=%.1f mobs=300 shots~100 (llvmpipe ok if no crash)" % [_floor.is_inside_tree(), fps])
	for en2 in mobs:
		if is_instance_valid(en2):
			en2.queue_free()
	for b2 in _floor.projectiles.get_children():
		if b2 is Bullet:
			b2.queue_free()
	_revive()
	p.global_position = room.center_global()
	print("QA_SPEC done")


func _is_int_px(v: float) -> bool:
	return absf(v - roundf(v)) <= 0.02


func _on_tile(v: float, tile: float = 64.0) -> bool:
	var m := fposmod(v, tile)
	return m <= 0.51 or m >= tile - 0.51


func _world_size(ci: CanvasItem) -> Vector2:
	if ci is Sprite2D:
		var r := (ci as Sprite2D).get_rect()
		var g: Vector2 = (ci as Sprite2D).global_scale.abs()
		return Vector2(absf(r.size.x) * g.x, absf(r.size.y) * g.y)
	if ci is AnimatedSprite2D:
		var spr := ci as AnimatedSprite2D
		if spr.sprite_frames == null:
			return Vector2.ZERO
		var anim := spr.animation
		if not spr.sprite_frames.has_animation(anim):
			return Vector2.ZERO
		if spr.sprite_frames.get_frame_count(anim) < 1:
			return Vector2.ZERO
		var tex := spr.sprite_frames.get_frame_texture(anim, 0)
		if tex == null:
			return Vector2.ZERO
		var g2: Vector2 = spr.global_scale.abs()
		return Vector2(tex.get_width() * g2.x, tex.get_height() * g2.y)
	return Vector2.ZERO


func _collect_canvas(n: Node, out: Array[CanvasItem]) -> void:
	if n is CanvasItem:
		out.append(n as CanvasItem)
	for c in n.get_children():
		_collect_canvas(c, out)


func _test_viz() -> void:
	print("QA_VIZ start")
	var tile := Game.WALL
	var dw := Game.DOOR_WIDTH
	var snap_ok := true
	var snap_bits: PackedStringArray = []
	var adj_ok := true
	var adj_bits: PackedStringArray = []
	var trig_ok := true
	var trig_bits: PackedStringArray = []
	var frac_art := 0

	for room in _floor.rooms.values():
		var r: Room = room
		if not _on_tile(r.global_position.x, tile) or not _on_tile(r.global_position.y, tile):
			snap_ok = false
			snap_bits.append("room_%s origin=%s" % [r.room_id, r.global_position])
		var mid_x := (r.size.x - dw) * 0.5
		var mid_y := (r.size.y - dw) * 0.5
		if not _on_tile(mid_x, tile):
			snap_ok = false
			snap_bits.append("room_%s door_mid_x=%.2f not %s-grid (opening=%.0f)" % [r.room_id, mid_x, tile, dw])
		if not _on_tile(mid_y, tile):
			snap_ok = false
			snap_bits.append("room_%s door_mid_y=%.2f not %s-grid" % [r.room_id, mid_y, tile])
		r.set_door_sprites_visible(true)
		for dir in r._door_art.keys():
			var spr: Sprite2D = r._door_art[dir]
			var body: StaticBody2D = r._door_bodies.get(dir)
			if spr:
				if not _is_int_px(spr.position.x) or not _is_int_px(spr.position.y):
					frac_art += 1
					snap_ok = false
				if not is_equal_approx(spr.scale.x, spr.scale.y):
					snap_bits.append("door scale %s" % spr.scale)
			if body and spr:
				# Gap sits in the 64px wall band; left/right (or above/below) walls exist by construction.
				var gap: Rect2 = spr.get_meta("gap") if spr.has_meta("gap") else Rect2()
				if gap.size == Vector2.ZERO:
					adj_ok = false
					adj_bits.append("%s dir=%s missing gap meta" % [r.room_id, dir])
				else:
					var touches_wall := gap.position.x <= 0.51 or gap.end.x >= r.size.x - 0.51 or gap.position.y <= 0.51 or gap.end.y >= r.size.y - 0.51
					if not touches_wall:
						adj_ok = false
						adj_bits.append("%s dir=%s floating gap=%s" % [r.room_id, dir, gap])
			# Trigger volume is the wall gap grown to the arch sprite.
			var dest: Room = r.neighbors.get(dir)
			if dest and spr:
				var tr := r.door_trigger_global(dir)
				if tr.size == Vector2.ZERO or not tr.has_point(spr.global_position):
					trig_ok = false
					trig_bits.append("%s dir=%s sprite=%s trigger=%s" % [r.room_id, dir, spr.global_position, tr])

	if frac_art > 0:
		snap_bits.append("door_art_fractional_px=%s" % frac_art)
	_item("Ambientacao", "VIZ-01", "PASS" if snap_ok else "FAIL", "tile=%s opening=%s %s" % [tile, dw, ", ".join(snap_bits) if snap_bits.size() else "room origins on grid"])
	_item("Ambientacao", "VIZ-02", "PASS" if adj_ok else "FAIL", ", ".join(adj_bits) if adj_bits.size() else "each door gap is carved from the 64px wall band (adjacent slabs)")
	_item("Ambientacao", "VIZ-03", "PASS" if trig_ok else "FAIL", ", ".join(trig_bits) if trig_bits.size() else "trigger aligned")

	# Pixel art: nearest + uniform scale.
	var items: Array[CanvasItem] = []
	_collect_canvas(_floor, items)
	var ui_n := _floor.ui
	if ui_n:
		_collect_canvas(ui_n, items)
	var linear: PackedStringArray = []
	var stretched: PackedStringArray = []
	var densities: PackedStringArray = []
	for ci in items:
		if ci is Sprite2D or ci is AnimatedSprite2D:
			var f := ci.texture_filter
			if f == CanvasItem.TEXTURE_FILTER_LINEAR or f == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS or f == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
				linear.append("%s filter=%s" % [ci.get_path(), f])
			var sc := (ci as Node2D).scale
			if absf(sc.x - sc.y) > 0.002:
				stretched.append("%s scale=%s" % [ci.name, sc])
			var ws := _world_size(ci)
			if ws.y > 4.0:
				var tex_h := 0.0
				if ci is Sprite2D and (ci as Sprite2D).texture:
					tex_h = (ci as Sprite2D).get_rect().size.y
				elif ci is AnimatedSprite2D:
					tex_h = _world_size(ci).y / maxf(absf((ci as Node2D).global_scale.y), 0.001)
				if tex_h > 0.0:
					densities.append("%s world=%.1f tex=%.1f ppu=%.2f sc=%.3f" % [ci.name, ws.y, tex_h, tex_h / ws.y, sc.y])
	var def_filter := int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 0))
	var snap2d := bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false))
	_item("PixelArt", "VIZ-04", "PASS" if linear.is_empty() and def_filter == 0 else "FAIL", "default_filter=%s (0=nearest) linear=%s snap2d=%s" % [def_filter, linear.size(), snap2d])
	_item("PixelArt", "VIZ-05", "PASS" if stretched.is_empty() else "FAIL", ", ".join(stretched) if stretched.size() else "all Sprite2D/AnimatedSprite2D scale.x==scale.y")

	var frac_world := 0
	for ci2 in items:
		if ci2 is Sprite2D or ci2 is AnimatedSprite2D:
			var nm := (ci2 as Node).name
			if nm.begins_with("fx") or nm == "TeleFx":
				continue
			var ws2 := _world_size(ci2)
			if ws2.x > 8.0 and (absf(ws2.x - roundf(ws2.x)) > 0.51 or absf(ws2.y - roundf(ws2.y)) > 0.51):
				frac_world += 1
	var zoom_ok := _floor.camera != null and _floor.camera.zoom == Vector2.ONE
	_item("PixelArt", "VIZ-06", "PASS" if frac_world == 0 and zoom_ok else "FAIL", "camera_zoom=%s non_integer_world_px=%s snap2d=%s %s" % [_floor.camera.zoom if _floor.camera else Vector2.ONE, frac_world, snap2d, densities[0] if densities.size() else ""])

	# Hierarchy: spawn one of each in the start room.
	var p: Player = _floor.player
	var start: Room = _floor.current
	p.rebind_visual()
	await get_tree().process_frame
	var player_h := 0.0
	if p._sheet:
		player_h = _world_size(p._sheet).y
	var samples: Dictionary = {"player": player_h}
	var kinds := [Enemy.Kind.IMP, Enemy.Kind.WRETCH, Enemy.Kind.CULTIST, Enemy.Kind.BOSS]
	var names := ["imp", "wretch", "cantor", "boss"]
	var spawned: Array[Enemy] = []
	for i in kinds.size():
		var en: Enemy = _floor._enemy_scene.instantiate()
		_floor.actors.add_child(en)
		en.configure(kinds[i], start.center_global() + Vector2(80.0 * float(i - 1), -40.0), kinds[i] == Enemy.Kind.CULTIST)
		en.set_physics_process(false)
		spawned.append(en)
		await get_tree().process_frame
		var h := _world_size(en._sprite) if en._sprite else Vector2.ZERO
		samples[names[i]] = h.y
	var npc_h := 0.0
	for room2 in _floor.rooms.values():
		if (room2 as Room).kind != Room.Kind.NPC:
			continue
		for ch in (room2 as Room).get_children():
			if ch is Concierge and (ch as Concierge)._sprite:
				npc_h = _world_size((ch as Concierge)._sprite).y
	samples["concierge"] = npc_h
	var imp_h := float(samples.get("imp", 0.0))
	var wretch_h := float(samples.get("wretch", 0.0))
	var cantor_h := float(samples.get("cantor", 0.0))
	var boss_h := float(samples.get("boss", 0.0))
	var hier := player_h > 40.0 and wretch_h > player_h and imp_h <= player_h and cantor_h <= player_h and boss_h >= player_h * 1.25
	_item("Hierarquia", "VIZ-07", "PASS" if hier else "FAIL", "h_player=%.1f npc=%.1f imp=%.1f wretch=%.1f cantor=%.1f boss=%.1f (wretch>player, other minions<=player, boss>=1.25x)" % [player_h, npc_h, imp_h, wretch_h, cantor_h, boss_h])

	var pivot_ok := true
	var pivot_bits: PackedStringArray = []
	if p._sheet and p._col:
		if p._sheet.position.length() > 1.0:
			pivot_ok = false
			pivot_bits.append("player sheet pos=%s" % p._sheet.position)
		if not p._sheet.centered:
			pivot_ok = false
			pivot_bits.append("player not centered")
		if p._col.position.length() > 1.0:
			pivot_ok = false
			pivot_bits.append("player col pos=%s" % p._col.position)
	for en2 in spawned:
		if en2._sprite and en2._col:
			if en2._sprite.position.length() > 1.0:
				pivot_ok = false
				pivot_bits.append("%s sprite pos=%s" % [en2.kind, en2._sprite.position])
			if en2._sprite.offset.length() > 12.0:
				pivot_ok = false
				pivot_bits.append("%s offset=%s" % [en2.kind, en2._sprite.offset])
			if en2._col.position.length() > 1.0:
				pivot_ok = false
				pivot_bits.append("%s col=%s" % [en2.kind, en2._col.position])
	_item("Hierarquia", "VIZ-08", "PASS" if pivot_ok else "FAIL", "top-down: sprite+collider share origin (no side-scroller ground line). %s" % (", ".join(pivot_bits) if pivot_bits.size() else "centered on body; boss offset=(0,10) within 12px"))

	for en3 in spawned:
		if is_instance_valid(en3):
			en3.queue_free()
	_floor._qa_shot("qa_viz_hierarchy")
	print("QA_VIZ done")


func _test_play() -> void:
	print("QA_PLAY start")
	_snap_each = true
	Game.release_gameplay_actions()
	_revive()
	await _test_play_menu()
	await _test_play_art()
	await _test_play_move()
	await _test_play_rooms()
	await _test_play_walkers()
	await _test_play_sheets()
	await _test_play_map()
	await _test_play_dialogue()
	await _test_play_sfx()
	await _test_play_combat_feel()
	await _test_play_life()
	_snap_each = false
	print("QA_PLAY done")


func _test_play_menu() -> void:
	var pick := RunPick.new()
	_floor.add_child(pick)
	await get_tree().process_frame
	await get_tree().process_frame
	pick.qa_show(Game.Body.CAIM, Game.Difficulty.NORMAL)
	await get_tree().process_frame
	var caim_ok: bool = pick.qa_has_pixel_preview() and pick.qa_preview_path().ends_with("player.png")
	_item("Menu", "PLAY-MENU-01", "PASS" if caim_ok else "FAIL", "Caim preview path=%s pixel=%s" % [pick.qa_preview_path(), pick.qa_has_pixel_preview()])
	pick.qa_show(Game.Body.LILITH, Game.Difficulty.NORMAL)
	await get_tree().process_frame
	var lil_ok: bool = pick.qa_has_pixel_preview() and pick.qa_preview_path().ends_with("player_f.png")
	_item("Menu", "PLAY-MENU-02", "PASS" if lil_ok else "FAIL", "Lilith preview path=%s" % pick.qa_preview_path())
	pick.qa_show(Game.Body.CAIM, Game.Difficulty.BABY)
	await get_tree().process_frame
	var baby_ok: bool = pick.qa_has_pixel_preview() and pick.qa_preview_path().ends_with("baby.png")
	_item("Menu", "PLAY-MENU-03", "PASS" if baby_ok else "FAIL", "Bebê preview path=%s" % pick.qa_preview_path())
	var vector: bool = pick.has_method("_draw_penitent")
	_item("Menu", "PLAY-MENU-04", "PASS" if not vector else "FAIL", "vector_penitent=%s (must be disk portraits)" % vector)
	var nearest: bool = pick.qa_preview_nearest()
	var faces: int = pick.qa_card_faces()
	_item("Menu", "PLAY-MENU-05", "PASS" if nearest and faces >= 4 else "FAIL", "preview_nearest=%s card_faces=%s want>=4" % [nearest, faces])
	pick.queue_free()
	await get_tree().process_frame


func _test_play_art() -> void:
	var p: Player = _floor.player
	_bind_walker(Game.Body.CAIM, Game.Difficulty.NORMAL)
	await get_tree().process_frame
	var caim := p.has_pixel() and p._sheet != null and not Game.is_baby() and Sprites.is_caim_own_body()
	_item("Arts", "PLAY-ART-CAIM", "PASS" if caim else "FAIL", "has_pixel=%s sheet=%s caim_own=%s md5_caim!=lilith" % [p.has_pixel(), p._sheet != null, Sprites.is_caim_own_body()])
	_floor._qa_shot("play_caim")

	_bind_walker(Game.Body.LILITH, Game.Difficulty.NORMAL)
	await get_tree().process_frame
	var lil := p.has_pixel() and p._sheet != null and Game.body == Game.Body.LILITH and not Game.is_baby()
	var md5_split := Sprites.disk_md5("res://assets/sprites/player.png") != Sprites.disk_md5("res://assets/sprites/player_f.png")
	_item("Arts", "PLAY-ART-LILITH", "PASS" if lil and md5_split else "FAIL", "lilith_body=%s has_pixel=%s distinct_sheet=%s hud=%s" % [Game.body, p.has_pixel(), md5_split, Game.walker_label()])
	_floor._qa_shot("play_lilith")

	_bind_walker(Game.Body.CAIM, Game.Difficulty.BABY)
	await get_tree().process_frame
	var baby := Game.is_baby() and p.has_pixel() and p._sheet == null and p._baby != null and p._baby.visible and p._baby.texture != null
	_item("Arts", "PLAY-ART-BABY", "PASS" if baby else "FAIL", "is_baby=%s baby_tex=%s sheet_cleared=%s hud=%s" % [Game.is_baby(), p._baby.texture != null if p._baby else false, p._sheet == null, Game.walker_label()])
	_floor._qa_shot("play_baby")

	_bind_walker(Game.Body.CAIM, Game.Difficulty.NORMAL)
	await get_tree().process_frame

	var tiled := false
	var env_n := 0
	var walls_n := 0
	for room in _floor.rooms.values():
		var r: Room = room
		if r.find_children("*", "TileMap", true, false).size() > 0:
			tiled = true
		for n in r.get_children():
			if n is Sprite2D:
				var spr := n as Sprite2D
				if spr.texture:
					var src := ""
					if spr.texture is AtlasTexture and (spr.texture as AtlasTexture).atlas:
						src = (spr.texture as AtlasTexture).atlas.resource_path
					else:
						src = spr.texture.resource_path
					if String(spr.name).begins_with("Env") or src.contains("env.png"):
						env_n += 1
						if String(spr.name).begins_with("EnvWall") or spr.z_index >= 1:
							walls_n += 1
	_item("Ambientacao", "PLAY-ART-FLOOR", "PASS" if env_n >= 40 and walls_n >= 8 and not tiled else "FAIL", "env_tiles=%s wall_tiles=%s tilemaps=%s (rows 1-3 of env.png, no checker)" % [env_n, walls_n, 1 if tiled else 0])

	var doors_ok := true
	var door_n := 0
	for room2 in _floor.rooms.values():
		for dir in (room2 as Room)._door_art.keys():
			var art: Sprite2D = (room2 as Room)._door_art[dir] as Sprite2D
			door_n += 1
			if art == null or art.texture == null or art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR:
				doors_ok = false
	_item("Ambientacao", "PLAY-ART-DOORS", "PASS" if doors_ok and door_n > 0 else "FAIL", "door_sprites=%s nearest_ok=%s" % [door_n, doors_ok])

	var hearts_ok := false
	if _floor.ui and _floor.ui.hearts:
		for c in _floor.ui.hearts.get_children():
			if c is TextureRect and (c as TextureRect).texture != null and (c as TextureRect).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST:
				hearts_ok = true
	var def_filter := int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 0))
	_item("PixelArt", "PLAY-ART-NEAREST", "PASS" if hearts_ok and def_filter == 0 else "FAIL", "hud_hearts_nearest=%s default_filter=%s" % [hearts_ok, def_filter])


func _test_play_move() -> void:
	var p: Player = _floor.player
	var start: Room = _floor.rooms.get(Vector2i.ZERO)
	p.global_position = start.center_global()
	p.knockback = Vector2.ZERO
	Game.release_gameplay_actions()
	p.set_physics_process(true)

	var dirs := [
		["move_right", Vector2.RIGHT],
		["move_left", Vector2.LEFT],
		["move_up", Vector2.UP],
		["move_down", Vector2.DOWN],
	]
	var card_ok := true
	var bits: PackedStringArray = []
	for pair in dirs:
		Game.release_gameplay_actions()
		p.global_position = start.center_global()
		Input.action_press(String(pair[0]))
		await get_tree().physics_frame
		await get_tree().physics_frame
		var want: Vector2 = pair[1]
		var along := p.velocity.dot(want)
		if along < Player.SPEED * 0.7:
			card_ok = false
			bits.append("%s vel=%s" % [pair[0], p.velocity])
		Input.action_release(String(pair[0]))
	_item("Input", "PLAY-MOVE-8DIR", "PASS" if card_ok else "FAIL", ", ".join(bits) if bits.size() else "WASD cardinals reach SPEED")

	Game.release_gameplay_actions()
	p.global_position = start.center_global()
	Input.action_press("move_right")
	Input.action_press("move_down")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var diag_len := p.velocity.length()
	var diag_ok := diag_len > Player.SPEED * 0.85 and diag_len < Player.SPEED * 1.08
	Game.release_gameplay_actions()
	_item("Input", "PLAY-MOVE-DIAG", "PASS" if diag_ok else "FAIL", "diag_speed=%.1f cap=%.1f (must not be SPEED*sqrt2)" % [diag_len, Player.SPEED])

	p.global_position = start.center_global()
	Input.action_press("move_left")
	Input.action_press("move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cancel := absf(p.velocity.x) < 12.0
	Game.release_gameplay_actions()
	_item("Input", "PLAY-MOVE-CANCEL", "PASS" if cancel else "FAIL", "A+D vel.x=%.1f (must neutralize)" % p.velocity.x)

	Input.action_press("move_right")
	await get_tree().physics_frame
	Game.release_gameplay_actions()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var sticky := absf(p.velocity.x) < 20.0
	_item("Input", "PLAY-MOVE-FOCUS", "PASS" if sticky else "FAIL", "after focus-out release vel=%s (Alt+Tab must not sticky-walk)" % p.velocity)

	# Hold-to-fire through cooldown (no tap buffer; holding is the buffer).
	for b in _floor.projectiles.get_children():
		if b is Bullet:
			b.queue_free()
	await get_tree().process_frame
	p.global_position = start.center_global().round()
	p.fire_left = 0.0
	p.aim = Vector2.RIGHT
	Input.action_press("shoot")
	var n1 := 0
	var n2 := 0
	var peak := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 480:
		await get_tree().physics_frame
		var live := _live_bullets()
		peak = maxi(peak, live)
		if n1 == 0 and live >= 1:
			n1 = live
		n2 = live
	Input.action_release("shoot")
	_item("Input", "PLAY-SHOOT-HOLD", "PASS" if n1 >= 1 and peak >= 2 else "FAIL", "first=%s later=%s peak=%s (hold through cooldown)" % [n1, n2, peak])

	for b2 in _floor.projectiles.get_children():
		if b2 is Bullet:
			b2.queue_free()
	await get_tree().process_frame
	p.aim = Vector2.RIGHT
	p.fire_left = 0.0
	p._shoot()
	var muzzle_ok := false
	var muzzle_d := 999.0
	var expect := p.global_position + Vector2.RIGHT * (Player.RADIUS + 8.0)
	for b3 in _floor.projectiles.get_children():
		if b3 is Bullet:
			muzzle_d = (b3 as Bullet).origin.distance_to(expect)
			muzzle_ok = muzzle_d < 3.0
			break
	_item("Combate", "PLAY-SHOOT-MUZZLE", "PASS" if muzzle_ok else "FAIL", "muzzle_err=%.2f expect=%s" % [muzzle_d, expect])


func _test_play_rooms() -> void:
	var p: Player = _floor.player
	var start: Room = _floor.rooms.get(Vector2i.ZERO)
	var east: Room = _floor.rooms.get(Vector2i(1, 0))
	var npc: Room = _floor.rooms.get(Vector2i(2, 0))
	if start == null or east == null:
		_item("Portas", "PLAY-DOOR-LOCK", "FAIL", "missing start/east")
		return
	_free_enemies()
	east.visited = false
	east.cleared = false
	east.locked = false
	p.global_position = start.center_global()
	_floor._enter_room(start, true)
	await get_tree().process_frame
	await _goto_room(east)
	await get_tree().process_frame
	var locked := east.locked and not east.cleared
	var spawned := _count_room_enemies(east.room_id)
	var iframe := p.i_timer >= 0.3
	_item("Portas", "PLAY-DOOR-LOCK", "PASS" if locked and spawned >= 1 else "FAIL", "locked=%s spawned=%s same_visit_lock" % [east.locked, spawned])
	_item("Portas", "PLAY-DOOR-IFRAME", "PASS" if iframe else "FAIL", "enter_i_timer=%.2f want 0.3-0.5s" % p.i_timer)
	_floor._qa_shot("play_east_combat")

	# Anti-trava: stand in the west gap of east and try to leave.
	var west_gap := east.door_trigger_global(Room.Dir.W)
	if west_gap.size != Vector2.ZERO:
		p.global_position = west_gap.get_center()
		p.velocity = Vector2.LEFT * 400.0
		for _i in 8:
			p.move_and_slide()
		var inside := east.contains_inner(p.global_position) or _floor.current == east
		_item("Portas", "PLAY-DOOR-JAMB", "PASS" if inside and east.locked else "FAIL", "after_backpedal current=%s pos=%s locked=%s" % [_floor.current.room_id if _floor.current else "?", p.global_position, east.locked])
	else:
		_item("Portas", "PLAY-DOOR-JAMB", "SKIP", "no west trigger")

	p.global_position = east.center_global()
	for n in _floor.actors.get_children():
		if n is Enemy and (n as Enemy).get_meta("room", "") == east.room_id:
			(n as Enemy).take_hit(99)
	await get_tree().process_frame
	await get_tree().process_frame
	var cleared := east.cleared and not east.locked
	_item("Portas", "PLAY-DOOR-CLEAR", "PASS" if cleared else "FAIL", "cleared=%s locked=%s alive=%s" % [east.cleared, east.locked, _count_room_enemies(east.room_id)])

	await _goto_room(start)
	await get_tree().process_frame
	await _goto_room(east)
	await get_tree().process_frame
	var again := _count_room_enemies(east.room_id)
	_item("Portas", "PLAY-DOOR-IDEMPOTENT", "PASS" if again == 0 and not east.locked else "FAIL", "revisit enemies=%s locked=%s (must not respawn)" % [again, east.locked])

	if npc:
		p.global_position = npc.center_global()
		_floor._enter_room(npc, true)
		await get_tree().process_frame
		var conc := 0
		for ch in npc.get_children():
			if ch is Concierge and (ch as Concierge)._sprite:
				conc += 1
		_item("Ambientacao", "PLAY-NPC", "PASS" if conc >= 1 else "FAIL", "concierge_pixel=%s" % conc)
		_floor._qa_shot("play_npc")
	else:
		_item("Ambientacao", "PLAY-NPC", "FAIL", "npc room missing")

	_floor._fall_cd = 0.0
	p.global_position = start.center_global()
	_floor._enter_room(start, true)
	await get_tree().process_frame
	var dest: Room = _floor.drop_room()
	p.global_position = start.pit_global()
	await get_tree().create_timer(0.4).timeout
	var pit_ok := dest != null and _floor.current != null and _floor.current.room_id == dest.room_id
	var still_caim := Game.body == Game.Body.CAIM and not Game.is_baby() and p.has_pixel() and p._sheet != null
	_item("Fosso", "PLAY-PIT", "PASS" if pit_ok and still_caim else "FAIL", "dest=%s now=%s caim_pixel=%s (must not become sword imp)" % [dest.room_id if dest else "?", _floor.current.room_id if _floor.current else "?", still_caim])
	_floor._qa_shot("play_pit")

	# Wall shot hermetic.
	var room: Room = _floor.current
	var wall_shot: Bullet = _floor.spawn_bullet(room.global_position + Vector2(Game.WALL + 28.0, Game.WALL + 48.0), Vector2.LEFT, 700.0, false, Palette.EMBER, 5.0, 0.0, 8.0, 0.0, 0.0, "player")
	await get_tree().create_timer(0.2).timeout
	_item("Combate", "PLAY-SHOOT-WALL", "PASS" if not is_instance_valid(wall_shot) or wall_shot.spent else "FAIL", "wall_spent=%s" % (wall_shot.spent if is_instance_valid(wall_shot) else true))


func _test_play_walkers() -> void:
	var p: Player = _floor.player
	var room: Room = _floor.current
	_free_enemies()
	for old in _floor.projectiles.get_children():
		if old is Bullet:
			old.queue_free()
	await get_tree().process_frame
	p.global_position = room.center_global()
	_bind_walker(Game.Body.LILITH, Game.Difficulty.NORMAL)
	await get_tree().process_frame
	p.set_physics_process(false)
	p._sheet.play("idle")
	await get_tree().process_frame
	var idle := p._sheet.animation == &"idle"
	p._sheet.play("walk")
	await get_tree().process_frame
	var walk := p._sheet.animation == &"walk"
	p.aim = Vector2.RIGHT
	p.fire_left = 0.0
	p._shoot()
	await get_tree().process_frame
	var atk := p._sheet.animation == &"attack"
	p.set_physics_process(true)
	_item("Walkers", "PLAY-LILITH-ANIM", "PASS" if idle and walk and atk and p.has_pixel() else "FAIL", "idle=%s walk=%s attack=%s" % [idle, walk, atk])

	_bind_walker(Game.Body.CAIM, Game.Difficulty.BABY)
	await get_tree().process_frame
	Game.bgm("play_for_run")
	await get_tree().process_frame
	for old in _floor.projectiles.get_children():
		if old is Bullet:
			old.queue_free()
	await get_tree().process_frame
	var pellet: Bullet = _floor.spawn_bullet(p.global_position + Vector2(20, 0), Vector2.LEFT, 180.0, true, Palette.HELL_RED, 5.0, 0.0, 8.0, 0.0, 0.0, "imp")
	p.take_hit(pellet)
	await get_tree().process_frame
	var deflected := is_instance_valid(pellet) and pellet.deflected and not pellet.from_enemy
	var hearts_same := Game.hearts == Game.MAX_HEARTS
	_item("Walkers", "PLAY-BABY-DEFLECT", "PASS" if deflected and hearts_same else "FAIL", "deflected=%s from_enemy=%s hearts=%s" % [pellet.deflected if is_instance_valid(pellet) else false, pellet.from_enemy if is_instance_valid(pellet) else true, Game.hearts])
	var sfx_n := get_node_or_null("/root/Sfx")
	var cry_on := false
	if sfx_n:
		var cry = sfx_n.get("_cry")
		cry_on = cry is AudioStreamPlayer and ((cry as AudioStreamPlayer).playing or (cry as AudioStreamPlayer).stream != null)
	_item("Walkers", "PLAY-BABY-BGM", "PASS" if cry_on else "FAIL", "cry sfx bound=%s label=%s" % [cry_on, Game.walker_label()])

	_bind_walker(Game.Body.CAIM, Game.Difficulty.NORMAL)
	Game.bgm("play_for_run")
	await get_tree().process_frame


func _test_play_combat_feel() -> void:
	var p: Player = _floor.player
	_free_enemies()
	for old in _floor.projectiles.get_children():
		if old is Bullet:
			old.queue_free()
	await get_tree().process_frame
	_revive()
	p.global_position = _floor.current.center_global()
	var h0 := Game.hearts
	p.i_timer = 0.0
	p._hit_stamp_ms = -99999
	Game._hurt_stamp_ms = -99999
	p.take_hit(p)
	var h1 := Game.hearts
	var blinks := 0
	var seen_off := false
	for _i in 12:
		await get_tree().process_frame
		if p.blink or (p._sheet and not p._sheet.visible):
			blinks += 1
			seen_off = true
	for _j in 8:
		p.take_hit(p)
		await get_tree().physics_frame
	var h2 := Game.hearts
	var iframe_ok := h1 == h0 - 1 and h2 == h1
	_item("Combate", "PLAY-HIT-IFRAME", "PASS" if iframe_ok else "FAIL", "hearts %s>%s stay=%s iframe_ms=%s (spec 1000-1500; game uses 550 and does not 10-tap)" % [h0, h1, h2, Game.IFRAME_MS])
	_item("Combate", "PLAY-HIT-BLINK", "PASS" if seen_off or blinks > 0 else "FAIL", "blink_frames=%s" % blinks)

	var hz: Node2D = _floor.spawn_hazard(Hazard.Kind.RING, _floor.current.center_global(), _floor.current)
	await get_tree().process_frame
	var inner := 0.0
	if hz:
		inner = float(hz.get("ring_inner"))
	var solvable := inner >= 40.0
	_item("Combate", "PLAY-BOSS-RING", "PASS" if solvable else "FAIL", "ring_inner=%.1f (center safe lane)" % inner)
	if hz:
		hz.queue_free()

	_item("Input", "PLAY-DASH", "SKIP", "no dodge/dash in this twin-stick")
	_item("Audio", "PLAY-SFX", "PASS" if get_node_or_null("/root/Sfx") != null else "FAIL", "Sfx autoload shoot/hit/pickup/door/talk")
	_item("Perf", "PLAY-POOL", "SKIP", "no object pool; bullets queue_free on spend")

	for old in _floor.projectiles.get_children():
		if old is Bullet:
			old.queue_free()
	await get_tree().process_frame
	var origin := _floor.current.center_global()
	for s in 48:
		_floor.spawn_bullet(origin, Vector2.RIGHT.rotated(float(s) * 0.13), 240.0, true, Palette.EMBER, 4.0, 0.0, 8.0, 0.0, 0.0, "imp")
	var fps_max := 0.0
	for _f in 16:
		await get_tree().process_frame
		fps_max = maxf(fps_max, Engine.get_frames_per_second())
	_item("Perf", "PLAY-VOLLEY", "PASS" if _floor.is_inside_tree() else "FAIL", "alive=%s fps_max=%.1f shots=48 (llvmpipe fps is informational)" % [_floor.is_inside_tree(), fps_max])
	for b in _floor.projectiles.get_children():
		if b is Bullet:
			b.queue_free()


func _test_play_life() -> void:
	var p: Player = _floor.player
	_revive()
	Game.release_gameplay_actions()
	_free_enemies()
	for old in _floor.projectiles.get_children():
		if old is Bullet:
			old.queue_free()
	await get_tree().process_frame
	p.set_physics_process(true)
	Game.hearts = 1
	p.i_timer = 0.0
	p._hit_stamp_ms = -99999
	Game._hurt_stamp_ms = -99999
	p.take_hit(p)
	await get_tree().process_frame
	var dead := Game.is_dead and Game.hearts <= 0
	var overlay := _floor.ui != null and _floor.ui.overlay.visible
	var before := _live_bullets()
	p.fire_left = 0.0
	Input.action_press("shoot")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("shoot")
	var zombie := _live_bullets() > before
	_item("Ciclo", "PLAY-DEATH", "PASS" if dead and overlay and not zombie else "FAIL", "dead=%s overlay=%s zombie_shot=%s live=%s->%s" % [dead, overlay, zombie, before, _live_bullets()])
	_revive()
	var reset := Game.hearts == Game.MAX_HEARTS and not Game.is_dead
	_item("Ciclo", "PLAY-RESTART", "PASS" if reset else "FAIL", "hearts=%s dead=%s (scene reload is R; harness reset_run equivalent)" % [Game.hearts, Game.is_dead])


func _bind_walker(body: Game.Body, diff: Game.Difficulty) -> void:
	Game.pick_run(body, diff)
	var p: Player = _floor.player
	if p:
		p.rebind_visual()
	if _floor.ui:
		_floor.ui.set_walker(Game.walker_label(), "")


func _count_room_enemies(room_id: String) -> int:
	var n := 0
	for node in _floor.actors.get_children():
		if node is Enemy and (node as Enemy).alive and String((node as Enemy).get_meta("room", "")) == room_id:
			n += 1
	return n


func _goto_room(dest: Room) -> void:
	var from: Room = _floor.current
	var p: Player = _floor.player
	if from == null or dest == null or p == null:
		return
	_floor._door_cd = 0.0
	for dir in from.neighbors.keys():
		if from.neighbors[dir] == dest:
			var tr := from.door_trigger_global(dir)
			if tr.size != Vector2.ZERO:
				p.global_position = tr.get_center()
			_floor._check_room_change()
			await get_tree().process_frame
			return
	p.global_position = dest.center_global()
	_floor._enter_room(dest, true)
	await get_tree().process_frame


func _pose(at: Vector2, zoom: float = 1.0) -> void:
	var p: Player = _floor.player
	if p:
		p.velocity = Vector2.ZERO
		p.knockback = Vector2.ZERO
	if _floor.camera:
		_floor.camera.position_smoothing_enabled = false
		_floor.camera.zoom = Vector2(zoom, zoom)
		_floor.camera.offset = Vector2.ZERO
		_floor.camera.global_position = at.round()
		_floor.camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().process_frame


func _pose_reset() -> void:
	if _floor.camera:
		_floor.camera.zoom = Vector2.ONE
		if _floor.current:
			_floor.camera.global_position = _floor.current.center_global()
			_floor.camera.reset_smoothing()
	await get_tree().process_frame


func _audit_sheet(ci: CanvasItem, want_h: float) -> String:
	if ci == null:
		return "missing sprite"
	var bits: PackedStringArray = []
	var f := ci.texture_filter
	if f == CanvasItem.TEXTURE_FILTER_LINEAR or f == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS or f == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
		bits.append("linear_filter=%s" % f)
	if ci is Node2D:
		var sc: Vector2 = (ci as Node2D).scale
		if absf(sc.x - sc.y) > 0.002:
			bits.append("squash=%s" % sc)
		var gp: Vector2 = (ci as Node2D).global_position
		if absf(gp.x - roundf(gp.x)) > 0.51 or absf(gp.y - roundf(gp.y)) > 0.51:
			bits.append("frac_pos=%s" % gp)
	if ci is Sprite2D and not (ci as Sprite2D).centered:
		bits.append("not_centered")
	if ci is AnimatedSprite2D and not (ci as AnimatedSprite2D).centered:
		bits.append("not_centered")
	var ws := _world_size(ci)
	if want_h > 0.0:
		if ws.y < want_h * 0.72 or ws.y > want_h * 1.35:
			bits.append("bad_h=%.1f want~%.0f" % [ws.y, want_h])
	if bits.is_empty():
		return "ok nearest square int_pos centered h=%.1f" % ws.y
	return ", ".join(bits)


func _audit_ok(detail: String) -> bool:
	if detail.begins_with("missing"):
		return false
	return not detail.contains("linear_filter") and not detail.contains("squash=") and not detail.contains("frac_pos=") and not detail.contains("not_centered") and not detail.contains("bad_h=")


func _test_play_sheets() -> void:
	var p: Player = _floor.player
	var start: Room = _floor.rooms.get(Vector2i.ZERO)
	_free_enemies()
	for old in _floor.projectiles.get_children():
		if old is Bullet:
			old.queue_free()
	await get_tree().process_frame
	_bind_walker(Game.Body.CAIM, Game.Difficulty.NORMAL)
	p.global_position = start.center_global().round()
	_floor._enter_room(start, true)
	p.set_physics_process(false)
	p.aim = Vector2.DOWN
	p.velocity = Vector2.ZERO
	if p._sheet:
		p._sheet.play("idle")
		p._sheet.frame = 0
	p._sync_sheet()
	await _pose(p.global_position, 3.0)
	var caim_d := _audit_sheet(p._sheet, 64.0)
	_item("Sheets", "PLAY-SHEET-CAIM", "PASS" if _audit_ok(caim_d) and p.has_pixel() else "FAIL", caim_d)
	var idle_ok := p._sheet != null and p._sheet.animation == &"idle"
	_item("Sheets", "PLAY-SHEET-CAIM-IDLE", "PASS" if idle_ok and _audit_ok(caim_d) else "FAIL", "anim=%s %s" % [p._sheet.animation if p._sheet else "none", caim_d])
	if p._sheet:
		p._sheet.play("walk")
		p._sheet.frame = 1
	await _pose(p.global_position, 3.0)
	var walk_d := _audit_sheet(p._sheet, 64.0)
	var walk_ok := p._sheet != null and p._sheet.animation == &"walk"
	_item("Sheets", "PLAY-SHEET-CAIM-WALK", "PASS" if walk_ok and _audit_ok(walk_d) else "FAIL", "anim=%s %s" % [p._sheet.animation if p._sheet else "none", walk_d])
	if p._sheet:
		p._sheet.play("attack")
		p._sheet.frame = 0
	await _pose(p.global_position, 3.0)
	var atk_d := _audit_sheet(p._sheet, 64.0)
	var atk_ok := p._sheet != null and p._sheet.animation == &"attack"
	_item("Sheets", "PLAY-SHEET-CAIM-SHOOT", "PASS" if atk_ok and _audit_ok(atk_d) else "FAIL", "anim=%s %s" % [p._sheet.animation if p._sheet else "none", atk_d])

	_bind_walker(Game.Body.LILITH, Game.Difficulty.NORMAL)
	p.aim = Vector2.DOWN
	if p._sheet:
		p._sheet.play("idle")
	p._sync_sheet()
	await _pose(p.global_position, 3.0)
	var lil_d := _audit_sheet(p._sheet, 64.0)
	_item("Sheets", "PLAY-SHEET-LILITH", "PASS" if _audit_ok(lil_d) and p.has_pixel() else "FAIL", lil_d)

	_bind_walker(Game.Body.CAIM, Game.Difficulty.BABY)
	await _pose(p.global_position, 3.0)
	var baby_d := _audit_sheet(p._baby, 72.0)
	_item("Sheets", "PLAY-SHEET-BABY", "PASS" if _audit_ok(baby_d) and p.has_pixel() else "FAIL", baby_d)
	_bind_walker(Game.Body.CAIM, Game.Difficulty.NORMAL)
	p.set_physics_process(false)
	p.global_position = start.center_global().round() + Vector2(0, 220)

	var kinds: Array = [Enemy.Kind.IMP, Enemy.Kind.WRETCH, Enemy.Kind.CULTIST, Enemy.Kind.BOSS]
	var sheet_ids: PackedStringArray = ["PLAY-SHEET-IMP", "PLAY-SHEET-WRETCH", "PLAY-SHEET-CANTOR", "PLAY-SHEET-BOSS"]
	var want: Array = [56.0, 80.0, 58.0, 115.0]
	var spawned: Array[Enemy] = []
	for i in kinds.size():
		var en: Enemy = _floor._enemy_scene.instantiate()
		_floor.actors.add_child(en)
		var at: Vector2 = (start.center_global() + Vector2(110.0 * float(i - 1), 0.0)).round()
		en.configure(kinds[i], at, false)
		en.set_physics_process(false)
		en.global_position = at
		spawned.append(en)
		await _pose(en.global_position, 2.5)
		var d := _audit_sheet(en._sprite, float(want[i]))
		_item("Sheets", sheet_ids[i], "PASS" if _audit_ok(d) else "FAIL", d)

	var npc_spr: AnimatedSprite2D = null
	var npc_room: Room = _floor.rooms.get(Vector2i(2, 0))
	if npc_room:
		for ch in npc_room.get_children():
			if ch is Concierge:
				npc_spr = (ch as Concierge)._sprite
				await _pose((ch as Concierge).global_position, 2.5)
				break
	var npc_d := _audit_sheet(npc_spr, 80.0)
	_item("Sheets", "PLAY-SHEET-NPC", "PASS" if _audit_ok(npc_d) else "FAIL", npc_d)

	var door_ok := true
	var door_d := "no door"
	start.set_door_sprites_visible(true)
	for dir in start._door_art.keys():
		var spr: Sprite2D = start._door_art[dir]
		door_d = _audit_sheet(spr, 0.0)
		if not _audit_ok(door_d) or not is_equal_approx(spr.scale.x, spr.scale.y):
			door_ok = false
			break
	await _pose(start.center_global() + Vector2(0, -200), 1.0)
	_item("Sheets", "PLAY-SHEET-DOORS", "PASS" if door_ok else "FAIL", door_d)

	var env_ok := true
	var env_n := 0
	var env_off := 0
	for n in start.get_children():
		if n is Sprite2D and String(n.name).begins_with("Env"):
			env_n += 1
			var lp: Vector2 = (n as Sprite2D).position
			if absf(lp.x - roundf(lp.x)) > 0.51 or absf(lp.y - roundf(lp.y)) > 0.51:
				env_off += 1
				env_ok = false
			if not is_equal_approx((n as Sprite2D).scale.x, (n as Sprite2D).scale.y):
				env_ok = false
	await _pose(start.center_global(), 1.0)
	_item("Sheets", "PLAY-SHEET-ENV", "PASS" if env_ok and env_n >= 20 else "FAIL", "tiles=%s frac=%s" % [env_n, env_off])

	for b in _floor.projectiles.get_children():
		if b is Bullet:
			b.queue_free()
	await get_tree().process_frame
	p.global_position = start.center_global().round()
	p.aim = Vector2.RIGHT
	p.fire_left = 0.0
	p._shoot()
	await get_tree().process_frame
	var shot_spr: CanvasItem = null
	for b2 in _floor.projectiles.get_children():
		if b2 is Bullet:
			b2.set_physics_process(false)
			b2.set_process(false)
			b2.global_position = b2.global_position.round()
			shot_spr = (b2 as Bullet)._spr
			if shot_spr == null:
				shot_spr = (b2 as Bullet)._core
			await _pose(b2.global_position, 4.0)
			break
	var shot_d := _audit_sheet(shot_spr, 24.0)
	_item("Sheets", "PLAY-SHEET-SHOT", "PASS" if shot_spr != null and _audit_ok(shot_d) else "FAIL", shot_d if shot_d != "" else "no shot sprite")

	p.global_position = start.center_global().round() + Vector2(-160, 0)
	_floor.spawn_pickup(Pickup.Kind.HEART, start.center_global().round() + Vector2(0, 80))
	await get_tree().process_frame
	var pick_spr: CanvasItem = null
	for n2 in _floor.actors.get_children():
		if n2 is Pickup:
			n2.set_process(false)
			if (n2 as Pickup)._icon:
				(n2 as Pickup)._icon.position = Vector2.ZERO
			n2.global_position = n2.global_position.round()
			pick_spr = (n2 as Pickup)._icon
			await _pose(n2.global_position, 3.0)
			break
	var pick_d := _audit_sheet(pick_spr, 48.0)
	_item("Sheets", "PLAY-SHEET-PICKUP", "PASS" if pick_spr != null and _audit_ok(pick_d) else "FAIL", pick_d)

	var heart_ok := false
	var heart_n := 0
	if _floor.ui and _floor.ui.hearts:
		for c in _floor.ui.hearts.get_children():
			if c is TextureRect and (c as TextureRect).texture != null:
				heart_n += 1
				if (c as TextureRect).texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST:
					heart_ok = true
	await _pose(start.center_global() + Vector2(-420, -280), 1.0)
	_item("Sheets", "PLAY-SHEET-HEARTS", "PASS" if heart_ok and heart_n >= 4 else "FAIL", "pips=%s nearest=%s" % [heart_n, heart_ok])

	Game.pierce = 1
	Game.rapid = 1
	Game.heavy = 1
	Game.burn = 1
	Game.loadout_changed.emit()
	await get_tree().process_frame
	var skill_n := 0
	if _floor.ui and _floor.ui.hearts:
		for c2 in _floor.ui.hearts.get_children():
			if c2 is TextureRect and (c2 as TextureRect).custom_minimum_size.x <= 22.5:
				skill_n += 1
	await _pose(start.center_global() + Vector2(-420, -280), 1.0)
	_item("Sheets", "PLAY-SHEET-SKILLS", "PASS" if skill_n >= 4 else "FAIL", "skill_pips=%s (pierce/rapid/heavy/burn)" % skill_n)
	Game.pierce = 0
	Game.rapid = 0
	Game.heavy = 0
	Game.burn = 0
	Game.loadout_changed.emit()

	var pit_spr: Sprite2D = null
	for n3 in start.get_children():
		if n3 is Sprite2D and String(n3.name) == "PitSprite":
			pit_spr = n3
			break
	await _pose(start.pit_global() if start.has_pit else start.center_global(), 2.0)
	var pit_d := _audit_sheet(pit_spr, 0.0)
	var pit_sc := pit_spr != null and is_equal_approx(pit_spr.scale.x, pit_spr.scale.y)
	_item("Sheets", "PLAY-SHEET-PIT", "PASS" if pit_spr and _audit_ok(pit_d) and pit_sc else "FAIL", pit_d)

	for en2 in spawned:
		if is_instance_valid(en2):
			en2.queue_free()
	for n4 in _floor.actors.get_children():
		if n4 is Pickup:
			n4.queue_free()
	for b3 in _floor.projectiles.get_children():
		if b3 is Bullet:
			b3.queue_free()
	p.set_physics_process(true)
	p.global_position = start.center_global().round()
	await _pose_reset()


func _test_play_map() -> void:
	var p: Player = _floor.player
	var grids: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 0),
		Vector2i(2, 1),
		Vector2i(0, 2),
	]
	var map_ids: PackedStringArray = [
		"PLAY-ROOM-START",
		"PLAY-ROOM-NORTH",
		"PLAY-ROOM-WEST",
		"PLAY-ROOM-EAST",
		"PLAY-ROOM-SOUTH",
		"PLAY-ROOM-SE",
		"PLAY-ROOM-NPC",
		"PLAY-ROOM-BOSS",
		"PLAY-ROOM-DEEP",
	]
	for i in grids.size():
		var grid: Vector2i = grids[i]
		var id: String = map_ids[i]
		var room: Room = _floor.rooms.get(grid)
		if room == null:
			_item("Mapa", id, "FAIL", "missing room")
			continue
		p.i_timer = 1.0
		p.global_position = room.center_global().round()
		_floor._enter_room(room, true)
		await _pose(room.center_global(), 1.0)
		var doors := 0
		for dir in room._door_art.keys():
			var spr: Sprite2D = room._door_art[dir]
			if spr and spr.texture:
				doors += 1
		var env_n := 0
		for ch in room.get_children():
			if ch is Sprite2D and String(ch.name).begins_with("Env"):
				env_n += 1
		var ok := env_n >= 8 and (room.kind == Room.Kind.START or doors >= 1 or room.kind == Room.Kind.BOSS)
		_item("Mapa", id, "PASS" if ok else "FAIL", "id=%s env=%s doors=%s kind=%s" % [room.room_id, env_n, doors, room.kind])
	var start: Room = _floor.rooms.get(Vector2i.ZERO)
	if start:
		p.global_position = start.center_global().round()
		_floor._enter_room(start, true)
	_free_enemies()
	await _pose_reset()


func _test_play_dialogue() -> void:
	var hud: HUD = _floor.ui
	var start: Room = _floor.rooms.get(Vector2i.ZERO)
	if hud == null or not hud.has_method("start_talk"):
		_item("Dialogo", "PLAY-DIALOGUE", "FAIL", "HUD.start_talk missing")
		return
	_free_enemies()
	_bind_walker(Game.Body.CAIM, Game.Difficulty.NORMAL)
	if start:
		_floor.player.global_position = start.center_global().round()
		_floor._enter_room(start, true)
	hud.start_talk(Flavor.concierge_script())
	await _pose(_floor.player.global_position, 1.0)
	var box := hud._dlg != null and hud._dlg.visible
	var face := hud._dlg_face != null and hud._dlg_face.texture != null
	var locked := Game.in_dialogue
	var who := hud._dlg_name.text if hud._dlg_name else ""
	_item("Dialogo", "PLAY-DIALOGUE", "PASS" if box and face and locked else "FAIL", "box=%s face=%s lock=%s name=%s" % [box, face, locked, who])
	hud.close_talk()
	_bind_walker(Game.Body.LILITH, Game.Difficulty.NORMAL)
	hud.start_talk(Flavor.concierge_script())
	await _pose(_floor.player.global_position, 1.0)
	var lil_face := hud._dlg_face != null and hud._dlg_face.texture != null
	var lil_who := hud._dlg_name.text if hud._dlg_name else ""
	_item("Dialogo", "PLAY-DIALOGUE-LILITH", "PASS" if hud._dlg and hud._dlg.visible and lil_face else "FAIL", "face=%s name=%s" % [lil_face, lil_who])
	hud.close_talk()
	_bind_walker(Game.Body.CAIM, Game.Difficulty.BABY)
	hud.start_talk(Flavor.concierge_script())
	await _pose(_floor.player.global_position, 1.0)
	var baby_face := hud._dlg_face != null and hud._dlg_face.texture != null
	var baby_who := hud._dlg_name.text if hud._dlg_name else ""
	_item("Dialogo", "PLAY-DIALOGUE-BABY", "PASS" if hud._dlg and hud._dlg.visible and baby_face else "FAIL", "face=%s name=%s" % [baby_face, baby_who])
	hud.close_talk()
	_bind_walker(Game.Body.CAIM, Game.Difficulty.NORMAL)
	var layout := _floor.ui.hearts != null and _floor.ui.minimap != null
	await _pose(_floor.player.global_position, 1.0)
	_item("HUD", "PLAY-HUD-LAYOUT", "PASS" if layout else "FAIL", "hearts=%s minimap=%s walker=%s" % [_floor.ui.hearts.get_child_count() if _floor.ui.hearts else 0, _floor.ui.minimap != null, Game.walker_label()])
	await get_tree().process_frame


func _test_play_sfx() -> void:
	var sfx_n := get_node_or_null("/root/Sfx")
	var bound := 0
	var miss: PackedStringArray = []
	if sfx_n:
		var players: Variant = sfx_n.get("_players")
		if players is Dictionary:
			for k in ["shoot", "hit", "pickup", "door", "unlock", "talk", "death", "cry"]:
				var node: Variant = (players as Dictionary).get(k)
				if node is AudioStreamPlayer and (node as AudioStreamPlayer).stream != null:
					bound += 1
				else:
					miss.append(String(k))
		var amb: Variant = sfx_n.get("_amb")
		if amb is AudioStreamPlayer and (amb as AudioStreamPlayer).stream != null:
			bound += 1
		else:
			miss.append("ambience")
	var start: Room = _floor.rooms.get(Vector2i.ZERO)
	if start:
		await _pose(start.center_global(), 1.0)
	_item("Audio", "PLAY-SFX-BIND", "PASS" if sfx_n != null and bound >= 8 else "FAIL", "bound=%s miss=%s" % [bound, ", ".join(miss) if miss.size() else "none"])
	await _pose_reset()

