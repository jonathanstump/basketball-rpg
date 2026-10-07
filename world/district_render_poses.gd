class_name DistrictRenderPoses
extends RefCounted
## Render-smoke staging for district looks (revision 10): stand by a street
## hoop, or at the end of a street looking out over the water toward the
## skyline. Screenshot-only; never used in play.


static func stage(d: District, pose: String) -> void:
	match pose:
		"hoop":
			_hoop(d)
		"edge":
			_edge(d)


static func _look(d: District, dir: Vector3, pitch: float) -> void:
	d.camera_rig.yaw = atan2(-dir.x, -dir.z)
	d.camera_rig.explore_pitch = CameraMath.clamp_pitch(pitch, d.camera_rig.cfg)
	d.player.facing = atan2(dir.x, dir.z)
	d.camera_rig.snap()


static func _hoop(d: District) -> void:
	for h: Variant in JU.a(d.layout, "hoops"):
		var hp: SimHoop = h
		var stand: Vector3 = Vector3(hp.rim.x, d.player.pos.y, hp.rim.z) + hp.facing * 4.5
		d.player.pos = stand
		_look(d, -hp.facing, 10.0)
		return


static func edge_spot(m: MapData) -> Dictionary:
	## {cell, dir} for the street tile whose end looks out past the map edge
	## toward the City (or the first such street). Pure.
	var cfg: Dictionary = JU.dict(DataDB.tuning("camera"), "skyline")
	var city_deg: float = JU.f(JU.dict(cfg, "city_dir_deg"), m.borough(), 0.0)
	var city_dir: Vector3 = Vector3(sin(deg_to_rad(city_deg)), 0, -cos(deg_to_rad(city_deg)))
	var best: Dictionary = {}
	var best_dot: float = -2.0
	for y: int in range(1, m.height - 1):
		for x: int in range(1, m.width - 1):
			var c: Vector2i = Vector2i(x, y)
			if m.at(c) != ".":
				continue
			for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if m.at(c + dv) == "#" and m.is_walkable(c - dv * 6):
					var dir: Vector3 = Vector3(dv.x, 0, dv.y)
					if dir.dot(city_dir) > best_dot:
						best_dot = dir.dot(city_dir)
						best = {"cell": c - dv * 6, "dir": dir}
	return best


static func _edge(d: District) -> void:
	var spot: Dictionary = edge_spot(d.map)
	if spot.is_empty():
		return
	d.player.pos = d.map.world_pos(spot["cell"], 0.1)
	_look(d, spot["dir"], 6.0)
