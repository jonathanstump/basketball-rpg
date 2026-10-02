class_name TitleScreen
extends Control
## Title (spec §3.3): the skyline at night, every clock stopped at 3:00.
## Continue / New Game / Settings / Quit.

var menu: CanvasLayer = null
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _buildings: Array[Rect2] = []
var _windows: Array[Rect2] = []
var _clocks: Array[Vector2] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 300
	var x: float = -20.0
	while x < 1940.0:
		var w: float = _rng.randf_range(90.0, 210.0)
		var h: float = _rng.randf_range(220.0, 640.0)
		var r: Rect2 = Rect2(x, 1080.0 - h, w, h)
		_buildings.append(r)
		var wy: float = r.position.y + 30.0
		while wy < 1040.0:
			var wx: float = r.position.x + 14.0
			while wx < r.end.x - 20.0:
				if _rng.randf() < 0.32:
					_windows.append(Rect2(wx, wy, 12.0, 18.0))
				wx += 26.0
			wy += 34.0
		if h > 420.0 and _rng.randf() < 0.5:
			_clocks.append(Vector2(r.position.x + w * 0.5, r.position.y + 70.0))
		x += w + _rng.randf_range(4.0, 18.0)
	var title: Label = _label("CONCRETE CROWN", UIFonts.graffiti(), 78, Color("#FF3EA5"), Vector2(1040, 720))
	title.size = Vector2(860, 140)
	var tag: Label = _label("One ball. Five boroughs. No fouls.
3:00 AM. The sun never came up.", UIFonts.body(), 28, Color("#F2F6FF"), Vector2(1040, 850))
	tag.size = Vector2(860, 90)
	AudioDirector.set_layer("title")
	open_main()


func _label(text: String, font: Font, size_px: int, col: Color, pos: Vector2) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	l.add_theme_constant_override("outline_size", 12)
	l.position = pos
	add_child(l)
	return l


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("#0A0A1E"))
	draw_rect(Rect2(0, 600, 1920, 480), Color("#14102A"))
	draw_circle(Vector2(1580, 210), 70.0, Color("#E8E4D0"))
	draw_circle(Vector2(1605, 195), 64.0, Color("#0A0A1E"))
	for b: Rect2 in _buildings:
		draw_rect(b, Color("#1C1638"))
		draw_rect(Rect2(b.position, Vector2(b.size.x, 6.0)), Color("#7B2FF7", 0.6))
	for i: int in _windows.size():
		var flick: float = 0.75 + 0.25 * sin(_t * 0.7 + float(i))
		draw_rect(_windows[i], Color("#FFD08A") * Color(1, 1, 1, flick))
	for c: Vector2 in _clocks:
		_clock(c, 34.0)
	_clock(Vector2(1470, 520), 90.0)


func _clock(c: Vector2, r: float) -> void:
	## Every clock reads 3:00.
	draw_circle(c, r, Color("#F2EEDC"))
	draw_arc(c, r, 0.0, TAU, 48, Color("#0B0B10"), maxf(2.0, r * 0.08))
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.82, c + Vector2(cos(a), sin(a)) * r * 0.94, Color("#0B0B10"), maxf(1.0, r * 0.03))
	draw_line(c, c + Vector2(0, -r * 0.78), Color("#0B0B10"), maxf(2.0, r * 0.06))
	draw_line(c, c + Vector2(r * 0.55, 0), Color("#0B0B10"), maxf(3.0, r * 0.09))
	draw_circle(c, maxf(2.0, r * 0.07), Color("#D8263A"))


func open_menu(m: CanvasLayer) -> void:
	close_menu()
	add_child(m)
	menu = m


func close_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null


func open_main() -> void:
	var slot: int = FrontEndFlow.latest_slot()
	var opts: Array[Dictionary] = []
	if slot >= 0:
		var s: Dictionary = SaveSystem.slot_summary(slot)
		opts.append({"id": "continue", "label": "Continue", "detail": "%s - Level %d - %d Crown(s)\nSaved %s" % [JU.s(s, "name"), JU.i(s, "level", 1), JU.i(s, "crowns"), JU.s(s, "saved_at")]})
	opts.append({"id": "new", "label": "New Game", "detail": "Make your hooper, pick a start borough, and call next."})
	opts.append({"id": "settings", "label": "Settings"})
	opts.append({"id": "quit", "label": "Quit"})
	var m: ListMenu = MenuKit.show(self, "", opts, func(id: String) -> void: _on_main(id, slot), "Pad: D-pad + A.  Keyboard: arrows + Enter.")
	m.cancelled.disconnect(close_menu)


func _on_main(id: String, slot: int) -> void:
	match id:
		"continue":
			close_menu()
			FrontEndFlow.continue_game(slot)
		"new":
			close_menu()
			SceneRouter.goto(FrontEndFlow.CREATOR, {"slot": FrontEndFlow.free_slot()})
		"settings":
			SettingsMenu.open(self, open_main)
		"quit":
			get_tree().quit()


func setup_render_smoke(entry: Dictionary) -> void:
	## Render smoke: "controls" opens Settings -> Controls over the title.
	if JU.s(entry, "mode") == "controls":
		ready.connect(func() -> void:
			SettingsMenu.open(self, open_main)
			RemapMenu.open(self, open_main, 4), CONNECT_DEFERRED)
