extends GutTest
## M0: input buffer, save atomic write + migration, settings round trip, console.


func test_input_buffer_window() -> void:
	var buf: InputBuffer = InputBuffer.new(8)
	buf.press("light", 100)
	assert_true(buf.peek("light", 108), "still buffered at +8")
	assert_false(buf.peek("light", 109), "expired at +9")
	assert_true(buf.consume("light", 105))
	assert_false(buf.consume("light", 105), "consumed once")


func test_save_atomic_round_trip() -> void:
	var path: String = "user://test_saves/slot_test.json"
	GameState.new_run("shooter", "uptown")
	GameState.add_tokens(1234)
	GameState.set_flag("met_pops")
	assert_eq(SaveSystem.write_json_atomic(path, SaveSystem.build_save()), OK)
	assert_eq(SaveSystem.write_json_atomic(path, SaveSystem.build_save()), OK, "second write makes .bak")
	assert_true(FileAccess.file_exists(path + ".bak"))
	var loaded: Dictionary = SaveSystem.read_save(path)
	assert_eq(JU.i(loaded, "schema_version"), SaveSystem.SCHEMA_VERSION)
	var g: Dictionary = JU.dict(loaded, "game")
	assert_eq(JU.i(g, "tokens"), 1234)
	assert_eq(JU.s(g, "start_borough"), "uptown")
	GameState.new_run("two_way", "brooklyn")
	GameState.from_dict(g)
	assert_eq(GameState.tokens, 1234)
	assert_true(GameState.has_flag("met_pops"))


func test_save_migration_v0() -> void:
	var v0: Dictionary = {"archetype": "slasher", "money": 50, "xp": 900}
	var migrated: Dictionary = SaveMigrations.migrate(v0, 1)
	assert_eq(JU.i(migrated, "schema_version"), 1)
	var g: Dictionary = JU.dict(migrated, "game")
	assert_eq(JU.i(g, "tokens"), 50)
	assert_eq(JU.i(g, "rep"), 900)


func test_settings_round_trip() -> void:
	var path: String = "user://test_settings.cfg"
	Settings.persist = false
	Settings.set_value("screen_shake", 0.25)
	assert_eq(Settings.save_settings(path), OK)
	Settings.set_value("screen_shake", 1.0)
	Settings.load_settings(path)
	assert_almost_eq(Settings.get_float("screen_shake"), 0.25, 0.0001)
	Settings.reset_defaults()
	Settings.persist = true


func test_debug_console_commands() -> void:
	assert_string_contains(DebugConsole.execute("help"), "god")
	var before: bool = DebugConsole.god_mode
	DebugConsole.execute("god")
	assert_ne(DebugConsole.god_mode, before)
	DebugConsole.execute("god")
	assert_string_contains(DebugConsole.execute("nope"), "unknown")


func test_input_map_built_from_data() -> void:
	for a: String in ["jump", "dodge", "light", "heavy", "shoot", "hands_up", "bag_move", "interact", "taunt", "menu"]:
		assert_true(InputMap.has_action(a), a)
		assert_gt(InputMap.action_get_events(a).size(), 0, a)
