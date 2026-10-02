class_name CreatorScreen
extends Node3D
## Character creator (spec §6.2) -> archetype (§6.3) -> start borough with
## the tier map preview (§4.3) -> "I Got Next". A turntable shows the look;
## left/right (or accept) cycles a value.

const LOOK_KEYS: PackedStringArray = ["skin", "face_shape", "eye_shape", "eye_color", "brows", "nose", "mouth", "marks", "facial_hair",
	"hair_style", "hair_color", "height", "voice"]
const LOOK_NAMES: Dictionary = {"skin": "Skin tone", "face_shape": "Face shape", "eye_shape": "Eyes", "eye_color": "Eye color", "brows": "Brows",
	"nose": "Nose", "mouth": "Mouth", "marks": "Freckles & marks", "facial_hair": "Facial hair", "hair_style": "Hair", "hair_color": "Hair color",
	"height": "Height", "voice": "Voice"}

var profile: Dictionary = CreatorRules.default_profile()
var archetype: String = "two_way"
var borough: String = "brooklyn"
var slot: int = 0
var menu: CanvasLayer = null
var turntable: Node3D
var rig: Node3D = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _look_index: int = 0
var _spin: float = 0.0
var _name_edit: LineEdit = null


func _ready() -> void:
	var params: Dictionary = SceneRouter.take_params()
	slot = int(params.get("slot", 0))
	rng.seed = int(Time.get_ticks_usec())
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = EnvPresets.build("brooklyn")
	add_child(env)
	add_child(EnvPresets.moon_light("brooklyn"))
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(-0.55, 1.05, 4.4)
	cam.look_at_from_position(cam.position, Vector3(-0.55, 0.8, 0), Vector3.UP)
	cam.fov = 38.0
	add_child(cam)
	var key: OmniLight3D = OmniLight3D.new()
	key.position = Vector3(0.5, 2.2, 2.0)
	key.light_energy = 2.0
	key.omni_range = 8.0
	key.light_color = Color("#FFE6C8")
	add_child(key)
	var rim: OmniLight3D = OmniLight3D.new()
	rim.position = Vector3(-1.6, 1.8, -1.2)
	rim.light_energy = 2.5
	rim.light_color = Color("#7B2FF7")
	add_child(rim)
	KitProps.ground_tile(self, Vector3(0, 0, 0), Vector2(30, 30), ToonMaterials.asphalt())
	turntable = Node3D.new()
	turntable.position = Vector3(0.55, 0, 0)
	add_child(turntable)
	_rebuild_rig()
	open_look()


func _process(delta: float) -> void:
	_spin += delta
	turntable.rotation.y = PI + sin(_spin * 0.6) * 0.9


func _rebuild_rig() -> void:
	if rig != null:
		rig.queue_free()
	var p: Dictionary = profile.duplicate()
	var r: PuppetRig = CharacterBuilder.build(p)
	var holder: Node3D = Node3D.new()
	holder.scale = Vector3.ONE * float(p.get("height", 1.0)) * 1.25
	holder.add_child(r)
	rig = holder
	turntable.add_child(holder)


func open_menu(m: CanvasLayer) -> void:
	close_menu()
	add_child(m)
	menu = m


func close_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null


func _list(title: String, opts: Array[Dictionary], footer: String, on_choose: Callable, on_back: Callable, start: int = 0) -> ListMenu:
	var m: ListMenu = ListMenu.new()
	m.set_options(title, opts, footer)
	m.index = clampi(start, 0, maxi(0, opts.size() - 1))
	m.chosen.connect(on_choose)
	m.cancelled.connect(on_back)
	open_menu(m)
	return m


# ------------------------------------------------------------ look

func open_look() -> void:
	var opts: Array[Dictionary] = []
	for k: String in LOOK_KEYS:
		opts.append({"id": k, "label": "%s:  %s" % [LOOK_NAMES[k], CreatorRules.label_of(k, profile.get(k))], "detail": "Left/Right or Accept to change."})
	opts.append({"id": "_random", "label": "Randomize", "detail": "Roll a whole new look."})
	opts.append({"id": "_name", "label": "Name:  %s" % str(profile.get("name", "")), "detail": "Your streetball name."})
	opts.append({"id": "_next", "label": "Next: Archetype"})
	opts.append({"id": "_back", "label": "Back to title"})
	var m: ListMenu = _list("YOUR HOOPER", opts, "No labels, no boxes. Just you.", _on_look, func() -> void:
		close_menu()
		SceneRouter.goto(FrontEndFlow.TITLE), _look_index)
	m.adjusted.connect(_adjust)


func _on_look(id: String) -> void:
	match id:
		"_random":
			var keep: String = str(profile.get("name", ""))
			profile = CreatorRules.randomize(rng)
			profile["name"] = keep
			_look_index = LOOK_KEYS.size()
			_rebuild_rig()
			open_look()
		"_name":
			open_name()
		"_next":
			open_archetype()
		"_back":
			close_menu()
			SceneRouter.goto(FrontEndFlow.TITLE)
		_:
			_adjust(id, 1)


func _adjust(id: String, dir: int) -> void:
	if not LOOK_KEYS.has(id):
		return
	CreatorRules.cycle(profile, id, dir)
	_look_index = LOOK_KEYS.find(id)
	_rebuild_rig()
	open_look()


# ------------------------------------------------------------ name

func open_name() -> void:
	var opts: Array[Dictionary] = []
	for pre: Variant in JU.a(CreatorRules.cfg(), "name_prefixes"):
		for base: Variant in JU.a(CreatorRules.cfg(), "name_bases"):
			var n: String = CreatorRules.compose_name(str(pre), str(base))
			opts.append({"id": n, "label": n})
	opts.push_front({"id": "_type", "label": "Type your own...", "detail": "Letters, numbers, spaces. Keep it clean."})
	_list("STREETBALL NAME", opts, "Pick one or type your own.", func(id: String) -> void:
		if id == "_type":
			_type_name()
			return
		profile["name"] = id
		_look_index = LOOK_KEYS.size() + 1
		open_look(), func() -> void: open_look())


func _type_name() -> void:
	close_menu()
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 40
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.9)
	bg.position = Vector2(560, 380)
	bg.size = Vector2(800, 260)
	layer.add_child(bg)
	var info: Label = Label.new()
	info.text = "TYPE A NAME  (Enter to confirm, Esc to cancel)"
	info.add_theme_font_override("font", UIFonts.title())
	info.add_theme_font_size_override("font_size", 28)
	info.position = Vector2(600, 410)
	layer.add_child(info)
	_name_edit = LineEdit.new()
	_name_edit.max_length = JU.i(CreatorRules.cfg(), "max_name_length", 18)
	_name_edit.position = Vector2(600, 480)
	_name_edit.size = Vector2(720, 60)
	_name_edit.add_theme_font_size_override("font_size", 34)
	_name_edit.text = str(profile.get("name", ""))
	layer.add_child(_name_edit)
	_name_edit.text_submitted.connect(func(t: String) -> void:
		var clean: String = CreatorRules.clean_name(t)
		if CreatorRules.is_allowed(clean):
			profile["name"] = clean
			layer.queue_free()
			menu = null
			open_look()
		else:
			info.text = "TRY ANOTHER NAME (keep it clean, 2+ letters)")
	open_menu(layer)
	_name_edit.grab_focus()


# ------------------------------------------------------------ archetype + borough

func open_archetype() -> void:
	var opts: Array[Dictionary] = []
	var ids: Array = DataDB.catalog("archetypes").keys()
	ids.sort()
	for id: Variant in ids:
		var a: Dictionary = DataDB.archetype(str(id))
		var st: Dictionary = JU.dict(a, "stats")
		var line: PackedStringArray = PackedStringArray()
		for s: String in DataSchemas.STATS:
			line.append("%s %d" % [s.substr(0, 3).to_upper(), int(st.get(s, 0))])
		var bm: String = JU.s(a, "start_bag_move")
		opts.append({"id": str(id), "label": JU.s(a, "name"), "detail": "%s\n\n%s\nBall: %s\nBag Move: %s" % [JU.s(a, "blurb"), "  ".join(line),
			JU.s(DataDB.ball(JU.s(a, "start_ball")), "name"), JU.s(DataDB.item("bag_moves", bm), "name", "none") if bm != "" else "none"]})
	_list("ARCHETYPE", opts, "All start at Level 1. Nobody is the challenge class.", func(id: String) -> void:
		archetype = id
		open_borough(), func() -> void: open_look(), ids.find(archetype))


func open_borough() -> void:
	var opts: Array[Dictionary] = []
	for b: String in DataSchemas.BOROUGHS:
		var info: Dictionary = CreatorRules.borough(b)
		var ok: bool = CreatorRules.start_available(b)
		opts.append({"id": b, "label": JU.s(info, "name") + ("" if ok else "  (closed tonight)"), "enabled": ok,
			"detail": "%s\nHome court: %s\n\nTIER MAP FROM HERE\n%s" % [JU.s(info, "blurb"), JU.s(info, "home_court"), CreatorRules.tier_preview(b)]})
	_list("START BOROUGH", opts, "Closest boroughs are easiest. Tier sticks for the whole run.", func(id: String) -> void:
		borough = id
		open_confirm(), func() -> void: open_archetype(), DataSchemas.BOROUGHS.find(borough))


func open_confirm() -> void:
	var opts: Array[Dictionary] = [{"id": "go", "label": "I got next.", "detail": "%s\n%s from %s." % [str(profile.get("name", "")),
		JU.s(DataDB.archetype(archetype), "name"), JU.s(CreatorRules.borough(borough), "name")]}, {"id": "_back", "label": "Back"}]
	_list("READY?", opts, "", func(id: String) -> void:
		if id == "go":
			close_menu()
			FrontEndFlow.start_new_game(archetype, borough, profile.duplicate(), slot)
		else:
			open_borough(), func() -> void: open_borough())
