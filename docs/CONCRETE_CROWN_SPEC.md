# CONCRETE CROWN — Game Design & Build Spec

_Working title. Spec v1.0 — October 1, 2026._

> **One ball. Five boroughs. No fouls.**

A 3D souls-like action RPG. You're a tiny nobody with a beat-up basketball, fighting larger-than-life streetball legends across a New York City stuck in an endless night. Every attack, every parry, every finisher is a basketball move. Win all five borough crowns, go into the City, and take down the last legend at The Garden so the sun can finally come up.

---

## 0. How to use this document

- **For Jonathan:** §1–§14 are the game. §17 is how to run Claude Code. §18 is the Steam checklist.
- **For Claude Code:** this file is the source of truth. Read all of it before M0. Build order and commit checkpoints are in §16. Agent rules are in Appendix A (copy into `CLAUDE.md` during M0).

### 0.1 Rules when the spec is silent

1. Pick the simplest option that keeps the pillars (§1.2) intact.
2. Content goes in `/data` JSON, not hard-coded.
3. Log the call in `docs/DECISIONS.md` (date, decision, one-line reason).
4. Never block on art or audio. Generate it procedurally (§12, §13, §15).
5. Every number in this spec is a **starting value** for tuning, not a law. Keep them in data files so they can change without code edits.

---

## 1. Vision

### 1.1 The pitch

Streetball meets souls-like. The ball is your only weapon. Common crews jump you in the streets with dribble combos and dunk slams. Mini-bosses and bosses fight you 1-on-1 on their home court with their hoop behind them, where scoring on them is the biggest damage in the game and a bad shot gets you punched in the face.

### 1.2 Pillars

1. **The ball is the blade.** Every attack, dodge, parry, and finisher is a basketball move. No swords, no guns, no punches from the player.
2. **Hard but fair.** Telegraphed, learnable fights. Death is a lesson. "Run it back."
3. **The city is the dungeon.** Dense, interconnected night streets with shortcuts, secrets, and loot worth exploring for.
4. **Style is power.** Ankle-breakers, posters, perfect splashes, and taunts build Hype, and Hype is real power.
5. **Playful, never grim.** Toybox proportions, neon, humor, and a lot of love for NYC.

### 1.3 Touchstones (for feel, never for copying)

Sekiro (posture and deflects), Dark Souls (bonfires, shortcuts, corpse runs), Elden Ring (open order, scaling freedom), NBA Street / NBA Jam (style and "on fire"), NBA 2K (shot meter), Pokémon Sword/Shield and the Link's Awakening remake (toy-diorama look), Spider-Verse (comic-pop flair), The Boondocks (character proportions and attitude).

### 1.4 Scope

- Single-player. 15–20 hour first playthrough.
- Steam: Windows + Linux (Steam Deck). Controller-first, full keyboard/mouse support.
- English at launch; every UI string goes through `tr()` so localization is cheap later.

---

## 2. Key design decisions

**D1 — 3D, not 2D.** The game needs a readable shot arc and hoop depth, jumping and dunking in a real vertical axis, souls-style lock-on, and real-time night lighting (streetlights, neon, wet asphalt). All of that is cheaper and better looking in 3D. A 2D version would need thousands of hand-drawn animation frames that an agent can't produce.

**D2 — High-angle third-person camera.**

- Exploration: pitch 50°, distance 12 m, FOV 45°, free yaw on the right stick, slight tilt-shift blur for a toy-diorama feel.
- Lock-on (any fight): pitch 38°, distance 9–14 m (dynamic), frames player + target (+ hoop in boss arenas).
- Buildings between camera and player dither-fade out (occlusion cutaway, §15.12).

**D3 — Godot 4 + GDScript, not Unity.** Jonathan knows Unity, but this build is meant to run unattended under `/goal`. Godot's scenes and resources are plain text, the engine runs fully headless for tests, there's no license activation to fight in CI, and a verify loop takes seconds instead of minutes. If you ever port, the architecture in §15 maps to Unity cleanly.

**D4 — Art from code first.** Everything ships first as a procedural "toybox" style: chunky primitive-built meshes, cel shading, thick outlines, neon. It's charming on its own and needs zero external assets. An `AssetRegistry` lets real models drop in later without code changes.

**D5 — Data-driven content.** Items, enemies, bosses, moves, maps, loot, dialogue, and tuning live in `/data`. Code is systems; data is content.

**D6 — How "same bosses in every borough" works.** Each borough has a fixed cast (its own 2 mini-bosses, 1 borough king, crews, and secrets). That cast is identical in every playthrough. What changes with your starting borough is each borough's **tier** (1–5), set by distance from where you started (§4.3). Higher tier = more health, more damage, and extra moves and phases.

---

## 3. Setting, story & cast

### 3.1 The Long Night

At 3:00 AM on the last night of summer, every clock in New York stopped. The sun never came up. On endless hype, the streetball legends who hold each borough's Crown grew into something more than human: giants, beasts, living landmarks. The courts got locked down by crews. Nobody gets "next" anymore.

The truth (revealed in pieces): **Midnight**, the greatest to ever do it, stopped the clock at The Garden so his last game would never end. Every legend's hype flows up to him. To make the sun rise, someone has to take all five Crowns, go into the City, and beat Midnight at The Garden.

### 3.2 Structure

- **Act I — The Five Boroughs.** Start in any borough. Beat its two mini-bosses and its Borough King to earn that borough's Crown. Go anywhere, in any order. Tier tells you how hard each place hits.
- **Act II — The City.** Holding all five Crowns forms the **Crown Pass**, which opens the bridges, ferry, and park gates into the City (Midtown and Downtown Manhattan). New Yorkers from the outer boroughs say they're "going into the city" when they mean Manhattan; that's exactly this act. Five landmark courts, any order.
- **Finale — The Garden.** Opens after all five landmarks. Three-phase fight against Midnight. Two endings.

### 3.3 Opening — "I Got Next"

1. Title screen: skyline at night, every clock at 3:00.
2. Character creator (§6.2), archetype pick (§6.3), starting borough pick with the tier map preview (§4.3).
3. Your home court. You walk up and call "I got next." A crew laughs. Tutorial fight teaches move, dribble strike, crossover, ankle-breaker, shooting at a crate hoop, strip, and Quarter Water.
4. **The unwinnable cameo.** The court lights flicker, a tall shadow in an old warm-up suit walks on, checks you the ball, and ends you in one move: "Not yet, kid." (Midnight. You'll see him again.)
5. You wake up in the nearest bodega with the cat sitting on your chest. Pops is at the counter. Rest, level, go.

### 3.4 Cast

| Character                | Role                 | Notes                                                                                                                                          |
| ------------------------ | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **You**                  | Player               | Tiny, customizable, quiet. The MC gives you a nickname after your first Crown based on your playstyle (§6.2).                                  |
| **Pops**                 | Mentor, old head     | Was a legend once. Bench at your starting court; shows up in each borough after its Crown. Teaches Bag Moves. Optional superboss in his prime. |
| **Mic Check**            | Announcer / hype man | Megaphone, fresh fit. Introduces every boss with a title card. Comments on your plays. Sells rumors (hints).                                   |
| **The Plug**             | Sneaker shop owner   | Runs a shop in every borough ("I got a guy everywhere"). Buys and sells gear. Grail Hunt questline.                                            |
| **Ink**                  | Tattoo artist        | Ink & Needle parlors in every borough. Applies and lasers tattoos.                                                                             |
| **Gripz**                | Pump & Grip owner    | Sporting goods. Sells balls, upgrades balls.                                                                                                   |
| **Bodega owners & cats** | Checkpoints          | Every bodega has a named cat. Petting the cat is how you rest. Cats are never enemies, ever.                                                   |
| **Deuce**                | Rival                | Cocky kid your size, red headband. Three duels across the game. Ends up in the Garden stands cheering for you.                                 |
| **Midnight**             | Final boss           | The Last Legend.                                                                                                                               |

### 3.5 Questlines (keep them small)

1. **Old Head Lessons (Pops):** after each Crown, Pops teaches one Bag Move. After all five, he asks for "one more run" (optional superboss).
2. **Grail Hunt (The Plug):** find the 5 Grail shoeboxes (one per borough) → legendary kicks "Golden Hour".
3. **Lost Cat (any bodega):** a bodega cat goes missing; find it in an alley across the borough → Nine Lives tattoo flash.
4. **Rival (Deuce):** duel after your first mini-boss, after your third Crown, and in The Garden tunnel before Midnight (optional fight).

### 3.6 Storytelling rules

- Souls-light: short dialogue, no long cutscenes. Lore lives in item flavor text, MC barks, and NPC lines.
- **Graffiti tags** are pre-written hint messages on walls ("try crossing over", "look up", "big man ahead", "cat's friendly"). About 10 per district. Read with Interact.
- Tone: warm, funny, confident. Never mean-spirited. No ethnic or regional stereotypes; borough identity comes from places, architecture, color, and landmarks.

### 3.6a Revision R6 / R1 (playtest): earn the court, hear the story

- **Courts are chained until the street knows you.** Each mini-boss and City landmark has a **Lieutenant**: a named crew captain on the street near the court, with an intro and a defeat line (`data/dialogue/lore.json`). Beating them opens the court.
  - A Borough King also waits for the borough's two minis, then sends his own lieutenant.
  - The Garden keeps its ticket-stub gate. Optional bosses and beaten courts stay open.
- **Lore lives on the street.** Every boss has "who they were before the clocks stopped." Two rumor NPCs per court stand by the bodegas and the station (placed from the map by `StreetLife`). Talking to them, beating the lieutenant, or hearing Mic Check adds the boss to **Pause → Word on the Street**.
- **Alley stashes:** up to two dead-end alleys per district hide a stash with the district's loot.
- **In-world direction (R1):** objectives speak the way people on the street would. "Make a name in Brooklyn — Word is The Stoop Queen holds the court in Bed-Stuy. Lil' Deacon decides who gets on it." No "beat the mini-boss." Pops says the same and tells you to ask around. The objective marker can be turned off in Settings.

### 3.6b Street rep and side streets (follow-up to R6)

- **Buzz (street rep) comes before the lieutenant.** A lieutenant only shows up once the district knows your name. You earn Buzz by beating crews, reading tags, talking to people, opening stashes and boxes, and clearing the side street. The court needs 6 Buzz for a mini and 8 for a King or a City landmark (`data/tuning/street_rep.json`). The objective counts it ("Buzz 2/6"). When you reach it, the lieutenant appears and the street tells you where.
- **One side street per district** (`data/dialogue/side_streets.json`). It's a named alley held by a small crew and their leader, with a local at the mouth who tells you about it. Clearing it pays the alley's loot and Buzz, and the local thanks you.
- **Street hits read clearly.** Hurt enemies show a health bar. When a street enemy is open (downed by ankles, or SHOOK), they glow gold, and the tag says FINISH when the Dunk Finisher would land.

### 3.7 Endings

After Midnight's third phase, the scoreboard clock reads 11:59:59. Prompt:

- **Let it run → "Daybreak."** The clock hits 12:00. The Garden roof opens to the first sunrise of the game (the only daylight scene). Credits over dawn. Post-credits, the overworld switches to a dawn lighting preset.
- **Stop the clock → "Overtime."** You take Midnight's crown. The night goes on. Starts New Game+ immediately with your character wearing the crown.

---

## 4. The world

### 4.1 Regions

| Region                                   | Districts (3 each; City has 2)              | Palette                 | Vibe                                                                       |
| ---------------------------------------- | ------------------------------------------- | ----------------------- | -------------------------------------------------------------------------- |
| **The Bronx**                            | Mott Haven, West Farms, Highbridge          | Crimson + gold          | Birthplace of hip-hop, elevated trains, art deco boulevard, murals         |
| **Brooklyn**                             | Bed-Stuy, Coney Island, DUMBO               | Violet + teal           | Brownstones and stoops, boardwalk and coaster, cobblestones under bridges  |
| **Queens**                               | Roosevelt Ave, Astoria, Flushing Meadows    | Green + orange          | Elevated line over night markets, waterfront, the giant steel globe        |
| **Staten Island**                        | St. George, The Narrows, The Heap           | Ferry orange + sea blue | The ferry, the old fort, landfill hills, deer in the woods                 |
| **Uptown** (Manhattan north of the park) | Harlem 125th, Washington Heights, The Mecca | Electric blue + white   | The theater marquee, rooftops and pigeon coops, the most famous park court |
| **The City** (Act II)                    | Downtown, Midtown                           | Gold + white neon       | Landmarks, screens, skyscraper rooftops                                    |

### 4.2 Crossings (walkable borough connections)

Each crossing is a short bridge, tunnel, or ferry sequence that loads the neighbor borough.

- Bronx ↔ Uptown — Harlem River Bridge
- Bronx ↔ Queens — the Sound Bridge
- Queens ↔ Uptown — the Tri-Bridge (also touches the Bronx side)
- Queens ↔ Brooklyn — the Cemetery Belt (spooky walk through old cemeteries)
- Brooklyn ↔ Staten Island — the Narrows Bridge
- Into the City (locked until Crown Pass): Uptown via the park's north gate, Brooklyn via the old bridge from DUMBO, Staten Island via the ferry, Queens via the river tunnel.

Subway fast travel (§5.3) connects any discovered stations, in any borough.

### 4.3 Tier scaling (the core rule)

At New Game, the starting borough sets every borough's tier for the whole run. Tiers come from real geographic distance between borough centers (Uptown uses Harlem as its center). Closest = easiest.

| Start ↓ / Tier of → | Bronx | Brooklyn | Queens | Staten Is. | Uptown |
| ------------------- | ----- | -------- | ------ | ---------- | ------ |
| **Bronx**           | 1     | 4        | 3      | 5          | 2      |
| **Brooklyn**        | 4     | 1        | 2      | 5          | 3      |
| **Queens**          | 3     | 2        | 1      | 5          | 4      |
| **Staten Island**   | 5     | 2        | 4      | 1          | 3      |
| **Uptown**          | 2     | 3        | 4      | 5          | 1      |

- The City is always **Tier 6**. The Garden is **Tier 7**.
- Staten Island is the geographic outlier, so it's Tier 5 from four of five starts. That's intentional: it's "the forgotten borough" and a fitting last stop before the City.
- Tier affects: HP, damage, composure, rewards, loot rarity weights, AI aggression, elite spawns (Tier 3+), and which boss moves/phases exist (§9.1).
- Nothing stops you from walking into a Tier 5 borough at level 1. It will hurt. That's the souls deal.
- New Game+ adds +2 to every tier (cap 7) and multiplies everything by 1.3 per cycle.
- Multipliers per tier are in §11.1.

### 4.4 What every borough contains

- 3 districts, each a 64×64-tile map (tile = 4 m, so 256 m square).
- 4 bodegas (checkpoints), 3 subway stations (1 per district).
- 1 The Plug, 1 Pump & Grip, 1 Ink & Needle.
- 2 mini-boss courts + 1 Borough King court (indoor arenas are listed in §4.6).
- 12–16 shoeboxes, 1 Grail box, 2–3 Bootleg mimics, 2–3 Wire Kicks, 1–2 Mixtapes, 1–2 Punch Cards, 1–2 Sugar Rush, 2–3 tattoo flash sheets.
- 6+ crate hoops.
- 2 Pickup Challengers (optional 1v1 duels).
- At least 3 one-way shortcuts (fire-escape ladders you kick down, gates you unlock from the far side).
- 1 secret area (rooftop route, tunnel, or hidden courtyard).
- ~10 graffiti hint tags per district.

### 4.5 Borough by borough

**THE BRONX**

- _Mott Haven (start district if Bronx)._ Murals, elevated tracks, Harlem River Bridge crossing. **Mini: King Crab** at the Market Hall (indoor waterfront fish market).
- _West Farms._ Zoo fence line, the river, Sound Bridge crossing to Queens. **Mini: Silverback** at the Zoo Fence Court.
- _Highbridge._ Art deco boulevard, the El overhead, the block-party court on Sedgwick. **King: Grandmaster Boom.**
- Unique enemy: **Breaker** (b-boy windmill spin AoE, freezes into a taunt pose that's punishable).
- Bodega cats: Papi, Chulo, Biscuit, Mami.

**BROOKLYN**

- _Bed-Stuy._ Brownstones, stoops, neighbors at windows, Cemetery Belt crossing to Queens. **Mini: The Stoop Queen.**
- _Coney Island._ Boardwalk, beach, coaster, Narrows Bridge crossing to Staten Island. **Mini: The Barker** in the Funhouse (indoor).
- _DUMBO._ Cobblestones, bridge archways, warehouses, a view of the locked City across the water. **King: The Toll.**
- Unique enemy: **Fixie Rider** (rides through in straight lines; dodge, then strip the rider when they turn around).
- Bodega cats: Tony, Bagel, Brownie, Mrs. Whiskers.

**QUEENS**

- _Roosevelt Ave._ Elevated line over a night market strip, string lights, Cemetery Belt crossing to Brooklyn. **Mini: The Express** on the elevated platform.
- _Astoria._ Waterfront, the Tri-Bridge crossing to Uptown and the Bronx. **Mini: Extra Sauce** in the Food Hall (indoor).
- _Flushing Meadows._ Old fairground pavilions, fountains, the giant steel globe. **King: Atlas.**
- Unique enemy: **Juggler** (keeps three balls in the air; each one is a separate lob attack).
- Bodega cats: Momo, Mango, Saffron, Taco.

**STATEN ISLAND**

- _St. George._ Ferry terminal (City ferry locked until Crown Pass), seawall court. **Mini: The Ferryman** on the ferry deck (boarding the docked ferry starts the fight as it pulls out).
- _The Narrows._ The old fort on the cliff, the Narrows Bridge crossing to Brooklyn. **Mini: The General** in the fort courtyard.
- _The Heap._ Landfill hills under floodlights, the woods' edge. **King: King of the Heap.**
- Unique enemies: **Gull** flocks (dive-bomb, snatch tokens) and **Night Deer** (charges in straight lines; Staten Island really does have a deer problem).
- Bodega cats: Gus, Rocco, Pickles, Ferry.

**UPTOWN (MANHATTAN)**

- _Harlem 125th._ Theater marquee, brownstones, Harlem River Bridge to the Bronx, Tri-Bridge to Queens, the park's north gate to the City (locked). **Mini: The Hook** on the theater stage (indoor).
- _Washington Heights._ Hills, stairs, rooftops, coops, the big bridge to New Jersey glowing in the background (out of bounds). **Mini: The Coop King** on a rooftop.
- _The Mecca._ The legendary park court on 155th: bleachers, chain fence, towers behind. **King: High Rise.**
- Unique enemy: **Pigeon Keeper** (whistles to send pigeon swarms; kill the keeper and the swarm scatters).
- Bodega cats: Duke, Sugar, Smokey, Lady.

**THE CITY (Act II, Tier 6)**

- _Downtown._ The Village, the financial district, the old bridge's Manhattan end, the ferry terminal, an abandoned tiled station. Landmarks: **The Cage**, **The Bridge**, **The Underground**.
- _Midtown._ The screens plaza, art deco towers, avenues of light. Landmarks: **The Crossroads**, **The Summit**, and **The Garden**.
- Unique enemies: **Suits** (fast, coordinated, "hedge" each other's attacks), **Big Head Mascots** (generic costumed characters, tanky, comedic), **Tourists** (non-hostile; their camera flashes blind you for a second).
- Bodega cats: Broadway, Chairman, Penny, Lex.

### 4.6 Interiors

Interiors load as small separate scenes through doors: The Plug, Pump & Grip, Ink & Needle, every bodega, and indoor arenas (King Crab's Market Hall, The Barker's Funhouse, Extra Sauce's Food Hall, The Hook's Theater, The Underground, The Garden). Rec-center gyms in some districts host Pickup Challengers indoors.

---

## 5. Core loop & progression systems

### 5.1 Loop

Explore night streets → fight crews and critters → find shoeboxes, tokens, mixtapes, punch cards → reach a bodega (rest, level, refill; enemies respawn) → tap into subway stations (fast travel, map reveal) → take on mini-bosses → beat the Borough King → Crown → repeat → Crown Pass → the City → The Garden.

### 5.2 Bodegas (checkpoints)

- Interact with the cat to **Rest**: refill Quarter Waters, respawn all common enemies, autosave, set respawn point.
- Counter menu: **Train** (level up with Rep), **Travel** (fast travel to any discovered station), **Stash** (storage), **Swap Bag Move**, **Shop** (consumables, §10.8), **Punch Card** trade-in (+1 Quarter Water charge).
- Resting reveals the map within 80 m.

### 5.3 Subway & map

- Stations are fast-travel points. Tapping in the first time reveals that district's street map (not its items).
- Walking reveals the map within 25 m (fog of war).
- The map screen is styled like an original subway map: colored lines, station dots, district outlines. Markers: bodegas, stations, shops, courts (boss icon once seen), up to 20 player pins.
- Fast travel works from any bodega or station to any discovered station.
- Travel shows a short subway-car loading scene (the loading screen is the ride).

### 5.4 Currencies and death

- **Tokens** (old subway tokens) buy gear, upgrades, tattoos, consumables. You keep tokens when you die.
- **Rep** is XP, spent at bodegas to level. Unspent Rep is what you risk.
- **Death → "COOKED."** You lose your unspent Rep; **all of it** drops as **your chain** on the spot you died, under a gold light beam you can see over the rooftops, and an amber HUD/map marker leads you back (revisions 8, 14). Respawn at your last bodega. Get back to the chain and touch it to reclaim the Rep ("Run it back"). Die again first, and it's gone.
- In a boss arena, the chain drops just outside the arena gate.

### 5.5 Exploration rewards

- **Shoeboxes** (chests): brand on the lid tells you the loot pool (§10.3). Some are locked and need a **Box Key** (dropped by Crew Captains).
- **Bootlegs:** fake shoeboxes that bite (mimics). Tell: slightly-wrong logo and the lid breathing if you watch for 3 seconds.
- **Wire Kicks:** sneakers hanging on a power line. Hit them with a pass to knock them down. Always kicks, often rare.
- **Crate hoops:** milk crates nailed to poles. Out of combat, your first make at each one pays tokens. In combat, see §7.9.
- **Mixtapes** (cassettes) teach Bag Moves. **Punch Cards** add Quarter Water charges. **Sugar Rush** packets increase how much each Quarter Water heals. **Flash sheets** unlock tattoos.
- **Graffiti tags:** hints (§3.6).

### 5.6 Healing

- **Quarter Waters** (the cheap little juice drinks): start with 3, max 10 via Punch Cards. Each heals 35% max Heart, +5% per Sugar Rush (max 5 → 60%). Drinking takes 0.9 s and you're vulnerable.
- Bodega consumables (§10.8) are optional extras.

### 5.7 Leveling ("Train")

- Each level = +1 to one stat. Cost in §11.3.
- Everyone starts at Level 1 with their archetype's stats.

### 5.8 New Game+ ("Run It Back+")

Keep all gear, stats, tattoos. Tiers +2 (cap 7), ×1.3 multipliers per cycle. Crowns reset.

### 5.9 Rookie Mode (settings toggle, off by default)

+2 Quarter Waters, shot and parry windows ×1.25, enemy damage ×0.75. Labeled honestly. Achievements still unlock (Jonathan's call before launch).

---

## 6. The player

### 6.1 Look

- Cartoon kid proportions in the spirit of The Boondocks: big round head, small body, expressive eyes, about 3 heads tall, 1.35 m total. Age-ambiguous young adult in-story.
- Always dribbling when idle or walking (soft bounce sound, cozy).
- Built as a segmented "puppet rig" (§15.11). Tattoos show as decals on arms, legs, neck.

### 6.2 Character creator

- Skin tone (16 swatches + fine slider), face shape (5), eyes (8 shapes, 10 colors), brows (6), nose (5), mouth (5), freckles/marks (6), facial hair (6, optional), height (0.95–1.05 scale), voice set (3 grunt sets).
- Hair (16): fade, high-top, afro, puffs, twists, locs, braids, cornrows, buzz, bald, curls, ponytail, bun, mohawk, waves, bantu knots. Hair color (12 + slider).
- No gendered labels; one body base with options.
- **Streetball name:** pick prefix + name from lists ("Lil'", "Young", "Big", "The" + "Handles", "Glide", "Splash", "Static", "Knots"…) or type your own (profanity filter).
- **Earned nickname:** after the first Crown, Mic Check gives you a title based on your most-used style (most ankle-breakers → "Ankle Taker"; most posters → "Poster Child"; most threes → "Long Range"; most strips → "Pickpocket"; most taunts → "All Mouth"). Shown on your HUD tag and in boss intros.

### 6.3 Archetypes (starting class)

Seven stats (§6.4). Starting stats below; all start at Level 1.

| Archetype     | HRT | WND | BDY | HDL | BNC | JMP | HND | Start ball      | Start Bag Move |
| ------------- | --- | --- | --- | --- | --- | --- | --- | --------------- | -------------- |
| Slasher       | 10  | 11  | 9   | 13  | 14  | 8   | 9   | Rec Ball        | Spin Cycle     |
| Shooter       | 9   | 10  | 8   | 11  | 9   | 16  | 11  | Leather Indoor  | Hesi           |
| Floor General | 10  | 11  | 8   | 15  | 9   | 10  | 11  | Rec Ball        | Snatchback     |
| Enforcer      | 14  | 10  | 15  | 8   | 11  | 7   | 9   | Rubber Blacktop | Trash Talk     |
| Two-Way       | 11  | 11  | 10  | 10  | 10  | 10  | 12  | Rec Ball        | Hesi           |
| **Nobody**    | 9   | 9   | 9   | 9   | 9   | 9   | 9   | Taped-Up Ball   | none           |

Nobody is the challenge class (fewer total points, worst ball, no Bag Move).

### 6.4 Stats

| Stat              | What it does                                                                                                                          |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **HEART** (HRT)   | Max HP. 300 at 10; +25/pt to 40, +10/pt to 60, +3/pt after.                                                                           |
| **WIND** (WND)    | Max stamina. 100 at 10; +3/pt to 40, +1/pt after. Sprint efficiency.                                                                  |
| **BODY** (BDY)    | Poise, damage reduction (+0.4%/pt above 10, cap 20%), shove/slam damage scaling, guard stability.                                     |
| **HANDLES** (HDL) | Dribble strike damage scaling, ankle-breaker window (+0.2 frame/pt above 10, max +6 frames), ball security vs steals, Bag Move power. |
| **BOUNCE** (BNC)  | Jump height (+0.02 m/pt), dunk range (+0.03 m/pt), dunk and aerial damage scaling.                                                    |
| **JUMPER** (JMP)  | Shot meter windows (§7.6), shot damage scaling, deep range.                                                                           |
| **HANDS** (HND)   | Parry/strip window (+0.2 frame/pt above 10, max 16 frames total), reach-in steal chance, rejection timing.                            |

Soft caps at 20 / 40 / 60 (diminishing returns per the formulas). Ball scaling grades (S/A/B/C/D) map to stat contribution multipliers 1.0/0.8/0.6/0.4/0.2.

---

## 7. Combat

### 7.1 Philosophy

- One weapon: the ball. What you can do depends on whether you have it.
- **Two parries, one on each side of the ball:**
  - **Offense (you have the ball): break their ankles.** A perfectly timed crossover dodge through an attack = ANKLE BREAKER.
  - **Defense (you don't): pick their pocket.** A perfectly timed Hands Up against an attack = STRIP (steal) or DEFLECT.
- Bosses add the hoop: scoring on them is skill-based damage that ignores your level (§7.10, §11.5).

### 7.2 Controls (controller / keyboard+mouse)

| Action                                     | Pad              | KB/M                       |
| ------------------------------------------ | ---------------- | -------------------------- |
| Move                                       | Left stick       | WASD                       |
| Camera                                     | Right stick      | Mouse                      |
| Lock-on / switch target                    | R3 / flick RS    | Middle mouse / mouse wheel |
| Jump                                       | A                | Space                      |
| Dodge (crossover / slide); hold = sprint   | B                | Shift (tap/hold)           |
| Light attack                               | X                | Left mouse                 |
| Heavy attack (hold = charge)               | Y                | Right mouse                |
| Shoot (hold, release on meter)             | RB               | E                          |
| Hands Up (tap = parry/strip, hold = guard) | LB               | Q                          |
| Bag Move                                   | LT               | F                          |
| Takeover (Hype full)                       | LT + RT          | F + R                      |
| Interact / dunk finisher prompt            | RT               | R                          |
| Quarter Water                              | D-pad up         | 1                          |
| Swap ball (2 slots)                        | D-pad left/right | 2 / 3                      |
| Taunt                                      | D-pad down       | T                          |
| Map                                        | View/Back        | M                          |
| Menu                                       | Start            | Esc                        |

Everything is remappable. Glyphs swap to the last-used device.

### 7.3 Resources

- **Heart** (HP), **Wind** (stamina, regen 45/s after a 0.6 s delay, 15/s while guarding).
- **Hype** (0–100): built by style (ankle-breakers +12, strips +10, perfect shots +10, posters +25, completed taunts +15, Bucket Blasts +8). Decays 2/s after 8 s of no gain. Spent on Bag Moves and Takeover.
- **Composure** (enemies/bosses only): posture bar. Breaks into SHOOK or STAGGER (§7.11).

### 7.4 With the ball (frame data at 60 fps)

| Move                  | Input                                | Startup / Active / Recovery | Wind | Base dmg         | Composure | Notes                                                                    |
| --------------------- | ------------------------------------ | --------------------------- | ---- | ---------------- | --------- | ------------------------------------------------------------------------ |
| Pound                 | X                                    | 9 / 4 / 14                  | 12   | 22               | 8         | Chain 1                                                                  |
| Cross Whip            | X,X                                  | 8 / 4 / 14                  | 12   | 22               | 8         | Chain 2                                                                  |
| Between-the-Legs Snap | X×3                                  | 10 / 5 / 16                 | 12   | 26               | 10        | Chain 3                                                                  |
| Behind-the-Back Slam  | X×4                                  | 16 / 6 / 24                 | 16   | 40               | 22        | Chain finisher                                                           |
| Euro Step Strike      | Sprint + X                           | 10 / 4+4 / 20               | 22   | 2×28             | 2×10      | Gap closer                                                               |
| Chest Pass            | Y                                    | 12 / projectile / 18        | 20   | 45               | 20        | 30 m/s, 18 m range. Hit = ball ricochets back to you. Miss = loose ball. |
| Baseball Pass         | Hold Y ≥ 36f                         | 20 / projectile / 30        | 35   | 90               | 40        | 35 m range, pierces 2 commons, always ends loose                         |
| Tomahawk Slam         | Jump + X                             | 14 / 6 / 26                 | 25   | 55 (AoE r 2.5 m) | 25        |                                                                          |
| Crossover             | B                                    | i-frames 3–14, total 22f    | 18   | —                | —         | 3.2 m dash. Perfect = Ankle Breaker.                                     |
| Stepback              | B + back                             | as Crossover                | 18   | —                | —         | Next shot within 0.8 s: window ×1.4                                      |
| Lob                   | RB with no hoop in range             | 14 / projectile / 20        | 18   | 35 (AoE r 2 m)   | 12        | High arc to target point (hits snipers on fire escapes)                  |
| Dunk                  | Sprint toward hoop + A in dunk range | 10 launch, 30 total         | 20   | bucket (§11.5)   | 30        | Range 3.5 m + Bounce                                                     |
| Dunk Finisher         | RT near a knocked-down/SHOOK common  | 8 / 6 / 20                  | 10   | ×3 crit          | —         | Jump and slam the ball off their head                                    |
| Quarter Water         | D-up                                 | 54 total                    | —    | —                | —         | Vulnerable                                                               |
| Taunt                 | D-down                               | 72 total                    | —    | —                | —         | +15 Hype if not hit                                                      |

**Ankle Breaker:** if an enemy's active hitbox overlaps your crossover's frames 3–12 (+ Handles bonus), time slows to 0.3× for 0.6 s, the enemy takes 35 composure damage (scaled by Handles), commons fall down for 1.5 s, +12 Hype, "ANKLES!" pops, the crowd (if any) goes "OOOOH".

### 7.5 Without the ball

| Move             | Input                            | Frames                                   | Wind    | Effect                                                                                                                                              |
| ---------------- | -------------------------------- | ---------------------------------------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Shove / Box Out  | X                                | 7 / 4 / 12                               | 10      | 12 dmg, 10 composure                                                                                                                                |
| Reach-in Swipe   | Y                                | 12 / 5 / 22                              | 14      | Steal chance 35% + Hands scaling vs target ball security, only vs dribbling (not attacking) targets. Miss = you're off-balance 20f.                 |
| Hands Up (parry) | Tap LB                           | 10f window (+Hands) / 18f whiff recovery | 8       | vs ball attacks: **STRIP** (ball knocked loose, biased toward you; 30 composure; +10 Hype). vs body attacks: **DEFLECT** (no damage; 20 composure). |
| Guard            | Hold LB                          | —                                        | dmg×0.8 | Frontal block, 25% chip damage, guard break at 0 Wind (1.2 s stagger)                                                                               |
| Defensive Slide  | B                                | i-frames 3–12, total 20f                 | 15      | 2.8 m dash. Perfect timing = "Read" (+5 Hype only).                                                                                                 |
| Hustle Dive      | B toward a loose ball within 3 m | 24 total                                 | 15      | Grabs it                                                                                                                                            |
| Rejection        | Jump + LB                        | 6 / 8 / 18                               | 15      | Swats airborne balls (lobs, mortars, boss statement dunks) → steal                                                                                  |

**Unblockable attacks** flash red (like Sekiro's perilous attacks). Hands Up fails against them; you must dodge.

### 7.6 Shooting (the 2K-style meter)

- Hold Shoot: a vertical meter fills beside you over the **gather time** (0.55 s base; balls modify it). Release in the window. Holding past full = automatic brick.
- **Grades:** PERFECT ("SPLASH!"), GOOD (make), NEAR MISS (rims out → loose ball), BRICK (way off → loose ball), **REJECTED** (see below).
- **Window formula** (meter runs 0→1, window centered at 0.82):
  - Base widths at Jumper 10: perfect 0.05, good 0.12, near-miss 0.22.
  - Jumper: perfect +0.0015/pt above 10 up to 40, +0.0005/pt up to 60. Good and near-miss scale proportionally.
  - Zone: close (<3 m) ×1.5, mid ×1.0, three (beyond the arc) ×0.85, deep (arc + 2 m) ×0.6.
  - Contest: × (1 − 0.6 × contest), where contest ∈ [0,1] from nearest defender distance vs their contest radius and facing.
  - Modifiers: Stepback ×1.4, Wide Open (boss SHOOK) ×2.0, Takeover ×1.6, low Wind (<25%) ×0.8, gear/tattoos as listed. Perfect width capped at 0.25.
  - **On the run** (revision 9): shoot while moving at run speed and you keep moving through the gather (×0.7 speed), but the windows shrink: ×0.65 running, ×0.5 sprinting (`tuning/shooting`).
- **REJECTED (the punish):** if contest ≥ 0.85 ("smothered") and the grade would be NEAR MISS or worse, the defender swats it and follows up with an unavoidable short combo (boss: 18% of your max Heart, tier-scaled); they take the ball.
- **Knocked out of the gather** (revision 13): a hit that cancels your shot before the release also clears the meter. No shot left your hands, so nothing flashes.
- **Every make is loud** (revision 11): a bucket horn, confetti and a light pillar at the rim (gold for you, red for them), so a make reads even when a big boss hides the hoop. In a boss fight, a boss bucket also shows a "SCORED ON!" banner with a flash and a camera punch, and yours shows "BUCKET!".
- The shot's outcome is decided at release. The flight is a scripted arc that plays out the result (clean swish, rim-in, rim-out, airball, block). Rim-outs hand off to ball physics.

### 7.7 Dunks, posters, finishers

- **Dunk:** sprint at a hoop in range and jump. In a boss arena, if the boss is in the paint between you and the rim and isn't SHOOK, they **meet you at the rim**: blocked, punished, ball lost.
- **POSTER:** if the boss is SHOOK and you're within 4 m with the ball, dunk = POSTERIZE. Freeze frame, camera flash, comic halftone, "POSTERIZED!" sticker, massive damage (§11.5).
- **Dunk Finisher** on commons: see §7.4.

### 7.8 Hype, Bag Moves, Takeover, taunts

- **Bag Moves** (LT): one equipped, swap at bodegas. Cost Hype. Full list §10.7.
- **Takeover** (LT+RT at 100 Hype): "ON FIRE" for 12 s. Ball literally on fire, shot windows ×1.6, damage ×1.25, Wind regen ×1.5, every make adds +2 s. 30-frame activation with i-frames.
- **Taunts:** risk/reward. 1.2 s of vulnerability for +15 Hype. Against bosses, a completed taunt also makes them more aggressive for 5 s.

### 7.9 Street rules (common enemies)

- Every street enemy has its own ball (their weapon). You always have yours.
- **Strip a common:** their ball flies ~5 m away. They're disarmed and run for it, taking +30% damage until they recover it.
- **Crate hoops in combat:** make a shot into a crate hoop and it fires a **Bucket Blast**: 6 m shockwave, 60 damage, 40 composure, knocks commons down. 20 s cooldown per hoop (the crate glows when ready). This is why you kite fights toward hoops.
- **Pickpockets** can steal your ball (§8.1). If they escape, your ball shows up at the nearest bodega's lost & found (a cat is sitting on it) and you fight with a spare Rec Ball until then.
- **Lost ball safety:** if your ball goes into water, out of bounds, or is unreachable for 10 s, a spare appears in your hands.
- Group AI: at most 2 enemies actively attack you at once (attack tokens); others circle and taunt.

### 7.10 Court rules (boss and mini-boss duels)

Every boss fight is half-court 1-on-1 with **one ball** and **one hoop**, mounted behind the boss.

**Possession state machine:**

- **CHECK:** the boss checks you the ball at the top of the key; boss resets into the paint; 1.2 s, then PLAYER OFFENSE. Every fight and every phase starts here.
- **PLAYER OFFENSE:** you attack with dribble strikes and passes, break ankles, and look for a shot or a dunk.
  - Make → damage + boss composure hit → **CHECK (make it, take it: you keep the ball).** The boss is rattled for ~1 s.
  - Near miss / brick → **LOOSE BALL** (rebound scramble).
  - Rejected → you take the punish, **BOSS OFFENSE**.
  - Pass hits boss → ball ricochets back, still your offense. Pass misses → LOOSE BALL.
  - Boss steals (its own strip move) → LOOSE BALL biased toward boss, or BOSS OFFENSE.
- **LOOSE BALL:** first to touch it gets it. Missed shots off the rim show a rebound ring: jump at the apex for a guaranteed board. If you get it: PLAYER OFFENSE but **not cleared**. If the boss gets it: BOSS OFFENSE.
- **Clear the ball (real half-court rule):** after a change of possession, you must dribble beyond the 3-point arc before your buckets count. The arc glows until you clear. An uncleared make does no damage: "TAKE IT BACK!" and you go to CHECK. Physical hits still count either way. Bosses clear automatically after 2 s with the ball.
- **BOSS OFFENSE:** the boss attacks you with its moveset. Its composure regenerates twice as fast while it holds the ball.
  - **Showboat:** bosses sometimes stop to show off (between-the-legs, finger spin). That's a telegraphed window: strip it for double composure damage. If they finish it, their composure fully refills.
  - **Statement Dunk:** when in the paint with the ball, a boss may go up for a big telegraphed dunk on its own hoop. If it lands: boss heals 8% Heart, composure refills, then CHECK (your ball). If you **Reject** it (Jump + LB on the cue): LOOSE BALL and −40 boss composure.
  - Your strip → LOOSE BALL biased to you.
  - Ball out of bounds → CHECK, your ball ("out on them").
- **GAME POINT:** when boss Heart hits 0, it collapses SHOOK permanently, the ball goes to your hands, and the banner reads GAME POINT. Score any bucket to end it. That last bucket is always a highlight-reel moment.
- **Phases:** at 50% Heart (when the boss has a Phase 2 at that tier, §9.1), the boss is invulnerable for a 3 s transition, the arena changes, then CHECK.
- **Locking in:** after each of your makes, the boss's contest radius grows 5% (stacks to +30% per phase). Spamming threes stops working; ankle-breakers and posters keep working.
- Why the boss gets the ball back on its own makes but you keep yours: "challenger's rules." It's their court; you have to earn it.

### 7.10a Revision R7 (playtest): basketball first

This amends §7.10. Numbers live in `data/tuning/bosses.json` → `duel.r7`.

- **Every boss has a basketball profile** (`hoops` in its data): a theme line, 0–100 ratings (inside, mid, three, dunk, handles, strength, defense, steal, block) and tendencies (ball_hunger, pressure, gamble, shot_mix). The Mic Check card shows the theme and the top three ratings.
- **On offense you score; punches are light.** While it's your ball, your hits on the boss deal ×0.35 damage. Composure damage is unchanged, so ankles, SHOOK and posters still work. Buckets (§11.5) are the damage.
- **Turnovers.** Damage the boss deals you during your possession fills a turnover meter: 30% of your max Heart (a big hit or two), raised by Handles (up to +60%). When it's full the ball pops loose toward the boss.
- **The boss defends like a defender.** It holds a guard distance set by `pressure` (3 m → 1.2 m), stays between you and the rim, and closes out when you gather a shot. It reaches for the ball by `gamble`: a short telegraphed swipe whose hit is a steal roll (its steal rating against your Handles). A crossover through it is an ankle-breaker as usual.
- **Loose balls.** `ball_hunger` sets how hard the boss chases loose balls and rebounds instead of swinging at you.
- **On defense you take it back.** Hit the boss while it holds the ball and it coughs it up once the damage passes 4.5% of its max Heart, scaled ×0.7–×1.6 by its handles. Hands Up strips still work.
- **Boss offense.** The boss picks a shot from its `shot_mix`: a drive for a layup or dunk, a mid-range pull-up, or a three. Stationary phases shoot from their seat.
  - **Body-up:** driving through you slows it, by your Body and Heart against its strength.
  - The gather is telegraphed (the red cue), then the release.
  - **Make chance** = its rating for the shot, lowered by your contest distance, your Body (most at the rim) and your Heart (a healthy defender is harder to score on).
  - **Timed contest:** Hands Up, a strike or a Rejection pressed right on the release blocks the shot (window 4 frames, plus Hands, up to 12; the ball goes loose toward you). Pressed up to 10 frames early, it alters the shot (×0.45).
  - Misses are live rebounds, and you can board them on the ring.
- **A boss bucket costs you Heart:** layup 7%, mid 8%, three 10%, dunk 12% of your max, +5% per tier above 1. Then CHECK, your ball. The Statement Dunk is the boss's dunk: it still has its slam hitbox and it's still Rejectable, but it **scores on you instead of healing the boss**.
- **Shot style** (revision 11, `hoops.offense`): a boss can override its shot mix with a fixed `style`, plus a `settle_s` before the gather, a slower `gather_f`, and `calm_until_hit`. The Stoop Queen only lays it in: about 1.4 s to settle and a 54-frame gather, so you can run up and punch it loose. She doesn't swing while she holds the ball until you hit her. Then she's provoked for 4 s and swings back (75% per check, 1.2 s apart, no showboats).
- **Swinging with the ball.** Bosses still throw attacks while holding the ball (projectiles, sweeps) at ×0.5 damage. They don't lob their own ball away.
- **HUD:** a possession line (YOUR BALL / THEIR BALL / LOOSE BALL) with a meter showing how close the ball is to coming loose.

### 7.11 Composure

- Enemies and bosses fill composure damage up to a max; at max, they break.
- **SHOOK** (broken by offense: ankle-breakers, heavy passes, makes): boss stumbles or sits down for 3.0 s. Ball stays with you. POSTER or WIDE OPEN shot available.
- **STAGGER** (broken by defense: strips, deflects, rejections): 2.0 s, ball loose (biased to you).
- At Tier 4+, SHOOK/STAGGER durations shrink 0.2 s per tier (floor 2.0 s / 1.4 s).
- Regen: 6%/s after 2 s without composure damage (×2 while holding the ball).

### 7.12 Damage formula

`damage = (move_base + ball_attack × scaling(stat, grade)) × ball_upgrade_mult × crit × buffs × (1 − target_DR)`

- `ball_upgrade_mult = 1 + 0.08 × upgrade_level`.
- Tier multipliers apply to enemy HP and enemy damage, not your damage.
- Bucket damage against bosses uses §11.5 (percentage floor + stat bonus), which is what lets a skilled player beat bosses under-leveled.

### 7.13 A boss fight, beat by beat (intent)

Chain gate slams shut. Mic Check: "SHE HAS BEEN ON THAT STOOP SINCE BEFORE YOU WERE BORN." Title card. The Stoop Queen checks you the ball. You pound-dribble into her shins twice, she telegraphs a slipper throw, you crossover through it on the frame: ANKLES, she wobbles but doesn't break. You stepback to the arc and let it fly: SPLASH. Make it, take it. She's mad. Next possession you get greedy with a contested three, she swats it into the street and knocks you flat. Her ball. She lobs from the stoop; you Reject the lob, scramble for the loose ball, dribble out past the arc (cleared), cross her up twice more, she breaks: SHOOK. You sprint in. POSTERIZED. At half health she stands up, the stoop crumbles, and the real fight starts.

### 7.14 Feel requirements (non-negotiable)

Hitstop (3–8 frames by hit weight), screen shake (toggleable), squash-and-stretch on ball and bodies, impact particles (concrete chips, sparks, feathers), speed lines on sprint, slow-mo on ankle-breakers, POSTER freeze-frame, chain-net "ching" on outdoor makes, swish on indoor nets, controller rumble, camera punch-in on dunks. Input buffering 8 frames for attacks/dodges. Coyote time 5 frames on ledges.

---

## 8. Enemies

### 8.1 Street archetypes (Tier 1 base values)

| Archetype      | HP  | Dmg | Composure | Speed m/s | Rep | Tokens | Behavior                                                                                                                                            |
| -------------- | --- | --- | --------- | --------- | --- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Ball Hog**   | 120 | 25  | 40        | 4.5       | 50  | 10     | 2-hit dribble combo, lunge pound. Slow, readable.                                                                                                   |
| **Showboat**   | 90  | 20  | 30        | 6.0       | 55  | 12     | Fast, fake-out lunges, taunts mid-fight (hitting a taunting Showboat = instant stagger).                                                            |
| **Big Man**    | 300 | 45  | 120       | 3.5       | 120 | 20     | Body-check charge, two-hand slam AoE (3 m). **Dunk finisher:** if you're knocked down nearby, he leaps to dunk on you (a grab; dodge to roll away). |
| **Sniper**     | 80  | 30  | 30        | 4.0       | 60  | 12     | Perches on fire escapes/stoops/rooftops. Lob mortars (ground reticle telegraph) and bullet chest passes. Lobs are Rejectable.                       |
| **Hype Man**   | 100 | 10  | 40        | 5.0       | 70  | 15     | Boombox aura: allies within 8 m get +25% speed and damage. Flees you. Smash the boombox (2 hits) to kill the aura.                                  |
| **Pickpocket** | 70  | 10  | 25        | 7.5       | 60  | 40     | Grab attack steals your ball and runs. Tires after 6 s. Swipe or shove to get it back.                                                              |

### 8.2 Critters

- **Pigeons** (swarms of 5–10, 8 HP each, 5 dmg pecks, scatter when hit). Bronx and Uptown rooftops.
- **Rats** (15 HP, 6 dmg, fast). Alleys and tunnels.
- **Pizza Rat** (rare, 40 HP, harmless, flees with a slice; kill = 150 tokens). One hidden per district.
- **Gulls** (Staten Island, Coney): dive-bomb and snatch 5% of carried tokens; kill to get them back.
- **Night Deer** (Staten Island): 200 HP straight-line charge.

### 8.3 Borough uniques

Breaker (Bronx), Fixie Rider (Brooklyn), Juggler (Queens), Gull/Night Deer (Staten Island), Pigeon Keeper (Uptown), Suits / Big Head Mascots / Tourists (City). Base values ≈ the closest archetype ±20%.

### 8.4 Elites & specials

- **Crew Captain:** any archetype ×1.6 HP, glowing bandana, one extra move, Rep ×3, 25% chance to drop a Box Key.
- **Bootleg (mimic):** 260 HP, 40 dmg, 80 composure, lunging bite grab, 150 Rep, 60 tokens + a real shoebox's loot.
- **Pickup Challengers:** named NPC hoopers who use the player's own moveset through an AI brain (same combat code). Two per borough, in rec gyms or park courts with a hoop, using court rules. Original names only (e.g., Glide, Sweet Pea, Knots, Wheels, Cookie, Tiny Tornado, Mr. Fundamental, Static Steve, Lefty Lou, Double Dribble Dee). Drop rare kicks or a mixtape.
- **Deuce (Rival):** Pickup Challenger rules, 3 scripted encounters (§3.5).

### 8.5 AI

- States: Idle/Patrol → Alert (sees you within 18 m and 120° FOV, or hears combat within 12 m) → Engage → Recover → Leash (returns home if pulled 35 m from spawn; heals while leashing).
- Attack tokens: max 2 attackers at once (3 at Tier 5+). Others circle at 4–6 m and taunt.
- Commons respawn when you rest. Crew Captains, Bootlegs, and challengers don't.
- Tier ≥ 3: Crew Captains appear in groups. Tier ≥ 5: commons get +1 combo hit and 20% faster recovery.
- **Defending against spam** (revision 12, `tuning/ai.json → defense`): commons, uniques and elites count your hit streak (hits less than 1 s apart). From the 3rd hit, each hit rolls a reaction (30% + 15% per extra hit, +10% per tier above 1, max 85%) that cancels their hitstun:
  - **Parry:** a 22-frame parry window. Your next punch is DEFLECTed, and they counter.
  - **Dodge:** 16 i-frames and a 2.6 m slide out of the string.
  - **Counter:** hyper armor and their fastest attack, right away.

  There is a 2 s cooldown between reactions. Critters, tourists and bosses don't defend this way.
- **Projectiles are drawn** (revision 11): every live projectile hitbox gets a glowing body, a trail and a ground shadow, and wide gust arcs (5 m and longer) show as a translucent fan. Moves can set `projectile.look` / `color` / `visual_radius`.

### 8.6 Tier application

On spawn: HP, damage, composure, rewards × tier multipliers (§11.1). Moves tagged `min_tier` are filtered. Loot tables shift rarity weights by tier.

---

## 9. Bosses

### 9.1 Rules for every boss

- **Arena:** half-court with a painted 3-point arc (6.75 m), regulation rim (3.05 m; it looks hilariously small next to giants, which is the point), the hoop behind the boss. Apron size per boss in data (15×14 m minimum, up to 30×26 m for giants).
- **Entry:** walk through the court's chain-link gate; it slams shut and padlocks. Mic Check intro line + comic title card (boss name in graffiti type, title underneath). Then CHECK.
- **Death:** your chain drops just outside the gate. Gate reopens on your next approach.
- **Phases by tier:**
  - Tier 1: Phase 1 only, base moves only.
  - Tier 2: adds moves tagged (T2).
  - Tier 3–4: Phase 2 at 50% Heart.
  - Tier 5+: Phase 2, plus the listed T5+ move/event at 25% Heart.
  - City (T6) and Garden (T7): everything.
- **HUD:** boss name, Heart bar, Composure bar under it.
- **Rewards:** Rep, tokens, listed drops. Borough Kings give that borough's **Crown** (also +1 tattoo slot).
- **Re-entry:** beaten bosses' courts become open courts (free practice with a crate hoop; Pickup Challengers sometimes show up there).

### 9.2 Move primitive library

Every boss move is one of these primitives plus data (telegraph, frames, damage, composure damage, parryable, unblockable flag, `min_tier`, phase, weight, range, cooldown, possession requirement).

| Primitive        | Description                                                                         |
| ---------------- | ----------------------------------------------------------------------------------- |
| `melee_arc`      | Swing with an arc hitbox (angle, radius)                                            |
| `lunge`          | Linear dash with hitbox along the path                                              |
| `charge_lane`    | Long dash along a predefined lane/track                                             |
| `grab`           | Cone/box check → scripted grab sequence; usually unblockable red                    |
| `projectile`     | Thrown ball or object, straight line                                                |
| `lob`            | High arc to a ground reticle; Rejectable if it's the ball                           |
| `ring_wave`      | Expanding ring shockwave (jump it)                                                  |
| `slam_circle`    | Ground AoE circle                                                                   |
| `line_sweep`     | Sweeping beam/line across the arena                                                 |
| `zone`           | Persistent hazard area (puddle, fire, electrified lane)                             |
| `summon`         | Spawn minions or clones                                                             |
| `arena_event`    | Environment hazard (train, cannons, flood, cage shrink, deck tilt, wind, lightning) |
| `showboat`       | Taunt/buff, a punishable window                                                     |
| `statement_dunk` | Boss dunk (scores on you per §7.10a; Rejectable)                                    |
| `reposition`     | Leap, teleport, submerge, fly                                                       |
| `mirror`         | Replays recorded player actions as attacks                                          |
| `stance`         | Temporary state (guard, shell, hyper armor)                                         |

Boss brain: every think tick, filter moves by phase, tier, cooldown, range, and possession; pick by weight with a penalty on recently used moves; run the possession behaviors (§7.10: clear, showboat, statement dunk, contest your shots).

### 9.3 Roster

Legend: (T2) = added at Tier 2+. ★ = build first as the reference boss.

#### THE BRONX

**`bx_crab` — KING CRAB — "Terror of the Market Docks"** (mini, indoor)

- _Arena:_ Fish market hall at night: ice bins, hanging scales, forklift lights. Hoop bolted over a loading-dock door.
- _Look:_ 3 m wide red crab, tank top, backwards cap. Dribbles with the small claw; the big claw is the threat.
- _Gimmick:_ Moves sideways. **Shell Up** blocks all frontal damage for 4 s; get to his flank (he turns slowly while shelled).
- _Moves:_ Sidewinder (lateral scuttle rush; dodge forward or back, not sideways) · Claw Pinch (grab, deflectable) · Double Dribble Claws (3-hit ball combo, strippable) · Shell Up (stance) · Bubble Spray (cone, slows 40% for 3 s) · (T2) Ice Slide (long-reach slide across the ice patch).
- _Phase 2 — Molt:_ shell cracks off: +30% speed, takes +25% damage, adds Snap-Snap (fast 2-hit; second hit unblockable).
- _T5+:_ Crate Avalanche (ice crates drop in a telegraphed grid).
- _Drops:_ Shell Ball, flash: Claw.
- _Mic Check:_ "He walks sideways, he talks sideways, and he WILL pinch you."

**`bx_silverback` — SILVERBACK — "The Zoo Breaker"** (mini)

- _Arena:_ Court beside a broken zoo fence, vines on the hoop, jungle shadows.
- _Look:_ 4 m gorilla in a #00 jersey, headband, wrist tape.
- _Gimmick:_ **Chest Pound** buffs him (+20% damage) but is a 2 s strip window.
- _Moves:_ Knuckle Rush (two straight charges) · Ground Slam (rings, jump them) · Overhand Hurl (boulder pass, Rejectable) · Chest Pound (showboat) · Grab & Shake (unblockable) · (T2) Fence Climb (leaps down from the fence).
- _Phase 2 — Enraged:_ Statement Dunks twice as often; hangs and swings on the rim (AoE).
- _T5+:_ Stampede (three charges; the last one curves).
- _Drops:_ Primal Ball, Bag Move: Chest Pound.
- _Mic Check:_ "Somebody left the gate open. Somebody is about to regret it."

**`bx_boom` — GRANDMASTER BOOM — "Father of the Block Party"** (Bronx King)

- _Arena:_ Block-party court under the elevated tracks. Speaker stacks and a DJ booth at the baseline; the hoop is mounted on a speaker tower. String lights, neighbors dancing at the edges.
- _Look:_ 6 m giant with a boombox for a head (cassette-reel eyes, a speaker-cone mouth that pulses), gold rope chains, tracksuit.
- _Gimmick:_ **RHYTHM.** Every attack lands on the beat (92 BPM; Phase 2 100 BPM). Court lines and speakers pulse with the beat. Dodging or striking on the beat = "ON BEAT" (+5 Hype).
- _Moves:_ Bass Drop (ring on the downbeat) · Scratch (two back-and-forth line sweeps) · Mic Toss (pass bomb) · Speaker Stack (summons 2 speaker towers that pulse rings on beats 2 and 4 until destroyed) · Train Pass (arena event every ~30 s: the El rolls overhead, sparks rain in telegraphed circles) · (T2) Sample (replays your last attack back at you).
- _Phase 2 — Remix:_ 100 BPM; Rewind (replays his last three attacks in reverse order).
- _T5+ — Breakbeat:_ the music cuts out and he attacks off-beat for 10 s.
- _Drops:_ **Bronx Crown**, Bass Ball, flash: Boombox.
- _Mic Check:_ "THE BRONX! Where all of this STARTED! Hands up for the GRANDMASTER!"

#### BROOKLYN

**`bk_stoop` — THE STOOP QUEEN — "She Sees Everything"** (mini) ★

- _Arena:_ Brownstone block. Her stoop at the end; hoop mounted over her front door; neighbors in lit windows.
- _Look:_ Giant grandma (4 m sitting), floral housecoat, curlers, huge glasses, folding lawn chair, paper fan.
- _Gimmick:_ Phase 1 she never leaves the stoop. She attacks at range, and every throw leaves the ball loose in the street. Race for it, clear, and attack the stoop (the steps are the paint).
- _Moves:_ Stoop Lob (lob mortar, Rejectable) · Chancla (fast flying slipper, unblockable, body attack) · Broom Sweep (close-range sweep across the steps) · Window Watchers (neighbors drop flower pots in telegraphed circles) · "Get Off My Stoop" (fan-gust knockback cone) · (T2) Double Lob.
- _Phase 2 — She Stands Up:_ 7 m tall, the stoop crumbles, melee mode: Housecoat Spin, Lawn Chair Slam (AoE), Grandma Hug (grab), plus her ranged moves at lower frequency.
- _T5+ — Block Party Call:_ 3 Ball Hogs ("the grandkids") join for 20 s.
- _Drops:_ Pinkie (ball), flash: Rose.
- _Mic Check:_ "She has been on that stoop since BEFORE YOU WERE BORN. And she has SEEN what you did."

**`bk_barker` — THE BARKER — "Ringmaster of the Boardwalk"** (mini, indoor)

- _Arena:_ The Funhouse: hall of mirrors, tilting floor panels, hoop over a clown-mouth doorway.
- _Look:_ Tall thin ringmaster, striped jacket, top hat, cane, a mirror-polished face that reflects you.
- _Gimmick:_ **Mirror clones.** Only the real Barker casts a shadow. Hitting a clone shatters it and stuns you 0.5 s.
- _Moves:_ Step Right Up (3 clones) · Ring Toss (rings trap you 1 s) · Cane Hook (pull, deflectable) · Whack-a-Mole (fists pop from floor panels in sequence) · (T2) Shell Game (clones shuffle; follow the shadow).
- _Phase 2 — Tilt:_ panels tilt every 15 s (you and the ball slide); coaster cars burst through the wall along a track.
- _T5+ — Hall of Mirrors:_ passes ricochet off mirror walls (yours and his).
- _Drops:_ Prize Ball, flash: Ticket.
- _Mic Check:_ "Step right up! Three tries, no refunds, NO MERCY!"

**`bk_toll` — THE TOLL — "Keeper of the Bridge"** (Brooklyn King)

- _Arena:_ Cobblestones under the bridge archway, steel girders overhead, the City skyline across the water. Hoop bolted to a bridge pylon.
- _Look:_ 7 m granite troll of cut stone blocks, suspension cables for hair, rivets for freckles, an old toll booth strapped to his back, amber eyes.
- _Gimmick:_ **TOLL.** His grab "Pay Up" takes 10% of your carried tokens into the booth. Strip him while the booth glows and they spill out to collect.
- _Moves:_ Cable Whip (long sweep) · Cobblestone Rip (throws stones, leaves trip holes) · Pylon Slam · Toll Gate (barrier between you and the hoop for 6 s) · Rivet Spray (shrapnel cone) · Pay Up (unblockable grab) · (T2) Overpass (leaps into the girders, drops behind you).
- _Phase 2 — Rush Hour:_ headlight glare sweeps from the bridge above (shrinks your shot window inside the beams); traffic drums roll through.
- _T5+ — Bridge Collapse:_ debris falls in a full-arena pattern with one safe lane.
- _Drops:_ **Brooklyn Crown**, Granite Ball, Bag Move: Toll Booth.
- _Mic Check:_ "Nobody crosses without paying. NOBODY. Brooklyn, make some noise for THE TOLL!"

#### QUEENS

**`qn_express` — THE EXPRESS — "Last Train Out"** (mini)

- _Arena:_ Elevated platform court above the avenue; tracks along both edges; hoop on the end-of-platform barrier; night market glowing below.
- _Look:_ A living three-car subway train, silver with an original color stripe, a grinning face on the front cab, doors like mouths.
- _Gimmick:_ **TRACKS.** Painted lanes show where it can charge. Every door attack is cued by a two-tone chime and "stand clear of the closing doors."
- _Moves:_ Express Charge (lane dash) · Door Chomp (grab, chime cue) · Car Whip (tail swipe) · Spit Pass (doors fire the ball) · Third Rail (one lane electrified 4 s) · (T2) Local (three hops with AoE landings at "stations").
- _Phase 2 — Decouple:_ three cars attack independently (shared HP; the front car holds the ball).
- _T5+ — Rush Hour Crowd:_ commuter silhouettes fill lanes (block movement only).
- _Drops:_ Third Rail Ball, flash: Express.
- _Mic Check:_ "This is the LAST TRAIN. Stand clear of the closing doors, kid."

**`qn_sauce` — EXTRA SAUCE — "Chef of the Night Market"** (mini, indoor)

- _Arena:_ Food hall at closing time; steam, string lights, stall counters; hoop on a food truck parked inside.
- _Look:_ A huge cheerful chef riding a living street cart (the awning is its face), two giant squeeze bottles (white and red) holstered like pistols.
- _Gimmick:_ **SAUCE ZONES.** White puddles slow 40%; red puddles burn (DoT + faster Wind drain); standing in both = "the combo" burst. Puddles last 12 s.
- _Moves:_ Squeeze Spray (cone, leaves puddles) · Cart Rush · Tong Grab · Steam Vent (AoE around the cart) · Flip the Ball (spinning pass) · (T2) Lid Slam (wok-lid bash; deflects your passes).
- _Phase 2 — Extra Extra:_ sauce lines sweep the floor in patterns; the cart flips into a shield.
- _T5+ — Rush Order:_ 3 Jugglers join for 20 s.
- _Drops:_ Spice Ball, Bag Move: Steam Fake.
- _Mic Check:_ "You want it MILD? There IS no mild! EXTRA! SAUCE!"

**`qn_atlas` — ATLAS — "Holder of the World"** (Queens King)

- _Arena:_ Fountain plaza around the giant steel globe; hoop on the globe's base; fountains ring the arena.
- _Look:_ 8 m bronze titan with green patina, carrying a lattice steel globe as his ball. Steal it and it shrinks to basketball size in your hands; he takes it back and it grows.
- _Gimmick:_ **ORBITS.** Three glowing rings rotate around him at different heights/speeds. Low ring: jump. High ring: slide under. Rings vanish while he's SHOOK.
- _Moves:_ Orbit Spin (rings speed up 4 s) · Gravity Well (pulls you in 2 s) · World Toss (globe pass, huge landing AoE, Rejectable) · Fountain Jets (water pillars at telegraphed spots) · Titan Stomp · (T2) Meridian (a light line sweeps the arena).
- _Phase 2 — Weight of the World:_ he drops the globe; it rolls around as a boulder hazard; he fights with ring-fists; the fight ball becomes normal-size bronze.
- _T5+ — Eclipse:_ darkness except the rings and your ball's glow for 15 s.
- _Drops:_ **Queens Crown**, Orbit Ball, flash: Globe.
- _Mic Check:_ "He's been carrying the WORLD on his back. Let's see if he can carry THIS L."

#### STATEN ISLAND

**`si_ferryman` — THE FERRYMAN — "Free Fare, No Return"** (mini)

- _Arena:_ Open deck of the orange ferry crossing the harbor at night, a distant green statue's torch glowing. Hoop on the wheelhouse.
- _Look:_ Tall, gaunt, bobbing, orange rain slicker with the hood up, lantern, sea-green glowing eyes. Spooky but playful.
- _Gimmick:_ **TIDE.** Every 20 s the deck tilts; you and loose balls slide downhill; waves wash across (knockback). Pushed off the rail = heavy damage, respawn on deck.
- _Moves:_ Lantern Swing · Undertow (pull toward the rail) · Fog Horn (stun ring) · Fare (grab, takes 5% tokens) · Rope Line (trip line across the deck) · (T2) Man Overboard (dives off, resurfaces elsewhere).
- _Phase 2 — Fog Bank:_ visibility 12 m; he lunges out of the fog (listen for the lantern creak).
- _T5+ — Storm:_ waves every 8 s.
- _Drops:_ Lantern Ball, flash: Anchor.
- _Mic Check:_ "The ride is free. Getting OFF is gonna cost you."

**`si_general` — THE GENERAL — "Ghost of the Old Fort"** (mini)

- _Arena:_ The old fort's courtyard on the cliff; cannons on the ramparts; the Narrows Bridge lit behind. Hoop on the fort gate.
- _Look:_ A weathered stone statue of an old general fused with his horse, centaur-like, moss in the cracks, glowing eyes.
- _Gimmick:_ **CANNONS.** He orders volleys (lit fuses + red reticles). Hit a cannon with a pass while its fuse is lit and it turns and fires at him (big composure damage).
- _Moves:_ Cavalry Charge · Rearing Stomp · Volley · Salute (showboat) · Saber Ball (sweeping ball swing) · (T2) Flank (circles at a gallop, then cuts in).
- _Phase 2 — Dismount:_ rider and horse split (shared HP). The horse charges; the rider handles the ball.
- _T5+ — Siege:_ every cannon fires in a rolling sequence with one safe lane.
- _Drops:_ Cannonball (ball), flash: Star.
- _Mic Check:_ "Two hundred years on guard duty. He is NOT in a good mood."

**`si_heap` — KING OF THE HEAP — "Lord of the Landfill"** (Staten Island King)

- _Arena:_ Top of the landfill hill under orange floodlights; trash ridges; gulls circling. Hoop built from a bent shopping cart and a bike rim on a tower of tires.
- _Look:_ 9 m trash colossus: trash-bag body, mattress chest, shopping-cart arms, a TV head with a static face, a crown of hubcaps.
- _Gimmick:_ **ARMOR + SHOT CLOCK.** He absorbs trash into armor (a white bar over his Heart; heavy hits and buckets strip it). Gulls are the shot clock: hold the ball more than 6 s without shooting or passing and they dive and snatch it (a timer ring shows around you).
- _Moves:_ Bag Avalanche (rolling bags down the slope) · Fridge Slam · Cart Grab · Compactor (two-arm clap, unblockable) · Methane Vent (fire jets) · Absorb (rebuilds armor; interrupt with a bucket or heavy pass) · (T2) Recycle (throws three objects; one is the ball).
- _Phase 2 — Collapse:_ crumbles into a trash wave, reforms bigger; a garbage truck sweeps a lane every 25 s.
- _T5+ — Fresh Load:_ a dump truck pours a pile that becomes 3 Trash Minions (Ball Hog stats).
- _Drops:_ **Staten Island Crown**, Junk Ball, Bag Move: Trash Talk.
- _Mic Check:_ "Everything this city ever threw away ended up HERE. And it CHOSE A KING."

#### UPTOWN

**`up_hook` — THE HOOK — "Amateur Night Executioner"** (mini, indoor)

- _Arena:_ Grand old theater stage, red curtains, footlights, a packed balcony of silhouettes. Hoop hangs from the fly rail at center stage under a spotlight.
- _Look:_ Tall vaudeville villain in a tux and tap shoes, pencil mustache, one arm ending in a giant shepherd's-crook hook.
- _Gimmick:_ **CROWD.** An Applause meter. Style plays fill applause; getting hit and whiffing fill boos. Full boos → "Get Off The Stage!" (hook grab, massive damage). Full applause → roses rain and the spotlight blinds him (free SHOOK).
- _Moves:_ Hook Yank (pull, deflectable) · Tap Routine (rhythmic stomp waves) · Curtain Call (curtains drop as moving walls) · Trapdoor (telegraphed floor drops) · Cane Juggle (showboat) · (T2) Encore (repeats his last combo faster).
- _Phase 2 — Spotlight Hunt:_ lights go down; he takes full damage only while lit.
- _T5+ — Standing Ovation:_ the crowd rushes the stage edges, shrinking the arena.
- _Drops:_ Spotlight Ball, Bag Move: Showstopper.
- _Mic Check:_ "Amateur Night! You know the rules. If they boo... THE HOOK COMES OUT."

**`up_coop` — THE COOP KING — "Lord of the Rooftops"** (mini)

- _Arena:_ Tar rooftop with a pigeon coop and water tower; the big bridge glowing far off. Hoop on the water tower's legs.
- _Look:_ Hundreds of pigeons in the shape of a guy in a hoodie, with a glowing white racing pigeon in his chest (the core).
- _Gimmick:_ **SWARM.** Hard hits disperse his body (walk through him); he reforms in 2 s. The core is exposed for 3 s whenever he throws or passes; core hits do triple damage and full composure.
- _Moves:_ Flock Lunge (pigeon stream) · Feather Storm (vision cloud) · Homing Pass · Coop Drop (cage trap, mash out) · Roost (perches on the tower, snipes) · (T2) Split Flock (two half bodies; one has the core).
- _Phase 2 — Takeoff:_ he flies; roof edges crumble; Reject his dive-dunks.
- _T5+ — Murmuration:_ a giant swarm wave sweeps the roof.
- _Drops:_ Feather Ball, flash: Wings.
- _Mic Check:_ "You see a bird? That's HIM. You see a hundred? STILL HIM."

**`up_highrise` — HIGH RISE — "Legend of the Mecca"** (Uptown King)

- _Arena:_ The legendary park court on 155th: packed bleachers, chain-link, towers behind, all of Uptown watching.
- _Look:_ 10 m tall, impossibly lanky, crane arms, high socks, number 0, head above a ring of clouds.
- _Gimmick:_ **REACH.** The purest basketball fight. His contest radius covers half the court, so normal shots get Rejected ("Not in my house!"). Win with ankle-breakers, stepbacks, and posters.
- _Moves:_ Wingspan Sweep · Finger Wag (block + punish) · Giant Step · Crossover Quake (his crossover sends a sideways line of shockwaves) · Self Oop (statement dunk off the backboard, Rejectable) · Cloud Burst (rain, slippery court 10 s) · (T2) Long Arm (strip from 6 m).
- _Phase 2 — Elevation:_ he grows to 12 m, the camera pulls back, his cloud becomes a thunderstorm (telegraphed lightning).
- _T5+ — Downtown:_ statement threes from anywhere (Rejectable only with perfect timing).
- _Drops:_ **Uptown Crown**, Mecca Ball, flash: Crown.
- _Mic Check:_ "Every legend in this city came through THIS court. Every one of them got WALKED by HIM."

#### THE CITY (Tier 6; any order; each awards a Garden Ticket stub)

**`city_chainlink` — CHAIN LINK — "Warden of the Cage"** (The Cage)

- _Arena:_ The famously tiny caged court in the Village; fence on all sides; faces pressed against the links.
- _Look:_ Hulking figure woven from chain-link and padlocks, a referee whistle he never blows.
- _Gimmick:_ **SHRINKING CAGE.** Every 30 s the walls move in 1.5 m (reset on phase change). Fence contact = shock damage. Hyper armor on most attacks, so strips and deflects are your main tools.
- _Moves:_ Lock Up (grab) · Padlock Flail · Fence Slam (fence wave) · No Call (unblockable counter right after you strip him) · Clamp · Cage Match (summons 2 Suits).
- _Phase 2 — Electrified:_ fence crackles; walls move every 20 s.
- _Drops:_ Chain Ball, flash: Chain Link.
- _Mic Check:_ "No blood. No foul. No WAY out."

**`city_suspension` — SUSPENSION — "The Steel Weaver"** (The Bridge)

- _Arena:_ The old bridge's wooden promenade at the stone tower with pointed arches; cables everywhere; the river far below.
- _Look:_ Spider-like titan of steel cables and gothic stone arches, lamplight eyes.
- _Gimmick:_ **TENSION.** Some cables are zip-lines you can ride (Interact). Striking glowing anchor points snaps cables and costs him balance (composure).
- _Moves:_ Cable Lash · Web Net (trap zone) · Arch Drop · Tension Snap (cables whip across lanes) · Weave (ball bounced along cables at angles) · Tower Leap.
- _Phase 2 — Sway:_ the promenade sways (tilt, sliding); planks collapse into gaps.
- _Drops:_ Cable Ball, flash: Bridge.
- _Mic Check:_ "This bridge has held for over a hundred years. Tonight it holds HIM."

**`city_primetime` — PRIME TIME — "The Jumbotron"** (The Crossroads)

- _Arena:_ The screens plaza: billboard canyon, red stairs, tourists everywhere. Hoop on a giant screen frame.
- _Look:_ Titan of LED billboard panels; its face is a screen showing replays of you.
- _Gimmick:_ **REPLAY.** Records your last 5 moves and throws them back at you. Tourist flashes blind you 0.8 s (white flicker cue first).
- _Moves:_ Replay · Commercial Break (screens "advertise" the next attack, then it happens) · Pixel Storm · Billboard Fall · Breaking News (ticker beam sweep) · Highlight Reel (3-attack combo of your most-used moves).
- _Phase 2 — Live:_ splits into 3 channel bodies; only the one showing "LIVE" is hittable.
- _Drops:_ Replay Ball, flash: Mic.
- _Mic Check:_ "The whole world is WATCHING. Smile for the cameras... while you still got teeth."

**`city_gator` — THE GATOR — "Legend of the Sewers"** (The Underground)

- _Arena:_ Abandoned subway station with tiled vaults, chandeliers, and skylights. Floods.
- _Look:_ 12 m albino alligator, gold chain, sewer-grate crown.
- _Gimmick:_ **FLOOD.** Water rises and falls on a cycle. In high water he submerges and ambushes (watch ripples). When the third rail sparks, get out of the water.
- _Moves:_ Death Roll (unblockable grab) · Tail Sweep · Chomp · Submerge & Ambush · Mud Spit (blind) · Tile Smash.
- _Phase 2 — Deep End:_ water stays high; floating debris is your footing.
- _Drops:_ Gator Ball, flash: Scale.
- _Mic Check:_ "They told you he was an urban legend. They LIED."

**`city_gargoyle` — THE GARGOYLE — "Eagle of the Spire"** (The Summit)

- _Arena:_ Rooftop court near the top of an art deco tower, steel eagle ornaments jutting out, the city lit below.
- _Look:_ Steel eagle gargoyle, wings like hood ornaments.
- _Gimmick:_ **WIND.** Gusts push you and curve your shots (meter shows a drift arrow; correct with the left stick during gather). He snatches the ball and flies; Reject his dive-dunks to get it back.
- _Moves:_ Talon Dive · Wing Gust · Spire Perch (pass bombs from the ornaments) · Updraft (lifts you; you can Tomahawk from the air) · Steel Feathers (projectile spread) · Ledge Shove.
- _Phase 2 — Storm Front:_ rain, lightning, gusts every 6 s.
- _Drops:_ Gale Ball, flash: Skyline.
- _Mic Check:_ "Look DOWN. That's the whole city. Now look UP. That's the last thing you'll see."

#### THE GARDEN (Tier 7)

**`fin_midnight` — MIDNIGHT — "The Last Legend"**

- _Arena:_ The Garden at night. Empty seats in darkness, one spotlight, the scoreboard frozen at 3:00.
- _Phase 1 — Warm-Up (2.5 m):_ silver hair, vintage warm-up suit, impossibly smooth. He uses your systems on you: dodge carelessly into his crossover and **you** go SHOOK (player-side stagger, 1.2 s); he strips, stepbacks, posters. Pure duel.
- _Phase 2 — Prime (5 m):_ his glowing younger self. The stands fill with ghostly silhouettes of every legend you beat. He uses one signature move from each Borough King and Landmark boss (reuse their move data): Bass Drop, Cable Whip, Orbit Spin, Compactor, Finger Wag, Cage Shrink, Replay, Death Roll, Talon Dive, Cable Lash.
- _Phase 3 — Overtime (15 m shadow with a clock face):_ the scoreboard counts down 60 s to midnight while the arena flickers through every landmark. At 0 he unleashes **MIDNIGHT** (full-screen unblockable). Perfect crossover through it = Ankle Breaker → SHOOK → the game's final POSTER. Miss it and you take 90% max Heart (not instant death) and the clock resets to 30 s.
- Three separate Heart bars (one per phase). GAME POINT only in Phase 3. Then the ending choice (§3.7).
- _Drops:_ Midnight Ball, flash: Midnight.
- _Mic Check:_ "Ladies and gentlemen... he never left. He never retired. He never let the night end. MIDNIGHT."

#### OPTIONAL

**`opt_ratking` — PIZZA RAT KING** — hidden tunnel between Brooklyn and Queens (tier = the higher of the two). Giant rat with a pizza-box crown riding a pile of rats. Summons swarms; eats slices to heal (strip the slice to deny it). Drops: flash: Slice, a pile of tokens.

**`opt_pops` — POPS, IN HIS PRIME** — your starting court after five Crowns, Tier 6. Human-size, flawless fundamentals, no gimmicks. Drops: Old Head Ball, flash: Clock.

**`rival_deuce` — DEUCE** — three duels (current borough tier; the third at Tier 6). Uses the player AI. Drops: Deuce's Band (legendary headband), Bag Move: Iso.

Required fights: 15 borough + 5 landmark + Midnight = **21**. Optional: 3.

---

## 10. Gear & items

### 10.1 Slots

Ball ×2 (quick swap) · Kicks · Fit · Headband · Sleeve · Chain ×2 · Bag Move ×1 · Tattoos (2 slots at start, +1 per Crown, 7 max).

### 10.2 Rarity

Common (white) · Rare (blue) · Epic (purple) · Legendary (gold) · **Grail** (red; one-of-a-kind sneakers and gear).

### 10.3 Shoeboxes

Fictional brands only, with original simple geometric logos (nothing resembling real brand marks):

| Brand    | Mark            | Loot pool                                  |
| -------- | --------------- | ------------------------------------------ |
| AIRWAVE  | Wing            | Bounce/dunk gear                           |
| KONG     | Fist            | Heart/Body gear                            |
| STRATA   | Three bars      | Jumper gear                                |
| VELOCI   | Arrow           | Handles/Wind gear                          |
| LOCKDOWN | Padlock         | Hands/defense gear                         |
| GHOST    | Plain black box | Random: tattoo flash, mixtapes, rare balls |

Box tiers: **Retail** (T1 odds: Common 70 / Rare 25 / Epic 5), **Limited** (Rare 60 / Epic 35 / Legendary 5; often locked), **Grail** (fixed legendary/grail item; one hidden per borough). Rarity odds shift by tier (§11.1). Every item has 1–2 lines of playful flavor text.

### 10.4 Balls (weapons)

Scaling grades for the relevant stats; upgrade +0 to +10 (§10.9).

| Ball            | Source                    | Scaling             | Property                                       |
| --------------- | ------------------------- | ------------------- | ---------------------------------------------- |
| Rec Ball        | Start                     | HDL C, JMP C, BDY C | Balanced                                       |
| Rubber Blacktop | Start (Enforcer)          | BDY B, JMP D        | +20% composure dmg, gather 0.60 s              |
| Leather Indoor  | Start (Shooter)           | JMP B, HDL C        | Gather 0.50 s, −10% physical dmg               |
| Taped-Up Ball   | Start (Nobody)            | all D               | At +10 it becomes **Old Faithful** (HDL S)     |
| Shell Ball      | King Crab                 | BDY B               | +poise while attacking                         |
| Primal Ball     | Silverback                | BDY B, BNC C        | 15% knockdown chance on commons                |
| Bass Ball       | Grandmaster Boom          | HDL B               | Every 3rd hit emits a shockwave                |
| Pinkie          | Stoop Queen               | HDL C, HND C        | Passes ricochet twice                          |
| Prize Ball      | The Barker                | JMP C, HDL C        | +15% crit                                      |
| Granite Ball    | The Toll                  | BDY A               | Huge composure dmg, slow, gather 0.70 s        |
| Third Rail Ball | The Express               | HDL B               | Shock chains to 2 nearby enemies               |
| Spice Ball      | Extra Sauce               | HDL C               | Burn DoT                                       |
| Orbit Ball      | Atlas                     | JMP B               | Passes curve toward target                     |
| Lantern Ball    | The Ferryman              | HND B               | Glows; reveals hidden boxes and Bootleg tells  |
| Cannonball      | The General               | BDY B               | Charged pass explodes                          |
| Junk Ball       | King of the Heap          | all C               | Random effect on each hit                      |
| Feather Ball    | The Coop King             | HDL A               | Fast, −20% Wind cost, low dmg                  |
| Spotlight Ball  | The Hook                  | JMP B               | Perfect makes always crit                      |
| Mecca Ball      | High Rise                 | JMP A               | Shot windows +20%                              |
| Chain Ball      | Chain Link                | BDY B, HND B        | Can't be stolen                                |
| Cable Ball      | Suspension                | HDL B               | Pass hits pull you to the target               |
| Replay Ball     | Prime Time                | HDL B, JMP B        | Every hit echoes a 30% ghost hit               |
| Gator Ball      | The Gator                 | BDY B               | Bleed buildup                                  |
| Gale Ball       | The Gargoyle              | JMP B               | Passes knock back                              |
| Midnight Ball   | Midnight                  | all B               | Takeover lasts +50%                            |
| Old Head Ball   | Pops                      | JMP S               | —                                              |
| Glow Ball       | Bronx (GHOST box)         | HDL C               | Lights dark areas                              |
| Medicine Ball   | Brooklyn (KONG box)       | BDY S               | Massive dmg, massive Wind cost                 |
| Chrome Ball     | Queens (LOCKDOWN box)     | HND B               | Perfect parry reflects projectiles             |
| Beach Ball      | Staten Island (GHOST box) | —                   | Joke ball: slow passes, Bucket Blast radius ×2 |
| Neon Ball       | Uptown (STRATA box)       | JMP C               | +20% Hype gain                                 |

### 10.5 Wearables (seed lists; generate the rest to ~12 per slot per borough using these patterns)

- **Kicks** (movement): Classic Lows (+5% speed) · Shell Tops (+10 poise) · Street Runners (+10% dodge distance) · High-Flyers (AIRWAVE: +0.25 m jump, +dunk range) · Lockdown Mids (+2 parry frames) · Slides & Socks (joke: −15% speed, taunts +100% Hype) · Kong Force (+15% poise, +5% DR) · Strata Pro (+0.01 perfect width) · Veloci Blur (+12% speed, −25% dodge Wind) · Ghost Walkers (dodge leaves a decoy) · Grails: Concourse Kings (Bronx), Stoop Legends (Brooklyn), Seven Line (Queens), Ferry Night (Staten Island), Mecca Royals (Uptown) · Golden Hour (Grail Hunt reward, +10% to everything).
- **Fits** (armor, with weight): Light (full dodge): Tank & Shorts (DR 2%), Practice Jersey (3%). Medium (−10% dodge distance): Hoodie & Joggers (6%), Tracksuit (7%, +Wind regen), Windbreaker (6%, wind resist). Heavy (−25% dodge distance, +4f recovery): Puffer Jacket (12%), Leather Bomber (10%, +poise). Borough sets: Block Party, Boardwalk, Night Market, Ferry Night, Uptown Royal.
- **Headbands** (offense): Sweatband (+5% dmg) · Splash Band (+0.008 perfect width) · Ninja Tie (+8% crit) · Rec League (+10% Hype gain) · Bandana (+12% dribble dmg) · Deuce's Band (legendary, +3 ankle-breaker frames).
- **Sleeves** (defense/handles): Compression (+3% DR) · Shooter Sleeve (+8% gather speed) · Lockdown Sleeve (+1 parry frame) · Grip Sleeve (+ball security) · Thermal (burn resist) · Ice Sleeve (+Wind regen).
- **Chains** (2 slots, like rings): Gold Rope (+10% Rep) · Cuban Link (+8% Heart) · Dog Tags (+15 poise) · Rope Twist (slower Hype decay) · Token Chain (+10% tokens) · Bodega Key (+5% Quarter Water heal) · Whistle (enemies leash 30% sooner) · Name Plate (+5% dmg) · Pendant of the Five (all five Crowns: +2 all stats).

### 10.6 Tattoos (permanent perks)

Get a flash sheet → visit any Ink & Needle → pay tokens → it's on you for good (shows on your model). **Laser removal** costs 3,000 × tier-price tokens and destroys the flash sheet. Slots: 2 at start, +1 per Crown, 7 max.

| Tattoo     | Effect                                                  | Source                  |
| ---------- | ------------------------------------------------------- | ----------------------- |
| Crown      | +10% damage at full Heart                               | High Rise               |
| Clock      | Heart < 30%: shot windows +35%                          | Pops                    |
| Wings      | +20% jump height, +10% dunk range                       | Coop King               |
| Rose       | Once per rest, survive a lethal hit at 1 HP             | Stoop Queen             |
| Boombox    | Taunts give +50% Hype                                   | Grandmaster Boom        |
| Claw       | Strips also deal 40 dmg (scaled)                        | King Crab               |
| Ticket     | +15% tokens                                             | The Barker              |
| Anchor     | +30% guard stability, 50% resist to pushes (tide, wind) | The Ferryman            |
| Globe      | Passes curve toward the locked target                   | Atlas                   |
| Star       | +20% composure dmg on dunks/posters                     | The General             |
| Express    | +8% move speed; sprint is free out of combat            | The Express             |
| Flame      | Takeover +4 s                                           | Bronx GHOST box         |
| Dice       | 10%: a make deals double bucket damage                  | Queens GHOST box        |
| Brick      | Your misses deal 30 dmg near the rim                    | Staten Island GHOST box |
| Hustle     | Loose-ball pickups: +5 Hype, +10% speed 3 s             | Uptown GHOST box        |
| Chain Link | +15% DR, −5% speed                                      | Chain Link              |
| Bridge     | Chest Pass +40% range, one extra ricochet               | Suspension              |
| Mic        | Ankle-breakers give double Hype                         | Prime Time              |
| Scale      | +25% status resist (bleed, burn, shock)                 | The Gator               |
| Skyline    | +3 all stats                                            | The Gargoyle            |
| Nine Lives | Your dropped chain survives one extra death             | Lost Cat quest          |
| Slice      | Quarter Waters also give +20 Hype                       | Pizza Rat King          |
| Midnight   | Takeover usable at 75 Hype                              | Midnight                |

### 10.7 Bag Moves (LT, costs Hype)

| Bag Move    | Hype | Effect                                                                   | Source                                  |
| ----------- | ---- | ------------------------------------------------------------------------ | --------------------------------------- |
| Snatchback  | 25   | Yank the ball back, slide 4 m back, deflect one projectile               | Brooklyn mixtape / Floor General start  |
| Spin Cycle  | 30   | 360° spin, multi-hit AoE r 2 m                                           | Bronx mixtape / Slasher start           |
| Hesi        | 20   | Hesitation; next attack within 1 s does +100% composure                  | Uptown mixtape / Shooter, Two-Way start |
| Orbit       | 40   | Ball orbits you 5 s, hitting anything close                              | Queens mixtape                          |
| Third Rail  | 30   | Electrified dash through enemies                                         | Staten Island mixtape                   |
| Self Oop    | 40   | Off the ground, slam: dunk AoE anywhere                                  | Pops lesson 1                           |
| Euro Glide  | 20   | Long evasive two-step with i-frames                                      | Pops lesson 2                           |
| Rainbow Lob | 35   | Giant lob landing as 3 impact zones                                      | Pops lesson 3                           |
| Bass Drop   | 35   | Three ground shockwave rings                                             | Pops lesson 4                           |
| Tunnel      | 25   | Roll it through their legs, appear behind them, guaranteed composure hit | Pops lesson 5                           |
| Chest Pound | 40   | Taunt that heals 15% Heart                                               | Silverback                              |
| Toll Booth  | 25   | Stance that reflects the next projectile                                 | The Toll                                |
| Steam Fake  | 25   | Pump fake; steam blinds enemies 2 s                                      | Extra Sauce                             |
| Trash Talk  | 30   | Enemies within 10 m deal −25% dmg for 15 s                               | King of the Heap / Enforcer start       |
| Showstopper | 50   | Spotlight cone freezes enemies 2 s                                       | The Hook                                |
| Iso         | 50   | 3 s slow-mo bubble, ankle-breaker windows ×2                             | Deuce                                   |

### 10.8 Bodega consumables (carry max 5 each)

Chopped Cheese (+40% Heart over 20 s) · Bacon Egg & Cheese (+50% Wind regen 60 s) · Coffee in a Blue Cup (+10% speed 60 s) · Italian Ice (cures burn, +fire resist 60 s) · Sunflower Seeds (+1 Hype/s for 30 s) · Honey Bun (+10% dmg 30 s). 80–300 tokens × tier price.

### 10.9 Upgrades (Pump & Grip)

Balls +1…+10. +1–5 use **Grip Tape** (common drop); +6–10 use **Pro Grip** (Crew Captains, minis, Limited boxes). Cost: 200 × level × tier price. Each level +8% damage. Wearables don't upgrade (scope).

---

## 11. Economy & tuning (starting values; all live in `data/tuning/*.json`)

### 11.1 Tier multipliers

|                                     | T1  | T2   | T3   | T4   | T5  | T6 City | T7 Garden |
| ----------------------------------- | --- | ---- | ---- | ---- | --- | ------- | --------- |
| Enemy HP                            | 1.0 | 1.7  | 2.6  | 3.7  | 5.0 | 6.5     | 8.0       |
| Enemy damage                        | 1.0 | 1.4  | 1.9  | 2.5  | 3.1 | 3.8     | 4.5       |
| Composure                           | 1.0 | 1.25 | 1.55 | 1.9  | 2.3 | 2.7     | 3.1       |
| Rep reward                          | 1   | 2.2  | 4    | 6.5  | 9.5 | 13      | 18        |
| Token reward                        | 1   | 1.8  | 3    | 4.5  | 6.5 | 9       | 12        |
| Shop prices                         | 1   | 1.6  | 2.4  | 3.4  | 4.6 | 6       | 7.5       |
| AI attack cooldown                  | 1.0 | 0.95 | 0.9  | 0.85 | 0.8 | 0.75    | 0.7       |
| Loot shift (pts from Common upward) | 0   | 5    | 10   | 15   | 20  | 25      | 30        |

### 11.2 Base numbers

- **Player:** walk 3.5 m/s, run 6.0, sprint 8.5 (12 Wind/s), jump 1.2 m, dunk jump 2.4 m (scripted), Wind 100, Heart 300 (at 10).
- **Mini-bosses (T1):** Heart 1,800, composure 200, light 45 / heavy 90 / grab 120, Rejected punish 18% of player max Heart, contest radius 3.0 m. Rewards 2,500 Rep / 800 tokens.
- **Borough Kings (T1):** Heart 3,200, composure 300, light 55 / heavy 110 / grab 150, contest radius 3.5 m (High Rise 7 m). Rewards 5,000 Rep / 1,500 tokens.
- **Landmarks:** King base × T6. **Midnight:** King base × T7 per phase, rewards ×2.

### 11.3 Level curve

Rep to next level = `floor(100 × L^1.5 + 150)` → L1: 250 · L5: 1,268 · L10: 3,312 · L20: 9,094 · L30: 16,581 · L40: 25,448 · L50: 35,505 · L60: 46,626.
Target levels at the end of each tier: T1 ≈ 10 · T2 ≈ 18 · T3 ≈ 27 · T4 ≈ 36 · T5 ≈ 45 · City ≈ 55 · Garden ≈ 60.

### 11.4 Rewards & prices

- Common rewards: §8.1 table × tier multipliers. Crew Captain ×3 Rep.
- Shop base prices (× tier price): Common wearable 400–800 · Rare 1,200–2,000 · Epic 3,000–5,000 · Legendary 8,000–12,000 (shop stock tops out at Epic; Legendary/Grail come from boxes, bosses, quests) · Tattoo application 1,000 · Ball upgrade 200 × level · Consumables 80–300.
- Crate hoop first make: 25 tokens × tier. Pizza Rat: 150 × tier.

### 11.5 Bucket damage vs bosses (skill beats grind)

| Bucket       | % of current phase max Heart | Composure |
| ------------ | ---------------------------- | --------- |
| Close (<3 m) | 4%                           | 10        |
| Mid          | 5%                           | 15        |
| Three        | 7.5%                         | 25        |
| Deep         | 10%                          | 30        |
| Dunk         | 8%                           | 30        |
| POSTER       | 15%                          | 60        |

Plus a stat bonus: `ball_attack × scaling(JMP or BNC) × 0.5`. Multipliers: Perfect ×1.4, Wide Open ×1.5, Takeover ×1.25. Cap 22% per bucket.

### 11.6 Balancing targets

- Tier-appropriate common: dies in 3–5 light hits.
- Tier-appropriate mini-boss: 2.5–4 min per clear; boss kills you in 4–6 hits.
- Borough King: 4–6 min per clear.
- A skilled player can beat a boss two tiers above their level by scoring (by design).

---

## 12. Art direction — "Toybox Night"

### 12.1 Look

- Chunky, rounded, low-poly shapes. Flat colors with 3-band cel shading, a crisp highlight, colored rim light, thick dark outlines.
- Always night until the Daybreak ending. Sodium-orange streetlights, neon, wet asphalt reflections, steam, haze.
- Toy-diorama camera feel: high angle, narrow FOV, subtle tilt-shift blur.
- Comic-pop moments: halftone, speed lines, sticker-style text pops ("ANKLES!", "SPLASH!", "POSTERIZED!", "COOKED").

### 12.2 Palettes (hex)

| Region        | Primary | Secondary | Base                     |
| ------------- | ------- | --------- | ------------------------ |
| Bronx         | #D7263D | #F4B400   | #1B1B3A                  |
| Brooklyn      | #7B2FF7 | #12C2B0   | #1A1530                  |
| Queens        | #2BB24C | #FF7A00   | #10221A                  |
| Staten Island | #FF6B1A | #1E6FD9   | #0E1A2B                  |
| Uptown        | #2D7BFF | #F2F6FF   | #0B1426                  |
| The City      | #FFC93C | #FFFFFF   | #0A0A14 (accent #FF3EA5) |

Shared: sodium #FFB347, asphalt #1E1E24, outline #0B0B10.

### 12.3 NYC kit (all procedural first)

Brownstones (stoops, bay windows, cornices) · walk-ups with fire escapes and window AC units · high-rises with lit window grids · rooftop water towers · bodegas (awning, glowing sign, roll-down gate with graffiti) · subway entrances (railings, green globe lamps) · elevated tracks (girders; passing trains as an effect) · cobra-head streetlights · blinking-yellow traffic lights · hydrants · generic mailboxes and news boxes (no real logos) · trash bag piles · dumpsters · sidewalk scaffolding sheds · chain-link courts with chain nets · milk-crate hoops · benches and caged street trees · manhole steam with striped stacks · generic yellow cabs and boxy parked cars · murals (procedural shape patterns) · sneakers on power lines · string lights · neon signs with original text (DELI GROCERY 24HR, PIZZA, KICKS, LAUNDROMAT, BARBER, TATTOO).

### 12.3a Borough looks and the edge of the map (revision 10)

- **Each borough builds in its own palette** (`palettes.json → buildings`):
  - Bronx: red brick with gold deco trim.
  - Brooklyn: brownstones.
  - Queens: tan and yellow brick with green trim.
  - Staten Island: blue and pale clapboard with pitched roofs.
  - Uptown: limestone with white trim.
  - City: glass and steel.
  - Water-tower frequency also varies by borough.
- **Skyline profiles per borough** (`tuning/camera → skyline.profiles`): the width of the water, the height, and the mix of tower kinds. The kinds are slab, wedding-cake setback, art deco crown, needle spire, round glass and twins. Crowns are lit in the borough's accent color, and spires carry blinking beacons. A low lit waterfront lines the far shore.
- **The edge is a harbor.** A stone quay with a railing and lamps runs along the map edge, then dark water with shimmering reflected shore light runs out to a far shore. Each borough's bridges reach toward the skyline: Brooklyn suspension (stone and steel towers), Bronx steel arch, Queens green truss, Staten Island long suspension, Uptown suspension and arch. Necklace lights are emissive only. The '#' ring still stops you, so you can never cross.
- **Street hoops** use the court hoop's parts: pole, white backboard with the shooter square, orange rim and chain net. The rim and square glow while the hoop's Bucket Blast is ready.

### 12.4 Characters

- Player: ~3 heads tall, 1.35 m. Commons: 1.6–2.2 m, chunkier and taller to read as threats. Bosses: 3–15 m with unmistakable silhouettes.
- Bosses are built from primitive shapes with a per-boss builder (§15.11), each readable as a silhouette at a glance.

### 12.5 Lighting & post

Dark blue-violet sky with an orange city-glow horizon and a stylized moon · OmniLights for streetlights (distance fade; only the 4 nearest cast shadows) · volumetric fog haze · glow/bloom for neon · per-borough color grading · SSR on wet asphalt (off in the Deck preset) · optional tilt-shift DOF · halftone post pass for POSTER moments.

---

## 13. Audio

- **Music direction:** Bronx = classic boom-bap and breakbeats; Brooklyn = jazzy boom-bap; Queens = grimy mid-90s East Coast; Staten Island = dusty and eerie; Uptown = soulful with horns; City = cinematic hip-hop; Garden = huge, choir-meets-drums. Three layers per track: explore (drums + bass), combat (+ lead), boss (full + boss stem).
- **Placeholder plan (agent-buildable):** a procedural `BeatSequencer` synthesizes kick/snare/hat/bass/chord pad from per-borough pattern data and exposes a BPM clock (Grandmaster Boom needs it). Replace with commissioned or licensed music before launch. Never use real song samples.
- **SFX:** surface-aware ball bounces (asphalt, wood, metal, wet), chain-net ching, swish, rim clank, sneaker squeaks indoors, crowd oohs, bodega door bell, cat purr. Placeholder via a procedural sfxr-style synth; CC0 packs are fine if fetchable.
- **Ambience:** distant sirens, train rumble, AC hum, muffled music from windows, crowds at courts.
- **Voices:** syllable-gibberish voices for NPC dialogue (pitch per character); Mic Check gets a megaphone filter.

---

## 14. UI/UX & accessibility

- **HUD:** top-left Heart (red), Wind (green), Hype (flame meter); bottom-left Quarter Waters; bottom-right 2 ball slots + Bag Move + Takeover-ready glow; top-right tokens and Rep; bottom-center boss bar (name in graffiti type + Composure bar); shot meter beside the player; lock-on reticle; context prompts.
- **Menus:** Locker (gear grid), Ink (body diagram with slots), Bag (moves), Map (subway-map style), Stats, Settings. Sticker/graffiti style. Fonts: Bungee (OFL), Permanent Marker (Apache 2.0), Inter (OFL). Fallback to Godot's default font if they can't be fetched.
- **Death screen:** "COOKED" in drippy sticker type, then fade to the bodega.
- **Accessibility:** full remapping, hold/toggle options, colorblind palettes plus shape markers on the shot meter, reduce-flashes toggle (tourist flashes, POSTER flash, lightning), screen shake slider, subtitles with speaker names, UI scale 80–150%, pass aim assist, Rookie Mode, pause anywhere (single-player).

---

## 15. Tech stack & architecture

### 15.1 Stack

| Layer         | Choice                                                                                  | Notes                                                              |
| ------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| Engine        | Godot 4.x, latest stable, **standard build (not .NET)**                                 | Record exact version + binary path in `docs/DECISIONS.md`          |
| Language      | GDScript with static typing                                                             | Untyped declarations = warnings treated as errors                  |
| Renderer      | Forward+                                                                                | Quality presets: Low, Deck, High, Ultra                            |
| Physics       | Jolt (built into recent Godot 4 releases) if available, else Godot Physics              | 60 Hz physics tick                                                 |
| Tests         | GUT in `addons/gut`                                                                     | Fallback: tiny `tools/mini_test.gd` runner if GUT can't be fetched |
| Steam         | GodotSteam GDExtension in `addons/godotsteam`                                           | `SteamService` no-ops when unavailable                             |
| Data          | JSON in `/data`, validated at boot and in tests                                         |                                                                    |
| VCS           | git + Git LFS for binaries                                                              |                                                                    |
| Fonts         | Bungee, Inter (OFL), Permanent Marker (Apache 2.0)                                      | Fallback: Godot default font                                       |
| Assets        | Procedural first; optional CC0 (Kenney, Quaternius, Poly Haven) through `AssetRegistry` | Every external asset logged in `CREDITS.md`                        |
| Export        | Windows x86_64, Linux x86_64 (Steam Deck)                                               | macOS later                                                        |
| CI (optional) | GitHub Actions running headless verify                                                  |                                                                    |

### 15.2 Project layout

```
concrete-crown/
  project.godot  CLAUDE.md  README.md  CREDITS.md  export_presets.cfg
  docs/        CONCRETE_CROWN_SPEC.md  PROGRESS.md  DECISIONS.md  PLAYTEST.md
  addons/      gut/  godotsteam/
  autoload/    event_bus.gd game_state.gd data_db.gd tier_manager.gd save_system.gd
               scene_router.gd audio_director.gd asset_registry.gd input_router.gd
               settings.gd steam_service.gd debug_console.gd
  core/        combat/ (frame_data, hitbox, hurtbox, damage_service, composure, combat_sim)
               ball/   (ball_controller, shot_resolver, hoop, chain_net, crate_hoop)
               duel/   (possession_duel)
               fsm/    (state_machine, state)
               stats/  (stats, equipment, tattoos, leveling)
  actors/      hooper/ (shared combat component + virtual input)
               player/ enemies/ critters/ bosses/ (boss_base, boss_brain, primitives/, builders/)
  world/       builder/ (borough_builder, kit/, map_parser, nav_baker)
               maps/ (*.txt ASCII + *.json sidecars)  interiors/  arenas/
               props/ (bodega, station, shoebox, bootleg, wire_kicks, ladder_shortcut, graffiti_tag)
  ui/          hud/ shot_meter/ boss_bar/ menus/ map/ creator/ title/ dialogue/
  rendering/   shaders/ (toon, outline, occlusion_dither, wet_asphalt, window_lights,
               neon, halftone_post, tilt_shift)  environments/
  audio/       beat_sequencer.gd beat_clock.gd sfx_synth.gd patterns/
  data/        tiers.json tuning/ archetypes.json items/ balls.json tattoos.json
               bag_moves.json consumables.json enemies.json bosses/ moves/
               boroughs.json loot_tables.json dialogue/ achievements.json poses/
  tests/       unit/ integration/ smoke/ qa/
  tools/       verify.sh verify.ps1 validate_data.gd map_lint.gd export.sh export.ps1
               screenshot.gd qa_runner.gd
  licenses/    (font + asset licenses)
```

### 15.3 Autoloads

- **EventBus:** typed signals for cross-system events (`bucket_scored(grade, zone)`, `ankle_broken(target)`, `boss_phase_changed`, `crown_awarded(borough)`, `player_cooked`, `chain_recovered`…).
- **GameState:** run state: start borough, tiers, crowns, flags, discovered stations, map reveal, inventory, equipment, stats, Rep, tokens, chain location, NG+ cycle.
- **DataDB:** loads and validates `/data` at boot; typed accessors; fails loudly on bad data.
- **TierManager:** tier lookup (§4.3) and multipliers (§11.1).
- **SaveSystem:** §15.14. **SceneRouter:** loads districts, interiors, arenas with the subway loading scene.
- **AudioDirector:** music layers, BeatClock, SFX. **AssetRegistry:** logical IDs → procedural builders or imported scenes.
- **InputRouter:** device detection, glyphs, 8-frame buffer. **Settings:** options and accessibility.
- **SteamService:** GodotSteam wrapper with no-op fallback. **DebugConsole:** dev builds only.

### 15.4 Data examples (patterns to follow)

`data/tiers.json`

```json
{
  "start_tiers": {
    "bronx": {
      "bronx": 1,
      "uptown": 2,
      "queens": 3,
      "brooklyn": 4,
      "staten_island": 5
    },
    "brooklyn": {
      "brooklyn": 1,
      "queens": 2,
      "uptown": 3,
      "bronx": 4,
      "staten_island": 5
    },
    "queens": {
      "queens": 1,
      "brooklyn": 2,
      "bronx": 3,
      "uptown": 4,
      "staten_island": 5
    },
    "staten_island": {
      "staten_island": 1,
      "brooklyn": 2,
      "uptown": 3,
      "queens": 4,
      "bronx": 5
    },
    "uptown": {
      "uptown": 1,
      "bronx": 2,
      "brooklyn": 3,
      "queens": 4,
      "staten_island": 5
    }
  },
  "fixed": { "city": 6, "garden": 7 },
  "multipliers": {
    "hp": [1.0, 1.7, 2.6, 3.7, 5.0, 6.5, 8.0],
    "damage": [1.0, 1.4, 1.9, 2.5, 3.1, 3.8, 4.5],
    "composure": [1.0, 1.25, 1.55, 1.9, 2.3, 2.7, 3.1],
    "rep": [1, 2.2, 4, 6.5, 9.5, 13, 18],
    "tokens": [1, 1.8, 3, 4.5, 6.5, 9, 12],
    "price": [1, 1.6, 2.4, 3.4, 4.6, 6, 7.5],
    "ai_cooldown": [1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7],
    "loot_shift": [0, 5, 10, 15, 20, 25, 30]
  },
  "ng_plus": { "tier_add": 2, "tier_cap": 7, "mult_per_cycle": 1.3 }
}
```

`data/bosses/bk_stoop.json`

```json
{
  "id": "bk_stoop",
  "name": "THE STOOP QUEEN",
  "title": "She Sees Everything",
  "borough": "brooklyn",
  "kind": "mini",
  "arena": {
    "theme": "brownstone_block",
    "size_m": [18, 16],
    "hoop": "over_door",
    "indoor": false
  },
  "base": {
    "hp": 1800,
    "composure": 200,
    "contest_radius": 3.0,
    "height_m": 4.0
  },
  "phases": [
    {
      "id": 1,
      "rules": { "stationary": true },
      "moves": [
        "stoop_lob",
        "chancla",
        "broom_sweep",
        "window_watchers",
        "fan_gust",
        "double_lob"
      ]
    },
    {
      "id": 2,
      "min_tier": 3,
      "at_hp_pct": 0.5,
      "transition": "stand_up",
      "moves": [
        "housecoat_spin",
        "lawn_chair_slam",
        "grandma_hug",
        "stoop_lob",
        "chancla"
      ]
    }
  ],
  "t5_event": { "at_hp_pct": 0.25, "move": "block_party_call" },
  "drops": ["ball_pinkie", "flash_rose"],
  "rewards": { "rep": 2500, "tokens": 800 },
  "mic_check": "She has been on that stoop since BEFORE YOU WERE BORN. And she has SEEN what you did."
}
```

`data/moves/bk_stoop/chancla.json`

```json
{
  "id": "chancla",
  "primitive": "projectile",
  "body_attack": true,
  "telegraph": {
    "anim": "windup_throw",
    "frames": 24,
    "vfx": "red_flash",
    "sfx": "whoosh"
  },
  "startup": 24,
  "active": 30,
  "recovery": 20,
  "damage": 45,
  "composure_dmg": 0,
  "parry": "none",
  "unblockable": true,
  "projectile": { "speed": 22, "range": 20, "homing": 0.1 },
  "min_tier": 1,
  "weight": 3,
  "cooldown_s": 4,
  "range_m": [4, 20],
  "possession": "any"
}
```

`data/balls.json` (one entry)

```json
{
  "id": "ball_pinkie",
  "name": "Pinkie",
  "rarity": "epic",
  "attack": 38,
  "scaling": { "handles": "C", "hands": "C" },
  "gather_s": 0.55,
  "props": { "pass_ricochets": 2 },
  "flavor": "Pink rubber with a hundred summers of stoop bounce in it. She kept it for somebody who deserved it."
}
```

Every data file has a schema check in `tools/validate_data.gd` (required keys, types, ID references resolve, enums valid).

### 15.5 Combat runtime

- 60 Hz physics; all frame data in frames.
- **Hitbox** (Area3D) enabled only on active frames; carries owner, move ID, damage packet. **Hurtbox** per actor (body capsule + head sphere).
- **DamageService.resolve(hit)** pipeline: i-frames → parry window (strip/deflect) → guard → poise/stagger → damage formula (§7.12) → composure → status → EventBus → hitstop request.
- **CombatSim:** steps physics frames without rendering for deterministic, frame-exact tests.
- **Hooper component:** the shared ball-combat implementation used by the player, Pickup Challengers, Deuce, Pops, and Midnight Phase 1. It reads from an `ActorInput` interface fed either by `InputRouter` (human) or a brain (AI). One code path for every hooper.

### 15.6 Ball runtime

- States: `HELD` (procedural dribble synced to footsteps, hand-to-floor arc) · `PASS` (kinematic projectile, shape-cast sweep) · `SHOT` (scripted arc playing out the outcome chosen at release) · `LOOSE` (RigidBody3D, bounce 0.78, small damping) · `IN_NET` · `DEAD`.
- Exactly one owner at a time. Boss arenas spawn a single ball; streets pool one per hooper.
- Hoop: torus rim collider, backboard, procedural verlet chain net (outdoor chain "ching") or nylon net (indoor swish).

### 15.7 ShotResolver (pure, fully unit-tested)

`static func compute_windows(ctx: ShotContext) -> ShotWindows` and `static func grade(release: float, windows: ShotWindows, contest: float) -> ShotGrade`. Context: Jumper, zone, distance, contest, stepback, wide-open, takeover, Wind ratio, wind drift, gear/tattoo modifiers. Implements §7.6 exactly. At least 25 tests: each grade boundary, each modifier, the perfect cap, smothered → REJECTED.

### 15.8 PossessionDuel (pure)

A plain class implementing §7.10 as an explicit transition table (states: CHECK, PLAYER_OFFENSE, LOOSE_BALL, BOSS_OFFENSE, PHASE_TRANSITION, GAME_POINT, VICTORY, DEFEAT; flags: `player_cleared`, `boss_cleared`, `lock_in_stacks`). Emits events; holds no scene references. Every transition has a unit test.

### 15.9 AI

- **EnemyBrain:** FSM (Patrol → Alert → Engage → Recover → Leash) + **AttackTokenManager** (max attackers by tier).
- **BossBrain:** utility move selection (§9.2) + possession behaviors (clear, showboat, statement dunk, contest).
- **ChallengerBrain:** drives a Hooper through `ActorInput` with a policy (approach, probe, crossover on enemy windup, shoot when open, strip on telegraphs). Difficulty from tier.

### 15.10 World builder (ASCII maps)

Districts are authored as 64×64 ASCII maps (`world/maps/<id>.txt`, tile = 4 m) plus a JSON sidecar. `BoroughBuilder` turns them into geometry at load with a deterministic seed per district, MultiMesh-batches repeated props, and bakes the navmesh on a thread during the subway loading scene (target < 3 s per district).

**Legend**

```
#  impassable wall / map edge        ~  water
.  road                              ,  sidewalk
B  brownstone (3–4 floors, stoops)    T  walk-up (5–6 floors, fire escapes)
H  high-rise (10–30 floors)           W  warehouse / industrial
P  park grass                         t  tree
C  outdoor court floor                h  crate hoop (on a pole)
D  bodega (checkpoint)                S  subway entrance (station)
K  The Plug    G  Pump & Grip    I  Ink & Needle
M  mini-boss court entrance           X  King/landmark court entrance
$  shoebox     %  Bootleg     w  Wire Kicks (shoes on the overhead wire)
e  crew spawn  E  elite spawn  c  critter spawn
L  fire-escape ladder shortcut (one-way)   g  gate shortcut (one-way)
^  rooftop access   R  elevated track overhead (on road tiles)
F  chain-link fence   n  NPC spot   @  player start   >  crossing / exit
```

- Contiguous building letters form a block; the builder splits blocks into 2–3-tile lots with varied facades, puts stoops/doors toward the nearest sidewalk, and adds rooftop water towers, AC units, and fire escapes by type.
- **Binding rule:** the k-th occurrence of a letter in row-major order binds to the k-th entry of that letter's list in the sidecar (bodegas, stations, NPCs, fights, crossings, loot overrides).

Example (24×12, format illustration only):

```
########################
#BBBBBB,..,TTTTTT,..,PP#
#BBBDBB,..,TTTTTL,..,PC#
#,,,h,,,..,,,$,,,,..,CM#
#..........e.........,C#
#.....@..............,,#
#,,,,,,,..,,,,,,,,..,,,#
#TTTTTT,..,BBBBBB,..,WW#
#TTTTTTS..,BBBBBB,..,WW#
#TTTTTT,..,BBBBBB,..,%W#
#,,,,,,,..,,,,,,,,..,,>#
########################
```

`world/maps/bk_bedstuy.json` (sidecar)

```json
{
  "id": "bk_bedstuy",
  "borough": "brooklyn",
  "palette": "brooklyn",
  "seed": 1101,
  "heights": { "B": [3, 4], "T": [5, 6], "H": [10, 18], "W": [2, 3] },
  "spawns": {
    "e": ["ball_hog", "showboat", "sniper"],
    "E": ["captain:big_man"],
    "c": ["rats", "pigeons"]
  },
  "bodegas": [{ "id": "bk_bodega_1", "cat": "Tony" }],
  "stations": [{ "id": "bk_st_bedstuy", "name": "Bed-Stuy" }],
  "fights": { "M": ["bk_stoop"] },
  "loot": { "$": "bk_retail", "%": "bootleg", "w": "bk_wire" },
  "crossings": [{ "to": "queens/qn_roosevelt", "via": "cemetery_belt" }],
  "graffiti": ["try crossing over", "she sees everything", "cat's friendly"]
}
```

`tools/map_lint.gd` checks: rectangular, legal chars, every bodega/station reachable from `@` or a crossing on the nav grid, binding counts match the sidecar, each court entrance touches a court.

### 15.11 Puppet rig, character & boss builders

- **Puppet rig:** body parts are separate meshes on pivot nodes (head, torso, hips, upper/lower arms, hands, thighs, shins, feet). No skinned meshes needed.
- **PoseLibrary** (`data/poses/*.json`): named poses as per-joint rotations + root offset. Animations are pose sequences with timing and easing, layered with procedural motion: locomotion bob, lean into turns, squash/stretch on land and dunk, two-bone hand-to-ball IK, head look-at.
- **CharacterBuilder:** customization profile → parts, colors, hair (each style is a recipe of spheres/capsules/tori), face decals, tattoo decals.
- **BossBuilder:** one builder script per boss composing its silhouette from primitives + toon materials (e.g., the Stoop Queen: lawn chair, housecoat body, curler cylinders, torus glasses). Bosses animate the same way (pose sets + procedural layers).

### 15.12 Rendering

- `toon.gdshader`: 3-band diffuse in `light()`, hard spec, fresnel rim tinted by palette, emission. `outline.gdshader`: inverted hull as `next_pass`, width scaled by distance.
- `occlusion_dither.gdshader`: screen-door fade on geometry between camera and player (raycast-driven parameter).
- `window_lights.gdshader`: facade UV grid → hashed lit/unlit windows, warm/cool tints, rare flicker.
- `wet_asphalt.gdshader`: puddle mask noise driving roughness for SSR.
- `halftone_post.gdshader` and tilt-shift for comic and diorama moments.
- One `WorldEnvironment` preset per region (sky gradient, fog, glow, color grade). Dawn preset for the Daybreak ending.
- Light budget: OmniLights with distance fade; only the 4 nearest cast shadows.

### 15.13 Audio runtime

`BeatSequencer` synthesizes drums/bass/pads through `AudioStreamGenerator` from pattern JSON; `BeatClock` emits `beat`/`bar` signals for gameplay (Grandmaster Boom). `SfxSynth` generates and caches placeholder `AudioStreamWAV`s at boot. `AudioDirector` crossfades explore/combat/boss layers.

### 15.14 Save system

JSON with `schema_version`, 3 slots, atomic write (temp file → rename) plus `.bak`. Autosave on rest, Crown, boss defeat, and (debounced) item pickups. Migration functions per version with tests. Project uses a custom user directory named `ConcreteCrown` so Steam Auto-Cloud paths are stable (§18).

### 15.15 Debug console & QA bot

- Backtick opens the console (dev builds): `tp <poi>`, `give <item>`, `tier <borough> <n>`, `start <borough>`, `god`, `onehit`, `kill_boss`, `crown <borough>`, `set_rep <n>`, `unlock_all`, `timescale <x>`, `duel_state`.
- **QA runner:** `$GODOT --headless --path . -- --qa-run=<script_id>` runs scripted sequences (teleport, trigger fight, god mode, autoplay policy) and prints `QA PASS <id>` / `QA FAIL <id>: <reason>`. Used by smoke tests and `verify --full`.

### 15.16 Verification harness

`tools/verify.sh` (macOS/Linux/Git Bash) and `tools/verify.ps1` (Windows) read the Godot path from `$GODOT` and run, in order:

1. Import/refresh resources headless (first run).
2. `validate_data.gd` (schemas, references) and `map_lint.gd`.
3. GUT: `$GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
4. Every scene in `tests/smoke/` headless with `--quit-after 900`; any `ERROR` or `SCRIPT ERROR` in output fails.
5. With `--full`: all QA scripts; render smoke + screenshots to `shots/` when a display is available (skipped with a printed warning otherwise); export dry run (skipped with a warning if export templates aren't installed).

Final line is exactly `VERIFY: ALL GREEN` (exit 0) or `VERIFY: FAILED (<n> problems)` (exit 1). Headless mode uses a dummy renderer, so shader errors only surface in the render smoke; run it whenever a display exists.

### 15.17 Performance budgets

60 fps at 1080p on GTX 1060 / RX 580-class GPUs · Steam Deck 40–60 fps at 1280×800 on the Deck preset (no SSR, no volumetric fog, half-res glow) · < 2,500 draw calls · ≤ 32 visible lights, 4 shadowed · district build < 3 s · RAM < 3 GB.

### 15.18 Steam integration

GodotSteam GDExtension: init, achievements (API names in Appendix B), rich presence ("Running it back in Brooklyn — Tier 3"), overlay pause. Dev uses `steam_appid.txt`. Every Steam call goes through `SteamService`, which no-ops cleanly when Steam or the extension is absent so the game and tests run anywhere.

---

## 16. Build plan — milestones & commit checkpoints

**Rules for every milestone**

- Implement → test → run `tools/verify.sh` → fix until `VERIFY: ALL GREEN` → update `docs/PROGRESS.md` → commit with the listed message → create the listed tag.
- Sub-commits inside a milestone are encouraged (`M3.2: parry windows`). The tagged commit is the checkpoint.
- Don't start the next milestone until the current one is tagged. Skip milestones already tagged (for resumed runs).
- `docs/PROGRESS.md` holds a table: milestone · status (TODO / IN PROGRESS / DONE) · date · what shipped · known issues · deferred items.

**M0 — Scaffold & harness** · commit `M0: scaffold, data layer, verify harness` · tag `m0`

- Confirm `$GODOT --version`; record version and path in DECISIONS.md. `git init`, Git LFS for `*.png *.jpg *.glb *.ogg *.wav *.ttf *.otf`, `.gitignore` (`.godot/`, `shots/`, `builds/`).
- `project.godot`: name, custom user dir `ConcreteCrown`, Forward+, 1920×1080 with `canvas_items`/`expand` stretch, 60 Hz physics, Jolt if available, strict typing warnings, full input map (§7.2).
- Folder layout (§15.2), autoload stubs with typed APIs (§15.3), GUT (or mini_test fallback), DataDB + `validate_data.gd`, `tiers.json` and `tuning/*.json` from §11, `archetypes.json` from §6.3.
- `tools/verify.sh` + `verify.ps1` (§15.16), `tests/smoke/boot_smoke.tscn`. Create CLAUDE.md (Appendix A), PROGRESS.md, DECISIONS.md, CREDITS.md, `licenses/`.
- Tests: DataDB loads; each tier row is a permutation of 1–5 with the start borough = 1 and matches §4.3 exactly; tuning values load.

**M1 — Look & move** · `M1: toon rendering, camera, puppet rig, movement` · `m1`

- All §15.12 shaders, region environment presets, quality presets. Camera rig (D2) with lock-on and occlusion cutaway.
- Puppet rig, CharacterBuilder (default profile), PoseLibrary (idle, dribble idle, walk, run, sprint, crossover, slide, jump, land, hit, knockdown, death). PlayerController: movement, sprint/Wind, dodge with i-frame flags, jump, coyote time, input buffer.
- `movement_lab` scene: one greybox street (brownstone, walk-up, streetlight, hydrant, water tower, bodega front).
- Tests: Wind math, i-frame windows, buffer, camera framing. Smoke: movement_lab with scripted input. Render smoke + one screenshot reviewed if a display exists.

**M2 — Ball & shooting** · `M2: ball system, shot meter, hoops, crate hoops` · `m2`

- Ball states (§15.6), dribble, chest/baseball pass with ricochet, lob, loose physics, pickup, lost-ball safety. Hoop with chain/nylon net. ShotResolver (§15.7) + shot meter UI + outcome flights. Crate hoops + Bucket Blast + cooldown. Wire Kicks knock-down.
- Tests: ≥25 ShotResolver cases, ball state transitions, ricochet rules, Bucket Blast radius/cooldown. Smoke: `ball_lab`.

**M3 — Combat core** · `M3: combat core` · `m3`

- Frame data runtime, Hitbox/Hurtbox, DamageService, CombatSim. Every move in §7.4–7.5. Ankle Breaker, Strip/Deflect, Guard, Rejection, unblockables. Hype, Takeover, Taunt, Bag Move framework (Snatchback, Spin Cycle, Hesi implemented). Composure/SHOOK/STAGGER. Quarter Waters. HUD bars. Hitstop/shake/slow-mo hooks. Death → COOKED → chain drop → respawn → recovery. Training dummy.
- Tests: frame-exact parry and ankle windows with stat scaling, §7.12 formula, composure break/regen, chain rules. Smoke: `combat_lab`.

**M4 — Enemies** · `M4: enemies and AI` · `m4`

- Hooper-based EnemyBase, EnemyBrain, AttackTokenManager, leash/respawn. Six archetypes, all critters, Crew Captain, Bootleg, borough and City uniques, ChallengerBrain. Disarm-on-strip, Pickpocket theft + lost & found, Dunk Finisher, Big Man dunk-on-you grab. Tier application on spawn.
- Tests: aggro/leash, token caps, tier multipliers, `min_tier` filtering. Smoke: `enemy_lab` (each type vs QA bot for 60 s).

**M5 — Boss framework + The Stoop Queen** · `M5: boss framework + Stoop Queen` · `m5`

- PossessionDuel (§15.8), arena template builder (court, arc, rim, chain gate, apron, theme hooks), Mic Check intro + title card, boss HUD, all 17 move primitives, BossBrain, phase/tier gating, T5 events, GAME POINT, rewards. The Stoop Queen complete. QA boss-sim policy.
- Tests: every PossessionDuel transition; clear rule; make-it-take-it; statement dunk heal; Rejected punish; gating at T1/T2/T3/T5. Smoke: `boss_lab_stoop` (120 s sim; debug win and loss paths both reached).

**M6 — World builder & exploration** · `M6: world builder, checkpoints, fast travel, exploration` · `m6`

- Map parser + `map_lint`, procedural kit (§12.3), BoroughBuilder with MultiMesh + threaded nav bake, SceneRouter + subway loading ride, crossings, interiors, bodega checkpoint (rest/travel/respawn; Train stub), stations + fast travel, fog of war + subway-style map + pins, shoeboxes (brands/tiers/locks/Box Keys), Bootlegs, Wire Kicks, graffiti tags, one-way shortcuts, secrets.
- Author `bk_bedstuy` as the first real district.
- Tests: lint all maps; builder determinism (same seed → same geometry hash); fast-travel unlock rules; reveal radii. Smoke: `district_walk` (QA bot walks Bed-Stuy, opens a box, rests, travels).

**M7 — RPG systems** · `M7: stats, gear, tattoos, shops, saves` · `m7`

- Stats/formulas (§6.4), Train (§11.3), equipment effects for every slot, full catalogs (§10) with flavor text, loot tables with tier shift, shops (Plug, Pump & Grip, Ink & Needle, Bodega), tattoo slots/apply/laser, all 16 Bag Moves, ball upgrades, Locker/Ink/Bag/Stats UI, Save/Load v1 + migration.
- Tests: formulas and soft caps, effect stacking, tattoo slot rules (2 + Crowns, max 7, laser), loot shift, save round-trip, migration.

**M8 — Vertical slice: Brooklyn** · `M8: Brooklyn vertical slice` · tags `m8` and `v0.1-slice`

- Title screen, character creator (§6.2), archetype + start-borough select with tier preview, prologue "I Got Next" (tutorial, Midnight cameo, bodega wake-up). Brooklyn's three districts fully authored with everything in §4.4. The Barker + The Toll. Fixie Rider. NPCs with dialogue data. Brooklyn Crown + earned nickname. Pause/settings. Complete HUD.
- Tests: QA slice run (new game in Brooklyn → tutorial → every POI → every fight via god mode → Crown); boss sim for all three Brooklyn bosses at Tier 1 and Tier 5. Write `docs/PLAYTEST.md` (what to try, what it should feel like).
- **Human checkpoint:** this is the moment for Jonathan to play.

**M9a / M9b / M9c / M9d — The Bronx / Queens / Staten Island / Uptown** · `M9a: The Bronx` … `M9d: Uptown` · tags `m9a` … `m9d`

- Per borough: three districts (§4.5), unique enemy, two minis + King with all phases and tier moves, shops and stock, 4 bodegas and cats, stations, loot, Grail box, two Pickup Challengers, secrets, crossings. (Grandmaster Boom needs a BeatClock; if M13 isn't done, build a minimal metronome clock now.)
- Tests per borough: boss sim for each new boss at Tier 1, 3, 5; QA borough run; map lint.

**M10 — The connected city** · `M10: crossings, tier matrix, questlines, NG+` · `m10`

- All crossings live, cross-borough fast travel, tiers wired for all five starts, Deuce duels 1–2, Pizza Rat King tunnel, Lost Cat and Grail Hunt, Pops lessons, NG+ tier shift.
- Tests: 5×5 tier matrix end to end (start each borough via QA; spawn a common and the King in every borough; assert multipliers); questline flags; NG+ shift and cap.

**M11 — The City** · `M11: The City and five landmarks` · `m11`

- Crown Pass gating, Downtown + Midtown districts, City uniques, five landmark bosses (Tier 6), Garden Ticket stubs.
- Tests: boss sim per landmark, gating rules, QA City run.

**M12 — The Garden & endings** · `M12: The Garden, Midnight, endings` · `m12`

- Midnight's three phases (player-side SHOOK, borrowed moves, countdown finale), Deuce duel 3, Pops superboss, ending choice, Daybreak (sunrise, credits, dawn overworld preset), Overtime (into NG+), credits.
- Tests: Midnight sim per phase; ending flags; NG+ from both endings; QA full run (new game → Garden with debug skips) passes from all five starting boroughs.

**M13 — Audio & juice** · `M13: audio, juice, accessibility` · `m13`

- BeatSequencer + per-region patterns + layer crossfades; BeatClock drives Boom; SfxSynth library; ambience; gibberish voices; every §7.14 feel item; POSTER halftone; all accessibility options (§14); controller glyphs; Rookie Mode.
- Tests: BeatClock drift < 5 ms over a simulated 5 minutes; settings persistence; reduce-flashes disables the listed effects.

**M14 — Steam & release candidate** · `M14: Steam integration and release candidate` · tags `m14` and `v1.0-rc`

- SteamService with GodotSteam (achievements, rich presence) and verified no-op fallback; export presets (Windows, Linux) and `tools/export.*` → `builds/`; Deck preset auto-selected on Steam Deck; performance pass vs §15.17; optional pre-baked districts; README (play/build), CREDITS, licenses; balancing pass using boss-sim time-to-kill logs vs §11.6 (log results in PROGRESS.md).
- Tests: `verify --full` green; export dry run produces both builds (or a logged manual step if templates are missing).

---

## 17. Running it with Claude Code

### 17.1 What to expect

- This is a very long autonomous run: likely many hours across sessions, with plenty of context compaction along the way. `docs/PROGRESS.md` and `docs/DECISIONS.md` are its memory, and the tags let it resume cleanly.
- The result should be a complete, playable game in the procedural toybox style with placeholder audio. It will **not** be a finished commercial release: combat feel and boss balance need your hands on a controller, and real art and music are a later upgrade.
- The riskiest parts are combat feel (M3), the boss framework (M5), and Steam Deck performance (M14). That's why the slice is a checkpoint.

### 17.2 One-time setup (no code)

1. Install **Godot 4** (the standard version, not .NET) from godotengine.org. Open it once, then **Editor → Manage Export Templates → Download and Install** (needed for M14 builds). Note where the Godot app/binary lives.
2. Install **Git** and **Git LFS**.
3. Make an empty folder named `concrete-crown`, make a `docs` folder inside it, and put this file there as `docs/CONCRETE_CROWN_SPEC.md`.
4. Open Claude Code in that folder. Run it on a machine with a display (so render checks and screenshots work), plugged in, with sleep disabled.
5. Switch Claude Code to **auto mode** so goal turns don't stop to ask for tool approvals.
6. Paste the `/goal` below with your Godot path filled in. Check progress any time with `/goal` (no argument). Stop with `/goal clear`. If the session ends, resuming it restores an active goal.

### 17.3 The full-build goal

```
/goal Build the game in docs/CONCRETE_CROWN_SPEC.md to release candidate. Godot binary: <PASTE YOUR GODOT PATH>. Read the whole spec first. In M0, create CLAUDE.md from Appendix A and follow it for the rest of the run. Execute the §16 milestones strictly in order: M0, M1, M2, M3, M4, M5, M6, M7, M8, M9a, M9b, M9c, M9d, M10, M11, M12, M13, M14, skipping any milestone already tagged. For each milestone: implement everything it lists, write its tests, run tools/verify.sh (tools/verify.ps1 on Windows) and fix until it prints VERIFY: ALL GREEN, update docs/PROGRESS.md, then make the listed commit and tag(s). Never start a milestone before the previous one is committed and tagged. Never claim a check passed without running it in this session and showing the output. If blocked (missing tool, no network, unclear spec), choose the simplest option consistent with the spec, log it in docs/DECISIONS.md, stub it with a TODO, and keep going instead of stopping to ask. Use only procedural or CC0 assets; never add paid, ripped, or trademarked content. The goal is met only when your latest turns show all of: (1) tools/verify.sh --full (tools/verify.ps1 --full on Windows) printing VERIFY: ALL GREEN with exit code 0; (2) git tag --list printing m0 m1 m2 m3 m4 m5 m6 m7 m8 m9a m9b m9c m9d m10 m11 m12 m13 m14 v0.1-slice v1.0-rc; (3) git status --porcelain printing nothing; (4) docs/PROGRESS.md listing every milestone as DONE.
```

### 17.4 Safer option: one goal per milestone (recommended through M8)

```
/goal Complete milestone M5 of docs/CONCRETE_CROWN_SPEC.md §16 and nothing past it, following CLAUDE.md. Done when your latest turns show: tools/verify.sh printing VERIFY: ALL GREEN, docs/PROGRESS.md marking M5 DONE, and git log -1 --oneline plus git tag --list m5 showing the M5 commit and tag. If blocked: decide, log it in docs/DECISIONS.md, stub, continue.
```

Swap `M5`/`m5` for each milestone (for M8 also check `v0.1-slice`). After you've played the slice, switch to the full-build goal; it skips what's already tagged.

### 17.5 When to check in

- **After M3:** play `combat_lab` (open the project in Godot, open the scene, press Play Scene). Does crossing up the dummy feel good?
- **After M5:** fight the Stoop Queen.
- **After M8:** play the Brooklyn slice start to finish with `docs/PLAYTEST.md`. Give feedback before M9.
- **After M12:** full playthrough from a different starting borough.
- **After M14:** run the builds in `builds/` on Windows and on a Deck if you have one.

---

## 18. Steam release checklist (dashboard steps)

You already have a Steamworks partner account, so this is per-app setup.

1. **Steamworks → Create new app** and pay the $100 Steam Direct fee (recouped after $1,000 in revenue). Valve's current onboarding docs list a 21-day wait between paying and releasing; some third-party guides still say 30, so go by what your dashboard shows.
2. **Store page:** capsule images, 5+ screenshots, trailer, description, tags. In the **content survey**, complete the AI-generated content disclosure (this game is built with AI tools).
3. Submit the store page for review (1–5 days), then **Post as Coming Soon**. It has to be public at least two weeks before release; post it early to collect wishlists.
4. **App Admin → Installation / Depots:** a Windows depot and a Linux depot, with launch options for each.
5. **Upload builds** with the SteamPipe GUI tool from the Steamworks SDK, then set the build live on the default branch.
6. **Stats & Achievements:** create the achievements using the API names in Appendix B; publish.
7. **Steam Cloud → Auto-Cloud:** Windows root `WinAppDataRoaming`, subdirectory `ConcreteCrown/saves`; Linux root `LinuxXdgDataHome`, subdirectory `ConcreteCrown/saves`; pattern `*.json`; small quota (10 MB); publish.
8. **Steam Deck:** request a compatibility review once a build is live on a branch.
9. Submit the build for review. When both reviews pass and the waiting periods are done, press **Release**.

---

## 19. IP & legal guardrails (not legal advice)

- Fictional sneaker and apparel brands only (§10.3); no real logos, swooshes, silhouettes, or names.
- Landmarks get evocative generic names in-game (The Garden, The Mecca, The Cage, The Bridge, The Crossroads, The Underground, The Summit). No arena, team, league, or transit-authority trademarks, logos, or map designs. Have a lawyer glance at "The Garden" and landmark depictions before launch.
- No real people: no real players, streetball legends, or their nicknames.
- No song samples. Fonts only under OFL/Apache with license files in `/licenses`. Assets only CC0 or self-made, logged in `CREDITS.md`.
- "Concrete Crown" is a working title. Check Steam and trademark databases before announcing.

---

## 20. Post-launch ideas (out of scope for v1)

Online graffiti messages (async player hints) · "2-on-1" co-op summons for boss fights · daily pickup challenges · photo mode ("mixtape cam") · speedrun timer · harder NG+ remixes · more neighborhoods · commissioned art and soundtrack pass.

---

## Appendix A — CLAUDE.md (create in M0)

```markdown
# CLAUDE.md — Concrete Crown

## Source of truth

docs/CONCRETE_CROWN_SPEC.md. Build order: §16. When the spec is silent: §0.1.

## Environment

- Godot binary: $GODOT (path + version recorded in docs/DECISIONS.md).
- Godot 4.x standard build, GDScript only. No C#/.NET.
- Run tools/verify.sh (or tools/verify.ps1) after every meaningful change.

## Hard rules

1. Static typing everywhere: typed vars, params, and returns.
2. Content lives in /data JSON and is read through DataDB. Tuning numbers live in data/tuning, not in gameplay code.
3. Every system gets unit tests. Every scene gets a smoke test.
4. Never report a check as passed without running it in this session.
5. Never block. Decide, log in docs/DECISIONS.md, stub with `# TODO(spec §x):`, continue.
6. Only procedural or CC0 assets (log CC0 in CREDITS.md). No trademarks, real brands, real people, or song samples.
7. Commit each passing sub-step ("M3.2: parry windows"). Milestone commit + tag only at milestone end, after VERIFY: ALL GREEN.
8. Update docs/PROGRESS.md at every milestone: status, what shipped, known issues, deferrals.
9. Files under ~400 lines, one class per file, cross-system events through EventBus.
10. Headless can't render. When a display exists, run the render smoke and Read a few screenshots in shots/ at M1, M6, M8, M12.
11. Don't weaken or delete tests to make them pass unless the spec changed. Fix the code.
12. Respect the performance budgets in §15.17 (MultiMesh for repeated props, light budget).

## Commands

- Verify: tools/verify.sh [--full]
- Tests: $GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
- One smoke scene: $GODOT --headless --path . res://tests/smoke/<name>.tscn --quit-after 900
- QA script: $GODOT --headless --path . -- --qa-run=<script_id>

## Style

snake_case files, PascalCase class_name, past-tense signals (bucket_scored), frame data in frames at 60 fps.
```

## Appendix B — Achievements (Steam API names)

| API name           | Name                    | Unlock                                           |
| ------------------ | ----------------------- | ------------------------------------------------ |
| ACH_FIRST_BUCKET   | First Bucket            | Score on any boss                                |
| ACH_ANKLES_100     | Ankle Taker             | 100 ankle-breakers                               |
| ACH_POSTER         | Posterized              | First POSTER                                     |
| ACH_SPLASH_50      | Splash Zone             | 50 perfect releases                              |
| ACH_MAKE_TAKE_5    | Make It, Take It        | 5 straight makes in one boss fight               |
| ACH_CROWN_BRONX    | The Bronx Crown         | Beat Grandmaster Boom                            |
| ACH_CROWN_BROOKLYN | The Brooklyn Crown      | Beat The Toll                                    |
| ACH_CROWN_QUEENS   | The Queens Crown        | Beat Atlas                                       |
| ACH_CROWN_SI       | The Staten Island Crown | Beat King of the Heap                            |
| ACH_CROWN_UPTOWN   | The Uptown Crown        | Beat High Rise                                   |
| ACH_CROWN_PASS     | Going Into the City     | Hold all five Crowns                             |
| ACH_LM_CAGE        | No Blood, No Foul       | Beat Chain Link                                  |
| ACH_LM_BRIDGE      | Suspension of Disbelief | Beat Suspension                                  |
| ACH_LM_CROSSROADS  | Prime Time              | Beat Prime Time                                  |
| ACH_LM_UNDERGROUND | Urban Legend            | Beat The Gator                                   |
| ACH_LM_SUMMIT      | Top of the City         | Beat The Gargoyle                                |
| ACH_END_DAYBREAK   | Daybreak                | Let the clock run                                |
| ACH_END_OVERTIME   | Overtime                | Stop the clock                                   |
| ACH_NOBODY         | Nobody to Legend        | Finish as the Nobody archetype                   |
| ACH_FULL_INK       | Fully Inked             | Fill all 7 tattoo slots                          |
| ACH_GRAILS         | Grail Hunter            | Open all 5 Grail boxes                           |
| ACH_RAT_KING       | Slice of Life           | Beat the Pizza Rat King                          |
| ACH_POPS           | Respect Your Elders     | Beat Pops in his prime                           |
| ACH_DEUCE          | Rivalry                 | Win all three duels with Deuce                   |
| ACH_NO_WATER       | Dry Game                | Beat a Borough King without Quarter Waters       |
| ACH_RUN_BACK_10    | Run It Back             | Recover your chain 10 times                      |
| ACH_ALL_CATS       | Cat Person              | Pet every bodega cat                             |
| ACH_BOOTLEG        | Counterfeit Detector    | Defeat 10 Bootlegs                               |
| ACH_TAKEOVER       | On Fire                 | Activate Takeover 25 times                       |
| ACH_TIER5_FIRST    | Long Way From Home      | Beat a Tier 5 Borough King before any other King |

## Appendix C — Glossary

**Ankle Breaker:** perfect crossover through an attack (offensive parry). **Strip / Deflect:** perfect Hands Up vs a ball attack / body attack. **Rejected:** a smothered bad shot gets swatted and punished. **SHOOK / STAGGER:** composure broken by offense / defense. **Check:** possession reset at the top of the key. **Make it, take it:** you keep the ball after you score. **Clear:** dribble past the arc after a change of possession before buckets count. **Statement Dunk:** a boss scoring attempt that heals it. **Bucket Blast:** crate-hoop make that shockwaves street enemies. **Quarter Water / Punch Card / Sugar Rush:** heal / +charge / +potency. **Rep:** XP, dropped as your **chain** on death. **Tokens:** money. **Crown / Crown Pass:** borough victory / all five, opens the City. **Tier:** difficulty set by distance from your start borough. **Bag Move:** Hype-powered special. **Takeover:** "on fire" mode. **Bootleg:** mimic shoebox. **Wire Kicks:** sneakers on a power line. **Grail:** top-rarity item. **Flash sheet:** tattoo unlock. **Mixtape:** teaches a Bag Move. **Pickup Challenger:** optional 1v1 NPC hooper.
