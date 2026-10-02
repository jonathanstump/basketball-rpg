class_name HUD
extends Control
## In-game HUD (spec §14): top-left Heart/Wind/Hype (flame meter), bottom-left
## Quarter Waters, bottom-right ball slots + Bag Move + Takeover-ready glow,
## top-right tokens and Rep, lock-on reticle, context prompt. Boss bar is a
## separate node (ui/boss_bar).

var game: GameWorld
var prompt: String = ""
var _t: float = 0.0
var labels: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label("hype", Vector2(292, 92), UIFonts.graffiti(), 22, HORIZONTAL_ALIGNMENT_LEFT, 200)
	_label("qw", Vector2(40, 1026), UIFonts.title(), 18, HORIZONTAL_ALIGNMENT_LEFT, 400)
	_label("bag", Vector2(1400, 1036), UIFonts.graffiti(), 24, HORIZONTAL_ALIGNMENT_LEFT, 280)
	_label("tokens", Vector2(1480, 36), UIFonts.title(), 28, HORIZONTAL_ALIGNMENT_RIGHT, 400)
	_label("rep", Vector2(1480, 74), UIFonts.title(), 24, HORIZONTAL_ALIGNMENT_RIGHT, 400)
	_label("prompt", Vector2(660, 880), UIFonts.title(), 26, HORIZONTAL_ALIGNMENT_CENTER, 600)


func _label(key: String, pos: Vector2, font: Font, size_px: int, align: HorizontalAlignment, width: float) -> Label:
	var l: Label = Label.new()
	l.position = pos
	l.size = Vector2(width, size_px + 10)
	l.horizontal_alignment = align
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	labels[key] = l
	return l


func _text(key: String, text: String, col: Color = Color.WHITE) -> void:
	var l: Label = labels[key]
	l.text = text
	l.add_theme_color_override("font_color", col)


func _process(delta: float) -> void:
	_t += delta
	scale = Vector2.ONE * Settings.get_float("ui_scale")
	if game != null and game.player != null:
		var p: SimActor = game.player
		var full: bool = p.hype.full()
		_text("hype", tr("ON FIRE!") if bool(p.flags.get("takeover", false)) else tr("HYPE"), Color("#FFE040") if full else Color("#FF7A20"))
		_text("qw", tr("QUARTER WATER x%d") % int(p.flags.get("qw", 0)))
		var bag: Dictionary = DataDB.item("bag_moves", str(p.flags.get("bag_move", "")))
		_text("bag", "" if bag.is_empty() else "%s  %d" % [tr(JU.s(bag, "name")), int(JU.f(bag, "hype"))], Color("#FFE060") if not bag.is_empty() and p.hype.value >= JU.f(bag, "hype") else Color("#8A8A9A"))
		_text("tokens", tr("%d TOKENS") % GameState.tokens, Color("#FFD860"))
		_text("rep", tr("%d REP") % GameState.rep, Color("#F2F6FF"))
		_text("prompt", prompt)
	queue_redraw()


func _bar(pos: Vector2, size: Vector2, ratio: float, col: Color, ghost: float = -1.0) -> void:
	draw_rect(Rect2(pos - Vector2(4, 4), size + Vector2(8, 8)), Color("#0B0B10"))
	draw_rect(Rect2(pos, size), Color("#24242E"))
	if ghost > ratio:
		draw_rect(Rect2(pos, Vector2(size.x * clampf(ghost, 0, 1), size.y)), Color(1, 1, 1, 0.35))
	draw_rect(Rect2(pos, Vector2(size.x * clampf(ratio, 0, 1), size.y)), col)


func _draw() -> void:
	if game == null or game.player == null:
		return
	var p: SimActor = game.player
	# Heart / Wind / Hype.
	var w_heart: float = 260.0 + p.hp_max * 0.25
	_bar(Vector2(40, 40), Vector2(w_heart, 22), p.hp / maxf(1.0, p.hp_max), Color("#E8344A"))
	_bar(Vector2(40, 74), Vector2(200.0 + p.wind.max_value * 0.6, 12), p.wind.ratio(), Color("#3CCB6A"))
	var hype: float = p.hype.value / p.hype.max_value
	var flame: Color = Color("#FF7A20").lerp(Color("#FFE040"), 0.5 + 0.5 * sin(_t * 9.0)) if hype >= 0.999 else Color("#FF7A20")
	_bar(Vector2(40, 98), Vector2(240, 14), hype, flame)
	# Quarter Waters.
	var qw: int = int(p.flags.get("qw", 0))
	for i: int in qw:
		var x: float = 40.0 + float(i) * 30.0
		draw_rect(Rect2(Vector2(x, 980), Vector2(20, 34)), Color("#0B0B10"))
		draw_rect(Rect2(Vector2(x + 3, 990), Vector2(14, 21)), Color("#FF5AA0"))
		draw_rect(Rect2(Vector2(x + 6, 982), Vector2(8, 8)), Color("#F2F2F2"))
	# Ball slots, Bag Move, Takeover glow.
	var slots: Array = [str(p.flags.get("ball_item", GameState.equipment.get("ball_1", ""))), GameState.equipment.get("ball_2", "")]
	for i2: int in 2:
		var c: Vector2 = Vector2(1700.0 + float(i2) * 90.0, 990)
		draw_circle(c, 38.0, Color("#0B0B10"))
		var item: String = str(slots[i2])
		draw_circle(c, 32.0, BallView._ball_color(item) if item != "" else Color("#2A2A34"))
		if i2 == 0 and not p.has_ball:
			draw_line(c - Vector2(24, 24), c + Vector2(24, 24), Color("#FF3E3E"), 6.0)
	if hype >= 0.999:
		draw_arc(Vector2(1745, 990), 100.0, 0.0, TAU, 48, Color(1.0, 0.5, 0.1, 0.5 + 0.4 * sin(_t * 6.0)), 6.0)
	# Tokens / Rep.
	# Lock-on reticle.
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null and game.player_hooper != null and game.player_hooper.lock_target != null:
		var t: SimActor = game.player_hooper.lock_target
		var wp: Vector3 = t.pos + Vector3(0, t.height * 0.6, 0)
		if not cam.is_position_behind(wp):
			var sp: Vector2 = PopupLayer.world_to_canvas(get_viewport(), cam, wp) / scale
			var r: float = 18.0 + 3.0 * sin(_t * 5.0)
			draw_arc(sp, r, 0.0, TAU, 24, Color("#FF3EA5"), 3.0)
			draw_circle(sp, 4.0, Color.WHITE)
			if t.composure != null:
				_bar(sp + Vector2(-40, 30), Vector2(80, 6), t.composure.ratio(), Color("#F4B400"))
