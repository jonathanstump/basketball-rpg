class_name WorldCollision
extends RefCounted
## 2.5D collision for the simulation: axis-aligned blocks in XZ with a top
## height. Blocks taller than the actor's feet + step height are walls; lower
## ones are walkable platforms (stoops, curbs, rooftops). Ground is y = 0
## unless a platform is underfoot. Spatial hash keeps lookups cheap.

const CELL: float = 8.0
const STEP_HEIGHT: float = 0.35

var blocks: Array[Dictionary] = []   # {min: Vector2, max: Vector2, top: float, tag: String}
var bounds_min: Vector2 = Vector2(-1e6, -1e6)
var bounds_max: Vector2 = Vector2(1e6, 1e6)
var water: Array[Dictionary] = []    # {min, max} regions that swallow loose balls
var _grid: Dictionary = {}           # Vector2i -> Array[int]


func add_block(min_xz: Vector2, max_xz: Vector2, top: float, tag: String = "") -> int:
	var idx: int = blocks.size()
	blocks.append({"min": min_xz, "max": max_xz, "top": top, "tag": tag})
	var c0: Vector2i = _cell(min_xz)
	var c1: Vector2i = _cell(max_xz)
	for cx: int in range(c0.x, c1.x + 1):
		for cz: int in range(c0.y, c1.y + 1):
			var key: Vector2i = Vector2i(cx, cz)
			if not _grid.has(key):
				_grid[key] = [] as Array[int]
			(_grid[key] as Array[int]).append(idx)
	return idx


func add_box(center: Vector3, size: Vector3, tag: String = "") -> int:
	## Convenience: block from a box resting on the ground.
	var h: Vector2 = Vector2(size.x, size.z) * 0.5
	var c: Vector2 = Vector2(center.x, center.z)
	return add_block(c - h, c + h, center.y + size.y * 0.5, tag)


func set_bounds(min_xz: Vector2, max_xz: Vector2) -> void:
	bounds_min = min_xz
	bounds_max = max_xz


func remove_tag(tag: String) -> void:
	## Disables blocks with a tag (opened gates, kicked-down ladders).
	for b: Dictionary in blocks:
		if str(b["tag"]) == tag:
			b["top"] = -100.0


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _nearby(p: Vector2, r: float) -> Array[int]:
	var out: Array[int] = []
	var c0: Vector2i = _cell(p - Vector2(r, r))
	var c1: Vector2i = _cell(p + Vector2(r, r))
	for cx: int in range(c0.x, c1.x + 1):
		for cz: int in range(c0.y, c1.y + 1):
			var key: Vector2i = Vector2i(cx, cz)
			if _grid.has(key):
				for i: int in (_grid[key] as Array[int]):
					if not out.has(i):
						out.append(i)
	return out


func ground_height(p: Vector3) -> float:
	var g: float = 0.0
	var p2: Vector2 = Vector2(p.x, p.z)
	for i: int in _nearby(p2, 0.0):
		var b: Dictionary = blocks[i]
		var top: float = b["top"]
		if top <= p.y + STEP_HEIGHT and top > g and _inside(p2, b, 0.0):
			g = top
	return g


func resolve(pos: Vector3, radius: float) -> Vector3:
	## Pushes a circle at feet height pos.y out of walls; clamps to bounds.
	var p2: Vector2 = Vector2(pos.x, pos.z)
	for _iter: int in 3:
		var moved: bool = false
		for i: int in _nearby(p2, radius):
			var b: Dictionary = blocks[i]
			if float(b["top"]) <= pos.y + STEP_HEIGHT:
				continue
			var bmin: Vector2 = b["min"]
			var bmax: Vector2 = b["max"]
			var closest: Vector2 = Vector2(clampf(p2.x, bmin.x, bmax.x), clampf(p2.y, bmin.y, bmax.y))
			var d: Vector2 = p2 - closest
			var dist: float = d.length()
			if dist >= radius:
				continue
			moved = true
			if dist > 0.0001:
				p2 = closest + d / dist * radius
			else:
				# Center inside the block: push out along the shallowest axis.
				var pushes: Array[Vector2] = [
					Vector2(bmin.x - radius - p2.x, 0.0), Vector2(bmax.x + radius - p2.x, 0.0),
					Vector2(0.0, bmin.y - radius - p2.y), Vector2(0.0, bmax.y + radius - p2.y)]
				var best: Vector2 = pushes[0]
				for pv: Vector2 in pushes:
					if pv.length() < best.length():
						best = pv
				p2 += best
		if not moved:
			break
	p2.x = clampf(p2.x, bounds_min.x + radius, bounds_max.x - radius)
	p2.y = clampf(p2.y, bounds_min.y + radius, bounds_max.y - radius)
	return Vector3(p2.x, pos.y, p2.y)


func blocked(pos: Vector3, radius: float) -> bool:
	return not resolve(pos, radius).is_equal_approx(pos)


func segment_blocked(a: Vector3, b: Vector3) -> bool:
	## True if a wall taller than both endpoints crosses the XZ segment.
	var a2: Vector2 = Vector2(a.x, a.z)
	var b2: Vector2 = Vector2(b.x, b.z)
	var mid: Vector2 = (a2 + b2) * 0.5
	var r: float = a2.distance_to(b2) * 0.5 + 0.1
	var min_y: float = minf(a.y, b.y)
	for i: int in _nearby(mid, r):
		var blk: Dictionary = blocks[i]
		if float(blk["top"]) <= min_y + STEP_HEIGHT:
			continue
		if _segment_hits_rect(a2, b2, blk["min"], blk["max"]):
			return true
	return false


func in_water(p: Vector3) -> bool:
	var p2: Vector2 = Vector2(p.x, p.z)
	for w: Dictionary in water:
		if _inside(p2, w, 0.0):
			return true
	return false


func out_of_bounds(p: Vector3) -> bool:
	return p.x < bounds_min.x or p.z < bounds_min.y or p.x > bounds_max.x or p.z > bounds_max.y


static func _inside(p: Vector2, b: Dictionary, pad: float) -> bool:
	var bmin: Vector2 = b["min"]
	var bmax: Vector2 = b["max"]
	return p.x >= bmin.x - pad and p.x <= bmax.x + pad and p.y >= bmin.y - pad and p.y <= bmax.y + pad


static func _segment_hits_rect(a: Vector2, b: Vector2, rmin: Vector2, rmax: Vector2) -> bool:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector2 = b - a
	for axis: int in 2:
		var dv: float = d.x if axis == 0 else d.y
		var av: float = a.x if axis == 0 else a.y
		var lo: float = rmin.x if axis == 0 else rmin.y
		var hi: float = rmax.x if axis == 0 else rmax.y
		if absf(dv) < 0.00001:
			if av < lo or av > hi:
				return false
		else:
			var ta: float = (lo - av) / dv
			var tb: float = (hi - av) / dv
			if ta > tb:
				var tmp: float = ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true
