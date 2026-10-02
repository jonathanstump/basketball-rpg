class_name DuelController
extends RefCounted
## Runs a boss duel on a SimWorld (spec §7.10): feeds PossessionDuel from sim
## events and applies its consequences — CHECK resets, bucket damage (§11.5),
## make-it-take-it, clear rule, Rejected punish, Statement Dunks, showboats,
## posters, dunk blocks, rebound boards, phases, T5 events, GAME POINT.
## Pure sim: no scene refs, so boss sims run headless.

const DT: float = 1.0 / 60.0

var world: SimWorld
var balls: BallSystem
var combat: CombatSystem
var duel: PossessionDuel = PossessionDuel.new()
var boss: SimActor
var player: SimActor
var hoop: SimHoop
var boss_data: Dictionary = {}
var layout: Dictionary = {}
var ball: SimBall
var started: bool = false
var pending_poster: bool = false
var rebound: Dictionary = {}
var stats: Dictionary = {"makes": 0, "misses": 0, "posters": 0, "ankles": 0, "rejected": 0, "statements": 0, "frames": 0, "buckets_damage": 0.0, "consecutive_makes": 0, "best_streak": 0}
var result: String = ""


func _init(w: SimWorld, b: BallSystem, c: CombatSystem, boss_actor: SimActor, player_actor: SimActor, h: SimHoop, data: Dictionary, lay: Dictionary) -> void:
	world = w
	balls = b
	combat = c
	boss = boss_actor
	player = player_actor
	hoop = h
	boss_data = data
	layout = lay
	balls.return_on_make = false
	balls.bucket_blasts_enabled = false
	(boss.controller as BossBrain).duel = duel
	w.sim_event.connect(_on_event)
	for x: SimBall in balls.balls:
		if x.home_id == player.id or x.holder_id == player.id:
			ball = x
	if ball == null:
		ball = balls.spawn_ball(str(player.flags.get("ball_item", "ball_rec")), player.pos, player)


func start() -> void:
	started = true
	duel.start()
	_drain()


func step() -> void:
	if not started:
		return
	if duel.is_over():
		_drain()
		return
	stats["frames"] = int(stats["frames"]) + 1
	_keep_inside(player)
	_keep_inside(boss)
	duel.tick(DT)
	boss.flags["contest_mult"] = duel.contest_mult()
	if duel.state == PossessionDuel.PLAYER_OFFENSE and not duel.player_cleared and player.has_ball and hoop.flat_distance(player.pos) > JU.f(duel.cfg, "arc_m", 6.75):
		duel.player_cleared_arc()
	_check_rebound()
	_check_hp()
	_drain()


# ------------------------------------------------------------ sim -> duel

func _on_event(ev: Dictionary) -> void:
	if not started or duel.is_over():
		return
	var t: String = str(ev.get("type", ""))
	var who: int = int(ev.get("actor", 0))
	match t:
		"shot_made":
			if who == player.id and str(ev.get("hoop", "")) == hoop.id:
				var kind: String = BucketDamage.kind_for(str(ev["zone"]), str(ev["grade"]), pending_poster)
				pending_poster = false
				duel.feed("player_made", {"kind": kind, "grade": ev["grade"]})
		"shot_missed":
			if who == player.id:
				stats["misses"] = int(stats["misses"]) + 1
				stats["consecutive_makes"] = 0
				rebound = {"pos": ev["rebound_pos"], "frame": world.frame + int(float(ev["rebound_t"]) * 60.0)}
				duel.feed("player_missed")
		"shot_rejected":
			if who == player.id and int(ev.get("blocker", 0)) == boss.id:
				stats["rejected"] = int(stats["rejected"]) + 1
				duel.feed("player_rejected")
		"pass_hit":
			if who == player.id and int(ev["target"]) == boss.id:
				duel.feed("pass_hit")
		"pass_missed":
			if who == player.id:
				duel.feed("pass_missed")
		"ball_picked", "pass_returned", "ball_returned":
			if who == player.id:
				duel.feed("player_picked")
			elif who == boss.id:
				duel.feed("boss_picked")
		"steal":
			if who == player.id and int(ev["target"]) == boss.id:
				(boss.controller as BossBrain).runner.interrupt()
				duel.feed("player_stripped")
				duel.feed("player_picked")
		"ball_stolen":
			if who == boss.id:
				duel.feed("boss_took")
		"ball_thrown":
			if who == boss.id:
				duel.feed("boss_threw")
		"hit_resolved":
			_on_hit(ev)
		"statement_dunk_finished":
			if who == boss.id and boss.has_ball:
				stats["statements"] = int(stats["statements"]) + 1
				world.emit("popup", {"text": "STATEMENT!", "pos": boss.pos, "style": "bad"})
				duel.feed("statement_landed")
		"showboat_completed":
			if who == boss.id and boss.composure != null:
				boss.composure.value = 0.0
				world.emit("popup", {"text": "SHOWBOAT!", "pos": boss.pos, "style": "bad"})
		"dunk_attempt":
			if who == player.id:
				_dunk_attempt()
		"ball_lost":
			duel.feed("out_of_bounds")
		"actor_killed":
			if who == player.id:
				duel.feed("player_died")
		"composure_broken":
			if who == boss.id and str(ev["kind"]) == "stagger" and boss.has_ball:
				var b: SimBall = balls.take_from(boss)
				if b != null:
					b.vel = (player.pos - boss.pos).normalized() * 4.0 + Vector3(0, 4, 0)
				duel.feed("player_stripped")
		"taunt_completed":
			if who == player.id:
				(boss.controller as BossBrain).aggro_until = world.frame + int(JU.f(JU.dict(DataDB.tuning("combat"), "taunt"), "boss_aggro_s", 5.0) * 60.0)


func _on_hit(ev: Dictionary) -> void:
	var r: String = str(ev["result"])
	if int(ev["attacker"]) == boss.id and int(ev["target"]) == player.id:
		if r == "strip":
			duel.feed("player_stripped")
		elif r == "rejection" and JU.s(DataDB.move(JU.s(boss_data, "id"), str(ev["move"])), "primitive") == "statement_dunk":
			duel.feed("statement_rejected")
		elif r == "ankle_breaker":
			stats["ankles"] = int(stats["ankles"]) + 1


func _dunk_attempt() -> void:
	var to_rim: Vector3 = hoop.floor_point() - player.pos
	to_rim.y = 0.0
	var to_boss: Vector3 = boss.pos - player.pos
	to_boss.y = 0.0
	if boss.is_shook() and to_boss.length() <= JU.f(duel.cfg, "poster_range_m", 4.0) + boss.radius:
		pending_poster = true
		world.emit("poster", {"actor": player.id, "boss": boss.id})
		return
	var boss_in_paint: bool = Vector2(boss.pos.x - hoop.rim.x, boss.pos.z - hoop.rim.z).length() <= 4.0
	if boss_in_paint and not boss.is_broken() and to_boss.dot(to_rim) > 0.0:
		player.flags["dunk_blocked"] = true
		world.emit("popup", {"text": "NOT IN MY HOUSE!", "pos": boss.pos, "style": "bad"})
		var b: SimBall = balls.ball_of(player)
		if b != null:
			balls.take_from(player)
			balls.give(b, boss)
		_punish(1.0)
		duel.feed("player_rejected")


func _keep_inside(a: SimActor) -> void:
	## Knockbacks and body pushes must never put anyone through the fence.
	if not layout.has("half"):
		return
	var lim: Vector2 = (layout["half"] as Vector2) + Vector2(ArenaBuilder.APRON_M, ArenaBuilder.APRON_M) - Vector2(a.radius, a.radius)
	var c: Vector3 = a.pos
	c.x = clampf(c.x, -lim.x, lim.x)
	c.z = clampf(c.z, -lim.y, lim.y)
	if c != a.pos:
		a.pos = c


func _check_rebound() -> void:
	if rebound.is_empty() or duel.state != PossessionDuel.LOOSE_BALL:
		return
	var f: int = int(rebound["frame"])
	if world.frame > f + 15:
		rebound = {}
		return
	var p: Vector3 = rebound["pos"]
	if not player.on_ground and absi(world.frame - f) <= 15 and Vector2(player.pos.x - p.x, player.pos.z - p.z).length() <= 1.6 and not player.has_ball:
		for b: SimBall in balls.balls:
			if b.state == SimBall.State.LOOSE:
				balls.give(b, player)
				world.emit("popup", {"text": "BOARD!", "pos": player.pos, "style": "good"})
				duel.feed("player_picked")
				break
		rebound = {}


func _check_hp() -> void:
	if duel.is_over() or duel.state == PossessionDuel.PHASE_TRANSITION or duel.state == PossessionDuel.GAME_POINT:
		return
	var brain: BossBrain = boss.controller as BossBrain
	var ratio: float = boss.hp / boss.hp_max
	var next: int = duel.phase + 1
	if next <= BossGating.phase_count(boss_data, boss.tier) and ratio <= BossGating.phase_threshold(boss_data, next, boss.tier):
		duel.feed("phase_down")
		return
	var t5: Dictionary = BossGating.t5_event(boss_data, boss.tier)
	if not t5.is_empty() and not brain.t5_done and ratio <= JU.f(t5, "at_hp_pct", 0.25):
		brain.t5_done = true
		brain.run_event_move(JU.s(t5, "move"))
		world.emit("t5_event", {"boss": boss.id, "move": JU.s(t5, "move")})
	if boss.hp <= 1.0:
		duel.feed("boss_down")


# ------------------------------------------------------------ duel -> sim

func _drain() -> void:
	for ev: Dictionary in duel.take_events():
		var t: String = str(ev["type"])
		world.emit("duel_" + t, ev)
		match t:
			"check":
				_do_check()
			"bucket":
				_bucket(str(ev.get("kind", "mid")), str(ev.get("grade", "GOOD")))
			"take_it_back":
				world.emit("popup", {"text": "TAKE IT BACK!", "pos": player.pos, "style": "bad"})
			"rejected_punish":
				_punish(1.0)
			"boss_heal":
				boss.hp = minf(boss.hp_max, boss.hp + boss.hp_max * float(ev["pct"]))
			"boss_composure_refill":
				if boss.composure != null:
					boss.composure.value = 0.0
			"boss_composure":
				if boss.composure != null:
					var br: String = boss.composure.add(absf(float(ev["amount"])), "stagger")
					if br != "":
						world.emit("composure_broken", {"actor": boss.id, "kind": br})
			"boss_rattled":
				(boss.controller as BossBrain).recover_s = maxf((boss.controller as BossBrain).recover_s, float(ev["seconds"]))
			"phase_changed":
				(boss.controller as BossBrain).set_phase(int(ev["phase"]))
				combat.clear_owner(boss.id)
				world.emit("boss_phase_changed", {"boss": boss.id, "phase": ev["phase"]})
			"game_point":
				combat.clear_owner(boss.id)
				if boss.composure != null:
					boss.composure.force_break("shook", 9999.0)
				_give_player_ball()
			"victory":
				result = "victory"
				boss.alive = false
				world.emit("duel_won", {"boss": boss.id, "rewards": BossFactory.rewards(boss_data, boss.tier), "stats": stats})
			"defeat":
				result = "defeat"
				world.emit("duel_lost", {"boss": boss.id, "stats": stats})


func _do_check() -> void:
	combat.clear_owner(boss.id)
	(boss.controller as BossBrain).runner.interrupt()
	_give_player_ball()
	var tok: Vector3 = layout.get("top_of_key", player.pos)
	player.pos = tok
	player.vel = Vector3.ZERO
	player.face_dir(hoop.floor_point() - tok)
	if not (boss.controller as BossBrain).stationary:
		boss.pos = layout.get("boss_spot", boss.pos)


func _give_player_ball() -> void:
	for b: SimBall in balls.balls:
		if b.state == SimBall.State.HELD and b.holder_id == player.id:
			return
	var holder_b: SimBall = null
	for b2: SimBall in balls.balls:
		if b2.state != SimBall.State.DEAD:
			holder_b = b2
	if holder_b == null:
		holder_b = balls.spawn_ball(str(player.flags.get("ball_item", "ball_rec")), player.pos, player)
	if holder_b.state == SimBall.State.HELD:
		var h: SimActor = world.actor_by_id(holder_b.holder_id)
		if h != null:
			h.has_ball = false
	holder_b.set_state(SimBall.State.LOOSE)
	player.has_ball = false
	balls.give(holder_b, player)


func _bucket(kind: String, grade: String) -> void:
	var res: Dictionary = BucketDamage.for_shooter(kind, boss.hp_max, player, grade, boss.is_shook())
	var dmg: float = float(res["damage"])
	if res.has("double_chance") and world.rng.randf() < float(res["double_chance"]):
		dmg *= 2.0
	combat.damage.apply_raw(boss, dmg)
	stats["makes"] = int(stats["makes"]) + 1
	stats["buckets_damage"] = float(stats["buckets_damage"]) + dmg
	stats["consecutive_makes"] = int(stats["consecutive_makes"]) + 1
	stats["best_streak"] = maxi(int(stats["best_streak"]), int(stats["consecutive_makes"]))
	if kind == "poster":
		stats["posters"] = int(stats["posters"]) + 1
		player.hype.gain("poster", float(player.flags.get("hype_gain_mult", 1.0)))
	if boss.composure != null and duel.state != PossessionDuel.GAME_POINT:
		var br: String = boss.composure.add(float(res["composure"]), "shook")
		if br != "":
			world.emit("composure_broken", {"actor": boss.id, "kind": br})
	world.emit("bucket_damage", {"actor": player.id, "boss": boss.id, "kind": kind, "grade": grade, "damage": dmg, "pos": boss.pos})


func _punish(mult: float) -> void:
	## Rejected / blocked dunk: unavoidable short combo, 18% of max Heart,
	## tier-scaled (+10% per tier above 1).
	var pct: float = JU.f(DataDB.tuning("shooting"), "rejected_punish_pct", 0.18) * (1.0 + 0.1 * float(boss.tier - 1)) * mult
	combat.damage.apply_raw(player, player.hp_max * pct)
	if player.controller is Hooper and player.alive:
		(player.controller as Hooper).on_hit({"result": "hit", "knockdown": true, "damage": 999.0, "weight": "heavy"})
	world.emit("popup", {"text": "GET THAT WEAK STUFF OUT!", "pos": player.pos, "style": "bad"})
	if not player.alive:
		world.emit("actor_killed", {"actor": player.id, "attacker": boss.id, "kind": player.kind, "archetype": ""})
