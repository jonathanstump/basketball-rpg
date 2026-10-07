# Next session

Everything in `docs/REVISIONS.md` is marked `[DONE]` (1-10). This run (2026-10-07) did revisions 8-10 and fixed the street Dunk Finisher. What changed and why is in `docs/DECISIONS.md` ("Revisions 8-10 + finisher fix"), spec §5.4, §7.6 and §12.3a, and the last two rows of `docs/PROGRESS.md`.

## What shipped
- **Finisher fix.** After an ankle-breaker, R used to do nothing: the crossover carries you 3.2 m, past the old 2.2 m reach. R now leaps to a downed or SHOOK enemy within 5 m (`hooper.json → dunk_finisher.seek_m`). It also cancels the crossover or stepback tail, so mashing R right after the ankle works. The "[R] FINISH" tag shows at the same range. You need the ball.
- **R8 death.** You lose your unspent Rep. Half of it (rounded down, `economy.death.recoverable_frac`) drops as your chain under a tall gold light beam. An amber marker (HUD + map) leads back to it, or to the crossing toward it.
- **R9 shooting on the run.** Shoot while running and you keep moving through the gather. The windows shrink ×0.65 when running and ×0.5 when sprinting (`shooting.modifiers.on_the_run` / `sprinting`).
- **R10 looks.**
  - Per-borough building palettes (`palettes.json → buildings`); Staten Island gets pitched roofs.
  - Per-borough skyline profiles (`camera.skyline.profiles`) with setback, art deco crown, spire, round glass and twin towers. Crowns are lit in the borough's accent color and spires carry beacons.
  - The map edge is now a quay over harbor water with each borough's bridges.
  - Street hoops now match the court hoops.

## Suggested next steps
1. **Playtest the R7 boss model by hand** (still open from last time). The numbers are in `data/tuning/bosses.json → duel.r7`. Balance REVIEW rows: Grandmaster Boom T1 and T5, Rat King T3.
2. **Feel-check the new tuning:**
   - shooting on the run (`on_the_run` 0.65, `sprinting` 0.5, `run_carry` 0.7)
   - the finisher leap (`seek_m` 5, `leap_speed_max` 16)
3. **Look-check in motion.** The render shots `edge_*`, `edgewide_*` and `bridge_*` (6 boroughs) and `district_street_hoop` show the new edge and hoops. Walk to a street end in each borough. If one bridge angle hides behind buildings, change its `deg` in the profile.
4. **Graphics pass (later, as planned).** The skyline wraps the whole ring, even where real NYC would be land; Uptown's south side could become land instead of water. The bridges are scenery only.
