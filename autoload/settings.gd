extends Node
## Options and accessibility (spec §14). Persisted to user://settings.cfg.

const PATH: String = "user://settings.cfg"

const DEFAULTS: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"screen_shake": 1.0,
	"reduce_flashes": false,
	"subtitles": true,
	"objective_marker": true,
	"ui_scale": 1.0,
	"colorblind": "off",
	"pass_aim_assist": true,
	"rookie_mode": false,
	"hold_to_guard": true,
	"hold_to_sprint": true,
	"camera_invert_y": false,
	"camera_sensitivity": 1.0,
	"quality": "high",
	"tilt_shift": true,
	"vsync": true,
	"fullscreen": false,
	"rumble": true,
	"remaps": {},
}

var values: Dictionary = {}
var persist: bool = true


func _ready() -> void:
	values = DEFAULTS.duplicate(true)
	var first_boot: bool = not FileAccess.file_exists(PATH)
	load_settings()
	if first_boot and is_steam_deck():
		## Deck preset auto-selected on Steam Deck (spec §16 M14, §15.17).
		values["quality"] = "deck"


static func is_steam_deck() -> bool:
	return OS.get_environment("SteamDeck") == "1"


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func get_bool(key: String) -> bool:
	return bool(get_value(key))


func get_float(key: String) -> float:
	return float(get_value(key))


func get_string(key: String) -> String:
	return str(get_value(key))


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	EventBus.settings_changed.emit()
	if persist:
		save_settings()


func reset_defaults() -> void:
	values = DEFAULTS.duplicate(true)
	EventBus.settings_changed.emit()


func save_settings(path: String = PATH) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	for k: Variant in values.keys():
		cfg.set_value("settings", str(k), values[k])
	return cfg.save(path)


func load_settings(path: String = PATH) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for k: Variant in DEFAULTS.keys():
		values[k] = cfg.get_value("settings", str(k), DEFAULTS[k])
	EventBus.settings_changed.emit()
