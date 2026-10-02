class_name InputPrompts
extends RefCounted
## Prompt text with live bindings (spec §14 remapping, §3.3 tutorial).
## Text carries `{action}` tokens (`{interact}`, `{dodge}`...) that resolve to
## the player's current key or button for the last-used device, e.g.
## "press {interact}" -> "press [R]" on keyboard, "press [RT]" on a pad.
## Two composite tokens: `{move}` (WASD / Left Stick) and `{camera}`.

## Readable names for the Controls menu and prompts.
const NAMES: Dictionary = {
	"move_forward": "Move forward", "move_back": "Move back", "move_left": "Move left", "move_right": "Move right",
	"light": "Light strike", "heavy": "Heavy strike", "dodge": "Dodge / Sprint / Crossover", "jump": "Jump",
	"shoot": "Shoot", "hands_up": "Hands Up (guard / strip)", "bag_move": "Bag Move", "interact": "Interact",
	"taunt": "Taunt", "quarter_water": "Quarter Water (heal)", "swap_ball_left": "Swap ball left",
	"swap_ball_right": "Swap ball right", "lock_on": "Lock on", "target_next": "Next target",
	"target_prev": "Previous target", "map": "Map", "menu": "Pause menu",
}

## What each action does (Controls menu detail line).
const HELP: Dictionary = {
	"move_forward": "Walk and run.", "move_back": "Walk and run.", "move_left": "Walk and run.", "move_right": "Walk and run.",
	"light": "Dribble strike. Tap near an opponent; chain for a combo.",
	"heavy": "Heavy strike: Tomahawk, Dunk on a downed opponent.",
	"dodge": "Tap to dodge. With the ball, tap to crossover (or stepback when pulling away). Hold while moving to sprint. Tap just as a defender winds up for an Ankle-breaker.",
	"jump": "Jump.", "shoot": "Hold to raise the shot meter, release at the top.",
	"hands_up": "Guard. Press on the cue as an attack lands to Strip the ball.",
	"bag_move": "Use your equipped Bag Move.", "interact": "Talk, open doors, call next, ride the subway, rest at a bodega.",
	"taunt": "Taunt to build Hype.", "quarter_water": "Drink a Quarter Water to heal.",
	"swap_ball_left": "Cycle balls.", "swap_ball_right": "Cycle balls.", "lock_on": "Lock the camera onto an opponent.",
	"target_next": "Switch lock-on target.", "target_prev": "Switch lock-on target.",
	"map": "Open the district map.", "menu": "Pause: Settings, Controls, Skip tutorial.",
}

const MOVE: PackedStringArray = ["move_forward", "move_left", "move_back", "move_right"]


static func key(action: String, device: String = "") -> String:
	## The bound key/button name, falling back to the other device, then "unbound".
	var dev: String = device if device != "" else InputRouter.last_device
	var g: String = InputRouter.glyph(action, dev)
	if g == "":
		g = InputRouter.glyph(action, "pad" if dev == "keyboard" else "keyboard")
	return g if g != "" else "unbound"


static func move_keys(device: String = "") -> String:
	var dev: String = device if device != "" else InputRouter.last_device
	if dev == "pad":
		return "Left Stick"
	var keys: PackedStringArray = PackedStringArray()
	for a: String in MOVE:
		keys.append(InputRouter.glyph(a, "keyboard"))
	var compact: bool = true
	for k: String in keys:
		compact = compact and k.length() == 1
	return "".join(keys) if compact else "/".join(keys)


static func format(text: String, device: String = "") -> String:
	## Replace every {token} with its [binding]; unknown tokens are left alone.
	var dev: String = device if device != "" else InputRouter.last_device
	var out: String = text
	var start: int = out.find("{")
	while start >= 0:
		var stop: int = out.find("}", start)
		if stop < 0:
			break
		var token: String = out.substr(start + 1, stop - start - 1)
		var rep: String = ""
		if token == "move":
			rep = "[%s]" % move_keys(dev)
		elif token == "camera":
			rep = "[%s]" % ("Right Stick" if dev == "pad" else "Mouse")
		elif InputMap.has_action(token):
			rep = "[%s]" % key(token, dev)
		if rep == "":
			start = out.find("{", stop + 1)
			continue
		out = out.substr(0, start) + rep + out.substr(stop + 1)
		start = out.find("{", start + rep.length())
	return out


static func display_name(action: String) -> String:
	return str(NAMES.get(action, action.replace("_", " ").capitalize()))
