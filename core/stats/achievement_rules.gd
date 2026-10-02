class_name AchievementRules
extends Node
## Appendix B achievements. Counter/state-based ones are a pure function of
## GameState (`evaluate`); event-based ones listen on EventBus. Unlocks go
## through SteamService (no-op without Steam) and persist locally.

const BOSS_ACH: Dictionary = {"bx_boom": "ACH_CROWN_BRONX", "bk_toll": "ACH_CROWN_BROOKLYN", "qn_atlas": "ACH_CROWN_QUEENS",
	"si_heap": "ACH_CROWN_SI", "up_highrise": "ACH_CROWN_UPTOWN", "city_chainlink": "ACH_LM_CAGE", "city_suspension": "ACH_LM_BRIDGE",
	"city_primetime": "ACH_LM_CROSSROADS", "city_gator": "ACH_LM_UNDERGROUND", "city_gargoyle": "ACH_LM_SUMMIT",
	"opt_ratking": "ACH_RAT_KING", "opt_pops": "ACH_POPS"}
const KINGS: PackedStringArray = ["bx_boom", "bk_toll", "qn_atlas", "si_heap", "up_highrise"]


static func evaluate() -> PackedStringArray:
	## Achievements implied by the current run state (safe to call any time).
	var out: PackedStringArray = PackedStringArray()
	var c: Callable = func(k: String) -> int: return GameState.counter(k)
	if int(c.call("boss_buckets")) >= 1:
		out.append("ACH_FIRST_BUCKET")
	if int(c.call("ankle_breakers")) >= 100:
		out.append("ACH_ANKLES_100")
	if int(c.call("posters")) >= 1:
		out.append("ACH_POSTER")
	if int(c.call("perfects")) >= 50:
		out.append("ACH_SPLASH_50")
	if int(c.call("best_streak")) >= 5:
		out.append("ACH_MAKE_TAKE_5")
	for b: String in BOSS_ACH.keys():
		if GameState.defeated_bosses.has(b):
			out.append(str(BOSS_ACH[b]))
	if GameState.has_crown_pass():
		out.append("ACH_CROWN_PASS")
	if GameState.has_flag("ending_daybreak"):
		out.append("ACH_END_DAYBREAK")
	if GameState.has_flag("ending_overtime"):
		out.append("ACH_END_OVERTIME")
	if GameState.archetype == "nobody" and (GameState.has_flag("ending_daybreak") or GameState.has_flag("ending_overtime")):
		out.append("ACH_NOBODY")
	if GameState.tattoos.size() >= 7:
		out.append("ACH_FULL_INK")
	if int(c.call("grails")) >= 5:
		out.append("ACH_GRAILS")
	if GameState.has_flag("beat_challenger_deuce_1") and GameState.has_flag("beat_challenger_deuce_2") and GameState.has_flag("beat_challenger_deuce_3"):
		out.append("ACH_DEUCE")
	if GameState.has_flag("dry_king"):
		out.append("ACH_NO_WATER")
	if int(c.call("chains_recovered")) >= 10:
		out.append("ACH_RUN_BACK_10")
	var cats: PackedStringArray = WorldIndex.all_cats()
	var petted: int = 0
	for cat: String in cats:
		if GameState.has_flag("pet_" + cat.to_lower().replace(" ", "_")):
			petted += 1
	if cats.size() > 0 and petted >= cats.size():
		out.append("ACH_ALL_CATS")
	if int(c.call("bootlegs")) >= 10:
		out.append("ACH_BOOTLEG")
	if int(c.call("takeovers")) >= 25:
		out.append("ACH_TAKEOVER")
	if GameState.has_flag("tier5_king_first"):
		out.append("ACH_TIER5_FIRST")
	return out


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss)
	EventBus.takeover_started.connect(func() -> void: GameState.bump_counter("takeovers"); check())
	for sig: Signal in [EventBus.crown_awarded, EventBus.chain_recovered, EventBus.box_opened, EventBus.rested, EventBus.bucket_scored, EventBus.district_loaded]:
		sig.connect(func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void: check())


func _on_boss(id: String) -> void:
	if id in KINGS:
		var kings_before: int = 0
		for k: String in KINGS:
			if k != id and GameState.defeated_bosses.has(k):
				kings_before += 1
		var region: String = JU.s(DataDB.boss(id), "borough")
		if kings_before == 0 and TierManager.tier_of(region) >= 5:
			GameState.set_flag("tier5_king_first")
	check()


func check() -> void:
	for api: String in evaluate():
		if not SteamService.is_unlocked(api):
			EventBus.achievement_unlocked.emit(api)
