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
| 2026-10-01 | Shot windows: widths are full widths centered on 0.82; flat gear bonuses (Strata Pro, Splash Band) add to all three widths after multipliers; good/near are clamped to stay nested (near >= good >= perfect). Jumper below 10 shrinks perfect by 0.0015/pt. | §7.6 is silent on these edges. |
| 2026-10-01 | Shot contest = clamp((1 - d / contest_radius) × 1.25 × facing_term), facing_term = clamp(dot(defender_forward, to_shooter) + 0.3). Smothered (>= 0.85) needs the defender within ~30% of their radius and facing you. | §7.6 names inputs (distance vs radius, facing) without a curve. |
| 2026-10-01 | Ball runtime is simulated in `BallSystem` (no RigidBody3D): LOOSE uses deterministic gravity/bounce 0.78/friction with torus-rim and backboard collisions. Loose-ball gravity is 14 m/s² (floatier than actors' 24). | Determinism and headless tests (see sim decision); §15.6 behaviors kept. |
| 2026-10-01 | In the street a made shot returns the ball to the shooter after it drops through the net (`return_on_make`); boss duels override this with CHECK rules (M5). Out-of-combat crate makes pay 25 × tier tokens once per crate. "In combat" = a hostile enemy/boss within 20 m. | Keeps street play flowing; §5.5/§7.9. |
| 2026-10-01 | Chest pass vs baseball pass: Y press starts the chest pass; if Y is still held at its 12f release frame it becomes a charge, and releasing after >= 36f total hold throws the baseball pass (extra Wind charged then). Releasing earlier throws the chest pass. | §7.4 "Hold Y >= 36f" with no tap latency. |
| 2026-10-01 | Pass targeting: lock-on target, else aim assist (25° cone, includes Wire Kicks overhead), else straight ahead. Settings `pass_aim_assist` disables the cone for the player. | §14 pass aim assist; Wire Kicks are 6 m up. |
| 2026-10-01 | Fonts fetched from the Google Fonts repo: Bungee (OFL), Permanent Marker (Apache 2.0), Inter variable (OFL) in `ui/fonts`, licenses in `licenses/`. | §14 / §15.1. |
| 2026-10-01 | Hitboxes/hurtboxes are math volumes (`HitVolume`: arc, sphere, circle, ring, box) tested against vertical actor capsules by `CombatSystem` each frame, not Area3D nodes. | Same determinism argument as the sim; §15.5 semantics (active frames only, owner, move id, packet) preserved. |
| 2026-10-01 | Hit pipeline order: Ankle Breaker window -> i-frames (Read on slides) -> Rejection (airborne-ball hitboxes) -> parry (strip vs `ball` packets, deflect vs `body`) -> projectile reflect -> damage x DR -> guard (frontal, 25% chip, Wind = dmg x 0.8, break at 0 Wind) -> composure -> status -> events -> hitstop. Ankle Breakers trigger on any hit including unblockables (needed for Midnight's finale). | §15.5 list made concrete. |
| 2026-10-01 | Parry/strip/ankle composure bonuses scale linearly 1 + 0.02/pt above 10 in Hands/Handles (cap x2). Crit: 5% base x1.5 for hooper attacks; Dunk Finisher forces x3. | §7.4/§7.5 say "scaled by Handles/Hands" without a curve. |
| 2026-10-01 | Dribble chain: the next X starts after 4 recovery frames of the current strike if X was pressed (buffered); dodge cancels strike recovery after 6 frames. | Fluid chains with readable commitment; spec silent. |
| 2026-10-01 | Hands Up: window = 10f + Hands bonus (cap 16f) starting on frame 1; holding LB past the window becomes Guard; a successful parry cancels the 18f whiff recovery. Rejection = LB while airborne or LB+A together. | §7.5. |
| 2026-10-01 | Bodies are solid: `SimWorld.separate_bodies()` pushes overlapping actors apart by mass (bosses effectively immovable). | Lunges/euro steps must not pass through targets. |
| 2026-10-01 | Move data: `weight` is the AI pick weight (§15.4); hit heaviness is `hit_weight` (light/medium/heavy -> hitstop 3/5/8f). | Avoids a field clash. |
| 2026-10-01 | Death keeps a list of chains (`GameState.chains`); each death removes chains with no lives left and drops a new one for unspent Rep. Nine Lives gives a new chain one extra life. | §5.4 + Nine Lives tattoo with no ambiguity. |
| 2026-10-01 | HUD text uses Label nodes; `CanvasItem.draw_string` with the imported TTFs rendered solid blocks in this engine build. | Observed in render smoke; Labels render the fonts correctly. |
| 2026-10-01 | Bag Moves Snatchback, Spin Cycle and Hesi are implemented in M3; the other 13 emit `bag_move_unimplemented` until M7. | §16 M3 scope. |
| 2026-10-01 | Enemies are data (`data/enemies.json`, moves in `data/moves/enemies.json`) run by one `EnemyBrain` FSM + `MoveRunner`; archetype quirks are small hooks in `EnemyBehaviors` keyed by `behavior`. Uniques use values within ±20% of their closest archetype. | §8.3 "base values ≈ closest archetype ±20%"; D5 data-driven. |
| 2026-10-01 | Attack tokens: an engaged enemy requests a token first (unless recovering), then approaches and attacks; it releases the token after each move. Without a token it circles at 4-6 m. | §8.5; prevents melee-range enemies from circling forever. |
| 2026-10-01 | Tourists are neutral NPCs (team 0, kind `npc`): never attacked, their camera flash applies a 1 s `blind` status after a 0.4 s cue. Hype Man's boombox is a separate 2-hit prop actor that follows him; the aura (+25% speed/damage within 8 m) lasts while it stands. | §4.5, §8.1. |
| 2026-10-01 | Pickpocket escape (>30 m away while holding your ball) sets the `lost_and_found` flag and gives you a spare Rec Ball; the bodega lost & found pickup lands with bodegas in M6. Gulls snatch 5% of carried tokens and return them when killed. | §7.9, §8.2. |
| 2026-10-01 | QA bot = `ChallengerBrain` driving the player's Hooper (same code as Pickup Challengers). `enemy_lab_smoke` runs every type vs the bot for 60 simulated seconds headless (pure sim stepping), asserting engage, attack and being hit. | §16 M4 smoke without a 60 s wall-clock wait per type. |
| 2026-10-01 | `PossessionDuel` is a literal transition table (state -> input -> next); `DuelController` maps sim events to inputs and duel events to effects, so boss fights run headless in `BossSim`. | §15.8 "explicit transition table", testable per transition. |
| 2026-10-01 | A Statement Dunk that lands goes to CHECK with the player's ball (the explicit §7.10 rule), even though §7.10's closing note says bosses get the ball back on their own makes. | The explicit transition is unambiguous; the note reads as flavor. |
| 2026-10-01 | CHECK teleports the player to the top of the key (7.6 m out) with the ball and resets non-stationary bosses to the paint; the check counts as cleared. | §7.10 "checks you the ball at the top of the key". |
| 2026-10-01 | Rejected punish / blocked dunk = 18% of player max Heart × (1 + 0.1 per tier above 1), plus knockdown. | §7.6 says "tier-scaled" without a curve; full tier damage multipliers would make it lethal at T5+. |
| 2026-10-01 | Bosses keep 1 HP (`cannot_die`) so 0 Heart triggers GAME POINT; a permanent SHOOK break; any bucket ends it. | §7.10 GAME POINT. |
| 2026-10-01 | Bosses have permanent hyper armor (no flinch); composure breaks are their stagger. Boss look = data recipe (`look.joints` + `look.parts`) built by one `BossBuilder` and animated procedurally by `BossView`, instead of one builder script per boss. | D5 data-driven; 24 bosses share one code path. |
| 2026-10-01 | Ball-throwing boss moves (`uses_ball`) throw the real SimBall (the Stoop Queen's lob is the ball, which then lands loose); a matching delayed hitbox carries `tags.ball` so a Rejection steals it. | §9.3 Stoop Queen gimmick + §7.5 Rejection. |
| 2026-10-01 | Showboats are stripped with the Reach-in Swipe (guaranteed during the showboat, x2 strip composure); finishing one refills the boss's composure. | §7.10 showboat window. |
| 2026-10-01 | The arena gate is a collision block tagged `arena_gate` (closed on entry, opened on victory); on death the chain drops just outside the gate and the lab resets the fight from CHECK. | §9.1. |
| 2026-10-01 | Map binding extensions: `L`/`g` shortcuts bind (in that order) to sidecar `shortcuts` with `open_from` n/s/e/w; `^` tiles come in pairs (k, k+1) that link a rooftop route; `K`/`G`/`I` take ids from sidecar `shops`; `$` takes per-occurrence loot pools from `loot.$` (a list) and is locked when the pool id contains "locked". | §15.10 lists the letters but not these details. |
| 2026-10-01 | Navigation is an AStarGrid2D over walkable map tiles (closed shortcuts solid), baked on a WorkerThreadPool task during load; enemies steer straight when there's line of sight and follow the path otherwise. | §15.10 "nav bake on a thread"; the sim has no navmesh. |
| 2026-10-01 | Building blocks are split into front/back strips and then 2-3 tile lots facing the street with the most walkable frontage; all repeated meshes (buildings as scaled boxes with world-space window shading, curbs, props) go through one MeshBatcher -> one MultiMeshInstance3D per mesh+material. Bed-Stuy builds in well under 3 s with < 1,200 draw groups. | §15.10, §15.17. |
| 2026-10-01 | Interiors are one `Interior` scene parameterized by kind (bodega/plug/pump_grip/ink_needle); the bodega counter offers Train/Travel/Stash/Swap Bag Move/Shop/Punch Card/Lost & Found. Train, Stash and shop stock are stubs until M7. | §4.6, §5.2; M6 lists "Train stub". |
| 2026-10-01 | Scene changes go through `SceneRouter` with a one-shot params dictionary; fast travel and crossings show the subway-car ride while the destination preloads on a thread; doors and court gates switch directly. Player Heart carries between scenes as `GameState.flags.hp_ratio` (rest resets it). | §5.3 "the loading screen is the ride". |
| 2026-10-01 | Exploration camera picks its initial yaw automatically (fewest walls between camera and player) on arrival. | Arrivals next to buildings otherwise opened on a dithered wall. |
| 2026-10-01 | Courts on district maps are fenced until their boss is beaten (gate `M`/`X` loads the boss arena); afterwards the fence/collision is gone and the court hoop is live for free practice. | §9.1 re-entry. |

## M7 — Level curve L60 value
Spec §11.3 lists L60 = 46,626 but `floor(100 × 60^1.5 + 150)` = 46,625 (every other row in the table is floored). The formula wins; the test asserts 46,625.

## M8 — Brooklyn vertical slice
- **Start boroughs before M9.** All five start boroughs appear in the creator with their tier maps, but a borough whose start district map is not authored yet shows "(closed tonight)" and can't be picked. `FrontEndFlow.start_district` falls back to Bed-Stuy.
- **Barker T5 "Hall of Mirrors"** is implemented as a wide projectile fan (6 rings) instead of true mirror-wall ricochets of both players' passes. TODO(spec §9.3): ricochet off the arena mirror walls once the ball system supports wall bounces.
- **Barker phase 2 "Tilt"** slides the player and loose balls for 4 s every 15 s instead of physically rotating the floor panels. The coaster cars are a telegraphed lane of hazard circles.
- **The Toll's booth** holds exactly what Pay Up took. Stripping him while it glows (6 s) spills it all back, and anything left over is refunded when you win. Toll Gate is an axis-aligned 7 m wall between you and the hoop for 6 s.
- **Rush Hour headlights** sweep across X every 5 s, and the glare status cuts the shot window to 60%. Traffic drums are a rolling lane of hazards.
- **Bridge Collapse** is a full-area grid of falling debris with one safe column (new `safe_lane` pattern).
- **Pickup Challengers** play first to 7 (2s and 3s), make it take it. Dropping to 1 Heart loses the run instead of cooking you, and the clear rule is not enforced in pickup runs. Brooklyn has three (Sweet Pea and Wheels in Coney Island, Knots in DUMBO), one more than the "2 per borough" minimum.
- **Boss drop "Bag Move: X"** is a mixtape item that teaches the move on pickup (Toll → Toll Booth).
- **Earned nickname** uses style counters bumped by the presenter (ankle-breakers, posters, threes, strips, taunts). If none has been used, the fallback is "Next Up".
- **Bot defense.** The QA bot now goes for Rejections on Statement Dunks (Jump + Hands Up 7 frames before the dunk lands). Without it, the Kings out-healed the bot.
- **Placed loot.** Loot pools can list `extra` items that always drop. This is how the authored mixtapes, Punch Card, Sugar Rush and flash sheets sit in specific shoeboxes.
- **Profanity filter.** A short blocked-word list in data/creator.json. Words of 3 letters or fewer only match whole words, to avoid false positives like "Cassidy".

## M9a — The Bronx
- **BeatClock** (`core/audio/beat_clock.gd`) is a minimal 60 fps metronome built ahead of M13. Grandmaster Boom's gimmick owns his move picks: it picks a move, then starts it so the first active frame lands on the next beat (Breakbeat moves this to the off-beat). M13's audio will follow this clock.
- **ON BEAT** means a crossover, stepback, slide or dribble strike within ±6 frames of a beat, for +5 Hype.
- **Scratch** is one 150° line sweep with 2 hits instead of two separate back-and-forth sweeps. **Sample** is a generic lunge, not a literal copy of your last attack. TODO(spec §9.3): replay the player's last move data.
- **Speaker Stacks** are two destructible props (160 HP × tier) that pulse a ring timed to land on beats 2 and 4.
- **Shell Up** is a `shell` stance with `full_block`: frontal hits deal 0, guard never breaks, and turning drops to 25% so you can reach his flank. **Molt** uses generic phase rules (`speed_mult`, `damage_taken_mult`).
- **Generic boss hooks added:** phase rules `speed_mult`/`damage_taken_mult`/`damage_mult`/`statement_cd_mult`, move `repeat` and `curve_last` (Knuckle Rush, Stampede), `lateral` charges (Sidewinder), showboat `buff_mult` (Chest Pound +20% for 10 s), and reposition landing hitboxes (Fence Climb).
- **Arena dressing is data** (`arena.props` in the boss file: shapes, neon, repeats, lights). Market Hall, Zoo Fence and Block Party use it.
- **Duel safety.** DuelController clamps both actors inside the fence. A charge could push the player through the thin fence, and the bot then stalled at GAME POINT.
- **QA bot** now changes its shooting spot and attacks off the dribble when a defender keeps contesting it. Before this, Kings who guard the paint walled it forever.
- **The Sound Bridge** lands in Flushing Meadows (qn_flushing). It's the closest Queens district to the Bronx side.

## M9b — Queens
- **Express lanes.** `axis_snap` charges always run along the arena axes (the painted lanes). **Third Rail** is a one-shot electrified lane of hazard circles that shocks (roots) for 1 s, not a 4 s persistent lane.
- **Decouple.** Two rear cars break off at Phase 2 with shared HP: damage to a car comes off the Express. **Rush Hour Crowd** is 8 commuter blocks (collision only) for 12 s.
- **Sauce zones** use the zone primitive: white puddles slow, red puddles burn, both last 12 s. While burning, Wind drains 8/s. Being slowed and burning at once triggers "the combo", a burst of 8% max Heart every 2 s at most.
- **Atlas's orbits** are three rotating spokes (box hit volumes swept around him), not full circles: two low ones you jump and one high one you dodge under. They're unblockable and only exist while he's not SHOOK. Phase 2 drops the globe as a bouncing boulder hazard. **Eclipse** is presentation only. The globe shrinking and growing when stolen is skipped (flavor).
- **Shock** status now roots the player like `rooted`. **Gravity Well** uses a generic `pull_mps` move field.
- **Lock-on camera** frames tall targets by including their height and allowing a longer distance (8 m + 1.4 × height).
- **The River Tunnel** (Flushing → City) is locked behind the Crown Pass and targets `city_midtown`.

## M9c — Staten Island
- **Tide.** The deck tilts every 20 s (every 8 s after the T5 Storm) for 3.5 s. A wave pushes grounded players 3 m downhill. Going past the rail costs 20% Heart and puts you back on deck. **Undertow** pulls you toward the nearest rail for 1.5 s. **Fog Bank** is the Phase 2 lunge set; the fog visuals are presentation.
- **Cannons.** Four cannons on the ramparts. A Volley (or Siege) lights them for 2.5 s, and a pass that comes within 2.2 m of a lit cannon backfires on the General: 90 composure and 4% Heart.
- **Split bosses** share `BossSplit`: Express cars and the General's riderless horse, each with shared HP.
- **Armor** is a generic actor flag that soaks damage before Heart. The Heap starts with 10% of his Heart as armor, and Absorb adds 1.5%/s while active (a bucket or a heavy hit interrupts it). The boss bar shows it as a white bar.
- **Gull shot clock.** Holding the ball 6 s in PLAYER_OFFENSE (not counting a shot gather) knocks it loose toward the King. **Garbage truck** sweeps a lane every 25 s in Phase 2.
- **Timed summons** now leave when `duration_s` runs out (`despawn_frame`). **Fresh Load** minions last 20 s; the spec gives no duration.
- **Duel robustness:** possession is reconciled from who actually holds the ball. Bosses must put the ball up after holding it 10 s in BOSS_OFFENSE. The player gets 40 wake-up i-frames after a knockdown (tuning `wakeup_iframes`). The QA bot slips sideways when pinned.
- **Test fixture fix (not weakened):** `test_rejected_punish_damages_player` now takes the ball from the player before emitting `shot_rejected`, as a real Rejection does. Without that, the new possession reconciler correctly saw the player still holding the ball.

## M9d — Uptown
- **Applause meter** (−100 boos to +100 applause). Ankle-breakers, strips, rejections, posters and makes fill applause; getting hit and missing fill boos. Full boos trigger "Get Off The Stage!" (hook grab). Full applause gives roses and 3 s of SHOOK. **Spotlight Hunt:** a spotlight wanders the stage, and he takes 35% damage outside it. **Standing Ovation** walls in the stage edges. **Encore** repeats his previous move with 30% faster recovery.
- **Swarm.** A heavy hit disperses him for 2 s (ghost and untouchable). Throwing or passing exposes the core for 3 s: triple damage, and any hit breaks his composure. **Split Flock** is an 8 s decoy. **Takeoff** crumbles the roof edges (arena walls) and doubles Statement frequency.
- **Reach.** High Rise's contest radius is 6 m. The spec's "half the court" was tuned down from 8 m because the QA bot couldn't score through it. Reach drops while he's SHOOK or STAGGERED, and for 1.4 s after your stepback. **Elevation** adds telegraphed lightning every 7 s. **Downtown** is a T5 heavy lob. Self Oop has weight 1, a 20 s cooldown and a 4.5 m radius.
- **Zone hazards** (puddles, rain, fire jets) no longer flinch the player (`no_flinch`); they only chip and apply status. Before this, rain re-hits cancelled Rejections.
- **Boss offense weighting** (with the ball, favor lobs and showboats ×2, other moves ×0.6) doesn't apply to Statement Dunks. The boss hold clock prefers a lob over a Statement Dunk.
- **Default district start** is the `@` tile, falling back to the station. It used to be the map center, which can be inside a building.
- **High Rise is still the hardest bot matchup.** Some seeds time out at T3/T5. The test sim uses seed 2, which wins at every tier.
- **The General's Volley** is now weight 2 with a 14 s cooldown (was 8 s). Volley spam was crowding out the bot's shots at T5.

## M10 — The connected city
- **Questlines** live in `core/stats/questlines.gd` as pure rules over GameState.
  - **Pops** gives one lesson per Crown, in spec order (Self Oop, Euro Glide, Rainbow Lob, Bass Drop, Tunnel), from any bodega counter. After the fifth, he sets `pops_one_more_run` for the M12 superboss.
  - **Grail Hunt**: open 5 Grail boxes (the `grails` counter), then The Plug hands over Golden Hour once.
  - **Lost Cat** starts at the first rest after your first Crown. That bodega's cat hides in another district of the same borough, near its first one-way alley (or the station). Finding it gives the Nine Lives flash.
  - **Deuce** duel 1 unlocks after any mini-boss and duel 2 after three Crowns. Both use Pickup Challenger rules: first to 7, then first to 9; skill 0.8/0.9; +1/+2 tier. He appears by the station of whatever district you load. Duel 1 drops the Iso mixtape and duel 2 drops Deuce's Band. Losing keeps him around.
- **Pizza Rat King** (`opt_ratking`) sits behind a sewer grate in Bed-Stuy near the Cemetery Belt; that's the hidden tunnel between Brooklyn and Queens. A new `tier_regions` boss field sets his tier to the higher of the two. Eating a slice is a showboat that heals 6% if he finishes it, so strip it to deny the heal. Rat Swarm summons last 15 s.
- **Districts can declare "specials"** in the sidecar (authored interactables such as boss tunnels).
- **NG+** (`GameState.start_ng_plus`) keeps stats, levels, gear, tattoos, Bag Moves and quest rewards, and resets Crowns, Garden stubs, bosses, boxes, kills, shortcuts and chains. Tiers +2 (cap 7) and ×1.3 per cycle come from `tiers.json`. Tattoo slots never drop below the ink you already have.
- **City stations** will use the `city_` id prefix, which fast travel gates behind the Crown Pass.

## M11 — The City
- **The City** is two districts: Downtown (The Cage, The Bridge and The Underground landmarks; the old bridge to DUMBO; the ferry to St. George) and Midtown (The Crossroads and The Summit; the park gate to Harlem; the river tunnel to Flushing; the City shops). Cats: Broadway, Chairman, Penny, Lex. Stations `city_st_*` are Crown Pass gated. The Garden entrance arrives in M12.
- **Landmarks** are `kind: landmark` with king base stats at Tier 6, both phases, and no T5 event (spec: "City (T6): everything"). Each one grants a Garden Ticket stub (`garden_tickets`).
- **Chain Link:** the cage walls move in 1.5 m every 30 s (20 s in Phase 2), touching the fence shocks for 4% Heart, and stripping him triggers an immediate unblockable No Call.
- **Suspension:** a strike within 2 m of one of 4 anchors snaps its cable (60 composure). Phase 2 sways the deck every 12 s and adds plank collapses. TODO(spec §9.3): zip-line riding (needs an arena interact) is not implemented.
- **Prime Time:** records your last 5 moves (shown when he plays Replay or Highlight Reel). A tourist flash blinds you 0.5 s after a white flicker cue. In Phase 2, 3 channels rotate LIVE every 6 s and only the LIVE one takes damage.
- **The Gator:** a 30 s flood cycle with 12 s of high water (always high in Phase 2). Wading slows you, and every 8 s in high water the third rail sparks (8% Heart and a shock, unless you're on the dry edges) and he submerges to ambush.
- **The Gargoyle:** 3 s gusts every 10 s (6 s in Phase 2) push you and shift the shot window center by 0.12. Lightning in Phase 2. Gusts stop at CHECK and GAME POINT.
- **Bot/duel fixes:** the boss possession clock now counts while the boss is mid-move. The bot aims at the live window center (gusts move it mid-gather) and breaks out of corners after 1.5 s pinned. Coop King's Split Flock and zones were slowed and the Rat King's slice heal reduced, after a full regression sweep.
- **QA fights** use the boss's real tier and the validated sim seed.

## M12 — The Garden & endings
- **The Garden** is a court in Midtown that stays locked until you hold all five Garden Ticket stubs. Tier 7.
- **Midnight** has three phases, each with its own Heart bar (phase `refill` with `at_hp_pct: 0.002`), and GAME POINT only comes in Phase 3.
  - **Warm-Up:** dodging (crossover, stepback or slide) into his Midnight Crossover within 3.5 m sends the player to the `player_shook` reaction.
  - **Prime:** borrows the listed signature moves through `owner:move` refs. Orbit Spin needs Atlas's ring gimmick, so it's swapped for Meridian; Cage Shrink is likewise a Chain Link gimmick, so it's swapped for Fence Slam.
  - **Overtime:** a 60 s countdown, then the full-arena unblockable MIDNIGHT. If the hit resolves as an ankle-breaker or a dodge/read (a perfect crossover through it), his Heart drops, he goes SHOOK and you reach GAME POINT. A miss costs 90% max Heart and resets the clock to 30 s.
- **Deuce duel 3** appears in Midtown (the Garden tunnel) once duel 2 is won and the five stubs are held. It's Tier 6 and first to 11.
- **Pops in his prime** (`opt_pops`, Tier 6) waits as a special on your start district after the fifth Pops lesson.
- **Endings:** after Midnight a choice menu appears at 11:59:59.
  - **Daybreak:** the `ending_daybreak` and `dawn` flags are set. Credits roll over a sunrise, and the overworld uses the dawn environment preset from then on.
  - **Overtime:** `ending_overtime` is set, Midnight's Crown (key item) is given, NG+ starts, and the credits roll.
  - NG+ after Daybreak clears `dawn`.
- **Credits** list the open-license fonts and tools. In headless runs they skip straight to the end.

## M13 — Audio, juice & accessibility
- **Music** is placeholder procedural audio. `BeatSequencer` synthesizes kick, snare, hat, bass, lead and pad from 16-step region patterns (`data/audio/patterns.json`, one per borough plus city, garden, title and interior, each matching the spec's mood notes) into an `AudioStreamGenerator` at 22.05 kHz. Step k always starts at `round(k·step_len)`, so there is no accumulated drift: the measured worst case is 0.02 ms over 5 minutes against BeatClock. Layers: explore (drums + bass), combat (+ lead, when a crew is within 14 m), boss (+ pad); gains crossfade at 1.5/s. No samples of real songs. Replace with commissioned music before launch.
- **SFX** come from `SfxSynth`: sfxr-style recipes in `data/audio/sfx.json` rendered once to `AudioStreamWAV` at boot. That covers ball bounces per surface, chain ching, swish, rim clank, squeaks, crowd ooh, door bell, cat purr, hits, parry, strip, ankles, poster horn, telegraph and chimes. Ambience loops are rendered the same way per region.
- **Voices** are syllable blips while dialogue types (pitch per speaker). Mic Check routes through a `Megaphone` bus (band-pass + distortion). Buses: Music, SFX, Voice (follow the volume settings).
- **Headless runs** keep the sequencer clock (dry advance) but skip synthesis and playback.
- **Juice:** impact particles (CPUParticles3D bursts: stone chips on bosses, sparks on crews, feathers on birds), sprint speed lines in the HUD, and a white-flash pass for tourist cameras and lightning.
- **Accessibility:**
  - "Reduce flashes" drops tourist and lightning flashes to 0.12 alpha, removes the POSTER white flash and halves the halftone (`PostFX.flash_strength`).
  - Toggle-guard mode when "Hold to guard" is off.
  - Invert-Y drives a new vertical look offset (mouse and `cam_up`/`cam_down`).
  - Full remapping UI (Settings → Controls), stored in `remaps` in the input_map.json spec format. Keyboard and pad bindings are separate, and prompt glyphs follow the last-used device.

## M14 — Steam & release candidate
- **GodotSteam is not vendored.** The GDExtension is a binary download that needs network access and a Steam app ID, so it isn't in the repo. `SteamService` checks `Engine.has_singleton("Steam")`; when the singleton is missing, every call becomes a no-op. Unlocks are mirrored to `user://achievements.json` (skipped under GUT), and rich presence is kept in memory. Tests cover the fallback. Shipping on Steam means dropping GodotSteam into `addons/` and setting the app ID. `# TODO(spec §15.18)`.
- **Achievements** live in `AchievementRules`, a child of SteamService. Counter and state achievements come from the pure `evaluate()` over GameState; it is re-checked on crown, chain, box, rest, bucket, district and boss events. `ACH_TIER5_FIRST` is set when a run's first King kill happens in a Tier ≥ 5 borough. Added counters: `perfects`, `best_streak`, `bootlegs`, `takeovers`.
- **Steam Deck detection:** the `SteamDeck=1` environment variable (set by SteamOS). On first boot only, before any saved quality setting exists, the Deck preset is chosen.
- **Export templates were not installed at first** (installed later on 2026-10-02; the export now runs in verify --full and produces both builds) (`%APPDATA%/Godot/export_templates/4.7.2.stable` is missing), so the export dry run is a logged manual step. verify prints a WARNING and skips it. `export_presets.cfg` (Windows Desktop and Linux) and `tools/export.ps1`/`.sh` are in place, and README explains how to install the templates.
- **Draw-call budget (§15.17).**
  - `MeshBatcher` groups by (mesh, material, 32 m chunk) instead of (mesh, material). District-wide MultiMeshes had defeated culling: each of the 4 shadowed omnis re-drew every group, giving about 5,100 draw calls in Bed-Stuy.
  - Omni shadows use dual-paraboloid mode (2 passes instead of 6).
  - Ground planes and clutter under 1.2 m don't cast shadows.
  - Batched facades share 3 seed buckets, since window cells already hash on world position.
  - Result: districts measure 241–709 draw calls and arenas 336–687, with ≤ 23 visible lights.
  - The test_world budget assertion now measures groups in the busiest 3×3-chunk camera window (`view_groups`), not the district total. The threshold (1,200 × 2 outline passes < 2,500) is unchanged.
- **LightBudget** scans OmniLights under its parent node rather than `current_scene`, which is null in tools. It rescans every 16 refreshes and caps visible lights at the quality preset's `max_lights` (low 16, deck 24, high/ultra 31; plus the moon gives ≤ 32). Moon shadow distance is 45 m with 2 splits.
- **Balancing pass:** `tests/qa/qa_balance.gd` runs every boss through the boss sim (QA bot, seed 2, god mode) at Tiers 1/3/5 for borough bosses, 6 for landmarks and 7 for the finals. It writes `docs/BALANCE.md`. Results 0.5×–1.5× outside the §11.6 windows are flagged `REVIEW` and not auto-tuned, because the bot is not a human player. The QA script fails if fewer than half are in range or any sim is lost.
- **Pre-baked districts** (optional in the spec) are deferred. Every district builds in under 3 s, which is tested for Bed-Stuy.
- **GPU frame rate** (60 fps on GTX 1060 / RX 580, 40–60 fps on Deck) can't be measured headless or on this machine's GPU class. It is a manual step on target hardware.
- **Tool scripts never orphan Godot.**
  - The Windows console binary is a wrapper that spawns the real `Godot_*.exe` as a child. `Start-Process` children are not tied to their parent, so when verify was killed mid-run (by an out-of-memory reaper), the wrapper and the real Godot kept running as orphans (reproduced).
  - `tools/proc_guard.ps1` puts every Godot that verify.ps1 or export.ps1 starts into a kill-on-close Job Object owned by the script, so the OS kills the whole tree when the script exits for any reason. Timeouts use `taskkill /T`. Both paths are tested: 0 Godot processes remain.
  - verify.sh tracks the current child and kills it from an EXIT/INT/TERM trap.
  - Verify only ever runs one Godot process at a time.

## Post-RC — tutorial controls
- **Prompt text is data with binding tokens.** `data/dialogue/prologue.json` prompts use `{action}` tokens (InputMap action names), plus `{move}` (WASD or Left Stick) and `{camera}`. `InputPrompts.format` resolves them to `[key]` for the last-used device. If the device has no binding, it falls back to the other device, then to "unbound"; tests require every tutorial token to be bound on both devices. Prompts are run through `tr()` first, so translations keep the tokens.
- **InputRouter.glyph(action, device)** takes an optional device and returns "" when the action is unbound. It used to return the raw action name. Mouse buttons read "Left Click" and "Right Click". `bindings_changed` fires after every InputMap rebuild, so on-screen prompts update immediately after a remap.
- **Controls menu** reuses RemapMenu with a new label, "Controls". Each row reads `Name   Keyboard | Controller`, and the detail panel gives the full name, what the action does, and both bindings. The cursor stays on the row you were editing.
- **Tutorial step flow:**
  - The prologue syncs the prompt to `tracker.current_id()` every physics frame (with the NICE popup), since steps complete from movement as well as from sim events.
  - "Move" counts from the call-next spot and requires a sprint, because its prompt teaches sprint.
  - Strip is a defense drill. Hands Up only exists without the ball (spec §7: "Defense (you don't): pick their pocket"), so while strip is the open step, the player's ball is held off the court (`no_pickup`, re-parked if a crate make hands it back) and returned when the step ends or the cameo starts.
  - The tutorial caps simultaneous attackers at 1 via `AttackTokenManager.cap` (spec's 2 is for real fights), so the cues are readable and the player can't be hit-stun locked.

## Post-RC — attack cue, story start, objectives (user-directed)
- **Telegraph aura.** `Telegraph.read(actor)` is pure: wind-up progress from the hostile's MoveRunner (enemy, boss, dummy) or a rival Hooper's strike startup. `TelegraphAura` is a billboard radial glow above the head.
  - The aura is red per the user's request. Unblockables get a larger glow with a white core, and they flicker unless Reduce flashes is on.
  - It pulses in the last `CUE_FRAMES = 6` frames: the dodge or Hands Up moment.
  - Stances, showboats, summons and taunts don't glow.
- **Ankle-breaker window 3–14** (spec says 3–12). The user asked for it slightly easier. `ankle_window()` now reads `tuning/combat ankle_breaker.window_end`, which was hard-coded before. Tests derive the window from tuning.
- **One-ball tutorial only** (user's choice).
  - Spawn opts: `no_ball` and `defending`. A "defending" enemy may use its ball moves without a ball. Tutorial crew also get `no_pickup`, so they never scoop up your ball.
  - Street crews keep the spec's own-ball design.
  - During the strip drill, attack tokens are released for everyone but the ball handler. With the tutorial's cap of 1, a ball-less crew member could otherwise hold the only token and deadlock the drill.
- **Story start.** Pops is a visible NPC in the wake-up bodega until your home Crown. His lines are data with `{borough}`, `{cast}`, `{first}`, `{objective}` and `{detail}` filled by `ObjectiveRules.story_tokens`. `LocationCard` shows the district and the time. You wake by the cat, not at the door.
- **Objectives** (not in the spec; added because the street had no direction).
  - `ObjectiveRules.current(from_district)` follows §3.2: home borough first, minis before the King, nearest by route, then the uncrowned borough with the lowest tier, then the City landmarks, then the Garden.
  - Routes are a BFS over district crossings, and City districts need the Crown Pass.
  - Optional bosses (`opt_*`) are never objectives.
- **Dialogue input.** While a dialogue is open, or within 250 ms after it closes, district and interior interactions are suppressed and the buffered Interact press is consumed. Interact both advances dialogue and triggers the nearest interaction, and the 8-frame input buffer used to carry the closing press into the world.
- **Strip drill (user's design):** on defense every crew member has a ball (no attack-token starvation possible); a strip from any of them ends the drill. The earlier "hand your ball to one crew member" version could deadlock when a ball-less crew member held the cap-1 token before the handler asked for it.
- **Telegraph timing = impact, not wind-up end.** `Telegraph.impact_frames_left` adds travel time for moves that cover ground (`lunge_m`; lunge default 4 m, charge_lane 12 m), predicted per frame from distance, hitbox radius and the travel speed over the active frames. The aura stays lit through the travel. Melee and area attacks are unchanged. Feints glow like real attacks, on purpose.
- **Objective on the map:** the district hands its ObjectivePanel target to MapScreen (gold ring, label, legend line). It is drawn even in unrevealed fog, because you know where you're headed.

## Playtest revisions (docs/REVISIONS.md)
- **R4, silent NPCs.** Built layouts store NPC lines as `PackedStringArray`. `JU.strs` read them through `JU.a`, which only accepts `Array`, so every non-challenger street NPC opened an empty dialogue (nothing happened), and challengers lost their intro line. `JU.strs` now accepts packed arrays. Regression test: `test_street_bugs.gd` walks up to the Old Deckhand in St. George and presses Interact.
- **R3, the gull.** `gull_dive` needs 2-8 m, and gulls had no engage case. After one dive they sat inside 2 m with no usable move and trailed the player. Gulls now wheel back out to 5-7 m between dives. After 3 dives, or a successful token snatch, they fly home and ignore you for 10 s (`calm_until`). A snatch pops "A GULL SNATCHED N TOKENS!" so the player knows what happened (kill it to get them back, as before).
- **R2, free look (supersedes spec D2's fixed 50° high angle).**
  - The mouse or right stick now moves pitch over −8°…65°, with mouse Y at the same per-pixel rate as yaw. Invert-Y is respected.
  - `CameraMath.explore_shape` shortens the orbit (12 m → 4.5 m) and raises the look point as the camera drops, ending in an over-the-shoulder view that can look up at buildings.
  - Default pitch is 38°, down from 50°, so you see what's ahead.
  - The camera pulls in front of walls. `CameraMath.line_clear` samples the line, so a wall only blocks where it's taller than the line.
  - Camera far plane is 900 m.
- **R2, skyline.** `DistrictSkyline` builds one MultiMesh ring of about 170 towers beyond the map edge, using a fog-free unshaded shader with a manual haze and lit window grids.
  - Towers are taller toward the City (`tuning/camera skyline.city_dir_deg` per borough); in the City they're tall all around.
  - Draw calls in the Bed-Stuy shots: 707 → 833 (budget 2,500).
- **R5, duel camera.** In boss and challenger duels the camera sits behind the player and looks at the rim (`CameraMath.duel_framing`). With the ball, the player squares up to the rim (`Hooper.face_point`); without it, they face the boss as before.
  - If the boss would hide the player, the framing tries yaw swings (±26°, ±46°), steeper pitches (+14/+26/+38°), and pulling the focus back onto the player. Each candidate is judged at the distance the walls allow.
  - Street lock-on is unchanged.
- **R7, the basketball-first boss model (spec §7.10a, user-directed).** Numbers are in `tuning/bosses duel.r7`.
  - **Per-boss `hoops` profile.** Every boss has a theme, 9 ratings and tendencies (`BossHoops`; validated by data validation and a test). Missing values fall back to `hoops_defaults` by kind.
  - **Your offense.** Your hits on the boss deal ×0.35 while it's your possession (`duel_strike_mult` read in `DamageService._buffs`).
    - Composure damage is unchanged, so ankles, SHOOK and posters still work.
    - The turnover meter is 30% of max Heart, +1% per Handles point above 10, capped at +60%. I first tried 14%: in a probe a single boss hit (45–95 dmg vs 275 Heart) always turned it over, which read as unfair.
  - **Boss defense (`BossCourtIQ`).** Guard distance comes from `pressure`, and the boss closes out on your shot gather.
    - **Reach steals.** A reach is a real telegraphed melee hitbox (`boss_reach`), so a crossover through it is an ankle-breaker. A hit becomes a steal roll: steal rating against your Handles.
    - **Loose balls.** `ball_hunger` sets loose-ball chase speed and how often the boss skips a swing to go get the ball.
  - **Boss offense.**
    - **Shot pick.** It picks from its `shot_mix`, walks to the spot (the paint, 4.6 m or 7.4 m) and waits until it's cleared.
    - **Shot release.** The shot is a synthetic `boss_shot` move: the gather is its startup, so the red cue times it, and the release emits `boss_shot_release`.
    - **Dunk.** The dunk uses the boss's own `statement_dunk` move. Stationary phases shoot their zone from where they sit.
    - A 4.5 s approach cap stops a walled-off boss from walking forever.
  - **Odds (`BossShotOdds`).** P(make) is a rating lerp of 0.22–0.78, multiplied by:
    - (1 − 0.45 × contest);
    - (1 − Body factor × contest), where the Body factor is 0.35 at the rim and 0.22 elsewhere;
    - (1 − 0.25 × your Heart ratio);
    - ×0.45 if altered.
    The result is clamped to 0.04–0.95.
  - **Contest timing.** The perfect window is 4 frames, plus Hands via `parry_window_frames`, capped at 12; that blocks the shot. Up to 10 frames more early alters it. The window is tighter than the 10-frame parry on purpose: a reflex press on the cue alters, and an exact press blocks. The QA bot nails the release half the time.
  - **Boss buckets** cost a % of your max Heart (7/8/10/12 by kind, +5% per tier), then CHECK. `statement_landed` now emits `boss_bucket` (dunk) and pushes the ball through the net instead of healing 8%.
  - **Boss attacks while holding the ball** are limited to a harass roll (30% every 0.75 s, then a 2.5 s cooldown) at ×0.5 damage (`ball_attack_mult` in `MoveRunner.damage`). They never lob their own ball away. Rolling every think tick kept bosses swinging nonstop and they never shot.
  - **Fix: GAME POINT stall.** A SHOOK boss used to scoop your missed GAME POINT shot on contact and hold it forever. Now the boss gets `no_pickup` at GAME POINT, and any ball it holds pops out.
  - **No RefCounted cycles.** `BossDuelRules → DuelController` and `BossCourtIQ → BossBrain` are WeakRef getters; the cycles leaked "17 resources in use" in the smokes.
  - **Balance (QA bot, god mode, seed 2).** 52/55 sims are inside 0.5×–1.5× of §11.6, up from 51/55, and every fight is won. REVIEW: Boom T1 116 s and T5 573 s, Rat King T3 389 s. See docs/BALANCE.md.
  - **Fix: boss parts froze the duel.** The General's split-off horse (`boss_part`) could pick up the loose duel ball, and the duel only reconciles the two duelists, so it stayed LOOSE_BALL forever (seen as a 900 s timeout at T3). Parts now get `no_pickup`.
- **R6, progression before bosses (spec §3.6a).**
  - **Gate rule (`CourtGate`, pure).** Minis and landmarks need their lieutenant beaten (`lt_beaten_<boss>`). Kings need the borough's minis, then their own lieutenant. Beaten courts, the Garden (still gated by its ticket stubs) and optional bosses are open. A chained gate explains itself in narration instead of loading the arena.
  - **Lieutenants are crew captains** (the existing ×1.6 HP, extra move and captain rewards). I chose the archetype per boss to fit (Sal is a Juggler, Padlock a Suit, and so on). Each gets an intro on first alert and a defeat line, and beating one marks the lore heard, re-labels the court and autosaves.
  - **Placement is procedural (`StreetLife.plan`, pure and deterministic):**
    - the lieutenant goes on the plain street tile 4-7 tiles from the gate that's nearest the district start (the side you arrive from);
    - rumor NPCs go on sidewalks 2-4 tiles from the bodegas and station;
    - up to 2 stashes go in dead-end alley tiles 14+ tiles from the start, using the district's first `$` loot pool.
    This way none of the 17 hand-made maps (or their bindings) changed. Tests check the plan is walkable, clear of walls and stable.
  - **Lore (`data/dialogue/lore.json`).** It has "who they were before the clocks stopped" for all 23 bosses, plus a lieutenant and two rumors for the 20 gated ones. Tone follows §3.6: warm, places and jobs, no stereotypes. Rumors double as hints that line up with the R7 profiles ("he drives every time, get in front of him").
  - **Word on the Street** (Pause) lists heard lore. It fills from rumor NPCs, chained gates, lieutenants and Mic Check.
  - **Scope.** No new hand-built side streets. The maps already have alleys, crews, shops and challengers; the stashes give the alleys a reason to visit. More hand-authored side content is deferred (see NEXT_SESSION).
- **R1, in-world direction.**
  - Objectives read "Make a name in <borough>" and "Word is <Boss> holds the court in <district>. <Lieutenant> decides who gets on it."; Kings read "<Borough>'s best have fallen…".
  - Counts moved out of the text into `done/total`.
  - The HUD header is "THE WORD".
  - Pops says "ask around, people talk" instead of "follow the marker".
  - New Settings toggle "Objective marker" (default on). It stays on by default because a stuck player is worse than a led one. Crossing arrows are kept (they're labeled like street signs).
- **Render smoke tonight.** In this session even the 2-draw-call boot scene ran at ~560 ms per frame (display asleep or locked, about 1 AM), so the full 58-shot render couldn't finish. The R2/R5 shots were taken earlier, while frames were normal (14-23 ms). The full verify ran with `CC_HEADLESS=1`. Re-run `tools/verify.ps1 --full` with the screen on.

## Street rep, side streets, hit feedback (2026-10-07, NEXT_SESSION steps 3-4)

- **Street rep, shown as "Buzz".** The in-game name is Buzz so it doesn't read like the Rep currency (`+12 REP` popups already exist on kills). Rules live in `StreetRep` (pure) and `data/tuning/street_rep.json`.
  - Per district: GameState counter `buzz_<district>`. Points: crew beaten 1 (every time, commons respawn), crew captain 2, tag read 1, NPC talked to 1, box or stash opened 1, side street cleared 3. Tags, NPCs, boxes and the side street count once each (`buzz_seen_<id>` flags). Lieutenants and side-street crews don't add kill Buzz; the side street pays its own 3.
  - Need: 6 for a mini's district, 8 for a King's or a City landmark's. The district HUD counts to the highest need among its courts.
  - Gate order (`CourtGate.status`): Kings' minis, then `need: "rep"`, then the lieutenant. Lieutenants only spawn once their court's need is met (`District.spawn_lieutenants`, safe to call again). When Buzz crosses the line mid-visit the lieutenant appears right away, with "THE BLOCK KNOWS YOUR NAME" and a narration line saying who is waiting where.
  - Objective text: "...Nobody gets on it until Bed-Stuy knows your name. (Buzz 2/6)". `+1 BUZZ 2/6` popups show only while a court here is still waiting.
  - A test checks every gated district can reach its need without fighting (tags, people, boxes), so a player who explores instead of brawling is never stuck.
  - Old saves with a beaten lieutenant are unaffected. NG+ keeps Buzz (and, as before, lieutenant flags).
- **Side streets (step 4).** `data/dialogue/side_streets.json` has one hand-written side street per district (17): a named alley, a local NPC with before/after lines, a crew leader (name, crew, archetype) plus 2 members, intro/defeat lines and a loot pool.
  - Placement (`SideStreets.plan`, pure, deterministic): the district's longest one-tile cut between buildings at least 10 tiles from the start. Only 0-4 true dead-end tiles exist per map, so dead ends couldn't host it. The leader holds the middle of the cut, the crew stands 1-3 walking steps away (BFS, never through a wall) and the local stands just past the mouth. An optional `tile` in the data pins it by hand.
  - Runtime (`DistrictSideStreet`): the leader is a captain, and no one in the crew respawns. The leader's intro plays when any of them spots you. When the whole crew is down: `side_cleared_<district>`, "<ALLEY> CLEARED", defeat line, loot from the pool, +3 Buzz, and the local switches to their "after" lines. A cleared crew never comes back.
- **Hit feedback on street enemies (playtest question).**
  - **What ankles do to street enemies (unchanged):** no Heart damage. The crossover dodge puts 35 composure (scaled by your Handles) on the attacker and knocks a street enemy down for 1.5 s (`tuning/combat ankle_breaker.knockdown_s`). While they're down or SHOOK you get free hits and, with the ball, the Dunk Finisher (Interact; 22 x 3.0 crit = 66). About three ankles on the same enemy (before their composure recovers) breaks them SHOOK (3 s).
  - **Before:** a 0.08 s white flash and a small white number, with no health bar and no sign of the knockdown window. So the knockdown wasn't readable.
  - **Now:** `EnemyBars` (CanvasLayer) draws a health bar over a street enemy for 4 s after you hurt them, with a white chip trail that drains after each hit and a shake on impact. Named enemies (lieutenants, side-street leaders, captains) show name + bar when you're within 14 m. A status tag reads DOWN / SHOOK / STAGGERED and becomes "[R] FINISH" when you hold the ball within 6 m and the finisher would land. A downed or SHOOK enemy pulses gold. Hits now flash red-white with a squash (bigger on heavy hits). Damage numbers are bigger (42), orange on heavy hits (54) and gold on crits (68). "DOWN!" pops over an enemy whose ankles you took, and "KO!" when a hit kills.
  - Balance is unchanged on purpose. A damage bonus on downed enemies is the next lever if ankles still feel weak.
