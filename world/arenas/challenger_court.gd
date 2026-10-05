class_name ChallengerCourt
extends GameWorld
## A Pickup Challenger run (spec §8.4): rec court, a named hooper on your own
## moveset, first to 7. Winning drops their prize; either way you walk back
## out to the district.

var challenger: Dictionary = {}
var rival_name: String = "Challenger"
var duel: ChallengerDuel
var rival: SimActor
var return_to: Dictionary = {}
var score_label: Label
var done: bool = false


func _ready() -> void:
	var params: Dictionary = SceneRouter.take_params()
	challenger = params.get("challenger", {"id": "lab", "skill": 0.5, "points": 7})
	rival_name = str(params.get("name", "Challenger"))
	return_to = params.get("return_to", {})
	var region: String = WorldIndex.district_borough(str(return_to.get("district", ""))) if not return_to.is_empty() else "brooklyn"
	if region == "":
		region = "brooklyn"
	setup_world(region)
	var lay: Dictionary = ArenaBuilder.build(sim, balls, ChallengerDuel.court_data(region), level_root)
	var hoop: SimHoop = lay["hoop"]
	presenter.add_hoop_view(hoop)
	spawn_player(lay["top_of_key"])
	var tier: int = TierManager.tier_of(region)
	rival = SimActor.new()
	rival.kind = "hooper"
	rival.team = 1
	rival.display_name = rival_name
	rival.pos = lay["boss_spot"]
	rival.stats = ChallengerDuel.rival_stats(tier, JU.i(challenger, "tier_bonus"))
	sim.add_actor(rival)
	CombatSim.equip_hooper(sim, balls, combat, rival, "ball_rec", false)
	var brain: ChallengerBrain = ChallengerBrain.new()
	brain.skill = JU.f(challenger, "skill", 0.5)
	brain.hoop_id = hoop.id
	brain.opponent_id = player.id
	rival.input_source = brain
	add_actor_view(rival, params.get("look", {}))
	duel = ChallengerDuel.new(sim, balls, player, rival, hoop, lay["top_of_key"], JU.i(challenger, "points", 7))
	camera_rig.hoop_pos = hoop.rim
	set_lock(rival)
	camera_rig.duel_boss = rival
	player_hooper.face_point = hoop.floor_point()
	score_label = Label.new()
	score_label.add_theme_font_override("font", UIFonts.title())
	score_label.add_theme_font_size_override("font_size", 30)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_label.position = Vector2(-300, 20)
	score_label.size = Vector2(600, 40)
	hud_layer.add_child(score_label)
	_refresh()
	EventBus.popup_text.emit("FIRST TO %d. BALL'S IN." % duel.points_to_win, player.pos, "style")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if duel != null:
		duel.step()


func _refresh() -> void:
	if score_label != null:
		score_label.text = duel.score_text(rival_name)


func _on_sim_event(ev: Dictionary) -> void:
	super._on_sim_event(ev)
	match str(ev.get("type", "")):
		"challenger_score":
			_refresh()
			EventBus.popup_text.emit("+%d" % int(ev["points"]), (sim.actor_by_id(int(ev["actor"])) as SimActor).pos, "good" if int(ev["actor"]) == player.id else "bad")
		"challenger_victory":
			_finish(true)
		"challenger_defeat":
			_finish(false)


func _finish(won: bool) -> void:
	if done:
		return
	done = true
	_refresh()
	var id: String = JU.s(challenger, "id")
	if won:
		EventBus.popup_text.emit("GAME! YOU WIN", player.pos, "big")
		if not GameState.has_flag("beat_challenger_" + id):
			GameState.set_flag("beat_challenger_" + id)
			var drop: String = JU.s(challenger, "drop")
			if drop != "":
				GameState.add_item(drop, 1)
				EventBus.popup_text.emit(JU.s(DataDB.find_any(drop), "name", drop).to_upper(), player.pos + Vector3(0, 0.8, 0), "style")
			GameState.add_rep(PlayerBuild.reward_rep(300 * TierManager.tier_of(region)))
		GameState.bump_counter("challengers_beaten")
	else:
		EventBus.popup_text.emit("GOOD RUN. RUN IT BACK ANYTIME.", player.pos, "miss")
	SaveSystem.request_autosave()
	if not return_to.is_empty():
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			GameState.flags["hp_ratio"] = maxf(0.2, player.hp / maxf(1.0, player.hp_max))
			SceneRouter.goto_district(str(return_to.get("district", GameState.current_district)), return_to.get("arrive", {}), false))
