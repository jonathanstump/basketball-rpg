class_name TitleCard
extends CanvasLayer
## Boss intro (spec §9.1): Mic Check's line as a subtitle with speaker name,
## then a comic title card — boss name in graffiti type, title underneath.

signal finished()

var mic_line: String = ""
var boss_name: String = ""
var boss_title: String = ""
var scouting: String = ""          # R7: the boss's game in a line + top ratings
var accent: Color = Color("#FF3EA5")
var line_s: float = 2.6
var card_s: float = 1.8
var _t: float = 0.0
var _sub: Label
var _speaker: Label
var _name: Label
var _title: Label
var _scout: Label
var _panel: ColorRect


func _ready() -> void:
	layer = 40
	_panel = ColorRect.new()
	_panel.color = Color(0.04, 0.03, 0.08, 0.0)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_speaker = _label(UIFonts.title(), 26, Color("#F4B400"), Vector2(260, 820), "MIC CHECK")
	_sub = _label(UIFonts.body(), 34, Color.WHITE, Vector2(260, 860), "")
	_sub.size = Vector2(1400, 160)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name = _label(UIFonts.graffiti(), 130, accent, Vector2(160, 360), tr(boss_name))
	_name.size = Vector2(1600, 180)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.rotation = -0.05
	_title = _label(UIFonts.title(), 40, Color("#F2F6FF"), Vector2(160, 560), tr(boss_title).to_upper())
	_title.size = Vector2(1600, 60)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scout = _label(UIFonts.body(), 28, Color("#C8D0E8"), Vector2(260, 640), tr(scouting))
	_scout.size = Vector2(1400, 120)
	_scout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if scouting != "":
		card_s += 1.4   # time to read the scouting report


func _label(font: Font, size_px: int, col: Color, pos: Vector2, text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	l.add_theme_constant_override("outline_size", 14)
	l.position = pos
	l.size = Vector2(1400, size_px + 20)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	var chars: int = int(_t * 45.0)
	var subs_on: bool = Settings.get_bool("subtitles")
	_sub.text = tr(mic_line).substr(0, chars) if subs_on else ""
	_speaker.visible = subs_on and _t < line_s
	_sub.visible = _t < line_s
	var card_t: float = _t - line_s
	var card_on: bool = card_t >= 0.0 and card_t < card_s
	_name.visible = card_on
	_title.visible = card_on
	_scout.visible = card_on
	_panel.color.a = 0.55 if card_on else 0.0
	if card_on:
		var pop: float = 1.0 + maxf(0.0, 0.25 - card_t) * 2.0
		_name.scale = Vector2.ONE * pop
	if _t >= line_s + card_s:
		finished.emit()
		queue_free()
