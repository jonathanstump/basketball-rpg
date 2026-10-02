class_name UIFonts
extends RefCounted
## Fonts (spec §14): Bungee (titles), Permanent Marker (graffiti/stickers),
## Inter (body). Falls back to Godot's default font if a file is missing.

const BUNGEE: String = "res://ui/fonts/Bungee-Regular.ttf"
const MARKER: String = "res://ui/fonts/PermanentMarker-Regular.ttf"
const INTER: String = "res://ui/fonts/Inter.ttf"


static func _load(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f: Variant = load(path)
		if f is Font:
			return f
	return ThemeDB.fallback_font


static func title() -> Font:
	return _load(BUNGEE)


static func graffiti() -> Font:
	return _load(MARKER)


static func body() -> Font:
	return _load(INTER)
