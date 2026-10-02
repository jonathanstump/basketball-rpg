class_name DialogueBox
extends CanvasLayer
## Short dialogue/barks (spec §3.6, §14): speaker name + lines, typed out,
## advanced with Interact/Accept. Graffiti tags, NPCs, Mic Check use it.
## Gibberish voice per speaker arrives with audio (M13).

signal closed()

var lines: PackedStringArray = PackedStringArray()
var speaker: String = ""
var index: int = 0
var _t: float = 0.0
var _panel: ColorRect
var _name: Label
var _text: Label
var _blips: int = -1
var open: bool = false


func _ready() -> void:
	layer = 30
	_panel = ColorRect.new()
	_panel.color = Color(0.03, 0.03, 0.06, 0.88)
	_panel.position = Vector2(260, 780)
	_panel.size = Vector2(1400, 210)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_name = Label.new()
	_name.add_theme_font_override("font", UIFonts.title())
	_name.add_theme_font_size_override("font_size", 28)
	_name.add_theme_color_override("font_color", Color("#F4B400"))
	_name.position = Vector2(290, 795)
	add_child(_name)
	_text = Label.new()
	_text.add_theme_font_override("font", UIFonts.body())
	_text.add_theme_font_size_override("font_size", 32)
	_text.position = Vector2(290, 840)
	_text.size = Vector2(1340, 140)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_text)
	visible = false
	EventBus.dialogue_requested.connect(show_lines)


func show_lines(who: String, ls: PackedStringArray) -> void:
	if ls.is_empty():
		return
	speaker = who
	lines = ls
	index = 0
	_t = 0.0
	open = true
	visible = true


func advance() -> void:
	if not open:
		return
	if int(_t * 50.0) < tr(lines[index]).length():
		_t = 999.0
		return
	index += 1
	_t = 0.0
	if index >= lines.size():
		open = false
		visible = false
		closed.emit()


func _process(delta: float) -> void:
	if not open:
		return
	_t += delta
	_name.text = tr(speaker)
	var shown: int = int(_t * 50.0)
	var full: String = tr(lines[index])
	_text.text = full.substr(0, shown)
	if shown < full.length() and shown / 3 != _blips:
		_blips = shown / 3
		AudioDirector.voice_blip(speaker)
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		advance()
