class_name LocationCard
extends CanvasLayer
## Big location card ("BED-STUY, BROOKLYN / 3:00 AM") that fades in, holds,
## and fades out. Used when you wake up after the prologue.

var top: String = ""
var bottom: String = ""
var hold_s: float = 3.0
var _t: float = 0.0
var _a: Label
var _b: Label


static func show_card(parent: Node, top_text: String, bottom_text: String, hold: float = 3.0) -> LocationCard:
	var c: LocationCard = LocationCard.new()
	c.top = top_text
	c.bottom = bottom_text
	c.hold_s = hold
	parent.add_child(c)
	return c


func _ready() -> void:
	layer = 25
	_a = _mk(UIFonts.graffiti(), 72, 380, Color("#FF3EA5"))
	_b = _mk(UIFonts.title(), 34, 480, Color("#F2F6FF"))
	_a.text = top
	_b.text = bottom
	_apply(0.0)


func _mk(font: Font, px: int, y: float, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	l.add_theme_constant_override("outline_size", 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(1920, px + 20)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func alpha_at(t: float) -> float:
	## 0.6 s in, hold, 0.8 s out.
	if t < 0.6:
		return t / 0.6
	if t < 0.6 + hold_s:
		return 1.0
	return clampf(1.0 - (t - 0.6 - hold_s) / 0.8, 0.0, 1.0)


func _apply(a: float) -> void:
	_a.modulate.a = a
	_b.modulate.a = a


func _process(delta: float) -> void:
	_t += delta
	_apply(alpha_at(_t))
	if _t > hold_s + 1.4:
		queue_free()
