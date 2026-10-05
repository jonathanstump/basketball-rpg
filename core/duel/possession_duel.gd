class_name PossessionDuel
extends RefCounted
## Half-court 1-on-1 possession rules (spec §7.10, §15.8) as an explicit
## transition table. Pure: no scene references. Callers feed it facts
## ("player_made", "loose_picked"...); it changes state and appends events
## that the DuelController turns into damage, ball moves and banners.

const CHECK: String = "CHECK"
const PLAYER_OFFENSE: String = "PLAYER_OFFENSE"
const LOOSE_BALL: String = "LOOSE_BALL"
const BOSS_OFFENSE: String = "BOSS_OFFENSE"
const PHASE_TRANSITION: String = "PHASE_TRANSITION"
const GAME_POINT: String = "GAME_POINT"
const VICTORY: String = "VICTORY"
const DEFEAT: String = "DEFEAT"

## state -> input -> next state ("" = stay). Inputs not listed are ignored.
const TABLE: Dictionary = {
	CHECK: {"check_done": PLAYER_OFFENSE, "player_died": DEFEAT},
	PLAYER_OFFENSE: {"player_made": CHECK, "player_missed": LOOSE_BALL, "player_rejected": BOSS_OFFENSE,
		"pass_hit": "", "pass_missed": LOOSE_BALL, "boss_stole": LOOSE_BALL, "boss_took": BOSS_OFFENSE,
		"out_of_bounds": CHECK, "phase_down": PHASE_TRANSITION, "boss_down": GAME_POINT, "player_died": DEFEAT,
		"player_turnover": LOOSE_BALL},
	LOOSE_BALL: {"player_picked": PLAYER_OFFENSE, "boss_picked": BOSS_OFFENSE, "out_of_bounds": CHECK,
		"phase_down": PHASE_TRANSITION, "boss_down": GAME_POINT, "player_died": DEFEAT},
	BOSS_OFFENSE: {"player_stripped": LOOSE_BALL, "statement_landed": CHECK, "statement_rejected": LOOSE_BALL,
		"boss_threw": LOOSE_BALL, "out_of_bounds": CHECK, "player_picked": PLAYER_OFFENSE,
		"boss_made": CHECK, "boss_missed": LOOSE_BALL, "boss_blocked": LOOSE_BALL, "boss_coughed": LOOSE_BALL,
		"phase_down": PHASE_TRANSITION, "boss_down": GAME_POINT, "player_died": DEFEAT},
	PHASE_TRANSITION: {"transition_done": CHECK, "player_died": DEFEAT},
	GAME_POINT: {"player_made": VICTORY, "player_missed": "", "player_died": DEFEAT},
	VICTORY: {},
	DEFEAT: {},
}

var state: String = CHECK
var phase: int = 1
var player_cleared: bool = true
var boss_cleared: bool = true
var lock_in_stacks: int = 0
var events: Array[Dictionary] = []
var timer_s: float = 0.0
var boss_ball_s: float = 0.0
var cfg: Dictionary = {}


func _init() -> void:
	cfg = JU.dict(DataDB.tuning("bosses"), "duel")


func start() -> void:
	phase = 1
	lock_in_stacks = 0
	_enter(CHECK, "start")


func can(input: String) -> bool:
	return JU.dict(TABLE, state).has(input)


func feed(input: String, data: Dictionary = {}) -> bool:
	## Applies an input; returns true if it was valid in the current state.
	if not can(input):
		return false
	var next: String = str(JU.dict(TABLE, state)[input])
	_side_effects(input, data)
	if next != "" and next != state:
		_enter(next, input)
	elif next == "" and input == "player_missed" and state == GAME_POINT:
		_emit("game_point_retry", {})
	return true


func _side_effects(input: String, data: Dictionary) -> void:
	match input:
		"player_made":
			var counts: bool = player_cleared or state == GAME_POINT
			if counts:
				_emit("bucket", data)
				lock_in_stacks = mini(lock_in_stacks + 1, int(round(JU.f(cfg, "lock_in_cap", 0.3) / JU.f(cfg, "lock_in_per_make", 0.05))))
				_emit("boss_rattled", {"seconds": JU.f(cfg, "rattled_s", 1.0)})
			else:
				_emit("take_it_back", {})
		"player_rejected":
			_emit("rejected_punish", data)
			boss_cleared = false
		"boss_stole", "player_stripped", "statement_rejected", "boss_threw", "player_turnover", "boss_blocked", "boss_coughed":
			if input == "statement_rejected":
				_emit("boss_composure", {"amount": -JU.f(cfg, "rejection_composure", 40.0)})
			_emit("loose", {"bias": "boss" if input == "boss_stole" or input == "player_turnover" else "player"})
		"boss_made":
			## R7: a boss bucket costs the player Heart (then your ball).
			_emit("boss_bucket", {"kind": JU.s(data, "kind", "mid")})
		"boss_took":
			boss_cleared = false
		"player_picked":
			player_cleared = false
		"boss_picked":
			boss_cleared = false
		"statement_landed":
			## R7: the Statement Dunk is the boss's dunk: it scores on you
			## (it used to heal the boss 8%), and its composure refills.
			_emit("boss_bucket", {"kind": "dunk"})
			_emit("boss_composure_refill", {})
		"out_of_bounds":
			_emit("out_on_them", {})


func _enter(next: String, cause: String) -> void:
	var prev: String = state
	state = next
	timer_s = 0.0
	boss_ball_s = 0.0
	match next:
		CHECK:
			player_cleared = true
			_emit("check", {"to": "player"})
		PLAYER_OFFENSE:
			if prev == CHECK:
				player_cleared = true
		BOSS_OFFENSE:
			boss_cleared = false
		PHASE_TRANSITION:
			phase += 1
			lock_in_stacks = 0
			_emit("phase_changed", {"phase": phase})
		GAME_POINT:
			player_cleared = true
			_emit("game_point", {})
		VICTORY:
			_emit("victory", {})
		DEFEAT:
			_emit("defeat", {})
	_emit("state", {"from": prev, "to": next, "cause": cause})


func tick(dt: float) -> void:
	timer_s += dt
	match state:
		CHECK:
			if timer_s >= JU.f(cfg, "check_s", 1.2):
				feed("check_done")
		PHASE_TRANSITION:
			if timer_s >= JU.f(cfg, "phase_transition_s", 3.0):
				feed("transition_done")
		BOSS_OFFENSE:
			boss_ball_s += dt
			if not boss_cleared and boss_ball_s >= JU.f(cfg, "boss_auto_clear_s", 2.0):
				boss_cleared = true
				_emit("boss_cleared", {})


func player_cleared_arc() -> void:
	if state == PLAYER_OFFENSE and not player_cleared:
		player_cleared = true
		_emit("cleared", {})


func contest_mult() -> float:
	return 1.0 + JU.f(cfg, "lock_in_per_make", 0.05) * float(lock_in_stacks)


func is_over() -> bool:
	return state == VICTORY or state == DEFEAT


func take_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events.duplicate()
	events.clear()
	return out


func _emit(type: String, data: Dictionary) -> void:
	var ev: Dictionary = data.duplicate()
	ev["type"] = type
	ev["state"] = state
	events.append(ev)
