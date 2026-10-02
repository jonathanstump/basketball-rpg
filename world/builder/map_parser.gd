class_name MapParser
extends RefCounted
## Loads world/maps/<id>.txt + <id>.json into MapData (spec §15.10).

const MAP_DIR: String = "res://world/maps"


static func load_map(id: String) -> MapData:
	var txt: String = MAP_DIR.path_join(id + ".txt")
	if not FileAccess.file_exists(txt):
		return null
	var side: Variant = JU.load_json(MAP_DIR.path_join(id + ".json"))
	return parse(id, FileAccess.get_file_as_string(txt), side if side is Dictionary else {})


static func parse(id: String, text: String, side: Dictionary) -> MapData:
	var m: MapData = MapData.new()
	m.id = id
	m.side = side
	for line: String in text.replace("\r", "").split("\n"):
		if line.strip_edges() == "":
			continue
		m.rows.append(line)
	m.height = m.rows.size()
	m.width = m.rows[0].length() if m.height > 0 else 0
	for y: int in m.height:
		var row: String = m.rows[y]
		for x: int in row.length():
			var ch: String = row[x]
			if not m.occurrences.has(ch):
				m.occurrences[ch] = []
			(m.occurrences[ch] as Array).append(Vector2i(x, y))
	return m


static func list_maps() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(MAP_DIR)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(".txt"):
			out.append(f.trim_suffix(".txt"))
	out.sort()
	return out
