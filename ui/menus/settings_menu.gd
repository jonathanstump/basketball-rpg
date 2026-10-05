class_name SettingsMenu
extends RefCounted
## Settings (spec §14): toggles and sliders as list entries (accept cycles
## the value). Persisted by the Settings autoload.

const ENTRIES: Array = [
	["screen_shake", "Screen shake", [0.0, 0.5, 1.0]],
	["reduce_flashes", "Reduce flashes", [false, true]],
	["subtitles", "Subtitles", [true, false]],
	["objective_marker", "Objective marker", [true, false]],
	["rookie_mode", "Rookie Mode", [false, true]],
	["hold_to_guard", "Hold to guard", [true, false]],
	["pass_aim_assist", "Pass aim assist", [true, false]],
	["colorblind", "Colorblind palette", ["off", "deuteranopia", "protanopia", "tritanopia"]],
	["ui_scale", "UI scale", [0.8, 1.0, 1.2, 1.5]],
	["camera_sensitivity", "Camera sensitivity", [0.5, 1.0, 1.5, 2.0]],
	["camera_invert_y", "Invert camera Y", [false, true]],
	["tilt_shift", "Tilt-shift blur", [true, false]],
	["quality", "Graphics quality", ["low", "deck", "high", "ultra"]],
	["rumble", "Controller rumble", [true, false]],
	["music_volume", "Music volume", [0.0, 0.4, 0.8, 1.0]],
	["sfx_volume", "SFX volume", [0.0, 0.5, 1.0]],
]


static func open(w: Node, back: Callable) -> void:
	var opts: Array[Dictionary] = []
	for e: Variant in ENTRIES:
		var en: Array = e
		opts.append({"id": str(en[0]), "label": "%s:  %s" % [TranslationServer.translate(str(en[1])), _fmt(Settings.get_value(str(en[0])))],
			"detail": "Rookie Mode: +2 Quarter Waters, wider shot and parry windows, enemies hit 25% softer. Achievements still unlock." if str(en[0]) == "rookie_mode" else ""})
	opts.append({"id": "_controls", "label": "Controls", "detail": "View every key and controller button, and change them. Tutorial prompts and hints use your bindings."})
	opts.append({"id": "_back", "label": "Back"})
	var m: ListMenu = MenuKit.show(w, "SETTINGS", opts, func(id: String) -> void:
		if id == "_back":
			back.call()
			return
		if id == "_controls":
			RemapMenu.open(w, func() -> void: open(w, back))
			return
		cycle(id)
		open(w, back), "Accept cycles a setting. Back returns.")
	m.cancelled.disconnect(Callable(w, "close_menu"))
	m.cancelled.connect(back)


static func cycle(key: String) -> void:
	for e: Variant in ENTRIES:
		var en: Array = e
		if str(en[0]) == key:
			var vals: Array = en[2]
			var cur: Variant = Settings.get_value(key)
			var idx: int = 0
			for i: int in vals.size():
				if str(vals[i]) == str(cur):
					idx = i
			Settings.set_value(key, vals[(idx + 1) % vals.size()])


static func _fmt(v: Variant) -> String:
	if v is bool:
		return "On" if v else "Off"
	if v is float:
		return "%d%%" % int(round(float(v) * 100.0))
	return str(v).capitalize()
