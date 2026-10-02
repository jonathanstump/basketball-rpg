class_name BoroughBuilder
extends RefCounted
## Turns a MapData into geometry + collision + a gameplay layout (spec
## §15.10). Deterministic per map seed; repeated meshes go through a
## MeshBatcher (MultiMesh). Building blocks are split into 2-3 tile lots with
## facades and stoops facing the nearest street.

const CURB_H: float = 0.15
const FLOOR_H: float = 3.0

var map: MapData
var sim: SimWorld
var balls: BallSystem
var parent: Node3D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var batcher: MeshBatcher = MeshBatcher.new()
var layout: Dictionary = {}
var _claimed: Dictionary = {}


static func build(m: MapData, w: SimWorld, b: BallSystem, root: Node3D) -> Dictionary:
	var bb: BoroughBuilder = BoroughBuilder.new()
	return bb.run(m, w, b, root)


func run(m: MapData, w: SimWorld, b: BallSystem, root: Node3D) -> Dictionary:
	map = m
	sim = w
	balls = b
	parent = root
	rng.seed = m.seed_value()
	layout = {"id": m.id, "borough": m.borough(), "start": m.world_pos(Vector2i(m.width / 2, m.height / 2)),
		"bodegas": [], "stations": [], "shops": [], "courts": [], "crossings": [], "boxes": [], "spawns": [],
		"hoops": [], "kicks": [], "tags": [], "shortcuts": [], "secrets": [], "npcs": [], "lights": 0}
	var half: Vector2 = Vector2(float(m.width), float(m.height)) * MapData.TILE * 0.5
	w.collision.set_bounds(-half, half)
	KitBuildings.batcher = batcher
	KitProps.batcher = batcher
	_ground()
	_buildings()
	DistrictDressing.dress(self)
	_bindings()
	KitBuildings.batcher = null
	KitProps.batcher = null
	if parent != null:
		layout["draw_groups"] = batcher.flush(parent)
	layout["hash"] = geometry_hash()
	layout["batched"] = batcher.count
	return layout


func geometry_hash() -> int:
	var parts: PackedStringArray = PackedStringArray([str(batcher.geometry_hash())])
	for blk: Dictionary in sim.collision.blocks:
		parts.append("%s%s%.2f" % [(blk["min"] as Vector2).snapped(Vector2(0.01, 0.01)), (blk["max"] as Vector2).snapped(Vector2(0.01, 0.01)), float(blk["top"])])
	return "".join(parts).hash()


# ------------------------------------------------------------ ground

func surface(c: Vector2i) -> String:
	## Underlying surface of a tile ("." road, "," sidewalk, "P" park, "C" court).
	var ch: String = map.at(c)
	if ch in [".", ",", "P", "C", "~"]:
		return ch
	if ch == "t":
		return "P"
	if ch == "R":
		return "."
	var votes: Dictionary = {}
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: String = map.at(c + d)
		if n in [".", ",", "P", "C"]:
			votes[n] = int(votes.get(n, 0)) + 1
	if votes.has(","):
		return ","
	var best: String = "."
	var bv: int = 0
	for k: Variant in votes.keys():
		if int(votes[k]) > bv:
			bv = int(votes[k])
			best = str(k)
	return best


func _ground() -> void:
	var road: Material = ToonMaterials.asphalt()
	var walk: Material = ToonMaterials.toon(Color("#4A4A58"), false)
	var grass: Material = ToonMaterials.toon(Color("#1F4A2C"), false)
	var water: Material = ToonMaterials.toon(Color("#0C1E33"), false, false, Color("#1E6FD9"), 0.25)
	var tile: float = MapData.TILE
	for y: int in map.height:
		var run_start: int = -1
		for x: int in map.width + 1:
			var c: Vector2i = Vector2i(x, y)
			var s: String = surface(c) if x < map.width and not map.is_building(map.at(c)) and map.at(c) != "#" else ""
			var p: Vector3 = map.world_pos(c)
			match s:
				".":
					batcher.add_at(MeshLib.plane(Vector2(tile, tile)), road, p)
				",":
					batcher.add_at(MeshLib.box(Vector3(tile, CURB_H, tile)), walk, p + Vector3(0, CURB_H * 0.5, 0))
				"P":
					batcher.add_at(MeshLib.plane(Vector2(tile, tile)), grass, p + Vector3(0, 0.01, 0))
				"~":
					batcher.add_at(MeshLib.plane(Vector2(tile, tile)), water, p + Vector3(0, -0.3, 0))
					sim.collision.water.append({"min": Vector2(p.x - tile * 0.5, p.z - tile * 0.5), "max": Vector2(p.x + tile * 0.5, p.z + tile * 0.5)})
					sim.collision.add_box(p + Vector3(0, 1.0, 0), Vector3(tile, 2.0, tile), "water")
				"C":
					batcher.add_at(MeshLib.plane(Vector2(tile, tile)), road, p)
			# Sidewalks: merge row runs into single curb blocks.
			if s == ",":
				if run_start < 0:
					run_start = x
			elif run_start >= 0:
				var a: Vector3 = map.world_pos(Vector2i(run_start, y))
				var bpos: Vector3 = map.world_pos(Vector2i(x - 1, y))
				sim.collision.add_block(Vector2(a.x - tile * 0.5, a.z - tile * 0.5), Vector2(bpos.x + tile * 0.5, bpos.z + tile * 0.5), CURB_H, "curb")
				run_start = -1
			if map.at(c) == "#" and x < map.width:
				sim.collision.add_box(p + Vector3(0, 4.0, 0), Vector3(tile, 8.0, tile), "edge")


# ------------------------------------------------------------ buildings

func _buildings() -> void:
	for y: int in map.height:
		for x: int in map.width:
			var c: Vector2i = Vector2i(x, y)
			var ch: String = map.at(c)
			if map.is_building(ch) and not _claimed.has(c):
				_region(c, ch)


func _region(start: Vector2i, ch: String) -> void:
	# Maximal rectangle of the same letter starting at `start` (row-major).
	var x1: int = start.x
	while map.at(Vector2i(x1 + 1, start.y)) == ch and not _claimed.has(Vector2i(x1 + 1, start.y)):
		x1 += 1
	var y1: int = start.y
	var ok: bool = true
	while ok:
		for x: int in range(start.x, x1 + 1):
			var c: Vector2i = Vector2i(x, y1 + 1)
			if map.at(c) != ch or _claimed.has(c):
				ok = false
				break
		if ok:
			y1 += 1
	for yy: int in range(start.y, y1 + 1):
		for xx: int in range(start.x, x1 + 1):
			_claimed[Vector2i(xx, yy)] = true
	var rect: Rect2i = Rect2i(start.x, start.y, x1 - start.x + 1, y1 - start.y + 1)
	if ch in ["D", "K", "G", "I"] or rect.size.x * rect.size.y <= 2:
		_lot(rect, ch)
		return
	# Split into strips facing streets (front + back halves), then 2-3 tile lots.
	var strips: Array[Rect2i] = []
	if rect.size.y >= 6 and rect.size.x >= rect.size.y * 0.5:
		var hh: int = rect.size.y / 2
		strips.append(Rect2i(rect.position, Vector2i(rect.size.x, hh)))
		strips.append(Rect2i(rect.position + Vector2i(0, hh), Vector2i(rect.size.x, rect.size.y - hh)))
	elif rect.size.x >= 6:
		var hw: int = rect.size.x / 2
		strips.append(Rect2i(rect.position, Vector2i(hw, rect.size.y)))
		strips.append(Rect2i(rect.position + Vector2i(hw, 0), Vector2i(rect.size.x - hw, rect.size.y)))
	else:
		strips.append(rect)
	for st: Rect2i in strips:
		var along_x: bool = st.size.x >= st.size.y
		var length: int = st.size.x if along_x else st.size.y
		var i: int = 0
		while i < length:
			var n: int = mini(length - i, rng.randi_range(2, 3))
			if length - i - n == 1:
				n += 1
			var lot: Rect2i = Rect2i(st.position + (Vector2i(i, 0) if along_x else Vector2i(0, i)), Vector2i(n, st.size.y) if along_x else Vector2i(st.size.x, n))
			_lot(lot, ch)
			i += n


func front_of(rect: Rect2i) -> Vector3:
	var best: Vector3 = Vector3(0, 0, 1)
	var bv: int = -1
	var sides: Array = [[Vector3(0, 0, -1), Vector2i(0, -1)], [Vector3(0, 0, 1), Vector2i(0, rect.size.y)], [Vector3(-1, 0, 0), Vector2i(-1, 0)], [Vector3(1, 0, 0), Vector2i(rect.size.x, 0)]]
	for sd: Variant in sides:
		var pair: Array = sd
		var dir: Vector3 = pair[0]
		var off: Vector2i = pair[1]
		var cnt: int = 0
		var span: int = rect.size.x if absf(dir.z) > 0.5 else rect.size.y
		for k: int in span:
			var c: Vector2i = rect.position + off + (Vector2i(k, 0) if absf(dir.z) > 0.5 else Vector2i(0, k))
			if map.is_walkable(c):
				cnt += 1
		if cnt > bv:
			bv = cnt
			best = dir
	return best


func _lot(rect: Rect2i, ch: String) -> void:
	var a: Vector3 = map.world_pos(rect.position)
	var b: Vector3 = map.world_pos(rect.position + rect.size - Vector2i.ONE)
	var center: Vector3 = (a + b) * 0.5
	var size_m: Vector2 = Vector2(float(rect.size.x), float(rect.size.y)) * MapData.TILE
	var front: Vector3 = front_of(rect)
	var facade_w: float = size_m.x if absf(front.z) > 0.5 else size_m.y
	var depth: float = size_m.y if absf(front.z) > 0.5 else size_m.x
	var hr: Array = JU.a(JU.dict(map.side, "heights"), ch)
	var floors: int = rng.randi_range(int(hr[0]), int(hr[1])) if hr.size() >= 2 else 2
	var tone_i: int = rng.randi_range(0, 3)
	match ch:
		"B":
			KitBuildings.brownstone(parent, sim.collision, center, facade_w - 0.2, depth - 0.4, floors, front, rng)
		"T":
			KitBuildings.walkup(parent, sim.collision, center, facade_w - 0.2, depth - 0.4, floors, front, rng)
		"H":
			var hcol: Color = [Color("#3A4250"), Color("#2E3846"), Color("#46505E"), Color("#38343E")][tone_i]
			KitBuildings.building(parent, sim.collision, center, Vector3(size_m.x - 0.4, float(floors) * FLOOR_H, size_m.y - 0.4), hcol, float(tone_i), 0.55)
			KitBuildings.water_tower(parent, center + Vector3(0, float(floors) * FLOOR_H, 0))
		"W":
			var wcol: Color = [Color("#5A5048"), Color("#4E4A50"), Color("#64584A"), Color("#4A4440")][tone_i]
			KitBuildings.building(parent, sim.collision, center, Vector3(size_m.x - 0.2, float(floors) * FLOOR_H + 1.0, size_m.y - 0.2), wcol, float(tone_i) + 20.0, 0.15)
			DistrictDressing.rollup_doors(self, center, front, facade_w, depth)
		"D", "K", "G", "I":
			var scol: Color = Color("#5A4A60") if ch == "D" else Color("#40384A")
			KitBuildings.building(parent, sim.collision, center, Vector3(size_m.x - 0.2, 7.0, size_m.y - 0.2), scol, 7.0, 0.5)
			var face: Vector3 = center + front * (depth * 0.5 - 0.1)
			var accent: Color = JU.color(JU.dict(JU.dict(DataDB.get_dict("palettes"), "regions"), map.borough()).get("secondary"), Color("#12C2B0"))
			var text: String = {"D": "DELI GROCERY 24HR", "K": "KICKS", "G": "PUMP & GRIP", "I": "TATTOO"}[ch]
			KitProps.bodega_front(parent, sim.collision, face, front, text, accent)
			var door: Vector3 = center + front * (depth * 0.5 + MapData.TILE * 0.5)
			_storefront_entry(ch, rect.position, door, front)


func _storefront_entry(ch: String, tile: Vector2i, door: Vector3, front: Vector3) -> void:
	var k: int = map.cells_of(ch).find(tile)
	match ch:
		"D":
			var bd: Variant = map.bound("D", k)
			var info: Dictionary = bd if bd is Dictionary else {"id": "%s_bodega_%d" % [map.id, k], "cat": "Cat"}
			(layout["bodegas"] as Array).append({"id": JU.s(info, "id"), "cat": JU.s(info, "cat", "Cat"), "name": JU.s(info, "name", "Bodega"), "door": door, "front": front})
		_:
			var ids: Array = JU.a(JU.dict(map.side, "shops"), ch)
			var kind: String = {"K": "plug", "G": "pump_grip", "I": "ink_needle"}[ch]
			(layout["shops"] as Array).append({"id": str(ids[k]) if k < ids.size() else "%s_%s" % [map.id, kind], "kind": kind, "door": door, "front": front})


# ------------------------------------------------------------ bindings

func _bindings() -> void:
	DistrictBindings.collect(self)
