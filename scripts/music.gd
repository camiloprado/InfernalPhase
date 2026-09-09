extends Node
## Original loops only. Cry track is a short synthesized choro loop — not a commercial OST.
## Boot-safe: missing files or loop API differences never abort the tree.

var _floor: AudioStreamPlayer
var _cry: AudioStreamPlayer
var _floor_db := -8.0
var _cry_db := -6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_floor = _make("res://assets/audio/floor.ogg")
	_cry = _make("res://assets/audio/cry.ogg")
	add_child(_floor)
	add_child(_cry)


func _make(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0
	p.bus = "Master"
	p.autoplay = false
	var stream := _load_stream(path)
	if stream:
		_enable_loop(stream)
		p.stream = stream
	return p


func _load_stream(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Variant = ResourceLoader.load(path)
	if loaded is AudioStream:
		return loaded
	return null


func _enable_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	if "loop" in stream:
		stream.set("loop", true)
	if "loop_mode" in stream:
		stream.set("loop_mode", 1)


func play_for_run() -> void:
	if Game.is_baby():
		play_cry()
	else:
		play_floor()


func play_floor() -> void:
	_cross(_floor, _cry, _floor_db)


func play_cry() -> void:
	_cross(_cry, _floor, _cry_db)


func stop_all() -> void:
	if _floor:
		_floor.stop()
	if _cry:
		_cry.stop()


func _cross(into: AudioStreamPlayer, out_of: AudioStreamPlayer, target_db: float) -> void:
	if into == null or into.stream == null:
		return
	if not into.playing:
		into.volume_db = -80.0
		into.play()
	if not into.playing:
		return
	var tw := create_tween()
	if tw == null:
		into.volume_db = target_db
		return
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(into, "volume_db", target_db, 0.7).set_trans(Tween.TRANS_SINE)
	if out_of and out_of.playing:
		tw.parallel().tween_property(out_of, "volume_db", -80.0, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func () -> void:
			if out_of and is_instance_valid(out_of) and out_of.volume_db < -40.0:
				out_of.stop()
		)
