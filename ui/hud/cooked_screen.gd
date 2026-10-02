class_name CookedScreen
extends CanvasLayer
## Death screen (spec §14): "COOKED" in drippy sticker type, then fade out.

signal finished()

var _t: float = 0.0
var _len: float = 3.0
var _label: Label
var _fade: ColorRect


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.0, 0.02, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_label = Label.new()
	_label.text = tr("COOKED")
	_label.add_theme_font_override("font", UIFonts.graffiti())
	_label.add_theme_font_size_override("font_size", 220)
	_label.add_theme_color_override("font_color", Color("#E8344A"))
	_label.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	_label.add_theme_constant_override("outline_size", 30)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.01)
	var k: float = clampf(_t / _len, 0.0, 1.0)
	_fade.color.a = clampf(k * 1.4, 0.0, 0.9)
	_label.modulate.a = clampf(_t * 3.0, 0.0, 1.0) * (1.0 - clampf((k - 0.8) * 5.0, 0.0, 1.0))
	_label.position.y = sin(_t * 2.0) * 6.0 + k * 20.0
	if _t >= _len:
		finished.emit()
		queue_free()
