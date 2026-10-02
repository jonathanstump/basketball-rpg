extends Node
## Music, ambience, SFX and voices (spec §13, §15.13). Procedural music from
## BeatSequencer through an AudioStreamGenerator; explore/combat/boss layers
## crossfade; region ambience loops; a pooled SFX player; syllable-gibberish
## voices with a megaphone bus for Mic Check. Buses follow the volume
## settings. Headless runs keep the sequencer's clock but skip synthesis.

const POOL: int = 12
const REGION_AMBIENCE: Dictionary = {"interior": "amb_hum", "garden": "amb_court", "title": ""}

var music_layer: String = "explore"
var region: String = ""
var sequencer: BeatSequencer = BeatSequencer.new()
var _music: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _ambience: AudioStreamPlayer = null
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _silent: bool = false
var sfx_played: Dictionary = {}       # id -> count (tests, QA)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Voice")
	_ensure_bus("Megaphone", "Voice")
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Megaphone")) == 0:
		var bp: AudioEffectBandPassFilter = AudioEffectBandPassFilter.new()
		bp.cutoff_hz = 1800.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Megaphone"), bp)
		var dist: AudioEffectDistortion = AudioEffectDistortion.new()
		dist.drive = 0.4
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Megaphone"), dist)
	apply_volumes()
	EventBus.settings_changed.connect(apply_volumes)
	if _silent:
		return
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = Synth.RATE
	gen.buffer_length = 0.3
	_music = AudioStreamPlayer.new()
	_music.stream = gen
	_music.bus = "Music"
	add_child(_music)
	_music.play()
	_playback = _music.get_stream_playback() as AudioStreamGeneratorPlayback
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "SFX"
	_ambience.volume_db = -8.0
	add_child(_ambience)
	for i: int in POOL:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	SfxSynth.warm_all()


func _ensure_bus(bus_name: String, send: String = "Master") -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)


func apply_volumes() -> void:
	for pair: Array in [["Music", "music_volume"], ["SFX", "sfx_volume"], ["Voice", "sfx_volume"]]:
		var idx: int = AudioServer.get_bus_index(str(pair[0]))
		if idx >= 0:
			var v: float = clampf(Settings.get_float(str(pair[1])), 0.0, 1.0)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(idx, v <= 0.0)


func set_region(r: String) -> void:
	if r == region:
		return
	region = r
	var pat: Dictionary = DataDB.item("patterns", r)
	if pat.is_empty():
		pat = DataDB.item("patterns", "city")
	sequencer.set_pattern(pat)
	var amb: String = str(REGION_AMBIENCE.get(r, "amb_street"))
	if _ambience != null:
		_ambience.stream = SfxSynth.stream(amb) if amb != "" else null
		if _ambience.stream != null:
			_ambience.play()
		else:
			_ambience.stop()


func set_layer(layer: String) -> void:
	music_layer = layer
	if layer == "title":
		set_region("title")
	sequencer.set_layer(layer)


func _process(_delta: float) -> void:
	if _playback == null:
		sequencer.advance_dry(int(Synth.RATE / 60))
		return
	var n: int = _playback.get_frames_available()
	if n > 0:
		_playback.push_buffer(sequencer.mix(n))


func play_sfx(id: String, _pos: Vector3 = Vector3.INF, pitch: float = 1.0) -> void:
	sfx_played[id] = int(sfx_played.get(id, 0)) + 1
	if _silent or _pool.is_empty() or not SfxSynth.has(id):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SfxSynth.stream(id)
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.bus = "SFX"
	p.play()


func voice_blip(speaker: String) -> void:
	## Syllable gibberish: one blip per few characters, pitch per speaker.
	var pitch: float = 0.75 + float(posmod(hash(speaker), 9)) * 0.07
	var mega: bool = speaker == "Mic Check"
	sfx_played["voice_blip"] = int(sfx_played.get("voice_blip", 0)) + 1
	if _silent or _pool.is_empty():
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SfxSynth.stream("megaphone_blip" if mega else "voice_blip")
	p.pitch_scale = pitch * randf_range(0.9, 1.1)
	p.bus = "Megaphone" if mega else "Voice"
	p.play()
