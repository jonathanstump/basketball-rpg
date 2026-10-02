class_name Interactables
extends RefCounted
## World interaction points (bodegas, stations, shoeboxes, tags, gates,
## shortcuts, secrets, crossings, NPCs...). The nearest enabled one within
## its radius drives the HUD prompt; Interact (RT / R) triggers it.

var items: Array[Dictionary] = []   # {id, kind, pos, radius, prompt, data, enabled}


func add(id: String, kind: String, pos: Vector3, prompt: String, data: Dictionary = {}, radius: float = 2.0) -> Dictionary:
	var it: Dictionary = {"id": id, "kind": kind, "pos": pos, "radius": radius, "prompt": prompt, "data": data, "enabled": true}
	items.append(it)
	return it


func remove(id: String) -> void:
	items = items.filter(func(it: Dictionary) -> bool: return str(it["id"]) != id)


func find(id: String) -> Dictionary:
	for it: Dictionary in items:
		if str(it["id"]) == id:
			return it
	return {}


func nearest(p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = 1e9
	for it: Dictionary in items:
		if not bool(it["enabled"]):
			continue
		var ip: Vector3 = it["pos"]
		var d: float = Vector2(ip.x - p.x, ip.z - p.z).length()
		if d <= float(it["radius"]) and d < bd and absf(ip.y - p.y) < 3.0:
			bd = d
			best = it
	return best


func of_kind(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in items:
		if str(it["kind"]) == kind:
			out.append(it)
	return out
