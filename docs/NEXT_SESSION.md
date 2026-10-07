# Next session

This session (2026-10-07) did NEXT_SESSION steps 1, 3 and 4, plus readable hit feedback on street enemies. What changed and why is in `docs/DECISIONS.md` ("Street rep, side streets, hit feedback") and spec §3.6b.

## What shipped
- **Buzz (street rep):** a lieutenant only shows up once the district knows your name. You earn Buzz from crews, tags, people, boxes and stashes, and the side street. The court needs 6 for a mini and 8 for a King or landmark (`data/tuning/street_rep.json`).
- **Side streets:** one hand-written alley per district (`data/dialogue/side_streets.json`). Each has a crew leader + 2, a local with before/after lines, loot, and +3 Buzz.
- **Hit feedback:** enemy health bars with a chip trail, DOWN/SHOOK tags that turn into "[R] FINISH", a gold glow on open enemies, a red-white flash + squash on hits, and bigger damage numbers.

## Suggested next steps
1. **Playtest the R7 boss model by hand** (still open). The numbers are in `data/tuning/bosses.json → duel.r7`. Balance REVIEW rows: Grandmaster Boom T1 and T5, Rat King T3.
2. **Playtest Buzz pacing.** If 6/8 feels grindy or trivial, change `need` in `street_rep.json`. Kill Buzz is uncapped (commons respawn at bodegas).
3. **Ankles vs street crews.** Balance is unchanged: knockdown 1.5 s, then the finisher window. If ankles still feel weak once they're readable, the next lever is a damage-taken bonus while DOWN (e.g. ×1.25 in `DamageService._buffs`).
4. Side streets are placed in each map's longest alley cut. If one lands somewhere odd, pin it with `"tile": [x, y]` in `side_streets.json`.
