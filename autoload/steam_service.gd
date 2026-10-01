extends Node
## GodotSteam wrapper (spec §15.18). Every Steam call goes through here and
## no-ops cleanly when Steam or the GDExtension is absent.

var available: bool = false
var unlocked: Dictionary = {}       # api_name -> true (mirrors Steam locally)
var rich_presence: Dictionary = {}
var _steam: Object = null


func _ready() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		var res: Variant = _steam.call("steamInitEx", false)
		available = res is Dictionary and int((res as Dictionary).get("status", 1)) == 0
	EventBus.achievement_unlocked.connect(unlock)


func _process(_delta: float) -> void:
	if available and _steam != null:
		_steam.call("run_callbacks")


func is_available() -> bool:
	return available


func unlock(api_name: String) -> void:
	if unlocked.has(api_name):
		return
	unlocked[api_name] = true
	if available and _steam != null:
		_steam.call("setAchievement", api_name)
		_steam.call("storeStats")


func is_unlocked(api_name: String) -> bool:
	return unlocked.has(api_name)


func set_presence(key: String, value: String) -> void:
	rich_presence[key] = value
	if available and _steam != null:
		_steam.call("setRichPresence", key, value)


func is_on_steam_deck() -> bool:
	if available and _steam != null:
		return bool(_steam.call("isSteamRunningOnSteamDeck"))
	return OS.get_environment("SteamDeck") == "1"
