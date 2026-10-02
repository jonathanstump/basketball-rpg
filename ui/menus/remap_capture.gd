class_name RemapCapture
extends CanvasLayer
## "Press a key or button" overlay for RemapMenu. Esc cancels.

signal done(ev: InputEvent)

var action: String = ""


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.92)
	bg.position = Vector2(560, 420)
	bg.size = Vector2(800, 200)
	add_child(bg)
	var l: Label = Label.new()
	l.text = "PRESS A KEY OR BUTTON FOR\n%s\n(Esc to cancel)" % action.replace("_", " ").to_upper()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UIFonts.title())
	l.add_theme_font_size_override("font_size", 30)
	l.position = Vector2(560, 450)
	l.size = Vector2(800, 150)
	add_child(l)


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		done.emit(null)
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		done.emit(event)
