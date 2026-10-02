# Progress

| Milestone | Status | Date | What shipped | Known issues | Deferred |
| --- | --- | --- | --- | --- | --- |
| M0 — Scaffold & harness | DONE | 2026-10-01 | project.godot (Forward+, Jolt, 60 Hz, custom user dir, strict typing, full input map), folder layout, 12 typed autoload stubs, DataDB + DataValidator/DataSchemas, tiers/tuning/archetypes/balls/bag_moves data, GUT 9.7.1, verify.ps1/verify.sh (+ `--full` QA, render smoke, export check), QA runner, boot smoke, save system with atomic write + migration | — | Export dry run (templates not installed); fonts fetched with HUD work |
| M1 — Look & move | DONE | 2026-10-01 | Toon/outline/facade/wet-asphalt/neon/halftone/tilt-shift/night-sky shaders + occlusion cutaway; 9 environment presets (5 boroughs, City, Garden, dawn, interior); quality presets; CameraRig (explore + lock-on fit solver + shake/punch-in); puppet rig, CharacterBuilder (16 hair recipes), PoseLibrary (13 anims), PuppetAnimator (bob, lean, squash, look-at); SimWorld/Hooper locomotion (walk/run/sprint, Wind, dodge i-frames, jump, coyote, 8f buffer); movement_lab greybox street; light budget; PostFX | Lighting is dark/moody and needs a look pass once districts exist | Remapping UI (M13), controller glyph art (M13) |
| M2 — Ball & shooting | DONE | 2026-10-01 | ShotResolver (§7.6, 29 tests) + ShotContext/ShotWindows; BallSystem with HELD/PASS/SHOT/LOOSE/IN_NET/DEAD; procedural dribble view; chest pass ricochet (Pinkie multi-ricochet), baseball pass pierce, lob AoE; loose physics with rim/backboard; pickup; lost-ball safety (water/OOB/10 s) with spare ball; regulation hoops with verlet chain/nylon nets; crate hoops with Bucket Blast + 20 s cooldown glow + first-make tokens; Wire Kicks; shot meter UI with colorblind markers; sticker popups; court-lines shader; ball_lab + smoke; fonts | Shot outcome flights are scripted arcs (no spin physics) | Dunk + finisher (M3 with combat moves); damage from passes/lobs/blasts applied in M3 |
| M3 — Combat core | DONE | 2026-10-01 | Hit volumes, Hitbox, CombatSystem, DamageService pipeline, CombatSim harness; every §7.4–7.5 move (strike chain, Euro Step, Tomahawk, Dunk, Dunk Finisher, Shove, Reach-in, Hands Up/Guard, Rejection, Hustle Dive, passes/lob); Ankle Breaker/Strip/Deflect/Read/guard break/unblockables; Composure SHOOK/STAGGER with tier durations; Hype + decay; Takeover; Taunt; Quarter Water; Bag Move framework (Snatchback, Spin Cycle, Hesi); status effects; MoveRunner + move primitives library; training dummy; HUD; hitstop/shake/slow-mo; death → COOKED → chain → respawn → reclaim; body separation; combat_lab + smoke; 44 new tests | Combat feel needs hands-on tuning (§17.5 checkpoint) | 13 Bag Moves (M7); Midnight player-SHOOK (M12) |
| M4 — Enemies | TODO | | | | |
| M5 — Boss framework + Stoop Queen | TODO | | | | |
| M6 — World builder & exploration | TODO | | | | |
| M7 — RPG systems | TODO | | | | |
| M8 — Brooklyn vertical slice | TODO | | | | |
| M9a — The Bronx | TODO | | | | |
| M9b — Queens | TODO | | | | |
| M9c — Staten Island | TODO | | | | |
| M9d — Uptown | TODO | | | | |
| M10 — The connected city | TODO | | | | |
| M11 — The City | TODO | | | | |
| M12 — The Garden & endings | TODO | | | | |
| M13 — Audio & juice | TODO | | | | |
| M14 — Steam & release candidate | TODO | | | | |
