class_name Hooper
extends RefCounted
## Shared ball-combat controller (spec §15.5) used by the player, Pickup
## Challengers, Deuce, Pops and Midnight P1. Reads only `actor.input`, so a
## human and an AI brain drive the exact same code path.
## Actions are frame-data driven (data/moves/hooper.json); frame 1 is the
## first frame of an action, total = startup + active + recovery.

const DT: float = 1.0 / 60.0
const FRAME_FLAGS: PackedStringArray = ["ankle_window", "read_window", "parry_window", "guarding", "rejecting"]
const REACTIONS: PackedStringArray = ["hitstun", "hitstun_heavy", "knockdown", "guard_break", "off_balance", "player_shook", "death"]

var actor: SimActor
var world: SimWorld
var moves: Dictionary = {}
var tuning: Dictionary = {}
var modules: Array[RefCounted] = []   # extra action modules (ball, combat); see add_module()

var action: String = ""
var action_frame: int = 0
var action_move: Dictionary = {}
var action_dir: Vector3 = Vector3.ZERO
var action_total: int = 0
var action_owner: RefCounted = null   # module handling the current action

var sprinting: bool = false
var lock_target: SimActor = null
var face_point: Vector3 = Vector3.INF   # boss duels: with the ball, square up to the rim (R5)
var stepback_timer_s: float = 0.0
var guarding: bool = false
var regen_mult: float = 1.0
var speed_mult: float = 1.0
var coyote_frames: int = 5
var jump_height_m: float = 1.2


func _init(a: SimActor, w: SimWorld) -> void:
	actor = a
	world = w
	moves = DataDB.moves_for("hooper")
	tuning = DataDB.tuning("player")
	coyote_frames = JU.i(tuning, "coyote_frames", 5)
	actor.input.buffer.window = JU.i(tuning, "input_buffer_frames", 8)
	refresh_stats()


func refresh_stats() -> void:
	actor.hp_max = StatFormulas.heart_max(actor.stat("heart"))
	actor.hp = actor.hp_max
	actor.wind.configure(StatFormulas.wind_max(actor.stat("wind")), tuning)
	actor.poise = StatFormulas.poise(actor.stat("body"))
	jump_height_m = StatFormulas.jump_height(actor.stat("bounce"), JU.f(tuning, "jump_height_m", 1.2))


func add_module(m: RefCounted) -> void:
	modules.append(m)


func step() -> void:
	if not actor.alive:
		actor.desired_vel = Vector3.ZERO
		return
	actor.invulnerable = world.frame < int(actor.flags.get("wakeup_until", -1))
	for f: String in FRAME_FLAGS:
		actor.flags[f] = false
	guarding = false
	stepback_timer_s = maxf(0.0, stepback_timer_s - DT)
	for m: RefCounted in modules:
		if m.has_method("tick"):
			m.call("tick", self)
	if action != "":
		_tick_action()
	if action == "":
		_free_state()
	actor.wind.tick(DT, guarding, regen_mult * float(actor.flags.get("buff_wind_regen_mult", 1.0)))
	_update_anim()


# ------------------------------------------------------------ action core

func move_data(id: String) -> Dictionary:
	var v: Variant = moves.get(id, {})
	return v if v is Dictionary else {}


func begin(id: String, dir: Vector3 = Vector3.ZERO, owner: RefCounted = null, spend_wind: bool = true) -> bool:
	var m: Dictionary = move_data(id)
	if m.is_empty():
		push_warning("Hooper: unknown move " + id)
		return false
	var cost: float = JU.f(m, "wind")
	if JU.s(m, "primitive") == "dodge":
		cost *= float(actor.flags.get("dodge_wind_mult", 1.0))
	if spend_wind and cost > 0.0 and not actor.wind.spend(cost * _wind_cost_mult()):
		return false
	action = id
	action_frame = 0
	action_move = m
	action_dir = dir.normalized() if dir.length() > 0.001 else actor.forward()
	action_total = JU.i(m, "startup") + JU.i(m, "active") + JU.i(m, "recovery")
	if JU.s(m, "primitive") == "dodge":
		action_total += int(actor.flags.get("recovery_frames_add", 0.0))
	action_owner = owner
	sprinting = false
	world.emit("action_started", {"actor": actor.id, "move": id})
	if owner != null and owner.has_method("on_begin"):
		owner.call("on_begin", self)
	_tick_action()
	return true


func end_action() -> void:
	var owner: RefCounted = action_owner
	var ended: String = action
	action = ""
	action_frame = 0
	action_move = {}
	action_owner = null
	actor.steer_locked = false
	if ended == "knockdown":
		## Wake-up i-frames so a knockdown can't chain into another.
		actor.flags["wakeup_until"] = world.frame + int(JU.f(tuning, "wakeup_iframes", 40.0))
	if owner != null and owner.has_method("on_end"):
		owner.call("on_end", self, ended)


func in_active() -> bool:
	var s: int = JU.i(action_move, "startup")
	return action_frame > s and action_frame <= s + JU.i(action_move, "active")


func in_recovery() -> bool:
	return action_frame > JU.i(action_move, "startup") + JU.i(action_move, "active")


func _tick_action() -> void:
	action_frame += 1
	var prim: String = JU.s(action_move, "primitive")
	if action_owner != null:
		action_owner.call("on_frame", self)
	elif prim == "dodge":
		_dodge_frame()
	elif prim == "recovery" or prim == "reaction":
		actor.desired_vel = Vector3.ZERO
		if action == "knockdown":
			actor.flags["downed"] = action_frame < action_total - 20
		if action == "death":
			action_frame = mini(action_frame, 2)
	if action != "" and action_frame >= action_total:
		end_action()


# ------------------------------------------------------------ free state

func _free_state() -> void:
	var inp: ActorInput = actor.input
	if StatusEffects.has(actor, "rooted") or StatusEffects.has(actor, "frozen") or StatusEffects.has(actor, "shock"):
		actor.desired_vel = Vector3.ZERO
		return
	for m: RefCounted in modules:
		if m.call("try_start", self):
			return
	if actor.on_ground and inp.peek("dodge") and actor.wind.can_act():
		inp.pressed("dodge")
		_start_dodge()
		return
	if inp.peek("jump") and can_jump():
		inp.pressed("jump")
		jump(jump_height_m)
	if actor.landed and not sprinting and action == "":
		begin("land")
		return
	_locomotion()


func can_jump() -> bool:
	return actor.on_ground or actor.frames_since_ground <= coyote_frames


func jump(height: float) -> void:
	actor.vel.y = sqrt(2.0 * world.gravity * maxf(0.1, height))
	actor.on_ground = false
	actor.frames_since_ground = 999
	world.emit("jumped", {"actor": actor.id})


func _locomotion() -> void:
	var inp: ActorInput = actor.input
	var dir: Vector3 = inp.move3()
	var mag: float = minf(1.0, dir.length())
	sprinting = sprinting and inp.is_held("dodge")
	if inp.is_held("dodge") and mag > 0.1 and actor.wind.value > 0.0 and actor.on_ground:
		sprinting = true
	if actor.wind.value <= 0.0:
		sprinting = false
	var speed: float = 0.0
	if mag > 0.1:
		if sprinting:
			speed = JU.f(tuning, "sprint_speed", 8.5)
			if not (bool(actor.flags.get("free_sprint", false)) and world.nearest_hostile(actor, 15.0) == null):
				actor.wind.drain(JU.f(tuning, "sprint_wind_per_s", 12.0) * DT * _sprint_cost_mult())
		elif mag >= JU.f(tuning, "run_stick_threshold", 0.6):
			speed = JU.f(tuning, "run_speed", 6.0)
		else:
			speed = JU.f(tuning, "walk_speed", 3.5)
	speed *= speed_mult * float(actor.flags.get("buff_speed_mult", 1.0))
	if StatusEffects.has(actor, "slow"):
		speed *= 0.6
	if world.frame < int(actor.flags.get("hustle_until", -1)):
		speed *= 1.1
	var target_vel: Vector3 = dir.normalized() * speed if mag > 0.1 else Vector3.ZERO
	if actor.on_ground:
		actor.desired_vel = target_vel
	else:
		actor.desired_vel = actor.desired_vel.lerp(target_vel, 0.08)
	var turn: float = JU.f(tuning, "turn_speed_rad_s", 14.0) * DT
	if face_point != Vector3.INF and actor.has_ball and not sprinting:
		actor.turn_toward(face_point - actor.pos, turn)
	elif lock_target != null and lock_target.alive and not sprinting:
		actor.turn_toward(lock_target.pos - actor.pos, turn)
	elif mag > 0.1:
		actor.turn_toward(dir, turn)


# ------------------------------------------------------------ dodge

func _start_dodge() -> void:
	var dir: Vector3 = actor.input.move3()
	if dir.length() < 0.1:
		dir = -actor.forward()
	var id: String = "defensive_slide"
	if actor.has_ball:
		id = "stepback" if dir.normalized().dot(actor.forward()) < -0.5 else "crossover"
	begin(id, dir)


func iframe_window() -> Vector2i:
	var s: int = JU.i(action_move, "startup")
	return Vector2i(s + 1, s + JU.i(action_move, "active"))


func ankle_window() -> Vector2i:
	## Crossover frames 3..window_end (tuning/combat ankle_breaker) + Handles
	## bonus (+0.2f/pt above 10, max +6).
	var start: int = JU.i(action_move, "startup") + 1
	var end: int = JU.i(JU.dict(DataDB.tuning("combat"), "ankle_breaker"), "window_end", 12) + int(StatFormulas.ankle_bonus_frames(actor.stat("handles")) + float(actor.flags.get("ankle_bonus", 0)))
	var mult: float = float(actor.flags.get("ankle_window_mult", 1.0))
	end = start + int(round(float(end - start) * mult))
	return Vector2i(start, end)


func _dodge_frame() -> void:
	var w: Vector2i = iframe_window()
	actor.invulnerable = action_frame >= w.x and action_frame <= w.y
	if actor.has_ball and (action == "crossover" or action == "stepback"):
		var aw: Vector2i = ankle_window()
		actor.flags["ankle_window"] = action_frame >= aw.x and action_frame <= aw.y
	elif action == "defensive_slide":
		actor.flags["read_window"] = actor.invulnerable
	if action_frame <= w.y:
		var speed: float = JU.f(action_move, "distance_m") * float(actor.flags.get("dodge_dist_mult", 1.0)) / (float(w.y) * DT)
		actor.desired_vel = action_dir * speed
	else:
		actor.desired_vel = action_dir * 1.0
	if action == "stepback":
		stepback_timer_s = JU.f(action_move, "stepback_window_s", 0.8)
		if lock_target != null:
			actor.turn_toward(lock_target.pos - actor.pos, 1.0)
	elif lock_target == null:
		actor.turn_toward(action_dir, 0.5)


# ------------------------------------------------------------ reactions

func on_hit(res: Dictionary) -> void:
	var r: String = str(res.get("result", ""))
	if bool(res.get("killed", false)) or not actor.alive:
		_react("death")
		return
	match r:
		"strip", "deflect":
			if action == "hands_up":
				end_action()   # successful parry cancels whiff recovery
		"guard_break":
			_react("guard_break")
		"hit":
			if actor.hyper_armor or bool(res.get("no_flinch", false)):
				return
			if bool(res.get("knockdown", false)):
				_react("knockdown")
			elif float(res.get("damage", 0.0)) >= actor.poise or str(res.get("weight", "")) == "heavy":
				_react("hitstun_heavy" if str(res.get("weight", "")) == "heavy" else "hitstun")


func on_parried(_res: Dictionary) -> void:
	if action != "" and not REACTIONS.has(action):
		_react("off_balance")


func _react(id: String) -> void:
	if action == "death":
		return
	if action != "":
		end_action()
	sprinting = false
	begin(id, -actor.forward(), null, false)
	if id == "death":
		actor.anim_state = "death"


func is_reacting() -> bool:
	return REACTIONS.has(action)


# ------------------------------------------------------------ helpers

func _wind_cost_mult() -> float:
	return float(actor.flags.get("wind_cost_mult", 1.0))


func _sprint_cost_mult() -> float:
	return float(actor.flags.get("sprint_cost_mult", 1.0))


func _update_anim() -> void:
	actor.anim_frame = action_frame
	if action != "":
		actor.anim_state = action
		return
	if not actor.on_ground:
		actor.anim_state = "jump" if actor.vel.y > 0.0 else "fall"
		return
	var sp: float = Vector2(actor.desired_vel.x, actor.desired_vel.z).length()
	actor.anim_speed = sp
	if sp < 0.2:
		actor.anim_state = "dribble_idle" if actor.has_ball else "idle"
	elif sprinting:
		actor.anim_state = "sprint"
	elif sp > JU.f(tuning, "walk_speed", 3.5) + 0.5:
		actor.anim_state = "run"
	else:
		actor.anim_state = "walk"
