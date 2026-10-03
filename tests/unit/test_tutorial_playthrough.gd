extends GutTest
## Plays the whole "I Got Next" tutorial with real button input (no marks,
## no teleports): every step must be completable by doing what its prompt
## says, and the prompt on screen must always match the open step.


class TutorialBot:
	extends InputSource
	var pro: Prologue
	var _cool: int = 0
	var _lap: int = 0
	var log_lines: PackedStringArray = PackedStringArray()

	func fill(input: ActorInput, a: SimActor, w: SimWorld) -> void:
		_cool = maxi(0, _cool - 1)
		var step: String = pro.tracker.current_id()
		for act: String in ["dodge", "hands_up", "light"]:
			# Taps are one frame; the move step holds dodge to sprint.
			if input.is_held(act) and not (act == "dodge" and step == "move"):
				input.release(act)
		match step:
			"walk_up":
				_go(input, a, pro.lay["top_of_key"])
			"call_next":
				input.move = Vector2.ZERO
				if _cool == 0:
					input.press("interact")
					_cool = 20
			"move":
				var pts: Array[Vector3] = [Vector3(-5, 0, 4), Vector3(5, 0, 4), Vector3(5, 0, -2), Vector3(-5, 0, -2)]
				if a.pos.distance_to(pts[_lap % 4]) < 1.0:
					_lap += 1
				_go(input, a, pts[_lap % 4])
				if not input.is_held("dodge"):
					input.press("dodge")
				input.held["dodge"] = true
			"strike":
				var c: SimActor = w.nearest_hostile(a, 40.0)
				if c != null:
					_go(input, a, c.pos)
					if a.dist_to(c) < 1.8 and _cool == 0:
						input.press("light")
						_cool = 14
			"crossover":
				if a.has_ball:
					input.move = Vector2(1, 0) if (w.frame / 40) % 2 == 0 else Vector2(-1, 0)
					if _cool == 0:
						input.press("dodge")
						_cool = 30
				else:
					_chase_ball(input, a)
			"ankle", "strip":
				var c2: SimActor = w.nearest_hostile(a, 40.0)
				if step == "ankle" and not a.has_ball:
					_chase_ball(input, a)
					return
				if c2 == null:
					return
				if a.dist_to(c2) > 2.2:
					_go(input, a, c2.pos)
				else:
					input.move = Vector2.ZERO
				# Follow the red glow like a player: act on the pulse.
				var cue: bool = false
				for c3: SimActor in pro.crew:
					cue = cue or (c3.alive and a.dist_to(c3) < 7.0 and bool(Telegraph.read(c3).get("now", false)))
				if cue and _cool == 0:
					input.press("dodge" if step == "ankle" else "hands_up")
					_cool = 24
			"shoot":
				if not a.has_ball:
					_chase_ball(input, a)
					return
				var crate: SimHoop = pro.balls.hoop_by_id("tutorial_crate")
				var spot: Vector3 = crate.floor_point() + crate.facing * 3.0
				var mod: HooperBall = _ball_mod()
				if mod != null and mod.meter >= 0.0:
					input.move = Vector2.ZERO
					var target: float = mod.windows.center if mod.windows != null else 0.82
					if mod.meter >= target:
						input.release("shoot")
					else:
						input.held["shoot"] = true
				elif a.pos.distance_to(spot) > 0.8:
					_go(input, a, spot)
				elif _cool == 0:
					input.move = Vector2.ZERO
					input.press("shoot")
					input.held["shoot"] = true
					_cool = 30
			"quarter_water":
				if _cool == 0:
					input.press("quarter_water")
					_cool = 40

	func _go(input: ActorInput, a: SimActor, dest: Vector3) -> void:
		var d: Vector3 = dest - a.pos
		d.y = 0.0
		input.move = Vector2(d.x, d.z).normalized() if d.length() > 0.4 else Vector2.ZERO

	func _chase_ball(input: ActorInput, a: SimActor) -> void:
		var best: SimBall = null
		for b: SimBall in pro.balls.balls:
			if b.holder_id == 0 and (best == null or b.pos.distance_to(a.pos) < best.pos.distance_to(a.pos)):
				best = b
		if best != null:
			_go(input, a, best.pos)

	func _ball_mod() -> HooperBall:
		for m: RefCounted in pro.player_hooper.modules:
			if m is HooperBall:
				return m
		return null


func test_whole_tutorial_with_real_input() -> void:
	GameState.new_run("nobody", "brooklyn")
	var pro: Prologue = (load("res://world/prologue/prologue.tscn") as PackedScene).instantiate() as Prologue
	pro.auto_wake = false
	add_child_autofree(pro)
	await wait_physics_frames(3)
	var bot: TutorialBot = TutorialBot.new()
	bot.pro = pro
	pro.use_scripted_input(bot)
	var step: String = ""
	var step_start: int = 0
	var frames: int = 0
	var times: Dictionary = {}
	var one_ball_ok: bool = true
	while frames < 60 * 60 and pro.phase in ["walk_up", "call", "tutorial"]:
		await wait_physics_frames(1)
		frames += 1
		var cur: String = pro.tracker.current_id()
		if frames % 30 == 0 and pro.phase == "tutorial":
			var carriers: int = 0
			for c: SimActor in pro.crew:
				carriers += 1 if c.alive and c.has_ball else 0
			var alive: int = 0
			for c2: SimActor in pro.crew:
				alive += 1 if c2.alive else 0
			if cur == "strip":
				one_ball_ok = one_ball_ok and carriers >= alive - 1 and not pro.player.has_ball
			else:
				one_ball_ok = one_ball_ok and carriers == 0
		if cur != step:
			if step != "":
				times[step] = frames - step_start
			step = cur
			step_start = frames
			await wait_physics_frames(1)
			frames += 1
			gut.p("f=%d step=%s prompt=%s" % [frames, cur, pro.prompt.text])
			if cur != "cameo":
				var raw: String = ""
				for s: Variant in pro.tracker.steps:
					if JU.s(s as Dictionary, "id") == cur:
						raw = JU.s(s as Dictionary, "prompt")
				assert_eq(pro.prompt.text, InputPrompts.format(raw), "%s: the prompt on screen is this step's" % cur)
	gut.p("frames per step: %s" % str(times))
	assert_true(pro.tracker.tutorial_complete(), "every step completable with real input; stuck on %s (%s)" % [pro.tracker.current_id(), pro.phase])
	assert_eq(pro.phase, "cameo", "the tutorial hands off to the cameo")
	assert_true(one_ball_ok, "on offense the crew have no balls; on defense they all do and you don't")


class StandStillDefender:
	extends InputSource
	## A player who stays put and only presses Hands Up when a crew member
	## near them glows red (the cue frames): the real-player strip drill.
	var pro: Prologue
	var _cool: int = 0

	func fill(input: ActorInput, a: SimActor, _w: SimWorld) -> void:
		input.move = Vector2.ZERO
		if input.is_held("hands_up"):
			input.release("hands_up")
		_cool = maxi(0, _cool - 1)
		for c: SimActor in pro.crew:
			if c.alive and a.dist_to(c) < 7.0 and bool(Telegraph.read(c).get("now", false)) and _cool == 0:
				input.press("hands_up")
				_cool = 20


func test_strip_drill_works_for_a_player_who_waits_for_the_cue() -> void:
	## Regression: the crew used to circle forever on defense (a ball-less
	## crew member sat on the only attack token).
	GameState.new_run("nobody", "brooklyn")
	var pro: Prologue = (load("res://world/prologue/prologue.tscn") as PackedScene).instantiate() as Prologue
	pro.auto_wake = false
	add_child_autofree(pro)
	await wait_physics_frames(3)
	pro.player.pos = pro.lay["top_of_key"]
	pro.tracker.mark("reach_court")
	pro.call_next()
	for k: String in ["moved", "strike", "crossover", "ankle_breaker", "crate_make"]:
		pro.tracker.mark(k)
	await wait_physics_frames(3)
	assert_eq(pro.tracker.current_id(), "strip")
	var armed: int = 0
	for c: SimActor in pro.crew:
		armed += 1 if c.alive and c.has_ball else 0
	assert_eq(armed, pro.crew.size(), "every crew member has a ball on defense")
	assert_false(pro.player.has_ball, "your ball sits out")
	var d: StandStillDefender = StandStillDefender.new()
	d.pro = pro
	pro.use_scripted_input(d)
	var frames: int = 0
	while pro.tracker.current_id() == "strip" and frames < 60 * 30:
		await wait_physics_frames(1)
		frames += 1
	gut.p("strip took %.1f s standing still" % (float(frames) / 60.0))
	assert_ne(pro.tracker.current_id(), "strip", "the crew attack and a cue-timed Hands Up strips one")
	await wait_physics_frames(2)
	assert_true(pro.player.has_ball, "back on offense with your ball")
	var left: int = 0
	for c3: SimActor in pro.crew:
		left += 1 if c3.has_ball else 0
	assert_eq(left, 0, "the crew's balls go away")
