class_name BeatClock
extends RefCounted
## Minimal metronome on sim frames (spec §9.3 Grandmaster Boom, §15.13):
## 60 fps fixed step, 4/4 bars. M13's AudioDirector can slave to this.

const FPS: float = 60.0

var bpm: float = 92.0
var origin_frame: int = 0


func _init(beats_per_minute: float = 92.0, origin: int = 0) -> void:
	bpm = beats_per_minute
	origin_frame = origin


func frames_per_beat() -> float:
	return FPS * 60.0 / bpm


func beat_at(frame: int) -> float:
	## Beats elapsed since the origin (fractional).
	return float(frame - origin_frame) / frames_per_beat()


func beat_index(frame: int) -> int:
	return int(floor(beat_at(frame)))


func beat_in_bar(frame: int) -> int:
	## 1..4
	return posmod(beat_index(frame), 4) + 1


func nearest_beat_in_bar(frame: int) -> int:
	## 1..4 for the beat nearest this frame (frames sit a hair before beats).
	return posmod(int(round(beat_at(frame))), 4) + 1


func frames_to_next_beat(frame: int, offset_beats: float = 0.0) -> int:
	## Frames until the next (optionally offset, e.g. 0.5 = off-beat) beat.
	var b: float = beat_at(frame) - offset_beats
	var next_b: float = floor(b) + 1.0
	return int(round((next_b - b) * frames_per_beat())) % maxi(1, int(round(frames_per_beat())))


func is_beat_frame(frame: int) -> bool:
	return beat_index(frame) != beat_index(frame - 1)


func is_on_beat(frame: int, window_frames: int = 6) -> bool:
	var b: float = beat_at(frame)
	var off: float = (b - round(b)) * frames_per_beat()
	return absf(off) <= float(window_frames)


func set_bpm(new_bpm: float, frame: int) -> void:
	## Change tempo keeping the current beat count continuous.
	var b: float = beat_at(frame)
	bpm = new_bpm
	origin_frame = frame - int(round(b * frames_per_beat()))
