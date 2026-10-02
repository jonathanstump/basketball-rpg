class_name MapLinter
extends RefCounted
## Map lint (spec §15.10): rectangular, legal chars, every bodega/station
## reachable from `@` or a crossing on the nav grid, binding counts match the
## sidecar, each court entrance touches a court, secrets come in pairs,
## shortcuts declare a side they open from.


static func lint(m: MapData) -> PackedStringArray:
	var errs: PackedStringArray = PackedStringArray()
	if m.height == 0:
		return PackedStringArray(["%s: empty map" % m.id])
	for y: int in m.height:
		if m.rows[y].length() != m.width:
			errs.append("%s: row %d has %d columns, expected %d" % [m.id, y, m.rows[y].length(), m.width])
		for x: int in m.rows[y].length():
			if not MapData.LEGAL.contains(m.rows[y][x]):
				errs.append("%s: illegal char '%s' at %d,%d" % [m.id, m.rows[y][x], x, y])
	if not errs.is_empty():
		return errs
	for letter: Variant in MapData.BINDINGS.keys():
		var l: String = str(letter)
		if l == "g":
			continue
		var n: int = m.cells_of(l).size() + (m.cells_of("g").size() if l == "L" else 0)
		var listed: int = m.binding_list(l).size()
		if n != listed:
			errs.append("%s: %d '%s' tiles but sidecar %s lists %d" % [m.id, n, l, MapData.BINDINGS[l], listed])
	if m.cells_of("^").size() % 2 != 0:
		errs.append("%s: '^' secret access tiles must come in pairs" % m.id)
	for k: int in m.cells_of("L").size() + m.cells_of("g").size():
		var sc: Variant = JU.a(m.side, "shortcuts")[k] if k < JU.a(m.side, "shortcuts").size() else null
		if sc is Dictionary and not ["n", "s", "e", "w"].has(JU.s(sc as Dictionary, "open_from")):
			errs.append("%s: shortcut %d needs open_from n/s/e/w" % [m.id, k])
	for court_letter: String in ["M", "X"]:
		for c: Vector2i in m.cells_of(court_letter):
			var touches: bool = false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if m.at(c + d) == "C":
					touches = true
			if not touches:
				errs.append("%s: court entrance %s at %s does not touch a court" % [m.id, court_letter, c])
	var starts: Array[Vector2i] = m.cells_of("@")
	starts.append_array(m.cells_of(">"))
	if starts.is_empty():
		errs.append("%s: no '@' start or '>' crossing" % m.id)
		return errs
	var reach: Dictionary = flood(m, starts)
	for letter2: String in ["D", "S", "K", "G", "I", "M", "X"]:
		for c2: Vector2i in m.cells_of(letter2):
			if not _reachable_or_adjacent(m, c2, reach):
				errs.append("%s: %s at %s is unreachable" % [m.id, letter2, c2])
	return errs


static func flood(m: MapData, starts: Array[Vector2i]) -> Dictionary:
	## Walkable flood fill; closed shortcuts count as walkable for reachability
	## only from their open side, so treat them as passable (they open).
	var seen: Dictionary = {}
	var stack: Array[Vector2i] = starts.duplicate()
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if seen.has(c) or not m.is_walkable(c):
			continue
		seen[c] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(c + d)
	# Secret pairs teleport.
	var secrets: Array[Vector2i] = m.cells_of("^")
	for i: int in range(0, secrets.size() - 1, 2):
		if seen.has(secrets[i]) != seen.has(secrets[i + 1]):
			var from: Vector2i = secrets[i + 1] if seen.has(secrets[i]) else secrets[i]
			var sub: Array[Vector2i] = [from]
			var extra: Dictionary = _flood_simple(m, sub, seen)
			for k: Variant in extra.keys():
				seen[k] = true
	return seen


static func _flood_simple(m: MapData, starts: Array[Vector2i], already: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var stack: Array[Vector2i] = starts.duplicate()
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if out.has(c) or already.has(c) or not m.is_walkable(c):
			continue
		out[c] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(c + d)
	return out


static func _reachable_or_adjacent(m: MapData, c: Vector2i, reach: Dictionary) -> bool:
	if reach.has(c):
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if reach.has(c + d):
			return true
	return false
