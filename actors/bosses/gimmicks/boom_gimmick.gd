class_name BoomGimmick
extends RefCounted
## Grandmaster Boom (spec §9.3): RHYTHM. Every attack lands on the beat
## (92 BPM, 100 in Phase 2): the gimmick picks the move, then starts it so
## its first active frame hits the next beat. Dodging or striking on the beat
## = ON BEAT (+5 Hype). Speaker Stacks pulse rings on beats 2 and 4. The El's
## Train Pass rolls through every ~30 s. Remix (P2) adds Rewind: his last
## three attacks in reverse. T5 Breakbeat: music cuts, off-beat for 10 s.

const DT: float = 1.0 / 60.0
const TRAIN_EVERY_S: float = 30.0
const ON_BEAT_HYPE: float = 5.0
const ON_BEAT_MOVES: PackedStringArray = ["crossover", "stepback", "defensive_slide", "pound", "cross_whip", "btl_snap", "btb_slam", "euro_step"]

var brain: BossBrain
var world: SimWorld
var clock: BeatClock
var pending: Dictionary = {}
var queue: Array[String] = []
var speakers: Array[SimActor] = []
var train_s: float = TRAIN_EVERY_S
var offbeat_until: int = -1
var muted: bool = false
var on_beats: int = 0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	clock = BeatClock.new(JU.f(b.boss, "bpm", 92.0), world.frame)
	world.sim_event.connect(_on_event)


func offbeat() -> bool:
	return world.frame < offbeat_until


func on_step(b: BossBrain) -> bool:
	if clock.is_beat_frame(world.frame) and not muted:
		world.emit("beat", {"actor": b.actor.id, "beat": clock.beat_in_bar(world.frame), "bpm": clock.bpm})
	if muted and not offbeat():
		muted = false
		world.emit("beat_restored", {"actor": b.actor.id})
	_tick_speakers()
	b.think_s = 1.0   # the gimmick owns move picking; the brain only positions
	var st: String = b.duel_state()
	var live: bool = st in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]
	if not live or b.actor.is_broken() or b.runner.running:
		if not live:
			pending = {}
		return false
	train_s -= DT
	if train_s <= 0.0 and b.target != null:
		train_s = TRAIN_EVERY_S
		b.run_event_move("train_pass")
		return true
	if pending.is_empty() and b.recover_s <= 0.0:
		if not queue.is_empty():
			pending = DataDB.move(JU.s(b.boss, "id"), queue.pop_front())
		else:
			pending = b.pick_move()
	if pending.is_empty():
		return false
	var lead: int = JU.i(pending, "startup") + 1
	var to_beat: int = clock.frames_to_next_beat(world.frame + lead, 0.5 if offbeat() else 0.0)
	if to_beat == 0:
		var m: Dictionary = pending
		pending = {}
		b.start_move(m)
		return true
	return false


func _on_event(ev: Dictionary) -> void:
	var t: String = str(ev.get("type", ""))
	match t:
		"action_started":
			var a: SimActor = world.actor_by_id(int(ev["actor"]))
			if a != null and a.kind == "hooper" and a.team == 0 and str(ev["move"]) in ON_BEAT_MOVES and not muted and clock.is_on_beat(world.frame, 6):
				a.hype.add(ON_BEAT_HYPE)
				on_beats += 1
				world.emit("on_beat", {"actor": a.id, "pos": a.pos})
		"mirror_requested":
			if int(ev["actor"]) == brain.actor.id and str(ev["move"]) == "rewind":
				var hist: Array[String] = []
				for id: String in brain.history:
					if not id in ["rewind", "train_pass", "speaker_stack", "breakbeat"]:
						hist.append(id)
				var last3: Array[String] = hist.slice(maxi(0, hist.size() - 3))
				last3.reverse()
				queue = last3
				world.emit("rewind", {"actor": brain.actor.id, "moves": last3})
		"arena_event":
			if int(ev["actor"]) != brain.actor.id:
				return
			match str(ev["event"]):
				"speaker_stack":
					spawn_speakers()
				"breakbeat":
					offbeat_until = world.frame + int(JU.f(ev["move"] as Dictionary, "duration_s", 10.0) * 60.0)
					muted = true
					world.emit("beat_muted", {"actor": brain.actor.id})
		"duel_phase_changed":
			if int(ev.get("phase", 1)) >= 2:
				clock.set_bpm(JU.f(brain.boss, "bpm_phase_2", 100.0), world.frame)
			clear_speakers()
		"duel_victory", "duel_check":
			if t == "duel_victory":
				clear_speakers()


func spawn_speakers() -> void:
	clear_speakers()
	var a: SimActor = brain.actor
	var m: Dictionary = DataDB.move(JU.s(brain.boss, "id"), "speaker_pulse")
	for sx: float in [-1.0, 1.0]:
		var s: SimActor = SimActor.new()
		s.kind = "prop"
		s.archetype = "speaker_tower"
		s.display_name = "Speaker Stack"
		s.team = a.team
		s.tier = a.tier
		s.radius = 0.8
		s.height = 2.6
		s.hp_max = JU.f(m, "tower_hp", 160.0) * TierMath.multiplier(DataDB.tiers(), "hp", a.tier)
		s.hp = s.hp_max
		s.poise = 9999.0
		s.hyper_armor = true
		s.pos = world.collision.resolve(a.home + Vector3(sx * 5.5, 0, 2.0), s.radius)
		world.add_actor(s)
		s.controller = SpeakerBrain.new(s, world, brain, clock, m)
		speakers.append(s)
		world.emit("speaker_spawned", {"actor": s.id, "pos": s.pos})


func clear_speakers() -> void:
	for s: SimActor in speakers:
		if s.alive:
			s.alive = false
		world.emit("speaker_destroyed", {"actor": s.id, "pos": s.pos, "quiet": true})
		world.remove_actor(s)
	speakers.clear()


func _tick_speakers() -> void:
	for s: SimActor in speakers.duplicate():
		if not s.alive or s.hp <= 0.0:
			speakers.erase(s)
			s.alive = false
			world.emit("speaker_destroyed", {"actor": s.id, "pos": s.pos})
			world.remove_actor(s)


class SpeakerBrain:
	extends RefCounted
	## A speaker tower: pulses a ring so it lands on beats 2 and 4.
	var actor: SimActor
	var world: SimWorld
	var clock: BeatClock
	var runner: MoveRunner
	var pulse: Dictionary

	func _init(a: SimActor, w: SimWorld, b: BossBrain, c: BeatClock, m: Dictionary) -> void:
		actor = a
		world = w
		clock = c
		pulse = m
		runner = MoveRunner.new(a, w, b.combat)

	func step() -> void:
		actor.desired_vel = Vector3.ZERO
		if runner.running:
			runner.step()
			return
		if pulse.is_empty():
			return
		var lead: int = JU.i(pulse, "startup") + 1
		if clock.frames_to_next_beat(world.frame + lead) == 0:
			var beat: int = clock.nearest_beat_in_bar(world.frame + lead)
			if beat == 2 or beat == 4:
				runner.start(pulse, null)
