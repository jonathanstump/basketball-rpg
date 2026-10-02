class_name CoopGimmick
extends RefCounted
## The Coop King (spec §9.3): SWARM. A heavy hit disperses his body (walk
## through him; he's untouchable) and he reforms in 2 s. Whenever he throws
## or passes, the glowing core is exposed for 3 s: hits do triple damage and
## break his composure. Split Flock (T2): a decoy half-body for 8 s.
## Phase 2 "Takeoff": the roof edges crumble (arena shrinks).

const DISPERSE_S: float = 2.0
const CORE_S: float = 3.0
const CORE_MULT: float = 3.0
const DECOY_S: float = 8.0

var brain: BossBrain
var world: SimWorld
var dispersed_until: int = -1
var core_until: int = -1
var decoy: SimActor = null
var decoy_until: int = -1
var crumbled: bool = false
var half: Vector2 = Vector2(9, 8)


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	var size: Array = JU.a(JU.dict(b.boss, "arena"), "size_m")
	if size.size() >= 2:
		half = Vector2(float(size[0]), float(size[1])) * 0.5
	world.sim_event.connect(_on_event)


func core_exposed() -> bool:
	return world.frame < core_until


func on_step(b: BossBrain) -> bool:
	var a: SimActor = b.actor
	var dispersed: bool = world.frame < dispersed_until
	a.flags["ghost"] = dispersed
	a.flags["damage_taken_mult"] = CORE_MULT if core_exposed() else 1.0
	if dispersed:
		a.invulnerable = true
		a.anim_state = "dispersed"
		b.runner.interrupt()
		return true
	if decoy != null and world.frame >= decoy_until:
		_clear_decoy()
	if b.phase >= 2 and not crumbled:
		crumbled = true
		for sx: float in [-1.0, 1.0]:
			world.collision.add_block(Vector2(sx * (half.x - 1.0) - 1.0, -half.y), Vector2(sx * (half.x - 1.0) + 1.0, half.y), 2.0, "crumble")
		world.emit("roof_crumble", {"actor": a.id})
	return false


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"ball_thrown", "pass_released", "lob_released":
			if int(ev.get("actor", 0)) == brain.actor.id:
				core_until = world.frame + int(CORE_S * 60.0)
				world.emit("core_exposed", {"actor": brain.actor.id, "s": CORE_S})
		"hit_resolved":
			if int(ev["target"]) != brain.actor.id or str(ev["result"]) != "hit":
				return
			if core_exposed():
				var c: Composure = brain.actor.composure
				if c != null and c.broken == "":
					c.force_break("shook")
					world.emit("composure_broken", {"actor": brain.actor.id, "kind": "shook"})
				world.emit("popup", {"text": "CORE HIT!", "pos": brain.actor.pos, "style": "big"})
			elif str(ev.get("weight", "")) == "heavy" and world.frame >= dispersed_until:
				dispersed_until = world.frame + int(DISPERSE_S * 60.0)
				world.emit("swarm_dispersed", {"actor": brain.actor.id, "pos": brain.actor.pos, "s": DISPERSE_S})
		"mirror_requested":
			if int(ev["actor"]) == brain.actor.id and str(ev["move"]) == "split_flock":
				_spawn_decoy()
		"duel_victory":
			_clear_decoy()


func _spawn_decoy() -> void:
	_clear_decoy()
	var split: BossSplit = BossSplit.new(brain)
	split.spawn(1, "flock_lunge", "coop_decoy", Vector2(0.8, 3.0), 0.7)
	decoy = split.parts[0]
	decoy_until = world.frame + int(DECOY_S * 60.0)


func _clear_decoy() -> void:
	if decoy != null:
		decoy.alive = false
		world.emit("car_removed", {"actor": decoy.id})
		world.remove_actor(decoy)
		decoy = null
