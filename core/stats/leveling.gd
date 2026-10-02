class_name Leveling
extends RefCounted
## "Train" at bodegas (spec §5.7, §11.3): each level = +1 to one stat.
## Rep to next level = floor(100 × L^1.5 + 150).


static func cost(level: int) -> int:
	var c: Dictionary = JU.dict(DataDB.tuning("economy"), "level_curve")
	return int(floor(JU.f(c, "a", 100.0) * pow(float(level), JU.f(c, "exp", 1.5)) + JU.f(c, "c", 150.0)))


static func can_train() -> bool:
	return GameState.rep >= cost(GameState.level)


static func train(stat: String) -> bool:
	if not DataSchemas.STATS.has(stat) or not can_train():
		return false
	GameState.add_rep(-cost(GameState.level))
	GameState.stats[stat] = GameState.stat(stat) + 1
	GameState.level += 1
	EventBus.leveled_up.emit(stat, GameState.level)
	return true
