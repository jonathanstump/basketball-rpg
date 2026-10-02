class_name ShotWindows
extends RefCounted
## Nested release windows on the 0..1 meter, all centered on `center`.
## Widths are full widths (a window spans center ± width / 2).

var center: float = 0.82
var perfect: float = 0.05
var good: float = 0.12
var near: float = 0.22
var zone: String = "mid"


func half(kind: String) -> float:
	match kind:
		"perfect":
			return perfect * 0.5
		"good":
			return good * 0.5
		"near":
			return near * 0.5
	return 0.0


func bounds(kind: String) -> Vector2:
	var h: float = half(kind)
	return Vector2(clampf(center - h, 0.0, 1.0), clampf(center + h, 0.0, 1.0))
