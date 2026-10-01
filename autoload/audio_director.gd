extends Node
## Music layers, BeatClock and SFX (spec §13, §15.13).
## TODO(spec §13): BeatSequencer, layer crossfades and SfxSynth arrive in M13.

var music_layer: String = "explore"
var region: String = ""


func set_region(r: String) -> void:
	region = r


func set_layer(layer: String) -> void:
	music_layer = layer


func play_sfx(_id: String, _pos: Vector3 = Vector3.INF) -> void:
	pass
