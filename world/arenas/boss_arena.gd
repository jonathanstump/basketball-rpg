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


func _ready() -> void:
	boss_data = DataDB.boss(boss_id)
	var region: String = JU.s(boss_data, "borough", "city")
	setup_world(region if DataDB.has_item("environments", region) else "city")
	if tier <= 0:
		tier = TierManager.tier_of(region)
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
			boss_bar.show_banner("BLOCK PARTY!", 1.6)


func _victory(ev: Dictionary) -> void:
	if finished:
		return
	finished = true
	boss_bar.show_banner("GAME!", 3.0)
	var r: Dictionary = ev["rewards"]
	GameState.add_rep(int(r["rep"]))
	GameState.add_tokens(int(r["tokens"]))
	for d: String in (r["drops"] as PackedStringArray):
		GameState.add_item(d, 1)
	if not GameState.defeated_bosses.has(boss_id):
		GameState.defeated_bosses.append(boss_id)
	if str(r["crown"]) != "":
		GameState.award_crown(str(r["crown"]))
	EventBus.boss_defeated.emit(boss_id)
	ArenaBuilder.open_gate(sim)
	SaveSystem.request_autosave()


func _on_respawn() -> void:
	## Lab/retry flow: reset the boss and run it back from CHECK.
	if finished:
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
