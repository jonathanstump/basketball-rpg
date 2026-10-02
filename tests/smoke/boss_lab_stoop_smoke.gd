extends Node
## Smoke: The Stoop Queen's court builds and runs with the QA bot under court
## rules; then headless boss sims cover a 120 s fight and the debug win and
## loss paths (spec §16 M5).

var lab: BossArena
var seen: Dictionary = {}


func _ready() -> void:
	lab = (load("res://world/labs/boss_lab_stoop.tscn") as PackedScene).instantiate() as BossArena
	lab.skip_intro = true
	add_child(lab)
	lab.sim.sim_event.connect(func(ev: Dictionary) -> void: seen[str(ev["type"])] = true)
	var bot: ChallengerBrain = ChallengerBrain.for_tier(6)
	bot.duel = lab.duel_ctl.duel
	bot.hoop_id = (lab.layout["hoop"] as SimHoop).id
	lab.use_scripted_input(bot)
	for _i: int in 600:
		await get_tree().physics_frame
	var problems: PackedStringArray = PackedStringArray()
	for t: String in ["duel_check", "move_started", "shot_released"]:
		if not seen.has(t):
			problems.append("scene: no " + t)
	if not lab.views.has(lab.boss.id):
		problems.append("no boss view")
	var fight: Dictionary = BossSim.run("bk_stoop", 1, {"god": true, "max_s": 120, "seed": 11})
	if int((fight["stats"] as Dictionary)["frames"]) < 60 * 20:
		problems.append("120 s sim ended too early: %s" % fight["result"])
	var win: Dictionary = BossSim.run("bk_stoop", 1, {"god": true, "boss_hp_pct": 0.1, "max_s": 240})
	var loss: Dictionary = BossSim.run("bk_stoop", 3, {"player_hp": 1.0, "passive_bot": true, "max_s": 120})
	if str(win["result"]) != "victory":
		problems.append("win path not reached: %s" % win["result"])
	if str(loss["result"]) != "defeat":
		problems.append("loss path not reached: %s" % loss["result"])
	if problems.is_empty():
		print("SMOKE OK boss_lab_stoop_smoke (sim 120 s: %s, boss hp %.0f%%; win %.1fs; loss %.1fs)" % [fight["result"], float(fight["boss_hp_ratio"]) * 100.0, float(win["time_s"]), float(loss["time_s"])])
	else:
		for p: String in problems:
			push_error("boss_lab_stoop_smoke: " + p)
	get_tree().quit()
