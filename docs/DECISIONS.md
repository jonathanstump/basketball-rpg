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
