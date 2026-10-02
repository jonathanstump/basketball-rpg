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
	_load_local()
	var rules: AchievementRules = AchievementRules.new()
	rules.name = "AchievementRules"
	add_child(rules)
	EventBus.district_loaded.connect(_presence_for_district)


func _process(_delta: float) -> void:
	if available and _steam != null:
		_steam.call("run_callbacks")


func is_available() -> bool:
	return available


func unlock(api_name: String) -> void:
	if unlocked.has(api_name):
		return
	unlocked[api_name] = true
	_save_local()
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


const LOCAL_PATH: String = "user://achievements.json"


func _load_local() -> void:
	## Local mirror so achievements survive runs without Steam (tests use their own copy).
	if OS.get_cmdline_args().has("res://addons/gut/gut_cmdln.gd"):
		return
	var d: Variant = JU.load_json(LOCAL_PATH)
	if d is Dictionary:
		for k: Variant in (d as Dictionary).keys():
			unlocked[str(k)] = true


func _save_local() -> void:
	if OS.get_cmdline_args().has("res://addons/gut/gut_cmdln.gd"):
		return
	var f: FileAccess = FileAccess.open(LOCAL_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(unlocked))


func _presence_for_district(district_id: String) -> void:
	## Rich presence (spec §15.18): "Running it back in Brooklyn - Tier 3".
	var b: String = WorldIndex.district_borough(district_id)
	var nm: String = JU.s(DataDB.item("boroughs", b), "name", "The City" if b == "city" else b.capitalize())
	set_presence("steam_display", "Running it back in %s - Tier %d" % [nm, TierManager.tier_of(b)])
