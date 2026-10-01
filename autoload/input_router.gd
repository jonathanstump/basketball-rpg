extends Node
## Device detection, glyphs, 8-frame buffer (spec §15.3, §7.2). Builds the
## InputMap from data/input_map.json (+ Settings remaps) so remapping is data.

signal device_changed(device: String)

const BUFFERED: PackedStringArray = ["light", "heavy", "dodge", "jump", "shoot", "hands_up",
	"bag_move", "interact", "taunt", "quarter_water"]

var last_device: String = "keyboard"
var buffer: InputBuffer = InputBuffer.new(8)
var frame: int = 0
var enabled: bool = true


func _ready() -> void:
	process_priority = -100
	buffer.window = JU.i(DataDB.tuning("player"), "input_buffer_frames", 8)
	apply_input_map()


func apply_input_map() -> void:
	var data: Dictionary = DataDB.get_dict("input_map")
	var deadzone: float = JU.f(data, "deadzone", 0.2)
	var actions: Dictionary = JU.dict(data, "actions")
	var remaps: Variant = Settings.get_value("remaps")
	for name_v: Variant in actions.keys():
		var action: String = str(name_v)
		var spec: Dictionary = actions[name_v]
		if remaps is Dictionary and (remaps as Dictionary).has(action):
			spec = (remaps as Dictionary)[action]
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, deadzone)
		for ev: InputEvent in InputSpec.events_from_spec(spec):
			InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	var dev: String = last_device
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4):
		dev = "pad"
	elif event is InputEventKey or event is InputEventMouseButton:
		dev = "keyboard"
	if dev != last_device:
		last_device = dev
		device_changed.emit(dev)


func _physics_process(_delta: float) -> void:
	frame += 1
	if not enabled:
		return
	for a: String in BUFFERED:
		if Input.is_action_just_pressed(a):
			buffer.press(a, frame)


func consume(action: String) -> bool:
	return buffer.consume(action, frame)


func glyph(action: String) -> String:
	## Text glyph for prompts; swaps with the last-used device.
	var events: Array[InputEvent] = InputMap.action_get_events(action) if InputMap.has_action(action) else []
	for ev: InputEvent in events:
		if last_device == "pad" and (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
			return _pad_name(ev)
		if last_device == "keyboard" and ev is InputEventKey:
			return OS.get_keycode_string((ev as InputEventKey).physical_keycode)
		if last_device == "keyboard" and ev is InputEventMouseButton:
			return ["", "LMB", "RMB", "MMB", "Wheel Up", "Wheel Down"][clampi(int((ev as InputEventMouseButton).button_index), 0, 5)]
	return action


func _pad_name(ev: InputEvent) -> String:
	if ev is InputEventJoypadButton:
		var names: Array[String] = ["A", "B", "X", "Y", "View", "Guide", "Start", "L3", "R3", "LB", "RB", "D-Up", "D-Down", "D-Left", "D-Right"]
		var idx: int = int((ev as InputEventJoypadButton).button_index)
		return names[idx] if idx < names.size() else "Btn%d" % idx
	var ax: int = int((ev as InputEventJoypadMotion).axis)
	return ["LS", "LS", "RS", "RS", "LT", "RT"][clampi(ax, 0, 5)]
