class_name HooperStyle
extends RefCounted
## Hooper module for style and resources (spec §5.6, §7.8): Quarter Water,
## Taunt, Bag Moves (LT, costs Hype) and Takeover (LT+RT at full Hype).

const DT: float = 1.0 / 60.0

var combat: CombatSystem
var balls: BallSystem
var actor_id: int = 0
var bag_impl: String = ""


func _init(c: CombatSystem, b: BallSystem, a: SimActor) -> void:
	combat = c
	balls = b
	actor_id = a.id
	c.world.sim_event.connect(_on_event)


func try_start(h: Hooper) -> bool:
	var a: SimActor = h.actor
	var inp: ActorInput = a.input
	if not a.on_ground:
		return false
	if inp.peek("bag_move") and (inp.peek("interact") or inp.is_held("interact")):
		if a.hype.value + 0.001 >= float(a.flags.get("takeover_cost", 100.0)) and not bool(a.flags.get("takeover", false)):
			inp.pressed("bag_move")
			inp.pressed("interact")
			return h.begin("takeover", a.forward(), self)
	if inp.peek("bag_move"):
		inp.pressed("bag_move")
		var bag_id: String = str(a.flags.get("bag_move", ""))
		var bag: Dictionary = DataDB.item("bag_moves", bag_id)
		if bag.is_empty():
			return false
		if not a.hype.spend(JU.f(bag, "hype") * float(a.flags.get("bag_cost_mult", 1.0))):
			combat.world.emit("hype_short", {"actor": a.id, "need": JU.f(bag, "hype")})
			return false
		bag_impl = JU.s(bag, "impl")
		return h.begin(BagMoves.action_for(h, bag_impl), a.forward(), self)
	if inp.peek("quarter_water"):
		inp.pressed("quarter_water")
		if int(a.flags.get("qw", 0)) <= 0:
			combat.world.emit("qw_empty", {"actor": a.id})
			return false
		a.flags["qw"] = int(a.flags["qw"]) - 1
		combat.world.emit("qw_used", {"actor": a.id, "left": a.flags["qw"]})
		return h.begin("quarter_water", a.forward(), self)
	if inp.peek("taunt"):
		inp.pressed("taunt")
		return h.begin("taunt", a.forward(), self)
	return false


func on_frame(h: Hooper) -> void:
	var a: SimActor = h.actor
	a.desired_vel = Vector3.ZERO
	match h.action:
		"quarter_water":
			if h.action_frame == JU.i(h.action_move, "heal_frame", 36):
				var pct: float = float(a.flags.get("qw_heal_pct", 0.35))
				var amt: float = a.hp_max * pct
				a.hp = minf(a.hp_max, a.hp + amt)
				a.hype.add(float(a.flags.get("qw_hype", 0.0)))
				combat.world.emit("healed", {"actor": a.id, "amount": amt})
		"taunt":
			if h.action_frame == h.action_total:
				a.hype.gain("taunt", float(a.flags.get("taunt_hype_mult", 1.0)))
				combat.world.emit("taunt_completed", {"actor": a.id})
		"takeover":
			a.invulnerable = true
			if h.action_frame == h.action_total:
				_activate_takeover(a, h)
		_:
			if h.action.begins_with("bag_"):
				BagMoves.frame(h, bag_impl, combat, balls, self)


func tick(h: Hooper) -> void:
	var a: SimActor = h.actor
	BagMoves.tick(h, combat)
	PlayerBuffs.tick(a, combat.world.frame, DT)
	if bool(a.flags.get("takeover", false)):
		h.regen_mult = JU.f(JU.dict(DataDB.tuning("combat"), "takeover"), "wind_regen_mult", 1.5)
		if combat.world.frame >= int(a.flags.get("takeover_until", 0)):
			a.flags["takeover"] = false
			h.regen_mult = 1.0
			combat.world.emit("takeover_ended", {"actor": a.id})


func _activate_takeover(a: SimActor, _h: Hooper) -> void:
	var tk: Dictionary = JU.dict(DataDB.tuning("combat"), "takeover")
	var dur: float = (JU.f(tk, "duration_s", 12.0) + float(a.flags.get("takeover_bonus_s", 0.0))) * float(a.flags.get("takeover_mult", 1.0))
	a.hype.value = 0.0
	a.flags["takeover"] = true
	a.flags["takeover_until"] = combat.world.frame + int(dur * 60.0)
	combat.world.emit("takeover_started", {"actor": a.id, "duration_s": dur})


func _on_event(ev: Dictionary) -> void:
	if str(ev.get("type", "")) != "shot_made" or int(ev.get("actor", 0)) != actor_id:
		return
	var a: SimActor = combat.world.actor_by_id(actor_id)
	if a == null:
		return
	if bool(a.flags.get("takeover", false)):
		a.flags["takeover_until"] = int(a.flags["takeover_until"]) + int(JU.f(JU.dict(DataDB.tuning("combat"), "takeover"), "make_bonus_s", 2.0) * 60.0)
	if str(ev.get("grade", "")) == "PERFECT":
		a.hype.gain("perfect_shot", float(a.flags.get("hype_gain_mult", 1.0)))
