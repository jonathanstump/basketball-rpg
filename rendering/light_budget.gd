class_name LightBudget
extends Node
## Light budget (spec §12.5, §15.17): OmniLights use distance fade and only the
## N nearest to the camera cast shadows. Lights register via the "cc_lights" group.

var max_shadowed: int = 4
var fade_m: float = 60.0
var interval_s: float = 0.25
var _t: float = 0.0


func _ready() -> void:
	var qp: Dictionary = EnvPresets.quality_preset(Settings.get_string("quality"))
	max_shadowed = JU.i(qp, "max_shadow_lights", 4)
	fade_m = JU.f(qp, "light_fade_m", 60.0)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = interval_s
	refresh()


func refresh() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var origin: Vector3 = cam.global_position
	var lights: Array[OmniLight3D] = []
	for n: Node in get_tree().get_nodes_in_group("cc_lights"):
		if n is OmniLight3D:
			var l: OmniLight3D = n
			l.distance_fade_enabled = true
			l.distance_fade_begin = fade_m
			l.distance_fade_length = 10.0
			lights.append(l)
	lights.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	for i: int in lights.size():
		lights[i].shadow_enabled = i < max_shadowed
