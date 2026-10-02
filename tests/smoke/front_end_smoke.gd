extends Node
## Smoke (spec §16 M8): title builds its menu; the creator walks look ->
## name -> archetype -> borough menus; the prologue runs the tutorial with
## live crew, then the Midnight cameo; a Pickup Challenger court runs a bot.

var problems: PackedStringArray = PackedStringArray()


func _ready() -> void:
	GameState.new_run("two_way", "brooklyn", {"name": "Smoke"})
	var title: TitleScreen = (load("res://ui/title/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	add_child(title)
	await _frames(5)
	if title.menu == null:
		problems.append("title: no menu")
	title.queue_free()
	var cr: CreatorScreen = (load("res://ui/creator/creator.tscn") as PackedScene).instantiate() as CreatorScreen
	add_child(cr)
	await _frames(3)
	for k: String in CreatorScreen.LOOK_KEYS:
		cr._adjust(k, 1)
	cr._on_look("_random")
	cr.open_name()
	cr.open_archetype()
	cr.open_borough()
	cr.open_confirm()
	await _frames(3)
	if cr.menu == null or cr.rig == null:
		problems.append("creator: no menu or preview")
	cr.queue_free()
	var pro: Prologue = (load("res://world/prologue/prologue.tscn") as PackedScene).instantiate() as Prologue
	pro.auto_wake = false
	add_child(pro)
	await _frames(5)
	pro.player.pos = pro.lay["top_of_key"]
	await _frames(3)
	if pro.phase != "call":
		problems.append("prologue: walk-up did not reach the court (%s)" % pro.phase)
	pro.call_next()
	await _frames(100)
	if pro.crew.is_empty():
		problems.append("prologue: no crew")
	pro.skip_tutorial()
	await _frames(260)
	if pro.phase != "out" or not pro.tracker.is_done("cameo"):
		problems.append("prologue: cameo did not finish (%s)" % pro.phase)
	pro.queue_free()
	await _frames(2)
	SceneRouter.take_params()
	var court: ChallengerCourt = (load("res://world/arenas/challenger_court.tscn") as PackedScene).instantiate() as ChallengerCourt
	add_child(court)
	await _frames(2)
	var bot: ChallengerBrain = ChallengerBrain.for_tier(6)
	bot.hoop_id = court.duel.hoop.id
	bot.opponent_id = court.rival.id
	court.use_scripted_input(bot)
	await _frames(300)
	if int(court.duel.score[court.player.id]) + int(court.duel.score[court.rival.id]) == 0:
		problems.append("challenger court: nobody scored in 300 frames")
	if problems.is_empty():
		print("SMOKE OK front_end_smoke")
	else:
		for p: String in problems:
			push_error("front_end_smoke: " + p)
	get_tree().quit()


func _frames(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame
