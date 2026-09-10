extends Node
## Autoload. Hearts, input bindings, and floor-wide signals.

signal hearts_changed(current: int, maximum: int)
signal flavor(text: String, hold: float)
signal died
signal won
signal room_cleared
signal boss_intro
signal shake(amount: float)
signal loadout_changed

enum Body { CAIM, LILITH }
enum Difficulty { NORMAL, BABY }

const BODY_NAMES := {
	Body.CAIM: "Caim",
	Body.LILITH: "Lilith",
}
const DIFF_NAMES := {
	Difficulty.NORMAL: "Normal",
	Difficulty.BABY: "Bebê Chorão",
}

const MAX_HEARTS := 4
const HEART_CAP := 6
const RAPID_CAP := 2
const PIERCE_CAP := 2
const IFRAME_MS := 550
const ROOM_SIZE := Vector2(1280, 720)
const WALL := 64.0
const DOOR_WIDTH := 200.0

var hearts: int = MAX_HEARTS
var max_hearts: int = MAX_HEARTS
var ember: int = 0
var rapid: int = 0
var pierce: int = 0
var burn: int = 0
var heavy: int = 0
var floor_seed: int = 0
var is_dead: bool = false
var is_won: bool = false
var rng := RandomNumberGenerator.new()
var _hurt_stamp_ms := -99999
var body: Body = Body.CAIM
var last_body: Body = Body.CAIM
var body_picked: bool = false
var difficulty: Difficulty = Difficulty.NORMAL
var last_difficulty: Difficulty = Difficulty.NORMAL


func _ready() -> void:
	rng.randomize()
	floor_seed = rng.randi()
	_bind_inputs()
	reset_run()


func reset_run() -> void:
	max_hearts = MAX_HEARTS
	hearts = max_hearts
	ember = 0
	rapid = 0
	pierce = 0
	burn = 0
	heavy = 0
	is_dead = false
	is_won = false
	_hurt_stamp_ms = -99999
	body_picked = false
	body = last_body
	difficulty = last_difficulty
	hearts_changed.emit(hearts, max_hearts)
	loadout_changed.emit()


func pick_run(p_body: Body, p_diff: Difficulty) -> void:
	body = p_body
	last_body = p_body
	difficulty = p_diff
	last_difficulty = p_diff
	body_picked = true
	loadout_changed.emit()


func body_name() -> String:
	return String(BODY_NAMES.get(body, "Caim"))


func difficulty_name() -> String:
	return String(DIFF_NAMES.get(difficulty, "Normal"))


func is_baby() -> bool:
	return difficulty == Difficulty.BABY


func walker_label() -> String:
	if is_baby():
		return "Bebê Chorão"
	return "%s  ·  Normal" % body_name()


func bgm(method: String) -> void:
	# Never touch the Music identifier — missing autoload must not abort boot.
	var m := get_node_or_null("/root/Music")
	if m == null or not m.has_method(method):
		return
	m.call(method)


func hurt(amount: int = 1) -> bool:
	if is_dead or is_won:
		return false
	var now := Time.get_ticks_msec()
	if now - _hurt_stamp_ms < IFRAME_MS:
		return false
	_hurt_stamp_ms = now
	hearts = max(hearts - amount, 0)
	hearts_changed.emit(hearts, max_hearts)
	shake.emit(10.0)
	if hearts <= 0:
		is_dead = true
		died.emit()
		return true
	return true


func heal(amount: int = 1) -> void:
	hearts = mini(hearts + amount, max_hearts)
	hearts_changed.emit(hearts, max_hearts)


func add_max_heart() -> bool:
	if max_hearts >= HEART_CAP:
		return false
	max_hearts += 1
	hearts = mini(hearts + 1, max_hearts)
	hearts_changed.emit(hearts, max_hearts)
	return true


func add_ember() -> void:
	ember = mini(ember + 1, 1)
	loadout_changed.emit()


func add_rapid() -> bool:
	if rapid >= RAPID_CAP:
		return false
	rapid += 1
	loadout_changed.emit()
	return true


func add_pierce() -> bool:
	if pierce >= PIERCE_CAP:
		return false
	pierce += 1
	loadout_changed.emit()
	return true


func add_burn() -> bool:
	if burn >= 1:
		return false
	burn = 1
	loadout_changed.emit()
	return true


func add_heavy() -> bool:
	if heavy >= 1:
		return false
	heavy = 1
	loadout_changed.emit()
	return true


func shot_damage() -> int:
	return 1 + ember + heavy


func win() -> void:
	if is_won or is_dead:
		return
	is_won = true
	won.emit()


func say(text: String, hold: float = 3.2) -> void:
	flavor.emit(text, hold)


func restart_floor() -> void:
	get_tree().paused = false
	reset_run()
	get_tree().reload_current_scene()


func _bind_inputs() -> void:
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("move_up", KEY_W)
	_add_key("move_down", KEY_S)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)

	_add_key("aim_left", KEY_LEFT)
	_add_key("aim_right", KEY_RIGHT)
	_add_key("aim_up", KEY_UP)
	_add_key("aim_down", KEY_DOWN)
	_add_joy_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)

	_add_key("shoot", KEY_SPACE)
	_add_key("shoot", KEY_J)
	_add_mouse("shoot", MOUSE_BUTTON_LEFT)
	_add_joy_button("shoot", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_axis("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	_add_key("restart", KEY_R)
	_add_key("restart", KEY_ENTER)
	_add_joy_button("restart", JOY_BUTTON_A)

	_add_key("interact", KEY_E)
	_add_joy_button("interact", JOY_BUTTON_X)


func _add_key(action: String, physical: Key) -> void:
	_ensure(action)
	var e := InputEventKey.new()
	e.physical_keycode = physical
	_add_event(action, e)


func _add_mouse(action: String, button: MouseButton) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	_add_event(action, e)


func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	_add_event(action, e)


func _add_joy_button(action: String, button: JoyButton) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	_add_event(action, e)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.35)


func _add_event(action: String, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
