class_name SimHoop
extends RefCounted
## A hoop target: regulation rim + backboard (boss courts, park courts) or a
## milk-crate hoop on a pole (streets, spec §5.5, §7.9).

var id: String = ""
var kind: String = "regulation"     # regulation | crate
var rim: Vector3 = Vector3(0, 3.05, 0)
var facing: Vector3 = Vector3(0, 0, 1)   # from backboard toward the court
var radius: float = 0.23
var net: String = "chain"           # chain (outdoor) | nylon (indoor)
var enabled: bool = true
var cooldown_s: float = 0.0         # crate Bucket Blast cooldown remaining
var first_make_paid: bool = false
var tier: int = 1


static func regulation(hoop_id: String, floor_pos: Vector3, toward_court: Vector3, height: float = 3.05, net_kind: String = "chain") -> SimHoop:
	var h: SimHoop = SimHoop.new()
	h.id = hoop_id
	h.facing = Vector3(toward_court.x, 0, toward_court.z).normalized()
	h.rim = Vector3(floor_pos.x, floor_pos.y + height, floor_pos.z)
	h.net = net_kind
	return h


static func crate(hoop_id: String, pole_pos: Vector3, toward_street: Vector3, height: float = 3.0) -> SimHoop:
	var h: SimHoop = SimHoop.new()
	h.id = hoop_id
	h.kind = "crate"
	h.facing = Vector3(toward_street.x, 0, toward_street.z).normalized()
	h.rim = pole_pos + h.facing * 0.25 + Vector3(0, height, 0)
	h.radius = 0.18
	h.net = "none"
	return h


func floor_point() -> Vector3:
	return Vector3(rim.x, 0.0, rim.z)


func backboard_center() -> Vector3:
	var off: float = 0.38 if kind == "regulation" else 0.2
	return rim - facing * off + Vector3(0, 0.3, 0)


func flat_distance(p: Vector3) -> float:
	return Vector2(p.x - rim.x, p.z - rim.z).length()


func is_ready() -> bool:
	return cooldown_s <= 0.0
