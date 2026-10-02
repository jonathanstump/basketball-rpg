class_name TollGimmick
extends RefCounted
## The Toll (spec §9.3): "Pay Up" takes 10% of your carried tokens into the
## booth on his back; strip him while the booth glows and they spill back
## out. Toll Gate raises a barrier between you and the hoop for 6 s. Phase 2
## "Rush Hour": headlight beams sweep the court (shot window shrinks inside).

const DT: float = 1.0 / 60.0
const GLOW_S: float = 6.0
const BEAM_EVERY_S: float = 5.0
const BEAM_SWEEP_S: float = 3.0
const BEAM_HALF_W: float = 1.6

var brain: BossBrain
var world: SimWorld
var booth: int = 0
var glow_until: int = -1
var gate_until: int = -1
var beam_timer_s: float = BEAM_EVERY_S
var beam_left_s: float = 0.0
var beam_x: float = 0.0
var beam_dir: float = 1.0
var half_w: float = 12.0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	half_w = float(JU.a(JU.dict(b.boss, "arena"), "size_m")[0]) * 0.5 if JU.a(JU.dict(b.boss, "arena"), "size_m").size() > 0 else 12.0
	world.sim_event.connect(_on_event)


func booth_glowing() -> bool:
	return world.frame < glow_until and booth > 0


func on_step(b: BossBrain) -> bool:
	b.actor.flags["booth_glow"] = booth_glowing()
	if gate_until >= 0 and world.frame >= gate_until:
		gate_until = -1
		world.collision.remove_tag("toll_gate")
		world.emit("toll_gate_down", {"actor": b.actor.id})
	if b.phase >= 2:
		_tick_beams(b)
	return false


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"hit_resolved":
			var att: int = int(ev["attacker"])
			var tgt: int = int(ev["target"])
			if att == brain.actor.id and str(ev["move"]) == "pay_up" and str(ev["result"]) == "hit":
				_pay_up(tgt)
			elif tgt == brain.actor.id and str(ev["result"]) == "strip" and booth_glowing():
				spill()
		"steal":
			if int(ev.get("target", 0)) == brain.actor.id and booth_glowing():
				spill()
		"arena_event":
			if int(ev["actor"]) == brain.actor.id and str(ev["event"]) == "toll_gate":
				raise_gate(JU.f(ev["move"] as Dictionary, "duration_s", 6.0))
		"duel_victory":
			if booth > 0:
				spill()
		"duel_phase_changed", "duel_check":
			if gate_until >= 0:
				gate_until = world.frame
				on_step(brain)


func _pay_up(target_id: int) -> void:
	var pct: float = JU.f(DataDB.move(JU.s(brain.boss, "id"), "pay_up"), "toll_pct", 0.10)
	var amount: int = int(floor(float(GameState.tokens) * pct))
	if world.actor_by_id(target_id) == null:
		return
	GameState.add_tokens(-amount)
	booth += amount
	glow_until = world.frame + int(GLOW_S * 60.0)
	world.emit("toll_paid", {"actor": brain.actor.id, "target": target_id, "amount": amount, "booth": booth, "pos": brain.actor.pos})


func spill() -> void:
	var amount: int = booth
	booth = 0
	glow_until = -1
	GameState.add_tokens(amount)
	world.emit("toll_spilled", {"actor": brain.actor.id, "amount": amount, "pos": brain.actor.pos})


func raise_gate(duration_s: float) -> void:
	## A barrier across the court between you and the hoop (axis-aligned:
	## the arena hoop sits on -Z, so the wall runs along X).
	var t: SimActor = brain.target
	if t == null or brain.hoop == null:
		return
	var hz: float = brain.hoop.floor_point().z
	var z: float = (t.pos.z + hz) * 0.5
	if absf(t.pos.z - z) < 1.6:
		z = t.pos.z - 1.6 * signf(t.pos.z - hz)
	world.collision.remove_tag("toll_gate")
	world.collision.add_block(Vector2(t.pos.x - 3.5, z - 0.3), Vector2(t.pos.x + 3.5, z + 0.3), 3.0, "toll_gate")
	gate_until = world.frame + int(duration_s * 60.0)
	world.emit("toll_gate_up", {"actor": brain.actor.id, "pos": Vector3(t.pos.x, 0, z), "width": 7.0, "duration_s": duration_s})


func _tick_beams(b: BossBrain) -> void:
	if beam_left_s > 0.0:
		beam_left_s -= DT
		beam_x += beam_dir * (half_w * 2.0 / BEAM_SWEEP_S) * DT
		var t: SimActor = b.target
		if t != null and absf(t.pos.x - beam_x) <= BEAM_HALF_W:
			StatusEffects.apply(t, {"glare": 0.25})
		if beam_left_s <= 0.0:
			world.emit("headlight_off", {"actor": b.actor.id})
		return
	beam_timer_s -= DT
	if beam_timer_s <= 0.0:
		beam_timer_s = BEAM_EVERY_S
		beam_left_s = BEAM_SWEEP_S
		beam_dir = 1.0 if world.rng.randf() < 0.5 else -1.0
		beam_x = -half_w * beam_dir
		world.emit("headlight_on", {"actor": b.actor.id, "x": beam_x, "dir": beam_dir, "sweep_s": BEAM_SWEEP_S, "half_w": half_w})
