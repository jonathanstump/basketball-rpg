class_name InputSpec
extends RefCounted
## Builds InputEvents from data/input_map.json action specs.


static func events_from_spec(spec: Dictionary) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for k: String in JU.strs(spec, "keys"):
		var ek: InputEventKey = InputEventKey.new()
		ek.physical_keycode = OS.find_keycode_from_string(k)
		out.append(ek)
	for m: Variant in JU.a(spec, "mouse"):
		var em: InputEventMouseButton = InputEventMouseButton.new()
		em.button_index = int(m) as MouseButton
		out.append(em)
	for jb: Variant in JU.a(spec, "joy_buttons"):
		var ej: InputEventJoypadButton = InputEventJoypadButton.new()
		ej.button_index = int(jb) as JoyButton
		ej.device = -1
		out.append(ej)
	for ja: Variant in JU.a(spec, "joy_axes"):
		var pair: Array = ja
		var em2: InputEventJoypadMotion = InputEventJoypadMotion.new()
		em2.axis = int(pair[0]) as JoyAxis
		em2.axis_value = float(pair[1])
		em2.device = -1
		out.append(em2)
	return out
