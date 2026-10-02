class_name ListMenu
extends CanvasLayer
## Sticker-style vertical menu (spec §14): title, options with optional
## detail text, pad/keyboard navigation (ui_up/ui_down/ui_accept/ui_cancel).
## Options: [{id, label, detail, enabled}]. Emits chosen(id) or cancelled().

signal chosen(id: String)
signal cancelled()

var title: String = ""
var options: Array[Dictionary] = []
var index: int = 0
var footer: String = ""
var _labels: Array[Label] = []
var _title: Label
var _detail: Label
var _footer: Label
var _bg: ColorRect


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.02, 0.05, 0.86)
	_bg.position = Vector2(120, 120)
	_bg.size = Vector2(900, 840)
	add_child(_bg)
	_title = _mk(UIFonts.graffiti(), 64, Vector2(160, 140), Color("#FF3EA5"))
	_detail = _mk(UIFonts.body(), 26, Vector2(1060, 200), Color("#F2F6FF"))
	_detail.size = Vector2(720, 600)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer = _mk(UIFonts.title(), 22, Vector2(160, 910), Color("#F4B400"))
	rebuild()


func _mk(font: Font, size_px: int, pos: Vector2, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	l.add_theme_constant_override("outline_size", 8)
	l.position = pos
	l.size = Vector2(840, size_px + 14)
	add_child(l)
	return l


func set_options(t: String, opts: Array[Dictionary], foot: String = "") -> void:
	title = t
	options = opts
	footer = foot
	index = 0
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	for l: Label in _labels:
		l.queue_free()
	_labels.clear()
	_title.text = tr(title)
	_footer.text = tr(footer)
	for i: int in options.size():
		var l2: Label = _mk(UIFonts.title(), 34, Vector2(170, 250 + 62 * i), Color.WHITE)
		_labels.append(l2)
	_refresh()


func _refresh() -> void:
	for i: int in _labels.size():
		var o: Dictionary = options[i]
		var on: bool = bool(o.get("enabled", true))
		_labels[i].text = ("> " if i == index else "  ") + tr(str(o.get("label", "")))
		_labels[i].add_theme_color_override("font_color", Color("#FFE060") if i == index else (Color.WHITE if on else Color("#6A6A7A")))
	if index < options.size():
		_detail.text = tr(str(options[index].get("detail", "")))


func move(delta_i: int) -> void:
	if options.is_empty():
		return
	index = (index + delta_i + options.size()) % options.size()
	_refresh()


func accept() -> void:
	if index < options.size() and bool(options[index].get("enabled", true)):
		chosen.emit(str(options[index]["id"]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		cancelled.emit()
	else:
		return
	get_viewport().set_input_as_handled()
