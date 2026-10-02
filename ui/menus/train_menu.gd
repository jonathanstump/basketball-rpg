class_name TrainMenu
extends RefCounted
## Bodega "Train" (spec §5.7, §11.3): spend Rep to raise one stat by 1.

const BLURB: Dictionary = {
	"heart": "Max Heart.", "wind": "Max Wind; sprint efficiency.", "body": "Poise, damage reduction, slam damage.",
	"handles": "Dribble damage, ankle-breaker window, ball security, Bag Move power.",
	"bounce": "Jump height, dunk range, dunk/aerial damage.", "jumper": "Shot windows, shot damage, deep range.",
	"hands": "Parry/strip window, steals, rejection timing.",
}


static func open(it: GameWorld) -> void:
	var cost: int = Leveling.cost(GameState.level)
	var opts: Array[Dictionary] = []
	for s: String in DataSchemas.STATS:
		opts.append({"id": s, "label": "%s  %d" % [s.to_upper(), GameState.stat(s)], "detail": str(BLURB[s]) + "\nNext level costs %d Rep (you have %d)." % [cost, GameState.rep], "enabled": GameState.rep >= cost})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(it, "TRAIN  -  LEVEL %d" % GameState.level, opts, func(id: String) -> void:
		if id == "_back":
			if it is Interior:
				(it as Interior).counter_menu()
			else:
				it.close_menu()
			return
		if Leveling.train(id):
			EventBus.popup_text.emit("%s UP" % id.to_upper(), it.player.pos, "style")
			PlayerBuild.apply(it.player, it.player_hooper)
			SaveSystem.request_autosave()
		open(it))
