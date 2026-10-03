extends GutTest
## The tutorial's first steps played with real movement input (no teleports):
## walk/sprint to the court, call next, and the prompt moves on.


class Steer:
	extends InputSource
	## Steers toward a target (world XZ), optionally holding an action.
	var target: Vector3 = Vector3.ZERO
	var hold_action: String = ""
	var press_queue: Array[String] = []

	func fill(input: ActorInput, actor: SimActor, _world: SimWorld) -> void:
		var d: Vector3 = target - actor.pos
		d.y = 0.0
		input.move = Vector2(d.x, d.z).normalized() if d.length() > 0.3 else Vector2.ZERO
		if hold_action != "":
			if not input.is_held(hold_action):
				input.press(hold_action)
			input.held[hold_action] = true
		for a: String in press_queue:
			input.press(a)
			input.release(a)
		press_queue.clear()


var pro: Prologue


func before_each() -> void:
	GameState.new_run("nobody", "brooklyn")
	pro = (load("res://world/prologue/prologue.tscn") as PackedScene).instantiate() as Prologue
	pro.auto_wake = false
	add_child_autofree(pro)
	await wait_physics_frames(3)


func _walk_to_court(sprint: bool, max_frames: int) -> int:
	var s: Steer = Steer.new()
	s.target = pro.lay["top_of_key"]
	s.hold_action = "dodge" if sprint else ""
	pro.use_scripted_input(s)
	for f: int in max_frames:
		await wait_physics_frames(1)
		if f % 60 == 0:
			gut.p("f=%d pos=%s dist=%.2f phase=%s step=%s" % [f, pro.player.pos, pro.player.pos.distance_to(pro.lay["top_of_key"]), pro.phase, pro.tracker.current_id()])
		if pro.phase != "walk_up":
			return f
	return -1


func test_walking_to_the_court_advances() -> void:
	gut.p("start=%s top_of_key=%s gate=%s" % [pro.player.pos, pro.lay["top_of_key"], pro.lay["gate"]])
	var f: int = await _walk_to_court(false, 900)
	assert_gt(f, -1, "walking reaches the court and the prompt moves on (phase %s)" % pro.phase)
	assert_eq(pro.tracker.current_id(), "call_next")


func test_sprinting_to_the_court_advances() -> void:
	var f: int = await _walk_to_court(true, 900)
	assert_gt(f, -1, "sprinting reaches the court and the prompt moves on (phase %s)" % pro.phase)


func test_after_calling_next_moving_moves_the_prompt_on() -> void:
	await _walk_to_court(false, 900)
	var s: Steer = pro.player.input_source as Steer
	s.press_queue.append("interact")
	await wait_physics_frames(3)
	assert_eq(pro.phase, "tutorial", "interact at the court calls next")
	var move_prompt: String = pro.prompt.text
	gut.p("after call: step=%s prompt=%s" % [pro.tracker.current_id(), move_prompt])
	assert_eq(pro.tracker.current_id(), "move", "move isn't done before you've moved")
	assert_string_contains(move_prompt, "[Shift]")
	# Walking alone doesn't finish it: the step also teaches sprint.
	s.target = Vector3(-5, 0, 4)
	await wait_physics_frames(90)
	assert_eq(pro.tracker.current_id(), "move", "walking only: still on the move step")
	# Sprint laps around the court like a player trying the move step.
	s.hold_action = "dodge"
	var corners: Array[Vector3] = [Vector3(-5, 0, 4), Vector3(5, 0, 4), Vector3(5, 0, -2), Vector3(-5, 0, -2)]
	for i: int in 12:
		s.target = corners[i % corners.size()]
		await wait_physics_frames(40)
	gut.p("after moving: step=%s done(move)=%s prompt=%s" % [pro.tracker.current_id(), pro.tracker.is_done("move"), pro.prompt.text])
	assert_true(pro.tracker.is_done("move"), "the move step completes")
	assert_ne(pro.prompt.text, move_prompt, "the on-screen prompt moves on to the next step")
	assert_string_contains(pro.prompt.text, "[Left Click]", "next prompt is the dribble strike")
