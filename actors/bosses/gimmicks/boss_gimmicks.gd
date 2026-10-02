class_name BossGimmicks
extends RefCounted
## Per-boss gimmick scripts (spec §9.3 "Gimmick" lines), picked by the boss
## file's "gimmick" key. A gimmick listens to sim events and may take over a
## BossBrain step via on_step(brain) -> bool.


static func attach(brain: BossBrain) -> void:
	match JU.s(brain.boss, "gimmick"):
		"mirror_clones":
			brain.gimmick = BarkerGimmick.new(brain)
		"toll":
			brain.gimmick = TollGimmick.new(brain)
		"rhythm":
			brain.gimmick = BoomGimmick.new(brain)
		"decouple":
			brain.gimmick = ExpressGimmick.new(brain)
		"sauce":
			brain.gimmick = SauceGimmick.new(brain)
		"orbits":
			brain.gimmick = AtlasGimmick.new(brain)
		"tide":
			brain.gimmick = FerrymanGimmick.new(brain)
		"cannons":
			brain.gimmick = GeneralGimmick.new(brain)
		"heap":
			brain.gimmick = HeapGimmick.new(brain)
