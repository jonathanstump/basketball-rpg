class_name GameWorld
extends Node3D
## Base for every playable scene (labs, districts, arenas, interiors): owns
## the SimWorld, steps it at 60 Hz, spawns views, the camera rig, region
## environment and light budget. Gameplay lives in the sim; this only presents.

signal sim_stepped(frame: int)

var sim: SimWorld
var region: String = "brooklyn"
var camera_rig: CameraRig
var env_node: WorldEnvironment
var views: Dictionary = {}          # actor id -> Node3D view
var player: SimActor = null
var player_hooper: Hooper = null
var human_input: HumanInput = null
var paused_sim: bool = false
var level_root: Node3D
var balls: BallSystem
var presenter: SimPresenter
var hud_layer: CanvasLayer
var shot_meter: ShotMeter
var player_ball_module: HooperBall = null


func _init() -> void:
	sim = SimWorld.new(1)
	balls = BallSystem.new(sim)


func setup_world(region_id: String) -> void:
	region = region_id
	level_root = Node3D.new()
	level_root.name = "Level"
	add_child(level_root)
	env_node = WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = EnvPresets.build(region)
	add_child(env_node)
	add_child(EnvPresets.moon_light(region))
	RenderingServer.global_shader_parameter_set("cc_rim_tint", EnvPresets.rim_tint(region))
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	EnvPresets.apply_viewport(get_viewport(), Settings.get_string("quality"))
	var fx: PostFX = PostFX.new()
	fx.name = "PostFX"
	add_child(fx)
	var lb: LightBudget = LightBudget.new()
	lb.name = "LightBudget"
	add_child(lb)
	presenter = SimPresenter.new(self)
	add_child(presenter)
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	hud_layer.layer = 10
	add_child(hud_layer)
	var popups: PopupLayer = PopupLayer.new()
	popups.name = "Popups"
	add_child(popups)
	shot_meter = ShotMeter.new()
	shot_meter.name = "ShotMeter"
	hud_layer.add_child(shot_meter)
	sim.sim_event.connect(_on_sim_event)
	AudioDirector.set_region(region)


func spawn_player(pos: Vector3, profile: Dictionary = {}, stats: Dictionary = {}) -> SimActor:
	var a: SimActor = SimActor.new()
	a.kind = "hooper"
	a.team = 0
	a.display_name = "Player"
	a.pos = pos
	a.stats = stats if not stats.is_empty() else GameState.stats.duplicate()
	if a.stats.is_empty():
		a.stats = JU.dict(DataDB.archetype("two_way"), "stats").duplicate()
	sim.add_actor(a)
	player_hooper = Hooper.new(a, sim)
	a.controller = player_hooper
	human_input = HumanInput.new()
	human_input.camera = camera_rig
	a.input_source = human_input
	player = a
	player_ball_module = HooperBall.new(balls)
	player_hooper.add_module(player_ball_module)
	var item: String = str(GameState.equipment.get("ball_1", "ball_rec"))
	if not DataDB.has_item("balls", item):
		item = "ball_rec"
	balls.give(balls.spawn_ball(item, pos, a), a)
	BallProps.apply(a, item)
	add_actor_view(a, profile if not profile.is_empty() else GameState.profile)
	shot_meter.module = player_ball_module
	shot_meter.actor = a
	shot_meter.camera = camera_rig.camera
	camera_rig.follow = a
	camera_rig.snap()
	return a


func use_scripted_input(si: InputSource) -> void:
	if player != null:
		player.input_source = si


func add_actor_view(a: SimActor, profile: Dictionary = {}) -> ActorView:
	var v: ActorView = ActorView.create(a, profile)
	add_child(v)
	views[a.id] = v
	return v


func remove_actor(a: SimActor) -> void:
	sim.remove_actor(a)
	if views.has(a.id):
		(views[a.id] as Node).queue_free()
		views.erase(a.id)


func _physics_process(_delta: float) -> void:
	if paused_sim:
		return
	_player_lock_on()
	sim.step()
	presenter.sync_balls()
	for v: Variant in views.values():
		if v is ActorView:
			(v as ActorView).physics_synced()
	sim_stepped.emit(sim.frame)


func _player_lock_on() -> void:
	if player == null or player_hooper == null:
		return
	if player.input.pressed("lock_on"):
		if player_hooper.lock_target != null:
			set_lock(null)
		else:
			set_lock(_best_lock_target())
	var lt: SimActor = player_hooper.lock_target
	if lt != null and (not lt.alive or lt.dist_to(player) > JU.f(JU.dict(camera_rig.cfg, "lockon"), "lock_range_m", 20.0) * 1.5):
		set_lock(null)


func _best_lock_target() -> SimActor:
	var best: SimActor = null
	var best_score: float = 1e9
	var range_m: float = JU.f(JU.dict(DataDB.tuning("camera"), "lockon"), "lock_range_m", 20.0)
	for o: SimActor in sim.hostiles_of(player):
		var d: float = o.dist_to(player)
		if d > range_m:
			continue
		var to: Vector3 = (o.pos - player.pos).normalized()
		var score: float = d - to.dot(camera_rig.forward_flat()) * 6.0
		if score < best_score:
			best_score = score
			best = o
	return best


func set_lock(target: SimActor) -> void:
	player_hooper.lock_target = target
	camera_rig.lock_target = target
	var v: ActorView = views.get(player.id, null)
	if v != null:
		v.animator.look_target = target.pos if target != null else Vector3.INF


func _on_sim_event(ev: Dictionary) -> void:
	## Hook for subclasses; also forwards presentation events.
	presenter.on_event(ev)
	match str(ev.get("type", "")):
		"hitstop":
			EventBus.hitstop_requested.emit(int(ev.get("frames", 3)))


func _exit_tree() -> void:
	if player_hooper != null:
		player_hooper.lock_target = null
	sim.dispose()
	player = null
	player_hooper = null


func setup_render_smoke(_entry: Dictionary) -> void:
	pass
