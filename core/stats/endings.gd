class_name Endings
extends RefCounted
## The two endings (spec §3.7). After Midnight's third phase the clock reads
## 11:59:59. Let it run -> "Daybreak": sunrise, credits, the overworld stays
## at dawn. Stop the clock -> "Overtime": take Midnight's crown, the night
## goes on, New Game+ starts immediately.

const TICKETS_NEEDED: int = 5


static func garden_open() -> bool:
	return GameState.garden_tickets.size() >= TICKETS_NEEDED


static func daybreak() -> void:
	GameState.set_flag("ending_daybreak")
	GameState.set_flag("dawn")
	GameState.bump_counter("endings")
	EventBus.achievement_unlocked.emit("ACH_END_DAYBREAK")


static func overtime() -> void:
	GameState.set_flag("ending_overtime")
	GameState.add_item("crown_midnight", 1)
	GameState.equipment["crown"] = "crown_midnight"
	GameState.bump_counter("endings")
	EventBus.achievement_unlocked.emit("ACH_END_OVERTIME")
	GameState.start_ng_plus()


static func ng_plus_after_daybreak() -> void:
	## "Run It Back+" from the credits of Daybreak: dawn stays, night returns.
	GameState.flags.erase("dawn")
	GameState.start_ng_plus()
