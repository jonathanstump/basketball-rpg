class_name PostFX
extends CanvasLayer
## Screen-space passes (spec §12.1, §12.5): tilt-shift diorama blur and the
## comic halftone used for POSTER moments. Halftone respects reduce-flashes.

const TILT: Shader = preload("res://rendering/shaders/tilt_shift.gdshader")
const HALFTONE: Shader = preload("res://rendering/shaders/halftone_post.gdshader")

const FLASH: Dictionary = {"tourist": [0.85, 0.12], "lightning": [0.7, 0.12], "poster": [0.6, 0.0], "hit": [0.25, 0.0]}

var tilt_rect: ColorRect
var halftone_rect: ColorRect
var flash_rect: ColorRect
var _flash: float = 0.0
var _halftone_t: float = 0.0
var _halftone_len: float = 0.0


func _ready() -> void:
	layer = 5
	tilt_rect = _make_rect(TILT, "TiltShift")
	halftone_rect = _make_rect(HALFTONE, "Halftone")
	halftone_rect.visible = false
	flash_rect = ColorRect.new()
	flash_rect.name = "Flash"
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
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


static func flash_strength(kind: String, reduce: bool) -> float:
	## Peak white-flash alpha; "Reduce flashes" (spec §14) cuts tourist
	## flashes, lightning and the POSTER flash down to a faint pulse or none.
	var pair: Array = FLASH.get(kind, [0.0, 0.0])
	return float(pair[1]) if reduce else float(pair[0])


static func halftone_length(reduce: bool) -> float:
	return 0.35 if reduce else 0.7


func _on_flash(kind: String) -> void:
	var reduce: bool = Settings.get_bool("reduce_flashes")
	if kind == "poster":
		play_halftone(halftone_length(reduce))
	_flash = maxf(_flash, flash_strength(kind, reduce))


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		flash_rect.color = Color(1, 1, 1, _flash)
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
