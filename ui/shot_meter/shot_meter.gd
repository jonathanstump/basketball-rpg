class_name ShotMeter
extends Control
## Vertical 2K-style shot meter beside the player (spec §7.6, §14). Shows the
## near/good/perfect windows with colorblind-safe shape markers, the fill, and
## the release mark.

const SIZE: Vector2 = Vector2(18, 150)

var module: HooperBall = null
var actor: SimActor = null
var camera: Camera3D = null
var _flash_t: float = 0.0
var _last_release: float = -1.0
var _last_windows: ShotWindows = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE + Vector2(40, 10)


func _process(delta: float) -> void:
	if module == null or actor == null or camera == null:
		visible = false
		return
	var gathering: bool = module.meter >= 0.0
	if gathering:
		_last_windows = module.windows
		_flash_t = 0.6
		_last_release = -1.0
	elif _flash_t > 0.0:
		_flash_t -= delta
		_last_release = module.last_release
	visible = gathering or _flash_t > 0.0
	if not visible:
		return
	var head: Vector3 = actor.pos + Vector3(0, 1.4, 0) + camera.global_basis.x * 0.9
	if camera.is_position_behind(head):
		visible = false
		return
	position = PopupLayer.world_to_canvas(get_viewport(), camera, head) - Vector2(0, SIZE.y * 0.5)
	queue_redraw()


func _y(v: float) -> float:
	return SIZE.y * (1.0 - clampf(v, 0.0, 1.0))


func _draw() -> void:
	var w: ShotWindows = _last_windows
	draw_rect(Rect2(Vector2(-3, -3), SIZE + Vector2(6, 6)), Color("#0B0B10"))
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("#2A2A34"))
	var colorblind: bool = Settings.get_string("colorblind") != "off"
	if w != null:
		for kind: String in ["near", "good", "perfect"]:
			var b: Vector2 = w.bounds(kind)
			var col: Color = {"near": Color("#5A5A70"), "good": Color("#12C2B0"), "perfect": Color("#F4B400")}[kind]
			if colorblind:
				col = {"near": Color("#606060"), "good": Color("#56B4E9"), "perfect": Color("#FFFFFF")}[kind]
			draw_rect(Rect2(Vector2(0, _y(b.y)), Vector2(SIZE.x, _y(b.x) - _y(b.y))), col)
		var pb: Vector2 = w.bounds("perfect")
		var mid: float = (_y(pb.x) + _y(pb.y)) * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(SIZE.x + 3, mid), Vector2(SIZE.x + 12, mid - 6), Vector2(SIZE.x + 12, mid + 6)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(-3, mid), Vector2(-12, mid - 6), Vector2(-12, mid + 6)]), Color.WHITE)
	var fill: float = module.meter if module.meter >= 0.0 else _last_release
	if fill >= 0.0:
		draw_rect(Rect2(Vector2(3, _y(fill)), Vector2(SIZE.x - 6, SIZE.y - _y(fill))), Color(1, 1, 1, 0.55))
		draw_rect(Rect2(Vector2(-6, _y(fill) - 2), Vector2(SIZE.x + 12, 4)), Color("#FF3EA5"))
