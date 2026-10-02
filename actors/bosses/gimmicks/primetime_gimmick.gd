class_name PrimeTimeGimmick
extends RefCounted
## Prime Time (spec §9.3, The Crossroads): REPLAY. Records your last 5 moves;
## "Replay" and "Highlight Reel" throw them back (named on the screen face).
## Tourist flashes blind you 0.8 s after a white flicker cue. Phase 2 "Live":
## three channel bodies; only the one showing LIVE takes damage (rotates).

const DT: float = 1.0 / 60.0
const FLASH_EVERY_S: float = 9.0
const LIVE_SWAP_S: float = 6.0

var brain: BossBrain
var world: SimWorld
var recorded: Array[String] = []
var flash_s: float = FLASH_EVERY_S
var cue_until: int = -1
var split: BossSplit
var live_index: int = 0
var live_s: float = LIVE_SWAP_S


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	split = BossSplit.new(b)
	world.sim_event.connect(_on_event)


func boss_live() -> bool:
	return split.parts.is_empty() or live_index == 0


func on_step(b: BossBrain) -> bool:
	split.sync()
	var t: SimActor = b.target
	if t == null:
		return false
	if cue_until >= 0 and world.frame >= cue_until:
		cue_until = -1
		StatusEffects.apply(t, {"blind": 0.8})
		world.emit("camera_flash", {"actor": t.id})
	flash_s -= DT
	if flash_s <= 0.0:
		flash_s = FLASH_EVERY_S
		cue_until = world.frame + 30
		world.emit("flash_cue", {"actor": b.actor.id})
	if not split.parts.is_empty():
		live_s -= DT
		if live_s <= 0.0:
			live_s = LIVE_SWAP_S
			live_index = (live_index + 1) % (split.parts.size() + 1)
			world.emit("live_channel", {"actor": b.actor.id, "index": live_index})
		b.actor.flags["damage_taken_mult"] = 1.0 if boss_live() else 0.0
	return false


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"action_started":
			if brain.target != null and int(ev["actor"]) == brain.target.id:
				recorded.append(str(ev["move"]))
				if recorded.size() > 5:
					recorded.pop_front()
		"move_started":
			if int(ev["actor"]) == brain.actor.id and str(ev["move"]) in ["replay", "highlight_reel"]:
				world.emit("replay_shown", {"actor": brain.actor.id, "moves": recorded.duplicate()})
		"duel_phase_changed":
			if int(ev.get("phase", 1)) >= 2 and split.parts.is_empty():
				split.spawn(2, "channel_zap", "primetime_channel", Vector2(1.2, 4.0), 0.6)
		"hit_resolved":
			## Hitting a non-LIVE channel does nothing; the LIVE one feeds the boss.
			var tgt: SimActor = world.actor_by_id(int(ev["target"]))
			if tgt != null and split.parts.has(tgt):
				var idx: int = split.parts.find(tgt) + 1
				if idx == live_index:
					split.on_hit(ev)
				else:
					tgt.hp = tgt.hp_max
		"duel_victory":
			split.clear()
