class_name BossFactory
extends RefCounted
## Spawns a boss SimActor from data/bosses/<id>.json at a tier (spec §9.1,
## §11.2): Heart/composure from mini/king tuning × tier multipliers, big
## body, permanent hyper armor (composure breaks are the stagger), and a
## BossBrain driving data moves.


static func spawn(w: SimWorld, c: CombatSystem, b: BallSystem, boss_id: String, pos: Vector3, tier: int, hoop: SimHoop) -> SimActor:
	var boss: Dictionary = DataDB.boss(boss_id)
	if boss.is_empty():
		push_error("BossFactory: unknown boss " + boss_id)
		return null
	var stats: Dictionary = BossGating.base_stats(boss)
	var tiers: Dictionary = DataDB.tiers()
	var ng: int = GameState.ng_cycle
	var a: SimActor = SimActor.new()
	a.kind = "boss"
	a.archetype = boss_id
	a.display_name = JU.s(boss, "name")
	a.team = 1
	a.tier = tier
	a.pos = pos
	a.home = pos
	a.radius = JU.f(stats, "radius_m", 1.2)
	a.height = JU.f(stats, "height_m", 4.0)
	a.hp_max = JU.f(stats, "hp", 1800.0) * TierMath.multiplier(tiers, "hp", tier, ng)
	a.hp = a.hp_max
	a.poise = JU.f(stats, "poise", 9999.0)
	a.hyper_armor = true
	a.flags["base_hyper_armor"] = true
	a.flags["cannot_die"] = true
	a.flags["speed"] = JU.f(stats, "speed", 4.0)
	a.flags["base_damage"] = JU.f(stats, "light", 45.0)
	a.contest_radius = JU.f(stats, "contest_radius", 3.0)
	a.set_composure(JU.f(stats, "composure", 200.0) * TierMath.multiplier(tiers, "composure", tier, ng), tier)
	if hoop != null:
		a.face_dir(hoop.facing)
	w.add_actor(a)
	var brain: BossBrain = BossBrain.new(a, w, c, b, boss, hoop)
	a.controller = brain
	BossGimmicks.attach(brain)
	return a


static func rewards(boss: Dictionary, tier: int) -> Dictionary:
	var r: Dictionary = JU.dict(boss, "rewards")
	var kind: String = JU.s(boss, "kind", "mini")
	var t: Dictionary = DataDB.tuning("bosses")
	var base: Dictionary = JU.dict(t, "king" if kind in ["king", "landmark", "final", "superboss"] else "mini")
	var tiers: Dictionary = DataDB.tiers()
	var mult: float = JU.f(JU.dict(t, "final"), "reward_mult", 2.0) if kind == "final" else 1.0
	return {
		"rep": int(round(JU.f(r, "rep", JU.f(base, "rep")) * TierMath.multiplier(tiers, "rep", tier, GameState.ng_cycle) * mult)),
		"tokens": int(round(JU.f(r, "tokens", JU.f(base, "tokens")) * TierMath.multiplier(tiers, "tokens", tier, GameState.ng_cycle) * mult)),
		"drops": JU.strs(boss, "drops"),
		"crown": JU.s(boss, "borough") if kind == "king" else "",
		"garden_ticket": JU.s(boss, "id") if kind == "landmark" else "",
	}
