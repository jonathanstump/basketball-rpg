class_name AtlasGimmick
extends RefCounted
## Atlas (spec §9.3): ORBITS. Glowing rings rotate around him: the low ring
## must be jumped, the high ring slid under (dodge). Rings vanish while he is
## SHOOK; Orbit Spin speeds them up for 4 s. Phase 2 "Weight of the World":
## the globe drops and rolls around the court as a boulder hazard. T5
## "Eclipse" is presentation (darkness except rings and your ball).

const DT: float = 1.0 / 60.0
## [height band bottom, band height, deg/s, reach m]
const RINGS: Array = [[0.0, 0.55, 70.0, 8.0], [1.05, 1.2, -50.0, 9.0], [0.0, 0.55, -95.0, 6.0]]

var brain: BossBrain
var world: SimWorld
var rings: Array[Hitbox] = []
var spin_until: int = -1
var globe: Hitbox = null
var globe_vel: Vector3 = Vector3.ZERO
var half: Vector2 = Vector2(11, 9)


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	var size: Array = JU.a(JU.dict(b.boss, "arena"), "size_m")
	if size.size() >= 2:
		half = Vector2(float(size[0]), float(size[1])) * 0.5
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	## CHECK / phase changes clear the owner's hitboxes: rebuild if that happened.
	if not rings.is_empty() and not b.combat.hitboxes.has(rings[0]):
		rings.clear()
	if globe != null and not b.combat.hitboxes.has(globe):
		b.combat.add(globe)
	var live: bool = not b.actor.is_shook() and b.duel_state() in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]
	if live and rings.is_empty():
		_make_rings()
	elif not live and not rings.is_empty():
		_clear_rings()
	var fast: float = 2.2 if world.frame < spin_until else 1.0
	for i: int in rings.size():
		var hb: Hitbox = rings[i]
		var spec: Array = RINGS[i]
		hb.volume.origin = b.actor.pos
		hb.volume.yaw += deg_to_rad(float(spec[2])) * fast * DT
		hb.frames_left = 999999
	_tick_globe()
	return false


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"move_started":
			if int(ev["actor"]) == brain.actor.id and str(ev["move"]) == "orbit_spin":
				spin_until = world.frame + 240
		"duel_phase_changed":
			if int(ev.get("phase", 1)) >= 2 and globe == null:
				drop_globe()
		"duel_victory":
			_clear_rings()
			if globe != null:
				globe.frames_left = 0
				globe = null


func _make_rings() -> void:
	for spec: Variant in RINGS:
		var s: Array = spec
		var hb: Hitbox = Hitbox.new()
		hb.owner_id = brain.actor.id
		hb.team = brain.actor.team
		hb.move_id = "orbit_ring"
		hb.world_space = true
		hb.volume = HitVolume.from_dict({"shape": "box", "length": float(s[3]), "width": 0.6, "height": float(s[1]), "y_offset": float(s[0])})
		hb.volume.origin = brain.actor.pos
		hb.volume.yaw = float(rings.size()) * TAU / 3.0
		hb.damage = DamageMath.enemy_damage(30.0, brain.actor.tier, GameState.ng_cycle, 1.0)
		hb.parryable = false
		hb.unblockable = true
		hb.rehit_frames = 45
		hb.frames_left = 999999
		hb.weight = "light"
		brain.combat.add(hb)
		rings.append(hb)
	world.emit("orbits_on", {"actor": brain.actor.id, "rings": RINGS.size()})


func _clear_rings() -> void:
	for hb: Hitbox in rings:
		hb.frames_left = 0
	rings.clear()
	world.emit("orbits_off", {"actor": brain.actor.id})


func drop_globe() -> void:
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = brain.actor.id
	hb.team = brain.actor.team
	hb.move_id = "rolling_globe"
	hb.world_space = true
	hb.volume = HitVolume.from_dict({"shape": "circle", "radius": 1.4, "height": 2.4})
	hb.volume.origin = brain.actor.pos + Vector3(2.0, 0, 2.0)
	hb.damage = DamageMath.enemy_damage(60.0, brain.actor.tier, GameState.ng_cycle, 1.0)
	hb.parryable = false
	hb.knockdown = true
	hb.rehit_frames = 60
	hb.frames_left = 999999
	hb.weight = "heavy"
	brain.combat.add(hb)
	globe = hb
	globe_vel = Vector3(4.5, 0, 3.0)
	world.emit("globe_dropped", {"actor": brain.actor.id, "pos": hb.volume.origin})


func _tick_globe() -> void:
	if globe == null:
		return
	var p: Vector3 = globe.volume.origin + globe_vel * DT
	if absf(p.x) > half.x:
		globe_vel.x = -globe_vel.x
		p.x = clampf(p.x, -half.x, half.x)
	if absf(p.z) > half.y:
		globe_vel.z = -globe_vel.z
		p.z = clampf(p.z, -half.y, half.y)
	globe.volume.origin = p
	globe.frames_left = 999999
	if world.frame % 6 == 0:
		world.emit("globe_rolled", {"actor": brain.actor.id, "pos": p})
