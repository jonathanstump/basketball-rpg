class_name ChallengerDuel
extends RefCounted
## Pickup Challenger 1v1 (spec §8.4): a named hooper on the player's own
## moveset, one ball, one hoop, first to N points (2s and 3s), make it take
## it (the ball comes back to the scorer, who checks it at the top of the
## key). Physical hits count; dropping to 1 Heart loses the run instead of
## cooking you. Pure sim, so it runs headless for tests.

var world: SimWorld
var balls: BallSystem
var player: SimActor
var rival: SimActor
var hoop: SimHoop
var top_of_key: Vector3
var points_to_win: int = 7
var score: Dictionary = {}
var result: String = ""


func _init(w: SimWorld, b: BallSystem, p: SimActor, r: SimActor, h: SimHoop, tok: Vector3, points: int = 7) -> void:
	world = w
	balls = b
	player = p
	rival = r
	hoop = h
	top_of_key = tok
	points_to_win = points
	score = {p.id: 0, r.id: 0}
	balls.return_on_make = true
	balls.bucket_blasts_enabled = false
	for a: SimActor in [p, r]:
		a.flags["cannot_die"] = true
	w.sim_event.connect(_on_event)


static func points_for(zone: String) -> int:
	return 3 if zone == "three" or zone == "deep" else 2


func _on_event(ev: Dictionary) -> void:
	if result != "":
		return
	if str(ev.get("type", "")) != "shot_made" or str(ev.get("hoop", "")) != hoop.id:
		return
	var who: int = int(ev["actor"])
	if not score.has(who):
		return
	score[who] = int(score[who]) + points_for(str(ev["zone"]))
	world.emit("challenger_score", {"actor": who, "score": score.duplicate(), "points": points_for(str(ev["zone"]))})
	if int(score[who]) >= points_to_win:
		_finish("victory" if who == player.id else "defeat")
	else:
		_check(world.actor_by_id(who))


func step() -> void:
	if result != "":
		return
	if player.hp <= 1.0:
		_finish("defeat")
	elif rival.hp <= 1.0:
		_finish("victory")


func _check(scorer: SimActor) -> void:
	## Make it take it: scorer checks up top, the defender resets under the rim.
	if scorer == null:
		return
	var other: SimActor = rival if scorer == player else player
	scorer.pos = top_of_key
	scorer.vel = Vector3.ZERO
	scorer.face_dir(hoop.floor_point() - top_of_key)
	other.pos = hoop.floor_point() + hoop.facing * 3.0
	other.vel = Vector3.ZERO
	world.emit("challenger_check", {"actor": scorer.id})


func _finish(r: String) -> void:
	result = r
	world.emit("challenger_" + r, {"score": score.duplicate()})


func score_text(rival_name: String) -> String:
	return "YOU %d  -  %d %s   (to %d)" % [int(score[player.id]), int(score[rival.id]), rival_name.to_upper(), points_to_win]


static func rival_stats(tier: int, bonus: int) -> Dictionary:
	## Challengers are Two-Way builds, +4 every stat per effective tier.
	var st: Dictionary = JU.dict(DataDB.archetype("two_way"), "stats").duplicate()
	for k: Variant in st.keys():
		st[k] = int(st[k]) + 4 * maxi(0, tier + bonus - 1)
	return st


static func run_sim(skill: float, tier: int, bonus: int, opts: Dictionary = {}) -> Dictionary:
	## Headless bot-vs-challenger run (QA + tests).
	var sim: CombatSim = CombatSim.new(int(opts.get("seed", 1)))
	sim.combat.damage.hitstop_enabled = false
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, court_data("brooklyn"), null)
	var p: Hooper = sim.hooper(lay["top_of_key"])
	var r: Hooper = sim.hooper(lay["boss_spot"], rival_stats(tier, bonus), false, 1)
	var hoop: SimHoop = lay["hoop"]
	var duel: ChallengerDuel = ChallengerDuel.new(sim.world, sim.balls, p.actor, r.actor, hoop, lay["top_of_key"], int(opts.get("points", 7)))
	var bot: ChallengerBrain = ChallengerBrain.for_tier(int(opts.get("bot_tier", 6)), 3)
	bot.hoop_id = hoop.id
	bot.opponent_id = r.actor.id
	p.actor.input_source = bot
	var rb: ChallengerBrain = ChallengerBrain.new()
	rb.skill = skill
	rb.hoop_id = hoop.id
	rb.opponent_id = p.actor.id
	r.actor.input_source = rb
	var frames: int = 0
	var max_frames: int = int(float(opts.get("max_s", 300.0)) * 60.0)
	while duel.result == "" and frames < max_frames:
		sim.run(1)
		duel.step()
		frames += 1
	var out: Dictionary = {"result": duel.result if duel.result != "" else "timeout", "time_s": float(frames) / 60.0,
		"player": int(duel.score[p.actor.id]), "rival": int(duel.score[r.actor.id])}
	sim.dispose()
	return out


static func court_data(region: String) -> Dictionary:
	return {"id": "pickup_court", "borough": region, "arena": {"theme": "rec_court", "size_m": [15, 14], "indoor": false}}
