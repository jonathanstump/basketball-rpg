class_name PopupLayer
extends CanvasLayer
## Sticker-style text pops (spec §12.1): "SPLASH!", "ANKLES!", "POSTERIZED!",
## "COOKED"... anchored to a world position, scale-pop then float and fade.

const STYLES: Dictionary = {
	"splash": {"color": "#3EF0FF", "size": 64},
	"good": {"color": "#F2F6FF", "size": 46},
	"miss": {"color": "#9A9AB0", "size": 40},
	"bad": {"color": "#FF5A5A", "size": 52},
	"style": {"color": "#F4B400", "size": 72},
	"hype": {"color": "#FF3EA5", "size": 56},
	"tokens": {"color": "#FFD860", "size": 36},
	"damage": {"color": "#FFFFFF", "size": 42},
	"damage_heavy": {"color": "#FF9A3E", "size": 54},
	"damage_crit": {"color": "#FFE040", "size": 68},
	"big": {"color": "#FF3EA5", "size": 110},
}

var camera_getter: Callable = Callable()
var _items: Array[Dictionary] = []


func _ready() -> void:
	layer = 20
	EventBus.popup_text.connect(show_text)


func show_text(text: String, world_pos: Vector3, style: String = "good") -> void:
	var st: Dictionary = STYLES.get(style, STYLES["good"])
	var l: Label = Label.new()
	l.text = tr(text)
	l.add_theme_font_override("font", UIFonts.graffiti())
	l.add_theme_font_size_override("font_size", int(st["size"]))
	l.add_theme_color_override("font_color", Color(str(st["color"])))
	l.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	l.add_theme_constant_override("outline_size", 14)
	l.pivot_offset = Vector2(160, 40)
	l.size = Vector2(320, 80)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.rotation = randf_range(-0.12, 0.12)
	add_child(l)
	_items.append({"label": l, "pos": world_pos, "t": 0.0})


func _process(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	for it: Dictionary in _items.duplicate():
		var l: Label = it["label"]
		var t: float = float(it["t"]) + delta
		it["t"] = t
		var wp: Vector3 = (it["pos"] as Vector3) + Vector3(0, 1.6 + t * 0.8, 0)
		if cam != null and not cam.is_position_behind(wp):
			l.position = world_to_canvas(get_viewport(), cam, wp) - l.size * 0.5
		var pop: float = 1.0 + 0.6 * maxf(0.0, 1.0 - t * 8.0)
		l.scale = Vector2.ONE * pop
		l.modulate.a = clampf(1.6 - t, 0.0, 1.0)
		if t > 1.6:
			_items.erase(it)
			l.queue_free()


static func world_to_canvas(vp: Viewport, cam: Camera3D, p: Vector3) -> Vector2:
	## unproject_position already returns canvas units under canvas_items
	## stretch (verified by render smoke); kept as one place to adjust.
	var _unused: Viewport = vp
	return cam.unproject_position(p)
