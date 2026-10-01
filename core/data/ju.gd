class_name JU
extends RefCounted
## Typed accessors for JSON-shaped Dictionaries. JSON numbers are floats, so
## every read goes through here to keep call sites statically typed.


static func f(d: Dictionary, key: String, def: float = 0.0) -> float:
	var v: Variant = d.get(key, def)
	if v is float or v is int:
		return float(v)
	return def


static func i(d: Dictionary, key: String, def: int = 0) -> int:
	var v: Variant = d.get(key, def)
	if v is float or v is int:
		return int(v)
	return def


static func s(d: Dictionary, key: String, def: String = "") -> String:
	var v: Variant = d.get(key, def)
	if v is String:
		return v
	return def


static func b(d: Dictionary, key: String, def: bool = false) -> bool:
	var v: Variant = d.get(key, def)
	if v is bool:
		return v
	return def


static func a(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, [])
	if v is Array:
		return v
	return []


static func dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	if v is Dictionary:
		return v
	return {}


static func strs(d: Dictionary, key: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for v: Variant in a(d, key):
		out.append(str(v))
	return out


static func floats(d: Dictionary, key: String) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for v: Variant in a(d, key):
		if v is float or v is int:
			out.append(float(v))
	return out


static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("JSON parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


static func vec3(v: Variant, def: Vector3 = Vector3.ZERO) -> Vector3:
	if v is Array and (v as Array).size() >= 3:
		var arr: Array = v
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return def


static func color(v: Variant, def: Color = Color.WHITE) -> Color:
	if v is String:
		return Color.from_string(v, def)
	return def
