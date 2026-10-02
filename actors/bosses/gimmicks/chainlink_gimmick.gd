class_name ChainLinkGimmick
extends RefCounted
## Chain Link (spec §9.3, The Cage): SHRINKING CAGE. Every 30 s (20 s in
## Phase 2 "Electrified") the walls move in 1.5 m; touching the fence
## shocks. Strip him and he answers with "No Call" (unblockable counter).

const DT: float = 1.0 / 60.0
const STEP_M: float = 1.5
const MIN_HALF: Vector2 = Vector2(5.0, 5.0)
const SHOCK_PCT: float = 0.04

var brain: BossBrain
var world: SimWorld
var half0: Vector2 = Vector2(9, 8)
var inset: float = 0.0
var shrink_s: float = 30.0
var shock_cd: int = 0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	var size: Array = JU.a(JU.dict(b.boss, "arena"), "size_m")
	if size.size() >= 2:
		half0 = Vector2(float(size[0]), float(size[1])) * 0.5 + Vector2(ArenaBuilder.APRON_M, ArenaBuilder.APRON_M)
	world.sim_event.connect(_on_event)


func cage_half() -> Vector2:
	return Vector2(maxf(MIN_HALF.x, half0.x - inset), maxf(MIN_HALF.y, half0.y - inset))


func on_step(b: BossBrain) -> bool:
	var live: bool = b.duel_state() in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]
	if live:
		shrink_s -= DT
		if shrink_s <= 0.0:
			shrink_s = 20.0 if b.phase >= 2 else 30.0
			inset += STEP_M
			_build_walls()
			world.emit("cage_shrink", {"actor": b.actor.id, "half": cage_half()})
	shock_cd -= 1
	var t: SimActor = b.target
	if t != null and inset > 0.0:
		var h: Vector2 = cage_half()
		if absf(t.pos.x) > h.x - 0.6 or absf(t.pos.z) > h.y - 0.6:
			t.pos.x = clampf(t.pos.x, -h.x + 0.7, h.x - 0.7)
			t.pos.z = clampf(t.pos.z, -h.y + 0.7, h.y - 0.7)
			if shock_cd <= 0:
				shock_cd = 30
				b.combat.damage.apply_raw(t, t.hp_max * SHOCK_PCT)
				world.emit("fence_shock", {"actor": t.id, "pos": t.pos})
	return false


func _build_walls() -> void:
	world.collision.remove_tag("cage")
	var h: Vector2 = cage_half()
	var t: float = 0.3
	world.collision.add_block(Vector2(-h.x - t, -h.y - t), Vector2(h.x + t, -h.y), 4.0, "cage")
	world.collision.add_block(Vector2(-h.x - t, h.y), Vector2(h.x + t, h.y + t), 4.0, "cage")
	world.collision.add_block(Vector2(-h.x - t, -h.y), Vector2(-h.x, h.y), 4.0, "cage")
	world.collision.add_block(Vector2(h.x, -h.y), Vector2(h.x + t, h.y), 4.0, "cage")


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"hit_resolved":
			if int(ev["target"]) == brain.actor.id and str(ev["result"]) == "strip" and not brain.runner.running:
				brain.run_event_move("no_call")
		"steal":
			if int(ev.get("target", 0)) == brain.actor.id:
				brain.run_event_move("no_call")
		"duel_phase_changed":
			inset = 0.0
			world.collision.remove_tag("cage")
			shrink_s = 20.0
		"duel_victory":
			world.collision.remove_tag("cage")
