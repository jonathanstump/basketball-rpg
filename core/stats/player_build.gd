class_name PlayerBuild
extends RefCounted
## Everything the player has on (spec §10.1): two balls, kicks, fit,
## headband, sleeve, two chains, Bag Move, tattoos, Crowns. compute() stacks
## their effects; apply() pushes stats and flags onto the player's SimActor
## so every system reads one place.

const GEAR_SLOTS: PackedStringArray = ["kicks", "fit", "headband", "sleeve", "chain_1", "chain_2"]
const SLOT_CATALOG: Dictionary = {"kicks": "kicks", "fit": "fits", "headband": "headbands", "sleeve": "sleeves", "chain_1": "chains", "chain_2": "chains", "ball_1": "balls", "ball_2": "balls"}


static func compute() -> EffectSet:
	var e: EffectSet = EffectSet.new()
	for slot: String in GEAR_SLOTS:
		var id: String = str(GameState.equipment.get(slot, ""))
		if id == "":
			continue
		var it: Dictionary = DataDB.item(str(SLOT_CATALOG[slot]), id)
		if JU.s(it, "requires") == "crown_pass" and not GameState.has_crown_pass():
			continue
		e.add_effects(JU.dict(it, "effects"), id)
	for t: String in GameState.tattoos:
		e.add_effects(JU.dict(DataDB.item("tattoos", t), "effects"), t)
	return e


static func effective_stats(base: Dictionary, e: EffectSet) -> Dictionary:
	var out: Dictionary = {}
	var all_add: int = int(e.add("stat_all_add"))
	for s: String in DataSchemas.STATS:
		out[s] = int(base.get(s, 10)) + all_add + int(e.add("stat_%s_add" % s))
	return out


static func apply(a: SimActor, h: Hooper, e: EffectSet = null) -> EffectSet:
	if e == null:
		e = compute()
	a.stats = effective_stats(GameState.stats if not GameState.stats.is_empty() else a.stats, e)
	if h != null:
		h.refresh_stats()
		h.speed_mult = e.mult("speed_mult")
		h.jump_height_m = (h.jump_height_m + e.add("jump_add")) * e.mult("jump_mult")
		h.regen_mult = e.mult("wind_regen_mult")
	a.hp_max *= e.mult("heart_mult")
	a.hp = a.hp_max
	a.poise = (a.poise + e.add("poise_add")) * e.mult("poise_mult")
	var f: Dictionary = a.flags
	f["damage_mult"] = e.mult("damage_mult")
	f["dribble_damage_mult"] = e.mult("dribble_damage_mult")
	f["dunk_damage_mult"] = e.mult("dunk_damage_mult")
	f["crit_bonus"] = e.add("crit_add") + float(JU.f(JU.dict(DataDB.ball(str(f.get("ball_item", "ball_rec"))), "props"), "crit_bonus", 0.0))
	f["perfect_bonus"] = e.add("perfect_add")
	f["shot_window_mult"] = 1.0
	f["low_heart_window_mult"] = e.mult("low_heart_window_mult")
	f["full_heart_damage_mult"] = e.mult("full_heart_damage_mult")
	f["parry_bonus_frames"] = e.add("parry_frames_add")
	f["ankle_bonus"] = e.add("ankle_frames_add")
	f["gather_mult"] = e.mult("gather_mult")
	f["dodge_dist_mult"] = e.mult("dodge_dist_mult")
	f["wind_cost_mult"] = float(JU.f(JU.dict(DataDB.ball(str(f.get("ball_item", "ball_rec"))), "props"), "wind_cost_mult", 1.0))
	f["dodge_wind_mult"] = e.mult("dodge_wind_mult")
	f["recovery_frames_add"] = e.add("recovery_frames_add")
	f["dunk_range_mult"] = e.mult("dunk_range_mult")
	f["dr"] = e.add("dr_add")
	f["ball_security"] = e.add("ball_security_add")
	f["status_resist"] = e.add("status_resist_add")
	f["burn_resist"] = e.add("burn_resist_add")
	f["guard_stability"] = e.mult("guard_stability_mult")
	f["push_resist"] = e.add("push_resist_add")
	f["strip_damage"] = e.add("strip_damage_add")
	f["taunt_hype_mult"] = 1.0 + e.add("taunt_hype_add") + (e.mult("taunt_hype_mult") - 1.0)
	f["ankle_hype_mult"] = e.mult("ankle_hype_mult")
	f["takeover_bonus_s"] = e.add("takeover_bonus_add")
	f["takeover_cost"] = 100.0 + e.add("takeover_cost_add")
	f["double_bucket_chance"] = e.add("double_bucket_add")
	f["poster_composure_mult"] = e.mult("poster_composure_mult")
	f["brick_damage"] = e.add("brick_damage_add")
	f["pass_range_mult"] = e.mult("pass_range_mult")
	f["pass_ricochets"] = int(f.get("pass_ricochets", 0)) + int(e.add("pass_ricochet_add"))
	f["pass_homing"] = float(f.get("pass_homing", 0.0)) + e.add("pass_homing_add")
	f["steal_bonus"] = e.add("steal_add")
	f["hustle"] = e.flag("hustle")
	f["free_sprint"] = e.flag("free_sprint")
	f["rose_ready"] = e.flag("rose") and bool(GameState.flags.get("rose_ready", true))
	var qw: Dictionary = JU.dict(DataDB.tuning("player"), "quarter_water")
	f["qw_heal_pct"] = JU.f(qw, "heal_pct", 0.35) + JU.f(qw, "sugar_rush_pct", 0.05) * float(mini(GameState.sugar_rush, JU.i(qw, "sugar_rush_max", 5))) + e.add("qw_heal_add")
	f["qw_hype"] = e.add("qw_hype_add")
	f["ball_upgrade"] = int(GameState.ball_upgrades.get(str(f.get("ball_item", "ball_rec")), 0))
	a.hype.gain_mult = e.mult("hype_gain_mult") * float(JU.f(JU.dict(DataDB.ball(str(f.get("ball_item", "ball_rec"))), "props"), "hype_gain_mult", 1.0))
	a.hype.decay_mult = e.mult("hype_decay_mult")
	GameState.flags["rep_mult"] = e.mult("rep_mult")
	GameState.flags["tokens_mult"] = e.mult("tokens_mult")
	GameState.flags["enemy_leash_mult"] = e.mult("enemy_leash_mult")
	return e


static func reward_rep(n: int) -> int:
	return int(round(float(n) * float(GameState.flags.get("rep_mult", 1.0))))


static func reward_tokens(n: int) -> int:
	return int(round(float(n) * float(GameState.flags.get("tokens_mult", 1.0))))
