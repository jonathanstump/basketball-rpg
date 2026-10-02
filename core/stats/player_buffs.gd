class_name PlayerBuffs
extends RefCounted
## Bodega consumables (spec §10.8): timed buffs stored on the actor's flags
## as {key: until_frame}; tick() applies heal-over-time and Hype-per-second
## and folds the rest into buff_* multipliers the systems read.


static func use(a: SimActor, id: String, frame: int) -> bool:
	if GameState.item_count(id) <= 0:
		return false
	var c: Dictionary = DataDB.item("consumables", id)
	if c.is_empty():
		return false
	GameState.add_item(id, -1)
	var e: Dictionary = JU.dict(c, "effects")
	var until: int = frame + int(JU.f(e, "duration_s", 30.0) * 60.0)
	var buffs: Dictionary = a.flags.get("buffs", {})
	for k: Variant in e.keys():
		if str(k) == "duration_s":
			continue
		if str(k) == "cure":
			var st: Dictionary = a.flags.get("status", {})
			st.erase(str(e[k]))
			continue
		buffs[str(k)] = {"value": e[k], "until": until}
	if e.has("heal_over_time_pct"):
		buffs["hot_left"] = {"value": a.hp_max * JU.f(e, "heal_over_time_pct"), "until": until}
	a.flags["buffs"] = buffs
	return true


static func tick(a: SimActor, frame: int, dt: float) -> void:
	var buffs: Dictionary = a.flags.get("buffs", {})
	var speed: float = 1.0
	var damage: float = 1.0
	var regen: float = 1.0
	for k: Variant in buffs.keys():
		var b: Dictionary = buffs[k]
		if frame >= int(b["until"]):
			buffs.erase(k)
			continue
		var v: float = float(b["value"])
		match str(k):
			"speed_mult":
				speed *= 1.0 + v
			"damage_mult":
				damage *= 1.0 + v
			"wind_regen_mult":
				regen *= 1.0 + v
			"hype_per_s":
				a.hype.add(v * dt)
			"hot_left":
				var left_s: float = maxf(dt, float(int(b["until"]) - frame) / 60.0)
				var amt: float = v / left_s * dt
				a.hp = minf(a.hp_max, a.hp + amt)
				b["value"] = v - amt
	a.flags["buff_speed_mult"] = speed
	a.flags["buff_damage_mult"] = damage
	a.flags["buff_wind_regen_mult"] = regen
