class_name SfxSynth
extends RefCounted
## Placeholder SFX (spec §13, §15.13): each id in data/audio/sfx.json is an
## sfxr-style recipe rendered once to an AudioStreamWAV and cached.

static var _cache: Dictionary = {}


static func has(id: String) -> bool:
	return DataDB.has_item("sfx", id)


static func stream(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var recipe: Dictionary = DataDB.item("sfx", id)
	if recipe.is_empty():
		return null
	var w: AudioStreamWAV = Synth.to_wav(Synth.render_sfx(recipe), Synth.RATE, id.begins_with("amb_"))
	_cache[id] = w
	return w


static func warm_all() -> int:
	## Render everything at boot so the first hit never hitches.
	var n: int = 0
	for id: Variant in DataDB.catalog("sfx").keys():
		if stream(str(id)) != null:
			n += 1
	return n


static func clear() -> void:
	_cache.clear()
