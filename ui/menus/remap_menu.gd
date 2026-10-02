class_name RemapMenu
extends RefCounted
## Controls (spec §14): every action with its keyboard and controller binding
## side by side, what it does, and remapping: pick an action, press the new
## key or button. Keyboard and pad bindings are stored separately in Settings
## "remaps" (the data/input_map.json spec format) and re-applied by
## InputRouter, so tutorial prompts and HUD hints follow immediately.

const ACTIONS: PackedStringArray = ["move_forward", "move_back", "move_left", "move_right", "light", "heavy", "dodge", "jump",
	"shoot", "hands_up", "bag_move", "interact", "quarter_water", "taunt", "swap_ball_left", "swap_ball_right", "lock_on",
	"map", "menu"]

## Short names that fit a menu row next to both bindings.
const SHORT: Dictionary = {"move_forward": "Forward", "move_back": "Back", "move_left": "Left", "move_right": "Right",
	"dodge": "Dodge/Sprint", "hands_up": "Hands Up", "quarter_water": "Quarter Water", "swap_ball_left": "Ball left",
	"swap_ball_right": "Ball right", "menu": "Pause"}


static func row_label(action: String) -> String:
	## "Interact   R | RT"
	var name: String = str(SHORT.get(action, InputPrompts.display_name(action)))
	var kb: String = InputRouter.glyph(action, "keyboard")
	var pad: String = InputRouter.glyph(action, "pad")
	return "%s   %s | %s" % [name, kb if kb != "" else "-", pad if pad != "" else "-"]


static func row_detail(action: String) -> String:
	var kb: String = InputRouter.glyph(action, "keyboard")
	var pad: String = InputRouter.glyph(action, "pad")
	return "%s\n\n%s\n\nKeyboard/mouse: %s\nController: %s\n\nAccept, then press the new key, mouse button or controller button. Esc cancels." % [
		InputPrompts.display_name(action), str(InputPrompts.HELP.get(action, "")), kb if kb != "" else "unbound", pad if pad != "" else "unbound"]


static func options() -> Array[Dictionary]:
	var opts: Array[Dictionary] = []
	for a: String in ACTIONS:
		if InputMap.has_action(a):
			opts.append({"id": a, "label": row_label(a), "detail": row_detail(a)})
	opts.append({"id": "_reset", "label": "Reset to defaults", "detail": "Put every key and button back to the defaults."})
	opts.append({"id": "_back", "label": "Back"})
	return opts


static func open(w: Node, back: Callable, at: int = 0) -> void:
	var opts: Array[Dictionary] = options()
	var m: ListMenu = MenuKit.show(w, "CONTROLS", opts, func(id: String) -> void:
		if id == "_back":
			back.call()
		elif id == "_reset":
			Settings.set_value("remaps", {})
			InputRouter.apply_input_map()
			open(w, back, opts.size() - 2)
		else:
			_capture(w, id, back, ACTIONS.find(id)), "Keyboard | Controller.  Changes save automatically.")
	m.cancelled.disconnect(Callable(w, "close_menu"))
	m.cancelled.connect(back)
	m.select(at)


static func _capture(w: Node, action: String, back: Callable, at: int) -> void:
	var cap: RemapCapture = RemapCapture.new()
	cap.action = action
	cap.done.connect(func(ev: InputEvent) -> void:
		if ev != null:
			bind(action, ev)
		open(w, back, at))
	w.call("open_menu", cap)


static func bind(action: String, ev: InputEvent) -> void:
	## Replace this action's binding for the event's device family.
	var remaps: Dictionary = (Settings.get_value("remaps") as Dictionary).duplicate(true) if Settings.get_value("remaps") is Dictionary else {}
	var spec: Dictionary = JU.dict(remaps, action) if remaps.has(action) else JU.dict(JU.dict(DataDB.get_dict("input_map"), "actions"), action).duplicate(true)
	if ev is InputEventKey:
		spec["keys"] = [OS.get_keycode_string((ev as InputEventKey).physical_keycode)]
		spec.erase("mouse")
	elif ev is InputEventMouseButton:
		spec["mouse"] = [int((ev as InputEventMouseButton).button_index)]
		spec.erase("keys")
	elif ev is InputEventJoypadButton:
		spec["joy_buttons"] = [int((ev as InputEventJoypadButton).button_index)]
		spec.erase("joy_axes")
	remaps[action] = spec
	Settings.set_value("remaps", remaps)
	InputRouter.apply_input_map()
