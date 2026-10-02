class_name HookGimmick
extends RefCounted
## The Hook (spec §9.3): CROWD. The applause meter runs -100 (boos) to +100
## (applause). Style plays fill applause; getting hit and missing fill boos.
## Full boos -> "Get Off The Stage!" (hook grab). Full applause -> roses and
## the spotlight blinds him (free SHOOK). Phase 2 "Spotlight Hunt": he takes
## full damage only while the wandering spotlight is on him. T5 "Standing
## Ovation": the crowd rushes the stage edges and shrinks the arena.

const DT: float = 1.0 / 60.0
const STYLE_GAIN: Dictionary = {"ankle_breaker": 25.0, "strip": 20.0, "poster": 40.0, "rejection": 25.0, "perfect": 15.0, "make": 10.0}
const BOO_GAIN: Dictionary = {"hit": 12.0, "miss": 15.0}
const DARK_DAMAGE_MULT: float = 0.35
const SPOT_RADIUS: float = 3.2

var brain: BossBrain
var world: SimWorld
var meter: float = 0.0
var spot: Vector3 = Vector3.ZERO
var spot_vel: Vector3 = Vector3(2.4, 0, 1.7)
var half: Vector2 = Vector2(9, 8)
var ovation: bool = false


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	var size: Array = JU.a(JU.dict(b.boss, "arena"), "size_m")
	if size.size() >= 2:
		half = Vector2(float(size[0]), float(size[1])) * 0.5
	world.sim_event.connect(_on_event)


func lit() -> bool:
	return Vector2(brain.actor.pos.x - spot.x, brain.actor.pos.z - spot.z).length() <= SPOT_RADIUS + brain.actor.radius


func on_step(b: BossBrain) -> bool:
	if not b.runner.running and b.runner.speed_mult != 1.0:
		b.runner.speed_mult = 1.0
	if b.phase >= 2:
		spot += spot_vel * DT
		if absf(spot.x) > half.x * 0.8:
			spot_vel.x = -spot_vel.x
		if absf(spot.z) > half.y * 0.8:
			spot_vel.z = -spot_vel.z
		b.actor.flags["damage_taken_mult"] = 1.0 if lit() else DARK_DAMAGE_MULT
		if world.frame % 10 == 0:
			world.emit("spotlight", {"actor": b.actor.id, "pos": spot, "radius": SPOT_RADIUS, "lit": lit()})
	return false


func add(amount: float) -> void:
	meter = clampf(meter + amount, -100.0, 100.0)
	world.emit("applause", {"actor": brain.actor.id, "meter": meter})
	if meter <= -100.0:
		meter = -30.0
		world.emit("popup", {"text": "GET OFF THE STAGE!", "pos": brain.actor.pos, "style": "bad"})
		brain.run_event_move("get_off_the_stage")
	elif meter >= 100.0:
		meter = 0.0
		if brain.actor.composure != null:
			brain.actor.composure.force_break("shook", 3.0)
			world.emit("composure_broken", {"actor": brain.actor.id, "kind": "shook"})
		world.emit("roses", {"actor": brain.actor.id, "pos": brain.actor.pos})
		world.emit("popup", {"text": "STANDING O! ROSES!", "pos": brain.actor.pos, "style": "big"})


func _on_event(ev: Dictionary) -> void:
	var t: String = str(ev.get("type", ""))
	var target: SimActor = brain.target
	if target == null:
		return
	match t:
		"hit_resolved":
			var r: String = str(ev["result"])
			if int(ev["target"]) == target.id and r == "hit":
				add(-BOO_GAIN["hit"])
			elif r in ["ankle_breaker", "strip", "rejection"] and (int(ev["attacker"]) == target.id or int(ev["target"]) == target.id):
				add(STYLE_GAIN[r])
		"shot_made":
			if int(ev.get("actor", 0)) == target.id:
				add(STYLE_GAIN["perfect"] if str(ev.get("grade", "")) == "PERFECT" else STYLE_GAIN["make"])
		"shot_missed":
			if int(ev.get("actor", 0)) == target.id:
				add(-BOO_GAIN["miss"])
		"poster":
			add(STYLE_GAIN["poster"])
		"arena_event":
			if int(ev["actor"]) == brain.actor.id and str(ev["event"]) == "standing_ovation" and not ovation:
				_ovation()
		"mirror_requested":
			if int(ev["actor"]) == brain.actor.id and str(ev["move"]) == "encore" and brain.history.size() >= 2:
				## Encore: his last combo again, faster.
				var last: String = brain.history[brain.history.size() - 2]
				if last != "encore":
					brain.runner.speed_mult = 0.7
					brain.run_event_move(last)


func _ovation() -> void:
	ovation = true
	for sx: float in [-1.0, 1.0]:
		world.collision.add_block(Vector2(sx * half.x * 0.75 - 0.4, -half.y), Vector2(sx * half.x * 0.75 + 0.4, half.y + 2.0), 2.0, "ovation")
	world.emit("ovation", {"actor": brain.actor.id, "x": half.x * 0.75})
