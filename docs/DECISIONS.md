# Decisions log

Format: date · decision · reason. Spec rule §0.1: when the spec is silent, pick the simplest option that keeps the pillars intact.

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-10-01 | Godot **4.7.2.stable.official.ed1daf0bf**, console binary at `C:/Users/jonat/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe` (the `.exe` name is a folder holding both binaries). | §15.1 asks to record version + path; console build shows logs. |
| 2026-10-01 | Project root is the repo root (`basketball-rpg/`), not a `concrete-crown/` subfolder. | The spec file already lives at `docs/` of this repo; layout §15.2 is otherwise followed. |
| 2026-10-01 | Test framework: **GUT 9.7.1** (MIT) vendored in `addons/gut`. Works on Godot 4.7.2. | §15.1; fetched over the network, so the mini_test fallback is not needed. |
| 2026-10-01 | `debug/gdscript/warnings/untyped_declaration = error`; addons excluded. Other warnings stay at defaults. | §15.1 strict typing; unsafe-access warnings would make JSON handling noisy without adding safety. |
| 2026-10-01 | Input bindings live in `data/input_map.json`; `InputRouter` builds the InputMap at boot (plus Settings remaps) and `tools/gen_input_map.gd` mirrors them into `project.godot`. | One source of truth for §7.2 and remapping (§14). |
| 2026-10-01 | Added `core/data/` (`JU` typed JSON accessors, `DataValidator`, `DataSchemas`). | §15.4 validation needs a schema registry shared by DataDB and `tools/validate_data.gd`. |
| 2026-10-01 | Move data may be one file per move (`data/moves/<owner>/<move>.json`, as in §15.4) **or** a bundle per owner (`data/moves/<owner>.json` with a `moves` array). DataDB indexes both into `moves_by_owner`. | ~170 boss moves; bundles keep authoring manageable while honoring the example format. |
| 2026-10-01 | Smoke scenes must print `SMOKE OK <name>` (verify fails if missing) and run with `--fixed-fps 60` in addition to `--quit-after 900`. | A positive signal catches silent early exits; fixed fps makes headless runs fast and deterministic. |
| 2026-10-01 | QA scripts are `tests/qa/qa_<id>.gd` (extend `QAScript`); `DebugConsole` starts `tools/qa_runner.gd` when `--qa-run=<id>` is on the command line. | §15.15 runner contract with no extra autoload. |
| 2026-10-01 | NG+ `mult_per_cycle` (×1.3) scales hp, damage, composure, rep and tokens, not shop prices or AI cooldown. | §4.3 says "multiplies everything"; scaling prices too would cancel the reward scaling. |
| 2026-10-01 | Stat scaling for §7.12: `scaling(stat, grade) = grade_mult × stat_factor(stat)`, stat_factor = 0.05/pt to 20, 0.025/pt to 40, 0.0125/pt to 60, 0.005/pt after (soft caps 20/40/60). A ball with no grade in the move's stat contributes 0. | Spec gives grades and soft caps but no curve. |
| 2026-10-01 | Dev window override 1280×720 (viewport stays 1920×1080, `canvas_items`/`expand`). | Fits a laptop screen; render smoke screenshots are 1280×720. |
| 2026-10-01 | Export templates are not installed on this machine; verify `--full` prints a warning and skips the export dry run until they are. | §15.16 allows the skip; revisit in M14. |
| 2026-10-01 | Gameplay is a pure fixed-step simulation (`SimWorld`/`SimActor`, 60 Hz, RefCounted) with Node3D views (`ActorView`) that interpolate between ticks. Collision is a 2.5D block model (`WorldCollision`: XZ rects with top heights; low tops are walkable platforms, tall ones are walls). | Frame-exact tests, headless QA bots and boss sims (§15.5 CombatSim); Godot physics bodies can't be stepped synchronously. Jolt stays the engine physics for any rigid bodies. |
| 2026-10-01 | Occlusion cutaway uses a screen-door dither in the shaders driven by a `cc_focus_pos` global shader parameter (cylinder around the camera-to-player line), shipped as `occlusion_dither.gdshaderinc` included by toon/outline/facade shaders. | Works for MultiMesh batches with no per-object raycast state; §15.12 intent preserved. |
| 2026-10-01 | Dodge fires on press (crossover with the ball, slide without; stepback when pulling away from facing); keeping the button held after the dodge becomes sprint. | Spec says "tap = dodge, hold = sprint" but parry timing needs zero-latency dodges. |
| 2026-10-01 | Shared toon lighting lives in `toon_light.gdshaderinc`; region rim color is the `cc_rim_tint` shader global set per region. | One lighting model across toon, facade and character materials. |
| 2026-10-01 | Hair styles (all 16) are data recipes in `data/hair_styles.json`; CharacterBuilder composes them from primitives. | §15.11 "each style is a recipe" kept as data (D5). |
| 2026-10-01 | Quality presets live in `data/tuning/quality.json` (low/deck/high/ultra): SSR, volumetric fog, glow, shadow atlas sizes, MSAA, 3D scale, tilt-shift, shadowed-light cap. | §15.1/§15.17 presets as data. |
| 2026-10-01 | `SimWorld.dispose()` breaks actor/controller reference cycles; `GameWorld._exit_tree` calls it, and `AssetRegistry._exit_tree` clears static material/mesh/pose caches. | Clean engine shutdown (no "resources still in use" errors in smoke runs). |
