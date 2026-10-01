extends GutTest
## M0: DataDB loads, validates, and exposes typed accessors.


func test_data_loads_without_problems() -> void:
	assert_true(DataDB.loaded, "DataDB loaded at boot")
	assert_eq(DataDB.validate().size(), 0, "no validation problems: %s" % [DataDB.validate()])


func test_catalogs_present() -> void:
	assert_eq(DataDB.catalog("archetypes").size(), 6)
	assert_true(DataDB.has_item("balls", "ball_rec"))
	assert_true(DataDB.has_item("bag_moves", "hesi"))
	assert_eq(DataDB.catalog("bag_moves").size(), 16)


func test_archetype_stats_match_spec() -> void:
	var expected: Dictionary = {
		"slasher": [10, 11, 9, 13, 14, 8, 9],
		"shooter": [9, 10, 8, 11, 9, 16, 11],
		"floor_general": [10, 11, 8, 15, 9, 10, 11],
		"enforcer": [14, 10, 15, 8, 11, 7, 9],
		"two_way": [11, 11, 10, 10, 10, 10, 12],
		"nobody": [9, 9, 9, 9, 9, 9, 9],
	}
	for id: Variant in expected.keys():
		var stats: Dictionary = JU.dict(DataDB.archetype(str(id)), "stats")
		var row: Array = expected[id]
		for idx: int in DataSchemas.STATS.size():
			assert_eq(JU.i(stats, DataSchemas.STATS[idx]), int(row[idx]), "%s %s" % [id, DataSchemas.STATS[idx]])
	assert_eq(JU.s(DataDB.archetype("nobody"), "start_ball"), "ball_taped")
	assert_false(DataDB.archetype("nobody").has("start_bag_move"))


func test_validator_catches_bad_refs() -> void:
	var db: DataStore = DataStore.new()
	db.load_all()
	var arch: Dictionary = db.archetype("slasher")
	arch["start_ball"] = "ball_does_not_exist"
	var errs: PackedStringArray = db.validate()
	db.free()
	assert_gt(errs.size(), 0)
	var joined: String = "\n".join(errs)
	assert_string_contains(joined, "ball_does_not_exist")


func test_validator_value_specs() -> void:
	assert_eq(DataValidator.check_value(DataDB, 3, "int"), "")
	assert_ne(DataValidator.check_value(DataDB, 3.5, "int"), "")
	assert_eq(DataValidator.check_value(DataDB, "epic", DataSchemas.RARITIES), "")
	assert_ne(DataValidator.check_value(DataDB, "mythic", DataSchemas.RARITIES), "")
	assert_eq(DataValidator.check_value(DataDB, ["ball_rec"], "refs:balls"), "")
	assert_ne(DataValidator.check_value(DataDB, ["nope"], "refs:balls"), "")
