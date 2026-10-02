class_name ShotFlight
extends RefCounted
## Scripted parabolic arc from start to end with a given apex height above the
## higher endpoint. Shots and lobs play their predetermined outcome on it.

var start: Vector3 = Vector3.ZERO
var end: Vector3 = Vector3.ZERO
var apex: float = 1.0       # extra height over the straight line at mid-flight
var duration: float = 1.0
var t: float = 0.0


static func make(a: Vector3, b: Vector3, apex_m: float, duration_s: float) -> ShotFlight:
	var f: ShotFlight = ShotFlight.new()
	f.start = a
	f.end = b
	f.apex = apex_m
	f.duration = maxf(0.05, duration_s)
	return f


func pos_at(time_s: float) -> Vector3:
	var u: float = clampf(time_s / duration, 0.0, 1.0)
	var p: Vector3 = start.lerp(end, u)
	p.y += 4.0 * apex * u * (1.0 - u)
	return p


func vel_at(time_s: float) -> Vector3:
	var dt: float = 1.0 / 120.0
	return (pos_at(time_s + dt) - pos_at(time_s - dt)) / (2.0 * dt)


func advance(dt: float) -> bool:
	## Returns true when the flight just finished.
	t += dt
	return t >= duration


func current() -> Vector3:
	return pos_at(t)


func apex_point() -> Vector3:
	return pos_at(duration * 0.5)
