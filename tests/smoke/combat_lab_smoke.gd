extends Node
## Smoke: combat_lab — dribble chain on a dummy, a reactive crossover for an
## Ankle Breaker, then death -> COOKED -> respawn -> run back to the chain.

var lab: GameWorld
var seen: Dictionary = {}
var results: Dictionary = {}
var phase: int = 0
var phase_frame: int = 0
var si: ScriptedInput
var chain_pos: Vector3 = Vector3.INF


func _ready() -> void:
	lab = (load("res://world/labs/combat_lab.tscn") as PackedScene).instantiate() as GameWorld
	add_child(lab)
	lab.sim.sim_event.connect(_on_event)
	lab.sim_stepped.connect(_on_step)
	EventBus.chain_recovered.connect(func(_r: int) -> void: seen["chain_recovered"] = true)
	EventBus.player_cooked.connect(func() -> void: seen["cooked"] = true)
	EventBus.player_respawned.connect(func(_b: String) -> void: seen["respawned"] = true)


func _on_event(ev: Dictionary) -> void:
	seen[str(ev["type"])] = true
	if str(ev["type"]) == "hit_resolved":
		results[str(ev["result"])] = true


func _set_script() -> void:
	si = ScriptedInput.new()
	lab.player.input.clear()
	lab.use_scripted_input(si)


func _on_step(_frame: int) -> void:
	phase_frame += 1
	var lab_dummy: TrainingDummy = lab.get("passive")
	var atk: TrainingDummy = lab.get("attacker")
	match phase:
		0:
			lab.player.pos = lab_dummy.actor.pos + Vector3(0, 0, 1.4)
			lab.player.facing = 0.0
			_set_script()
			si.press_at(1, "light").press_at(19, "light").press_at(37, "light").press_at(59, "light")
			_next()
		1:
			if phase_frame > 120:
				lab.player.pos = atk.actor.pos + Vector3(0, 0, 1.6)
				_set_script()
				_next()
		2:
			var r: MoveRunner = atk.runner
			if r.running and r.frame == r.startup() - 5:
				si.move_at(si.local_frame + 1, Vector2(1, 0)).press_at(si.local_frame + 1, "dodge")
			if results.has("ankle_breaker") or phase_frame > 600:
				_next()
		3:
			GameState.rep = 500
			lab.player.hp = 1.0
			lab.player.pos = atk.actor.pos + Vector3(0, 0, 1.5)
			_set_script()
			_next()
		4:
			if phase_frame % 60 == 0 and OS.has_environment("CC_DEBUG"):
				print("p4 f=%d hp=%.1f alive=%s dist=%.2f run=%s cd=%.2f stun=%d act=%s" % [phase_frame, lab.player.hp, lab.player.alive, lab.player.dist_to(atk.actor), atk.runner.running, atk.cooldown_s, atk.stun_frames, lab.player_hooper.action])
			if not lab.player.alive and chain_pos == Vector3.INF:
				chain_pos = lab.player.pos
			if seen.has("respawned") and chain_pos != Vector3.INF:
				lab.player.pos = chain_pos
				_next()
			elif phase_frame > 900:
				_finish()
		5:
			if phase_frame > 10:
				_finish()


func _next() -> void:
	phase += 1
	phase_frame = 0


func _finish() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for r: String in ["hit", "ankle_breaker"]:
		if not results.has(r):
			problems.append("no %s result" % r)
	for e: String in ["cooked", "respawned", "chain_recovered"]:
		if not seen.has(e):
			problems.append("missing " + e)
	if problems.is_empty():
		print("SMOKE OK combat_lab_smoke")
	else:
		for p: String in problems:
			push_error("combat_lab_smoke: " + p)
	set_process(false)
	lab.sim_stepped.disconnect(_on_step)
	get_tree().quit()
