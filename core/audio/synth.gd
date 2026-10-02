class_name Synth
extends RefCounted
## Tiny procedural instruments (spec §13 placeholder plan): kick, snare, hat,
## bass, lead, pad and generic sfx voices rendered to mono float buffers.
## Deterministic (seeded noise) so tests and caches are stable.

const RATE: int = 22050


static func midi_hz(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


static func render(kind: String, freq: float = 110.0, length_s: float = 0.3, rate: int = RATE) -> PackedFloat32Array:
	var n: int = maxi(1, int(length_s * float(rate)))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(kind) + int(freq)
	var phase: float = 0.0
	var lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(rate)
		var env: float = 1.0
		var v: float = 0.0
		match kind:
			"kick":
				var f: float = 45.0 + 80.0 * exp(-t * 30.0)
				phase += TAU * f / float(rate)
				env = exp(-t * 9.0)
				v = sin(phase)
			"snare":
				phase += TAU * 185.0 / float(rate)
				env = exp(-t * 18.0)
				v = 0.45 * sin(phase) + 0.75 * rng.randf_range(-1.0, 1.0)
			"hat":
				var nz: float = rng.randf_range(-1.0, 1.0)
				v = nz - lp
				lp = nz
				env = exp(-t * 60.0) * 0.5
			"bass":
				phase += TAU * freq / float(rate)
				env = minf(1.0, t * 200.0) * exp(-t * 3.5)
				v = 0.7 * sin(phase) + 0.25 * sin(phase * 2.0) + 0.12 * sin(phase * 3.0)
			"lead":
				phase += TAU * freq / float(rate)
				env = minf(1.0, t * 80.0) * exp(-t * 4.0) * 0.6
				v = signf(sin(phase)) * 0.5 + 0.5 * sin(phase)
			"pad":
				phase += TAU * freq / float(rate)
				env = minf(1.0, t * 4.0) * minf(1.0, (length_s - t) * 4.0) * 0.35
				v = sin(phase) + 0.5 * sin(phase * 1.26) + 0.5 * sin(phase * 1.5)
			_:
				phase += TAU * freq / float(rate)
				v = sin(phase)
				env = exp(-t * 6.0)
		out[i] = clampf(v * env, -1.0, 1.0)
	return out


static func render_sfx(recipe: Dictionary, rate: int = RATE) -> PackedFloat32Array:
	## sfxr-style: wave (sine/square/saw/noise), f0 -> f1 sweep, attack/decay,
	## optional noise mix and tremolo.
	var length_s: float = JU.f(recipe, "len", 0.2)
	var n: int = maxi(1, int(length_s * float(rate)))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(JU.s(recipe, "wave")) + int(JU.f(recipe, "f0", 440.0))
	var wave: String = JU.s(recipe, "wave", "sine")
	var f0: float = JU.f(recipe, "f0", 440.0)
	var f1: float = JU.f(recipe, "f1", f0)
	var att: float = maxf(0.0005, JU.f(recipe, "attack", 0.005))
	var dec: float = maxf(0.001, JU.f(recipe, "decay", length_s))
	var noise_mix: float = JU.f(recipe, "noise", 0.0)
	var trem: float = JU.f(recipe, "tremolo", 0.0)
	var vol: float = JU.f(recipe, "vol", 0.6)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / float(rate)
		var k: float = t / maxf(length_s, 0.001)
		var f: float = lerpf(f0, f1, k)
		phase += TAU * f / float(rate)
		var v: float = 0.0
		match wave:
			"square":
				v = signf(sin(phase))
			"saw":
				v = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			"noise":
				v = rng.randf_range(-1.0, 1.0)
			_:
				v = sin(phase)
		if noise_mix > 0.0:
			v = lerpf(v, rng.randf_range(-1.0, 1.0), noise_mix)
		var env: float = minf(1.0, t / att) * exp(-maxf(0.0, t - att) / dec * 3.0)
		if trem > 0.0:
			env *= 0.6 + 0.4 * sin(TAU * trem * t)
		out[i] = clampf(v * env * vol, -1.0, 1.0)
	return out


static func to_wav(samples: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w: AudioStreamWAV = AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w
