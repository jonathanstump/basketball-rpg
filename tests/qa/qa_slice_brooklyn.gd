extends QAScript
## QA slice run (spec §16 M8): new game in Brooklyn -> creator -> tutorial
## "I Got Next" -> wake in the bodega -> every POI in Bed-Stuy, Coney Island
## and DUMBO -> every fight (god-mode bot, T1) -> the Brooklyn Crown and an
## earned nickname.

const DISTRICTS: PackedStringArray = ["bk_bedstuy", "bk_coney", "bk_dumbo"]
const BOSSES: PackedStringArray = ["bk_stoop", "bk_barker", "bk_toll"]


func run() -> bool:
	await frames(5)
	if not check(get_tree().current_scene is TitleScreen, "boot did not land on the title"):
		return false
	# ---- New game: creator -> prologue.
	SceneRouter.goto(FrontEndFlow.CREATOR, {"slot": 2})
	await frames(8)
	if not check(get_tree().current_scene is CreatorScreen, "creator did not open"):
		return false
	var cr: CreatorScreen = get_tree().current_scene as CreatorScreen
	cr._on_look("_random")
	cr.profile["name"] = "QA Glide"
	FrontEndFlow.start_new_game("slasher", "brooklyn", cr.profile.duplicate(), 2)
	await frames(8)
	if not check(get_tree().current_scene is Prologue, "prologue did not open"):
		return false
	var pro: Prologue = get_tree().current_scene as Prologue
	pro.player.pos = pro.lay["top_of_key"]
	await frames(4)
	if not check(pro.phase == "call", "walk-up step did not complete"):
		return false
	pro.call_next()
	await frames(30)
	var si: ScriptedInput = ScriptedInput.new()
	pro.use_scripted_input(si)
	# The move step teaches sprint: hold dodge while moving, for real.
	si.move_at(0, Vector2(1, 0)).hold(0, 70, "dodge").move_at(71, Vector2.ZERO)
	pro.player.flags["qw"] = 3
	si.press_at(90, "dodge")             # ScriptedInput frames are relative to its first fill
	si.press_at(110, "quarter_water")
	await frames(160)
	for k: String in ["moved", "crossover", "qw_used"]:
		if not check(pro.tracker.done.has({"moved": "move", "crossover": "crossover", "qw_used": "quarter_water"}[k]), "tutorial step %s not detected from play" % k):
			return false
	# Timing-based steps (strike/ankle/crate/strip) are driven by tests/unit;
	# here the QA marks them to keep the run deterministic.
	for k2: String in ["strike", "ankle_breaker", "crate_make", "strip"]:
		pro.tracker.mark(k2)
	await frames(400)
	if not check(GameState.has_flag("prologue_done"), "cameo did not hand off to the bodega"):
		return false
	await frames(10)
	if not check(get_tree().current_scene is Interior, "did not wake up in a bodega"):
		return false
	print("QA slice: prologue done, woke up in %s" % GameState.respawn_bodega)
	# ---- Every POI, bodega, shop and fight (shared borough run helpers).
	var runner: QABoroughRun = QABoroughRun.new()
	add_child(runner)
	GameState.add_item("box_key", 20)
	for id: String in DISTRICTS:
		if await runner.sweep_district(id) < 0:
			return fail(runner.failure)
	if not await runner.visit_interiors(DISTRICTS):
		return fail(runner.failure)
	for boss_id: String in BOSSES:
		if not await runner.fight(boss_id):
			return fail(runner.failure)
	# ---- Pickup Challengers.
	for id3: String in DISTRICTS:
		for npc: Variant in JU.a(WorldIndex.all()[id3] as Dictionary, "npcs"):
			var ch: Dictionary = JU.dict(npc as Dictionary, "challenger")
			if ch.is_empty():
				continue
			var cr2: Dictionary = ChallengerDuel.run_sim(JU.f(ch, "skill", 0.5), 1, JU.i(ch, "tier_bonus"), {"max_s": 400, "seed": 5})
			print("QA slice: challenger %s -> %s %d-%d" % [JU.s(ch, "id"), cr2["result"], int(cr2["player"]), int(cr2["rival"])])
			if not check(str(cr2["result"]) != "timeout", "challenger %s never finished" % JU.s(ch, "id")):
				return false
	# ---- The Crown.
	if not check(GameState.has_crown("brooklyn"), "no Brooklyn Crown"):
		return false
	if not check(GameState.item_count("crown_brooklyn") == 1, "Crown item missing"):
		return false
	if not check(GameState.nickname != "", "no earned nickname"):
		return false
	if not check(TattooRules.slots() == 3, "Crown did not open a tattoo slot"):
		return false
	if not check(GameState.known_bag_moves.has("toll_booth"), "Toll Booth Bag Move not learned"):
		return false
	print("QA slice: Crown earned, nickname \"%s\", level %d, %d tokens, %d Rep" % [GameState.nickname, GameState.level, GameState.tokens, GameState.rep])
	return true

