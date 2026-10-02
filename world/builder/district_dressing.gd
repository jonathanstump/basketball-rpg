class_name DistrictDressing
extends RefCounted
## Street furniture for a district (spec §12.3): cobra-head streetlights,
## hydrants, trash bags, trees, chain-link fences, elevated tracks, subway
## entrances, roll-up doors. Deterministic from the builder's rng; repeated
## meshes are batched.


static func dress(bb: BoroughBuilder) -> void:
	var m: MapData = bb.map
	var metal: Material = ToonMaterials.toon(Color("#3A4048"))
	var bag: Material = ToonMaterials.toon(Color("#101014"))
	var trunk: Material = ToonMaterials.toon(Color("#4A3426"))
	var leaf: Material = ToonMaterials.toon(Color("#2E6B3A"))
	var fence: Material = ToonMaterials.toon(Color("#7A808C"))
	var lights: int = 0
	for y: int in m.height:
		for x: int in m.width:
			var c: Vector2i = Vector2i(x, y)
			var ch: String = m.at(c)
			var p: Vector3 = m.world_pos(c)
			var road_dir: Vector3 = _road_dir(m, c)
			if ch == "," and road_dir != Vector3.ZERO:
				if (x * 7 + y * 13) % 9 == 0 and lights < 48:
					KitProps.streetlight(bb.parent, bb.sim.collision, p + Vector3(0, BoroughBuilder.CURB_H, 0) - road_dir * 1.2, road_dir, Color("#FFB347"))
					lights += 1
				elif (x * 31 + y * 17) % 23 == 0:
					KitProps.hydrant(bb.parent, bb.sim.collision, p + Vector3(0, BoroughBuilder.CURB_H, 0) - road_dir * 1.4)
			if ch == "," and _next_to_building(m, c) and bb.rng.randf() < 0.05:
				var off: Vector3 = Vector3(bb.rng.randf_range(-1.2, 1.2), 0, bb.rng.randf_range(-1.2, 1.2))
				for i: int in 3:
					bb.batcher.add_at(MeshLib.sphere(0.35), bag, p + off + Vector3(0.3 * float(i) - 0.3, BoroughBuilder.CURB_H + 0.3, 0.2 * float(i % 2)), Vector3.ZERO, Vector3(1, 0.8, 1))
			match ch:
				"t":
					bb.batcher.add_at(MeshLib.cylinder(0.18, 2.6), trunk, p + Vector3(0, 1.3, 0))
					bb.batcher.add_at(MeshLib.sphere(1.4), leaf, p + Vector3(0, 3.2, 0))
					bb.batcher.add_at(MeshLib.sphere(1.0), leaf, p + Vector3(0.6, 3.9, 0.3))
					bb.sim.collision.add_box(p + Vector3(0, 1.3, 0), Vector3(0.5, 2.6, 0.5), "tree")
				"F":
					bb.batcher.add_at(MeshLib.box(Vector3(MapData.TILE, 3.2, 0.06)), fence, p + Vector3(0, 1.6, 0), Vector3(0, 90.0 if _vertical_run(m, c, "F") else 0.0, 0))
					bb.sim.collision.add_box(p + Vector3(0, 1.6, 0), Vector3(MapData.TILE, 3.2, MapData.TILE) * Vector3(1, 1, 0.15) if not _vertical_run(m, c, "F") else Vector3(MapData.TILE * 0.15, 3.2, MapData.TILE), "fence")
				"R":
					if (x + y) % 3 == 0:
						for s: float in [-1.0, 1.0]:
							var side: Vector3 = Vector3(road_dir.z, 0, -road_dir.x) if road_dir != Vector3.ZERO else Vector3(1, 0, 0)
							bb.batcher.add_at(MeshLib.box(Vector3(0.5, 6.5, 0.5)), metal, p + side * 1.6 * s + Vector3(0, 3.25, 0))
							bb.sim.collision.add_box(p + side * 1.6 * s + Vector3(0, 3.25, 0), Vector3(0.5, 6.5, 0.5), "el_pillar")
					bb.batcher.add_at(MeshLib.box(Vector3(MapData.TILE, 0.8, MapData.TILE * 0.9)), metal, p + Vector3(0, 6.9, 0))
				"S":
					_subway_entrance(bb, p, road_dir)
	bb.layout["lights"] = lights


static func _subway_entrance(bb: BoroughBuilder, p: Vector3, road_dir: Vector3) -> void:
	var rail: Material = ToonMaterials.toon(Color("#1E5A3A"))
	var globe: Material = ToonMaterials.neon(Color("#3CFF8A"), 3.0)
	var base: Vector3 = p + Vector3(0, BoroughBuilder.CURB_H, 0)
	for s: float in [-1.0, 1.0]:
		var side: Vector3 = Vector3(road_dir.z, 0, -road_dir.x) if road_dir != Vector3.ZERO else Vector3(1, 0, 0)
		bb.batcher.add_at(MeshLib.box(Vector3(0.08, 1.0, 2.6)), rail, base + side * 0.9 * s + Vector3(0, 0.5, 0), Vector3(0, rad_to_deg(atan2(side.x, side.z)) + 90.0, 0))
		bb.batcher.add_at(MeshLib.cylinder(0.05, 2.0), rail, base + side * 0.9 * s + Vector3(0, 1.0, 0))
		bb.batcher.add_at(MeshLib.sphere(0.2), globe, base + side * 0.9 * s + Vector3(0, 2.1, 0))
	bb.batcher.add_at(MeshLib.box(Vector3(1.6, 0.3, 1.6)), ToonMaterials.toon(Color("#20242C")), base + Vector3(0, -0.1, 0))


static func rollup_doors(bb: BoroughBuilder, center: Vector3, front: Vector3, facade_w: float, depth: float) -> void:
	var door: Material = ToonMaterials.toon(Color("#8A8E98"))
	var face: Vector3 = center + front * (depth * 0.5)
	var side: Vector3 = Vector3(front.z, 0, -front.x)
	var n: int = maxi(1, int(facade_w / 4.5))
	for i: int in n:
		var off: float = (float(i) - float(n - 1) * 0.5) * 4.0
		bb.batcher.add_at(MeshLib.box(Vector3(3.0, 3.2, 0.1)), door, face + side * off + Vector3(0, 1.6, 0) + front * 0.06, Vector3(0, rad_to_deg(atan2(front.x, front.z)), 0))


static func _road_dir(m: MapData, c: Vector2i) -> Vector3:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: String = m.at(c + d)
		if n == "." or n == "R":
			return Vector3(float(d.x), 0, float(d.y))
	return Vector3.ZERO


static func _next_to_building(m: MapData, c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if m.is_building(m.at(c + d)):
			return true
	return false


static func _vertical_run(m: MapData, c: Vector2i, ch: String) -> bool:
	return m.at(c + Vector2i(0, 1)) == ch or m.at(c + Vector2i(0, -1)) == ch
