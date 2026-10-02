extends GutTest
## M7: stat formulas + soft caps, leveling, effect stacking, player build,
## tattoo slots/apply/laser, shops, upgrades, consumables, Bag Moves, saves.


func before_each() -> void:
	GameState.new_run("two_way", "brooklyn")


func test_heart_and_wind_soft_caps() -> void:
	assert_almost_eq(StatFormulas.heart_max(20), 300.0 + 250.0, 0.01)
	assert_almost_eq(StatFormulas.heart_max(41) - StatFormulas.heart_max(40), 10.0, 0.01, "+10/pt past 40")
	assert_almost_eq(StatFormulas.heart_max(61) - StatFormulas.heart_max(60), 3.0, 0.01, "+3/pt past 60")
	assert_almost_eq(StatFormulas.wind_max(41) - StatFormulas.wind_max(40), 1.0, 0.01)


func test_handles_hands_bounce_formulas() -> void:
	assert_almost_eq(StatFormulas.ankle_bonus_frames(15), 1.0, 0.001)
	assert_almost_eq(StatFormulas.ankle_bonus_frames(80), 6.0, 0.001, "max +6")
	assert_almost_eq(StatFormulas.parry_window_frames(15, 10.0), 11.0, 0.001)
	assert_almost_eq(StatFormulas.parry_window_frames(80, 10.0), 16.0, 0.001, "16 frames total max")
	assert_almost_eq(StatFormulas.jump_height(20, 1.2), 1.4, 0.001)
	assert_almost_eq(StatFormulas.dunk_range(20, 3.5), 3.8, 0.001)


func test_level_curve_table() -> void:
	assert_eq(Leveling.cost(1), 250)
	assert_eq(Leveling.cost(5), 1268)
	assert_eq(Leveling.cost(10), 3312)
	assert_eq(Leveling.cost(20), 9094)
	assert_eq(Leveling.cost(30), 16581)
	assert_eq(Leveling.cost(40), 25448)
	assert_eq(Leveling.cost(50), 35505)
	assert_eq(Leveling.cost(60), 46625, "formula; spec table rounds L60 (DECISIONS)")


func test_train_spends_rep() -> void:
	GameState.rep = 300
	var before: int = GameState.stat("jumper")
	assert_true(Leveling.train("jumper"))
	assert_eq(GameState.stat("jumper"), before + 1)
	assert_eq(GameState.level, 2)
	assert_eq(GameState.rep, 50)
	assert_false(Leveling.train("jumper"), "not enough Rep")


func test_effect_stacking_rules() -> void:
	var e: EffectSet = EffectSet.new()
	e.add_effects({"speed_mult": 0.05, "dr_add": 0.02})
	e.add_effects({"speed_mult": 0.10, "dr_add": 0.03, "rose": 1})
	assert_almost_eq(e.mult("speed_mult"), 1.05 * 1.10, 0.0001, "multiplicative")
	assert_almost_eq(e.add("dr_add"), 0.05, 0.0001, "additive")
	assert_true(e.flag("rose"))
	e.add_effects({"all_mult": 0.10})
	assert_almost_eq(e.mult("damage_mult"), 1.10, 0.0001, "Golden Hour feeds everything")
	assert_almost_eq(e.mult("speed_mult"), 1.05 * 1.10 * 1.10, 0.0001)


func test_player_build_from_gear_and_tattoos() -> void:
	GameState.inventory["kicks_brooklyn_0"] = 1
	GameState.equipment["kicks"] = "kicks_brooklyn_0"
	GameState.equipment["headband"] = "headband_brooklyn_0"
	GameState.tattoos.append("tattoo_skyline")
	var e: EffectSet = PlayerBuild.compute()
	assert_almost_eq(e.mult("speed_mult"), 1.05, 0.0001, "Classic Lows +5% speed")
	assert_almost_eq(e.mult("damage_mult"), 1.05, 0.0001, "Sweatband +5% dmg")
	var st: Dictionary = PlayerBuild.effective_stats(GameState.stats, e)
	assert_eq(int(st["jumper"]), GameState.stat("jumper") + 3, "Skyline +3 all stats")
	var sim: CombatSim = CombatSim.new()
	var h: Hooper = sim.hooper()
	PlayerBuild.apply(h.actor, h, e)
	assert_almost_eq(h.speed_mult, 1.05, 0.0001)
	assert_almost_eq(float(h.actor.flags["damage_mult"]), 1.05, 0.0001)
	sim.dispose()


func test_pendant_needs_crown_pass() -> void:
	GameState.equipment["chain_1"] = "chain_pendant_five"
	assert_eq(PlayerBuild.compute().add("stat_all_add"), 0.0)
	for b: String in DataSchemas.BOROUGHS:
		GameState.award_crown(b)
	assert_eq(PlayerBuild.compute().add("stat_all_add"), 2.0)


func test_crown_and_clock_tattoos_are_conditional() -> void:
	var sim: CombatSim = CombatSim.new()
	var h: Hooper = sim.hooper()
	GameState.tattoos.append("tattoo_crown")
	PlayerBuild.apply(h.actor, h)
	assert_almost_eq(HooperCombat.damage_buffs(h.actor), 1.10, 0.0001, "+10% at full Heart")
	h.actor.hp -= 10.0
	assert_almost_eq(HooperCombat.damage_buffs(h.actor), 1.0, 0.0001)
	sim.dispose()


func test_tattoo_slots_rules() -> void:
	assert_eq(TattooRules.slots(), 2, "2 at start")
	GameState.award_crown("brooklyn")
	assert_eq(TattooRules.slots(), 3, "+1 per Crown")
	for b: String in DataSchemas.BOROUGHS:
		GameState.award_crown(b)
	assert_eq(TattooRules.slots(), 7, "max 7")


func test_tattoo_apply_and_laser() -> void:
	GameState.tokens = 100000
	assert_eq(TattooRules.can_apply("tattoo_rose", "brooklyn"), "need the flash sheet")
	GameState.add_item("flash_rose", 1)
	GameState.add_item("flash_claw", 1)
	GameState.add_item("flash_mic", 1)
	assert_true(TattooRules.apply("tattoo_rose", "brooklyn"))
	assert_true(TattooRules.apply("tattoo_claw", "brooklyn"))
	assert_eq(TattooRules.can_apply("tattoo_mic", "brooklyn"), "no free slots")
	var cost: int = TattooRules.laser_cost("brooklyn")
	var t0: int = GameState.tokens
	assert_true(TattooRules.laser("tattoo_rose", "brooklyn"))
	assert_eq(t0 - GameState.tokens, cost)
	assert_eq(GameState.item_count("flash_rose"), 0, "laser destroys the flash")
	assert_true(TattooRules.apply("tattoo_mic", "brooklyn"))
	assert_eq(TattooRules.laser_cost("brooklyn"), 3000, "Brooklyn start = tier 1 price")


func test_shop_buy_sell_and_carry_limit() -> void:
	GameState.tokens = 5000
	var stock: PackedStringArray = ShopLogic.plug_stock("brooklyn")
	assert_gt(stock.size(), 10)
	for id: String in stock:
		assert_ne(JU.s(DataDB.find_any(id), "rarity"), "legendary", "stock tops out at Epic")
	var id0: String = stock[0]
	var p: int = ShopLogic.price(id0, "brooklyn")
	assert_eq(ShopLogic.buy(id0, "brooklyn"), "")
	assert_eq(GameState.tokens, 5000 - p)
	assert_eq(ShopLogic.sell(id0, "brooklyn"), "")
	assert_eq(GameState.tokens, 5000 - p + int(round(float(p) * 0.25)))
	GameState.tokens = 99999
	for _i: int in 5:
		assert_eq(ShopLogic.buy("honey_bun", "brooklyn"), "")
	assert_eq(ShopLogic.buy("honey_bun", "brooklyn"), "can't carry more")


func test_prices_scale_with_tier() -> void:
	GameState.new_run("two_way", "bronx")
	assert_eq(ShopLogic.price("honey_bun", "staten_island"), int(round(300.0 * 4.6)))


func test_ball_upgrades_and_evolution() -> void:
	GameState.new_run("nobody", "brooklyn")
	GameState.tokens = 1000000
	GameState.add_item("grip_tape", 5)
	GameState.add_item("pro_grip", 5)
	for i: int in 9:
		assert_eq(ShopLogic.upgrade("ball_taped", "brooklyn"), "", "level %d" % (i + 1))
	assert_eq(int(GameState.ball_upgrades["ball_taped"]), 9)
	assert_eq(ShopLogic.upgrade_material(5), "grip_tape")
	assert_eq(ShopLogic.upgrade_material(6), "pro_grip")
	assert_eq(ShopLogic.upgrade_cost(3, "brooklyn"), 600)
	assert_eq(ShopLogic.upgrade("ball_taped", "brooklyn"), "evolved:ball_old_faithful")
	assert_eq(str(GameState.equipment["ball_1"]), "ball_old_faithful")
	assert_eq(GameState.item_count("ball_old_faithful"), 1)


func test_consumable_buffs() -> void:
	var sim: CombatSim = CombatSim.new()
	var h: Hooper = sim.hooper()
	GameState.add_item("honey_bun", 1)
	GameState.add_item("chopped_cheese", 1)
	assert_true(PlayerBuffs.use(h.actor, "honey_bun", sim.world.frame))
	sim.run(2)
	assert_almost_eq(float(h.actor.flags["buff_damage_mult"]), 1.10, 0.0001)
	h.actor.hp = 100.0
	assert_true(PlayerBuffs.use(h.actor, "chopped_cheese", sim.world.frame))
	sim.run(60 * 20 + 2)
	assert_almost_eq(h.actor.hp, minf(h.actor.hp_max, 100.0 + h.actor.hp_max * 0.4), 2.0, "+40% over 20 s")
	assert_almost_eq(float(h.actor.flags["buff_damage_mult"]), 1.10, 0.0001, "honey bun still up at 20 s")
	sim.run(60 * 10)
	assert_almost_eq(float(h.actor.flags["buff_damage_mult"]), 1.0, 0.0001, "honey bun expired")
	assert_false(PlayerBuffs.use(h.actor, "honey_bun", sim.world.frame), "none left")
	sim.dispose()


func test_every_bag_move_runs() -> void:
	for id: Variant in DataDB.catalog("bag_moves").keys():
		var sim: CombatSim = CombatSim.new()
		sim.combat.damage.hitstop_enabled = false
		var h: Hooper = sim.hooper()
		var d: TrainingDummy = sim.dummy(Vector3(0, 0, -2.0))
		d.actor.hp_max = 99999.0
		d.actor.hp = 99999.0
		h.actor.flags["bag_move"] = str(id)
		h.actor.hype.add(100.0)
		(h.actor.input_source as ScriptedInput).press_at(0, "bag_move")
		sim.run(120)
		assert_eq(sim.count("bag_move_unimplemented"), 0, "%s implemented" % id)
		assert_eq(sim.count("bag_move_used"), 1, "%s used" % id)
		sim.dispose()


func test_bag_move_effects() -> void:
	var sim: CombatSim = CombatSim.new()
	sim.combat.damage.hitstop_enabled = false
	var h: Hooper = sim.hooper()
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -3.0))
	h.actor.flags["bag_move"] = "trash_talk"
	h.actor.hype.add(100.0)
	(h.actor.input_source as ScriptedInput).press_at(0, "bag_move")
	sim.run(30)
	assert_true(StatusEffects.has(d.actor, "trash_talked"))
	h.actor.flags["bag_move"] = "showstopper"
	h.actor.hype.add(100.0)
	h.actor.facing = 0.0
	(h.actor.input_source as ScriptedInput).press_at(40, "bag_move")
	sim.run(40)
	assert_true(StatusEffects.has(d.actor, "frozen"))
	h.actor.flags["bag_move"] = "chest_pound"
	h.actor.hype.add(100.0)
	h.actor.hp = 100.0
	(h.actor.input_source as ScriptedInput).press_at(90, "bag_move")
	sim.run(90)
	assert_almost_eq(h.actor.hp, 100.0 + h.actor.hp_max * 0.15, 0.5)
	sim.dispose()


func test_save_round_trip_full_state() -> void:
	GameState.tokens = 4321
	GameState.rep = 777
	GameState.level = 7
	GameState.equipment["kicks"] = "kicks_bronx_3"
	GameState.tattoos.append("tattoo_rose")
	GameState.ball_upgrades["ball_rec"] = 4
	GameState.crowns.append("bronx")
	GameState.discovered_stations.append("bk_st_bedstuy")
	GameState.chains = [{"district": "bk_bedstuy", "pos": [1, 0, 2], "rep": 100, "lives": 0}]
	var mask: PackedByteArray = MapReveal.ensure("bk_bedstuy", 64, 64)
	mask[5] = 1
	var path: String = "user://test_saves/full.json"
	assert_eq(SaveSystem.write_json_atomic(path, SaveSystem.build_save()), OK)
	GameState.new_run("shooter", "queens")
	GameState.from_dict(JU.dict(SaveSystem.read_save(path), "game"))
	assert_eq(GameState.tokens, 4321)
	assert_eq(GameState.level, 7)
	assert_eq(str(GameState.equipment["kicks"]), "kicks_bronx_3")
	assert_true(GameState.tattoos.has("tattoo_rose"))
	assert_eq(int(GameState.ball_upgrades["ball_rec"]), 4)
	assert_true(GameState.has_crown("bronx"))
	assert_eq(GameState.chains.size(), 1)
	assert_eq((GameState.map_reveal["bk_bedstuy"] as PackedByteArray)[5], 1)


func test_catalog_sizes_and_flavor() -> void:
	for cat: String in ["kicks", "fits", "headbands", "sleeves", "chains"]:
		assert_gte(DataDB.catalog(cat).size(), 60, cat)
		for id: Variant in DataDB.catalog(cat).keys():
			assert_ne(JU.s(DataDB.catalog(cat)[id], "flavor"), "", "%s has flavor" % id)
	assert_eq(DataDB.catalog("tattoos").size(), 23)
	assert_eq(DataDB.catalog("consumables").size(), 6)
	assert_eq(DataDB.catalog("mixtapes").size(), 16)
