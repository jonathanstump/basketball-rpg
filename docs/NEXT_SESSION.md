# Next session

Everything in `docs/REVISIONS.md` is marked `[DONE]` (1-14). This run (2026-10-09) did revisions 11-14. The details are in `docs/DECISIONS.md` ("Revisions 11-14"), spec §7.6, §7.10a and §8.5, and the last row of `docs/PROGRESS.md`.

## Notes from this run
- **economy.json was corrupted by the R8 commit.** A `"death"` key had been injected into every object. Values still read correctly, but check any JSON edit made by script. It's rebuilt now.
- **Projectiles had no view at all, for every boss, not just the Stoop Queen.** `world/projectile_fx.gd` now draws all of them. Moves can set `projectile.look` (`orb` | `slipper`), `color` and `visual_radius`. Only the chancla is styled; the rest get the default amber orb. Worth giving each boss's projectile its own look in the graphics pass.
- **Enemy defense (R12) changes street-fight feel.** Jab strings past 3 hits now get parried, dodged or countered (30% at the 3rd hit, rising). Tuning is in `data/tuning/ai.json → defense`. If it feels too strict, raise `min_hits` or lower `base` first.
- **Stoop Queen offense (R11)** is data-driven through `hoops.offense` in `data/bosses/bk_stoop.json`. Other bosses can use the same block, e.g. a calm big man who only posts up.

## Suggested next steps
1. **Playtest the R7 boss model by hand** (still open). The numbers are in `data/tuning/bosses.json → duel.r7`. Balance REVIEW rows: Grandmaster Boom T1 and T5, Rat King T3.
2. **Feel-check the new tuning:**
   - shooting on the run (`on_the_run` 0.65, `sprinting` 0.5, `run_carry` 0.7)
   - the finisher leap (`seek_m` 5, `leap_speed_max` 16)
   - enemy defense (`ai.json → defense`)
   - the Stoop Queen's settle and gather (`settle_s` 1.4, `gather_f` 54) and her provoked swings
3. **Look-check in motion.**
   - The render shots `edge_*`, `edgewide_*` and `bridge_*` (6 boroughs) and `district_street_hoop` show the new edge and hoops. Walk to a street end in each borough. If a bridge angle hides behind buildings, change its `deg` in the profile.
   - Also watch a chancla in flight and a boss bucket (pillar + banner).
4. **Graphics pass (later, as planned).** The skyline wraps the whole ring, even where real NYC would be land; Uptown's south side could become land instead of water. The bridges are scenery only.
