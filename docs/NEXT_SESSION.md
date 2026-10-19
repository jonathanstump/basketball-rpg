# Next session

Everything in `docs/REVISIONS.md` is marked `[DONE]` (1-17). This run (2026-10-18) did revisions 15-17. Details are in `docs/DECISIONS.md` ("Revisions 15-17"), spec D2, §3.3, the §7.4 controls table, §7.7 and the Stoop Queen's chancla JSON, and the last row of `docs/PROGRESS.md`.

None of the hand playtests below have been done yet, including everything carried over from earlier runs. All of it is verified by automated tests only.

## Notes from this run
- **R15 finisher:** one Dunk Finisher per knockdown or SHOOK (`finish_spent` flag). The gold glow and FINISH tag go out after the slam and come back on the next opening.
- **R16 chancla:** the old view did draw it, but it spawned inside the Queen's body and only flew for 0.9 s. Now every projectile leaves from the thrower's edge. The chancla winds up for 36 f with the slipper held overhead and a lane on the ground, then flies at 12 m/s for 2 s with weak homing. Any `projectile` move gets the same wind-up cue, so the other bosses' throws changed too.
- **R17 lock-on:** middle mouse / R3 to toggle. Switch targets with the mouse wheel or a sideways flick of the mouse or right stick. You keep facing the target while you back up, and the lock breaks past 20 m (`camera.json → lockon`). It's a new tutorial step between crossover and ankle-breaker. Boss arenas still lock onto the boss at fight start (unchanged).

## Suggested next steps
1. **Hand-check this run's changes:**
   - **Tutorial:** does the lock-on step read clearly, and is a locked stepback a natural way to take ankles?
   - **Lock switching:** the flick thresholds (`flick_px` 90, stick 0.7) are guesses. Check that mouse flicks don't trigger by accident mid-fight and aren't too hard to do on purpose.
   - **Break range:** 20 m. Too far or too near?
   - **The Stoop Queen's chancla:** readable now? Is a 2 s flight too easy to dodge? If so, try speed 15 before cutting the wind-up.
   - **Other bosses' projectiles:** they also get the overhead wind-up cue and now spawn at the boss's edge.
   - **R15:** check that one finisher per knockdown doesn't make street fights feel slow. If it does, a damage bonus on downed enemies is the next lever (per the 2026-10-07 note).
2. **Playtest the R7 boss model by hand** (still open). The numbers are in `data/tuning/bosses.json → duel.r7`. Balance REVIEW rows: Grandmaster Boom T1 and T5, Rat King T3.
3. **Feel-check the earlier tuning** (still open):
   - shooting on the run (`on_the_run` 0.65, `sprinting` 0.5, `run_carry` 0.7)
   - the finisher leap (`seek_m` 5, `leap_speed_max` 16)
   - enemy defense (`ai.json → defense`)
   - the Stoop Queen's settle and gather (`settle_s` 1.4, `gather_f` 54) and her provoked swings
4. **Look-check in motion** (still open).
   - The render shots `edge_*`, `edgewide_*`, `bridge_*` and `district_street_hoop` show the edge and hoops. Walk to a street end in each borough.
   - Watch a chancla wind-up and flight, and a boss bucket (pillar + banner).
5. **Graphics pass (later, as planned).** Give each boss's projectile its own look (only the chancla is styled). The skyline wraps the whole ring, even where real NYC would be land. The bridges are scenery only.
