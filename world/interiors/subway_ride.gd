extends Node3D
## The loading screen is the ride (spec §5.3): a swaying subway car interior,
## tunnel lights streaking past the windows, "NEXT STOP" sign. Preloads the
## destination scene on a thread, then hands over.

const MIN_S: float = 1.6

var _t: float = 0.0
var _cam: Camera3D
var _lights: Array[Node3D] = []
var _requested: bool = false


func _ready() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = EnvPresets.build("interior")
	add_child(env)
	var seat: Material = ToonMaterials.toon(Color("#FF7A20"))
	var wall: Material = ToonMaterials.toon(Color("#C8CCD4"))
	var floor_m: Material = ToonMaterials.toon(Color("#3A3A44"))
	_box(Vector3(3.2, 0.1, 14), floor_m, Vector3(0, 0, 0))
	_box(Vector3(3.2, 0.1, 14), wall, Vector3(0, 2.4, 0))
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(0.1, 2.4, 14), wall, Vector3(1.6 * sx, 1.2, 0))
		_box(Vector3(0.6, 0.45, 12), seat, Vector3(1.25 * sx, 0.45, 0))
		for z: float in [-4.0, 0.0, 4.0]:
			var win: MeshInstance3D = _box(Vector3(0.05, 0.8, 2.4), ToonMaterials.toon(Color("#101018"), false, false, Color("#202838"), 0.6), Vector3(1.55 * sx, 1.55, z))
			win.name = "Window"
	for z2: float in [-5.0, -1.5, 2.0, 5.5]:
		_box(Vector3(0.06, 2.4, 0.06), ToonMaterials.toon(Color("#E0E4EC")), Vector3(0, 1.2, z2))
	for i: int in 6:
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color("#FFE0A0")
		l.light_energy = 2.0
		l.omni_range = 4.0
		l.position = Vector3(2.4, 1.6, -8.0 + float(i) * 3.2)
		add_child(l)
		_lights.append(l)
	var amb: OmniLight3D = OmniLight3D.new()
	amb.light_color = Color("#FFF4E0")
	amb.light_energy = 1.2
	amb.omni_range = 9.0
	amb.position = Vector3(0, 2.2, 0)
	add_child(amb)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.4, 6.0)
	_cam.fov = 60.0
	_cam.current = true
	add_child(_cam)
	_cam.look_at(Vector3(0, 1.2, -4.0))
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var sign: Label = Label.new()
	sign.text = tr("NEXT STOP: %s") % str(SceneRouter.ride_target.get("title", "")).to_upper()
	sign.add_theme_font_override("font", UIFonts.title())
	sign.add_theme_font_size_override("font_size", 48)
	sign.add_theme_color_override("font_color", Color("#FF7A20"))
	sign.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	sign.add_theme_constant_override("outline_size", 10)
	sign.position = Vector2(80, 940)
	layer.add_child(sign)
	var path: String = str(SceneRouter.ride_target.get("path", ""))
	if path != "":
		ResourceLoader.load_threaded_request(path)
		_requested = true


func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = MeshLib.box(size)
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	_cam.rotation.z = sin(_t * 3.1) * 0.012
	_cam.position.y = 1.4 + sin(_t * 7.3) * 0.01
	for l: Node3D in _lights:
		l.position.z += delta * 24.0
		if l.position.z > 10.0:
			l.position.z -= 19.2
	var path: String = str(SceneRouter.ride_target.get("path", ""))
	var loaded: bool = not _requested or ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS
	if _t >= MIN_S and loaded:
		set_process(false)
		SceneRouter.finish_ride()
