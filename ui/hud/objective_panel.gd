class_name ObjectivePanel
extends Control
## Current objective (ObjectiveRules) under the tokens/Rep, plus a world
## marker: a diamond over the target (court gate, or the crossing that leads
## toward it) with the distance, or an arrow on the screen edge when it's
## off-screen. Child of the HUD so it follows the UI-scale setting. Your
## dropped chain gets its own amber marker (revision 8), shown even with the
## objective marker turned off.

var game: GameWorld
var objective: Dictionary = {}
var has_target: bool = false
var target: Vector3 = Vector3.ZERO
var target_label: String = ""
var has_chain: bool = false
var chain_target: Vector3 = Vector3.ZERO
var chain_label: String = ""
var _title: Label
var _detail: Label
var _head: Label
var _t: float = 0.0
var _changed_t: float = 0.0
var _last_title: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head = _mk(UIFonts.title(), 18, Vector2(1440, 116), Color("#F4B400"))
	_title = _mk(UIFonts.title(), 24, Vector2(1440, 140), Color.WHITE)
	_detail = _mk(UIFonts.body(), 18, Vector2(1440, 174), Color("#E6E6F0"))
	_detail.size = Vector2(440, 60)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _mk(font: Font, px: int, pos: Vector2, col: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.position = pos
	l.size = Vector2(440, px + 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func set_objective(obj: Dictionary) -> void:
	objective = obj
	var title: String = tr(JU.s(obj, "title"))
	if title != _last_title:
		if _last_title != "" or title != "":
			_changed_t = 4.0
		_last_title = title
	_head.text = tr("NEW WORD") if _changed_t > 0.0 and title != "" else (tr("THE WORD") if title != "" else "")
	_title.text = title
	_detail.text = tr(JU.s(obj, "detail"))


func _process(delta: float) -> void:
	_t += delta
	visible = game == null or game.menu == null   # the map / menus have the screen
	_changed_t = maxf(0.0, _changed_t - delta)
	if _changed_t <= 0.0 and _head.text == tr("NEW WORD"):
		_head.text = tr("THE WORD")
	_head.add_theme_color_override("font_color", Color("#FFE060").lerp(Color("#FF3EA5"), 0.5 + 0.5 * sin(_t * 8.0)) if _changed_t > 0.0 else Color("#F4B400"))
	queue_redraw()


func _draw() -> void:
	if game == null or game.player == null:
		return
	if has_target and Settings.get_bool("objective_marker"):
		_marker(target, target_label, Color("#FFE060"))
	if has_chain:
		_marker(chain_target, chain_label, Color("#FF9A2E"))


func _marker(at: Vector3, label: String, col: Color) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var s: Vector2 = get_parent().scale if get_parent() is Control else Vector2.ONE
	var vs: Vector2 = get_viewport_rect().size / s
	var wp: Vector3 = at + Vector3(0, 3.0, 0)
	var dist: float = Vector2(at.x - game.player.pos.x, at.z - game.player.pos.z).length()
	var text: String = "%s  %dm" % [tr(label), int(round(dist))]
	var font: Font = UIFonts.title()
	var pulse: float = 0.5 + 0.5 * sin(_t * 4.0)
	var behind: bool = cam.is_position_behind(wp)
	var sp: Vector2 = PopupLayer.world_to_canvas(get_viewport(), cam, wp) / s
	var margin: float = 70.0
	var on_screen: bool = not behind and sp.x > margin and sp.x < vs.x - margin and sp.y > margin and sp.y < vs.y - margin
	if on_screen:
		var d: float = 14.0 + 3.0 * pulse
		var pts: PackedVector2Array = PackedVector2Array([sp + Vector2(0, -d), sp + Vector2(d, 0), sp + Vector2(0, d), sp + Vector2(-d, 0)])
		draw_colored_polygon(pts, Color("#0B0B10"))
		draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -d + 4), sp + Vector2(d - 4, 0), sp + Vector2(0, d - 4), sp + Vector2(-d + 4, 0)]), col)
		draw_string_outline(font, sp + Vector2(-160, -d - 10), text, HORIZONTAL_ALIGNMENT_CENTER, 320, 20, 6, Color("#0B0B10"))
		draw_string(font, sp + Vector2(-160, -d - 10), text, HORIZONTAL_ALIGNMENT_CENTER, 320, 20, col)
		return
	# Off-screen: an arrow on the edge pointing toward it.
	var center: Vector2 = vs * 0.5
	var dir: Vector2 = sp - center
	if behind:
		dir = -dir
	if dir.length() < 1.0:
		dir = Vector2.UP
	dir = dir.normalized()
	var half: Vector2 = center - Vector2(margin, margin)
	var k: float = minf(half.x / maxf(0.001, absf(dir.x)), half.y / maxf(0.001, absf(dir.y)))
	var p: Vector2 = center + dir * k
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = p + dir * (14.0 + 4.0 * pulse)
	draw_colored_polygon(PackedVector2Array([tip + dir * 4.0, p - dir * 8.0 + side * 18.0, p - dir * 8.0 - side * 18.0]), Color("#0B0B10"))
	draw_colored_polygon(PackedVector2Array([tip, p - dir * 4.0 + side * 13.0, p - dir * 4.0 - side * 13.0]), col)
	var tp: Vector2 = p - dir * 46.0 + Vector2(-160, 6)
	tp.x = clampf(tp.x, 8.0, vs.x - 328.0)   # keep the label on screen
	draw_string_outline(font, tp, text, HORIZONTAL_ALIGNMENT_CENTER, 320, 18, 6, Color("#0B0B10"))
	draw_string(font, tp, text, HORIZONTAL_ALIGNMENT_CENTER, 320, 18, col)
