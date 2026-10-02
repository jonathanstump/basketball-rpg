class_name NavGrid
extends RefCounted
## Tile-grid navigation for a district (spec §15.10 nav bake): an AStarGrid2D
## over walkable map tiles, built on a worker thread during the subway ride.
## steer() goes straight when there's line of sight, else follows the path.

var map: MapData
var astar: AStarGrid2D = AStarGrid2D.new()
var collision: WorldCollision
var ready: bool = false
var _cache: Dictionary = {}   # "from|to" -> PackedVector2Array of tiles
var _task: int = -1


static func create(m: MapData, col: WorldCollision) -> NavGrid:
	var n: NavGrid = NavGrid.new()
	n.map = m
	n.collision = col
	return n


func bake() -> void:
	astar.region = Rect2i(0, 0, map.width, map.height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y: int in map.height:
		for x: int in map.width:
			var c: Vector2i = Vector2i(x, y)
			astar.set_point_solid(c, not map.is_walkable(c) or map.at(c) in ["L", "g"])
	ready = true


func bake_threaded() -> void:
	_task = WorkerThreadPool.add_task(bake, false, "nav_bake")


func wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func open_tile(c: Vector2i) -> void:
	astar.set_point_solid(c, false)
	_cache.clear()


func path(from: Vector3, to: Vector3) -> PackedVector2Array:
	if not ready:
		return PackedVector2Array()
	var a: Vector2i = _clamp(map.cell_of(from))
	var b: Vector2i = _clamp(map.cell_of(to))
	var key: String = "%s|%s" % [a, b]
	if _cache.has(key):
		return _cache[key]
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return PackedVector2Array()
	var pts: PackedVector2Array = astar.get_point_path(a, b)
	if _cache.size() > 512:
		_cache.clear()
	_cache[key] = pts
	return pts


func steer(from: Vector3, to: Vector3, direct: Vector3) -> Vector3:
	if not ready or not collision.segment_blocked(from + Vector3(0, 0.5, 0), to + Vector3(0, 0.5, 0)):
		return direct
	var pts: PackedVector2Array = path(from, to)
	if pts.size() < 2:
		return direct
	var next: Vector2 = pts[1]
	var wp: Vector3 = map.world_pos(Vector2i(int(next.x), int(next.y)))
	var d: Vector3 = wp - from
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else direct


func _clamp(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 0, map.width - 1), clampi(c.y, 0, map.height - 1))
