extends GameWorld
## M1 movement lab: one greybox street with a brownstone row, a walk-up, a
## streetlight, hydrant, water tower and a bodega front (spec §16 M1).

@export var auto_capture_mouse: bool = false


func _ready() -> void:
	setup_world("brooklyn")
	build_street()
	spawn_player(Vector3(0, 0, 4))
	camera_rig.yaw = 0.0
	camera_rig.snap()
	if auto_capture_mouse and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func build_street() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1101
	var col: WorldCollision = sim.collision
	col.set_bounds(Vector2(-40, -20), Vector2(40, 24))
	var root: Node3D = level_root
	var asphalt: Material = ToonMaterials.asphalt()
	var walk: Material = ToonMaterials.toon(Color("#4A4A55"), false)
	KitProps.ground_tile(root, Vector3(0, 0, 4), Vector2(80, 10), asphalt)
	# Sidewalks are 15 cm curbs (walkable platforms).
	for z: float in [-3.0, 11.0]:
		KitProps.ground_tile(root, Vector3(0, 0, z), Vector2(80, 4), walk, 0.15)
		col.add_box(Vector3(0, 0.075, z), Vector3(80, 0.15, 4), "curb")
	KitProps.ground_tile(root, Vector3(0, 0, -15), Vector2(80, 20), walk)
	KitProps.ground_tile(root, Vector3(0, 0, 20), Vector2(80, 10), walk)
	# North side (facing +Z): brownstone row, bodega, walk-up.
	var x: float = -34.0
	for i: int in 4:
		KitBuildings.brownstone(root, col, Vector3(x + 3.5, 0, -9.0), 7.0, 8.0, rng.randi_range(3, 4), Vector3(0, 0, 1), rng)
		x += 7.2
	KitBuildings.building(root, col, Vector3(-1.0, 0, -9.0), Vector3(8.0, 6.6, 8.0), Color("#5A4A60"), 7.0, 0.5)
	KitProps.bodega_front(root, col, Vector3(-1.0, 0, -5.0), Vector3(0, 0, 1), "DELI GROCERY 24HR", Color("#12C2B0"))
	KitBuildings.walkup(root, col, Vector3(10.0, 0, -9.0), 10.0, 8.0, 6, Vector3(0, 0, 1), rng)
	KitBuildings.building(root, col, Vector3(24.0, 0, -9.5), Vector3(14.0, 34.0, 9.0), Color("#3A4250"), 12.0, 0.55)
	# South side (facing -Z).
	x = -34.0
	for i2: int in 5:
		KitBuildings.walkup(root, col, Vector3(x + 5.0, 0, 17.5), 10.0, 8.0, rng.randi_range(5, 6), Vector3(0, 0, -1), rng)
		x += 14.0
	KitProps.streetlight(root, col, Vector3(-8.0, 0.15, -1.6), Vector3(0, 0, 1))
	KitProps.streetlight(root, col, Vector3(14.0, 0.15, 9.6), Vector3(0, 0, -1))
	KitProps.streetlight(root, col, Vector3(-26.0, 0.15, 9.6), Vector3(0, 0, -1))
	KitProps.hydrant(root, col, Vector3(4.0, 0.15, -1.8))
	KitBuildings.water_tower(root, Vector3(-1.0, 6.6, -9.0))


func setup_render_smoke(entry: Dictionary) -> void:
	auto_capture_mouse = false
	if JU.s(entry, "mode") == "cutaway":
		ready.connect(func() -> void:
			player.pos = Vector3(-20.0, 0.15, -2.0)
			camera_rig.yaw = PI
			camera_rig.snap())
	if JU.s(entry, "mode") == "walk":
		var si: ScriptedInput = ScriptedInput.new()
		si.move_at(0, Vector2(1, 0))
		ready.connect(func() -> void: use_scripted_input(si))
