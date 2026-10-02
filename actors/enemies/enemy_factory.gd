class_name EnemyFactory
extends RefCounted
## Spawns enemies from data/enemies.json with tier applied on spawn (spec
## §8.6): HP, damage, composure and rewards × tier multipliers, `min_tier`
## move filtering, Tier 5+ combo/recovery boost, Crew Captain upgrade (§8.4).


static func def(id: String) -> Dictionary:
	return DataDB.enemy(id)


static func spawn(w: SimWorld, c: CombatSystem, b: BallSystem, enemy_id: String, pos: Vector3, tier: int, opts: Dictionary = {}) -> SimActor:
	var d: Dictionary = def(enemy_id)
	if d.is_empty():
		push_error("EnemyFactory: unknown enemy " + enemy_id)
		return null
	var tiers: Dictionary = DataDB.tiers()
	var ng: int = GameState.ng_cycle
	var captain: bool = bool(opts.get("captain", false))
	var ai: Dictionary = DataDB.tuning("ai")
	var cap: Dictionary = JU.dict(ai, "captain")
	var a: SimActor = SimActor.new()
	a.kind = "prop" if JU.s(d, "kind") == "prop_target" else ("critter" if JU.s(d, "kind") == "critter" else "enemy")
	if JU.s(d, "kind") == "prop_target":
		a.kind = "enemy"
		a.flags["prop_target"] = true
	a.archetype = enemy_id
	a.display_name = JU.s(d, "name")
	a.team = 1
	if d.has("hostile") and not JU.b(d, "hostile", true):
		a.team = 0
		a.kind = "npc"
	a.tier = tier
	a.pos = pos
	a.home = pos
	a.facing = float(opts.get("facing", 0.0))
	a.radius = JU.f(d, "radius", 0.4)
	a.height = JU.f(d, "height", 1.8)
	a.contest_radius = JU.f(d, "contest_radius", 1.4)
	a.poise = JU.f(d, "poise", 0.0)
	var hp: float = JU.f(d, "hp") * TierMath.multiplier(tiers, "hp", tier, ng)
	if captain:
		hp *= JU.f(cap, "hp_mult", 1.6)
		a.flags["captain"] = true
		a.display_name = "Crew Captain " + a.display_name
	a.hp_max = hp
	a.hp = hp
	var comp: float = JU.f(d, "composure")
	if comp > 0.0:
		a.set_composure(comp * TierMath.multiplier(tiers, "composure", tier, ng), tier)
	a.flags["base_damage"] = JU.f(d, "damage")
	a.flags["speed"] = JU.f(d, "speed", 4.0)
	a.flags["mass"] = JU.f(d, "mass", 1.0 + a.radius)
	for k: String in ["fixed_damage", "snatch_pct", "flying", "harmless", "perch", "aura_radius", "tire_s", "hostile"]:
		if d.has(k):
			a.flags[k] = d[k]
	var rep: float = JU.f(d, "rep") * TierMath.multiplier(tiers, "rep", tier, ng) * (JU.f(cap, "rep_mult", 3.0) if captain else 1.0)
	a.flags["reward_rep"] = int(round(rep))
	a.flags["reward_tokens"] = int(round(JU.f(d, "tokens") * TierMath.multiplier(tiers, "tokens", tier, ng)))
	w.add_actor(a)
	if JU.b(d, "has_ball") and b != null:
		b.give(b.spawn_ball("ball_rec", pos, a), a)
	var brain: EnemyBrain = EnemyBrain.new(a, w, c, b, d, move_list(d, tier, captain))
	a.controller = brain
	if JU.b(d, "dormant"):
		brain.state = "dormant"
	return a


static func move_list(d: Dictionary, tier: int, captain: bool) -> Array[Dictionary]:
	var ids: PackedStringArray = JU.strs(d, "moves")
	if captain and JU.s(d, "captain_move") != "" and not ids.has(JU.s(d, "captain_move")):
		ids.append(JU.s(d, "captain_move"))
	var out: Array[Dictionary] = []
	for id: String in ids:
		var m: Dictionary = DataDB.move("enemies", id)
		if m.is_empty():
			push_error("EnemyFactory: missing move " + id)
			continue
		if JU.i(m, "min_tier", 1) <= tier:
			out.append(m)
	return out
