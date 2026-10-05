class_name BossDuelRules
extends RefCounted
## The basketball-first boss model (playtest R7), on top of DuelController:
## - Your offense: punches do x`offense_strike_mult`; buckets are the damage.
##   Take enough hits while holding and you cough it up (turnover meter).
## - Your defense: hit the boss enough while it holds and it coughs it up
##   (ball security, scaled by its Handles), or strip it with Hands Up.
## - Boss shots: odds from its rating vs your contest distance, Body and
##   Heart; a contest pressed right on the release blocks or alters it.
## - A boss bucket costs you Heart, then CHECK (your ball).
## Pure sim: no scene refs.

var ctl: DuelController:   # weak: the controller owns us (no RefCounted cycle)
	get:
		return _ctl.get_ref() as DuelController
var _ctl: WeakRef
var r7: Dictionary = {}
var profile: Dictionary = {}
var turnover: float = 0.0
var security: float = 0.0
var contest_frame: int = -9999
var last_kind: String = "mid"
var _last_action: String = ""
var stats: Dictionary = {"boss_shots": 0, "boss_makes": 0, "blocks": 0, "altered": 0, "turnovers": 0, "coughs": 0, "boss_steals": 0, "heart_lost": 0.0}


func _init(c: DuelController) -> void:
	_ctl = weakref(c)
	r7 = JU.dict(JU.dict(DataDB.tuning("bosses"), "duel"), "r7")
	profile = BossHoops.profile(c.boss_data)


func step() -> void:
	var st: String = ctl.duel.state
	ctl.boss.flags["duel_strike_mult"] = JU.f(r7, "offense_strike_mult", 0.35) if st == PossessionDuel.PLAYER_OFFENSE else 1.0
	if st != PossessionDuel.PLAYER_OFFENSE:
		turnover = 0.0
	if not ctl.boss.has_ball:
		security = 0.0
	var h: Hooper = ctl.player.controller as Hooper
	if h != null:
		if h.action != _last_action and JU.strs(JU.dict(r7, "contest"), "actions").has(h.action):
			contest_frame = ctl.world.frame
		_last_action = h.action


func turnover_limit() -> float:
	var bonus: float = minf(JU.f(r7, "turnover_handles_cap", 0.6), maxf(0.0, float(ctl.player.stat("handles") - 10)) * JU.f(r7, "turnover_handles_per_pt", 0.01))
	return ctl.player.hp_max * JU.f(r7, "turnover_pct", 0.14) * (1.0 + bonus)


func security_limit() -> float:
	var k: float = lerpf(JU.f(r7, "cough_handles_min", 0.7), JU.f(r7, "cough_handles_max", 1.6), BossHoops.rating(profile, "handles") / 100.0)
	return ctl.boss.hp_max * JU.f(r7, "cough_pct", 0.045) * k


func on_hit(ev: Dictionary) -> void:
	var r: String = str(ev.get("result", ""))
	var dmg: float = float(ev.get("damage", 0.0))
	var p: SimActor = ctl.player
	var b: SimActor = ctl.boss
	if int(ev.get("target", 0)) == p.id and int(ev.get("attacker", 0)) == b.id and r == "hit":
		if str(ev.get("move", "")) == "boss_reach" and p.has_ball and ctl.world.rng.randf() < (b.controller as BossBrain).iq.steal_chance(p):
			var ball: SimBall = ctl.balls.take_from(p)
			if ball != null:
				ctl.balls.give(ball, b)
				stats["boss_steals"] = int(stats["boss_steals"]) + 1
				ctl.world.emit("popup", {"text": "PICKED YOUR POCKET!", "pos": p.pos, "style": "bad"})
				ctl.duel.feed("boss_took")
			return
		if ctl.duel.state == PossessionDuel.PLAYER_OFFENSE and p.has_ball and dmg > 0.0:
			turnover += dmg
			if turnover >= turnover_limit():
				turnover = 0.0
				stats["turnovers"] = int(stats["turnovers"]) + 1
				_knock_loose(p, b.pos)
				ctl.world.emit("popup", {"text": "TURNOVER!", "pos": p.pos, "style": "bad"})
				ctl.duel.feed("player_turnover")
	elif int(ev.get("attacker", 0)) == p.id and int(ev.get("target", 0)) == b.id and (r == "hit" or r == "guarded"):
		if ctl.duel.state == PossessionDuel.BOSS_OFFENSE and b.has_ball and dmg > 0.0:
			security += dmg
			if security >= security_limit():
				security = 0.0
				stats["coughs"] = int(stats["coughs"]) + 1
				(b.controller as BossBrain).runner.interrupt()
				_knock_loose(b, p.pos)
				ctl.world.emit("popup", {"text": "COUGHED IT UP!", "pos": b.pos, "style": "good"})
				ctl.duel.feed("boss_coughed")


func on_release(kind: String) -> void:
	## The boss lets it go: contest timing, odds, then the real shot flight.
	var p: SimActor = ctl.player
	var b: SimActor = ctl.boss
	if not b.has_ball or ctl.duel.state != PossessionDuel.BOSS_OFFENSE:
		return
	stats["boss_shots"] = int(stats["boss_shots"]) + 1
	last_kind = kind
	var dist: float = maxf(0.0, p.dist_to(b) - b.radius)
	var timing: String = ""
	if dist <= JU.f(JU.dict(r7, "contest"), "range_m", 3.2) and p.alive:
		var off: int = ctl.world.frame - contest_frame
		timing = BossShotOdds.timing_grade(off if off <= 40 else -1, p.stat("hands"))
	if timing == BossShotOdds.BLOCKED:
		stats["blocks"] = int(stats["blocks"]) + 1
		_knock_loose(b, p.pos)
		p.hype.gain("strip", float(p.flags.get("hype_gain_mult", 1.0)))
		ctl.world.emit("popup", {"text": "BLOCKED!", "pos": b.pos + Vector3.UP * 2.0, "style": "good"})
		ctl.world.emit("boss_shot", {"actor": b.id, "kind": kind, "chance": 0.0, "timing": timing, "make": false})
		ctl.duel.feed("boss_blocked")
		return
	if timing == BossShotOdds.ALTERED:
		stats["altered"] = int(stats["altered"]) + 1
		ctl.world.emit("popup", {"text": "ALTERED!", "pos": b.pos + Vector3.UP * 2.0, "style": "good"})
	var chance: float = BossShotOdds.make_chance(kind, BossHoops.shot_rating(profile, kind), dist, p.stat("body"), p.hp / maxf(1.0, p.hp_max), timing)
	var make: bool = ctl.world.rng.randf() < chance
	var grade: String = ShotResolver.GOOD if make else (ShotResolver.BRICK if timing == BossShotOdds.ALTERED else ShotResolver.NEAR_MISS)
	ctl.world.emit("boss_shot", {"actor": b.id, "kind": kind, "chance": chance, "timing": timing, "make": make})
	ctl.balls.shoot(b, ctl.hoop, grade, "close" if kind == "layup" else kind)


func on_made() -> void:
	ctl.duel.feed("boss_made", {"kind": last_kind})


func boss_bucket(kind: String) -> void:
	var p: SimActor = ctl.player
	var dmg: float = BossShotOdds.score_damage(kind, p.hp_max, ctl.boss.tier)
	if Settings.get_bool("rookie_mode"):
		dmg *= JU.f(JU.dict(DataDB.tuning("player"), "rookie"), "enemy_damage_mult", 0.75)
	stats["boss_makes"] = int(stats["boss_makes"]) + 1
	stats["heart_lost"] = float(stats["heart_lost"]) + dmg
	ctl.combat.damage.apply_raw(p, dmg)
	ctl.world.emit("boss_scored", {"actor": ctl.boss.id, "kind": kind, "damage": dmg})
	ctl.world.emit("popup", {"text": ("THEY DUNKED ON YOU" if kind == "dunk" else "THEY SCORED") + " -%d" % int(round(dmg)), "pos": p.pos, "style": "bad"})
	if not p.alive:
		ctl.world.emit("actor_killed", {"actor": p.id, "attacker": ctl.boss.id, "kind": p.kind, "archetype": ""})


func _knock_loose(holder: SimActor, toward: Vector3) -> void:
	var ball: SimBall = ctl.balls.take_from(holder)
	if ball == null:
		return
	var d: Vector3 = toward - holder.pos
	d.y = 0.0
	ball.vel = (d.normalized() if d.length() > 0.01 else -holder.forward()) * 4.0 + Vector3(0, 4.0, 0)
