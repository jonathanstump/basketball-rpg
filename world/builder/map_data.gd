class_name MapData
extends RefCounted
## A parsed district: 64×64 ASCII grid (tile = 4 m) + JSON sidecar
## (spec §15.10). The k-th occurrence of a letter in row-major order binds to
## the k-th entry of that letter's sidecar list.

const TILE: float = 4.0
const LEGAL: String = "#~.,BTHWPtChDSKGIMX$%weEcLg^RFn@>"
const BUILDING: String = "BTHWDKGI"
const BLOCKING: String = "#~BTHWDKGIF"
const WALKABLE: String = ".,PtChSMX$%weEcLg^Rn@>"
## Letters that bind to sidecar lists, and the list each binds to.
const BINDINGS: Dictionary = {"D": "bodegas", "S": "stations", "n": "npcs", ">": "crossings",
	"L": "shortcuts", "g": "shortcuts", "^": "secrets", "M": "fights.M", "X": "fights.X"}

var id: String = ""
var rows: PackedStringArray = PackedStringArray()
var width: int = 0
var height: int = 0
var side: Dictionary = {}
var occurrences: Dictionary = {}   # letter -> Array[Vector2i] in row-major order


func at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= height or c.x < 0 or c.x >= rows[c.y].length():
		return "#"
	return rows[c.y][c.x]


func cells_of(letter: String) -> Array[Vector2i]:
	var v: Variant = occurrences.get(letter, [])
	var out: Array[Vector2i] = []
	for c: Variant in (v as Array):
		out.append(c as Vector2i)
	return out


func binding_list(letter: String) -> Array:
	var key: String = str(BINDINGS.get(letter, ""))
	if key == "":
		return []
	if key.begins_with("fights."):
		return JU.a(JU.dict(side, "fights"), key.substr(7))
	if letter == "L" or letter == "g":
		return JU.a(side, "shortcuts")
	return JU.a(side, key)


func bound(letter: String, k: int) -> Variant:
	## The sidecar entry bound to the k-th occurrence of `letter`.
	var list: Array = binding_list(letter)
	if letter == "g":
		k += cells_of("L").size()   # L and g share the shortcuts list, L first
	return list[k] if k < list.size() else null


func world_pos(c: Vector2i, y: float = 0.0) -> Vector3:
	## Tile center in world space; the map origin is the grid center.
	return Vector3((float(c.x) - float(width) * 0.5 + 0.5) * TILE, y, (float(c.y) - float(height) * 0.5 + 0.5) * TILE)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / TILE + float(width) * 0.5), floori(p.z / TILE + float(height) * 0.5))


func is_walkable(c: Vector2i) -> bool:
	return WALKABLE.contains(at(c))


func is_building(ch: String) -> bool:
	return BUILDING.contains(ch)


func borough() -> String:
	return JU.s(side, "borough", "brooklyn")


func seed_value() -> int:
	return JU.i(side, "seed", id.hash())
