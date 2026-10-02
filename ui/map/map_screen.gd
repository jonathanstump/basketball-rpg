class_name MapScreen
extends CanvasLayer
## Subway-map style district map (spec §5.3): revealed tiles only (fog of
## war), the street layer once a station is tapped, colored line + station
## dots, markers for bodegas, stations, shops, courts (boss icon once seen),
## the player, and up to 20 player pins (accept toggles a pin at the cursor).

const MAX_PINS: int = 20

var map: MapData
var layout: Dictionary = {}
var player_pos: Vector3 = Vector3.ZERO
var cursor: Vector2i = Vector2i.ZERO
var _canvas: Control


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)
	var title: Label = Label.new()
	title.text = tr(WorldIndex.district_name(map.id)).to_upper() if map != null else ""
	title.add_theme_font_override("font", UIFonts.title())
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#F2F6FF"))
	title.position = Vector2(1320, 120)
	add_child(title)
	var hint: Label = Label.new()
	hint.text = tr("Arrows: move cursor   Accept: pin   Map/Esc: close")
	hint.add_theme_font_override("font", UIFonts.body())
	hint.add_theme_font_size_override("font_size", 22)
	hint.position = Vector2(1320, 960)
	add_child(hint)
	if map != null:
		cursor = map.cell_of(player_pos)


func pins() -> Array:
	return GameState.flags.get("pins_" + map.id, [])


func toggle_pin(c: Vector2i) -> void:
	var p: Array = pins().duplicate()
	var key: Array = [c.x, c.y]
	if p.has(key):
		p.erase(key)
	elif p.size() < MAX_PINS:
		p.append(key)
	GameState.flags["pins_" + map.id] = p


func _unhandled_input(event: InputEvent) -> void:
	var d: Vector2i = Vector2i.ZERO
	if event.is_action_pressed("ui_left"):
		d = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_right"):
		d = Vector2i(1, 0)
	elif event.is_action_pressed("ui_up"):
		d = Vector2i(0, -1)
	elif event.is_action_pressed("ui_down"):
		d = Vector2i(0, 1)
	elif event.is_action_pressed("ui_accept"):
		toggle_pin(cursor)
	if d != Vector2i.ZERO:
		cursor = Vector2i(clampi(cursor.x + d.x, 0, map.width - 1), clampi(cursor.y + d.y, 0, map.height - 1))
	_canvas.queue_redraw()


func _draw_map() -> void:
	if map == null:
		return
	var origin: Vector2 = Vector2(260, 60)
	var cell: float = 960.0 / float(maxi(map.width, map.height))
	_canvas.draw_rect(Rect2(origin - Vector2(20, 20), Vector2(cell * map.width + 40, cell * map.height + 40)), Color("#F2EEE4"))
	var mask: PackedByteArray = MapReveal.ensure(map.id, map.width, map.height)
	var streets: bool = MapReveal.streets_known(map.id)
	var line_col: Color = JU.color(JU.dict(JU.dict(DataDB.get_dict("palettes"), "regions"), map.borough()).get("primary"), Color("#7B2FF7"))
	for y: int in map.height:
		for x: int in map.width:
			var c: Vector2i = Vector2i(x, y)
			var seen: bool = MapReveal.is_revealed(mask, map.width, c)
			var ch: String = map.at(c)
			var street: bool = ch in [".", "R"]
			if not seen and not (streets and street):
				continue
			var col: Color = Color("#D8D2C4")
			if map.is_building(ch):
				col = Color("#B8B0A0")
			elif ch == "P" or ch == "t":
				col = Color("#9CC89A")
			elif ch == "~":
				col = Color("#8CB8E0")
			elif ch == "C":
				col = Color("#E8A070")
			elif street:
				col = Color("#FFFFFF")
			elif ch == "#":
				col = Color("#6A6A6A")
			_canvas.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), col)
	# Subway line through discovered stations, then markers.
	var st_pts: PackedVector2Array = PackedVector2Array()
	for st: Variant in JU.a(layout, "stations"):
		var sd: Dictionary = st
		var sc: Vector2i = map.cell_of(sd["pos"])
		var known: bool = GameState.discovered_stations.has(JU.s(sd, "id"))
		var sp: Vector2 = origin + (Vector2(sc) + Vector2(0.5, 0.5)) * cell
		st_pts.append(sp)
		_canvas.draw_circle(sp, cell * 0.9, Color.WHITE)
		_canvas.draw_circle(sp, cell * 0.65, line_col if known else Color("#8A8A8A"))
	if st_pts.size() >= 2:
		_canvas.draw_polyline(st_pts, line_col, cell * 0.5)
	for b: Variant in JU.a(layout, "bodegas"):
		_marker(origin, cell, (b as Dictionary)["door"], Color("#FFC830"), "square")
	for s2: Variant in JU.a(layout, "shops"):
		_marker(origin, cell, (s2 as Dictionary)["door"], Color("#12C2B0"), "diamond")
	for ct: Variant in JU.a(layout, "courts"):
		var cd: Dictionary = ct
		var seen_court: bool = GameState.has_flag("seen_court_" + JU.s(cd, "boss"))
		_marker(origin, cell, cd["gate"], Color("#E8344A") if seen_court else Color("#7A7A8A"), "skull" if seen_court else "square")
	for pin: Variant in pins():
		var pa: Array = pin
		_canvas.draw_circle(origin + (Vector2(int(pa[0]), int(pa[1])) + Vector2(0.5, 0.5)) * cell, cell * 0.5, Color("#FF3EA5"))
	var pc: Vector2i = map.cell_of(player_pos)
	_canvas.draw_circle(origin + (Vector2(pc) + Vector2(0.5, 0.5)) * cell, cell * 0.8, Color("#101014"))
	_canvas.draw_circle(origin + (Vector2(pc) + Vector2(0.5, 0.5)) * cell, cell * 0.5, Color("#3EF0FF"))
	_canvas.draw_rect(Rect2(origin + Vector2(cursor) * cell, Vector2(cell, cell)), Color("#FF3EA5"), false, 2.0)


func _marker(origin: Vector2, cell: float, wp: Vector3, col: Color, shape: String) -> void:
	var c: Vector2i = map.cell_of(wp)
	var mask: PackedByteArray = MapReveal.ensure(map.id, map.width, map.height)
	if not MapReveal.is_revealed(mask, map.width, c):
		return
	var p: Vector2 = origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell
	match shape:
		"diamond":
			_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -cell), p + Vector2(cell, 0), p + Vector2(0, cell), p + Vector2(-cell, 0)]), col)
		"skull":
			_canvas.draw_circle(p, cell * 0.9, col)
			_canvas.draw_circle(p + Vector2(-cell * 0.3, -cell * 0.1), cell * 0.2, Color.BLACK)
			_canvas.draw_circle(p + Vector2(cell * 0.3, -cell * 0.1), cell * 0.2, Color.BLACK)
		_:
			_canvas.draw_rect(Rect2(p - Vector2(cell, cell) * 0.8, Vector2(cell, cell) * 1.6), col)
