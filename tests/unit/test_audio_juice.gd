extends GutTest
## M13: BeatSequencer/BeatClock stay locked (drift < 5 ms over 5 minutes),
## layers crossfade, SfxSynth renders every recipe, accessibility settings
## persist, reduce-flashes cuts the listed effects, remapping works.

var _saved_remaps: Variant


func before_each() -> void:
	_saved_remaps = Settings.get_value("remaps")


func after_each() -> void:
	Settings.set_value("remaps", _saved_remaps)
	InputRouter.apply_input_map()
	Settings.set_value("reduce_flashes", false)


func test_beat_clock_drift_under_5ms_over_5_minutes() -> void:
	for region: String in ["bronx", "garden", "staten_island"]:
		var pat: Dictionary = DataDB.item("patterns", region)
		var seq: BeatSequencer = BeatSequencer.new(pat)
		var clock: BeatClock = BeatClock.new(seq.bpm, 0)
		var chunk: int = Synth.RATE / 60
		var frames: int = 60 * 300
		for _f: int in frames:
			seq.advance_dry(chunk)
		var worst: float = 0.0
		var beats: int = 0
		for i: int in range(0, seq.triggers.size(), 4):
			var k: int = i / 4
			var t_seq: float = float(seq.triggers[i]) / float(Synth.RATE)
			var t_ideal: float = seq.beat_time_s(k)
			var t_clock: float = (float(clock.origin_frame) + float(k) * clock.frames_per_beat()) / 60.0
			worst = maxf(worst, maxf(absf(t_seq - t_ideal), absf(t_clock - t_seq)))
			beats += 1
		gut.p("%s: %d beats over 5 min, worst drift %.3f ms" % [region, beats, worst * 1000.0])
		assert_gt(beats, int(seq.bpm * 4.5), "about 5 minutes of beats")
		assert_lt(worst, 0.005, "%s drift < 5 ms" % region)
		## The gameplay clock agrees with the music on which beat is "now".
		assert_eq(clock.beat_index(int(round(seq.beat_time_s(200) * 60.0)) + 1), 200)


func test_sequencer_layers_crossfade() -> void:
	var seq: BeatSequencer = BeatSequencer.new(DataDB.item("patterns", "garden"))
	var a: PackedVector2Array = seq.mix(Synth.RATE)
	var energy: float = 0.0
	for v: Vector2 in a:
		energy += absf(v.x)
	assert_gt(energy, 10.0, "explore layer is audible")
	assert_eq(float(seq.gains["lead"]), 0.0, "no lead while exploring")
	seq.set_layer("boss")
	seq.mix(Synth.RATE * 2)
	assert_almost_eq(float(seq.gains["pad"]), 1.0, 0.001, "boss stem faded in")
	seq.set_layer("explore")
	seq.mix(Synth.RATE / 4)
	assert_gt(float(seq.gains["lead"]), 0.0, "crossfade, not a hard cut")
	assert_lt(float(seq.gains["lead"]), 1.0)


func test_every_region_has_a_pattern_and_sfx_render() -> void:
	for r: String in ["bronx", "brooklyn", "queens", "staten_island", "uptown", "city", "garden", "title", "interior"]:
		assert_false(DataDB.item("patterns", r).is_empty(), "pattern for %s" % r)
	for id: Variant in DataDB.catalog("sfx").keys():
		var w: AudioStreamWAV = SfxSynth.stream(str(id))
		assert_not_null(w, str(id))
		assert_gt(w.data.size(), 100, "%s has samples" % id)
	for needed: String in ["chain_ching", "swish", "rim_clank", "crowd_ooh", "cooked", "door_bell", "cat_purr", "bounce_wood", "bounce_wet", "squeak"]:
		assert_true(SfxSynth.has(needed), "spec §13 sfx %s" % needed)
	assert_true(SfxSynth.stream("amb_street").loop_mode == AudioStreamWAV.LOOP_FORWARD, "ambience loops")


func test_voices_and_sfx_requests() -> void:
	var n0: int = int(AudioDirector.sfx_played.get("voice_blip", 0))
	AudioDirector.voice_blip("Pops")
	AudioDirector.voice_blip("Mic Check")
	assert_eq(int(AudioDirector.sfx_played["voice_blip"]), n0 + 2)


func test_accessibility_settings_persist() -> void:
	var path: String = "user://test_settings_m13.cfg"
	var keys: Dictionary = {"reduce_flashes": true, "ui_scale": 1.5, "colorblind": "tritanopia", "hold_to_guard": false,
		"camera_invert_y": true, "screen_shake": 0.0, "rookie_mode": true, "pass_aim_assist": false, "subtitles": false,
		"music_volume": 0.4, "sfx_volume": 0.5, "remaps": {"jump": {"keys": ["K"]}}}
	for k: Variant in keys.keys():
		Settings.set_value(str(k), keys[k])
	assert_eq(Settings.save_settings(path), OK)
	Settings.reset_defaults()
	Settings.load_settings(path)
	for k2: Variant in keys.keys():
		assert_eq(str(Settings.get_value(str(k2))), str(keys[k2]), "%s persists" % k2)
	Settings.reset_defaults()


func test_reduce_flashes_disables_listed_effects() -> void:
	for kind: String in ["tourist", "lightning", "poster"]:
		assert_gt(PostFX.flash_strength(kind, false), 0.5, "%s flashes normally" % kind)
		assert_lt(PostFX.flash_strength(kind, true), 0.15, "%s reduced" % kind)
	assert_lt(PostFX.halftone_length(true), PostFX.halftone_length(false), "POSTER halftone shortened")


func test_remap_binds_new_key() -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_K
	RemapMenu.bind("jump", ev)
	var found: bool = false
	for e: InputEvent in InputMap.action_get_events("jump"):
		found = found or (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_K)
	assert_true(found, "jump is now K")
	InputRouter.last_device = "keyboard"
	assert_eq(InputRouter.glyph("jump"), "K", "prompt glyph follows the remap")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	RemapMenu.bind("jump", pad)
	InputRouter.last_device = "pad"
	assert_eq(InputRouter.glyph("jump"), "Y")
	InputRouter.last_device = "keyboard"
	assert_eq(InputRouter.glyph("jump"), "K", "keyboard binding kept")


func test_rookie_mode_values() -> void:
	Settings.set_value("rookie_mode", true)
	GameState.new_run("two_way", "brooklyn")
	assert_eq(GameState.quarter_water_max, 5, "+2 Quarter Waters")
	Settings.set_value("rookie_mode", false)
	GameState.new_run("two_way", "brooklyn")
	assert_eq(GameState.quarter_water_max, 3)
