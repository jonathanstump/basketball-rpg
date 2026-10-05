extends GutTest
## M5: every PossessionDuel transition (spec §7.10, §15.8) and its rules.

const D: GDScript = preload("res://core/duel/possession_duel.gd")


func _duel_in(state: String) -> PossessionDuel:
	var d: PossessionDuel = PossessionDuel.new()
	d.state = state
	return d


func test_every_table_transition() -> void:
	var count: int = 0
	for st: Variant in PossessionDuel.TABLE.keys():
		var row: Dictionary = PossessionDuel.TABLE[st]
		for input: Variant in row.keys():
			var d: PossessionDuel = _duel_in(str(st))
			d.player_cleared = true
			var expected: String = str(row[input])
			if expected == "":
				expected = str(st)
			assert_true(d.feed(str(input)), "%s accepts %s" % [st, input])
			assert_eq(d.state, expected, "%s --%s--> %s" % [st, input, expected])
			count += 1
	assert_gt(count, 30)


func test_invalid_inputs_are_ignored() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.CHECK)
	assert_false(d.feed("player_made"))
	assert_eq(d.state, PossessionDuel.CHECK)
	var v: PossessionDuel = _duel_in(PossessionDuel.VICTORY)
	assert_false(v.feed("player_died"))


func test_start_is_check_then_offense_after_1_2s() -> void:
	var d: PossessionDuel = PossessionDuel.new()
	d.start()
	assert_eq(d.state, PossessionDuel.CHECK)
	for _i: int in 71:
		d.tick(1.0 / 60.0)
	assert_eq(d.state, PossessionDuel.CHECK)
	d.tick(2.0 / 60.0)
	assert_eq(d.state, PossessionDuel.PLAYER_OFFENSE)
	assert_true(d.player_cleared, "the check is at the top of the key")


func test_make_it_take_it() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.PLAYER_OFFENSE)
	d.player_cleared = true
	d.feed("player_made", {"kind": "three"})
	var ev: Array[Dictionary] = d.take_events()
	var types: Array[String] = []
	for e: Dictionary in ev:
		types.append(str(e["type"]))
	assert_true(types.has("bucket"))
	assert_true(types.has("boss_rattled"))
	assert_eq(d.state, PossessionDuel.CHECK)
	for e2: Dictionary in ev:
		if str(e2["type"]) == "check":
			assert_eq(str(e2["to"]), "player", "you keep the ball")


func test_clear_rule() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.LOOSE_BALL)
	d.feed("player_picked")
	assert_false(d.player_cleared, "change of possession: must clear")
	d.feed("player_made")
	var types: Array[String] = []
	for e: Dictionary in d.take_events():
		types.append(str(e["type"]))
	assert_true(types.has("take_it_back"))
	assert_false(types.has("bucket"), "uncleared make does no damage")
	assert_eq(d.state, PossessionDuel.CHECK)


func test_clearing_the_arc() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.LOOSE_BALL)
	d.feed("player_picked")
	d.player_cleared_arc()
	assert_true(d.player_cleared)
	d.feed("player_made")
	var types: Array[String] = []
	for e: Dictionary in d.take_events():
		types.append(str(e["type"]))
	assert_true(types.has("bucket"))


func test_lock_in_stacks_cap_and_reset() -> void:
	var d: PossessionDuel = PossessionDuel.new()
	d.start()
	for _i: int in 10:
		d.state = PossessionDuel.PLAYER_OFFENSE
		d.player_cleared = true
		d.feed("player_made")
	assert_eq(d.lock_in_stacks, 6, "+30% cap = 6 stacks of 5%")
	assert_almost_eq(d.contest_mult(), 1.3, 0.0001)
	d.state = PossessionDuel.PLAYER_OFFENSE
	d.feed("phase_down")
	assert_eq(d.lock_in_stacks, 0, "resets per phase")
	assert_eq(d.phase, 2)


func test_boss_auto_clears_after_2s() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.LOOSE_BALL)
	d.feed("boss_picked")
	assert_false(d.boss_cleared)
	for _i: int in 119:
		d.tick(1.0 / 60.0)
	assert_false(d.boss_cleared)
	d.tick(2.0 / 60.0)
	assert_true(d.boss_cleared)


func test_statement_dunk_scores_and_rejection() -> void:
	## Playtest R7 (spec change): a landed Statement Dunk is a bucket on you,
	## not an 8% heal.
	var d: PossessionDuel = _duel_in(PossessionDuel.BOSS_OFFENSE)
	d.feed("statement_landed")
	var kind: String = ""
	var healed: bool = false
	for e: Dictionary in d.take_events():
		if str(e["type"]) == "boss_bucket":
			kind = str(e["kind"])
		healed = healed or str(e["type"]) == "boss_heal"
	assert_eq(kind, "dunk")
	assert_false(healed)
	assert_eq(d.state, PossessionDuel.CHECK, "then CHECK, your ball")
	var r: PossessionDuel = _duel_in(PossessionDuel.BOSS_OFFENSE)
	r.feed("statement_rejected")
	var comp: float = 0.0
	for e2: Dictionary in r.take_events():
		if str(e2["type"]) == "boss_composure":
			comp = float(e2["amount"])
	assert_almost_eq(comp, -40.0, 0.0001)
	assert_eq(r.state, PossessionDuel.LOOSE_BALL)


func test_r7_boss_shot_transitions() -> void:
	var made: PossessionDuel = _duel_in(PossessionDuel.BOSS_OFFENSE)
	made.feed("boss_made", {"kind": "three"})
	assert_eq(made.state, PossessionDuel.CHECK, "boss bucket: your ball")
	for inp: String in ["boss_missed", "boss_blocked", "boss_coughed"]:
		var x: PossessionDuel = _duel_in(PossessionDuel.BOSS_OFFENSE)
		x.feed(inp)
		assert_eq(x.state, PossessionDuel.LOOSE_BALL, inp)
	var t: PossessionDuel = _duel_in(PossessionDuel.PLAYER_OFFENSE)
	t.feed("player_turnover")
	assert_eq(t.state, PossessionDuel.LOOSE_BALL, "turnover")


func test_rejected_punish_gives_boss_offense() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.PLAYER_OFFENSE)
	d.feed("player_rejected")
	var types: Array[String] = []
	for e: Dictionary in d.take_events():
		types.append(str(e["type"]))
	assert_true(types.has("rejected_punish"))
	assert_eq(d.state, PossessionDuel.BOSS_OFFENSE)


func test_phase_transition_lasts_3s() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.PLAYER_OFFENSE)
	d.feed("phase_down")
	d.tick(2.9)
	assert_eq(d.state, PossessionDuel.PHASE_TRANSITION)
	d.tick(0.2)
	assert_eq(d.state, PossessionDuel.CHECK)


func test_game_point_any_bucket_wins() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.LOOSE_BALL)
	d.feed("boss_down")
	assert_eq(d.state, PossessionDuel.GAME_POINT)
	assert_true(d.player_cleared)
	d.feed("player_missed")
	assert_eq(d.state, PossessionDuel.GAME_POINT, "misses keep game point")
	d.player_cleared = false
	d.feed("player_made")
	assert_eq(d.state, PossessionDuel.VICTORY)


func test_out_of_bounds_checks_to_player() -> void:
	var d: PossessionDuel = _duel_in(PossessionDuel.BOSS_OFFENSE)
	d.feed("out_of_bounds")
	assert_eq(d.state, PossessionDuel.CHECK)
