class_name MapReveal
extends RefCounted
## Fog of war (spec §5.3, §5.2): walking reveals within 25 m, resting at a
## bodega reveals 80 m, a station tap-in reveals the district's street layer.
## Masks are one byte per tile, stored in GameState.map_reveal[district].

const WALK_RADIUS_M: float = 25.0
const REST_RADIUS_M: float = 80.0


static func ensure(district: String, w: int, h: int) -> PackedByteArray:
	var mask: PackedByteArray = GameState.map_reveal.get(district, PackedByteArray())
	if mask.size() != w * h:
		mask = PackedByteArray()
		mask.resize(w * h)
		GameState.map_reveal[district] = mask
	return mask


static func reveal(mask: PackedByteArray, w: int, h: int, center: Vector2i, radius_tiles: float) -> int:
	## Marks tiles within the radius; returns how many became newly visible.
	var r: int = int(ceil(radius_tiles))
	var n: int = 0
	for y: int in range(maxi(0, center.y - r), mini(h, center.y + r + 1)):
		for x: int in range(maxi(0, center.x - r), mini(w, center.x + r + 1)):
			if Vector2(x - center.x, y - center.y).length() <= radius_tiles:
				var i: int = y * w + x
				if mask[i] == 0:
					mask[i] = 1
					n += 1
	return n


static func is_revealed(mask: PackedByteArray, w: int, c: Vector2i) -> bool:
	var i: int = c.y * w + c.x
	return i >= 0 and i < mask.size() and mask[i] != 0


static func radius_tiles(meters: float) -> float:
	return meters / MapData.TILE


static func count(mask: PackedByteArray) -> int:
	var n: int = 0
	for v: int in mask:
		if v != 0:
			n += 1
	return n


static func streets_known(district: String) -> bool:
	return GameState.has_flag("streets_" + district)
