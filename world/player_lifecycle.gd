class_name PlayerLifecycle
extends Node
## Death -> "COOKED" -> chain drop -> respawn -> "Run it back" (spec §5.4).
## Owned by GameWorld. The chain drops where you died unless the scene sets
## `chain_drop_override` (boss arenas: just outside the gate).

signal respawned()

var game: GameWorld
var chain_views: Array[ChainView] = []
var chain_drop_override: Vector3 = Vector3.INF
var respawn_point: Vector3 = Vector3.ZERO
var dying: bool = false


func _init(g: GameWorld) -> void:
	game = g
	name = "PlayerLifecycle"


func _ready() -> void:
	refresh_chain_views()


func on_player_killed() -> void:
	if dying:
		return
	dying = true
	var p: SimActor = game.player
	var drop: Vector3 = p.pos if chain_drop_override == Vector3.INF else chain_drop_override
	var nine: bool = GameState.tattoos.has("tattoo_nine_lives")
	var lost: int = GameState.rep
	var kept: int = ChainRules.recoverable(lost)
	GameState.chains = ChainRules.on_death(GameState.chains, kept, district_id(), drop, nine)
	GameState.rep = 0
	if lost > 0:
		EventBus.popup_text.emit("-%d REP  (%d ON YOUR CHAIN)" % [lost, kept], p.pos, "bad")
	EventBus.rep_changed.emit(0)
	EventBus.player_cooked.emit()
	EventBus.chain_dropped.emit(drop, ChainRules.total_rep(GameState.chains))
	AudioDirector.play_sfx("cooked")
	var screen: CookedScreen = CookedScreen.new()
	screen.finished.connect(_respawn)
	game.add_child(screen)


func district_id() -> String:
	return GameState.current_district if GameState.current_district != "" else String(game.name)


func _respawn() -> void:
	game.respawn_player(respawn_point)
	dying = false
	refresh_chain_views()
	respawned.emit()


func refresh_chain_views() -> void:
	for v: ChainView in chain_views:
		v.queue_free()
	chain_views.clear()
	var d: String = district_id()
	for c: Variant in GameState.chains:
		var ch: Dictionary = c
		if str(ch.get("district", "")) == d:
			var v2: ChainView = ChainView.create(JU.vec3(ch.get("pos")), int(ch.get("rep", 0)))
			game.add_child(v2)
			chain_views.append(v2)


func physics_check() -> void:
	## Touching a chain reclaims its Rep.
	if dying or game.player == null or not game.player.alive or chain_views.is_empty():
		return
	var res: Dictionary = ChainRules.touch(GameState.chains, district_id(), game.player.pos)
	var gained: int = int(res["rep"])
	if gained <= 0:
		return
	GameState.chains = res["chains"]
	GameState.add_rep(gained)
	GameState.bump_counter("chains_recovered")
	EventBus.chain_recovered.emit(gained)
	EventBus.popup_text.emit("RAN IT BACK +%d" % gained, game.player.pos, "tokens")
	refresh_chain_views()
