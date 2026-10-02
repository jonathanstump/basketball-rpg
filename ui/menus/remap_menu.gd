class_name RemapMenu
extends RefCounted
## Full remapping (spec §14): pick an action, press the new key or button.
## Keyboard and pad bindings are stored separately in Settings "remaps" (the
## data/input_map.json spec format) and re-applied by InputRouter.

const ACTIONS: PackedStringArray = ["light", "heavy", "dodge", "jump", "shoot", "hands_up", "bag_move", "interact", "taunt",
	"quarter_water", "swap_ball_left", "swap_ball_right", "lock_on", "menu", "map"]


static func open(w: Node, back: Callable) -> void:
	var opts: Array[Dictionary] = []
	for a: String in ACTIONS:
		if not InputMap.has_action(a):
			continue
		opts.append({"id": a, "label": "%s:  %s" % [a.replace("_", " ").capitalize(), InputRouter.glyph(a)],
			"detail": "Accept, then press the new key or button (%s)." % InputRouter.last_device})
	opts.append({"id": "_reset", "label": "Reset to defaults"})
	opts.append({"id": "_back", "label": "Back"})
	var m: ListMenu = MenuKit.show(w, "CONTROLS", opts, func(id: String) -> void:
		if id == "_back":
			back.call()
		elif id == "_reset":
			Settings.set_value("remaps", {})
			InputRouter.apply_input_map()
			open(w, back)
		else:
			_capture(w, id, back), "Remaps save automatically.")
	m.cancelled.disconnect(Callable(w, "close_menu"))
	m.cancelled.connect(back)


static func _capture(w: Node, action: String, back: Callable) -> void:
	var cap: RemapCapture = RemapCapture.new()
	cap.action = action
	cap.done.connect(func(ev: InputEvent) -> void:
		if ev != null:
			bind(action, ev)
		open(w, back))
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
