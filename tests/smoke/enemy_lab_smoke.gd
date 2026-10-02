extends Node
## Smoke: enemy_lab builds with a view for every type; then each hostile type
## fights the QA bot (ChallengerBrain driving a player Hooper) for 60 s of
## simulated time. Each must engage, use a move (if it has any) and be hit.

const SKIP_DAMAGE: PackedStringArray = ["pizza_rat", "tourist", "bootleg"]


func _ready() -> void:
	var lab: GameWorld = (load("res://world/labs/enemy_lab.tscn") as PackedScene).instantiate() as GameWorld
	add_child(lab)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var problems: PackedStringArray = PackedStringArray()
	var types: int = 0
	for a: SimActor in lab.sim.actors:
		if a.team == 1 and not lab.views.has(a.id):
			problems.append("no view for " + a.archetype)
	for row: Variant in lab.get("ROWS"):
		for id: Variant in (row as Array):
			types += 1
			problems.append_array(_duel(str(id)))
	if problems.is_empty():
		print("SMOKE OK enemy_lab_smoke (%d types x 60 s)" % types)
	else:
		for p: String in problems:
			push_error("enemy_lab_smoke: " + p)
	get_tree().quit()


func _duel(id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var sim: CombatSim = CombatSim.new(id.hash())
	sim.combat.damage.hitstop_enabled = false
	var bot: Hooper = sim.hooper(Vector3(0, 0, 6))
	bot.actor.flags["cannot_die"] = true
	var brain: ChallengerBrain = ChallengerBrain.for_tier(4, id.hash())
	brain.passive_frames = 60 * 8
	bot.actor.input_source = brain
	var e: SimActor = sim.enemy(id, Vector3(0, 0, -4), 1, {"facing": PI})
	if e.team == 0:
		sim.run(60 * 20)
		sim.dispose()
		return out
	var engaged: bool = false
	for _i: int in 60 * 60:
		sim.run(1)
		var br: EnemyBrain = e.controller as EnemyBrain
		if br != null and br.state == "engage":
			engaged = true
		if not e.alive:
			break
	var used_move: bool = false
	var got_hit: bool = false
	for ev: Dictionary in sim.events:
		if str(ev["type"]) == "move_started" and int(ev["actor"]) == e.id:
			used_move = true
		if str(ev["type"]) == "hit_resolved" and int(ev["target"]) == e.id:
			got_hit = true
	var d: Dictionary = DataDB.enemy(id)
	if not engaged and JU.s(d, "behavior") != "flee":
		out.append("%s never engaged" % id)
	if not JU.a(d, "moves").is_empty() and not used_move:
		out.append("%s never attacked" % id)
	if not SKIP_DAMAGE.has(id) and not got_hit:
		out.append("%s was never hit by the bot" % id)
	sim.dispose()
	return out
