class_name Hitbox
extends RefCounted
## An active attack (spec §15.5): owner, move, damage packet and a volume.
## Lives for `frames_left` frames; follows its owner unless `world_space`.
## Each target is hit at most once per hitbox (unless `rehit_frames` > 0).

var owner_id: int = 0
var team: int = 0
var move_id: String = ""
var volume: HitVolume = HitVolume.new()
var frames_left: int = 1
var delay: int = 0                       # frames before it becomes active (lobs, telegraphed circles)
var world_space: bool = false
var velocity: Vector3 = Vector3.ZERO     # projectiles / expanding rings
var grow_per_s: float = 0.0              # ring waves expand
var hit_ids: Array[int] = []
var rehit_frames: int = 0
var _rehit: Dictionary = {}

# Damage packet
var damage: float = 0.0                  # final pre-defense damage
var composure: float = 0.0
var kind: String = "body"                # ball | body (strip vs deflect)
var unblockable: bool = false
var parryable: bool = true
var weight: String = "light"             # light | medium | heavy (hitstop, flinch)
var knockdown: bool = false
var knockdown_commons: bool = false
var grab: bool = false
var break_kind: String = "shook"         # which composure break this causes
var crit: float = 1.0
var hype_on_hit: float = 0.0
var status: Dictionary = {}              # {burn: s, bleed: amt, slow: s...}
var projectile: bool = false
var lob: bool = false                    # airborne ball (Rejection can swat it)
var tags: Dictionary = {}


func can_hit(target: SimActor, frame: int) -> bool:
	if target.id == owner_id or target.team == team or not target.alive or target.kind == "prop":
		return false
	if hit_ids.has(target.id):
		if rehit_frames <= 0:
			return false
		if frame - int(_rehit.get(target.id, -999)) < rehit_frames:
			return false
	return volume.hits(target)


func mark_hit(target: SimActor, frame: int) -> void:
	if not hit_ids.has(target.id):
		hit_ids.append(target.id)
	_rehit[target.id] = frame


func hitstop_frames() -> int:
	var hs: Dictionary = JU.dict(DataDB.tuning("combat"), "hitstop")
	return JU.i(hs, weight, 3)
