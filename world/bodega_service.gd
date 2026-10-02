class_name BodegaService
extends RefCounted
## Bodega checkpoint rules (spec §5.2): petting the cat rests — refill
## Quarter Waters, full Heart, respawn commons (on next district load),
## autosave, set the respawn point, reveal the map within 80 m.


static func rest(bodega_id: String) -> void:
	if Questlines.maybe_start_lost_cat(bodega_id):
		var lc: Dictionary = Questlines.lost_cat()
		EventBus.dialogue_requested.emit("Bodega owner", PackedStringArray(["Have you seen %s? Gone since last night." % JU.s(lc, "cat"), "Somebody said they heard meowing over in %s. In an alley." % WorldIndex.district_name(JU.s(lc, "district"))]))
	GameState.quarter_waters = GameState.quarter_water_max
	GameState.flags["hp_ratio"] = 1.0
	GameState.respawn_bodega = bodega_id
	GameState.flags["rose_ready"] = GameState.tattoos.has("tattoo_rose")
	var info: Dictionary = WorldIndex.bodega(bodega_id)
	var cat: String = JU.s(info, "cat")
	if cat != "":
		GameState.set_flag("pet_" + cat.to_lower().replace(" ", "_"))
	var district: String = JU.s(info, "district", GameState.current_district)
	var door: Variant = GameState.flags.get("bodega_door_" + bodega_id, null)
	var m: MapData = MapParser.load_map(district) if district != "" else null
	if m != null and door is Array:
		var mask: PackedByteArray = MapReveal.ensure(district, m.width, m.height)
		var dp: Array = door
		MapReveal.reveal(mask, m.width, m.height, Vector2i(int(dp[0]), int(dp[1])), MapReveal.radius_tiles(MapReveal.REST_RADIUS_M))
	AudioDirector.play_sfx("cat_purr")
	EventBus.rested.emit(bodega_id)
	SaveSystem.request_autosave()


static func punch_card_trade() -> bool:
	## Punch Card -> +1 Quarter Water charge (max 10).
	var cap: int = JU.i(JU.dict(DataDB.tuning("player"), "quarter_water"), "max_charges", 10)
	if GameState.item_count("punch_card") <= 0 or GameState.quarter_water_max >= cap:
		return false
	GameState.add_item("punch_card", -1)
	GameState.quarter_water_max += 1
	GameState.quarter_waters = GameState.quarter_water_max
	return true
