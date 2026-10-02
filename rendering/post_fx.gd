class_name PostFX
extends CanvasLayer
## Screen-space passes (spec §12.1, §12.5): tilt-shift diorama blur and the
## comic halftone used for POSTER moments. Halftone respects reduce-flashes.

const TILT: Shader = preload("res://rendering/shaders/tilt_shift.gdshader")
const HALFTONE: Shader = preload("res://rendering/shaders/halftone_post.gdshader")

var tilt_rect: ColorRect
var halftone_rect: ColorRect
var _halftone_t: float = 0.0
var _halftone_len: float = 0.0


func _ready() -> void:
	layer = 5
	tilt_rect = _make_rect(TILT, "TiltShift")
	halftone_rect = _make_rect(HALFTONE, "Halftone")
	halftone_rect.visible = false
	apply_settings()
	EventBus.settings_changed.connect(apply_settings)
	EventBus.flash_requested.connect(_on_flash)


func _make_rect(shader: Shader, n: String) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.name = n
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader
	r.material = m
	add_child(r)
	return r


func apply_settings() -> void:
	var qp: Dictionary = EnvPresets.quality_preset(Settings.get_string("quality"))
	tilt_rect.visible = Settings.get_bool("tilt_shift") and JU.b(qp, "tilt_shift", true)


func play_halftone(duration_s: float = 0.6) -> void:
	_halftone_len = duration_s
	_halftone_t = duration_s
	halftone_rect.visible = true


func _on_flash(kind: String) -> void:
	if kind == "poster":
		play_halftone(0.7 if not Settings.get_bool("reduce_flashes") else 0.35)


func _process(delta: float) -> void:
	if _halftone_t <= 0.0:
		return
	_halftone_t -= delta
	var k: float = clampf(_halftone_t / maxf(_halftone_len, 0.01), 0.0, 1.0)
	var amount: float = sin(k * PI)
	if Settings.get_bool("reduce_flashes"):
		amount *= 0.5
	(halftone_rect.material as ShaderMaterial).set_shader_parameter("amount", amount)
	if _halftone_t <= 0.0:
		halftone_rect.visible = false
