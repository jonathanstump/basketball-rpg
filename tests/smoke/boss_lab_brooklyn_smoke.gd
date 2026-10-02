extends Node
## Smoke: The Barker's Funhouse and The Toll's bridge court (Tier 5, so every
## phase and gimmick is live) build and run with the QA bot under court rules
## (spec §16 M8). Forces each gimmick once so its presentation path runs.

var seen: Dictionary = {}


func _ready() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for id: String in ["barker", "toll"]:
		var lab: BossArena = (load("res://world/labs/boss_lab_%s.tscn" % id) as PackedScene).instantiate() as BossArena
		lab.skip_intro = true
		add_child(lab)
		lab.sim.sim_event.connect(func(ev: Dictionary) -> void: seen[str(ev["type"])] = true)
		var bot: ChallengerBrain = ChallengerBrain.for_tier(6)
		bot.duel = lab.duel_ctl.duel
		bot.hoop_id = (lab.layout["hoop"] as SimHoop).id
		lab.use_scripted_input(bot)
		var brain: BossBrain = lab.boss.controller as BossBrain
		for i: int in 300:
			if i == 60:
				brain.run_event_move("step_right_up" if id == "barker" else "toll_gate")
			if i == 150 and id == "toll":
				(brain.gimmick as TollGimmick).raise_gate(1.0)
				brain.set_phase(2)
				(brain.gimmick as TollGimmick).beam_timer_s = 0.01
			await get_tree().physics_frame
		if not lab.views.has(lab.boss.id):
			problems.append("%s: no boss view" % id)
		for t: String in ["duel_check", "move_started"]:
			if not seen.has(t):
				problems.append("%s: no %s" % [id, t])
		lab.queue_free()
		await get_tree().process_frame
		seen.clear()
	if problems.is_empty():
		print("SMOKE OK boss_lab_brooklyn_smoke")
	else:
		for p: String in problems:
			push_error("boss_lab_brooklyn_smoke: " + p)
	get_tree().quit()
