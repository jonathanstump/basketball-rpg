class_name ExpressGimmick
extends RefCounted
## The Express (spec §9.3): Phase 2 "Decouple" — two rear cars break off and
## attack on their own. Shared HP: damage to a car comes off the Express.
## T5 "Rush Hour Crowd": commuter silhouettes fill lanes (block movement only).

const CROWD_S: float = 12.0

var brain: BossBrain
var world: SimWorld
var split: BossSplit
var cars: Array[SimActor]:
	get:
		return split.parts
var crowd_until: int = -1


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	split = BossSplit.new(b)
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	if crowd_until >= 0 and world.frame >= crowd_until:
		crowd_until = -1
		world.collision.remove_tag("crowd")
		world.emit("crowd_cleared", {"actor": b.actor.id})
	split.sync()
	return false


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"duel_phase_changed":
			if int(ev.get("phase", 1)) >= 2 and split.parts.is_empty():
				split.spawn(2, "car_charge", "express_car", Vector2(1.0, 3.0))
		"hit_resolved":
			split.on_hit(ev)
		"arena_event":
			if int(ev["actor"]) == brain.actor.id and str(ev["event"]) == "rush_hour_crowd":
				crowd()
		"duel_victory":
			split.clear()


func crowd() -> void:
	## Commuters stand in two lanes across the court for a while.
	world.collision.remove_tag("crowd")
	var size: Array = JU.a(JU.dict(brain.boss, "arena"), "size_m")
	var half: Vector2 = Vector2(float(size[0]), float(size[1])) * 0.5
	for lane: float in [-half.x * 0.5, half.x * 0.5]:
		for k: int in 4:
			var z: float = -half.y * 0.6 + float(k) * half.y * 0.45
			world.collision.add_block(Vector2(lane - 0.4, z - 0.4), Vector2(lane + 0.4, z + 0.4), 1.9, "crowd")
			world.emit("commuter", {"pos": Vector3(lane, 0, z)})
	crowd_until = world.frame + int(CROWD_S * 60.0)
