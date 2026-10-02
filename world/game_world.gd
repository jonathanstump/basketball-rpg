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
var combat: CombatSystem
var spawner: EnemySpawner
var lifecycle: PlayerLifecycle
var time_fx: TimeFX
var hud: HUD
var menu: CanvasLayer = null


func _init() -> void:
	sim = SimWorld.new(1)
	balls = BallSystem.new(sim)
	combat = CombatSystem.new(sim, balls)
	spawner = EnemySpawner.new(sim, combat, balls)


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
	hud = HUD.new()
	hud.name = "HUDDraw"
	hud.game = self
	hud_layer.add_child(hud)
	time_fx = TimeFX.new()
	time_fx.name = "TimeFX"
	add_child(time_fx)
	lifecycle = PlayerLifecycle.new(self)
	add_child(lifecycle)
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
	var item: String = str(GameState.equipment.get("ball_1", "ball_rec"))
	if not DataDB.has_item("balls", item):
		item = "ball_rec"
	player_hooper = CombatSim.equip_hooper(sim, balls, combat, a, item, true)
	for m: RefCounted in player_hooper.modules:
		if m is HooperBall:
			player_ball_module = m
	human_input = HumanInput.new()
	human_input.camera = camera_rig
	a.input_source = human_input
	player = a
	a.flags["qw"] = GameState.quarter_waters
	a.flags["qw_heal_pct"] = 0.35 + 0.05 * float(GameState.sugar_rush)
	a.flags["bag_move"] = str(GameState.equipment.get("bag_move", ""))
	lifecycle.respawn_point = pos
	PlayerBuild.apply(a, player_hooper)
	a.flags["qw"] = GameState.quarter_waters
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


func open_menu(m: CanvasLayer) -> void:
	close_menu()
	add_child(m)
	menu = m
	paused_sim = true


func close_menu() -> void:
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	menu = null
	paused_sim = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and menu == null and player != null:
		PauseMenu.open(self)
		get_viewport().set_input_as_handled()
	elif menu is MapScreen and (event.is_action_pressed("map") or event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		close_menu()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if paused_sim:
		return
	_player_lock_on()
	sim.step()
	presenter.sync_balls()
	lifecycle.physics_check()
	if player != null:
		GameState.quarter_waters = int(player.flags.get("qw", 0))
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
		"actor_killed":
			if player != null and int(ev["actor"]) == player.id:
				lifecycle.on_player_killed()
		"rose_saved":
			GameState.flags["rose_ready"] = false
		"enemy_spawned":
			var ea: SimActor = sim.actor_by_id(int(ev["actor"]))
			if ea != null and not views.has(ea.id):
				var ev_view: ActorView = EnemyViewBuilder.create(ea)
				add_child(ev_view)
				views[ea.id] = ev_view
		"enemy_defeated":
			GameState.add_rep(PlayerBuild.reward_rep(int(ev["rep"])))
			GameState.add_tokens(PlayerBuild.reward_tokens(int(ev["tokens"])))
			for drop: String in (ev["drops"] as PackedStringArray):
				if not drop.begins_with("loot:"):
					GameState.add_item(drop, 1)
			if int(ev["rep"]) > 0:
				EventBus.popup_text.emit("+%d REP" % int(ev["rep"]), ev["pos"], "tokens")
		"summon_scattered", "pickpocket_escaped":
			var gone: SimActor = sim.actor_by_id(int(ev["actor"]))
			if gone != null and views.has(gone.id):
				(views[gone.id] as Node3D).visible = false
		"hitstop":
			EventBus.hitstop_requested.emit(int(ev.get("frames", 3)))


func respawn_player(point: Vector3) -> void:
	## Back on your feet (labs: spawn point; districts override with bodegas).
	if player == null:
		return
	player.alive = true
	player.hp = player.hp_max
	player.pos = point
	player.vel = Vector3.ZERO
	player.wind.value = player.wind.max_value
	player_hooper.end_action()
	player.flags["qw"] = GameState.quarter_water_max
	if not player.has_ball:
		var item: String = str(player.flags.get("ball_item", "ball_rec"))
		balls.give(balls.spawn_ball(item, point, player), player)
	EventBus.player_respawned.emit(GameState.respawn_bodega)
	camera_rig.snap()


func add_dummy(pos: Vector3, mode: String = "attack") -> TrainingDummy:
	var d: TrainingDummy = TrainingDummy.spawn(sim, combat, pos, mode)
	add_actor_view(d.actor, {"top_color": "#C8A060", "shorts_color": "#6A5030", "skin": "#B08A5A", "hair_style": "bald", "height": 1.35, "shoe_color": "#5A4632"})
	return d


func _exit_tree() -> void:
	if player_hooper != null:
		player_hooper.lock_target = null
	sim.dispose()
	player = null
	player_hooper = null


func setup_render_smoke(_entry: Dictionary) -> void:
	pass
