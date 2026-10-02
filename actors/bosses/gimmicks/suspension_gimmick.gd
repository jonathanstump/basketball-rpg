class_name SuspensionGimmick
extends RefCounted
## Suspension (spec §9.3, The Bridge): TENSION. Glowing anchor points ring
## the promenade; strike near one to snap its cable and cost him balance
## (composure). Phase 2 "Sway": the deck sways every 12 s (you slide) and
## planks give way (hazard circles).

const DT: float = 1.0 / 60.0
const SNAP_RANGE: float = 2.0
const SNAP_COMPOSURE: float = 60.0
const STRIKES: PackedStringArray = ["pound", "cross_whip", "btl_snap", "btb_slam", "shove", "euro_step", "tomahawk", "reach_in"]

var brain: BossBrain
var world: SimWorld
var anchors: Array[Vector3] = []
var snapped: Array[bool] = []
var sway_s: float = 12.0
var sway_left: float = 0.0
var sway_dir: Vector3 = Vector3.RIGHT


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	var size: Array = JU.a(JU.dict(b.boss, "arena"), "size_m")
	var half: Vector2 = Vector2(float(size[0]), float(size[1])) * 0.5 if size.size() >= 2 else Vector2(10, 9)
	for p: Vector3 in [Vector3(-half.x + 1.0, 0, -half.y * 0.3), Vector3(half.x - 1.0, 0, -half.y * 0.3), Vector3(-half.x + 1.0, 0, half.y * 0.5), Vector3(half.x - 1.0, 0, half.y * 0.5)]:
		anchors.append(p)
		snapped.append(false)
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	if b.phase >= 2 and b.target != null:
		if sway_left > 0.0:
			sway_left -= DT
			if b.target.on_ground:
				b.target.pos = world.collision.resolve(b.target.pos + sway_dir * 2.0 * DT, b.target.radius)
		else:
			sway_s -= DT
			if sway_s <= 0.0:
				sway_s = 12.0
				sway_left = 3.0
				sway_dir = -sway_dir
				world.emit("floor_tilt", {"actor": b.actor.id, "dir": sway_dir})
	return false


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"action_started":
			var a: SimActor = world.actor_by_id(int(ev["actor"]))
			if a == null or brain.target == null or a != brain.target or not str(ev["move"]) in STRIKES:
				return
			for i: int in anchors.size():
				if not snapped[i] and Vector2(a.pos.x - anchors[i].x, a.pos.z - anchors[i].z).length() <= SNAP_RANGE:
					snap(i)
					return
		"duel_phase_changed":
			for i: int in snapped.size():
				snapped[i] = false
			world.emit("anchors_restrung", {"actor": brain.actor.id})


func snap(i: int) -> void:
	snapped[i] = true
	var c: Composure = brain.actor.composure
	if c != null:
		var br: String = c.add(SNAP_COMPOSURE, "stagger")
		if br != "":
			world.emit("composure_broken", {"actor": brain.actor.id, "kind": br})
	world.emit("cable_snapped", {"actor": brain.actor.id, "anchor": i, "pos": anchors[i]})
	world.emit("popup", {"text": "SNAP!", "pos": anchors[i], "style": "big"})
