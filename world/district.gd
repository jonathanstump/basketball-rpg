class_name District
extends GameWorld
## A playable district (spec §4.4, §15.10): built from its ASCII map at load,
## enemies spawned at the borough's tier, interactables for bodegas,
## stations, shops, courts, crossings, shoeboxes, Wire Kicks, graffiti,
## shortcuts and secrets; fog of war reveals as you walk.

@export var district_id: String = "bk_bedstuy"

var map: MapData
var layout: Dictionary = {}
var nav: NavGrid
var interact: Interactables = Interactables.new()
var views_extra: DistrictViews
var dialogue: DialogueBox
var tier: int = 1
var arrive: Dictionary = {}
var _reveal_t: int = 0
var objective_panel: ObjectivePanel


func _ready() -> void:
	var params: Dictionary = SceneRouter.take_params()
	district_id = str(params.get("district", district_id))
	arrive = params.get("arrive", {})
	GameState.current_district = district_id
	map = MapParser.load_map(district_id)
	if map == null:
		push_error("District: no map " + district_id)
		return
	var borough: String = map.borough()
	setup_world(JU.s(map.side, "palette", borough))
	tier = TierManager.tier_of(borough)
	var t0: int = Time.get_ticks_msec()
	layout = BoroughBuilder.build(map, sim, balls, level_root)
	nav = NavGrid.create(map, sim.collision)
	nav.bake_threaded()
	views_extra = DistrictViews.new(self)
	add_child(views_extra)
	views_extra.build()
	_spawn_enemies()
	spawn_player(_arrival_point())
	camera_rig.auto_yaw(sim.collision)
	nav.wait()
	sim.nav = nav
	layout["build_ms"] = Time.get_ticks_msec() - t0
	DistrictActions.register(self)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	MapReveal.ensure(district_id, map.width, map.height)
	_reveal(MapReveal.WALK_RADIUS_M)
	objective_panel = ObjectivePanel.new()
	objective_panel.game = self
	hud.add_child(objective_panel)
	update_objective()
	player.hp = player.hp_max * float(GameState.flags.get("hp_ratio", 1.0))
	if auto_capture() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.district_loaded.emit(district_id)
	SteamService.set_presence("steam_display", "Running it back in %s — Tier %d" % [WorldIndex.district_name(district_id), tier])


func auto_capture() -> bool:
	return DebugConsole.qa_arg() == ""


func _arrival_point() -> Vector3:
	var kind: String = JU.s(arrive, "kind")
	match kind:
		"bodega":
			for b: Variant in JU.a(layout, "bodegas"):
				if JU.s(b as Dictionary, "id") == JU.s(arrive, "id"):
					return ((b as Dictionary)["door"] as Vector3) + Vector3(0, 0.2, 0)
		"station":
			for s: Variant in JU.a(layout, "stations"):
				if JU.s(s as Dictionary, "id") == JU.s(arrive, "id"):
					return ((s as Dictionary)["pos"] as Vector3) + Vector3(1.5, 0.2, 0)
		"crossing":
			for c: Variant in JU.a(layout, "crossings"):
				if JU.s(c as Dictionary, "to") == JU.s(arrive, "from"):
					var cp: Vector3 = (c as Dictionary)["pos"]
					return cp - cp.normalized() * 6.0
		"court":
			for ct: Variant in JU.a(layout, "courts"):
				if JU.s(ct as Dictionary, "boss") == JU.s(arrive, "id"):
					var g: Vector3 = (ct as Dictionary)["gate"]
					return g + (g - ((ct as Dictionary)["center"] as Vector3)).normalized() * 2.0
		"shop":
			for sh: Variant in JU.a(layout, "shops"):
				if JU.s(sh as Dictionary, "id") == JU.s(arrive, "id"):
					return (sh as Dictionary)["door"]
		"pos":
			return JU.vec3(arrive.get("pos"))
	return layout["start"]


func _spawn_enemies() -> void:
	for s: Variant in JU.a(layout, "spawns"):
		var sd: Dictionary = s
		var key: String = "killed_" + JU.s(sd, "id")
		if (bool(sd["captain"]) or JU.s(sd, "enemy") == "bootleg") and GameState.has_flag(key):
			continue
		var a: SimActor = spawner.add(JU.s(sd, "enemy"), sd["pos"], tier, {"captain": bool(sd["captain"]), "facing": float(JU.s(sd, "id").hash() % 628) / 100.0})
		if a != null:
			a.flags["spawn_id"] = JU.s(sd, "id")


func respawn_player(point: Vector3) -> void:
	## Back at your last bodega (spec §5.4) — maybe in another district.
	var bid: String = GameState.respawn_bodega
	var info: Dictionary = WorldIndex.bodega(bid)
	if bid != "" and JU.s(info, "district") != "" and JU.s(info, "district") != district_id:
		GameState.flags["hp_ratio"] = 1.0
		SceneRouter.goto_district(JU.s(info, "district"), {"kind": "bodega", "id": bid}, false)
		return
	for b: Variant in JU.a(layout, "bodegas"):
		if JU.s(b as Dictionary, "id") == bid:
			point = (b as Dictionary)["door"]
	if bid == "":
		point = layout["start"]
	super.respawn_player(point)
	spawner.respawn_commons()


func _physics_process(delta: float) -> void:
	if menu != null:
		return
	super._physics_process(delta)
	if player == null:
		return
	_reveal_t += 1
	if _reveal_t % 15 == 0:
		_reveal(MapReveal.WALK_RADIUS_M)
	if _reveal_t % 30 == 0:
		update_objective()
	if dialogue != null and dialogue.blocking():
		hud.prompt = ""   # Interact advances the dialogue; it must not also leave/trigger
		if player.input.peek("interact"):
			player.input.pressed("interact")   # eat the buffered press so closing the box doesn't fire it
		return
	var near: Dictionary = interact.nearest(player.pos)
	hud.prompt = ("[%s] %s" % [InputPrompts.key("interact"), tr(str(near.get("prompt", "")))]) if not near.is_empty() else ""
	if not near.is_empty() and player.input.peek("interact") and player_hooper.action == "":
		player.input.pressed("interact")
		DistrictActions.trigger(self, near)
	if Input.is_action_just_pressed("map") and DisplayServer.get_name() != "headless":
		open_map()
	GameState.flags["hp_ratio"] = player.hp / maxf(1.0, player.hp_max)


func _reveal(meters: float) -> void:
	var mask: PackedByteArray = MapReveal.ensure(district_id, map.width, map.height)
	MapReveal.reveal(mask, map.width, map.height, map.cell_of(player.pos), MapReveal.radius_tiles(meters))


func open_map() -> void:
	var ms: MapScreen = MapScreen.new()
	ms.map = map
	ms.layout = layout
	ms.player_pos = player.pos
	open_menu(ms)


func _on_sim_event(ev: Dictionary) -> void:
	super._on_sim_event(ev)
	match str(ev.get("type", "")):
		"actor_killed":
			var a: SimActor = sim.actor_by_id(int(ev["actor"]))
			if a != null and a.flags.has("spawn_id") and (bool(a.flags.get("captain", false)) or a.archetype == "bootleg"):
				GameState.set_flag("killed_" + str(a.flags["spawn_id"]))
		"enemy_defeated":
			for d: String in (ev["drops"] as PackedStringArray):
				if d.begins_with("loot:"):
					DistrictActions.drop_loot(self, "bootleg", ev["pos"])
		"wire_kicks_down":
			DistrictActions.kicks_down(self, str(ev["id"]), ev["pos"])
		"crate_first_make":
			GameState.add_tokens(int(ev["tokens"]))
			GameState.set_flag("crate_paid_" + str(ev["hoop"]))


func setup_render_smoke(entry: Dictionary) -> void:
	if JU.b(entry, "dawn"):
		GameState.set_flag("dawn")
	if JU.s(entry, "district") != "":
		district_id = JU.s(entry, "district")
	if JU.s(entry, "mode") == "objective":
		GameState.set_flag("prologue_done")
	if JU.s(entry, "mode") == "map":
		ready.connect(func() -> void:
			MapReveal.reveal(MapReveal.ensure(district_id, map.width, map.height), map.width, map.height, map.cell_of(player.pos), 20.0)
			open_map())


func update_objective() -> void:
	## HUD objective + marker: the boss court here, or the crossing on the
	## way to the district it's in.
	var obj: Dictionary = ObjectiveRules.current(district_id)
	objective_panel.set_objective(obj)
	objective_panel.has_target = false
	var to: String = JU.s(obj, "district")
	if to == "":
		return
	if to == district_id:
		for c: Variant in JU.a(layout, "courts"):
			if JU.s(c as Dictionary, "boss") == JU.s(obj, "boss"):
				objective_panel.target = (c as Dictionary)["gate"]
				objective_panel.target_label = JU.s(DataDB.boss(JU.s(obj, "boss")), "name")
				objective_panel.has_target = true
		return
	var path: Array[String] = ObjectiveRules.route(district_id, to)
	if path.is_empty():
		return
	for x: Variant in JU.a(layout, "crossings"):
		if JU.s(x as Dictionary, "to") == path[0]:
			objective_panel.target = (x as Dictionary)["pos"]
			objective_panel.target_label = "To %s" % WorldIndex.district_name(path[0])
			objective_panel.has_target = true
