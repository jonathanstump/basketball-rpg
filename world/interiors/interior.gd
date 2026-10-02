class_name Interior
extends GameWorld
## Small interiors loaded through doors (spec §4.6): every bodega (cat =
## rest, counter = Train/Travel/Stash/Swap Bag Move/Shop/Punch Card/Lost &
## Found) and the shops (The Plug, Pump & Grip, Ink & Needle).

@export var kind: String = "bodega"
@export var place_id: String = "bk_bodega_1"

var return_to: Dictionary = {}
var interact: Interactables = Interactables.new()
var dialogue: DialogueBox
var menu: CanvasLayer = null
var info: Dictionary = {}


func _ready() -> void:
	var p: Dictionary = SceneRouter.take_params()
	kind = str(p.get("kind", kind))
	place_id = str(p.get("id", place_id))
	return_to = p.get("return_to", {})
	info = WorldIndex.bodega(place_id) if kind == "bodega" else {}
	setup_world("interior")
	_room()
	spawn_player(Vector3(0, 0, 2.6))
	camera_rig.yaw = 0.0
	camera_rig.snap()
	player.hp = player.hp_max * float(GameState.flags.get("hp_ratio", 1.0))
	dialogue = DialogueBox.new()
	add_child(dialogue)
	_interactables()
	if kind != "bodega":
		ShopService.on_enter(self)


func _room() -> void:
	sim.collision.set_bounds(Vector2(-5, -4), Vector2(5, 4))
	var root: Node3D = level_root
	var floor_c: Color = Color("#E8D8C0") if kind == "bodega" else Color("#2A2A34")
	KitProps.ground_tile(root, Vector3.ZERO, Vector2(10, 8), ToonMaterials.toon(floor_c, false))
	var wall: Material = ToonMaterials.toon(Color("#F2E6C8") if kind == "bodega" else Color("#3A3048"))
	for spec: Array in [[Vector3(0, 1.75, -4.1), Vector3(10, 3.5, 0.2)], [Vector3(-5.1, 1.75, 0), Vector3(0.2, 3.5, 8)], [Vector3(5.1, 1.75, 0), Vector3(0.2, 3.5, 8)]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = MeshLib.box(spec[1])
		mi.material_override = wall
		mi.position = spec[0]
		root.add_child(mi)
		sim.collision.add_box(spec[0], spec[1], "wall")
	var counter: MeshInstance3D = MeshInstance3D.new()
	counter.mesh = MeshLib.box(Vector3(4.0, 1.1, 0.9))
	counter.material_override = ToonMaterials.toon(Color("#7B2FF7") if kind == "bodega" else Color("#FF3EA5"))
	counter.position = Vector3(-1.5, 0.55, -2.4)
	root.add_child(counter)
	sim.collision.add_box(counter.position, Vector3(4.0, 1.1, 0.9), "counter")
	for i: int in 4:
		var shelf: MeshInstance3D = MeshInstance3D.new()
		shelf.mesh = MeshLib.box(Vector3(0.5, 2.2, 3.0))
		shelf.material_override = ToonMaterials.toon(Color("#C8A060"))
		shelf.position = Vector3(3.5 - float(i % 2) * 1.2, 1.1, -1.0 + float(i / 2) * 2.6)
		root.add_child(shelf)
		sim.collision.add_box(shelf.position, Vector3(0.5, 2.2, 3.0), "shelf")
	var fridge: MeshInstance3D = MeshInstance3D.new()
	fridge.mesh = MeshLib.box(Vector3(2.4, 2.4, 0.6))
	fridge.material_override = ToonMaterials.toon(Color("#BFE8FF"), true, false, Color("#BFE8FF"), 1.2)
	fridge.position = Vector3(2.8, 1.2, -3.6)
	root.add_child(fridge)
	for lx: float in [-2.5, 2.5]:
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color("#FFF0D0")
		l.light_energy = 1.6
		l.omni_range = 7.0
		l.position = Vector3(lx, 3.0, 0)
		root.add_child(l)
	var sign: Label3D = Label3D.new()
	sign.text = tr(JU.s(info, "name", _shop_name())).to_upper()
	sign.font = UIFonts.title()
	sign.font_size = 72
	sign.pixel_size = 0.006
	sign.modulate = Color("#FFE060")
	sign.position = Vector3(-1.5, 2.8, -3.95)
	root.add_child(sign)
	# Door at the front (open side of the room).
	var door: MeshInstance3D = MeshInstance3D.new()
	door.mesh = MeshLib.box(Vector3(1.4, 2.4, 0.1))
	door.material_override = ToonMaterials.toon(Color("#FFE0A0"), false, false, Color("#FFC870"), 1.5)
	door.position = Vector3(0, 1.2, 4.0)
	root.add_child(door)
	sim.collision.add_block(Vector2(-5.2, 3.9), Vector2(5.2, 4.2), 4.0, "front_wall")
	if kind == "bodega":
		var cat: SimActor = SimActor.new()
		cat.kind = "npc"
		cat.team = 0
		cat.archetype = "cat"
		cat.pos = Vector3(-2.6, 1.1, -2.4)
		cat.radius = 0.2
		cat.flags["no_pickup"] = true
		cat.flags["ghost"] = true
		sim.add_actor(cat)
		var cv: ActorView = EnemyViewBuilder.create_cat(cat, JU.s(info, "cat", "Cat"))
		add_child(cv)
		views[cat.id] = cv
	var owner: SimActor = SimActor.new()
	owner.kind = "npc"
	owner.team = 0
	owner.pos = Vector3(-0.5, 0, -3.3)
	owner.facing = PI
	owner.flags["ghost"] = true
	sim.add_actor(owner)
	add_actor_view(owner, {"top_color": "#F2F6FF", "shorts_color": "#3A3048", "skin": "#C68642", "hair_style": "bald", "facial_hair": "beard", "height": 1.3})


func _shop_name() -> String:
	return {"plug": "The Plug", "pump_grip": "Pump & Grip", "ink_needle": "Ink & Needle", "bodega": "Bodega"}.get(kind, "Shop")


func _interactables() -> void:
	if kind == "bodega":
		interact.add("cat", "cat", Vector3(-2.6, 0, -1.6), "Pet %s (Rest)" % JU.s(info, "cat", "the cat"), {}, 1.8)
		interact.add("counter", "counter", Vector3(-0.6, 0, -1.6), "Counter", {}, 1.8)
	else:
		interact.add("counter", "shop_counter", Vector3(-0.6, 0, -1.6), "Talk to %s" % ShopService.keeper(kind), {}, 1.8)
	interact.add("door", "door", Vector3(0, 0, 3.4), "Leave", {}, 1.5)


func _physics_process(delta: float) -> void:
	if menu != null:
		return
	super._physics_process(delta)
	var near: Dictionary = interact.nearest(player.pos)
	hud.prompt = ("[%s] %s" % [InputRouter.glyph("interact"), tr(str(near.get("prompt", "")))]) if not near.is_empty() else ""
	if not near.is_empty() and player.input.peek("interact") and player_hooper.action == "":
		player.input.pressed("interact")
		trigger(str(near["kind"]))


func trigger(k: String) -> void:
	match k:
		"cat":
			BodegaService.rest(place_id)
			player.hp = player.hp_max
			player.flags["qw"] = GameState.quarter_waters
			EventBus.popup_text.emit("RESTED", player.pos, "good")
			if GameState.has_flag("lost_and_found"):
				EventBus.dialogue_requested.emit(JU.s(info, "cat", "Cat"), PackedStringArray(["*the cat is sitting on your ball*", "Lost & found. Ask at the counter."]))
		"counter":
			counter_menu()
		"shop_counter":
			ShopService.open(self)
		"door":
			leave()


func leave() -> void:
	GameState.flags["hp_ratio"] = player.hp / maxf(1.0, player.hp_max)
	var d: String = str(return_to.get("district", GameState.current_district))
	SceneRouter.goto_district(d, return_to.get("arrive", {}), false)


func counter_menu() -> void:
	var opts: Array[Dictionary] = [
		{"id": "train", "label": "Train", "detail": "Spend Rep to level up a stat.", "enabled": true},
		{"id": "travel", "label": "Travel", "detail": "Fast travel to any station you've tapped into."},
		{"id": "stash", "label": "Stash", "detail": "Store gear you aren't carrying."},
		{"id": "bag", "label": "Swap Bag Move", "detail": "Equip one of the Bag Moves you know."},
		{"id": "shop", "label": "Shop", "detail": "Bodega snacks and drinks."},
		{"id": "punch", "label": "Punch Card", "detail": "Trade a Punch Card for +1 Quarter Water charge. You have %d." % GameState.item_count("punch_card"), "enabled": GameState.item_count("punch_card") > 0},
	]
	if GameState.has_flag("lost_and_found"):
		opts.append({"id": "lost", "label": "Lost & Found", "detail": "The cat was sitting on your ball the whole time."})
	opts.append({"id": "leave", "label": "Done"})
	_open_menu(ListMenu.new(), "COUNTER", opts, _on_counter)


func _open_menu(m: ListMenu, title: String, opts: Array[Dictionary], handler: Callable) -> void:
	close_menu()
	m.set_options(title, opts, "Tokens: %d   Rep: %d" % [GameState.tokens, GameState.rep])
	m.chosen.connect(handler)
	m.cancelled.connect(close_menu)
	add_child(m)
	menu = m
	paused_sim = true


func close_menu() -> void:
	if menu != null:
		menu.queue_free()
	menu = null
	paused_sim = false


func _on_counter(id: String) -> void:
	match id:
		"train":
			TrainMenu.open(self)
		"travel":
			var opts: Array[Dictionary] = []
			for st: String in FastTravel.destinations(GameState.discovered_stations):
				var si: Dictionary = WorldIndex.station(st)
				opts.append({"id": st, "label": JU.s(si, "name", st), "detail": WorldIndex.district_name(JU.s(si, "district")), "enabled": FastTravel.can_travel("bodega", st, GameState.discovered_stations)})
			if opts.is_empty():
				opts.append({"id": "_none", "label": "No stations yet", "enabled": false})
			opts.append({"id": "_back", "label": "Back"})
			_open_menu(ListMenu.new(), "TRAVEL", opts, func(st_id: String) -> void:
				if st_id == "_back":
					counter_menu()
				elif st_id != "_none":
					close_menu()
					DistrictActions.travel_to_station(st_id))
		"bag":
			var opts2: Array[Dictionary] = []
			for bm: String in GameState.known_bag_moves:
				var bd: Dictionary = DataDB.item("bag_moves", bm)
				opts2.append({"id": bm, "label": JU.s(bd, "name", bm) + (" (equipped)" if str(GameState.equipment.get("bag_move", "")) == bm else ""), "detail": "%s  - %d Hype" % [JU.s(bd, "effect"), int(JU.f(bd, "hype"))]})
			opts2.append({"id": "_back", "label": "Back"})
			_open_menu(ListMenu.new(), "BAG MOVES", opts2, func(bm_id: String) -> void:
				if bm_id != "_back":
					GameState.equipment["bag_move"] = bm_id
					player.flags["bag_move"] = bm_id
				counter_menu())
		"stash":
			StashMenu.open(self)
		"shop":
			ShopService.open_bodega(self)
		"punch":
			if BodegaService.punch_card_trade():
				EventBus.popup_text.emit("+1 QUARTER WATER", player.pos, "good")
			counter_menu()
		"lost":
			GameState.flags.erase("lost_and_found")
			EventBus.popup_text.emit("GOT YOUR BALL BACK", player.pos, "good")
			counter_menu()
		_:
			close_menu()
