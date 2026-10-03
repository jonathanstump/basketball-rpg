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
var _hint: Label
var _blips: int = -1
var open: bool = false
var closed_at_ms: int = -100000


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
	_hint = Label.new()
	_hint.add_theme_font_override("font", UIFonts.title())
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color("#F4B400"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.position = Vector2(1260, 955)
	_hint.size = Vector2(380, 30)
	add_child(_hint)
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
	if int(_t * 50.0) < line_parts(tr(lines[index]), speaker)[1].length():
		_t = 999.0
		return
	index += 1
	_t = 0.0
	if index >= lines.size():
		open = false
		visible = false
		closed_at_ms = Time.get_ticks_msec()
		closed.emit()


func _process(delta: float) -> void:
	if not open:
		return
	_t += delta
	var parts: PackedStringArray = line_parts(tr(lines[index]), tr(speaker))
	_name.text = parts[0]
	var shown: int = int(_t * 50.0)
	var full: String = parts[1]
	_text.text = full.substr(0, shown)
	var narration: bool = parts[0] == ""
	_text.add_theme_color_override("font_color", Color("#B8B8C8") if narration else Color.WHITE)
	_hint.text = InputPrompts.format("{interact} Next" if index < lines.size() - 1 else "{interact} Close")
	if shown < full.length() and shown / 3 != _blips and not narration:
		_blips = shown / 3
		AudioDirector.voice_blip(parts[0])
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		advance()


static func line_parts(line: String, default_speaker: String) -> PackedStringArray:
	## "Pops: Easy, kid." -> ["Pops", "Easy, kid."]; "(A cat.)" -> ["", "(A cat.)"]
	## (narration has no name tag); anything else keeps the default speaker.
	if line.begins_with("("):
		return PackedStringArray(["", line])
	var colon: int = line.find(": ")
	if colon > 0 and colon <= 20 and not line.substr(0, colon).contains("."):
		return PackedStringArray([line.substr(0, colon), line.substr(colon + 2)])
	return PackedStringArray([default_speaker, line])


func blocking() -> bool:
	## Open, or just closed (the Interact press that closed it is still
	## buffered for a few frames and must not also trigger the world).
	return open or Time.get_ticks_msec() - closed_at_ms < 250
