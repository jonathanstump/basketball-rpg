class_name ChainRules
extends RefCounted
## Death and "Run it back" (spec §5.4): on death you lose your unspent Rep,
## and half of it (rounded down, tuning economy.death) drops as a chain where
## you fell (boss arenas: outside the gate). Touch it to reclaim. Die again
## first and it's gone — unless the Nine Lives tattoo gives it one more life.
## Chains are {district, pos:[x,y,z], rep, lives}.


static func recoverable(rep: int) -> int:
	## The part of your unspent Rep that drops as the chain (revision 8: half,
	## rounded down).
	var frac: float = JU.f(JU.dict(DataDB.tuning("economy"), "death"), "recoverable_frac", 0.5)
	return maxi(0, floori(float(rep) * frac))


static func on_death(chains: Array, rep: int, district: String, pos: Vector3, nine_lives: bool) -> Array:
	## Returns the new chains list. Existing chains lose a life (gone at < 0).
	var out: Array = []
	for c: Variant in chains:
		var ch: Dictionary = (c as Dictionary).duplicate()
		ch["lives"] = int(ch.get("lives", 0)) - 1
		if int(ch["lives"]) >= 0:
			out.append(ch)
	if rep > 0:
		out.append({"district": district, "pos": [pos.x, pos.y, pos.z], "rep": rep, "lives": 1 if nine_lives else 0})
	return out


static func touch(chains: Array, district: String, pos: Vector3, radius: float = 1.4) -> Dictionary:
	## Returns {"chains": remaining, "rep": reclaimed} for chains within reach.
	var remaining: Array = []
	var gained: int = 0
	for c: Variant in chains:
		var ch: Dictionary = c
		var p: Vector3 = JU.vec3(ch.get("pos"))
		if str(ch.get("district", "")) == district and Vector2(p.x - pos.x, p.z - pos.z).length() <= radius:
			gained += int(ch.get("rep", 0))
		else:
			remaining.append(ch)
	return {"chains": remaining, "rep": gained}


static func waypoint(chains: Array, district: String) -> Dictionary:
	## Where to point the "your chain" marker from `district`: {} with no
	## chains; else {district, pos: Vector3, rep}, preferring one here.
	var best: Dictionary = {}
	for c: Variant in chains:
		var ch: Dictionary = c
		if best.is_empty() or (str(ch.get("district", "")) == district and str(best["district"]) != district):
			best = {"district": str(ch.get("district", "")), "pos": JU.vec3(ch.get("pos")), "rep": int(ch.get("rep", 0))}
	return best


static func total_rep(chains: Array) -> int:
	var t: int = 0
	for c: Variant in chains:
		t += int((c as Dictionary).get("rep", 0))
	return t
