# Playtest — v0.1 Brooklyn slice

This is the first build meant to be played start to finish. It covers a new
game in Brooklyn through the Brooklyn Crown. Plan on 45–90 minutes.

## How to run

- Open the project in Godot 4.7 and press Play, or run
  `Godot_v4.7.2-stable_win64_console.exe --path .` from the repo root.
- Controller recommended. Keyboard: WASD to move, mouse to aim the camera,
  Space to dodge, left click for Light, E to interact, Esc to pause, M for the map.
- **Pick Brooklyn as your start borough.** The other four show their tier
  maps, but their districts are marked "closed tonight" until M9.

## What to try (in order)

1. **Title → New Game.** Go through the creator. Cycle every look option with
   left/right. Try typing a rude name to see the filter block it. Pick each
   archetype and read the stat lines. On the borough screen, compare the tier maps.
2. **"I Got Next."** Walk up to the court and call next. The prompts teach move,
   dribble strike, crossover, the ankle-breaker (dodge right as they wind up),
   a crate-hoop jumper, a strip (Hands Up on the cue), and Quarter Water. Steps
   can be done in any order. Pause → "Skip the tutorial" if you get stuck.
3. **The cameo.** The lights flicker and a tall shadow walks on. You aren't
   supposed to win this one.
4. **Wake up in the bodega.** The cat is on your chest and Pops talks. Pet the
   cat to rest and Train at the counter.
5. **Bed-Stuy.** Read the graffiti, kick down the ladder from below, take the
   rooftop route into the hidden courtyard, and find the station. Then fight
   **The Stoop Queen**: jump her lobs and swat them, race the loose ball, and
   clear it past the arc before you score.
6. **Coney Island** (south crossing). Take on the Pickup Challengers Sweet Pea and
   Wheels, first to 7. Then fight **The Barker** in the Funhouse. Only the real
   one casts a shadow. Hit a mirror clone and you're stunned for half a second.
7. **DUMBO** (north crossing from Bed-Stuy). Knots is in the warehouse yard, and the
   Grail box is in the hidden loft courtyard. Then fight **The Toll** under the
   bridge. His "Pay Up" grab takes 10% of your tokens into the booth on his back,
   and you can strip him while it glows to win them back. Watch for the Toll Gate
   wall and, at higher tiers, the headlight beams.
8. **The Crown.** Beating The Toll gives you the Brooklyn Crown, a third tattoo
   slot, the Toll Booth Bag Move, and a nickname from Mic Check based on your
   style. Check the HUD tag under your Hype bar.

## What it should feel like

- **Moving:** snappy and readable. You shouldn't fight the camera, and
  buildings between you and the camera should dither out.
- **Fighting:** every hit lands with weight (hitstop, shake). Dodging a
  windup at the right moment should feel great. ANKLES! is the reward.
- **Shooting:** releasing at the top of the meter should feel learnable after a
  few tries. Green flashes are rare and earned.
- **Bosses:** each one should teach its gimmick within the first minute. The
  slice targets are 2.5–4 minutes for a mini-boss and 4–6 minutes for the King
  at Tier 1, for a player who scores.
- **Tone:** warm, funny, never mean.

## Known rough edges (please note anything else)

- Audio is placeholder until M13.
- Menus are plain lists in sticker type, without the grid or body-diagram
  layouts yet.
- Balance comes from bot sims, not human play. The bot takes 1–6.5 minutes per
  Brooklyn boss at Tier 1.
- The Barker's T5 "Hall of Mirrors" is a ricochet-style projectile fan for now
  (see docs/DECISIONS.md).
- Other boroughs, the City and the Garden come in M9–M12.

## Reporting

For each issue, write down where you were (district or arena), what you did,
what you expected, and what happened. A screenshot helps. The debug console
(backtick key) has `god` if you want to skip ahead past a wall.
