class_name HitVolume
extends RefCounted
## Math hit volumes evaluated against actor hurtboxes (vertical capsule =
## radius + height). Shapes (spec §9.2 primitives need them):
##   arc     radius, angle (deg), height     — swing in front of the owner
##   sphere  radius, forward, height         — ball/hand at a point ahead
##   circle  radius, height                  — ground AoE around a point
##   ring    radius (outer), width, height   — expanding shockwave (jump it)
##   box     length, width, height           — lane/charge/line sweep ahead
## `origin`/`yaw` place the volume in the world each frame.

var shape: String = "arc"
var radius: float = 1.5
var angle: float = 120.0
var height: float = 1.6
var forward: float = 0.0
var width: float = 1.0
var length: float = 2.0
var origin: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var y_offset: float = 0.0


static func from_dict(d: Dictionary) -> HitVolume:
	var v: HitVolume = HitVolume.new()
	v.shape = JU.s(d, "shape", "arc")
	v.radius = JU.f(d, "radius", 1.5)
	v.angle = JU.f(d, "angle", 120.0)
	v.height = JU.f(d, "height", 1.6)
	v.forward = JU.f(d, "forward", 0.0)
	v.width = JU.f(d, "width", 1.0)
	v.length = JU.f(d, "length", 2.0)
	v.y_offset = JU.f(d, "y_offset", 0.0)
	return v


func fwd() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func center() -> Vector3:
	return origin + fwd() * forward


func hits(target: SimActor) -> bool:
	var base_y: float = origin.y + y_offset
	if target.pos.y > base_y + height or target.pos.y + target.height < base_y - 0.1:
		return false
	var c: Vector3 = center()
	var rel: Vector2 = Vector2(target.pos.x - c.x, target.pos.z - c.z)
	var d: float = rel.length()
	match shape:
		"sphere", "circle":
			return d <= radius + target.radius
		"arc":
			if d > radius + target.radius:
				return false
			if d < target.radius + 0.2:
				return true
			var f: Vector3 = fwd()
			var ang: float = rad_to_deg(Vector2(f.x, f.z).angle_to(rel))
			var slack: float = rad_to_deg(atan2(target.radius, maxf(d, 0.01)))
			return absf(ang) <= angle * 0.5 + slack
		"ring":
			return d <= radius + target.radius and d >= maxf(0.0, radius - width) - target.radius
		"box":
			var f2: Vector3 = fwd()
			var side: Vector2 = Vector2(-f2.z, f2.x)
			var along: float = rel.dot(Vector2(f2.x, f2.z))
			var lateral: float = absf(rel.dot(side))
			return along >= -target.radius and along <= length + target.radius and lateral <= width * 0.5 + target.radius
	return false
