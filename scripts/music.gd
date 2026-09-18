extends Node
## BGM facade. Combat mix is SFX stingers + a quiet rumble — not the old OGG beds.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play_for_run() -> void:
	_sfx("play_for_run")


func play_floor() -> void:
	_sfx("play_floor")


func play_cry() -> void:
	_sfx("play_cry")


func stop_all() -> void:
	_sfx("stop_all")


func _sfx(method: String) -> void:
	var s := get_node_or_null("/root/Sfx")
	if s and s.has_method(method):
		s.call(method)
