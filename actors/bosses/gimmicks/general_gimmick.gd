class_name GeneralGimmick
extends RefCounted
## The General (spec §9.3): CANNONS on the ramparts. A Volley lights their
## fuses for 2.5 s; hit a lit cannon with a pass and it swings round and fires
## at him (big composure damage). Phase 2 "Dismount": the horse splits off
## and charges on its own (shared HP); the rider keeps the ball.

const FUSE_S: float = 2.5
const BACKFIRE_COMPOSURE: float = 90.0
const BACKFIRE_DAMAGE_PCT: float = 0.04

var brain: BossBrain
var world: SimWorld
var cannons: Array[Vector3] = []
var lit_until: int = -1
var backfires: int = 0
var split: BossSplit


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	split = BossSplit.new(b)
	var size: Array = JU.a(JU.dict(b.boss, "arena"), "size_m")
	var half: Vector2 = Vector2(float(size[0]), float(size[1])) * 0.5 if size.size() >= 2 else Vector2(9, 8)
	for sx: float in [-1.0, 1.0]:
		for z: float in [-half.y * 0.4, half.y * 0.4]:
			cannons.append(Vector3(sx * (half.x + 1.2), 0, z))
	world.sim_event.connect(_on_event)


func fuses_lit() -> bool:
	return world.frame < lit_until


func on_step(b: BossBrain) -> bool:
	split.sync()
	if not fuses_lit():
		return false
	for ball: SimBall in b.balls.balls:
		if ball.state != SimBall.State.PASS:
			continue
		var passer: SimActor = world.actor_by_id(ball.passer_id)
		if passer == null or passer.team != 0:
			continue
		for i: int in cannons.size():
			if Vector2(ball.pos.x - cannons[i].x, ball.pos.z - cannons[i].z).length() <= 2.2:
				backfire(i)
				return false
	return false


func backfire(i: int) -> void:
	lit_until = -1
	backfires += 1
	var a: SimActor = brain.actor
	if a.composure != null:
		var br: String = a.composure.add(BACKFIRE_COMPOSURE, "stagger")
		if br != "":
			world.emit("composure_broken", {"actor": a.id, "kind": br})
	brain.combat.damage.apply_raw(a, a.hp_max * BACKFIRE_DAMAGE_PCT)
	world.emit("cannon_backfire", {"actor": a.id, "cannon": i, "from": cannons[i], "pos": a.pos})
	world.emit("popup", {"text": "BACKFIRE!", "pos": a.pos, "style": "big"})


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"arena_event":
			if int(ev["actor"]) == brain.actor.id and str(ev["event"]) in ["volley", "siege"]:
				lit_until = world.frame + int(FUSE_S * 60.0)
				world.emit("fuses_lit", {"actor": brain.actor.id, "cannons": cannons.duplicate(), "s": FUSE_S})
		"duel_phase_changed":
			if int(ev.get("phase", 1)) >= 2 and split.parts.is_empty():
				split.spawn(1, "horse_charge", "general_horse", Vector2(1.2, 2.6))
		"hit_resolved":
			split.on_hit(ev)
		"duel_victory":
			split.clear()
