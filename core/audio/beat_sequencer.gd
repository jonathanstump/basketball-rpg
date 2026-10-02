class_name BeatSequencer
extends RefCounted
## Procedural music (spec §13, §15.13): a 16-step pattern per region
## (data/audio/patterns.json) synthesized into stereo frames. Step k always
## starts at round(k * step_len) samples (no accumulated rounding), so the
## music never drifts from the BeatClock. Three layers: explore (drums +
## bass), combat (+ lead), boss (+ pad); gains crossfade per buffer.

const LAYER_TRACKS: Dictionary = {"explore": ["kick", "snare", "hat", "bass"], "combat": ["kick", "snare", "hat", "bass", "lead"],
	"boss": ["kick", "snare", "hat", "bass", "lead", "pad"], "title": ["hat", "bass", "pad"]}
const TRACKS: PackedStringArray = ["kick", "snare", "hat", "bass", "lead", "pad"]
const FADE_PER_S: float = 1.5

var rate: int = Synth.RATE
var pattern: Dictionary = {}
var bpm: float = 92.0
var steps: int = 16
var sample_pos: int = 0
var next_step: int = 0
var layer: String = "explore"
var gains: Dictionary = {}
var voices: Array[Dictionary] = []      # {buf, at, gain_key}
var triggers: Array[int] = []           # dry-mode log of step start samples (tests)
var _cache: Dictionary = {}


func _init(pat: Dictionary = {}, sample_rate: int = Synth.RATE) -> void:
	rate = sample_rate
	set_pattern(pat)
	for t: String in TRACKS:
		gains[t] = 1.0 if (LAYER_TRACKS[layer] as Array).has(t) else 0.0


func set_pattern(pat: Dictionary) -> void:
	pattern = pat
	bpm = JU.f(pat, "bpm", 92.0)
	steps = JU.i(pat, "steps", 16)


func set_layer(l: String) -> void:
	if LAYER_TRACKS.has(l):
		layer = l


func step_len() -> float:
	## Samples per 16th note.
	return float(rate) * 60.0 / bpm / 4.0


func step_start(k: int) -> int:
	return int(round(float(k) * step_len()))


func beat_time_s(beat: int) -> float:
	return float(beat) * 60.0 / bpm


func _voice_buf(track: String, value: int) -> PackedFloat32Array:
	var key: String = "%s:%d:%d" % [track, value, int(bpm)]
	if not _cache.has(key):
		var root: int = JU.i(pattern, "root", 45)
		var len_s: float = 60.0 / bpm * (1.0 if track in ["bass", "lead"] else (4.0 if track == "pad" else 0.5))
		_cache[key] = Synth.render(track, Synth.midi_hz(root + value), len_s, rate)
	return _cache[key]


func _trigger_step(k: int, offset: int) -> void:
	var idx: int = posmod(k, steps)
	var tracks: Dictionary = JU.dict(pattern, "tracks")
	for t: String in TRACKS:
		var seq: Array = JU.a(tracks, t)
		if idx >= seq.size():
			continue
		var v: Variant = seq[idx]
		if v == null or (v is float and int(v) < 0) or (v is int and int(v) < 0) or (v is bool and not v):
			continue
		var note: int = 0 if (v is bool) else int(v)
		if t in ["kick", "snare", "hat"] and note <= 0:
			continue
		voices.append({"buf": _voice_buf(t, note if not t in ["kick", "snare", "hat"] else 0), "at": -offset, "track": t})


func advance_dry(n: int) -> void:
	## Step timing only (no audio): used by drift tests and headless runs.
	var end: int = sample_pos + n
	while step_start(next_step) < end:
		triggers.append(step_start(next_step))
		next_step += 1
	sample_pos = end


func mix(n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(n)
	var dt: float = float(n) / float(rate)
	for t: String in TRACKS:
		var want: float = 1.0 if (LAYER_TRACKS[layer] as Array).has(t) else 0.0
		gains[t] = move_toward(float(gains[t]), want, FADE_PER_S * dt)
	var end: int = sample_pos + n
	while step_start(next_step) < end:
		_trigger_step(next_step, step_start(next_step) - sample_pos)
		next_step += 1
	var alive: Array[Dictionary] = []
	for v: Dictionary in voices:
		var buf: PackedFloat32Array = v["buf"]
		var at: int = int(v["at"])
		var g: float = float(gains.get(str(v["track"]), 0.0)) * 0.3
		if g > 0.0:
			for i: int in n:
				var j: int = at + i
				if j >= 0 and j < buf.size():
					var s: float = buf[j] * g
					out[i] += Vector2(s, s)
		v["at"] = at + n
		if int(v["at"]) < buf.size():
			alive.append(v)
	voices = alive
	sample_pos = end
	return out
