class_name TrainingDummy
extends RefCounted
## Training dummy (spec §16 M3): a tall rec-center dummy with a composure bar.
## "passive" just takes hits; "attack" cycles a strippable swipe, a
## deflectable shoulder check and an unblockable red slam so parries, ankle
## breakers and dodges can be practiced. Heals fully 3 s after damage.

const DT: float = 1.0 / 60.0

var actor: SimActor
var world: SimWorld
var runner: MoveRunner
var mode: String = "attack"
var cycle: PackedStringArray = ["dummy_swipe", "dummy_shove", "dummy_heavy"]
var idx: int = 0
var cooldown_s: float = 1.5
var stun_frames: int = 0
var since_hit_s: float = 99.0
var trigger_range: float = 3.2
var target: SimActor = null


static func spawn(w: SimWorld, c: CombatSystem, pos: Vector3, mode_v: String = "attack") -> TrainingDummy:
	var a: SimActor = SimActor.new()
	a.kind = "enemy"
	a.archetype = "training_dummy"
	a.display_name = "Training Dummy"
	a.team = 1
	a.pos = pos
	a.radius = 0.45
	a.height = 1.9
	a.hp_max = 600.0
	a.hp = 600.0
	a.poise = 0.0
	a.contest_radius = 1.6
	a.flags["cannot_die"] = true
	w.add_actor(a)
	a.set_composure(120.0, 1)
	var d: TrainingDummy = TrainingDummy.new()
	d.actor = a
	d.world = w
	d.mode = mode_v
	d.runner = MoveRunner.new(a, w, c)
	a.controller = d
	return d


func step() -> void:
	since_hit_s += DT
	if since_hit_s > 3.0:
		actor.hp = actor.hp_max
	if target == null or not target.alive:
		target = world.nearest_hostile(actor, 30.0)
	actor.flags["downed"] = stun_frames > 0 and bool(actor.flags.get("knocked", false))
	if stun_frames > 0:
		stun_frames -= 1
		actor.desired_vel = Vector3.ZERO
		actor.anim_state = "knockdown" if bool(actor.flags.get("knocked", false)) else "hit"
		if stun_frames == 0:
			actor.flags["knocked"] = false
		return
	if actor.is_broken():
		actor.desired_vel = Vector3.ZERO
		actor.anim_state = "hit"
		return
	if runner.step():
		return
	actor.anim_state = "idle"
	if target != null:
		actor.turn_toward(target.pos - actor.pos, 0.1)
	cooldown_s -= DT
	if mode == "attack" and target != null and cooldown_s <= 0.0 and actor.dist_to(target) <= trigger_range:
		var m: Dictionary = DataDB.move("dummy", cycle[idx % cycle.size()])
		idx += 1
		runner.start(m, target)
		cooldown_s = 1.2


func on_hit(res: Dictionary) -> void:
	since_hit_s = 0.0
	var r: String = str(res.get("result", ""))
	if r == "hit" and float(res.get("knockdown_s", 0.0)) <= 0.0:
		if bool(res.get("knockdown", false)):
			_stun(90, true)
		elif not runner.in_active():
			runner.interrupt()
			_stun(12, false)


func on_parried(res: Dictionary) -> void:
	runner.interrupt()
	var kd: float = float(res.get("knockdown_s", 0.0))
	if kd > 0.0:
		_stun(int(kd * 60.0), true)
	else:
		_stun(30, false)


func _stun(frames: int, knocked: bool) -> void:
	stun_frames = maxi(stun_frames, frames)
	if knocked:
		actor.flags["knocked"] = true
