# Next session

All 7 playtest revisions in `docs/REVISIONS.md` are done and marked `[DONE]`. The last `tools/verify.ps1 --full` (run with `CC_HEADLESS=1`) was ALL GREEN: 383 tests, all smokes, all QA scripts and balance. What changed and why is in `docs/DECISIONS.md` (section "Playtest revisions") and the 2026-10-05 row of `docs/PROGRESS.md`. The spec has §3.6a (R6/R1) and §7.10a (R7).

## Where things stand
- **Not run:** the full render smoke. The display was asleep, so even the boot screen ran at ~560 ms per frame. The R2/R5 shots (`district_look_up`, `district_street_level`, `boss_*`) were taken and checked earlier in the session, while frames were normal.
- **Two new render entries** in `tools/render_scenes.json`: `district_look_up` and `district_street_level`.

## Suggested next steps
1. With the screen on, run `powershell -ExecutionPolicy Bypass -File tools/verify.ps1 --full`. Then Read a few shots: the skyline, the duel camera, and the possession HUD (`boss_*`).
2. **Playtest the R7 boss model by hand.** These numbers are in `data/tuning/bosses.json → duel.r7`:
   - `offense_strike_mult` 0.35
   - `turnover_pct` 0.30
   - `cough_pct` 0.045
   - the contest windows (`perfect_base_f` 4, `good_extra_f` 10)
   - `score_pct` per shot kind

   Balance REVIEW rows: Grandmaster Boom T1 (fast) and T5 (long), Rat King T3.
3. **Playtest R6 pacing.** Each court has one lieutenant. If it still feels like you can rush bosses, the next lever is a "street rep" count per district: beat N crews, read N tags, or talk to people before the lieutenant shows up.
4. **Deferred: more hand-authored side streets** (§0.1 scope). Right now each district gets 2 procedural alley stashes and rumor NPCs. Each map could also get a hand-placed side alley with a mini-encounter and a unique NPC.
