extends GutTest
## M14: Steam wrapper no-ops cleanly, every Appendix B achievement has a
## trigger, Deck preset detection, export presets exist.

const ALL: PackedStringArray = ["ACH_FIRST_BUCKET", "ACH_ANKLES_100", "ACH_POSTER", "ACH_SPLASH_50", "ACH_MAKE_TAKE_5", "ACH_CROWN_BRONX",
	"ACH_CROWN_BROOKLYN", "ACH_CROWN_QUEENS", "ACH_CROWN_SI", "ACH_CROWN_UPTOWN", "ACH_CROWN_PASS", "ACH_LM_CAGE", "ACH_LM_BRIDGE",
	"ACH_LM_CROSSROADS", "ACH_LM_UNDERGROUND", "ACH_LM_SUMMIT", "ACH_END_DAYBREAK", "ACH_END_OVERTIME", "ACH_NOBODY", "ACH_FULL_INK",
	"ACH_GRAILS", "ACH_RAT_KING", "ACH_POPS", "ACH_DEUCE", "ACH_NO_WATER", "ACH_RUN_BACK_10", "ACH_ALL_CATS", "ACH_BOOTLEG", "ACH_TAKEOVER",
	"ACH_TIER5_FIRST"]


func before_each() -> void:
	GameState.new_run("nobody", "brooklyn")


func test_steam_no_op_fallback() -> void:
	assert_false(SteamService.is_available(), "no Steam in CI: everything still runs")
	SteamService.unlock("ACH_TEST_ONLY")
	assert_true(SteamService.is_unlocked("ACH_TEST_ONLY"), "local mirror")
	SteamService.set_presence("steam_display", "test")
	assert_eq(str(SteamService.rich_presence["steam_display"]), "test")
	SteamService.unlocked.erase("ACH_TEST_ONLY")


func test_every_achievement_has_a_trigger() -> void:
	assert_eq(AchievementRules.evaluate().size(), 0, "fresh run: nothing")
	for k: String in ["boss_buckets", "posters"]:
		GameState.bump_counter(k)
	GameState.counters["ankle_breakers"] = 100
	GameState.counters["perfects"] = 50
	GameState.counters["best_streak"] = 5
	GameState.counters["grails"] = 5
	GameState.counters["chains_recovered"] = 10
	GameState.counters["bootlegs"] = 10
	GameState.counters["takeovers"] = 25
	for b: String in AchievementRules.BOSS_ACH.keys():
		GameState.defeated_bosses.append(b)
	for borough: String in DataSchemas.BOROUGHS:
		GameState.award_crown(borough)
	GameState.set_flag("ending_daybreak")
	GameState.set_flag("ending_overtime")
	for i: int in 7:
		GameState.tattoos.append("t%d" % i)
	for n: int in [1, 2, 3]:
		GameState.set_flag("beat_challenger_deuce_%d" % n)
	GameState.set_flag("dry_king")
	GameState.set_flag("tier5_king_first")
	for cat: String in WorldIndex.all_cats():
		GameState.set_flag("pet_" + cat.to_lower().replace(" ", "_"))
	var got: PackedStringArray = AchievementRules.evaluate()
	for api: String in ALL:
		assert_true(got.has(api), "%s can unlock" % api)
	assert_eq(WorldIndex.all_cats().size(), 24, "every bodega cat (5 boroughs + the City)")


func test_tier5_first_rule() -> void:
	GameState.new_run("two_way", "brooklyn")
	var rules: AchievementRules = AchievementRules.new()
	add_child_autofree(rules)
	GameState.defeated_bosses.append("si_heap")
	rules._on_boss("si_heap")
	assert_true(GameState.has_flag("tier5_king_first"), "Staten Island is Tier 5 from Brooklyn")
	GameState.new_run("two_way", "brooklyn")
	GameState.defeated_bosses.append("bk_toll")
	rules._on_boss("bk_toll")
	assert_false(GameState.has_flag("tier5_king_first"))


func test_deck_and_export_presets() -> void:
	assert_eq(Settings.is_steam_deck(), OS.get_environment("SteamDeck") == "1")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export presets exist")
	var names: PackedStringArray = PackedStringArray()
	for sec: String in cfg.get_sections():
		if cfg.has_section_key(sec, "platform"):
			names.append(str(cfg.get_value(sec, "platform")))
	assert_true(names.has("Windows Desktop"))
	assert_true(names.has("Linux"))
	assert_true(FileAccess.file_exists("res://tools/export.ps1"))
	assert_true(FileAccess.file_exists("res://tools/export.sh"))
