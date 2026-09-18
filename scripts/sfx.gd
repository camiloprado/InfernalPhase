extends Node
## Short WAV stingers. Disk bytes first so a missing .import cannot mute the floor.

var _players: Dictionary = {}
var _amb: AudioStreamPlayer
var _cry: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in ["shoot", "hit", "pickup", "door", "unlock", "talk", "death", "cry"]:
		_players[key] = _make("res://assets/audio/sfx/%s.wav" % key, false)
	_amb = _make("res://assets/audio/sfx/ambience.wav", true)
	_cry = _make("res://assets/audio/sfx/cry.wav", false)
	if _amb:
		_amb.volume_db = -18.0


func play_named(key: String) -> void:
	var p: AudioStreamPlayer = _players.get(key)
	if p == null or p.stream == null:
		return
	p.pitch_scale = randf_range(0.94, 1.08)
	p.play()


func play_floor() -> void:
	_stop(_cry)
	if _amb and _amb.stream and not _amb.playing:
		_amb.play()


func play_cry() -> void:
	_stop(_amb)
	if _cry and _cry.stream:
		_cry.pitch_scale = randf_range(0.9, 1.12)
		_cry.play()


func play_for_run() -> void:
	if Game.is_baby():
		play_cry()
	else:
		play_floor()


func stop_all() -> void:
	_stop(_amb)
	_stop(_cry)
	for p in _players.values():
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).stop()


func _stop(p: AudioStreamPlayer) -> void:
	if p:
		p.stop()


func _make(path: String, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = -6.0
	p.stream = _load_wav(path, loop)
	add_child(p)
	return p


func _load_wav(path: String, loop: bool) -> AudioStream:
	var abs := ProjectSettings.globalize_path(path)
	var bytes := PackedByteArray()
	if FileAccess.file_exists(path):
		bytes = FileAccess.get_file_as_bytes(path)
	elif FileAccess.file_exists(abs):
		bytes = FileAccess.get_file_as_bytes(abs)
	if bytes.size() < 44:
		if ResourceLoader.exists(path):
			var loaded: Variant = ResourceLoader.load(path)
			if loaded is AudioStream:
				return loaded as AudioStream
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = bytes.slice(44)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	if loop:
		stream.loop_begin = 0
		stream.loop_end = int(stream.data.size() / 2.0)
	return stream
