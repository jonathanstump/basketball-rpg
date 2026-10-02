extends GameWorld
## M2 ball lab: half court with a regulation chain-net hoop, two crate hoops,
## Wire Kicks on a power line and training dummies to pass at.

var dummies: Array[SimActor] = []


func _ready() -> void:
	setup_world("uptown")
	build_lab()
	spawn_player(Vector3(0, 0, 0))
	camera_rig.yaw = 0.0
	camera_rig.snap()


func build_lab() -> void:
	sim.collision.set_bounds(Vector2(-30, -30), Vector2(30, 30))
	var hoop: SimHoop = balls.add_hoop(SimHoop.regulation("lab_hoop", Vector3(0, 0, -7.0), Vector3(0, 0, 1)))
	presenter.add_hoop_view(hoop)
	CourtFloor.build(level_root, hoop, Vector2(30, 28), Vector3(0, -0.02, 0))
	KitProps.ground_tile(level_root, Vector3(0, -0.03, 0), Vector2(70, 70), ToonMaterials.asphalt())
	for side: float in [-1.0, 1.0]:
		var crate: SimHoop = balls.add_hoop(SimHoop.crate("crate_%d" % int(side), Vector3(13.0 * side, 0, 2.0), Vector3(-side, 0, 0)))
		presenter.add_hoop_view(crate)
		KitProps.streetlight(level_root, sim.collision, Vector3(15.5 * side, 0, -6.0), Vector3(-side, 0, 0))
	balls.add_wire_kicks("lab_kicks", Vector3(0, 6.0, 9.0))
	presenter.add_wire_kicks_view("lab_kicks", Vector3(0, 6.0, 9.0), Vector3(1, 0, 0), Color("#7B2FF7"))
	for p: Vector3 in [Vector3(-4, 0, -4), Vector3(4, 0, -4)]:
		var d: SimActor = SimActor.new()
		d.kind = "enemy"
		d.team = 1
		d.display_name = "Dummy"
		d.pos = p
		d.radius = 0.45
		d.height = 1.8
		d.hp = 9999.0
		d.hp_max = 9999.0
		d.contest_radius = 1.5
		d.facing = PI
		sim.add_actor(d)
		add_actor_view(d, {"top_color": "#C8A060", "shorts_color": "#6A5030", "skin": "#B08A5A", "hair_style": "bald", "height": 1.3})
		dummies.append(d)


func setup_render_smoke(entry: Dictionary) -> void:
	if JU.s(entry, "mode") == "shoot":
		var si: ScriptedInput = ScriptedInput.new()
		si.hold(5, 30, "shoot")
		ready.connect(func() -> void: use_scripted_input(si))
