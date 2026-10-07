class_name ShotContext
extends RefCounted
## Everything that affects a shot's timing windows (spec §7.6, §15.7).

var jumper: int = 10
var distance: float = 5.0
var zone: String = ""            # close | mid | three | deep ("" = derive from distance)
var contest: float = 0.0         # 0..1
var stepback: bool = false
var on_run: String = ""          # "" | "run" | "sprint": shooting on the move (revision 9)
var wide_open: bool = false      # boss SHOOK
var takeover: bool = false
var wind_ratio: float = 1.0      # current Wind / max
var wind_drift: float = 0.0      # center shift from gusts (Gargoyle), corrected by stick
var window_mult: float = 1.0     # gear/tattoo/ball multipliers (Mecca Ball, Clock tattoo...)
var perfect_bonus: float = 0.0   # flat perfect-width bonus (Strata Pro, Splash Band)
var rookie: bool = false


static func make(jumper_v: int, distance_v: float, contest_v: float = 0.0) -> ShotContext:
	var c: ShotContext = ShotContext.new()
	c.jumper = jumper_v
	c.distance = distance_v
	c.contest = contest_v
	return c
