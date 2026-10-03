class_name Prologue
extends GameWorld
## "I Got Next" (spec §3.3): your home court. Call next, the crew laughs,
## the tutorial teaches move / strike / crossover / ankle-breaker / crate
## shot / strip / Quarter Water. Then the lights flicker, a tall shadow in
## an old warm-up suit checks you the ball and ends you: "Not yet, kid."
## You wake up in the nearest bodega.

const CREW: PackedStringArray = ["ball_hog", "showboat", "ball_hog"]
const MIDNIGHT_LOOK: Dictionary = {"skin": "#3A2418", "top_color": "#141428", "shorts_color": "#141428", "shoe_color": "#E8E4D0",
	"hair_style": "fade", "hair_color": "#C8C8C8", "height": 1.7, "headband": ""}

var borough: String = "brooklyn"
var tracker: TutorialTracker
var lay: Dictionary = {}
var crew: Array[SimActor] = []
var midnight: SimActor = null
var prompt: Label
var controls_hint: Label         # "[Esc] Pause · Settings → Controls..." under the prompt
var start_pos: Vector3
var phase: String = "walk_up"    # walk_up, call, tutorial, cameo, out
var _cameo_t: float = 0.0
var _shown_step: String = ""     # step whose prompt is on screen
var _move_origin: Vector3        # where "move" is measured from (the call-next spot)
var _sprinted: bool = false
var _parked: Array[SimBall] = [] # balls set aside while the strip drill puts you on defense
var auto_wake: bool = true       # smoke/QA turn this off to stay in the scene


func _ready() -> void:
	var params: Dictionary = SceneRouter.take_params()
	borough = str(params.get("borough", GameState.start_borough if GameState.start_borough != "" else "brooklyn"))
	setup_world(borough)
	var data: Dictionary = ChallengerDuel.court_data(borough)
	(data["arena"] as Dictionary)["size_m"] = [18, 16]
	lay = ArenaBuilder.build(sim, balls, data, level_root)
	presenter.add_hoop_view(lay["hoop"])
	ArenaBuilder.open_gate(sim)
	var crate: SimHoop = balls.add_hoop(SimHoop.crate("tutorial_crate", Vector3(-6.5, 0, 2.0), Vector3(1, 0, 0)))
	presenter.add_hoop_view(crate)
	start_pos = lay["gate_outside"]
	spawn_player(start_pos)
	player.flags["cannot_die"] = true
	camera_rig.hoop_pos = (lay["hoop"] as SimHoop).rim
	tracker = TutorialTracker.new(player.id)
	# Teaching fight: one crew member swings at a time so every cue is readable.
	sim.attack_tokens = AttackTokenManager.new()
	sim.attack_tokens.cap = 1
	prompt = Label.new()
	prompt.add_theme_font_override("font", UIFonts.title())
	prompt.add_theme_font_size_override("font_size", 30)
	prompt.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(160, 150)
	prompt.size = Vector2(1600, 50)
	hud_layer.add_child(prompt)
	controls_hint = Label.new()
	controls_hint.add_theme_font_override("font", UIFonts.body())
	controls_hint.add_theme_font_size_override("font_size", 20)
	controls_hint.add_theme_color_override("font_color", Color("#F4B400"))
	controls_hint.add_theme_color_override("font_outline_color", Color("#0B0B10"))
	controls_hint.add_theme_constant_override("outline_size", 6)
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.position = Vector2(160, 200)
	controls_hint.size = Vector2(1600, 30)
	hud_layer.add_child(controls_hint)
	# Prompts show the player's own bindings: refresh on device swap or remap.
	InputRouter.device_changed.connect(_on_device_changed)
	InputRouter.bindings_changed.connect(_update_prompt)
	_update_prompt()
	AudioDirector.set_layer("explore")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if player == null or paused_sim:
		return
	match phase:
		"walk_up":
			if player.pos.distance_to(lay["top_of_key"]) < 9.0:
				tracker.mark("reach_court")
				phase = "call"
				_update_prompt()
		"call":
			if player.input.pressed("interact"):
				call_next()
		"tutorial":
			# "Move" teaches moving and sprinting: both, after calling next.
			_sprinted = _sprinted or (player_hooper != null and player_hooper.sprinting)
			if _sprinted and player.pos.distance_to(_move_origin) > 4.0:
				tracker.mark("moved")
			if player.hp < player.hp_max * 0.35:
				player.hp = player.hp_max * 0.35
			if tracker.tutorial_complete():
				start_cameo()
		"cameo":
			_tick_cameo(delta)
	_sync_prompt()


func _sync_prompt() -> void:
	## Any step can complete from any path (sim events, movement, skips), so
	## the prompt follows the tracker every frame instead of per event.
	if tracker == null:
		return
	var cur: String = tracker.current_id()
	if cur == "strip" and player.has_ball:
		_start_defense_drill()   # a ball can land back in your hands mid-drill (shot return, spare)
	if cur == _shown_step:
		return
	if _shown_step != "" and phase == "tutorial" and cur != "cameo":
		EventBus.popup_text.emit("NICE", player.pos, "good")
	_shown_step = cur
	if cur == "strip":
		_start_defense_drill()
	else:
		_end_defense_drill()
	_update_prompt()


func _start_defense_drill() -> void:
	## Hands Up is defense (spec §7: "you don't [have the ball]: pick their
	## pocket"), so the strip step sets your ball aside until you've stripped.
	player.flags["no_pickup"] = true
	if player.has_ball:
		var b: SimBall = balls.take_from(player)
		if b != null:
			balls.balls.erase(b)
			_parked.append(b)


func _end_defense_drill() -> void:
	player.flags.erase("no_pickup")
	for b: SimBall in _parked:
		b.pos = player.pos + Vector3(0, 0.5, 0)
		b.vel = Vector3.ZERO
		balls.balls.append(b)
		if not player.has_ball:
			balls.give(b, player)
	_parked.clear()


func call_next() -> void:
	tracker.mark("called_next")
	phase = "tutorial"
	_move_origin = player.pos
	_sprinted = false
	EventBus.dialogue_requested.emit("Crew", JU.strs(JU.dict(DataDB.get_dict("dialogue/prologue"), "lines"), "crew_laugh"))
	for i: int in CREW.size():
		var a: SimActor = spawner.add(CREW[i], (lay["boss_spot"] as Vector3) + Vector3(-3.0 + 3.0 * float(i), 0, 1.5), 1, {"no_respawn": true})
		if a != null:
			a.hp_max *= 3.0
			a.hp = a.hp_max
			crew.append(a)
	_update_prompt()


func _on_sim_event(ev: Dictionary) -> void:
	super._on_sim_event(ev)
	if tracker == null or phase != "tutorial":
		return
	tracker.feed(ev)
	if str(ev.get("type", "")) == "enemy_defeated" and tracker.current_id() != "cameo":
		_respawn_crew_member(ev)
	_sync_prompt()


func _respawn_crew_member(ev: Dictionary) -> void:
	## Somebody always wants next: keep a sparring partner on the court.
	var alive: int = 0
	for c: SimActor in crew:
		if c.alive:
			alive += 1
	if alive == 0:
		var a: SimActor = spawner.add("ball_hog", lay["boss_spot"], 1, {"no_respawn": true})
		if a != null:
			crew.append(a)


func _on_device_changed(_device: String) -> void:
	_update_prompt()


func _update_prompt() -> void:
	if prompt == null or tracker == null:
		return
	var teaching: bool = phase != "cameo" and phase != "out"
	prompt.text = InputPrompts.format(tr(JU.s(tracker.current(), "prompt"))) if teaching else ""
	controls_hint.text = InputPrompts.format(tr(JU.s(DataDB.get_dict("dialogue/prologue"), "controls_hint"))) if teaching else ""


func skip_tutorial() -> void:
	for s: Variant in tracker.steps:
		tracker.mark(JU.s(s as Dictionary, "done"))
	if phase == "walk_up" or phase == "call":
		phase = "tutorial"
	start_cameo()


func start_cameo() -> void:
	if phase == "cameo" or phase == "out":
		return
	phase = "cameo"
	_cameo_t = 0.0
	_update_prompt()
	EventBus.dialogue_requested.emit("Crew", JU.strs(JU.dict(DataDB.get_dict("dialogue/prologue"), "lines"), "crew_beaten"))
	for c: SimActor in crew:
		if c.alive:
			c.alive = false
			remove_actor(c)
	crew.clear()
	if env_node != null:
		var tw: Tween = create_tween()
		tw.tween_property(env_node.environment, "ambient_light_energy", 0.05, 0.4)
		tw.tween_property(env_node.environment, "ambient_light_energy", 0.6, 0.15)
		tw.tween_property(env_node.environment, "ambient_light_energy", 0.08, 0.5)
	midnight = SimActor.new()
	midnight.kind = "npc"
	midnight.team = 2
	midnight.display_name = "???"
	midnight.radius = 0.5
	midnight.height = 2.3
	midnight.pos = lay["gate_outside"]
	midnight.hp_max = 99999.0
	midnight.hp = 99999.0
	midnight.invulnerable = true
	sim.add_actor(midnight)
	add_actor_view(midnight, MIDNIGHT_LOOK)


func _tick_cameo(delta: float) -> void:
	_cameo_t += delta
	if midnight == null:
		return
	var to: Vector3 = player.pos - midnight.pos
	to.y = 0.0
	if _cameo_t < 4.0 and to.length() > 1.8:
		midnight.desired_vel = to.normalized() * 2.2
		midnight.anim_state = "walk"
		midnight.face_dir(to)
		return
	midnight.desired_vel = Vector3.ZERO
	midnight.anim_state = "idle"
	if not GameState.has_flag("midnight_cameo"):
		GameState.set_flag("midnight_cameo")
		EventBus.dialogue_requested.emit("???", JU.strs(JU.dict(DataDB.get_dict("dialogue/prologue"), "lines"), "midnight"))
		EventBus.flash_requested.emit("poster")
		EventBus.slowmo_requested.emit(0.2, 0.8)
		player.flags["cannot_die"] = false
		if player_hooper != null:
			player_hooper.on_hit({"result": "hit", "knockdown": true, "damage": 999.0, "weight": "heavy"})
		player.hp = 1.0
		tracker.mark("cameo_done")
		phase = "out"
		if auto_wake:
			get_tree().create_timer(2.5 if DisplayServer.get_name() != "headless" else 0.1).timeout.connect(FrontEndFlow.wake_up)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") and menu == null and phase in ["walk_up", "call", "tutorial"]:
		MenuKit.show(self, "PAUSED", [{"id": "resume", "label": "Resume"}, {"id": "controls", "label": "Controls",
			"detail": "See every key and button, and change them."}, {"id": "skip", "label": "Skip the tutorial"},
			{"id": "settings", "label": "Settings"}] as Array[Dictionary], func(id: String) -> void:
				close_menu()
				if id == "skip":
					skip_tutorial()
				elif id == "controls":
					RemapMenu.open(self, close_menu)
				elif id == "settings":
					SettingsMenu.open(self, close_menu), "")
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func setup_render_smoke(entry: Dictionary) -> void:
	if JU.s(entry, "mode") == "cameo":
		ready.connect(func() -> void:
			player.pos = lay["top_of_key"]
			skip_tutorial())
