class_name CreditsScreen
extends Control
## Credits (spec §3.7). Scrolls over dawn (Daybreak) or the night (Overtime),
## then returns you to your start district — or offers Run It Back+.

const LINES: PackedStringArray = [
	"CONCRETE CROWN", "", "One ball. Five boroughs. No fouls.", "", "",
	"DESIGN, CODE, ART & SOUND", "Procedurally built in Godot 4", "", "",
	"FONTS", "Bungee — SIL Open Font License", "Permanent Marker — Apache License 2.0", "Inter — SIL Open Font License", "", "",
	"TOOLS", "Godot Engine — MIT License", "GUT (Godot Unit Test) — MIT License", "", "",
	"THE BOROUGHS", "The Bronx · Brooklyn · Queens · Staten Island · Uptown", "", "",
	"THE CATS", "Papi · Chulo · Biscuit · Mami · Tony · Bagel · Brownie · Mrs. Whiskers", "Momo · Mango · Saffron · Taco · Gus · Rocco · Pickles · Ferry",
	"Duke · Sugar · Smokey · Lady · Broadway · Chairman · Penny · Lex", "", "",
	"Every legend came through the Garden.", "Thanks for running it with us.",
]

var scroll: float = 0.0
var label: Label
var ending: String = "daybreak"
var finished: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var params: Dictionary = SceneRouter.take_params()
	ending = str(params.get("ending", "daybreak"))
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#F2A65A") if ending == "daybreak" else Color("#0A0A1E")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ending == "daybreak":
		var sun: Panel = Panel.new()
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color("#FFE6A0")
		sb.set_corner_radius_all(200)
		sun.add_theme_stylebox_override("panel", sb)
		sun.position = Vector2(760, 820)
		sun.size = Vector2(400, 400)
		add_child(sun)
	label = Label.new()
	label.text = "\n".join(LINES)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UIFonts.title())
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color("#1A1020") if ending == "daybreak" else Color("#F2F6FF"))
	label.position = Vector2(0, 600)
	label.size = Vector2(1920, 2400)
	add_child(label)
	if DisplayServer.get_name() == "headless":
		scroll = 99999.0


func _process(delta: float) -> void:
	scroll += delta * 70.0
	label.position.y = 600.0 - scroll
	if not finished and (label.position.y < -2200.0 or Input.is_action_just_pressed("ui_accept")):
		done()


func done() -> void:
	finished = true
	var d: String = FrontEndFlow.start_district(GameState.start_borough)
	SaveSystem.request_autosave()
	SceneRouter.goto_district(d, {}, false)
