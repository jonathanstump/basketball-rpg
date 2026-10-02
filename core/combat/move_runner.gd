class_name MoveRunner
extends RefCounted
## Runs one data-driven move for a non-hooper actor (enemies, critters,
## bosses): telegraph during startup, hitbox(es) on active frames, movement
## for lunges/charges, then recovery. Primitive behavior lives in
## MovePrimitives so bosses (M5) extend the same runner.

var actor: SimActor
var world: SimWorld
var combat: CombatSystem
var move: Dictionary = {}
var frame: int = 0
var total: int = 0
var running: bool = false
var dir: Vector3 = Vector3.FORWARD
var target: SimActor = null
var state: Dictionary = {}          # per-move scratch for primitives
var speed_mult: float = 1.0         # tier/aggression recovery scaling


func _init(a: SimActor, w: SimWorld, c: CombatSystem) -> void:
	actor = a
	world = w
	combat = c


func start(m: Dictionary, tgt: SimActor = null) -> void:
	move = m
	target = tgt
	frame = 0
	running = true
	state = {}
	var rec: int = int(round(float(JU.i(m, "recovery")) * speed_mult))
	var extra_hits: int = 1 if JU.b(m, "combo") and a_tier() >= 5 else 0
	total = JU.i(m, "startup") + maxi(JU.i(m, "active"), JU.i(m, "hit_gap") * (JU.i(m, "hits", 1) + extra_hits)) + rec
	dir = actor.forward()
	if tgt != null:
		var to: Vector3 = tgt.pos - actor.pos
		to.y = 0.0
		if to.length() > 0.01:
			dir = to.normalized()
			actor.face_dir(dir)
	actor.flags["move"] = JU.s(m, "id")
	actor.flags["unblockable_flash"] = JU.b(m, "unblockable")
	world.emit("move_started", {"actor": actor.id, "move": JU.s(m, "id"), "unblockable": JU.b(m, "unblockable"), "primitive": JU.s(m, "primitive")})


func a_tier() -> int:
	return actor.tier if actor.kind == "enemy" else 1


func interrupt() -> void:
	if not running:
		return
	running = false
	combat.clear_owner(actor.id)
	_clear_flags()


func startup() -> int:
	return JU.i(move, "startup")


func active() -> int:
	return JU.i(move, "active")


func in_startup() -> bool:
	return running and frame <= startup()


func in_active() -> bool:
	return running and frame > startup() and frame <= startup() + active()


func step() -> bool:
	## Advances one frame; returns true while the move is still running.
	if not running:
		return false
	frame += 1
	actor.flags["telegraph"] = frame <= startup()
	if frame > startup():
		actor.flags["unblockable_flash"] = false
	actor.desired_vel = Vector3.ZERO
	MovePrimitives.frame(self)
	if frame <= startup():
		actor.anim_state = JU.s(move, "anim_windup", "windup")
	elif frame <= startup() + active():
		actor.anim_state = JU.s(move, "anim", "attack")
	else:
		actor.anim_state = "recover"
	actor.anim_frame = frame
	if frame >= total:
		running = false
		_clear_flags()
	return running


func _clear_flags() -> void:
	actor.flags["telegraph"] = false
	actor.flags["unblockable_flash"] = false
	actor.flags.erase("move")
	actor.hyper_armor = bool(actor.flags.get("base_hyper_armor", false))


func make_hitbox(volume_dict: Dictionary, frames: int) -> Hitbox:
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = actor.id
	hb.team = actor.team
	hb.move_id = JU.s(move, "id")
	hb.volume = HitVolume.from_dict(volume_dict)
	hb.volume.origin = actor.pos
	hb.volume.yaw = actor.facing
	hb.frames_left = frames
	hb.damage = damage()
	hb.composure = JU.f(move, "composure_dmg", JU.f(move, "composure"))
	hb.kind = "body" if JU.b(move, "body_attack") else "ball"
	hb.unblockable = JU.b(move, "unblockable")
	var parry: String = JU.s(move, "parry", "strip" if hb.kind == "ball" else "deflect")
	hb.parryable = parry != "none"
	hb.weight = JU.s(move, "hit_weight", "medium")
	hb.knockdown = JU.b(move, "knockdown")
	hb.grab = JU.s(move, "primitive") == "grab"
	hb.break_kind = "stagger"
	hb.status = JU.dict(move, "status")
	if JU.b(move, "steal"):
		hb.tags["steal"] = true
	if JU.b(move, "snatch"):
		hb.tags["snatch_pct"] = float(actor.flags.get("snatch_pct", 0.05))
	return combat.add(hb)


func damage() -> float:
	var base: float = JU.f(move, "damage")
	if base <= 0.0:
		base = float(actor.flags.get("base_damage", 20.0)) * JU.f(move, "dmg_mult", 1.0)
	var mult: float = float(actor.flags.get("damage_mult", 1.0))
	if world.frame < int(actor.flags.get("aura_until", -1)):
		mult *= 1.25
	return DamageMath.enemy_damage(base, actor.tier, GameState.ng_cycle, mult)
