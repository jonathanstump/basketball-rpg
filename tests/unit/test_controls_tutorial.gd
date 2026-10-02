extends GutTest
## Tutorial prompts name the player's own keys (from Settings remaps), and
## Settings has a Controls menu to view and change every binding.

const TAUGHT: Dictionary = {"walk_up": "move", "call_next": "interact", "move": "dodge", "strike": "light",
	"crossover": "dodge", "ankle": "dodge", "shoot": "shoot", "strip": "hands_up", "quarter_water": "quarter_water"}


func before_each() -> void:
	Settings.set_value("remaps", {})
	InputRouter.apply_input_map()
	InputRouter.last_device = "keyboard"


func after_each() -> void:
	Settings.set_value("remaps", {})
	InputRouter.apply_input_map()
	InputRouter.last_device = "keyboard"


func _steps() -> Array:
	return JU.a(DataDB.get_dict("dialogue/prologue"), "steps")


func _key(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	return ev


func test_every_tutorial_step_names_its_binding() -> void:
	for s: Variant in _steps():
		var step: Dictionary = s
		var id: String = JU.s(step, "id")
		if id == "cameo":
			continue
		var raw: String = JU.s(step, "prompt")
		assert_true(TAUGHT.has(id), "%s is covered" % id)
		assert_string_contains(raw, "{%s}" % str(TAUGHT.get(id, "?")), false)
		for dev: String in ["keyboard", "pad"]:
			var shown: String = InputPrompts.format(raw, dev)
			assert_false(shown.contains("{"), "%s/%s: every token resolved: %s" % [id, dev, shown])
			assert_false(shown.contains("unbound"), "%s/%s: action is bound: %s" % [id, dev, shown])
			assert_true(shown.contains("["), "%s/%s shows a key: %s" % [id, dev, shown])


func test_default_bindings_render_correctly() -> void:
	assert_eq(InputPrompts.format("Press {interact}", "keyboard"), "Press [R]")
	assert_eq(InputPrompts.format("Press {interact}", "pad"), "Press [RT]")
	assert_eq(InputPrompts.format("{move}", "keyboard"), "[WASD]")
	assert_eq(InputPrompts.format("{move}", "pad"), "[Left Stick]")
	assert_eq(InputPrompts.format("{dodge} {quarter_water} {light}", "keyboard"), "[Shift] [1] [Left Click]")
	assert_eq(InputPrompts.format("{dodge} {quarter_water} {light}", "pad"), "[B] [D-Up] [X]")
	assert_eq(InputPrompts.format("keep {this} and {"), "keep {this} and {", "unknown tokens are left alone")


func test_prompts_follow_remaps() -> void:
	var call_next: String = ""
	for s: Variant in _steps():
		if JU.s(s as Dictionary, "id") == "call_next":
			call_next = JU.s(s as Dictionary, "prompt")
	assert_string_starts_with(InputPrompts.format(call_next, "keyboard"), "Press [R] ")
	RemapMenu.bind("interact", _key(KEY_K))
	assert_string_starts_with(InputPrompts.format(call_next, "keyboard"), "Press [K] ", "the remap shows up in the tutorial")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	RemapMenu.bind("interact", pad)
	assert_string_starts_with(InputPrompts.format(call_next, "pad"), "Press [Y] ")
	assert_string_starts_with(InputPrompts.format(call_next, "keyboard"), "Press [K] ", "keyboard binding kept")


func test_controls_menu_lists_every_binding() -> void:
	var opts: Array[Dictionary] = RemapMenu.options()
	var ids: PackedStringArray = PackedStringArray()
	for o: Dictionary in opts:
		ids.append(str(o["id"]))
	for a: String in ["move_forward", "move_back", "move_left", "move_right", "interact", "light", "heavy", "dodge", "jump",
			"shoot", "hands_up", "quarter_water", "bag_move", "lock_on", "map", "menu"]:
		assert_true(ids.has(a), "Controls lists %s" % a)
	for o: Dictionary in opts:
		if str(o["id"]) == "interact":
			assert_eq(str(o["label"]), "Interact   R | RT", "row shows keyboard and controller")
			assert_string_contains(str(o["detail"]), "call next")
		if str(o["id"]) == "light":
			assert_eq(str(o["label"]), "Light strike   Left Click | X")
	assert_true(ids.has("_reset") and ids.has("_back"))
	RemapMenu.bind("light", _key(KEY_J))
	for o2: Dictionary in RemapMenu.options():
		if str(o2["id"]) == "light":
			assert_eq(str(o2["label"]), "Light strike   J | X", "rows show the current binding")


func test_settings_has_controls_entry() -> void:
	var host: MenuHost = MenuHost.new()
	add_child_autofree(host)
	SettingsMenu.open(host, func() -> void: pass)
	var m: ListMenu = host.current as ListMenu
	assert_not_null(m)
	var found: bool = false
	for o: Dictionary in m.options:
		found = found or (str(o["id"]) == "_controls" and str(o["label"]) == "Controls")
	assert_true(found, "Settings -> Controls")
	m.chosen.emit("_controls")
	var c: ListMenu = host.current as ListMenu
	assert_eq(c.title, "CONTROLS", "Controls opens from Settings")
	c.cancelled.emit()
	assert_eq((host.current as ListMenu).title, "SETTINGS", "Back returns to Settings")


func test_prologue_prompt_uses_live_bindings() -> void:
	GameState.new_run("nobody", "brooklyn")
	var pro: Prologue = (load("res://world/prologue/prologue.tscn") as PackedScene).instantiate() as Prologue
	pro.auto_wake = false
	add_child_autofree(pro)
	await wait_physics_frames(2)
	assert_eq(pro.prompt.text, "Walk up to the court: move with [WASD].")
	assert_string_contains(pro.controls_hint.text, "[Escape] Pause")
	assert_string_contains(pro.controls_hint.text, "Controls")
	pro.tracker.mark("reach_court")
	pro.phase = "call"
	pro._update_prompt()
	assert_eq(pro.prompt.text, "Press [R] to call \"I got next.\"")
	RemapMenu.bind("interact", _key(KEY_G))
	assert_eq(pro.prompt.text, "Press [G] to call \"I got next.\"", "remap updates the on-screen prompt")
	InputRouter.last_device = "pad"
	InputRouter.device_changed.emit("pad")
	assert_eq(pro.prompt.text, "Press [RT] to call \"I got next.\"", "device swap updates the prompt")
	pro.skip_tutorial()
	assert_eq(pro.prompt.text, "", "no prompt during the cameo")
	assert_eq(pro.controls_hint.text, "")
