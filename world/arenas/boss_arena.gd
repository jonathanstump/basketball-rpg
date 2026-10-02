class_name BossArena
extends GameWorld
## A boss court (spec §9.1): build the arena from boss data, slam the gate,
## Mic Check intro + title card, then the possession duel. Rewards on
## victory; on death the chain drops outside the gate and the fight resets.

@export var boss_id: String = "bk_stoop"
@export var tier: int = 1
@export var skip_intro: bool = false

var boss: SimActor
var boss_data: Dictionary = {}
var duel_ctl: DuelController
var layout: Dictionary = {}
var boss_bar: BossBar
var court: MeshInstance3D = null
var finished: bool = false
var return_to: Dictionary = {}


func _ready() -> void:
	var params: Dictionary = SceneRouter.take_params()
	if params.has("boss_id"):
		boss_id = str(params["boss_id"])
		tier = 0
	return_to = params.get("return_to", {})
	boss_data = DataDB.boss(boss_id)
	var region: String = JU.s(boss_data, "borough", "city")
	setup_world(region if DataDB.has_item("environments", region) else "city")
	if tier <= 0:
		tier = TierManager.tier_of(region)
		## Optional bosses between boroughs use the higher tier (spec §9.3 opt_ratking).
		for r: String in JU.strs(boss_data, "tier_regions"):
			tier = maxi(tier, TierManager.tier_of(r))
	layout = ArenaBuilder.build(sim, balls, boss_data, level_root)
	var hoop: SimHoop = layout["hoop"]
	presenter.add_hoop_view(hoop)
	for n: Node in level_root.get_children():
		if n.name == "CourtFloor":
			court = n as MeshInstance3D
	spawn_player(layout["player_start"])
	boss = BossFactory.spawn(sim, combat, balls, boss_id, layout["boss_spot"], tier, hoop)
	var bv: BossView = BossView.create_boss(boss, boss_data)
	add_child(bv)
	views[boss.id] = bv
	duel_ctl = DuelController.new(sim, balls, combat, boss, player, hoop, boss_data, layout)
	lifecycle.chain_drop_override = layout["gate_outside"]
	lifecycle.respawn_point = layout["gate_outside"]
	lifecycle.respawned.connect(_on_respawn)
	camera_rig.hoop_pos = hoop.rim
	boss_bar = BossBar.new()
	boss_bar.boss = boss
	boss_bar.duel = duel_ctl.duel
	boss_bar.title = JU.s(boss_data, "title")
	hud_layer.add_child(boss_bar)
	ArenaBuilder.close_gate(sim)
	EventBus.boss_engaged.emit(boss_id)
	AudioDirector.set_layer("boss")
	if skip_intro or DisplayServer.get_name() == "headless":
		_begin()
	else:
		var card: TitleCard = TitleCard.new()
		card.mic_line = JU.s(boss_data, "mic_check")
		if GameState.nickname != "":
			card.mic_line += " And stepping up... %s!" % NicknameRules.display_name()
		card.boss_name = JU.s(boss_data, "name")
		card.boss_title = JU.s(boss_data, "title")
		card.finished.connect(_begin)
		add_child(card)


func _begin() -> void:
	set_lock(boss)
	duel_ctl.start()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if duel_ctl != null:
		duel_ctl.step()
		if court != null:
			CourtFloor.set_arc_glow(court, duel_ctl.duel.state == PossessionDuel.PLAYER_OFFENSE and not duel_ctl.duel.player_cleared)


func _on_sim_event(ev: Dictionary) -> void:
	super._on_sim_event(ev)
	var t: String = str(ev.get("type", ""))
	match t:
		"duel_check":
			boss_bar.show_banner("CHECK", 1.0)
		"duel_game_point":
			boss_bar.show_banner("GAME POINT", 2.5)
			EventBus.game_point_reached.emit(boss_id)
		"duel_take_it_back":
			boss_bar.show_banner("TAKE IT BACK!", 1.2)
		"duel_phase_changed":
			boss_bar.show_banner("PHASE %d" % int(ev["phase"]), 2.0)
			EventBus.boss_phase_changed.emit(boss_id, int(ev["phase"]))
		"duel_cleared":
			EventBus.popup_text.emit("CLEARED", player.pos, "good")
		"bucket_damage":
			EventBus.bucket_scored.emit(str(ev["grade"]), str(ev["kind"]), float(ev["damage"]))
			EventBus.popup_text.emit("-%d" % int(ev["damage"]), ev["pos"], "big" if str(ev["kind"]) == "poster" else "damage")
			GameState.bump_counter("boss_buckets")
		"poster":
			EventBus.popup_text.emit("POSTERIZED!", player.pos, "big")
			EventBus.flash_requested.emit("poster")
			EventBus.slowmo_requested.emit(0.15, 0.5)
			camera_rig.punch_in()
			GameState.bump_counter("posters")
		"duel_won":
			_victory(ev)
		"t5_event":
			boss_bar.show_banner(JU.s(DataDB.move(boss_id, str(ev["move"])), "name", "T5").to_upper() + "!", 1.6)
		_:
			ArenaFx.on_event(self, ev)


func _victory(ev: Dictionary) -> void:
	if finished:
		return
	finished = true
	boss_bar.show_banner("GAME!", 3.0)
	var r: Dictionary = ev["rewards"]
	var nick: String = grant_rewards(boss_id, r)
	if nick != "":
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			EventBus.dialogue_requested.emit("Mic Check", PackedStringArray([
				"LADIES AND GENTLEMEN, %s HAS A CROWN!" % JU.s(DataDB.item("boroughs", str(r["crown"])), "name", "THE BOROUGH").to_upper(),
				"From now on, this city calls you... \"%s\"!" % nick])))
	EventBus.boss_defeated.emit(boss_id)
	ArenaBuilder.open_gate(sim)
	SaveSystem.request_autosave()
	if not return_to.is_empty():
		get_tree().create_timer(4.0).timeout.connect(_leave)


static func grant_rewards(id: String, r: Dictionary) -> String:
	## Rep, tokens, drops, the Crown (+1 tattoo slot) and, on the first Crown,
	## the earned nickname (returned, else "").
	GameState.add_rep(PlayerBuild.reward_rep(int(r["rep"])))
	GameState.add_tokens(PlayerBuild.reward_tokens(int(r["tokens"])))
	for d: String in (r["drops"] as PackedStringArray):
		GameState.add_item(d, 1)
		if DataDB.has_item("mixtapes", d):
			var teaches: String = JU.s(DataDB.item("mixtapes", d), "teaches")
			if not GameState.known_bag_moves.has(teaches):
				GameState.known_bag_moves.append(teaches)
	if not GameState.defeated_bosses.has(id):
		GameState.defeated_bosses.append(id)
	if str(r.get("garden_ticket", "")) != "" and not GameState.garden_tickets.has(str(r["garden_ticket"])):
		## Landmarks (spec §9.3 City): one Garden Ticket stub each; five open the Garden.
		GameState.garden_tickets.append(str(r["garden_ticket"]))
	if str(r["crown"]) == "":
		return ""
	GameState.award_crown(str(r["crown"]))
	return NicknameRules.award_if_first_crown()


func _leave() -> void:
	GameState.flags["hp_ratio"] = player.hp / maxf(1.0, player.hp_max) if player != null else 1.0
	SceneRouter.goto_district(str(return_to.get("district", GameState.current_district)), return_to.get("arrive", {}), false)


func respawn_player(point: Vector3) -> void:
	if return_to.is_empty():
		super.respawn_player(point)
		return
	## Cooked in the arena: back to your last bodega; the gate reopens on approach.
	GameState.flags["hp_ratio"] = 1.0
	var bid: String = GameState.respawn_bodega
	var info: Dictionary = WorldIndex.bodega(bid)
	if bid != "" and not info.is_empty():
		SceneRouter.goto_district(JU.s(info, "district"), {"kind": "bodega", "id": bid}, false)
	else:
		SceneRouter.goto_district(str(return_to.get("district", GameState.current_district)), {}, false)


func _on_respawn() -> void:
	## Lab/retry flow: reset the boss and run it back from CHECK.
	if finished or not return_to.is_empty():
		return
	boss.hp = boss.hp_max
	boss.alive = true
	if boss.composure != null:
		boss.composure.broken = ""
		boss.composure.value = 0.0
	boss.pos = layout["boss_spot"]
	var brain: BossBrain = boss.controller as BossBrain
	brain.set_phase(1)
	brain.t5_done = false
	boss.flags["scale"] = 1.0
	duel_ctl.duel = PossessionDuel.new()
	brain.duel = duel_ctl.duel
	boss_bar.duel = duel_ctl.duel
	player.pos = layout["player_start"]
	duel_ctl.start()


func setup_render_smoke(entry: Dictionary) -> void:
	## Render smoke: any boss by id ("boss"), at a tier (default 5).
	if JU.s(entry, "boss") != "":
		boss_id = JU.s(entry, "boss")
		tier = JU.i(entry, "tier", 5)
	skip_intro = true
