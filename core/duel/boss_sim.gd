class_name BossSim
extends RefCounted
## QA boss-sim policy (spec §16 M5): headless boss fight between a boss at a
## tier and the QA bot (ChallengerBrain on the player's Hooper) under full
## court rules. Returns result + time-to-kill stats for tests, smoke runs and
## the M14 balancing pass.


static func run(boss_id: String, tier: int, opts: Dictionary = {}) -> Dictionary:
	var seed_value: int = int(opts.get("seed", 1))
	var sim: CombatSim = CombatSim.new(seed_value)
	sim.combat.damage.hitstop_enabled = false
	var data: Dictionary = DataDB.boss(boss_id)
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, data, null)
	var stats: Dictionary = opts.get("stats", {})
	var p: Hooper = sim.hooper(lay["player_start"], stats, true)
	if bool(opts.get("god", false)):
		p.actor.flags["cannot_die"] = true
	if opts.has("player_hp"):
		p.actor.hp = float(opts["player_hp"])
	var boss: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, boss_id, lay["boss_spot"], tier, lay["hoop"])
	if opts.has("boss_hp_pct"):
		boss.hp = boss.hp_max * float(opts["boss_hp_pct"])
	var ctl: DuelController = DuelController.new(sim.world, sim.balls, sim.combat, boss, p.actor, lay["hoop"], data, lay)
	var bot: ChallengerBrain = ChallengerBrain.for_tier(int(opts.get("skill_tier", 6)), seed_value)
	bot.duel = ctl.duel
	bot.hoop_id = (lay["hoop"] as SimHoop).id
	bot.opponent_id = boss.id
	p.actor.input_source = bot
	if bool(opts.get("passive_bot", false)):
		bot.passive_frames = 999999
		bot.aggressive = false
	var max_frames: int = int(float(opts.get("max_s", 300.0)) * 60.0)
	ctl.start()
	if int(opts.get("start_phase", 1)) > 1:
		## Per-phase sims (Midnight): jump straight to a later phase.
		var sp: int = int(opts["start_phase"])
		ctl.duel.phase = sp
		(boss.controller as BossBrain).set_phase(sp)
		boss.hp = boss.hp_max * float(opts.get("boss_hp_pct", 1.0))
		sim.world.emit("duel_phase_changed", {"phase": sp})
	var frames: int = 0
	var phases_seen: Dictionary = {int(opts.get("start_phase", 1)): true}
	while frames < max_frames and not ctl.duel.is_over():
		sim.run(1)
		ctl.step()
		phases_seen[ctl.duel.phase] = true
		frames += 1
	var out: Dictionary = {
		"boss": boss_id, "tier": tier, "result": ctl.result if ctl.result != "" else "timeout",
		"time_s": float(frames) / 60.0, "boss_hp_ratio": boss.hp / boss.hp_max,
		"player_hp_ratio": p.actor.hp / p.actor.hp_max, "phase": ctl.duel.phase,
		"phases_seen": phases_seen.keys(), "state": ctl.duel.state, "stats": ctl.stats.duplicate(),
		"events": _counts(sim.events),
	}
	var hits: Array[float] = _hits_on(sim.events, p.actor.id, p.actor.hp_max)
	out["player_hits"] = hits.size()
	out["hits_to_kill"] = (float(hits.size()) / maxf(0.0001, _sum(hits))) if not hits.is_empty() else 0.0
	sim.dispose()
	return out


static func _hits_on(events: Array[Dictionary], target_id: int, hp_max: float) -> Array[float]:
	## Damage (as a fraction of max HP) of each clean hit the player took.
	var out: Array[float] = []
	for e: Dictionary in events:
		if str(e["type"]) == "hit_resolved" and int(e.get("target", -1)) == target_id and str(e.get("result", "")) == "hit" and float(e.get("damage", 0.0)) > 0.0:
			out.append(float(e["damage"]) / maxf(1.0, hp_max))
	return out


static func _sum(xs: Array[float]) -> float:
	var t: float = 0.0
	for x: float in xs:
		t += x
	return t


static func _counts(events: Array[Dictionary]) -> Dictionary:
	var c: Dictionary = {}
	for e: Dictionary in events:
		var t: String = str(e["type"])
		c[t] = int(c.get(t, 0)) + 1
	return c
