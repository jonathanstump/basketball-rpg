class_name CreatorRules
extends RefCounted
## Character creator rules (spec §6.2, §6.3, §4.3): option lists from
## data/creator.json, cycling, random looks, streetball names with a
## profanity filter, start borough availability and the tier map preview.

## profile key -> creator.json list it cycles through
const OPTION_LISTS: Dictionary = {
	"skin": "skin", "face_shape": "face_shapes", "eye_shape": "eye_shapes", "eye_color": "eye_colors", "brows": "brows",
	"nose": "noses", "mouth": "mouths", "marks": "marks", "facial_hair": "facial_hair", "hair_style": "_hair",
	"hair_color": "hair_colors", "voice": "voices", "height": "_height",
}


static func cfg() -> Dictionary:
	return DataDB.get_dict("creator")


static func values(key: String) -> Array:
	var list: String = str(OPTION_LISTS.get(key, ""))
	match list:
		"_hair":
			var ids: Array = DataDB.catalog("hair_styles").keys()
			ids.sort()
			return ids
		"_height":
			var h: Dictionary = JU.dict(cfg(), "height")
			var out: Array = []
			var v: float = JU.f(h, "min", 0.95)
			while v <= JU.f(h, "max", 1.05) + 0.0001:
				out.append(snappedf(v, 0.001))
				v += JU.f(h, "step", 0.025)
			return out
		"":
			return []
	var raw: Array = JU.a(cfg(), list)
	var vals: Array = []
	for i: int in raw.size():
		vals.append(i if raw[i] is Dictionary else raw[i])
	return vals


static func cycle(profile: Dictionary, key: String, dir: int = 1) -> void:
	var vals: Array = values(key)
	if vals.is_empty():
		return
	var cur: int = 0
	for i: int in vals.size():
		if str(vals[i]) == str(profile.get(key, vals[0])):
			cur = i
	profile[key] = vals[posmod(cur + dir, vals.size())]


static func label_of(key: String, v: Variant) -> String:
	var list: String = str(OPTION_LISTS.get(key, ""))
	if list != "" and not list.begins_with("_"):
		var raw: Array = JU.a(cfg(), list)
		if v is int and int(v) < raw.size() and raw[int(v)] is Dictionary:
			return JU.s(raw[int(v)] as Dictionary, "id").capitalize()
		if str(v).begins_with("#"):
			return "Swatch %d" % (raw.find(v) + 1)
	if key == "height":
		return "%d%%" % int(round(float(v) * 100.0))
	return str(v).capitalize()


static func default_profile() -> Dictionary:
	return {"skin": "#8D5524", "face_shape": 0, "eye_shape": 0, "eye_color": "#3B2414", "brows": 0, "nose": 0, "mouth": 1,
		"marks": "none", "facial_hair": "none", "hair_style": "high_top", "hair_color": "#1A1210", "voice": "Grunt set B (mid)",
		"height": 1.0, "name": "Lil' Handles", "top_color": "#7B2FF7", "shorts_color": "#12C2B0", "shoe_color": "#F2F6FF"}


static func randomize(rng: RandomNumberGenerator) -> Dictionary:
	var p: Dictionary = default_profile()
	for key: Variant in OPTION_LISTS.keys():
		var vals: Array = values(str(key))
		if not vals.is_empty():
			p[key] = vals[rng.randi() % vals.size()]
	var pre: Array = JU.a(cfg(), "name_prefixes")
	var base: Array = JU.a(cfg(), "name_bases")
	p["name"] = compose_name(str(pre[rng.randi() % pre.size()]), str(base[rng.randi() % base.size()]))
	return p


static func compose_name(prefix: String, base: String) -> String:
	return (prefix + " " + base).strip_edges()


static func clean_name(raw: String) -> String:
	## Typed names: trim, cap the length, keep letters/digits/space/'.-.
	var out: String = ""
	for ch: String in raw.strip_edges():
		if ch.is_valid_identifier() or ch.is_valid_int() or ch in [" ", "'", ".", "-"]:
			out += ch
	return out.substr(0, JU.i(cfg(), "max_name_length", 18)).strip_edges()


static func is_allowed(name: String) -> bool:
	var squashed: String = name.to_lower().replace(" ", "").replace(".", "").replace("-", "").replace("'", "")
	squashed = squashed.replace("0", "o").replace("1", "i").replace("3", "e").replace("4", "a").replace("5", "s").replace("$", "s")
	if squashed.length() < 2:
		return false
	for w: Variant in JU.a(cfg(), "blocked_words"):
		var bw: String = str(w)
		if bw.length() <= 3:
			for word: String in name.to_lower().split(" ", false):
				if word == bw:
					return false
		elif squashed.contains(bw):
			return false
	return true


static func borough(id: String) -> Dictionary:
	return DataDB.item("boroughs", id)


static func start_available(borough_id: String) -> bool:
	return WorldIndex.has_district(JU.s(borough(borough_id), "start_district"))


static func tier_preview(start: String) -> String:
	## "Tier map" for a start borough (spec §4.3): every borough's tier.
	var rows: PackedStringArray = PackedStringArray()
	var st: Dictionary = JU.dict(JU.dict(DataDB.tiers(), "start_tiers"), start)
	for b: String in DataSchemas.BOROUGHS:
		var t: int = int(st.get(b, 1))
		rows.append("%s  T%d  %s" % [JU.s(borough(b), "name", b), t, "#".repeat(t)])
	rows.append("The City  T6   The Garden  T7")
	return "\n".join(rows)
