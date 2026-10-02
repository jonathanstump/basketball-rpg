class_name NicknameRules
extends RefCounted
## Earned nickname (spec §6.2): after the first Crown, Mic Check names you by
## your most-used style. Ties go to the earlier entry in STYLES.

const STYLES: Array = [
	["ankle_breakers", "Ankle Taker"],
	["posters", "Poster Child"],
	["threes", "Long Range"],
	["strips", "Pickpocket"],
	["taunts", "All Mouth"],
]
const FALLBACK: String = "Next Up"


static func pick(counters: Dictionary) -> String:
	var best: String = FALLBACK
	var best_n: int = 0
	for s: Variant in STYLES:
		var pair: Array = s
		var n: int = int(counters.get(str(pair[0]), 0))
		if n > best_n:
			best_n = n
			best = str(pair[1])
	return best


static func award_if_first_crown() -> String:
	## Called when a Crown is awarded; names you once.
	if GameState.nickname != "" or GameState.crowns.size() < 1:
		return ""
	GameState.nickname = pick(GameState.counters)
	return GameState.nickname


static func display_name() -> String:
	var n: String = str(GameState.profile.get("name", "You"))
	if GameState.nickname != "":
		return "%s \"%s\"" % [n, GameState.nickname]
	return n
