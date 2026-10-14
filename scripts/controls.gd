extends Node
## Input bindings, rebinding, controller detection, button prompts and vibration (autoload "Controls").

signal device_changed

# Rebindable actions, in the order the Controls settings list them.
const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "dash", "pause", "reroll"]
const NAMES := {"move_up": "Move Up", "move_down": "Move Down", "move_left": "Move Left", "move_right": "Move Right",
	"dash": "Dash", "pause": "Pause", "reroll": "Reroll"}
const DEFAULT_KEYS := {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"dash": KEY_SPACE, "pause": KEY_ESCAPE, "reroll": KEY_R}
const DEFAULT_PAD := {"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN, "move_left": JOY_BUTTON_DPAD_LEFT,
	"move_right": JOY_BUTTON_DPAD_RIGHT, "dash": JOY_BUTTON_A, "pause": JOY_BUTTON_START, "reroll": JOY_BUTTON_X}
# Always-on extras that are not rebindable.
const FIXED_KEYS := {"move_up": [KEY_UP], "move_down": [KEY_DOWN], "move_left": [KEY_LEFT], "move_right": [KEY_RIGHT], "pause": [KEY_P]}
const FIXED_AXES := {"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0]}
const FIXED_PAD := {"dash": [JOY_BUTTON_RIGHT_SHOULDER]}

var using_pad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply()
	Input.joy_connection_changed.connect(func(_d, _c): device_changed.emit())


func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif (event is InputEventKey and event.pressed) or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and event.relative.length() > 4.0:
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit()


# ---------------------------------------------------------------- bindings
func key_for(action: String) -> int:
	return int(_binds().get(action, {}).get("key", DEFAULT_KEYS[action]))


func pad_for(action: String) -> int:
	return int(_binds().get(action, {}).get("pad", DEFAULT_PAD[action]))


func _binds() -> Dictionary:
	var s: Dictionary = Save.data.settings
	if not s.has("binds") or typeof(s.binds) != TYPE_DICTIONARY:
		s.binds = {}
	return s.binds


func rebind(action: String, kind: String, code: int) -> void:
	## kind is "key" or "pad". A code already used by another action is swapped onto it.
	var b := _binds()
	var cur := key_for(action) if kind == "key" else pad_for(action)
	for other in ACTIONS:
		if other != action and (key_for(other) if kind == "key" else pad_for(other)) == code:
			if not b.has(other):
				b[other] = {}
			b[other][kind] = cur
	if not b.has(action):
		b[action] = {}
	b[action][kind] = code
	Save.persist()
	apply()


func reset_binds() -> void:
	Save.data.settings.binds = {}
	Save.persist()
	apply()


func apply() -> void:
	var dz := float(Save.data.settings.get("deadzone", 0.25))
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, dz if action.begins_with("move_") else 0.5)
		var keys := [key_for(action)]
		keys.append_array(FIXED_KEYS.get(action, []))
		for k in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		var btns := [pad_for(action)]
		btns.append_array(FIXED_PAD.get(action, []))
		for bt in btns:
			var jb := InputEventJoypadButton.new()
			jb.button_index = bt
			jb.device = p1_pad()
			InputMap.action_add_event(action, jb)
		if FIXED_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = FIXED_AXES[action][0]
			jm.axis_value = FIXED_AXES[action][1]
			jm.device = p1_pad()
			InputMap.action_add_event(action, jm)
	device_changed.emit()


# ---------------------------------------------------------------- prompts
func pad_style() -> String:
	var pref := str(Save.data.settings.get("prompts", "auto"))
	if pref != "auto":
		return pref
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return "xbox"
	var n := Input.get_joy_name(pads[0]).to_lower()
	for w in ["ps3", "ps4", "ps5", "playstation", "dualshock", "dualsense", "sony"]:
		if w in n:
			return "ps"
	for w in ["nintendo", "switch", "pro controller", "joy-con", "joycon"]:
		if w in n:
			return "nintendo"
	return "xbox"


func key_name(code: int) -> String:
	var n := ""
	if DisplayServer.get_name() != "headless":
		n = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))  # AZERTY etc. show their own letters
	if n == "":
		n = OS.get_keycode_string(code)
	return n


func pad_name(btn: int, style := "") -> String:
	if style == "":
		style = pad_style()
	var faces := {
		"xbox": {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
			JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Menu", JOY_BUTTON_BACK: "View", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS"},
		"ps": {JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle", JOY_BUTTON_LEFT_SHOULDER: "L1",
			JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_START: "Options", JOY_BUTTON_BACK: "Share", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3"},
		"nintendo": {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X", JOY_BUTTON_LEFT_SHOULDER: "L",
			JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_START: "+", JOY_BUTTON_BACK: "-", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS"},
	}
	var dpad := {JOY_BUTTON_DPAD_UP: "D-Pad Up", JOY_BUTTON_DPAD_DOWN: "D-Pad Down", JOY_BUTTON_DPAD_LEFT: "D-Pad Left", JOY_BUTTON_DPAD_RIGHT: "D-Pad Right"}
	if dpad.has(btn):
		return tr(dpad[btn])
	return faces.get(style, faces.xbox).get(btn, "Button %d" % btn)


func prompt(action: String) -> String:
	## Short label for the binding on the device the player is using now.
	return pad_name(pad_for(action)) if using_pad else key_name(key_for(action))


# ---------------------------------------------------------------- co-op
# Player 2 owns one joypad (p2_device). Player 1 keeps the keyboard and any other joypad.
var p2_device := -1


func set_p2(device: int) -> void:
	p2_device = device
	apply()


func p1_pad() -> int:
	## The joypad player 1 should use while player 2 holds p2_device: -1 = any, 99 = none.
	if p2_device < 0:
		return -1
	for d in Input.get_connected_joypads():
		if d != p2_device:
			return d
	return 99


func pad_pressed(device: int, action: String) -> bool:
	if Input.is_joy_button_pressed(device, pad_for(action)):
		return true
	for bt in FIXED_PAD.get(action, []):
		if Input.is_joy_button_pressed(device, bt):
			return true
	return false


func pad_vector(device: int) -> Vector2:
	var v := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	var dz := float(Save.data.settings.get("deadzone", 0.25))
	if v.length() < dz:
		v = Vector2.ZERO
	else:
		v = v.normalized() * clampf((v.length() - dz) / (1.0 - dz), 0.0, 1.0)
	if Input.is_joy_button_pressed(device, pad_for("move_left")): v.x = -1
	if Input.is_joy_button_pressed(device, pad_for("move_right")): v.x = 1
	if Input.is_joy_button_pressed(device, pad_for("move_up")): v.y = -1
	if Input.is_joy_button_pressed(device, pad_for("move_down")): v.y = 1
	return v.limit_length(1.0)


# ---------------------------------------------------------------- vibration
func rumble(weak: float, strong: float, secs: float) -> void:
	var s: Dictionary = Save.data.settings
	if not s.get("vibration", true):
		return
	var k := float(s.get("vibration_strength", 0.8))
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(weak * k, 0, 1), clampf(strong * k, 0, 1), secs)
